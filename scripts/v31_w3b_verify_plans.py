#!/usr/bin/env python3
"""v31 W3b 批内复验（只读）：4 份综合官方计划的 dose 格式 / 预算 / 主题对齐。

**独立于生成脚本**：只读 `Resources/Plans/plan_*.json`、`Resources/Drills/`、
`Drills/index.json` 与 `content/position_play/sequences/`，不 import 生成器的任何设计数据。

检查项（编号沿用 W3a 复验脚本）：
- V1（格式切净）：**全部 10 份**官方计划每条 `PlanDrillRef` 都有 `dose`，且无残留
  `sets` / `ballsPerSet`（本批 4 份 + W3a 的 6 份一并对照，完成标准 1）；
- V2（drillId 存在）：本批每条目 `drillId` ∈ `Drills/index.json`；
- V3（dose 可解析）：`roundsPerFormation` 与 `formations` 恰好二选一、轮数 ≥1；
  用 `roundsPerFormation` 的 drill 若有 `perFormation` 则逐球形展开，否则回落汇总兜底
  （口径同 `TrainingDoseResolver.resolve`）；
- V4（token 外键）：`dose.formations[].token` ∈ 该 drill 的 `perFormation` token 集合，
  且 ∈ 该 drill 的序列 token 集合（契约 §6.6 推论 2 / I11）；
- V5（预算）：每 session 派生总球数 B 与**球当量** B*（见下）都要满足
  「B×25s 与 B×30s 两端都落在 `minutesPerSession` 的 ±15% 内」，等价 B ∈ [2.04M, 2.30M]；
- V6（主题周对齐）：`focused` 阶段每个动作的主分类 ∈ 该周主题分类集合（`WEEK_CATEGORIES`），
  或其 `secondaryCategories` 与该集合有交（契约 §3.3：副分类可参与主题归属，统计仍只记主分类）；
- V7（结构）：`weeks` 数 == `durationWeeks`、每周 sessions 数 == `sessionsPerWeek`、
  阶段时长合计 == `minutesPerSession`。

**球当量（W3b 特有）**：基准 25–30 秒/球（含摆球）。
- 按局条目（c065 8 球/局、c067 9 球/局、c070 8 球/局）：一局 = 摆一副球（≈60 秒）+ 逐球击打。
  8×20 秒 + 60 秒 = 220 秒 ⇒ 27.5 秒/球，正落基准带中点 ⇒ **系数 1.0，不折算**。
- 按次条目（c066 开球 10 次/轮）：一次 = 摆全副球（≈60 秒）+ 一杆开球（≈15 秒）≈ 75 秒，
  摆球开销无法摊薄 ⇒ 系数 75/27.5 ≈ **2.7**。
V5 要求 B 与 B* **两条都在带内**，故本脚本的预算判据比 W3a 更紧，⛔ 不是放宽。

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

BATCH = ["plan_beginner", "plan_intermediate", "plan_advanced", "plan_fullskill"]
W3A_BATCH = ["plan_accuracy", "plan_cueball", "plan_english",
             "plan_force", "plan_separation", "plan_positioning"]

SEC_LOW, SEC_HIGH, SEC_MID, TOLERANCE = 25, 30, 27.5, 0.15

# 按次条目的球当量（见模块文档）。未列出者 = 1.0，含全部按局条目。
UNIT_BALL_EQUIV = {"drill_c066": 75 / SEC_MID}

# 逐周主题所属分类集合：**按该周 `theme` 文案逐周推导**，focused 动作须命中其一。
# ⛔ 不得为了让检查通过而写成「全部分类」——8 个分类是
# fundamentals / accuracy / cueAction / separation / positioning / forceControl /
# specialShots / combined，下表每周最多用到 4 个。
WEEK_CATEGORIES: dict[str, dict[int, set[str]]] = {
    "plan_beginner": {
        # 「姿势与握杆基础」= 纯基本功
        1: {"fundamentals"},
        # 「出杆稳定性与直线球」= 基本功（出杆）+ 准度（直线球）
        2: {"fundamentals", "accuracy"},
        # 「中杆定杆与中袋直线」= 中杆定杆同名两条（c010 fundamentals / c014 cueAction）
        # + 中袋直线（accuracy）
        3: {"fundamentals", "cueAction", "accuracy"},
        # 「角度入门与底袋小角度」= 纯准度
        4: {"accuracy"},
        # 「基础杆法引入 — 高杆」= 纯杆法
        5: {"cueAction"},
        # 「基础杆法引入 — 低杆」= 纯杆法
        6: {"cueAction"},
        # 「走位意识入门」= 纯走位
        7: {"positioning"},
        # 「综合巩固与检验」= 复习 W1–W7 出现过的四类（⛔ 不含 separation /
        # forceControl / specialShots / combined —— 新手计划从未教过它们）
        8: {"fundamentals", "accuracy", "cueAction", "positioning"},
    },
    "plan_intermediate": {
        # 「准度、定杆与加塞入门」= 准度 + 杆法（定杆/加塞）
        1: {"accuracy", "cueAction"},
        # 「角度球攻防」= 角度球进袋 → 准度
        2: {"accuracy"},
        3: {"positioning"},            # 「走位专项强化」
        4: {"cueAction"},              # 「杆法组合训练」
        5: {"accuracy"},               # 「准度提升 — 远台与中袋」
        6: {"positioning"},            # 「走位连打」
        # 「综合球形 — 多球连打」= 综合球形 + 多球走位
        7: {"combined", "positioning"},
        # 「实战模拟 — 连打与攻防」= 连打（combined）+ 攻防（安全球/贴库/翻袋 → specialShots）
        8: {"combined", "specialShots"},
        # 「薄弱环节补强 — 分离角与力度」= 主题文案已点名两类
        9: {"separation", "forceControl"},
        # 「综合检验 — 全面测试」= 综合类检验局
        10: {"combined"},
    },
    "plan_advanced": {
        1: {"cueAction"},                     # 「加塞基础 — 左右塞入门」
        2: {"cueAction", "positioning"},      # 「加塞走位 — 吃库后转向」
        3: {"positioning"},                   # 「多库走位入门」
        4: {"specialShots"},                  # 「防守策略 — 安全球」= 安全球/解球/跳球/贴库
        5: {"cueAction"},                     # 「加塞精度提升」（带塞准度条目副分类 cueAction）
        6: {"combined", "specialShots"},      # 「高级球形 — 连打攻防」
        7: {"combined"},                      # 「比赛模拟」= 清台 / Ghost / 开球
        8: {"combined"},                      # 「综合检验 — 全面挑战」
    },
    "plan_fullskill": {
        1: {"accuracy"},                      # 「准度基石 — 各角度巩固」
        2: {"cueAction"},                     # 「杆法深化 — 精准控制」
        3: {"positioning"},                   # 「走位体系 — 连续多球」
        4: {"combined", "specialShots"},      # 「综合攻防训练」
        5: {"separation"},                    # 「分离角体系 — 厚薄与调控」
        6: {"forceControl"},                  # 「力度控制 — 五档与强力杆法」
        7: {"specialShots"},                  # 「特殊球处理 — 翻袋 / K 球 / 跳球」
        8: {"specialShots"},                  # 「防守与解球 — 攻防转换」
        9: {"accuracy", "positioning"},       # 「进阶循环 — 准度与走位」
        10: {"cueAction"},                    # 「进阶循环 — 杆法与加塞」
        11: {"separation", "forceControl"},   # 「进阶循环 — 分离角与力度」
        12: {"combined"},                     # 「综合检验 — 全台清台与 Ghost」
    },
}


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

    # --- V1：全部 10 份计划格式切净（本批 4 份 + W3a 6 份对照）---
    for plan_id in BATCH + W3A_BATCH:
        plan = json.loads((PLANS_DIR / f"{plan_id}.json").read_text(encoding="utf-8"))
        for week in plan["weeks"]:
            for session in week["sessions"]:
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        checked["V1"] += 1
                        where = (f"{plan_id} W{week['weekNumber']} D{session['dayNumber']} "
                                 f"{phase['type']} {ref['drillId']}")
                        if "sets" in ref or "ballsPerSet" in ref:
                            fails.append(f"V1 {where}: 仍残留旧格式 sets/ballsPerSet")
                        if "dose" not in ref:
                            fails.append(f"V1 {where}: 缺 dose")

    # --- V2–V7：本批 4 份 ---
    for plan_id in BATCH:
        plan = json.loads((PLANS_DIR / f"{plan_id}.json").read_text(encoding="utf-8"))
        minutes = plan["minutesPerSession"]
        low = (1 - TOLERANCE) * minutes * 60 / SEC_LOW
        high = (1 + TOLERANCE) * minutes * 60 / SEC_HIGH
        week_cats = WEEK_CATEGORIES[plan_id]

        checked["V7"] += 1
        if len(plan["weeks"]) != plan["durationWeeks"]:
            fails.append(f"V7 {plan_id}: weeks {len(plan['weeks'])} != durationWeeks")
        if set(week_cats) != {w["weekNumber"] for w in plan["weeks"]}:
            fails.append(f"V6 {plan_id}: WEEK_CATEGORIES 的周编号与计划不符")

        for week in plan["weeks"]:
            checked["V7"] += 1
            if len(week["sessions"]) != plan["sessionsPerWeek"]:
                fails.append(
                    f"V7 {plan_id} W{week['weekNumber']}: sessions "
                    f"{len(week['sessions'])} != sessionsPerWeek"
                )
            themed = week_cats.get(week["weekNumber"], set())
            for session in week["sessions"]:
                where_s = f"{plan_id} W{week['weekNumber']} D{session['dayNumber']}"
                checked["V7"] += 1
                if sum(p["durationMinutes"] for p in session["phases"]) != minutes:
                    fails.append(f"V7 {where_s}: 阶段时长合计 != minutesPerSession")

                total_balls = 0
                total_equiv = 0.0
                for phase in session["phases"]:
                    for ref in phase["drills"]:
                        drill_id = ref["drillId"]
                        where = f"{where_s} {phase['type']} {drill_id}"
                        referenced.add(drill_id)

                        if "dose" not in ref:
                            continue      # 已在 V1 记账

                        checked["V2"] += 1
                        if drill_id not in index_ids:
                            fails.append(f"V2 {where}: drillId 不在 index.json")
                            continue

                        checked["V3"] += 1
                        drill = drills[drill_id]
                        balls = resolve_balls(drill, ref["dose"], fails, where)
                        total_balls += balls
                        total_equiv += balls * UNIT_BALL_EQUIV.get(drill_id, 1.0)

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
                            if not (cats & themed):
                                fails.append(
                                    f"V6 {where}: 主/副分类 {sorted(cats)} 未命中周主题分类集合"
                                    f" {sorted(themed)}（周主题「{week['theme']}」）"
                                )

                checked["V5"] += 1
                ok_raw = low <= total_balls <= high
                ok_eq = low <= total_equiv <= high
                if not ok_raw:
                    fails.append(
                        f"V5 {where_s}: 派生球数 {total_balls} 超预算带 "
                        f"[{low:.0f},{high:.0f}]（{minutes}′±15%）"
                    )
                if not ok_eq:
                    fails.append(
                        f"V5 {where_s}: 球当量 {total_equiv:.1f} 超预算带 "
                        f"[{low:.0f},{high:.0f}]（{minutes}′±15%）"
                    )
                session_rows.append((where_s, total_balls, total_equiv, minutes,
                                     low, high, ok_raw and ok_eq))

    print("=== V5 逐 session 预算（球数 / 球当量 × 25–30 秒 vs minutesPerSession ±15%）===")
    for where_s, balls, equiv, minutes, low, high, ok in session_rows:
        eq_tag = "" if abs(equiv - balls) < 0.5 else f" 当量 {equiv:5.1f}"
        print(f"{'OK ' if ok else '⛔ '} {where_s:28} 球数 {balls:4}{eq_tag:>12} → "
              f"{equiv * SEC_LOW / 60:5.1f}′~{equiv * SEC_HIGH / 60:5.1f}′ vs {minutes}′ "
              f"(带 {low:.0f}–{high:.0f}, 偏差 {(equiv * SEC_LOW / 60 - minutes) / minutes:+.1%}"
              f" ~ {(equiv * SEC_HIGH / 60 - minutes) / minutes:+.1%})")

    print("\n=== V6 focused 主题周对齐（逐周主题分类集合）===")
    for plan_id in BATCH:
        plan = json.loads((PLANS_DIR / f"{plan_id}.json").read_text(encoding="utf-8"))
        for week in plan["weeks"]:
            themed = WEEK_CATEGORIES[plan_id][week["weekNumber"]]
            ids = sorted({
                r["drillId"]
                for s in week["sessions"] for p in s["phases"]
                if p["type"] == "focused" for r in p["drills"]
            })
            tags = []
            for d in ids:
                cat = drills[d]["category"]
                sec = drills[d].get("secondaryCategories") or []
                hit = "主" if cat in themed else ("副" if set(sec) & themed else "⛔")
                tags.append(f"{d.split('_')[1]}({hit}·{cat})")
            print(f"{plan_id:18} W{week['weekNumber']:2} 「{week['theme']}」"
                  f" ⊆ {sorted(themed)}: {' '.join(tags)}")

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
    print(f"本批 4 份计划引用 drill {len(referenced)} 条")
    print(f"全库 {len(index_ids)} 条中，10 份官方计划合计未引用 {len(unreferenced)} 条"
          + ("：" + ", ".join(d.replace("drill_", "") for d in unreferenced)
             if unreferenced else "（清零）"))
    print("\n--- 本批新纳入（W3a 后仍未引用的 16 条，逐条落位）---")
    w3a_remaining = [f"drill_c{n:03d}" for n in list(range(54, 62)) + list(range(64, 72))]
    for d in w3a_remaining:
        plans = sorted(p for p in all_refs.get(d, set()) if p in BATCH)
        print(f"  {d.replace('drill_', '')}: "
              + (", ".join(plans) if plans else "⛔ 仍未引用"))

    print("\n--- 检查计数 ---")
    for name, count in checked.items():
        print(f"{name}: {count} 次")
    print(f"\nFAIL {len(fails)}")
    for f in fails:
        print("  ⛔ " + f)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
