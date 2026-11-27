#!/usr/bin/env python3
"""Resumable research-only simulator search; run inside a simulator fleet lease."""
from __future__ import annotations

import argparse
from collections import Counter
import gzip
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

import one_solution_plan as plan

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BUILD = ROOT / "build/cb01-masse-jump-20261122"
PRODUCTS = BUILD / "DerivedData/Build/Products"
APP = PRODUCTS / "Debug-iphonesimulator/球迹.app"
BUNDLE = APP / "PlugIns/QiuJiTests.xctest"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def atomic_json(path, value):
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temp.replace(path)


def candidates(shape):
    jobs = [plan.request_job(shape, technique, params, i)
            for technique, parameters in (("jump", plan.JUMP_PARAMETERS), ("masse", plan.MASSE_PARAMETERS))
            for i, params in enumerate(parameters)]
    return sorted(jobs, key=lambda job: job["elevationDegrees"])


def validate(result, expected, run_id):
    assert result["requestSHA256"] == run_id, "wrong execution identity"
    assert result["candidateCount"] == len(expected)
    rows = result["rows"]
    assert 0 < len(rows) <= len(expected)
    for row, job in zip(rows, expected):
        assert all(row.get(k) == v for k, v in job.items()), "result/input mismatch"
    winners = [r for r in rows if r.get("basePotted")]
    if winners:
        assert len(winners) == 1 and winners[0] == rows[-1]
        winner = winners[0]
        for key in ("settled", "contactHemispherePass", "techniqueShapePass", "baseSafe",
                    "objectPotted", "firstContactIsTarget", "directPotLineBlocked", "cueFinalOnBed"):
            assert winner.get(key) is True, key
        for key in ("cueEscaped", "targetEscaped", "obstacleContact", "cueLeftTable"):
            assert winner.get(key) is False, key
        assert result["status"] == "solved"
    else:
        assert len(rows) == len(expected) and result["status"] == "exhausted"


def summarize(evidence, jobs_by_index, run_id):
    solved, exhausted, attempts, incomplete = [], [], 0, 0
    unresolved_incomplete, all_incomplete = [], []
    failures = Counter()
    for file in sorted((evidence / "shapes").glob("*.json.gz")):
        with gzip.open(file, "rt") as stream:
            result = json.load(stream)
        validate(result, jobs_by_index[result["sampleIndex"]], run_id)
        rows = result["rows"]
        attempts += len(rows)
        incomplete += sum(not row.get("settled", False) for row in rows)
        failures.update(str(row.get("failure")) for row in rows if not row.get("basePotted"))
        if result["status"] == "solved":
            solved.append(rows[-1])
        else:
            exhausted.append(result["sampleIndex"])
            if any(not row.get("settled", False) for row in rows):
                unresolved_incomplete.append(result["sampleIndex"])
            if all(not row.get("settled", False) for row in rows):
                all_incomplete.append(result["sampleIndex"])
    output = evidence / "solutions.jsonl.gz"
    with output.with_suffix(".tmp").open("wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as stream:
        for row in solved:
            stream.write((json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode())
    output.with_suffix(".tmp").replace(output)
    completed = {r["sampleIndex"] for r in solved} | set(exhausted)
    summary = {
        "schema": "cb01-one-solution-summary-v2", "runIdentity": run_id,
        "status": "complete" if len(completed) == len(jobs_by_index) else "partial",
        "totalBaseShapes": len(jobs_by_index), "completedBaseShapes": len(completed),
        "solvedBaseShapes": len(solved), "searchExhaustedBaseShapes": len(exhausted),
        "pendingBaseShapes": len(jobs_by_index) - len(completed),
        "actualSimulations": attempts, "incompleteSimulations": incomplete,
        "unresolvedWithIncompleteSimulations": len(unresolved_incomplete),
        "unresolvedAllSimulationsIncomplete": len(all_incomplete),
        "unresolvedIncompleteSampleIndexes": unresolved_incomplete,
        "techniques": dict(Counter(r["technique"] for r in solved)),
        "elevationDegrees": dict(Counter(str(r["elevationDegrees"]) for r in solved)),
        "failures": dict(failures), "exhaustedSampleIndexes": exhausted,
        "pendingSampleIndexes": sorted(set(jobs_by_index) - completed),
        "note": "Search exhaustion is not physical impossibility. Frozen 20261122 engine; no real-table calibration.",
        "solutions": str(output),
    }
    atomic_json(evidence / "summary.json", summary)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--mode", choices=("pilot", "all"), default="pilot")
    parser.add_argument("--batch-size", type=int, default=500)
    args = parser.parse_args()
    assert os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "use simulator_fleet.py run"
    assert os.environ.get("QIUJI_SIMULATOR_UDID") == args.udid
    build_record = json.loads((HERE / "one-solution-build-20261124.json").read_text())
    assert sha(HERE / "Research.swift") == build_record["researchSwiftSHA256"], "rebuild changed research code"
    binary_uuid = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(BUNDLE / "QiuJiTests")], text=True).split()[1]
    assert binary_uuid == build_record["testBinaryUUID"], "test binary differs from verified build"
    assert sha(BUILD / "snapshot/QiuJiTests/PhysicsEngineTests.swift") == build_record["snapshotTestSHA256"]
    shapes = plan.read_plans()
    jobs_by_index = {shape["sampleIndex"]: candidates(shape) for shape in shapes}
    snapshot = BUILD / "snapshot"
    physics_hashes = {str(p.relative_to(snapshot)): sha(p) for p in sorted((snapshot / "QiuJi").rglob("*.swift"))
                      if "/Physics/" in str(p) or "/SpatialPractice/" in str(p)}
    manifest = {
        "schema": "cb01-one-solution-run-v2", "researchSwiftSHA256": sha(HERE / "Research.swift"),
        "planSHA256": sha(plan.PLAN), "bankSHA256": sha(plan.BANK),
        "parameterCandidates": {"jump": plan.JUMP_PARAMETERS, "masse": plan.MASSE_PARAMETERS},
        "physicsSnapshot": str(snapshot), "physicsHashes": physics_hashes,
        "priority": "ascending elevation across techniques; first valid pot stops the shape",
        "obstacles": "one fixed blocked layout per base shape; no perturbations",
    }
    assert manifest["bankSHA256"] == sha(snapshot / "QiuJi/Resources/training-grid-bank.json")
    run_id = identity(manifest)
    evidence = HERE / "evidence" / ("one-solution-20261124-" + run_id[:12])
    (evidence / "shapes").mkdir(parents=True, exist_ok=True)
    atomic_json(evidence / "manifest.json", dict(manifest, runIdentity=run_id))
    atomic_json(HERE / "one-solution-current-run.json", {"evidence": str(evidence), "runIdentity": run_id})
    selected = shapes[::100] if args.mode == "pilot" else shapes
    pending = []
    for shape in selected:
        file = evidence / "shapes" / f"{shape['sampleIndex']:05d}.json.gz"
        if file.exists():
            with gzip.open(file, "rt") as stream:
                validate(json.load(stream), jobs_by_index[shape["sampleIndex"]], run_id)
        else:
            pending.append(shape)
    print(json.dumps({"evidence": str(evidence), "mode": args.mode, "remaining": len(pending)}), flush=True)
    template = next(PRODUCTS.glob("CB01Research_*.xctestrun"))
    stamp = str(time.time_ns())
    try:
        for offset in range(0, len(pending), args.batch_size):
            batch = pending[offset:offset + args.batch_size]
            batch_indexes = {shape["sampleIndex"] for shape in batch}
            tag = f"{args.mode}-{stamp}-{offset:05d}"
            request_name = "cb01-one-active-request.json"
            request = {
                "sourceBankSHA256": manifest["bankSHA256"], "requestIdentity": run_id,
                "jobs": [job for shape in batch for job in jobs_by_index[shape["sampleIndex"]]],
            }
            atomic_json(evidence / (tag + "-request.json"), request)
            shutil.copyfile(evidence / (tag + "-request.json"), BUNDLE / request_name)
            for path in (BUNDLE, APP):
                subprocess.run(["codesign", "--force", "--sign", "-", "--preserve-metadata=entitlements,requirements,flags", str(path)], check=True, capture_output=True)
            config = plistlib.loads(template.read_bytes())
            test = config["QiuJiTests"]
            # Resolve placeholders since this generated xctestrun is outside Products.
            for key, value in list(test.items()):
                if isinstance(value, str):
                    test[key] = value.replace("__TESTROOT__", str(PRODUCTS))
            test.setdefault("EnvironmentVariables", {})["CB01_REQUEST_FILE"] = request_name
            test["OnlyTestIdentifiers"] = ["CB01CapabilityResearchTests/testCB01OneSolutionSearch"]
            config_file = evidence / (tag + ".xctestrun")
            config_file.write_bytes(plistlib.dumps(config))
            command = ["xcodebuild", "test-without-building", "-xctestrun", str(config_file),
                       "-destination", f"platform=iOS Simulator,id={args.udid}",
                       "-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1",
                       "-only-testing:QiuJiTests/CB01CapabilityResearchTests/testCB01OneSolutionSearch",
                       "-resultBundlePath", str(evidence / (tag + ".xcresult"))]
            received = set()
            started = time.monotonic()
            with (evidence / (tag + ".log")).open("w") as log:
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
                try:
                    for line in process.stdout:
                        log.write(line)
                        log.flush()
                        if "CB01_ONE " not in line:
                            continue
                        result = json.loads(line.split("CB01_ONE ", 1)[1])
                        index = result["sampleIndex"]
                        assert index in batch_indexes and index not in received
                        validate(result, jobs_by_index[index], run_id)
                        received.add(index)
                        path = evidence / "shapes" / f"{index:05d}.json.gz"
                        temp = path.with_suffix(".tmp")
                        with gzip.open(temp, "wt") as stream:
                            json.dump(result, stream, ensure_ascii=False, separators=(",", ":"))
                        temp.replace(path)
                        if len(received) % 25 == 0:
                            print(f"{tag}: {len(received)}/{len(batch)} shapes, {time.monotonic()-started:.1f}s", flush=True)
                    code = process.wait()
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=30)
            summary = summarize(evidence, jobs_by_index, run_id)
            print(json.dumps({k: summary[k] for k in ("completedBaseShapes", "solvedBaseShapes", "actualSimulations", "techniques")}), flush=True)
            if code != 0 or received != batch_indexes:
                raise RuntimeError(f"batch failed exit={code}, received={len(received)}/{len(batch)}; checkpoints retained")
    finally:
        summary = summarize(evidence, jobs_by_index, run_id)
        # Fleet selected a shutdown device. Restore it before releasing the lease.
        subprocess.run(["xcrun", "simctl", "shutdown", args.udid], capture_output=True)
    print(json.dumps({"summary": str(evidence / "summary.json"), "completed": summary["completedBaseShapes"], "solved": summary["solvedBaseShapes"]}), flush=True)


if __name__ == "__main__":
    main()
