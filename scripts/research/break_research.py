#!/usr/bin/env python3
"""Reproducible XCTest research orchestration; no production physics mutations."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get("BREAK_RESEARCH_OUTPUT", ROOT / "build/break-potting-research-20261002"))
DERIVED = OUT / "DerivedData"
DEVICE = "E7C9EC40-49A0-407F-B5E7-9C6A8C986753"
TARGET = ROOT / "QiuJiTests/BreakRackPhysicsTests.swift"
HARNESS = Path(__file__).with_suffix(".swift")
BEGIN = "// BEGIN BREAK POTTING RESEARCH 20261002\n"
END = "// END BREAK POTTING RESEARCH 20261002\n"


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def hashes() -> dict[str, str]:
    paths = sorted((ROOT / "QiuJi/Core/Physics").rglob("*.swift"))
    paths += sorted((ROOT / "QiuJi/Core/Rack").rglob("*.swift"))
    paths += sorted((ROOT / "QiuJi/Core/SpatialPhysics").rglob("*.swift"))
    # Actual spatial dependencies may be under other paths; the full compiler file list is retained.
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def job(identifier: str, **kw) -> dict:
    data = dict(id=identifier, rackKind="production", seed=1, theta=0, fraction=0,
                contactSpeed=10, reverse=False, mirror=False, trace=False, mode="matched",
                cueX=0.70, cueZ=0, aimTheta=0, power=8, spinY=0)
    data.update(kw)
    return data


def geometry() -> list[dict]:
    jobs = []
    for theta in range(-22, 23, 2):
        for f in range(-4, 5):
            for kind, seed in [("nominal", 0)] + [("production", n) for n in range(1, 5)]:
                identifier = f"g_t{theta}_b{f}_s{seed}_{kind}"
                jobs.append(job(identifier, theta=theta, fraction=f / 10, rackKind=kind, seed=seed,
                                trace=kind == "nominal" and theta in (-16, 0, 16) and f in (-2, 0, 2)))
    return jobs


def parse_log(log: Path) -> list[dict]:
    rows = []
    for line in log.read_text(errors="replace").splitlines():
        marker = "[BREAK-RESEARCH] "
        if marker in line:
            try:
                rows.append(json.loads(line.split(marker, 1)[1]))
            except json.JSONDecodeError as error:
                raise RuntimeError(f"Malformed result line in {log}: {error}") from error
    return rows


def xcode_args(action: str) -> list[str]:
    return ["xcodebuild", "-project", str(ROOT / "QiuJi.xcodeproj"), "-scheme", "QiuJi",
            "-configuration", "Debug", "-derivedDataPath", str(DERIVED), "-destination",
            f"platform=iOS Simulator,id={DEVICE}", "-parallel-testing-enabled", "NO",
            "-enableCodeCoverage", "NO", "SWIFT_OPTIMIZATION_LEVEL=-O", "-jobs", "2", action]


def build() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    before = TARGET.read_bytes()
    if BEGIN.encode() in before:
        raise RuntimeError("Harness is already installed; inspect before retrying")
    write_json(OUT / "production-hashes-before.json", hashes())
    (OUT / "BreakRackPhysicsTests-before.swift").write_bytes(before)
    source = HARNESS.read_text().replace(
        'private let configurationPath = "/Users/song/projects/13.billiard_trainer/build/break-potting-research-20261002/config.json"',
        'private let configurationPath = ' + json.dumps(str(OUT / "config.json")))
    block = BEGIN.encode() + source.encode() + b"\n" + END.encode()
    TARGET.write_bytes(before + b"\n" + block)
    try:
        with (OUT / "build.log").open("w") as log:
            code = subprocess.call(xcode_args("build-for-testing"), cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    finally:
        current = TARGET.read_bytes()
        if current.count(block) != 1:
            raise RuntimeError("Harness fence changed; refusing unsafe source restoration")
        restored = current.replace(b"\n" + block, b"", 1)
        TARGET.write_bytes(restored)
        write_json(OUT / "restoration.json", {
            "testSourceIdentical": restored == before,
            "productionUnchangedDuringBuild": hashes() == json.loads((OUT / "production-hashes-before.json").read_text()),
            "currentProductionHashes": hashes(),
        })
    print(f"build-for-testing exit={code}; temporary harness restored", flush=True)
    if code == 0:
        binary = next((DERIVED / "Build/Products/Debug-iphonesimulator").glob("*.app/PlugIns/QiuJiTests.xctest/QiuJiTests"))
        (OUT / "compiled-harness.swift").write_text(source)
        write_json(OUT / "compiled-evidence.json", {
            "harnessSHA256": hashlib.sha256(source.encode()).hexdigest(),
            "testBinary": str(binary), "testBinarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            "optimization": "-O", "simulator": DEVICE, "sourceHashes": hashes()})
    return code


def run(batch: str, method: str, jobs: list[dict]) -> int:
    compiled = json.loads((OUT / "compiled-evidence.json").read_text())
    if hashes() != compiled["sourceHashes"]:
        raise RuntimeError("Production physics sources changed after compilation; freeze a new study version")
    if hashlib.sha256(Path(compiled["testBinary"]).read_bytes()).hexdigest() != compiled["testBinarySHA256"]:
        raise RuntimeError("Compiled test binary changed; do not mix versions within a batch")
    config = dict(protocolVersion=1, batch=batch, jobs=jobs)
    write_json(OUT / "config.json", config)
    write_json(OUT / f"{batch}-config.json", config)
    log_path = OUT / f"{batch}.log"
    if log_path.exists():
        raise RuntimeError(f"Refusing to overwrite evidence: {log_path}")
    args = xcode_args("test-without-building")
    args[-1:-1] = ["-only-testing:QiuJiTests/BreakPottingResearchTests/" + method,
                   "-test-timeouts-enabled", "YES", "-maximum-test-execution-time-allowance", "1800",
                   "-resultBundlePath", str(OUT / f"{batch}.xcresult")]
    write_json(OUT / f"{batch}-command.json", args)
    print(f"{batch}: {len(jobs)} requested jobs; log={log_path}", flush=True)
    with log_path.open("w") as log:
        code = subprocess.call(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    rows = parse_log(log_path)
    write_json(OUT / f"{batch}-results.json", rows)
    text = log_path.read_text(errors="replace")
    complete = any(r.get("kind") == "batchComplete" and r["requested"] == len(jobs) for r in rows)
    count = len([r for r in rows if "id" in r and "kind" not in r])
    manifest = {"exitCode": code, "rows": count, "requested": len(jobs), "batchComplete": complete,
                "testExecuted": bool(re.search(r"Executed [1-9]\d* test", text)),
                "compiledHarnessSHA256": compiled["harnessSHA256"], "testBinarySHA256": compiled["testBinarySHA256"],
                "productionUnchanged": hashes() == json.loads((OUT / "production-hashes-before.json").read_text())}
    write_json(OUT / f"{batch}-execution.json", manifest)
    print(json.dumps(manifest), flush=True)
    if code == 0 and not manifest["testExecuted"]:
        raise RuntimeError("Zero tests executed")
    if method == "test_runConfiguredBatch" and (not complete or count != len(jobs)):
        raise RuntimeError("Incomplete results; retain original log and diagnose")
    return code


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("phase", choices=["prepare", "build", "preflight", "pair-audit", "gap-audit", "geometry", "custom", "parse"])
    p.add_argument("--batch")
    p.add_argument("--config", type=Path)
    args = p.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.phase == "prepare":
        write_json(OUT / "config.json", dict(protocolVersion=1, jobs=geometry()))
        print(f"Prepared {len(geometry())} geometric jobs")
        return 0
    if args.phase == "build":
        return build()
    if args.phase == "parse":
        batch = args.batch or "geometry"
        write_json(OUT / f"{batch}-results.json", parse_log(OUT / f"{batch}.log"))
        return 0
    if args.phase == "preflight":
        return run(args.batch or "preflight", "test_preflightGeometryStateAndProductionParity", geometry())
    if args.phase == "pair-audit":
        return run(args.batch or "pair-audit", "test_pairContactSymmetryAudit", [])
    if args.phase == "gap-audit":
        return run(args.batch or "gap-audit", "test_rackGapTriggerAudit", [])
    jobs = geometry() if args.phase == "geometry" else json.loads(args.config.read_text())["jobs"]
    return run(args.batch or args.phase, "test_runConfiguredBatch", jobs)


if __name__ == "__main__":
    sys.exit(main())
