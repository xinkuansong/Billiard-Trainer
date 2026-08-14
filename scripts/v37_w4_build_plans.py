#!/usr/bin/env python3
"""v37 W4：按 D-v37-3 目录重写官方计划 JSON + 自检报告。

衰减口径（3b=B 优先于目录 §4「第 2 次 70%」）：
  n=1、n=2 完整剂量、禁止 decay；n=3 ≈70% decay；n≥4 ≈50% decay。
  特殊球主计划同此（第 3 次起 70%）。
  无序列 8 条只能 roundsPerFormation=1，不能 decay。
跨计划咬合：该后计划内第一次出现按 §6.6 走完整剂量 + reviewFrom，不标 decay
（契约「首次引入不得 decay」优先于目录 §5「必须 decay」）。
"""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = ROOT / "QiuJi/Resources/Drills"
PLANS_DIR = ROOT / "QiuJi/Resources/Plans"
LOG_DIR = ROOT / "build/v37-w4-logs"
AXES = ("aim", "cue", "spin", "position", "constraint", "speed")
BANDS = (75, 90, 120, 150)
NO_SEQ = {
    "drill_c008", "drill_c043", "drill_c059", "drill_c061",
    "drill_c065", "drill_c067", "drill_c068", "drill_c070",
}
def scalar_max(drill: dict) -> int:
    return max(load_axes(drill).values()) if drill.get("load") else 0


def did(short: str) -> str:
    return short if short.startswith("drill_") else f"drill_{short}"


def load_drills() -> dict[str, dict]:
    out = {}
    for path in DRILLS_DIR.rglob("drill_c*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        out[data["id"]] = data
    return out


def formations(drill: dict) -> list[dict]:
    return list((drill.get("sets") or {}).get("perFormation") or [])


def load_axes(drill: dict) -> dict[str, int]:
    raw = drill.get("load") or {}
    return {k: int(raw.get(k, 0)) for k in AXES}


def full_balls(drill: dict) -> int:
    pf = formations(drill)
    if pf:
        return sum(int(x["defaultRounds"]) * int(x["ballsPerRound"]) for x in pf)
    sets = drill.get("sets") or {}
    return int(sets.get("defaultSets") or 0) * int(sets.get("defaultBallsPerSet") or 0)


def mins_of(balls: int) -> int:
    if balls <= 0:
        return 0
    return max(1, int(round(balls / 2.5)))


def decay_pct(n: int, drill_id: str) -> tuple[float, bool]:
    """返回 (倍数, 是否标 decay)。n 为该计划内第几次出现（1-based）。"""
    if drill_id in NO_SEQ:
        return 1.0, False
    if n <= 2:
        return 1.0, False
    if n == 3:
        return 0.7, True
    return 0.5, True


def make_dose(drill: dict, n: int, review_from: str | None) -> tuple[dict, int]:
    drill_id = drill["id"]
    pct, decay = decay_pct(n, drill_id)
    # 跨计划首次：契约禁止 decay；reviewFrom 仍写。
    if review_from and n <= 2:
        # 跨计划前两次仍走完整剂量（§6.6 首次 + 3b 全量≥2 若复现）。
        decay = False
        pct = 1.0
    pf = formations(drill)
    if not pf:
        dose: dict = {"roundsPerFormation": 1}
        balls = full_balls(drill)
    else:
        items = []
        balls = 0
        for item in pf:
            floor = int(item["defaultRounds"])
            rounds = max(1, int(round(floor * pct)))
            if not decay:
                rounds = max(rounds, floor)
            items.append({"token": item["token"], "rounds": rounds})
            balls += rounds * int(item["ballsPerRound"])
        dose = {"formations": items}
    if decay:
        dose["decay"] = True
    if review_from:
        dose["reviewFrom"] = review_from
    return dose, balls


# (plan_id, drill_id) → 来源计划。仅咬合条目。
CROSS = {
    ("plan_intermediate", "drill_c032"): "plan_accuracy",
    ("plan_english", "drill_c017"): "plan_cueball",
    ("plan_positioning2", "drill_c036"): "plan_positioning",
    ("plan_positioning2", "drill_c079"): "plan_positioning",
    ("plan_fullskill", "drill_c082"): "plan_positioning2",
    ("plan_fullskill", "drill_c054"): "plan_advanced",
    ("plan_fullskill", "drill_c078"): "plan_intermediate",
}

# 主计划归属（3b=B，83 条各一）。
HOME: dict[str, tuple[str, ...]] = {
    "plan_beginner": ("c006", "c007", "c008", "c009", "c010", "c022", "c023", "c043"),
    "plan_accuracy": ("c001", "c011", "c012", "c013", "c002", "c032"),
    "plan_cueball": ("c003", "c004", "c014", "c015", "c016", "c017"),
    "plan_force": ("c044", "c045", "c046", "c047", "c048", "c049", "c050", "c051"),
    "plan_separation": ("c024", "c025", "c026", "c027", "c028", "c029", "c030", "c031", "c083", "c084"),
    "plan_english": ("c018", "c020", "c021", "c073", "c074", "c075"),
    "plan_positioning": ("c034", "c037", "c005", "c035", "c036", "c079", "c081"),
    "plan_positioning2": ("c038", "c039", "c040", "c041", "c042", "c080", "c082"),
    "plan_intermediate": ("c033", "c052", "c053", "c062", "c063", "c072", "c076", "c077", "c078"),
    "plan_advanced": ("c054", "c055", "c056", "c057", "c058", "c059", "c060", "c061"),
    "plan_fullskill": ("c064", "c065", "c066", "c067", "c068", "c069", "c070", "c071"),
}

# 货架顺序（index.json）。
SHELF_ORDER = [
    "plan_beginner", "plan_accuracy", "plan_cueball", "plan_force",
    "plan_separation", "plan_english", "plan_positioning", "plan_positioning2",
    "plan_intermediate", "plan_advanced", "plan_fullskill",
]

META = {
    "plan_beginner": {
        "nameZh": "基本功", "nameEn": "Fundamentals",
        "targetLevel": "L0→L1", "isPremium": False, "targetBand": 75,
        "description": "建立握杆、手架、站位与出杆直线等基本功，为后续准度与杆法打底。每周三次课，关键动作完整剂量巩固后再减量复现。",
    },
    "plan_accuracy": {
        "nameZh": "准度Ⅰ·近中台", "nameEn": "Accuracy I · Near/Mid Table",
        "targetLevel": "L0→L2", "isPremium": False, "targetBand": 90,
        "description": "聚焦近台与中台准度：半台/近台直线、中袋直线、近台小角度与中台切角。远台与带塞准度见准度Ⅱ。因底袋小角度全量约 102 分钟，本计划课时档取 90′（目录原 75′ 装不下完整剂量）。",
    },
    "plan_cueball": {
        "nameZh": "杆法Ⅰ·高低杆", "nameEn": "Cue Action I · Follow & Draw",
        "targetLevel": "L1", "isPremium": False, "targetBand": 90,
        "description": "掌握中杆定杆、高杆跟进与低杆缩杆，建立停点与力度标尺；本计划不加塞、不练挤偏。",
    },
    "plan_force": {
        "nameZh": "力度", "nameEn": "Force Control",
        "targetLevel": "L1→L2", "isPremium": True, "targetBand": 90,
        "description": "建立五档力度标尺，并在强弱杆、控力走位与全力度综合中把标尺用出来。",
    },
    "plan_separation": {
        "nameZh": "分离角", "nameEn": "Separation Angle",
        "targetLevel": "L2", "isPremium": True, "targetBand": 120,
        "description": "分离角专项：从 90° 规则与薄厚感知，到高低杆调制、精确控制与吃库/不吃库对照。",
    },
    "plan_english": {
        "nameZh": "杆法Ⅱ·加塞挤偏", "nameEn": "Cue Action II · English & Squirt",
        "targetLevel": "L2→L3", "isPremium": True, "targetBand": 150,
        "description": "加塞与挤偏专项：近台认知、长台放大、塞量阶梯，以及高低杆加塞走位。带塞准度留在准度Ⅱ。",
    },
    "plan_positioning": {
        "nameZh": "走位Ⅰ·短距到一库", "nameEn": "Position I · Short to One-Rail",
        "targetLevel": "L1→L3", "isPremium": True, "targetBand": 120,
        "description": "从不吃库短距离与入位，到一库定点/高杆一库/低杆一库，以及四球走位与同袋叫位。多库与蛇彩见走位Ⅱ。",
    },
    "plan_positioning2": {
        "nameZh": "走位Ⅱ·多库与蛇彩", "nameEn": "Position II · Multi-Rail & Snake",
        "targetLevel": "L2→L4", "isPremium": True, "targetBand": 150,
        "description": "上下半台、两库与对角、组合与三库，以及初级蛇彩与横向围 8。热身咬合走位Ⅰ末段。",
    },
    "plan_intermediate": {
        "nameZh": "准度Ⅱ·远台带塞", "nameEn": "Accuracy II · Long Table with English",
        "targetLevel": "L2→L3", "isPremium": True, "targetBand": 150,
        "description": "远台斜线与三分点、中袋角度与极薄、远台中袋/直线极限，以及带塞准度。热身咬合准度Ⅰ末段切角。",
    },
    "plan_advanced": {
        "nameZh": "特殊球", "nameEn": "Special Shots",
        "targetLevel": "L3", "isPremium": True, "targetBand": 90,
        "description": "翻袋、K 球、贴库、跳球、安全球与解球等约束技术，按完整剂量打两次再减量复现。",
    },
    "plan_fullskill": {
        "nameZh": "全能精选", "nameEn": "All-Around Select",
        "targetLevel": "L2→L4", "isPremium": True, "targetBand": 120,
        "description": "开球、连打、Ghost、9 球/五球/全台清台与蛇彩进阶，检验各线程衔接。其它线程只作咬合热身。",
    },
}

# 每周 (theme, [focused ×3])。热身按六轴 max ≤ 主课自动配对；咬合作优先热身。
LAYOUTS: dict[str, list[tuple[str, list[str]]]] = {
    "plan_beginner": [
        ("握杆与站位", ["c006", "c007", "c006"]),
        ("手架与出杆直线", ["c008", "c009", "c023"]),
        ("定杆与瞄准线", ["c010", "c010", "c009"]),
        ("远台出杆巩固", ["c022", "c043", "c022"]),
    ],
    "plan_accuracy": [
        ("近台直线起步", ["c001", "c011", "c001"]),
        ("中袋与半台", ["c012", "c013", "c012"]),
        ("切角起步", ["c002", "c032", "c002"]),
    ],
    "plan_cueball": [
        ("中杆定杆与停球", ["c016", "c014", "c016"]),
        ("高杆跟进", ["c014", "c015", "c003"]),
        ("低杆缩杆", ["c004", "c017", "c004"]),
    ],
    "plan_force": [
        ("力度标尺", ["c045", "c044", "c049"]),
        ("强弱杆", ["c047", "c048", "c046"]),
        ("控力走位与全力度", ["c050", "c051", "c051"]),
    ],
    "plan_separation": [
        ("厚球与高低杆感知", ["c026", "c027", "c028"]),
        ("精确控制与走位", ["c029", "c030", "c031"]),
        ("吃库对照与 90°", ["c083", "c084", "c024"]),
        ("薄球分离", ["c025", "c025", "c024"]),
    ],
    "plan_english": [
        ("挤偏近台", ["c073", "c018", "c073"]),
        ("高低杆加塞走位", ["c020", "c021", "c020"]),
        ("挤偏长台", ["c074", "c074", "c018"]),
        ("塞量阶梯", ["c075", "c075", "c021"]),
    ],
    "plan_positioning": [
        ("不吃库短距与入位", ["c034", "c037", "c034"]),
        ("一库定点与高杆一库", ["c005", "c035", "c005"]),
        ("低杆一库", ["c036", "c036", "c035"]),
        ("四球走位与同袋叫位", ["c079", "c081", "c079"]),
    ],
    "plan_positioning2": [
        ("初级蛇彩与半台", ["c042", "c080", "c038"]),
        ("两库与对角", ["c041", "c041", "c038"]),
        ("组合与三库", ["c039", "c040", "c039"]),
        ("横向围 8", ["c082", "c082", "c040"]),
    ],
    "plan_intermediate": [
        ("中袋角度起步", ["c053", "c076", "c053"]),
        ("远台斜线", ["c033", "c072", "c033"]),
        ("远台中袋与极薄", ["c062", "c063", "c078"]),
        ("三分点与带塞", ["c052", "c077", "c052"]),
    ],
    "plan_advanced": [
        ("K 球与贴库", ["c056", "c057", "c058"]),
        ("翻袋", ["c054", "c055", "c054"]),
        ("安全球与解球", ["c060", "c061", "c061"]),
        ("跳球", ["c059", "c059", "c055"]),
    ],
    "plan_fullskill": [
        ("开球与三球连打", ["c066", "c064", "c069"]),
        ("五球与 9 球", ["c071", "c068", "c067"]),
        ("Ghost", ["c065", "c065", "c068"]),
        ("全台清台", ["c070", "c070", "c067"]),
        ("蛇彩收官", ["c069", "c071", "c070"]),
    ],
}

BITES: dict[str, tuple[str, ...]] = {
    "plan_intermediate": ("c032",),
    "plan_english": ("c017",),
    "plan_positioning2": ("c036", "c079"),
    "plan_fullskill": ("c082", "c054", "c078"),
}


def emit_ref(drill: dict, n: int, review_from: str | None) -> tuple[dict, int]:
    dose, balls = make_dose(drill, n, review_from)
    return {"drillId": drill["id"], "dose": dose}, balls


def _appearance_n(weeks: list, drill_id: str) -> int:
    n = 0
    for week in weeks:
        for session in week["sessions"]:
            for phase in session["phases"]:
                n += sum(1 for ref in phase["drills"] if ref["drillId"] == drill_id)
    return n


def _repair_second_full(
    plan_id: str,
    weeks: list,
    drills: dict[str, dict],
    home: set[str],
) -> None:
    """把仍只有 1 次完整剂量的主课补进某节热身（不替换已有条目）。"""
    for hid in sorted(home):
        full_n = 0
        for week in weeks:
            for session in week["sessions"]:
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        if ref["drillId"] == hid and is_full_dose(ref, drills[hid]):
                            full_n += 1
        if full_n >= 2:
            continue
        hid_max = scalar_max(drills[hid])
        placed = False
        for week in weeks:
            for session in week["sessions"]:
                focused = next(p for p in session["phases"] if p["type"] == "focused")
                fids = [r["drillId"] for r in focused["drills"]]
                if hid in fids:
                    continue
                fmax = max(scalar_max(drills[i]) for i in fids)
                if hid_max > fmax:
                    continue
                add_mins = mins_of(full_balls(drills[hid]))
                already = sum(p["durationMinutes"] for p in session["phases"])
                if already + add_mins > 180:
                    continue
                warmup = next((p for p in session["phases"] if p["type"] == "warmup"), None)
                if warmup and hid in [r["drillId"] for r in warmup["drills"]]:
                    continue
                n = _appearance_n(weeks, hid) + 1
                ref, balls = emit_ref(drills[hid], n, CROSS.get((plan_id, hid)))
                extra_min = max(1, mins_of(balls))
                if warmup:
                    warmup["drills"].append(ref)
                    warmup["durationMinutes"] += extra_min
                else:
                    session["phases"].insert(0, {
                        "type": "warmup",
                        "durationMinutes": extra_min,
                        "drills": [ref],
                    })
                placed = True
                break
            if placed:
                break


def pick_warmup(
    plan_id: str,
    focused_id: str,
    introduced: list[str],
    counts: dict[str, int],
    drills: dict[str, dict],
    home: set[str],
    unused_bites: list[str],
) -> str | None:
    # 咬合优先，但不得把超大主课再叠成 3 小时。
    fmax = scalar_max(drills[focused_id])
    focused_mins = mins_of(full_balls(drills[focused_id]))
    if unused_bites:
        bite = unused_bites[0]
        bite_mins = mins_of(full_balls(drills[bite]))
        if focused_mins + bite_mins <= 160:
            return bite
    if focused_mins >= 90:
        light = []
        seen = []
        for did_ in reversed(introduced):
            if did_ == focused_id or did_ in seen:
                continue
            seen.append(did_)
            if scalar_max(drills[did_]) > fmax:
                continue
            if mins_of(full_balls(drills[did_])) > 30:
                continue
            need = 1 if (did_ in home and counts[did_] < 2) else 0
            light.append((need, scalar_max(drills[did_]), counts[did_], did_))
        if not light:
            return None
        light.sort(key=lambda x: (-x[0], -x[1], x[2]))
        return light[0][3]
    ranked: list[tuple[int, int, int, str]] = []
    seen = []
    for did_ in reversed(introduced):
        if did_ == focused_id or did_ in seen:
            continue
        seen.append(did_)
        if scalar_max(drills[did_]) > fmax:
            continue
        need = 1 if (did_ in home and counts[did_] < 2) else 0
        ranked.append((need, scalar_max(drills[did_]), counts[did_], did_))
    if not ranked:
        return None
    ranked.sort(key=lambda x: (-x[0], -x[1], x[2]))
    return ranked[0][3]


def build_plan(plan_id: str, drills: dict[str, dict]) -> dict:
    meta = META[plan_id]
    home = {did(x) for x in HOME[plan_id]}
    counts: dict[str, int] = defaultdict(int)
    introduced: list[str] = []
    unused_bites = [did(x) for x in BITES.get(plan_id, ())]
    weeks_out = []
    session_mins = []
    for week_number, (theme, days) in enumerate(LAYOUTS[plan_id], start=1):
        sessions = []
        for day_number, focused_short in enumerate(days, start=1):
            fid = did(focused_short)
            wid = pick_warmup(
                plan_id, fid, introduced, counts, drills, home, unused_bites
            )
            phases = []
            if wid:
                counts[wid] += 1
                review = CROSS.get((plan_id, wid))
                ref, balls = emit_ref(drills[wid], counts[wid], review)
                phases.append({
                    "type": "warmup",
                    "durationMinutes": max(1, mins_of(balls)),
                    "drills": [ref],
                })
                if wid not in introduced:
                    introduced.append(wid)
                if wid in unused_bites:
                    unused_bites.remove(wid)
            counts[fid] += 1
            review = CROSS.get((plan_id, fid))
            ref, balls = emit_ref(drills[fid], counts[fid], review)
            phases.append({
                "type": "focused",
                "durationMinutes": max(1, mins_of(balls)),
                "drills": [ref],
            })
            if fid not in introduced:
                introduced.append(fid)
            phases.append({"type": "review", "durationMinutes": 5, "drills": []})
            sessions.append({"dayNumber": day_number, "phases": phases})
            session_mins.append(sum(p["durationMinutes"] for p in phases))
        weeks_out.append({
            "weekNumber": week_number,
            "theme": theme,
            "sessions": sessions,
        })
    _repair_second_full(plan_id, weeks_out, drills, home)
    session_mins = [
        sum(p["durationMinutes"] for p in session["phases"])
        for week in weeks_out for session in week["sessions"]
    ]
    mean = sum(session_mins) / len(session_mins)
    snapped = min(BANDS, key=lambda b: abs(b - mean))
    return {
        "id": plan_id,
        "nameZh": meta["nameZh"],
        "nameEn": meta["nameEn"],
        "targetLevel": meta["targetLevel"],
        "durationWeeks": len(weeks_out),
        "sessionsPerWeek": 3,
        "minutesPerSession": snapped,
        "isPremium": meta["isPremium"],
        "description": meta["description"],
        "weeks": weeks_out,
        "_sessionMins": session_mins,
        "_mean": mean,
        "_targetBand": meta["targetBand"],
    }


def is_full_dose(ref: dict, drill: dict) -> bool:
    dose = ref.get("dose") or {}
    if dose.get("decay") is True:
        return False
    pf = formations(drill)
    if not pf:
        return dose.get("roundsPerFormation") == 1
    listed = {x["token"]: x["rounds"] for x in dose.get("formations") or []}
    if set(listed) != {x["token"] for x in pf}:
        return False
    return all(listed[x["token"]] >= int(x["defaultRounds"]) for x in pf)


def check_all(plans: dict[str, dict], drills: dict[str, dict]) -> list[str]:
    fails = []
    home_ids = {pid: {did(x) for x in shorts} for pid, shorts in HOME.items()}
    covered = set()
    for pid, shorts in HOME.items():
        covered |= {did(x) for x in shorts}
    expected = set(drills)
    if covered != expected:
        fails.append(f"主计划覆盖 {len(covered)} != 83；缺 {sorted(expected - covered)} 多 {sorted(covered - expected)}")

    for pid, plan in plans.items():
        home = home_ids[pid]
        first_week: dict[str, int] = {}
        full_count: dict[str, int] = defaultdict(int)
        focused_full: dict[str, int] = defaultdict(int)
        first_decay: dict[str, bool] = {}
        week_new_max: dict[int, int] = {}
        for week in plan["weeks"]:
            wn = week["weekNumber"]
            new_this_week = []
            for session in week["sessions"]:
                phases = {p["type"]: p for p in session["phases"]}
                wrefs = (phases.get("warmup") or {}).get("drills") or []
                frefs = (phases.get("focused") or {}).get("drills") or []
                if not frefs:
                    fails.append(f"{pid} W{wn}D{session['dayNumber']} 无 focused")
                    continue
                # R4 热身≤主课（跨计划咬合热身豁免：复习条目不是本线程新课）
                if wrefs:
                    compared = False
                    wscalar = 0
                    for ref in wrefs:
                        if CROSS.get((pid, ref["drillId"])):
                            continue
                        compared = True
                        wscalar = max(wscalar, scalar_max(drills[ref["drillId"]]))
                    fscalar = max(scalar_max(drills[ref["drillId"]]) for ref in frefs)
                    if compared and wscalar > fscalar:
                        fails.append(
                            f"R4 热身>主课 {pid} W{wn}D{session['dayNumber']} "
                            f"warmup_max={wscalar} focused_max={fscalar}"
                        )
                for phase_name, refs in (("warmup", wrefs), ("focused", frefs)):
                    for ref in refs:
                        did_ = ref["drillId"]
                        if did_ not in first_week:
                            first_week[did_] = wn
                            if not CROSS.get((pid, did_)):
                                new_this_week.append(did_)
                        decay = (ref.get("dose") or {}).get("decay") is True
                        if did_ not in first_decay:
                            first_decay[did_] = decay
                        if is_full_dose(ref, drills[did_]):
                            full_count[did_] += 1
                            if phase_name == "focused":
                                focused_full[did_] += 1
                        src = CROSS.get((pid, did_))
                        review = (ref.get("dose") or {}).get("reviewFrom")
                        if src and review != src:
                            fails.append(f"R6 {pid} {did_} 期望 reviewFrom={src} 实得 {review}")
                        if (not src) and review:
                            fails.append(f"R6 {pid} {did_} 非咬合却写了 reviewFrom={review}")
            if new_this_week:
                week_new_max[wn] = max(
                    max(load_axes(drills[d]).values()) for d in new_this_week
                )
        # 周序不降：后周新引入的 max 不得低于前周新引入
        prev = None
        for wn in sorted(week_new_max):
            cur = week_new_max[wn]
            if prev is not None and cur < prev:
                fails.append(f"R4 周序下降 {pid} 后周 max={cur} < 前周 {prev}（W{wn}）")
            prev = cur
        for hid in home:
            if first_decay.get(hid) is True:
                fails.append(f"首次 decay {pid} {hid}")
            if focused_full.get(hid, 0) < 1:
                fails.append(f"3b 缺 focused 全量 {pid} {hid} focused_full={focused_full.get(hid, 0)}")
            if full_count.get(hid, 0) < 2:
                fails.append(f"3b 全量<2 {pid} {hid} full={full_count.get(hid, 0)}")
        # 课时档：计划级 minutesPerSession 必须落在 75/90/120/150（单课可偏离，v34 R7「大概」）
        mps = plan["minutesPerSession"]
        if mps not in BANDS:
            fails.append(f"课时档未落带 {pid} mps={mps} mean={plan['_mean']:.1f}")
        extra = set()
        for week in plan["weeks"]:
            for session in week["sessions"]:
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        extra.add(ref["drillId"])
        for bid in BITES.get(pid, ()):
            if did(bid) not in extra:
                fails.append(f"R6 缺咬合 {pid} {did(bid)}")
        unexpected = extra - home - {d for (p, d) in CROSS if p == pid}
        if unexpected:
            fails.append(f"{pid} 多出非主课/非咬合 {sorted(unexpected)}")

        banned_english = {"drill_c076", "drill_c077", "drill_c078"}
        if pid == "plan_english" and extra & banned_english:
            fails.append(f"杆法Ⅱ禁收带塞准度：{sorted(extra & banned_english)}")
        if pid == "plan_positioning":
            for hid in home:
                if load_axes(drills[hid])["position"] >= 4:
                    fails.append(f"走位Ⅰ禁 pos=4：{hid}")
    return fails


def write_index(plans: dict[str, dict]) -> dict:
    return {
        "version": 7,
        "plans": [
            {
                "id": pid,
                "nameZh": plans[pid]["nameZh"],
                "targetLevel": plans[pid]["targetLevel"],
                "isPremium": plans[pid]["isPremium"],
            }
            for pid in SHELF_ORDER
        ],
    }


def strip_private(plan: dict) -> dict:
    return {k: v for k, v in plan.items() if not k.startswith("_")}


def main() -> int:
    drills = load_drills()
    assert len(drills) == 83, len(drills)
    plans = {pid: build_plan(pid, drills) for pid in SHELF_ORDER}
    fails = check_all(plans, drills)
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    lines = ["# v37 W4 计划自检", ""]
    for pid in SHELF_ORDER:
        p = plans[pid]
        lines.append(
            f"## {pid}  {p['nameZh']}  {p['durationWeeks']}周  "
            f"mps={p['minutesPerSession']}  mean={p['_mean']:.1f}  "
            f"sessions={p['_sessionMins']}"
        )
        home = [did(x) for x in HOME[pid]]
        lines.append(f"主课 {len(home)}：{' '.join(home)}")
        lines.append("")
    lines.append("## 检查结果")
    if fails:
        lines.append(f"FAIL {len(fails)}")
        lines.extend(f"- {x}" for x in fails)
    else:
        lines.append("PASS 0")
    report = "\n".join(lines) + "\n"
    (LOG_DIR / "plan-selfcheck.md").write_text(report, encoding="utf-8")
    print(report)

    if fails:
        print("自检未过，不写 JSON。")
        return 1

    for pid, plan in plans.items():
        path = PLANS_DIR / f"{pid}.json"
        path.write_text(
            json.dumps(strip_private(plan), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"wrote {path.name}")
    index_path = PLANS_DIR / "index.json"
    index_path.write_text(
        json.dumps(write_index(plans), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote index.json version 7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
