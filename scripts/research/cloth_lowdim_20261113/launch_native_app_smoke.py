#!/usr/bin/env python3
"""Historical xctrace-launch experiment, retired after the system open -a path worked.

Kept as source evidence only. Its original r3 helper pin is not updated to pretend
compatibility with later attach-launcher revisions; this script cannot execute.
"""
from __future__ import annotations
import argparse, json, os, signal, subprocess, sys, time, uuid
from pathlib import Path
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
import run_direct_trace as direct

SCRIPT = Path(__file__).resolve()
WRAPPER = direct.ROOT / "output/local-test-runs/599cb6efc8f14aca9cc9f04092ad44a7/work/build/DerivedData/Build/Products/Debug-iphoneos/.XCInstall/%E7%90%83%E8%BF%B9.app"
EXPECTED_SHA = "72292637d98539c85696f70e3563f2409e996c8e18fb5677a9db759e83d8a0ec"
HELPER_SHA = "0de2675da609167c80a26e51d939f3395032f1ecd637b5e5c87610b3ce1b5142"
ARGUMENTS = ["-daily3D.diagnostics", "-3dDrag.probe", "-renderProfileProbe", "-dailyLayout.probe"]


def matched_apps():
    matches = []
    for line in subprocess.check_output(["/bin/ps", "-ww", "-axo", "pid=,comm="], text=True).splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2 or not parts[1].endswith("/Wrapper/球迹.app/球迹"):
            continue
        try:
            identity = direct.process_identity(int(parts[0]), EXPECTED_SHA)
        except (OSError, ValueError, subprocess.SubprocessError):
            continue  # exited, unrelated build, or unverified process: never record as our App
        matches.append(identity)
    return matches


def record_command(work, evidence, notification, arguments):
    return ["xcrun", "xctrace", "record", "--template", "Time Profiler", "--instrument", "Activity Monitor",
            "--instrument", "os_signpost", "--recording-options", str(evidence / "recording-options.json"),
            "--time-limit", "5s", "--window", "10s", "--notify-tracing-started", notification,
            "--target-stdout", str(work / "app-stdout.log"), "--output", str(work / "capture.trace"),
            "--launch", "--", str(WRAPPER), *arguments]


def execute(args, arguments):
    work, evidence = args.work.resolve(), args.evidence.resolve()
    direct.require(str(work) == os.environ.get("QIUJI_TEST_WORK") and str(evidence) == os.environ.get("QIUJI_TEST_EVIDENCE")
                   and work.parent.name == os.environ.get("QIUJI_TEST_RUN_ID"), "Managed lifecycle child required")
    direct.require(work.parent == evidence.parent and work.parent.parent == direct.DEFAULT_ROOT
                   and json.loads((work.parent / "run.json").read_text()).get("hold")
                   and not os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "Explicit held native workspace required")
    os.umask(0o077)
    for path in (work.parent, work, evidence): os.chmod(path, 0o700)
    for path in evidence.iterdir():
        if path.is_file() and not path.is_symlink(): os.chmod(path, 0o600)
    temporary = work / "tmpdir"; temporary.mkdir(mode=0o700)
    summary = {"status": "failed", "performanceAccepted": False, "traceSealed": False, "appKilledByScript": False,
               "actualProcessScopeVerified": False, "TMPDIRPropagationToXPCHelpersVerified": False,
               "minimumFreeBytes": direct.MIN_FREE_BYTES, "freePolicyScope": "light CPU recipe; actual peak unknown"}
    recorder = notification = None
    resources, matched, errors, handlers = [], {}, [], {}
    def observe(label):
        sample = {"phase": label, **direct.disk_snapshot(work, temporary)}; resources.append(sample)
        direct.write(evidence / "resource-samples.json", resources); return sample
    def interrupt(signum, frame): raise KeyboardInterrupt("Signal " + str(signum))
    try:
        for signum in (signal.SIGINT, signal.SIGTERM): handlers[signum] = signal.signal(signum, interrupt)
        direct.require(observe("before-record")["availableBytes"] >= direct.MIN_FREE_BYTES, "At least 8 GiB free required")
        direct.require(not matched_apps(), "Fixed r9 App is already running; refuse reuse or termination")
        for source in (SCRIPT, Path(direct.__file__)): (evidence / source.name).write_bytes(source.read_bytes())
        direct.write(evidence / "launch-arguments.json", arguments)
        direct.write(evidence / "recording-options.json", direct.RECORDING_OPTIONS)
        direct.write(evidence / "source.json", {"launcherSHA256": direct.sha(SCRIPT), "helperSHA256": HELPER_SHA,
                     "wrapper": str(WRAPPER), "innerSHA256": EXPECTED_SHA, "environmentWhitelist": sorted(direct.ENVIRONMENT_KEYS)})
        notification = direct.DarwinStartNotification("com.qiuji.research.launch." + uuid.uuid4().hex)
        command = record_command(work, evidence, notification.name, arguments)
        direct.write(evidence / "record-command.json", command)
        with (work / "record-stdout-stderr.log").open("wb") as log:
            recorder = subprocess.Popen(command, cwd=work, stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True, env=direct.tool_environment(temporary))
            spawned = last_progress = time.monotonic(); deadline = spawned + 605; next_check = spawned
            summary["recorderPID"] = recorder.pid
            direct.write(evidence / "recorder-process.json", {"pid": recorder.pid, "spawnWall": time.time(), "spawnMonotonic": spawned})
            while True:
                now = time.monotonic()
                if notification.poll() and not summary.get("startNotificationReceived"):
                    summary.update(startNotificationReceived=True, startWall=time.time(), startMonotonic=now)
                    deadline = now + 605
                    print("NATIVE_LAUNCH_RECORDING_STARTED " + json.dumps(summary), flush=True)
                if now >= next_check:
                    for identity in matched_apps():
                        direct.require(all(flag in identity["args"].split() for flag in arguments), "Matched App argv missing diagnostics")
                        matched[str(identity["pid"])] = identity
                    direct.write(evidence / "matched-apps.json", list(matched.values())); next_check = now + 1
                if recorder.poll() is not None: break
                if now - last_progress >= 15:
                    print("NATIVE_LAUNCH_PROGRESS " + json.dumps(observe("capture-or-sealing")), flush=True); last_progress = now
                direct.require(now < deadline, "Recorder exceeded capture plus 600 s seal allowance; mutable work retained")
                time.sleep(0.2)
        summary["recorderExitCode"] = recorder.wait()
        direct.require(summary["recorderExitCode"] == 0 and summary.get("startNotificationReceived") and matched,
                       "Require original successful exit, actual start notification and verified launched App")
        summary["appProcessesAfterRecorderExit"] = matched_apps()
        direct.stable_trace(work / "capture.trace", evidence / "trace-stability.json")
        result = direct.export(["xcrun", "xctrace", "export", "--input", str(work / "capture.trace"), "--toc",
                                "--output", str(evidence / "trace-toc.xml")], evidence, "toc", temporary)
        direct.require(result.get("exitCode") == 0 and ET.parse(evidence / "trace-toc.xml").getroot().findall("./run"), "TOC required")
        summary["status"] = "launch_smoke_acquired_held_pending_analysis"
    except BaseException as error: errors.append(repr(error))
    finally:
        if notification is not None:
            try: notification.cancel()
            except (OSError, ValueError) as error: errors.append("notify-cancel: " + repr(error))
        if recorder is not None:
            summary.update(recorderStillRunning=recorder.poll() is None, recorderExitCode=recorder.poll())
        summary.update(errors=errors, mutableTracePath=str(work / "capture.trace"), workRequiresHold=True)
        try: observe("finally")
        except OSError as error: errors.append("resource-observation: " + repr(error))
        if errors: summary["status"] = "failed_held_mutable_work"
        for signum, handler in handlers.items(): signal.signal(signum, handler)
        direct.write(evidence / "summary.json", summary)
        print("NATIVE_LAUNCH_SUMMARY " + json.dumps(summary), flush=True)
    return 1 if errors else 0


def main():
    raise SystemExit("Retired historical launcher: use the verified system open -a path, then run_direct_trace.py attach")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--launch-arguments-json", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--work", type=Path); parser.add_argument("--evidence", type=Path)
    args = parser.parse_args(); arguments = json.loads(args.launch_arguments_json.read_text())
    direct.require(arguments == ARGUMENTS, "Only the explicit four diagnostic flags are allowed; no fixture/reset/premium")
    direct.require(direct.sha(Path(direct.__file__)) == HELPER_SHA, "Frozen r3 helper drift")
    direct.require(direct.sha(WRAPPER / "Wrapper/球迹.app/球迹") == EXPECTED_SHA, "Fixed r9 executable SHA mismatch")
    if not args.execute:
        print(json.dumps({"executionStarted": False, "recordArgv": record_command(Path("{work}"), Path("{evidence}"), "PLAN", arguments),
                          "requiresLifecycleHold": True, "appSurvivalAfterRecordNotGuaranteed": True}, ensure_ascii=False, indent=2)); return 0
    direct.require(args.work and args.evidence, "Execute only as local_test_lifecycle child with explicit hold")
    return execute(args, arguments)


if __name__ == "__main__": sys.exit(main())
