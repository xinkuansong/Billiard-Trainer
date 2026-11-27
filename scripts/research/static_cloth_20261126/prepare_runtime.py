#!/usr/bin/env python3
"""Prepare immutable simulator products before requesting a protected review device."""
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
from mac_mini_queue import tree_files, verify


def main():
    parent = Path(sys.argv[1]).resolve()
    work, evidence = (Path(os.environ[k]) for k in ("QIUJI_TEST_WORK", "QIUJI_TEST_EVIDENCE"))
    assert os.environ["QIUJI_TEST_RUN_ID"]
    manifest = verify(parent / "work/snapshot")
    source = parent / "work/source"
    assert tree_files(source) == manifest["files"]
    if shutil.disk_usage(work).free < 12 * 1024**3:
        raise RuntimeError("Simulator build needs 12 GiB including evidence reserve")
    selectors = ["CuePhysTests/" + s for s in [
        "ClothAppearanceTests/testApprovedBrightnessSurvivesAppearanceAndSceneRebuilds",
        "ClothAppearanceTests/testRailAppearanceSurvivesMaterialLifecycles",
        "ClothAppearanceTests/testRenderPaletteAndGreenRestoration",
        "ClothAppearanceTests/testReferenceLightingPaletteAndBounce",
        "Daily3DRenderDiagnosticsTests/testPageRequiresVisibleForeground3DAndBalancesEveryExit",
        "Daily3DRenderDiagnosticsTests/testIdleRequiresAnActualInactiveSchedulerDecision",
        "Daily3DRenderDiagnosticsTests/testFirstWakeAndRenderRetainInputIdentityAndExitClearsPendingInput",
        "Daily3DRenderDiagnosticsTests/testDisabledDiagnosticsStaySilentAndDelegatesPreserveFrameReceipt",
    ]]
    command = ["make", "-f", str(source / "scripts/Makefile"), "test",
        "TEST_ACTION=build-for-testing", "TEST_CONFIGURATION=Debug",
        "TEST_DESTINATION=generic/platform=iOS Simulator",
        "BUILD_DIR=" + str(work / "build"), "DERIVED_DATA=" + str(work / "build/DerivedData"),
        "TEST_LOG=" + str(evidence / "build.log"), "TEST_JUNIT=" + str(evidence / "build.xml"),
        "TEST_RESULT_BUNDLE=" + str(evidence / "build.xcresult"),
        "TEST_BUILD_SETTINGS=ARCHS=arm64 CODE_SIGNING_ALLOWED=NO -jobs 4",
        "TEST_CODE_COVERAGE=NO", "TEST_SELECTOR=" + " ".join("-only-testing:" + s for s in selectors),
        "SIM_TEST_GUARD="]
    (evidence / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    result = {"snapshotID": manifest["snapshot_id"], "selectors": selectors,
        "scope": "Simulator build only; no device acquired, app installed or tests executed"}
    try:
        with (evidence / "driver.log").open("wb") as stream:
            subprocess.run(command, cwd=source, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=1800)
        app = work / "build/DerivedData/Build/Products/Debug-iphonesimulator/CuePhys.app"
        info = plistlib.loads((app / "Info.plist").read_bytes())
        executable = app / info["CFBundleExecutable"]
        result.update(status="succeeded", minimumOS=info["MinimumOSVersion"],
            executableSHA256=hashlib.sha256(executable.read_bytes()).hexdigest())
    except BaseException as error:
        result.update(status="failed", error=repr(error))
        raise
    finally:
        result["sourceUnchanged"] = tree_files(source) == manifest["files"]
        (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        assert result["sourceUnchanged"]


if __name__ == "__main__":
    main()
