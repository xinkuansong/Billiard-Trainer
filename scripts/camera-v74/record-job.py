#!/usr/bin/env python3
"""Read-only capture while this task's queue device lease is active."""
import sys,time,json,subprocess,signal
from pathlib import Path
job=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
record=None
for _ in range(2400):
 if (job/'job.json').exists():
  state=json.loads((job/'job.json').read_text())['state']
  if state in ['succeeded','failed','cancelled','interrupted']:break
  device=job/'evidence/device-result.json'
  if record is None and device.exists() and (job/'evidence/tests.command.json').exists():
   uid=json.loads(device.read_text())['udid']
   log=(out/'record.log').open('w')
   record=subprocess.Popen(['xcrun','simctl','io',uid,'recordVideo',str(out/'native.mp4')],stdout=log,stderr=log)
 time.sleep(1)
if record:
 record.send_signal(signal.SIGINT)
 try:record.wait(timeout=20)
 except subprocess.TimeoutExpired:record.terminate();record.wait()
(out/'capture.json').write_text(json.dumps({'job':job.name,'recorded':record is not None,'recordingExitCode':record.returncode if record else None}))
