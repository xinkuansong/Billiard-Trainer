from pathlib import Path
import json,gzip,math,hashlib,statistics
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-collision-counterfactual-20261026'
def write(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
def key(r):
 i=r['input'];return f"{i['tag']}_{'reverse' if i['reverseRegistration'] else 'forward'}"
cal=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text());L,W,R=(cal['domain'][k] for k in ['length','width','radius'])
protocol=json.loads((OUT/'protocol.json').read_text());groups={};rawby={};rows=[];audits=[]
for file in sorted(OUT.glob('raw-*.jsonl.gz')):
 with gzip.open(file,'rt') as f:
  for line in f:
   r=json.loads(line);i=r['input'];rid=i['rackID'];k=key(r);rawby[rid,k]=r
   q=np.array([[v[0]*L-L/2,v[1]*L-W/2] for name,v in r['board'].items() if name!='cueBall'])
   distances=np.linalg.norm(q[:,None]-q[None,:],axis=2);np.fill_diagonal(distances,np.inf)
   index=float(distances.min(1).mean()/cal['reference'][str(len(q))]['expectedMeanM'])
   scalar=statistics.mean(min(math.dist(a,b) for jj,b in enumerate(q) if ii!=jj) for ii,a in enumerate(q))/cal['reference'][str(len(q))]['expectedMeanM'];assert abs(index-scalar)<1e-12
   sample=r['samples'][1];assert abs(sample['delay']-.005)<1e-8
   v=np.array([b['v'] for b in sample['states'][1:]]);p=np.array([b['p'] for b in sample['states'][1:]])
   E=.5*.17*(v*v).sum(1);share=E/E.sum();d=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(d,np.inf)
   first=r['impulseTrace'][0];E0=sum(.5*.17*np.dot(c['preV'],c['preV']) for c in first['changed'])
   sep=[];maxMomentum=0;maxEnergy=-1e99;paircount=0;nonpairs=[];gaps=[]
   for event in r['impulseTrace']:
    ch=event['changed']
    if len(ch)!=2:nonpairs.append(dict(t=event['t'],slots=[c['slot'] for c in ch]));continue
    paircount+=1;dv=np.sum([np.array(c['postV'])-c['preV'] for c in ch],axis=0);maxMomentum=max(maxMomentum,float(np.linalg.norm(dv)))
    de=sum(.5*.17*(np.dot(c['postV'],c['postV'])-np.dot(c['preV'],c['preV']))+.17*R*R/5*(np.dot(c['postW'],c['postW'])-np.dot(c['preW'],c['preW'])) for c in ch);maxEnergy=max(maxEnergy,float(de))
    normal=np.array(ch[1]['preP'])-ch[0]['preP'];dist=np.linalg.norm(normal);normal/=dist
    approach=float(-np.dot(np.array(ch[1]['preV'])-ch[0]['preV'],normal))
    gap=float((dist-2*R)*1000);gaps.append(gap)
    if approach < -1e-5:sep.append(dict(t=event['t'],approach=approach,gapMM=gap,slots=[c['slot'] for c in ch],energyChange=de))
   names={n:j-1 for j,n in enumerate(r['names'])};bb=[e for e in r['resolvedEvents'] if e['kind']=='ball'];firstB={}
   for order,e in enumerate(bb):
    a,b=names[e['a']],names[e['b']]
    if a==0 or b==0:
     other=b if a==0 else a
     if other in [1,2] and other not in firstB:firstB[other]=(order,e['time'])
   row=dict(rackID=rid,key=k,index=index,success=int(r['status']=='settled' and index>=1.2),status=r['status'],remaining=len(q),potted=15-len(q),cpuMS=r['cpuSeconds']*1000,wallMS=r['seconds']*1000,eventCount=len(r['resolvedEvents']),zeroImpulseCount=sum(e['t']==0 and len(e['changed'])==2 for e in r['impulseTrace']),E1=float(share[10]),E5=float(share[14]),interiorShare=float(share[[4,7,8]].sum()),effectiveBalls=float(E.sum()**2/np.dot(E,E)),energyFraction=float(E.sum()/E0),internalGapMM=float((d.min(1)[[4,7,8]]-2*R).mean()*1000),branchTied=int(len(firstB)==2 and firstB[1][1]==firstB[2][1]),firstPlusZ=int(len(firstB)==2 and firstB[1][0]<firstB[2][0]),separatingCount=len(sep),maxContactGapMM=max(gaps),maxMomentum=maxMomentum,maxEnergyGain=maxEnergy)
   rows.append(row);groups.setdefault(k,[]).append(row);audits.append(dict(rackID=rid,key=k,separating=sep,nonPairs=nonpairs))
assert len(rows)==1600 and len(rawby)==1600
old=json.loads((ROOT/'output/rack-contact-factorial-20261026/derived.json').read_text());oldlookup={(r['rackID'],r['key']):r for r in old}
expected={r['rackID'] for r in protocol['racks']};assert all(len(v)==200 and {r['rackID'] for r in v}==expected for v in groups.values())
for k,g in groups.items():g.sort(key=lambda r:r['rackID'])
summary={};rng=np.random.default_rng(202610260811)
def cp(k,n,tail):
 def cdf(k,p):return sum(math.comb(n,j)*p**j*(1-p)**(n-j) for j in range(k+1))
 def invert(k,target):
  lo,hi=0.,1.
  for _ in range(80):
   mid=(lo+hi)/2
   if cdf(k,mid)>target:lo=mid
   else:hi=mid
  return (lo+hi)/2
 return (0. if k==0 else invert(k-1,1-tail),1. if k==n else invert(k,tail))
def ci(a,b):
 d=np.array(a)-np.array(b);n=len(d);plus=int(sum(d>0));minus=int(sum(d<0));alpha=.05/8
 lp,up=cp(plus,n,alpha/4);lm,um=cp(minus,n,alpha/4)
 return dict(delta=float(d.mean()),ci=[lp-um,up-lm],newPass=plus,lostPass=minus,method='Conservative exact marginal Clopper-Pearson bounds on paired discordances; union bound, 8 comparisons familywise95%.')
for k,g in groups.items():
 original=('250um_1e-07_' if k.startswith('current') else '1um_1e-12_')+('reverse' if k.endswith('reverse') else 'forward')
 baseline=[oldlookup[r['rackID'],original] for r in g]
 d={n:float(np.mean([r[n] for r in g])) for n in ['index','potted','E1','E5','interiorShare','energyFraction','effectiveBalls','internalGapMM','eventCount','zeroImpulseCount']}
 d.update(n=len(g),passed=sum(r['success'] for r in g),incomplete=sum(r['status']!='settled' for r in g),baselinePassed=sum(r['success'] for r in baseline),baselineKey=original,rateDifference=ci([r['success'] for r in g],[r['success'] for r in baseline]),separatingRacks=sum(r['separatingCount']>0 for r in g),separatingImpulses=sum(r['separatingCount'] for r in g),wallMedianMS=float(np.median([r['wallMS'] for r in g])),wallP95MS=float(np.quantile([r['wallMS'] for r in g],.95)))
 summary[k]=d
order={}
for tag in ['current_bounded','narrow_canonical','narrow_bounded','narrow_both']:
 a,b=tag+'_forward',tag+'_reverse'
 order[tag]=dict(exactBoards=sum(rawby[id,a]['board']==rawby[id,b]['board'] for id in expected),exact5ms=sum(rawby[id,a]['samples'][1]==rawby[id,b]['samples'][1] for id in expected),passFlips=sum(x['success']!=y['success'] for x,y in zip(groups[a],groups[b])),meanAbsIndexDifference=float(np.mean([abs(x['index']-y['index']) for x,y in zip(groups[a],groups[b])])),max5msVelocityDifference=max(float(np.linalg.norm(np.array(x['v'])-y['v'])) for id in expected for x,y in zip(rawby[id,a]['samples'][1]['states'],rawby[id,b]['samples'][1]['states'])))
# Match all eight variants' geometry and original exact inputs.
oldraw={}
for path in (ROOT/'output/rack-contact-factorial-20261026').glob('raw-*.gz'):
 with gzip.open(path,'rt') as f:
  for l in f:
   r=json.loads(l)
   if r['input']['contactEpsilon']==.00025 and r['input']['tieEpsilon']==1e-7 and not r['input']['reverseRegistration']:oldraw[r['input']['rackID']]=r
for (id,k),r in rawby.items():
 for field in ['rack','cue','direction','power','spin']:assert r[field]==oldraw[id][field]
write('derived.json',rows);write('impulse-audit.json',audits)
write('analysis.json',dict(groups=summary,order=order,audit=dict(records=1600,geometryIdentity=True,scoreScalarCrosscheck=True,maxMomentum=max(r['maxMomentum'] for r in rows),maxEnergyGain=max(r['maxEnergyGain'] for r in rows),nonPairJumps=sum(len(a['nonPairs']) for a in audits)),rateCI='Exploratory paired discordance exact marginal intervals with union-bound adjustment for 8 comparisons, 95% familywise; zero flips do not imply zero population effect. Timing cross-run not causal.'))
for k,v in summary.items():print(k,v)
print('ORDER',order)
