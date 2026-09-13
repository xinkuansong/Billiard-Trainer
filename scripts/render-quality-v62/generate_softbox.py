#!/usr/bin/env python3
"""Generate the original v62 RGBE environment; no external imagery is used."""
import argparse
import math
from pathlib import Path


def generate():
    width, height = 512, 256
    data = bytearray(f"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y {height} +X {width}\n".encode())
    for y in range(height):
        theta = math.pi * (y + 0.5) / height
        for x in range(width):
            phi = 2 * math.pi * (x + 0.5) / width
            nx, ny, nz = math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi)
            value = 0.018 + 0.6 * max(0, ny)
            if ny > 0:
                u, t = nx / ny, nz / ny
                for center in [-0.32, 0, 0.32]:
                    distance = max(abs(u) - 0.70, abs(t - center) - 0.055)
                    value += 5 * max(0, min(1, 0.5 - distance / 0.025))
            rgb = [value, value * 0.985, value * 0.96]
            maximum = max(rgb)
            fraction, exponent = math.frexp(maximum)
            scale = fraction * 256 / maximum
            data.extend([min(255, int(channel * scale)) for channel in rgb] + [exponent + 128])
    return data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New output file; existing files are never overwritten")
    args = parser.parse_args()
    with args.output.open("xb") as stream:
        stream.write(generate())
