#!/usr/bin/env python3
"""Independently audit exported masks/codes and scores using complex-vector dot products."""
import argparse
from collections import Counter
import cmath
import hashlib
import json
import math
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entries(target):
    codes = iter(target["combinationIndices"])
    for mi, mask in enumerate(target["masks"]):
        for bit in range(11):
            if mask & 2**bit:
                yield mi, bit, next(codes)
    assert next(codes, None) is None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.output / "manifest.json").read_text())
    source = Path(manifest["source"])
    assert digest(source) == manifest["sourceSHA256"]
    for name, expected in manifest["artifacts"].items():
        assert digest(args.output / name) == expected, name
    bank = json.loads(source.read_text())
    derived = json.loads((args.output / "geometric-filtered-bank.json").read_text())
    changed = {"targets", "counts", "contract", "sourceLayoutBankSHA256"}
    assert all(derived[k] == v for k, v in bank.items() if k not in changed)
    target_map = {t["inventoryTargetIndex"]: t for t in derived["targets"]}
    assert len(target_map) == len(derived["targets"])
    assert set(target_map) <= {t["inventoryTargetIndex"] for t in bank["targets"]}
    g = bank["geometry"]
    r, x, z = g["radius"], g["length"] / 2, g["width"] / 2
    anchors = [complex(-x+r, -z+r), complex(x-r, -z+r), complex(-x+r, z-r),
               complex(x-r, z-r), complex(0, -z), complex(0, z)]
    counts, pocket_counts, combo_counts = Counter(), Counter(), Counter()
    closest_margin, max_score_error = math.inf, 0
    with (args.output / "excluded.jsonl").open() as stream:
        for target in bank["targets"]:
            tid, pid = target["inventoryTargetIndex"], target["pocket"]
            saved = target_map.get(tid)
            if saved is not None:
                assert set(saved) == set(target)
                assert all(saved[k] == v for k, v in target.items()
                           if k not in {"masks", "combinationIndices"})
            retained = {(mi, bit): code for mi, bit, code in entries(saved)} if saved else {}
            obj = complex(target["object"]["x"], target["object"]["z"])
            ghost = complex(target["ghost"]["x"], target["ghost"]["z"])
            back = (ghost - obj) / abs(ghost - obj)
            valid_count = 0
            for mi, bit, code in entries(target):
                cue = ghost + bank["distanceSamples"][bit] * back * cmath.exp(1j * math.pi * (mi-85) / 180)
                scores = []
                for p in anchors:
                    outgoing = p - obj
                    incoming = obj - 2*r*outgoing/abs(outgoing) - cue
                    dot = (incoming.conjugate() * outgoing).real
                    scores.append(abs(outgoing)**2 * abs(incoming) / dot if dot > 0 else math.inf)
                best = min(s for i, s in enumerate(scores) if i != pid)
                drop = best <= .7*scores[pid]
                closest_margin = min(closest_margin, abs(best/scores[pid] - .7))
                status = "drop" if drop else "keep"
                counts[status] += 1
                pocket_counts[pid, status] += 1
                combo_counts[code, status] += 1
                lid = f"grid-v3:{tid}:{mi}:{bit}"
                if drop:
                    assert (mi, bit) not in retained, lid
                    row = json.loads(next(stream))
                    assert row["id"] == lid and row["original"]["pocket"] == pid
                    best_pid = row["bestAlternative"]["pocket"]
                    assert best_pid != pid and math.isclose(scores[best_pid], best, rel_tol=1e-10)
                    for actual, expected in ((row["original"]["score"], scores[pid]),
                                             (row["bestAlternative"]["score"], best)):
                        max_score_error = max(max_score_error, abs(actual-expected))
                        assert math.isclose(actual, expected, rel_tol=1e-10, abs_tol=1e-12)
                    assert math.isclose(row["scoreRatio"], best/scores[pid], rel_tol=1e-10)
                else:
                    assert retained.get((mi, bit)) == code, lid
                    valid_count += 1
            assert valid_count == len(retained), tid
        assert next(stream, None) is None, "Extra exclusion rows"
    summary = json.loads((args.output / "summary.json").read_text())
    assert dict(counts) == summary["counts"]
    assert sum(counts.values()) == sum(bank["counts"].values())
    assert counts["keep"] == sum(derived["counts"].values())
    for pid in range(6):
        for status in ("keep", "drop"):
            assert pocket_counts[pid, status] == summary["byOriginalPocket"][str(pid)][status]
    combinations = json.loads((args.output / "combination-counts.json").read_text())
    for code, row in enumerate(combinations):
        assert all(row[k] == v for k, v in bank["combinationTable"][code].items())
        for status in ("keep", "drop"):
            assert combo_counts[code, status] == row[status]
        assert row["source"] == row["keep"] + row["drop"]
    assert digest(source) == manifest["sourceSHA256"]
    report = dict(passed=True, independentlyRecomputed=sum(counts.values()), counts=dict(counts),
                  method="Complex-vector reconstruction; S=|OP|^2*|GC|/dot(GC,OP)",
                  exactPartitionAndCombinationCodes=True, immutableTargetFieldsUnchanged=True,
                  closestRatioDistanceToThreshold=closest_margin, maxScoreDifference=max_score_error,
                  sourceUnchanged=True, artifactHashesVerified=True, auditorSHA256=digest(Path(__file__)))
    (args.output / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
