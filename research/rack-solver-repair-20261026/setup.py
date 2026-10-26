from pathlib import Path
import os
ROOT=Path.cwd();D=Path(os.environ.get('RACK_REPAIR_GENERATE_DIR',str(ROOT/'research/rack-solver-repair-20261026')));A=ROOT/'research/rack-solver-mirror-exact-20261026'
def write(name,s):(D/name).write_text(s)
s=(A/'EventDrivenEngine.swift').read_text();s=s.replace('enum InvarianceTrace {','enum InvarianceTrace {\n static var mode=0\n static var rejected:[[String:Any]]=[]')
s=s.replace('static func reset(){ rows=[]; first=nil }','static func reset(){ rows=[]; first=nil; rejected=[] }')
# Convert ball-pair resolution to a real applied-event contract.
s=s.replace('            resolveBallBallCollision(ballA: ballA, ballB: ballB)\n            resolvedEvents.append(event.type)\n            resolvedEventTimes.append(currentTime)', '            if resolveBallBallCollision(ballA: ballA, ballB: ballB) {\n                resolvedEvents.append(event.type)\n                resolvedEventTimes.append(currentTime)\n            }')
a=s.index('    private func resolveBallBallCollision(ballA:');b=s.index('    /// Resolve ball-cushion collision',a);chunk=s[a:b].replace('ballB: String) {','ballB: String) -> Bool {').replace('else { return }','else { return false }')
marker='        InvarianceTrace.pair("beforeKiss",a:stateA,b:stateB,now:currentTime)'
chunk=chunk.replace(marker,'''        if InvarianceTrace.mode > 0 && !EngineNumerics.isBallPairOverlappingOrTouching(stateA,stateB) {
            InvarianceTrace.rejected.append(["t":Double(currentTime),"a":ballA,"b":ballB])
            return false
        }
'''+marker)
chunk=chunk.replace('        balls[ballB] = stateB','        balls[ballB] = stateB\n        return true');s=s[:a]+chunk+s[b:];write('EventDrivenEngine.swift',s)
s=(ROOT/'QiuJi/Core/Physics/EngineNumerics.swift').read_text();marker='    static func isBallPairOverlappingOrTouching(_ a: BallState, _ b: BallState) -> Bool {'
s=s.replace(marker,'''    // Conservative Float position arithmetic envelope: four rounding operations
    // per coordinate in r+v*t-0.5*a*t*t. Scales with actual stored-coordinate ULPs,
    // not a physical ball gap or a tunable fraction of the radius.
    static func researchContactRoundoff(_ a:SCNVector3,_ b:SCNVector3)->Double {
        let dx=Double(a.x.ulp)+Double(b.x.ulp), dz=Double(a.z.ulp)+Double(b.z.ulp)
        return 4*(hypot(dx,dz)+Double(BallPhysics.radius.ulp))
    }
'''+marker+'''
        if InvarianceTrace.mode > 0 {
            let dx=Double(b.position.x)-Double(a.position.x), dz=Double(b.position.z)-Double(a.position.z)
            let d=hypot(dx,dz), gap=d-2*Double(BallPhysics.radius)
            let closing=dx*(Double(b.velocity.x)-Double(a.velocity.x))+dz*(Double(b.velocity.z)-Double(a.velocity.z))
            return gap <= researchContactRoundoff(a.position,b.position) && closing < 0
        }
''')
s=s.replace('    ) -> Bool {\n        guard maxTime > 0 else { return false }','    ) -> Bool {\n        if InvarianceTrace.mode > 0 { return false } // bounded roots already cover this interval\n        guard maxTime > 0 else { return false }',1);write('EngineNumerics.swift',s)
s=(ROOT/'QiuJi/Core/Physics/PhysicsEvent.swift').read_text();s=s.replace('    static func < (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {','''    static func < (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        if InvarianceTrace.mode > 0 {
            return lhs.time == rhs.time ? lhs.priority < rhs.priority : lhs.time < rhs.time
        }''');s=s.replace('    static func == (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {','''    static func == (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        if InvarianceTrace.mode > 0 { return lhs.time == rhs.time && lhs.priority == rhs.priority }
        return''');write('PhysicsEvent.swift',s)
s=(ROOT/'QiuJi/Core/Physics/CollisionDetector.swift').read_text();marker='        let roots = QuarticSolver.solveQuartic(a: a, b: b, c: c, d: d, e: e)';assert s.count(marker)==1
s=s.replace(marker,'''        if InvarianceTrace.mode > 0 {
            let roots = QuarticSolver.boundedRealRoots(coefficients:[a,b,c,d,e],maxTime:maxTime)
            let entering = roots.filter { t in
                let p=dp+dv*t+da*(0.5*t*t), v=dv+da*t
                return dot(p,v)<0
            }
            return smallestPositiveRoot(roots:entering,maxTime:maxTime)
        }
'''+marker);write('CollisionDetector.swift',s)
s=(ROOT/'QiuJi/Core/Physics/CollisionResolver.swift').read_text();marker='''    ) -> BallBallResult {
        let unitX''';assert s.count(marker)==1
s=s.replace(marker,'''    ) -> BallBallResult {
        if InvarianceTrace.mode >= 2 {
            return researchSymmetricPair(posA:posA,posB:posB,velA:velA,velB:velB,angVelA:angVelA,angVelB:angVelB)
        }
        let unitX''')
s+='''
extension CollisionResolver {
    // Same sliding/sticking model in a vector basis, no angle rotations and no
    // label-based A/B canonicalization. Double intermediates, one Float rounding.
    static func researchSymmetricPair(posA:SCNVector3,posB:SCNVector3,velA:SCNVector3,velB:SCNVector3,angVelA:SCNVector3,angVelB:SCNVector3)->BallBallResult {
        func d(_ v:SCNVector3)->SIMD3<Double>{SIMD3(Double(v.x),Double(v.y),Double(v.z))}
        func f(_ v:SIMD3<Double>)->SCNVector3{SCNVector3(Float(v.x),Float(v.y),Float(v.z))}
        func dot(_ a:SIMD3<Double>,_ b:SIMD3<Double>)->Double{a.x*b.x+a.y*b.y+a.z*b.z}
        func cross(_ a:SIMD3<Double>,_ b:SIMD3<Double>)->SIMD3<Double>{SIMD3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)}
        var delta=d(posB)-d(posA);delta.y=0
        let n=delta/sqrt(dot(delta,delta)),a=d(velA),b=d(velB),wa=d(angVelA),wb=d(angVelB)
        let R=Double(BallPhysics.radius),e=Double(BallPhysics.restitution),relative=a-b,normal=dot(relative,n)
        let u=relative-n*normal+cross(wa+wb,n)*R
        let speed=sqrt(dot(u,u)),mu=Double(BallPhysics.contactFriction(relativeSurfaceSpeed:Float(speed)))
        var tangential=SIMD3<Double>.zero
        if speed>0.0001 {
            let sliding=u*(-mu*abs(e*normal)/speed)
            tangential=dot(u,u+sliding*7)>0 ? sliding : -u/7
        } else { tangential = -u/7 }
        let impulse = -n*(0.5*(1+e)*normal)+tangential
        let dw=cross(n,tangential)*(2.5/R)
        var va=a+impulse,vb=b-impulse;va.y=0;vb.y=0
        return BallBallResult(velA:f(va),velB:f(vb),angVelA:f(wa+dw),angVelB:f(wb+dw))
    }
}
''';write('CollisionResolver.swift',s)
write('BreakSimulator.swift',(A/'BreakSimulator.swift').read_text())
s=(A/'build.py').read_text().replace('output/rack-solver-mirror-exact-20261026','output/rack-solver-repair-20261026')
s=s.replace("'BreakSimulator.swift'];bindings", "'BreakSimulator.swift','EngineNumerics.swift','PhysicsEvent.swift','CollisionDetector.swift','CollisionResolver.swift'];bindings")
s=s.replace("old.name in ['EventDrivenEngine.swift','BreakSimulator.swift']", "old.name in ['EventDrivenEngine.swift','BreakSimulator.swift','EngineNumerics.swift','PhysicsEvent.swift','CollisionDetector.swift','CollisionResolver.swift']")
s=s.replace("'BreakSimulator.o']", "'BreakSimulator.o','EngineNumerics.o','PhysicsEvent.o','CollisionDetector.o','CollisionResolver.o']");write('build.py',s)
s=(A/'main.swift').read_text().replace('            let original = RackLayout.make', '            InvarianceTrace.mode = input["mode"] as! Int\n            let original = RackLayout.make')
s=s.replace('let rack = Rack(game:game,cue:original.cue,balls:reverse ? Array(canonical.reversed()):canonical,surfaceY:original.surfaceY)', '''let ordered = (input["permutation"] as? [Int]).map { p in p.map{canonical[$0]} } ?? (reverse ? Array(canonical.reversed()):canonical)
            let rack = Rack(game:game,cue:original.cue,balls:ordered,surfaceY:original.surfaceY)''')
s=s.replace('                row["pairTrace"] = InvarianceTrace.rows','                row["rejectedPairs"] = InvarianceTrace.rejected\n                row["pairTrace"] = InvarianceTrace.rows');write('main.swift',s)

# r2 corrections, included here so the research sources are reproducible.
p=D/'PhysicsEvent.swift';s=p.read_text().replace('        return\n        return abs','        return abs');p.write_text(s)
p=D/'EventDrivenEngine.swift';s=p.read_text()
s=s.replace('        EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)\n        EngineNumerics.constrainPairSeparation(&stateA, &stateB, geometry: tableGeometry)', '        if InvarianceTrace.mode == 0 {\n            EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)\n            EngineNumerics.constrainPairSeparation(&stateA, &stateB, geometry: tableGeometry)\n        }')
s=s.replace('        let targetDist = twoR + spacer','        let targetDist = InvarianceTrace.mode > 0 ? twoR : twoR + spacer')
s=s.replace('                    if d2 >= triggerDistSq { continue }', '                    if d2 >= triggerDistSq { continue }\n                    if InvarianceTrace.mode > 0 {\n                        let exactDistance=hypot(Double(b.position.x)-Double(a.position.x),Double(b.position.z)-Double(a.position.z))\n                        if 2*Double(BallPhysics.radius)-exactDistance <= EngineNumerics.researchContactRoundoff(a.position,b.position) { continue }\n                    }')
p.write_text(s)
p=D/'EngineNumerics.swift';s=p.read_text().replace('        let target = 2 * BallPhysics.radius + 3e-5','        let target = InvarianceTrace.mode > 0 ? 2 * BallPhysics.radius : 2 * BallPhysics.radius + 3e-5');p.write_text(s)
p=D/'main.swift';s=p.read_text();s=s.replace('let profile = AccuracyTipSelector.renderedProfile()', (ROOT/'research/rack-solver-repair-20261026/probe.swift').read_text()+'\nlet probe=repairProbe()\nlet profile = AccuracyTipSelector.renderedProfile()');s=s.replace('"pid": ProcessInfo.processInfo.processIdentifier, "length": length,','"pid": ProcessInfo.processInfo.processIdentifier, "probe":probe,"length": length,');p.write_text(s)
