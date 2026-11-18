#!/usr/bin/env python3
"""Summarize retained XCTest JSON measurements without treating a small N as P95."""
import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


def summarize(rows):
    groups = defaultdict(list)
    for row in rows:
        groups[row["case"]].append(row)
    result = {}
    for label, samples in groups.items():
        item = {"runs": len(samples), "terminations": [r["termination"] for r in samples]}
        for field in ("solveMS", "freezeMS", "encodeMS", "bytes", "samples", "intervals",
                      "maxInterpolationErrorM", "endpointCorrectionM"):
            values = [r[field] for r in samples if field in r]
            if not values:
                continue
            warm = values[1:]
            item[field] = {"raw": values, "first": values[0], "max": max(values),
                           "warmMedian": statistics.median(warm) if warm else None,
                           "warmP95": sorted(warm)[math.ceil(.95 * len(warm)) - 1]
                           if len(warm) >= 20 else None}
        first = samples[0]
        item["worstTime"] = first.get("worstTime")
        item["worstKey"] = first.get("worstKey")
        item["errorWindows"] = first.get("discontinuities", [])
        result[label] = item
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = summarize(json.loads(args.input.read_text()))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    for label, item in result.items():
        print(label, "solveMS=", item["solveMS"]["raw"],
              "errorM=", item.get("maxInterpolationErrorM", {}).get("max"),
              "time=", item["worstTime"], "ball=", item["worstKey"])
