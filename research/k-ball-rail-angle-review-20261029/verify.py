"""Independent saved-angle and coordinate-transform checks."""
from pathlib import Path
import hashlib,json,math,urllib.request
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-rail-angle-review-20261029'
d=json.loads((OUT/'data.json').read_text());audit=json.loads((OUT/'source-audit.json').read_text());R=d['geometry']['radius']
rows={e['id']:e for e in d['selected']};errors=[]
for e in rows.values():
    pts=[p[1:] for p in e['route']['trajectory2mm']['points']];i=e['pointIndex'];p=pts[i]
    horizontal=abs(abs(p[1])-(d['geometry']['width']/2-R))<1e-3
    for q,field in [(pts[i-1],'inAngle'),(pts[i+1],'outAngle')]:
        v=[q[k]-p[k] for k in (0,1)];length=math.hypot(*v);assert length>=.06
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
for axis,groups in d['groups'].items():
    for group in groups:
        assert len(group['ids'])==2 and len(set(group['ids']))==2
        assert all(group['lower']<=rows[id][axis]<group['upper'] for id in group['ids'])
for name,digest in {**audit['bindings'],**audit['indices']}.items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest
files=['index.html','data.json','source-audit.json']+[str(p.relative_to(OUT)) for p in (OUT/'images').glob('*.png')]+[p.name for p in OUT.glob('overview-*.jpg')]
for name in files:
    with urllib.request.urlopen('http://127.0.0.1:8850/'+name) as r:assert r.status==200
result={'passed':True,'uniqueExamples':len(rows),'displaySlots':24,'angleMaxDifferenceDegrees':max(errors),'httpResources':len(files),
        'sourceUnchanged':True,'checks':['acos independent angles','orthonormal transform','35cm clipping','local crop maps to source','bin membership','SHA'],
        'scope':'Archive geometry and presentation only; no instantaneous physical angles or K-shot robustness claim'}
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(result)
