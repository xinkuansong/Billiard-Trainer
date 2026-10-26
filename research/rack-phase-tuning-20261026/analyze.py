from pathlib import Path
import sys,json,hashlib,itertools,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'research/rack-correlated-pattern-20261026'))
import common as old
from common import NOM,R,L,W,EDGES,readraw,write,extract,stats,ci,sequence
OUT=ROOT/'output/rack-phase-tuning-20261026'
q=NOM.astype(float)-NOM.astype(float).mean(0);q/=np.linalg.norm(q,axis=1)[:,None]
t=np.column_stack([-q[:,1],q[:,0]])
def expected(bp,v):
 if v in ('baseline','radial_contract'):return old.expected(bp,v)
 d=bp-NOM;r=np.linalg.norm(d,axis=1);u=d/np.where(r>0,r,1)[:,None];u[r==0]=[1,0]
 c=np.array([np.mean(np.sum(u*q,axis=1)),np.mean(np.sum(u*t,axis=1))]);phase=math.atan2(abs(c[1]),abs(c[0]));sign=1 if c[1]>=0 else -1
 angle=0 if v=='radial_pure' else math.radians(int(v.split('band')[1])*15+phase/(math.pi/2)*15)
 return np.float32(NOM.astype(float)+r[:,None]*(-math.cos(angle)*q+sign*math.sin(angle)*t))
def geometry(raw,base):
 bp=np.array([[b['x'],b['z']] for b in base['rack']]);p=np.array([[b['x'],b['z']] for b in raw['rack']]);v=raw['input']['variant']
 error=float(np.max(np.abs(expected(bp,v)-p)));assert error<1e-7,(raw['input']['id'],error)
 rad=np.linalg.norm(p-NOM,axis=1);change=float(np.max(np.abs(rad-np.linalg.norm(bp-NOM,axis=1))))
 pair=np.linalg.norm(p[:,None]-p[None,:],axis=2);gap=pair[np.triu_indices(15,1)]-2*R
 assert rad.max()<.0000901 and gap.min()>.0000197 and change<1e-7
 assert [b['number'] for b in raw['rack']]==[b['number'] for b in base['rack']]
 assert raw['cue']==[L/4,0] and raw['power']==9.75 and raw['spin']==[0,0] and raw['simulatedElevation']==0
 aim=p[0]-raw['cue'];aim/=np.linalg.norm(aim);assert np.max(np.abs(aim-raw['direction']))<1e-7
 u=(p-NOM)/rad[:,None];c=float(np.mean(np.sum(u*q,axis=1)));s=float(np.mean(np.sum(u*t,axis=1)))
 angle=math.degrees(math.atan2(abs(s),-c))
 # Direction angles reconstructed after Float rounding are ill-conditioned for near-zero offsets.
 # Independent Cartesian transform and radius bounds above are the acceptance gate.
 # Record angles descriptively; never reject valid small-radius racks by a fixed angular tolerance.
 return dict(errorM=error,minGapMM=float(gap.min()*1000),maxRadiusChangeMM=change*1000,maxOffsetMM=float(rad.max()*1000)),dict(edgeGapMM=[float((pair[a,b]-2*R)*1000) for a,b in EDGES],angle=angle,sign=1 if s>=0 else -1)
def outcome(raw):
 p=np.array([[a[0]*L-L/2,a[1]*L-W/2] for k,a in raw['board'].items() if k!='cueBall']);n=len(p)
 d=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(d,np.inf);adj=d<4*R;close=int(np.any(adj,axis=1).sum());seen=set();components=[]
 for i in range(n):
  if i in seen:continue
  todo=[i];seen.add(i);size=0
  while todo:
   j=todo.pop();size+=1
   for k in np.flatnonzero(adj[j]):
    if int(k) not in seen:seen.add(int(k));todo.append(int(k))
  components.append(size)
 return dict(closeBalls=close,closeFraction=close/n,largestGroup=max(components),scratch=int(raw['cueScratched']))
def main(stage):
 folder=OUT/stage;plan=json.loads((folder/'protocol.json').read_text());ids=[r['rackID'] for r in plan['racks']];vs=plan['variants']
 bases={r['input']['rackID']:r for r in readraw(folder) if r['input']['variant']=='baseline'};rows={};audits=[]
 for raw in readraw(folder):
  i,v=raw['input']['rackID'],raw['input']['variant'];assert (i,v) not in rows and raw['status']=='settled'
  assert raw['input']['seed']==bases[i]['input']['seed'];a,g=geometry(raw,bases[i]);audits.append(a)
  r=extract(raw);r.update(variant=v,**g,**outcome(raw),**sequence(raw));rows[i,v]=r
 assert set(rows)==set(itertools.product(ids,vs))
 assert {(r['rackID'],r['seed']) for r in plan['racks']}=={(i,bases[i]['input']['seed']) for i in ids}
 result=dict(stage=stage,count=len(rows),variants={},comparisons={},audit={k:(min(a[k] for a in audits) if k=='minGapMM' else max(a[k] for a in audits)) for k in audits[0]})
 for v in vs:
  rr=[rows[i,v] for i in ids]
  result['variants'][v]=dict(**stats(rr),**{k:float(np.mean([r[k] for r in rr])) for k in ['scratch','closeBalls','closeFraction','largestGroup','remaining','cpuMS']},edgeGapMM=float(np.mean([r['edgeGapMM'] for r in rr])),censored=sum(bool(r['censoredSlots']) for r in rr),internalEnergy5=float(np.mean([r['features']['5']['interiorEnergyFraction'] for r in rr])),effectiveBalls5=float(np.mean([r['features']['5']['effectiveBalls'] for r in rr])))
  result['variants'][v]['signDiagnostics']={str(s):dict(n=sum(r['sign']==s for r in rr),mean=float(np.mean([r['score'] for r in rr if r['sign']==s]))) for s in [-1,1] if any(r['sign']==s for r in rr)}
 if stage=='discovery':
  rank=sorted((v for v in vs if v not in ['baseline','radial_contract']),key=lambda v:(-result['variants'][v]['mean'],v));result.update(ranking=rank,selected=rank[:2])
  nextplan=json.loads((OUT/'validation-plan.json').read_text());del nextplan['variantsPending'];nextplan['variants']=['baseline','radial_contract']+rank[:2];nextplan['selectionEvidence']=dict(summaryMeans={v:r['mean'] for v,r in result['variants'].items()},discoveryProtocolSHA256=hashlib.sha256((folder/'protocol.json').read_bytes()).hexdigest())
  assert not (OUT/'validation/protocol.json').exists();write(OUT/'validation/protocol.json',nextplan)
 else:
  comparisons=[('radial_contract','baseline')]+[(v,ref) for v in vs[2:] for ref in ['baseline','radial_contract']]
  for v,ref in comparisons:
   delta=np.array([rows[i,v]['score']-rows[i,ref]['score'] for i in ids]);half=len(ids)//2
   c=dict(**ci(delta,5),relative=float(delta.mean()/result['variants'][ref]['mean']),halfMeans=[float(delta[:half].mean()),float(delta[half:].mean())])
   for k in ['scratch','wallMS','cpuMS']:
    c[k]=ci([rows[i,v][k]-rows[i,ref][k] for i in ids],5)
   c['pass']=ci([int(rows[i,v]['score']>=1.2)-int(rows[i,ref]['score']>=1.2) for i in ids],5)
   result['comparisons'][v+'--'+ref]=c
 binding=json.loads((folder/'source-binding.json').read_text())
 exceptions=json.loads((OUT/'source-exceptions.json').read_text())
 for r in binding['production']:
  current=hashlib.sha256((ROOT/r['path']).read_bytes()).hexdigest()
  if current!=r['sha256']:
   e=next(e for e in exceptions if e['path']==r['path']);assert current==e['currentSHA256'] and r['sha256']==e['frozenSHA256']
   assert stage=='discovery' and json.loads((folder/'post-run-review.json').read_text())['simulationValid']
 result['audit'].update(allSettled=True,sourceBindings=len(binding['production']))
 write(folder/'rows.json',[rows[i,v] for i in ids for v in vs]);write(folder/'summary.json',result)
 print(json.dumps(result,indent=2))
if __name__=='__main__':main(sys.argv[1])
