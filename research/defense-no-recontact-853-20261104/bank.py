from pathlib import Path
import gzip,json,hashlib,collections,shutil
ROOT=Path(__file__).resolve().parents[2];OLD=ROOT/'output/defense-full-5698-20261104/r1';OUT=ROOT/'output/defense-no-recontact-522-20261104/r1'
POLICY='pure-defense-cut60-rails1-total2-no-target-rail-recontact-v2'
def enc(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def read(p):return json.loads(p.read_bytes())
def write(p,x):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(enc(x)+b'\n')
def sha(b):return hashlib.sha256(b).hexdigest()
def load(bank):
 idx=read(bank/'index.json');rows=[]
 for s in idx['shards']:
  raw=(bank/(s['name']+'.jsonl.gz')).read_bytes();assert sha(raw)==s['sha256'];rows+=list(map(json.loads,gzip.decompress(raw).splitlines()))
 return idx,rows

def forbidden(events,own):
 contacted=False;bounced=False
 for e in events:
  pair=e['kind']=='ballBall' and set(e['ballNumbers'])=={0,own}
  if pair:
   if contacted and bounced:return True
   contacted=True
  elif contacted and e['kind']=='cushion' and e['ballNumbers']==[own] and e.get('railIndex') in range(6):bounced=True
 return False

def export(rows,coverage,dest,provenance):
 assert not dest.exists(),'Immutable output already exists'
 dest.mkdir(parents=True);idx=read(OLD/'bank/index.json')
 idx.update(policyVersion=POLICY,counts=dict(inputs=5698,questions=len(rows),references=sum(len(q['references']) for q in rows)),shards=[],questions=[],revisionProvenance=provenance);idx.pop('fingerprint')
 for kind in ('one','two_black','two_own','three'):
  group=[q for q in rows if q['kind']==kind]
  for start in range(0,len(group),100):
   name=f'{kind}-{start//100:04d}';part=group[start:start+100]
   for q in part:
    assert q['references'] and not any(forbidden(r['expected']['events'],q['ownBallNumber']) for r in q['references'])
   raw=gzip.compress(b''.join(enc(q)+b'\n' for q in part),mtime=0);(dest/(name+'.jsonl.gz')).write_bytes(raw)
   idx['shards'].append(dict(name=name,sha256=sha(raw),bytes=len(raw)))
   idx['questions'] += [dict(id=q['id'],kind=kind,shard=name,line=i) for i,q in enumerate(part)]
 idx['fingerprint']=sha(enc(idx));write(dest/'index.json',idx);write(dest/'coverage.json',coverage)
 ri,rr=load(dest);assert rr==[q for k in ('one','two_black','two_own','three') for q in rows if q['kind']==k]
 write(dest/'audit.json',dict(passed=True,counts=idx['counts'],forbiddenReferences=0,fingerprint=idx['fingerprint']))
 return idx

def clean():
 idx,rows=load(OLD/'bank');retained=[];missing=[];removed=[]
 for q in rows:
  keep=[]
  for r in q['references']:
   if forbidden(r['expected']['events'],q['ownBallNumber']):removed.append(dict(question=q['id'],reference=r['id']))
   else:r['selectionProbePolicyVersion']=idx['policyVersion'];keep.append(r)
  q['references']=keep
  if keep:retained.append(q)
  else:missing.append(q['id'])
 assert len(removed)==2008 and len(missing)==522 and len(retained)==3818
 write(OUT/'removed-references.json',removed);write(OUT/'missing-question-ids.json',missing)
 coverage=read(OLD/'bank/coverage.json');counts={q['id']:len(q['references']) for q in retained}
 for c in coverage:
  if c['id'] in missing:c.update(status='pending-research',referenceCount=0)
  elif c['id'] in counts:c['referenceCount']=counts[c['id']]
 export(retained,coverage,OUT/'filtered-bank',dict(sourceFingerprint=idx['fingerprint'],removedReferences=2008,scope='Reference filtering only; inherited probes retain old policy, not revalidated'))
 print('Filtered: 3818 questions / 8459 references; 522 queued')

def merge():
 idx,base=load(OUT/'filtered-bank');_,new=load(OUT/'bank');missing=set(read(OUT/'missing-question-ids.json'));assert not missing & {q['id'] for q in base}
 assert {q['id'] for q in new}<=missing
 for q in new:
  for r in q['references']:r['selectionProbePolicyVersion']=POLICY
 coverage=read(OUT/'filtered-bank/coverage.json');newcoverage={c['id']:c for c in read(OUT/'bank/coverage.json')}
 for i,c in enumerate(coverage):
  if c['id'] in missing:coverage[i]=newcoverage[c['id']]
 result=export(base+new,coverage,OUT/'final-bank',dict(sourceFingerprint=idx['fingerprint'],researchFingerprint=read(OUT/'run-config.json')['fingerprint'],recomputedQuestions=522,refilledQuestions=len(new)))
 print(json.dumps(result['counts']))
if __name__=='__main__':
 import sys
 (merge if len(sys.argv)>1 and sys.argv[1]=='merge' else clean)()
