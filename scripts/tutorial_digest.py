#!/usr/bin/env python3
"""
tutorial_digest.py — 走位序列 JSON → 精讲写作事实清单（deterministic digest）

用途：为「序列 → 图文精讲」写作提供预计算的几何事实，写作方（人或 AI）
只做语言组织，禁止自行脑算几何。配套技能：.cursor/skills/tutorial-authoring/SKILL.md。

用法：
    python3 scripts/tutorial_digest.py content/position_play/sequences/<seq>.json [更多.json...]

坐标契约（DR-063；代码真源 AngleSceneCalculator.sceneToNormalized）：
    归一化 2D：canvasX ∈ [0,1]（= 世界 X），canvasY ∈ [0,0.5]（= 世界 Z，同向）。
    canvasX = (sceneX + 1.270)/2.540；canvasY = (sceneZ + 0.635)/2.540。
    x/y 同尺度（均为台面长 2.540m 的比例），欧氏距离 × 2.540 = 米。
    球直径（canvas）= 0.0225；短轴中线 canvasY = 0.25。

    用户可见方位词统一到 **portrait 屏幕系**（与精讲配图 / 击打页同向，
    CameraRig.applyTopDown2DRotated）：
        屏幕上 = 世界 +X = canvasX 增
        屏幕右 = 世界 +Z = canvasY 增
    region / octant / 袋口中文名均按此屏幕系输出。

输出不包含轨迹细节（吃库次数、路径形状）——digest 只有 before/after 快照事实。
涉及「几库走位 / 是否吃库」的表述必须对照出片产物（sNN.mp4 / sNN_still.png）核实。
"""

import json
import math
import sys

# ---------------------------------------------------------------- constants

TABLE_LEN_M = 2.540          # 台面长（米），归一化 1.0 对应值
BALL_DIAM = 0.0225           # 球直径（canvas 单位），= ballRadius × 2
MISCUE_LIMIT = 0.5           # CuePhysics.miscueLimitFraction（打点读数分母）
MIDLINE_Y = 0.25             # 短轴中线（canvasY；portrait 屏幕左右分界）

# 打点读数单位契约（DR-063 T1）：
#   ShotIntent.Spin / ShotInput.spinX·spinY = 接触点偏移 / R（无量纲）。
#   spin=1.0 ⇒ 1.0·R = 28.575 mm；满塞钳制 MISCUE_LIMIT=0.5 ⇒ 0.5·R = 14.2875 mm。
#   SpinDisplay 百分比读数 = spin / MISCUE_LIMIT × 100（满塞=100%）。
#   定性塞量用「皮头」：任务口径皮头宽≈12 mm（代码 CuePhysics.tipDiameter=11 mm，
#   定性词阈值按 12 mm 换算，避免与台球房口吻偏差）。
BALL_R_MM = 28.575
TIP_WIDTH_MM = 12.0                      # 定性词用；非代码 tipDiameter
HALF_TIP_SPIN = (TIP_WIDTH_MM / 2) / BALL_R_MM   # 6mm / R ≈ 0.2100
ONE_TIP_SPIN = TIP_WIDTH_MM / BALL_R_MM          # 12mm / R ≈ 0.4199

POCKETS = {
    "topLeft":      (-0.0165, -0.0165),
    "topRight":     (1.0165, -0.0165),
    "bottomLeft":   (-0.0165, 0.5165),
    "bottomRight":  (1.0165, 0.5165),
    "topCenter":    (0.5, -0.0268),
    "bottomCenter": (0.5, 0.5268),
}

# portrait 屏幕系袋口名（DR-063；与 PocketDisplay / DrillCoverAnnotation 同口径）
POCKET_NAMES = {
    "topLeft": "左下角袋", "topRight": "左上角袋",
    "bottomLeft": "右下角袋", "bottomRight": "右上角袋",
    "topCenter": "左侧中袋", "bottomCenter": "右侧中袋",
}

# ---------------------------------------------------------------- helpers


def ball_label(key):
    if key == "cueBall":
        return "母球"
    if key.startswith("_"):
        return f"{key[1:]}号球"
    return key


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def in_balls(d):
    return d / BALL_DIAM


def fmt_balls(d):
    b = in_balls(d)
    if b < 0.75:
        return "不足1颗球"
    return f"约{b:.1f}颗球"


def region(p):
    """粗区域（portrait 屏幕系，DR-063）。

    契约：屏幕上=+canvasX，屏幕右=+canvasY。
    - 纵向（长轴=canvasX）分下/中/上三路；横向（短轴=canvasY）分左/右半。
    - 库名：顶库=+X 短库（canvasX 大）、底库=−X 短库、左库=−Z 长库、右库=+Z 长库。
    """
    x, y = p  # canvasX, canvasY
    # 屏幕纵向：canvasX 大 = 上路（屏幕上方）
    lane = "下路" if x < 1 / 3 else ("中路" if x < 2 / 3 else "上路")
    half = "左半" if y < MIDLINE_Y - 0.01 else ("右半" if y > MIDLINE_Y + 0.01 else "中线")
    parts = [f"{lane}{half}"]
    cushions = []
    if x > 0.93:
        cushions.append("近顶库")
    if x < 0.07:
        cushions.append("近底库")
    if y < 0.035:
        cushions.append("近左库")
    if y > 0.465:
        cushions.append("近右库")
    if cushions:
        parts.append("、".join(cushions))
    return "，".join(parts)


def octant(from_p, to_p):
    """to_p 相对 from_p 的八方位（portrait 屏幕系，DR-063）。

    屏幕右 = +canvasY，屏幕上 = +canvasX；atan2(上分量, 右分量)。
    """
    right = to_p[1] - from_p[1]   # +canvasY
    up = to_p[0] - from_p[0]      # +canvasX
    if abs(right) < 1e-9 and abs(up) < 1e-9:
        return "原地"
    ang = math.degrees(math.atan2(up, right))
    ang = (ang + 360) % 360
    names = ["右", "右上", "上", "左上", "左", "左下", "下", "右下"]
    return names[int((ang + 22.5) // 45) % 8]


def cut_angle_deg(cue, target, pocket_xy):
    """切球角（近似）：cue→target 方向与 target→袋口 方向的夹角。0° = 直线球。"""
    v1 = (target[0] - cue[0], target[1] - cue[1])
    v2 = (pocket_xy[0] - target[0], pocket_xy[1] - target[1])
    n1, n2 = math.hypot(*v1), math.hypot(*v2)
    if n1 < 1e-9 or n2 < 1e-9:
        return 0.0
    c = (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def cut_desc(deg):
    if deg < 5:
        return "直线球"
    if deg < 15:
        return "近直线（小角度）"
    if deg < 35:
        return "中小角度"
    if deg < 55:
        return "中等角度"
    if deg < 75:
        return "大角度"
    return "极薄切球"


def spin_readout(sx, sy):
    """与 App SpinDisplay.readout 同口径：占打滑极限(0.5R)的百分比。"""
    h = round(sx / MISCUE_LIMIT * 100)
    v = round(sy / MISCUE_LIMIT * 100)
    if h == 0 and v == 0:
        return "中心球", h, v
    parts = []
    if v != 0:
        parts.append(f"{'高' if v > 0 else '低'}{abs(v)}%")
    if h != 0:
        parts.append(f"{'左' if h > 0 else '右'}{abs(h)}%")
    return " · ".join(parts), h, v


def power_name(v):
    """力度定性词；阈值与 App PowerDisplay.name 同源，词面用台球房口径（DR-063）。"""
    if v < 1.2:
        return "轻推"
    if v < 2.2:
        return "小力"
    if v < 3.6:
        return "中力"
    if v < 4.8:
        return "中大力"
    return "大力"


def power_phrase(v):
    """如「小力（1.6 m/s）」。"""
    return f"{power_name(v)}（{v:.1f} m/s）"


def vertical_cue(sy):
    """竖向杆法定性词（阈值按 T1 皮头换算，单位=spin=偏移/R）。

    |sy| 分档（中点切分）：
      < half/2 (0.105)           → 中杆
      < (half+one)/2 (0.315)     → 中高杆 / 中低杆
      < (one+miscue)/2 (0.460)   → 高杆 / 低杆
      ≥ 0.460                    → 纯高杆 / 纯低杆
    """
    mag = abs(sy)
    if mag < HALF_TIP_SPIN / 2:
        return "中杆"
    if mag < (HALF_TIP_SPIN + ONE_TIP_SPIN) / 2:
        return "中高杆" if sy > 0 else "中低杆"
    if mag < (ONE_TIP_SPIN + MISCUE_LIMIT) / 2:
        return "高杆" if sy > 0 else "低杆"
    return "纯高杆" if sy > 0 else "纯低杆"


def side_english(sx):
    """横向塞：无塞 / 半颗皮头的左|右塞 / 一颗皮头的左|右塞（取最近档）。"""
    levels = (0.0, HALF_TIP_SPIN, ONE_TIP_SPIN)
    mag = abs(sx)
    nearest = min(levels, key=lambda lv: abs(mag - lv))
    if nearest == 0.0:
        return "无塞"
    side = "左塞" if sx > 0 else "右塞"
    amount = "半颗皮头的" if nearest == HALF_TIP_SPIN else "一颗皮头的"
    return f"{amount}{side}"


def cue_phrase(sx, sy):
    """组合杆法：如「中高杆加一颗皮头的右塞」；中杆且无塞 →「中杆」。"""
    vert = vertical_cue(sy)
    side = side_english(sx)
    if side == "无塞":
        return vert
    if vert == "中杆":
        return side  # 「半颗皮头的左塞」
    return f"{vert}加{side}"


def spin_class(sx, sy):
    """杆法分类（供理论参考映射）。用定性竖/横向，不再用 15% 硬切。"""
    vert = vertical_cue(sy)
    side = side_english(sx)
    # theory_hints 仍认「高杆/低杆/中心」粗桶
    if "高" in vert:
        vert_bucket = "高杆"
    elif "低" in vert:
        vert_bucket = "低杆"
    else:
        vert_bucket = "中心"
    side_bucket = "" if side == "无塞" else ("左塞" if sx > 0 else "右塞")
    return vert_bucket, side_bucket


def theory_hints(vert, side, cut, n_steps, step_idx):
    """理论参考（16.billiard_theory 定理编号）。仅供作者转成教练话，禁止正文出现编号。"""
    hints = []
    if vert == "中心" and cut >= 15:
        hints.append("T02 90°法则：中心/定杆击球，母球沿切线（垂直于两球连心线）分离约90°")
    if vert == "高杆":
        hints.append("T01 30°法则/T03 切线法则：母球先走切线，随后被前旋拉弯向前；短距离时来不及转成滚动，实际更贴切线")
    if vert == "低杆":
        hints.append("T03 切线法则：母球先走切线，随后被回旋向后拉弯；距离越短切线段占比越大")
    if cut < 5:
        hints.append("直线球没有切角可用：母球只能沿击球线前后走（跟进/定/缩），无法横向走位")
    if side:
        hints.append("T09 最少加塞原则：此杆用了侧塞，正文应交代为什么中杆做不到（否则应反思参数）")
    if n_steps >= 2:
        if step_idx == n_steps - 2:
            hints.append("T06 关键球原理：这是倒数第二杆（key ball 位），走位质量直接决定收尾成败")
        if step_idx < n_steps - 1:
            hints.append("T05 反向规划：本杆落点由下一杆需求倒推而来，「为什么」条必须写出下一杆需要什么")
    return hints


# ---------------------------------------------------------------- digest


def digest(path):
    with open(path, encoding="utf-8") as f:
        seq = json.load(f)

    steps = seq.get("steps", [])
    lines = []
    w = lines.append

    w(f"# 事实清单：{seq.get('name', '?')}（{len(steps)} 杆）")
    w(f"来源文件：{path}")
    w("")
    w("> 本清单由 scripts/tutorial_digest.py 确定性计算生成。写精讲时几何事实只准抄本清单，")
    w("> 禁止自行从坐标脑算。清单不含轨迹细节（吃库/路径形状），涉及吃库表述须核对出片视频。")
    w("")

    # ---- 开局
    w("## 开局布局")
    initial = seq.get("initial", {}).get("onTable", {})
    for key in sorted(initial, key=lambda k: (k != "cueBall", k)):
        p = (initial[key]["x"], initial[key]["y"])
        w(f"- {ball_label(key)}：({p[0]:.3f}, {p[1]:.3f}) — {region(p)}")

    order = " → ".join(
        f"{ball_label(s['shot']['targetKey'])}·{POCKET_NAMES.get(s['shot']['pocket'], s['shot']['pocket'])}"
        for s in steps if s["shot"].get("targetKey")
    )
    w(f"- 击打顺序与袋口：{order}")
    w("")

    # ---- 形态判定（DR-062）：开局布局之后、逐杆之前；纯新增行，不改既有字段格式
    # 判据：各杆目标球距袋距离极差 < 0.5 颗球 且袋口一致 → 独立阶梯；否则走位链。
    pocket_set = set()
    dtp_balls = []
    for step in steps:
        shot = step["shot"]
        tkey = shot.get("targetKey", "")
        pocket = shot.get("pocket", "")
        if not tkey or not pocket:
            continue
        before = {k: (v["x"], v["y"]) for k, v in step["before"]["onTable"].items()}
        if tkey not in before:
            continue
        pk = POCKETS.get(pocket)
        if not pk:
            continue
        pocket_set.add(pocket)
        dtp_balls.append(in_balls(dist(before[tkey], pk)))
    if dtp_balls and len(pocket_set) == 1 and (max(dtp_balls) - min(dtp_balls)) < 0.5:
        dtp_rep = sum(dtp_balls) / len(dtp_balls)
        w(f"形态判定：独立阶梯（目标球距袋恒定 {dtp_rep:.1f} 颗球，袋口不变）")
    else:
        w("形态判定：走位链（目标球距袋逐杆变化）")
    w("")

    # ---- 逐杆
    for i, step in enumerate(steps):
        shot = step["shot"]
        before = {k: (v["x"], v["y"]) for k, v in step["before"]["onTable"].items()}
        after = {k: (v["x"], v["y"]) for k, v in step["after"]["onTable"].items()}
        tkey = shot.get("targetKey", "")
        pocket = shot.get("pocket", "")
        pocket_zh = POCKET_NAMES.get(pocket, pocket or "（自由球，无袋口）")
        free = shot.get("freeAim") is not None or not tkey

        w(f"## 第{i + 1}杆：{ball_label(tkey) if tkey else '自由球'} · {pocket_zh}")

        cue_b = before.get("cueBall")
        cue_a = after.get("cueBall")
        sx = shot.get("spinX", 0)
        sy = shot.get("spinY", 0)
        readout, h_pct, v_pct = spin_readout(sx, sy)
        vel = shot.get("velocity", 0)
        vert, side = spin_class(sx, sy)
        cue_zh = cue_phrase(sx, sy)

        w(f"- params（照抄进 JSON）：spinX={sx}, "
          f"spinY={sy}, velocity={vel}")
        w(f"- 打点读数：{readout}（h={h_pct}% v={v_pct}%）；"
          f"杆法：{cue_zh}；力度：{power_phrase(vel)}")

        if cue_b and tkey in before and not free:
            tgt = before[tkey]
            pk = POCKETS.get(pocket)
            w(f"- 击球前：母球在{ball_label(tkey)}的{octant(tgt, cue_b)}方，"
              f"两球相距{fmt_balls(dist(cue_b, tgt))}"
              f"（{dist(cue_b, tgt) * TABLE_LEN_M:.2f} m）；"
              f"{ball_label(tkey)}距{pocket_zh}{fmt_balls(dist(tgt, pk))}")
            cut = cut_angle_deg(cue_b, tgt, pk)
            w(f"- 切球角（近似）：{cut:.0f}° — {cut_desc(cut)}")
        else:
            cut = 0.0
            if cue_b:
                w(f"- 击球前：母球位于 ({cue_b[0]:.3f}, {cue_b[1]:.3f}) — {region(cue_b)}")

        potted = step.get("potted", [])
        if potted:
            w(f"- 本杆进袋：{'、'.join(ball_label(k) for k in potted)}"
              f"{'（含母球 scratch ⚠️）' if step.get('cuePocketed') else ''}")

        if cue_a:
            w(f"- 母球落点（after 快照）：({cue_a[0]:.3f}, {cue_a[1]:.3f}) — {region(cue_a)}")
            if tkey in before:
                w(f"- 母球接触后移动距离：{fmt_balls(dist(before[tkey], cue_a))}"
                  f"（自目标球原位起算，近似值）")
            if cue_b:
                crossed = (cue_b[1] - MIDLINE_Y) * (cue_a[1] - MIDLINE_Y) < 0
                w(f"- 是否穿越纵向中线（canvasY=0.25，portrait 左右分界）："
                  f"{'是' if crossed else '否'}")
        elif step.get("cuePocketed"):
            w("- 母球落点：进袋离场（scratch）")

        # 与下一杆的衔接
        if i + 1 < len(steps):
            nxt = steps[i + 1]
            n_shot = nxt["shot"]
            n_tkey = n_shot.get("targetKey", "")
            n_before = {k: (v["x"], v["y"]) for k, v in nxt["before"]["onTable"].items()}
            if cue_a and n_tkey in n_before:
                n_tgt = n_before[n_tkey]
                n_pk = POCKETS.get(n_shot.get("pocket", ""))
                w(f"- 【为下一杆创造的局面】母球停在{ball_label(n_tkey)}的"
                  f"{octant(n_tgt, cue_a)}方，相距{fmt_balls(dist(cue_a, n_tgt))}")
                if n_pk:
                    n_cut = cut_angle_deg(cue_a, n_tgt, n_pk)
                    w(f"- 【为下一杆留出的切球角】约{n_cut:.0f}° — {cut_desc(n_cut)}"
                      f"（下一杆打{POCKET_NAMES.get(n_shot.get('pocket', ''), '?')}）")

        hints = theory_hints(vert, side, cut, len(steps), i)
        if hints:
            w("- 理论参考（转成教练话用，正文禁止出现编号）：")
            for hint in hints:
                w(f"    - {hint}")
        w("")

    # ---- 终局
    final = steps[-1]["after"]["onTable"] if steps else {}
    if final:
        w("## 终局")
        for key in sorted(final, key=lambda k: (k != "cueBall", k)):
            p = (final[key]["x"], final[key]["y"])
            w(f"- {ball_label(key)}：({p[0]:.3f}, {p[1]:.3f}) — {region(p)}")
        w("")

    return "\n".join(lines)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    for path in argv[1:]:
        try:
            print(digest(path))
            print("=" * 72)
        except Exception as exc:  # noqa: BLE001 — CLI 边界，如实报错即可
            print(f"ERROR: {path}: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
