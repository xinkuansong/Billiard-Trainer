"""Frozen whole-rack factorial and independent paired validation analysis."""
from pathlib import Path
import sys,json,gzip,hashlib,math,itertools
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
import importlib.util
spec=importlib.util.spec_from_file_location('energy_analysis',ROOT/'research/rack-energy-separation-20261026/analyze.py')
energy=importlib.util.module_from_spec(spec);spec.loader.exec_module(energy)
extract,stats,L,W,R=energy.extract,energy.stats,energy.L,energy.W,energy.R
OUT=ROOT/'output/rack-global-pattern-20261026'
GROUPS=[[0,1,2],[4,7,8],[3,5,6,9],[11,12,13],[10,14]]
NAMES=['front','interior','flanks','rearMiddle','rearCorners']
S=np.float32(np.float32(R)*2+np.float32(.0002)); STEP=np.float32(S*np.sqrt(np.float32(3))/2)
NOM=np.array([[np.float32(-np.float32(L)/4-np.float32(r)*STEP),np.float32((np.float32(r)/2-np.float32(c))*S)] for r in range(5) for c in range(r+1)])
EDGES=[(a,b) for a in range(15) for b in range(a+1,15) if abs(math.dist(NOM[a],NOM[b])-S)<1e-6]
assert len(EDGES)==30

def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,allow_nan=False))
def readraw(folder):
 for p in sorted(folder.glob('raw-*.jsonl.gz')):
  with gzip.open(p,'rt') as f:
   for s in f:yield json.loads(s)
def ci(d,family=1):
 d=np.asarray(d); rng=np.random.default_rng(202610261502); a=[]
 for _ in range(100):a.extend(d[rng.integers(len(d),size=(200,len(d)))].mean(1))
 return dict(mean=float(d.mean()),ci95=np.quantile(a,[.025,.975]).tolist(),family95=np.quantile(a,[.025/family,1-.025/family]).tolist())
def expected(bp,variant):
 p=bp.copy()
 if variant=='toward':p[GROUPS[1],0]=NOM[GROUPS[1],0]+np.abs(bp[GROUPS[1],0]-NOM[GROUPS[1],0])
 if variant.startswith('g'):
  mask=int(variant[1:])
  for g,slots in enumerate(GROUPS):
   axis=1 if g in (2,4) else 0
   sign=1 if mask&(1<<g) else -1
   side=np.sign(NOM[slots,1]) if axis==1 else 1
   p[slots,axis]=NOM[slots,axis]+sign*side*np.abs(bp[slots,axis]-NOM[slots,axis])
 return p

def main(stage):
 folder=OUT/stage; protocol=json.loads((folder/'protocol.json').read_text()); ids=[r['rackID'] for r in protocol['racks']]; variants=protocol['variants']
 bases={r['input']['rackID']:r for r in readraw(folder) if r['input']['variant']=='baseline'}
 assert len(bases)==len(ids)
 result={}; keys=set(); gmin=1; gmax=0; offsetmax=0; radchange=0; anglemax=0; sources=[]
 for p in folder.glob('raw-*.jsonl.gz'):sources.append(dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
 for raw in readraw(folder):
  i,v=raw['input']['rackID'],raw['input']['variant']; assert (i,v) not in keys;keys.add((i,v))
  assert raw['status']=='settled',(i,v,raw['status'])
  base=bases[i];bp=np.array([[b['x'],b['z']] for b in base['rack']]);p=np.array([[b['x'],b['z']] for b in raw['rack']])
  assert raw['input']['seed']==base['input']['seed']
  assert np.max(np.abs(p-expected(bp,v)))<1e-7
  assert [b['number'] for b in base['rack']]==[b['number'] for b in raw['rack']]
  for f in ['cue','power','spin','simulatedElevation']:assert base[f]==raw[f]
  # The fixed rule aims at each actual apex. Moving the apex X changes the
  # direction by a tiny amount; do not falsely assert bit-identical aim.
  aim=p[0]-np.array(raw['cue']);aim/=np.linalg.norm(aim)
  assert np.max(np.abs(aim-raw['direction']))<1e-7
  anglemax=max(anglemax,abs(math.atan2(*raw['direction'][::-1])-math.atan2(*base['direction'][::-1])))
  pair=np.linalg.norm(p[:,None]-p[None,:],axis=2);gap=pair[np.triu_indices(15,1)]-2*R
  gmin=min(gmin,float(gap.min()));gmax=max(gmax,max(pair[a,b]-2*R for a,b in EDGES))
  radii=np.linalg.norm(p-NOM,axis=1); offsetmax=max(offsetmax,float(radii.max()));radchange=max(radchange,float(np.max(np.abs(radii-np.linalg.norm(bp-NOM,axis=1)))))
  row=extract(raw);row['variant']=v
  row['edgeGapMM']=[float((pair[a,b]-2*R)*1000) for a,b in EDGES]
  sample=min(raw['samples'],key=lambda s:abs(s['delay']-.005))
  vv=np.array([s['v'] for s in sample['states'][1:]]);ee=.085*(vv*vv).sum(1)
  row['energyShares5']=list(map(float,ee/ee.sum()))
  row['groupEnergyShares5']=[float(ee[g].sum()/ee.sum()) for g in GROUPS]
  row['pocketed']=raw['pocketed'];row['cueScratched']=raw['cueScratched']
  board=np.array([[v[0]*L-L/2,v[1]*L-W/2] for k,v in raw['board'].items() if k!='cueBall'])
  dd=np.linalg.norm(board[:,None]-board[None,:],axis=2);np.fill_diagonal(dd,np.inf)
  row['closeBallCount']=int(np.sum(dd.min(1)<4*R))
  result[i,v]=row
 assert keys==set(itertools.product(ids,variants))
 assert gmin>=.00002-3e-7 and gmax<=.00038+3e-7 and offsetmax<=.00009+1e-7 and radchange<1e-7
 binding=json.loads((folder/'source-binding.json').read_text())
 drift=[x['path'] for x in binding['production'] if hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()!=x['sha256']];assert not drift
 summary=dict(stage=stage,count=len(keys),seeds=len(ids),sources=sources,variants={},comparisons={},audit=dict(allSettled=True,gapMinMM=gmin*1000,neighborGapMaxMM=gmax*1000,maxOffsetMM=offsetmax*1000,maxRadiusChangeMM=radchange*1000,maxAimChangeRadians=anglemax,sourceDrift=drift),edges=EDGES)
 for v in variants:
  rr=[result[i,v] for i in ids]; ys=np.array([r['score'] for r in rr])
  summary['variants'][v]=dict(**stats(rr),p10=float(np.quantile(ys,.1)),cpuMeanMS=float(np.mean([r['cpuMS'] for r in rr])),closeBallMean=float(np.mean([r['closeBallCount'] for r in rr])),scratchRate=float(np.mean([r['cueScratched'] for r in rr])),edgeGapMM=np.mean([r['edgeGapMM'] for r in rr],axis=0).tolist(),energyShares5=np.mean([r['energyShares5'] for r in rr],axis=0).tolist(),groupEnergyShares5=np.mean([r['groupEnergyShares5'] for r in rr],axis=0).tolist(),mechanisms={f:float(np.mean([r['features']['5'][f] for r in rr])) for f in rr[0]['features']['5']})
 if stage=='discovery':
  ranking=sorted([v for v in variants if v.startswith('g')],key=lambda v:(-summary['variants'][v]['mean'],int(v[1:])))
  summary['ranking']=ranking;summary['selected']=ranking[:2]
  y=np.array([[result[i,f'g{m:02}']['score'] for m in range(32)] for i in ids]); signs=np.array([[1 if m&(1<<g) else -1 for g in range(5)] for m in range(32)])
  summary['factorEffects']={NAMES[g]:ci(2*(y*signs[:,g]).mean(1),15) for g in range(5)}
  summary['interactions']={NAMES[a]+'*'+NAMES[b]:ci(4*(y*signs[:,a]*signs[:,b]).mean(1),15) for a,b in itertools.combinations(range(5),2)}
  plan=json.loads((OUT/'validation-plan.json').read_text());plan['variants']=['baseline','toward']+ranking[:2];plan['selectedFrom']=dict(path=str(folder/'summary.json'),rule=protocol['selection']);del plan['variantsPending']
  assert not (OUT/'validation/protocol.json').exists();write(OUT/'validation/protocol.json',plan)
 else:
  comps=[(v,'baseline') for v in variants if v!='baseline']+[(v,'toward') for v in variants if v.startswith('g')]
  assert len(comps)==5
  for v,ref in comps:
   d=np.array([result[i,v]['score']-result[i,ref]['score'] for i in ids]); baseline=summary['variants'][ref]['mean']
   summary['comparisons'][v+'-'+ref]=dict(**ci(d,5),relativeMeanChange=float(d.mean()/baseline),better=int(np.sum(d>1e-12)),worse=int(np.sum(d< -1e-12)),wallDelta=ci([result[i,v]['wallMS']-result[i,ref]['wallMS'] for i in ids],5),halfMeans=[float(d[:500].mean()),float(d[500:].mean())])
 write(folder/'rows.json',[result[i,v] for i in ids for v in variants]);write(folder/'summary.json',summary)
 print(json.dumps(dict(count=len(keys),audit=summary['audit'],ranking=summary.get('ranking'),means={v:round(s['mean'],6) for v,s in summary['variants'].items()},comparisons=summary['comparisons']),indent=2))
if __name__=='__main__':main(sys.argv[1])
