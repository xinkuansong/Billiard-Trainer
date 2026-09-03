#!/usr/bin/env python3
"""Create labeled visual-review sheets for passed simulator-matrix units."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def create_sheet(
    screenshot_dir: Path,
    *,
    columns: int,
    thumb_width: int,
    expected_count: int | None,
) -> Path:
    summary_path = screenshot_dir.parent / "unit-summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    images = sorted(screenshot_dir.glob("*.png"))
    if summary.get("status") != "passed" or not images:
        raise ValueError(f"not a passed unit with screenshots: {screenshot_dir}")
    if expected_count is not None and len(images) != expected_count:
        raise ValueError(
            f"expected {expected_count} screenshots, found {len(images)}: {screenshot_dir}"
        )

    font = load_font(14)
    label_height = 30
    padding = 8
    rendered: list[tuple[str, Image.Image]] = []
    max_height = 0
    for path in images:
        with Image.open(path) as source:
            rgb = ImageOps.exif_transpose(source).convert("RGB")
            height = max(1, round(rgb.height * thumb_width / rgb.width))
            thumb = rgb.resize((thumb_width, height), Image.Resampling.LANCZOS)
        rendered.append((path.name, thumb))
        max_height = max(max_height, thumb.height)

    cell_width = thumb_width + padding * 2
    cell_height = max_height + label_height + padding * 2
    rows = math.ceil(len(rendered) / columns)
    sheet = Image.new("RGB", (cell_width * columns, cell_height * rows), "#d9dde3")
    draw = ImageDraw.Draw(sheet)
    for index, (name, thumb) in enumerate(rendered):
        column = index % columns
        row = index // columns
        x = column * cell_width + padding
        y = row * cell_height + padding
        sheet.paste(thumb, (x, y))
        label_y = row * cell_height + padding + max_height + 5
        draw.text((x, label_y), name, fill="#111827", font=font)

    output = screenshot_dir.parent / "contact-sheet.jpg"
    sheet.save(output, "JPEG", quality=88, optimize=True)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", type=Path, default=Path("build/v50/matrix"))
    parser.add_argument("--columns", type=int, default=6)
    parser.add_argument("--thumb-width", type=int, default=220)
    parser.add_argument(
        "--all-passed",
        action="store_true",
        help="include every passed unit that has screenshots instead of only 66-image tours",
    )
    args = parser.parse_args()
    if args.columns < 1 or args.thumb_width < 80:
        parser.error("columns must be >= 1 and thumb width must be >= 80")

    outputs = []
    pattern = "ios-*/*/*/*/*/screenshots" if args.all_passed else "ios-*/*/*/*/tour/screenshots"
    for screenshot_dir in sorted(args.root.glob(pattern)):
        summary_path = screenshot_dir.parent / "unit-summary.json"
        if not summary_path.exists():
            continue
        try:
            outputs.append(create_sheet(
                screenshot_dir,
                columns=args.columns,
                thumb_width=args.thumb_width,
                expected_count=None if args.all_passed else 66,
            ))
        except ValueError:
            continue
    for output in outputs:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
