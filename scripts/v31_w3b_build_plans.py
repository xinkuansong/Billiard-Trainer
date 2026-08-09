#!/usr/bin/env python3
"""v31 W3b：重写 4 份综合官方计划（beginner / intermediate / advanced / fullskill）。

做法与姊妹批 W3a（`v31_w3a_build_plans.py`）完全一致——设计里只写「目标球数」，
轮数与球数一律由 drill JSON 的 `sets.perFormation` 派生 + 预算求解，⛔ 不手写球数。
两处 W3b 特有的扩展：

1. **按局 / 按次条目的时间口径**（真源 §六 P3 已裁定量值，此处只解决「折算成时长」）。
   基准 25–30 秒/球（含摆球）。逐类核算：
   - **按局**（c065 Ghost 8 球/局、c067 9 球清台 9 球/局、c070 全台清台 8 球/局）：
     一局 = 摆一副球（约 60 秒）+ 逐球击打。普通 drill 每杆也要复位目标球（约 5–10 秒/杆），
     故「每球摊到的非击打开销」两者接近（8 球一副 ⇒ 60/8 = 7.5 秒/球）。
     实测算式：8×20 秒击打 + 60 秒摆球 = 220 秒 ⇒ **27.5 秒/球**，正落基准带中点。
     ⇒ **系数 1.0，无需折算**。
   - **按次**（c066 开球，10 次/轮）：一次 = 摆全副球（约 60 秒）+ 一杆开球（约 15 秒）≈ 75 秒，
     击打只占 1/5，摆球开销**无法摊薄**。⇒ 系数 75 / 27.5 ≈ **2.7**。
   实现：`UNIT_BALL_EQUIV` 给出「球当量」，预算求解要求**原始球数与球当量两条都落在带内**，
   即比 W3a 的严格解更紧，⛔ 不是放宽。

2. **逐周主题分类集合**：综合计划的周主题跨多个分类，W3a 的「一份计划一个专项分类」不适用。
   每周主题所属分类集合按该周 `theme` 文案逐周推导，写在复验脚本 `v31_w3b_verify_plans.py`
   的 `WEEK_CATEGORIES` 表（本脚本只负责让 focused 动作落在该集合里）。
"""

from __future__ import annotations

import itertools
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
PLANS_DIR = REPO / "QiuJi" / "Resources" / "Plans"

SEC_PER_BALL_LOW = 25
SEC_PER_BALL_HIGH = 30
SEC_PER_BALL_MID = 27.5
TOLERANCE = 0.15

# 「一个计量单位折算成几个普通球的时间成本」。默认 1.0；见模块文档说明 1。
UNIT_BALL_EQUIV = {
    "drill_c066": 75 / SEC_PER_BALL_MID,   # 开球：摆全副球 60 秒 + 开球 15 秒
}


# --- 设计输入的三种条目 -------------------------------------------------

def W(drill_id: str, rounds: int) -> dict:
    return {"id": drill_id, "rounds": rounds, "kind": "fixed"}


C = W


def A(drill_id: str, balls: int) -> dict:
    return {"id": drill_id, "balls": balls, "kind": "alloc"}


def F(drill_id: str, formations: dict[str, int]) -> dict:
    return {"id": drill_id, "formations": formations, "kind": "formations"}


# --- drill 剂量真源 -----------------------------------------------------

def load_drills() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for path in sorted(DRILLS_DIR.glob("*/*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        out[data["id"]] = data
    return out


DRILLS = load_drills()


def balls_per_round(drill_id: str) -> int:
    """一轮（roundsPerFormation=1）派生多少球：Σ 各球形 ballsPerRound；无球形回落汇总兜底。"""
    sets = DRILLS[drill_id]["sets"]
    per = sets.get("perFormation")
    if per:
        return sum(f["ballsPerRound"] for f in per)
    return sets["defaultBallsPerSet"]


def formation_balls(drill_id: str, token: str) -> int:
    for f in DRILLS[drill_id]["sets"]["perFormation"]:
        if f["token"] == token:
            return f["ballsPerRound"]
    raise KeyError(f"{drill_id} 无球形 {token}")


def entry_balls(entry: dict, rounds: int | None = None) -> int:
    if entry["kind"] == "formations":
        return sum(formation_balls(entry["id"], t) * r
                   for t, r in entry["formations"].items())
    return balls_per_round(entry["id"]) * (rounds if rounds is not None else entry["rounds"])


def entry_equiv(entry: dict, rounds: int | None = None) -> float:
    return entry_balls(entry, rounds) * UNIT_BALL_EQUIV.get(entry["id"], 1.0)


def design_rounds(entry: dict) -> int:
    if entry["kind"] == "alloc":
        return max(1, round(entry["balls"] / balls_per_round(entry["id"])))
    return entry.get("rounds", 1)


# --- 预算求解 -----------------------------------------------------------

def budget_band(minutes: int) -> tuple[float, float]:
    """派生球数下界 / 上界：25 s/球 与 30 s/球 两端估算都要落在 ±15% 内。"""
    low = (1 - TOLERANCE) * minutes * 60 / SEC_PER_BALL_LOW
    high = (1 + TOLERANCE) * minutes * 60 / SEC_PER_BALL_HIGH
    return low, high


def solve_session(session: dict, minutes: int) -> list[tuple[dict, int]]:
    """在设计轮数邻域内搜索使总量最贴近预算目标的组合（focused ±3、热身/综合固定）。"""
    entries: list[dict] = [session["warmup"]] + session["focused"] + [session["combined"]]
    # 热身 / 综合的轮数是设计意图（固定的开场与收尾），预算差额一律由专项段吸收。
    weights: list[int] = [2] + [1] * len(session["focused"]) + [2]
    spans: list[int] = [0] + [3] * len(session["focused"]) + [0]

    candidates: list[list[int]] = []
    for entry, span in zip(entries, spans):
        base = design_rounds(entry)
        if entry["kind"] == "formations":
            candidates.append([base])
        else:
            candidates.append([r for r in range(base - span, base + span + 1) if r >= 1])

    target = minutes * 60 / SEC_PER_BALL_MID
    low, high = budget_band(minutes)

    best = None
    for combo in itertools.product(*candidates):
        total = sum(entry_balls(e, r) for e, r in zip(entries, combo))
        equiv = sum(entry_equiv(e, r) for e, r in zip(entries, combo))
        # 原始球数与球当量两条都要落在带内（按次条目使两者不等，见模块文档）。
        in_band = low <= total <= high and low <= equiv <= high
        drift = sum(w * abs(r - design_rounds(e))
                    for e, r, w in zip(entries, combo, weights))
        # 先要落进预算带，其次尽量贴近设计轮数，最后才比谁更靠近目标点。
        key = (0 if in_band else 1, drift, abs(equiv - target))
        if best is None or key < best[0]:
            best = (key, list(combo), total)
    assert best is not None
    return list(zip(entries, best[1]))


# --- JSON 输出 ----------------------------------------------------------

def dose_json(entry: dict, rounds: int) -> str:
    if entry["kind"] == "formations":
        inner = ", ".join(
            '{"token": "%s", "rounds": %d}' % (t, r) for t, r in entry["formations"].items()
        )
        dose = '{"formations": [%s]}' % inner
    else:
        dose = '{"roundsPerFormation": %d}' % rounds
    return '{"drillId": "%s", "dose": %s}' % (entry["id"], dose)


def render_plan(spec: dict) -> tuple[str, list[dict]]:
    meta = spec["meta"]
    minutes = meta["minutesPerSession"]
    phases = spec["phaseMinutes"]
    report: list[dict] = []

    lines = ["{"]
    for key in ("id", "nameZh", "nameEn", "targetLevel"):
        lines.append('  "%s": %s,' % (key, json.dumps(meta[key], ensure_ascii=False)))
    for key in ("durationWeeks", "sessionsPerWeek", "minutesPerSession"):
        lines.append('  "%s": %d,' % (key, meta[key]))
    lines.append('  "isPremium": %s,' % ("true" if meta["isPremium"] else "false"))
    lines.append('  "description": %s,' % json.dumps(meta["description"], ensure_ascii=False))
    lines.append('  "weeks": [')

    week_chunks = []
    for week in spec["weeks"]:
        wlines = ["    {"]
        wlines.append('      "weekNumber": %d,' % week["n"])
        wlines.append('      "theme": %s,' % json.dumps(week["theme"], ensure_ascii=False))
        wlines.append('      "sessions": [')
        session_chunks = []
        for day, session in enumerate(week["sessions"], start=1):
            resolved = solve_session(session, minutes)
            by_entry = {id(e): r for e, r in resolved}
            total = sum(entry_balls(e, r) for e, r in resolved)
            equiv = sum(entry_equiv(e, r) for e, r in resolved)
            report.append({
                "plan": meta["id"], "week": week["n"], "day": day,
                "balls": total, "equiv": equiv, "minutes": minutes,
                "entries": [
                    (e["id"],
                     sum(e["formations"].values()) if e["kind"] == "formations" else r,
                     entry_balls(e, r))
                    for e, r in resolved
                ],
            })

            slines = ["        {"]
            slines.append('          "dayNumber": %d,' % day)
            slines.append('          "phases": [')
            groups = [
                ("warmup", phases["warmup"], [session["warmup"]]),
                ("focused", phases["focused"], session["focused"]),
                ("combined", phases["combined"], [session["combined"]]),
                ("review", phases["review"], []),
            ]
            plines = []
            for ptype, pmin, pentries in groups:
                drills = ", ".join(dose_json(e, by_entry[id(e)]) for e in pentries)
                plines.append(
                    '            {"type": "%s", "durationMinutes": %d, "drills": [%s]}'
                    % (ptype, pmin, drills)
                )
            slines.append(",\n".join(plines))
            slines.append("          ]")
            slines.append("        }")
            session_chunks.append("\n".join(slines))
        wlines.append(",\n".join(session_chunks))
        wlines.append("      ]")
        wlines.append("    }")
        week_chunks.append("\n".join(wlines))

    lines.append(",\n".join(week_chunks))
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n", report


# =======================================================================
# 计划设计
# =======================================================================
#
# 逐周主题分类集合（focused 动作须命中；表的权威副本在复验脚本）：
#   beginner     W1 fundamentals | W2 fundamentals+accuracy | W3 fundamentals+cueAction+accuracy
#                W4 accuracy | W5 cueAction | W6 cueAction | W7 positioning
#                W8 fundamentals+accuracy+cueAction+positioning（复习前 7 周主题）
#   intermediate W1 accuracy+cueAction | W2 accuracy | W3 positioning | W4 cueAction
#                W5 accuracy | W6 positioning | W7 combined+positioning
#                W8 combined+specialShots | W9 separation+forceControl | W10 combined
#   advanced     W1 cueAction | W2 cueAction+positioning | W3 positioning | W4 specialShots
#                W5 cueAction | W6 combined+specialShots | W7 combined | W8 combined
#   fullskill    W1 accuracy | W2 cueAction | W3 positioning | W4 combined+specialShots
#                W5 separation | W6 forceControl | W7 specialShots | W8 specialShots
#                W9 accuracy+positioning | W10 cueAction | W11 separation+forceControl
#                W12 combined

BEGINNER = {
    "meta": {
        "id": "plan_beginner", "nameZh": "新手入门计划", "nameEn": "Beginner Fundamentals",
        "targetLevel": "L0→L1", "durationWeeks": 8, "sessionsPerWeek": 3,
        "minutesPerSession": 60, "isPremium": False,
        "description": "从零开始，建立正确的姿势、握杆、出杆习惯，逐步过渡到基础准度、基础杆法与走位意识。"
                       "8 周 24 次训练，每次约 60 分钟。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 35, "combined": 10, "review": 5},
    "weeks": [
        {"n": 1, "theme": "姿势与握杆基础", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c007", 45), A("drill_c008", 45)],
             "combined": C("drill_c001", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c008", 45), A("drill_c023", 45)],
             "combined": C("drill_c011", 1)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c007", 60), A("drill_c009", 30)],
             "combined": C("drill_c001", 2)},
        ]},
        {"n": 2, "theme": "出杆稳定性与直线球", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c010", 45), A("drill_c001", 40)],
             "combined": C("drill_c011", 1)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c009", 45), A("drill_c012", 40)],
             "combined": C("drill_c002", 1)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c022", 30), A("drill_c001", 40), A("drill_c011", 20)],
             "combined": C("drill_c012", 1)},
        ]},
        {"n": 3, "theme": "中杆定杆与中袋直线", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c010", 45), A("drill_c012", 40)],
             "combined": C("drill_c002", 1)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c014", 40), A("drill_c012", 40)],
             "combined": C("drill_c001", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c014", 40), A("drill_c011", 30), A("drill_c001", 15)],
             "combined": C("drill_c012", 1)},
        ]},
        {"n": 4, "theme": "角度入门与底袋小角度", "sessions": [
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c002", 40), A("drill_c013", 40)],
             "combined": C("drill_c012", 1)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c013", 60), A("drill_c002", 30)],
             "combined": C("drill_c011", 1)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c002", 40), A("drill_c012", 30), A("drill_c001", 15)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 5, "theme": "基础杆法引入 — 高杆", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c003", 60), A("drill_c014", 30)],
             "combined": C("drill_c002", 1)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c003", 40), A("drill_c015", 40)],
             "combined": C("drill_c012", 1)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c015", 40), A("drill_c014", 30), A("drill_c003", 20)],
             "combined": C("drill_c011", 1)},
        ]},
        {"n": 6, "theme": "基础杆法引入 — 低杆", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c004", 60), A("drill_c014", 30)],
             "combined": C("drill_c002", 1)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c004", 40), A("drill_c017", 40)],
             "combined": C("drill_c012", 1)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c017", 40), A("drill_c016", 30), A("drill_c004", 20)],
             "combined": C("drill_c011", 1)},
        ]},
        {"n": 7, "theme": "走位意识入门", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c034", 50), A("drill_c037", 40)],
             "combined": C("drill_c002", 1)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c034", 40), A("drill_c005", 40)],
             "combined": C("drill_c012", 1)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c005", 40), A("drill_c037", 30), A("drill_c034", 20)],
             "combined": C("drill_c011", 1)},
        ]},
        {"n": 8, "theme": "综合巩固与检验", "sessions": [
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c001", 40), A("drill_c002", 40)],
             "combined": C("drill_c005", 1)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c003", 40), A("drill_c004", 40)],
             "combined": C("drill_c013", 1)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c005", 40), A("drill_c013", 40), A("drill_c001", 10)],
             "combined": C("drill_c011", 1)},
        ]},
    ],
}

INTERMEDIATE = {
    "meta": {
        "id": "plan_intermediate", "nameZh": "中级综合突破", "nameEn": "Intermediate Comprehensive",
        "targetLevel": "L2", "durationWeeks": 10, "sessionsPerWeek": 4,
        "minutesPerSession": 90, "isPremium": True,
        "description": "准度、杆法、走位、分离角、力度与综合球形全面提升。10 周系统训练，每周 4 练、"
                       "每次约 90 分钟，适合已有基础的进阶玩家。系统练加塞请选「加塞专项」。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 50, "combined": 25, "review": 5},
    "weeks": [
        {"n": 1, "theme": "准度、定杆与加塞入门", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c001", 60), A("drill_c012", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c014", 60), A("drill_c013", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c073", 80), A("drill_c076", 56)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [F("drill_c075", {"manual01": 3, "manual02": 2}),
                         A("drill_c012", 60)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 2, "theme": "角度球攻防", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c002", 70), A("drill_c013", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c032", 70), A("drill_c013", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c053", 69), A("drill_c002", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c052", 60), A("drill_c032", 40), A("drill_c013", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 3, "theme": "走位专项强化", "sessions": [
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c005", 70), A("drill_c034", 60)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c035", 70), A("drill_c005", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c036", 70), A("drill_c037", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c080", 50), A("drill_c005", 40), A("drill_c035", 40)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 4, "theme": "杆法组合训练", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c003", 60), A("drill_c004", 60)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c015", 60), A("drill_c017", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c016", 60), A("drill_c018", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c003", 40), A("drill_c004", 40), A("drill_c016", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 5, "theme": "准度提升 — 远台与中袋", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c033", 70), A("drill_c012", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c052", 70), A("drill_c053", 46)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c062", 40), A("drill_c033", 50), A("drill_c012", 40)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c053", 69), A("drill_c033", 60)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 6, "theme": "走位连打", "sessions": [
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c039", 64), A("drill_c079", 48)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c081", 48), A("drill_c038", 60)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c041", 60), A("drill_c005", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c039", 40), A("drill_c081", 32), A("drill_c079", 32)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 7, "theme": "综合球形 — 多球连打", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c064", 45), A("drill_c068", 50), A("drill_c042", 45)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c069", 60), A("drill_c064", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c068", 50), A("drill_c082", 48), A("drill_c079", 32)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c042", 45), A("drill_c064", 45), A("drill_c068", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 8, "theme": "实战模拟 — 连打与攻防", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c060", 60), A("drill_c058", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c054", 60), A("drill_c055", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c064", 45), A("drill_c060", 50), A("drill_c055", 40)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c058", 60), A("drill_c068", 50)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 9, "theme": "薄弱环节补强 — 分离角与力度", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c024", 60), A("drill_c084", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c025", 60), A("drill_c044", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c045", 60), A("drill_c049", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c046", 50), A("drill_c084", 40), A("drill_c024", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 10, "theme": "综合检验 — 全面测试", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c064", 45), A("drill_c069", 60), A("drill_c068", 30)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c069", 80), A("drill_c064", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c068", 60), A("drill_c064", 45), A("drill_c069", 40)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c069", 60), A("drill_c068", 50)],
             "combined": C("drill_c066", 1)},
        ]},
    ],
}

ADVANCED = {
    "meta": {
        "id": "plan_advanced", "nameZh": "加塞与多库专项", "nameEn": "Advanced: English & Multi-Cushion",
        "targetLevel": "L3", "durationWeeks": 8, "sessionsPerWeek": 5,
        "minutesPerSession": 100, "isPremium": True,
        "description": "加塞精准、多库走位、防守解球与高级球形。面向已有中级水平的玩家，"
                       "每周 5 练、每次约 100 分钟；后段以清台与 Ghost Game 做周期末检验。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 55, "combined": 25, "review": 10},
    "weeks": [
        {"n": 1, "theme": "加塞基础 — 左右塞入门", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c073", 80), A("drill_c018", 80)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c074", 80), A("drill_c018", 80)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [F("drill_c075", {"manual01": 4, "manual02": 2}),
                         A("drill_c073", 60), A("drill_c018", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c021", 72), A("drill_c020", 75)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c073", 60), A("drill_c074", 60), A("drill_c018", 40)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 2, "theme": "加塞走位 — 吃库后转向", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c018", 80), A("drill_c035", 80)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c020", 75), A("drill_c036", 80)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c021", 72), A("drill_c040", 80)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c018", 60), A("drill_c035", 50), A("drill_c036", 50)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c020", 60), A("drill_c041", 60), A("drill_c018", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 3, "theme": "多库走位入门", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c038", 84), A("drill_c040", 80)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c041", 84), A("drill_c038", 72)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c040", 80), A("drill_c080", 70)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c082", 60), A("drill_c038", 60), A("drill_c040", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c041", 60), A("drill_c080", 50), A("drill_c005", 50)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 4, "theme": "防守策略 — 安全球", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c060", 80), A("drill_c061", 80)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c060", 80), A("drill_c058", 80)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c061", 80), A("drill_c059", 70)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c058", 60), A("drill_c060", 50), A("drill_c061", 50)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c059", 60), A("drill_c061", 50), A("drill_c060", 50)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 5, "theme": "加塞精度提升", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c077", 80), A("drill_c074", 80)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c078", 75), A("drill_c077", 80)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c076", 84), A("drill_c077", 60)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [F("drill_c075", {"manual01": 2, "manual02": 3, "manual03": 3}),
                         A("drill_c078", 60), A("drill_c077", 30)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c074", 60), A("drill_c076", 56), A("drill_c077", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 6, "theme": "高级球形 — 连打攻防", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c064", 60), A("drill_c069", 60), A("drill_c068", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c071", 75), A("drill_c064", 45), A("drill_c068", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [F("drill_c056", {"Snipaste_2026_06_19_17_32_46": 3,
                                          "Snipaste_2026_06_19_17_35_51": 3}),
                         A("drill_c054", 60), A("drill_c055", 40)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [F("drill_c057", {"Snipaste_2026_06_19_17_43_31": 3,
                                          "Snipaste_2026_06_19_17_45_48": 2,
                                          "Snipaste_2026_06_19_17_48_56": 2}),
                         A("drill_c055", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c069", 60), A("drill_c071", 50), A("drill_c064", 45)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 7, "theme": "比赛模拟", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c067", 81), A("drill_c064", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c065", 80), A("drill_c068", 60)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c070", 80), A("drill_c067", 63)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c065", 64), A("drill_c067", 54), A("drill_c064", 45)],
             "combined": C("drill_c066", 1)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c070", 64), A("drill_c065", 56), A("drill_c068", 40)],
             "combined": C("drill_c011", 3)},
        ]},
        {"n": 8, "theme": "综合检验 — 全面挑战", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c070", 80), A("drill_c069", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c067", 81), A("drill_c071", 50)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c065", 80), A("drill_c071", 50)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c070", 64), A("drill_c069", 60), A("drill_c064", 45)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c067", 63), A("drill_c065", 56), A("drill_c068", 40)],
             "combined": C("drill_c011", 3)},
        ]},
    ],
}

FULLSKILL = {
    "meta": {
        "id": "plan_fullskill", "nameZh": "全能综合训练", "nameEn": "Complete Skills Training",
        "targetLevel": "L3→L4", "durationWeeks": 12, "sessionsPerWeek": 5,
        "minutesPerSession": 110, "isPremium": True,
        "description": "持续性全面训练计划，12 周覆盖全部八个分类：准度、杆法、走位、综合球形、"
                       "分离角、力度控制、特殊球与防守解球，末周以清台与 Ghost Game 检验。"
                       "适合长期使用，每周 5 练、每次约 110 分钟。",
    },
    "phaseMinutes": {"warmup": 15, "focused": 55, "combined": 30, "review": 10},
    "weeks": [
        {"n": 1, "theme": "准度基石 — 各角度巩固", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c001", 60), A("drill_c002", 50), A("drill_c013", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c032", 70), A("drill_c013", 80)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c033", 70), A("drill_c052", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c053", 69), A("drill_c012", 50), A("drill_c011", 40)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c063", 50), A("drill_c052", 60), A("drill_c032", 50)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 2, "theme": "杆法深化 — 精准控制", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c003", 80), A("drill_c015", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c004", 80), A("drill_c017", 70)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c016", 70), A("drill_c014", 60), A("drill_c003", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c073", 80), A("drill_c074", 60), A("drill_c016", 30)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c015", 60), A("drill_c017", 60), A("drill_c004", 60)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 3, "theme": "走位体系 — 连续多球", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c039", 64), A("drill_c005", 50), A("drill_c034", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c079", 48), A("drill_c081", 48), A("drill_c080", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c035", 70), A("drill_c036", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c037", 60), A("drill_c039", 48), A("drill_c005", 50)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c080", 60), A("drill_c079", 40), A("drill_c081", 40),
                         A("drill_c034", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 4, "theme": "综合攻防训练", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c064", 60), A("drill_c069", 60), A("drill_c068", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c054", 70), A("drill_c055", 50), A("drill_c064", 45)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c058", 80), A("drill_c068", 50), A("drill_c064", 30)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c069", 60), A("drill_c071", 50), A("drill_c055", 40)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c064", 45), A("drill_c068", 50), A("drill_c058", 60),
                         A("drill_c054", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 5, "theme": "分离角体系 — 厚薄与调控", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c024", 80), A("drill_c084", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c025", 80), A("drill_c026", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c027", 70), A("drill_c028", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [F("drill_c026", {"manual01": 3, "manual02": 2, "manual03": 2}),
                         A("drill_c029", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c083", 60), A("drill_c029", 50), A("drill_c084", 40),
                         A("drill_c027", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 6, "theme": "力度控制 — 五档与强力杆法", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c044", 70), A("drill_c045", 70)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c049", 80), A("drill_c046", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c047", 72), A("drill_c048", 72)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c050", 70), A("drill_c051", 70)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c049", 60), A("drill_c051", 50), A("drill_c047", 48),
                         A("drill_c045", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 7, "theme": "特殊球处理 — 翻袋 / K 球 / 跳球", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c054", 80), A("drill_c055", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [F("drill_c056", {"Snipaste_2026_06_19_17_32_46": 3,
                                          "Snipaste_2026_06_19_17_35_51": 2,
                                          "Snipaste_2026_06_19_17_37_37": 2}),
                         A("drill_c054", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [F("drill_c057", {"Snipaste_2026_06_19_17_43_31": 3,
                                          "Snipaste_2026_06_19_17_45_48": 3,
                                          "Snipaste_2026_06_19_17_48_56": 2}),
                         A("drill_c055", 50)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c059", 70), A("drill_c054", 60), A("drill_c055", 40)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c056", 60), A("drill_c059", 60), A("drill_c055", 40)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 8, "theme": "防守与解球 — 攻防转换", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c060", 80), A("drill_c061", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c061", 80), A("drill_c058", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c058", 80), A("drill_c060", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c060", 60), A("drill_c061", 50), A("drill_c059", 50)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c061", 60), A("drill_c058", 60), A("drill_c060", 50)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 9, "theme": "进阶循环 — 准度与走位", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c033", 70), A("drill_c041", 72)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c052", 70), A("drill_c038", 72)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c072", 50), A("drill_c040", 60), A("drill_c052", 40)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c063", 50), A("drill_c082", 60), A("drill_c033", 40)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c040", 60), A("drill_c041", 48), A("drill_c052", 40),
                         A("drill_c033", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 10, "theme": "进阶循环 — 杆法与加塞", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c020", 75), A("drill_c021", 72)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c077", 70), A("drill_c078", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c076", 84), A("drill_c018", 50)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [F("drill_c075", {"manual01": 3, "manual02": 3, "manual03": 2}),
                         A("drill_c020", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c021", 60), A("drill_c018", 50), A("drill_c077", 40),
                         A("drill_c020", 30)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 11, "theme": "进阶循环 — 分离角与力度", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c030", 70), A("drill_c031", 65)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c031", 78), A("drill_c083", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c047", 72), A("drill_c051", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c048", 72), A("drill_c049", 60)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c030", 50), A("drill_c083", 50), A("drill_c051", 40),
                         A("drill_c031", 39)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 12, "theme": "综合检验 — 全台清台与 Ghost", "sessions": [
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c070", 80), A("drill_c069", 60)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 3),
             "focused": [A("drill_c065", 80), A("drill_c071", 50)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c001", 9),
             "focused": [A("drill_c067", 81), A("drill_c064", 45)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 3),
             "focused": [A("drill_c070", 64), A("drill_c065", 56), A("drill_c068", 40)],
             "combined": C("drill_c066", 1)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c067", 63), A("drill_c071", 50), A("drill_c069", 40),
                         A("drill_c064", 30)],
             "combined": C("drill_c013", 2)},
        ]},
    ],
}

SPECS = [BEGINNER, INTERMEDIATE, ADVANCED, FULLSKILL]


def main() -> None:
    all_report: list[dict] = []
    for spec in SPECS:
        text, report = render_plan(spec)
        # 结构自检：解码回来核对周数 / 每周天数 / 阶段时长合计
        parsed = json.loads(text)
        assert len(parsed["weeks"]) == parsed["durationWeeks"], parsed["id"]
        for week in parsed["weeks"]:
            assert len(week["sessions"]) == parsed["sessionsPerWeek"], parsed["id"]
            for session in week["sessions"]:
                assert sum(p["durationMinutes"] for p in session["phases"]) \
                    == parsed["minutesPerSession"], parsed["id"]
        path = PLANS_DIR / f"{spec['meta']['id']}.json"
        path.write_text(text, encoding="utf-8")
        all_report.extend(report)
        minutes = spec["meta"]["minutesPerSession"]
        low, high = budget_band(minutes)
        balls = [r["balls"] for r in report]
        equiv = [r["equiv"] for r in report]
        out = sum(1 for b in balls if not low <= b <= high)
        out_e = sum(1 for b in equiv if not low <= b <= high)
        print(f"{spec['meta']['id']:20} sessions={len(report):3} "
              f"balls {min(balls)}–{max(balls)} 当量 {min(equiv):.0f}–{max(equiv):.0f} "
              f"(band {low:.0f}–{high:.0f}) 越界 球数 {out} / 当量 {out_e}")

    print("\n--- 逐 session 派生球数 ---")
    for r in all_report:
        detail = " ".join(f"{i.split('_')[1]}×{n}={b}" for i, n, b in r["entries"])
        tag = "" if abs(r["equiv"] - r["balls"]) < 0.5 else f" [当量 {r['equiv']:.0f}]"
        print(f"{r['plan']:18} W{r['week']:2} D{r['day']} 球数 {r['balls']:4}{tag} | {detail}")


if __name__ == "__main__":
    main()
