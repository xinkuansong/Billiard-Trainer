#!/usr/bin/env python3
"""Build deterministic billiards cover pilot images from one immutable table base.

ImageGen is used only to create the clean, ball/line/spot-free base. This script
owns the table-coordinate homography, cloth markings, cue sticks, ball identity,
card crops, and Light/Dark card-size inspection sheet.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


BALL_RADIUS = 0.01125
BALL_COLORS: dict[int, tuple[int, int, int]] = {
    1: (244, 201, 37),
    2: (39, 83, 178),
    3: (202, 44, 45),
    4: (108, 54, 151),
    5: (234, 113, 38),
    6: (28, 126, 74),
    7: (132, 42, 48),
    8: (25, 25, 27),
    9: (244, 201, 37),
    10: (39, 83, 178),
    11: (202, 44, 45),
    12: (108, 54, 151),
    13: (234, 113, 38),
    14: (28, 126, 74),
    15: (132, 42, 48),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("/System/Library/Fonts/STHeiti Medium.ttc" if bold else "/System/Library/Fonts/STHeiti Light.ttc"),
        Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def solve_homography(src: np.ndarray, dst: np.ndarray) -> np.ndarray:
    rows: list[list[float]] = []
    values: list[float] = []
    for (x, y), (u, v) in zip(src, dst, strict=True):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        values.extend([u, v])
    h = np.linalg.solve(np.asarray(rows, dtype=float), np.asarray(values, dtype=float))
    return np.append(h, 1.0).reshape(3, 3)


class TableProjector:
    def __init__(self, manifest: dict[str, Any], output_size: tuple[int, int]) -> None:
        homography = manifest["coordinateContract"]["imageHomography"]
        w, h = output_size
        src = np.asarray([[0, 0], [1, 0], [1, 0.5], [0, 0.5]], dtype=float)
        dst_norm = np.asarray([
            homography["canvas00NearLeft"],
            homography["canvas10FarLeft"],
            homography["canvas105FarRight"],
            homography["canvas005NearRight"],
        ], dtype=float)
        dst = dst_norm * np.asarray([w, h], dtype=float)
        self.matrix = solve_homography(src, dst)

    def point(self, x: float, y: float) -> tuple[float, float]:
        q = self.matrix @ np.asarray([x, y, 1.0], dtype=float)
        q /= q[2]
        return float(q[0]), float(q[1])

    def ball_radius(self, x: float, y: float) -> float:
        eps = 0.002
        px = np.asarray(self.point(x, y))
        dx = (np.asarray(self.point(min(1.0, x + eps), y)) - px) / eps
        dy = (np.asarray(self.point(x, min(0.5, y + eps))) - px) / eps
        local_scale = math.sqrt(max(1.0, np.linalg.norm(dx) * np.linalg.norm(dy)))
        return BALL_RADIUS * local_scale


def read_board(repo_root: Path, source: str) -> dict[str, dict[str, float]]:
    payload = json.loads((repo_root / source).read_text(encoding="utf-8"))
    return payload["initial"]["onTable"]


def cue_number(key: str) -> int | None:
    if key == "cueBall":
        return None
    return int(key.removeprefix("_"))


def make_ball_sprite(number: int | None, radius: int) -> Image.Image:
    radius = max(8, radius)
    scale = 4
    r = radius * scale
    size = r * 2 + 8 * scale
    cx = cy = size // 2
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    circle = (cx - r, cy - r, cx + r, cy + r)

    if number is None:
        base = (241, 240, 232, 255)
    elif number >= 9:
        base = (239, 238, 229, 255)
    else:
        c = BALL_COLORS[number]
        base = (*c, 255)
    draw.ellipse(circle, fill=base)

    if number is not None and number >= 9:
        band_h = int(r * 0.82)
        stripe = Image.new("RGBA", image.size, (0, 0, 0, 0))
        stripe_draw = ImageDraw.Draw(stripe)
        stripe_draw.rectangle((cx - r, cy - band_h // 2, cx + r, cy + band_h // 2), fill=(*BALL_COLORS[number], 255))
        mask = Image.new("L", image.size, 0)
        ImageDraw.Draw(mask).ellipse(circle, fill=255)
        image.alpha_composite(Image.composite(stripe, Image.new("RGBA", image.size), mask))

    pixels = np.asarray(image).astype(np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    nx = (xx - cx) / r
    ny = (yy - cy) / r
    inside = nx * nx + ny * ny <= 1.0
    light = np.clip(1.08 - 0.24 * nx - 0.30 * ny - 0.28 * (nx * nx + ny * ny), 0.52, 1.18)
    pixels[..., :3] *= light[..., None]
    pixels[..., :3] = np.clip(pixels[..., :3], 0, 255)
    pixels[..., 3] = np.where(inside, pixels[..., 3], 0)
    image = Image.fromarray(pixels.astype(np.uint8), "RGBA")
    draw = ImageDraw.Draw(image)

    if number is None:
        dot_r = max(3 * scale, int(r * 0.105))
        for dx, dy in [(-0.42, -0.18), (0.34, -0.34), (0.22, 0.38)]:
            x = cx + int(dx * r)
            y = cy + int(dy * r)
            draw.ellipse((x - dot_r, y - dot_r, x + dot_r, y + dot_r), fill=(204, 38, 42, 255))
    else:
        patch_r = max(5 * scale, int(r * 0.34))
        draw.ellipse((cx - patch_r, cy - patch_r, cx + patch_r, cy + patch_r), fill=(244, 243, 237, 255))
        number_font = font(max(9 * scale, int(r * 0.45)), bold=True)
        label = str(number)
        box = draw.textbbox((0, 0), label, font=number_font)
        draw.text((cx - (box[2] - box[0]) / 2, cy - (box[3] - box[1]) / 2 - box[1]), label, font=number_font, fill=(22, 22, 24, 255))

    highlight_r = max(2 * scale, int(r * 0.10))
    hx = cx - int(r * 0.30)
    hy = cy - int(r * 0.34)
    draw.ellipse((hx - highlight_r, hy - highlight_r, hx + highlight_r, hy + highlight_r), fill=(255, 255, 255, 205))
    return image.resize((size // scale, size // scale), Image.Resampling.LANCZOS)


def load_ball_sprite(sprite_dir: Path, key: str, radius: int) -> Image.Image:
    source = sprite_dir / f"{key}.png"
    if not source.exists():
        return make_ball_sprite(cue_number(key), radius)
    sprite = Image.open(source).convert("RGBA")
    alpha_bbox = sprite.getchannel("A").getbbox()
    if alpha_bbox:
        sprite = sprite.crop(alpha_bbox)
    diameter = max(16, radius * 2)
    return sprite.resize((diameter, diameter), Image.Resampling.LANCZOS)


def draw_markings(image: Image.Image, projector: TableProjector, manifest: dict[str, Any]) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    markings = manifest["coordinateContract"]["markings"]
    x = float(markings["headStringX"])
    a = projector.point(x, 0.018)
    b = projector.point(x, 0.482)
    draw.line((a, b), fill=(250, 250, 244, 220), width=2)
    for key in ("headSpot", "footSpot"):
        sx, sy = markings[key]
        px, py = projector.point(float(sx), float(sy))
        spot_r = max(2.0, projector.ball_radius(float(sx), float(sy)) * 0.18)
        draw.ellipse((px - spot_r, py - spot_r, px + spot_r, py + spot_r), fill=(250, 250, 244, 235))


def draw_cue(
    image: Image.Image,
    projector: TableProjector,
    cue: dict[str, float],
    target: dict[str, float],
    tip_offset: float,
) -> None:
    cx, cy = float(cue["x"]), float(cue["y"])
    tx, ty = float(target["x"]), float(target["y"])
    dx, dy = tx - cx, ty - cy
    length = math.hypot(dx, dy)
    if length < 1e-6:
        return
    dx, dy = dx / length, dy / length
    start = projector.point(cx - dx * 0.48, cy - dy * 0.48)
    center = np.asarray(projector.point(cx, cy))
    target_px = np.asarray(projector.point(tx, ty))
    direction_px = target_px - center
    direction_px /= max(np.linalg.norm(direction_px), 1e-6)
    normal_px = np.asarray([-direction_px[1], direction_px[0]])
    ball_r = projector.ball_radius(cx, cy)
    tip = center - direction_px * (ball_r + 2.0) + normal_px * (tip_offset * ball_r)

    draw = ImageDraw.Draw(image, "RGBA")
    start_np = np.asarray(start)
    span = tip - start_np
    butt = start_np + span * 0.38
    draw.line((tuple(start_np + (5, 7)), tuple(tip + (5, 7))), fill=(0, 0, 0, 75), width=15)
    draw.line((tuple(start_np), tuple(butt)), fill=(88, 43, 21, 255), width=13)
    draw.line((tuple(butt), tuple(tip)), fill=(222, 174, 104, 255), width=8)
    draw.line((tuple(butt), tuple(tip)), fill=(249, 210, 142, 190), width=3)
    ferrule_start = tip - direction_px * 16
    draw.line((tuple(ferrule_start), tuple(tip - direction_px * 3)), fill=(238, 229, 205, 255), width=8)
    draw.line((tuple(tip - direction_px * 3), tuple(tip)), fill=(45, 68, 65, 255), width=8)


def draw_balls(
    image: Image.Image,
    projector: TableProjector,
    balls: dict[str, dict[str, float]],
    sprite_dir: Path,
) -> None:
    ordered = sorted(balls.items(), key=lambda item: float(item[1]["x"]), reverse=True)
    for key, point in ordered:
        x, y = float(point["x"]), float(point["y"])
        px, py = projector.point(x, y)
        radius = max(8, int(round(projector.ball_radius(x, y))))
        shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.ellipse((px - radius * 0.85 + 6, py + radius * 0.35, px + radius * 0.85 + 8, py + radius * 1.12), fill=(0, 0, 0, 105))
        shadow = shadow.filter(ImageFilter.GaussianBlur(max(2, radius // 3)))
        image.alpha_composite(shadow)
        sprite = load_ball_sprite(sprite_dir, key, radius)
        image.alpha_composite(sprite, (int(round(px - sprite.width / 2)), int(round(py - sprite.height / 2))))


def normalize_crop(crop: list[int]) -> tuple[int, int, int, int]:
    left, top, right, bottom = map(int, crop)
    width, height = right - left, bottom - top
    if width * 3 != height * 4:
        raise ValueError(f"Crop must be exactly 4:3, got {width}x{height}: {crop}")
    return left, top, right, bottom


def card_overlay(cover: Image.Image, card: dict[str, Any], index: int, dark: bool, opacity: float) -> Image.Image:
    card_w, cover_h, text_h = 524, 393, 112
    bg = (28, 28, 30) if dark else (255, 255, 255)
    text = (246, 246, 248) if dark else (22, 22, 24)
    secondary = (178, 178, 184) if dark else (99, 99, 105)
    canvas = Image.new("RGB", (card_w, cover_h + text_h), bg)
    scaled = cover.resize((card_w, cover_h), Image.Resampling.LANCZOS).convert("RGBA")
    scrim = Image.new("RGBA", scaled.size, (0, 0, 0, int(round(255 * opacity))))
    scaled.alpha_composite(scrim)
    draw = ImageDraw.Draw(scaled, "RGBA")
    draw.rounded_rectangle((13, 13, 80, 55), radius=10, fill=(20, 20, 22, 105))
    label = f"{index:02d}" if card["kind"] == "practice" else f"第 {index} 期"
    draw.text((23, 19), label, font=font(22, bold=True), fill=(255, 255, 255, 238))
    if card["kind"] == "practice" and card["id"] in {"practice-diamond"}:
        draw.rounded_rectangle((443, 13, 510, 55), radius=18, fill=(30, 30, 32, 190))
        draw.text((457, 20), "PRO", font=font(19, bold=True), fill=(244, 195, 67, 255))
    canvas.paste(scaled.convert("RGB"), (0, 0))
    body = ImageDraw.Draw(canvas)
    body.text((18, 410), card["title"], font=font(27, bold=True), fill=text)
    subtitle = "真实计划球形 · 确定性合成" if card["kind"] == "plan" else "语义局面 · 确定性合成"
    body.text((18, 453), subtitle, font=font(19), fill=secondary)
    return canvas


def make_contact_sheet(cards: list[dict[str, Any]], covers: dict[str, Image.Image], output: Path, opacity: float) -> None:
    margin, gap = 32, 24
    card_w, card_h = 524, 505
    sheet_w = margin * 2 + card_w * 3 + gap * 2
    sheet_h = margin * 2 + card_h * 4 + gap * 3 + 54
    sheet = Image.new("RGB", (sheet_w, sheet_h), (235, 236, 240))
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 16), "封面试装批 · Light / Dark · 524×393 px @3x", font=font(30, bold=True), fill=(25, 25, 28))
    for theme_index, dark in enumerate((False, True)):
        for idx, card in enumerate(cards):
            grid_index = theme_index * len(cards) + idx
            row, col = divmod(grid_index, 3)
            x = margin + col * (card_w + gap)
            y = margin + 54 + row * (card_h + gap)
            rendered = card_overlay(covers[card["id"]], card, idx + 1, dark, opacity)
            sheet.paste(rendered, (x, y))
    sheet.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    manifest_path = args.manifest.resolve()
    pilot_dir = manifest_path.parent
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    output_dir = pilot_dir / "output"
    output_dir.mkdir(parents=True, exist_ok=True)
    output_size = (int(manifest["output"]["width"]), int(manifest["output"]["height"]))
    base = Image.open(pilot_dir / manifest["baseImage"]).convert("RGBA").resize(output_size, Image.Resampling.LANCZOS)
    sprite_dir = pilot_dir / manifest["ballSpriteDir"]
    projector = TableProjector(manifest, output_size)
    covers: dict[str, Image.Image] = {}

    for card in manifest["cards"]:
        if "boardSource" in card:
            balls = read_board(args.repo_root.resolve(), card["boardSource"])
        else:
            balls = card["balls"]
        image = base.copy()
        if card.get("markings", False):
            draw_markings(image, projector, manifest)
        cue = balls.get("cueBall")
        if cue:
            if "cueTargetKey" in card:
                target = balls[card["cueTargetKey"]]
            else:
                target = card["cueTarget"]
            draw_cue(image, projector, cue, target, float(card.get("cueTipOffset", 0.0)))
        draw_balls(image, projector, balls, sprite_dir)
        crop = normalize_crop(card["crop"])
        cover = image.crop(crop).resize(output_size, Image.Resampling.LANCZOS).convert("RGB")
        cover = ImageEnhance.Sharpness(cover).enhance(1.08)
        path = output_dir / f"{card['assetKey']}.png"
        cover.save(path, optimize=True)
        covers[card["id"]] = cover

    make_contact_sheet(
        manifest["cards"],
        covers,
        output_dir / "pilot-card-check-light-dark@3x.png",
        float(manifest["output"]["runtimeNeutralScrimOpacity"]),
    )
    print(f"PASS: generated {len(covers)} deterministic 1600x1200 pilot covers")
    print(f"PASS: card check {output_dir / 'pilot-card-check-light-dark@3x.png'}")


if __name__ == "__main__":
    main()
