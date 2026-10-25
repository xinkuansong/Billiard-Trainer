from pathlib import Path
import sys,subprocess,json
import run
c=run.read('run-paths.json');e=Path(c['evidence'])
if len(sys.argv)==1:
 assert run.hashes(Path(c['snapshot']))==run.read('snapshot-hashes.json')
 run.command([run.PY,run.OUT/'analyze.py','design'],e/'audit-design-v2.log',run.ROOT)
 run.command([sys.executable,run.ROOT/'scripts/simulator_fleet.py','run','--role','notch-phone','--task','two-ball-strategy-holdout','--',sys.executable,run.OUT/'resume.py','{udid}'],e/'device-holdout.log',run.ROOT)
 assert run.hashes(Path(c['snapshot']))==run.read('snapshot-hashes.json')
 run.save('source-hashes-after.json',run.hashes(run.ROOT))
else:
 uid=sys.argv[1]
 try:
  run.save('request.json',{'mode':'holdout'})
  run.command(run.make_args(c,'test-without-building','holdout',uid),e/'make-holdout.log',c['snapshot'])
  run.command([run.PY,run.OUT/'analyze.py','holdout'],e/'analyze-holdout.log',run.ROOT)
 finally:
  r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
  run.save('shutdown-holdout.json',{'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
