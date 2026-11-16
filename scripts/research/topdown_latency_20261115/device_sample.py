#!/usr/bin/env python3
"""Bounded physical-device CPU capture; no App launch/install or UI actions."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time
import uuid

p = argparse.ArgumentParser()
p.add_argument('--device', required=True)
p.add_argument('--pid', required=True, type=int)
p.add_argument('--target-name')
p.add_argument('--all-processes', action='store_true')
p.add_argument('--seconds', required=True, type=int, choices=(5, 30, 45))
p.add_argument('--out', required=True, type=Path)
a = p.parse_args()
out = a.out.resolve()
out.mkdir(parents=True, exist_ok=False)
spec = importlib.util.spec_from_file_location('direct', Path(__file__).resolve().parents[1] / 'cloth_lowdim_20261113/run_direct_trace.py')
direct = importlib.util.module_from_spec(spec)
spec.loader.exec_module(direct)
tmp = out / 'tmp'
tmp.mkdir()
free = shutil.disk_usage(out).free
if free < 8 * 1024**3:
    raise RuntimeError('Less than 8 GiB available for bounded CPU-only capture')
options = out / 'options.json'
options.write_text(json.dumps({'Time Profiler': {'contextSwitchSampling': False,
    'highFrequencySampling': False, 'recordKernelStacks': False, 'recordWaitingThreads': True}}))
notification = direct.DarwinStartNotification('com.qiuji.topdown.' + uuid.uuid4().hex)
command = ['xcrun', 'xctrace', 'record', '--template', 'Time Profiler', '--device', a.device,
           *(['--all-processes'] if a.all_processes else ['--attach', a.target_name or str(a.pid)]), '--time-limit', str(a.seconds) + 's',
           '--recording-options', str(options), '--notify-tracing-started', notification.name,
           '--output', str(out / 'capture.trace')]
state = {'command': command, 'freeBytesBefore': free, 'pid': a.pid,
         'device': a.device, 'durationSeconds': a.seconds, 'startNotification': None}
def save():
    (out / 'state.json').write_text(json.dumps(state, indent=2))
save()
start = time.monotonic()
with (out / 'record.log').open('w') as log:
    proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                            env=direct.tool_environment(tmp))
    state['recorderPID'] = proc.pid
    save()
    try:
        while proc.poll() is None:
            if state['startNotification'] is None and notification.poll():
                state['startNotification'] = time.time()
                save()
                print('RECORDING_STARTED ' + str(state['startNotification']), flush=True)
            if shutil.disk_usage(out).free < 4 * 1024**3:
                state['stoppedForSpace'] = True
                proc.send_signal(2)
                break
            if time.monotonic() - start > a.seconds + 180:
                state['recorderTimeout'] = True
                proc.send_signal(2)
                break
            time.sleep(0.2)
        try:
            state['exitCode'] = proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            state['exitCode'] = None
            state['stillSealing'] = True
        state['freeBytesAfter'] = shutil.disk_usage(out).free
        save()
        print(json.dumps(state), flush=True)
    finally:
        notification.cancel()
if state.get('exitCode') != 0 or state['startNotification'] is None:
    raise SystemExit('Capture incomplete; inspect original log and state')
