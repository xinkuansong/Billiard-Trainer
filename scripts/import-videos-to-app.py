#!/usr/bin/env python3
"""
⚠️ 归档（v25 W1）：引擎渲染视频已下线（D-v25-1），本脚本不再用于日常内容管线。
保留文件以便未来「真人示范」恢复时参考落位约定与 JSON `videos` 写入格式。
勿删除。

---
import-videos-to-app.py — _inbox 录屏复制并改名进入 QiuJi App Bundle

源：/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings/_inbox/drill_NNN/*.mp4
目标：QiuJi/Resources/Videos/drill_cNNN/take_MM.mp4
       （MM 按时间戳升序，01 起编号）

同时更新：每个 drill_cNNN.json 增加 "videos" 字段（仅当该 drill 有视频时）：
  "videos": [
    { "id": "take_01", "file": "take_01.mp4" },
    ...
  ]

规则：
- 文件改名为 take_NN.mp4（NN = 01..MM）便于 schema 引用
- 同一 drill 已有 take_NN.mp4 且大小一致则跳过 copy（幂等）
- 仅写入 index.json 中存在的 drill_cNNN
- 默认不删除目标多余文件；--prune 可清理目标里已不在源中的 take_NN.mp4
- 默认不重置 drill JSON 的 videos 字段；--rewrite-json 重写

用法：
  python3 scripts/import-videos-to-app.py             # 复制 + 更新 JSON
  python3 scripts/import-videos-to-app.py --dry-run   # 仅打印计划
  python3 scripts/import-videos-to-app.py --prune --rewrite-json   # 严格同步
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
INDEX_JSON = DRILLS_DIR / "index.json"
VIDEOS_DEST_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "Videos"

INBOX_DIR = Path("/Users/song/projects/15.tutorial_video/assets/raw/shooterspool-recordings/_inbox")

DRILL_DIR_RE = re.compile(r"^drill_(\d{3})$")
TAKE_RE = re.compile(r"^take_\d{2}\.mp4$")


def load_index() -> dict:
    return json.loads(INDEX_JSON.read_text())


def build_drill_to_category(index_data: dict) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for group in index_data["categories"]:
        cat = group["category"]
        for drill_id in group["drills"]:
            mapping[drill_id] = cat
    return mapping


def update_drill_json(drill_json_path: Path, takes: list[str], dry_run: bool, rewrite_json: bool) -> str:
    """
    更新 drill JSON 的 videos 字段。返回 'added' / 'updated' / 'unchanged' / 'missing'。
    """
    if not drill_json_path.is_file():
        return "missing"

    raw = drill_json_path.read_text()
    data = json.loads(raw)
    new_videos = [{"id": t, "file": f"{t}.mp4"} for t in takes]

    existing = data.get("videos")
    if existing == new_videos and not rewrite_json:
        return "unchanged"

    if existing is None:
        status = "added"
    else:
        status = "updated"

    data["videos"] = new_videos

    if not dry_run:
        text = json.dumps(data, ensure_ascii=False, indent=2)
        if not text.endswith("\n"):
            text += "\n"
        drill_json_path.write_text(text)

    return status


def sync_drill_videos(
    drill_inbox_dir: Path,
    drill_cid: str,
    dest_dir: Path,
    dry_run: bool,
    prune: bool,
) -> tuple[list[str], int, int, int]:
    """
    将源 mp4（按时间戳升序）复制并改名为 take_NN.mp4。
    返回 (final_take_ids, copied_count, skipped_count, pruned_count)。
    """
    src_files = sorted(drill_inbox_dir.glob("*.mp4"), key=lambda p: p.name)
    take_ids = [f"take_{i + 1:02d}" for i in range(len(src_files))]
    plan = list(zip(src_files, take_ids, strict=True))

    if plan and not dry_run:
        dest_dir.mkdir(parents=True, exist_ok=True)

    copied = 0
    skipped = 0
    for src, take_id in plan:
        dest = dest_dir / f"{take_id}.mp4"
        if dest.exists() and dest.stat().st_size == src.stat().st_size:
            skipped += 1
            continue
        if dry_run:
            print(f"    [dry-run] cp {src.name} → {drill_cid}/{take_id}.mp4")
        else:
            shutil.copy2(src, dest)
        copied += 1

    pruned = 0
    if prune and dest_dir.is_dir():
        keep = {f"{tid}.mp4" for tid in take_ids}
        for existing in dest_dir.iterdir():
            if not existing.is_file():
                continue
            if not TAKE_RE.match(existing.name):
                continue
            if existing.name not in keep:
                if dry_run:
                    print(f"    [dry-run] rm {drill_cid}/{existing.name}")
                else:
                    existing.unlink()
                pruned += 1

    return take_ids, copied, skipped, pruned


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不实际复制 / 改 JSON")
    parser.add_argument("--prune", action="store_true", help="删除目标目录中已不在源中的 take_NN.mp4")
    parser.add_argument("--rewrite-json", action="store_true", help="即使 videos 字段未变也重写一遍")
    args = parser.parse_args()

    if not INBOX_DIR.is_dir():
        print(f"❌ Inbox 不存在: {INBOX_DIR}", file=sys.stderr)
        return 1
    if not INDEX_JSON.is_file():
        print(f"❌ index.json 不存在: {INDEX_JSON}", file=sys.stderr)
        return 1

    index_data = load_index()
    drill_to_cat = build_drill_to_category(index_data)

    inbox_drills = sorted(
        p for p in INBOX_DIR.iterdir() if p.is_dir() and DRILL_DIR_RE.match(p.name)
    )

    total_copied = 0
    total_skipped = 0
    total_pruned = 0
    json_added = 0
    json_updated = 0
    json_unchanged = 0
    json_missing = 0
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
            continue

        videos = sorted(drill_dir.glob("*.mp4"))
        if not videos:
            continue

        drill_count += 1
        dest_dir = VIDEOS_DEST_ROOT / drill_cid
        print(f"→ {drill_dir.name} ({len(videos)} 段) → Videos/{drill_cid}/")
        take_ids, copied, skipped, pruned = sync_drill_videos(
            drill_dir, drill_cid, dest_dir, args.dry_run, args.prune
        )
        total_copied += copied
        total_skipped += skipped
        total_pruned += pruned

        drill_json_path = DRILLS_DIR / category / f"{drill_cid}.json"
        status = update_drill_json(drill_json_path, take_ids, args.dry_run, args.rewrite_json)
        if status == "added":
            json_added += 1
        elif status == "updated":
            json_updated += 1
        elif status == "unchanged":
            json_unchanged += 1
        elif status == "missing":
            json_missing += 1
            print(f"    ⚠️  {drill_json_path} 不存在")

    print()
    print("─" * 60)
    print(f"  App Bundle 视频导入完成{'（dry-run）' if args.dry_run else ''}")
    print(f"  涉及 drill 数：      {drill_count}")
    print(f"  视频复制：           {total_copied}（跳过 {total_skipped}，清理 {total_pruned}）")
    print(f"  JSON 新增 videos：    {json_added}")
    print(f"  JSON 更新 videos：    {json_updated}")
    print(f"  JSON 无变化：         {json_unchanged}")
    print(f"  JSON 缺失：           {json_missing}")
    print(f"  目标根：             {VIDEOS_DEST_ROOT}")
    print("─" * 60)
    if args.dry_run:
        print("ℹ️  这是 dry-run。去掉 --dry-run 后实际执行。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
