#!/usr/bin/env python3
"""v31 W3a 批内复验（只读）：6 份专项官方计划的 dose 格式 / 预算 / 主题对齐。

**独立于生成脚本**：只读 `Resources/Plans/plan_*.json`、`Resources/Drills/`、
`Drills/index.json` 与 `content/position_play/sequences/`，不 import 生成器的任何设计数据。

检查项：
- V1（格式切净）：每条 `PlanDrillRef` 有 `dose`，且**无残留** `sets` / `ballsPerSet`；
- V2（drillId 存在）：每条目 `drillId` ∈ `Drills/index.json`；
- V3（dose 可解析）：`roundsPerFormation` 与 `formations` 恰好二选一、轮数 ≥1；
  用 `roundsPerFormation` 的 drill 若有 `perFormation` 则逐球形展开，否则回落汇总兜底
  （口径同 `TrainingDoseResolver.resolve`）；
- V4（token 外键）：`dose.formations[].token` ∈ 该 drill 的 `perFormation` token 集合，
  且 ∈ 该 drill 的序列 token 集合（契约 §6.6 推论 2 / I11）；
- V5（预算）：每 session 派生总球数 B，估时区间 [B×25s, B×30s] 的**两端**都要落在
  `minutesPerSession` 的 ±15% 内（等价 B ∈ [2.04M, 2.30M]）；逐 session 列出；
- V6（主题周对齐）：`focused` 阶段每个动作的主分类 == 该计划专项分类，或其
  `secondaryCategories` 含该分类（契约 §3.3：副分类可参与主题归属，统计仍只记主分类）；
- V7（结构）：`weeks` 数 == `durationWeeks`、每周 sessions 数 == `sessionsPerWeek`、
  阶段时长合计 == `minutesPerSession`。

退出码非 0 表示有 FAIL。
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
PLANS_DIR = REPO / "QiuJi" / "Resources" / "Plans"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"

BATCH = [
    "plan_accuracy", "plan_cueball", "plan_english",
    "plan_force", "plan_separation", "plan_positioning",
]

# 每份专项计划的「专项分类」——focused 阶段动作须以它为主分类或副分类。
PLAN_SPECIALTY = {
    "plan_accuracy": "accuracy",
    "plan_cueball": "cueAction",
    "plan_english": "cueAction",      # c076–c078 主分类 accuracy，副分类 cueAction
    "plan_force": "forceControl",
    "plan_separation": "separation",
    "plan_positioning": "positioning",
}

SEC_LOW, SEC_HIGH, TOLERANCE = 25, 30, 0.15


def load_drills() -> dict[str, dict]:
    return {
        d["id"]: d
        for d in (json.loads(p.read_text(encoding="utf-8"))
                  for p in sorted(DRILLS_DIR.glob("*/*.json")))
    }


def load_index_ids() -> set[str]:
    data = json.loads((DRILLS_DIR / "index.json").read_text(encoding="utf-8"))
    return {d for g in data["categories"] for d in g["drills"]}


def sequence_tokens() -> dict[str, set[str]]:
    tokens: dict[str, set[str]] = defaultdict(set)
    for path in sorted(SEQ_DIR.glob("*.json")):
        name = path.name
        if "__" not in name:
            continue
        drill_id, rest = name.split("__", 1)
        tokens[drill_id].add(rest.split("-", 1)[0])
    return tokens


def resolve_balls(drill: dict, dose: dict, fails: list[str], where: str) -> int:
    """按 `TrainingDoseResolver.resolve` 的语义算派生球数。"""
    per = drill["sets"].get("perFormation")
    uniform = dose.get("roundsPerFormation")
    listed = dose.get("formations")

    if (uniform is None) == (listed is None):
        fails.append(f"V3 {where}: roundsPerFormation / formations 必须恰好二选一")
        return 0

    if listed is not None:
        if not listed:
            fails.append(f"V3 {where}: formations 为空数组")
            return 0
        if per is None:
            fails.append(f"V3 {where}: drill 无 perFormation，不能按球形引用")
            return 0
        balls_by_token = {f["token"]: f["ballsPerRound"] for f in per}
        total = 0
        for item in listed:
            if item["rounds"] < 1:
                fails.append(f"V3 {where}/{item['token']}: rounds < 1")
            if item["token"] not in balls_by_token:
                fails.append(
                    f"V4 {where}: token `{item['token']}` 不在 perFormation "
                    f"{sorted(balls_by_token)} 中"
                )
                continue
            total += balls_by_token[item["token"]] * item["rounds"]
        return total

    if uniform < 1:
        fails.append(f"V3 {where}: roundsPerFormation < 1")
        return 0
    if per:
        return uniform * sum(f["ballsPerRound"] for f in per)
    return uniform * drill["sets"]["defaultBallsPerSet"]


def main() -> None:
    drills = load_drills()
    index_ids = load_index_ids()
    seq_tokens = sequence_tokens()

    fails: list[str] = []
    checked = {f"V{i}": 0 for i in range(1, 8)}
    referenced: set[str] = set()
    session_rows: list[tuple] = []

    for plan_id in BATCH:
        plan = json.loads((PLANS_DIR / f"{plan_id}.json").read_text(encoding="utf-8"))
        minutes = plan["minutesPerSession"]
        low = (1 - TOLERANCE) * minutes * 60 / SEC_LOW
        high = (1 + TOLERANCE) * minutes * 60 / SEC_HIGH
        specialty = PLAN_SPECIALTY[plan_id]

        checked["V7"] += 1
        if len(plan["weeks"]) != plan["durationWeeks"]:
            fails.append(f"V7 {plan_id}: weeks {len(plan['weeks'])} != durationWeeks")

        for week in plan["weeks"]:
            checked["V7"] += 1
            if len(week["sessions"]) != plan["sessionsPerWeek"]:
                fails.append(
                    f"V7 {plan_id} W{week['weekNumber']}: sessions "
                    f"{len(week['sessions'])} != sessionsPerWeek"
                )
            for session in week["sessions"]:
                where_s = f"{plan_id} W{week['weekNumber']} D{session['dayNumber']}"
                checked["V7"] += 1
                if sum(p["durationMinutes"] for p in session["phases"]) != minutes:
                    fails.append(f"V7 {where_s}: 阶段时长合计 != minutesPerSession")

                total_balls = 0
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        drill_id = ref["drillId"]
                        where = f"{where_s} {phase['type']} {drill_id}"
                        referenced.add(drill_id)

                        checked["V1"] += 1
                        if "sets" in ref or "ballsPerSet" in ref:
                            fails.append(f"V1 {where}: 仍残留旧格式 sets/ballsPerSet")
                        if "dose" not in ref:
                            fails.append(f"V1 {where}: 缺 dose")
                            continue

                        checked["V2"] += 1
                        if drill_id not in index_ids:
                            fails.append(f"V2 {where}: drillId 不在 index.json")
                            continue

                        checked["V3"] += 1
                        drill = drills[drill_id]
                        total_balls += resolve_balls(drill, ref["dose"], fails, where)

                        for item in ref["dose"].get("formations") or []:
                            checked["V4"] += 1
                            known = seq_tokens.get(drill_id, set())
                            if known and item["token"] not in known:
                                fails.append(
                                    f"V4 {where}: token `{item['token']}` 不在序列 token "
                                    f"集合 {sorted(known)}"
                                )

                        if phase["type"] == "focused":
                            checked["V6"] += 1
                            cats = {drill["category"], *(drill.get("secondaryCategories") or [])}
                            if specialty not in cats:
                                fails.append(
                                    f"V6 {where}: 主/副分类 {sorted(cats)} 未命中"
                                    f"专项分类 `{specialty}`（周主题「{week['theme']}」）"
                                )

                checked["V5"] += 1
                est_low = total_balls * SEC_LOW / 60
                est_high = total_balls * SEC_HIGH / 60
                dev_low = (est_low - minutes) / minutes
                dev_high = (est_high - minutes) / minutes
                ok = low <= total_balls <= high
                if not ok:
                    fails.append(
                        f"V5 {where_s}: 派生球数 {total_balls} 超预算带 "
                        f"[{low:.0f},{high:.0f}]（{minutes}′±15%）"
                    )
                session_rows.append(
                    (where_s, total_balls, minutes, est_low, est_high, dev_low, dev_high, ok)
                )

    print("=== V5 逐 session 预算（球数 × 25–30 秒/杆 vs minutesPerSession ±15%）===")
    for where_s, balls, minutes, e_low, e_high, d_low, d_high, ok in session_rows:
        print(f"{'OK ' if ok else '⛔ '} {where_s:28} 球数 {balls:4} → "
              f"{e_low:5.1f}′~{e_high:5.1f}′ vs {minutes}′ "
              f"(偏差 {d_low:+.1%} ~ {d_high:+.1%})")

    print("\n=== V6 focused 主题周对齐（按专项分类）===")
    for plan_id in BATCH:
        plan = json.loads((PLANS_DIR / f"{plan_id}.json").read_text(encoding="utf-8"))
        for week in plan["weeks"]:
            ids = sorted({
                r["drillId"]
                for s in week["sessions"] for p in s["phases"]
                if p["type"] == "focused" for r in p["drills"]
            })
            tags = []
            for d in ids:
                cat = drills[d]["category"]
                sec = drills[d].get("secondaryCategories") or []
                hit = "主" if cat == PLAN_SPECIALTY[plan_id] else (
                    "副" if PLAN_SPECIALTY[plan_id] in sec else "⛔")
                tags.append(f"{d.split('_')[1]}({hit}·{cat})")
            print(f"{plan_id:18} W{week['weekNumber']} 「{week['theme']}」: {' '.join(tags)}")

    print("\n=== 引用覆盖 ===")
    all_refs: dict[str, set[str]] = defaultdict(set)
    for path in sorted(PLANS_DIR.glob("plan_*.json")):
        plan = json.loads(path.read_text(encoding="utf-8"))
        for w in plan["weeks"]:
            for s in w["sessions"]:
                for p in s["phases"]:
                    for r in p["drills"]:
                        all_refs[r["drillId"]].add(plan["id"])
    unreferenced = sorted(index_ids - set(all_refs))
    print(f"本批 6 份计划引用 drill {len(referenced)} 条")
    print(f"全库 {len(index_ids)} 条中，10 份官方计划合计未引用 {len(unreferenced)} 条：")
    print("  " + ", ".join(d.replace("drill_", "") for d in unreferenced))

    print("\n--- 检查计数 ---")
    for name, count in checked.items():
        print(f"{name}: {count} 次")
    print(f"\nFAIL {len(fails)}")
    for f in fails:
        print("  ⛔ " + f)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
