import json,gzip,math,statistics,collections
from pathlib import Path
OUT=Path('output/rack-solver-invariance-20261026')
rows=[json.loads(l) for l in gzip.open(OUT/'raw.jsonl.gz','rt')];groups=collections.defaultdict(dict)
R=.028574999421834946;L=2.5399999618530273
norm=lambda a:math.sqrt(sum(v*v for v in a))
dist=lambda a,b:norm([x-y for x,y in zip(a,b)])
def stats(xs):return dict(mean=statistics.mean(xs),min=min(xs),max=max(xs),median=statistics.median(xs))
def states(r):return dict(zip(r['names'],r['samples'][1]['states']))
def tail(r):return max(x['tail'] for x in r['spinTail'])
def energy(s):return sum(x*x for x in s['v'])+.4*R*R*sum(x*x for x in s['w'])
audit=[];examples=[];variants={}
for r in rows:
 rid=r['input']['rackID'];condition=r['input']['condition'];groups[rid][condition]=r
 tr=r['pairTrace'];assert len(tr)%3==0
 early=[];sep=[];same=0;previous=None;energyExcess=[]
 for k in range(0,len(tr),3):
  bk,bi,ai=tr[k:k+3];assert [x['phase'] for x in (bk,bi,ai)]==['beforeKiss','beforeImpulse','afterImpulse']
  assert bk['t']==bi['t']==ai['t'];assert bk['a']['name']==bi['a']['name']==ai['a']['name']
  impulse=max(dist(bi[b]['v'],ai[b]['v']) for b in ['a','b'])
  if impulse<1e-5:continue
  e0=sum(energy(bi[b]) for b in ['a','b']);e1=sum(energy(ai[b]) for b in ['a','b']);energyExcess.append((e1-e0)/max(e0,1e-12))
  if previous==bi['t']:same+=1
  previous=bi['t']
  item=dict(rackID=rid,condition=condition,t=bi['t']-r['t0'],pair=[bi[b]['name'] for b in ['a','b']],beforeGap=bk['gap'],impulseGap=bi['gap'],approach=bi['approach'],deltaV=impulse)
  if bk['gap']>1e-6:early.append(item)
  if bi['approach'] < -1e-4:sep.append(item)
 if condition=='original' and len(examples)<6:
  examples.extend(early[:1]+sep[:1])
 audit.append(dict(rackID=rid,condition=condition,events=len(tr)//3,premature=len(early),maxPositiveGap=max([x['impulseGap'] for x in early],default=0),separating=len(sep),maxSeparationSpeed=max([-x['approach'] for x in sep],default=0),sameTime=same,maxRelativeEnergyIncrease=max(energyExcess,default=0),separatingEvents=sep))
for condition in ['original','reverse','mirror','mirror_reverse']:
 rs=[r for r in rows if r['input']['condition']==condition];aa=[x for x in audit if x['condition']==condition]
 shares=[[],[]];dominant=collections.Counter();tails=[]
 for r in rs:
  s=states(r);total=sum(sum(v*v for v in s[name]['v']) for name in r['canonicalNames'])
  for j,slot in enumerate([10,14]):shares[j].append(sum(v*v for v in s[r['canonicalNames'][slot]]['v'])/total)
  t=tail(r);tails.append(t)
  if t>1e-4:
   name=max(r['spinTail'],key=lambda x:x['tail'])['name'];slot=r['canonicalNames'].index(name) if name!='cueBall' else -1;dominant[slot]+=1
 variants[condition]=dict(n=len(rs),settled=sum(r['status']=='settled' for r in rs),corner10EnergyShare5ms=stats(shares[0]),corner14EnergyShare5ms=stats(shares[1]),tail=stats(tails),tailAbove5=sum(t>5 for t in tails),tailBallCanonicalSlot=dict(dominant),prematureShots=sum(x['premature']>0 for x in aa),prematureImpulses=sum(x['premature'] for x in aa),maxGapM=max(x['maxPositiveGap'] for x in aa),separatingShots=sum(x['separating']>0 for x in aa),separatingImpulses=sum(x['separating'] for x in aa),maxSeparationSpeed=max(x['maxSeparationSpeed'] for x in aa),meanSameTime=statistics.mean(x['sameTime'] for x in aa),maxRelativeEnergyIncrease=max(x['maxRelativeEnergyIncrease'] for x in aa))
comparisons=[]
for rid,rs in groups.items():
 base=rs['original'];bs=states(base)
 for label in ['reverse','mirror','mirror_reverse']:
  r=rs[label];mirror=r['input']['mirror'];s=states(r);maxp=maxv=maxw=0
  # Verify intervention changed only reflection and list order.
  br={x['number']:x for x in base['rack']};rr={x['number']:x for x in r['rack']}
  assert br.keys()==rr.keys()
  for n,b in br.items():assert rr[n]['x']==b['x'] and rr[n]['z']==(-b['z'] if mirror else b['z'])
  for name,a in bs.items():
   p=a['p'][:];v=a['v'][:];w=a['w'][:]
   if mirror:p[2]*=-1;v[2]*=-1;w[0]*=-1;w[1]*=-1
   maxp=max(maxp,dist(p,s[name]['p']));maxv=max(maxv,dist(v,s[name]['v']));maxw=max(maxw,dist(w,s[name]['w']))
  boardMatch=base['board'].keys()==r['board'].keys();delta=0
  for name in base['board'].keys()&r['board'].keys():
   a=base['board'][name][:]
   if mirror:a[1]=.5-a[1]
   delta=max(delta,dist(a,r['board'][name])*L)
  comparisons.append(dict(rackID=rid,condition=label,maxPositionDelta5ms=maxp,maxVelocityDelta5ms=maxv,maxOmegaDelta5ms=maxw,earlyInvariant=maxp<=1e-6 and maxv<=1e-4 and maxw<=.01,pocketedMatch=base['pocketed']==r['pocketed'],boardInvariant=boardMatch and delta<=.001,commonBoardMaxDeltaM=delta))
comp={}
for label in ['reverse','mirror','mirror_reverse']:
 a=[x for x in comparisons if x['condition']==label]
 comp[label]=dict(n=len(a),earlyPass=sum(x['earlyInvariant'] for x in a),boardPass=sum(x['boardInvariant'] for x in a),pocketedMatch=sum(x['pocketedMatch'] for x in a),maxV5ms=stats([x['maxVelocityDelta5ms'] for x in a]),maxP5ms=stats([x['maxPositionDelta5ms'] for x in a]))
summary=dict(variants=variants,comparisons=comp,examples=examples)
for name,data in [('summary',summary),('audit',audit),('comparisons',comparisons)]: (OUT/(name+'.json')).write_text(json.dumps(data,indent=2))
assert len(rows)==400 and len(groups)==100
print(json.dumps(summary,indent=2))
