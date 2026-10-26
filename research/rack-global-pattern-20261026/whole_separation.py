"""Post-validation exploratory whole-rack separation diagnostics; no policy selection."""
import json
import numpy as np
from analyze import OUT,R,EDGES,readraw,write
folder=OUT/'validation';compact={(r['id'],r['variant']):r for r in json.loads((folder/'rows.json').read_text())};features={};variants=json.loads((folder/'protocol.json').read_text())['variants']
for raw in readraw(folder):
 key=(raw['input']['rackID'],raw['input']['variant']);f={}
 for sample in raw['samples']:
  ms=round(sample['delay']*1000)
  if ms not in [5,20]:continue
  p=np.array([s['p'] for s in sample['states'][1:]])[:,[0,2]];v=np.array([s['v'] for s in sample['states'][1:]])[:,[0,2]]
  dist=np.linalg.norm(p[:,None]-p[None,:],axis=2);np.fill_diagonal(dist,np.inf);near=dist.argmin(1)
  opening=np.sum((p[near]-p)*(v[near]-v),axis=1)/dist.min(1)
  edgeOpening=np.array([np.dot(p[b]-p[a],v[b]-v[a])/np.linalg.norm(p[b]-p[a]) for a,b in EDGES])
  f[str(ms)]=dict(nearestOpeningQ25=float(np.quantile(opening,.25)),nearestOpeningMedian=float(np.median(opening)),nearestClosingBalls=int(np.sum(opening<0)),initialEdgeOpeningMean=float(edgeOpening.mean()),initialEdgeClosingCount=int(np.sum(edgeOpening<0)),speedQ20=float(np.quantile(np.linalg.norm(v,axis=1),.2)),nearestGapQ25MM=float(np.quantile(dist.min(1)-2*R,.25)*1000))
 features[key]=f
ids=sorted({k[0] for k in compact});summary=dict(purpose='Exploratory diagnostics defined after primary validation results; not independent confirmation or new selection',variants={},deltaCorrelations={})
for v in variants:
 summary['variants'][v]={t:{n:float(np.mean([features[i,v][t][n] for i in ids])) for n in features[ids[0],v][t]} for t in ['5','20']}
 if v=='baseline':continue
 ds=[compact[i,v]['score']-compact[i,'baseline']['score'] for i in ids]
 summary['deltaCorrelations'][v]={t:{n:float(np.corrcoef(ds,[features[i,v][t][n]-features[i,'baseline'][t][n] for i in ids])[0,1]) for n in features[ids[0],v][t]} for t in ['5','20']}
write(OUT/'whole-separation.json',summary);print(json.dumps(summary,indent=2))
