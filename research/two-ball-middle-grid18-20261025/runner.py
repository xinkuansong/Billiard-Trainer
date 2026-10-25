from pathlib import Path
import argparse,collections,fcntl,gzip,json,multiprocessing,os,queue,signal,subprocess,sys,tempfile,time,traceback
import pipeline as P
from memory import MemoryMonitor
ROOT=P.ROOT;HERE=P.HERE

def worker(index,uid,stage,out,jobs,results,stop,contract):
 w=None;stem=None
 def halt(sig,frame):raise KeyboardInterrupt('worker interrupted')
 signal.signal(signal.SIGTERM,halt)
 try:
  P.common.OUT=out;P.common.APP=HERE/'Worker.app/Worker';w=P.common.Worker(uid,index)
  results.put({'kind':'ready','index':index,'nativePID':w.pid,'wrapperPID':w.p.pid,'pythonPID':os.getpid()})
  with tempfile.TemporaryDirectory(prefix=f'w{index}-',dir=out/'tmp') as td:
   for job in iter(jobs.get,None):
    if stop.is_set():break
    stem=job['stem'];src=Path(job['source']);assert P.sha(src)==job['sourceSHA256'];rows=[json.loads(s) for s in gzip.decompress(src.read_bytes()).splitlines()]
    if 'layoutIDs' in job:rows=[r for r in rows if r['id'] in job['layoutIDs']]
    oldproof={}
    if stage=='b':
     pp=Path(job['proofs']);assert P.sha(pp)==job['proofsSHA256'];oldproof={r['id']:r for r in (json.loads(l) for l in gzip.decompress(pp.read_bytes()).splitlines())}
    total={};ids=[];t=time.perf_counter();fp=out/'parts'/f'{stem}.partial';tp=out/'proofs'/f'{stem}.partial'
    with gzip.open(fp,'wb',compresslevel=6) as ff,gzip.open(tp,'wb',compresslevel=6) as tf:
     for row in rows:
      if stop.is_set():return
      if stage=='b':row['_middleProofs']=oldproof[row['id']]['middleProofs']
      f,proof,st=(P.stage_a if stage=='a' else P.stage_b)(row,w,Path(td))
      check(row,f,proof,stage,oldproof.get(row['id']))
      ff.write(P.enc(f)+b'\n');tf.write(P.enc(proof)+b'\n');P.merge(total,st);ids.append(f['id'])
      results.put({'kind':'layout','worker':index,'id':f['id'],'stage':stage,'seconds':st['layoutSeconds'],'newSimulations':st.get('newSimulations',0)})
    final=fp.with_name(stem+'.jsonl.gz');trace=tp.with_name(stem+'.jsonl.gz');fp.replace(final);tp.replace(trace)
    receipt={'stem':stem,'contract':contract,'sourceSHA256':job['sourceSHA256'],'layoutIDs':ids,'finalSHA256':P.sha(final),'proofsSHA256':P.sha(trace),'finalBytes':final.stat().st_size,'proofBytes':trace.stat().st_size,'stats':total,'seconds':time.perf_counter()-t}
    P.write(out/'receipts'/f'{stem}.json',receipt);results.put({'kind':'receipt','receipt':receipt})
 except BaseException:
  stop.set();e={'worker':index,'part':stem,'time':time.time(),'traceback':traceback.format_exc()};P.write(out/'failures'/f'worker-{index}-{time.time_ns()}.json',e);results.put({'kind':'failure','error':e});raise
 finally:
  if w:w.close();P.write(out/'logs'/f'worker-{index}-closed.json',{'nativePID':w.pid,'exitCode':w.p.poll()})

def check(old,f,t,stage,priorProof=None):
 assert f['id']==old['id']==t['id'] and f['board']==old['board'];assert len(f['candidates'])==len(old['candidates'])
 routes={r['comboIndex']:r for r in f['routes']};used=set();proofs={p['key']:p for p in (priorProof or {}).get('middleProofs',[])+t['middleProofs']}
 for p in proofs.values():
  assert p['passed']==any(v['passed'] for v in p['trials'])
  for v in p['trials']:
   if v['passed']:assert v['settled'] and not v['cuePocketed'] and v['route']=='direct-pot' and any(e['kind']=='pocket' and e['ball']=='object' and e['pocketID']==f"pocket_{p['request']['pocket']}" for e in v['events'])
 for c,o in zip(f['candidates'],old['candidates'],strict=True):
  assert c['cellID']==o['cellID'] and c['position']==o['position'] and len(c['top5'])<=5
  for q in c['top5']:
   r=routes[q['comboIndex']];used.add(q['comboIndex']);P.seq(r)
   assert r['cueJawsAfterContact']==r['cueOtherCushionsAfterContact']==0
   if not P.seq(r):assert r['spinX']==0
   if q['pocket'] in (4,5):
    pr=proofs[q['middleProofKey']];assert pr['passed'] and pr['request']['cue']==r['cueStop'] and pr['request']['object']==c['position'] and pr['request']['pocket']==q['pocket']
   if stage=='a':assert {k:v for k,v in q.items() if k!='middleProofKey'} in o['top5']
   else:
    assert q['angle']<=18;opts,why=P.candidate_options(r,c['position'],f['board']);assert not why and any(abs(v['score']-q['score'])<1e-10 and v['pocket']==q['pocket'] for v in opts)
    assert abs(P.C.independent_angle(r['cueStop'],c['position'],P.C.G.anchors()[q['pocket']])-q['angle'])<1e-7
  if stage=='a':assert [q for q in c['top5'] if q['pocket']<4]==[q for q in o['top5'] if q['pocket']<4]
 assert used==set(routes)
 if stage=='a':
  assert sum(len(c['top5']) for c in old['candidates'])==sum(len(c['top5']) for c in f['candidates'])+len(t['deleted'])
  for d in t['deleted']:assert not proofs[d['proofKey']]['passed']
  oldroutes={r['comboIndex']:r for r in old['routes']}
  assert all(r==oldroutes[i] for i,r in routes.items())
 else:
  roots={r['comboIndex']:r for r in t['roots']};trials={v['comboIndex']:v for v in t['gridTrials']};validParams={}
  for root in roots.values():
   keys,_=P.grid(root)
   for key in keys:validParams.setdefault(key,set()).add(root['comboIndex'])
  for trial in trials.values():assert tuple(trial['parameters']) in validParams
  for c,dec in zip(f['candidates'],t['candidates'],strict=True):
   assert c['cellID']==dec['cellID'];ranked=dec['ranked'];assert ranked==sorted(ranked,key=lambda q:(q['score'],q['comboIndex']))
   for ch in dec['roots']:
    assert sum(ch['beforeScoringRejected'].values())+len(ch['statePreservingVariants'])==245
    assert ch['optimal']==next((q for q in ranked if ch['rootComboIndex'] in q['rootComboIndices']),None)
    for i in ch['statePreservingVariants']:
     got=P.seq(roots[i]) if i in roots else tuple(trials[i]['railSequence']);assert got==tuple(ch['expectedRails'])
   for q in c['top5']:
    assert q in ranked
    for parent in q['rootComboIndices']:
     assert parent in {v['comboIndex'] for v in old['candidates'][f['candidates'].index(c)]['top5']}
     assert P.seq(routes[q['comboIndex']])==P.seq(roots[parent])
     assert P.C.params(routes[q['comboIndex']]) in P.grid(roots[parent])[0]


def schedule(stage,pilot):
 source=P.SOURCE if stage=='a' else P.A;jobs=[]
 for rp in sorted((source/'receipts').glob('*.json')):
  r=P.read(rp);stem=rp.stem;src=source/('final' if stage=='a' else 'parts')/f'{stem}.jsonl.gz'
  job={'stem':stem,'source':str(src),'sourceSHA256':r['finalSHA256']}
  if stage=='b':job.update(proofs=str(source/'proofs'/f'{stem}.jsonl.gz'),proofsSHA256=r['proofsSHA256'])
  jobs.append(job)
  if pilot and len(jobs)>=pilot:break
 return jobs

def main():
 ap=argparse.ArgumentParser();ap.add_argument('uid');ap.add_argument('--stage',choices=['a','b'],required=True);ap.add_argument('--pilot',type=int,default=0);ap.add_argument('--workers',type=int,default=16);args=ap.parse_args();stage=args.stage
 out=(P.A if stage=='a' else P.B)
 if args.pilot:out=out/f'pilot-{args.pilot}'
 for name in ('parts','proofs','receipts','logs','failures','tmp'): (out/name).mkdir(parents=True,exist_ok=True)
 lock=(out/'run.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 if (out/'summary.json').exists() and P.read(out/'summary.json').get('auditPassed'):raise RuntimeError('Already complete; do not duplicate')
 jobspec=schedule(stage,args.pilot)
 if not args.pilot:
  assert len(jobspec)==1357
  sourceSummary=P.read((P.SOURCE if stage=='a' else P.A)/'summary.json');assert sourceSummary['state']=='complete' and sourceSummary['auditPassed']
 hashes={str(p.relative_to(ROOT)):P.sha(p) for p in [HERE/'pipeline.py',HERE/'runner.py',HERE/'main.swift',HERE/'Worker.app/Worker',ROOT/'research/two-ball-refine-full-20261025/dedup',ROOT/'research/two-ball-refine-full-20261025/core.py',ROOT/'research/two-ball-independent125-full-20261024/contract.py',ROOT/'research/two-ball-independent125-full-20261024/runtime_common.py',ROOT/'scripts/training-question-bank/filter_second_ball_preview.py',ROOT/'scripts/training-question-bank/pocket_geometry_filter.py']}
 manifest={'policy':P.POLICY,'stage':stage,'hashes':hashes,'schedule':jobspec,'workers':args.workers,'pilotParts':args.pilot}
 if (out/'manifest.json').exists():assert P.read(out/'manifest.json')==manifest,'Frozen manifest mismatch'
 else:P.write(out/'manifest.json',manifest)
 contract=P.sha(out/'manifest.json');receipts=[];pending=[]
 for job in jobspec:
  rp=out/'receipts'/f'{job["stem"]}.json'
  if rp.exists():
   r=P.read(rp);assert r['contract']==contract and P.sha(out/'parts'/f'{job["stem"]}.jsonl.gz')==r['finalSHA256'] and P.sha(out/'proofs'/f'{job["stem"]}.jsonl.gz')==r['proofsSHA256'];receipts.append(r)
  else:pending.append(job)
 ctx=multiprocessing.get_context('spawn');jobs=ctx.Queue();results=ctx.Queue();stop=ctx.Event();workers=[];ready=[];monitor=None;started=time.time();start=time.perf_counter();booted=False
 for job in pending:jobs.put(job)
 for _ in range(args.workers):jobs.put(None)
 def halt(sig,frame):stop.set();raise KeyboardInterrupt('controller interrupted')
 signal.signal(signal.SIGTERM,halt);signal.signal(signal.SIGINT,halt)
 P.write(out/'execution.json',{'pid':os.getpid(),'started':started,'device':args.uid,'workers':args.workers,'pendingParts':len(pending),'contract':contract})
 try:
  subprocess.run(['xcrun','simctl','boot',args.uid],check=True,capture_output=True);booted=True;subprocess.run(['xcrun','simctl','bootstatus',args.uid,'-b'],check=True,capture_output=True)
  for i in range(args.workers):
   p=ctx.Process(target=worker,args=(i,args.uid,stage,out,jobs,results,stop,contract));p.start();workers.append(p)
  compute=time.perf_counter();last=0;live={}
  while len(receipts)<len(jobspec) or len(ready)<args.workers:
   try:msg=results.get(timeout=5)
   except queue.Empty:msg=None
   if msg:
    if msg['kind']=='failure':raise RuntimeError(msg['error']['traceback'])
    if msg['kind']=='ready':
     ready.append(msg);P.write(out/'workers.json',{'workers':ready})
     if len(ready)==args.workers:monitor=MemoryMonitor([r['nativePID'] for r in ready],[os.getpid()]+[r['pythonPID'] for r in ready],out);monitor.start()
    if msg['kind']=='receipt':receipts.append(msg['receipt'])
    if msg['kind']=='layout':live[str(msg['worker'])]=msg
   if any(p.exitcode not in (None,0) for p in workers):raise RuntimeError('Worker failed')
   if time.perf_counter()-last>=10:
    stats={}
    for r in receipts:P.merge(stats,r['stats'])
    P.write(out/'progress.json',{'state':'running','stage':stage,'parts':len(receipts),'totalParts':len(jobspec),'stats':stats,'live':live,'elapsedSeconds':time.perf_counter()-compute});print('PROGRESS',stage,len(receipts),stats.get('layouts',0),round(time.perf_counter()-compute,1),flush=True);last=time.perf_counter()
  for p in workers:p.join(60);assert p.exitcode==0
  elapsed=time.perf_counter()-compute;P.write(out/'run-complete.json',{'computeAndWriteSeconds':elapsed,'needsAudit':True})
 except BaseException:
  fail={'time':time.time(),'traceback':traceback.format_exc()};P.write(out/'failure.json',fail);P.write(out/'failures'/f'controller-{time.time_ns()}.json',fail);raise
 finally:
  stop.set()
  for p in workers:
   if p.is_alive():p.terminate()
  for p in workers:p.join(30)
  if monitor:monitor.stop()
  assert all(not p.is_alive() for p in workers)
  shut=subprocess.run(['xcrun','simctl','shutdown',args.uid],capture_output=True,text=True) if booted else None
  P.write(out/'cleanup.json',{'workerExitCodes':[p.exitcode for p in workers],'nativeClosed':[P.read(out/'logs'/f'worker-{i}-closed.json') for i in range(args.workers) if (out/'logs'/f'worker-{i}-closed.json').exists()],'shutdownExitCode':shut.returncode if shut else None,'shutdownError':shut.stderr if shut else None})
  if shut:assert shut.returncode==0
 # Independent complete readback, including every source/final/proof SHA and state gate.
 auditStart=time.perf_counter();stats={};seen=set();byStem={r['stem']:r for r in receipts}
 for n,job in enumerate(jobspec):
  r=byStem[job['stem']];assert P.sha(Path(job['source']))==job['sourceSHA256'];fp=out/'parts'/f'{r["stem"]}.jsonl.gz';tp=out/'proofs'/f'{r["stem"]}.jsonl.gz';assert P.sha(fp)==r['finalSHA256'] and P.sha(tp)==r['proofsSHA256']
  oldrows=[json.loads(l) for l in gzip.decompress(Path(job['source']).read_bytes()).splitlines()];prior={}
  if stage=='b':
   assert P.sha(Path(job['proofs']))==job['proofsSHA256'];prior={v['id']:v for v in (json.loads(l) for l in gzip.decompress(Path(job['proofs']).read_bytes()).splitlines())}
  ids=[];local={}
  with gzip.open(fp,'rt') as ff,gzip.open(tp,'rt') as tf:
   for o,fl,tl in zip(oldrows,ff,tf,strict=True):
    f=json.loads(fl);t=json.loads(tl);assert f['id'] not in seen;seen.add(f['id']);ids.append(f['id']);check(o,f,t,stage,prior.get(f['id']));P.merge(local,f['stats'])
  assert local==r['stats'] and ids==r['layoutIDs'];P.merge(stats,local)
  if n%20==0:P.write(out/'audit-progress.json',{'state':'auditing','parts':n+1,'layouts':len(seen),'stats':stats})
 if not args.pilot:
  assert len(seen)==13570 and stats['BPositions']==173577
  if stage=='a':assert stats['beforeTop']==816076
 for p,h in hashes.items():assert P.sha(ROOT/p)==h
 summary={'state':'complete','auditPassed':True,'stage':stage,'pilotParts':args.pilot,'stats':stats,'workers':args.workers,'computeAndWriteSeconds':elapsed,'auditSeconds':time.perf_counter()-auditStart,'startupThroughAuditSeconds':time.perf_counter()-start,'finalGzipBytes':sum(r['finalBytes'] for r in receipts),'proofGzipBytes':sum(r['proofBytes'] for r in receipts),'contract':contract,'completedAt':time.time()}
 P.write(out/'parts-index.json',receipts);P.write(out/'summary.json',summary);P.write(out/'progress.json',summary);print('COMPLETE',json.dumps(summary),flush=True)
if __name__=='__main__':main()
