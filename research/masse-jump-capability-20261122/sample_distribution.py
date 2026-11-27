#!/usr/bin/env python3
"""Create a distribution-weighted 36-shape source preview.

Thirty samples follow the filtered source distance distribution. The selected
rows are chosen from repeated fixed-size draws so pocket and angle marginals
stay close to the source distribution as well. Six explicit coverage samples
retain rare near-rail, middle-pocket and angle-end cases.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from sample_100 import load_groups, base_key, make_html, make_svg

HERE = Path(__file__).resolve().parent
OUT_JSON = HERE / "source-filter-sample-36.json"
OUT_HTML = HERE / "source-filter-sample-36.html"
OUT_SVG = HERE / "source-filter-sample-36.svg"
OUT_PNG = HERE / "source-filter-sample-36.png"


def center_rows(groups: dict) -> list[dict]:
    return [variants[0.5] for variants in groups.values()]


def choose_coverage(rows: list[dict], selected: set[tuple[int, int, int]], predicate, seed: int) -> dict:
    candidates = [row for row in rows if base_key(row) not in selected and predicate(row)]
    if not candidates:
        raise RuntimeError("coverage condition has no remaining candidate")
    candidates.sort(key=lambda row: (row["sourceTargetIndex"], row["maskIndex"], row["distanceBit"]))
    return candidates[random.Random(seed).randrange(len(candidates))]


def distribution_score(rows: list[dict]) -> float:
    """Score marginal drift for the 30 main rows.

    The target counts are rounded from the 91,814-shape source distribution.
    Distance is enforced separately by ``distance_allocation``.
    """
    pocket_target = {0: 7, 1: 7, 2: 6, 3: 6, 4: 2, 5: 2}
    angle_target = {0: 3, 1: 6, 2: 8, 3: 8, 4: 5}
    pocket_counts = {key: 0 for key in pocket_target}
    angle_counts = {key: 0 for key in angle_target}
    for row in rows:
        pocket_counts[int(row["pocket"])] += 1
        angle_counts[int(row["angleIndex"])] += 1
    return sum((pocket_counts[key] - target) ** 2 for key, target in pocket_target.items()) + sum(
        (angle_counts[key] - target) ** 2 for key, target in angle_target.items()
    )


def choose_distribution_weighted(rows: list[dict], seed: int) -> list[dict]:
    """Choose 30 rows while preserving the source marginals.

    The distance quota is fixed to the rounded source distribution. Within
    that quota, a deterministic random search minimizes pocket and angle drift.
    This keeps the preview representative without pretending it is a formal
    estimator of the full bank.
    """
    distance_allocation = {5: 10, 6: 7, 7: 5, 8: 4, 9: 4}
    by_distance = {
        distance: [row for row in rows if int(row["distanceBit"]) == distance]
        for distance in distance_allocation
    }
    rng = random.Random(seed)
    best_rows: list[dict] | None = None
    best_score: float | None = None
    for _ in range(5_000):
        candidate: list[dict] = []
        for distance, count in distance_allocation.items():
            candidate.extend(rng.sample(by_distance[distance], count))
        score = distribution_score(candidate)
        if best_score is None or score < best_score:
            best_score = score
            best_rows = candidate
            if score == 0:
                break
    if best_rows is None:
        raise RuntimeError("distribution-weighted sample could not be generated")
    return best_rows


def sample_rows(groups: dict) -> list[dict]:
    rows = center_rows(groups)
    selected: list[dict] = choose_distribution_weighted(rows, seed=20261122)
    selected_keys: set[tuple[int, int, int]] = set()
    selected_keys.update(base_key(row) for row in selected)

    guards = [
        ("nearRail", lambda row: int(row["railIndex"]) == 1 and int(row["angleIndex"]) == 2 and int(row["distanceBit"]) == 6, 101),
        ("nearRail", lambda row: int(row["railIndex"]) == 1 and int(row["angleIndex"]) == 3 and int(row["distanceBit"]) == 7, 102),
        ("middlePocket", lambda row: int(row["pocket"]) == 4 and int(row["angleIndex"]) == 1 and int(row["distanceBit"]) == 6, 201),
        ("middlePocket", lambda row: int(row["pocket"]) == 5 and int(row["angleIndex"]) == 2 and int(row["distanceBit"]) == 7, 202),
        ("lowAngle", lambda row: int(row["angleIndex"]) == 0 and int(row["distanceBit"]) == 5, 301),
        ("highAngle", lambda row: int(row["angleIndex"]) == 4 and int(row["distanceBit"]) == 5, 401),
    ]
    guard_labels = {}
    for label, predicate, seed in guards:
        row = choose_coverage(rows, selected_keys, predicate, seed)
        selected.append(row)
        selected_keys.add(base_key(row))
        guard_labels[base_key(row)] = label

    selected.sort(key=lambda row: (int(row["distanceBit"]), int(row["pocket"]), int(row["sourceTargetIndex"]), int(row["maskIndex"])))
    samples = []
    for index, center in enumerate(selected, start=1):
        variants = groups[base_key(center)]
        item = {
            "sampleIndex": index,
            "sampleClass": guard_labels.get(base_key(center), "distributionWeighted"),
            "sourceTargetIndex": center["sourceTargetIndex"],
            "sourceLayoutID": center["sourceLayoutID"].rsplit("-o", 1)[0],
            "sourceCombinationID": center["sourceCombinationID"],
            "distanceBit": center["distanceBit"],
            "cueTargetDistanceMetres": center["cueTargetDistanceMetres"],
            "pocket": center["pocket"],
            "angleIndex": center["angleIndex"],
            "railIndex": center["railIndex"],
            "cueNearestRailGapMetres": center["cueNearestRailGapMetres"],
            "cue": center["cue"],
            "target": center["target"],
            "ghost": center["ghost"],
            "variants": {
                str(ratio): {"obstacle": variants[ratio]["obstacle"], "obstaclePocketClearanceMetres": variants[ratio]["obstaclePocketClearanceMetres"]}
                for ratio in (0.3, 0.5, 0.7)
            },
        }
        samples.append(item)
    return samples


def main() -> None:
    groups = load_groups()
    samples = sample_rows(groups)
    payload = {
        "schema": "cb01-source-filter-sample-v2",
        "count": len(samples),
        "sampling": {
            "distributionWeightedCount": 30,
            "coverageGuardCount": 6,
            "distanceAllocation": {"5": 10, "6": 7, "7": 5, "8": 4, "9": 4},
            "mainPocketTarget": {"0": 7, "1": 7, "2": 6, "3": 6, "4": 2, "5": 2},
            "mainAngleTarget": {"0": 3, "1": 6, "2": 8, "3": 8, "4": 5},
            "mainSelection": "5000 deterministic draws minimizing pocket and angle marginal drift",
            "seed": 20261122,
            "coverageGuards": [
                "nearRail angle2 d6",
                "nearRail angle3 d7",
                "middlePocket4 angle1 d6",
                "middlePocket5 angle2 d7",
                "lowAngle d5",
                "highAngle d5",
            ],
        },
        "rows": samples,
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    OUT_SVG.write_text(make_svg(samples))
    OUT_HTML.write_text(make_html(samples))
    print(json.dumps({"count": len(samples), "json": str(OUT_JSON), "html": str(OUT_HTML), "svg": str(OUT_SVG)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
