from pathlib import Path
import gzip,json,statistics,math,collections
O=Path('output/rack-spin-experiments-20261026');rs=[]
for p in ['sweep-r2','holdout']:
 rs += [json.loads(l) for l in gzip.open(O/p/'raw.jsonl.gz','rt')]
by=collections.defaultdict(dict)
for r in rs:
 if r['input']['condition']=='original':by[r['input']['experiment']][r['input']['rackID']]=r
out={}
for label in ['han14','han14_spin22','mathavan','mathavan14']:
 pairs=[]
 for i,b in by['repair'].items():
  last=max(b['spinTail'],key=lambda x:x['tail'])
  if last['tail']<=5:continue
  r=by[label][i];name=last['name'];x=next(x for x in r['spinTail'] if x['name']==name)
  row=dict(id=i,name=name,baseTail=last['tail'],tail=x['tail'],pocketed=name not in r['board'],translationDelta=r['lastTranslation']-b['lastTranslation'])
  for prefix,q in [('base',b),('candidate',r)]:
   hits=[c for c in q['cushionTrace'] if c['pre']['name']==name]
   row[prefix+'LastCushion']=None if not hits else dict(t=hits[-1]['time'],wy=hits[-1]['post']['w'][1])
  pairs.append(row)
 out[label]=dict(n=len(pairs),problemBallPocketed=sum(x['pocketed'] for x in pairs),retainedOver5=sum(not x['pocketed'] and x['tail']>5 for x in pairs),retainedOver1=sum(not x['pocketed'] and x['tail']>1 for x in pairs),meanTranslationDelta=statistics.mean(x['translationDelta'] for x in pairs),rows=pairs)
(O/'same-ball-forensics.json').write_text(json.dumps(out,indent=2))
for k,v in out.items():print(k,{a:b for a,b in v.items() if a!='rows'})
