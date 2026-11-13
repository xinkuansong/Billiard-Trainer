#!/usr/bin/env python3
"""Install the previously validated r7 app and launch its opt-in guard preview.

Explicit user-requested deployment, no test fixtures, reset, uninstall or profiling.
Requires local_test_lifecycle.py and the currently discovered physical device ID.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from mac_mini_queue import digest, tree_files, verify


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def command(argv, cwd, evidence, label, timeout=1200):
    write(evidence / (label + "-command.json"), argv)
    print(label + " started", flush=True)
    with (evidence / (label + "-driver.log")).open("wb") as stream:
        subprocess.run(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=timeout)
    print(label + " completed", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--device", required=True)
    a = parser.parse_args()
    work, evidence = a.work.resolve(), a.evidence.resolve()
    if str(work) != os.environ.get("QIUJI_TEST_WORK") or str(evidence) != os.environ.get("QIUJI_TEST_EVIDENCE"):
        raise ValueError("Requires a managed local test owner")
    snapshot = ROOT / "output/render-lowdim-20261113/ios-snapshot-r7"
    manifest = verify(snapshot)
    if manifest["snapshot_id"] != "ade5961f45f2e436c6a6aa5df3da862e740a699f58b231d1139d39c7cc02b834":
        raise ValueError("Unexpected source snapshot")
    source = work / "source"
    write(evidence / "snapshot-manifest.json", manifest)
    shutil.copyfile(__file__, evidence / "install_phone_preview.py")
    result = {"status": "running", "snapshotID": manifest["snapshot_id"], "device": a.device,
        "scope": "User hands-on preview; no performance/thermal acceptance",
        "launchArguments": ["-daily3D.guardClothSupport"],
        "persistence": "Flag applies to this launched process only; later icon relaunch uses original R"}
    try:
        command(["cp", "-cR", str(snapshot / "source"), str(source)], ROOT, evidence, "clone")
        if tree_files(source) != manifest["files"]:
            raise ValueError("Clone differs from frozen inputs")
        command(["make", "-f", str(source / "scripts/Makefile"), "test", "TEST_ACTION=build",
            "TEST_CONFIGURATION=Debug", "TEST_DESTINATION=generic/platform=iOS",
            "BUILD_DIR=" + str(work / "build"), "DERIVED_DATA=" + str(work / "build/DerivedData"),
            "TEST_LOG=" + str(evidence / "build.log"), "TEST_JUNIT=" + str(evidence / "build.xml"),
            "TEST_RESULT_BUNDLE=" + str(evidence / "build.xcresult"),
            "TEST_BUILD_SETTINGS=SWIFT_OPTIMIZATION_LEVEL=-O ARCHS=arm64 -jobs 4",
            "SIM_TEST_GUARD="], source, evidence, "build")
        app = work / "build/DerivedData/Build/Products/Debug-iphoneos/球迹.app"
        info = plistlib.loads((app / "Info.plist").read_bytes())
        bundle = info["CFBundleIdentifier"]
        if bundle != "com.xinkuan.qiuji":
            raise ValueError("Unexpected app identity")
        command(["codesign", "--verify", "--deep", "--strict", str(app)], ROOT, evidence, "signature")
        write(evidence / "product.json", {"bundle": bundle, "version": info.get("CFBundleShortVersionString"),
            "build": info.get("CFBundleVersion"), "executableSHA256": digest(app / info["CFBundleExecutable"]),
            "profileSHA256": digest(app / "embedded.mobileprovision"),
            "configuration": "Debug -O, production DEBUG guard flag available"})
        command(["xcrun", "devicectl", "device", "info", "details", "--device", a.device,
            "--json-output", str(evidence / "device-details.json"), "--timeout", "20"], ROOT, evidence, "device", 30)
        details = json.loads((evidence / "device-details.json").read_text())
        # The exact device was discovered/read before this run. Record fresh
        # transport/identity here, without resetting any device or app data.
        command(["xcrun", "devicectl", "device", "install", "app", "--device", a.device, str(app),
            "--json-output", str(evidence / "install.json"), "--timeout", "180"], ROOT, evidence, "install", 200)
        command(["xcrun", "devicectl", "device", "process", "launch", "--device", a.device,
            "--terminate-existing", "--json-output", str(evidence / "launch.json"), "--timeout", "30",
            bundle, "--", "-daily3D.guardClothSupport"], ROOT, evidence, "launch", 40)
        result["status"] = "installed-and-launched"
    except BaseException as error:
        result.update(status="failed", error=repr(error))
        raise
    finally:
        verify(snapshot)
        actual = tree_files(source) if source.exists() else {}
        checks = {"snapshotVerified": True, "cloneVerified": actual == manifest["files"],
            "changedOrMissing": [p for p, v in manifest["files"].items() if actual.get(p) != v],
            "added": sorted(actual.keys() - manifest["files"].keys())}
        write(evidence / "hash-after.json", checks)
        write(evidence / "result.json", result)
        if result["status"] == "installed-and-launched" and not checks["cloneVerified"]:
            raise ValueError("Source integrity changed during deployment")


if __name__ == "__main__":
    main()
