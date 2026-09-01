#!/usr/bin/env python3
"""Collect the evidence inventory required before editing one Drill's learner copy."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterator


REPO = Path(__file__).resolve().parents[4]
DRILL_ROOT = REPO / "QiuJi" / "Resources" / "Drills"
MASTER_ROOT = REPO / "QiuJi" / "Resources" / "DrillTutorials"
PUBLISH_ROOT = REPO / "QiuJi" / "Resources" / "TutorialFigures"
SEQUENCE_ROOT = REPO / "content" / "position_play" / "sequences"
PROFILE_ROOT = REPO / "content" / "drill_profiles"
INTENT_TABLE = REPO / "docs" / "research" / "20260819-动作库球形训练意图.md"

LEARNER_FIELDS = (
    "nameZh",
    "description",
    "coachingPoints",
    "standardCriteria",
    "sets",
)


def normalize_id(raw: str) -> tuple[str, str]:
    value = raw.strip()
    if value.startswith("drill_"):
        drill_id = value
        short_id = value.removeprefix("drill_")
    else:
        short_id = value
        drill_id = f"drill_{value}"
    if not short_id.startswith("c") or not short_id[1:].isdigit():
        raise ValueError("ID 应为 c001 或 drill_c001 形式")
    return drill_id, short_id


def relative(path: Path) -> str:
    return str(path.relative_to(REPO))


def find_drill(drill_id: str) -> Path:
    matches = sorted(DRILL_ROOT.glob(f"*/{drill_id}.json"))
    if len(matches) != 1:
        found = ", ".join(relative(path) for path in matches) or "无"
        raise FileNotFoundError(f"预期唯一 Drill JSON，实际：{found}")
    return matches[0]


def intent_rows(short_id: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in INTENT_TABLE.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and cells[0] == short_id:
            rows.append(cells)
    return rows


def walk_images(node: Any, location: str = "tutorial") -> Iterator[tuple[str, str]]:
    if isinstance(node, dict):
        for key, value in node.items():
            child = f"{location}.{key}"
            if key == "image" and isinstance(value, str):
                yield child, value
            else:
                yield from walk_images(value, child)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from walk_images(value, f"{location}[{index}]")


def status(path: Path) -> str:
    return f"存在 · {relative(path)}" if path.is_file() else f"缺失 · {relative(path)}"


def print_context(drill_id: str, short_id: str, drill_path: Path, data: dict[str, Any]) -> None:
    print(f"# {drill_id} 文案证据清单")
    print(f"\nDrill JSON：{relative(drill_path)}")

    print("\n## 当前字段")
    for field in LEARNER_FIELDS:
        print(f"- {field}: {json.dumps(data.get(field), ensure_ascii=False)}")

    print("\n## 用户训练意图")
    rows = intent_rows(short_id)
    if not rows:
        print("- 缺失：意图表没有该 ID")
    for cells in rows:
        padded = cells + [""] * (7 - len(cells))
        _, name, level, formation_index, formation, original, refined = padded[:7]
        print(f"- {formation_index} · {formation}（{name} / {level}）")
        print(f"  - 训练意图原文：{original or '（空）'}")
        print(f"  - 完善：{refined or '（空）'}")

    profile = PROFILE_ROOT / f"{drill_id}.profile.json"
    print("\n## 变量档案")
    print(f"- {status(profile)}")

    print("\n## 序列")
    sequences = sorted(SEQUENCE_ROOT.glob(f"{drill_id}__*.json"))
    if not sequences:
        print("- 缺失：未找到序列")
    for sequence in sequences:
        print(f"- {relative(sequence)}")

    print("\n## JSON 实际引用的图片")
    images = list(walk_images(data.get("tutorial", {})))
    if not images:
        print("- 缺失：tutorial 没有 image 引用")
    for location, key in images:
        master = MASTER_ROOT / f"{key}.png"
        published = PUBLISH_ROOT / f"{key}.heic"
        print(f"- {location}: {key}")
        print(f"  - PNG 母版：{status(master)}")
        print(f"  - HEIC 发布图：{status(published)}")

    print("\n## 动笔前人工动作")
    print("- 逐张实际查看上述开局图与逐杆图；只列文件不算读图。")
    print("- 对每条序列运行 scripts/tutorial_digest.py，几何与参数只从事实清单取值。")
    print("- 填写证据卡；若意图、图片、序列冲突，停止写作并报告。")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("drill_id", help="c001 或 drill_c001")
    args = parser.parse_args()
    try:
        drill_id, short_id = normalize_id(args.drill_id)
        drill_path = find_drill(drill_id)
        data = json.loads(drill_path.read_text(encoding="utf-8"))
        print_context(drill_id, short_id, drill_path, data)
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
