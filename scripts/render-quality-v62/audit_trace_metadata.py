#!/usr/bin/env python3
"""Check trace provenance before analysis; never infer FPS from trace duration.

Input is `xctrace export --toc` XML. Passing these checks only permits further
analysis; it does not prove presentation, CPU/GPU budgets, or device acceptance.
"""
import argparse
import json
import math
import xml.etree.ElementTree as ET


def audit(toc, run_number, expected_process, minimum_seconds):
    root = ET.parse(toc).getroot()
    run = root.find(f"./run[@number='{run_number}']")
    if run is None:
        raise ValueError(f"Run {run_number} is absent")
    device = run.find("./info/target/device")
    process = run.find("./info/target/process")
    if device is None or process is None:
        raise ValueError("Target device/process metadata is absent")
    duration = float(run.findtext("./info/summary/duration", default="nan"))
    schemas = sorted({t.get("schema") for t in run.findall("./data/table") if t.get("schema")})
    issues = []
    # A simulator is not a physical iOS sample even if its OS version is iOS.
    platform = device.get("platform", "")
    if platform != "iOS" or "simulator" in device.get("model", "").lower():
        issues.append("Target is not identified as a physical iOS device")
    if process.get("name") != expected_process:
        issues.append("Target process differs from the expected application")
    if not math.isfinite(duration) or duration < minimum_seconds:
        issues.append("Recording duration is missing or shorter than the sample window")
    if not {"ca-client-presented-handler", "display-surface-queue"}.intersection(schemas):
        issues.append("No known presentation schema is listed")
    return {
        "metadata_preconditions_pass": not issues,
        "performance_accepted": False,
        "reason": "Presentation rows and CPU/GPU/memory/thermal evidence still require analysis",
        "issues": issues,
        "target_device": dict(device.attrib),
        "target_process": dict(process.attrib),
        "recording_seconds": duration if math.isfinite(duration) else None,
        "minimum_sample_seconds": minimum_seconds,
        "schemas": schemas,
        "fps": None,
        "cpu_p95_ms": None,
        "gpu_p95_ms": None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("toc")
    parser.add_argument("--run", type=int, default=1)
    parser.add_argument("--process", default="球迹")
    parser.add_argument("--minimum-seconds", type=float, default=60)
    args = parser.parse_args()
    if args.run < 1 or not math.isfinite(args.minimum_seconds) or args.minimum_seconds <= 0:
        parser.error("Run and minimum sample duration must be positive")
    try:
        result = audit(args.toc, args.run, args.process, args.minimum_seconds)
    except (OSError, ET.ParseError, ValueError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False))
    return 0 if result["metadata_preconditions_pass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
