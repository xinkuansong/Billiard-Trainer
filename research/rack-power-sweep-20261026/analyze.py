from pathlib import Path
import sys,json,gzip,math,hashlib,statistics,itertools
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/rack-power-sweep-20261026';DATA=OUT/'sweep'
import importlib.util
spec=importlib.util.spec_from_file_location('regional_analysis',ROOT/'research/rack-regional-phase-20261026/analyze.py');regional=importlib.util.module_from_spec(spec);spec.loader.exec_module(regional)
outcome,readraw,stats,ci,L,W,R=(getattr(regional,k) for k in ['outcome','readraw','stats','ci','L','W','R'])
CAL=json.loads((ROOT/'output/rack-center-mechanism-20261026/calibration.json').read_text())
plan=json.loads((DATA/'protocol.json').read_text());ids=[r['rackID'] for r in plan['racks']];powers=plan['powers']
rows={};bases={};gallery={};audit=dict(initialSpeedMaxError=0.,productionBindings=0,allSettled=True,replayGallery=0)
# Stream in two passes; preserve exactly identical coordinates/aim at every speed.
for r in readraw(DATA):
 if r['power']==9.75:bases[r['input']['rackID']]={k:r[k] for k in ['rack','cue','direction','spin','simulatedElevation','board','pocketed','status']}
old={r['input']['rackID']:r for r in readraw(ROOT/'output/rack-best-100-20261026/gallery') if r['input']['variant']=='radial_sideM60'}
for r in readraw(DATA):
 i,p=r['input']['rackID'],r['input']['power'];key=(i,p);assert key not in rows
 assert r['power']==p and r['input']['seed']==plan['racks'][ids.index(i)]['seed']
 assert r['input']['variant']=='radial_sideM60'
 for k in ['rack','cue','direction','spin','simulatedElevation']:assert r[k]==bases[i][k]
 assert r['spin']==[0,0] and r['simulatedElevation']==0
 assert r['status']=='settled',(key,r['termination'])
 speed=math.sqrt(sum(x*x for x in r['initialCueVelocity']));expected=2*p/(1+.170/.567);err=abs(speed-expected);assert err<.00001;audit['initialSpeedMaxError']=max(err,audit['initialSpeedMaxError'])
 assert set(r['names'])-set(r['board'])==set(r['pocketed']) and r['cueScratched']==('cueBall' in r['pocketed'])
 points=np.array([[x[0]*L-L/2,x[1]*L-W/2] for k,x in r['board'].items() if k!='cueBall']);n=len(points);assert n>=2
 dist=np.linalg.norm(points[:,None]-points[None,:],axis=2);np.fill_diagonal(dist,np.inf)
 nearest=dist.min(1).mean();score=nearest/CAL['reference'][str(n)]['expectedMeanM']
 scalar=statistics.mean(min(math.dist(x,y) for j,y in enumerate(points) if i!=j) for i,x in enumerate(points))/CAL['reference'][str(n)]['expectedMeanM'];assert abs(score-scalar)<1e-12
 out=outcome(r)
 row=dict(id=i,seed=r['input']['seed'],power=p,score=float(score),remaining=n,potted=15-n,wallMS=r['seconds']*1000,cpuMS=r['cpuSeconds']*1000,nearestMM=float(nearest*1000),initialCueSpeed=speed,contactCount=len(r['contacts']),duration=r['duration'],**out)
 # Absolute energy and relative allocation at 5ms; temporal comparisons are descriptive at equal time since first contact.
 sample=min(r['samples'],key=lambda s:abs(s['delay']-.005));assert abs(sample['delay']-.005)<1e-7
 e=np.array([.085*sum(v*v for v in s['v']) for s in sample['states'][1:]])
 row.update(energy5=float(e.sum()),effectiveBalls5=float(e.sum()**2/(e@e)),internalShare5=float(e[[4,7,8]].sum()/e.sum()))
 rows[key]=row
 if i in old:
  if p==9.75:
   for k in ['rack','cue','direction','spin','simulatedElevation','board','pocketed','status']:assert r[k]==old[i][k],(i,k)
   audit['replayGallery']+=1
  gallery.setdefault(i,dict(index=ids.index(i)+1,rackID=i,seed=row['seed'],powers={}))['powers'][str(p)]=dict(score=row['score'],scratch=r['cueScratched'],potted=row['potted'],balls=[dict(n=0 if k=='cueBall' else int(k[1:]),x=a[0]*L-L/2,z=a[1]*L-W/2) for k,a in r['board'].items()])
assert set(rows)==set(itertools.product(ids,powers));assert audit['replayGallery']==100
summary={}
for p in powers:
 rr=[rows[i,p] for i in ids];summary[str(p)]=dict(**stats(rr),**{k:float(np.mean([r[k] for r in rr])) for k in ['scratch','potted','closeBalls','closeFraction','largestGroup','cpuMS','nearestMM','duration','contactCount','initialCueSpeed','energy5','effectiveBalls5','internalShare5']},cleanPass=float(np.mean([r['score']>=1.2 and not r['scratch'] for r in rr])),new900Mean=float(np.mean([r['score'] for r in rr[100:]])),new900Pass=float(np.mean([r['score']>=1.2 for r in rr[100:]])))
comparison={}
for p in powers[1:]:
 c={k:ci([rows[i,p][k]-rows[i,9.75][k] for i in ids],5) for k in ['score','scratch','closeFraction','cpuMS','wallMS']}
 c['pass']=ci([int(rows[i,p]['score']>=1.2)-int(rows[i,9.75]['score']>=1.2) for i in ids],5)
 c['winFraction']=float(np.mean([rows[i,p]['score']>rows[i,9.75]['score'] for i in ids]));comparison[str(p)]=c
binding=json.loads((DATA/'source-binding.json').read_text());assert all(hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in binding['production']);audit['productionBindings']=len(binding['production'])
assert json.loads((DATA/'closure.json').read_text())['success']
for name,value in [('rows.json',[rows[i,p] for i in ids for p in powers]),('summary.json',dict(powers=summary,comparisons=comparison,audit=audit)),('atlas.json',dict(meta=json.loads((DATA/'metadata.json').read_text()),powers=powers,cases=[gallery[i] for i in ids[:100]]))]:
 (OUT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False))
print(json.dumps(summary,indent=2))
