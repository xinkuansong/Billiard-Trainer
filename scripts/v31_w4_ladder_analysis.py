#!/usr/bin/env python3
"""v31 W4 批内分析（只读）：阶梯型 `repetition` 球形的 `ballsPerRound` 口径张力取值。

背景：契约 §5.6.2 给 `repetition` 型的取值带是 10–15，但部分球形的序列本身就是一趟
「阶梯」（逐档变化的同一击球），档数 > 15 时一轮 10–15 球走不完一趟阶梯。
本脚本**从真源脚本取值**（档数 = 序列文件 `steps` 长度，与 I6b 的实测杆数同一口径），
列出全库所有 `repetition` 型球形的 (ballsPerRound, 档数) 对照，并复算若把
「档数 > 15 的球形」的 `ballsPerRound` 提到档数，对 drill 总量护栏与 10 份官方计划
逐 session 派生球数 / 时长预算的影响面。

用法：python3 scripts/v31_w4_ladder_analysis.py
"""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
PLANS_DIR = REPO / "QiuJi" / "Resources" / "Plans"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"

SEC_LOW, SEC_HIGH, TOLERANCE = 25, 30, 0.15


def load_drills() -> dict[str, dict]:
    return {
        d["id"]: d
        for d in (json.loads(p.read_text(encoding="utf-8"))
                  for p in sorted(DRILLS_DIR.glob("*/*.json")))
    }


def shots_by_token() -> dict[str, dict[str, int]]:
    """{drillId: {token: 实测杆数}}，口径同 I6b（len(steps)）。"""
    out: dict[str, dict[str, int]] = defaultdict(dict)
    for path in sorted(SEQ_DIR.glob("drill_c*.json")):
        name = path.name
        if "__" in name:
            drill_id, rest = name.split("__", 1)
            token = rest.split("-", 1)[0]
        else:
            drill_id, token = name.split("-", 1)[0], ""
        steps = json.loads(path.read_text(encoding="utf-8")).get("steps", [])
        out[drill_id][token] = len(steps)
    return out


def resolve_balls(drill: dict, dose: dict, override: dict[tuple[str, str], int]) -> int:
    """按 `TrainingDoseResolver.resolve` 语义算派生球数；override 用于试算改后值。"""
    per = drill["sets"].get("perFormation")
    uniform = dose.get("roundsPerFormation")
    listed = dose.get("formations")

    def balls(token: str, value: int) -> int:
        return override.get((drill["id"], token), value)

    if listed:
        by_token = {f["token"]: balls(f["token"], f["ballsPerRound"]) for f in (per or [])}
        return sum(by_token.get(i["token"], 0) * i["rounds"] for i in listed)
    rounds = uniform if uniform is not None else 1
    if per:
        return rounds * sum(balls(f["token"], f["ballsPerRound"]) for f in per)
    return rounds * drill["sets"]["defaultBallsPerSet"]


def session_totals(drills: dict[str, dict], override: dict[tuple[str, str], int]):
    rows = []
    for path in sorted(PLANS_DIR.glob("plan_*.json")):
        plan = json.loads(path.read_text(encoding="utf-8"))
        minutes = plan["minutesPerSession"]
        low = (1 - TOLERANCE) * minutes * 60 / SEC_LOW
        high = (1 + TOLERANCE) * minutes * 60 / SEC_HIGH
        for week in plan["weeks"]:
            for session in week["sessions"]:
                total = 0
                touched = set()
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        drill = drills[ref["drillId"]]
                        total += resolve_balls(drill, ref.get("dose") or {}, override)
                        if any(k[0] == ref["drillId"] for k in override):
                            touched.add(ref["drillId"])
                rows.append((f"{plan['id']} W{week['weekNumber']}D{session['dayNumber']}",
                             total, minutes, low, high, sorted(touched)))
    return rows


def main() -> None:
    drills = load_drills()
    shots = shots_by_token()

    print("=== 全库 repetition 型球形：ballsPerRound vs 档数（= 序列实测杆数）===")
    ladder: list[tuple[str, str, int, int]] = []
    for drill_id, drill in sorted(drills.items()):
        for f in drill["sets"].get("perFormation") or []:
            if f["mode"] != "repetition":
                continue
            steps = shots.get(drill_id, {}).get(f["token"])
            flag = ""
            if steps is not None and steps > 15:
                flag = "  ← 档数 > 15，10–15 带走不完一趟"
                ladder.append((drill_id, f["token"], f["ballsPerRound"], steps))
            if steps is not None and (steps > 15 or f["ballsPerRound"] >= 14):
                print(f"{drill_id}/{f['token']:10} ballsPerRound={f['ballsPerRound']:3} "
                      f"档数={steps:3}{flag}")

    print(f"\n档数 > 15 的 repetition 球形：{len(ladder)} 个")
    for drill_id, token, bpr, steps in ladder:
        print(f"  {drill_id}/{token}: {bpr} → {steps}")

    override = {(d, t): s for d, t, _, s in ladder}

    print("\n=== 改后：受影响 drill 的总量护栏（§5.6.3 目标 40–60）===")
    for drill_id in sorted({d for d, _ in override}):
        per = drills[drill_id]["sets"]["perFormation"]
        before = sum(f["ballsPerRound"] * f["defaultRounds"] for f in per)
        after = sum(override.get((drill_id, f["token"]), f["ballsPerRound"]) * f["defaultRounds"]
                    for f in per)
        print(f"  {drill_id}: 总量 {before} → {after}  "
              f"({'带内' if 40 <= after <= 60 else '越界'})")

    print("\n=== 改后：10 份官方计划逐 session 预算影响（仅列涉及受影响 drill 的 session）===")
    before_rows = session_totals(drills, {})
    after_rows = session_totals(drills, override)
    changed = 0
    newly_out = 0
    for (name, b_total, minutes, low, high, _), (_, a_total, _, _, _, touched) in zip(
            before_rows, after_rows):
        if b_total == a_total:
            continue
        changed += 1
        b_ok = low <= b_total <= high
        a_ok = low <= a_total <= high
        if b_ok and not a_ok:
            newly_out += 1
        print(f"  {name:26} {b_total:4} → {a_total:4} 球  预算带 [{low:.0f},{high:.0f}]  "
              f"{'OK' if b_ok else '越界'} → {'OK' if a_ok else '越界'}"
              f"{'  ⛔ 由带内变越界' if b_ok and not a_ok else ''}  用到 {','.join(touched)}")
    print(f"\n受影响 session {changed} 个；由带内变越界 {newly_out} 个")


if __name__ == "__main__":
    main()
