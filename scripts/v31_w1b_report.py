#!/usr/bin/env python3
"""v31 W1b 汇报表生成（只读）：从已写盘 JSON + 决策表理由生成三张交付表。

1. `build/v31-w1b-logs/dose-final.md`              逐 drill 最终剂量 + mode 判定依据（对照底稿表）
2. `build/v31-w1b-logs/secondary-categories.md`     副分类清单（真源 §六 P2，W5 前用户确认）
3. `build/v31-w1b-logs/combined-dose-proposal.md`   综合类/无序列 drill 量值建议表（真源 §六 P3）
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

from v31_w1b_apply_dose import (  # noqa: E402
    DECISIONS,
    GUARDRAIL_EXEMPT,
    NO_SEQ_TOTALS,
    REASONS,
    SECONDARY,
    SECONDARY_REASONS,
    SECONDARY_REJECTED,
    drill_path,
)

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "build" / "v31-w1b-logs"
DRAFT_CSV = REPO / "build" / "v31-dose-draft-w1b.csv"

# 综合类量值建议表覆盖范围：specialShots + combined 全类 + 本批内无序列/0 杆序列条目
PROPOSAL_IDS = [
    "drill_c054", "drill_c055", "drill_c056", "drill_c057", "drill_c058",
    "drill_c059", "drill_c060", "drill_c061",
    "drill_c064", "drill_c065", "drill_c066", "drill_c067", "drill_c068",
    "drill_c069", "drill_c070", "drill_c071",
]

UNIT = {
    "drill_c065": "局", "drill_c067": "局",
    "drill_c066": "次", "drill_c068": "次", "drill_c070": "次",
    "drill_c059": "次", "drill_c061": "次",
}


def draft_current_sets() -> dict[str, str]:
    rows = list(csv.DictReader(DRAFT_CSV.open(encoding="utf-8")))
    return {r["drillId"]: r["currentSets"] for r in rows}


def dose_of(drill_id: str) -> tuple[str, int, dict]:
    data = json.loads(drill_path(drill_id).read_text(encoding="utf-8"))
    sets = data["sets"]
    per = sets.get("perFormation") or []
    if per:
        detail = "<br>".join(
            f"`{d['token']}`:{d['mode']}×{d['ballsPerRound']}×{d['defaultRounds']}" for d in per
        )
        total = sum(d["ballsPerRound"] * d["defaultRounds"] for d in per)
    else:
        detail = f"（无 perFormation·§5.6.4 豁免）{sets['defaultSets']}×{sets['defaultBallsPerSet']}"
        total = sets["defaultSets"] * sets["defaultBallsPerSet"]
    return detail, total, data


def main() -> None:
    before = draft_current_sets()

    lines = [
        "# v31 W1b 最终剂量表（对照底稿 `build/v31-dose-draft-w1b.csv`）",
        "",
        "口径：契约 §5.6（`sequence` 型每轮球数锁死=序列实测杆数；`repetition` 型 10–15 人工定；"
        "总量护栏 40–60 球，轮数向下取，下限 1 轮；综合类按局/按次可豁免护栏并附理由）。",
        "",
        "| drillId | 主分类 | 改前 sets | 改后（逐球形 token:mode×每轮球数×轮数） | 总量 | mode 判定依据（R7 人工逐条） |",
        "|---|---|---|---|---|---|",
    ]
    for drill_id in DECISIONS:
        detail, total, data = dose_of(drill_id)
        mark = "" if 40 <= total <= 60 else "（越界·已豁免）"
        lines.append(
            f"| {drill_id} | {data['category']} | {before.get(drill_id, '?')} | {detail} "
            f"| {total}{mark} | {REASONS[drill_id]} |"
        )
    lines.append("")
    (OUT_DIR / "dose-final.md").write_text("\n".join(lines), encoding="utf-8")

    sec = [
        "# v31 W1b 副分类清单（R1 / 契约 §3.3）——待用户在 W5 前确认（真源 §六 P2）",
        "",
        "口径：每条 drill ≤1 个副分类；**只影响动作库浏览与筛选**，⛔ 不参与统计、不改文件目录、"
        "不在 `index.json` 产生第二条登记。",
        "",
        "| drillId | 名称 | 主分类 | 副分类 | 理由（据 drill 正文/判据） |",
        "|---|---|---|---|---|",
    ]
    for drill_id, category in SECONDARY.items():
        data = json.loads(drill_path(drill_id).read_text(encoding="utf-8"))
        sec.append(
            f"| {drill_id} | {data['nameZh']} | {data['category']} | **{category}** "
            f"| {SECONDARY_REASONS[drill_id]} |"
        )
    sec += [
        "",
        f"**本批合计 {len(SECONDARY)} 条**跨类标注；加上 W1a 定稿的 9 条，全库共 "
        f"**{len(SECONDARY) + 9} 条**（真源 R1 预算「15 条左右」）。",
        "",
        "## 评估后**未采纳**的候选（留档备查）",
        "",
        "| drillId | 名称 | 曾考虑的副分类 | 不采纳理由 |",
        "|---|---|---|---|",
    ]
    for drill_id, reason in SECONDARY_REJECTED.items():
        data = json.loads(drill_path(drill_id).read_text(encoding="utf-8"))
        sec.append(f"| {drill_id} | {data['nameZh']} | positioning / combined | {reason} |")
    sec.append("")
    (OUT_DIR / "secondary-categories.md").write_text("\n".join(sec), encoding="utf-8")

    prop = [
        "# v31 W1b 综合类与无序列 drill 量值建议表（真源 §六 P3，待用户确认）",
        "",
        "范围：`specialShots`(8) + `combined`(8) 全类，含本批内全部无序列 / 0 杆序列条目。",
        "已按本表建议值落 JSON；用户改口径后由后续批次调整（真源 §四 W1b 约定）。",
        "",
        "## 计量约定（本表两种口径并存，逐条标注）",
        "",
        "| 口径 | 适用 | `defaultSets` 含义 | `defaultBallsPerSet` 含义 | made 记什么 |",
        "|---|---|---|---|---|",
        "| 按球（默认） | 单杆/多档专项 | 轮数 | 每轮击球次数 | 该轮成功次数 |",
        "| 按局/按次 | Ghost、清台、开球、五球挑战 | 局数 / 次数 | 单局满清球数（或单次目标数） | 该局实际清台球数 |",
        "",
        "两种口径都符合契约 §5.1「N 次中成功 M 次」的单一录入原语，差别只在 `unitLabel`"
        "（W2 运行时派生：球 / 局 / 次）。",
        "",
        "| drillId | 名称 | 口径 | 改前 | 建议值 | 总量 | 护栏 | 理由 |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for drill_id in PROPOSAL_IDS:
        detail, total, data = dose_of(drill_id)
        unit = UNIT.get(drill_id, "球")
        if 40 <= total <= 60:
            guard = "✅ 40–60 内"
        else:
            guard = "⚠️ 越界·豁免"
        reason = GUARDRAIL_EXEMPT.get(drill_id, "") or REASONS[drill_id]
        prop.append(
            f"| {drill_id} | {data['nameZh']} | {unit} | {before.get(drill_id, '?')} | {detail} "
            f"| {total} | {guard} | {reason} |"
        )
    prop += [
        "",
        "## 无序列 / 0 杆序列条目单列（契约 §5.6.4 人工定量）",
        "",
        "| drillId | 有无序列 | 建议 `defaultSets` × `defaultBallsPerSet` | 依据 |",
        "|---|---|---|---|",
    ]
    for drill_id, (s, b) in NO_SEQ_TOTALS.items():
        data = json.loads(drill_path(drill_id).read_text(encoding="utf-8"))
        prop.append(f"| {drill_id} | 无序列（§8.5 I9 豁免） | {s} × {b} | {REASONS[drill_id]} |")
    prop.append(
        "| drill_c066 | 0 杆序列 `manual01`（仅摆球） | 1 × 10 | "
        + REASONS["drill_c066"]
        + " |"
    )
    prop += [
        "",
        "## 需要用户拍板的两个开放问题 —— ✅ 已裁定（2026-08-09 用户拍板）",
        "",
        "1. **c065 / c067 / c070 的「每局球数」取值** —— **裁定：c065 改为 8**"
        "（己方 7 颗 + 黑八，与 c070 口径对齐）；c067 = 9、c070 = 8 保持不变。"
        "已落 `drill_c065.json`：`defaultSets` 10 不变、`defaultBallsPerSet` 7 → 8，总量 70 → 80，"
        "按局豁免护栏的理由不变。",
        "2. **按局条目要不要拆成逐局一组** —— **裁定：维持每局一行**。"
        "保持「10 组 × 每局满清球数」，录入时每局一行、made 记该局清台球数"
        "（贴合 c065 criteria「记录每局清台球数」）；⛔ 不改成「1 组 × 10 局、made 记赢局数」。",
        "",
    ]
    (OUT_DIR / "combined-dose-proposal.md").write_text("\n".join(prop), encoding="utf-8")

    for name in ("dose-final.md", "secondary-categories.md", "combined-dose-proposal.md"):
        print(f"已生成 {OUT_DIR / name}")


if __name__ == "__main__":
    main()
