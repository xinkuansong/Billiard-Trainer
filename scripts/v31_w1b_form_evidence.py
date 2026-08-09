#!/usr/bin/env python3
"""v31 W1b 形态判定证据提取（只读脚本，不下结论）。

R7 要求 mode 人工逐条判定。本脚本只提供**可核对的客观证据**，避免脑算：

1. **连续性检验**（走位链 vs 独立阶梯的决定性判据）：
   逐杆比对 `steps[i].after.onTable` 与 `steps[i+1].before.onTable`。
   - 台上球集合从 after 到下一杆 before 只少不多、母球位置延续 ⇒ 走位链（sequence）；
   - 每杆 before 都「重摆」（球数回升 / 母球被搬回起手区）⇒ 独立阶梯（repetition）。
2. `tutorial.tutorialKind` 与 section 标题结构（`第N杆` 节数）；
3. 逐杆 targetKey / pocket（freeAim 空串比例）。

输出 build/v31-w1b-logs/form-evidence.md（+ JSON）。
"""

from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DRILLS_DIR = REPO / "QiuJi" / "Resources" / "Drills"
SEQ_DIR = REPO / "content" / "position_play" / "sequences"
OUT_DIR = REPO / "build" / "v31-w1b-logs"

BATCH_CATEGORIES = ["separation", "positioning", "specialShots", "combined"]
SHOT_TITLE_RE = re.compile(r"^第.+杆")


def load_index() -> dict[str, list[str]]:
    data = json.loads((DRILLS_DIR / "index.json").read_text(encoding="utf-8"))
    return {g["category"]: list(g["drills"]) for g in data["categories"]}


def sequences_by_drill(drill_ids: set[str]) -> dict[str, list[Path]]:
    buckets: dict[str, list[Path]] = defaultdict(list)
    for path in sorted(SEQ_DIR.glob("*.json")):
        for drill_id in drill_ids:
            if path.name.startswith(drill_id + "__") or path.name.startswith(drill_id + "-"):
                buckets[drill_id].append(path)
                break
    return buckets


def token_of(path: Path, drill_id: str) -> str:
    marker = drill_id + "__"
    if not path.name.startswith(marker):
        return ""
    return path.name[len(marker):].split("-", 1)[0]


def analyse_sequence(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    steps = data.get("steps", [])
    links: list[str] = []
    for i in range(len(steps) - 1):
        after = steps[i].get("after", {}).get("onTable", {})
        nxt = steps[i + 1].get("before", {}).get("onTable", {})
        after_balls = set(after) - {"cueBall"}
        next_balls = set(nxt) - {"cueBall"}
        cue_a = after.get("cueBall")
        cue_b = nxt.get("cueBall")
        cue_same = (
            cue_a is not None
            and cue_b is not None
            and abs(cue_a["x"] - cue_b["x"]) < 1e-6
            and abs(cue_a["y"] - cue_b["y"]) < 1e-6
        )
        balls_same = after_balls == next_balls
        if cue_same and balls_same:
            links.append("链")          # 完全延续：母球与台上球都接上
        elif balls_same:
            links.append("球同/母球移")  # 台上球接上但母球被搬动
        elif next_balls < after_balls:
            links.append("球减")        # 台上球继续减少（仍属推进）
        elif next_balls > after_balls:
            links.append("重摆")        # 台上球回升 ⇒ 重置
        else:
            links.append("换形")        # 台上球集合互不包含 ⇒ 换盘面
    return {
        "file": path.name,
        "shots": len(steps),
        "links": links,
        "chainRatio": (links.count("链") + links.count("球减")) / len(links) if links else None,
        "targets": [
            (s.get("targetKey") or "", s.get("pocket") or "") for s in steps
        ],
        "ballCounts": [
            len(set(s.get("before", {}).get("onTable", {})) - {"cueBall"}) for s in steps
        ],
    }


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    index = load_index()
    batch = [(c, d) for c in BATCH_CATEGORIES for d in index[c]]
    seqs = sequences_by_drill({d for _, d in batch})

    report: dict = {}
    lines = ["# v31 W1b 形态判定证据（脚本实测，不含结论）", ""]
    lines.append(
        "连续性标记含义：`链`=母球+台上球完全延续；`球减`=台上球继续减少；"
        "`球同/母球移`=台上球同但母球被搬动；`重摆`=台上球回升（重置）；`换形`=盘面互不包含。"
    )
    lines.append("")
    for cat, drill_id in batch:
        drill = json.loads((DRILLS_DIR / cat / f"{drill_id}.json").read_text(encoding="utf-8"))
        tut = drill.get("tutorial") or {}
        kind = tut.get("tutorialKind", "(无)")
        if "formations" in tut:
            shot_sections = {
                f.get("id", "?"): sum(
                    1 for s in f.get("sections", []) if SHOT_TITLE_RE.match(s.get("title", ""))
                )
                for f in tut["formations"]
            }
        else:
            shot_sections = {
                "-": sum(
                    1 for s in tut.get("sections", []) if SHOT_TITLE_RE.match(s.get("title", ""))
                )
            }
        entries = [analyse_sequence(p) for p in seqs.get(drill_id, [])]
        report[drill_id] = {
            "category": cat,
            "nameZh": drill.get("nameZh"),
            "tutorialKind": kind,
            "shotSections": shot_sections,
            "sequences": [
                {"token": token_of(SEQ_DIR / e["file"], drill_id), **e} for e in entries
            ],
        }
        lines.append(f"## {drill_id} [{cat}] {drill.get('nameZh')}")
        lines.append("")
        lines.append(f"- `tutorialKind`：{kind}；逐杆节数：{shot_sections}")
        lines.append(f"- `standardCriteria`：{drill.get('standardCriteria')}")
        if not entries:
            lines.append("- 序列：**无**（豁免几何校验）")
        for e in entries:
            token = token_of(SEQ_DIR / e["file"], drill_id)
            ratio = "-" if e["chainRatio"] is None else f"{e['chainRatio']:.2f}"
            lines.append(
                f"- 球形 `{token}`：实测 **{e['shots']} 杆**；连续性 [{' '.join(e['links'])}]"
                f"（链+球减占比 {ratio}）"
            )
            lines.append(f"  - 台上球数逐杆：{e['ballCounts']}")
            lines.append(
                "  - 逐杆 target/pocket："
                + "、".join(f"{t or '∅'}/{p or '∅'}" for t, p in e["targets"])
            )
        lines.append("")

    (OUT_DIR / "form-evidence.md").write_text("\n".join(lines), encoding="utf-8")
    (OUT_DIR / "form-evidence.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("\n".join(lines))


if __name__ == "__main__":
    main()
