#!/usr/bin/env python3
"""Compare six generation anchors using angle and OP distance only.

No pocket-width, collision, power, spin, scratch or position-play evaluation.
Outputs are geometric screening decisions, not potting feasibility proofs.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, dataclass
import hashlib
import json
import math
from pathlib import Path
import time

Point = tuple[float, float]  # SceneKit X/Z, metres; Y is up.
ROOT = Path(__file__).resolve().parents[2]
RULE_VERSION = "generation-anchor-angle-distance-v1"
# Arithmetic roundoff only; neither is a gameplay tolerance.
ANGLE_EPS = 1e-9
DISTANCE_EPS = 1e-12


@dataclass(frozen=True)
class Thresholds:
    angle_improvement_degrees: float = 15.0
    distance_improvement_metres: float = 0.30
    distance_reduction_fraction: float = 0.25

    def __post_init__(self):
        if not all(math.isfinite(v) for v in asdict(self).values()):
            raise ValueError("Thresholds must be finite")
        if not (0 < self.angle_improvement_degrees < 90
                and self.distance_improvement_metres > 0
                and 0 < self.distance_reduction_fraction < 1):
            raise ValueError("Invalid angle/distance thresholds")


@dataclass(frozen=True)
class Geometry:
    length: float
    width: float
    radius: float

    def __post_init__(self):
        if not all(math.isfinite(v) and v > 0 for v in asdict(self).values()):
            raise ValueError("Geometry must be finite and positive")
        if 2 * self.radius >= min(self.length, self.width):
            raise ValueError("Ball does not fit the playfield")

    def anchors(self) -> tuple[Point, ...]:
        # Matches GridGeometry.generationAnchor, including the original IDs.
        x, z = self.length / 2 - self.radius, self.width / 2 - self.radius
        return ((-x, -z), (x, -z), (-x, z), (x, z),
                (0.0, -self.width / 2), (0.0, self.width / 2))


@dataclass(frozen=True)
class PocketMetrics:
    pocket: int
    cut_degrees: float
    object_distance_metres: float


@dataclass(frozen=True)
class Decision:
    # keep means no alternative meets THIS rule, not physically feasible.
    status: str
    original: PocketMetrics
    alternatives: tuple[PocketMetrics, ...]
    metrics: tuple[PocketMetrics, ...]


def clearly_better(original: PocketMetrics, candidate: PocketMetrics,
                   thresholds: Thresholds = Thresholds()) -> bool:
    """All three inclusive comparisons must pass; ratios use ORIGINAL distance."""
    for metric in (original, candidate):
        if not (math.isfinite(metric.cut_degrees) and 0 <= metric.cut_degrees <= 180
                and math.isfinite(metric.object_distance_metres)
                and metric.object_distance_metres > 0):
            raise ValueError("Invalid pocket metrics")
    return (candidate.pocket != original.pocket
            and original.cut_degrees - candidate.cut_degrees + ANGLE_EPS
            >= thresholds.angle_improvement_degrees
            and original.object_distance_metres - candidate.object_distance_metres
            + DISTANCE_EPS >= thresholds.distance_improvement_metres
            and candidate.object_distance_metres <= original.object_distance_metres
            * (1 - thresholds.distance_reduction_fraction) + DISTANCE_EPS)


def point(value: dict) -> Point:
    return float(value["x"]), float(value["z"])


def pocket_metrics(cue: Point, target: Point, anchor: Point,
                   radius: float, pocket: int) -> PocketMetrics:
    if not all(math.isfinite(v) for p in (cue, target, anchor) for v in p):
        raise ValueError("Non-finite coordinates")
    dx, dz = anchor[0] - target[0], anchor[1] - target[1]
    distance = math.hypot(dx, dz)
    if distance <= DISTANCE_EPS or not math.isfinite(radius) or radius <= 0:
        raise ValueError("Undefined anchor direction or radius")
    ux, uz = dx / distance, dz / distance
    # Ghost G = O - 2R * unit(P-O). Cut is angle(G-C, P-O), not angle(O-C, P-O).
    gx, gz = target[0] - 2 * radius * ux, target[1] - 2 * radius * uz
    vx, vz = gx - cue[0], gz - cue[1]
    if math.hypot(vx, vz) <= DISTANCE_EPS:
        raise ValueError("Cue coincides with ghost; cut is undefined")
    cut = math.degrees(math.atan2(abs(vx * uz - vz * ux), vx * ux + vz * uz))
    return PocketMetrics(pocket, cut, distance)


def evaluate_layout(cue: Point, target: Point, original_pocket: int,
                    geometry: Geometry,
                    thresholds: Thresholds = Thresholds()) -> Decision:
    """Pure, deterministic six-pocket filter. Invalid geometry raises, never drops."""
    if type(original_pocket) is not int or original_pocket not in range(6):
        raise ValueError("Pocket ID must be an integer in 0...5")
    if math.dist(cue, target) < 2 * geometry.radius - DISTANCE_EPS:
        raise ValueError("Overlapping cue/object balls")
    metrics = tuple(pocket_metrics(cue, target, p, geometry.radius, i)
                    for i, p in enumerate(geometry.anchors()))
    original = metrics[original_pocket]
    alternatives = tuple(m for m in metrics if clearly_better(original, m, thresholds))
    return Decision("drop" if alternatives else "keep", original, alternatives, metrics)


def layouts(bank: dict):
    """Restore the exact masks order used by TrainingGridBank.board(reference:)."""
    distances = bank["distanceSamples"]
    for t in bank["targets"]:
        ox, oz = point(t["object"])
        gx, gz = point(t["ghost"])
        length = math.hypot(gx - ox, gz - oz)
        bx, bz = (gx - ox) / length, (gz - oz) / length
        for mi, mask in enumerate(t["masks"]):
            a = math.radians(mi - 85)
            dx, dz = bx * math.cos(a) - bz * math.sin(a), bx * math.sin(a) + bz * math.cos(a)
            for bit, distance in enumerate(distances):
                if mask & (1 << bit):
                    yield (f"grid-v3:{t['inventoryTargetIndex']}:{mi}:{bit}",
                           (gx + distance * dx, gz + distance * dz), (ox, oz),
                           t["pocket"], abs(mi - 85))


def validate_bank(bank: dict, geometry: Geometry):
    if bank["schema"] != "layout-bank-grid-v2-combination-ids":
        raise ValueError("Unsupported bank schema")
    if len(bank["distanceSamples"]) != 11 or not all(
            math.isfinite(d) and d > 0 for d in bank["distanceSamples"]):
        raise ValueError("Invalid distance samples")
    anchors, counts, seen = geometry.anchors(), Counter(), set()
    for t in bank["targets"]:
        pid = t["pocket"]
        if type(pid) is not int or pid not in range(6):
            raise ValueError("Invalid pocket ID")
        if t["inventoryTargetIndex"] in seen:
            raise ValueError("Duplicate inventory target ID")
        seen.add(t["inventoryTargetIndex"])
        if math.dist(point(t["aim"]), anchors[pid]) > DISTANCE_EPS:
            raise ValueError("Stored anchor does not match generation contract")
        o, g, p = point(t["object"]), point(t["ghost"]), anchors[pid]
        distance = math.dist(o, p)
        expected_g = tuple(o[i] - 2 * geometry.radius * (p[i] - o[i]) / distance for i in range(2))
        if math.dist(g, expected_g) > DISTANCE_EPS:
            raise ValueError("Stored ghost does not match generation contract")
        masks = t["masks"]
        if len(masks) != 171 or any(type(m) is not int or not 0 <= m < 2048 for m in masks):
            raise ValueError("Invalid masks")
        count = sum(bin(m).count("1") for m in masks)
        if count != len(t["combinationIndices"]):
            raise ValueError("Mask/combination count mismatch")
        counts["corner" if pid < 4 else "middle"] += count
    if dict(counts) != bank["counts"]:
        raise ValueError("Bank counts mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bank", type=Path, default=ROOT / "QiuJi/Resources/training-grid-bank.json")
    parser.add_argument("--output", type=Path, required=True, help="New output directory; never replaces bank")
    parser.add_argument("--limit", type=int, help="Optional prefix for CLI smoke tests")
    args = parser.parse_args()
    if args.limit is not None and args.limit <= 0:
        parser.error("--limit must be positive")
    source = args.bank.read_bytes()
    bank = json.loads(source)
    geometry = Geometry(**{k: bank["geometry"][k] for k in ("length", "width", "radius")})
    thresholds = Thresholds()
    validate_bank(bank, geometry)
    args.output.mkdir(parents=True, exist_ok=False)
    start, totals, by_pocket, samples = time.monotonic(), Counter(), {}, []
    max_angle_error = 0.0
    with (args.output / "excluded.jsonl").open("x") as excluded:
        for index, (lid, cue, target, pid, expected_angle) in enumerate(layouts(bank)):
            if args.limit is not None and index >= args.limit:
                break
            decision = evaluate_layout(cue, target, pid, geometry, thresholds)
            error = abs(decision.original.cut_degrees - expected_angle)
            max_angle_error = max(max_angle_error, error)
            if error > ANGLE_EPS:
                raise ValueError(f"Generation angle roundtrip mismatch at {lid}: {error}")
            totals[decision.status] += 1
            by_pocket.setdefault(str(pid), Counter())[decision.status] += 1
            if decision.status == "drop":
                excluded.write(json.dumps({"id": lid, "original": asdict(decision.original),
                    "alternatives": [asdict(m) for m in decision.alternatives]}, separators=(",", ":")) + "\n")
            if len(samples) < 12 and (not samples or (pid, decision.status) not in
                    {(s["original"]["pocket"], s["status"]) for s in samples}):
                samples.append(dict(id=lid, cue=cue, target=target, **asdict(decision)))
    complete = sum(totals.values()) == sum(bank["counts"].values())
    if args.limit is None and not complete:
        raise ValueError("Incomplete bank scan")
    if args.bank.read_bytes() != source:
        raise ValueError("Source bank changed during scan")
    summary = dict(rule=RULE_VERSION, thresholds=asdict(thresholds), geometry=asdict(geometry),
        source=str(args.bank.resolve()), sourceSHA256=hashlib.sha256(source).hexdigest(),
        scriptSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        complete=complete, counts=dict(totals), byOriginalPocket=by_pocket,
        maxGenerationAngleErrorDegrees=max_angle_error, seconds=time.monotonic()-start,
        scope="Only generation-anchor cut and OP distance; no physical feasibility or pocket-width evaluation")
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    (args.output / "samples.json").write_text(json.dumps(samples, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
