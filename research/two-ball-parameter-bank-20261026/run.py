from pathlib import Path
import subprocess,json,os,sys,time,hashlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output/two-ball-parameter-bank-20261026'
def device(uid):
 data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json']))
 return next(dict(d,runtime=r) for r,ds in data['devices'].items() for d in ds if d['udid']==uid)
if len(sys.argv)>1 and sys.argv[1]=='native':
 uid=sys.argv[2];worker=sys.argv[3];before=device(uid);assert before['state']=='Shutdown';start=time.time();code=1
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  with (OUT/'native.log').open('w') as log:
   code=subprocess.run(['xcrun','simctl','spawn',uid,worker,str(OUT/'ParameterBank'),str(OUT/'reference-cases.json'),str(OUT/'native-results.json')],stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
 finally:
  subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
  after=device(uid);assert after['state']=='Shutdown'
  (OUT/'device-closure.json').write_text(json.dumps({'deviceBefore':before,'deviceAfter':after,'workerExitCode':code,'wallSecondsIncludingBootShutdown':time.time()-start,'hostCPU':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'managedEvidence':os.environ['QIUJI_TEST_EVIDENCE'],'leaseToken':os.environ['QIUJI_SIMULATOR_LEASE_TOKEN']},indent=2))
 sys.exit(code)
else:
 subprocess.run([sys.executable,str(HERE/'build.py')],check=True)
 worker=Path(os.environ['QIUJI_TEST_WORK'])/'ParameterWorker.app/Worker'
 (OUT/'executable-sha256.txt').write_text(hashlib.sha256(worker.read_bytes()).hexdigest()+'\n')
 code=subprocess.run([sys.executable,str(ROOT/'scripts/simulator_fleet.py'),'run','--role','large-phone','--task','two-ball-parameter-replay-20261026','--',sys.executable,str(HERE/'run.py'),'native','{udid}',str(worker)]).returncode
 if code==0:
  sys.path.insert(0,str(ROOT/'scripts'));from simulator_lifecycle import Manager
  # The fleet wrapper returned only after shutdown and lease release.
  closure=json.loads((OUT/'device-closure.json').read_text());closure['fleetExitCode']=code;closure['fleetReturnedAfterRelease']=True
  (OUT/'device-closure.json').write_text(json.dumps(closure,indent=2))
 sys.exit(code)
