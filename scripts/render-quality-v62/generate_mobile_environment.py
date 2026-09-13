#!/usr/bin/env python3
"""Rebuild the S95 mobile RGBE environment without external imagery or dependencies."""
import argparse
import math
from pathlib import Path


def generate():
    width, height = 512, 256
    repeats = 4
    mean = sum(math.cos(repeats * math.pi * (x + .5) / width) ** 16
               for x in range(width)) / width
    data = bytearray(f"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y {height} +X {width}\n".encode())
    for y in range(height):
        theta = math.pi * (y + .5) / height
        for x in range(width):
            phi = 2 * math.pi * (x + .5) / width
            nx, ny, nz = math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi)
            if ny >= 0:
                value = .22 + .28 * ny
                rgb = [value, value * .985, value * .96]
                distance = max(abs(nx / ny) - .95, abs(abs(nz / ny) - .22) - .075)
                # S92 numerical integration: retain the original horizontal
                # cosine-weighted irradiance before RGBE quantization.
                panel = 4 * max(0, min(1, .5 - distance / .025)) * 2.192144565818658
            else:
                lower = abs(ny)
                rgb = [.18 - .10 * lower, .18 - .035 * lower, .17 - .10 * lower]
                panel = 0
            # The azimuthal structure has no frequency below order four.
            # Modulate only the base room; the twin sources remain separate.
            window = max(0, 1 - abs(ny) / .65) ** 2
            factor = 1 + .9 * window * (math.cos(repeats * phi / 2) ** 16 / mean - 1)
            rgb = [channel * factor + panel for channel in rgb]
            maximum = max(rgb)
            fraction, exponent = math.frexp(maximum)
            scale = fraction * 256 / maximum
            data.extend([min(255, int(channel * scale)) for channel in rgb] + [exponent + 128])
    return data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New file; an existing output is never overwritten")
    args = parser.parse_args()
    with args.output.open("xb") as stream:
        stream.write(generate())
