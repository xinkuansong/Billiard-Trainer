#!/usr/bin/env python3
"""Use the authorized iOS 17 lease, then restore the backed-up review install."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from mac_mini_queue import test_summary


def contents(root, metadata=True):
    result = {}
    for p in sorted(root.rglob("*")):
        relative = str(p.relative_to(root))
        if not metadata and relative == ".com.apple.mobile_container_manager.metadata.plist":
            continue
        if p.is_symlink():
            result[relative] = {"link": os.readlink(p)}
        elif p.is_file():
            result[relative] = {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
    return result


def main():
    prepared, backup = [Path(p).resolve() for p in sys.argv[1:3]]
    evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
    assert os.environ["QIUJI_TEST_RUN_ID"] and os.environ["QIUJI_SIMULATOR_LEASE_TOKEN"]
    prior = json.loads((backup / "evidence/backup-manifest.json").read_text())
    uid, bundle = prior["device"], prior["bundle"]
    assert os.environ["QIUJI_SIMULATOR_UDID"] == uid
    built = json.loads((prepared / "evidence/result.json").read_text())
    assert built["status"] == "succeeded" and built["minimumOS"] == "17.0"
    for record in prior["records"]:
        assert contents(Path(record["backup"])) == record["files"]
        assert contents(Path(record["original"])) == record["files"], "Review changed since backup"
    app_record = next(r for r in prior["records"] if r["category"] == "Bundle/Application")
    data_record = next(r for r in prior["records"] if r["category"] == "Data/Application")
    old_apps = list(Path(app_record["backup"]).glob("*.app"))
    assert len(old_apps) == 1
    old_app = old_apps[0]
    old_app_files = contents(old_app)
    old_data_files = contents(Path(data_record["backup"]), metadata=False)
    def sim(*args):
        return subprocess.check_output(["xcrun", "simctl", *args], text=True, timeout=120).strip()
    live = json.loads(sim("list", "devices", "-j"))
    device = next(d for ds in live["devices"].values() for d in ds if d["udid"] == uid)
    assert device["state"] == "Shutdown"
    products = prepared / "work/build/DerivedData/Build/Products"
    descriptors = list(products.glob("*.xctestrun"))
    assert len(descriptors) == 1
    app = products / "Debug-iphonesimulator/CuePhys.app"
    assert hashlib.sha256((app / "CuePhys").read_bytes()).hexdigest() == built["executableSHA256"]
    selectors = built["selectors"]
    def absolute(value):
        if isinstance(value, dict):
            result = {k: absolute(v) for k, v in value.items()}
            if "CuePhysTests.xctest" in result.get("TestBundlePath", ""):
                result["OnlyTestIdentifiers"] = [s.removeprefix("CuePhysTests/") for s in selectors]
            return result
        if isinstance(value, list):
            return [absolute(v) for v in value]
        return value.replace("__TESTROOT__", str(products)) if isinstance(value, str) else value
    descriptor = evidence / "runtime.xctestrun"
    descriptor.write_bytes(plistlib.dumps(absolute(plistlib.loads(descriptors[0].read_bytes()))))
    result = {"device": uid, "runtime": "iOS 17.0", "snapshotID": built["snapshotID"],
        "authorization": "User explicitly allowed borrowing and restoring the review device", "restore": "pending"}
    changed = False
    try:
        sim("boot", uid)
        sim("bootstatus", uid, "-b")
        command = ["make", "-f", str(ROOT / "scripts/Makefile"), "test", "TEST_ACTION=test-without-building",
            "TEST_XCTESTRUN=" + str(descriptor), "TEST_DESTINATION=platform=iOS Simulator,id=" + uid,
            "BUILD_DIR=" + str(prepared / "work/build"), "DERIVED_DATA=" + str(prepared / "work/build/DerivedData"),
            "TEST_LOG=" + str(evidence / "tests.log"), "TEST_JUNIT=" + str(evidence / "tests.xml"),
            "TEST_RESULT_BUNDLE=" + str(evidence / "tests.xcresult"),
            "TEST_SELECTOR=" + " ".join("-only-testing:" + s for s in selectors),
            "TEST_CODE_COVERAGE=NO", "TEST_BUILD_SETTINGS=CODE_SIGNING_ALLOWED=NO", "SIM_TEST_GUARD="]
        (evidence / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        changed = True
        with (evidence / "driver.log").open("wb") as stream:
            test = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600)
        result["testExitCode"] = test.returncode
        with (evidence / "export.log").open("wb") as stream:
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path",
                str(evidence / "tests.xcresult"), "--output-path", str(evidence / "attachments")],
                stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
        test.check_returncode()
        summary = test_summary(evidence, selectors)
        assert summary["totalTestCount"] == 8
        result["tests"] = "8 passed"
    finally:
        try:
            if changed:
                # No uninstall/erase: reinstall the exact old app, then restore its
                # data while the device is shut down. Preserve container metadata.
                sim("install", uid, str(old_app))
                restored_app = Path(sim("get_app_container", uid, bundle, "app"))
                restored_data = Path(sim("get_app_container", uid, bundle, "data"))
                sim("shutdown", uid)
                subprocess.run(["rsync", "-a", "--delete", "--exclude=.com.apple.mobile_container_manager.metadata.plist",
                    str(Path(data_record["backup"])) + "/", str(restored_data) + "/"], check=True)
                assert contents(restored_app) == old_app_files, "Restored app differs"
                assert contents(restored_data, metadata=False) == old_data_files, "Restored data differs"
                result["restore"] = "original app and app data verified; device shutdown"
            else:
                # A boot-only failure must also restore the original power state.
                current = json.loads(sim("list", "devices", "-j"))
                state = next(d["state"] for ds in current["devices"].values() for d in ds if d["udid"] == uid)
                if state != "Shutdown":
                    sim("shutdown", uid)
                result["restore"] = "no app changes; device shutdown"
        except BaseException as error:
            result["restore"] = "FAILED: " + repr(error)
            raise
        finally:
            (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
