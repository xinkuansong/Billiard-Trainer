#!/usr/bin/env python3
"""Read-only v56 cover color audit for the 60 currently installed assets."""

from __future__ import annotations

import argparse
import colorsys
import json
import statistics
from pathlib import Path

from PIL import Image, ImageStat


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    return ordered[round((len(ordered) - 1) * fraction)]


def asset_metrics(path: Path) -> dict[str, float | str]:
    with Image.open(path) as source:
        image = source.convert("RGB")
        image.thumbnail((240, 180))
        pixels = list(image.get_flattened_data())

    luminance = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in pixels]
    mean = ImageStat.Stat(image).mean
    green_saturation = []
    for r, g, b in pixels:
        if g > r * 1.08 and g > b * 1.08:
            _, saturation, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            green_saturation.append(saturation * 100)

    width, height = image.size
    safe = image.crop((0, 0, width, max(1, round(height * 0.28))))
    safe_luminance = [
        0.2126 * r + 0.7152 * g + 0.0722 * b
        for r, g, b in safe.get_flattened_data()
    ]
    return {
        "asset": path.parent.stem,
        "file": str(path),
        "median_luma": round(percentile(luminance, 0.5), 1),
        "black_p10": round(percentile(luminance, 0.1), 1),
        "temperature_r_minus_b": round(mean[0] - mean[2], 1),
        "green_saturation": round(percentile(green_saturation, 0.5), 1),
        "top_safe_luma": round(percentile(safe_luminance, 0.5), 1),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--assets",
        type=Path,
        default=Path("QiuJi/Resources/Assets.xcassets/Atmosphere"),
    )
    args = parser.parse_args()
    paths = sorted(args.assets.glob("cover*.imageset/cover*.png"))
    rows = [asset_metrics(path) for path in paths]
    luma = [float(row["median_luma"]) for row in rows]
    high_key = sorted(row["asset"] for row in rows if float(row["median_luma"]) > 150)
    bright = sorted(row["asset"] for row in rows if 75 < float(row["median_luma"]) <= 150)
    dark = sorted(row["asset"] for row in rows if float(row["median_luma"]) < 45)
    summary = {
        "median_of_medians": round(statistics.median(luma), 1),
        "range": [round(min(luma), 1), round(max(luma), 1)],
        "high_key": high_key,
        "bright": bright,
        "dark": dark,
    }
    print(json.dumps({"count": len(rows), "summary": summary, "rows": rows}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
