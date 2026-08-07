#!/usr/bin/env python3
"""
tutorial_digest.py — 走位序列 JSON → 精讲写作事实清单（deterministic digest）

用途：为「序列 → 图文精讲」写作提供预计算的几何事实，写作方（人或 AI）
只做语言组织，禁止自行脑算几何。配套技能：.cursor/skills/tutorial-authoring/SKILL.md。

用法：
    python3 scripts/tutorial_digest.py content/position_play/sequences/<seq>.json [更多.json...]

坐标契约（真源：QiuJi/Resources/Drills/schema.md + .kiro/steering/table-geometry.md）：
    归一化 2D 顶视：x ∈ [0,1] 左→右，y ∈ [0,0.5] 上→下；长轴水平，2:1。
    x/y 同尺度（均为台面长 2.540m 的比例），欧氏距离 × 2.540 = 米。
    球直径（canvas）= 0.0225；中线（长轴中心线）y = 0.25。

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
MIDLINE_Y = 0.25             # 长轴中心线

POCKETS = {
    "topLeft":      (-0.0165, -0.0165),
    "topRight":     (1.0165, -0.0165),
    "bottomLeft":   (-0.0165, 0.5165),
    "bottomRight":  (1.0165, 0.5165),
    "topCenter":    (0.5, -0.0268),
    "bottomCenter": (0.5, 0.5268),
}

POCKET_NAMES = {  # 与 App PocketDisplay 同口径
    "topLeft": "左上袋", "topRight": "右上袋",
    "bottomLeft": "左下袋", "bottomRight": "右下袋",
    "topCenter": "上中袋", "bottomCenter": "下中袋",
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
    """粗区域：横向三分 × 纵向上/下半，附近库标记。"""
    x, y = p
    col = "左" if x < 1 / 3 else ("中" if x < 2 / 3 else "右")
    row = "上半" if y < MIDLINE_Y - 0.01 else ("下半" if y > MIDLINE_Y + 0.01 else "中线上")
    parts = [f"{col}路{row}"]
    cushions = []
    if x < 0.07:
        cushions.append("近左库")
    if x > 0.93:
        cushions.append("近右库")
    if y < 0.035:
        cushions.append("近上库")
    if y > 0.465:
        cushions.append("近下库")
    if cushions:
        parts.append("、".join(cushions))
    return "，".join(parts)


def octant(from_p, to_p):
    """to_p 相对 from_p 的八方位（顶视：y 小 = 上）。"""
    dx = to_p[0] - from_p[0]
    dy = to_p[1] - from_p[1]
    if abs(dx) < 1e-9 and abs(dy) < 1e-9:
        return "原地"
    ang = math.degrees(math.atan2(-dy, dx))  # 屏幕上方为正
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
    """与 App PowerDisplay.name 同口径。"""
    if v < 1.2:
        return "轻推"
    if v < 2.2:
        return "轻"
    if v < 3.6:
        return "中"
    if v < 4.8:
        return "中大"
    return "大力"


def spin_class(h_pct, v_pct):
    """杆法分类（供理论参考映射）。阈值 15% 以下按接近中心处理。"""
    vert = "高杆" if v_pct >= 15 else ("低杆" if v_pct <= -15 else "中心")
    side = "左塞" if h_pct >= 15 else ("右塞" if h_pct <= -15 else "")
    return vert, side


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
        readout, h_pct, v_pct = spin_readout(shot.get("spinX", 0), shot.get("spinY", 0))
        vel = shot.get("velocity", 0)
        vert, side = spin_class(h_pct, v_pct)

        w(f"- params（照抄进 JSON）：spinX={shot.get('spinX', 0)}, "
          f"spinY={shot.get('spinY', 0)}, velocity={vel}")
        w(f"- 打点读数：{readout}（杆法分类：{vert}{'+' + side if side else ''}）；"
          f"力度：{power_name(vel)} · {vel:.1f} m/s")

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
                w(f"- 是否穿越中线（y=0.25）：{'是' if crossed else '否'}")
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
