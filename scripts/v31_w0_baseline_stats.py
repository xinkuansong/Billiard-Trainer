#!/usr/bin/env python3
"""v31 W0 底账重取：drill / 球形 / 序列 / 计划引用的实测统计。

真源口径（`.kiro/steering/content-data-contract.md`）：
- drill 清单以 `QiuJi/Resources/Drills/index.json` 为准（App 实际加载集合）；
- 球形数以 `content/position_play/sequences/*.json` 为准（§1.1 球形几何真源），
  归属判定按 §3.2 文件名协议做前缀 + 分隔符匹配，禁止子串误匹配；
- 计划引用以 `QiuJi/Resources/Plans/plan_*.json` 为准。

只读脚本，不写任何内容文件。输出 Markdown + JSON 到 build/v31-w0-logs/。
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
PLANS_DIR = REPO / "QiuJi" / "Resources" / "Plans"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"
OUT_DIR = REPO / "build" / "v31-w0-logs"

SHOT_COUNT_RE = re.compile(r"-(\d+)杆\.json$")


def load_index() -> dict[str, list[str]]:
    data = json.loads((DRILLS_DIR / "index.json").read_text(encoding="utf-8"))
    return {group["category"]: list(group["drills"]) for group in data["categories"]}


def sequence_files_by_drill(drill_ids: list[str]) -> dict[str, list[Path]]:
    """按契约 §3.2 归属判定：`<drillId>__<token>-…` 或 `<drillId>-…`。"""
    buckets: dict[str, list[Path]] = defaultdict(list)
    known = set(drill_ids)
    for path in sorted(SEQ_DIR.glob("*.json")):
        name = path.name
        for drill_id in known:
            if name.startswith(drill_id + "__") or name.startswith(drill_id + "-"):
                buckets[drill_id].append(path)
                break
    return buckets


def token_of(path: Path, drill_id: str) -> str:
    """token = `__` 与下一个 `-` 之间的段；旧式单序列为空串（同 DrillTryoutBoardStore）。"""
    name = path.name
    marker = drill_id + "__"
    if not name.startswith(marker):
        return ""
    rest = name[len(marker):]
    return rest.split("-", 1)[0]


def shot_count_of(path: Path) -> int | None:
    match = SHOT_COUNT_RE.search(path.name)
    return int(match.group(1)) if match else None


def plan_references() -> tuple[Counter, dict[str, list[str]]]:
    counts: Counter = Counter()
    by_plan: dict[str, list[str]] = {}
    for plan_path in sorted(PLANS_DIR.glob("plan_*.json")):
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        seen: list[str] = []
        for week in plan.get("weeks", []):
            for session in week.get("sessions", []):
                for phase in session.get("phases", []):
                    for ref in phase.get("drills", []):
                        counts[ref["drillId"]] += 1
                        if ref["drillId"] not in seen:
                            seen.append(ref["drillId"])
        by_plan[plan_path.stem] = seen
    return counts, by_plan


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    index = load_index()
    all_ids = [drill_id for ids in index.values() for drill_id in ids]

    sequences = sequence_files_by_drill(all_ids)
    formations = {
        drill_id: [
            {
                "token": token_of(path, drill_id),
                "shots": shot_count_of(path),
                "file": path.name,
            }
            for path in sequences.get(drill_id, [])
        ]
        for drill_id in all_ids
    }

    multi = {d: f for d, f in formations.items() if len(f) >= 2}
    no_seq = [d for d in all_ids if not formations[d]]
    ref_counts, by_plan = plan_references()
    unreferenced = [d for d in all_ids if ref_counts[d] == 0]
    dangling = sorted(set(ref_counts) - set(all_ids))

    report: dict = {
        "drillTotal": len(all_ids),
        "categoryCounts": {c: len(ids) for c, ids in index.items()},
        "multiFormationCount": len(multi),
        "multiFormationDrills": {
            d: [{"token": f["token"], "shots": f["shots"]} for f in fs]
            for d, fs in sorted(multi.items())
        },
        "noSequenceCount": len(no_seq),
        "noSequenceDrills": no_seq,
        "sequenceFileTotal": sum(len(v) for v in sequences.values()),
        "planCount": len(by_plan),
        "unreferencedCount": len(unreferenced),
        "unreferencedDrills": unreferenced,
        "danglingPlanRefs": dangling,
        "topReferenced": ref_counts.most_common(5),
    }
    (OUT_DIR / "baseline-stats.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    lines: list[str] = ["# v31 W0 底账重取（脚本实测）", ""]
    lines.append(f"- drill 总数：**{report['drillTotal']}** 条 / {len(index)} 分类")
    lines.append("- 分类分布：" + "、".join(
        f"{c} {n}" for c, n in report["categoryCounts"].items()
    ))
    lines.append(
        f"- 序列文件总数：{report['sequenceFileTotal']}（覆盖 "
        f"{report['drillTotal'] - report['noSequenceCount']} 条 drill）"
    )
    lines.append("")
    lines.append(f"## 多球形 drill（≥2 球形）：{report['multiFormationCount']} 条")
    lines.append("")
    lines.append("| drillId | 球形数 | token（杆数） |")
    lines.append("|---|---|---|")
    for drill_id, fs in sorted(multi.items()):
        detail = "、".join(f"{f['token']}({f['shots']}杆)" for f in fs)
        lines.append(f"| {drill_id} | {len(fs)} | {detail} |")
    lines.append("")
    lines.append(f"## 无序列 drill：{report['noSequenceCount']} 条")
    lines.append("")
    lines.append("、".join(no_seq) if no_seq else "（无）")
    lines.append("")
    lines.append(
        f"## 从未被任何官方计划引用：{report['unreferencedCount']} 条"
        f"（共 {report['planCount']} 份计划）"
    )
    lines.append("")
    lines.append("、".join(unreferenced) if unreferenced else "（无）")
    lines.append("")
    if dangling:
        lines.append(f"⚠️ 计划引用了 index 之外的 drillId：{'、'.join(dangling)}")
        lines.append("")
    lines.append("## 引用次数 Top 5")
    lines.append("")
    for drill_id, count in report["topReferenced"]:
        lines.append(f"- {drill_id}：{count} 次")
    lines.append("")

    (OUT_DIR / "baseline-stats.md").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
