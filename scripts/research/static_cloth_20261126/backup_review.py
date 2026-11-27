#!/usr/bin/env python3
"""Read-only backup of the precise iOS 17 review install before asking to borrow it."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess

UDID = "16365EE2-0C42-4EE1-B707-09AC55A0ABA7"
BUNDLE = "com.youbilliards.cuephys"


def files(root):
    result = {}
    for path in sorted(root.rglob("*")):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            result[relative] = {"link": os.readlink(path)}
        elif path.is_file():
            result[relative] = {"bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    return result


def shutdown():
    devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))
    target = [d for entries in devices["devices"].values() for d in entries if d["udid"] == UDID]
    assert len(target) == 1 and target[0]["state"] == "Shutdown", "Review device changed state"


work, evidence = (Path(os.environ[k]) for k in ("QIUJI_TEST_WORK", "QIUJI_TEST_EVIDENCE"))
assert os.environ["QIUJI_TEST_RUN_ID"]
shutdown()
containers = Path.home() / "Library/Developer/CoreSimulator/Devices" / UDID / "data/Containers"
records = []
for category in ["Bundle/Application", "Data/Application"]:
    matches = []
    for container in (containers / category).iterdir():
        metadata = container / ".com.apple.mobile_container_manager.metadata.plist"
        if metadata.exists() and plistlib.loads(metadata.read_bytes()).get("MCMMetadataIdentifier") == BUNDLE:
            matches.append(container)
    assert len(matches) == 1, "Expected exactly one review container"
    original = matches[0]
    before = files(original)
    copy = work / category.split("/")[0]
    subprocess.run(["cp", "-cR", str(original), str(copy)], check=True)
    assert files(copy) == before == files(original), "Backup identity or review contents changed"
    records.append({"category": category, "original": str(original), "backup": str(copy), "files": before})
shutdown()
(evidence / "backup-manifest.json").write_text(json.dumps({"device": UDID, "bundle": BUNDLE,
    "scope": "App bundle and app data only; no device changes; not a full simulator/keychain backup",
    "records": records}, indent=2) + "\n")
print("Review installation and app data backed up and verified; original device unchanged")
