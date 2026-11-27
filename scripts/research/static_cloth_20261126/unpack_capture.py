#!/usr/bin/env python3
"""Reassemble only the files emitted by the owned XCTest GPU capture."""
import json
from pathlib import Path, PurePosixPath
import shutil
import sys

root = Path(sys.argv[1]).resolve()
attachments = root / "attachments"
entries = [e for c in json.loads((attachments/"manifest.json").read_text()) for e in c["attachments"]]


def attachment(prefix):
    matches = [e for e in entries if e["suggestedHumanReadableName"].startswith(prefix+"_")]
    if len(matches) != 1:
        raise ValueError(f"Missing or duplicate attachment {prefix}: {len(matches)}")
    return attachments / matches[0]["exportedFileName"]


for arm in ("A","B"):
    manifest = json.loads(attachment(f"static-cloth-capture-{arm}-manifest").read_text())
    assert manifest["arm"] == arm
    destination = root / (arm+".gputrace")
    destination.mkdir()
    links = []
    for entry in manifest["files"]:
        path = PurePosixPath(entry["path"])
        if path.is_absolute() or ".." in path.parts:
            raise ValueError("Unsafe relative capture path")
        target = destination / path
        target.parent.mkdir(parents=True,exist_ok=True)
        if "directory" in entry:
            target.mkdir(exist_ok=True)
        elif "link" in entry:
            links.append((target,entry["link"]))
        else:
            shutil.copyfile(attachment(entry["attachment"]),target)
    for target,link in links:
        if not (target.parent/link).resolve().is_relative_to(destination):
            raise ValueError("Capture link leaves its root")
        # Lifecycle evidence must contain regular files, not symlinks.
        shutil.copyfile((target.parent/link).resolve(),target)
    print(destination)
