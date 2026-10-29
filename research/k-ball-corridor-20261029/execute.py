from pathlib import Path
import subprocess,sys,os,json,tarfile
from build import build,ROOT,OUT
PYTHON='/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3'
if len(sys.argv)==1:
 app=build()
 with tarfile.open(OUT/'frozen-worker-source.tar.gz','w:gz') as tar:tar.add(Path(os.environ['QIUJI_TEST_WORK'])/'source',arcname='source')
 subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','k-ball-corridor-20261029','--',sys.executable,__file__,'{udid}',str(app/'Worker')],check=True)
else:
 uid,worker=sys.argv[1:]
 def run(*args):subprocess.run(['xcrun','simctl','spawn',uid,worker,*map(str,args)],check=True)
 subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  run('geometry',OUT/'geometry.json')
  subprocess.run([PYTHON,str(Path(__file__).with_name('candidates.py'))],check=True)
  run('simulate',OUT/'candidates.json',OUT/'trials.json',OUT/'baselines.json')
  passed=[r for r in json.loads((OUT/'trials.json').read_text()) if r['success']]
  (OUT/'samples.json').write_text(json.dumps(passed))
  run('verify',OUT/'samples.json',OUT/'replay.json')
 finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
