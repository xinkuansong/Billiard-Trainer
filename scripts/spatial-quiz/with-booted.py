#!/usr/bin/env python3
"""Run only inside simulator_fleet's exclusive lease; await OS boot before XCTest."""
import json
import subprocess
import sys

udid, *command = sys.argv[1:]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
device = next(d for group in devices["devices"].values() for d in group if d["udid"] == udid)
started_here = device["state"] != "Booted"
if started_here:
    subprocess.run(["xcrun", "simctl", "boot", udid], check=True)
try:
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)
    result = subprocess.run(command).returncode
finally:
    if started_here:
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=True)
sys.exit(result)
