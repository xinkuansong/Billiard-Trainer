"""Run inside a borrowed simulator lease; observe the existing app without installing."""
import argparse
import hashlib
import json
from pathlib import Path
import signal
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--udid', required=True)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--seconds', type=int, default=20)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=False)
rows = subprocess.check_output(['ps', '-Ao', 'pid=,comm='], text=True).splitlines()
matches = [int(r.strip().split(None, 1)[0]) for r in rows
           if a.udid in r and r.rstrip().endswith('/球迹.app/球迹')]
assert len(matches) == 1, matches
pid = matches[0]
app = Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,
    'com.xinkuan.qiuji','app'],text=True).strip())
identity = {'pid':pid, 'udid':a.udid, 'appSHA256':hashlib.sha256((app/'球迹').read_bytes()).hexdigest(),
            'wallStart':time.time(), 'durationRequestedSeconds':a.seconds}
with (a.out/'capture.log').open('w') as out:
    video = subprocess.Popen(['xcrun','simctl','io',a.udid,'recordVideo','--codec=h264',str(a.out/'video.mp4')],stdout=out,stderr=out)
    sample = subprocess.Popen(['sample',str(pid),str(a.seconds),'1','-file',str(a.out/'stacks.txt')],stdout=out,stderr=out)
    print('sampling ready',flush=True)
    try:
        time.sleep(a.seconds)
    finally:
        video.send_signal(signal.SIGINT)
        identity['videoExit'] = video.wait(timeout=30)
        identity['sampleExit'] = sample.wait(timeout=30)
        identity['wallEnd'] = time.time()
        (a.out/'identity.json').write_text(json.dumps(identity,indent=2))
print('sampling complete',flush=True)
