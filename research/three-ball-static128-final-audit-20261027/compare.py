"""Compare actual outputs with the previous same-seed 128-question full-audit run."""
from pathlib import Path
import json,hashlib,collections
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output'/Path(__file__).resolve().parent.name;OLD=ROOT/'output/three-ball-static128-20261027'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def band(a):
 a=abs(a);return '0–10°' if a<10 else '10–20°' if a<20 else '20–30°' if a<30 else '30–50°' if a<50 else '50°+'
def main():
 a,b=read(OLD/'summary.json'),read(OUT/'summary.json');assert a['workers']==b['workers']==8
 assert (OLD/'inputs.json').read_bytes()==(OUT/'inputs.json').read_bytes()
 assert (OLD/'formations.json').read_bytes()==(OUT/'formations.json').read_bytes()
 assert a['counts']==b['counts'] and a['selectedHistogram']==b['selectedHistogram']
 assert (OLD/'native-output.json').read_bytes()==(OUT/'native-output.json').read_bytes()
 selected_pairs=0;unselected_pairs=0;rows=[];times=collections.defaultdict(list)
 for i in range(1,129):
  x,y=read(OLD/f'sample-{i:03}.json'),read(OUT/f'sample-{i:03}.json')
  for k in ['sample','counts','unresolvedIDs','blockSelectedIDs','selectedPositions']:assert x[k]==y[k],(i,k)
  assert len(x['groups'])==len(y['groups'])
  selected={c['id'] for c in y['selectedPositions']}
  for og,ng in zip(x['groups'],y['groups']):
   assert {k:v for k,v in og.items() if k!='dense'}=={k:v for k,v in ng.items() if k!='dense'},i
   passed={c['candidate'] for c in ng['checks'] if c['status']=='bounded_pass'};expected=sorted(selected&passed)
   assert ng['dense']['auditedCandidateIDs']==expected
   assert ng['dense']['comparisons']==len(expected)*ng['dense']['points']
   if expected:
    assert ng['dense']['points']==og['dense']['points'] and ng['dense']['minimumMargin']>0
    assert ng['dense']['minimumMargin']>=og['dense']['minimumMargin']-1e-10
   else:assert ng['dense']['points']==ng['dense']['comparisons']==0
   selected_pairs+=len(expected);unselected_pairs+=len(passed-selected)
  times[band(y['sample']['board']['angle'])].append(y['timing']['total'])
  rows.append(dict(sample=i,oldSeconds=x['timing']['total'],newSeconds=y['timing']['total']))
 population={v['band']:v['population'] for v in read(OLD/'estimate.json')['bands']};n=sum(population.values())
 scale=b['poolWallSeconds']/(b['taskSeconds']/8)
 weighted=sum(population[k]*np.mean(v) for k,v in times.items())/8*scale/3600
 random=np.random.default_rng(202610270128);boot=[]
 for _ in range(3000):boot.append(sum(population[k]*random.choice(v,len(v),replace=True).mean() for k,v in times.items())/8*scale/3600)
 report=dict(passed=True,inputsByteIdentical=True,formationsByteIdentical=True,nativeResultsIdentical=True,all128FullPartitionChecksIdentical=True,allBlockAndFinalSelectionsIdentical=True,allSelectedPocketOptionsDenseChecked=True,selectedCandidatePocketPairs=selected_pairs,unselectedCandidatePocketPairsNotDenseChecked=unselected_pairs,counts=b['counts'],oldPoolSeconds=a['poolWallSeconds'],newPoolSeconds=b['poolWallSeconds'],speedup=a['poolWallSeconds']/b['poolWallSeconds'],wallTimeReductionPercent=100*(1-b['poolWallSeconds']/a['poolWallSeconds']),oldEndToEndSeconds=a['endToEndSeconds'],newEndToEndSeconds=b['endToEndSeconds'],oldDenseComparisons=a['denseComparisons'],newDenseComparisons=b['denseComparisons'],fullLinearHours=b['poolWallSeconds']/128*n/3600,fullAngleWeightedHours=float(weighted),bootstrap5To95Hours=np.percentile(boot,[5,95]).tolist(),bootstrapCaveat='sampling-only range, not a runtime guarantee; sequential historical A/B, not simultaneous or repeated controlled timings',formationSHA256=sha(OUT/'formations.json'),fullGenerationStarted=False)
 (OUT/'comparison.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));(OUT/'per-question-times.json').write_text(json.dumps(rows,indent=2))
 print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
