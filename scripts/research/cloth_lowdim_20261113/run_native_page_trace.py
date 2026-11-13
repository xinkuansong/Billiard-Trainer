#!/usr/bin/env python3
"""Plan, or explicitly execute, one native Mac page trace using a held build.

Default is read-only. --execute creates a fresh local_test_lifecycle work/evidence
owner; its child borrows only the specified successful held native build. The
upstream state.lock stays held while using source/DerivedData, so the existing
lifecycle manager cannot reclaim those products. This does not own/delete them.
No simulator, phone, remote host, build action or production input is modified.
Acquisition success is not trace-schema acceptance or a performance conclusion.
"""
from __future__ import annotations

import argparse
from contextlib import ExitStack
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from local_test_lifecycle import DEFAULT_ROOT, identity, locked, record
from mac_mini_queue import digest, test_summary, tree_files, verify

SCRIPT = Path(__file__).resolve()
DESTINATION = "platform=macOS,arch=arm64,variant=Designed for iPad,id=00006050-0015294102F9401C"
SELECTORS = {
    "reference": "QiuJiUITests/ClothSupportPageResearchUITests/testNativeMacReferenceFullPageTrace",
    "guard": "QiuJiUITests/ClothSupportPageResearchUITests/testNativeMacGuardedFullPageTrace",
}
MARKER = "CLOTH_NATIVE_PAGE_MARKER "


def need(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def checked_run(path):
    path = Path(os.path.abspath(path))
    need(path.resolve() == path and path.parent == DEFAULT_ROOT and re.fullmatch(r"[0-9a-f]{32}", path.name),
         "Upstream must be an exact nonsymlink local_test_lifecycle run directory")
    return path


def ui_target(plist):
    candidates = []
    for configuration in plist.get("TestConfigurations", []):
        candidates += configuration.get("TestTargets", [])
    candidates += [value for value in plist.values() if isinstance(value, dict) and value.get("BlueprintName")]
    matches = [item for item in candidates if item.get("BlueprintName") == "QiuJiUITests"
               and item.get("IsUITestBundle") is True]
    need(len(matches) == 1, "xctestrun must already contain exactly one enabled QiuJiUITests target; do not rewrite the scheme")
    need(matches[0].get("IsEnabled", True), "UI target is disabled")
    need(not matches[0].get("OnlyTestIdentifiers") and not matches[0].get("SkipTestIdentifiers"),
         "Existing UI target has a selector restriction; do not rewrite it")
    return matches[0]


def product_path(value, products, host=None):
    need(isinstance(value, str), "Missing xctestrun product path")
    value = value.replace("__TESTROOT__", str(products))
    if host is not None:
        value = value.replace("__TESTHOST__", str(host))
    path = Path(value)
    need("__" not in value and path.is_absolute() and path.resolve() == path
         and path.is_relative_to(products) and path.exists(), "Product path escapes the held build: " + value)
    return path


def executable(bundle, expected_identifier=None):
    info = plistlib.loads((bundle / "Info.plist").read_bytes())
    if expected_identifier:
        need(info.get("CFBundleIdentifier") == expected_identifier, "Unexpected App bundle identity")
    name = info.get("CFBundleExecutable")
    need(isinstance(name, str) and Path(name).name == name, "Invalid bundle executable")
    path = bundle / name
    need(path.is_file() and path.resolve() == path, "Missing or symlinked executable")
    return path


def upstream_info(run):
    """Caller owns the existing upstream state.lock. Reads sealed evidence as bytes only."""
    state = record(run)
    need(state.get("state") == "complete" and state.get("exit_code") == 0 and bool(state.get("hold")),
         "Upstream must be complete, exit 0, and explicitly held; running/failed is not reusable")
    work, evidence = run / "work", run / "evidence"
    need(work.is_dir() and identity(work) == state["work_identity"], "Upstream work identity changed")
    sealed = state.get("evidence_sha256", {})
    need(bool(sealed), "Missing upstream evidence seal")
    actual = tree_files(evidence)
    need(set(actual) == set(sealed) and all(actual[p]["sha256"] == sha for p, sha in sealed.items()),
         "Upstream evidence differs from its seal; never open sealed xcresult with tools")
    result, after, launch = [read(evidence / p) for p in ("result.json", "hash-after.json", "launcher.json")]
    manifest = read(evidence / "snapshot-manifest.json")
    need(result.get("status") == "succeeded" and result.get("snapshotID") == manifest["snapshot_id"],
         "Upstream native launcher did not succeed with this snapshot")
    need(after.get("snapshotVerified") and after.get("cloneVerified") and not after.get("changedOrMissing")
         and not after.get("added"), "Upstream source integrity was not verified")
    need(launch.get("destination") == DESTINATION, "Upstream is not the authorized native Mac destination")
    source, derived = work / "source", work / "build/DerivedData"
    need(source.resolve() == source and derived.resolve() == derived and tree_files(source) == manifest["files"],
         "Held source no longer matches the frozen manifest")
    ui_source = (source / "QiuJiUITests/ClothSupportPageResearchUITests.swift").read_text()
    need(all("func " + selector.rsplit("/", 1)[1] + "()" in ui_source for selector in SELECTORS.values()),
         "Frozen source does not contain both explicit native UI selectors")
    command = state["command"]
    need(command.count("--snapshot") == 1, "Cannot identify the original frozen snapshot")
    snapshot = Path(command[command.index("--snapshot") + 1])
    need(verify(snapshot)["snapshot_id"] == manifest["snapshot_id"], "Frozen snapshot identity changed")
    products = derived / "Build/Products"
    runs = list(products.glob("*.xctestrun"))
    need(len(runs) == 1, "Require one unambiguous existing xctestrun; do not rebuild missing UI products")
    target = ui_target(plistlib.loads(runs[0].read_bytes()))
    app = product_path(target.get("UITargetAppPath"), products)
    runner = product_path(target.get("TestHostPath"), products)
    test_bundle = product_path(target.get("TestBundlePath"), products, runner)
    app_exe = executable(app, "com.xinkuan.qiuji")
    runner_exe = executable(runner)
    need(test_bundle.suffix == ".xctest", "Missing prebuilt UI XCTest bundle")
    built = {"app": tree_files(app), "runner": tree_files(runner), "xctestrun": digest(runs[0])}
    return {"upstreamRun": str(run), "upstreamState": state["state"], "upstreamHold": state["hold"],
        "upstreamRunJSONSHA256": digest(run / "run.json"), "snapshot": str(snapshot),
        "snapshotID": manifest["snapshot_id"], "source": str(source), "derivedData": str(derived),
        "products": str(products), "xctestrun": str(runs[0]), "appBundle": str(app),
        "appExecutable": str(app_exe), "appExecutableSHA256": digest(app_exe),
        "runnerBundle": str(runner), "runnerExecutable": str(runner_exe),
        "runnerExecutableSHA256": digest(runner_exe), "uiTestBundle": str(test_bundle),
        "originalInputCount": len(manifest["files"]), "builtProducts": built}


def make_command(info, evidence, selector):
    source, derived = Path(info["source"]), Path(info["derivedData"])
    return ["make", "-f", str(source / "scripts/Makefile"), "test",
        "TEST_ACTION=test-without-building", "TEST_CONFIGURATION=Debug",
        "BUILD_DIR=" + str(derived.parent), "DERIVED_DATA=" + str(derived),
        "TEST_LOG=" + str(evidence / "tests.log"), "TEST_JUNIT=" + str(evidence / "tests.xml"),
        "TEST_RESULT_BUNDLE=" + str(evidence / "tests.xcresult"),
        "TEST_DESTINATION=" + DESTINATION, "TEST_CODE_COVERAGE=NO",
        "TEST_SELECTOR=-only-testing:" + selector,
        "TEST_BUILD_SETTINGS=ARCHS=arm64 SWIFT_OPTIMIZATION_LEVEL=-O -jobs 4 -maximum-test-execution-time-allowance 360",
        "SIM_TEST_GUARD="]


def recorder_command(evidence, pid, smoke, arm, run_id):
    name = "schema-smoke" if smoke else arm
    return ["xcrun", "xctrace", "record", "--template", "Game Performance", "--attach", str(pid),
        "--time-limit", "12s" if smoke else "240s", "--window", "20s" if smoke else "300s",
        "--run-name", "native-page-" + name + "-" + run_id,
        "--notify-tracing-started", "com.qiuji.research.native-page." + run_id,
        "--output", str(evidence / "page.trace")]


def expected_markers():
    result = [("READY", "begin"), ("READY", "end")]
    for stage in ("2D-idle", "enter-3D", "aim-wheel", "shotCamera.firstPerson", "shotCamera.thirdPerson",
                  "dailyClearance.observeTable", "temporary-top-down", "restore-3D", "real-shot"):
        result += [(stage, boundary) for boundary in ("action.begin", "action.end", "observe.begin", "observe.end")]
    result += [("shot-completion", "begin"), ("shot-completion", "end")]
    result += [("post-shot-idle", boundary) for boundary in ("action.begin", "action.end", "observe.begin", "observe.end")]
    return result + [("exit-page", "begin"), ("exit-page", "end"), ("COMPLETE", "end")]


def validate_marker(marker, markers, arm):
    sequence = len(markers)
    need(sequence < len(expected_markers()) and marker.get("sequence") == sequence,
         "Missing, duplicate or extra marker sequence")
    need((marker.get("stage"), marker.get("boundary")) == expected_markers()[sequence], "Unexpected stage order")
    need(marker.get("recipe") == ("guarded" if arm == "guard" else "reference")
         and marker.get("runnerIsiOSAppOnMac") is True, "Wrong recipe or non-native runner")
    uuid.UUID(marker["runID"])
    for key in ("appPID", "runnerPID"):
        need(type(marker.get(key)) is int and marker[key] > 0, "Invalid process identity")
    need(marker["appPID"] != marker["runnerPID"], "Runner PID is not App PID")
    need(float(marker["wallUnixSeconds"]) > 0 and int(marker["runnerUptimeNanoseconds"]) > 0, "Invalid marker clock")
    if markers:
        need(all(marker[k] == markers[0][k] for k in ("runID", "appPID", "runnerPID", "recipe")),
             "App/runner/recipe restarted or changed during this trace")
        need(int(marker["runnerUptimeNanoseconds"]) >= int(markers[-1]["runnerUptimeNanoseconds"]),
             "Runner monotonic clock moved backwards")


def process_identity(pid, expected, sha, started, observations=None, observation_path=None):
    comm = subprocess.check_output(["ps", "-p", str(pid), "-o", "comm="], text=True).strip()
    details = subprocess.check_output(["ps", "-p", str(pid), "-o", "pid=,ppid=,lstart="], text=True).strip()
    # Preserve the actual host observation before any assertion can reject it.
    if observations is not None:
        observations.append({"pid": pid, "comm": comm, "details": details,
            "expectedExecutable": expected, "observedAt": time.time()})
        write(observation_path, observations)
    parts = details.split(None, 2)
    need(len(parts) == 3 and int(parts[0]) == pid, "Host ps could not prove the marker process")
    launched = time.mktime(time.strptime(parts[2], "%a %b %d %H:%M:%S %Y"))
    need(launched >= started - 2, "Marker PID predates this test invocation")
    path = Path(comm)
    need(path.is_absolute() and path.resolve() == Path(expected).resolve() and digest(path) == sha,
         "Host executable is not the exact held build; retain observed path and do not guess")
    return {"pid": pid, "ppid": int(parts[1]), "lstart": parts[2], "comm": comm,
        "resolvedExecutable": str(path.resolve()), "sha256": sha, "observedAt": time.time()}


def plan(args):
    run = checked_run(args.upstream_run)
    result = {"schema": 1, "executionStarted": False, "upstreamRun": str(run),
        "arm": args.arm, "selector": SELECTORS[args.arm], "schemaSmoke": args.schema_smoke,
        "destination": DESTINATION, "blockers": [], "launcherSHA256": digest(SCRIPT),
        "lifecycleBoundary": "Fresh child work/evidence only. Existing successful held source/DerivedData remain upstream-owned; state.lock prevents reclamation during reuse. No build/cleanup/simulator lease.",
        "trigger": ["enter-3D", "action.begin"] if args.schema_smoke else ["READY", "begin"],
        "requiredMarkers": expected_markers(),
        "traceStartBoundary": "A marker triggers attach, but does not prove recording began. Preserve xctrace stdout/stderr and notified channel; verify actual start, process and coverage inside sealed trace before analysis."}
    try:
        with locked(run):
            info = upstream_info(run)
        result["upstream"] = {k: v for k, v in info.items() if k != "builtProducts"}
        result["testArgv"] = make_command(info, Path("{evidence}"), SELECTORS[args.arm])
        result["recordArgvTemplate"] = recorder_command(Path("{evidence}"), "ACTUAL_APP_PID_FROM_THIS_TEST",
            args.schema_smoke, args.arm, "THIS_LIFECYCLE_RUN_ID")
    except (OSError, ValueError, KeyError) as error:
        result["blockers"].append(str(error))
    return result


def execute_child(args):
    work, evidence = args.work.resolve(), args.evidence.resolve()
    need(str(work) == os.environ.get("QIUJI_TEST_WORK") and str(evidence) == os.environ.get("QIUJI_TEST_EVIDENCE")
         and bool(os.environ.get("QIUJI_TEST_RUN_ID")), "Use the existing local_test_lifecycle owner")
    need(work.parent == evidence.parent and not work.is_symlink() and not evidence.is_symlink(), "Invalid child boundary")
    need(not os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "Native trace must not borrow any simulator")
    upstream = checked_run(args.upstream_run)
    need(work.parent != upstream and not upstream.is_relative_to(work), "Child cannot own or reclaim upstream products")
    result = {"status": "failed", "arm": args.arm, "schemaSmoke": args.schema_smoke,
        "performanceConclusion": "none; acquisition only", "traceStartVerifiedInsideTrace": False}
    errors, markers, identities, recorder_events, process_observations = [], [], [], [], []
    recorder = None
    complete = False
    recorder_ended_early = False
    with locked(upstream), ExitStack() as stack:
        def interrupted(signum, frame):
            raise KeyboardInterrupt("Native page launcher received signal " + str(signum))
        for signum in (signal.SIGINT, signal.SIGTERM):
            previous = signal.signal(signum, interrupted)
            stack.callback(signal.signal, signum, previous)
        info = upstream_info(upstream)
        write(evidence / "upstream.json", {k: v for k, v in info.items() if k != "builtProducts"})
        write(evidence / "upstream-built-products-before.json", info["builtProducts"])
        write(evidence / "launcher.json", {"source": str(SCRIPT), "sha256": digest(SCRIPT),
            "destination": DESTINATION, "selector": SELECTORS[args.arm], "upstream": str(upstream),
            "sourcePath": info["source"], "derivedDataPath": info["derivedData"],
            "childWork": str(work), "childEvidence": str(evidence), "snapshotID": info["snapshotID"]})
        (evidence / SCRIPT.name).write_bytes(SCRIPT.read_bytes())
        env = dict(os.environ, TEST_RUNNER_CLOTH_NATIVE_PAGE_RESEARCH="1", PYTHONDONTWRITEBYTECODE="1")
        for key in list(env):
            if key.startswith(("CLOTH_RESEARCH_", "TEST_RUNNER_CLOTH_RESEARCH_")):
                del env[key]
        # Do not let a caller's unprefixed value defeat the explicit runner opt-in.
        env["CLOTH_NATIVE_PAGE_RESEARCH"] = "1"
        test_argv = make_command(info, evidence, SELECTORS[args.arm])
        write(evidence / "tests-command.json", test_argv)
        started = time.time()
        tests = subprocess.Popen(test_argv, cwd=info["source"], env=env,
            stdout=stack.enter_context((evidence / "tests-driver.log").open("wb")), stderr=subprocess.STDOUT)
        write(evidence / "tests-process.json", {"pid": tests.pid, "startedAt": started})
        pending, offset = "", 0

        def stop_recorder(reason):
            if recorder is not None and recorder.poll() is None:
                recorder.send_signal(signal.SIGINT)  # only this owned Popen child, never the App
                recorder_events.append({"event": "SIGINT", "reason": reason, "pid": recorder.pid, "at": time.time()})

        def consume(line):
            nonlocal recorder, complete, recorder_ended_early
            if MARKER not in line:
                return
            try:
                marker = json.loads(line.split(MARKER, 1)[1])
                validate_marker(marker, markers, args.arm)
                markers.append(marker)
                write(evidence / "markers.json", markers)
                if len(markers) == 1:
                    # READY has a twenty-second window. Prove both native process paths here.
                    for role in ("app", "runner"):
                        pid = marker["appPID" if role == "app" else "runnerPID"]
                        identities.append({"role": role, **process_identity(pid, info[role + "Executable"],
                            info[role + "ExecutableSHA256"], started, process_observations,
                            evidence / "host-process-observations.json")})
                    write(evidence / "process-identities.json", identities)
                trigger = ("enter-3D", "action.begin") if args.schema_smoke else ("READY", "begin")
                if (marker["stage"], marker["boundary"]) == trigger and not errors:
                    need(recorder is None, "Recorder already started")
                    identities.append({"role": "app-at-attach", **process_identity(marker["appPID"],
                        info["appExecutable"], info["appExecutableSHA256"], started, process_observations,
                        evidence / "host-process-observations.json")})
                    write(evidence / "process-identities.json", identities)
                    command = recorder_command(evidence, marker["appPID"], args.schema_smoke, args.arm,
                                               os.environ["QIUJI_TEST_RUN_ID"])
                    write(evidence / "record-command.json", command)
                    recorder = subprocess.Popen(command, cwd=work, env=env,
                        stdout=stack.enter_context((evidence / "record-stdout-stderr.log").open("wb")),
                        stderr=subprocess.STDOUT, start_new_session=True)
                    recorder_events.append({"event": "spawned-not-start-confirmed", "pid": recorder.pid,
                        "at": time.time(), "triggerMarkerSequence": marker["sequence"],
                        "notificationChannel": command[command.index("--notify-tracing-started") + 1]})
                if marker["stage"] == "COMPLETE":
                    complete = True
                    if recorder is not None and recorder.poll() is not None:
                        recorder_ended_early = True
                    stop_recorder("COMPLETE marker")
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                errors.append("marker: " + repr(error))

        try:
            while True:
                log = evidence / "tests.log"
                if log.exists():
                    with log.open("r", errors="replace") as stream:
                        stream.seek(offset)
                        pending += stream.read()
                        offset = stream.tell()
                    lines = pending.split("\n")
                    pending = lines.pop()
                    for line in lines:
                        consume(line)
                if tests.poll() is not None:
                    if pending.strip():
                        consume(pending)
                    break
                time.sleep(0.2)
            result["testDriverExitCode"] = tests.returncode
            if tests.returncode != 0:
                errors.append("Native test driver exited " + str(tests.returncode))
        finally:
            stop_recorder("test driver ended; seal owned recorder")
            if recorder is not None:
                try:
                    result["recorderExitCode"] = recorder.wait(timeout=90)
                except subprocess.TimeoutExpired:
                    # Do not force-kill a recorder mid-seal or touch the App.
                    errors.append("Recorder did not seal within 90 seconds; process retained for explicit recovery")
                    result["retainedRecorderPID"] = recorder.pid
                recorder_events.append({"event": "wait-finished", "exitCode": recorder.poll(), "at": time.time()})
            write(evidence / "recorder-events.json", recorder_events)
            record_log = evidence / "record-stdout-stderr.log"
            write(evidence / "record-start-state.json", {
                "spawned": recorder is not None, "notificationObserved": False,
                "traceInternalStartVerified": False,
                "stdoutStartRelatedLines": [line for line in record_log.read_text(errors="replace").splitlines()
                    if "start" in line.lower() or "recording" in line.lower()] if record_log.exists() else [],
                "boundary": "Raw recorder output is retained; spawn/marker timestamps do not prove trace coverage."})

        try:
            summary = test_summary(evidence, [SELECTORS[args.arm]])
            need(summary.get("totalTestCount") == 1 and summary.get("passedTests") == 1, "Exactly one Passed UI selector is required")
            result["testResult"] = "Passed"
        except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
            errors.append("test-summary: " + repr(error))
        try:
            command = ["xcrun", "xcresulttool", "export", "attachments", "--path", str(evidence / "tests.xcresult"),
                       "--output-path", str(evidence / "attachments")]
            write(evidence / "attachment-command.json", command)
            with (evidence / "attachment-export.log").open("wb") as output:
                subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as error:
            errors.append("attachments: " + repr(error))
        if not complete or len(markers) != len(expected_markers()):
            errors.append("Incomplete native stage markers")
        if recorder_ended_early and not args.schema_smoke:
            errors.append("Formal recorder ended before COMPLETE; full-page coverage incomplete")
        if recorder is None or result.get("recorderExitCode") != 0:
            errors.append("Recorder did not complete successfully")
        else:
            try:
                trace = evidence / "page.trace"
                need(trace.is_dir(), "Recorder produced no trace bundle")
                command = ["xcrun", "xctrace", "export", "--input", str(trace), "--toc", "--output", str(evidence / "trace-toc.xml")]
                write(evidence / "trace-toc-command.json", command)
                with (evidence / "trace-toc-export.log").open("wb") as output:
                    subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=60)
                toc = ET.parse(evidence / "trace-toc.xml")
                need(bool(toc.findall(".//run")), "Trace TOC contains no recording run")
                hashes = tree_files(trace)
                need(bool(hashes), "Trace bundle is empty")
                write(evidence / "trace-receipt.json", {"files": hashes, "recorderExited": True,
                    "tocExportedBeforeSeal": True, "schemaAndProcessCoverageVerified": False})
                need(tree_files(trace) == hashes, "Trace changed while sealing")
                result["traceSealed"] = True
            except (ValueError, OSError, ET.ParseError, subprocess.SubprocessError) as error:
                errors.append("trace-seal: " + repr(error))
        try:
            after = upstream_info(upstream)
            need(after["builtProducts"] == info["builtProducts"], "Held App/runner/xctestrun changed during test-without-building")
            write(evidence / "upstream-integrity-after.json", {"sourceAndSealedEvidenceVerified": True,
                "appRunnerAndXctestrunUnchanged": True, "upstreamRunJSONSHA256": after["upstreamRunJSONSHA256"]})
        except (ValueError, OSError, KeyError) as error:
            errors.append("upstream-integrity: " + repr(error))
        result.update(status="succeeded" if not errors else "failed", errors=errors, markers=len(markers),
            fullMarkerSequenceComplete=complete, snapshotID=info["snapshotID"],
            traceCoverageScope="schema smoke only" if args.schema_smoke else "full single-arm acquisition; trace-internal coverage still requires analysis")
        write(evidence / "result.json", result)
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return 0 if result["status"] == "succeeded" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream-run", type=Path, required=True)
    parser.add_argument("--arm", choices=SELECTORS, required=True)
    parser.add_argument("--schema-smoke", action="store_true")
    parser.add_argument("--plan-out", type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--work", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--evidence", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.work or args.evidence:
        need(args.execute and args.work and args.evidence, "Internal child requires explicit execution and both managed paths")
        return execute_child(args)
    prepared = plan(args)
    if args.plan_out:
        args.plan_out.parent.mkdir(parents=True, exist_ok=True)
        write(args.plan_out, prepared)
    print(json.dumps(prepared, ensure_ascii=False, indent=2), flush=True)
    if prepared["blockers"]:
        return 2
    if not args.execute:
        return 0
    need(not os.environ.get("QIUJI_TEST_WORK") and not os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "Refusing nested lifecycle/lease")
    child = [sys.executable, str(SCRIPT), "--upstream-run", str(checked_run(args.upstream_run)),
        "--arm", args.arm, "--execute", "--work", "{work}", "--evidence", "{evidence}"]
    if args.schema_smoke:
        child.append("--schema-smoke")
    task = "cloth-native-page-" + args.arm + ("-schema-smoke" if args.schema_smoke else "-trace")
    return subprocess.call([sys.executable, str(ROOT / "scripts/local_test_lifecycle.py"),
        "run", "--task", task, "--", *child])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
