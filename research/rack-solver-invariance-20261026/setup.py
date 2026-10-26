from pathlib import Path
ROOT=Path.cwd();D=ROOT/'research/rack-solver-invariance-20261026'
s=(ROOT/'QiuJi/Core/Physics/EventDrivenEngine.swift').read_text()
for old,new in [
('        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss','        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)\n        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss'),
('        let approach = ContactSoundEvent.approach(stateA.velocity - stateB.velocity,','        InvarianceTrace.pair("beforeImpulse",a:stateA,b:stateB,now:currentTime)\n        let approach = ContactSoundEvent.approach(stateA.velocity - stateB.velocity,'),
('        balls[ballA] = stateA\n        balls[ballB] = stateB','        InvarianceTrace.pair("afterImpulse",a:stateA,b:stateB,now:currentTime)\n        balls[ballA] = stateA\n        balls[ballB] = stateB')]:
 assert s.count(old)==1;s=s.replace(old,new)
s+='''
// Research-only observer. No solver decisions or parameters are changed.
enum InvarianceTrace {
 static var rows:[[String:Any]]=[]
 static var first:Float?=nil
 static func reset(){ rows=[]; first=nil }
 static func v(_ x:SCNVector3)->[Double]{[Double(x.x),Double(x.y),Double(x.z)]}
 static func state(_ b:BallState)->[String:Any]{["name":b.name,"p":v(b.position),"v":v(b.velocity),"w":v(b.angularVelocity),"state":b.state.rawValue]}
 static func pair(_ phase:String,a:BallState,b:BallState,now:Float){
  if first == nil { first=now }
  guard now <= first! + 0.020001 else { return }
  let dp=SIMD3<Double>(Double(b.position.x)-Double(a.position.x),Double(b.position.y)-Double(a.position.y),Double(b.position.z)-Double(a.position.z))
  let dv=SIMD3<Double>(Double(b.velocity.x)-Double(a.velocity.x),Double(b.velocity.y)-Double(a.velocity.y),Double(b.velocity.z)-Double(a.velocity.z))
  let dist=sqrt(dp.x*dp.x+dp.y*dp.y+dp.z*dp.z)
  rows.append(["phase":phase,"t":Double(now),"a":state(a),"b":state(b),"gap":dist-2*Double(BallPhysics.radius),"approach":-(dp.x*dv.x+dp.y*dv.y+dp.z*dv.z)/dist])
 }
}
'''
(D/'EventDrivenEngine.swift').write_text(s)
s=(ROOT/'research/rack-spin-tail-20261026/build.py').read_text().replace('output/rack-spin-tail-20261026','output/rack-solver-invariance-20261026')
s=s.replace("replacements=['RackLayout.swift','BreakFlowRunner.swift']", "replacements=['RackLayout.swift','BreakFlowRunner.swift','EventDrivenEngine.swift']")
s=s.replace("shutil.copy2(q if old.name in replacements else old,new)", "shutil.copy2(HERE/old.name if old.name=='EventDrivenEngine.swift' else (q if old.name in replacements else old),new)")
s=s.replace("['main.o','RackLayout.o','BreakFlowRunner.o']", "['main.o','RackLayout.o','BreakFlowRunner.o','EventDrivenEngine.o']")
(D/'build.py').write_text(s)
s=(ROOT/'research/rack-production-integration-20261026/main.swift').read_text()
s=s.replace('            let rack = RackLayout.make(game, seed: seed)', '''            let original = RackLayout.make(game, seed: seed)
            let mirror = input["mirror"] as! Bool
            let reverse = input["reverse"] as! Bool
            let canonical = original.balls.map { b -> RackBall in
                var p=b.position; if mirror { p.z = -p.z }
                return RackBall(key:b.key,number:b.number,position:p)
            }
            let rack = Rack(game:game,cue:original.cue,balls:reverse ? Array(canonical.reversed()):canonical,surfaceY:original.surfaceY)''')
s=s.replace('                let result = BreakSimulator.breakShot', '                InvarianceTrace.reset()\n                let result = BreakSimulator.breakShot')
s=s.replace('                row["seconds"]', '                row["pairTrace"] = InvarianceTrace.rows\n                row["canonicalNames"] = canonical.map(\\.key)\n                row["seconds"]',1)
s=s.replace('                row["firstContacts"]', '''                let lastMoving = frames[0].indices.last { k in frames.contains { $0[k].state == .sliding || $0[k].state == .rolling } }
                let stopIndex = min((lastMoving ?? 0)+1,frames[0].count-1)
                let lastTranslation=frames[0][stopIndex].time
                row["lastTranslation"] = Double(lastTranslation)
                row["spinTail"] = names.indices.map { i -> [String:Any] in
                    let f=frames[i],at=f[stopIndex]
                    let end=f[stopIndex...].first(where:{$0.state == .stationary})?.time ?? at.time
                    let tail=at.state == .spinning && abs(at.angularVelocity.y)>0.0001 ? max(0,end-lastTranslation):0
                    return ["name":names[i],"tail":Double(tail),"wy":Double(at.angularVelocity.y),"peakWy":Double(f.map{abs($0.angularVelocity.y)}.max()!)]
                }
                row["firstContacts"]''')
(D/'main.swift').write_text(s)
