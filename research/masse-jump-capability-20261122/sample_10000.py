#!/usr/bin/env python3
"""Downsample the filtered base-shape set to 10,000 research records.

The source set has one base shape for each source target, mask and distance
combination.  The sampler preserves the joint distribution of distance,
pocket, angle and rail strata with Hamilton allocation, then samples inside
each stratum using a fixed seed.  Each output record keeps all three obstacle
ratios and is independent of the jump/masse technique label.
"""
from __future__ import annotations

import gzip
import hashlib
import io
import json
import random
from collections import Counter, defaultdict
from pathlib import Path

from sample_100 import base_key, load_groups

HERE = Path(__file__).resolve().parent
INPUT = HERE / "filtered-source-shapes.jsonl.gz"
OUT_JSONL_GZ = HERE / "source-filter-sample-10000.jsonl.gz"
OUT_SUMMARY = HERE / "source-filter-sample-10000-summary.json"
SEED = 20261122
SAMPLE_COUNT = 10_000
STRATUM_FIELDS = ("distanceBit", "pocket", "angleIndex", "railIndex")


def stratum_key(row: dict) -> tuple[int, int, int, int]:
    return tuple(int(row[field]) for field in STRATUM_FIELDS)


def allocate_hamilton(groups: dict[tuple, list[dict]], total: int) -> dict[tuple, int]:
    available = sum(len(rows) for rows in groups.values())
    if total > available:
        raise ValueError(f"requested {total} rows from {available} available rows")
    raw = {key: total * len(rows) / available for key, rows in groups.items()}
    allocation = {key: int(value) for key, value in raw.items()}
    remaining = total - sum(allocation.values())
    order = sorted(
        groups,
        key=lambda key: (raw[key] - allocation[key], tuple(key)),
        reverse=True,
    )
    for key in order[:remaining]:
        allocation[key] += 1
    if any(count > len(groups[key]) for key, count in allocation.items()):
        raise AssertionError("Hamilton allocation exceeded a stratum")
    return allocation


def compact_record(index: int, center: dict, variants: dict[float, dict]) -> dict:
    return {
        "sampleIndex": index,
        "sourceTargetIndex": center["sourceTargetIndex"],
        "sourceLayoutID": center["sourceLayoutID"].rsplit("-o", 1)[0],
        "sourceCombinationID": center["sourceCombinationID"],
        "maskIndex": center["maskIndex"],
        "distanceBit": center["distanceBit"],
        "sourceDistanceMetres": center["sourceDistanceMetres"],
        "cueTargetDistanceMetres": center["cueTargetDistanceMetres"],
        "pocket": center["pocket"],
        "angleIndex": center["angleIndex"],
        "railIndex": center["railIndex"],
        "objectIndex": center["objectIndex"],
        "pocketType": center["pocketType"],
        "cueNearestRailGapMetres": center["cueNearestRailGapMetres"],
        "cue": center["cue"],
        "target": center["target"],
        "ghost": center["ghost"],
        "variants": {
            str(ratio): {
                "obstacle": variants[ratio]["obstacle"],
                "obstaclePocketClearanceMetres": variants[ratio]["obstaclePocketClearanceMetres"],
            }
            for ratio in (0.3, 0.5, 0.7)
        },
    }


def marginals(rows: list[dict]) -> dict[str, dict[str, int]]:
    return {
        field: dict(sorted((str(key), value) for key, value in Counter(row[field] for row in rows).items()))
        for field in ("distanceBit", "pocket", "angleIndex", "railIndex", "objectIndex", "pocketType")
    }


def main() -> None:
    groups = load_groups()
    if len(groups) != 91_814:
        raise AssertionError(f"expected 91814 base shapes, found {len(groups)}")
    rows = []
    for key, variants in groups.items():
        if set(variants) != {0.3, 0.5, 0.7}:
            raise AssertionError(f"incomplete obstacle variants for {key}")
        rows.append(variants[0.5])

    strata: dict[tuple[int, int, int, int], list[dict]] = defaultdict(list)
    for row in rows:
        strata[stratum_key(row)].append(row)
    allocation = allocate_hamilton(strata, SAMPLE_COUNT)
    rng = random.Random(SEED)
    selected: list[dict] = []
    for key in sorted(strata):
        values = sorted(strata[key], key=base_key)
        selected.extend(rng.sample(values, allocation[key]))
    selected.sort(key=base_key)
    if len(selected) != SAMPLE_COUNT or len({base_key(row) for row in selected}) != SAMPLE_COUNT:
        raise AssertionError("sample count or uniqueness check failed")

    records = [
        compact_record(index, center, groups[base_key(center)])
        for index, center in enumerate(selected, start=1)
    ]
    with OUT_JSONL_GZ.open("wb") as raw, gzip.GzipFile(
        fileobj=raw, mode="wb", compresslevel=6, mtime=0
    ) as compressed, io.TextIOWrapper(compressed, encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")

    source_sha256 = hashlib.sha256(INPUT.read_bytes()).hexdigest()
    summary = {
        "schema": "cb01-source-filter-sample-v3",
        "source": {
            "baseShapeCount": len(rows),
            "input": str(INPUT),
            "inputSHA256": source_sha256,
        },
        "sample": {
            "count": len(records),
            "seed": SEED,
            "stratumFields": list(STRATUM_FIELDS),
            "stratumCount": len(strata),
            "allocation": "Hamilton largest-remainder proportional allocation",
            "selection": "seeded random sample within each joint stratum",
            "obstacleVariants": [0.3, 0.5, 0.7],
        },
        "sourceMarginals": marginals(rows),
        "sampleMarginals": marginals(records),
        "distanceRangeMetres": [
            min(row["cueTargetDistanceMetres"] for row in records),
            max(row["cueTargetDistanceMetres"] for row in records),
        ],
        "outputs": {
            "jsonlGzip": str(OUT_JSONL_GZ),
            "summary": str(OUT_SUMMARY),
        },
    }
    OUT_SUMMARY.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"count": len(records), "strata": len(strata), "jsonlGzip": str(OUT_JSONL_GZ), "summary": str(OUT_SUMMARY)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
