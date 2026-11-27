from pathlib import Path
from collections import Counter
import json,hashlib,math,random
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/defense-t02-expand-20261104';BASE=ROOT/'output/defense-full-filter-20261104';PILOT=ROOT/'output/defense-reuse-20261104'
read=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=read(BASE/'input-manifest.json');pool={'one':[],'two':[],'three':[]};proof={};rng=random.Random(20261104)
def sig(r,own):return min(tuple(round(v,3) for p in [r['cue'],r['positions'][own]] for v in [p[0]*sx,p[1]*sz]) for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)])
for chunk in m['chunks']:
 p=BASE/chunk['file'];stem=p.stem
 if chunk['bank']!='three':
  dp=BASE/f'results/{stem}-decisions.json';done=BASE/f'results/{stem}-done.json'
  if not done.exists():continue
  d=read(done);assert sha(dp)==d['outputs'][str(dp.relative_to(BASE))]
  wanted=[x for x in read(dp) if x['status']=='rejected' and .002<x.get('witnessWidth',0)<=.008 and 4<=x.get('witnessComfort',0)<10]
  if not wanted:continue
  assert sha(p)==chunk['sha256'];rows={r['ordinal']:r for r in read(p)}
  pool[chunk['bank']].extend((rows[x['ordinal']],x['own']) for x in wanted)
 else:
  assert sha(p)==chunk['sha256'];rows=read(p)
  # 80 boards per shard; evaluate both secondary targets. Bounded exploratory sample.
  for r in rng.sample(rows,min(80,len(rows))):
   pool['three'].extend([(r,1),(r,2)])
 proof[str(p.relative_to(ROOT))]=sha(p)
candidates=[];used=set()
for bank,limit in [('one',240),('two',360),('three',1800)]:
 rng.shuffle(pool[bank]);take=[]
 for r,own in pool[bank]:
  key=sig(r,own)
  if key in used:continue
  used.add(key);take.append((r,own))
  if len(take)==limit:break
 for r,own in take:
  n=len(r['positions']);q=dict(r);q['own']=own;q['source']={'one':'accuracy','two':'two','three':'three'}[bank]
  if n==1:q.update(kind='one',numbers=[8],enemy=0)
  elif n==2:
   nums=[8,8];nums[own]=1;q.update(kind='two_own',numbers=nums,enemy=1-own)
  else:
   enemy=next(i for i in range(n) if i!=own);nums=[8]*3;nums[own]=1;nums[enemy]=9;q.update(kind='three',numbers=nums,enemy=enemy)
  q['id']=len(candidates)+100000;candidates.append(q)
# Preserve the 27 last reviewed examples as exact metric regression controls.
controls=read(ROOT/'output/defense-threshold-ladder-20261104/samples.json')
for q in controls:
 r={k:v for k,v in q.items() if k not in ['ownAttack','enemyAttack','maxPocketComfort']};r['regressionControl']=True;candidates.append(r)
(OUT/'candidate-input.json').write_text(json.dumps(candidates,separators=(',',':')))
(OUT/'controls.json').write_text(json.dumps(controls,separators=(',',':')))
(OUT/'bank-provenance.json').write_text(json.dumps({'files':m['sourceFiles']},indent=2))
(OUT/'sampling.json').write_text(json.dumps({'seed':20261104,'preselectionCounts':{k:len(v) for k,v in pool.items()},'selectedCounts':Counter(q['source'] for q in candidates),'partialInputHashes':proof,'scope':'Partial rejection witnesses only preselect candidates; every candidate must be fully recomputed across six pockets. Three-ball sample comes from all shards. Not a full-bank or prevalence estimate.'},indent=2))
print('candidates',len(candidates),'pools',{k:len(v) for k,v in pool.items()},Counter(q['source'] for q in candidates))
