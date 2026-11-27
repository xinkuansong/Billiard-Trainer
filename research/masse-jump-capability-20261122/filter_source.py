#!/usr/bin/env python3
"""Filter the full accuracy-layout source for CB-01 research candidates.

This script only creates research artifacts. It never writes the production
training bank. It expands valid source combinations into technique-specific
obstacle layouts and records every rejection reason.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BANK = ROOT / "QiuJi/Resources/training-grid-bank.json"

RADIUS = 0.028575
LENGTH = 2.540
WIDTH = 1.270
HALF_LENGTH = LENGTH / 2
HALF_WIDTH = WIDTH / 2
OVERLAP_MARGIN = 0.001
MIN_CUE_TARGET_DISTANCE = 1.0
OBSTACLE_RATIOS = (0.30, 0.50, 0.70)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def point(value: dict[str, float]) -> tuple[float, float]:
    return float(value["x"]), float(value["z"])


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def dot(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1]


def unit(value: tuple[float, float]) -> tuple[float, float]:
    length = math.hypot(*value)
    if length <= 1e-12:
        raise ValueError("zero direction")
    return value[0] / length, value[1] / length


def cue_position(target: dict, distance_bit: int, distances: list[float], mask_index: int) -> tuple[float, float]:
    """Reconstruct the source grid cue position using the bank's mask contract."""
    obj = point(target["object"])
    ghost = point(target["ghost"])
    basis = unit((ghost[0] - obj[0], ghost[1] - obj[1]))
    angle = math.radians(mask_index - 85)
    direction = (
        basis[0] * math.cos(angle) - basis[1] * math.sin(angle),
        basis[0] * math.sin(angle) + basis[1] * math.cos(angle),
    )
    d = distances[distance_bit]
    return ghost[0] + d * direction[0], ghost[1] + d * direction[1]


def legal_center(value: tuple[float, float]) -> bool:
    return abs(value[0]) <= HALF_LENGTH - RADIUS and abs(value[1]) <= HALF_WIDTH - RADIUS


def nearest_rail_gap(value: tuple[float, float]) -> float:
    return min(HALF_LENGTH - abs(value[0]), HALF_WIDTH - abs(value[1])) - RADIUS


def axis_rail_clearance(cue: tuple[float, float], aim: tuple[float, float]) -> float:
    backwards = (-aim[0], -aim[1])
    candidates: list[float] = []
    if backwards[0] < -1e-9:
        candidates.append((-HALF_LENGTH - cue[0]) / backwards[0])
    if backwards[0] > 1e-9:
        candidates.append((HALF_LENGTH - cue[0]) / backwards[0])
    if backwards[1] < -1e-9:
        candidates.append((-HALF_WIDTH - cue[1]) / backwards[1])
    if backwards[1] > 1e-9:
        candidates.append((HALF_WIDTH - cue[1]) / backwards[1])
    positive = [item for item in candidates if item >= 0 and math.isfinite(item)]
    return min(positive) - RADIUS if positive else float("inf")


def pocket_clearance(value: tuple[float, float], geometry: dict, pocket_index: int) -> float:
    pocket = geometry["pockets"][pocket_index]
    centre = point(pocket["center"])
    return distance(value, centre) - float(pocket["radius"]) - RADIUS


def obstacle_at_ratio(cue: tuple[float, float], target: tuple[float, float], ratio: float) -> tuple[float, float]:
    return cue[0] + ratio * (target[0] - cue[0]), cue[1] + ratio * (target[1] - cue[1])


def combination_rows(bank: dict):
    table = bank["combinationTable"]
    distances = [float(value) for value in bank["distanceSamples"]]
    for target in bank["targets"]:
        masks = target["masks"]
        combinations = target["combinationIndices"]
        expected = sum(int(mask).bit_count() for mask in masks)
        if expected != len(combinations):
            yield {"target": target, "error": "combinationIndexCountMismatch", "expected": expected, "actual": len(combinations)}
            continue
        cursor = 0
        for mask_index, mask in enumerate(masks):
            mask_value = int(mask)
            for distance_bit in range(len(distances)):
                if not (mask_value & (1 << distance_bit)):
                    continue
                combination_index = int(combinations[cursor])
                cursor += 1
                yield {
                    "target": target,
                    "maskIndex": mask_index,
                    "distanceBit": distance_bit,
                    "combinationIndex": combination_index,
                    "combination": table[combination_index],
                    "distances": distances,
                }


def reject_reasons(row: dict, geometry: dict) -> list[str]:
    target = row["targetPoint"]
    cue = row["cuePoint"]
    obstacle = row["obstaclePoint"]
    reasons: list[str] = []
    if not row["targetClean"]:
        reasons.append("sourceTargetNotClean")
    if not legal_center(cue):
        reasons.append("cueOutsidePlayfield")
    if not legal_center(target):
        reasons.append("targetOutsidePlayfield")
    if not legal_center(obstacle):
        reasons.append("obstacleOutsidePlayfield")
    if row["cueTargetDistanceMetres"] < MIN_CUE_TARGET_DISTANCE:
        reasons.append("cueTargetTooClose")
    if distance(cue, target) <= 2 * RADIUS + OVERLAP_MARGIN:
        reasons.append("cueTargetOverlap")
    if distance(cue, obstacle) <= 2 * RADIUS + OVERLAP_MARGIN:
        reasons.append("cueObstacleTooClose")
    if distance(target, obstacle) <= 2 * RADIUS + OVERLAP_MARGIN:
        reasons.append("targetObstacleTooClose")
    if row["targetPocketClearanceMetres"] < 0:
        reasons.append("targetPocketZone")
    if row["obstaclePocketClearanceMetres"] < 0:
        reasons.append("obstaclePocketZone")
    if row["cueAxisRailClearanceMetres"] < 0:
        reasons.append("cueAxisRailOverlap")
    return reasons


def compact_row(row: dict) -> dict:
    return {
        "candidateID": row["candidateID"],
        "sourceLayoutID": row["sourceLayoutID"],
        "sourceCombinationID": row["sourceCombinationID"],
        "sourceCombinationIndex": row["sourceCombinationIndex"],
        "sourceTargetIndex": row["sourceTargetIndex"],
        "technique": row["technique"],
        "pocket": row["pocket"],
        "angleIndex": row["angleIndex"],
        "cueIndex": row["cueIndex"],
        "objectIndex": row["objectIndex"],
        "pocketType": row["pocketType"],
        "railIndex": row["railIndex"],
        "maskIndex": row["maskIndex"],
        "distanceBit": row["distanceBit"],
        "sourceDistanceMetres": row["sourceDistanceMetres"],
        "cueTargetDistanceMetres": row["cueTargetDistanceMetres"],
        "cueNearestRailGapMetres": row["cueNearestRailGapMetres"],
        "cueAxisRailClearanceMetres": row["cueAxisRailClearanceMetres"],
        "targetPocketClearanceMetres": row["targetPocketClearanceMetres"],
        "obstaclePocketClearanceMetres": row["obstaclePocketClearanceMetres"],
        "obstacleRatio": row["obstacleRatio"],
        "cue": row["cue"],
        "target": row["target"],
        "ghost": row["ghost"],
        "obstacle": row["obstacle"],
        "geometryStatus": row["geometryStatus"],
        "geometryFailures": row["geometryFailures"],
    }


def filter_rules() -> dict:
    return {
        "minCueTargetDistanceMetres": MIN_CUE_TARGET_DISTANCE,
        "ballRadiusMetres": RADIUS,
        "overlapMarginMetres": OVERLAP_MARGIN,
        "cueTailRestNumericThreshold": "deferred",
        "cueTailRestCurrentGate": "cueAxisRailClearanceMetres >= 0",
        "solverRequiredForEntry": True,
    }


def run_filter() -> None:
    bank = json.loads(BANK.read_text())
    if bank.get("schema") != "layout-bank-grid-v2-combination-ids":
        raise ValueError("unexpected source bank schema")
    geometry = bank["geometry"]
    if abs(float(geometry.get("radius", 0)) - RADIUS) > 1e-8:
        raise ValueError("source radius does not match table contract")

    source_hash = sha256(BANK)
    audit_path = HERE / "source-filter-audit.jsonl.gz"
    passed_path = HERE / "filtered-source-shapes.jsonl.gz"
    counts_by_technique = {
        technique: {"sourceRows": 0, "passed": 0, "rejected": 0, "uniqueSourceLayouts": set(), "uniquePassedLayouts": set()}
        for technique in ("jump", "masse")
    }
    rejection_reasons: Counter[str] = Counter()
    expanded = passed_count = rejected_count = malformed_count = 0

    import gzip
    with gzip.open(audit_path, "wt", encoding="utf-8", compresslevel=6) as audit, gzip.open(passed_path, "wt", encoding="utf-8", compresslevel=6) as passed_file:
        for item in combination_rows(bank):
            if "error" in item:
                malformed_count += 1
                audit.write(json.dumps({"status": "malformed", **item}, ensure_ascii=False, separators=(",", ":")) + "\n")
                continue
            target = item["target"]
            target_point = point(target["object"])
            cue_point = cue_position(target, item["distanceBit"], item["distances"], item["maskIndex"])
            ghost_point = point(target["ghost"])
            aim = unit((ghost_point[0] - cue_point[0], ghost_point[1] - cue_point[1]))
            for ratio in OBSTACLE_RATIOS:
                obstacle_point = obstacle_at_ratio(cue_point, target_point, ratio)
                base = {
                    "sourceLayoutID": f"target-{int(target['inventoryTargetIndex'])}-m{item['maskIndex']:03d}-d{item['distanceBit']}-o{int(ratio * 100):02d}",
                    "sourceCombinationID": item["combination"]["id"],
                    "sourceCombinationIndex": item["combinationIndex"],
                    "sourceTargetIndex": int(target["inventoryTargetIndex"]),
                    "pocket": int(target["pocket"]),
                    "angleIndex": int(item["combination"]["angleIndex"]),
                    "cueIndex": int(item["combination"]["cueIndex"]),
                    "objectIndex": int(item["combination"]["objectIndex"]),
                    "pocketType": int(item["combination"]["pocketType"]),
                    "railIndex": int(item["combination"]["railIndex"]),
                    "maskIndex": item["maskIndex"],
                    "distanceBit": item["distanceBit"],
                    "sourceDistanceMetres": item["distances"][item["distanceBit"]],
                    "cueTargetDistanceMetres": distance(cue_point, target_point),
                    "cueNearestRailGapMetres": nearest_rail_gap(cue_point),
                    "cueAxisRailClearanceMetres": axis_rail_clearance(cue_point, aim),
                    "targetPocketClearanceMetres": pocket_clearance(target_point, geometry, int(target["pocket"])),
                    "obstaclePocketClearanceMetres": pocket_clearance(obstacle_point, geometry, int(target["pocket"])),
                    "obstacleRatio": ratio,
                    "cue": {"x": cue_point[0], "z": cue_point[1]},
                    "target": {"x": target_point[0], "z": target_point[1]},
                    "ghost": {"x": ghost_point[0], "z": ghost_point[1]},
                    "obstacle": {"x": obstacle_point[0], "z": obstacle_point[1]},
                }
                reasons = reject_reasons({**base, "targetClean": bool(target.get("clean")), "cuePoint": cue_point, "targetPoint": target_point, "obstaclePoint": obstacle_point}, geometry)
                status = "pass" if not reasons else "reject"
                for technique in ("jump", "masse"):
                    row = {**base, "technique": technique, "candidateID": f"{base['sourceLayoutID']}-{technique}", "geometryStatus": status, "geometryFailures": reasons}
                    compact = compact_row(row)
                    audit.write(json.dumps(compact, ensure_ascii=False, separators=(",", ":")) + "\n")
                    counts = counts_by_technique[technique]
                    counts["sourceRows"] += 1
                    counts["uniqueSourceLayouts"].add(base["sourceLayoutID"])
                    expanded += 1
                    if status == "pass":
                        passed_file.write(json.dumps(compact, ensure_ascii=False, separators=(",", ":")) + "\n")
                        counts["passed"] += 1
                        counts["uniquePassedLayouts"].add(base["sourceLayoutID"])
                        passed_count += 1
                    else:
                        counts["rejected"] += 1
                        rejected_count += 1
                        rejection_reasons.update(reasons)

    normalized_counts = {}
    for technique, counts in counts_by_technique.items():
        normalized_counts[technique] = {
            **counts,
            "uniqueSourceLayouts": len(counts["uniqueSourceLayouts"]),
            "uniquePassedLayouts": len(counts["uniquePassedLayouts"]),
        }
    rules = filter_rules()
    summary = {
        "schema": "cb01-source-filter-summary-v1",
        "status": "pass",
        "sourceBank": str(BANK.relative_to(ROOT)),
        "sourceBankSHA256": source_hash,
        "sourceTargets": len(bank["targets"]),
        "expandedObstacleRatios": list(OBSTACLE_RATIOS),
        "expandedSourceRows": expanded,
        "passedRows": passed_count,
        "rejectedRows": rejected_count,
        "malformedTargets": malformed_count,
        "countsByTechnique": normalized_counts,
        "rejectionReasons": dict(rejection_reasons),
        "rules": rules,
        "outputs": {
            "passedJSONLCompressed": str(passed_path.relative_to(HERE)),
            "auditJSONLCompressed": str(audit_path.relative_to(HERE)),
        },
        "note": "Research-only source filter. It does not modify the production training bank and does not claim solver feasibility.",
    }
    write_json(HERE / "filter-summary.json", summary)
    write_json(HERE / "filtered-source-shapes.json", {
        "schema": "cb01-source-filtered-manifest-v1",
        "status": "research-only",
        "sourceBank": str(BANK.relative_to(ROOT)),
        "sourceBankSHA256": source_hash,
        "rules": rules,
        "count": passed_count,
        "rowsPath": str(passed_path.relative_to(HERE)),
    })
    write_json(HERE / "source-filter-audit.json", {
        "schema": "cb01-source-filter-audit-manifest-v1",
        "status": "research-only",
        "sourceBank": str(BANK.relative_to(ROOT)),
        "sourceBankSHA256": source_hash,
        "count": expanded,
        "rowsPath": str(audit_path.relative_to(HERE)),
    })
    print(json.dumps({"sourceTargets": len(bank["targets"]), "expanded": expanded, "passed": passed_count, "rejected": rejected_count, "reasons": dict(rejection_reasons)}, ensure_ascii=False))

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["filter"])
    args = parser.parse_args()
    if args.command == "filter":
        run_filter()


if __name__ == "__main__":
    main()
