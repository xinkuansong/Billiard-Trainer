"""16 native workers; atomic dual gzip receipts; SHA-based resume; full audit."""
from pathlib import Path
import argparse,fcntl,gzip,json,multiprocessing,os,queue,shutil,signal,subprocess,tempfile,time,traceback
import engine as E
from memory import MemoryMonitor

def readrows(p):return [json.loads(l) for l in gzip.decompress(Path(p).read_bytes()).splitlines()]
def worker(index,uid,jobs,results,stop,contract):
 w=None;stem=None
 def halt(sig,frame):raise KeyboardInterrupt('worker interrupted')
 signal.signal(signal.SIGTERM,halt)
 try:
  E.common.OUT=E.OUT;E.common.APP=E.APP;w=E.common.Worker(uid,index)
  results.put(dict(kind='ready',index=index,nativePID=w.pid,wrapperPID=w.p.pid,pythonPID=os.getpid()))
  with tempfile.TemporaryDirectory(prefix=f'w{index}-',dir=E.OUT/'tmp') as td:
   for job in iter(jobs.get,None):
    if stop.is_set():break
    if shutil.disk_usage(E.OUT).free<4*1024**3:raise RuntimeError('Disk reserve reached: retain evidence and resume after space is available; no files deleted')
    stem=job['stem'];assert E.sha(Path(job['source']))==job['sourceSHA256'] and E.sha(Path(job['scores']))==job['scoresSHA256']
    rows=readrows(job['source']);scores=readrows(job['scores']);ids=[];stats={};t=time.perf_counter()
    fp=E.OUT/'final'/f'{stem}.partial';tp=E.OUT/'refinement'/f'{stem}.partial'
    with gzip.open(fp,'wb',compresslevel=9) as ff,gzip.open(tp,'wb',compresslevel=9) as tf:
     for old,sc in zip(rows,scores,strict=True):
      if stop.is_set():return
      f,trace,st=E.process(old,sc,w,Path(td));E.verify(old,sc,f,trace,Path(td))
      ff.write(E.enc(f)+b'\n');tf.write(E.enc(trace)+b'\n');ids.append(old['id']);E.merge(stats,st)
      results.put(dict(kind='layout',worker=index,id=old['id'],seconds=st['layoutSeconds'],newSimulations=st['newSimulations']))
    assert ids==job['layoutIDs']
    final=E.OUT/'final'/f'{stem}.jsonl.gz';proof=E.OUT/'refinement'/f'{stem}.jsonl.gz';fp.replace(final);tp.replace(proof)
    receipt=dict(stem=stem,contract=contract,sourceSHA256=job['sourceSHA256'],scoresSHA256=job['scoresSHA256'],layoutIDs=ids,finalSHA256=E.sha(final),refinementSHA256=E.sha(proof),finalBytes=final.stat().st_size,refinementBytes=proof.stat().st_size,stats=stats,seconds=time.perf_counter()-t)
    E.write(E.OUT/'receipts'/f'{stem}.json',receipt);results.put(dict(kind='receipt',receipt=receipt))
 except BaseException:
  stop.set();error=dict(worker=index,stem=stem,time=time.time(),traceback=traceback.format_exc());E.write(E.OUT/'failures'/f'worker-{index}-{time.time_ns()}.json',error);results.put(dict(kind='failure',error=error));raise
 finally:
  if w:w.close();E.write(E.OUT/'logs'/f'worker-{index}-closed.json',dict(nativePID=w.pid,exitCode=w.p.returncode))

def audit(jobs,receipts,pilot):
 t=time.perf_counter();stats={};seen=set();bseen=set();byStem={r['stem']:r for r in receipts}
 with tempfile.TemporaryDirectory(prefix='audit-',dir=E.OUT/'tmp') as td:
  for n,job in enumerate(jobs):
   r=byStem[job['stem']];fp=E.OUT/'final'/f'{job["stem"]}.jsonl.gz';tp=E.OUT/'refinement'/f'{job["stem"]}.jsonl.gz'
   assert E.sha(Path(job['source']))==r['sourceSHA256']==job['sourceSHA256'] and E.sha(Path(job['scores']))==r['scoresSHA256']==job['scoresSHA256']
   assert E.sha(fp)==r['finalSHA256'] and E.sha(tp)==r['refinementSHA256']
   local={};ids=[]
   with gzip.open(fp,'rt') as ff,gzip.open(tp,'rt') as tf:
    for old,sc,fl,tl in zip(readrows(job['source']),readrows(job['scores']),ff,tf,strict=True):
     out=json.loads(fl);tr=json.loads(tl);assert old['id'] not in seen;seen.add(old['id']);ids.append(old['id'])
     E.verify(old,sc,out,tr,Path(td),deep=True)
     st=out['comfortRefinementStats'];assert st==tr['stats']
     assert st['beforeRecommendations']==sum(len(c['top5']) for c in old['candidates'])
     assert st['afterRecommendations']==sum(len(c['top5']) for c in out['candidates'])
     assert st['afterQualified']==sum(q['comfort']['totalScore']>=85 for c in out['candidates'] for q in c['top5'])
     assert st['lowRecommendations']==st['optimizedQualified']+st['failedKeepOriginal']
     for c in out['candidates']:
      k=(out['id'],c['cellID']);assert k not in bseen;bseen.add(k)
     E.merge(local,st)
   assert ids==r['layoutIDs'] and local==r['stats'];E.merge(stats,local)
   if n%10==0:E.write(E.OUT/'audit-progress.json',dict(state='auditing',pilot=pilot,parts=n+1,totalParts=len(jobs),layouts=len(seen),BPositions=len(bseen),seconds=time.perf_counter()-t))
 if not pilot:
  assert (len(seen),len(bseen),stats['beforeRecommendations'],stats['lowRecommendations'],stats['beforeQualified'])==(13570,173577,765246,222917,542329)
  assert stats['originalQualifiedDedupRemoved']==0 and stats['afterValidB']==167122 and stats['afterQualifiedB']>=stats['beforeQualifiedB']
 return stats,time.perf_counter()-t

def main():
 ap=argparse.ArgumentParser();ap.add_argument('uid');ap.add_argument('--pilot',action='store_true');args=ap.parse_args()
 for name in ['final','refinement','receipts','logs','failures','tmp','runs']:(E.OUT/name).mkdir(exist_ok=True)
 lock=(E.OUT/'run.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 manifest=E.read(E.OUT/'manifest.json');contract=E.sha(E.OUT/'manifest.json')
 for p,h in manifest['hashes'].items():assert E.sha(Path(p))==h,'Contract hash drift '+p
 if (E.OUT/'summary.json').exists() and E.read(E.OUT/'summary.json').get('auditPassed'):raise RuntimeError('Already complete')
 selected={'00000','00001','00002','00817','00337','00618','00831','00077'}
 jobspec=[j for j in manifest['schedule'] if not args.pilot or j['stem'] in selected];pending=[];receipts=[]
 for job in jobspec:
  rp=E.OUT/'receipts'/f'{job["stem"]}.json'
  if rp.exists():
   r=E.read(rp);assert r['contract']==contract and E.sha(E.OUT/'final'/f'{job["stem"]}.jsonl.gz')==r['finalSHA256'] and E.sha(E.OUT/'refinement'/f'{job["stem"]}.jsonl.gz')==r['refinementSHA256'];receipts.append(r)
  else:pending.append(job)
 ctx=multiprocessing.get_context('spawn');jobs=ctx.Queue();results=ctx.Queue();stop=ctx.Event();workers=[];ready=[];monitor=None;booted=False;start=time.perf_counter();started=time.time();last=0;live={}
 for job in pending:jobs.put(job)
 for _ in range(16):jobs.put(None)
 def halt(sig,frame):stop.set();raise KeyboardInterrupt('controller interrupted')
 signal.signal(signal.SIGTERM,halt);signal.signal(signal.SIGINT,halt)
 execution=dict(pid=os.getpid(),startedAt=started,device=args.uid,workers=16,pendingParts=len(pending),pilot=args.pilot,contract=contract)
 E.write(E.OUT/'execution.json',execution);E.write(E.OUT/'runs'/f'{int(started)}-execution.json',execution)
 try:
  if pending:
   subprocess.run(['xcrun','simctl','boot',args.uid],check=True,capture_output=True);booted=True;subprocess.run(['xcrun','simctl','bootstatus',args.uid,'-b'],check=True,capture_output=True)
   for i in range(16):
    p=ctx.Process(target=worker,args=(i,args.uid,jobs,results,stop,contract));p.start();workers.append(p)
  compute=time.perf_counter()
  while len(receipts)<len(jobspec) or (pending and len(ready)<16):
   try:msg=results.get(timeout=5)
   except queue.Empty:msg=None
   if msg:
    if msg['kind']=='failure':raise RuntimeError(msg['error']['traceback'])
    if msg['kind']=='ready':
     ready.append(msg);E.write(E.OUT/'workers.json',dict(workers=ready,pilot=args.pilot))
     if len(ready)==16:monitor=MemoryMonitor([x['nativePID'] for x in ready],[os.getpid()]+[x['pythonPID'] for x in ready],E.OUT);monitor.start()
    if msg['kind']=='receipt':receipts.append(msg['receipt'])
    if msg['kind']=='layout':live[str(msg['worker'])]=msg
   if any(p.exitcode not in (None,0) for p in workers):raise RuntimeError('Worker failed')
   if time.perf_counter()-last>=10:
    st={}
    for r in receipts:E.merge(st,r['stats'])
    E.write(E.OUT/'progress.json',dict(state='running',pilot=args.pilot,parts=len(receipts),totalParts=len(jobspec),stats=st,live=live,elapsedSeconds=time.perf_counter()-compute,freeDiskBytes=shutil.disk_usage(E.OUT).free));print('PROGRESS',len(receipts),st.get('layouts',0),round(time.perf_counter()-compute),flush=True);last=time.perf_counter()
  for p in workers:p.join(60);assert p.exitcode==0
  elapsed=time.perf_counter()-compute
 except BaseException:
  fail=dict(time=time.time(),traceback=traceback.format_exc());E.write(E.OUT/'failure.json',fail);E.write(E.OUT/'failures'/f'controller-{time.time_ns()}.json',fail);raise
 finally:
  stop.set()
  for p in workers:
   if p.is_alive():p.terminate()
  for p in workers:p.join(30)
  if monitor:monitor.stop()
  shut=subprocess.run(['xcrun','simctl','shutdown',args.uid],capture_output=True,text=True) if booted else None
  cleanup=dict(workerExitCodes=[p.exitcode for p in workers],nativeClosed=[E.read(E.OUT/'logs'/f'worker-{i}-closed.json') for i in range(16) if (E.OUT/'logs'/f'worker-{i}-closed.json').exists()],shutdownExitCode=shut.returncode if shut else None)
  E.write(E.OUT/'cleanup.json',cleanup);E.write(E.OUT/'runs'/f'{int(started)}-cleanup.json',cleanup)
  if shut:assert shut.returncode==0
 stats,auditSeconds=audit(jobspec,receipts,args.pilot)
 for p,h in manifest['hashes'].items():assert E.sha(Path(p))==h
 summary=dict(state='pilot-complete' if args.pilot else 'complete',auditPassed=True,pilot=args.pilot,stats=stats,workers=16,computeAndWriteSeconds=elapsed,auditSeconds=auditSeconds,startupThroughAuditSeconds=time.perf_counter()-start,finalGzipBytes=sum(r['finalBytes'] for r in receipts),refinementGzipBytes=sum(r['refinementBytes'] for r in receipts),contract=contract,completedAt=time.time())
 E.write(E.OUT/('pilot-summary.json' if args.pilot else 'summary.json'),summary);E.write(E.OUT/('pilot-parts-index.json' if args.pilot else 'parts-index.json'),receipts);E.write(E.OUT/'progress.json',summary)
 if not args.pilot:
  report=E.load('comfort_full_report',E.HERE/'report.py');report.main()
 print('COMPLETE',json.dumps(summary),flush=True)
if __name__=='__main__':
 try:main()
 except BaseException:
  fail=dict(time=time.time(),traceback=traceback.format_exc());E.write(E.OUT/'failure.json',fail);raise
