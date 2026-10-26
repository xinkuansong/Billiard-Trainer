"""Score-level regions only. Production files and original pilot remain read-only."""
from pathlib import Path
import hashlib, json, math, os, subprocess, time
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'output' / HERE.name
OLD = ROOT / 'output/three-ball-placement-pilot-20261026'
SOURCE = ROOT / 'QiuJi/Core/PositionPlay/ShotComfortScore.swift'
G = json.loads((OLD / 'samples.json').read_text())
GEOM = json.loads((OLD / 'protocol.json').read_text())['geometry']
L, W, R = (GEOM[k] for k in ('length', 'width', 'radius'))
HX, HZ = L / 2, W / 2
ANCHORS = np.array([[-HX+R,-HZ+R],[HX-R,-HZ+R],[-HX+R,HZ-R],[HX-R,HZ-R],[0,-HZ],[0,HZ]])

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def evaluate(c, ball, aim):
    """Vector implementation checked against the unchanged Swift source below."""
    c, b, p = np.asarray(c, dtype=float), np.asarray(ball), np.asarray(aim)
    length = np.linalg.norm(p-b)
    n = (p-b) / length
    ghost = b - 2*R*n
    v = ghost-c
    norm = np.linalg.norm(v, axis=-1)
    dot = v @ n
    cue_distance = np.linalg.norm(c-b, axis=-1)
    angle_degrees = np.degrees(np.arctan2(np.abs(v[...,0]*n[1]-v[...,1]*n[0]), dot))
    depth = max(0, min(((bound if direction > 0 else -bound)-pos)/direction
                      for pos, direction, bound in zip(b, -n, [HX-R,HZ-R]) if abs(direction)>1e-12))
    scale = min(1, max(.4, depth/.9))
    lo, hi = .5*scale, .8*scale
    D = 100*np.exp(-(np.maximum(lo-cue_distance,0)/(.8*lo))**2-(np.maximum(cue_distance-hi,0)/.75)**2)
    with np.errstate(divide='ignore', invalid='ignore'):
        back = -v / norm[...,None]
    gaps = np.stack([HX-c[...,0]-R,HX+c[...,0]-R,HZ-c[...,1]-R,HZ+c[...,1]-R],axis=-1)
    directions = np.stack([back[...,0],-back[...,0],back[...,1],-back[...,1]],axis=-1)
    penalties = (45+15*np.maximum(directions,0)**2)*np.exp(-(np.maximum(gaps,0)*100/8)**1.2)
    main = np.argmax(penalties,axis=-1)
    adj = np.where(main<2, np.max(penalties[...,2:],axis=-1),np.max(penalties[...,:2],axis=-1))
    E = 100-np.max(penalties,axis=-1)-np.minimum(8,.25*adj)
    plateau, decay = min(15,9/length), min(20,20*math.sqrt(.6/length))
    A = 100*np.exp(-(np.maximum(angle_degrees-plateau,0)/decay)**2)
    total = .5*np.minimum(np.minimum(D,E),A)+.5*np.cbrt(D*E*A)
    ans = np.stack([D,E,A,total],axis=-1)
    valid = (cue_distance>=2*R)&(norm>1e-9)&(dot>1e-12)
    return np.where(valid[...,None],ans,np.nan)

def cross(a,b):
    return a[0]*b[1]-a[1]*b[0]

def contour(ball, aim, step, levels):
    """Piecewise-linear triangles, shared edge IDs, closed boundary loops.

    Triangle clipping also yields area independently of loop orientation or holes.
    Grid refinement is empirical convergence, not a certified continuum bound.
    """
    x=np.linspace(-HX+R,HX-R,math.ceil((L-2*R)/step)+1)
    z=np.linspace(-HZ+R,HZ-R,math.ceil((W-2*R)/step)+1)
    xx,zz=np.meshgrid(x,z)
    f=np.nan_to_num(evaluate(np.stack([xx,zz],axis=-1),ball,aim)[...,3],nan=0.)
    nx=len(x); dx=x[1]-x[0]; dz=z[1]-z[0]
    result=[]
    for level in levels:
        hi=f>=level
        count=hi[:-1,:-1].astype(int)+hi[:-1,1:]+hi[1:,:-1]+hi[1:,1:]
        assert not (hi[0,:].any() or hi[-1,:].any() or hi[:,0].any() or hi[:,-1].any()), 'Contour touches domain edge'
        area=float(np.count_nonzero(count==4)*dx*dz)
        points={}; adjacency={}
        def coord(k):return np.array([x[k%nx],z[k//nx]])
        def crossing(a,b):
            key=tuple(sorted((a,b)))
            if key not in points:
                va,vb=f.flat[a],f.flat[b]
                assert va != vb
                points[key]=coord(a)+(coord(b)-coord(a))*((level-va)/(vb-va))
            return key
        for iz,ix in zip(*np.where((count>0)&(count<4))):
            ll=int(iz*nx+ix);lr=ll+1;ul=ll+nx;ur=ul+1
            for tri in [(ll,lr,ur),(ll,ur,ul)]:
                polygon=[]; cuts=[]
                for a,b in zip(tri,tri[1:]+tri[:1]):
                    ia,ib=f.flat[a]>=level,f.flat[b]>=level
                    if ia:polygon.append(coord(a))
                    if ia != ib:
                        key=crossing(a,b);polygon.append(points[key]);cuts.append(key)
                if len(polygon)>=3:
                    area+=abs(sum(cross(a,b) for a,b in zip(polygon,polygon[1:]+polygon[:1])))/2
                if cuts:
                    assert len(cuts)==2
                    a,b=cuts
                    adjacency.setdefault(a,[]).append(b);adjacency.setdefault(b,[]).append(a)
        assert all(len(v)==2 for v in adjacency.values()), 'Non-closed topology'
        # Resolve every grid-edge intersection against the true score, rather
        # than interpolating through the min() aggregation's sharp corners.
        keys=list(points)
        left=np.array([coord(k[0]) for k in keys]);right=np.array([coord(k[1]) for k in keys])
        side=np.array([f.flat[k[0]]>=level for k in keys])
        for _ in range(32):
            middle=(left+right)/2
            same=(evaluate(middle,ball,aim)[:,3]>=level)==side
            left=np.where(same[:,None],middle,left);right=np.where(same[:,None],right,middle)
        for key,p in zip(keys,(left+right)/2):points[key]=p
        unvisited=set(adjacency);loops=[]
        while unvisited:
            start=min(unvisited);prev=None;cur=start;loop=[]
            while True:
                unvisited.remove(cur);loop.append(points[cur].tolist())
                nxt=next(k for k in adjacency[cur] if k!=prev)
                prev,cur=cur,nxt
                if cur==start:break
            loop.append(loop[0]);loops.append(refine_chords(loop,ball,aim,level))
        # These eight observed regions each have one simple ring. Do not infer
        # this topology for other layouts or silently sum holes as filled area.
        assert len(loops)==1, 'New topology needs an explicit area integration'
        poly=np.array(loops[0]);poly-=poly[0]
        area=float(abs(np.sum(poly[:-1,0]*poly[1:,1]-poly[1:,0]*poly[:-1,1]))/2)
        boundary=np.array([p for loop in loops for p in loop[:-1]])
        midpoints=np.array([(np.array(a)+b)/2 for loop in loops for a,b in zip(loop,loop[1:])])
        probes=np.concatenate([boundary,midpoints]) if len(boundary) else np.empty((0,2))
        residual=float(np.max(np.abs(evaluate(probes,ball,aim)[...,3]-level))) if len(probes) else 0.
        result.append(dict(threshold=level,areaM2=area,loops=loops,vertices=len(boundary),maxBoundaryScoreResidual=residual))
    return result

def refine_chords(loop,ball,aim,level):
    pts=np.array(loop)
    for _ in range(20):
        a,b=pts[:-1],pts[1:];middle=(a+b)/2
        residual=np.abs(evaluate(middle,ball,aim)[:,3]-level)
        bad=residual>1e-4
        if not bad.any():return pts.tolist()
        chord=b[bad]-a[bad];length=np.linalg.norm(chord,axis=-1)
        normal=np.stack([-chord[:,1],chord[:,0]],axis=-1)/length[:,None]
        left=middle[bad]-normal*length[:,None]
        right=middle[bad]+normal*length[:,None]
        side=evaluate(left,ball,aim)[:,3]>=level
        assert np.all(side!=(evaluate(right,ball,aim)[:,3]>=level)), 'Local contour root not bracketed'
        for _ in range(32):
            mid=(left+right)/2;same=(evaluate(mid,ball,aim)[:,3]>=level)==side
            left=np.where(same[:,None],mid,left);right=np.where(same[:,None],right,mid)
        inserted=(left+right)/2;updated=[];j=0
        for i,p in enumerate(a):
            updated.append(p)
            if bad[i]:updated.append(inserted[j]);j+=1
        updated.append(updated[0]);pts=np.array(updated)
    raise AssertionError('Contour chord refinement did not converge')

def native_check(cases, work):
    # Only the unused default-geometry provider is shimmed. All calls explicitly
    # pass the frozen bank geometry; the actual scoring source compiles unchanged.
    main=f'''import Foundation
enum AngleSceneCalculator {{
 static let innerLength: Double = {L}
 static let innerWidth: Double = {W}
 static let ballRadius: Double = {R}
}}
struct Input: Decodable {{ let c,b,p: [Double] }}
let input=try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
let g=ShotComfortScore.Geometry(length:{L},width:{W},radius:{R})
let result:[[Double]?]=input.map {{ t in
 guard let q=ShotComfortScore.evaluate(cue:(t.c[0],t.c[1]),ball:(t.b[0],t.b[1]),aim:(t.p[0],t.p[1]),geometry:g,pocketDistanceAngle:true) else {{ return nil }}
 return [q.distance,q.space,q.angle,q.total]
}}
try JSONEncoder().encode(result).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
'''
    (work/'main.swift').write_text(main)
    (HERE/'native-check-main.swift.txt').write_text(main)
    src_before=sha(SOURCE)
    command=['xcrun','swiftc','-O',str(SOURCE),str(work/'main.swift'),'-o',str(work/'score-check')]
    run=subprocess.run(command,capture_output=True,text=True)
    (OUT/'native-build.log').write_text(run.stdout+run.stderr)
    assert run.returncode==0,run.stderr
    write(OUT/'native-input.json',cases)
    subprocess.run([str(work/'score-check'),str(OUT/'native-input.json'),str(OUT/'native-output.json')],check=True)
    native=json.loads((OUT/'native-output.json').read_text())
    max_error=0.;invalid=0
    for case,n in zip(cases,native):
        p=evaluate(case['c'],case['b'],case['p'])
        if n is None:
            assert np.isnan(p).all();invalid+=1
        else:
            assert np.isfinite(p).all()
            max_error=max(max_error,float(np.max(np.abs(p-n))))
    assert len(native)==len(cases) and max_error<1e-9
    assert sha(SOURCE)==src_before
    return dict(cases=len(cases),invalidCases=invalid,maxComponentError=max_error,sourceSHA256=src_before,compileCommand=command)

def main():
    start=time.monotonic();work=Path(os.environ['QIUJI_TEST_WORK'])
    OUT.mkdir(parents=True,exist_ok=True)
    baseline_sha={p.name:sha(p) for p in [OLD/'samples.json',OLD/'index.html',*[OLD/f'sample-{i}.json' for i in range(1,6)]]}
    rng=np.random.default_rng(2026102701);samples=[];cases=[];audits=[]
    for sample in G:
        raw=json.loads((OLD/f"sample-{sample['number']}.json").read_text())
        regions=[]
        for pocket in sorted({ref[1] for ref in sample['refs']}):
            ball=sample['second'];aim=ANCHORS[pocket]
            coarse=contour(ball,aim,.002,[85])
            fine=contour(ball,aim,.001,[85,90,95])
            delta=abs(coarse[0]['areaM2']-fine[0]['areaM2'])
            stops=[]
            for baseline in raw['baselines']:
                if baseline['pocket2']!=pocket:continue
                stop=baseline['result']['stop']
                score=evaluate(stop,ball,aim)
                stops.append(dict(rank=baseline['rank'],position=stop,score=score.tolist(),inside=bool(score[3]>=85),routeID=baseline['parameter']['id'],path=baseline['result']['cuePath']))
            # All vertices and all segment midpoints, plus random domain/invalid probes.
            points=[*rng.uniform([-HX+R,-HZ+R],[HX-R,HZ-R],size=(1000,2)).tolist(),ball]
            for level in fine:
                for loop in level['loops']:
                    points.extend(loop[:-1]);points.extend(((np.array(a)+b)/2).tolist() for a,b in zip(loop,loop[1:]))
            points.extend(s['position'] for s in stops)
            cases.extend(dict(c=c,b=ball,p=aim.tolist()) for c in points)
            audits.append(dict(sample=sample['number'],pocket=pocket,areaCoarse=coarse[0]['areaM2'],areaFine=fine[0]['areaM2'],areaDifferenceM2=delta,maxBoundaryScoreResidual=max(q['maxBoundaryScoreResidual'] for q in fine),loops=[len(q['loops']) for q in fine]))
            regions.append(dict(pocket=pocket,aim=aim.tolist(),levels=fine,stops=stops,coarseAreaM2=coarse[0]['areaM2']))
            print('region',sample['number'],pocket,'area',fine[0]['areaM2'],'delta',delta,'scores',[round(s['score'][3],3) for s in stops],flush=True)
        samples.append(dict(number=sample['number'],id=sample['id'],second=sample['second'],board=sample['board'],regions=regions))
    native=native_check(cases,work)
    assert all(sha(OLD/name)==digest for name,digest in baseline_sha.items())
    # Reflection and cut geometry checks cover direction/sign handling independently.
    b=np.array([.2,.1]);p=np.array([1.,.1]);ghost=b-np.array([2*R,0])
    c=ghost-np.array([.5,0]);assert abs(evaluate(c,b,p)[2]-100)<1e-12
    c45=ghost-np.array([.5,.5]);expected=100*math.exp(-((45-min(15,9/.8))/min(20,20*math.sqrt(.6/.8)))**2)
    assert abs(evaluate(c45,b,p)[2]-expected)<1e-10
    mirror=rng.uniform([-.8,-.4],[.8,.4],size=(500,2));reflect=np.array([-1,1])
    assert np.allclose(evaluate(mirror,b,p),evaluate(mirror*reflect,b*reflect,p*reflect),equal_nan=True,atol=1e-10)
    assert max(q['maxBoundaryScoreResidual'] for q in audits)<1.01e-4
    audit=dict(passed=True,method='1mm maximum grid locates triangles; bracketed true-score roots plus adaptive chord-midpoint refinement to 1e-4 score; 2mm refinement comparison, not a continuum certificate',geometry=GEOM,native=native,regions=audits,baselineSHA=baseline_sha,originalPilotUnchanged=True,seconds=time.monotonic()-start)
    payload=dict(samples=samples,geometry=GEOM,anchors=ANCHORS.tolist(),threshold=85,scoreVersion='comfort-d2-s3-pocket-angle20-min50-v1',audit=audit)
    write(OUT/'data.json',payload);write(OUT/'audit.json',audit)
    html=(HERE/'viewer.html').read_text().replace('/*__DATA__*/',json.dumps(payload,ensure_ascii=False,allow_nan=False,separators=(',',':')))
    (OUT/'index.html').write_text(html)
    print('PASS',native['cases'],'native cases, max error',native['maxComponentError'],'time',audit['seconds'],flush=True)

if __name__=='__main__':main()
