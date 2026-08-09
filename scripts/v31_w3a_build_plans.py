#!/usr/bin/env python3
"""v31 W3a：重写 6 份专项官方计划（accuracy / cueball / english / force / separation / positioning）。

产出 `QiuJi/Resources/Plans/plan_*.json`，条目全量为 dose 格式（契约 §6.6）：
`{"drillId": ..., "dose": {"roundsPerFormation": N}}` 或 `{"dose": {"formations": [...]}}`。

**球数不在本脚本里手写**——每条目球数一律由 drill JSON 的 `sets.perFormation`
（`Σ ballsPerRound`，无 `perFormation` 时回落 `defaultBallsPerSet`）× 轮数派生，
口径与运行时 `TrainingDoseResolver.resolve` 一致（契约 §5.6 / §6.6）。

设计输入只有三类：
- `W(id, rounds)` 热身 / `C(id, rounds)` 综合：显式轮数；
- `A(id, balls)` 专项：**目标球数**，轮数 = round(balls / 每轮球数)，≥1；
- `F(id, {token: rounds})` 按球形引用（球形即难度阶梯，如 c075 塞量三档）。

写盘前对每个 session 做**预算求解**：在设计轮数附近的小邻域内搜索，使
「派生总球数 × 25–30 秒/杆」两端都落在 `minutesPerSession` 的 ±15% 内
（等价 B ∈ [2.04M, 2.30M]），目标点取 27.5 秒/杆。超预算只减轮数、不改分钟数。
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
    """在设计轮数邻域内搜索使总球数最贴近预算目标的组合（focused ±3、热身/综合 ±1）。"""
    entries: list[dict] = [session["warmup"]] + session["focused"] + [session["combined"]]
    # 热身 / 综合的轮数是设计意图（固定 ~30 球的开场与收尾），预算差额一律由专项段吸收。
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
        in_band = low <= total <= high
        drift = sum(w * abs(r - design_rounds(e))
                    for e, r, w in zip(entries, combo, weights))
        # 先要落进预算带，其次尽量贴近设计轮数，最后才比谁更靠近目标点——
        # 避免为了凑到目标点把某个动作压到 2 轮、另一个抬到 8 轮。
        key = (0 if in_band else 1, drift, abs(total - target))
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
            report.append({
                "plan": meta["id"], "week": week["n"], "day": day,
                "balls": total, "minutes": minutes,
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

ACCURACY = {
    "meta": {
        "id": "plan_accuracy", "nameZh": "准度专项", "nameEn": "Accuracy Specialist",
        "targetLevel": "L1→L2", "durationWeeks": 6, "sessionsPerWeek": 3,
        "minutesPerSession": 75, "isPremium": False,
        "description": "准度专项 / 短板补强：6 周聚焦进袋准度（近台直线→底袋/中袋角度→远台与三分点→薄切极限），"
                       "不做综合主线杂烩。不含带塞准度（留给加塞专项）。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 45, "combined": 15, "review": 5},
    "weeks": [
        {"n": 1, "theme": "近台直线打底", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c011", 70), A("drill_c001", 35)],
             "combined": C("drill_c013", 1)},
            {"warmup": W("drill_c022", 1),
             "focused": [A("drill_c011", 50), A("drill_c001", 25), A("drill_c012", 30)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c023", 2),
             "focused": [A("drill_c011", 60), A("drill_c012", 45)],
             "combined": C("drill_c001", 6)},
        ]},
        {"n": 2, "theme": "底袋角度入门", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c013", 60), A("drill_c002", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c013", 80), A("drill_c002", 25)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c023", 2),
             "focused": [A("drill_c013", 40), A("drill_c002", 40), A("drill_c012", 25)],
             "combined": C("drill_c001", 6)},
        ]},
        {"n": 3, "theme": "中台角度巩固", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c032", 60), A("drill_c013", 40)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c032", 70), A("drill_c002", 35)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c022", 1),
             "focused": [A("drill_c032", 50), A("drill_c013", 40), A("drill_c012", 20)],
             "combined": C("drill_c002", 3)},
        ]},
        {"n": 4, "theme": "中袋角度系列", "sessions": [
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c053", 69), A("drill_c012", 35)],
             "combined": C("drill_c032", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c053", 46), A("drill_c012", 30), A("drill_c032", 30)],
             "combined": C("drill_c013", 1)},
            {"warmup": W("drill_c023", 2),
             "focused": [A("drill_c053", 69), A("drill_c012", 40)],
             "combined": C("drill_c002", 3)},
        ]},
        {"n": 5, "theme": "远台与三分点", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c033", 60), A("drill_c052", 45)],
             "combined": C("drill_c032", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c033", 40), A("drill_c052", 40), A("drill_c062", 24)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c033", 50), A("drill_c062", 28), A("drill_c052", 30)],
             "combined": C("drill_c053", 1)},
        ]},
        {"n": 6, "theme": "薄切与极限综合", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c063", 50), A("drill_c052", 50)],
             "combined": C("drill_c033", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c063", 40), A("drill_c072", 40), A("drill_c033", 30)],
             "combined": C("drill_c032", 3)},
            {"warmup": W("drill_c022", 1),
             "focused": [A("drill_c072", 50), A("drill_c063", 30), A("drill_c052", 30)],
             "combined": C("drill_c013", 1)},
        ]},
    ],
}

CUEBALL = {
    "meta": {
        "id": "plan_cueball", "nameZh": "基础杆法专项", "nameEn": "Cue Ball Control Basics",
        "targetLevel": "L1", "durationWeeks": 6, "sessionsPerWeek": 3,
        "minutesPerSession": 75, "isPremium": False,
        "description": "系统掌握五种基础杆法：定杆、高杆、低杆、斯登杆、加塞。配合准度训练，在 6 周内建立杆法意识。"
                       "系统补加塞准度请选「加塞专项」。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 45, "combined": 15, "review": 5},
    "weeks": [
        {"n": 1, "theme": "定杆精准 — 母球完全静止", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c014", 60), A("drill_c016", 45)],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c014", 50), A("drill_c016", 50)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c014", 55), A("drill_c016", 50)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 2, "theme": "高杆跟进 — 母球向前走", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c003", 60), A("drill_c015", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c003", 80), A("drill_c015", 30)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c003", 40), A("drill_c015", 40), A("drill_c014", 25)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 3, "theme": "低杆缩回 — 母球向后退", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c004", 60), A("drill_c017", 45)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c004", 80), A("drill_c017", 30)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c004", 40), A("drill_c017", 40), A("drill_c016", 25)],
             "combined": C("drill_c001", 6)},
        ]},
        {"n": 4, "theme": "高低杆混合 — 前后控制", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c003", 40), A("drill_c004", 40), A("drill_c015", 25)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c003", 40), A("drill_c004", 40), A("drill_c017", 25)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c015", 35), A("drill_c017", 35), A("drill_c014", 35)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 5, "theme": "杆法与走位结合", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c018", 50), A("drill_c020", 45)],
             "combined": C("drill_c005", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c021", 48), A("drill_c018", 50)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c020", 45), A("drill_c021", 36), A("drill_c018", 30)],
             "combined": C("drill_c005", 3)},
        ]},
        {"n": 6, "theme": "加塞与挤偏 — 让点入门", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c073", 60), A("drill_c074", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c073", 50),
                         F("drill_c075", {"manual01": 2, "manual02": 2, "manual03": 1})],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c074", 60),
                         F("drill_c075", {"manual01": 1, "manual02": 1, "manual03": 2})],
             "combined": C("drill_c012", 3)},
        ]},
    ],
}

ENGLISH = {
    "meta": {
        "id": "plan_english", "nameZh": "加塞专项", "nameEn": "English / Squirt Specialist",
        "targetLevel": "L2", "durationWeeks": 6, "sessionsPerWeek": 3,
        "minutesPerSession": 75, "isPremium": True,
        "description": "加塞专项 / 短板补强：6 周聚焦带塞进袋准度与挤偏让点（近台挤偏认知→长台挤偏放大→塞量阶梯→"
                       "小/中大角度带塞→远台带塞准度）。⛔ 非碰库变线主题；不做综合主线杂烩。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 45, "combined": 15, "review": 5},
    "weeks": [
        {"n": 1, "theme": "挤偏认知·近台", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c073", 60), A("drill_c077", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c073", 80), A("drill_c077", 25)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c073", 60), A("drill_c077", 45)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 2, "theme": "挤偏放大·长台", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c074", 60), A("drill_c073", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c074", 80), A("drill_c077", 25)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c074", 60), A("drill_c073", 40)],
             "combined": C("drill_c032", 3)},
        ]},
        {"n": 3, "theme": "塞量阶梯", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [F("drill_c075", {"manual01": 5}), A("drill_c073", 50)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [F("drill_c075", {"manual01": 3, "manual02": 3}), A("drill_c074", 40)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [F("drill_c075", {"manual01": 2, "manual02": 3, "manual03": 3}),
                         A("drill_c077", 30)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 4, "theme": "小角度带塞", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c076", 56), A("drill_c073", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c076", 84), A("drill_c077", 20)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c076", 56), A("drill_c074", 40)],
             "combined": C("drill_c032", 3)},
        ]},
        {"n": 5, "theme": "中大角度带塞", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c077", 60), A("drill_c076", 42)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c077", 70), A("drill_c073", 40)],
             "combined": C("drill_c033", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c077", 50), A("drill_c076", 28), A("drill_c074", 20)],
             "combined": C("drill_c013", 1)},
        ]},
        {"n": 6, "theme": "远台带塞准度", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c078", 60), A("drill_c077", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c011", 3),
             "focused": [A("drill_c078", 75), A("drill_c074", 40)],
             "combined": C("drill_c033", 3)},
            {"warmup": W("drill_c001", 6),
             "focused": [A("drill_c078", 45), A("drill_c077", 30), A("drill_c076", 28)],
             "combined": C("drill_c012", 3)},
        ]},
    ],
}

FORCE = {
    "meta": {
        "id": "plan_force", "nameZh": "力度控制专项", "nameEn": "Force Control Specialist",
        "targetLevel": "L1→L2", "durationWeeks": 4, "sessionsPerWeek": 3,
        "minutesPerSession": 70, "isPremium": True,
        "description": "力度控制专项 / 短板补强：4 周聚焦控力（轻推与三档→控力落点→强力高/低杆→五档阶梯与全力度综合），"
                       "不做综合主线杂烩。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 40, "combined": 15, "review": 5},
    "weeks": [
        {"n": 1, "theme": "轻推与三档", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c044", 50), A("drill_c045", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c043", 2),
             "focused": [A("drill_c044", 60), A("drill_c045", 35)],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c045", 50), A("drill_c044", 45)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 2, "theme": "控力落点", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c046", 50), A("drill_c050", 45)],
             "combined": C("drill_c005", 3)},
            {"warmup": W("drill_c043", 2),
             "focused": [A("drill_c046", 60), A("drill_c050", 35)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c050", 50), A("drill_c046", 45)],
             "combined": C("drill_c001", 6)},
        ]},
        {"n": 3, "theme": "强力杆法", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c047", 48), A("drill_c048", 48)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c047", 60), A("drill_c048", 36)],
             "combined": C("drill_c012", 3)},
            {"warmup": W("drill_c043", 2),
             "focused": [A("drill_c048", 60), A("drill_c047", 36)],
             "combined": C("drill_c001", 6)},
        ]},
        {"n": 4, "theme": "阶梯与全力度", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c049", 50), A("drill_c051", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c051", 50), A("drill_c049", 45)],
             "combined": C("drill_c005", 3)},
            {"warmup": W("drill_c043", 2),
             "focused": [A("drill_c049", 40), A("drill_c051", 30), A("drill_c046", 25)],
             "combined": C("drill_c012", 3)},
        ]},
    ],
}

SEPARATION = {
    "meta": {
        "id": "plan_separation", "nameZh": "分离角专项", "nameEn": "Separation Angle Specialist",
        "targetLevel": "L2", "durationWeeks": 6, "sessionsPerWeek": 3,
        "minutesPerSession": 75, "isPremium": True,
        "description": "分离角专项 / 短板补强：6 周聚焦分离角（90° 规则→厚薄感知→高/低杆调控→定杆精确与走位应用→"
                       "综合挑战），不做综合主线杂烩。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 45, "combined": 15, "review": 5},
    "weeks": [
        {"n": 1, "theme": "90° 规则", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c024", 60), A("drill_c084", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c024", 60), A("drill_c084", 40)],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c084", 50), A("drill_c024", 60)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 2, "theme": "厚薄感知", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c025", 60), A("drill_c026", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c026", 60), A("drill_c025", 40)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c025", 40), A("drill_c026", 30), A("drill_c024", 40)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 3, "theme": "高杆缩小分离角", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c027", 60), A("drill_c024", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c027", 70), A("drill_c025", 40)],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c027", 50), A("drill_c084", 30), A("drill_c024", 20)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 4, "theme": "低杆扩大分离角", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c028", 60), A("drill_c026", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c028", 70), A("drill_c025", 40)],
             "combined": C("drill_c002", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c028", 50), A("drill_c027", 30), A("drill_c026", 30)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 5, "theme": "定杆精确与走位应用", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c029", 60), A("drill_c030", 45)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c030", 60), A("drill_c029", 45)],
             "combined": C("drill_c005", 3)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c029", 40), A("drill_c030", 35), A("drill_c083", 30)],
             "combined": C("drill_c012", 3)},
        ]},
        {"n": 6, "theme": "综合挑战", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c031", 65), A("drill_c083", 40)],
             "combined": C("drill_c011", 3)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c031", 52), A("drill_c083", 50)],
             "combined": C("drill_c001", 6)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c031", 52), A("drill_c030", 30), A("drill_c029", 25)],
             "combined": C("drill_c012", 3)},
        ]},
    ],
}

POSITIONING = {
    "meta": {
        "id": "plan_positioning", "nameZh": "走位突破计划", "nameEn": "Position Play Breakthrough",
        "targetLevel": "L1→L2", "durationWeeks": 8, "sessionsPerWeek": 4,
        "minutesPerSession": 80, "isPremium": True,
        "description": "从不吃库走位到一库走位，再到分离角与多球叫位，8 周建立系统走位意识。每周 4 练，每次约 80 分钟。",
    },
    "phaseMinutes": {"warmup": 10, "focused": 45, "combined": 20, "review": 5},
    "weeks": [
        {"n": 1, "theme": "走位意识建立 — 不吃库", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c034", 60), A("drill_c037", 45)],
             "combined": C("drill_c001", 8)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c034", 70), A("drill_c037", 35)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c037", 60), A("drill_c034", 45)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c034", 50), A("drill_c037", 50)],
             "combined": C("drill_c003", 2)},
        ]},
        {"n": 2, "theme": "一库走位 — 底库/顶库", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c005", 60), A("drill_c035", 45)],
             "combined": C("drill_c011", 4)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c005", 70), A("drill_c035", 35)],
             "combined": C("drill_c004", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c035", 60), A("drill_c005", 45)],
             "combined": C("drill_c012", 4)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c005", 50), A("drill_c035", 50)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 3, "theme": "杆法与走位配合", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c036", 60), A("drill_c018", 45)],
             "combined": C("drill_c003", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c036", 70), A("drill_c018", 35)],
             "combined": C("drill_c004", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c018", 60), A("drill_c036", 45)],
             "combined": C("drill_c011", 4)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c036", 50), A("drill_c018", 30), A("drill_c035", 25)],
             "combined": C("drill_c013", 2)},
        ]},
        {"n": 4, "theme": "角度球走位 — 分离角入门", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c030", 60), A("drill_c031", 39)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c030", 70), A("drill_c031", 39)],
             "combined": C("drill_c012", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c031", 52), A("drill_c030", 50)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c030", 40), A("drill_c031", 39), A("drill_c005", 30)],
             "combined": C("drill_c001", 8)},
        ]},
        {"n": 5, "theme": "连续走位 — 两球连打", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c039", 56), A("drill_c079", 48)],
             "combined": C("drill_c011", 4)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c039", 64), A("drill_c081", 40)],
             "combined": C("drill_c003", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c079", 40), A("drill_c081", 40), A("drill_c039", 32)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c039", 48), A("drill_c079", 28), A("drill_c081", 28)],
             "combined": C("drill_c004", 2)},
        ]},
        {"n": 6, "theme": "准度维持与走位强化", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c080", 60), A("drill_c005", 45)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c080", 70), A("drill_c005", 35)],
             "combined": C("drill_c012", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c005", 60), A("drill_c080", 45)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c080", 50), A("drill_c005", 30), A("drill_c034", 25)],
             "combined": C("drill_c011", 4)},
        ]},
        {"n": 7, "theme": "复杂角度走位", "sessions": [
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c038", 60), A("drill_c041", 48)],
             "combined": C("drill_c011", 4)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c038", 72), A("drill_c041", 36)],
             "combined": C("drill_c003", 2)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c041", 60), A("drill_c038", 48)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c038", 36), A("drill_c041", 36), A("drill_c080", 30)],
             "combined": C("drill_c004", 2)},
        ]},
        {"n": 8, "theme": "综合走位检验", "sessions": [
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c040", 60), A("drill_c042", 45)],
             "combined": C("drill_c011", 4)},
            {"warmup": W("drill_c010", 2),
             "focused": [A("drill_c040", 50), A("drill_c082", 48)],
             "combined": C("drill_c002", 4)},
            {"warmup": W("drill_c006", 1),
             "focused": [A("drill_c042", 60), A("drill_c082", 48)],
             "combined": C("drill_c013", 2)},
            {"warmup": W("drill_c009", 2),
             "focused": [A("drill_c040", 40), A("drill_c042", 30), A("drill_c082", 36)],
             "combined": C("drill_c001", 8)},
        ]},
    ],
}

SPECS = [ACCURACY, CUEBALL, ENGLISH, FORCE, SEPARATION, POSITIONING]


def main() -> None:
    all_report: list[dict] = []
    for spec in SPECS:
        text, report = render_plan(spec)
        # 结构自检：解码回来核对周数 / 每周天数
        parsed = json.loads(text)
        assert len(parsed["weeks"]) == parsed["durationWeeks"], parsed["id"]
        for week in parsed["weeks"]:
            assert len(week["sessions"]) == parsed["sessionsPerWeek"], parsed["id"]
        path = PLANS_DIR / f"{spec['meta']['id']}.json"
        path.write_text(text, encoding="utf-8")
        all_report.extend(report)
        minutes = spec["meta"]["minutesPerSession"]
        low, high = budget_band(minutes)
        balls = [r["balls"] for r in report]
        out = sum(1 for b in balls if not low <= b <= high)
        print(f"{spec['meta']['id']:20} sessions={len(report):3} "
              f"balls {min(balls)}–{max(balls)} (band {low:.0f}–{high:.0f}) 越界 {out}")

    print("\n--- 逐 session 派生球数 ---")
    for r in all_report:
        detail = " ".join(f"{i.split('_')[1]}×{n}={b}" for i, n, b in r["entries"])
        print(f"{r['plan']:18} W{r['week']} D{r['day']} 球数 {r['balls']:4} | {detail}")


if __name__ == "__main__":
    main()
