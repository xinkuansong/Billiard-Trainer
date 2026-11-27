"""Third-ball partitions on the accepted 2 cm comfort region. Research only."""
from pathlib import Path
import importlib.util, os, json, hashlib, math, subprocess, time
import numpy as np

ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=ROOT/'output'/HERE.name;WORK=Path(os.environ['QIUJI_TEST_WORK'])
def load(name,path):
    s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
P=load('previous',ROOT/'research/plan-three-region-compare-20261101/run.py')
R=P.old
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,allow_nan=False,indent=2))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def compile_native():
    P.OUT=OUT
    geometry,frozen=P.native_inputs()
    source=(ROOT/'QiuJi/Features/TwoBallPractice/TwoBallQuestionPreparer.swift').read_text()
    bank=(ROOT/'QiuJi/Features/TwoBallPractice/TwoBallBankStore.swift').read_text()
    angle=(ROOT/'QiuJi/Core/Scene/AngleSceneCalculator.swift').read_text()
    prep=(ROOT/'QiuJi/Features/ThreeBallPractice/ThreeBallQuestionPreparer.swift').read_text()
    code=(OUT/'native-source.swift.txt').read_text().split('struct Input:Decodable')[0]
    code+='\nenum TwoBallDifficultyMetric {\n'+P.between(bank,'    struct Geometry: Codable {','    struct Result: Codable')+'}\n'
    code+=source[source.index('enum TwoBallComfortScore {'):]
    code+='\nextension AngleSceneCalculator {\n static let maxCutAngle:Double=89\n'
    for marker in ['    static func cutAngle(','    static func isFeasible(','    static func isCueBallBlocking(','    static func isPathBlocked(']:code+=P.function(angle,marker)+'\n'
    code+='}\nenum ThreeBallQuestionPreparer {\n'+P.function(prep,'    static func canContinue(')+'\n}\n'
    code+='''
struct Input:Decodable { let cue,ball,third:[Double];let pocket:Int }
struct Result:Encodable {
 let available,overlap:Bool
 let base,final,angle,depth:Double
 let coefficient:Double?
 let direction:MiddlePocketDirectionScore.Result?
 let aim,ghost,u,t,q:[Double]
}
func length(_ v:SIMD2<Double>)->Double {hypot(v.x,v.y)}
func dot(_ a:SIMD2<Double>,_ b:SIMD2<Double>)->Double{a.x*b.x+a.y*b.y}
func vector(_ p:[Double])->SCNVector3{SCNVector3(Float(p[0]),0,Float(p[1]))}
let inputs=try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
let results=inputs.map { i -> Result in
 let c=SIMD2(i.cue[0],i.cue[1]),b=SIMD2(i.ball[0],i.ball[1]),z=SIMD2(i.third[0],i.third[1])
 let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:vector(i.ball),pocketIndex:i.pocket,surfaceY:0)
 // Exact current middle-pocket direction convention; corner proposal uses effective aim.
 let centre=(i.pocket==4 || i.pocket==5) ? AngleSceneCalculator.pocketPositions(surfaceY:0)[i.pocket] : aim
 let p=SIMD2(Double(centre.x),Double(centre.z)),n=(p-b)/length(p-b)
 let g=b-2*Double(AngleSceneCalculator.ballRadius)*n,u=(g-c)/length(g-c)
 let cosine=dot(u,n),t=u-cosine*n
 var q=SIMD2(-u.y,u.x);if dot(q,t)<0{q = -q}
 let depth=dot(z-g,q),angle=acos(min(1,max(-1,cosine)))*180/Double.pi
 let overlap=length(z-c)<2*Double(AngleSceneCalculator.ballRadius) || length(b-c)<2*Double(AngleSceneCalculator.ballRadius)
 let available=ThreeBallQuestionPreparer.canContinue(cue:vector(i.cue),target:vector(i.ball),pocket:i.pocket,obstacle:vector(i.third),surfaceY:0) && !overlap
 let base=TwoBallComfortScore.evaluateFreePosition(cue:(c.x,c.y),ball:(b.x,b.y),pocket:i.pocket)?.total ?? 0
 let k=MiddlePocketDirectionScore.evaluate(cue:(c.x,c.y),ball:(b.x,b.y),third:(z.x,z.y),pocket:i.pocket)
 let final=available ? base*(k?.coefficient ?? 1):0
 return Result(available:available,overlap:overlap,base:base,final:final,angle:angle,depth:depth,coefficient:k?.coefficient,direction:k,aim:[Double(aim.x),Double(aim.z)],ghost:[g.x,g.y],u:[u.x,u.y],t:[t.x,t.y],q:[q.x,q.y])
}
try JSONEncoder().encode(results).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
'''
    (WORK/'third.swift').write_text(code);(OUT/'native-third-source.swift.txt').write_text(code)
    cmd=['xcrun','swiftc','-O',str(WORK/'third.swift'),'-o',str(WORK/'third')]
    run=subprocess.run(cmd,capture_output=True,text=True);(OUT/'native-third-build.log').write_text(run.stdout+run.stderr)
    assert run.returncode==0,run.stderr
    for p in [ROOT/'QiuJi/Features/TwoBallPractice/TwoBallQuestionPreparer.swift',ROOT/'QiuJi/Features/TwoBallPractice/TwoBallBankStore.swift',ROOT/'QiuJi/Features/ThreeBallPractice/ThreeBallQuestionPreparer.swift',ROOT/'QiuJi/Features/ThreeBallPractice/ThreeBallQuestion.swift']:
        frozen[str(p.relative_to(ROOT))]=sha(p)
    return geometry,frozen

def area(poly):
    a=np.array(poly);b=np.roll(a,-1,axis=0)
    return abs(np.sum(a[:,0]*b[:,1]-b[:,0]*a[:,1]))/2

def tiles(ball,aim):
    # Same grid and fixed triangle diagonal as the accepted coarse contour.
    x=np.linspace(-R.HX+R.R,R.HX-R.R,math.ceil((R.L-2*R.R)/.02)+1)
    z=np.linspace(-R.HZ+R.R,R.HZ-R.R,math.ceil((R.W-2*R.R)/.02)+1)
    xx,zz=np.meshgrid(x,z);grid=np.stack([xx,zz],axis=-1)
    f=np.nan_to_num(R.evaluate(grid,ball,aim)[...,3],nan=0.)
    result=[]
    for iz in range(len(z)-1):
        for ix in range(len(x)-1):
            a=(iz,ix);b=(iz,ix+1);c=(iz+1,ix);d=(iz+1,ix+1)
            for tri in [(a,b,d),(a,d,c)]:
                poly=[]
                for u,v in zip(tri,tri[1:]+tri[:1]):
                    pu,pv=grid[u],grid[v];fu,fv=f[u],f[v]
                    if fu>=85:poly.append(pu.tolist())
                    if (fu>=85)!=(fv>=85):poly.append((pu+(pv-pu)*((85-fu)/(fv-fu))).tolist())
                if len(poly)>=3 and area(poly)>1e-15:
                    result.append(dict(poly=poly,point=np.mean(poly,axis=0).tolist(),area=area(poly)))
    return result

def independent_k(c,b,z,pocket):
    """Scalar v2 oracle, separate rectangle clipping and aggregation."""
    p=np.array([0,float(np.float32(-.67596474 if pocket==4 else .67596474))])
    n=(p-b)/np.linalg.norm(p-b);g=b-2*R.R*n;u=(g-c)/np.linalg.norm(g-c)
    cosine=float(u@n);t=u-cosine*n;q=np.array([-u[1],u[0]])
    if q@t<0:q=-q
    signed=float((z-g)@q);angle=math.degrees(math.acos(min(1,cosine)))
    reverse=np.linalg.norm(t)>1e-10 and signed<0
    normal=-q if signed<0 else q
    rectangle=[[-R.HX,-R.HZ],[R.HX,-R.HZ],[R.HX,R.HZ],[-R.HX,R.HZ]];poly=[]
    for a,bp in zip(rectangle,rectangle[1:]+rectangle[:1]):
        a=np.array(a);bp=np.array(bp);sa=(a-g)@normal;sb=(bp-g)@normal
        if sa>=0:poly.append(a)
        if (sa<0)!=(sb<0):poly.append(a+(bp-a)*sa/(sa-sb))
    ratio=area(poly)/(R.L*R.W) if len(poly)>=3 else 0
    clamp=lambda v:max(0,min(1,v))
    penalty=.4*clamp(max(0,-signed)/(.35*R.L))*(.75+.25*ratio)*(.6+.4*clamp(np.linalg.norm(c-b)/(.35*R.L)))
    m=.7+.3*clamp(((angle-30)/25)**2)
    return max(.6,1-penalty*m) if reverse else 1

def main():
    OUT.mkdir(parents=True,exist_ok=True);geometry,frozen=compile_native()
    original=json.loads((ROOT/'output/plan-three-region-compare-20261101/data.json').read_text())['cases']
    # Controlled third-ball placements, not newly generated training questions.
    specs=[(1,[-.80,.18],'A1 · 中袋，第三球在左','只移动第三球，与A2对照'),
           (1,[1.05,.18],'A2 · 中袋，第三球在右','第二球和袋口与A1完全相同'),
           (1,[.68,.34],'A3 · 中袋，第三球靠近落区','同时看占位与母球进攻线遮挡'),
           (1,None,'A4 · 中袋，第三球挡住进球线','不应因分离方向合适就保留落区'),
           (0,[-.65,.32],'B1 · 角袋，第三球在左下','角袋只有候选几何分区，现有评分不乘K'),
           (0,[.90,.30],'B2 · 角袋，第三球在右下','与B1对照；不把研究扩展当成已上线评分'),
           (6,[-.55,.34],'C1 · 近库球，第三球在左下','检查当前单侧扇形的离库裁剪'),
           (6,[-.55,-.36],'C2 · 近库球，第三球靠近上库','与C1对照；本轮不搜索吃库路线')]
    cases=[];inputs=[]
    for index,(baseidx,third,title,note) in enumerate(specs):
        source=original[baseidx];ball=source['ball'];aim=geometry[baseidx]['aim']
        if third is None:third=((np.array(ball)+np.array(aim))*.5).tolist()
        third=np.array(third,dtype=np.float32).astype(float).tolist()
        assert abs(third[0])<R.HX-R.R and abs(third[1])<R.HZ-R.R and np.linalg.norm(np.array(third)-ball)>2*R.R
        ts=tiles(ball,aim);start=len(inputs)
        inputs.extend(dict(cue=t['point'],ball=ball,third=third,pocket=source['pocket']) for t in ts)
        cases.append(dict(number=index+1,baseCase=baseidx+1,title=title,note=note,ball=ball,third=third,pocket=source['pocket'],pocketName=source['pocketName'],aim=aim,base=P.coarse(ball,aim,.02),tiles=ts,start=start))
    # Explicit standard, current-v2 golden, and mirror probes; no UI-only evidence.
    tests=[dict(cue=[0,.3],ball=[0,-.2],third=[-.8,.2],pocket=4),
           dict(cue=[.013719135802469,.32729938271605],ball=[.070555555555555,-.30966049382716],third=[-1.1328086419753,.28418209876543],pocket=4)]
    expected=[1,.75796747872099]
    teststart=len(inputs)
    for case in tests:
        for mx,mz in [(1,1),(-1,1),(1,-1),(-1,-1)]:
            reflection=np.array([mx,mz]);inputs.append(dict(cue=(np.array(case['cue'])*reflection).tolist(),ball=(np.array(case['ball'])*reflection).tolist(),third=(np.array(case['third'])*reflection).tolist(),pocket=4 if mz==1 else 5))
    write(OUT/'partition-input.json',inputs)
    start=time.perf_counter();subprocess.run([str(WORK/'third'),str(OUT/'partition-input.json'),str(OUT/'partition-output.json')],check=True);native_ms=(time.perf_counter()-start)*1000
    outputs=json.loads((OUT/'partition-output.json').read_text());assert len(outputs)==len(inputs)
    kerror=0;counts={};centroidCount=0
    for case in cases:
        total=sum(t['area'] for t in case['tiles']);areas={k:0 for k in ['same','reverse','straight','blocked']};scorearea=0
        for j,tile in enumerate(case['tiles']):
            n=outputs[case['start']+j];tile.update(n);centroidCount+=1
            if not n['available']:kind='blocked'
            elif n['angle']<5:kind='straight'
            elif n['depth']<0:kind='reverse'
            else:kind='same'
            tile['kind']=kind;areas[kind]+=tile['area']
            if n['final']>=85:scorearea+=tile['area']
            if case['pocket'] in [4,5]:
                k=independent_k(np.array(tile['point']),np.array(case['ball']),np.array(case['third']),case['pocket'])
                kerror=max(kerror,abs(k-n['coefficient']))
                assert .6<=n['coefficient']<=1
                if abs(n['angle'])>1e-8:assert (n['direction']['reverseDepth']>0)==(n['depth']<0)
            else:assert n.get('coefficient') is None
            # Geometry classification must not be mistaken for the existing final-score rule.
            assert abs(n['final']-(n['base']*(n.get('coefficient') or 1) if n['available'] else 0))<1e-10
        assert abs(sum(areas.values())-total)<1e-12
        case['areas']={k:100*v/total for k,v in areas.items()};case['totalArea']=total;case['actual85Pct']=100*scorearea/total
        # The existing preferredSide chooses one fixed side via tangent dot B2->B3.
        u=np.array(case['aim'])-case['ball'];u/=np.linalg.norm(u)
        sign=1 if np.array([-u[1],u[0]])@(np.array(case['third'])-case['ball'])>=0 else -1
        # Keep exact native production sector vertices; order of nil-third output is [+1,-1].
        sectors=geometry[case['baseCase']-1]['sectors']
        # Re-evaluate with third through production compute below (handles clipped-empty side).
        case['legacySideSign']=sign
        representatives=[]
        for kind in ['same','reverse','straight','blocked']:
            group=[t for t in case['tiles'] if t['kind']==kind]
            if group:
                center=np.average([t['point'] for t in group],axis=0,weights=[t['area'] for t in group])
                chosen=min(group,key=lambda t:np.linalg.norm(np.array(t['point'])-center))
                representatives.append(dict(kind=kind,**{k:chosen[k] for k in ['point','angle','base','final','available','ghost','u','t','q']},coefficient=chosen.get('coefficient')))
        case['representatives']=representatives
        print(case['title'],{k:round(v,1) for k,v in case['areas'].items()},'actual85',round(case['actual85Pct'],1),flush=True)
    assert kerror<1e-7,kerror
    for i,n in enumerate(outputs[teststart:]):assert abs(n['coefficient']-expected[i//4])<1e-7
    # Native current sector with third. Reuse the frozen production source without changing the method.
    prefix=(OUT/'native-source.swift.txt').read_text().split('struct Input:Decodable')[0]
    main=prefix+'''
struct Input:Decodable{let ball,third:[Double];let pocket:Int}
let a=try JSONDecoder().decode([Input].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
let result=a.map{i -> [[[Float]]] in
 let b=SCNVector3(Float(i.ball[0]),0,Float(i.ball[1])),z=SCNVector3(Float(i.third[0]),0,Float(i.third[1]))
 let p=AngleSceneCalculator.effectivePocketAimPoint(targetBall:b,pocketIndex:i.pocket,surfaceY:0)
 return PlanThreeSectorSolver.compute(ball2:b,aim2:p,ball3:z,surfaceY:0).map{s in (s.outer+Array(s.inner.reversed())+[s.outer[0]]).map{[$0.x,$0.z]}}
}
try JSONEncoder().encode(result).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
'''
    (WORK/'sector-third.swift').write_text(main)
    cp=subprocess.run(['xcrun','swiftc','-O',str(WORK/'sector-third.swift'),'-o',str(WORK/'sector-third')],capture_output=True,text=True)
    (OUT/'native-sector-build.log').write_text(cp.stdout+cp.stderr);assert cp.returncode==0,cp.stderr
    write(OUT/'sector-input.json',[{k:c[k] for k in ['ball','third','pocket']} for c in cases])
    subprocess.run([str(WORK/'sector-third'),str(OUT/'sector-input.json'),str(OUT/'sector-output.json')],check=True)
    for c,loops in zip(cases,json.loads((OUT/'sector-output.json').read_text())):c['legacySectors']=loops
    for path,digest in frozen.items():assert sha(ROOT/path)==digest
    audit=dict(passed=True,centroids=centroidCount,goldenAndMirrorCases=8,kOracleMaxError=kerror,nativeBatchMilliseconds=native_ms,sourceSHA256=frozen,gridCM=2,transitionCutDegrees=5,transitionStatus='proposal inherited from old sector lower bound; not accepted production rule',partitionMethod='piecewise constant category at each clipped grid triangle centroid; exact native score values at that point',scope='static second/third-ball study; actual canContinue and K; no physical second/third shot simulation',sourceGeometry=dict(length=R.L,width=R.W,radius=R.R))
    write(OUT/'data.json',dict(cases=cases,audit=audit));write(OUT/'audit.json',audit)
    print('PASSED',centroidCount,'K oracle max',kerror,flush=True)

if __name__=='__main__':main()
