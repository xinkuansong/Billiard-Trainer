"""Compare adaptive centre colouring against retained exact 2 cm sample scores.

This is a display approximation audit, not proof of continuous-region safety.
It reuses existing baseline evidence; it performs no extra scoring or target perturbation.
"""
from pathlib import Path
import collections, json, math, statistics

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/defense-region-adaptive-20261105'
data=json.loads((OUT/'scan-adaptive.json').read_text())
base=json.loads((ROOT/'output/defense-region-fixed-target-20261105/scan-base.json').read_text())
assert data['target']==base['target']
groups=collections.defaultdict(list)
for r in data['rows']: groups[(r['ix'],r['iz'])].append(r)
left=min(r['bounds'][0] for r in data['rows']);top=min(r['bounds'][1] for r in data['rows'])
errors=[];boundary_changes=[];masked=[];uncovered=[]
for b in base['rows']:
    if 'score' not in b:continue
    ix=min(data['nx']-1,int(math.floor((b['x']-left)/data['dx'])))
    iz=min(data['nz']-1,int(math.floor((b['z']-top)/data['dz'])))
    hits=[r for r in groups[(ix,iz)] if r['bounds'][0]<=b['x']<=r['bounds'][2] and r['bounds'][1]<=b['z']<=r['bounds'][3]]
    if not hits:uncovered.append([b['x'],b['z']]);continue
    r=hits[0]
    if 'score' not in r:masked.append([b['x'],b['z']]);continue
    errors.append(abs(b['score']-r['score']))
    if (b['status']=='pot-block') != (r['status']=='pot-block'):
        boundary_changes.append({'point':[b['x'],b['z']],'exactScore':b['score'],
                                 'cellCentreScore':r['score'],'cellBounds':r['bounds'],'cellLevel':r['level']})
assert not uncovered,uncovered
errors.sort()
result={'comparedValidPoints':len(errors),'uncoveredPoints':uncovered,'validPointsInInvalidCentreCells':masked,
        'meanAbsoluteDisplayError':statistics.mean(errors),'p95AbsoluteDisplayError':errors[round(.95*(len(errors)-1))],
        'maximumAbsoluteDisplayError':max(errors),'blockClassificationDifferences':boundary_changes,
        'meaning':'Every leaf is coloured by its centre sample. Display error is against retained exact samples, not algorithmic score disagreement. No continuous-area certificate.'}
(OUT/'display-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({k:(len(v) if isinstance(v,list) else v) for k,v in result.items()},ensure_ascii=False,indent=2))
