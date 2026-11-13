#!/usr/bin/env python3
"""Build and test the frozen iOS app natively on the explicitly authorized Mac.

No simulator or remote host is used. Must run inside local_test_lifecycle.py.
User authorized Xcode development-device registration on 2026-11-13.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from mac_mini_queue import digest, test_summary, tree_files, verify

DESTINATION = "platform=macOS,arch=arm64,variant=Designed for iPad,id=00006050-0015294102F9401C"
DEFAULT_SELECTOR = "QiuJiTests/ClothSupportPerformanceResearchTests/testNativeProductionGuardComboGPUComparison"


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def run(command, cwd, evidence, label):
    write(evidence / (label + "-command.json"), command)
    print(label + " started", flush=True)
    with (evidence / (label + "-driver.log")).open("wb") as stream:
        subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                       timeout=1800, check=True)
    print(label + " completed", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--test", action="append")
    parser.add_argument("--expected-count", type=int, default=1)
    parser.add_argument("--allow-provisioning-updates", action="store_true",
                        help="Explicitly allow Xcode to refresh/register development profiles; default uses installed profiles")
    args = parser.parse_args()
    work, evidence = args.work.resolve(), args.evidence.resolve()
    if (str(work) != os.environ.get("QIUJI_TEST_WORK") or
            str(evidence) != os.environ.get("QIUJI_TEST_EVIDENCE") or
            not os.environ.get("QIUJI_TEST_RUN_ID")):
        raise ValueError("Use the existing managed local-test lifecycle owner")
    selectors = args.test or [DEFAULT_SELECTOR]
    if any(any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/" for c in s) for s in selectors):
        raise ValueError("Invalid XCTest selector")
    manifest = verify(args.snapshot)
    source = work / "source"
    if source.exists():
        raise ValueError("Refusing to overwrite a work clone")
    write(evidence / "snapshot-manifest.json", manifest)
    shutil.copyfile(__file__, evidence / "run_native_app.py")
    write(evidence / "launcher.json", {"path": str(Path(__file__).resolve()),
        "sha256": digest(Path(__file__)), "destination": DESTINATION,
        "authorization": "User explicitly approved registering this Mac and updating development profiles for native testing on 2026-11-13",
        "selectors": selectors, "scope": "Native iOS-on-Mac; not iPhone or Simulator",
        "configuration": "Debug -O", "allowProvisioningUpdates": args.allow_provisioning_updates})
    result = {"status": "running", "snapshotID": manifest["snapshot_id"]}
    try:
        run(["cp", "-cR", str(args.snapshot / "source"), str(source)], ROOT, evidence, "clone")
        if tree_files(source) != manifest["files"]:
            raise ValueError("Cloned inputs differ from the sealed snapshot")
        for action, label in [("build-for-testing", "build"), ("test-without-building", "tests")]:
            command = ["make", "-f", str(source / "scripts/Makefile"), "test",
                "TEST_ACTION=" + action, "TEST_CONFIGURATION=Debug",
                "BUILD_DIR=" + str(work / "build"),
                "DERIVED_DATA=" + str(work / "build/DerivedData"),
                "TEST_LOG=" + str(evidence / (label + ".log")),
                "TEST_JUNIT=" + str(evidence / (label + ".xml")),
                "TEST_RESULT_BUNDLE=" + str(evidence / (label + ".xcresult")),
                "TEST_DESTINATION=" + DESTINATION, "TEST_CODE_COVERAGE=NO",
                "TEST_SELECTOR=" + " ".join("-only-testing:" + s for s in selectors),
                "TEST_BUILD_SETTINGS=ARCHS=arm64 SWIFT_OPTIMIZATION_LEVEL=-O -jobs 4" +
                    (" -allowProvisioningUpdates -allowProvisioningDeviceRegistration" if args.allow_provisioning_updates else ""),
                "SIM_TEST_GUARD="]
            run(command, source, evidence, label)
        summary = test_summary(evidence, selectors)
        if summary.get("totalTestCount") != args.expected_count:
            raise ValueError("Unexpected native test count")
        run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(evidence / "tests.xcresult"),
             "--output-path", str(evidence / "attachments")], source, evidence, "attachments")
        result["status"] = "succeeded"
    except BaseException as error:
        result.update(status="failed", error=repr(error))
        raise
    finally:
        checks = {}
        try:
            verify(args.snapshot)
            actual = tree_files(source) if source.exists() else {}
            checks = {"snapshotVerified": True, "cloneVerified": actual == manifest["files"],
                "changedOrMissing": [p for p, entry in manifest["files"].items() if actual.get(p) != entry],
                "added": sorted(actual.keys() - manifest["files"].keys())}
        except BaseException as error:
            checks["error"] = repr(error)
        write(evidence / "hash-after.json", checks)
        write(evidence / "result.json", result)
        if result["status"] == "succeeded" and not (checks.get("snapshotVerified") and checks.get("cloneVerified")):
            raise ValueError("Post-run source integrity verification failed")


if __name__ == "__main__":
    main()
