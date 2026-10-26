from pathlib import Path
from collections import defaultdict
import hashlib,json,math
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'output/middle-pocket-angle-20261026/tangent-check'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    meta=json.loads((OUT/'metadata.json').read_text());g=json.loads((OUT/'geometry.json').read_text())
    theta=math.radians(g['theta']);m=1/math.tan(theta);b=g['inset'];h=meta['width']/2
    # Independent line-to-circle distance, lip membership and contact projection.
    cx,_,cz=g['jaw']['center'];cy=h-cz;px,pz=g['point'];py=h-pz
    assert [px,pz] in meta['pockets'][5]['lip']
    assert abs(py-m*px-b)<1e-12
    distance=abs(cy-m*cx-b)/math.hypot(m,1)
    assert abs(distance-g['expandedRadius'])<1e-12
    assert abs(g['aimOffset']+b/m)<1e-12
    stats=defaultdict(lambda:dict(cases=0,feasible=0));count=0;mirror={};directions=[]
    for line in (OUT/'raw.jsonl').read_text().splitlines():
        row=json.loads(line);x=row['input'];a=math.radians(x['angle']);d=x['distance'];delta=x['delta']
        actualDepth=h-x['side']*row['start'][2]
        residual=actualDepth-m*abs(row['start'][0])-b
        assert (residual>0)==(delta<0),(x,residual)
        assert all(v['termination']=='settled' for v in row['results'])
        results=[]
        for v in row['results']:
            count+=1
            events=v['events'];contacts=[e for e in events if e['kind']!='pocket']
            ids=[e['id'] for e in events if e['kind']=='pocket']
            direct=(ids==['pocket_4' if x['side']<0 else 'pocket_5'] and
                not any(e['kind']=='cushion' or abs(e['position'][0])>=.16 or abs(e['position'][2]-x['side']*h)>=.16 for e in contacts))
            assert direct==v['direct']
            results.append(direct)
            if direct:directions.append(math.degrees(math.atan2(abs(v['direction'][0]),abs(v['direction'][2]))))
        feasible=any(results)
        assert feasible==(delta<0),x
        stats[delta]['cases']+=1;stats[delta]['feasible']+=feasible
        if x['mode']=='sliding':mirror.setdefault((d,x['speed'],delta),{})[(x['side'],x['hand'])]=results
    comparisons=0
    for key,orientations in mirror.items():
        assert len(orientations)==4
        for v in orientations.values():assert v==orientations[(-1,1)];comparisons+=len(v)
    generation=json.loads((OUT/'generation.json').read_text());assert generation['complete'] and generation['simulations']==count
    binding=json.loads((OUT/'source-binding.json').read_text());assert all(sha(ROOT/r['path'])==r['sha256'] for r in binding['production'])
    assert json.loads((OUT/'replays.json').read_text())['passed']
    result=dict(passed=True,simulations=count,positions=sum(v['cases'] for v in stats.values()),
        byDelta=dict(stats),mirrorShotComparisons=comparisons,maxSuccessfulIncomingAngle=max(directions),
        tangentDistance=distance,expandedRadius=g['expandedRadius'],sourceBindings=len(binding['production']),rawSHA256=sha(OUT/'raw.jsonl'))
    (OUT/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
    proposal=dict(status='research-only; not integrated',model=meta['model'],tableLength=meta['length'],tableWidth=meta['width'],ballRadius=meta['radius'],
        angleFromNormalDegrees=g['theta'],angleFromRailDegrees=90-g['theta'],apexInsetMeters=b,slope=m,
        formula='depth >= apexInsetMeters + slope * abs(ballX); depth=innerWidth/2-sideSign*ballZ; sideSign=-1 for pocket_4, +1 for pocket_5',
        meaning='candidate region for existence of a direct pot direction, not guarantee or comfort/probability',
        scope='standard rectangular ball-center domain; tested radial distances .08..1.28m, speeds 1/2/4m/s, zero initial spin sliding and natural rolling; obstacles excluded',
        boundaryVerificationDegrees=.005)
    (OUT.parent/'region-proposal.json').write_text(json.dumps(proposal,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
