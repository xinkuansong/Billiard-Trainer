"""Independent B-only native probes for obstructed rays; known pot witnesses protect positives."""
from prepare import *
import concurrent.futures,os,subprocess,sys,traceback
sys.path.insert(0,str(ROOT/'research/two-ball-independent125-full-20261024'))
import runtime_common as common
def worker(index,uid,requests):
 common.OUT=OUT/'native-validation';common.APP=HERE/'native/Worker.app/Worker';w=common.Worker(uid,index);result=[]
 try:
  for offset in range(0,len(requests),32):
   batch=requests[offset:offset+32];w.p.stdin.write(json.dumps(batch)+'\n');w.p.stdin.flush();out=w.receive('RESULT',180)
   assert [p['key'] for p in out]==[p['key'] for p in batch]
   for p in out:
    assert p['passed']==any(t['passed'] for t in p['trials'])
    if p['passed']:assert any(t['passed'] and t['route']=='direct-pot' and t['settled'] and any(e['kind']=='pocket' and e['pocket']==f"pocket_{p['pocket']}" for e in t['events']) for t in p['trials'])
   result.extend(out)
  write(common.OUT/f'worker-{index}-proofs.json',result)
  return result
 finally:
  w.close();write(common.OUT/f'worker-{index}-closed.json',dict(nativePID=w.pid,exitCode=w.p.returncode))
def main():
 start=time.perf_counter();dest=OUT/'native-validation';dest.mkdir(exist_ok=True);(dest/'logs').mkdir(exist_ok=True);uid=sys.argv[1];assert not (dest/'complete.json').exists()
 proofs=read(OUT/'geometry-proofs.json');requests=[p for p in proofs if not p['passed']]
 write(dest/'execution.json',dict(pid=os.getpid(),device=uid,workers=8,requests=len(requests),startedAt=time.time(),policy='B only, original direction, no spin; .5..8 adaptive up to5, direct designated pot; own mouth allowed, main-rail banks excluded; no cue ball/access/scratch gate'))
 booted=False
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);booted=True;subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
  with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
   futures=[pool.submit(worker,i,uid,requests[i::8]) for i in range(8)];allresults=[p for f in futures for p in f.result()]
  assert len(allresults)==len(requests);write(dest/'proofs.json',allresults);write(dest/'complete.json',dict(requests=len(requests),passed=sum(p['passed'] for p in allresults),seconds=time.perf_counter()-start,proofsSHA256=sha(dest/'proofs.json')))
 except BaseException:write(dest/'failure.json',dict(traceback=traceback.format_exc()));raise
 finally:
  if booted:
   s=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True);write(dest/'cleanup.json',dict(device=uid,shutdownCode=s.returncode,stderr=s.stderr));assert s.returncode==0
 print((dest/'complete.json').read_text())
if __name__=='__main__':main()
