#!/usr/bin/env python3
"""Prepare one-obstacle, one-solution search plans from the 10k base sample.

This script only creates research requests. The actual solution is accepted
after the existing ShotPredictor research test reports a clean pot.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INPUT = HERE / "source-filter-sample-10000.jsonl.gz"
PLAN = HERE / "one-solution-plan-10000.jsonl.gz"
SUMMARY = HERE / "one-solution-plan-summary.json"
BANK = ROOT / "CuePhys/Resources/training-grid-bank.json"
if not BANK.exists():
    BANK = ROOT / "QiuJi/Resources/training-grid-bank.json"
RADIUS = 0.028575
MARGIN = 0.001
LENGTH = 2.540
WIDTH = 1.270
HALF_LENGTH = LENGTH / 2
HALF_WIDTH = WIDTH / 2

LONGITUDINAL_LEVELS = (0.30, 0.50, 0.70)
OCCLUSION_LEVELS = (1.00, 0.75, 0.50, 0.25)

# E2 seeds; prefer lower elevation within each technique. The execution request
# also sorts across techniques so high-elevation jumps are only a fallback.
JUMP_PARAMETERS = (
    (40, 5.0, 0.0, 0.25),
    (50, 3.5, 0.0, 0.10),
    (50, 5.0, 0.0, 0.25),
    (60, 4.5, 0.0, 0.10),
    (60, 5.0, 0.0, 0.10),
    (60, 3.5, 0.0, 0.10),
    (70, 4.5, 0.0, 0.25),
    (70, 5.0, 0.0, 0.40),
)
MASSE_PARAMETERS = (
    (15, 1.0, 0.0, -0.40),
    (15, 1.0, 0.3, -0.55),
    (15, 1.0, -0.3, -0.55),
    (15, 1.5, 0.0, -0.40),
    (20, 1.5, 0.0, -0.40),
    (25, 1.0, 0.0, -0.55),
    (15, 1.5, 0.3, -0.55),
    (25, 1.5, -0.3, -0.55),
    (25, 2.0, 0.0, -0.55),
)


def point(value: dict) -> tuple[float, float]:
    return float(value["x"]), float(value["z"])


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def legal_center(value: tuple[float, float]) -> bool:
    return abs(value[0]) <= HALF_LENGTH - RADIUS and abs(value[1]) <= HALF_WIDTH - RADIUS


def pocket_clearance(value: tuple[float, float], pocket: int) -> float:
    # The source filter uses the pocket centre/radius geometry. Keep this
    # lightweight check aligned with that research-only filter contract.
    pocket_centres = (
        (-1.3120000362, -0.6769999862),
        (1.3120000362, -0.6769999862),
        (-1.3120000362, 0.6769999862),
        (1.3120000362, 0.6769999862),
        (0.0, -0.67596474),
        (0.0, 0.67596474),
    )
    return distance(value, pocket_centres[pocket]) - (0.043 if pocket >= 4 else 0.042) - RADIUS


def segment_distance(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)))
    return distance(p, (a[0] + t * dx, a[1] + t * dz))


def obstacle_candidates(row: dict) -> list[dict]:
    cue = point(row["cue"])
    target = point(row["target"])
    delta = (target[0] - cue[0], target[1] - cue[1])
    span = math.hypot(*delta)
    unit = (delta[0] / span, delta[1] / span)
    normal = (-unit[1], unit[0])
    clear = 2 * RADIUS + MARGIN
    candidates = []
    for s in LONGITUDINAL_LEVELS:
        for q in OCCLUSION_LEVELS:
            h = (1 - q) * clear
            sides = (0,) if h == 0 else (1, -1)
            for side in sides:
                centre = (
                    cue[0] + s * delta[0] + side * h * normal[0],
                    cue[1] + s * delta[1] + side * h * normal[1],
                )
                failures = []
                if not legal_center(centre):
                    failures.append("obstacleOutsidePlayfield")
                if distance(cue, centre) < clear:
                    failures.append("cueObstacleTooClose")
                if distance(target, centre) < clear:
                    failures.append("targetObstacleTooClose")
                if min(pocket_clearance(centre, pocket) for pocket in range(6)) < 0:
                    failures.append("obstaclePocketZone")
                direct_clearance = segment_distance(centre, cue, point(row["ghost"])) - 2 * RADIUS
                if direct_clearance >= -MARGIN:
                    failures.append("directPotLineNotBlocked")
                candidates.append({
                    "s": s,
                    "q": q,
                    "side": side,
                    "h": h,
                    "center": {"x": centre[0], "z": centre[1]},
                    "directPotLineClearanceMetres": direct_clearance,
                    "failures": failures,
                })
    return candidates


def choose_obstacle(row: dict) -> dict:
    candidates = obstacle_candidates(row)
    # Rotate the cell order, rather than the side-expanded candidate order, so
    # q=1 receives the same quota as the offset cells with two mirror sides.
    cells = [(s, q) for s in LONGITUDINAL_LEVELS for q in OCCLUSION_LEVELS]
    start = (int(row["sampleIndex"]) - 1) % len(cells)
    for offset in range(len(cells)):
        s, q = cells[(start + offset) % len(cells)]
        cell_candidates = [item for item in candidates if item["s"] == s and item["q"] == q]
        preferred_side = 1 if ((int(row["sampleIndex"]) - 1) // len(cells)) % 2 == 0 else -1
        cell_candidates.sort(key=lambda item: (item["side"] != preferred_side, item["side"]))
        for candidate in cell_candidates:
            if not candidate["failures"]:
                return candidate
    return {"status": "noLegalObstacle", "candidates": candidates}


def read_plan_rows() -> list[dict]:
    return [json.loads(line) for line in gzip.open(INPUT, "rt", encoding="utf-8")]


def read_plans() -> list[dict]:
    return [json.loads(line) for line in gzip.open(PLAN, "rt", encoding="utf-8")]


def actual_contact_up(spin_x: float, spin_y: float, elevation_degrees: float) -> float:
    theta = math.radians(elevation_degrees)
    c = math.sqrt(max(0.0, 1.0 - spin_x * spin_x - spin_y * spin_y))
    return math.sin(theta) * c + math.cos(theta) * spin_y


def request_job(plan: dict, technique: str, parameters: tuple[float, float, float, float], candidate_index: int) -> dict:
    elevation, speed, spin_x, spin_y = parameters
    obstacle = plan["obstacle"]
    obstacle_mode = f"s{obstacle['s']:.2f}-q{obstacle['q']:.2f}-side{obstacle['side']}"
    job_id = f"one-{plan['sampleIndex']:05d}-{technique}-c{candidate_index:02d}"
    return {
        "id": job_id,
        "nominalID": job_id,
        "technique": technique,
        "layoutID": plan["sourceLayoutID"],
        "sourceGridID": f"filtered:{plan['sourceTargetIndex']}:{plan['maskIndex']}:{plan['distanceBit']}",
        "sourceTargetIndex": plan["sourceTargetIndex"],
        "maskIndex": plan["maskIndex"],
        "distanceBit": plan["distanceBit"],
        "sampleIndex": plan["sampleIndex"],
        "pocket": plan["pocket"],
        "cue": plan["cue"],
        "target": plan["target"],
        "ghost": plan["ghost"],
        "obstacle": obstacle["center"],
        "obstacleEnabled": True,
        "obstacleMode": obstacle_mode,
        "obstacleS": obstacle["s"],
        "obstacleQ": obstacle["q"],
        "obstacleSide": obstacle["side"],
        "obstacleLateralGapMetres": obstacle["h"],
        "cueObjectDistanceMetres": plan["cueTargetDistanceMetres"],
        "elevationDegrees": elevation,
        "speedMPS": speed,
        "spinX": spin_x,
        "spinY": spin_y,
        "actualContactUpOverR": actual_contact_up(spin_x, spin_y, elevation),
    }


def make_request(start: int, count: int) -> None:
    plans = read_plans()
    end = min(len(plans), start + count)
    if start < 0 or start >= end:
        raise ValueError(f"invalid request range {start}:{end}")
    jobs = []
    for plan in plans[start:end]:
        shape_jobs = []
        for candidate_index, parameters in enumerate(JUMP_PARAMETERS):
            shape_jobs.append(request_job(plan, "jump", parameters, candidate_index))
        for candidate_index, parameters in enumerate(MASSE_PARAMETERS):
            shape_jobs.append(request_job(plan, "masse", parameters, candidate_index))
        jobs.extend(sorted(shape_jobs, key=lambda job: job["elevationDegrees"]))
    name = f"one-solution-request-{start:05d}-{end:05d}.json"
    output = HERE / name
    payload = {
        "schema": "cb01-one-solution-request-v1",
        "status": "research-only",
        "sourceBankSHA256": hashlib.sha256(BANK.read_bytes()).hexdigest(),
        "planFile": str(PLAN),
        "planStart": start,
        "planEnd": end,
        "oneObstaclePerBaseShape": True,
        "oneSolutionSelection": "first basePotted row by candidate order",
        "limits": {"maxEvents": 3000, "maxTimeSeconds": 40.0},
        "jobs": jobs,
    }
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"planStart": start, "planEnd": end, "jobs": len(jobs), "request": str(output)}, ensure_ascii=False))


def select_results(result_paths: list[Path], output: Path) -> None:
    # Only v2 packets carry a verified early-stop prefix and strict safety gates.
    # Historical E1/E2 rows must never silently become bank candidates.
    import run_one_solution as runner

    current = json.loads((HERE / "one-solution-current-run.json").read_text())
    plans = {item["sampleIndex"]: item for item in read_plans()}
    selected, exhausted, seen = [], [], set()
    attempts = 0
    for path in result_paths:
        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8") as stream:
            packet = json.load(stream)
        if packet.get("schema") != "cb01-one-solution-result-v2":
            raise ValueError(f"{path}: requires v2 physical result packet, not legacy or synthetic rows")
        index = packet["sampleIndex"]
        if index in seen:
            raise ValueError(f"duplicate base shape {index}")
        seen.add(index)
        runner.validate(packet, runner.candidates(plans[index]), current["runIdentity"])
        attempts += len(packet["rows"])
        if packet["status"] == "solved":
            selected.append(packet["rows"][-1])
        else:
            exhausted.append(index)
    selected.sort(key=lambda row: row["sampleIndex"])
    with output.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=6, mtime=0) as compressed:
        for row in selected:
            compressed.write((json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode())
    summary = output.with_name(output.stem.replace(".jsonl", "") + "-summary.json")
    runner.atomic_json(summary, {
        "schema": "cb01-one-solution-selection-v2", "runIdentity": current["runIdentity"],
        "resultFiles": [str(path) for path in result_paths], "resultRows": attempts,
        "baseShapesWithResults": len(seen), "solvedBaseShapes": len(selected),
        "searchExhaustedBaseShapes": len(exhausted), "exhaustedSampleIndexes": sorted(exhausted),
        "techniques": {key: sum(row["technique"] == key for row in selected) for key in ("jump", "masse")},
        "output": str(output),
    })
    print(json.dumps({"solvedBaseShapes": len(selected), "output": str(output), "summary": str(summary)}, ensure_ascii=False))


def prepare() -> None:
    rows = read_plan_rows()
    if len(rows) != 10_000:
        raise AssertionError(f"expected 10000 base rows, found {len(rows)}")
    plans = []
    for row in rows:
        obstacle = choose_obstacle(row)
        plans.append({
            "sampleIndex": row["sampleIndex"],
            "sourceTargetIndex": row["sourceTargetIndex"],
            "maskIndex": row["maskIndex"],
            "distanceBit": row["distanceBit"],
            "sourceLayoutID": row["sourceLayoutID"],
            "sourceCombinationID": row["sourceCombinationID"],
            "pocket": row["pocket"],
            "angleIndex": row["angleIndex"],
            "railIndex": row["railIndex"],
            "cueTargetDistanceMetres": row["cueTargetDistanceMetres"],
            "cue": row["cue"],
            "target": row["target"],
            "ghost": row["ghost"],
            "obstacle": obstacle,
            "parameterCandidates": {
                "jump": len(JUMP_PARAMETERS),
                "masse": len(MASSE_PARAMETERS),
            },
        })
    with PLAN.open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=6, mtime=0) as compressed:
        for plan in plans:
            compressed.write((json.dumps(plan, ensure_ascii=False, separators=(",", ":")) + "\n").encode())
    legal = [plan for plan in plans if plan["obstacle"].get("failures") == []]
    obstacle_cells = {}
    for plan in legal:
        obstacle = plan["obstacle"]
        key = f"s{obstacle['s']:.2f}-q{obstacle['q']:.2f}"
        obstacle_cells[key] = obstacle_cells.get(key, 0) + 1
    summary = {
        "schema": "cb01-one-solution-plan-v1",
        "status": "research-only",
        "baseShapeCount": len(plans),
        "legalObstacleCount": len(legal),
        "noLegalObstacleCount": len(plans) - len(legal),
        "oneObstaclePerBaseShape": True,
        "obstacleLevels": {"s": LONGITUDINAL_LEVELS, "q": OCCLUSION_LEVELS},
        "obstacleCellCounts": dict(sorted(obstacle_cells.items())),
        "parameterCandidates": {"jump": len(JUMP_PARAMETERS), "masse": len(MASSE_PARAMETERS)},
        "inputSHA256": hashlib.sha256(INPUT.read_bytes()).hexdigest(),
        "outputs": {"plan": str(PLAN), "summary": str(SUMMARY)},
    }
    SUMMARY.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"count": len(plans), "legalObstacleCount": len(legal), "noLegalObstacleCount": len(plans) - len(legal), "plan": str(PLAN), "summary": str(SUMMARY)}, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["prepare", "make-request", "select"])
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--results", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare()
    elif args.command == "make-request":
        make_request(args.start, args.count)
    elif args.command == "select":
        if not args.results or args.output is None:
            parser.error("select requires --results and --output")
        select_results(args.results, args.output)


if __name__ == "__main__":
    main()
