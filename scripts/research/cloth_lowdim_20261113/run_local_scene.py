#!/usr/bin/env python3
"""Run selected frozen XCTest entries through the local work/fleet owners.

Default is read-only preflight. --execute is the explicit start switch; it creates
one managed work directory, APFS-clones the sealed snapshot, builds without a
device, and then borrows only the configured Shutdown large-pad. No production
source or frozen snapshot is edited. The default remains the original four-case
SceneKit entry. Simulator timings are raw diagnostics, never GPU performance
rankings, presented-page FPS or physical-iPhone performance.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from mac_mini_queue import digest, test_summary, tree_files, verify
from simulator_fleet import select
from simulator_lifecycle import inventory, processes, STATE_ROOT

SELECTOR = "QiuJiTests/ClothSupportPerformanceResearchTests/testProductionSceneHeightSafeSupportGPUComparison"
DEFAULT_SNAPSHOT = ROOT / "output/render-lowdim-20261113/ios-snapshot-r4"
ROLE = "large-pad"
TASK = "cloth-support-scene-local-r4"
SCRIPT = Path(__file__).resolve()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def registry():
    path = STATE_ROOT / "registry.json"
    return json.loads(path.read_text()) if path.exists() else {"devices": {}}


def selection_arguments(selectors, expected_count, task):
    return [value for selector in selectors for value in ("--test", selector)] + [
        "--expected-count", str(expected_count), "--task", task]


def preflight(snapshot, selectors=(SELECTOR,), expected_count=1, task=TASK):
    manifest = verify(snapshot)
    host_source = (snapshot / "source/QiuJiTests/ClothSupportPerformanceResearchTests.swift").read_text()
    if '"harness": "sequential-command-buffer-r4"' not in host_source:
        raise ValueError("Requires the corrected sequential-command-buffer-r4 host; r3 deadlocks during warmup")
    config = json.loads((ROOT / "scripts/simulator-fleet.json").read_text())
    live = inventory()
    uid = select(config, live, role=ROLE)
    record = registry()["devices"].get(uid, {})
    busy = processes()
    blockers = []
    if live[uid]["state"] != "Shutdown":
        blockers.append("large-pad is not Shutdown; preserve the current session")
    if record.get("lease"):
        blockers.append("large-pad has an existing lease")
    if busy.get(uid) or busy.get("*"):
        blockers.append("target or unresolved external simulator command is active")
    runtimes = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "runtimes", "--json"]))["runtimes"]
    runtime = next(r for r in runtimes if r["identifier"] == live[uid]["runtime"])
    return {
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "snapshot": str(snapshot), "snapshotID": manifest["snapshot_id"],
        "snapshotFileCount": len(manifest["files"]),
        "selector": selectors[0] if len(selectors) == 1 else None,
        "selectors": list(selectors), "expectedTestCount": expected_count, "task": task,
        "role": ROLE, "device": live[uid], "leaseRecord": record,
        "runtime": {k: runtime[k] for k in ("identifier", "name", "version", "buildversion", "isAvailable")},
        "otherBootedDevicesPreserved": [dict(udid=k, name=v["name"])
            for k, v in live.items() if k != uid and v["state"] == "Booted"],
        "blockers": blockers,
        "matrix": ("Default smoke: 2-ball near / 16-ball scatter, each 700x400 and 1400x800, MSAA4"
            if list(selectors) == [SELECTOR] else "Explicit XCTest batch; each selected test retains its frozen fixture contract"),
        "warmups": ("Frozen test: prepare reference 8, repeat 1, red control 4, candidate 8, restore 4; each timed switch 2"
            if list(selectors) == [SELECTOR] else "Defined independently by the selected frozen tests"),
        "measurement": ("9 ABBA/BAAB groups; 6 independently committed render(atTime:1) commands per batch; raw Simulator timing only, not GPU performance ranking"
            if list(selectors) == [SELECTOR] else "Test result/selector/count and attachment evidence; any Simulator timing is raw diagnostics only, not GPU performance ranking"),
        "executionStarted": False,
    }, manifest


def logged(command, cwd, evidence, label, env=None):
    write_json(evidence / (label + "-command.json"), command)
    print(label + ": " + json.dumps(command), flush=True)
    with (evidence / (label + "-driver.log")).open("wb") as stream:
        subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                       stderr=subprocess.STDOUT, check=True)


def clean_environment():
    env = dict(os.environ)
    # Retain each frozen test's defaults, independent of unrelated exploratory
    # settings in the caller's shell. No test implementation changes.
    for key in list(env):
        if key.startswith(("CLOTH_RESEARCH_", "TEST_RUNNER_CLOTH_RESEARCH_")):
            del env[key]
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def make_command(source, work, evidence, action, destination, selectors=(SELECTOR,)):
    label = "build" if action == "build-for-testing" else "tests"
    return ["make", "-f", str(source / "scripts/Makefile"), "test",
        "TEST_ACTION=" + action, "TEST_CONFIGURATION=Debug",
        "BUILD_DIR=" + str(work / "build"),
        "DERIVED_DATA=" + str(work / "build/DerivedData"),
        "TEST_LOG=" + str(evidence / (label + ".log")),
        "TEST_JUNIT=" + str(evidence / (label + ".xml")),
        "TEST_RESULT_BUNDLE=" + str(evidence / (label + ".xcresult")),
        "TEST_DESTINATION=" + destination, "TEST_CODE_COVERAGE=NO",
        "TEST_SELECTOR=" + " ".join("-only-testing:" + selector for selector in selectors),
        "TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO ARCHS=arm64 -jobs 4",
        # Fleet already owns the lease. Both Makefile actions bypass its local
        # workspace wrapper, and this prevents a second simulator wrapper.
        "SIM_TEST_GUARD="]


def assert_managed_paths(work, evidence):
    if (str(work) != os.environ.get("QIUJI_TEST_WORK")
            or str(evidence) != os.environ.get("QIUJI_TEST_EVIDENCE")
            or not os.environ.get("QIUJI_TEST_RUN_ID")):
        raise ValueError("Internal phase requires the existing local-test lifecycle owner")
    if work.is_symlink() or evidence.is_symlink() or work.parent != evidence.parent:
        raise ValueError("Unexpected managed work/evidence boundary")


def leased_test(work, evidence, uid, selectors=(SELECTOR,), expected_count=1, task=TASK):
    assert_managed_paths(work, evidence)
    token = os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN")
    lease = registry()["devices"].get(uid, {}).get("lease", {})
    if (uid != os.environ.get("QIUJI_SIMULATOR_UDID") or not token
            or lease.get("token") != token):
        raise ValueError("Test phase requires the existing fleet lease")
    source = work / "source"
    write_json(evidence / "device-at-test.json", inventory()[uid])
    logged(make_command(source, work, evidence, "test-without-building",
        "platform=iOS Simulator,id=" + uid, selectors), source, evidence, "tests", clean_environment())
    write_json(evidence / "test-selection.json", {"selectors": list(selectors),
        "expectedTestCount": expected_count, "task": task})
    # Read/export while the lifecycle owner still holds the unsealed evidence;
    # its final receipt is created only after this child returns.
    summary = test_summary(evidence, list(selectors))
    if summary.get("totalTestCount") != expected_count:
        raise RuntimeError(f"Selected XCTest count mismatch: expected {expected_count}, got {summary.get('totalTestCount')}")
    logged(["xcrun", "xcresulttool", "export", "attachments", "--path",
        str(evidence / "tests.xcresult"), "--output-path", str(evidence / "attachments")],
        source, evidence, "attachments")
    write_json(evidence / "device-after-test.json", inventory()[uid])


def execute_work(snapshot, work, evidence, selectors=(SELECTOR,), expected_count=1, task=TASK):
    assert_managed_paths(work, evidence)
    plan, manifest = preflight(snapshot, selectors, expected_count, task)
    write_json(evidence / "preflight.json", plan)
    if plan["blockers"]:
        raise RuntimeError("; ".join(plan["blockers"]))
    write_json(evidence / "snapshot-manifest.json", manifest)
    write_json(evidence / "launcher.json", {"source": str(SCRIPT), "sha256": digest(SCRIPT),
        "host": platform.platform(), "machine": platform.machine(),
        "selector": selectors[0] if len(selectors) == 1 else None,
        "selectors": list(selectors), "expectedTestCount": expected_count, "task": task})
    source = work / "source"
    if source.exists():
        raise ValueError("Refusing to overwrite an existing work/source")
    result = {"status": "running", "snapshotID": manifest["snapshot_id"]}
    try:
        logged(["cp", "-cR", str(snapshot / "source"), str(source)], ROOT, evidence, "clone")
        if tree_files(source) != manifest["files"]:
            raise RuntimeError("APFS clone differs from the immutable snapshot")
        write_json(evidence / "hash-before.json", {"snapshotVerified": True, "cloneVerified": True,
            "fileCount": len(manifest["files"]), "snapshotID": manifest["snapshot_id"]})
        logged(["xcodebuild", "-version"], source, evidence, "xcode-environment")
        logged(make_command(source, work, evidence, "build-for-testing",
            "generic/platform=iOS Simulator", selectors), source, evidence, "build", clean_environment())
        # Recheck after a potentially long compile; fleet performs its own
        # final identity/Shutdown check and atomically acquires the lease.
        after_build, _ = preflight(snapshot, selectors, expected_count, task)
        write_json(evidence / "preflight-after-build.json", after_build)
        if after_build["blockers"]:
            raise RuntimeError("; ".join(after_build["blockers"]))
        logged([sys.executable, str(ROOT / "scripts/simulator_fleet.py"), "run",
            "--role", ROLE, "--task", task, "--", sys.executable, str(SCRIPT),
            "--phase", "leased", "--work", str(work), "--evidence", str(evidence),
            "--udid", "{udid}"] + selection_arguments(selectors, expected_count, task),
            ROOT, evidence, "fleet", clean_environment())
        uid = plan["device"]["udid"]
        record = registry()["devices"].get(uid, {})
        write_json(evidence / "lease-after.json", record)
        if record.get("lease"):
            raise RuntimeError("Fleet lease was not released")
        result["status"] = "succeeded"
    except BaseException as error:
        result.update(status="failed", error=repr(error))
        raise
    finally:
        # These checks also run after build/test failure, preserving the first
        # failure while recording all source changes for diagnosis.
        checks = {}
        try:
            verify(snapshot)
            checks["snapshotVerified"] = True
            actual = tree_files(source) if source.exists() else {}
            checks["cloneVerified"] = actual == manifest["files"]
            checks["changedOrMissing"] = [p for p, entry in manifest["files"].items() if actual.get(p) != entry]
            checks["added"] = sorted(actual.keys() - manifest["files"].keys())
        except BaseException as error:
            checks.update(snapshotVerified=False, error=repr(error))
        write_json(evidence / "hash-after.json", checks)
        write_json(evidence / "result.json", result)
        if result["status"] == "succeeded" and not (checks.get("snapshotVerified") and checks.get("cloneVerified")):
            result.update(status="failed", error="Post-run source integrity check failed")
            write_json(evidence / "result.json", result)
            raise RuntimeError(result["error"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--test", action="append", help="XCTest target/class/method selector; repeat for multiple entries")
    parser.add_argument("--expected-count", type=int, default=1, help="Required number of executed XCTest methods (default: 1)")
    parser.add_argument("--task", default=TASK, help="Task identity for both existing lifecycle owners")
    parser.add_argument("--execute", action="store_true", help="Start the prepared build/test workflow")
    parser.add_argument("--plan-out", type=Path, help="Optional read-only preflight JSON evidence path")
    parser.add_argument("--phase", choices=["work", "leased"], help=argparse.SUPPRESS)
    parser.add_argument("--work", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--evidence", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--udid", help=argparse.SUPPRESS)
    args = parser.parse_args()
    selectors = args.test if args.test is not None else [SELECTOR]
    if args.expected_count < 1:
        parser.error("--expected-count must be positive")
    if any(not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_./-]*", selector) for selector in selectors):
        parser.error("--test must be a plain XCTest target/class/method selector")
    if len(set(selectors)) != len(selectors):
        parser.error("Duplicate --test selectors are not allowed")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", args.task):
        parser.error("--task must contain only letters, digits, underscores, dots or hyphens")
    if args.phase:
        if not args.work or not args.evidence:
            parser.error("Internal phases require --work and --evidence")
        if args.phase == "work":
            execute_work(args.snapshot.resolve(), args.work.resolve(), args.evidence.resolve(),
                selectors, args.expected_count, args.task)
        elif args.udid:
            leased_test(args.work.resolve(), args.evidence.resolve(), args.udid,
                selectors, args.expected_count, args.task)
        else:
            parser.error("Leased phase requires --udid")
        return 0
    plan, _ = preflight(args.snapshot.resolve(), selectors, args.expected_count, args.task)
    if args.plan_out:
        args.plan_out.parent.mkdir(parents=True, exist_ok=True)
        write_json(args.plan_out, plan)
    print(json.dumps(plan, ensure_ascii=False, indent=2), flush=True)
    if plan["blockers"]:
        return 2
    if args.execute:
        if os.environ.get("QIUJI_TEST_WORK") or os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"):
            raise RuntimeError("Refusing nested workspace/lease execution")
        return subprocess.call([sys.executable, str(ROOT / "scripts/local_test_lifecycle.py"),
            "run", "--task", args.task, "--", sys.executable, str(SCRIPT),
            "--phase", "work", "--snapshot", str(args.snapshot.resolve()),
            "--work", "{work}", "--evidence", "{evidence}"]
            + selection_arguments(selectors, args.expected_count, args.task), env=clean_environment())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
