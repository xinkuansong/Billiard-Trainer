#!/usr/bin/env python3
"""Summarize SCNAction evaluation traces; these are not GPU display receipts."""
import argparse
import json
import math
import statistics
from pathlib import Path


def distribution(values):
    ordered = sorted(values)
    return {"count": len(values), "min": min(values), "p50": statistics.median(values),
            "p95": ordered[math.ceil(.95 * len(values)) - 1], "max": max(values)} if values else {}


def summarize(trace):
    rows = trace["rows"]
    wall = [b[0] - a[0] for a, b in zip(rows, rows[1:])]
    shot = [b[1] - a[1] for a, b in zip(rows, rows[1:])]
    steps = [math.dist(a[2:5], b[2:5]) for a, b in zip(rows, rows[1:])]
    lag = [math.dist(row[2:5], row[5:8]) for row in rows]
    plateaus = []
    start = None
    for i, step in enumerate(steps):
        if step < 1e-7:
            if start is None:
                start = i
        else:
            if start is not None and step > .001:
                plateaus.append({"shotStart": rows[start][1], "shotEnd": rows[i][1],
                                 "wallDurationMS": (rows[i][0] - rows[start][0]) * 1000,
                                 "nextStepMM": step * 1000})
            start = None
    return {"source": "SCNAction callback, not display/GPU frame receipt", "speed": trace["speed"],
            "rows": len(rows), "wallIntervalMS": distribution([v * 1000 for v in wall]),
            "shotIntervalMS": distribution([v * 1000 for v in shot]),
            "modelToPresentationMM": distribution([v * 1000 for v in lag]),
            "timeRegressions": sum(v < 0 for v in shot), "sameShotTime": sum(v == 0 for v in shot),
            "stationaryThenMoving": plateaus}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = summarize(json.loads(args.input.read_text()))
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, ensure_ascii=False))
