#!/usr/bin/env python3
"""
import-videos-stage1.py — _inbox 录屏按分类归位到 15.tutorial_video Stage 1 标准位置

源：/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings/_inbox/drill_NNN/*.mp4
目标：/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings/<category>/drill_cNNN/*.mp4

规则：
- drill_NNN  →  drill_cNNN （添加 c 前缀）
- 文件名保留原始时间戳（shot 标注留待人工后续处理）
- 分类来自 QiuJi/Resources/Drills/index.json
- 默认幂等：目标文件存在且大小一致则跳过
- _inbox 文件保留（不删除）

用法：
  python3 scripts/import-videos-stage1.py             # 实际执行
  python3 scripts/import-videos-stage1.py --dry-run   # 仅打印计划
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
INDEX_JSON = REPO_ROOT / "QiuJi" / "Resources" / "Drills" / "index.json"

INBOX_DIR = Path("/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings/_inbox")
STAGE1_ROOT = Path("/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings")

DRILL_DIR_RE = re.compile(r"^drill_(\d{3})$")


def load_drill_to_category() -> dict[str, str]:
    """读取 index.json，构建 drill_cNNN → category 映射。"""
    data = json.loads(INDEX_JSON.read_text())
    mapping: dict[str, str] = {}
    for group in data["categories"]:
        cat = group["category"]
        for drill_id in group["drills"]:
            mapping[drill_id] = cat
    return mapping


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不实际复制")
    args = parser.parse_args()

    if not INBOX_DIR.is_dir():
        print(f"❌ Inbox 不存在: {INBOX_DIR}", file=sys.stderr)
        return 1
    if not INDEX_JSON.is_file():
        print(f"❌ index.json 不存在: {INDEX_JSON}", file=sys.stderr)
        return 1

    drill_to_cat = load_drill_to_category()

    inbox_drills = sorted(
        p for p in INBOX_DIR.iterdir() if p.is_dir() and DRILL_DIR_RE.match(p.name)
    )

    total_copied = 0
    total_skipped = 0
    total_missing_mapping = 0
    drill_count = 0

    for drill_dir in inbox_drills:
        m = DRILL_DIR_RE.match(drill_dir.name)
        if not m:
            continue
        num = m.group(1)
        drill_cid = f"drill_c{num}"
        category = drill_to_cat.get(drill_cid)
        if category is None:
            print(f"⚠️  {drill_dir.name} → {drill_cid} 在 index.json 中无映射，跳过")
            total_missing_mapping += 1
            continue

        videos = sorted(drill_dir.glob("*.mp4"))
        if not videos:
            continue

        dest_dir = STAGE1_ROOT / category / drill_cid
        if not args.dry_run:
            dest_dir.mkdir(parents=True, exist_ok=True)

        drill_count += 1
        print(f"→ {drill_dir.name} ({len(videos)} 段) → {category}/{drill_cid}/")
        for src in videos:
            dest = dest_dir / src.name
            if dest.exists() and dest.stat().st_size == src.stat().st_size:
                total_skipped += 1
                continue
            if args.dry_run:
                print(f"    [dry-run] cp {src.name} → {dest}")
            else:
                shutil.copy2(src, dest)
            total_copied += 1

    print()
    print("─" * 60)
    print(f"  Stage 1 归位完成{'（dry-run）' if args.dry_run else ''}")
    print(f"  涉及 drill 数：       {drill_count}")
    print(f"  本次复制：            {total_copied} 段")
    print(f"  已存在跳过：          {total_skipped} 段")
    print(f"  index.json 中缺映射： {total_missing_mapping} 个")
    print(f"  目标根：              {STAGE1_ROOT}")
    print("─" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
