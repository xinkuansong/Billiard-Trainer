#!/usr/bin/env python3
"""Build the exact frozen integration source in Release; no install or tests."""
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
    assert json.loads((parent / "evidence/result.json").read_text())["status"] == "succeeded"
    manifest = verify(parent / "work/snapshot")
    frozen = parent / "work/source"
    assert tree_files(frozen) == manifest["files"]
    if shutil.disk_usage(work).free < 10 * 1024**3:
        raise RuntimeError("Release needs 10 GiB including evidence reserve")
    source = work / "source"
    subprocess.run(["cp", "-cR", str(frozen), str(source)], check=True)
    assert tree_files(source) == manifest["files"]
    # The public snapshot deliberately excludes private build configuration.
    # Supply it only in this local disposable clone; never export its contents.
    private_config = source / "Config/Secrets.xcconfig"
    private_config.parent.chmod(private_config.parent.stat().st_mode | 0o200)
    shutil.copyfile(ROOT / "Config/Secrets.xcconfig", private_config)
    private_digest = hashlib.sha256(private_config.read_bytes()).digest()
    command = ["make", "-f", str(source / "scripts/Makefile"), "test",
        "TEST_ACTION=build", "TEST_CONFIGURATION=Release", "TEST_DESTINATION=generic/platform=iOS",
        "BUILD_DIR=" + str(work / "build"), "DERIVED_DATA=" + str(work / "build/DerivedData"),
        "TEST_LOG=" + str(evidence / "build.log"), "TEST_JUNIT=" + str(evidence / "build.xml"),
        "TEST_RESULT_BUNDLE=" + str(evidence / "build.xcresult"),
        "TEST_BUILD_SETTINGS=ARCHS=arm64 CODE_SIGNING_ALLOWED=NO -jobs 4", "TEST_SELECTOR=", "SIM_TEST_GUARD="]
    (evidence / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    result = {"snapshotID": manifest["snapshot_id"], "privateConfigSuppliedLocally": True,
        "scope": "Unsigned Release build only; no runtime test or phone install"}
    try:
        with (evidence / "driver.log").open("wb") as stream:
            subprocess.run(command, cwd=source, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=1800)
        app = work / "build/DerivedData/Build/Products/Release-iphoneos/CuePhys.app"
        info = plistlib.loads((app / "Info.plist").read_bytes())
        executable = app / info["CFBundleExecutable"]
        result.update(status="succeeded", minimumOS=info["MinimumOSVersion"],
            executableSHA256=hashlib.sha256(executable.read_bytes()).hexdigest())
    except BaseException as error:
        result.update(status="failed", error=repr(error))
        raise
    finally:
        actual = tree_files(source)
        actual.pop("Config/Secrets.xcconfig")
        result["sourceUnchanged"] = (actual == manifest["files"]
            and tree_files(frozen) == manifest["files"]
            and hashlib.sha256(private_config.read_bytes()).digest() == private_digest)
        (evidence / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        assert result["sourceUnchanged"]


if __name__ == "__main__":
    main()
