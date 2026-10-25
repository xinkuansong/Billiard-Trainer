from pathlib import Path
import os,sys,json,subprocess,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
if (OUT/'launch.json').exists():
 old=json.loads((OUT/'launch.json').read_text());pid=old['pid']
 try:os.kill(pid,0)
 except ProcessLookupError:pass
 else:raise SystemExit(f'Existing launcher PID {pid}; do not duplicate')
cmd=['/usr/bin/caffeinate','-i',sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','two-ball-independent125-full-16','--',sys.executable,str(HERE/'run_full.py'),'{udid}']
with (OUT/'launcher.log').open('a') as log:
 p=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
(OUT/'launch.json').write_text(json.dumps(dict(pid=p.pid,command=cmd,startedAt=time.time()),indent=2));print('LAUNCHED',p.pid)
