#!/usr/bin/env python3
"""
verify_tutorial_images.py — 校验 drill JSON 精讲 `image` 引用 vs DrillTutorials 磁盘文件

扫描 QiuJi/Resources/Drills/**/*.json 中 tutorial.sections / tutorial.formations[].sections
的 image 字段（不含扩展名），对照 QiuJi/Resources/DrillTutorials/ 下实际文件。

用法：
  python3 scripts/verify_tutorial_images.py
  python3 scripts/verify_tutorial_images.py --json   # 机器可读摘要

退出码：有失效引用则为 1，否则 0。
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
TUTORIALS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "DrillTutorials"


def collect_image_refs(drills_dir: Path | None = None) -> list[tuple[str, str, str]]:
    """Return list of (drill_id, image_stem, location_hint)."""
    refs: list[tuple[str, str, str]] = []
    for path in sorted((drills_dir or DRILLS_DIR).rglob("*.json")):
        if path.name == "index.json":
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        drill_id = data.get("id") or path.stem
        tutorial = data.get("tutorial")
        if not isinstance(tutorial, dict):
            continue

        sections = tutorial.get("sections")
        if isinstance(sections, list):
            for i, section in enumerate(sections):
                if not isinstance(section, dict):
                    continue
                image = section.get("image")
                if isinstance(image, str) and image.strip():
                    refs.append((drill_id, image.strip(), f"sections[{i}]"))

        formations = tutorial.get("formations")
        if isinstance(formations, list):
            for form in formations:
                if not isinstance(form, dict):
                    continue
                fid = form.get("id", "?")
                for i, section in enumerate(form.get("sections") or []):
                    if not isinstance(section, dict):
                        continue
                    image = section.get("image")
                    if isinstance(image, str) and image.strip():
                        refs.append(
                            (drill_id, image.strip(), f"formations[{fid}].sections[{i}]")
                        )
    return refs


def tutorial_basenames() -> set[str]:
    """Basenames present under DrillTutorials (any extension)."""
    if not TUTORIALS_ROOT.is_dir():
        return set()
    names: set[str] = set()
    for p in TUTORIALS_ROOT.iterdir():
        if p.is_file() and not p.name.startswith("."):
            names.add(p.name)
            names.add(p.stem)
    return names


def resolve_exists(image: str, available: set[str]) -> bool:
    if image in available:
        return True
    if f"{image}.png" in available:
        return True
    if f"{image}.heic" in available:
        return True
    if f"{image}.jpg" in available or f"{image}.jpeg" in available:
        return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="Emit JSON summary")
    args = ap.parse_args()

    refs = collect_image_refs()
    available = tutorial_basenames()
    missing: list[tuple[str, str, str]] = []
    for drill_id, image, hint in refs:
        if not resolve_exists(image, available):
            missing.append((drill_id, image, hint))

    by_drill: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for drill_id, image, hint in missing:
        by_drill[drill_id].append((image, hint))

    summary = {
        "total_refs": len(refs),
        "missing_refs": len(missing),
        "drills_with_missing": len(by_drill),
        "missing_by_drill": {
            did: [{"image": img, "at": hint} for img, hint in items]
            for did, items in sorted(by_drill.items())
        },
    }

    if args.json:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
    else:
        print(f"总引用数: {summary['total_refs']}")
        print(f"失效数:   {summary['missing_refs']}")
        print(f"涉及 drill: {summary['drills_with_missing']}")
        if by_drill:
            print("\n按 drill 分组的失效清单:")
            for did, items in sorted(by_drill.items()):
                print(f"  {did} ({len(items)})")
                for img, hint in items:
                    print(f"    - {img}  @ {hint}")

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
