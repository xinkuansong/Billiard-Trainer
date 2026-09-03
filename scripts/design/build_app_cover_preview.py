#!/usr/bin/env python3
"""Build compact App screenshot boards for the random cover installation preview."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PAGES = [
    ("计划", "plan-shelf-top.png"),
    ("学", "learn-top.png"),
    ("理", "theory-top.png"),
    ("练", "train-top.png"),
    ("打", "play-top.png"),
    ("解", "solve-top.png"),
]


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def build_overview(root: Path, font_path: Path) -> Path:
    card_width = 360
    card_height = 783
    margin = 32
    gutter = 24
    header_height = 112
    canvas_width = margin * 2 + card_width * 3 + gutter * 2
    canvas_height = header_height + margin + card_height * 2 + gutter + margin
    canvas = Image.new("RGB", (canvas_width, canvas_height), (242, 242, 247))
    draw = ImageDraw.Draw(canvas)
    title_font = font(font_path, 36)
    label_font = font(font_path, 28)
    draw.text((margin, 30), "随机封面试装 · App 六页面总览", font=title_font, fill=(20, 20, 22))

    for index, (label, filename) in enumerate(PAGES):
        source = root / "after" / filename
        with Image.open(source) as image:
            tile = image.convert("RGB").resize((card_width, card_height), Image.Resampling.LANCZOS)
        column = index % 3
        row = index // 3
        x = margin + column * (card_width + gutter)
        y = header_height + margin + row * (card_height + gutter)
        canvas.paste(tile, (x, y))
        draw.rounded_rectangle((x + 12, y + 12, x + 82, y + 62), radius=16, fill=(12, 12, 14, 220))
        draw.text((x + 32, y + 20), label, font=label_font, fill=(255, 255, 255))

    output = root / "app-six-page-overview.jpg"
    canvas.save(output, "JPEG", quality=92, optimize=True, progressive=True)
    return output


def build_comparison(root: Path, font_path: Path) -> Path:
    labels = ["计划", "学", "理", "练", "打", "解"]
    files = [filename for _, filename in PAGES]
    tile_width = 300
    tile_height = 652
    margin = 28
    gutter_x = 18
    gutter_y = 26
    header_height = 112
    row_label_width = 70
    canvas_width = margin * 2 + row_label_width + tile_width * 2 + gutter_x
    canvas_height = header_height + margin + (tile_height + gutter_y) * 6 - gutter_y + margin
    canvas = Image.new("RGB", (canvas_width, canvas_height), (28, 28, 30))
    draw = ImageDraw.Draw(canvas)
    title_font = font(font_path, 32)
    meta_font = font(font_path, 24)
    draw.text((margin, 22), "随机封面试装 · 替换前 / 替换后", font=title_font, fill=(248, 248, 248))
    draw.text((margin + row_label_width + 90, 72), "替换前", font=meta_font, fill=(174, 174, 180))
    draw.text((margin + row_label_width + tile_width + gutter_x + 90, 72), "替换后", font=meta_font, fill=(174, 174, 180))

    for row, (label, filename) in enumerate(zip(labels, files, strict=True)):
        y = header_height + margin + row * (tile_height + gutter_y)
        draw.text((margin + 16, y + 12), label, font=meta_font, fill=(248, 248, 248))
        for column, phase in enumerate(("before", "after")):
            source = root / phase / filename
            with Image.open(source) as image:
                tile = image.convert("RGB").resize((tile_width, tile_height), Image.Resampling.LANCZOS)
            x = margin + row_label_width + column * (tile_width + gutter_x)
            canvas.paste(tile, (x, y))

    output = root / "before-after-six-page.jpg"
    canvas.save(output, "JPEG", quality=90, optimize=True, progressive=True)
    return output


def build_gallery(root: Path, overview: Path, comparison: Path) -> Path:
    lines = [
        "# 随机封面 App 试装预览",
        "",
        "## 六页面总览",
        "",
        f"![计划、学、理、练、打、解总览]({overview.resolve()})",
        "",
        "## 替换前后",
        "",
        f"![六页面替换前后]({comparison.resolve()})",
        "",
        "## 替换后完整截图",
        "",
    ]
    for label, filename in PAGES:
        lines.extend(
            [
                f"### {label}",
                "",
                f"![{label}页面]({(root / 'after' / filename).resolve()})",
                "",
            ]
        )
    path = root / "PREVIEW.md"
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    args = parser.parse_args()
    overview = build_overview(args.root, args.font)
    comparison = build_comparison(args.root, args.font)
    gallery = build_gallery(args.root, overview, comparison)
    print(overview)
    print(comparison)
    print(gallery)


if __name__ == "__main__":
    main()
