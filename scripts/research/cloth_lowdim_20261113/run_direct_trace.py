#!/usr/bin/env python3
"""Explicit native Mac PID attachment, under the existing local test lifecycle.

Default only checks identity and prints a plan. --execute records 60 seconds of
Time Profiler, Activity Monitor and target-process os_signpost information;
it never launches, controls, or terminates the App. --export-core additionally
exports each observed core table separately after the recorder exits.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SCRIPT = Path(__file__).resolve()
sys.path.insert(0, str(ROOT / "scripts"))
from local_test_lifecycle import DEFAULT_ROOT
from mac_mini_queue import tree_files

CORE = {"time-info", "metal-gpu-intervals", "metal-application-command-buffer-submissions",
        "time-profile", "activity-monitor-process-live", "os-signpost"}

DEFAULT_DURATION_SECONDS = 60
SEAL_WAIT_SECONDS = 600
MIN_FREE_BYTES = 8 * 1024 ** 3  # entry policy for the light CPU recipe, not Game Performance
RECORDING_OPTIONS = {
    "Time Profiler": {"contextSwitchSampling": False, "highFrequencySampling": False,
                      "recordKernelStacks": False, "recordWaitingThreads": False},
    "os_signpost": {"recordAllProcessesInSingleProcessMode": False,
                    "dynamicTracingEnabledSubsystems": ["com.qiuji.daily3d"]},
}
ENVIRONMENT_KEYS = {"PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "DEVELOPER_DIR",
                    "LC_ALL", "LC_COLLATE", "LC_CTYPE", "LC_MESSAGES", "LC_MONETARY", "LC_NUMERIC", "LC_TIME"}


def tool_environment(temporary_directory=None):
    """Do not embed the agent's credential-bearing environment in Instruments."""
    environment = {key: value for key, value in os.environ.items() if key in ENVIRONMENT_KEYS}
    if temporary_directory is not None:
        directory = Path(temporary_directory)
        require(directory.is_absolute() and directory.resolve() == directory and directory.is_dir(),
                "Private TMPDIR must be an existing nonsymlink absolute directory")
        environment["TMPDIR"] = str(directory) + os.sep
    return environment


def disk_snapshot(work, temporary_directory):
    volume = os.statvfs(work)
    files, logical, allocated, skipped, symlinks = 0, 0, 0, 0, 0
    inodes = set()
    for parent, dirs, names in os.walk(temporary_directory, followlinks=False):
        for name in dirs + names:
            if (Path(parent) / name).is_symlink():
                symlinks += 1
        for name in names:
            path = Path(parent) / name
            if path.is_symlink():
                continue
            try:
                stat = path.stat()
            except FileNotFoundError:
                skipped += 1  # a temporary file disappeared during this observation
                continue
            files += 1
            logical += stat.st_size
            identity = (stat.st_dev, stat.st_ino)
            if identity not in inodes:
                allocated += stat.st_blocks * 512
                inodes.add(identity)
    return {"wallUnixSeconds": time.time(), "monotonicNanoseconds": time.monotonic_ns(),
            "availableBytes": volume.f_bavail * volume.f_frsize, "volumeDevice": work.stat().st_dev,
            "privateTMPDIR": str(temporary_directory), "temporaryFileCount": files,
            "temporaryLogicalBytes": logical, "temporaryAllocatedBytes": allocated,
            "temporarySymlinkCount": symlinks, "entriesDisappearedDuringSample": skipped,
            "scope": "private TMPDIR only; XPC helper use of this directory remains to be verified"}


class DarwinStartNotification:
    """Public notify.h FD delivery avoids register_check's documented false positives."""
    def __init__(self, name):
        self.name = name
        self.library = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
        register = self.library.notify_register_file_descriptor
        register.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_int), ctypes.c_int,
                             ctypes.POINTER(ctypes.c_int)]
        register.restype = ctypes.c_uint32
        self.library.notify_cancel.argtypes = [ctypes.c_int]
        self.library.notify_cancel.restype = ctypes.c_uint32
        fd, token = ctypes.c_int(-1), ctypes.c_int(-1)
        status = register(name.encode(), ctypes.byref(fd), 0, ctypes.byref(token))
        require(status == 0, "Darwin notification registration failed: " + str(status))
        self.fd, self.token, self.pending = fd.value, token.value, b""
        try:
            os.set_blocking(self.fd, False)
            require(not self.poll(), "Unexpected notification before recorder launch")
        except BaseException:
            self.cancel()
            raise

    def poll(self):
        try:
            data = os.read(self.fd, 4096)
        except BlockingIOError:
            return False
        require(bool(data), "Darwin notification descriptor closed unexpectedly")
        self.pending += data
        received = False
        while len(self.pending) >= 4:
            token = int.from_bytes(self.pending[:4], "big")
            self.pending = self.pending[4:]
            require(token == self.token, "Darwin notification token mismatch")
            received = True
        return received

    def cancel(self):
        if self.token is not None:
            status = self.library.notify_cancel(self.token)
            self.token = None
            require(status == 0, "Darwin notification cancellation failed: " + str(status))


def trace_snapshot(path):
    require(path.is_dir(), "Recorder produced no trace directory")
    rows = []
    for base, dirs, files in os.walk(path):
        for name in dirs + files:
            item = Path(base) / name
            require(not item.is_symlink(), "Unexpected trace symlink")
        for name in files:
            item = Path(base) / name
            stat = item.stat()
            rows.append((str(item.relative_to(path)), stat.st_size, stat.st_mtime_ns))
    require(bool(rows), "Trace directory has no files")
    rows.sort()
    return {"metadataSHA256": hashlib.sha256(json.dumps(rows).encode()).hexdigest(),
            "fileCount": len(rows), "bytes": sum(row[1] for row in rows)}


def stable_trace(path, report, interval=1.0, maximum_samples=10):
    samples, previous = [], None
    for _ in range(maximum_samples):
        current = trace_snapshot(path)
        samples.append({"wallUnixSeconds": time.time(), "monotonicNanoseconds": time.monotonic_ns(), **current})
        write(report, {"minimumIntervalSeconds": interval, "samples": samples,
                       "stable": current == previous, "requiresRecorderExitSeparately": True})
        if current == previous:
            return current
        previous = current
        time.sleep(interval)
    raise ValueError("Trace metadata did not stabilize after recorder exit")


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n")


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def process_identity(pid, expected, raw_path=None):
    rows = {}
    for key, columns in (("comm", "comm="), ("args", "args="), ("start", "pid=,ppid=,lstart=")):
        rows[key] = subprocess.check_output(["/bin/ps", "-ww", "-p", str(pid), "-o", columns],
                                           text=True, timeout=5).strip()
    if raw_path is not None:
        write(raw_path, {"pid": pid, "observedAt": time.time(), **rows})
    parts = rows["start"].split(None, 2)
    require(len(parts) == 3 and int(parts[0]) == pid, "Cannot establish PID/start identity")
    exe = Path(rows["comm"])
    require(exe.is_absolute() and exe.is_file(), "ps did not return a complete executable path")
    require("/CoreSimulator/" not in str(exe), "Native host task refuses a Simulator process")
    actual = sha(exe)
    require(actual == expected, "Actual process executable SHA differs from the explicitly expected binary")
    return {"pid": pid, "ppid": int(parts[1]), "lstart": parts[2], "comm": rows["comm"],
            "args": rows["args"], "resolvedExecutable": str(exe.resolve()), "sha256": actual}


def record_command(pid, target_directory, notification_name=None, options_path=None,
                   duration_seconds=DEFAULT_DURATION_SECONDS):
    require(duration_seconds in (20, 60), "Duration must be 20 or 60 seconds")
    return ["xcrun", "xctrace", "record", "--template", "Time Profiler", "--attach", str(pid),
            "--time-limit", str(duration_seconds) + "s", "--window", str(duration_seconds + 10) + "s",
            "--run-name", "native-direct-cpu-schema-smoke",
            "--instrument", "Activity Monitor", "--instrument", "os_signpost",
            "--recording-options", str(options_path or target_directory / "recording-options.json"),
            "--notify-tracing-started", notification_name or "com.qiuji.research.direct.PLAN",
            "--output", str(target_directory / "capture.trace")]


def export(command, evidence, label, temporary_directory=None):
    write(evidence / (label + "-command.json"), command)
    result = {"command": command, "timeoutSeconds": 60}
    with (evidence / (label + "-export.log")).open("wb") as log:
        try:
            completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=60,
                                       env=tool_environment(temporary_directory))
            result["exitCode"] = completed.returncode
        except subprocess.TimeoutExpired:
            result.update(exitCode=None, timedOut=True)
    write(evidence / (label + "-export-result.json"), result)
    return result


def export_tables(toc, evidence, enabled, temporary_directory=None):
    observed, results = [], []
    for run in toc.findall("./run"):
        number = run.get("number", "")
        require(number.isdigit(), "Unknown trace run identity; preserve TOC without guessing XPath")
        for index, table in enumerate(run.findall("./data/table"), 1):
            schema = table.get("schema", "")
            row = {"run": number, "tableIndex": index, "attributes": dict(table.attrib)}
            observed.append(row)
            if not enabled or schema not in CORE:
                continue
            name = "run-" + number + "-table-" + str(index) + "-" + schema
            output = evidence / (name + ".xml")
            xpath = '/trace-toc/run[@number="' + number + '"]/data/table[' + str(index) + ']'
            command = ["xcrun", "xctrace", "export", "--input", str(evidence / "capture.trace"),
                       "--xpath", xpath, "--output", str(output)]
            result = {**row, **export(command, evidence, name, temporary_directory)}
            if result.get("exitCode") == 0:
                try:
                    count = 0
                    for _, element in ET.iterparse(output, events=("end",)):
                        if element.tag == "row":
                            count += 1
                        element.clear()
                    result.update(xmlValid=True, rows=count, nonempty=count > 0)
                except (OSError, ET.ParseError) as error:
                    result.update(xmlValid=False, error=repr(error))
            results.append(result)
            write(evidence / "table-export-results.json", results)
    schemas = {item["attributes"].get("schema") for item in observed}
    return {"observedTables": observed, "requestedSchemasAbsent": sorted(CORE - schemas),
            "unknownSchemasPreservedInTOC": sorted(s for s in schemas if s and s not in CORE),
            "exportRequested": enabled, "exports": results,
            "schemaValidation": "not performance acceptance; process/clock/ROI attribution still required"}


def child(args):
    duration = args.duration_seconds
    require(duration in (20, 60), "Duration must be 20 or 60 seconds")
    work, evidence = args.work.resolve(), args.evidence.resolve()
    require(str(work) == os.environ.get("QIUJI_TEST_WORK") and str(evidence) == os.environ.get("QIUJI_TEST_EVIDENCE")
            and os.environ.get("QIUJI_TEST_RUN_ID"), "Use local_test_lifecycle managed work/evidence")
    require(not os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "This task must not borrow a simulator")
    require(work.parent == evidence.parent and work.parent.parent == DEFAULT_ROOT,
            "Unexpected managed workspace boundary")
    require(work.stat().st_dev == evidence.stat().st_dev, "Atomic artifact transfer requires one filesystem")
    os.umask(0o077)
    for directory in (work.parent, work, evidence):
        os.chmod(directory, 0o700)
    for existing in evidence.iterdir():
        if existing.is_file() and not existing.is_symlink():
            os.chmod(existing, 0o600)
    temporary_directory = work / "tmpdir"
    temporary_directory.mkdir(mode=0o700)
    trace, raw_path = work / "capture.trace", work / "record-stdout-stderr.log"
    require(not trace.exists() and not raw_path.exists(), "Refuse existing recording artifacts")
    summary = {"status": "failed", "performanceAccepted": False, "appControlled": False,
               "durationLimitSeconds": duration, "sealWaitSeconds": SEAL_WAIT_SECONDS,
               "windowSeconds": duration + 10, "traceInternalStartVerified": False,
               "recordingStartNotificationReceived": False, "traceSealed": False,
               "template": "Time Profiler", "instruments": ["Activity Monitor", "os_signpost"],
               "minimumFreeBytes": MIN_FREE_BYTES, "minimumFreePolicyScope": "light CPU recipe only; peak unverified",
               "actualProcessScopeVerified": False}
    errors, recorder, notification = [], None, None
    resource_samples = []
    interrupted, transferred = False, False
    old_handlers = {}
    offset = 0

    def interrupt(signum, frame):
        raise KeyboardInterrupt("Signal " + str(signum))

    def forward_raw():
        nonlocal offset
        if raw_path.exists():
            with raw_path.open("rb") as stream:
                stream.seek(offset); data = stream.read(); offset = stream.tell()
            if data:
                sys.stdout.buffer.write(data); sys.stdout.buffer.flush()

    def observe_resources(label):
        sample = {"phase": label, **disk_snapshot(work, temporary_directory)}
        resource_samples.append(sample)
        write(evidence / "resource-samples.json", resource_samples)
        return sample

    try:
        for signum in (signal.SIGINT, signal.SIGTERM):
            old_handlers[signum] = signal.signal(signum, interrupt)
        before = process_identity(args.pid, args.expected_sha, evidence / "process-before-raw.json")
        write(evidence / "process-before.json", before)
        space = observe_resources("before-record")
        require(space["availableBytes"] >= MIN_FREE_BYTES,
                "Light CPU recording requires at least 8 GiB currently available on the work volume")
        (evidence / SCRIPT.name).write_bytes(SCRIPT.read_bytes())
        write(evidence / "launcher.json", {"source": str(SCRIPT), "sha256": sha(SCRIPT),
              "expectedSHA256": args.expected_sha, "pid": args.pid, "scope": "native Mac App, attach only",
              "mutableTracePath": str(trace), "mutableRecorderLogPath": str(raw_path),
              "privateTMPDIR": str(temporary_directory), "TMPDIRPropagationToXPCHelpersVerified": False,
              "subprocessEnvironmentWhitelist": sorted(ENVIRONMENT_KEYS),
              "environmentValuesRecorded": False, "privateDirectoryMode": "0700", "privateFileUmask": "0077"})
        notification_name = "com.qiuji.research.direct." + os.environ["QIUJI_TEST_RUN_ID"] + "." + uuid.uuid4().hex
        notification = DarwinStartNotification(notification_name)  # must succeed before Popen
        write(evidence / "notification-registration.json", {"name": notification_name,
              "method": "notify_register_file_descriptor", "token": notification.token,
              "registeredBeforeRecorder": True, "initialDescriptorHadNoEvent": True})
        options_path = evidence / "recording-options.json"
        write(options_path, RECORDING_OPTIONS)
        command = record_command(args.pid, work, notification_name, options_path, duration)
        write(evidence / "record-command.json", command)
        print("DIRECT_TRACE_ATTACH_REQUEST " + json.dumps({"pid": args.pid, "evidence": str(evidence)}), flush=True)
        with raw_path.open("wb") as raw:
            recorder = subprocess.Popen(command, cwd=work, stdout=raw, stderr=subprocess.STDOUT,
                                        start_new_session=True, env=tool_environment(temporary_directory))
            spawned = time.monotonic()
            deadline = spawned + duration + SEAL_WAIT_SECONDS
            last_progress, received_at = spawned, None
            write(evidence / "recorder-process.json", {"pid": recorder.pid, "spawnedAt": time.time(),
                  "recordingStartedProven": False, "mutableTracePath": str(trace),
                  "mutableRecorderLogPath": str(raw_path)})
            while True:
                forward_raw()
                if notification.poll() and received_at is None:
                    received_at = time.monotonic()
                    deadline = received_at + duration + SEAL_WAIT_SECONDS
                    event = {"notification": notification_name, "appPID": args.pid, "recorderPID": recorder.pid,
                             "wallUnixSeconds": time.time(), "monotonicNanoseconds": time.monotonic_ns(),
                             "scope": "Darwin recording-start notification; not an App render or present event"}
                    summary["recordingStartNotificationReceived"] = True
                    write(evidence / "recording-start-notification.json", event)
                    print("DIRECT_TRACE_RECORDING_STARTED " + json.dumps(event), flush=True)
                code = recorder.poll()
                if code is not None:
                    summary["recorderExitCode"] = recorder.wait()  # original owned recorder exit code
                    forward_raw()
                    break
                now = time.monotonic()
                if now - last_progress >= 15:
                    phase = ("waiting-start-notification" if received_at is None else
                             "capture-limit-not-yet-elapsed" if now - received_at < duration else
                             "waiting-recorder-exit-after-capture-limit")
                    progress = {"phase": phase, "recorderPID": recorder.pid,
                                "elapsedSinceSpawnSeconds": now - spawned,
                                "remainingWaitSeconds": max(0, deadline - now), "recorderStillRunning": True}
                    progress["resources"] = observe_resources(phase)
                    write(evidence / "recording-progress.json", progress)
                    print("DIRECT_TRACE_PROGRESS " + json.dumps(progress), flush=True)
                    last_progress = now
                if now >= deadline:
                    # Do not send another SIGINT into normal sealing, and do not put
                    # this still-mutable trace/log into immutable evidence.
                    raise TimeoutError("Recorder still active after capture allowance plus 600 second sealing wait")
                time.sleep(0.2)
        require(summary["recorderExitCode"] == 0, "Recorder did not exit successfully")
        observe_resources("recorder-exited")
        require(summary["recordingStartNotificationReceived"], "No actual Darwin recording-start notification received")
        after = process_identity(args.pid, args.expected_sha, evidence / "process-after-raw.json")
        write(evidence / "process-after.json", after)
        require(before == after, "App PID/path/argv/start identity changed during recording/sealing")
        summary["sameProcessBeforeAfter"] = True
        stable_trace(trace, evidence / "trace-stability-before-transfer.json")
        require(not (evidence / "capture.trace").exists() and not (evidence / raw_path.name).exists(),
                "Refuse overwriting immutable recording artifacts")
        trace.rename(evidence / "capture.trace")
        raw_path.rename(evidence / raw_path.name)
        transferred = True
        toc_command = ["xcrun", "xctrace", "export", "--input", str(evidence / "capture.trace"),
                       "--toc", "--output", str(evidence / "trace-toc.xml")]
        toc_result = export(toc_command, evidence, "toc", temporary_directory)
        require(toc_result.get("exitCode") == 0, "TOC export failed; retain original trace and log")
        toc = ET.parse(evidence / "trace-toc.xml").getroot()
        require(toc.tag == "trace-toc" and len(toc.findall("./run")) > 0, "Unknown or empty trace TOC")
        tables = export_tables(toc, evidence, args.export_core, temporary_directory)
        write(evidence / "schema-inventory.json", tables)
        summary.update(tocExported=True, observedTableCount=len(tables["observedTables"]),
                       requestedSchemasAbsent=tables["requestedSchemasAbsent"],
                       exportRequested=args.export_core,
                       nonemptyExportedTables=sum(bool(row.get("nonempty")) for row in tables["exports"]),
                       failedOrEmptyExports=sum(not row.get("nonempty", False) for row in tables["exports"]))
        summary["status"] = "acquired_pending_trace_analysis"
    except BaseException as error:
        interrupted = isinstance(error, KeyboardInterrupt)
        errors.append(repr(error))
    finally:
        if interrupted and recorder is not None and recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)  # explicit interruption; owned recorder only
            summary["explicitInterruptSentToRecorder"] = True
            try:
                summary["recorderExitCode"] = recorder.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass  # still-mutable work retained below; never declared sealed
        if recorder is not None and recorder.poll() is None:
            summary.update(retainedRecorderPID=recorder.pid, recorderExitCode=None,
                           mutableTracePath=str(trace), mutableRecorderLogPath=str(raw_path),
                           workRequiresExplicitRecovery=True)
            errors.append("Recorder remains active; mutable artifacts stay in failed lifecycle work, outside evidence")
        elif recorder is not None and "recorderExitCode" not in summary:
            summary["recorderExitCode"] = recorder.wait()
        if not transferred and (trace.exists() or raw_path.exists()):
            summary.update(mutableTracePath=str(trace), mutableRecorderLogPath=str(raw_path),
                           workRequiresExplicitRecovery=True)
        if transferred:
            try:
                final_trace = evidence / "capture.trace"
                stable = stable_trace(final_trace, evidence / "trace-stability-after-exports.json")
                files = tree_files(final_trace)
                require(trace_snapshot(final_trace) == stable, "Trace changed during final hashing")
                write(evidence / "trace-receipt.json", {"files": files, "recorderExited": True,
                      "recorderExitCode": summary["recorderExitCode"], "allExportsFinishedBeforeSeal": True,
                      "stabilityReport": "trace-stability-after-exports.json"})
                summary["traceSealed"] = bool(files)
            except (ValueError, OSError) as error:
                errors.append("trace-receipt: " + repr(error))
        if notification is not None:
            try:
                notification.cancel()
                summary["notificationCancelled"] = True
            except (ValueError, OSError) as error:
                errors.append("notify-cancel: " + repr(error))
        try:
            observe_resources("finally")
            summary.update(minimumObservedAvailableBytes=min(row["availableBytes"] for row in resource_samples),
                           maximumObservedPrivateTemporaryAllocatedBytes=max(row["temporaryAllocatedBytes"] for row in resource_samples),
                           resourceSampleCount=len(resource_samples),
                           resourcePeakSamplingBoundary="periodic observations, not an exact allocation peak")
        except OSError as error:
            errors.append("resource-observation: " + repr(error))
        for signum, handler in old_handlers.items():
            signal.signal(signum, handler)
        if errors:
            summary["status"] = "failed_unsealed_work_retained" if not transferred else "failed"
        summary["errors"] = errors
        write(evidence / "summary.json", summary)
        print("DIRECT_TRACE_SUMMARY " + json.dumps(summary), flush=True)
    return 0 if not errors else 1


def launch_owner(args):
    command = [sys.executable, str(ROOT / "scripts/local_test_lifecycle.py"), "run", "--task", args.task,
               "--", sys.executable, "-B", str(SCRIPT), "--pid", str(args.pid), "--expected-sha", args.expected_sha,
               "--duration-seconds", str(args.duration_seconds),
               "--execute", "--work", "{work}", "--evidence", "{evidence}"]
    if args.export_core:
        command.append("--export-core")
    # The lifecycle owns execution and sealing. This layer only forwards its child's
    # command.log, since the lifecycle otherwise prints that log after completion.
    owner = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             env=tool_environment())
    old_handlers = {}
    def forward_interrupt(signum, frame):
        if owner.poll() is None:
            owner.send_signal(signum)  # the lifecycle owner handles its own child
    for signum in (signal.SIGINT, signal.SIGTERM):
        old_handlers[signum] = signal.signal(signum, forward_interrupt)
    command_log, offset, pending = None, 0, b""
    with selectors.DefaultSelector() as ready:
        ready.register(owner.stdout, selectors.EVENT_READ)
        while ready.get_map() or owner.poll() is None:
            for key, _ in ready.select(timeout=0.1):
                data = os.read(key.fd, 65536)
                if not data:
                    ready.unregister(key.fileobj)
                    continue
                pending += data
                lines = pending.split(b"\n"); pending = lines.pop()
                for line in lines:
                    text = line.decode(errors="replace")
                    if text.startswith("Local test run: "):
                        run = Path(text.removeprefix("Local test run: "))
                        require(run.parent == DEFAULT_ROOT and re.fullmatch(r"[0-9a-f]{32}", run.name), "Invalid lifecycle run")
                        command_log = run / "evidence/command.log"
                        print(text, flush=True)
                    elif text.startswith(("Local workspace:", "Cleanup deferred:")):
                        print(text, flush=True)
            if command_log is not None and command_log.exists():
                with command_log.open("rb") as stream:
                    stream.seek(offset); data = stream.read(); offset = stream.tell()
                if data:
                    sys.stdout.buffer.write(data); sys.stdout.buffer.flush()
    if command_log is None and pending:
        sys.stdout.buffer.write(pending); sys.stdout.buffer.flush()
    for signum, handler in old_handlers.items():
        signal.signal(signum, handler)
    return owner.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--duration-seconds", type=int, choices=(20, 60), default=DEFAULT_DURATION_SECONDS)
    parser.add_argument("--task", default="cloth-native-direct-schema-smoke")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--export-core", action="store_true")
    parser.add_argument("--work", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--evidence", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    require(args.pid > 0 and re.fullmatch(r"[0-9a-f]{64}", args.expected_sha), "Explicit PID and lowercase SHA256 required")
    if args.work or args.evidence:
        require(args.work and args.evidence and args.execute, "Managed child requires both paths and --execute")
        return child(args)
    identity = process_identity(args.pid, args.expected_sha)
    print(json.dumps({"executionStarted": False, "identity": identity,
          "recordArgv": record_command(args.pid, Path("{work}"), options_path=Path("{evidence}/recording-options.json"),
                                       duration_seconds=args.duration_seconds),
          "durationLimitSeconds": args.duration_seconds, "windowSeconds": args.duration_seconds + 10,
          "recordingOptions": RECORDING_OPTIONS, "privateTMPDIR": "{work}/tmpdir/",
          "minimumFreeBytes": MIN_FREE_BYTES,
          "minimumFreePolicyScope": "light CPU recipe only; peak and XPC TMPDIR propagation unverified",
          "actualProcessScopeVerified": False, "gpuMetricsExpected": False,
          "exportCore": args.export_core},
          ensure_ascii=False, indent=2), flush=True)
    if not args.execute:
        return 0
    require(not os.environ.get("QIUJI_TEST_WORK") and not os.environ.get("QIUJI_SIMULATOR_LEASE_TOKEN"), "Refuse nested lifecycle")
    return launch_owner(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("ERROR: " + repr(error), file=sys.stderr)
        sys.exit(1)
