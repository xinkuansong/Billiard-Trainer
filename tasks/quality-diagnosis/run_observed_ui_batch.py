#!/usr/bin/env python3
"""Serial diagnostic run with owned-simulator video and exact App PID/RSS samples.

Uses the reviewed run_ui_batch config without changing its selectors or inputs.
Video is observation evidence; success does not replace frame-by-frame review.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


def main():
    config_path = Path(sys.argv[1]).resolve()
    config = json.loads(config_path.read_text())
    repo = Path(__file__).resolve().parents[2]
    udid = config['udid']
    devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j']))
    matches = [d for group in devices['devices'].values() for d in group if d['udid'] == udid]
    assert len(matches) == 1 and matches[0]['name'].startswith('QD004-')
    assert matches[0]['state'] == 'Booted'
    out = repo / 'build/quality-diagnosis/observations' / config['run']
    out.mkdir(parents=True, exist_ok=False)
    assert not (repo / 'build/quality-diagnosis' / config['run']).exists()
    metadata = {'config': config, 'device': matches[0], 'started': datetime.datetime.now().astimezone().isoformat(),
                'observerSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'hostMonotonicStart': time.monotonic(), 'hostLoadAverage': os.getloadavg(),
                'memoryUnit': 'ps RSS KiB; simulator App only, not a leak verdict',
                'videoReview': 'pending all required cycles; no automatic motion verdict'}
    (out / 'observation.json').write_text(json.dumps(metadata, indent=2))
    (out / 'observer-source.py').write_bytes(Path(__file__).read_bytes())
    stop = threading.Event()

    def sample():
        executable = None
        resolved_at = 0.0
        with (out / 'pid-rss.jsonl').open('w') as log:
            while not stop.is_set():
                # XCTest may reinstall into a different bundle-container UUID.
                # Refresh the owned path so pre-build discovery cannot go stale.
                if time.monotonic() - resolved_at >= 4:
                    resolved_at = time.monotonic()
                    p = subprocess.run(['xcrun', 'simctl', 'get_app_container', udid, 'com.xinkuan.qiuji', 'app'], capture_output=True, text=True)
                    if p.returncode == 0:
                        container = Path(p.stdout.strip())
                        # Read only the executable name; never emit app preferences or secrets.
                        q = subprocess.run(['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleExecutable', str(container / 'Info.plist')], capture_output=True, text=True)
                        if q.returncode == 0 and udid in str(container):
                            executable = str(container / q.stdout.strip())
                rows = []
                if executable:
                    p = subprocess.run(['ps', '-axo', 'pid=,rss=,vsz=,command='], capture_output=True, text=True)
                    for line in p.stdout.splitlines():
                        parts = line.split(None, 3)
                        if len(parts) == 4 and (parts[3] == executable or parts[3].startswith(executable + ' ')):
                            rows.append({'pid': int(parts[0]), 'rssKiB': int(parts[1]), 'vszKiB': int(parts[2])})
                log.write(json.dumps({'monotonic': time.monotonic(), 'wallTime': datetime.datetime.now().astimezone().isoformat(),
                                      'executable': executable, 'processes': rows}) + '\n')
                log.flush()
                stop.wait(1)

    recorder_log = (out / 'recorder.log').open('w')
    recorder = subprocess.Popen(['xcrun', 'simctl', 'io', udid, 'recordVideo', '--codec=h264', str(out / 'continuous.mp4')],
                                stdout=recorder_log, stderr=subprocess.STDOUT)
    worker = None
    result = None
    try:
        deadline = time.monotonic() + 15
        while 'Recording started' not in (out / 'recorder.log').read_text():
            if recorder.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Recorder did not confirm Recording started; test not launched')
            time.sleep(0.1)
        metadata['recordingConfirmedMonotonic'] = time.monotonic()
        worker = threading.Thread(target=sample)
        worker.start()
        with (out / 'runner-output.log').open('w') as log:
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('run_ui_batch.py')), str(config_path)],
                                    stdout=log, stderr=subprocess.STDOUT)
        return result.returncode
    finally:
        stop.set()
        if worker:
            worker.join(timeout=10)
        if recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
        try:
            recorder.wait(timeout=30)
        except subprocess.TimeoutExpired:
            metadata['recorderFinalization'] = 'timed-out; video may be incomplete'
            recorder.terminate()
            recorder.wait(timeout=10)
        recorder_log.close()
        metadata.update(finished=datetime.datetime.now().astimezone().isoformat(), recorderExit=recorder.returncode,
                        runnerExit=None if result is None else result.returncode)
        (out / 'observation.json').write_text(json.dumps(metadata, indent=2))
        print(json.dumps({'observationDirectory': str(out), 'runnerExit': metadata['runnerExit'], 'recorderExit': recorder.returncode}))


if __name__ == '__main__':
    sys.exit(main())
