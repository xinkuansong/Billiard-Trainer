#!/usr/bin/env python3
"""Build ordered 2x2 contact sheets for cover candidate review."""

from __future__ import annotations

import argparse
import html
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


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
                raise ValueError(f"duplicate asset key in spec: {asset_key}")
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
                raise ValueError(f"duplicate asset key in spec: {asset_key}")
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


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def rounded_label(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
) -> None:
    x, y = xy
    left, top, right, bottom = draw.textbbox((x, y), text, font=font)
    padding_x = 22
    padding_y = 12
    box = (
        left - padding_x,
        top - padding_y,
        right + padding_x,
        bottom + padding_y,
    )
    draw.rounded_rectangle(box, radius=22, fill=(10, 10, 12, 225))
    draw.text((x, y), text, font=font, fill=(255, 255, 255))


def build_sheet(
    entry: CoverEntry,
    candidate_root: Path,
    output_dir: Path,
    title_font: ImageFont.FreeTypeFont,
    meta_font: ImageFont.FreeTypeFont,
    label_font: ImageFont.FreeTypeFont,
) -> Path:
    tile_width = 800
    tile_height = 600
    margin = 24
    gutter = 16
    header_height = 124
    canvas_width = margin * 2 + tile_width * 2 + gutter
    canvas_height = header_height + margin + tile_height * 2 + gutter + margin
    canvas = Image.new("RGB", (canvas_width, canvas_height), (28, 28, 30))
    draw = ImageDraw.Draw(canvas, "RGBA")

    display_title = f"{entry.sequence:02d}  {entry.section} · {entry.title}"
    draw.text((margin, 20), display_title, font=title_font, fill=(248, 248, 248))
    draw.text((margin, 76), entry.asset_key, font=meta_font, fill=(174, 174, 180))

    candidate_dir = candidate_root / entry.asset_key
    for index in range(1, 5):
        source = candidate_dir / f"v{index:02d}.png"
        if not source.is_file():
            raise FileNotFoundError(source)
        with Image.open(source) as image:
            tile = image.convert("RGB")
            if tile.size != (1600, 1200):
                raise ValueError(f"unexpected size {tile.size}: {source}")
            tile = tile.resize((tile_width, tile_height), Image.Resampling.LANCZOS)

        row = (index - 1) // 2
        column = (index - 1) % 2
        x = margin + column * (tile_width + gutter)
        y = header_height + margin + row * (tile_height + gutter)
        canvas.paste(tile, (x, y))
        draw.rectangle(
            (x, y, x + tile_width - 1, y + tile_height - 1),
            outline=(255, 255, 255, 70),
            width=2,
        )
        rounded_label(draw, (x + 36, y + 28), str(index), label_font)

    output_path = output_dir / f"{entry.sequence:02d}-{entry.asset_key}.jpg"
    canvas.save(output_path, format="JPEG", quality=91, optimize=True, progressive=True)
    return output_path


def build_markdown(entries: list[CoverEntry], sheets: list[Path], gallery_path: Path) -> None:
    lines = [
        "# 封面四选一联系表",
        "",
        "> 顺序：官方计划 → 学 → 理 → 练 → 打 → 解 → 自定义计划模板。",
        "> 每张联系表：左上 1、右上 2、左下 3、右下 4。候选尚未写入正式资源。",
        "",
    ]
    for entry, sheet in zip(entries, sheets, strict=True):
        lines.extend(
            [
                f"## {entry.sequence:02d}. {entry.section} · {entry.title}",
                "",
                f"资源键：`{entry.asset_key}`",
                "",
                f"![{entry.asset_key} 四选一]({sheet.resolve()})",
                "",
            ]
        )
    gallery_path.write_text("\n".join(lines), encoding="utf-8")


def build_html(entries: list[CoverEntry], sheets: list[Path], html_path: Path) -> None:
    cards = []
    for entry, sheet in zip(entries, sheets, strict=True):
        cards.append(
            "\n".join(
                [
                    '<section class="card">',
                    f"<h2>{entry.sequence:02d}. {html.escape(entry.section)} · {html.escape(entry.title)}</h2>",
                    f"<p>{html.escape(entry.asset_key)}</p>",
                    f'<img src="contact-sheets/{html.escape(sheet.name)}" alt="{html.escape(entry.asset_key)}">',
                    "</section>",
                ]
            )
        )

    document = f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>封面四选一联系表</title>
<style>
:root {{ color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif; }}
body {{ margin: 0; background: #111214; color: #f2f2f7; }}
header {{ position: sticky; top: 0; z-index: 2; padding: 18px 24px; background: rgba(17,18,20,.94); border-bottom: 1px solid #343438; backdrop-filter: blur(16px); }}
h1 {{ margin: 0 0 6px; font-size: 22px; }}
header p {{ margin: 0; color: #a8a8ae; }}
main {{ width: min(1180px, calc(100% - 32px)); margin: 24px auto 80px; }}
.card {{ margin: 0 0 34px; padding: 18px; background: #1c1c1e; border: 1px solid #343438; border-radius: 18px; }}
h2 {{ margin: 0 0 4px; font-size: 19px; }}
.card p {{ margin: 0 0 14px; color: #8e8e93; font-family: ui-monospace, monospace; }}
img {{ display: block; width: 100%; height: auto; border-radius: 10px; }}
</style>
</head>
<body>
<header><h1>封面四选一联系表</h1><p>共 60 组；每组左上 1、右上 2、左下 3、右下 4。</p></header>
<main>{''.join(cards)}</main>
</body>
</html>
"""
    html_path.write_text(document, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--candidate-root", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    args = parser.parse_args()

    entries = parse_entries(args.spec)
    output_dir = args.candidate_root / "contact-sheets"
    output_dir.mkdir(parents=True, exist_ok=True)

    title_font = load_font(args.font, 34)
    meta_font = load_font(args.font, 23)
    label_font = load_font(args.font, 32)
    sheets = [
        build_sheet(entry, args.candidate_root, output_dir, title_font, meta_font, label_font)
        for entry in entries
    ]

    build_markdown(entries, sheets, args.candidate_root / "GALLERY.md")
    build_html(entries, sheets, args.candidate_root / "index.html")
    print(f"entries={len(entries)} sheets={len(sheets)}")
    print(args.candidate_root / "GALLERY.md")
    print(args.candidate_root / "index.html")


if __name__ == "__main__":
    main()
