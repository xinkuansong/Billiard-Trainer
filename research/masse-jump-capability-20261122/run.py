#!/usr/bin/env python3
"""Prepare, build and run CB-01 masse/jump capability research.

The research consumer is an isolated XCTest snapshot. Production sources and the
formal training bank remain read-only. E0 is pure geometry validation. E1 is
executed by Research.swift through the production spatial ShotPredictor.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BANK = ROOT / "QiuJi/Resources/training-grid-bank.json"
WORK = ROOT / "build/cb01-masse-jump-20261122"
EVIDENCE = HERE / "evidence"
SOURCE_TEST = ROOT / "QiuJiTests/PhysicsEngineTests.swift"

RADIUS = 0.028575
SURFACE_Y = 0.80
LENGTH = 2.540
WIDTH = 1.270
HALF_LENGTH = LENGTH / 2
HALF_WIDTH = WIDTH / 2

FAMILIES = [
    {"id": "C0-L", "target": 59, "mask": 85, "pocket": 0, "angles": 0, "bits": [3, 5, 7, 9]},
    {"id": "C20-L", "target": 59, "mask": 65, "pocket": 0, "angles": 20, "bits": [3, 5, 7, 9]},
    {"id": "C40-L", "target": 63, "mask": 45, "pocket": 0, "angles": 40, "bits": [3, 5, 7, 9]},
    {"id": "C60-L", "target": 71, "mask": 25, "pocket": 0, "angles": 60, "bits": [3, 5, 7, 9]},
    {"id": "C0-R", "target": 1436, "mask": 85, "pocket": 3, "angles": 0, "bits": [3, 5, 7, 9]},
    {"id": "C40-R", "target": 1440, "mask": 45, "pocket": 3, "angles": 40, "bits": [3, 5, 7, 9]},
    {"id": "M0-D", "target": 1934, "mask": 85, "pocket": 4, "angles": 0, "bits": [3, 5]},
    {"id": "M40-U", "target": 2665, "mask": 45, "pocket": 5, "angles": 40, "bits": [3, 5, 7]},
]

TECHNIQUE_PARAMETERS = {
    "jump": {
        "elevationDegrees": [20, 30, 40, 50, 60],
        "boundaryElevationDegrees": [70, 75],
        "speedMPS": [1.5, 2.5, 3.5, 4.5, 5.5],
        "spinX": [0.0],
        "spinY": [0.10, 0.25, 0.40, 0.55],
        "contactHemisphere": "upper",
    },
    "masse": {
        "elevationDegrees": [15, 25, 35, 45, 55, 60],
        "boundaryElevationDegrees": [],
        "speedMPS": [1.0, 1.5, 2.0, 2.5, 3.5, 4.5],
        "spinX": [-0.30, 0.0, 0.30],
        "spinY": [-0.10, -0.25, -0.40, -0.55],
        "contactHemisphere": "lower",
    },
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def point(value: dict[str, float]) -> tuple[float, float]:
    return float(value["x"]), float(value["z"])


def distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def cross(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[1] - a[1] * b[0]


def dot(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1]


def unit(v: tuple[float, float]) -> tuple[float, float]:
    length = math.hypot(*v)
    if length <= 1e-12:
        raise ValueError("zero direction")
    return v[0] / length, v[1] / length


def segment_distance(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    ab = (b[0] - a[0], b[1] - a[1])
    length2 = dot(ab, ab)
    t = max(0.0, min(1.0, dot((p[0] - a[0], p[1] - a[1]), ab) / length2)) if length2 else 0.0
    q = (a[0] + t * ab[0], a[1] + t * ab[1])
    return distance(p, q)


def cue_position(target: dict, distance_bit: int, distances: list[float], mask_index: int) -> tuple[float, float]:
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


def axis_rail_clearance(cue: tuple[float, float], aim: tuple[float, float]) -> float:
    """Distance from cue centre backwards along the cue axis to a legal rail."""
    backwards = (-aim[0], -aim[1])
    candidates = []
    if backwards[0] < -1e-9:
        candidates.append((-HALF_LENGTH - cue[0]) / backwards[0])
    if backwards[0] > 1e-9:
        candidates.append((HALF_LENGTH - cue[0]) / backwards[0])
    if backwards[1] < -1e-9:
        candidates.append((-HALF_WIDTH - cue[1]) / backwards[1])
    if backwards[1] > 1e-9:
        candidates.append((HALF_WIDTH - cue[1]) / backwards[1])
    positive = [value for value in candidates if value >= 0 and math.isfinite(value)]
    return min(positive) - RADIUS if positive else float("inf")


def legal_center(p: tuple[float, float]) -> bool:
    return abs(p[0]) <= HALF_LENGTH - RADIUS and abs(p[1]) <= HALF_WIDTH - RADIUS


def pocket_clearance(p: tuple[float, float], bank_geometry: dict, pocket_index: int) -> float:
    pocket = bank_geometry["pockets"][pocket_index]
    centre = point(pocket["center"])
    return distance(p, centre) - float(pocket["radius"]) - RADIUS


def actual_contact_up(spin_x: float, spin_y: float, elevation_degrees: float) -> float:
    theta = math.radians(elevation_degrees)
    c = math.sqrt(max(0.0, 1.0 - spin_x * spin_x - spin_y * spin_y))
    return math.sin(theta) * c + math.cos(theta) * spin_y


def load_bank() -> dict:
    bank = json.loads(BANK.read_text())
    if bank.get("schema") != "layout-bank-grid-v2-combination-ids":
        raise ValueError("unexpected training bank schema")
    geometry = bank.get("geometry", {})
    if abs(float(geometry.get("radius", 0)) - RADIUS) > 1e-8:
        raise ValueError("bank radius does not match table contract")
    return bank


def build_e0() -> tuple[dict, dict, dict]:
    bank = load_bank()
    targets = {int(item["inventoryTargetIndex"]): item for item in bank["targets"]}
    distances = [float(value) for value in bank["distanceSamples"]]
    source_hash = sha256(BANK)
    issues: list[dict] = []
    formations: list[dict] = []
    layouts: list[dict] = []
    for family in FAMILIES:
        target = targets.get(family["target"])
        if target is None:
            issues.append({"family": family["id"], "reason": "missingTarget"})
            continue
        if int(target["pocket"]) != family["pocket"]:
            issues.append({"family": family["id"], "reason": "pocketMismatch"})
            continue
        if not bool(target.get("clean")):
            issues.append({"family": family["id"], "reason": "sourceNotClean"})
            continue
        if not (0 <= family["mask"] < len(target["masks"])):
            issues.append({"family": family["id"], "reason": "maskOutOfRange"})
            continue
        bit_values = [bit for bit in family["bits"] if target["masks"][family["mask"]] & (1 << bit)]
        if len(bit_values) != len(family["bits"]):
            issues.append({"family": family["id"], "reason": "distanceBitMissing"})
            continue
        formations.append({
            "familyID": family["id"],
            "sourceGrid": f"grid-v3:{family['target']}:{family['mask']}",
            "targetIndex": family["target"],
            "maskIndex": family["mask"],
            "pocket": family["pocket"],
            "cutAngleDegrees": family["angles"],
            "sourceTarget": target["object"],
            "sourceGhost": target["ghost"],
            "sourceAim": target["aim"],
        })
        obj = point(target["object"])
        for bit in bit_values:
            cue = cue_position(target, bit, distances, family["mask"])
            target_point = obj
            co_distance = distance(cue, target_point)
            aim = unit((point(target["ghost"])[0] - cue[0], point(target["ghost"])[1] - cue[1]))
            rail_clearance = axis_rail_clearance(cue, aim)
            for obstacle_ratio in (0.30, 0.50, 0.70):
                obstacle = (
                    cue[0] + obstacle_ratio * (target_point[0] - cue[0]),
                    cue[1] + obstacle_ratio * (target_point[1] - cue[1]),
                )
                failures: list[str] = []
                if not legal_center(cue):
                    failures.append("cueOutsidePlayfield")
                if not legal_center(target_point):
                    failures.append("targetOutsidePlayfield")
                if not legal_center(obstacle):
                    failures.append("obstacleOutsidePlayfield")
                if distance(cue, target_point) < 2 * RADIUS + 1e-6:
                    failures.append("cueTargetOverlap")
                if distance(cue, obstacle) < 2 * RADIUS + 0.001:
                    failures.append("cueObstacleTooClose")
                if distance(obstacle, target_point) < 2 * RADIUS + 0.001:
                    failures.append("obstacleTargetTooClose")
                if pocket_clearance(target_point, bank["geometry"], family["pocket"]) < 0:
                    failures.append("targetPocketZone")
                if pocket_clearance(obstacle, bank["geometry"], family["pocket"]) < 0:
                    failures.append("obstaclePocketZone")
                if rail_clearance < 0:
                    failures.append("cueAxisRailOverlap")
                record = {
                    "layoutID": f"{family['id']}-b{bit}-s{int(obstacle_ratio * 100):02d}",
                    "familyID": family["id"],
                    "sourceGridID": f"grid-v3:{family['target']}:{family['mask']}:{bit}",
                    "targetIndex": family["target"],
                    "maskIndex": family["mask"],
                    "distanceBit": bit,
                    "sourceDistanceMetres": distances[bit],
                    "cueObjectDistanceMetres": co_distance,
                    "obstacleRatio": obstacle_ratio,
                    "cue": {"x": cue[0], "z": cue[1]},
                    "target": {"x": target_point[0], "z": target_point[1]},
                    "ghost": {"x": point(target["ghost"])[0], "z": point(target["ghost"])[1]},
                    "obstacle": {"x": obstacle[0], "z": obstacle[1]},
                    "pocket": family["pocket"],
                    "cutAngleDegrees": family["angles"],
                    "cueAxisRailClearanceMetres": rail_clearance,
                    "geometryStatus": "pass" if not failures else "reject",
                    "geometryFailures": failures,
                }
                if not failures:
                    for technique in ("jump", "masse"):
                        layouts.append({**record, "technique": technique})
    first_batch = {
        "schema": "cb01-first-batch-v1",
        "status": "research-only",
        "sourceBank": str(BANK.relative_to(ROOT)),
        "sourceBankSHA256": source_hash,
        "table": {"lengthMetres": LENGTH, "widthMetres": WIDTH, "ballRadiusMetres": RADIUS, "surfaceYMetres": SURFACE_Y},
        "families": formations,
        "layouts": layouts,
        "rejectedLayouts": [
            item for item in [
                {"familyID": family["id"], "reason": "sourceValidation"}
                for family in FAMILIES
                if family["id"] not in {row["familyID"] for row in formations}
            ]
        ],
        "parameterMatrix": TECHNIQUE_PARAMETERS,
    }
    e0 = {
        "schema": "cb01-e0-summary-v1",
        "sourceBankSHA256": source_hash,
        "familyCount": len(formations),
        "layoutCount": len(layouts),
        "acceptedGeometryLayouts": len(layouts) // 2,
        "rejectedSourceIssues": issues,
        "status": "pass" if not issues and layouts else "fail",
        "note": "E0 validates research layouts only. It does not claim physical shot feasibility.",
    }
    request = {
        "schema": "cb01-e1-request-v1",
        "status": "research-only",
        "sourceBankSHA256": source_hash,
        "layouts": layouts,
        "techniqueParameters": TECHNIQUE_PARAMETERS,
        "robustnessPerturbations": {
            "speedFactors": [0.95, 1.0, 1.05],
            "aimDeltaDegrees": [-0.5, 0.0, 0.5],
            "spinDelta": [-0.05, 0.0, 0.05],
        },
        "limits": {"maxEvents": 3000, "maxTimeSeconds": 40.0},
    }
    return first_batch, e0, request


def prepare() -> None:
    first_batch, e0, request = build_e0()
    write_json(HERE / "first-batch.json", first_batch)
    write_json(HERE / "e0-summary.json", e0)
    write_json(HERE / "request.json", request)
    write_json(HERE / "source-hashes.json", {
        "bank": sha256(BANK),
        "entry": sha256(Path(__file__)),
        "researchSwift": sha256(HERE / "Research.swift"),
    })
    print(json.dumps({"E0": e0, "jobs": sum(1 for _ in jobs_from_request(request))}, ensure_ascii=False))


def jobs_from_request(request: dict):
    for layout in request["layouts"]:
        params = request["techniqueParameters"][layout["technique"]]
        elevations = params["elevationDegrees"] + params.get("boundaryElevationDegrees", [])
        for elevation, speed, sx, sy in itertools.product(
            elevations, params["speedMPS"], params["spinX"], params["spinY"]
        ):
            actual_up = actual_contact_up(float(sx), float(sy), float(elevation))
            if layout["technique"] == "jump" and actual_up <= 0:
                continue
            if layout["technique"] == "masse" and actual_up >= 0:
                continue
            yield {
                "id": f"{layout['layoutID']}-{layout['technique']}-e{elevation}-v{speed}-x{sx}-y{sy}",
                "technique": layout["technique"],
                "layoutID": layout["layoutID"],
                "sourceGridID": layout["sourceGridID"],
                "pocket": layout["pocket"],
                "cue": layout["cue"],
                "target": layout["target"],
                "ghost": layout["ghost"],
                "obstacle": layout["obstacle"],
                "obstacleRatio": layout["obstacleRatio"],
                "cueObjectDistanceMetres": layout["cueObjectDistanceMetres"],
                "cueAxisRailClearanceMetres": layout["cueAxisRailClearanceMetres"],
                "cutAngleDegrees": layout["cutAngleDegrees"],
                "elevationDegrees": elevation,
                "speedMPS": speed,
                "spinX": sx,
                "spinY": sy,
                "actualContactUpOverR": actual_up,
            }


def write_job_file() -> Path:
    request = json.loads((HERE / "request.json").read_text())
    jobs = list(jobs_from_request(request))
    request["jobs"] = jobs
    write_json(HERE / "request.json", request)
    write_json(HERE / "jobs.json", {"schema": "cb01-e1-jobs-v1", "jobs": jobs, "count": len(jobs)})
    return HERE / "jobs.json"


def run_command(command: list[str], log: Path, cwd: Path | None = None) -> None:
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as handle:
        result = subprocess.run(command, cwd=cwd, stdout=handle, stderr=subprocess.STDOUT)
    if result.returncode:
        tail = log.read_text(errors="replace")[-12000:]
        raise RuntimeError(f"command failed with exit {result.returncode}\n{tail}")


def write_research_scheme(snapshot: Path) -> None:
    schemes = snapshot / "QiuJi.xcodeproj/xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    schemes.joinpath("CB01Research.xcscheme").write_text("""<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Scheme LastUpgradeVersion=\"1600\" version=\"1.3\">
  <BuildAction parallelizeBuildables=\"YES\" buildImplicitDependencies=\"YES\"><BuildActionEntries>
    <BuildActionEntry buildForTesting=\"YES\" buildForRunning=\"YES\" buildForProfiling=\"NO\" buildForArchiving=\"NO\" buildForAnalyzing=\"NO\"><BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"ED115D93DFF073BDF0B40893\" BuildableName=\"&#x7403;&#x8ff9;.app\" BlueprintName=\"QiuJi\" ReferencedContainer=\"container:QiuJi.xcodeproj\"/></BuildActionEntry>
    <BuildActionEntry buildForTesting=\"YES\" buildForRunning=\"NO\" buildForProfiling=\"NO\" buildForArchiving=\"NO\" buildForAnalyzing=\"NO\"><BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"FB4F19630C62446AC534A858\" BuildableName=\"QiuJiTests.xctest\" BlueprintName=\"QiuJiTests\" ReferencedContainer=\"container:QiuJi.xcodeproj\"/></BuildActionEntry>
  </BuildActionEntries></BuildAction>
  <TestAction buildConfiguration=\"Debug\" selectedDebuggerIdentifier=\"Xcode.DebuggerFoundation.Debugger.LLDB\" selectedLauncherIdentifier=\"Xcode.DebuggerFoundation.Launcher.LLDB\" shouldUseLaunchSchemeArgsEnv=\"YES\"><MacroExpansion><BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"ED115D93DFF073BDF0B40893\" BuildableName=\"&#x7403;&#x8ff9;.app\" BlueprintName=\"QiuJi\" ReferencedContainer=\"container:QiuJi.xcodeproj\"/></MacroExpansion><Testables><TestableReference skipped=\"NO\" parallelizable=\"NO\"><BuildableReference BuildableIdentifier=\"primary\" BlueprintIdentifier=\"FB4F19630C62446AC534A858\" BuildableName=\"QiuJiTests.xctest\" BlueprintName=\"QiuJiTests\" ReferencedContainer=\"container:QiuJi.xcodeproj\"/></TestableReference></Testables></TestAction>
</Scheme>
""")


def build() -> None:
    if not (HERE / "request.json").exists():
        prepare()
    write_job_file()
    if WORK.exists():
        shutil.rmtree(WORK)
    snapshot = WORK / "snapshot"
    snapshot.mkdir(parents=True)
    for name in ("QiuJi", "QiuJiTests", "QiuJiLiveActivity", "QiuJi.xcodeproj", "Config", "scripts", "Packages", "project.yml"):
        source = ROOT / name
        destination = snapshot / name
        subprocess.run(["/bin/cp", "-cR", str(source), str(destination)], check=True)
    write_research_scheme(snapshot)
    target = snapshot / "QiuJiTests/PhysicsEngineTests.swift"
    target.write_text(target.read_text() + "\n\n" + (HERE / "Research.swift").read_text())
    write_json(WORK / "snapshot-hashes.json", {
        "bank": sha256(BANK),
        "sourceTestBefore": sha256(SOURCE_TEST),
        "researchSwift": sha256(HERE / "Research.swift"),
    })
    derived = WORK / "DerivedData"
    command = [
        "xcodebuild", "-project", str(snapshot / "QiuJi.xcodeproj"), "-scheme", "CB01Research",
        "-configuration", "Debug", "-derivedDataPath", str(derived),
        "-enableCodeCoverage", "NO", "-parallel-testing-enabled", "NO", "-jobs", "2",
        "ARCHS=arm64",
        "-destination", "generic/platform=iOS Simulator", "build-for-testing",
    ]
    write_json(EVIDENCE / "build-command.json", command)
    run_command(command, EVIDENCE / "build.log", snapshot)
    write_json(WORK / "compiled.json", {"snapshot": str(snapshot), "derived": str(derived), "command": command})
    print("E1 build-for-testing passed")


def run_tests() -> None:
    compiled = json.loads((WORK / "compiled.json").read_text())
    snapshot = Path(compiled["snapshot"])
    derived = Path(compiled["derived"])
    command = [
        "xcodebuild", "-project", str(snapshot / "QiuJi.xcodeproj"), "-scheme", "CB01Research",
        "-configuration", "Debug", "-derivedDataPath", str(derived),
        "-parallel-testing-enabled", "NO", "-only-testing:QiuJiTests/CB01CapabilityResearchTests/testCB01CapabilitySweep",
        "-destination", "platform=iOS Simulator,id={udid}",
        "-resultBundlePath", str(EVIDENCE / "e1.xcresult"), "test-without-building",
    ]
    script = [sys.executable, str(ROOT / "scripts/simulator_lifecycle.py"), "run",
              "--task", "cb01-masse-jump-e1", "--type", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
              "--runtime", "com.apple.CoreSimulator.SimRuntime.iOS-26-3", "--temporary",
              "--evidence", str(EVIDENCE / "e1-lifecycle.json"), "--"] + command
    run_command(script, EVIDENCE / "simulator.log", ROOT)
    print("E1 simulator run passed")


def report() -> None:
    result_path = HERE / "e1-results.json"
    if not result_path.exists():
        summary = {
            "schema": "cb01-e1-summary-v1",
            "status": "blocked",
            "groups": [],
            "note": "E1 solver scan has not produced rows. Check e1-execution-status.json before interpreting this report.",
        }
        write_json(HERE / "e1-summary.json", summary)
        print(json.dumps(summary, ensure_ascii=False))
        return
    rows = json.loads(result_path.read_text())["rows"]
    groups: dict[tuple[str, float, float], list[dict]] = {}
    for row in rows:
        key = (row["technique"], float(row["cueObjectDistanceMetres"]), float(row["obstacleRatio"]))
        groups.setdefault(key, []).append(row)
    summaries = []
    for (technique, co, ratio), values in sorted(groups.items()):
        summaries.append({
            "technique": technique,
            "cueObjectDistanceMetres": co,
            "obstacleRatio": ratio,
            "samples": len(values),
            "baseSafe": sum(bool(item.get("baseSafe")) for item in values),
            "basePotted": sum(bool(item.get("basePotted")) for item in values),
            "targetEscaped": sum(bool(item.get("targetEscaped")) for item in values),
            "cueEscaped": sum(bool(item.get("cueEscaped")) for item in values),
            "obstacleContacts": sum(bool(item.get("obstacleContact")) for item in values),
            "contactHemispherePass": sum(bool(item.get("contactHemispherePass")) for item in values),
            "maximumHeightMetres": max((float(item.get("cueMaximumHeightMetres", 0)) for item in values), default=0),
            "maximumLateralOffsetMetres": max((float(item.get("cueMaximumLateralOffsetMetres", 0)) for item in values), default=0),
        })
    write_json(HERE / "e1-summary.json", {
        "schema": "cb01-e1-summary-v1",
        "status": "pass",
        "rows": len(rows),
        "groups": summaries,
    })
    print(json.dumps({"rows": len(rows), "groups": len(summaries)}, ensure_ascii=False))


def ingest_remote_log(log_path: Path) -> None:
    rows = []
    for line in log_path.read_text(errors="replace").splitlines():
        if line.startswith("CB01_ROW\t"):
            rows.append(json.loads(line.split("\t", 1)[1]))
    if not rows:
        raise RuntimeError(f"no CB01_ROW records found in {log_path}")
    request = json.loads((HERE / "request.json").read_text())
    result = {
        "schema": "cb01-e1-results-v1",
        "rows": rows,
        "count": len(rows),
        "sourceBankSHA256": request["sourceBankSHA256"],
        "solver": "ShotPredictor.simulateFree:spatialPractice",
        "geometryVersion": "SpatialPracticeGeometry",
        "ingestSource": str(log_path),
    }
    write_json(HERE / "e1-results.json", result)
    print(json.dumps({"rows": len(rows), "source": str(log_path)}, ensure_ascii=False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["prepare", "build", "run", "ingest-remote-log", "report", "all"])
    parser.add_argument("--log", type=Path, help="Remote E1 test log containing CB01_ROW records")
    args = parser.parse_args()
    if args.command in ("prepare", "all"):
        prepare()
    if args.command in ("build", "all"):
        build()
    if args.command in ("run", "all"):
        run_tests()
    if args.command == "ingest-remote-log":
        if args.log is None:
            parser.error("ingest-remote-log requires --log")
        ingest_remote_log(args.log)
    if args.command in ("report", "all"):
        report()


if __name__ == "__main__":
    main()
