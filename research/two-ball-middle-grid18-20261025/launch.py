from pathlib import Path
import os,sys,json,subprocess,time
import pipeline as P
stage=sys.argv[1];assert stage in ('a','b');out=P.A if stage=='a' else P.B
if (out/'summary.json').exists() and P.read(out/'summary.json').get('auditPassed'):raise SystemExit('Already complete')
for name in ('launch.json','execution.json'):
 if (out/name).exists():
  pid=P.read(out/name)['pid']
  try:os.kill(pid,0)
  except ProcessLookupError:pass
  else:raise SystemExit(f'Inspect existing PID {pid}; duplicate launch forbidden')
cmd=['/usr/bin/caffeinate','-i',sys.executable,str(P.ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task',f'two-ball-middle-grid18-{stage}-20261025','--',sys.executable,str(P.HERE/'runner.py'),'{udid}','--stage',stage,'--workers','16']
env=dict(os.environ,PYTHONPATH='/tmp/codex-angle-density-20261024-deps')
with (out/'launcher.log').open('a') as log:p=subprocess.Popen(cmd,cwd=P.ROOT,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
P.write(out/'launch.json',{'pid':p.pid,'command':cmd,'startedAt':time.time()});print('LAUNCHED',stage,p.pid)
