from pathlib import Path
import os,sys,json,gzip,time,hashlib,subprocess,multiprocessing,queue,signal,traceback,tempfile,collections,fcntl,shutil
import core as C
from memory import MemoryMonitor
ROOT=C.ROOT;HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name;SOURCE=ROOT/'output/two-ball-p2-60-top5-full-20261025';OLD=ROOT/'output/two-ball-independent125-full-20261024'
read=C.read;sha=C.sha
KEYS=('comboIndex','trialID','strokeCategory','velocity','spinX','spinY','strikeDirection','aimOffsetRadians','cueStop','cueMainRailsAfterContact','cueJawsAfterContact','cueOtherCushionsAfterContact','trajectory2mm','origin')
def encoded(v):return json.dumps(v,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()
def atomic(p,b):
 tmp=p.with_name(p.name+'.tmp');tmp.write_bytes(b);os.replace(tmp,p)
def write(p,v):atomic(p,encoded(v))
def merge(a,b):
 for k,v in b.items():
  if isinstance(v,dict):merge(a.setdefault(k,{}),v)
  else:a[k]=a.get(k,0)+v
 return a

def validate_generated(orig,generated):
 rows={r['comboIndex']:r for r in orig['rows']};keys=set(C.params(r) for r in orig['rows'] if r['status']=='success');counts=collections.Counter()
 for r in generated['rows']:
  assert r['comboIndex'] not in rows and C.params(r) not in keys;keys.add(C.params(r));parent=rows[r['origin']['parentComboIndex']];rows[r['comboIndex']]=r
  dv=abs(r['velocity']-parent['velocity']);dx=abs(r['spinX']-parent['spinX']);dy=abs(r['spinY']-parent['spinY']);stage=r['origin']['stage']
  assert .6<=r['velocity']<=4.5 and r['spinX']**2+r['spinY']**2<=.25+1e-8 and r['directionRetries']==0
  if stage=='removeSideSpin':assert r['spinX']==0 and dv==dy==0 and not C.railseq(parent)
  elif stage=='speed':assert 0<dv<=.200001 and dx==dy==0
  elif stage=='vertical':assert dv<=.100001 and dx==0 and 0<dy<=.060001
  elif stage=='side':assert dv<=.100001 and 0<dx<=.030001 and dy==0 and C.railseq(parent)
  else:raise AssertionError(stage)
  assert ('trajectory2mm' in r)==(r['status']=='success')
  if r['status']=='success':assert r['trajectory2mm']['maxDeviationMeters']<=.002+1e-8
  counts[r['status']]+=1
 return rows,dict(counts)

def compact_and_check(old,new,orig,generated,fullcheck=False):
 allrows,status=validate_generated(orig,generated);st=new['stats'];assert status==st['newSimulationStatus'];assert len(generated['rows'])==st['newSimulationCount'];used=set();stats={'layouts':1,'BPositions':len(new['candidates']),'originalSuccess':st['originalSuccess'],'originalJawOrOther':st['originalJawOrOther'],'zeroSideRequests':st['zeroSideRequests'],'baseRoutes':st['baseCount'],'baseRejected':st['baseRejected'],'newSimulations':len(generated['rows']),'newStatus':status,'summedWorkerSeconds':st['workerSeconds'],'summedLayoutSeconds':st['elapsedSeconds'],'unchangedReplays':int(st['replayExact'] is True),'beforeEligible':0,'baseEligible25':0,'afterEligible':0,'addedByTune':0,'beforeTop':0,'beforeTopWithin25':0,'afterTop':0,'uniqueFinalRoutes':len(new['routes']),'topCountHistogram':{},'railHistogram':{},'categoryHistogram':{},'eligiblePerBHistogram':{},'topAngleMax':{},'checks':{'generatedParameterRows':len(generated['rows']),'eligiblePairs':0,'verifiedTopPairs':st['verifiedTopPairs'],'fullGreedyParity':0,'pilotParity':0}}
 def inc(obj,key):obj[str(key)]=obj.get(str(key),0)+1
 assert len(new['candidates'])==len(old['candidates'])
 for c,o,cs in zip(new['candidates'],old['candidates'],st['candidates'],strict=True):
  assert c['cellID']==o['cellID']==cs['cellID'] and c['position']==o['position'];assert len(c['ranked'])==c['eligibleCount'];assert c['ranked']==sorted(c['ranked'],key=lambda q:(q['score'],q['comboIndex']))
  assert len({q['comboIndex'] for q in c['ranked']})==len(c['ranked'])
  for q in c['ranked']:
   r=allrows[q['comboIndex']];assert C.reason(r) is None
   independent=C.independent_angle(r['cueStop'],c['position'],C.G.anchors()[q['pocket']]);assert independent<=25+1e-8 and abs(independent-q['angle'])<1e-7
   stats['checks']['eligiblePairs']+=1
  for decision in c['refineDecisions']:
   for entry in decision['checks']:
    if entry['reason'] is None:assert C.railseq(allrows[entry['comboIndex']])==decision['expectedMainRails']
  lookup={q['comboIndex']:q for q in c['ranked']}
  for q in c['top5']:
   assert q==lookup[q['comboIndex']];r=allrows[q['comboIndex']];assert C.assess(r,c['position'],new['board'])[1] is None;used.add(q['comboIndex']);inc(stats['railHistogram'],r['cueMainRailsAfterContact']);inc(stats['categoryHistogram'],r['strokeCategory'])
  for key in ['beforeEligible','baseEligible25','afterEligible','addedByTune','beforeTop','beforeTopWithin25'] :stats[key]+=cs[key]
  stats['afterTop']+=len(c['top5']);inc(stats['topCountHistogram'],len(c['top5']));inc(stats['eligiblePerBHistogram'],c['eligibleCount'])
 assert used=={r['comboIndex'] for r in new['routes']}
 if fullcheck:
  subprocess.run([str(HERE/'dedup'),str(C.OUT/'dedup-current-input.json'),str(C.OUT/'full.json'),'--full'],check=True,capture_output=True)
  assert [v['top5'] for v in read(C.OUT/'full.json')['results']]==[[q['comboIndex'] for q in c['top5']] for c in new['candidates']];stats['checks']['fullGreedyParity']=1
 # Compare all original five pilot layouts again using live simulations.
 pilot=next((i+1 for i,r in enumerate(C.D['boards']) if r['id']==new['id']),None)
 if pilot:
  ref=read(ROOT/f'output/two-ball-refine-five-20261025/result-{pilot}.json')
  for a,b in zip(new['candidates'],ref['candidates'],strict=True):assert a['ranked']==b['ranked'] and a['top5']==b['top5']
  for a,b in zip(new['routes'],ref['routes'],strict=True):assert all(a[k]==b[k] for k in KEYS if k in a or k in b)
  stats['checks']['pilotParity']=1
 final={'schema':'two-ball-refined25-p2-60-top5-v1','id':new['id'],'board':new['board'],'simulationSource':old['simulationSource'],'sourceSHA256':st['sourceSHA256'],'validFirstShots':new['validFirstShots'],'candidates':[{k:v for k,v in c.items() if k not in ('ranked','refineDecisions')} for c in new['candidates']],'routes':[{k:r[k] for k in KEYS if k in r} for r in new['routes']],'stats':stats}
 process={'schema':'two-ball-refinement-process-v1','id':new['id'],'board':new['board'],'simulationSource':old['simulationSource'],'sourceSHA256':st['sourceSHA256'],'rows':generated['rows'],'requests':generated['requests'],'candidates':[{'cellID':c['cellID'],'ranked':c['ranked'],'refineDecisions':c['refineDecisions']} for c in new['candidates']],'stats':st}
 return final,process,stats

def work(index,uid,jobs,results,stop,contract):
 worker=None;current=None;session=str(int(time.time()))
 def halt(sig,frame):raise KeyboardInterrupt('worker interrupted')
 signal.signal(signal.SIGTERM,halt)
 try:
  C.common.OUT=OUT;C.common.APP=OLD.parent.parent/'research/two-ball-independent125-full-20261024/Worker.app/Worker'
  worker=C.common.Worker(uid,index);results.put({'kind':'ready','index':index,'pythonPID':os.getpid(),'nativePID':worker.pid,'wrapperPID':worker.p.pid})
  with tempfile.TemporaryDirectory(prefix=f'worker-{index}-',dir=OUT/'tmp') as tmp:
   C.OUT=Path(tmp)
   while not stop.is_set():
    job=jobs.get()
    if job is None:break
    stem=job['stem'];current=stem;oldpath=SOURCE/'parts'/f'{stem}.jsonl.gz';assert sha(oldpath)==job['baselineSHA256'];olds=list(map(json.loads,gzip.decompress(oldpath.read_bytes()).splitlines()));assert len(olds)==job['layouts'];idxs={o['simulationSource']['rowInPart']:o for o in olds};source=ROOT/job['source'];sr=read(OLD/'receipts'/f'{stem}.json');assert sha(source)==sr['sha256'];sourcehash=sr['sha256']
    finalTemp=OUT/'final'/f'{stem}.partial';traceTemp=OUT/'refinement'/f'{stem}.partial';stats={};ids=[];start=time.perf_counter()
    with gzip.open(source,'rt') as sf,gzip.open(finalTemp,'wt',compresslevel=6) as ff,gzip.open(traceTemp,'wt',compresslevel=6) as tf:
     for rowidx,line in enumerate(sf):
      if rowidx not in idxs:continue
      if stop.is_set():return
      orig=json.loads(line);old=idxs[rowidx];assert orig['id']==old['id'];assert len(orig['rows'])==125
      new=C.process(old,worker,'current',orig,sourcehash);generated=read(C.OUT/'generated-current.json');final,trace,st=compact_and_check(old,new,orig,generated,fullcheck=(int(stem)%100==0 or any(p['id']==old['id'] for p in C.D['boards'])))
      ff.write(encoded(final).decode()+'\n');tf.write(encoded(trace).decode()+'\n');merge(stats,st);ids.append(orig['id'])
    assert set(ids)=={o['id'] for o in olds}
    finalPath=OUT/'final'/f'{stem}.jsonl.gz';tracePath=OUT/'refinement'/f'{stem}.jsonl.gz';os.replace(finalTemp,finalPath);os.replace(traceTemp,tracePath)
    receipt={'stem':stem,'contract':contract,'layoutIDs':ids,'source':job['source'],'sourceSHA256':sourcehash,'baselineSHA256':job['baselineSHA256'],'finalSHA256':sha(finalPath),'refinementSHA256':sha(tracePath),'finalBytes':finalPath.stat().st_size,'refinementBytes':tracePath.stat().st_size,'stats':stats,'worker':index,'elapsedSeconds':time.perf_counter()-start}
    write(OUT/'receipts'/f'{stem}.json',receipt);results.put({'kind':'receipt','receipt':receipt})
 except BaseException:
  stop.set();failure={'worker':index,'part':current,'traceback':traceback.format_exc(),'time':time.time()};write(OUT/'failures'/f'{session}-worker-{index}.json',failure);results.put({'kind':'failure','failure':failure});raise
 finally:
  if worker:worker.close();write(OUT/'logs'/f'worker-{index}-closed.json',{'nativePID':worker.pid,'exitCode':worker.p.poll()})

def audit(manifest,receipts):
 start=time.perf_counter();seen=set();stats={};bcount=0;refs=0
 expected={x['id']:x for x in read(ROOT/'output/two-ball-block-sampled-13570-20261025/simulation-index.json')}
 for j,r in enumerate(sorted(receipts,key=lambda x:x['stem'])):
  stem=r['stem'];fp=OUT/'final'/f'{stem}.jsonl.gz';tp=OUT/'refinement'/f'{stem}.jsonl.gz';assert sha(fp)==r['finalSHA256'] and sha(tp)==r['refinementSHA256'];ids=[];localstats={}
  with gzip.open(fp,'rt') as ff,gzip.open(tp,'rt') as tf:
   for fl,tl in zip(ff,tf,strict=True):
    f=json.loads(fl);t=json.loads(tl);assert f['id']==t['id'] and f['id'] not in seen;seen.add(f['id']);ids.append(f['id']);assert f['simulationSource']==expected[f['id']];routes={v['comboIndex']:v for v in f['routes']};used=set();assert len(f['candidates'])==len(t['candidates'])
    for c,tc in zip(f['candidates'],t['candidates'],strict=True):
     assert c['cellID']==tc['cellID'] and c['eligibleCount']==len(tc['ranked']);assert len(c['top5'])<=5;bcount+=1;refs+=len(c['top5'])
     for q in c['top5']:
      route=routes[q['comboIndex']];used.add(q['comboIndex']);assert q in tc['ranked'] and q['angle']<=25
      assert route['cueJawsAfterContact']==route['cueOtherCushionsAfterContact']==0
      if route['cueMainRailsAfterContact']==0:assert route['spinX']==0
      assert C.assess(route,c['position'],f['board'])[1] is None
      assert abs(C.independent_angle(route['cueStop'],c['position'],C.G.anchors()[q['pocket']])-q['angle'])<1e-7
    assert used==set(routes);merge(localstats,f['stats'])
  assert ids==r['layoutIDs'] and localstats==r['stats'];merge(stats,localstats)
  if j%20==0:write(OUT/'audit-progress.json',{'state':'auditing','parts':j+1,'totalParts':len(receipts),'layouts':len(seen),'BPositions':bcount})
 assert seen==set(expected) and len(seen)==13570 and bcount==173577 and refs==stats['afterTop'];assert stats['checks']['pilotParity']==5
 for path,h in manifest['hashes'].items():assert sha(ROOT/path)==h,path
 return stats,time.perf_counter()-start

def main():
 uid=sys.argv[1];manifest=read(OUT/'manifest.json');contract=sha(OUT/'manifest.json');lock=(OUT/'run.lock').open('a');fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
 if (OUT/'summary.json').exists() and read(OUT/'summary.json').get('auditPassed'):raise SystemExit('Already complete')
 for p,h in manifest['hashes'].items():assert sha(ROOT/p)==h,p
 ctx=multiprocessing.get_context('spawn');jobs=ctx.Queue();results=ctx.Queue();stop=ctx.Event();receipts=[];pending=[]
 for job in read(OUT/'schedule.json'):
  rp=OUT/'receipts'/f'{job["stem"]}.json'
  if rp.exists():
   r=read(rp);assert r['contract']==contract and sha(OUT/'final'/f'{job["stem"]}.jsonl.gz')==r['finalSHA256'] and sha(OUT/'refinement'/f'{job["stem"]}.jsonl.gz')==r['refinementSHA256'];receipts.append(r)
  else:pending.append(job)
 for job in pending:jobs.put(job)
 for _ in range(16):jobs.put(None)
 started=time.time();start=time.perf_counter();session=str(int(started));workers=[];monitor=None;ready=[];success=False
 def halt(sig,frame):stop.set();raise KeyboardInterrupt('controller interrupted')
 signal.signal(signal.SIGTERM,halt);signal.signal(signal.SIGINT,halt)
 write(OUT/'execution.json',{'pid':os.getpid(),'started':started,'session':session,'device':uid,'workers':16,'pendingParts':len(pending),'resumedParts':len(receipts),'contract':contract})
 try:
  subprocess.run(['xcrun','simctl','boot',uid],check=True,capture_output=True);subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True,capture_output=True)
  for i in range(16):
   p=ctx.Process(target=work,args=(i,uid,jobs,results,stop,contract));p.start();workers.append(p)
  compute=time.perf_counter();last=0
  while len(receipts)<manifest['parts'] or len(ready)<16:
   try:msg=results.get(timeout=5)
   except queue.Empty:msg=None
   if msg:
    if msg['kind']=='failure':raise RuntimeError(msg['failure']['traceback'])
    if msg['kind']=='ready':
     ready.append(msg)
     if len(ready)==16:
      assert len({r['nativePID'] for r in ready})==16;write(OUT/'workers.json',{'count':16,'device':uid,'workers':ready})
      monitor=MemoryMonitor([r['nativePID'] for r in ready],[os.getpid()]+[v for r in ready for v in (r['pythonPID'],r['wrapperPID'])],OUT);monitor.start()
    if msg['kind']=='receipt':receipts.append(msg['receipt'])
   if any(p.exitcode not in (None,0) for p in workers):raise RuntimeError('Worker exited abnormally')
   if time.perf_counter()-last>=10:
    sums={}
    for r in receipts:merge(sums,r['stats'])
    sums.update(state='running',completedParts=len(receipts),totalParts=manifest['parts'],totalLayouts=13570,totalBPositions=173577,elapsedSessionSeconds=time.perf_counter()-compute,workers=len(ready));write(OUT/'progress.json',sums);print('PROGRESS',sums.get('layouts',0),sums.get('BPositions',0),round(sums['elapsedSessionSeconds'],1),flush=True);last=time.perf_counter()
  for p in workers:p.join(60);assert p.exitcode==0
  elapsed=time.perf_counter()-compute;write(OUT/'run-complete.json',{'state':'needs_audit','session':session,'computeAndWriteSeconds':elapsed,'startupComputeSeconds':time.perf_counter()-start,'resumedParts':manifest['parts']-len(pending)});write(OUT/'parts-index.json',sorted(receipts,key=lambda r:r['stem']));success=True
 except BaseException:
  stop.set();v={'session':session,'time':time.time(),'traceback':traceback.format_exc()};write(OUT/'failures'/f'{session}.json',v);write(OUT/'failure.json',v);raise
 finally:
  stop.set()
  for p in workers:
   if p.is_alive():p.terminate()
  for p in workers:p.join(60)
  if monitor:monitor.stop()
  assert all(not p.is_alive() for p in workers),'Some workers still alive; refuse device shutdown'
  closed=[read(OUT/'logs'/f'worker-{i}-closed.json') for i in range(16) if (OUT/'logs'/f'worker-{i}-closed.json').exists()]
  shut=subprocess.run(['xcrun','simctl','shutdown',uid],capture_output=True,text=True);write(OUT/'cleanup.json',{'workerExitCodes':[p.exitcode for p in workers],'nativeClosed':closed,'shutdownExitCode':shut.returncode,'shutdownError':shut.stderr,'session':session,'elapsedSeconds':time.perf_counter()-start});write(OUT/'sessions'/f'{session}.json',{'computeCompleted':success,'elapsedSeconds':time.perf_counter()-start,'committedParts':len(receipts),'started':started});assert shut.returncode==0
 write(OUT/'progress.json',{'state':'auditing','layouts':13570,'BPositions':173577});stats,auditSeconds=audit(manifest,receipts)
 summary={'state':'complete','auditPassed':True,'stats':stats,'workers':16,'computeAndWriteSeconds':elapsed,'auditSeconds':auditSeconds,'startupThroughAuditSeconds':time.perf_counter()-start,'finalGzipBytes':sum(r['finalBytes'] for r in receipts),'refinementGzipBytes':sum(r['refinementBytes'] for r in receipts),'parts':len(receipts),'contract':contract,'completedAt':time.time()}
 write(OUT/'summary.json',summary);write(OUT/'progress.json',{'state':'complete','layouts':13570,'BPositions':173577});subprocess.run([sys.executable,str(HERE/'report.py')],check=True);print('COMPLETE',flush=True)
if __name__=='__main__':
 try:main()
 except BaseException:
  v={'time':time.time(),'traceback':traceback.format_exc(),'pid':os.getpid()}
  if (OUT/'failures').exists():
   write(OUT/'failures'/f'controller-{time.time_ns()}.json',v);write(OUT/'failure.json',v)
  raise
