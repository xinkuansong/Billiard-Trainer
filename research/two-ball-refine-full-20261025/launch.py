from pathlib import Path
import os,sys,json,subprocess,time
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
if (OUT/'summary.json').exists() and json.loads((OUT/'summary.json').read_text()).get('auditPassed'):raise SystemExit('Already complete')
for name in ('launch.json','execution.json'):
 if (OUT/name).exists():
  prior=json.loads((OUT/name).read_text());pid=prior['pid']
  try:os.kill(pid,0)
  except ProcessLookupError:pass
  else:raise SystemExit(f'Existing PID {pid} in {name}; inspect, do not duplicate')
cmd=['/usr/bin/caffeinate','-i',sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','two-ball-refine-full-20261025','--',sys.executable,str(HERE/'runner.py'),'{udid}']
env=os.environ.copy();env['PYTHONPATH']='/tmp/codex-angle-density-20261024-deps'
with (OUT/'launcher.log').open('a') as log:p=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
(OUT/'launch.json').write_text(json.dumps(dict(pid=p.pid,command=cmd,startedAt=time.time()),indent=2));print('LAUNCHED',p.pid)
