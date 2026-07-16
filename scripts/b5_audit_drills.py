#!/usr/bin/env python3
"""B5a/B5b 全库审计批量几何脚本。

坐标契约（geometry-spatial-reasoning 回显）：
- Canvas 归一化 2D 系（真源 .kiro/steering/table-geometry.md + content-engineering/SKILL.md）：
  原点=台面左上角（顶视图），X∈[0,1] 左→右，Y∈[0,0.5] 上→下，
  单位=台面内沿长度 2.540 m 的百分比，2:1 台面。
- 球半径 r = 0.028575/2.540 = 0.01125（归一化）。
- 切角口径（沿用 B2 scripts/b2_variable_coverage_midpocket.py）：
  * 行进线切角 cut_travel = 白球→ghost ball 行进方向 与 进球线(目标球心→袋口中心) 的夹角；
  * 表观切角 cut_apparent = 白球心→目标球心连线 与 进球线 的夹角。
  ghost = target − 2r·normalize(pocket − target)。
- 中袋入袋角 = 进球线 与 中袋袋口法向(垂直于库边、指向台内) 的夹角；
  角袋入袋角 = 进球线 与 袋口对角轴(45°) 的夹角。

用法：python3 scripts/b5_audit_drills.py [categories...] > build/b5-audit-output.txt
默认审计 B5a 四分类：fundamentals accuracy cueAction separation。
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRILLS = ROOT / "QiuJi" / "Resources" / "Drills"
BOARDS = ROOT / "QiuJi" / "Resources" / "DrillBoards"

R = 0.028575 / 2.540  # 球半径（归一化）= 0.01125
TABLE_LEN_M = 2.540   # 归一化 1.0 对应的实距

POCKETS = {
    "topLeft":      (-0.0165, -0.0165),
    "topRight":     (+1.0165, -0.0165),
    "bottomLeft":   (-0.0165, +0.5165),
    "bottomRight":  (+1.0165, +0.5165),
    "topCenter":    (0.5, -0.0268),
    "bottomCenter": (0.5, +0.5268),
}
# 袋口轴向（袋口指向台内的“正入袋”方向）
POCKET_AXIS = {
    "topLeft":      (math.cos(math.radians(45)), math.sin(math.radians(45))),    # 指向右下
    "topRight":     (-math.cos(math.radians(45)), math.sin(math.radians(45))),   # 指向左下
    "bottomLeft":   (math.cos(math.radians(45)), -math.sin(math.radians(45))),   # 指向右上
    "bottomRight":  (-math.cos(math.radians(45)), -math.sin(math.radians(45))),  # 指向左上
    "topCenter":    (0.0, 1.0),   # 指向下（台内）
    "bottomCenter": (0.0, -1.0),  # 指向上（台内）
}


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def norm(v):
    return math.hypot(v[0], v[1])


def unit(v):
    n = norm(v)
    return (v[0] / n, v[1] / n)


def ang_between(u, v):
    """两向量夹角（度，0–180）。"""
    dot = u[0] * v[0] + u[1] * v[1]
    dot = max(-1.0, min(1.0, dot / (norm(u) * norm(v))))
    return math.degrees(math.acos(dot))


def rail_dist(p):
    """到最近库边的归一化距离（有效区边界按 0/1/0/0.5 台内沿）。"""
    return min(p[0], 1.0 - p[0], p[1], 0.5 - p[1])


def fmt_m(d):
    return f"{d:.3f} ({d * TABLE_LEN_M:.2f} m)"


def analyze_shot(i, shot):
    cue = (shot["cue"]["x"], shot["cue"]["y"])
    tgt = (shot["target"]["x"], shot["target"]["y"])
    pocket_name = shot.get("pocket")
    spin = shot.get("spin", {"x": 0.0, "y": 0.0})
    vel = shot.get("velocity")
    lines = []
    ct = norm(sub(tgt, cue))
    lines.append(f"  shot#{i}: cue=({cue[0]:.4f},{cue[1]:.4f}) target=({tgt[0]:.4f},{tgt[1]:.4f}) "
                 f"pocket={pocket_name} v={vel} spin=({spin.get('x', 0)},{spin.get('y', 0)})")
    lines.append(f"    白球→目标球距 |CT| = {fmt_m(ct)}")
    if pocket_name in POCKETS:
        p = POCKETS[pocket_name]
        line_v = unit(sub(p, tgt))                       # 进球线方向
        tp = norm(sub(p, tgt))
        ghost = (tgt[0] - 2 * R * line_v[0], tgt[1] - 2 * R * line_v[1])
        travel_v = unit(sub(ghost, cue))                 # 白球行进方向
        cut_travel = ang_between(travel_v, line_v)
        cut_apparent = ang_between(unit(sub(tgt, cue)), line_v)
        # 侧别：白球在进球线的哪一侧（叉积符号，Y 向下的左手系里 cross>0 = 屏幕逆时针）
        cross = line_v[0] * (cue[1] - tgt[1]) - line_v[1] * (cue[0] - tgt[0])
        side = "直线" if abs(cut_travel) < 2.0 else ("A侧(cross>0)" if cross > 0 else "B侧(cross<0)")
        # 入袋角：袋口→目标球方向（= −进球线）与袋口台内轴向的夹角；正入袋 = 0°
        pocket_angle = ang_between((-line_v[0], -line_v[1]), POCKET_AXIS[pocket_name])
        lines.append(f"    目标球→袋口距 = {fmt_m(tp)}   进球线方向=({line_v[0]:+.3f},{line_v[1]:+.3f})")
        lines.append(f"    行进线切角 = {cut_travel:.1f}°   表观切角 = {cut_apparent:.1f}°   侧别 = {side}")
        lines.append(f"    入袋角(相对袋口轴) = {pocket_angle:.1f}°")
    else:
        lines.append(f"    ⚠ 无法解析袋口: {pocket_name}")
    lines.append(f"    距库: cue最近库距 = {rail_dist(cue):.4f}   target最近库距 = {rail_dist(tgt):.4f}"
                 f"{'   [cue近库<0.06]' if rail_dist(cue) < 0.06 else ''}"
                 f"{'   [target近库<0.06]' if rail_dist(tgt) < 0.06 else ''}")
    obstacles = shot.get("obstacles")
    if obstacles:
        obs_str = " ".join(f"({o['x']:.4f},{o['y']:.4f})" for o in obstacles)
        lines.append(f"    障碍球 obstacles × {len(obstacles)}: {obs_str}")
    return lines


def summarize_board(path):
    """DrillBoards 序列文件（PositionPlaySequence）摘要：逐杆 before 坐标 + 几何量 + 母球 after 落点。"""
    seq = json.loads(path.read_text(encoding="utf-8"))
    steps = seq.get("steps", [])
    lines = [f"    · board「{seq.get('name', path.stem)}」 steps={len(steps)} "
             f"initial 球数={len(seq.get('initial', {}).get('onTable', {}))}"]
    for i, st in enumerate(steps, 1):
        shot = st.get("shot", {})
        before = st.get("before", {}).get("onTable", {})
        after = st.get("after", {}).get("onTable", {})
        cue_b = before.get("cueBall")
        tkey = shot.get("targetKey")
        tgt_b = before.get(tkey) if tkey else None
        pocket_name = shot.get("pocket")
        cue_a = after.get("cueBall")
        seg = (f"      step{i}: target={tkey} pocket={pocket_name} v={shot.get('velocity'):.2f} "
               f"spin=({shot.get('spinX', 0):.2f},{shot.get('spinY', 0):.2f}) "
               f"potted={st.get('objectPocketed')}")
        if cue_b and tgt_b and pocket_name in POCKETS:
            cue = (cue_b["x"], cue_b["y"])
            tgt = (tgt_b["x"], tgt_b["y"])
            p = POCKETS[pocket_name]
            line_v = unit(sub(p, tgt))
            ghost = (tgt[0] - 2 * R * line_v[0], tgt[1] - 2 * R * line_v[1])
            cut = ang_between(unit(sub(ghost, cue)), line_v)
            seg += f" 切角={cut:.1f}° |CT|={norm(sub(tgt, cue)):.3f}"
        if cue_a:
            seg += f" cue落点=({cue_a['x']:.3f},{cue_a['y']:.3f})"
        lines.append(seg)
    return lines


def audit_drill(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    out = []
    out.append("=" * 78)
    out.append(f"[{data['id']}] {data.get('nameZh', '?')} / {data.get('nameEn', '?')}")
    out.append(f"  category={data.get('category')} subcategory={data.get('subcategory')} "
               f"level={data.get('level')} difficulty={data.get('difficulty')} premium={data.get('isPremium')}")
    out.append(f"  standardCriteria: {data.get('standardCriteria')}")
    sets = data.get("sets", {})
    out.append(f"  sets: {sets.get('defaultSets')}×{sets.get('defaultBallsPerSet')}")
    out.append(f"  description: {data.get('description', '')}")
    anim = data.get("animation", {})
    out.append(f"  animation.source: {anim.get('source', '(未标注/手画)')}   "
               f"tutorial: {'formations' if 'formations' in data.get('tutorial', {}) else ('sections' if data.get('tutorial') else '无')}")
    boards = sorted(BOARDS.glob(f"{data['id']}[-_]*.json")) if BOARDS.exists() else []
    if boards:
        names = [b.stem.split("-", 1)[-1] for b in boards]
        out.append(f"  DrillBoards 已有球形 × {len(boards)}: {'; '.join(names)}")
        for b in boards:
            out.extend(summarize_board(b))
    else:
        out.append("  DrillBoards 已有球形 × 0")
    si = data.get("shotIntent")
    if si and si.get("shots"):
        shots = si["shots"]
        out.append(f"  shotIntent.shots 数量 = {len(shots)}")
        for i, s in enumerate(shots, 1):
            out.extend(analyze_shot(i, s))
    else:
        out.append("  shotIntent: 无（仅 animation 手画或无球形）")
        cb = anim.get("cueBall", {}).get("start")
        tb = anim.get("targetBall", {}).get("start")
        if cb and tb:
            out.append(f"    animation.cueBall.start=({cb['x']},{cb['y']}) targetBall.start=({tb['x']},{tb['y']}) "
                       f"pocket={anim.get('pocket')}")
    return out


def main():
    cats = sys.argv[1:] or ["fundamentals", "accuracy", "cueAction", "separation"]
    index = json.loads((DRILLS / "index.json").read_text(encoding="utf-8"))
    by_cat = {c["category"]: c["drills"] for c in index["categories"]}
    shot_sig = {}  # (cue, target, pocket) -> [(id, v, spin)]
    for cat in cats:
        ids = by_cat[cat]
        print(f"\n{'#' * 78}\n# 分类 {cat}（{len(ids)} 条）\n{'#' * 78}")
        for drill_id in ids:
            path = DRILLS / cat / f"{drill_id}.json"
            for line in audit_drill(path):
                print(line)
            data = json.loads(path.read_text(encoding="utf-8"))
            for s in data.get("shotIntent", {}).get("shots", []):
                key = (s["cue"]["x"], s["cue"]["y"], s["target"]["x"], s["target"]["y"], s.get("pocket"))
                spin = s.get("spin", {})
                shot_sig.setdefault(key, []).append(
                    f"{drill_id}(v={s.get('velocity')},spin=({spin.get('x', 0)},{spin.get('y', 0)}))")
    print(f"\n{'#' * 78}\n# 跨条目坐标级重复检测（cue/target/pocket 全同）\n{'#' * 78}")
    dups = {k: v for k, v in shot_sig.items() if len(v) > 1}
    if dups:
        for key, members in sorted(dups.items(), key=lambda kv: kv[1][0]):
            print(f"  cue=({key[0]},{key[1]}) target=({key[2]},{key[3]}) pocket={key[4]}:")
            for m in members:
                print(f"    - {m}")
    else:
        print("  无重复")
    print(f"\n共审计 {sum(len(by_cat[c]) for c in cats)} 条 drill。")


def _selftest():
    """金标准回归（geometry 技能强制）：已知答案样例。"""
    # 1) 正对直球：cue(0.5,0.25) target(0.5,0.43) bottomCenter → 两切角均 0
    p = POCKETS["bottomCenter"]
    tgt = (0.5, 0.43)
    cue = (0.5, 0.25)
    line_v = unit(sub(p, tgt))
    ghost = (tgt[0] - 2 * R * line_v[0], tgt[1] - 2 * R * line_v[1])
    assert abs(ang_between(unit(sub(ghost, cue)), line_v)) < 1e-9
    assert abs(ang_between(unit(sub(tgt, cue)), line_v)) < 1e-9
    assert abs(ghost[1] - (tgt[1] - 2 * R)) < 1e-12  # ghost 沿进球线反向退 2r
    # 2) B2 A5 回归：θ=45° 右切 cue=(0.6980,0.1863) target=(0.5,0.4068) bottomCenter
    tgt = (0.5, 0.4068)
    cue = (0.6980, 0.1863)
    line_v = unit(sub(p, tgt))
    ghost = (tgt[0] - 2 * R * line_v[0], tgt[1] - 2 * R * line_v[1])
    ct = ang_between(unit(sub(ghost, cue)), line_v)
    ca = ang_between(unit(sub(tgt, cue)), line_v)
    assert abs(ct - 45.0) < 0.02, ct    # B2 输出 45.0000°
    assert abs(ca - 41.9224) < 0.01, ca  # B2 输出 41.9224°
    # 3) 中袋正入袋：进球线 (0,+1) 指向 bottomCenter，入袋角应为 0
    assert abs(ang_between((0.0, 1.0), (0.0, -1.0)) - 180.0) < 1e-9  # 轴向定义自检
    assert abs(ang_between((0.0, 1.0), tuple(-a for a in POCKET_AXIS["bottomCenter"]))) < 1e-9


if __name__ == "__main__":
    _selftest()
    main()
