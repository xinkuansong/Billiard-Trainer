from pathlib import Path
import importlib.util,os,subprocess,sys,tarfile,json,time
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/k-ball-obstacles-20261030'
def main():
 if len(sys.argv)==1:
  if (OUT/'finish').exists():raise RuntimeError('Completed experiment retained. Choose a fresh output directory for another execution.')
  spec=importlib.util.spec_from_file_location('builder',ROOT/'research/k-ball-tolerance-20261029/build.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);m.HERE=HERE;m.OUT=OUT
  app=m.build()
  with tarfile.open(OUT/'frozen-worker-source.tar.gz','w:gz') as t:t.add(Path(os.environ['QIUJI_TEST_WORK'])/'source',arcname='source')
  subprocess.run([sys.executable,str(ROOT/'scripts/simulator_lifecycle.py'),'run','--task','k-ball-obstacles-20261030','--udid','0D3AE337-488E-49D0-8AFF-E711249046EC','--evidence',str(OUT/'execution-receipt.json'),'--',sys.executable,__file__,'0D3AE337-488E-49D0-8AFF-E711249046EC',str(app/'Worker')],check=True)
  return
 uid,worker=sys.argv[1:];state=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']));original=next(d['state'] for ds in state['devices'].values() for d in ds if d['udid']==uid)
 if original=='Shutdown':
  subprocess.run(['xcrun','simctl','boot',uid],check=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
 else:assert original=='Booted'
 try:
  (OUT/'worker-ready.json').write_text(json.dumps(dict(uid=uid,worker=worker,originalState=original)))
  # Interactive research stages consume the same leased worker without touching the installed App.
  while not (OUT/'finish').exists():time.sleep(1)
  (OUT/'execution-receipt.json').write_text(json.dumps(dict(complete=True,endedAt=time.time(),uid=uid,originalState=original)))
 finally:
  if original=='Shutdown':subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
