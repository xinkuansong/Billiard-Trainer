from pathlib import Path
import json,gzip,statistics,collections,random,math,hashlib
O=Path('output/rack-fixed-physics-20261027');rs=[json.loads(l) for l in gzip.open(O/'full/raw.jsonl.gz','rt')]
assert len(rs)==1200
s=json.loads((O/'full/scalars.json').read_text());ix={(x['id'],x['label']):x for x in s};ri={(r['input']['rackID'],r['input']['experiment']):r for r in rs}
labels=list(dict.fromkeys(x['label'] for x in s));ids=list(range(11300,11500));params=rs[0]['parameters']
assert all(r['parameters']==params and r['power']==10 and r['status']=='settled' and not r['researchFailures'] for r in rs)
assert all(ri[i,l]['rack']==ri[i,'production']['rack'] and ri[i,l]['initialCueVelocity']==ri[i,'production']['initialCueVelocity'] for i in ids for l in labels)
audit=dict(parameters=params,parametersIdentical=True,racksAndInitialVelocityIdentical=True,runs=len(rs),settled=sum(r['status']=='settled' for r in rs),researchFailures=0)
for phase in ['pilot','full']:
 d=O/phase;b=json.loads((d/'source-binding.json').read_text());assert all(hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256'] for r in b['production'])
 assert json.loads((d/'closure.json').read_text())['success']
audit['productionSourceUnchanged']=True
# Paired resampling across all pre-specified rack IDs, including pilot IDs.
rng=random.Random(20261027);draws=[[rng.randrange(200) for _ in ids] for _ in range(4000)]
def ci(d):
 boot=sorted(sum(d[k] for k in v)/len(d) for v in draws)
 return dict(mean=statistics.mean(d),ci95=[boot[100],boot[3899]])
comparisons={}
for base in ['production','baseline']:
 for label in labels:
  if label==base:continue
  comparisons[label+' minus '+base]={k:ci([ix[i,label][k]-ix[i,base][k] for i in ids]) for k in ['tail','score','cpuMS']}
detail={}
for label in labels:
 group=[ri[i,label] for i in ids];hist=collections.Counter();joint=[];shares=[]
 for r in group:
  hist.update({int(k):v for k,v in r['contactComponents'].items()});joint.extend(dict(x,delay=x['t']-r['t0']) for x in r['jointTrace'])
  states=dict(zip(r['names'],r['samples'][1]['states']));en={n:sum(v*v for v in states[n]['v']) for n in r['canonicalNames']};tot=sum(en.values());shares.append((en[r['canonicalNames'][10]]+en[r['canonicalNames'][14]])/tot)
 detail[label]=dict(contactComponents=dict(hist),jointEvents=len(joint),earliestJointDelay=min([x['delay'] for x in joint],default=None),meanCornerTranslationEnergyShare5ms=statistics.mean(shares),meanLastTranslation=statistics.mean(r['lastTranslation'] for r in group),meanDuration=statistics.mean(r['duration'] for r in group))
tracking={}
for label in ['support','combined']:
 track=[]
 for i in ids:
  base=ri[i,'baseline'];ball=max(base['spinTail'],key=lambda x:x['tail'])
  if ball['tail']<=5:continue
  r=ri[i,label];same=next(b for b in r['spinTail'] if b['name']==ball['name']);pocketed=ball['name'] not in r['board']
  contacts=[c for c in r['cushionTrace'] if c['pre']['name']==ball['name']]
  track.append(dict(id=i,ball=ball['name'],pocketed=pocketed,tail=same['tail'],peakWy=same['peakWy'],lastCushionWy=contacts[-1]['post']['w'][1] if contacts else None))
 tracking[label]=dict(n=len(track),pocketed=sum(x['pocketed'] for x in track),onTableMaxTail=max(x['tail'] for x in track if not x['pocketed']),onTableOver1=sum(not x['pocketed'] and x['tail']>1 for x in track),rows=track)
# A pre-existing worst production seed: matched identities, no post-hoc swapping.
case={};rid=11331
for label in ['production','baseline','support','combined']:
 r=ri[rid,label];names=r['canonicalNames'];target=names[10];cs=[c for c in r['cushionTrace'] if c['pre']['name']==target]
 case[label]=dict(ball=target,spin=next(x for x in r['spinTail'] if x['name']==target),score=ix[rid,label]['score'],lastTranslation=r['lastTranslation'],cushions=[dict(t=c['time'],preV=c['pre']['v'],postV=c['post']['v'],preWy=c['pre']['w'][1],postWy=c['post']['w'][1]) for c in cs])
for name,v in [('audit',audit),('paired',comparisons),('mechanism',detail),('same-ball',tracking),('case-11331',case)]: (O/(name+'.json')).write_text(json.dumps(v,indent=2))
print(json.dumps(dict(audit=audit,mechanism=detail,comparisons={k:v for k,v in comparisons.items() if k.startswith(('support','combined'))},tracking={k:{a:b for a,b in v.items() if a!='rows'} for k,v in tracking.items()}),indent=2))
