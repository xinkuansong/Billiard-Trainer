#!/usr/bin/env python3
"""Export a deletion-only bank using the user-approved 30% geometric score rule."""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict
import hashlib
import json
import math
from pathlib import Path

from pocket_geometry_filter import Geometry, PocketMetrics, ROOT, layouts, pocket_metrics, validate_bank

RULE = "generation-anchor-distance-over-cos-30pct-v1"
RATIO = 0.70


def score(metric: PocketMetrics) -> float | None:
    if not (math.isfinite(metric.cut_degrees) and 0 <= metric.cut_degrees <= 180
            and math.isfinite(metric.object_distance_metres) and metric.object_distance_metres > 0):
        raise ValueError("Invalid metric")
    if metric.cut_degrees >= 90:
        return None
    return metric.object_distance_metres / math.cos(math.radians(metric.cut_degrees))


def rank_alternatives(metrics, original_pocket):
    original = metrics[original_pocket]
    original_score = score(original)
    if original_score is None:
        raise ValueError("Original pocket must have a cut below 90 degrees")
    ranked = sorted(((score(m), m.pocket, m) for m in metrics
                     if m.pocket != original_pocket and score(m) is not None),
                    key=lambda item: (item[0], item[1]))
    better = [item for item in ranked if item[0] <= RATIO * original_score]
    return original_score, ranked, better


def retain_target(target, keep_ids):
    """Filter masks and their parallel combination codes without reclassifying."""
    masks, codes, source_index = [], [], 0
    for mi, mask in enumerate(target["masks"]):
        retained_mask = 0
        for bit in range(11):
            if mask & (1 << bit):
                lid = f"grid-v3:{target['inventoryTargetIndex']}:{mi}:{bit}"
                if lid in keep_ids:
                    retained_mask |= 1 << bit
                    codes.append(target["combinationIndices"][source_index])
                source_index += 1
        masks.append(retained_mask)
    if source_index != len(target["combinationIndices"]):
        raise ValueError("Mask/combination alignment mismatch")
    return dict(target, masks=masks, combinationIndices=codes)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bank", type=Path, default=ROOT / "QiuJi/Resources/training-grid-bank.json")
    parser.add_argument("--review", type=Path, default=ROOT / "output/two-ball-pocket-filter-20261024/review-r2-30pct/samples.json")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raw = args.bank.read_bytes()
    bank = json.loads(raw)
    geometry = Geometry(**{k: bank["geometry"][k] for k in ("length", "width", "radius")})
    validate_bank(bank, geometry)
    review_raw = args.review.read_bytes()
    review = json.loads(review_raw)
    if review["sourceSHA256"] != sha(raw) or review["thresholds"]["score_ratio_max"] != RATIO:
        raise ValueError("Review source or rule differs")
    expected = {s["id"]: s for s in review["samples"]}
    args.output.mkdir(parents=True, exist_ok=False)
    counts, by_pocket, keep_ids = Counter(), {str(i): Counter() for i in range(6)}, set()
    seen_review, max_angle_error = set(), 0.0
    anchors = geometry.anchors()
    with (args.output / "excluded.jsonl").open("x") as excluded:
        for lid, cue, obj, pid, expected_angle in layouts(bank):
            metrics = tuple(pocket_metrics(cue, obj, p, geometry.radius, i) for i, p in enumerate(anchors))
            original_score, ranked, better = rank_alternatives(metrics, pid)
            status = "drop" if better else "keep"
            error = abs(metrics[pid].cut_degrees - expected_angle)
            max_angle_error = max(max_angle_error, error)
            if error > 1e-9:
                raise ValueError(f"Angle reconstruction mismatch: {lid}")
            counts[status] += 1
            by_pocket[str(pid)][status] += 1
            if status == "keep":
                keep_ids.add(lid)
            else:
                best_score, best_pid, best_metric = ranked[0]
                excluded.write(json.dumps(dict(id=lid,
                    original=dict(asdict(metrics[pid]), score=original_score),
                    bestAlternative=dict(asdict(best_metric), score=best_score),
                    scoreRatio=best_score / original_score,
                    qualifyingAlternativePockets=[item[1] for item in better]),
                    separators=(",", ":"), allow_nan=False) + "\n")
            if lid in expected:
                s = expected[lid]
                best_pid = ranked[0][1] if ranked else None
                if status != s["status"] or best_pid != s["bestOtherPocket"]:
                    raise ValueError(f"R2 decision mismatch: {lid}")
                if [item[1] for item in better] != [m["pocket"] for m in s["alternatives"]]:
                    raise ValueError(f"R2 alternatives mismatch: {lid}")
                seen_review.add(lid)
    if sum(counts.values()) != sum(bank["counts"].values()) or seen_review != set(expected):
        raise ValueError("Incomplete source or review scan")
    retained_targets = [retain_target(t, keep_ids) for t in bank["targets"]]
    retained_targets = [t for t in retained_targets if t["combinationIndices"]]
    by_type = {kind: {status: sum(by_pocket[str(p)][status] for p in pockets)
                     for status in ("keep", "drop")}
               for kind, pockets in (("corner", range(4)), ("middle", range(4, 6)))}
    scope = ("Deletion only. Compare generation-anchor OP/cos(cut); other cuts >=90 degrees excluded. "
             "No candidate simulation or pocket-entry feasibility gate. No manual ID exceptions. "
             "Retained original pockets and coordinates unchanged; not installed in app.")
    provenance = dict(rule=RULE, scoreDefinition="object_distance_metres/cos(cut_degrees)",
                      scoreRatioMaximum=RATIO, parentSHA256=sha(raw), scope=scope,
                      upstreamSourceLayoutBankSHA256=bank.get("sourceLayoutBankSHA256"))
    result = dict(bank, targets=retained_targets,
                  counts={k: v["keep"] for k, v in by_type.items()},
                  sourceLayoutBankSHA256=sha(raw), geometricScreening=provenance,
                  sourceContract=bank["contract"],
                  contract=bank["contract"] + " Further deletion-only geometric score screening: " + scope)
    validate_bank(result, geometry)
    if {entry[0] for entry in layouts(result)} != keep_ids:
        raise ValueError("Export masks do not exactly restore retained IDs")
    original_codes = Counter(code for t in bank["targets"] for code in t["combinationIndices"])
    kept_codes = Counter(code for t in result["targets"] for code in t["combinationIndices"])
    if any(type(code) is not int or not 0 <= code < len(bank["combinationTable"]) for code in original_codes):
        raise ValueError("Invalid combination index")
    combinations = [dict(definition, source=original_codes[i], keep=kept_codes[i],
                         drop=original_codes[i]-kept_codes[i])
                    for i, definition in enumerate(bank["combinationTable"])]
    bank_path = args.output / "geometric-filtered-bank.json"
    bank_path.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":"), allow_nan=False) + "\n")
    # Round-trip the actual serialized artifact, not just the in-memory result.
    decoded = json.loads(bank_path.read_bytes())
    validate_bank(decoded, geometry)
    if decoded != result or args.bank.read_bytes() != raw:
        raise ValueError("Serialization mismatch or source modified during export")
    write_json(args.output / "combination-counts.json", combinations)
    summary = dict(complete=True, sourceTotal=sum(counts.values()), counts=dict(counts),
                   byOriginalPocket=by_pocket, byOriginalPocketType=by_type,
                   sourceTargetCount=len(bank["targets"]), retainedTargetCount=len(retained_targets),
                   emptyTargetsRemoved=len(bank["targets"])-len(retained_targets),
                   combinationDefinitionCount=len(bank["combinationTable"]),
                   occupiedCombinations=sum(v > 0 for v in kept_codes.values()),
                   reviewDecisionsAndBestAlternativesMatched=len(seen_review),
                   maxGenerationAngleErrorDegrees=max_angle_error, sourceUnchanged=True, **provenance)
    write_json(args.output / "summary.json", summary)
    dependencies = [Path(__file__), Path(__file__).with_name("pocket_geometry_filter.py")]
    write_json(args.output / "manifest.json", dict(source=str(args.bank.resolve()), sourceSHA256=sha(raw),
        review=str(args.review.resolve()), reviewSHA256=sha(review_raw),
        scripts={str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in dependencies},
        artifacts={p.name: sha(p.read_bytes()) for p in args.output.iterdir() if p.is_file()},
        rule=provenance))
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
