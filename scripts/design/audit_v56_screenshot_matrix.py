#!/usr/bin/env python3
"""Audit direct v56 66-page screenshot directories and build visual contact sheets."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def expected_names(manifest: Path) -> set[str]:
    names: set[str] = set()
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        names.add(Path(line.split()[-1]).name)
    return names


def load_font(size: int) -> ImageFont.ImageFont:
    for path in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/SFNS.ttf"):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            pass
    return ImageFont.load_default()


def contact_sheet(directory: Path, images: list[Path]) -> Path:
    columns, thumb_width, padding, label_height = 6, 180, 6, 26
    font = load_font(12)
    thumbs: list[tuple[str, Image.Image]] = []
    max_height = 0
    for path in images:
        with Image.open(path) as source:
            rgb = ImageOps.exif_transpose(source).convert("RGB")
            height = max(1, round(rgb.height * thumb_width / rgb.width))
            thumb = rgb.resize((thumb_width, height), Image.Resampling.LANCZOS)
        thumbs.append((path.name, thumb))
        max_height = max(max_height, thumb.height)

    cell_width = thumb_width + padding * 2
    cell_height = max_height + label_height + padding * 2
    sheet = Image.new(
        "RGB",
        (cell_width * columns, cell_height * math.ceil(len(thumbs) / columns)),
        "#d9dde3",
    )
    draw = ImageDraw.Draw(sheet)
    for index, (name, thumb) in enumerate(thumbs):
        x = (index % columns) * cell_width + padding
        y = (index // columns) * cell_height + padding
        sheet.paste(thumb, (x, y))
        draw.text((x, y + max_height + 4), name, fill="#111827", font=font)
    output = directory / "contact-sheet.jpg"
    sheet.save(output, "JPEG", quality=90, optimize=True)
    return output


def audit(directory: Path, expected: set[str]) -> dict[str, object]:
    images = sorted(directory.glob("*.png"))
    produced = {path.name for path in images}
    failures: list[str] = []
    if len(images) != len(expected):
        failures.append(f"expected {len(expected)} PNGs, found {len(images)}")
    missing = sorted(expected - produced)
    extra = sorted(produced - expected)
    if missing:
        failures.append("missing: " + ", ".join(missing))
    if extra:
        failures.append("unexpected: " + ", ".join(extra))

    dimensions: set[tuple[int, int]] = set()
    hashes: dict[str, list[str]] = {}
    details: list[dict[str, object]] = []
    for path in images:
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            hashes.setdefault(digest, []).append(path.name)
            with Image.open(path) as source:
                source.verify()
            with Image.open(path) as source:
                width, height = source.size
                dimensions.add((width, height))
                sample = source.convert("RGB").resize((48, 48), Image.Resampling.BILINEAR)
                extrema = sample.getextrema()
                near_solid = max(high - low for low, high in extrema) < 8
            if near_solid:
                failures.append(f"near-solid: {path.name}")
            details.append(
                {
                    "name": path.name,
                    "bytes": path.stat().st_size,
                    "sha256": digest,
                    "width": width,
                    "height": height,
                    "near_solid": near_solid,
                }
            )
        except Exception as error:  # Keep the rest of the audit actionable.
            failures.append(f"decode failed: {path.name}: {error}")

    if len(dimensions) != 1:
        failures.append(f"mixed dimensions: {sorted(dimensions)}")
    allowed_duplicates = {
        frozenset(("00-launch.png", "01-training-home.png")),
        frozenset(("50-profile-top.png", "51-profile-scrolled.png")),
    }
    duplicates = [sorted(names) for names in hashes.values() if len(names) > 1]
    for names in duplicates:
        if frozenset(names) not in allowed_duplicates:
            failures.append("unapproved duplicate: " + ", ".join(names))

    result: dict[str, object] = {
        "status": "passed" if not failures else "failed",
        "count": len(images),
        "dimensions": [list(value) for value in sorted(dimensions)],
        "missing": missing,
        "extra": extra,
        "duplicates": duplicates,
        "failures": failures,
        "images": details,
    }
    (directory / "image-audit.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    contact_sheet(directory, images)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directories", nargs="+", type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("docs/design/v47/baseline-screenshots.sha256"),
    )
    args = parser.parse_args()
    expected = expected_names(args.manifest)
    if len(expected) != 66:
        parser.error(f"manifest must contain 66 names, found {len(expected)}")
    failed = False
    for directory in args.directories:
        result = audit(directory, expected)
        print(f"{result['status']} {directory} {result['count']} {result['dimensions']}")
        failed = failed or result["status"] != "passed"
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
