#!/usr/bin/env python3
"""Extract actual production generators for a bounded CPU-only construction study.

Default prepares source only. --execute compiles/runs after the coordinated
measurement window is available. No iOS build, renderer, GPU or source mutation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "QiuJi/Core/Scene/MobileReferenceLighting.swift"
HELPER = ROOT / "QiuJi/Core/Scene/DailyClothSupportExperiment.swift"
CONSTANTS = ROOT / "QiuJi/Core/Physics/BTPhysicsConstants.swift"
AUDITED = ROOT / "QiuJiTests/ClothResearchShaders.swift"
TAIL = Path(__file__).with_suffix(".swift")
SURFACE = ROOT / "output/render-lowdim-20261113/visual-r2/reference.surface"


def sha(data):
    return hashlib.sha256(data if isinstance(data, bytes) else data.encode()).hexdigest()


def between(source, start, end):
    assert source.count(start) == 1, start
    first = source.index(start)
    return source[first:source.index(end, first)]


def command(cmd, log):
    start = time.monotonic()
    result = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    log.write_text(result.stdout + result.stderr)
    assert result.returncode == 0, f"{cmd}: see {log}"
    return {"argv": cmd, "exitCode": result.returncode, "wallSeconds": time.monotonic() - start,
            "stdout": result.stdout, "stderr": result.stderr}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--cycles", type=int, default=9)
    parser.add_argument("--batch", type=int, default=8)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert not (out / "results.json").exists(), "Preserve completed evidence; choose a new --out"
    if (out / "manifest.json").exists():
        assert json.loads((out / "manifest.json").read_text())["status"] == "prepared-only", "Preserve failed evidence; choose a new --out"
    source = SOURCE.read_text()
    pieces = {
        "Panel_Rig": between(source, "    struct Panel {", "    /// Same gate"),
        "sampling": between(source, "    enum SamplingProfile {", "    enum SpecializedProfile:"),
        "profile": between(source, "    enum SpecializedProfile:", "    /// Shared baseline."),
        "profileSelection": between(source, "    static var specializedProfile:", "    static func filteredBallShader("),
        "balanceSelection": between(source, "    static var balanceTrialRequested:", "    static let trialTopGain"),
        "directShadowShader": between(source, "    static func directShadowShader(", "    /// S1:"),
        "directShadowProgram": between(source, "    static func directShadowProgram(", "    #endif"),
        "analytic": between(source, "    static let emitterGeometry: String = {", "    /// Cue varnish,"),
        "cloth": between(source, '    private static let clothShader = rig.shader("""', "\n}\n\n\n#if DEBUG"),
    }
    geometry = CONSTANTS.read_text()
    sizes = []
    for name in ("innerLength", "innerWidth"):
        lines = re.findall(r"^    static let " + name + r": Float = [0-9.]+$", geometry, re.M)
        assert len(lines) == 1, name
        sizes += lines
    helper = HELPER.read_text()
    audited = AUDITED.read_text()
    assert audited.count("@testable import QiuJi") == 1
    audited = audited.replace("@testable import QiuJi", "")
    # Leave directShadowShader verbatim. S/RS is unreachable because all measured
    # calls explicitly pass .reflection; a fatal stub fails if that domain leaks.
    stub = '    static func analyticDirectShadowShader(ballCount: Int) -> String { fatalError("CPU study is R only") }\n'
    generated = ("import Foundation\nimport SceneKit\nimport simd\nenum TablePhysics {\n"
                 + "\n".join(sizes) + "\n}\nenum MobileReferenceLighting {\n"
                 + "\n".join(pieces.values()) + "\n" + stub + "\n}\n" + helper + "\n" + audited + "\n" + TAIL.read_text())
    swift = out / "cpu-program.swift"
    swift.write_text(generated)
    copied = out / "reference.surface"
    copied.write_bytes(SURFACE.read_bytes())
    assert sha(copied.read_bytes()) == "9495698875cd01a4ecd8d00708ce88bf9989c6e118805620f99a11d03dcca390"
    paths = [SOURCE, HELPER, CONSTANTS, AUDITED, TAIL, Path(__file__), SURFACE]
    fingerprints = {str(path.relative_to(ROOT)): sha(path.read_bytes()) for path in paths}
    metadata = {
        "sourceSHA256": fingerprints,
        "pieceSHA256": {name: sha(piece) for name, piece in pieces.items()},
        "generatedSwiftSHA256": sha(generated),
        "sourceExtraction": "Verbatim production R generator, wrapper, helper, ProcessInfo gates and rig. Unreachable analytic S function is a fatal stub; R=reflection explicit on every call.",
        "optimization": "-O -D DEBUG -swift-version 5 (project.yml Debug uses -O and SWIFT_VERSION 5.9); native macOS harness, not iOS binary",
        "invocation": {"cycles": args.cycles, "batch": args.batch},
        "status": "prepared-only",
    }
    (out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
    if not args.execute:
        print(f"Prepared only; no compiler or benchmark started: {out}")
        return
    metadata["host"] = {"platform": platform.platform(), "machine": platform.machine(), "node": platform.node()}
    for name, cmd in [("swift", ["xcrun", "swiftc", "--version"]),
                      ("xcode", ["xcodebuild", "-version"]),
                      ("hardware", ["sysctl", "-n", "hw.model", "machdep.cpu.brand_string"]),
                      ("macos", ["sw_vers"])]:
        metadata[name] = command(cmd, out / f"{name}.log")
    binary = out / "cpu-program"
    metadata["compile"] = command(["xcrun", "swiftc", "-O", "-D", "DEBUG", "-swift-version", "5",
                                   str(swift), "-o", str(binary)], out / "compile.log")
    metadata["binarySHA256"] = sha(binary.read_bytes())
    metadata["run"] = command([str(binary), str(copied), "16", str(args.cycles), str(args.batch),
                               str(out / "results.json")], out / "run.log")
    assert fingerprints == {str(path.relative_to(ROOT)): sha(path.read_bytes()) for path in paths}, "Source changed during run"
    metadata["status"] = "completed"
    (out / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(metadata["run"]["stdout"].strip())
    print(out)


if __name__ == "__main__":
    main()
