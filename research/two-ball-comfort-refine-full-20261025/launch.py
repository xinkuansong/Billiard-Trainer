import engine as E
import os,subprocess,sys,time
pilot='--pilot' in sys.argv
for name in ['launch.json','execution.json']:
 p=E.OUT/name
 if p.exists():
  pid=E.read(p)['pid']
  try:os.kill(pid,0)
  except ProcessLookupError:pass
  else:raise SystemExit(f'Existing PID {pid}; inspect before starting')
cmd=['/usr/bin/caffeinate','-i',sys.executable,str(E.ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','two-ball-comfort85-full-20261025','--',sys.executable,str(E.HERE/'runner.py'),'{udid}']+(['--pilot'] if pilot else [])
env=dict(os.environ,PYTHONPATH='/tmp/codex-angle-density-20261024-deps')
with (E.OUT/'launcher.log').open('a') as log:p=subprocess.Popen(cmd,cwd=E.ROOT,stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
E.write(E.OUT/'launch.json',dict(pid=p.pid,command=cmd,startedAt=time.time(),pilot=pilot));print('LAUNCHED',p.pid,'pilot',pilot)
