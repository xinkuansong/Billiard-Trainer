from pathlib import Path
import json,gzip,sys,os,time,queue,threading,concurrent.futures,subprocess,traceback,signal,fcntl
import runtime_common as common
from stratified_sampling import combinations,VERSION
from contract import normalize,validate,stats,merge
from memory import MemoryMonitor
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];OUT=ROOT/'output'/HERE.name
common.OUT=OUT;common.APP=HERE/'Worker.app/Worker';read=lambda p:json.loads(p.read_text())
uid=sys.argv[1];manifest=read(OUT/'manifest.json');lockfile=(OUT/'run.lock').open('a');fcntl.flock(lockfile,fcntl.LOCK_EX|fcntl.LOCK_NB)
for path,key in [(OUT/'layouts.json','layoutsSHA256'),(OUT/'schedule.json','scheduleSHA256'),(HERE/'stratified_sampling.py','samplingSHA256'),(HERE/'quota_sampling_v1.py','quotaBaselineSHA256'),(common.APP,'binarySHA256'),(Path(manifest['sourceBank']),'sourceBankSHA256')]:assert common.sha(path)==manifest[key],str(path)
assert sys.version==manifest['python'],'Keep frozen Python sampling runtime'
if (OUT/'summary.json').exists() and read(OUT/'summary.json').get('auditPassed'):raise SystemExit('Already complete; no duplicate launch')
boards=read(OUT/'layouts.json');schedule=read(OUT/'schedule.json');shards=[schedule[i:i+100] for i in range(0,len(schedule),100)];pending=queue.Queue();receipts=[];guard=threading.Lock();stop=threading.Event();workers=[];monitor=None
for i,indices in enumerate(shards):
 receipt=OUT/'receipts'/f'{i:05d}.json';path=OUT/'parts'/f'{i:05d}.jsonl.gz'
 if receipt.exists():
  r=read(receipt);assert r['layoutIndices']==indices and common.sha(path)==r['sha256'];receipts.append(r)
 else:pending.put((i,indices))
initialCommitted=len(receipts);startall=time.monotonic();started=time.time();session=f'{int(started)}';fixtures={round(i*(len(schedule)-1)/19) for i in range(20)}
common.write(OUT/'execution.json',dict(pid=os.getpid(),startedAt=started,session=session,pendingShards=pending.qsize(),codeSHA256={f:common.sha(HERE/f) for f in ['run_full.py','contract.py','runtime_common.py','memory.py','audit.py']}))
def interrupted(signum,frame):stop.set();raise KeyboardInterrupt('Managed run interrupted')
signal.signal(signal.SIGTERM,interrupted);signal.signal(signal.SIGINT,interrupted)
def aggregate():
 s={}
 for r in sorted(receipts,key=lambda x:x['index']):merge(s,r['stats'])
 return s
try:
 subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
 for i in range(16):workers.append(common.Worker(uid,i))
 assert len({w.pid for w in workers})==16 and all(w.ready['profile']==workers[0].ready['profile'] for w in workers)
 common.write(OUT/'workers.json',dict(pids=[w.pid for w in workers],device=uid,count=16,binarySHA256=manifest['binarySHA256']))
 # Same-input pilot parity before processing any full-bank shard.
 ref=read(OUT/'parity-reference.json');cs=combinations(ref['id']);test=workers[0].run(ref['board'],cs);test['samplingVersion']=VERSION
 for r,c in zip(test['rows'],cs):r['strokeCategory']=c['strokeCategory'];normalize(r)
 validate(test,ref['board'],cs)
 def clean(v):
  if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if k not in ['elapsedSeconds','wallMilliseconds','initialAimMilliseconds','physicsMilliseconds','extractionCompressionMilliseconds','excludedPreContactCushionMetadata']}
  if isinstance(v,list):return [clean(x) for x in v]
  return v
 assert clean(test)==clean(ref),'Pilot parity failed'
 common.write(OUT/'pilot-parity.json',dict(passed=True,id=ref['id'],attempts=125,parametersResultsAndKeypointsExact=True))
 monitor=MemoryMonitor([w.pid for w in workers],[os.getpid()]+[w.p.pid for w in workers],OUT);monitor.start();start=time.monotonic()
 def work(w):
  current=None;result=None
  try:
   while not stop.is_set():
    try:index,indices=pending.get_nowait()
    except queue.Empty:return
    path=OUT/'parts'/f'{index:05d}.jsonl.gz';tmp=path.with_suffix('.partial');st={}
    with gzip.open(tmp,'wt',compresslevel=6) as f:
     for local,bi in enumerate(indices):
      if stop.is_set():return
      current=boards[bi];cs=combinations(current['id']);w.p.stdin.write(json.dumps(dict(board=current,combinations=cs,captureAudit=index*100+local in fixtures),separators=(',',':'))+'\n');w.p.stdin.flush();result=w.receive('RESULT',180);common.checked(result,current,cs);result['samplingVersion']=VERSION;raw=[]
      for r,c in zip(result['rows'],cs):
       r['strokeCategory']=c['strokeCategory'];normalize(r)
       if 'auditFullLine' in r:raw.append(dict(comboIndex=r['comboIndex'],line=r.pop('auditFullLine'),compact=r['trajectory2mm'],cueStop=r['cueStop']))
      validate(result,current,cs)
      if raw:
       with gzip.open(OUT/'audit-paths'/f'{index*100+local:06d}.json.gz','wt') as af:json.dump(dict(id=current['id'],rows=raw),af)
      f.write(json.dumps(result,separators=(',',':'))+'\n');merge(st,stats(result))
    tmp.replace(path);receipt=dict(index=index,layoutIndices=indices,stats=st,sha256=common.sha(path),bytes=path.stat().st_size,binarySHA256=manifest['binarySHA256'])
    common.write(OUT/'receipts'/f'{index:05d}.json',receipt)
    with guard:receipts.append(receipt)
    pending.task_done()
  except BaseException:
   stop.set();common.write(OUT/'failures'/f'{session}-worker-{w.index}.json',dict(board=current,result=result,error=traceback.format_exc()));raise
 with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
  futures=[pool.submit(work,w) for w in workers]
  while not all(f.done() for f in futures):
   failed=[f.exception() for f in futures if f.done() and f.exception()]
   if failed:stop.set();raise failed[0]
   with guard:s=aggregate()
   s.update(state='running',workers=16,elapsedSessionSeconds=time.monotonic()-start,totalLayouts=135700,totalAttempts=16962500,session=session)
   common.write(OUT/'progress.json',s);print('PROGRESS',s.get('layoutCount',0),'/',135700,'seconds',round(s['elapsedSessionSeconds'],1),flush=True)
   concurrent.futures.wait(futures,timeout=10,return_when=concurrent.futures.FIRST_EXCEPTION)
  for f in futures:f.result()
 elapsed=time.monotonic()-start;monitor.stop()
 previous=read(OUT/'run-complete.json') if (OUT/'run-complete.json').exists() else {}
 common.write(OUT/'run-complete.json',dict(state='needs_audit',layoutCount=135700,elapsedComputeAndWriteSeconds=elapsed,elapsedIncludingStartupSeconds=time.monotonic()-startall,session=session,resumedCommittedShards=initialCommitted,receipts=sorted(receipts,key=lambda r:r['index'])))
 common.write(OUT/'progress.json',dict(aggregate(),state='needs_audit',workers=16));print('COMPUTE_DONE',elapsed,flush=True)
except BaseException as e:
 stop.set();failure=dict(error=str(e),traceback=traceback.format_exc(),session=session,time=time.time());common.write(OUT/'failures'/f'{session}.json',failure);common.write(OUT/'failure.json',failure);raise
finally:
 common.write(OUT/'failures'/f'{session}-session-timing.json',dict(session=session,startedAt=started,elapsedIncludingStartupSeconds=time.monotonic()-startall,elapsedComputeAndWriteSeconds=(time.monotonic()-start if 'start' in globals() else 0),completedShards=len(receipts),initialCommittedShards=initialCommitted))
 if monitor:monitor.stop()
 for w in workers:w.close()
 r=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True);common.write(OUT/'cleanup.json',dict(workerExitCodes=[w.p.poll() for w in workers],shutdownExitCode=r.returncode,shutdownError=r.stderr,session=session))
 if r.returncode:raise RuntimeError('Shutdown failed: '+r.stderr)
subprocess.run([sys.executable,str(HERE/'audit.py')],check=True)
plotpy='/Users/song/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3'
subprocess.run([plotpy,str(HERE/'report.py')],env=dict(os.environ,PYTHONPATH='/tmp/codex-angle-density-20261024-deps'),check=True)
print('FULL_RUN_COMPLETE',flush=True)
