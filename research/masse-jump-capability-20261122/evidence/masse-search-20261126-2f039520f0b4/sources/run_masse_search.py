#!/usr/bin/env python3
"""CB-01 dedicated masse search: prepare -> build -> leased simulator run."""
import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import random
import shutil
import subprocess
import time

import one_solution_plan as source

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BUILD = ROOT / "build/cb01-masse-jump-20261122"
PRODUCTS = BUILD / "DerivedData/Build/Products"
APP = PRODUCTS / "Debug-iphonesimulator/球迹.app"
BUNDLE = APP / "PlugIns/QiuJiTests.xctest"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic(path, data):
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    temp.replace(path)


def shutdown_device(udid, receipt):
    result = subprocess.run(["xcrun", "simctl", "shutdown", udid], capture_output=True, text=True)
    inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"], text=True))
    device = next(d for group in inventory["devices"].values() for d in group if d["udid"] == udid)
    atomic(receipt, {"exitCode": result.returncode, "stderr": result.stderr, "verifiedState": device["state"]})
    # Xcode may already shut down a device that it booted for a test.
    assert device["state"] == "Shutdown", "leased simulator did not reach Shutdown"


def resolve_testroot(value):
    if isinstance(value, str):
        return value.replace("__TESTROOT__", str(PRODUCTS))
    if isinstance(value, list):
        return [resolve_testroot(v) for v in value]
    if isinstance(value, dict):
        return {k: resolve_testroot(v) for k, v in value.items()}
    return value


def prepare():
    pool = source.read_plans()
    rng = random.Random(20261126)
    rng.shuffle(pool)
    groups = defaultdict(list)
    for item in pool:
        groups[item["pocket"], item["distanceBit"]].append(item)
    chosen = []
    # At least one from each pocket/distance cell, then cover angle/rail marginals.
    for key in sorted(groups):
        chosen.append(groups[key][0])
    ids = {x["sampleIndex"] for x in chosen}
    covered = Counter((k, str(x[k])) for x in chosen for k in ("angleIndex", "railIndex", "distanceBit", "pocket"))
    while len(chosen) < 60:
        candidate = max((x for x in pool if x["sampleIndex"] not in ids),
                        key=lambda x: sum(1 / (1 + covered[k, str(x[k])]) for k in ("angleIndex", "railIndex", "distanceBit", "pocket")))
        chosen.append(candidate)
        ids.add(candidate["sampleIndex"])
        covered.update((k, str(candidate[k])) for k in ("angleIndex", "railIndex", "distanceBit", "pocket"))
    rng.shuffle(chosen)
    bank = json.loads(source.BANK.read_text())
    for shape in chosen:
        # Use the same source pocket aiming centre that produced the original ghost.
        shape["pocketCenter"] = bank["geometry"]["pockets"][shape["pocket"]]["center"]
        candidates = [x for x in source.obstacle_candidates(shape) if not x["failures"]]
        candidates.sort(key=lambda x: x != shape["obstacle"])
        shape["obstacleCandidates"] = candidates
    params = []
    for elevation in (5, 10, 15, 20, 25, 30, 35, 40, 45):
        for sx, sy in ((.3, -.4), (.3, -.55), (.5, -.55), (.6, -.4), (.3, -.65)):
            for speed in (1.5, 1., 2., 2.5):
                for sign in (1, -1):
                    if sx*sx+sy*sy <= .64 and source.actual_contact_up(sign*sx, sy, elevation) < 0:
                        params.append([float(elevation), speed, sign*sx, sy])
    payload = {"schema": "cb01-masse-search-input-v1", "sourceSampleSHA256": sha(source.INPUT),
               "sourceBankSHA256": sha(source.BANK), "parameters": params, "shapes": chosen,
               "sampling": "60 coverage samples, seed 20261126; pocket/distance cells followed by angle/rail coverage; not prevalence estimation",
               "policy": "first valid masse only; obstacle positions may be searched; no perturbation robustness tests",
               "researchSwiftSHA256": sha(HERE / "MasseSearch.swift")}
    payload["runIdentity"] = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    atomic(HERE / "masse-search-request-20261126.json", payload)
    print(json.dumps({"shapes": len(chosen), "parameters": len(params), "runIdentity": payload["runIdentity"]}))


def validate(record, expected, identity):
    assert record["runIdentity"] == identity
    assert record["source"] == expected
    assert record["sampleIndex"] == expected["sampleIndex"]
    assert record["simulations"] > 0
    if record["status"] == "solved":
        solution = record["solution"]
        assert solution["technique"] == "masse"
        assert solution["obstacle"] in expected["obstacleCandidates"]
        assert solution["actualContactUpOverR"] < 0 and solution["cueAccessible"] is True
        metrics = solution["metrics"]
        assert all(metrics[k] is True for k in ("settled", "objectPotted", "cueOnTable", "cueStayedOnCloth", "firstContactIsTarget"))
        assert metrics["obstacleContact"] is False and metrics["cueRailBeforeTarget"] is False
        assert metrics["precontactChordDeviationMetres"] > .001
        assert metrics["minimumPrecontactObstacleGapMetres"] > 0
        assert all(math.isfinite(float(v)) for name, frames in solution["trajectory"].items() for frame in frames for v in frame)
    else:
        assert record["status"] == "searchExhausted" and record["solution"] is None


def summarize(out, request):
    lookup = {x["sampleIndex"]: x for x in request["shapes"]}
    records = []
    for f in sorted((out / "shapes").glob("*.json.gz")):
        with gzip.open(f, "rt") as stream:
            row = json.load(stream)
        validate(row, lookup[row["sampleIndex"]], request["runIdentity"])
        records.append(row)
    solved = [r for r in records if r["status"] == "solved"]
    with gzip.open(out / "solutions.jsonl.gz", "wt") as stream:
        for r in solved:
            stream.write(json.dumps(r, ensure_ascii=False, separators=(",", ":")) + "\n")
    summary = {"requested": len(lookup), "completed": len(records), "solved": len(solved),
               "unresolved": len(records)-len(solved), "pending": len(lookup)-len(records),
               "unresolvedCompleteSearch": sum(r["status"] != "solved" and r["incompleteFinalSimulations"] == 0 for r in records),
               "unresolvedWithIncompleteSimulation": sum(r["status"] != "solved" and r["incompleteFinalSimulations"] > 0 for r in records),
               "simulations": sum(r["simulations"] for r in records),
               "incompleteFinalSimulations": sum(r["incompleteFinalSimulations"] for r in records),
               "solvedIndexes": [r["sampleIndex"] for r in solved],
               "angles": dict(Counter(str(r["solution"]["parameter"][0]) for r in solved)),
               "runIdentity": request["runIdentity"]}
    atomic(out / "summary.json", summary)
    return summary


def run(args):
    assert os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN") and os.environ.get("QIUJI_SIMULATOR_UDID") == args.udid
    request = json.loads((HERE / "masse-search-request-20261126.json").read_text())
    assert request["researchSwiftSHA256"] == sha(HERE / "MasseSearch.swift"), "source changed; rebuild and prepare"
    build = json.loads((HERE / "masse-build-20261126.json").read_text())
    assert build["researchSwiftSHA256"] == request["researchSwiftSHA256"], "binary source identity mismatch"
    actual_uuid = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(BUNDLE / "QiuJiTests")], text=True).split()[1]
    assert build["testBinaryUUID"] == actual_uuid, "test executable changed; rebuild"
    out = HERE / "evidence" / ("masse-search-20261126-" + request["runIdentity"][:12])
    (out / "shapes").mkdir(parents=True, exist_ok=True)
    atomic(out / "manifest.json", request)
    atomic(HERE / "masse-search-current.json", {"evidence": str(out), "runIdentity": request["runIdentity"]})
    pending = []
    for shape in request["shapes"][:args.count]:
        existing = out / "shapes" / f"{shape['sampleIndex']:05d}.json.gz"
        if existing.exists():
            with gzip.open(existing, "rt") as stream:
                validate(json.load(stream), shape, request["runIdentity"])
        else:
            pending.append(shape)
    print(json.dumps({"evidence": str(out), "pending": len(pending)}), flush=True)
    stamp = str(time.time_ns())
    try:
        for start in range(0, len(pending), args.batch_size):
            shapes = pending[start:start+args.batch_size]
            subrequest = dict(request, shapes=shapes)
            tag = f"batch-{stamp}-{start:04d}"
            atomic(out / (tag + "-input.json"), subrequest)
            shutil.copyfile(out / (tag + "-input.json"), BUNDLE / "masse-request.json")
            for bundle in (BUNDLE, APP):
                subprocess.run(["codesign", "--force", "--sign", "-", "--preserve-metadata=entitlements,requirements,flags", str(bundle)], check=True, capture_output=True)
            config = resolve_testroot(plistlib.loads(next(PRODUCTS.glob("CB01Research_*.xctestrun")).read_bytes()))
            test = config["QiuJiTests"]
            test.setdefault("EnvironmentVariables", {})["CB01_MASSE_REQUEST"] = "masse-request.json"
            test["OnlyTestIdentifiers"] = ["CB01MasseSearchTests"]
            cfg = out / (tag + ".xctestrun")
            cfg.write_bytes(plistlib.dumps(config))
            command = ["xcodebuild", "test-without-building", "-xctestrun", str(cfg), "-destination", f"platform=iOS Simulator,id={args.udid}",
                       "-parallel-testing-enabled", "NO", "-only-testing:QiuJiTests/CB01MasseSearchTests", "-resultBundlePath", str(out / (tag + ".xcresult"))]
            lookup = {x["sampleIndex"]: x for x in shapes}
            received = set()
            # Wait for SpringBoard readiness instead of racing Xcode's implicit boot.
            with (out / (tag + "-boot.log")).open("w") as boot_log:
                boot = subprocess.run(["xcrun", "simctl", "boot", args.udid], stdout=boot_log, stderr=subprocess.STDOUT)
                if boot.returncode != 0:
                    inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "--json"], text=True))
                    assert any(d["udid"] == args.udid and d["state"] == "Booted" for group in inventory["devices"].values() for d in group), "boot failed"
                subprocess.run(["xcrun", "simctl", "bootstatus", args.udid, "-b"], stdout=boot_log, stderr=subprocess.STDOUT, check=True)
            with (out / (tag + ".log")).open("w") as log:
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                try:
                    for line in process.stdout:
                        log.write(line);log.flush()
                        if "CB01_MASSE " not in line:
                            continue
                        result = json.loads(line.split("CB01_MASSE ", 1)[1])
                        index = result["sampleIndex"]
                        assert index not in received
                        validate(result, lookup[index], request["runIdentity"])
                        received.add(index)
                        path = out / "shapes" / f"{index:05d}.json.gz"
                        tmp = path.with_suffix(".tmp")
                        with gzip.open(tmp, "wt") as stream:
                            json.dump(result, stream, ensure_ascii=False, separators=(",", ":"))
                        tmp.replace(path)
                        print(json.dumps({"index": index, "status": result["status"], "simulations": result["simulations"], "diagnostics": result["diagnostics"]}), flush=True)
                    code = process.wait()
                finally:
                    if process.poll() is None:
                        process.terminate();process.wait(timeout=30)
            assert code == 0 and received == set(lookup), f"batch failed: {code}, {len(received)}/{len(lookup)}"
            print(json.dumps(summarize(out, request)), flush=True)
            # Reusing the signed host immediately can fail SpringBoard preflight
            # with Busy after XCTest exits. Reset only this leased device between batches.
            if start + args.batch_size < len(pending):
                shutdown_device(args.udid, out / (tag + "-shutdown.json"))
    finally:
        summarize(out, request)
        shutdown_device(args.udid, out / ("shutdown-" + stamp + ".json"))


def build():
    snapshot_test = BUILD / "snapshot/QiuJiTests/PhysicsEngineTests.swift"
    baseline = HERE / "masse-base-test-20261126.swift"
    assert baseline.exists(), "preserve the frozen baseline before first append"
    snapshot_test.write_bytes(baseline.read_bytes() + b"\n" + (HERE / "MasseSearch.swift").read_bytes())
    command = ["make", "-f", "scripts/Makefile", "test", "TEST_ACTION=build-for-testing", "SCHEME=CB01Research",
               f"PROJECT_FLAG=-project {BUILD / 'snapshot/QiuJi.xcodeproj'}", f"DERIVED_DATA={BUILD / 'DerivedData'}",
               "TEST_DESTINATION=generic/platform=iOS Simulator", "TEST_CODE_COVERAGE=NO",
               "TEST_BUILD_SETTINGS=-jobs 2 ARCHS=arm64", f"TEST_LOG={HERE / 'masse-build-20261126.log'}",
               f"TEST_JUNIT={HERE / 'masse-build-20261126.xml'}"]
    with (HERE / "masse-build-driver-20261126.log").open("w") as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    uuid = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(BUNDLE / "QiuJiTests")], text=True).split()[1]
    atomic(HERE / "masse-build-20261126.json", {"researchSwiftSHA256": sha(HERE / "MasseSearch.swift"),
           "testBinaryUUID": uuid, "snapshotTestSHA256": sha(snapshot_test)})
    print("Masse search build succeeded", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("prepare", "build", "run", "report"))
    parser.add_argument("--udid")
    parser.add_argument("--count", type=int, default=60)
    parser.add_argument("--batch-size", type=int, default=5)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare()
    elif args.command == "build":
        build()
    elif args.command == "run":
        run(args)
    else:
        current = json.loads((HERE / "masse-search-current.json").read_text())
        out = Path(current["evidence"])
        print(json.dumps(summarize(out, json.loads((out / "manifest.json").read_text()))))
