#!/usr/bin/env python3
"""Generate and summarize the CB-01 E2 focused boundary sweep.

E2 is research-only. It reuses E0 layouts, adds no-obstacle masse controls, and
keeps the production training bank and training pages untouched.
"""
from __future__ import annotations

import argparse
import json
import math
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BANK = ROOT / "QiuJi/Resources/training-grid-bank.json"

DISTANCE_BITS = (5, 7, 9)
JUMP_ELEVATIONS = (40, 50, 60, 70)
JUMP_SPEEDS = (3.5, 4.5, 5.0)
JUMP_SPIN_Y = (0.10, 0.25, 0.40)
JUMP_OBSTACLE_RATIOS = (0.30, 0.50, 0.70)
MASSE_ELEVATIONS = (15, 20, 25)
MASSE_SPEEDS = (1.0, 1.5, 2.0)
MASSE_SPIN_X = (-0.30, 0.0, 0.30)
MASSE_SPIN_Y = (-0.55, -0.40, -0.25)
MASSE_OBSTACLE_MODES = (None, 0.50, 0.70)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def actual_contact_up(spin_x: float, spin_y: float, elevation_degrees: float) -> float:
    theta = math.radians(elevation_degrees)
    c = math.sqrt(max(0.0, 1.0 - spin_x * spin_x - spin_y * spin_y))
    return math.sin(theta) * c + math.cos(theta) * spin_y


def selected_layouts() -> list[dict]:
    first = json.loads((HERE / "first-batch.json").read_text())
    layouts = [
        item for item in first["layouts"]
        if item["technique"] == "jump"
        and float(item["obstacleRatio"]) == 0.50
        and int(item["distanceBit"]) in DISTANCE_BITS
    ]
    if len(layouts) < 18:
        raise ValueError(f"expected at least 18 selected layouts, got {len(layouts)}")
    return layouts


def obstacle_at_ratio(layout: dict, obstacle_ratio: float) -> dict:
    cue = layout["cue"]
    target = layout["target"]
    return {
        "x": cue["x"] + obstacle_ratio * (target["x"] - cue["x"]),
        "z": cue["z"] + obstacle_ratio * (target["z"] - cue["z"]),
    }


def common_job(layout: dict, technique: str, elevation: int, speed: float, spin_x: float,
               spin_y: float, obstacle_enabled: bool, obstacle_ratio: float,
               control_type: str) -> dict:
    mode = "none" if not obstacle_enabled else f"ratio-{int(obstacle_ratio * 100):02d}"
    e2_id = (
        f"e2-{technique}-{layout['layoutID']}-e{elevation}-v{speed}"
        f"-x{spin_x}-y{spin_y}-o{mode}"
    )
    return {
        "id": e2_id,
        "e2ID": e2_id,
        "e2Phase": "center-diagnostic",
        "nominalID": e2_id,
        "controlType": control_type,
        "technique": technique,
        "layoutID": layout["layoutID"],
        "familyID": layout["familyID"],
        "sourceGridID": layout["sourceGridID"],
        "pocket": layout["pocket"],
        "cue": layout["cue"],
        "target": layout["target"],
        "ghost": layout["ghost"],
        "obstacle": obstacle_at_ratio(layout, obstacle_ratio) if obstacle_enabled else layout["obstacle"],
        "obstacleEnabled": obstacle_enabled,
        "obstacleMode": mode,
        "obstacleRatio": obstacle_ratio,
        "cueObjectDistanceMetres": layout["cueObjectDistanceMetres"],
        "cueAxisRailClearanceMetres": layout["cueAxisRailClearanceMetres"],
        "cutAngleDegrees": layout["cutAngleDegrees"],
        "distanceBit": layout["distanceBit"],
        "elevationDegrees": elevation,
        "speedMPS": speed,
        "spinX": spin_x,
        "spinY": spin_y,
        "actualContactUpOverR": actual_contact_up(spin_x, spin_y, elevation),
    }


def build_jobs() -> list[dict]:
    layouts = selected_layouts()
    jobs: list[dict] = []
    for layout in layouts:
        for elevation in JUMP_ELEVATIONS:
            for speed in JUMP_SPEEDS:
                for spin_y in JUMP_SPIN_Y:
                    for ratio in JUMP_OBSTACLE_RATIOS:
                        jobs.append(common_job(
                            layout, "jump", elevation, speed, 0.0, spin_y,
                            True, ratio, "jump-obstacle-center",
                        ))
        for elevation in MASSE_ELEVATIONS:
            for speed in MASSE_SPEEDS:
                for spin_x in MASSE_SPIN_X:
                    for spin_y in MASSE_SPIN_Y:
                        for ratio in MASSE_OBSTACLE_MODES:
                            enabled = ratio is not None
                            jobs.append(common_job(
                                layout, "masse", elevation, speed, spin_x, spin_y,
                                enabled, float(ratio or 0.0),
                                "masse-no-obstacle-control" if not enabled else "masse-obstacle-center",
                            ))
    return jobs


def prepare() -> None:
    jobs = build_jobs()
    first = json.loads((HERE / "first-batch.json").read_text())
    request = {
        "schema": "cb01-e2-request-v1",
        "status": "research-only",
        "phase": "center-diagnostic",
        "sourceBankSHA256": first["sourceBankSHA256"],
        "selectedDistanceBits": list(DISTANCE_BITS),
        "jobs": jobs,
        "limits": {"maxEvents": 3000, "maxTimeSeconds": 40.0},
        "purpose": {
            "masse": "compare no-obstacle and three actual obstacle placements before deciding why no target was potted",
            "jump": "refine the observed 40-70 degree and 3.5-5.0 m/s window across three distances and actual obstacle placements",
        },
    }
    write_json(HERE / "e2-request.json", request)
    write_json(HERE / "e2-jobs.json", {"schema": "cb01-e2-jobs-v1", "count": len(jobs), "jobs": jobs})
    write_json(HERE / "e2-plan.json", {
        "schema": "cb01-e2-plan-v1",
        "selectedLayouts": len(selected_layouts()),
        "jumpJobs": sum(item["technique"] == "jump" for item in jobs),
        "masseJobs": sum(item["technique"] == "masse" for item in jobs),
        "totalJobs": len(jobs),
        "distanceBits": list(DISTANCE_BITS),
        "jump": {"elevations": JUMP_ELEVATIONS, "speeds": JUMP_SPEEDS, "spinY": JUMP_SPIN_Y, "obstacleRatios": JUMP_OBSTACLE_RATIOS},
        "masse": {"elevations": MASSE_ELEVATIONS, "speeds": MASSE_SPEEDS, "spinX": MASSE_SPIN_X, "spinY": MASSE_SPIN_Y, "obstacleModes": ["none", 0.50, 0.70]},
        "acceptance": {
            "masse": "report no-obstacle versus obstacle-safe and target-pocket events separately",
            "jump": "report center-safe and center-potted rates by distance, elevation, speed and obstacle ratio",
        },
    })
    print(json.dumps({"jobs": len(jobs), "jump": sum(item["technique"] == "jump" for item in jobs), "masse": sum(item["technique"] == "masse" for item in jobs)}, ensure_ascii=False))


def ingest(log_path: Path) -> None:
    rows = []
    for line in log_path.read_text(errors="replace").splitlines():
        if line.startswith("CB01_ROW\t"):
            rows.append(json.loads(line.split("\t", 1)[1]))
    if not rows:
        raise RuntimeError(f"no CB01_ROW records found in {log_path}")
    request = json.loads((HERE / "e2-request.json").read_text())
    result = {
        "schema": "cb01-e2-results-v1",
        "rows": rows,
        "count": len(rows),
        "sourceBankSHA256": request["sourceBankSHA256"],
        "solver": "ShotPredictor.simulateFree:spatialPractice",
        "ingestSource": str(log_path),
    }
    write_json(HERE / "e2-results.json", result)
    print(json.dumps({"rows": len(rows)}, ensure_ascii=False))


def report() -> None:
    result = json.loads((HERE / "e2-results.json").read_text())
    rows = result["rows"]
    groups: dict[tuple[str, str, float], list[dict]] = defaultdict(list)
    for row in rows:
        groups[(row["technique"], row.get("obstacleMode", "unknown"), float(row["cueObjectDistanceMetres"]))].append(row)
    summaries = []
    for (technique, mode, distance), values in sorted(groups.items()):
        summaries.append({
            "technique": technique,
            "obstacleMode": mode,
            "cueObjectDistanceMetres": distance,
            "samples": len(values),
            "baseSafe": sum(bool(item.get("baseSafe")) for item in values),
            "basePotted": sum(bool(item.get("basePotted")) for item in values),
            "baseSafeRate": sum(bool(item.get("baseSafe")) for item in values) / len(values),
            "basePottedRate": sum(bool(item.get("basePotted")) for item in values) / len(values),
            "obstacleContacts": sum(bool(item.get("obstacleContact")) for item in values),
            "cueEscaped": sum(bool(item.get("cueEscaped")) for item in values),
            "targetEscaped": sum(bool(item.get("targetEscaped")) for item in values),
        })
    write_json(HERE / "e2-summary.json", {
        "schema": "cb01-e2-summary-v1",
        "status": "pass",
        "rows": len(rows),
        "groups": summaries,
    })
    print(json.dumps({"rows": len(rows), "groups": len(summaries)}, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["prepare", "ingest", "report"])
    parser.add_argument("--log", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare()
    elif args.command == "ingest":
        if args.log is None:
            parser.error("ingest requires --log")
        ingest(args.log)
    else:
        report()


if __name__ == "__main__":
    main()
