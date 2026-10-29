"""Independently check saved exploratory intersections; no dynamics claims."""
from pathlib import Path
import collections, hashlib, json, math, urllib.request
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/k-ball-route-study-20261029'
d=json.loads((OUT/'data.json').read_text());a=json.loads((OUT/'audit.json').read_text());r=d['geometry']['radius']
def distance(p,x,y):
    dx=y[0]-x[0];dy=y[1]-x[1];den=dx*dx+dy*dy
    t=((p[0]-x[0])*dx+(p[1]-x[1])*dy)/den if den else 0
    t=min(1,max(0,t));return math.hypot(p[0]-x[0]-t*dx,p[1]-x[1]-t*dy)
count=0
for row in d['selected']:
    track=row['route']['trajectory2mm'];points=[p[1:] for p in track['points']]
    assert all(p[0]<=q[0] for p,q in zip(track['points'],track['points'][1:]))
    assert math.dist(points[-1],row['route']['cueStop'])<1e-5
    assert len(track['cushions'])==row['originalTotalRails']
    for c in row['candidates']:
        i=c['segment'];p=c['position'];hit=c['contact'];u=c['fraction']
        assert 0<=u<=1 and math.dist(hit,[points[i][k]+u*(points[i+1][k]-points[i][k]) for k in (0,1)])<1e-10
        assert abs(math.dist(hit,p)-2*r)<1e-9
        assert all(distance(p,x,y)>=2*r-1e-9 for x,y in zip(points[:i],points[1:i+1]))
        normal=[hit[k]-p[k] for k in (0,1)];vel=[points[i+1][k]-points[i][k] for k in (0,1)]
        assert sum(normal[k]*vel[k] for k in (0,1))<=1e-9
        assert c['kRails']==sum(e['pointIndex']<i+u for e in track['cushions'])
        count+=1
    for c in row['shown']:
        assert {k:v for k,v in c.items() if k!='label'} in row['candidates']
for name,digest in {**a['sourceBindings'],**a['indexHashes']}.items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest
files=['index.html','data.json','audit.json']+[str(p.relative_to(OUT)) for p in (OUT/'images').glob('*.png')]+[p.name for p in OUT.glob('overview-*.jpg')]
for path in files:
    with urllib.request.urlopen('http://127.0.0.1:8849/'+path) as response:assert response.status==200
result={'passed':True,'routes':len(d['selected']),'geometricCandidates':count,'httpResources':len(files),
        'checks':['earliest contact / no earlier polyline intersection','approaching contact','rail prefix count','source unchanged','display subset','monotonic times / final point'],
        'scope':'Polyline geometry only; no simulation or K-shot success verification'}
(OUT/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(result)
