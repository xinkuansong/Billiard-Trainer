#!/usr/bin/env python3
"""Run targeted lifecycle consumers on an already verified, held native build."""
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


def main():
    parent = Path(sys.argv[1]).resolve()
    evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
    assert os.environ["QIUJI_TEST_RUN_ID"]
    assert json.loads((parent / "evidence/result.json").read_text())["status"] == "succeeded"
    assert json.loads((parent / "evidence/hash-after.json").read_text())["cloneVerified"]
    selectors = [
        "ClothAppearanceTests/testRenderPaletteAndGreenRestoration",
        "ClothAppearanceTests/testReferenceLightingPaletteAndBounce",
        "Daily3DRenderDiagnosticsTests/testPageRequiresVisibleForeground3DAndBalancesEveryExit",
        "Daily3DRenderDiagnosticsTests/testIdleRequiresAnActualInactiveSchedulerDecision",
        "Daily3DRenderDiagnosticsTests/testFirstWakeAndRenderRetainInputIdentityAndExitClearsPendingInput",
        "Daily3DRenderDiagnosticsTests/testDisabledDiagnosticsStaySilentAndDelegatesPreserveFrameReceipt",
    ]
    products = parent / "work/build/DerivedData/Build/Products"
    descriptors = list(products.glob("*.xctestrun"))
    assert len(descriptors) == 1
    app = products / "Debug-iphoneos/CuePhys.app"
    paths = [descriptors[0], app / "CuePhys", app / "PlugIns/CuePhysTests.xctest/CuePhysTests"]
    def identities():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before = identities()
    configured = 0
    def prepare(value):
        nonlocal configured
        if isinstance(value, dict):
            result = {k: prepare(v) for k, v in value.items()}
            if "CuePhysTests.xctest" in result.get("TestBundlePath", ""):
                result["OnlyTestIdentifiers"] = selectors
                configured += 1
            return result
        if isinstance(value, list):
            return [prepare(x) for x in value]
        return value.replace("__TESTROOT__", str(products)) if isinstance(value, str) else value
    descriptor = prepare(plistlib.loads(descriptors[0].read_bytes()))
    assert configured == 1
    run = evidence / "consumers.xctestrun"
    run.write_bytes(plistlib.dumps(descriptor))
    (evidence / "identities.json").write_text(json.dumps(before, indent=2) + "\n")
    full = ["CuePhysTests/" + s for s in selectors]
    command = ["make", "-f", str(ROOT / "scripts/Makefile"), "test",
        "TEST_ACTION=test-without-building", "TEST_XCTESTRUN=" + str(run),
        "TEST_DESTINATION=platform=macOS,arch=arm64,variant=Designed for iPad,id=00006050-0015294102F9401C",
        "BUILD_DIR=" + str(parent / "work/build"),
        "DERIVED_DATA=" + str(parent / "work/build/DerivedData"),
        "TEST_LOG=" + str(evidence / "tests.log"), "TEST_JUNIT=" + str(evidence / "tests.xml"),
        "TEST_RESULT_BUNDLE=" + str(evidence / "tests.xcresult"),
        "TEST_SELECTOR=" + " ".join("-only-testing:" + s for s in full),
        "TEST_CODE_COVERAGE=NO", "SIM_TEST_GUARD="]
    (evidence / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    try:
        with (evidence / "driver.log").open("wb") as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=600)
        with (evidence / "export.log").open("wb") as stream:
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path",
                str(evidence / "tests.xcresult"), "--output-path", str(evidence / "attachments")],
                stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
        result.check_returncode()
        summary = test_summary(evidence, full)
        assert summary["totalTestCount"] == len(selectors)
        print(json.dumps(summary))
    finally:
        after = identities()
        (evidence / "identity-after.json").write_text(json.dumps(after, indent=2) + "\n")
        assert after == before, "Frozen signed product changed"


if __name__ == "__main__":
    main()
