"""Independent saved-angle and coordinate-transform checks."""
from pathlib import Path
import hashlib,json,math,urllib.request
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-natural-review-20261029'
d=json.loads((OUT/'data.json').read_text());audit=json.loads((OUT/'source-audit.json').read_text());R=d['geometry']['radius']
rows={e['id']:e for e in d['selected']};errors=[]
for e in rows.values():
    pts=[p[1:] for p in e['route']['trajectory2mm']['points']];i=e['pointIndex'];p=pts[i]
    horizontal=abs(abs(p[1])-(d['geometry']['width']/2-R))<1e-3
    for q,field in [(pts[i-1],'inAngle'),(pts[i+1],'outAngle')]:
        v=[q[k]-p[k] for k in (0,1)];length=math.hypot(*v);assert length>1e-8
        if e['railOrdinal']==1:assert length>=.06
        angle=math.degrees(math.acos(min(1,abs(v[0 if horizontal else 1])/length)))
        errors.append(abs(angle-e[field]));assert errors[-1]<1e-8
    t=e['tangent'];n=e['inward'];assert abs(sum(t[k]*n[k] for k in (0,1)))<1e-12
    assert abs(math.hypot(*t)-1)<1e-12 and abs(math.hypot(*n)-1)<1e-12
    for key in ['localIn','localOut']:
        arr=e[key];assert all(q[1]>=R-1e-6 for q in arr)
        assert sum(math.dist(a,b) for a,b in zip(arr,arr[1:]))<=.3500001
        assert math.dist(arr[-1 if key=='localIn' else 0],[0,R])<1e-10
        # The local crop maps back onto the archived polyline.
        for q in arr:
            w=[p[k]+q[0]*t[k]+(q[1]-R)*n[k] for k in (0,1)]
            ds=[]
            for a,b in zip(pts,pts[1:]):
                v=[b[k]-a[k] for k in (0,1)];den=sum(x*x for x in v)
                u=max(0,min(1,sum((w[k]-a[k])*v[k] for k in (0,1))/den)) if den else 0
                ds.append(math.dist(w,[a[k]+u*v[k] for k in (0,1)]))
            assert min(ds)<1e-8
# Recompute screening metrics from original points, independently of saved review metrics.
f=d['screening']['filters'];hx=d['geometry']['length']/2;hz=d['geometry']['width']/2
pockets=[[-hx,-hz],[hx,-hz],[-hx,hz],[hx,hz],[0,-hz],[0,hz]]
for e in rows.values():
    r=e['route'];pts=[p[1:] for p in r['trajectory2mm']['points']];i=e['pointIndex'];j=e['railOrdinal']-1;cs=r['trajectory2mm']['cushions']
    arc=lambda a,b:sum(math.dist(pts[k],pts[k+1]) for k in range(a,b))
    indices=[0]+[c['pointIndex'] for c in cs[:j+1]];hi=cs[j+1]['pointIndex'] if j+1<len(cs) else len(pts)-1
    actual={'prefixMeters':arc(0,i),'remainingMeters':arc(i,len(pts)-1),'incomingLegMeters':arc(indices[-2],i),
      'outgoingLegMeters':arc(i,hi),'minPriorLegMeters':min(arc(a,b) for a,b in zip(indices[:-1],indices[1:-1])) if j else None,
      'minPriorRailPocketDistanceMeters':min(math.dist(pts[k],p) for k in indices[1:-1] for p in pockets) if j else None,
      'observationPocketDistanceMeters':min(math.dist(pts[i],p) for p in pockets)}
    assert all(actual[k] is None if v is None else abs(actual[k]-v)<1e-10 for k,v in e['reviewMetrics'].items())
    common=(e['railOrdinal']<=3 and r['velocity']<=f['maxVelocity'] and abs(r['spinX'])<=f['maxAbsSideSpin'] and abs(r['spinY'])<=f['maxAbsVerticalSpin']
      and actual['prefixMeters']<=f['maxPrefixMetersByRail'][str(j+1)] and actual['incomingLegMeters']>=f['minIncomingLegMeters']
      and (j==0 or actual['minPriorLegMeters']>=f['minPriorLegMeters']) and (j==0 or actual['minPriorRailPocketDistanceMeters']>=f['minPriorRailPocketDistanceMeters']))
    before=common;after=common and actual['outgoingLegMeters']>=f['afterMinOutgoingLegMeters'] and actual['remainingMeters']>=f['afterMinRemainingMeters']
    assert e['eligibility']['inAngle']['passed']==before and e['eligibility']['outAngle']['passed']==after
    assert e['nearObservationPocket']==(actual['observationPocketDistanceMeters']<f['nearObservationPocketWarningMeters'])
assert any(e['key']==d['screening']['referenceKey'] for e in rows.values())
old=json.loads((ROOT/'output/k-ball-rail-angle-review-20261029/data.json').read_text())
rejected={e['key'] for e in old['selected'] if e['id'] in ['E01','E09','E12']}
assert not rejected.intersection(e['key'] for e in rows.values())
for axis,groups in d['groups'].items():
    for group in groups:
        assert len(set(group['ids']))==len(group['ids'])
        assert all(group['lower']<=rows[id][axis]<group['upper'] for id in group['ids'])
# Each axis contains ALL passing second/third events, and no failing events.
for axis,groups in d['groups'].items():
    expected={e['key'] for e in d['screening']['eventAudit'] if e['railOrdinal']>=2 and e[axis]['passed'] and e['key'] not in {x['key'] for x in d['reviewDecisions']['excluded']}}
    shown=[rows[id] for g in groups for id in g['ids']]
    assert {e['key'] for e in shown if e['railOrdinal']>=2}==expected
    assert all(e['eligibility'][axis]['passed'] for e in shown)
    assert all(a[axis]<=b[axis] for a,b in zip(shown,shown[1:]))
assert rows['N08-R2']['key']=='grid-v3:2137:66:0/217/2'
assert rows['N08-R2']['shortAngleSegment'] and rows['N08-R2']['reviewMetrics']['remainingMeters']>.9
assert all('N01-R3' not in g['ids'] for gs in d['groups'].values() for g in gs)
assert all(any('N01' in g['ids'] for g in gs) for gs in d['groups'].values())
assert rows['N04-R3']['key']=='grid-v3:1753:54:5/10266/3'
assert rows['N04-R3']['eligibility']['inAngle']['passed'] and not rows['N04-R3']['eligibility']['outAngle']['passed']
assert rows['N04-R3']['nearObservationPocket'] and .32<rows['N04-R3']['reviewMetrics']['remainingMeters']<.34
baseline=json.loads(Path(__file__).with_name('baseline-second-selection.json').read_text())
assert all(rows[e['id']]['key']==e['key'] for e in baseline['rows'])
for name,digest in {**audit['bindings'],**audit['indices']}.items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest
files=['index.html','data.json','source-audit.json']+[str(p.relative_to(OUT)) for p in (OUT/'images').glob('*.png')]+[p.name for p in OUT.glob('overview-*.jpg')]
for name in files:
    with urllib.request.urlopen('http://127.0.0.1:8851/'+name) as r:assert r.status==200
result={'passed':True,'uniqueExamples':len(rows),'displaySlots':sum(len(g['ids']) for gs in d['groups'].values() for g in gs),'angleMaxDifferenceDegrees':max(errors),'httpResources':len(files),
        'sourceUnchanged':True,'checks':['acos independent angles','orthonormal transform','35cm clipping','local crop maps to source','bin membership','SHA','screening metrics and thresholds','all eligible second/third rails shown per-axis; stable IDs; N08-R2 retained; N04-R3 before-only','E02 retained; E01 E09 E12 excluded'],
        'scope':'Archive geometry and presentation only; no instantaneous physical angles or K-shot robustness claim'}
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(result)
