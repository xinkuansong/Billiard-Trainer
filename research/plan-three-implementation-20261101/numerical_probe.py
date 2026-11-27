from pathlib import Path
s=Path('QiuJi/Features/PositionPlay/ViewModels/PlanThreeViewModel.swift').read_text();alg=s[s.index('enum PlanThreeComfortRegion'):s.index('// MARK: - ViewModel')]
s=Path('QiuJi/Core/PositionPlay/PositionPlaySolverModels.swift').read_text();mesh=s[s.index('struct SampledSolveRegion'):s.index('// MARK: - Constraint')]
s=Path('QiuJi/Core/Scene/AngleSceneCalculator.swift').read_text();block=s[s.index('    static func isPathBlocked('):s.index('    // MARK: - Snooker coverage')]
base='''import Foundation
struct SCNVector3 { var x:Float; var y:Float; var z:Float; init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z} }
enum AngleSceneCalculator { static let innerLength:Float=2.54,innerWidth:Float=1.27,ballRadius:Float=0.028575
'''+block+'}\n'
import json, subprocess, hashlib
out=Path('output/plan-three-implementation-20261101');out.mkdir(parents=True,exist_ok=True)
cases=json.loads(Path('output/plan-three-third-region-20261101/data.json').read_text())['cases']
inputs=[]
for case in cases:
 for sx,sz in [(1,1),(-1,1),(1,-1),(-1,-1)]:
  def v(k):
   a=case[k];return f'SCNVector3({a[0]*sx},0,{a[1]*sz})'
  inputs.append(f'({json.dumps(case["title"],ensure_ascii=False)}, {v("ball")}, {v("aim")}, {v("third")})')
main="""
let cases: [(String,SCNVector3,SCNVector3,SCNVector3)] = [CASES]
var rows:[[String:Any]]=[]
for (title,ball,aim,third) in cases {
 let start=Date()
 guard let mesh=PlanThreeComfortRegion.compute(ball:ball,aim:aim,third:third) else {
 rows.append(["title":title,"empty":true]);continue
 }
 func dot(_ a:SIMD2<Double>,_ b:SIMD2<Double>)->Double{a.x*b.x+a.y*b.y}
 func norm(_ a:SIMD2<Double>)->Double{hypot(a.x,a.y)}
 let b=SIMD2<Double>(Double(ball.x),Double(ball.z)),p=SIMD2<Double>(Double(aim.x),Double(aim.z))
 let z=SIMD2<Double>(Double(third.x),Double(third.z)),n=(p-b)/norm(p-b),g=b-2*Double(AngleSceneCalculator.ballRadius)*n
 var minAngle=180.0,minSide=1.0,invalid=0,minScore=100.0
 for poly in mesh.polygons {
 let c=poly.reduce(SIMD2<Double>.zero,+)/Double(poly.count)
 if mesh.signedDistance(c)>1e-7 { invalid += 1 }
 minScore=min(minScore,ShotComfortScore.evaluate(cue:(c.x,c.y),ball:(b.x,b.y),aim:(p.x,p.y))?.total ?? 0)
 for c in poly {
 let v=(g-c)/norm(g-c),q=v-dot(v,n)*n,axis=SIMD2<Double>(-v.y,v.x)
 minAngle=min(minAngle,acos(min(1,max(-1,dot(v,n))))*180/Double.pi)
 minSide=min(minSide,dot(q,axis)*dot(z-g,axis))
 }
 }
 let closed=mesh.boundaryLoops.allSatisfy{norm($0.first!-$0.last!)<1e-7}
 precondition(invalid==0 && minAngle>=5-1e-7 && minSide>=(-1e-9) && closed)
 rows.append(["title":title,"polygons":mesh.polygons.count,"loops":mesh.boundaryLoops.count,"invalidCenters":invalid,"minimumCut":minAngle,"minimumSideProduct":minSide,"minimumCentroidComfort":minScore,"closed":closed,"seconds":Date().timeIntervalSince(start)])
}
let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
FileHandle.standardOutput.write(data)
""".replace('CASES',',\n'.join(inputs))
code=base+mesh+Path('QiuJi/Core/PositionPlay/ShotComfortScore.swift').read_text()+alg+main
src=out/'numerical-probe.swift';src.write_text(code)
subprocess.run(['swiftc','-O',str(src),'-o',str(out/'numerical-probe')],check=True)
with (out/'numerical-audit.json').open('w') as f:subprocess.run([str(out/'numerical-probe')],stdout=f,check=True)
(out/'numerical-provenance.json').write_text(json.dumps({str(src):hashlib.sha256(src.read_bytes()).hexdigest(),"scope":"Production pure geometry extracted verbatim; SCNVector3 and geometry constants bridged for host CLI. Not native UI or physical-engine evidence."},indent=2))
print('32 original/mirrored layouts checked')
