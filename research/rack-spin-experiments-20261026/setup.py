from pathlib import Path
import shutil,hashlib,json,ast,math
D=Path(__file__).resolve().parent;ROOT=D.parents[1];BASE=ROOT/'research/rack-solver-repair-20261026'
for name in ['EventDrivenEngine.swift','BreakSimulator.swift','EngineNumerics.swift','PhysicsEvent.swift','CollisionDetector.swift','CollisionResolver.swift','main.swift','build.py']:
 shutil.copy2(BASE/name,D/name)
# Per-shot parameters, no production source change. Body-level hooks avoid default-argument freezing.
p=D/'AnalyticalMotion.swift';s=(ROOT/'QiuJi/Core/Physics/AnalyticalMotion.swift').read_text()
s=s.replace('struct AnalyticalMotion {','struct AnalyticalMotion {\n static var researchSpinScale:Float=1')
assert 'researchSpinScale:Float=1' in s
s=s.replace('let alpha = 5 * spinFriction * gravity / (2 * radius)','let alpha = 5 * spinFriction * gravity / (2 * radius) * researchSpinScale')
s=s.replace('return wy * 2.0 / 5.0 * radius / (spinFriction * gravity)','return wy * 2.0 / 5.0 * radius / (spinFriction * gravity) / researchSpinScale');p.write_text(s)
p=D/'Han2005CushionModel.swift';s=(ROOT/'QiuJi/Core/Physics/Han2005CushionModel.swift').read_text()
s=s.replace('enum Han2005CushionModel {','enum Han2005CushionModel {\n static var researchModel="han"\n static var researchMu:Float=0.2\n static var researchStep:Double=0.0001\n static var researchCalls:[[String:Any]]=[]')
s=s.replace('        // 接触角：', '''        let mu = Self.researchMu
        if Self.researchModel == "mathavan" {
            let q=ResearchMathavan.solve([-Double(vTangent),Double(vNormal),-Double(wTangent),Double(wNormal),Double(wUp)],R:Double(R),M:Double(M),h:Double(h),e:Double(e),mu:Double(mu),step:researchStep)
            return Result(vNormal:Float(q[1]),vTangent:Float(-q[0]),wNormal:Float(q[3]),wTangent:Float(-q[2]),wUp:Float(q[4]))
        }
        // 接触角：''',1)
s += '\n'+(D/'Mathavan.swift.txt').read_text();p.write_text(s)
p=D/'EventDrivenEngine.swift';s=p.read_text();s=s.replace('        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)','        let preState=state\n        let approach = ContactSoundEvent.approach(state.velocity, normal: normal)')
s=s.replace('        balls[ball] = state\n        return true\n    }\n    \n    /// Resolve state transition','''        Han2005CushionModel.researchCalls.append(["time":Double(currentTime),"index":cushionIndex,"surface":surface.rawValue,"pre":InvarianceTrace.state(preState),"post":InvarianceTrace.state(state),"normal":InvarianceTrace.v(normal)])
        balls[ball] = state
        return true
    }
    
    /// Resolve state transition''');p.write_text(s)
p=D/'main.swift';s=p.read_text();s=s.replace('            InvarianceTrace.mode = input["mode"] as! Int','''            InvarianceTrace.mode = input["mode"] as! Int
            Han2005CushionModel.researchModel=input["cushionModel"] as! String
            Han2005CushionModel.researchMu=Float(input["mu"] as! Double)
            Han2005CushionModel.researchStep=input["step"] as! Double
            Han2005CushionModel.researchCalls=[]
            AnalyticalMotion.researchSpinScale=Float(input["spinScale"] as! Double)''')
s=s.replace('                row["pairTrace"] = InvarianceTrace.rows','                row["pairTrace"] = InvarianceTrace.rows\n                row["cushionTrace"] = Han2005CushionModel.researchCalls')
# Capped complete physical horizon remains 30s; no visual cutoff or spin clamp.
# Include an independent upstream-reference fixture set in native READY.
probe='''
func cushionProbe()->[[String:Any]] {
 var rows:[[String:Any]]=[]
 for i in 1...100 {
  let q=[Double(i%13)-6,0.1+Double(i%17)*0.7,Double(i%19-9)*13,Double(i%11-5)*17,Double(i%23-11)*23]
  let a=ResearchMathavan.solve(q,R:Double(BallPhysics.radius),M:Double(BallPhysics.mass),h:Double(TablePhysics.cushionHeight),e:0.85,mu:0.2,step:0.0001)
  rows.append(["input":q,"output":a])
 }
 AnalyticalMotion.researchSpinScale=Float(22.0/10.9)
 let t=AnalyticalMotion.spinToStationaryTime(angularVelocity:SCNVector3(0,220,0))
 let w=AnalyticalMotion.decaySpin(angularVelocity:SCNVector3(0,220,0),dt:5)
 precondition(abs(t-10)<0.00001 && abs(w.y-110)<0.0001)
 AnalyticalMotion.researchSpinScale=1
 return rows
}
'''
s=s.replace('let probe=repairProbe()',probe+'\nlet probe=repairProbe()')
s=s.replace('"probe":probe,','"probe":probe,"cushionProbe":cushionProbe(),');p.write_text(s)
p=D/'build.py';s=p.read_text().replace("OUT=ROOT/'output/rack-solver-repair-20261026'","OUT=ROOT/'output/rack-spin-experiments-20261026'")
s=s.replace("'CollisionResolver.swift']","'CollisionResolver.swift','AnalyticalMotion.swift','Han2005CushionModel.swift']")
s=s.replace("'CollisionResolver.o']","'CollisionResolver.o','AnalyticalMotion.o','Han2005CushionModel.o']")
p.write_text(s)
# Execute only the pure numerical upstream functions; no pooltool installation.
mod=ast.parse((D/'upstream-mathavan.py').read_text());nodes=[]
for n in mod.body:
 if isinstance(n,ast.FunctionDef) and n.name in ['get_sin_and_cos_theta','calculate_slip_speeds_and_angles','update_velocity','update_angular_velocity','calculate_work_done','compression_phase','restitution_phase','solve']:
  n.decorator_list=[];nodes.append(n)
ns={'math':math,'np':math};exec(compile(ast.Module(body=nodes,type_ignores=[]),'upstream','exec'),ns)
R=.028574999421834946;M=.17000000178813934;h=.03700000047683716
fixtures=[]
for i in range(1,101):
 q=[float(i%13)-6,.1+(i%17)*.7,(i%19-9)*13.,(i%11-5)*17.,(i%23-11)*23.]
 fixtures.append(dict(input=q,output=ns['solve'](M,R,h,.85,.20000000298023224,.2,*q)))
(D/'mathavan-reference.json').write_text(json.dumps(fixtures,indent=2))
(D/'source-provenance.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [*BASE.glob('*.swift'),ROOT/'QiuJi/Core/Physics/AnalyticalMotion.swift',ROOT/'QiuJi/Core/Physics/Han2005CushionModel.swift']},indent=2))
