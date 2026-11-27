"""Read-only production geometry extraction; coarse comfort contours for review."""
from pathlib import Path
import importlib.util, json, math, os, hashlib, subprocess, time, statistics
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'output'/HERE.name
WORK=Path(os.environ['QIUJI_TEST_WORK'])
OLD=ROOT/'research/three-ball-comfort-region-20261027/region.py'
spec=importlib.util.spec_from_file_location('old_region',OLD)
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
DATA=json.loads((ROOT/'output/three-ball-comfort-region-20261027/data.json').read_text())
NAMES=['左上角袋','右上角袋','左下角袋','右下角袋','上中袋','下中袋']
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,allow_nan=False,indent=2))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def between(s,a,b):return s[s.index(a):s.index(b)]
def function(s,marker):
    start=s.index(marker);opening=s.index('{',start);depth=1;i=opening+1
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]

def native_inputs():
    """Compile actual scalar geometry and sector code, with Float vector storage.

    No SceneKit rendering, simulation, or substitute aiming rule. Table factory
    extraction retains exact production pocket centres and measured capture lips.
    """
    paths={k:ROOT/v for k,v in dict(
        angle='QiuJi/Core/Scene/AngleSceneCalculator.swift',
        sector='QiuJi/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift',
        table='QiuJi/Core/Physics/TableGeometry.swift',
        factory='QiuJi/Core/Physics/TableGeometry+QiuJi.swift',
        constants='QiuJi/Core/Physics/BTPhysicsConstants.swift',
        quartic='QiuJi/Core/Physics/QuarticSolver.swift',
        numerics='QiuJi/Core/Physics/EngineNumerics.swift',
        score='QiuJi/Core/PositionPlay/ShotComfortScore.swift').items()}
    src={k:p.read_text() for k,p in paths.items()}
    frozen={str(p.relative_to(ROOT)):sha(p) for p in paths.values()}
    angle=src['angle'].split('    // MARK: - Pocket reachability')[0].replace('import SceneKit','')+'\n}\n'
    sector=between(src['sector'],'struct PlanThreeSector {','// MARK: - ViewModel')
    start=sector.index('    /// 求解用**默认落区**')
    end=sector.index('    /// 构建单侧扇形')
    sector=sector[:start]+sector[end:]
    pocket=between(src['table'],'struct Pocket {','struct LinearCushionSegment')
    factory=between(src['factory'],'        let cx = TablePhysics.cornerPocketCenterOffsetX','        // 安全喉壁')
    lips=between(src['factory'],'    private static let measuredCornerLip','    // MARK: - 安全喉壁')
    code='''import Foundation
struct SCNVector3 { var x,y,z:Float; init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z} }
let SCNVector3Zero=SCNVector3(0,0,0)
'''+src['constants']+src['quartic']+'\nenum EngineNumerics {\n'+function(src['numerics'],'    static func smallestPositiveRoot')+'\n}\n'+pocket+'''
struct TableGeometry {
 let pockets:[Pocket]
 static func chineseEightBallQiuJi(surfaceY:Float)->TableGeometry {
 let y=surfaceY
'''+factory+'return TableGeometry(pockets:pockets)\n}\n'+lips+'\n}\n'+angle+sector+src['score']+'''
struct Input:Decodable { let ball:[Double];let pocket:Int }
struct Output:Encodable { let aim:[Float];let sectors:[[[Float]]];let ghost:[Float] }
let args=CommandLine.arguments
if args[1]=="geometry" {
 let inputs=try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
 let outputs=inputs.map { q -> Output in
  let b=SCNVector3(Float(q.ball[0]),0,Float(q.ball[1]))
  let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:b,pocketIndex:q.pocket,surfaceY:0)
  let g=AngleSceneCalculator.ghostBallPosition(targetBall:b,pocket:aim,ballRadius:AngleSceneCalculator.ballRadius)
  let sectors=PlanThreeSectorSolver.compute(ball2:b,aim2:aim,ball3:nil,surfaceY:0).map { s in (s.outer+Array(s.inner.reversed())+[s.outer[0]]).map{[$0.x,$0.z]} }
  return Output(aim:[aim.x,aim.z],sectors:sectors,ghost:[g.x,g.z])
 }
 try JSONEncoder().encode(outputs).write(to:URL(fileURLWithPath:args[3]))
} else {
 struct Check:Decodable { let c,b,p:[Double] }
 let checks=try JSONDecoder().decode([Check].self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
 let result=checks.map { q -> [Double]? in
  guard let r=ShotComfortScore.evaluate(cue:(q.c[0],q.c[1]),ball:(q.b[0],q.b[1]),aim:(q.p[0],q.p[1])) else {return nil}
  return [r.distance,r.space,r.angle,r.total]
 }
 try JSONEncoder().encode(result).write(to:URL(fileURLWithPath:args[3]))
}
'''
    (WORK/'main.swift').write_text(code)
    (OUT/'native-source.swift.txt').write_text(code)
    command=['xcrun','swiftc','-O',str(WORK/'main.swift'),'-o',str(WORK/'geometry')]
    run=subprocess.run(command,capture_output=True,text=True)
    (OUT/'native-build.log').write_text(run.stdout+run.stderr)
    assert run.returncode==0,run.stderr
    inputs=[dict(ball=s['second'],pocket=r['pocket']) for s in DATA['samples'] for r in s['regions']]
    write(OUT/'native-input.json',inputs)
    subprocess.run([str(WORK/'geometry'),'geometry',str(OUT/'native-input.json'),str(OUT/'native-output.json')],check=True)
    return json.loads((OUT/'native-output.json').read_text()),frozen

def coarse(ball,aim,step,level=85):
    """Uniform grid, fixed diagonal triangles, one linear edge interpolation.

    No root search, recursive refinement, polygon smoothing, or convex hull.
    Connected components/holes are kept independently by the edge graph.
    """
    x=np.linspace(-old.HX+old.R,old.HX-old.R,math.ceil((old.L-2*old.R)/step)+1)
    z=np.linspace(-old.HZ+old.R,old.HZ-old.R,math.ceil((old.W-2*old.R)/step)+1)
    xx,zz=np.meshgrid(x,z)
    f=np.nan_to_num(old.evaluate(np.stack([xx,zz],axis=-1),ball,aim)[...,3],nan=0.)
    hi=f>=level
    # The tested 85-level domains do not touch the legal-centre boundary.
    assert not (hi[0].any() or hi[-1].any() or hi[:,0].any() or hi[:,-1].any())
    count=sum(v.astype(int) for v in [hi[:-1,:-1],hi[:-1,1:],hi[1:,:-1],hi[1:,1:]])
    nx=len(x);points={};edges={}
    def coord(i):return np.array([x[i%nx],z[i//nx]])
    for iz,ix in zip(*np.where((count>0)&(count<4))):
        a=int(iz*nx+ix);b=a+1;c=a+nx;d=c+1
        for tri in [(a,b,d),(a,d,c)]:
            cuts=[]
            for u,v in zip(tri,tri[1:]+tri[:1]):
                if (f.flat[u]>=level)!=(f.flat[v]>=level):
                    key=tuple(sorted((u,v)))
                    if key not in points:points[key]=coord(u)+(coord(v)-coord(u))*((level-f.flat[u])/(f.flat[v]-f.flat[u]))
                    cuts.append(key)
            if cuts:
                assert len(cuts)==2
                u,v=cuts;edges.setdefault(u,[]).append(v);edges.setdefault(v,[]).append(u)
    assert all(len(v)==2 for v in edges.values())
    remaining=set(edges);loops=[]
    while remaining:
        start=min(remaining);previous=None;cur=start;loop=[]
        while True:
            remaining.remove(cur);loop.append(points[cur].tolist())
            nxt=next(n for n in edges[cur] if n!=previous)
            previous,cur=cur,nxt
            if cur==start:break
        loop.append(loop[0]);loops.append(loop)
    return dict(step=step,loops=loops,vertices=sum(len(p)-1 for p in loops),evaluations=f.size)

def contains(points,loops):
    # Even-odd fill matches the review SVG; includes holes without a hull.
    inside=np.zeros(len(points),dtype=bool);x,y=points.T
    for loop in loops:
        for (x1,y1),(x2,y2) in zip(loop,loop[1:]):
            if y1==y2:continue
            inside^=((y1>y)!=(y2>y))&(x<(x2-x1)*(y-y1)/(y2-y1)+x1)
    return inside

def metrics(region,ball,aim,probes,truth):
    actual=contains(probes,region['loops']);union=truth|actual
    p=np.concatenate([np.asarray(loop)[:-1] for loop in region['loops']])
    mid=np.concatenate([(np.asarray(loop)[:-1]+np.asarray(loop)[1:])/2 for loop in region['loops']])
    boundary=old.evaluate(np.concatenate([p,mid]),ball,aim)[:,3]
    return dict(overlapPct=100*np.count_nonzero(truth&actual)/np.count_nonzero(union),
      missedPct=100*np.count_nonzero(truth&~actual)/np.count_nonzero(truth),
      extraPct=100*np.count_nonzero(actual&~truth)/max(1,np.count_nonzero(actual)),
      areaM2=float(actual.sum()*(probes[1,0]-probes[0,0])**2),
      boundaryScoreMin=float(boundary.min()),boundaryScoreMax=float(boundary.max()))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    native,frozen=native_inputs()
    # Use the exact Float production dimensions promoted to Double.
    assert np.float32(old.L)==np.float32(2.54) and np.float32(old.R)==np.float32(.028575)
    probes=np.stack(np.meshgrid(np.arange(-old.HX+old.R+.001,old.HX-old.R,.002),np.arange(-old.HZ+old.R+.001,old.HZ-old.R,.002)),axis=-1).reshape(-1,2)
    results=[];checks=[];rng=np.random.default_rng(20261101);i=0
    for sample in DATA['samples']:
        for prior in sample['regions']:
            n=native[i];i+=1;ball=np.array(sample['second'],dtype=np.float32).astype(float);aim=n['aim']
            start=time.perf_counter();fine=old.contour(ball,aim,.001,[85])[0];fine_ms=(time.perf_counter()-start)*1000
            truth=np.nan_to_num(old.evaluate(probes,ball,aim)[:,3],nan=0)>=85
            variants=[]
            for step in [.02,.04,.06]:
                timings=[]
                for _ in range(7):
                    start=time.perf_counter();region=coarse(ball,aim,step);timings.append((time.perf_counter()-start)*1000)
                region['milliseconds']=statistics.median(timings)
                region.update(metrics(region,ball,aim,probes,truth));variants.append(region)
            current=dict(loops=n['sectors']);current.update(metrics(current,ball,aim,probes,truth))
            # Current ghost/sector orientation from native output; scalar oracle checks.
            u=(np.array(aim)-ball);u/=np.linalg.norm(u);ghost=ball-2*old.R*u
            assert np.max(np.abs(ghost-n['ghost']))<1e-6
            for poly in n['sectors']:
                d=np.array(poly)-ghost;radius=np.linalg.norm(d,axis=1)
                angle=np.degrees(np.arctan2(d[:,0]*u[1]-d[:,1]*u[0],-d@u))
                assert np.all((np.abs(angle)>4.999)&(np.abs(angle)<20.001))
                assert radius.min()>.10999 and radius.max()<.55001
            # Unambiguous mirror and straight-shot checks for the reused scoring code.
            points=rng.uniform([-old.HX+old.R,-old.HZ+old.R],[old.HX-old.R,old.HZ-old.R],(300,2))
            mirror=np.array([-1,1]);assert np.allclose(old.evaluate(points,ball,aim),old.evaluate(points*mirror,ball*mirror,np.array(aim)*mirror),equal_nan=True)
            checks += [dict(c=p.tolist(),b=ball.tolist(),p=aim) for p in points]
            results.append(dict(number=len(results)+1,sample=sample['number'],id=sample['id'],pocket=prior['pocket'],pocketName=NAMES[prior['pocket']],ball=ball.tolist(),aim=aim,legacyAim=prior['aim'],board=sample['board'],stops=prior['stops'],current=current,fine=dict(loops=fine['loops'],vertices=fine['vertices'],milliseconds=fine_ms,areaM2=fine['areaM2']),variants=variants))
            print('case',len(results),'coarse4cm',round(variants[1]['milliseconds'],2),'ms','IoU',round(variants[1]['overlapPct'],3),'current IoU',round(current['overlapPct'],2),flush=True)
    write(OUT/'score-input.json',checks)
    subprocess.run([str(WORK/'geometry'),'scores',str(OUT/'score-input.json'),str(OUT/'score-output.json')],check=True)
    output=json.loads((OUT/'score-output.json').read_text());error=0;valid=0
    for c,n in zip(checks,output):
        a=old.evaluate(c['c'],c['b'],c['p'])
        if n is None:assert np.isnan(a).all()
        else:error=max(error,float(np.max(np.abs(a-n))));valid+=1
    assert len(output)==len(checks) and error<1e-9,(error,valid)
    for path,digest in frozen.items():assert sha(ROOT/path)==digest
    audit=dict(passed=True,scoreCases=len(checks),validScoreCases=valid,maxScoreError=error,sourceSHA256=frozen,reference='same current effective aim; 1 mm old root-refined contour',comparison='2 mm grid, even-odd polygon membership vs exact score >=85',timing='local Python/NumPy; excludes native aim, rendering, file IO; 7-run median for coarse, one fine run; not iPhone',scope='8 original ball/pocket pairs; no third ball, no obstacles, no shot simulation',geometry=dict(length=old.L,width=old.W,radius=old.R))
    write(OUT/'data.json',dict(cases=results,audit=audit));write(OUT/'audit.json',audit)
    print('AUDIT',json.dumps({k:v for k,v in audit.items() if k not in ['sourceSHA256']},ensure_ascii=False),flush=True)

if __name__=='__main__':main()
