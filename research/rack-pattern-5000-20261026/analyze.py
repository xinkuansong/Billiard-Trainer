"""Frozen train/holdout analysis; only this research directory and its output are written."""
from pathlib import Path
import json,math,hashlib,statistics,csv,itertools
import numpy as np
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'output/rack-pattern-5000-20261026'
def write(name,x):
 (OUT/name).write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def pct(x):return float(np.mean(x))
def main():
 protocol=json.loads((OUT/'protocol.json').read_text()); cal=json.loads((OUT/'calibration.json').read_text()); meta=json.loads((OUT/'metadata.json').read_text())
 generation=json.loads((OUT/'generation.json').read_text()); assert generation['complete'] and generation['count']==5000
 specs=json.loads((OUT/'racks.json').read_text()); inputs={x['id']:x for x in json.loads((OUT/'inputs.json').read_text())};pos=[x['name'] for x in protocol['positions']]
 L,W,R=(meta[x] for x in ['length','width','radius']); rows=[];racks={};outcomes={}; checks=0
 for part in generation['parts']:
  p=OUT/f"raw-{part['worker']}.jsonl"; assert sha(p)==part['sha256']
  rows += [json.loads(s) for s in p.read_text().splitlines()]
 assert len(rows)==5000 and len({r['input']['id'] for r in rows})==5000
 Y=np.zeros((1000,5)); indexes=np.full((1000,5),np.nan); Ns=np.zeros((1000,5),dtype=int); wall=np.zeros((1000,5));cpu=np.zeros((1000,5)); scratch=np.zeros((1000,5)); valid=np.zeros((1000,5),dtype=bool)
 for row in rows:
  inp=row['input'];assert inp==inputs[inp['id']]
  i=inp['rackID'];j=pos.index(inp['position']);assert inp['seed']==specs[i]['seed'] and inp['split']==specs[i]['split']
  rack=row['rack'];assert len(rack)==15 and {b['number'] for b in rack}==set(range(1,16))
  if i in racks:assert racks[i]==rack
  else:racks[i]=rack
  # Entire initial rack finite, nonoverlapping, within table; independent scalar geometry.
  ps=[(b['x'],b['z']) for b in rack]
  assert all(math.isfinite(c) for p in ps for c in p)
  assert min(math.dist(a,b) for a,b in itertools.combinations(ps,2))>=2*R-1e-7
  wall[i,j]=row.get('seconds',0);cpu[i,j]=row.get('cpuSeconds',0)
  if row['status']=='settled':
   board=row['board'];potted=set(row['pocketed']);assert not set(board)&potted
   assert set(board)|potted=={'cueBall'}|{f'_{k}' for k in range(1,16)}
   assert row['cueScratched']==('cueBall' in potted);scratch[i,j]=row['cueScratched']
   targets=[(v[0]*L-L/2,v[1]*L-W/2) for k,v in sorted(board.items()) if k!='cueBall'];n=len(targets);Ns[i,j]=n
   assert all(math.isfinite(c) for p in targets for c in p)
   if n>1:assert min(math.dist(a,b) for a,b in itertools.combinations(targets,2))>=2*R-1.1e-5
   assert all(abs(x)<=L/2+R and abs(z)<=W/2+R for x,z in targets)
   if str(n) in cal['reference']:
    a=np.array(targets);ds=np.linalg.norm(a[:,None,:]-a[None,:,:],axis=2);np.fill_diagonal(ds,np.inf)
    mean=float(ds.min(axis=1).mean());scalar=statistics.mean(min(math.dist(p,q) for k,q in enumerate(targets) if k!=h) for h,p in enumerate(targets));assert abs(mean-scalar)<1e-12
    index=mean/cal['reference'][str(n)]['expectedMeanM'];indexes[i,j]=index;Y[i,j]=int(index>=1.2);valid[i,j]=True
  outcomes[(i,j)]=row;checks+=1
 assert valid.all(),'Incomplete or out-of-calibration rows must be separately handled and reported, never silently excluded'
 # Physical slot labels follow production row order, independent of shuffled ball numbers.
 labels=[f'{chr(65+r)}{c+1}' for r in range(5) for c in range(r+1)]
 rowID=np.array([r for r in range(5) for c in range(r+1)])
 spacing=2*R+.0002;step=spacing*math.sqrt(3)/2
 nominal=np.array([[-L/4-r*step,(r/2-c)*spacing] for r in range(5) for c in range(r+1)])
 edges=[(i,j) for i,j in itertools.combinations(range(15),2) if abs(np.linalg.norm(nominal[i]-nominal[j])-spacing)<1e-6];assert len(edges)==30
 assert edges[:2]==[(0,1),(0,2)]
 positions=np.array([[(b['x'],b['z']) for b in racks[i]] for i in range(1000)])
 gaps=np.array([[(math.dist(p[a],p[b])-2*R)*1000 for a,b in edges] for p in positions])
 assert gaps.min()>=.019 and gaps.max()<=.381
 features=[dict(name=f'{labels[a]}–{labels[b]}',type='edge',slots=[a,b]) for a,b in edges];vals=[gaps[:,i] for i in range(30)]
 def add(name,v,**kw):features.append(dict(name=name,**kw));vals.append(v)
 add('顶球两边平均缝隙',gaps[:,:2].mean(1),type='aggregate',edgeIndices=[0,1]);add('顶球两边缝隙绝对差',abs(gaps[:,0]-gaps[:,1]),type='aggregate',edgeIndices=[0,1])
 for r in range(1,5):
  ids=[k for k,(a,b) in enumerate(edges) if rowID[a]==rowID[b]==r];add(f'{chr(65+r)}排内平均缝隙',gaps[:,ids].mean(1),type='aggregate',edgeIndices=ids)
 for r in range(4):
  ids=[k for k,(a,b) in enumerate(edges) if {rowID[a],rowID[b]}=={r,r+1}];add(f'{chr(65+r)}到{chr(66+r)}排间平均缝隙',gaps[:,ids].mean(1),type='aggregate',edgeIndices=ids)
 sides=[]
 for sign,word in [(1,'下侧+Z'),(-1,'上侧−Z')]:
  ids=[k for k,(a,b) in enumerate(edges) if sign*(nominal[a,1]+nominal[b,1])>1e-9];sides.append(gaps[:,ids].mean(1));add(f'{word}平均缝隙',sides[-1],type='aggregate',edgeIndices=ids)
 add('两侧平均缝隙之差(+Z减−Z)',sides[0]-sides[1],type='aggregate')
 for word,fn in [('平均',np.mean),('最小',np.min),('最大',np.max),('标准差',np.std)]:add(f'全架缝隙{word}',fn(gaps,axis=1),type='aggregate')
 # Six fixed straight diagonals from the upper three rows to the base.
 for start in range(6):
  rr=int(rowID[start]);cc=start-rr*(rr+1)//2
  for direction in ([0,1] if rr<2 else [cc%2]):
   slots=[start]
   for r in range(rr+1,5):
    cc+=direction;slots.append(r*(r+1)//2+cc)
   ids=[edges.index(tuple(sorted((a,b)))) for a,b in zip(slots,slots[1:])]
   add('链'+''.join(labels[s]+'/' for s in slots).rstrip('/'),gaps[:,ids].mean(1),type='chain',slots=slots,edgeIndices=ids)
 X=np.column_stack(vals);yr=Y.mean(1);train=np.array([r['split']=='train' for r in specs]);hold=~train;assert train.sum()==800 and hold.sum()==200
 write('features.json',dict(labels=labels,nominal=nominal.tolist(),edges=edges,features=features,values=X.tolist(),units='mm'))
 # Train-only selection. Single candidate plus <=2 highest positive depth2 tree leaves.
 candidates=[];scan=[]
 for f in range(X.shape[1]):
  for q in [.2,.5,.8]:
   t=float(np.quantile(X[train,f],q))
   for le in [True,False]:
    m=(X[:,f]<=t) if le else (X[:,f]>t);a=train&m;b=train&~m
    if min(a.sum(),b.sum())<100:continue
    delta=float(yr[a].mean()-yr[b].mean())
    scan.append(dict(feature=f,threshold=t,le=le,quantile=q,selected=int(a.sum()),delta=delta))
 best=max(scan,key=lambda x:(x['delta'],-x['feature']));candidates.append(dict(origin='single',conditions=[{k:best[k] for k in ['feature','threshold','le']}]))
 def grow(ids,conditions,depth):
  if depth==2 or len(ids)<200:return [(conditions,ids)]
  y=yr[ids];base=float(((y-y.mean())**2).sum());bestSplit=None
  for f in range(X.shape[1]):
   order=ids[np.argsort(X[ids,f],kind='stable')];v=X[order,f];z=yr[order];cs=np.cumsum(z);cs2=np.cumsum(z*z);n=len(ids)
   ks=np.arange(100,n-99);ks=ks[v[ks-1]<v[ks]]
   if not len(ks):continue
   sums=cs[ks-1];loss=cs2[ks-1]-sums*sums/ks+(cs2[-1]-cs2[ks-1])-(cs[-1]-sums)**2/(n-ks)
   idx=int(np.argmin(loss));k=int(ks[idx]);improvement=base-float(loss[idx]);t=float((v[k-1]+v[k])/2)
   if bestSplit is None or improvement>bestSplit[0]:bestSplit=(improvement,f,t,order[:k],order[k:])
  if bestSplit is None or bestSplit[0]<=1e-12:return [(conditions,ids)]
  _,f,t,left,right=bestSplit
  return grow(left,conditions+[dict(feature=f,threshold=t,le=True)],depth+1)+grow(right,conditions+[dict(feature=f,threshold=t,le=False)],depth+1)
 leaves=grow(np.where(train)[0],[],0); leaves=sorted(leaves,key=lambda x:float(yr[x[1]].mean()),reverse=True)
 for conditions,ids in leaves:
  if not conditions or len(candidates)>=3:continue
  if yr[ids].mean()<=yr[train].mean():continue
  if conditions==candidates[0]['conditions']:continue
  candidates.append(dict(origin='depth2-tree',conditions=conditions))
 for k,c in enumerate(candidates):c['id']=f'R{k+1}'
 lock=dict(protocolSHA=sha(OUT/'protocol.json'),trainingRackIDs=np.where(train)[0].tolist(),features=features,candidates=candidates,trainBaseline=float(yr[train].mean()),treeLeaves=[dict(conditions=c,trainCount=len(ids),rate=float(yr[ids].mean())) for c,ids in leaves],scanCount=len(scan))
 write('candidate-lock.json',lock) # Written BEFORE any holdout metrics or rankings.
 def mask(c):
  m=np.ones(1000,dtype=bool)
  for x in c['conditions']:m&=(X[:,x['feature']]<=x['threshold']) if x['le'] else (X[:,x['feature']]>x['threshold'])
  return m
 def metrics(ids):
  a=Y[ids];return dict(racks=int(ids.sum()),shots=int(a.size),successes=int(a.sum()),rate=float(a.mean()),meanIndex=float(indexes[ids].mean()),meanPotted=float((15-Ns[ids]).mean()),noPotShots=int((Ns[ids]==15).sum()),wallMedianMS=float(np.median(wall[ids])*1000),wallP95MS=float(np.quantile(wall[ids],.95)*1000),wallMaxMS=float(wall[ids].max()*1000),cpuMedianMS=float(np.median(cpu[ids])*1000),cpuP95MS=float(np.quantile(cpu[ids],.95)*1000),byPosition=[dict(name=p,successes=int(Y[ids,j].sum()),rate=float(Y[ids,j].mean()),meanIndex=float(indexes[ids,j].mean())) for j,p in enumerate(pos)])
 rng=np.random.default_rng(202610260504);results=[]
 for c in candidates:
  m=mask(c);sel=hold&m;other=hold&~m;a=yr[sel];b=yr[other]
  assert len(a)>0 and len(b)>0
  boot=a[rng.integers(len(a),size=(5000,len(a)))].mean(1)-b[rng.integers(len(b),size=(5000,len(b)))].mean(1)
  ci=np.quantile(boot,[.05/(2*3),1-.05/(2*3)]).tolist()
  def sensitivity(ids):
   out=[]
   for n in sorted(set(Ns[hold].flat)):
    both=ids[:,None]&(Ns==n);count=int(both.sum())
    if count:out.append(dict(remaining=int(n),shots=count,rate=float(Y[both].mean()),meanIndex=float(indexes[both].mean())))
   return out
  text=[]
  for x in c['conditions']:text.append(f"{features[x['feature']]['name']} {'≤' if x['le'] else '>'} {x['threshold']:.6f} mm")
  results.append(dict(**c,description=' 且 '.join(text),trainSelected=metrics(train&m),trainOther=metrics(train&~m),holdoutSelected=metrics(sel),holdoutOther=metrics(other),holdoutDelta=float(a.mean()-b.mean()),holdoutDeltaSimultaneousCI=ci,positiveValidated=ci[0]>0,holdoutByRemainingSelected=sensitivity(sel),holdoutByRemainingOther=sensitivity(other),selectedRackIDs=np.where(m)[0].tolist()))
 # Bootstrap on rack rows for baseline and position-specific rates.
 allboot=Y[rng.integers(1000,size=(5000,1000))].mean(axis=(1,2));baseci=np.quantile(allboot,[.025,.975]).tolist()
 summary=dict(complete=True,shots=5000,racks=1000,scored=int(valid.sum()),incomplete=0,baseline=metrics(np.ones(1000,dtype=bool)),baselineClusterCI95=baseci,train=metrics(train),holdout=metrics(hold),candidateLockSHA=sha(OUT/'candidate-lock.json'),candidates=results,initialGapMM=dict(min=float(gaps.min()),max=float(gaps.max()),mean=float(gaps.mean())),features=X.shape[1],selectionTrials=len(scan),remainingCounts={str(n):int((Ns==n).sum()) for n in sorted(set(Ns.flat))},scratchCount=int(scratch.sum()),validationReplays=sum(p['replays'] for p in generation['parts']))
 write('analysis.json',summary)
 # Long-form data export retains outcomes and audit identities.
 with (OUT/'shots.csv').open('w') as f:
  names=['rackID','split','seed','position','remaining','index','success','wallMS','cpuMS','scratch'];w=csv.DictWriter(f,fieldnames=names);w.writeheader()
  for i in range(1000):
   for j,p in enumerate(pos):w.writerow(dict(rackID=i,split=specs[i]['split'],seed=specs[i]['seed'],position=p,remaining=Ns[i,j],index=indexes[i,j],success=int(Y[i,j]),wallMS=wall[i,j]*1000,cpuMS=cpu[i,j]*1000,scratch=int(scratch[i,j])))
 before=json.loads((OUT/'source-before.json').read_text());drift=[p for p,h in before.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h]
 write('audit.json',dict(passed=True,rows=checks,racks=1000,pairedFiveIdenticalRacks=True,independentDistanceCheck=True,splitDisjoint=True,trainOnlyRuleSelection=True,nativeReplays=summary['validationReplays'],inputSHA=sha(OUT/'inputs.json'),protocolSHA=sha(OUT/'protocol.json'),calibrationSHA=sha(OUT/'calibration.json'),sourceChangesDuringRun=drift,productionBindingDrift=generation['productionBindingDrift']))
 print(json.dumps(dict(baseline=summary['baseline'],candidates=[dict(description=x['description'],train=x['trainSelected']['rate'],holdout=x['holdoutSelected']['rate'],other=x['holdoutOther']['rate'],n=x['holdoutSelected']['racks'],ci=x['holdoutDeltaSimultaneousCI']) for x in results]),ensure_ascii=False,indent=2))
if __name__=='__main__':main()
