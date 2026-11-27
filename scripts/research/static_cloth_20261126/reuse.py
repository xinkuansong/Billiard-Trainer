#!/usr/bin/env python3
"""Run a checksum-bound research shader on a held, signed native baseline."""
import base64
import hashlib
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
from mac_mini_queue import test_summary


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parent, candidate = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
    evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
    assert os.environ["QIUJI_TEST_RUN_ID"]
    if json.loads((parent / "evidence/result.json").read_text())["status"] != "succeeded":
        raise ValueError("Parent baseline is not successful")
    if not json.loads((parent / "evidence/hash-after.json").read_text())["cloneVerified"]:
        raise ValueError("Parent frozen source verification failed")
    products = parent / "work/build/DerivedData/Build/Products"
    runs = list(products.glob("*.xctestrun"))
    if len(runs) != 1:
        raise ValueError("Ambiguous native test product")
    app = products / "Debug-iphoneos/CuePhys.app"
    executable = app / "CuePhys"
    test_bundle = app / "PlugIns/CuePhysTests.xctest/CuePhysTests"
    identities = {str(p): sha(p) for p in (runs[0], executable, test_bundle)}
    source = candidate.read_bytes()
    environment = {"STATIC_CLOTH_INPUT_SHA": "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04",
                   "STATIC_CLOTH_OUTPUT_SHA": hashlib.sha256(source).hexdigest(),
                   "STATIC_CLOTH_SOURCE_BASE64": base64.b64encode(source).decode(),
                   "STATIC_CLOTH_QUALITY": "1"}
    if os.environ.get("STATIC_CLOTH_EXTENDED") == "1":
        environment["STATIC_CLOTH_EXTENDED"] = "1"
    if "STATIC_CLOTH_GEOMETRY_GRID" in os.environ:
        grid=os.environ["STATIC_CLOTH_GEOMETRY_GRID"]
        if grid not in ("33","65"):
            raise ValueError("Only the two predeclared static geometry grids are allowed")
        environment["STATIC_CLOTH_GEOMETRY_GRID"] = grid
    if "STATIC_CLOTH_RESPONSE_GRID" in os.environ:
        grid=os.environ["STATIC_CLOTH_RESPONSE_GRID"]
        if grid not in ("17","33"):
            raise ValueError("Only predeclared response grids")
        kernel=candidate.with_suffix(".metal").read_bytes()
        environment.update(STATIC_CLOTH_RESPONSE_GRID=grid,
                           STATIC_CLOTH_RESPONSE_KERNEL=base64.b64encode(kernel).decode(),
                           STATIC_CLOTH_RESPONSE_SHA=hashlib.sha256(kernel).hexdigest())
        (evidence/"response-kernel.metal").write_bytes(kernel)
    if os.environ.get("STATIC_CLOTH_CAPTURE") == "1":
        if shutil.disk_usage(evidence).free < 4*1024**3:
            raise RuntimeError("Capture needs 4 GiB free, including raw trace and evidence reserve")
        # Test host owns its temporary directory and returns traces through XCTest attachments.
        environment.update(METAL_CAPTURE_ENABLED="1", STATIC_CLOTH_CAPTURE="1")
    descriptor = plistlib.loads(runs[0].read_bytes())
    configured = 0
    def prepare(value):
        nonlocal configured
        if isinstance(value, dict):
            result = {k: prepare(v) for k, v in value.items()}
            if "TestBundlePath" in result and "CuePhysTests.xctest" in result["TestBundlePath"]:
                result.setdefault("EnvironmentVariables", {}).update(environment)
                result["OnlyTestIdentifiers"] = ["ClothSupportPerformanceResearchTests/testNativeStaticClothCandidate"]
                configured += 1
            return result
        if isinstance(value, list):
            return [prepare(x) for x in value]
        if isinstance(value, str):
            return value.replace("__TESTROOT__", str(products))
        return value
    descriptor = prepare(descriptor)
    if configured != 1:
        raise ValueError(f"Expected one target, configured {configured}")
    test_run = evidence / "candidate.xctestrun"
    test_run.write_bytes(plistlib.dumps(descriptor))
    (evidence / "candidate.surface").write_bytes(source)
    (evidence / "identities.json").write_text(json.dumps(identities, indent=2)+"\n")
    selector = "CuePhysTests/ClothSupportPerformanceResearchTests/testNativeStaticClothCandidate"
    command = ["make", "-f", str(ROOT / "scripts/Makefile"), "test", "TEST_ACTION=test-without-building",
        "TEST_XCTESTRUN="+str(test_run), "TEST_DESTINATION=platform=macOS,arch=arm64,variant=Designed for iPad,id=00006050-0015294102F9401C",
        "BUILD_DIR="+str(parent / "work/build"), "DERIVED_DATA="+str(parent / "work/build/DerivedData"),
        "TEST_LOG="+str(evidence / "tests.log"), "TEST_JUNIT="+str(evidence / "tests.xml"),
        "TEST_RESULT_BUNDLE="+str(evidence / "tests.xcresult"), "TEST_SELECTOR=-only-testing:"+selector,
        "TEST_CODE_COVERAGE=NO", "SIM_TEST_GUARD="]
    (evidence / "command.json").write_text(json.dumps(command, indent=2)+"\n")
    with (evidence / "driver.log").open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600)
    with (evidence / "export.log").open("wb") as stream:
        exported = subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path",
            str(evidence / "tests.xcresult"), "--output-path", str(evidence / "attachments")],
            stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    after = {name: sha(Path(name)) for name in identities}
    (evidence / "identity-after.json").write_text(json.dumps(after, indent=2)+"\n")
    if after != identities:
        raise ValueError("Signed baseline changed")
    if result.returncode or exported.returncode:
        raise RuntimeError(f"Test {result.returncode}, export {exported.returncode}")
    if os.environ.get("STATIC_CLOTH_CAPTURE") == "1":
        subprocess.run([sys.executable,str(Path(__file__).with_name("unpack_capture.py")),str(evidence)],check=True)
    summary = test_summary(evidence, [selector])
    if summary.get("totalTestCount") != 1:
        raise ValueError("Unexpected test count")
    subprocess.run([sys.executable,str(Path(__file__).with_name("analyze.py")),str(evidence)],check=True)
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
