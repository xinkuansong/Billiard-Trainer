#!/usr/bin/env python3
"""
里程碑 A：从 Drill 参考截图全自动定位球位 + 提取轨迹。

输入：一组「摆球态 / 带轨迹态」成对帧（奇数=摆球、偶数=带轨迹，两两一组=一杆）。
处理（逐帧独立，因成对帧尺寸不同、未像素配准）：
  S0 标定   ：HSV 抠绿呢 → 取稳健包围盒作内沿球桌矩形 → 像素↔归一化(x∈[0,1], y∈[0,0.5])。
  S1 定位   ：摆球帧在台面内做颜色团块检测（白=母球 / 橙=目标球 / 蓝=障碍球），质心→归一化。
  S1.5 轨迹 ：带轨迹帧按颜色分割「灰=母球轨迹 / 橙=目标球进球线」→ 归一化点集；橙线远端→选定袋。
输出：
  build/shot_reconstruction/<drill>/overlay_groupN.png  人工肉眼核对的识别叠加图
  build/shot_reconstruction/<drill>/extraction.json      归一化坐标（喂给下游 Swift 反解 S2）

坐标系与引擎一致：normalizedToScene 用 x∈[0,1]→length(2.54m)、y∈[0,0.5]→width(1.27m)。
"""
from __future__ import annotations

import argparse
import glob
import json
import os
from dataclasses import dataclass, field, asdict

import cv2
import numpy as np

# 引擎常量（QiuJi/Core/Scene/AngleSceneCalculator.swift）
BALL_DIAMETER_M = 0.05715
INNER_LENGTH_M = 2.54
# 球直径占归一化 x 的比例（用于按台桌像素宽推算球的像素大小）
BALL_DIAM_NX = BALL_DIAMETER_M / INNER_LENGTH_M  # ≈ 0.0225

# 归一化袋口中心（schema.md / P10 Pocket ID → index）
POCKETS = {
    "topLeft": (0.0, 0.0),
    "topRight": (1.0, 0.0),
    "bottomLeft": (0.0, 0.5),
    "bottomRight": (1.0, 0.5),
    "topCenter": (0.5, 0.0),
    "bottomCenter": (0.5, 0.5),
}


@dataclass
class TableRect:
    """带轨迹/摆球帧各自的内沿球桌矩形（像素），用于像素↔归一化映射。"""
    x0: int
    y0: int
    x1: int
    y1: int

    @property
    def w(self) -> int:
        return self.x1 - self.x0

    @property
    def h(self) -> int:
        return self.y1 - self.y0

    def to_norm(self, px: float, py: float) -> tuple[float, float]:
        nx = (px - self.x0) / self.w
        ny = (py - self.y0) / self.h * 0.5
        return nx, ny

    def to_px(self, nx: float, ny: float) -> tuple[int, int]:
        px = self.x0 + nx * self.w
        py = self.y0 + ny / 0.5 * self.h
        return int(round(px)), int(round(py))


@dataclass
class Ball:
    role: str          # cue / target / obstacle
    nx: float
    ny: float
    px: int
    py: int
    r_px: int


@dataclass
class ShotExtraction:
    group: int
    setup_frame: str
    path_frame: str
    balls: list[Ball] = field(default_factory=list)
    cue_path_norm: list[tuple[float, float]] = field(default_factory=list)
    cue_path_ordered: list[tuple[float, float]] = field(default_factory=list)
    cue_rest_norm: tuple[float, float] | None = None  # 母球落点（走位终点）
    object_path_norm: list[tuple[float, float]] = field(default_factory=list)
    selected_pocket: str | None = None


# ---------------------------------------------------------------- S0 标定

def calibrate(img: np.ndarray) -> TableRect:
    """抠绿呢取内沿球桌矩形。绿呢是台面最大的高饱和绿色连通域，其稳健包围盒≈库边内沿。"""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    # 绿呢：H 35~95、S 较高、V 中高
    green = cv2.inRange(hsv, (35, 60, 40), (95, 255, 255))
    green = cv2.morphologyEx(green, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    green = cv2.morphologyEx(green, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    ys, xs = np.where(green > 0)
    if len(xs) == 0:
        raise RuntimeError("未找到绿呢区域，标定失败")
    # 用 1% 分位去除杂散绿点
    x0 = int(np.percentile(xs, 0.5))
    x1 = int(np.percentile(xs, 99.5))
    y0 = int(np.percentile(ys, 0.5))
    y1 = int(np.percentile(ys, 99.5))
    return TableRect(x0, y0, x1, y1)


# ---------------------------------------------------------------- S1 球位

def _ball_px_radius(rect: TableRect) -> float:
    return BALL_DIAM_NX * rect.w / 2.0


def _detect_color_blobs(hsv: np.ndarray, mask: np.ndarray, rect: TableRect,
                        roi: np.ndarray, min_frac=0.25, max_frac=4.0) -> list[tuple[int, int, int]]:
    """在 roi 内对 mask 找球大小的团块，返回 [(px,py,r_px)]，按面积降序。"""
    mask = cv2.bitwise_and(mask, roi)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    rb = _ball_px_radius(rect)
    area_ball = np.pi * rb * rb
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    out = []
    for c in cnts:
        a = cv2.contourArea(c)
        if a < area_ball * min_frac or a > area_ball * max_frac:
            continue
        (x, y), r = cv2.minEnclosingCircle(c)
        # 圆度过滤（球应接近圆）
        if a / (np.pi * r * r + 1e-6) < 0.55:
            continue
        out.append((int(x), int(y), int(r)))
    out.sort(key=lambda t: -t[2])
    return out


def detect_balls(img: np.ndarray, rect: TableRect) -> list[Ball]:
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    # 台面内 ROI（向内收 1.2 个球半径，排除库边高光 / 袋口 jaw / 顶部球架）
    m = int(_ball_px_radius(rect) * 1.2)
    roi = np.zeros(img.shape[:2], np.uint8)
    roi[rect.y0 + m:rect.y1 - m, rect.x0 + m:rect.x1 - m] = 255

    masks = {
        # 白母球：低饱和 + 高亮
        "cue": cv2.inRange(hsv, (0, 0, 175), (179, 60, 255)),
        # 橙/黄目标球
        "target": cv2.inRange(hsv, (10, 120, 150), (32, 255, 255)),
        # 蓝障碍球
        "obstacle": cv2.inRange(hsv, (95, 110, 80), (130, 255, 255)),
    }
    balls: list[Ball] = []
    for role, mask in masks.items():
        blobs = _detect_color_blobs(hsv, mask, rect, roi)
        if not blobs:
            continue
        x, y, r = blobs[0]  # 取最大团块作该色球
        nx, ny = rect.to_norm(x, y)
        balls.append(Ball(role=role, nx=round(nx, 4), ny=round(ny, 4), px=x, py=y, r_px=r))
    return balls


# ---------------------------------------------------------------- S1.5 轨迹

def _norm_points(mask: np.ndarray, rect: TableRect, step=6) -> list[tuple[float, float]]:
    ys, xs = np.where(mask > 0)
    pts = []
    for i in range(0, len(xs), step):
        nx, ny = rect.to_norm(float(xs[i]), float(ys[i]))
        pts.append((round(nx, 4), round(ny, 4)))
    return pts


def extract_trajectory(img: np.ndarray, rect: TableRect, balls: list[Ball]
                       ) -> tuple[list, list, np.ndarray, np.ndarray]:
    """带轨迹帧：用 top-hat 提取细亮线（轨迹线比绿呢亮、比球细），再按色相分灰线/橙线。

    返回 (cue_pts, obj_pts, gray_mask, orange_mask)。"""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    gray_img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    m = int(_ball_px_radius(rect) * 0.8)
    roi = np.zeros(img.shape[:2], np.uint8)
    roi[rect.y0 + m:rect.y1 - m, rect.x0 + m:rect.x1 - m] = 255

    # top-hat：核大于线宽(~2px)、小于球(~21px)，提取细亮结构（轨迹线、瞄准线）
    rb = _ball_px_radius(rect)
    ksz = max(7, int(rb))           # ≈ 球半径
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (ksz, ksz))
    tophat = cv2.morphologyEx(gray_img, cv2.MORPH_TOPHAT, kernel)
    _, lines = cv2.threshold(tophat, 14, 255, cv2.THRESH_BINARY)
    lines = cv2.bitwise_and(lines, roi)

    # 抠掉球本体（含较大半径，去掉球的高光/阴影边）
    for b in balls:
        cv2.circle(lines, (b.px, b.py), int(b.r_px * 1.8), 0, -1)

    # 仅保留线状连通域（剔除残留小团块）
    lines = _keep_thin(lines, rect)

    # 按色相把线分成「橙=进球线」与「灰=母球轨迹」
    s = hsv[:, :, 1]
    h = hsv[:, :, 0]
    is_orange = ((h >= 5) & (h <= 32) & (s >= 70)).astype(np.uint8) * 255
    orange = cv2.bitwise_and(lines, is_orange)
    orange = cv2.dilate(orange, np.ones((3, 3), np.uint8))
    orange = cv2.bitwise_and(orange, lines)
    gray = cv2.bitwise_and(lines, cv2.bitwise_not(orange))

    cue_pts = _norm_points(gray, rect)
    obj_pts = _norm_points(orange, rect)
    return cue_pts, obj_pts, gray, orange


def _keep_thin(mask: np.ndarray, rect: TableRect) -> np.ndarray:
    """剔除非线状的大面积团块（按连通域宽高比/填充率）。"""
    rb = _ball_px_radius(rect)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    out = np.zeros_like(mask)
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area < 8:
            continue
        fill = area / (w * h + 1e-6)
        long_side = max(w, h)
        # 线状：细长（长边大于球半径）且填充率低（非实心团块）
        if long_side > rb and fill < 0.6:
            out[lab == i] = 255
    return out


def _pt_seg_dist(p, a, b) -> float:
    px, py = p
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 < 1e-9:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def cue_rest_geodesic(pts: list, start: tuple[float, float], radius=0.05
                      ) -> tuple[float, float] | None:
    """母球落点 = 从最靠近起点的点出发、在邻接图(半径radius)里测地最远可达点。

    比"欧氏最远点"稳健：自交折线沿路径走、不会抄近路；间隙≤radius 自动桥接。"""
    import heapq
    if len(pts) < 2:
        return pts[-1] if pts else None
    P = pts
    n = len(P)
    s = min(range(n), key=lambda i: (P[i][0] - start[0]) ** 2 + (P[i][1] - start[1]) ** 2)
    dist = [float("inf")] * n
    dist[s] = 0.0
    pq = [(0.0, s)]
    r2 = radius * radius
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist[u]:
            continue
        ux, uy = P[u]
        for v in range(n):
            if v == u:
                continue
            dx, dy = P[v][0] - ux, P[v][1] - uy
            w2 = dx * dx + dy * dy
            if w2 <= r2:
                nd = d + w2 ** 0.5
                if nd < dist[v]:
                    dist[v] = nd
                    heapq.heappush(pq, (nd, v))
    far = max(range(n), key=lambda i: dist[i] if dist[i] != float("inf") else -1.0)
    return P[far]


def order_cue_path(pts: list, start: tuple[float, float], max_step=0.06
                   ) -> list[tuple[float, float]]:
    """带动量的最近邻排序：从最靠近母球起点的点出发，沿当前朝向贪心连成有向折线。

    动量项让自交折线（碰库 V 形）在交叉处仍沿原方向延伸而非折返。末端 = 母球落点。"""
    if not pts:
        return []
    remaining = list(pts)
    cur = min(remaining, key=lambda p: (p[0] - start[0]) ** 2 + (p[1] - start[1]) ** 2)
    remaining.remove(cur)
    path = [cur]
    heading = None
    while remaining:
        cands = [p for p in remaining if (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2 <= max_step ** 2]
        if not cands:
            break
        if heading is None:
            nxt = min(cands, key=lambda p: (p[0] - cur[0]) ** 2 + (p[1] - cur[1]) ** 2)
        else:
            def score(p):
                vx, vy = p[0] - cur[0], p[1] - cur[1]
                l = (vx * vx + vy * vy) ** 0.5 + 1e-9
                cosang = (vx * heading[0] + vy * heading[1]) / l
                return l + 0.04 * (1 - cosang)   # 距离 + 转向惩罚
            nxt = min(cands, key=score)
        hx, hy = nxt[0] - cur[0], nxt[1] - cur[1]
        hl = (hx * hx + hy * hy) ** 0.5 + 1e-9
        heading = (hx / hl, hy / hl)
        path.append(nxt)
        remaining.remove(nxt)
        cur = nxt
    return path


def guess_pocket(obj_pts: list, balls: list[Ball]) -> str | None:
    """投票法：选定袋 = 橙(进球线)点落在 目标球→该袋 连线附近最多的那个袋。

    对角落零星橙噪声稳健（噪声不会成片落在正确连线上）。"""
    target = next((b for b in balls if b.role == "target"), None)
    if target is None or not obj_pts:
        return None
    t = (target.nx, target.ny)
    tol = 0.03  # 归一化容差（约 1 个球径）
    best, best_score = None, -1
    for name, pk in POCKETS.items():
        # 只数离目标球足够远(>0.05)的橙点，避免目标球边缘像素对所有袋都计数
        far_pts = [p for p in obj_pts if (p[0] - t[0]) ** 2 + (p[1] - t[1]) ** 2 > 0.05 ** 2]
        score = sum(1 for p in far_pts if _pt_seg_dist(p, t, pk) <= tol)
        if score > best_score:
            best_score, best = score, name
    return best if best_score > 0 else None


# ---------------------------------------------------------------- 叠加可视化

def draw_overlay(img: np.ndarray, rect: TableRect, ex: ShotExtraction,
                 gray_mask: np.ndarray, orange_mask: np.ndarray) -> np.ndarray:
    out = img.copy()
    # 标定矩形
    cv2.rectangle(out, (rect.x0, rect.y0), (rect.x1, rect.y1), (0, 255, 255), 2)
    # 归一化网格（每 0.1 x / 0.05 y 画一条淡线，便于核对坐标）
    for k in range(1, 10):
        x = rect.x0 + int(k / 10 * rect.w)
        cv2.line(out, (x, rect.y0), (x, rect.y1), (60, 60, 60), 1)
    for k in range(1, 5):
        y = rect.y0 + int(k / 5 * rect.h)
        cv2.line(out, (rect.x0, y), (rect.x1, y), (60, 60, 60), 1)
    # 轨迹掩膜上色
    out[gray_mask > 0] = (255, 255, 255)
    out[orange_mask > 0] = (0, 165, 255)
    # 球
    role_color = {"cue": (255, 255, 255), "target": (0, 140, 255), "obstacle": (255, 120, 0)}
    for b in ex.balls:
        cv2.circle(out, (b.px, b.py), b.r_px + 2, role_color.get(b.role, (0, 0, 255)), 2)
        cv2.putText(out, f"{b.role} ({b.nx:.2f},{b.ny:.2f})", (b.px + 10, b.py - 8),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, role_color.get(b.role, (0, 0, 255)), 1, cv2.LINE_AA)
    # 母球落点（走位终点）：洋红实心 + 标注
    if ex.cue_rest_norm:
        rx, ry = rect.to_px(*ex.cue_rest_norm)
        cv2.circle(out, (rx, ry), 9, (255, 0, 255), -1)
        cv2.circle(out, (rx, ry), 9, (255, 255, 255), 1)
        cv2.putText(out, "cue rest", (rx + 10, ry + 4),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 0, 255), 1, cv2.LINE_AA)
    # 选定袋
    if ex.selected_pocket:
        px, py = rect.to_px(*POCKETS[ex.selected_pocket])
        cv2.circle(out, (px, py), 16, (0, 0, 255), 2)
        cv2.putText(out, ex.selected_pocket, (px - 30, py + 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1, cv2.LINE_AA)
    cv2.putText(out, f"group {ex.group}", (rect.x0 + 6, rect.y0 + 22),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2, cv2.LINE_AA)
    return out


# ---------------------------------------------------------------- 主流程

def process(frames_dir: str, drill: str, out_dir: str) -> None:
    frames = sorted(glob.glob(os.path.join(frames_dir, "frame_*.png")))
    if len(frames) % 2 != 0:
        print(f"⚠️ 帧数 {len(frames)} 非偶数，最后一帧将被忽略")
    os.makedirs(out_dir, exist_ok=True)

    results = []
    for gi in range(len(frames) // 2):
        setup_f = frames[2 * gi]
        path_f = frames[2 * gi + 1]
        setup = cv2.imread(setup_f)
        path = cv2.imread(path_f)

        setup_rect = calibrate(setup)
        path_rect = calibrate(path)

        balls = detect_balls(setup, setup_rect)
        cue_pts, obj_pts, gmask, omask = extract_trajectory(path, path_rect, balls)
        cue = next((b for b in balls if b.role == "cue"), None)
        ordered = order_cue_path(cue_pts, (cue.nx, cue.ny)) if cue else []
        rest = cue_rest_geodesic(cue_pts, (cue.nx, cue.ny)) if cue else None
        ex = ShotExtraction(
            group=gi + 1, setup_frame=os.path.basename(setup_f), path_frame=os.path.basename(path_f),
            balls=balls, cue_path_norm=cue_pts, cue_path_ordered=ordered, cue_rest_norm=rest,
            object_path_norm=obj_pts, selected_pocket=guess_pocket(obj_pts, balls),
        )
        overlay = draw_overlay(path, path_rect, ex, gmask, omask)
        op = os.path.join(out_dir, f"overlay_group{gi + 1}.png")
        cv2.imwrite(op, overlay)
        results.append(ex)
        roles = ", ".join(f"{b.role}({b.nx:.2f},{b.ny:.2f})" for b in balls)
        rest_s = f"({rest[0]:.2f},{rest[1]:.2f})" if rest else "∅"
        print(f"[group {gi+1}] {os.path.basename(setup_f)}+{os.path.basename(path_f)} "
              f"球: {roles or '∅'} | 袋: {ex.selected_pocket} | 母球落点: {rest_s} | "
              f"cuePts={len(cue_pts)} objPts={len(obj_pts)} -> {op}")

    jp = os.path.join(out_dir, "extraction.json")
    with open(jp, "w") as f:
        json.dump({"drill": drill, "shots": [asdict(r) for r in results]}, f,
                  ensure_ascii=False, indent=2)
    print(f"\nJSON -> {jp}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", default="QiuJi/Resources/Previews/drill_c005")
    ap.add_argument("--drill", default="drill_c005")
    ap.add_argument("--out", default="build/shot_reconstruction/drill_c005")
    args = ap.parse_args()
    process(args.frames, args.drill, args.out)


if __name__ == "__main__":
    main()
