from pathlib import Path
import sys,json,time,subprocess,gzip,queue,threading,concurrent.futures,hashlib,traceback,collections,os
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
sys.path.insert(0,str(HERE.parent/'two-ball-strike-full-20261024'))
import run_full as common
from sampling import combinations
common.OUT=OUT;common.APP=HERE/'Worker.app/Worker'
uid=sys.argv[1];workers=[];lock=threading.Lock();done=[];stop=threading.Event()
for d in ['logs','parts','audit-paths']:(OUT/d).mkdir(exist_ok=True)
if list((OUT/'parts').glob('*.jsonl.gz')):raise SystemExit('Existing parts; refusing duplicate run')
boards=json.loads((OUT/'layouts.json').read_text());q=queue.Queue()
for i in range(0,len(boards),10):q.put((i,boards[i:i+10]))
startAll=time.monotonic()
try:
 subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True)
 subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
 for i in range(8):workers.append(common.Worker(uid,i))
 assert len({w.pid for w in workers})==8
 common.write(OUT/'workers.json',dict(pids=[w.pid for w in workers],device=uid,binarySHA256=common.sha(common.APP)))
 start=time.monotonic()
 def work(w):
  while not stop.is_set():
   try:offset,chunk=q.get_nowait()
   except queue.Empty:return
   path=OUT/'parts'/f'{offset//10:04d}.jsonl.gz';tmp=path.with_suffix('.partial');counts=collections.Counter();wall=0.;valid=[]
   with gzip.open(tmp,'wt',compresslevel=6) as f:
    for bi,board in enumerate(chunk,offset):
     if stop.is_set():return
     cs=combinations(board['id'],125)
     request=dict(board=board,combinations=cs,captureAudit=bi<20)
     w.p.stdin.write(json.dumps(request,separators=(',',':'))+'\n');w.p.stdin.flush()
     result=w.receive('RESULT',180);common.checked(result,board,cs)
     assert len(result['rows'])==125
     raw=[]
     for r in result['rows']:
      assert r['directionRetries']==0 and r['simulationCalls'] in [0,1]
      assert ('trajectory2mm' in r)==r['usableForPositionMatch']
      if 'auditFullLine' in r:raw.append(dict(comboIndex=r['comboIndex'],line=r.pop('auditFullLine'),compact=r['trajectory2mm'],cueStop=r['cueStop']))
     if raw:
      with gzip.open(OUT/'audit-paths'/f'{bi:04d}.json.gz','wt') as a:json.dump(dict(id=board['id'],rows=raw),a)
     f.write(json.dumps(result,separators=(',',':'))+'\n');wall+=result['elapsedSeconds'];counts.update(r['status'] for r in result['rows']);valid.append(sum(r['usableForPositionMatch'] for r in result['rows']))
   tmp.replace(path)
   with lock:done.append(dict(file=path.name,layouts=len(chunk),status=dict(counts),summedBatchWallSeconds=wall,validPerLayout=valid,bytes=path.stat().st_size,sha256=common.sha(path)))
   q.task_done()
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
  futures=[pool.submit(work,w) for w in workers]
  while not all(f.done() for f in futures):
   failures=[f.exception() for f in futures if f.done() and f.exception()]
   if failures:stop.set();raise failures[0]
   with lock:snapshot=list(done)
   progress=dict(state='running',completedLayouts=sum(r['layouts'] for r in snapshot),elapsedSeconds=time.monotonic()-start,workers=8)
   common.write(OUT/'progress.json',progress);print(json.dumps(progress),flush=True);time.sleep(5)
  for f in futures:f.result()
 elapsed=time.monotonic()-start
 common.write(OUT/'run-complete.json',dict(state='needs_audit',layoutCount=sum(r['layouts'] for r in done),elapsedComputeAndWriteSeconds=elapsed,elapsedIncludingStartupSeconds=time.monotonic()-startAll,receipts=sorted(done,key=lambda r:r['file'])))
 print('COMPUTE_DONE',elapsed,flush=True)
except BaseException as e:
 stop.set();common.write(OUT/'failure.json',dict(error=str(e),traceback=traceback.format_exc()));raise
finally:
 for w in workers:w.close()
 r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True)
 common.write(OUT/'cleanup.json',dict(workerExitCodes=[w.p.poll() for w in workers],shutdownExitCode=r.returncode,shutdownError=r.stderr))
 if r.returncode:raise RuntimeError('Simulator shutdown failed: '+r.stderr)
