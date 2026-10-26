"""Secondary radial-phase analysis, frozen after discovery before validation readout."""
from common import *
import sys,hashlib,datetime

def phases(stage):
 rr={(r['id'],r['variant']):r for r in json.loads((OUT/stage/'rows.json').read_text())};a=[]
 q=NOM.astype(float)-NOM.astype(float).mean(0);q/=np.linalg.norm(q,axis=1)[:,None]
 for raw in readraw(OUT/stage):
  if raw['input']['variant']!='radial_full':continue
  p=np.array([[b['x'],b['z']] for b in raw['rack']]);d=p-NOM;r=np.linalg.norm(d,axis=1);u=d/np.where(r>0,r,1)[:,None]
  cosine=float(np.mean(np.sum(u*q,axis=1)));sine=float(np.mean(q[:,0]*u[:,1]-q[:,1]*u[:,0]));i=raw['input']['rackID']
  a.append(dict(id=i,cosine=cosine,sine=sine,delta=rr[i,'radial_full']['score']-rr[i,'baseline']['score'],score=rr[i,'radial_full']['score'],baseline=rr[i,'baseline']['score'],gapMM=float(np.mean(rr[i,'radial_full']['edgeGapMM']))))
 return a

def summarize(a):
 pos=[r for r in a if r['cosine']>=0];neg=[r for r in a if r['cosine']<0]
 summary={label:dict(n=len(rows),mean=float(np.mean([r['score'] for r in rows])),baselineMean=float(np.mean([r['baseline'] for r in rows])),gapMeanMM=float(np.mean([r['gapMM'] for r in rows])),delta=ci([r['delta'] for r in rows],3)) for label,rows in [('expanding',pos),('contracting',neg)]}
 rng=np.random.default_rng(202610261705);x=np.array([r['delta'] for r in pos]);y=np.array([r['delta'] for r in neg]);s=[]
 for _ in range(100):s.extend(x[rng.integers(len(x),size=(200,len(x)))].mean(1)-y[rng.integers(len(y),size=(200,len(y)))].mean(1))
 summary['interaction']=dict(mean=float(x.mean()-y.mean()),family95=np.quantile(s,[.025/3,1-.025/3]).tolist());return summary
if __name__=='__main__':
 stage=sys.argv[1];a=phases(stage);summary=summarize(a);write(OUT/(stage+'-phase-rows.json'),a);write(OUT/(stage+'-phase.json'),summary)
 if stage=='discovery':
  assert not (OUT/'validation/summary.json').exists()
  plan=dict(createdUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),basis='Secondary hypothesis derived from radial policy geometry after discovery; frozen before validation result readout',cut='mean cosine of each offset with its radial-from-rack-center direction >=0 expanding, else contracting',tests='Radial vs paired baseline within each half, plus difference of those changes; 3 familywise95 comparisons, 20000 rack bootstrap. Secondary family distinct from primary5.',noSelection='No change to selected policies or simulation parameters. No new production rule is implied by subgroup association.',scriptSHA=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
  write(OUT/'phase-plan.json',plan)
 print(json.dumps(summary,indent=2))
