from pathlib import Path
import subprocess,sys,os,tarfile
from build import build,ROOT,OUT
if len(sys.argv)==1:
 subprocess.run([sys.executable,str(Path(__file__).with_name('prepare.py'))],check=True)
 app=build()
 with tarfile.open(OUT/'frozen-worker-source.tar.gz','w:gz') as tar:tar.add(Path(os.environ['QIUJI_TEST_WORK'])/'source',arcname='source')
 subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','notch-phone','--task','k-ball-tolerance-20261029','--',sys.executable,__file__,'{udid}',str(app/'Worker')],check=True)
else:
 uid,worker=sys.argv[1:];subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  subprocess.run(['xcrun','simctl','spawn',uid,worker,str(OUT/'samples.json'),str(OUT/'protocol.json'),str(OUT/'results.jsonl')],check=True)
 finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
