from pathlib import Path
import json,gzip,math,hashlib,statistics
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-contact-factorial-20261026'
def write(n,v):(OUT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False))
def key(r):
 i=r['input'];return f"{i['contactEpsilon']*1e6:g}um_{i['tieEpsilon']:g}_{'reverse' if i['reverseRegistration'] else 'forward'}"
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
assert len(rows)==2400 and len(rawby)==2400
expectedIDs={r['rackID'] for r in protocol['racks']}
assert all(len(g)==200 and {r['rackID'] for r in g}==expectedIDs for g in groups.values()) and len(groups)==12
# All twelve inputs share exact rack geometry, numbering, cue and aim.
for rid in expectedIDs:
 batch=[r for (id,k),r in rawby.items() if id==rid]
 for field in ['rack','cue','direction','power','spin']:assert all(r[field]==batch[0][field] for r in batch)
for k in groups:groups[k].sort(key=lambda r:r['rackID'])
summary={}
for k,g in groups.items():
 stats={name:float(np.mean([r[name] for r in g])) for name in ['index','potted','zeroImpulseCount','E1','E5','interiorShare','effectiveBalls','energyFraction','internalGapMM','eventCount','firstPlusZ','branchTied']}
 stats.update(n=len(g),passed=sum(r['success'] for r in g),incomplete=sum(r['status']!='settled' for r in g),separatingRacks=sum(r['separatingCount']>0 for r in g),separatingImpulses=sum(r['separatingCount'] for r in g))
 for n in ['cpuMS','wallMS','eventCount']:
  stats[n+'Median']=float(np.median([r[n] for r in g]));stats[n+'P95']=float(np.quantile([r[n] for r in g],.95))
 summary[k]=stats
rng=np.random.default_rng(202610260703)
def paired_ci(a,b,alpha=.05):
 d=np.array(a)-np.array(b);samples=d[rng.integers(0,len(d),(20000,len(d)))].mean(1)
 return dict(delta=float(d.mean()),ci=[float(v) for v in np.quantile(samples,[alpha/2,1-alpha/2])])
base=groups['250um_1e-07_forward'];contrasts={}
for k,g in groups.items():
 if k=='250um_1e-07_forward':continue
 contrasts[k]=paired_ci([r['success'] for r in g],[r['success'] for r in base],.05/11)
order={}
for e in [250,10,1]:
 for t in ['1e-07','1e-12']:
  stem=f'{e}um_{t}';ka=stem+'_forward';kb=stem+'_reverse';a=groups[ka];b=groups[kb]
  exact=early=0;sharedDisplacements=[];pottedDifferent=0
  for rid in sorted(expectedIDs):
   x,y=rawby[rid,ka],rawby[rid,kb];exact+=x['board']==y['board'];early+=x['samples'][1]==y['samples'][1];pottedDifferent+=x['pocketed']!=y['pocketed']
   common=set(x['board'])&set(y['board'])-{'cueBall'}
   sharedDisplacements.append(float(np.mean([math.dist(x['board'][n],y['board'][n])*L for n in common])))
  order[stem]=dict(exactBoards=exact,exact5ms=early,differentPotting=pottedDifferent,meanSharedBallDisplacementM=float(np.mean(sharedDisplacements)),meanAbsE1ShareChange=float(np.mean([abs(x['E1']-y['E1']) for x,y in zip(a,b)])),meanAbsIndexChange=float(np.mean([abs(x['index']-y['index']) for x,y in zip(a,b)])),passFlips=sum(x['success']!=y['success'] for x,y in zip(a,b)),reverseMinusForward=paired_ci([r['success'] for r in b],[r['success'] for r in a],.05/6))
write('derived.json',rows);write('impulse-audit.json',audits)
write('analysis.json',dict(groups=summary,order=order,contrasts=contrasts,rateCIs='Paired rack bootstrap 20000; 11 contrasts familywise 95% via Bonferroni; 6 order contrasts separate family.',audit=dict(records=len(rows),uniqueInputs=len(rawby),geometryIdentity=True,scoreScalarCrosscheck=True,maxMomentum=max(r['maxMomentum'] for r in rows),maxEnergyGain=max(r['maxEnergyGain'] for r in rows),nonPairJumps=sum(len(a['nonPairs']) for a in audits))))
for k in sorted(summary):print(k,summary[k])
print('ORDER',json.dumps(order))
