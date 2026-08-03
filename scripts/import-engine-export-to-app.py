#!/usr/bin/env python3
"""
import-engine-export-to-app.py — 引擎出片产物回填进 App Bundle（本地预览用）

源：build/position_play_export/<exportDir>/
  - full.mp4 / full_3d.mp4 / full.gif
  - initial.png / sNN_still.png / final.png
  - cover.png / preview/（可选）

目标：
  - QiuJi/Resources/Videos/<drillId>/…          （替换旧 take_*.mp4）
  - QiuJi/Resources/DrillTutorials/<drillId>_… （静帧）
  - QiuJi/Resources/Previews/<assetKey>/…      （卡片预览帧，可选）
  - 各 drill JSON 的 videos[] 重写为引擎片引用

命名：
  - 单序列 drill：full.mp4 / full_3d.mp4 / full.gif
  - 多序列 drill：以 `__` 后、`-` 前的 token 为前缀
      例 drill_c077__A3-… → A3_full.mp4 / A3_full_3d.mp4
  - 静帧：引擎出片 `sNN_still.png` → 落位 `<drillId>_sNN.png`（去掉 `_still`，
    与 content-engineering SKILL / JSON `image` 约定一致，D-v25-6）
  - `manual01` 默认别名：token 为 `manual01` 时，额外写入无 token 前缀的副本
    （`<drillId>_initial.png` / `<drillId>_sNN.png`），供 JSON 未写 manual 前缀时使用
  - seq_* 目录默认跳过（除非 --include-seq）；c042 历史 demo 用 drill 序列，不靠 seq_f4ded688

用法：
  python3 scripts/import-engine-export-to-app.py --dry-run
  python3 scripts/import-engine-export-to-app.py --prune
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

STILL_STEP_RE = re.compile(r"^(s\d{2})_still$")
MANUAL01_TOKEN = "manual01"

REPO_ROOT = Path(__file__).resolve().parents[1]
EXPORT_ROOT = REPO_ROOT / "build" / "position_play_export"
DRILLS_DIR = REPO_ROOT / "QiuJi" / "Resources" / "Drills"
INDEX_JSON = DRILLS_DIR / "index.json"
VIDEOS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "Videos"
TUTORIALS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "DrillTutorials"
PREVIEWS_ROOT = REPO_ROOT / "QiuJi" / "Resources" / "Previews"

DRILL_DIR_RE = re.compile(r"^(drill_c\d{3})(?:__(.+))?$")
# export dir = full basename of sequence file without .json
# e.g. drill_c077__A3-中大角度带塞进袋 · 球形3-0杆  OR drill_c001-半台直线球-1杆


def load_index_ids() -> set[str]:
    data = json.loads(INDEX_JSON.read_text())
    ids: set[str] = set()
    for group in data.get("categories", []):
        ids.update(group.get("drills", []))
    return ids


def find_drill_json(drill_id: str) -> Path | None:
    matches = list(DRILLS_DIR.rglob(f"{drill_id}.json"))
    return matches[0] if matches else None


def parse_export_dir(name: str) -> tuple[str, str] | None:
    """Return (drill_id, variant_token) or None if not a drill export."""
    if name.startswith("seq_"):
        return None
    # Strip trailing "-<title>-<N>杆" by splitting on first '-' after drill/token part.
    # Prefer __token form.
    m = re.match(r"^(drill_c\d{3})(?:__([^-]+))?(?:-.*)?$", name)
    if not m:
        return None
    drill_id = m.group(1)
    token = m.group(2) or "main"
    # sanitize token for filenames
    token = re.sub(r"[^\w.\-]+", "_", token, flags=re.UNICODE)
    return drill_id, token


def copy_file(src: Path, dst: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"  COPY {src} → {dst}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def still_dest_stem(src_stem: str) -> str:
    """Map export still stem → DrillTutorials stem (strip `_still`, idempotent).

    Engine writes `s01_still.png`; JSON / SKILL expect `…_s01.png`.
    Already-stripped stems (`s01`, `initial`, `final`) pass through unchanged.
    """
    m = STILL_STEP_RE.fullmatch(src_stem)
    if m:
        return m.group(1)
    if src_stem.endswith("_still"):
        # defensive: any other `*_still` → strip once
        return src_stem[: -len("_still")]
    return src_stem


def import_one(
    export_dir: Path,
    drill_id: str,
    token: str,
    multi: bool,
    dry_run: bool,
) -> list[dict]:
    """Copy media; return videos[] entries for this variant."""
    prefix = f"{token}_" if multi else ""
    video_entries: list[dict] = []

    dest_videos = VIDEOS_ROOT / drill_id
    mapping = [
        ("full.mp4", f"{prefix}full.mp4", f"{prefix}full" if multi else "full"),
        ("full_3d.mp4", f"{prefix}full_3d.mp4", f"{prefix}full3d" if multi else "full3d"),
        ("full.gif", f"{prefix}full.gif", None),  # gif 进 Videos，不进 videos[]（详情页播 mp4）
    ]
    for src_name, dst_name, vid_id in mapping:
        src = export_dir / src_name
        if not src.is_file():
            print(f"  ⚠️ missing {src_name} in {export_dir.name}")
            continue
        copy_file(src, dest_videos / dst_name, dry_run)
        if vid_id:
            video_entries.append({"id": vid_id, "file": dst_name})

    # Stills → DrillTutorials（去掉 sNN_still 的 `_still`；与 JSON image 约定对齐）
    still_prefix = f"{drill_id}_{token}_" if multi else f"{drill_id}_"
    write_manual01_alias = token == MANUAL01_TOKEN
    for src in sorted(export_dir.glob("*.png")):
        if src.name in {"cover.png"}:
            continue
        if src.name.startswith("preview"):
            continue
        dest_stem = still_dest_stem(src.stem)  # initial / s01 / final
        primary = TUTORIALS_ROOT / f"{still_prefix}{dest_stem}.png"
        copy_file(src, primary, dry_run)
        # 默认取 manual01：JSON 未写 manual 前缀时指向无 token 文件名
        if write_manual01_alias:
            alias = TUTORIALS_ROOT / f"{drill_id}_{dest_stem}.png"
            if alias != primary:
                copy_file(src, alias, dry_run)

    # Preview frames
    preview_src = export_dir / "preview"
    if preview_src.is_dir():
        asset_key = f"{drill_id}_{token}" if multi else drill_id
        for frame in sorted(preview_src.glob("frame_*.png")):
            copy_file(frame, PREVIEWS_ROOT / asset_key / frame.name, dry_run)
        cover = export_dir / "cover.png"
        if cover.is_file():
            copy_file(cover, PREVIEWS_ROOT / asset_key / "cover.png", dry_run)

    return video_entries


def rewrite_videos(drill_id: str, videos: list[dict], dry_run: bool) -> str:
    path = find_drill_json(drill_id)
    if path is None:
        return "missing_json"
    data = json.loads(path.read_text())
    if data.get("videos") == videos:
        return "unchanged"
    data["videos"] = videos
    if not dry_run:
        text = json.dumps(data, ensure_ascii=False, indent=2)
        if not text.endswith("\n"):
            text += "\n"
        path.write_text(text)
    return "updated"


def prune_videos(drill_id: str, keep_files: set[str], dry_run: bool) -> int:
    dest = VIDEOS_ROOT / drill_id
    if not dest.is_dir():
        return 0
    removed = 0
    for p in dest.iterdir():
        if not p.is_file():
            continue
        if p.name in keep_files:
            continue
        print(f"  PRUNE {p}")
        if not dry_run:
            p.unlink()
        removed += 1
    return removed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--prune", action="store_true", help="删除目标目录中未回填的旧 take_*/旧文件")
    ap.add_argument("--include-seq", action="store_true", help="也处理 seq_* 目录（默认跳过）")
    args = ap.parse_args()

    if not EXPORT_ROOT.is_dir():
        print(f"无出片目录: {EXPORT_ROOT}", file=sys.stderr)
        return 1

    index_ids = load_index_ids()
    # group export dirs by drill
    by_drill: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    skipped = 0
    for d in sorted(EXPORT_ROOT.iterdir()):
        if not d.is_dir() or d.name.startswith("."):
            continue
        if d.name.startswith("seq_") and not args.include_seq:
            skipped += 1
            continue
        parsed = parse_export_dir(d.name)
        if parsed is None:
            print(f"SKIP unparsed {d.name}")
            skipped += 1
            continue
        drill_id, token = parsed
        if drill_id not in index_ids:
            print(f"SKIP not in index: {drill_id} ({d.name})")
            skipped += 1
            continue
        # require at least full.mp4
        if not (d / "full.mp4").is_file():
            print(f"SKIP incomplete (no full.mp4): {d.name}")
            skipped += 1
            continue
        by_drill[drill_id].append((token, d))

    print(f"将回填 {len(by_drill)} 个 drill（跳过 {skipped} 个目录） dry_run={args.dry_run}")
    TUTORIALS_ROOT.mkdir(parents=True, exist_ok=True)

    updated = 0
    for drill_id, variants in sorted(by_drill.items()):
        variants = sorted(variants, key=lambda x: x[0])
        multi = len(variants) > 1
        print(f"\n== {drill_id} ×{len(variants)} multi={multi}")
        all_videos: list[dict] = []
        keep: set[str] = set()
        for token, export_dir in variants:
            entries = import_one(export_dir, drill_id, token, multi, args.dry_run)
            all_videos.extend(entries)
            for e in entries:
                keep.add(e["file"])
            # gif keep for prune
            gif_name = f"{token}_full.gif" if multi else "full.gif"
            if (export_dir / "full.gif").is_file():
                keep.add(gif_name)
        status = rewrite_videos(drill_id, all_videos, args.dry_run)
        print(f"  videos[{len(all_videos)}] json={status}")
        if status == "updated":
            updated += 1
        if args.prune:
            n = prune_videos(drill_id, keep, args.dry_run)
            if n:
                print(f"  pruned {n} files")

    print(f"\nDONE drills={len(by_drill)} json_updated={updated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
