"""Eight native workers; audit before atomic compression/checkpoint; pilot then full."""
from pathlib import Path
import json,gzip,hashlib,subprocess,sys,time,os,shutil,collections
from audit import audit,rail_sequences
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;OUT=ROOT/'output'/HERE.name
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def atomic(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':')));tmp.replace(p)
def phase(name,questions,uid,binary,identity):
 folder=OUT/name;folder.mkdir(exist_ok=True);store=folder/'records';store.mkdir(exist_ok=True)
 completed={};lookup={q['id']:q for q in questions};pending=set(lookup)
 for qid in list(pending):
  cp=store/(qid+'.checkpoint.json');gz=store/(qid+'.json.gz')
  if cp.exists():
   c=json.loads(cp.read_bytes());assert c['identity']==identity and sha(gz)==c['sha256'],'Checkpoint mismatch'
   payload=json.loads(gzip.decompress(gz.read_bytes()));summary=audit(payload['record'],payload['metrics'],lookup[qid],identity)
   assert summary==c['summary'];completed[qid]=summary;pending.remove(qid)
 initialCompleted=len(completed)
 processes=[];logs=[];active={};started=time.time()
 try:
  for i in range(8):
   work=folder/f'worker-{i}';work.mkdir(exist_ok=True)
   qs=[q for j,q in enumerate(questions) if j%8==i and q['id'] in pending]
   atomic(work/'inputs.json',qs);(work/'identity.txt').write_text(identity)
   # Completed raw folders are accepted only after the final checkpoint was audited.
   for q in qs:
    cp=work/'cases'/q['id']/'complete.json'
    if cp.exists():
     c=json.loads(cp.read_bytes());assert c['identity']==identity
   log=(work/'run.log').open('a');logs.append(log)
   p=subprocess.Popen(['xcrun','simctl','spawn',uid,binary,str(work)],stdout=log,stderr=subprocess.STDOUT)
   processes.append((work,p));active.update({q['id']:work/'cases'/q['id'] for q in qs})
  while True:
   for qid,d in list(active.items()):
    if not (d/'complete.json').exists():continue
    record=json.loads((d/'result.json').read_bytes());metrics=json.loads((d/'candidate-metrics.json').read_bytes())
    summary=audit(record,metrics,lookup[qid],identity)
    payload=json.dumps({'record':record,'metrics':metrics},separators=(',',':')).encode()
    gz=store/(qid+'.json.gz');tmp=gz.with_suffix('.tmp');tmp.write_bytes(gzip.compress(payload,compresslevel=6,mtime=0))
    assert gzip.decompress(tmp.read_bytes())==payload;tmp.replace(gz)
    atomic(store/(qid+'.checkpoint.json'),{'identity':identity,'sha256':sha(gz),'summary':summary})
    completed[qid]=summary;active.pop(qid)
    # Only remove this task's raw files after an independently audited, roundtrip-checked archive.
    for f in ['complete.json','result.json','candidate-metrics.json']:(d/f).unlink()
    d.rmdir()
   rows=list(completed.values());state='running' if any(p.poll() is None for _,p in processes) else 'workers-finished'
   status=dict(state=state,phase=name,completed=len(rows),total=len(questions),initialCompleted=initialCompleted,newlyCompleted=len(rows)-initialCompleted,multi=sum(r['admitted'] for r in rows),single=sum(r['retained']==1 for r in rows),noSolution=sum(r['retained']==0 for r in rows),routes=sum(r['retained'] for r in rows),elapsedSeconds=time.time()-started,updatedAt=time.time(),workers=[dict(pid=p.pid,exitCode=p.poll()) for _,p in processes])
   atomic(OUT/'status.json',status)
   if all(p.poll() is not None for _,p in processes):break
   if any(p.poll() not in (None,0) for _,p in processes):raise RuntimeError('Worker failed; inspect per-worker logs')
   if shutil.disk_usage(OUT).free<8*1024**3:raise RuntimeError('Less than 8 GiB available; preserved checkpoints')
   time.sleep(5)
  assert all(p.returncode==0 for _,p in processes) and not active and len(completed)==len(questions)
  atomic(folder/'summary.json',dict(complete=True,identity=identity,counts=status,questions=[completed[q['id']] for q in questions]))
  return completed
 finally:
  for _,p in processes:
   if p.poll() is None:p.terminate()
  for _,p in processes:
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:p.kill();p.wait()
  for log in logs:log.close()
def package(questions,identity):
 store=OUT/'full/records';dest=OUT/'candidate-package';dest.mkdir(exist_ok=True)
 admitted=[];ledgers={'multi':[],'single':[],'noSolution':[]};shards=[];batch=[]
 def flush():
  if not batch:return
  path=dest/f'questions-{len(shards):04d}.json.gz'
  raw=json.dumps({'schema':'defense-rail-sequences-candidate-v2','identity':identity,'questions':batch},separators=(',',':')).encode()
  tmp=path.with_suffix('.tmp');tmp.write_bytes(gzip.compress(raw,mtime=0));assert gzip.decompress(tmp.read_bytes())==raw;tmp.replace(path)
  shards.append(dict(file=path.name,sha256=sha(path),questions=len(batch),routes=sum(len(x['routes']) for x in batch)));batch.clear()
 for q in questions:
  qid=q['id'];cp=json.loads((store/(qid+'.checkpoint.json')).read_bytes());path=store/(qid+'.json.gz');assert sha(path)==cp['sha256'] and cp['identity']==identity
  summary=cp['summary'];category='multi' if summary['admitted'] else 'single' if summary['retained'] else 'noSolution';ledgers[category].append(summary)
  if summary['admitted']:
   payload=json.loads(gzip.decompress(path.read_bytes()));record=payload['record'];assert audit(record,payload['metrics'],q,identity)==summary
   batch.append(dict(question=q,region=record['scan'],routes=record['result']['routes']));admitted.append(qid)
   if len(batch)==250:flush()
 flush()
 for category,rows in ledgers.items():atomic(dest/(category+'.json'),rows)
 assert sum(map(len,ledgers.values()))==len(questions)==57575
 atomic(dest/'manifest.json',dict(complete=True,schema='defense-rail-sequences-candidate-v2',identity=identity,processed=len(questions),admitted=len(admitted),counts={k:len(v) for k,v in ledgers.items()},shards=shards,policy=json.loads((OUT/'policy.json').read_bytes()),scope='Independent offline candidate package. Bounded search; no-solution means none found under this policy. No production replacement or device acceptance.'))
 atomic(OUT/'status.json',dict(state='complete',phase='full',completed=len(questions),total=len(questions),admitted=len(admitted),shards=len(shards),updatedAt=time.time(),manifest=str(dest/'manifest.json')))
def import_old(questions,identity):
 old=ROOT/'output/defense-multisolution-full-20261106'
 previous=json.loads((old/'run-identity.json').read_bytes());current=json.loads((OUT/'run-identity.json').read_bytes())
 assert previous['production']==current['production'] and previous['assets']==current['assets'],'Cannot reuse after physical/scoring drift'
 a=json.loads((old/'policy.json').read_bytes());b=json.loads((OUT/'policy.json').read_bytes())
 for k in a:
  if k not in ['version','diversity']:assert a[k]==b[k],k
 lookup={q['id']:q for q in questions};target=OUT/'full/records';target.mkdir(parents=True,exist_ok=True)
 reused=[];retry=[];classification=[]
 for cp in sorted((old/'full/records').glob('*.checkpoint.json')):
  c=json.loads(cp.read_bytes());qid=c['summary']['id'];gz=cp.with_name(cp.name.replace('.checkpoint.json','.json.gz'))
  assert c['identity']==previous['identity'] and sha(gz)==c['sha256']
  payload=json.loads(gzip.decompress(gz.read_bytes()));record=payload['record'];q=record['question'];r=record['result'];own='_'+str(q['ownBallNumber'])
  assert q==lookup[qid]
  groups={}
  for route in r['routes']:
   seq=rail_sequences(route['events'],own);key=(tuple(seq['cue']),tuple(seq['target']))
   route['railSequences']=seq
   # Native output was ordered by existing execution quality. First member is the representative.
   groups.setdefault(key,route)
  selected=list(groups.values());classification.append(dict(id=qid,before=len(r['routes']),classes=len(selected)))
  # Zero/single results exhausted all spin tiers and retain unchanged physics validity.
  # If two new classes already exist, the same stop criterion is satisfied. Otherwise re-search.
  reusable=len(selected)>=2 or (len(r['routes'])<2 and r['tiers'][-1]['tier']==3)
  if not reusable:retry.append(qid);continue
  if (target/(qid+'.checkpoint.json')).exists():continue
  record['provenance']=dict(sourceIdentity=record['identity'],sourceArchive=str(gz),sha256=c['sha256'],mode='reclassified-verified-existing-physics')
  record['identity']=identity;r['routes']=selected;r['retainedCount']=len(selected);r['admitted']=len(selected)>=2;r['diversityVersion']='per-ball-rail-sequences-v2'
  summary=audit(record,payload['metrics'],q,identity)
  dst=target/gz.name;tmp=dst.with_suffix('.tmp');raw=json.dumps(payload,separators=(',',':')).encode();tmp.write_bytes(gzip.compress(raw,compresslevel=6,mtime=0));assert gzip.decompress(tmp.read_bytes())==raw;tmp.replace(dst)
  atomic(target/cp.name,dict(identity=identity,sha256=sha(dst),summary=summary));reused.append(qid)
 atomic(OUT/'old-classification.json',dict(sourceIdentity=previous['identity'],cases=classification,reused=len(reused),reusedIDs=reused,needResearch=len(retry),retryIDs=retry))
 print('Imported audited old results',len(reused),'need wider class search',len(retry),flush=True)
def main():
 uid,binary,identity=sys.argv[1:]
 subprocess.run(['xcrun','simctl','boot',uid],check=True)
 try:
  subprocess.run(['xcrun','simctl','bootstatus',uid,'-b'],check=True)
  pilot=json.loads((OUT/'pilot-inputs.json').read_bytes());checked=phase('pilot',pilot,uid,binary,identity)
  assert len(checked)==36 and {q['kind'] for q in pilot}=={'two_black','two_own','three'}
  # Contract checks must exercise retained routes in both two-ball roles and three-ball roles.
  coverage={k:sum(r['retained'] for r in checked.values() if r['kind']==k) for k in ['two_black','two_own','three']}
  assert all(coverage.values()),('Pilot lacks route coverage',coverage)
  atomic(OUT/'pilot-audit.json',dict(passed=True,identity=identity,cases=36,routeCoverage=coverage,distinctMultiLayouts=sum(r['admitted'] for r in checked.values())))
  full=json.loads((OUT/'inputs.json').read_bytes())
  import_old(full,identity)
  # Reuse audited pilot records, without recalculating or changing original layouts.
  target=OUT/'full/records';target.mkdir(parents=True,exist_ok=True)
  for p in (OUT/'pilot/records').iterdir():
   if p.is_file():
    dst=target/p.name
    if dst.exists():dst.unlink()  # superseded by same-input fresh v2 pilot, original v1 kept
    os.link(p,dst)
  phase('full',full,uid,binary,identity);package(full,identity)
 except BaseException as e:
  atomic(OUT/'failure.json',dict(error=repr(e),time=time.time()));raise
 finally:subprocess.run(['xcrun','simctl','shutdown',uid],check=True)
if __name__=='__main__':main()
