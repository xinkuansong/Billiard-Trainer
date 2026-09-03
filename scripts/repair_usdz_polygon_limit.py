#!/usr/bin/env python3
"""Split USD mesh faces at SceneKit's 256-vertex polygon failure boundary.

SceneKit on iOS 17 stores polygon edge counts in a path that turns 256 into
zero, leaving a null renderable mesh element and crashing the Metal renderer.
This script converts each 256+ vertex face into two or more overlapping-edge
polygons below the configured limit while preserving face-varying attributes
and GeomSubset material membership.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


ARRAY_PATTERNS = {
    "counts": r"int\[\] faceVertexCounts = \[(.*?)\]",
    "indices": r"int\[\] faceVertexIndices = \[(.*?)\]",
    "normals": r"normal3f\[\] normals = \[(.*?)\]\s*\(",
    "texcoords": r"texCoord2f\[\] primvars:st = \[(.*?)\]\s*\(",
}


def run(command: list[str], *, cwd: Path | None = None) -> None:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if completed.returncode:
        raise RuntimeError(completed.stderr or completed.stdout)


def split_values(raw: str) -> list[str]:
    values: list[str] = []
    start = 0
    depth = 0
    for index, character in enumerate(raw):
        if character in "([{" :
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif character == "," and depth == 0:
            values.append(raw[start:index].strip())
            start = index + 1
    tail = raw[start:].strip()
    if tail:
        values.append(tail)
    return values


def replace_match(text: str, match: re.Match[str], values: list[str]) -> str:
    return text[: match.start(1)] + ", ".join(values) + text[match.end(1) :]


def split_face_positions(count: int, limit: int) -> list[list[int]]:
    if count < limit:
        return [list(range(count))]
    # Each continuation shares the first vertex and the preceding boundary
    # vertex, so the pieces cover the original planar polygon without gaps.
    pieces: list[list[int]] = []
    cursor = 1
    max_new_vertices = limit - 2
    while cursor < count - 1:
        end = min(count - 1, cursor + max_new_vertices)
        pieces.append([0] + list(range(cursor, end + 1)))
        cursor = end
    return pieces


def repair_mesh_block(block: str, limit: int) -> tuple[str, int]:
    matches = {name: re.search(pattern, block, re.S) for name, pattern in ARRAY_PATTERNS.items()}
    if not all(matches.values()):
        return block, 0

    counts = [int(value) for value in split_values(matches["counts"].group(1))]  # type: ignore[union-attr]
    indices = split_values(matches["indices"].group(1))  # type: ignore[union-attr]
    normals = split_values(matches["normals"].group(1))  # type: ignore[union-attr]
    texcoords = split_values(matches["texcoords"].group(1))  # type: ignore[union-attr]
    if sum(counts) != len(indices) or len(normals) != len(indices) or len(texcoords) != len(indices):
        raise ValueError("face-varying arrays do not match faceVertexCounts")

    new_counts: list[int] = []
    new_indices: list[str] = []
    new_normals: list[str] = []
    new_texcoords: list[str] = []
    face_map: list[list[int]] = []
    repaired = 0
    offset = 0
    for count in counts:
        positions = split_face_positions(count, limit)
        if len(positions) > 1:
            repaired += 1
        mapped: list[int] = []
        for piece in positions:
            mapped.append(len(new_counts))
            new_counts.append(len(piece))
            new_indices.extend(indices[offset + position] for position in piece)
            new_normals.extend(normals[offset + position] for position in piece)
            new_texcoords.extend(texcoords[offset + position] for position in piece)
        face_map.append(mapped)
        offset += count

    if repaired == 0:
        return block, 0

    replacements = {
        "counts": [str(value) for value in new_counts],
        "indices": new_indices,
        "normals": new_normals,
        "texcoords": new_texcoords,
    }
    # Replace from the end so earlier match offsets remain valid.
    for name, match in sorted(matches.items(), key=lambda item: item[1].start(1), reverse=True):  # type: ignore[union-attr]
        block = replace_match(block, match, replacements[name])  # type: ignore[arg-type]

    subset_pattern = re.compile(
        r'(def GeomSubset "[^"]+".*?int\[\] indices = \[)(.*?)(\])', re.S
    )

    def replace_subset(match: re.Match[str]) -> str:
        old_faces = [int(value) for value in split_values(match.group(2))]
        expanded = [new_face for old_face in old_faces for new_face in face_map[old_face]]
        return match.group(1) + ", ".join(map(str, expanded)) + match.group(3)

    block = subset_pattern.sub(replace_subset, block)
    return block, repaired


def repair_usda(text: str, limit: int) -> tuple[str, int]:
    mesh_start = re.compile(r'^\s*def Mesh "[^"]+"', re.M)
    starts = [match.start() for match in mesh_start.finditer(text)]
    total = 0
    for start in reversed(starts):
        next_prim = re.search(r'^\s{4}def (?:Mesh|Xform) "', text[start + 1 :], re.M)
        end = start + 1 + next_prim.start() if next_prim else len(text)
        repaired_block, count = repair_mesh_block(text[start:end], limit)
        if count:
            text = text[:start] + repaired_block + text[end:]
            total += count
    return text, total


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--limit", type=int, default=255)
    args = parser.parse_args()
    if args.limit < 4:
        raise ValueError("limit must be at least 4")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qiuji-usdz-repair-") as raw_temp:
        temp = Path(raw_temp)
        package = temp / "package"
        package.mkdir()
        shutil.unpack_archive(str(args.input.resolve()), str(package), format="zip")
        root_layers = sorted(package.glob("*.usd*"))
        if len(root_layers) != 1:
            raise ValueError(f"expected one root USD layer, found {len(root_layers)}")
        source_layer = root_layers[0]
        source_usda = temp / "source.usda"
        repaired_usda = temp / "repaired.usda"
        run(["/usr/bin/usdcat", str(source_layer), "-o", str(source_usda)])
        repaired_text, repaired_count = repair_usda(source_usda.read_text(encoding="utf-8"), args.limit)
        if repaired_count == 0:
            raise ValueError("no polygons met the repair threshold")
        repaired_usda.write_text(repaired_text, encoding="utf-8")
        run(["/usr/bin/usdcat", str(repaired_usda), "-o", str(source_layer)])
        output_temp = temp / args.output.name
        inputs = [source_layer.name] + sorted(
            str(path.relative_to(package)) for path in package.rglob("*") if path.is_file() and path != source_layer
        )
        run(["/usr/bin/usdzip", str(output_temp), *inputs], cwd=package)
        run(["/usr/bin/usdchecker", str(output_temp)])
        shutil.copy2(output_temp, args.output)
        print(f"repaired_polygons={repaired_count} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
