#!/usr/bin/env python3
"""Keep all paired native measurements; do not substitute device utilization."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics


def median(values):
    if not values:
        raise ValueError("Empty measurement")
    return statistics.median(values)


def percentile(values, fraction):
    # Nearest rank, fixed before interpreting candidate tails; retain every frame.
    return sorted(values)[max(0, math.ceil(len(values)*fraction)-1)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    candidates = []
    for path in (args.evidence / "attachments").glob("**/*"):
        if path.is_file() and path.suffix == ".json":
            try:
                value = json.loads(path.read_text())
            except (ValueError, UnicodeError):
                continue
            if isinstance(value, dict) and value.get("study", "").startswith("static-cloth-"):
                candidates.append((path, value))
    if len(candidates) != 1:
        raise ValueError(f"Expected one complete report, found {len(candidates)}")
    path, report = candidates[0]
    expected = {"static-cloth-B0": 12, "static-cloth-B0-daily": 3, "static-cloth-candidate": 8}
    if not report["completed"] or len(report["rows"]) != expected[report["study"]]:
        raise ValueError("Incomplete baseline")
    summaries = []
    for row in report["rows"]:
        pairs = []
        for cycle in range(6):
            arms = {arm: [frame["gpuSpanMS"]
                          for slot in row["times"] if slot["cycle"] == cycle and slot["arm"] == arm
                          for frame in slot["frames"]] for arm in ("A", "B")}
            if any(len(samples) != 64 for samples in arms.values()):
                raise ValueError("Missing or duplicate frames")
            a, b = median(arms["A"]), median(arms["B"])
            pair = {"cycle": cycle, "A_ms": a, "B_ms": b, "reduction_pct": (a-b)/a*100}
            for name, fraction in [("P95",0.95),("P99",0.99)]:
                av,bv = [percentile(arms[arm],fraction) for arm in ("A","B")]
                pair.update({name+"_A_ms":av,name+"_B_ms":bv,name+"_change_pct":(bv-av)/av*100})
            pairs.append(pair)
        summaries.append({"pose": row["pose"], "variant": row["variant"],
            "A_ms": median([p["A_ms"] for p in pairs]), "B_ms": median([p["B_ms"] for p in pairs]),
            "median_reduction_pct": median([p["reduction_pct"] for p in pairs]),
            "absolute_pair_change_median_pct": median([abs(p["reduction_pct"]) for p in pairs]),
            "faster_pairs": sum(p["reduction_pct"] > 0 for p in pairs), "pairs": pairs,
            "maximum_image_difference": row["maximum"], "changed_pixels": row["changedPixels"],
            "eye": row["eye"], "down": row["down"], "fov": row["fov"],
            "thermal_states": sorted({s["thermal"] for s in row["times"]})})
        for name in ["P95","P99"]:
            summaries[-1][name+"_change_median_pct"] = median([p[name+"_change_pct"] for p in pairs])
            summaries[-1][name+"_absolute_change_median_pct"] = median([abs(p[name+"_change_pct"]) for p in pairs])
        summaries[-1]["cpu_encode_median_ms"] = {arm: median([f["cpuEncodeMS"] for s in row["times"] if s["arm"]==arm for f in s["frames"]]) for arm in ("A","B")}
    summary = {"source": str(path), "sourceSHA256": hashlib.sha256(path.read_bytes()).hexdigest(),
               "device": report["device"], "shaderSHA256": report["sourceSHA"], "rows": summaries,
               "quality": report.get("quality",[]),
               "scope": report["scope"]}
    (args.evidence / "analysis.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    for r in summaries:
        print(f'{r["pose"]:12} {r["variant"]:18} {r["A_ms"]:.4f} -> {r["B_ms"]:.4f} ms '
              f'{r["median_reduction_pct"]:+.2f}% {r["faster_pairs"]}/6 maxΔ={r["maximum_image_difference"]}')


if __name__ == "__main__":
    main()
