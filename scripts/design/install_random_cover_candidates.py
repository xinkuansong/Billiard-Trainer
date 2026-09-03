#!/usr/bin/env python3
"""Install one reproducibly random candidate per card-cover asset for App preview."""

from __future__ import annotations

import argparse
import hashlib
import random
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass(frozen=True)
class CoverEntry:
    sequence: int
    section: str
    title: str
    asset_key: str


HEADING_PATTERN = re.compile(
    r"^### (?P<section>P\d{2}|[学理练打解] \d{2}) `[^`]+` — "
    r"(?P<title>.+?) / `(?P<asset>cover[A-Za-z0-9]+)`$"
)
TEMPLATE_PATTERN = re.compile(r"^\| `(?P<asset>coverTemplate(?P<number>\d{2}))` \|")


def parse_entries(spec_path: Path) -> list[CoverEntry]:
    entries: list[CoverEntry] = []
    seen: set[str] = set()
    for line in spec_path.read_text(encoding="utf-8").splitlines():
        heading = HEADING_PATTERN.match(line)
        if heading:
            asset_key = heading.group("asset")
            if asset_key in seen:
                raise ValueError(f"duplicate asset key: {asset_key}")
            seen.add(asset_key)
            entries.append(
                CoverEntry(
                    sequence=len(entries) + 1,
                    section=heading.group("section"),
                    title=heading.group("title"),
                    asset_key=asset_key,
                )
            )
            continue

        template = TEMPLATE_PATTERN.match(line)
        if template:
            asset_key = template.group("asset")
            if asset_key in seen:
                raise ValueError(f"duplicate asset key: {asset_key}")
            seen.add(asset_key)
            number = template.group("number")
            entries.append(
                CoverEntry(
                    sequence=len(entries) + 1,
                    section=f"模板 {number}",
                    title=f"自定义计划模板 {number}",
                    asset_key=asset_key,
                )
            )

    if len(entries) != 60:
        raise ValueError(f"expected 60 entries, found {len(entries)}")
    return entries


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_png(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(path)
    with Image.open(path) as image:
        if image.format != "PNG" or image.size != (1600, 1200):
            raise ValueError(f"expected 1600x1200 PNG: {path} ({image.format}, {image.size})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--asset-root", type=Path, required=True)
    parser.add_argument("--preview-root", type=Path, required=True)
    parser.add_argument("--seed")
    parser.add_argument("--restore", action="store_true", help="restore the backed-up formal assets")
    args = parser.parse_args()

    entries = parse_entries(args.spec)
    backup_dir = args.preview_root / "formal-assets-before"
    backup_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = args.preview_root / "random-selection-manifest.md"

    if args.restore:
        for entry in entries:
            backup = backup_dir / f"{entry.asset_key}.png"
            destination = args.asset_root / f"{entry.asset_key}.imageset" / f"{entry.asset_key}.png"
            validate_png(backup)
            shutil.copy2(backup, destination)
            validate_png(destination)
            if sha256(backup) != sha256(destination):
                raise ValueError(f"restored hash mismatch: {entry.asset_key}")
        print(f"restored={len(entries)}")
        return

    if not args.seed:
        parser.error("--seed is required unless --restore is used")

    rng = random.Random(args.seed)
    rows: list[str] = []

    for entry in entries:
        candidates = [args.candidate_root / entry.asset_key / f"v{i:02d}.png" for i in range(1, 5)]
        for candidate in candidates:
            validate_png(candidate)

        destination = args.asset_root / f"{entry.asset_key}.imageset" / f"{entry.asset_key}.png"
        validate_png(destination)
        backup = backup_dir / f"{entry.asset_key}.png"
        before_hash = sha256(destination)
        if backup.exists():
            validate_png(backup)
        else:
            shutil.copy2(destination, backup)

        choice = rng.randint(1, 4)
        source = candidates[choice - 1]
        shutil.copy2(source, destination)
        validate_png(destination)
        source_hash = sha256(source)
        installed_hash = sha256(destination)
        if source_hash != installed_hash:
            raise ValueError(f"installed hash mismatch: {entry.asset_key}")

        rows.append(
            f"| {entry.sequence:02d} | {entry.section} | {entry.title} | `{entry.asset_key}` | "
            f"v{choice:02d} | `{source_hash}` | `{before_hash}` |"
        )

    installed = list(args.asset_root.glob("cover*.imageset/cover*.png"))
    if len(installed) != 60:
        raise ValueError(f"expected 60 installed cover PNGs, found {len(installed)}")

    manifest = [
        "# App 随机封面试装清单",
        "",
        f"- 随机种子：`{args.seed}`",
        "- 抽取规则：按规格顺序，Python `random.Random(seed).randint(1, 4)`，每组独立抽取一次。",
        "- 范围：12 个官方计划、36 个练习入口、12 个自定义模板，共 60 张。",
        "- 状态：已写入正式 Asset Catalog，仅作本地视觉试装；原资源已完整备份。",
        "",
        "| 顺序 | 分组 | 标题 | 资源键 | 选中 | 安装 SHA-256 | 原资源 SHA-256 |",
        "|---:|---|---|---|---:|---|---|",
        *rows,
        "",
        f"原资源备份：`{backup_dir.resolve()}`",
    ]
    manifest_path.write_text("\n".join(manifest) + "\n", encoding="utf-8")
    print(f"seed={args.seed}")
    print(f"installed={len(entries)} backup={len(list(backup_dir.glob('cover*.png')))}")
    print(manifest_path)


if __name__ == "__main__":
    main()
