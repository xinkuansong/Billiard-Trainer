#!/usr/bin/env python3
"""Explicit Metal System Trace recipe over the frozen r4 attach lifecycle.

Default is a read-only plan. This wrapper makes exact, checked substitutions in
the pinned r4 source in memory; it does not modify the CPU launcher. Each run
retains the wrapper, original basis, configured source and their hashes.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys
import types

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve()
BASIS = SCRIPT.with_name("run_direct_trace.py")
BASIS_SHA256 = "6949b8bc65ff46d2fe2a8eb16ffc65116b48bcff1f5ac69dca1335808013d244"
CORE = {"time-info", "metal-gpu-intervals", "metal-application-command-buffer-submissions", "os-signpost",
        "metal-command-buffer-frame-assignment", "metal-gpu-submission-to-command-buffer-id"}
REPLACEMENTS = [
    ('CORE = {"time-info", "metal-gpu-intervals", "metal-application-command-buffer-submissions",\n'
     '        "time-profile", "activity-monitor-process-live", "os-signpost"}',
     "CORE = {" + ", ".join(json.dumps(value) for value in sorted(CORE)) + "}"),
    ("Time Profiler, Activity Monitor and target-process os_signpost information;",
     "Metal System Trace and target-process os_signpost information;"),
    ('MIN_FREE_BYTES = 8 * 1024 ** 3  # entry policy for the light CPU recipe, not Game Performance',
     'MIN_FREE_BYTES = 20 * 1024 ** 3  # GPU capture entry policy; global XPC temporary peak remains unknown'),
    ('"--template", "Time Profiler", "--attach"', '"--template", "Metal System Trace", "--attach"'),
    ('"--instrument", "Activity Monitor", "--instrument", "os_signpost",', '"--instrument", "os_signpost",'),
    ('"--run-name", "native-direct-cpu-schema-smoke"', '"--run-name", "native-direct-gpu-schema-smoke"'),
    ('"template": "Time Profiler", "instruments": ["Activity Monitor", "os_signpost"],',
     '"template": "Metal System Trace", "instruments": ["os_signpost"], "templateIncludesCPUSampling": True,'),
    ('"light CPU recipe only; peak unverified"', '"Metal System Trace; 12 GiB global XPC buffer precedent; peak unknown"'),
    ('"Light CPU recording requires at least 8 GiB currently available on the work volume"',
     '"GPU recording requires at least 20 GiB currently available on the work volume"'),
    ('default="cloth-native-direct-schema-smoke"', 'default="cloth-native-gpu-schema-smoke"'),
    ('"light CPU recipe only; peak and XPC TMPDIR propagation unverified"',
     '"Metal System Trace; 12 GiB global XPC buffer precedent; private TMPDIR cannot constrain XPC"'),
    ('"gpuMetricsExpected": False', '"gpuMetricsExpected": True'),
]


def configured_source():
    raw = BASIS.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASIS_SHA256:
        raise ValueError("Frozen r4 CPU basis changed; do not silently inherit a new lifecycle")
    source = raw.decode()
    for before, after in REPLACEMENTS:
        if source.count(before) != 1:
            raise ValueError("Expected one exact GPU recipe substitution: " + before)
        source = source.replace(before, after, 1)
    return raw, source


def main():
    raw, source = configured_source()
    runtime = types.ModuleType("configured_gpu_trace")
    runtime.__file__ = str(SCRIPT)
    exec(compile(source, str(SCRIPT), "exec"), runtime.__dict__)
    provenance = {"basisPath": str(BASIS), "basisSHA256": BASIS_SHA256,
                  "configuredSourceSHA256": hashlib.sha256(source.encode()).hexdigest(),
                  "wrapperSHA256": hashlib.sha256(SCRIPT.read_bytes()).hexdigest(),
                  "exactSubstitutions": [{"before": a, "after": b} for a, b in REPLACEMENTS],
                  "coreTableSchemas": sorted(CORE), "templateIncludesCPUSampling": True,
                  "explicitAdditionalInstruments": ["os_signpost"], "globalCollectionPossible": True,
                  "privateTMPDIRCannotConstrainXPC": True, "knownGlobalTemporaryBufferPrecedentGiB": 12,
                  "requiredIndependentAcceptance": "nonempty target PID GPU rows; queue/CB identity and labels; aligned App signposts",
                  "presentTimingVerified": False, "performanceAccepted": False, "deriveFPSFromCommandSpan": False}
    original_write = runtime.write
    def write(path, value):
        if path.name in {"launcher.json", "summary.json", "schema-inventory.json"}:
            value = {**value, "gpuRecipe": provenance}
        if path.name == "launcher.json":
            (path.parent / "run_direct_trace.r4-basis.py").write_bytes(raw)
            (path.parent / "configured_gpu_runner.py").write_text(source)
        original_write(path, value)
    runtime.write = write
    # The same parent/managed-child entry remains, including actual start notices,
    # 600 s seal allowance, 15 s volume observations and private filtered environment.
    print("GPU_TRACE_RECIPE " + json.dumps(provenance, ensure_ascii=False), flush=True)
    return runtime.main()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print("ERROR: " + repr(error), file=sys.stderr)
        sys.exit(1)
