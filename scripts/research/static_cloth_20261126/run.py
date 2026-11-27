#!/usr/bin/env python3
"""Managed, immutable current-source native cloth study (not a phone test)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from mac_mini_queue import snapshot


def main():
    work = Path(os.environ["QIUJI_TEST_WORK"])
    evidence = Path(os.environ["QIUJI_TEST_EVIDENCE"])
    assert os.environ["QIUJI_TEST_RUN_ID"]
    free = shutil.disk_usage(ROOT).free
    (evidence / "preflight.json").write_text(json.dumps({
        "availableBytes": free, "minimumGiB": 12,
        "scope": "native iOS-on-Mac, isolated frozen source; no phone install",
    }, indent=2) + "\n")
    if free < 12 * 1024**3:
        raise RuntimeError("At least 12 GiB required for build, evidence and reserve")
    snapshot(ROOT, work / "snapshot", dirty=True, quiescent=True)
    for relative in ["CuePhysTests/ClothSupportPerformanceResearchTests.swift",
                     "CuePhysTests/ClothAppearanceTests.swift",
                     "CuePhys/Core/Scene/MobileReferenceLighting.swift",
                     "CuePhys/Core/Scene/StaticClothIrradiance.swift",
                     "CuePhys/Core/Scene/ClothSpecularLTC.swift",
                     "CuePhys/Core/Scene/MobileRailAppearance.swift",
                     "CuePhys/Core/Scene/MobileTableRendering.swift",
                     "CuePhys/Core/Scene/AngleTrainingScene.swift"]:
        target = evidence / "frozen-source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(work / "snapshot/source" / relative, target)
    shutil.copyfile(ROOT / "tasks/render-static-cloth-20261126/BASELINE.md", evidence / "BASELINE.md")
    selectors = sys.argv[1:] or ["testNativeStaticClothB0"]
    selectors = ["CuePhysTests/" + (s if "/" in s else "ClothSupportPerformanceResearchTests/"+s) for s in selectors]
    command = [sys.executable, str(ROOT / "scripts/research/cloth_lowdim_20261113/run_native_app.py"),
               "--snapshot", str(work / "snapshot"), "--work", str(work),
               "--evidence", str(evidence), "--expected-count",str(len(selectors))]
    for selector in selectors:
        command += ["--test",selector]
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode and (evidence / "tests.xcresult").exists():
        with (evidence / "failure-export.log").open("wb") as stream:
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path",
                            str(evidence / "tests.xcresult"), "--output-path", str(evidence / "failure-attachments")],
                           stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
