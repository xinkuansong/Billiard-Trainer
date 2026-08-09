#!/usr/bin/env python3
"""v31 W1a 汇报表生成（只读）：从已写盘 JSON + 决策表理由生成两张交付表。

1. `build/v31-w1a-logs/dose-final.md`  逐 drill 最终剂量 + mode 判定依据（对照底稿表）
2. `build/v31-w1a-logs/secondary-categories.md`  副分类清单（供用户在 W5 前确认，真源 §六 P2）
"""

from __future__ import annotations

import csv
import json
from pathlib import Path

from v31_w1a_apply_dose import (  # noqa: E402
    DECISIONS,
    REASONS,
    SECONDARY,
    SECONDARY_REASONS,
    SECONDARY_REJECTED,
    drill_path,
)

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "build" / "v31-w1a-logs"
DRAFT_CSV = REPO / "build" / "v31-dose-draft.csv"


def draft_current_sets() -> dict[str, str]:
    rows = list(csv.DictReader(DRAFT_CSV.open(encoding="utf-8")))
    return {r["drillId"]: r["currentSets"] for r in rows}


def main() -> None:
    before = draft_current_sets()
    lines = [
        "# v31 W1a 最终剂量表（对照底稿 `build/v31-dose-draft.csv`）",
        "",
        "口径：契约 §5.6（`sequence` 型每轮球数锁死=序列实测杆数；`repetition` 型 10–15 人工定；"
        "总量护栏 40–60 球，轮数向下取，下限 1 轮）。",
        "",
        "| drillId | 主分类 | 改前 sets | 改后（逐球形 token:mode×每轮球数×轮数） | 总量 | mode 判定依据（R7 人工逐条） |",
        "|---|---|---|---|---|---|",
    ]
    for drill_id in DECISIONS:
        path = drill_path(drill_id)
        data = json.loads(path.read_text(encoding="utf-8"))
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
        lines.append(
            f"| {drill_id} | {data['category']} | {before.get(drill_id, '?')} | {detail} "
            f"| {total} | {REASONS[drill_id]} |"
        )
    lines.append("")
    (OUT_DIR / "dose-final.md").write_text("\n".join(lines), encoding="utf-8")

    sec = [
        "# v31 W1a 副分类清单（R1 / 契约 §3.3）——待用户在 W5 前确认（真源 §六 P2）",
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
    sec.append("")
    sec.append(f"**本批合计 {len(SECONDARY)} 条**跨类标注（真源 R1 全库预算「15 条左右」）。")
    sec.append("")
    sec.append("## 评估后**未采纳**的真源候选（留档备查）")
    sec.append("")
    sec.append("| drillId | 名称 | 真源建议 | 不采纳理由 |")
    sec.append("|---|---|---|---|")
    for drill_id, reason in SECONDARY_REJECTED.items():
        data = json.loads(drill_path(drill_id).read_text(encoding="utf-8"))
        sec.append(f"| {drill_id} | {data['nameZh']} | +positioning | {reason} |")
    sec.append("")
    (OUT_DIR / "secondary-categories.md").write_text("\n".join(sec), encoding="utf-8")
    print(f"已生成 {OUT_DIR/'dose-final.md'}")
    print(f"已生成 {OUT_DIR/'secondary-categories.md'}")


if __name__ == "__main__":
    main()
