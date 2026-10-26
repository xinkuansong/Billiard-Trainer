import Foundation
import SceneKit
import Darwin
func cpuSeconds() -> Double {
    var t = timespec(); clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t)
    return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9
}

// Research entry. Rack, strike, material constants, motion decay and pockets are production code; collision algorithms vary explicitly.
func emit(_ prefix: String, _ object: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    FileHandle.standardOutput.write(Data((prefix + "\t" + String(decoding: data, as: UTF8.self) + "\n").utf8))
}
func vec(_ v: SCNVector3) -> [Double] { [Double(v.x),Double(v.y),Double(v.z)] }
func vec3(_ v: SCNVector4) -> [Double] { [Double(v.x),Double(v.y),Double(v.z)] }
func evolved(_ f: BallFrame, dt: Float) -> BallFrame {
    let w=SCNVector3(f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z)
    var p=f.position,v=f.velocity,omega=w
    switch f.state {
    case .sliding:
        let q=AnalyticalMotion.evolveSliding(position:p,velocity:v,angularVelocity:w,dt:dt);p=q.position;v=q.velocity;omega=q.angularVelocity
    case .rolling:
        let q=AnalyticalMotion.evolveRolling(position:p,velocity:v,angularVelocity:w,dt:dt);p=q.position;v=q.velocity;omega=q.angularVelocity
    case .spinning:
        let q=AnalyticalMotion.evolveSpinning(position:p,angularVelocity:w,dt:dt);p=q.position;omega=q.angularVelocity
    case .stationary,.pocketed: break
    }
    return BallFrame(time:f.time+dt,position:p,velocity:v,angularVelocity:SCNVector4(omega.x,omega.y,omega.z,0),state:f.state)
}

func repairProbe()->[String:Any] {
 InvarianceTrace.mode=2
 func w(_ v:SCNVector3)->Double{Double(v.x)*Double(v.x)+Double(v.y)*Double(v.y)+Double(v.z)*Double(v.z)}
 func mirrorV(_ v:SCNVector3)->SCNVector3{SCNVector3(v.x,v.y,-v.z)}
 func mirrorW(_ v:SCNVector3)->SCNVector3{SCNVector3(-v.x,-v.y,v.z)}
 var maxEnergyIncrease=0.0,maxOldDelta:Float=0
 for i in 1...300 {
  let theta=Float(i)*0.213,n=SCNVector3(cosf(theta),0,sinf(theta)),t=SCNVector3(-n.z,0,n.x)
  let a=SCNVector3(0.3,0.85,0.1),b=a+n*(2*BallPhysics.radius)
  let va=n*Float(2+i%17)+t*Float(i%5),vb=t*Float(i%3)
  let wa=SCNVector3(Float(i%7)*3,Float(i%13)*5,Float(i%11)*2),wb=SCNVector3(Float(i%5)*7,-Float(i%17)*2,Float(i%3)*11)
  let q=CollisionResolver.resolveBallBallPure(posA:a,posB:b,velA:va,velB:vb,angVelA:wa,angVelB:wb)
  let rev=CollisionResolver.resolveBallBallPure(posA:b,posB:a,velA:vb,velB:va,angVelA:wb,angVelB:wa)
  precondition((q.velA-rev.velB).length()==0 && (q.velB-rev.velA).length()==0)
  precondition((q.angVelA-rev.angVelB).length()==0 && (q.angVelB-rev.angVelA).length()==0)
  let m=CollisionResolver.resolveBallBallPure(posA:mirrorV(a),posB:mirrorV(b),velA:mirrorV(va),velB:mirrorV(vb),angVelA:mirrorW(wa),angVelB:mirrorW(wb))
  precondition((mirrorV(q.velA)-m.velA).length()==0 && (mirrorW(q.angVelA)-m.angVelA).length()==0)
  let R=Double(BallPhysics.radius),before=w(va)+w(vb)+0.4*R*R*(w(wa)+w(wb)),after=w(q.velA)+w(q.velB)+0.4*R*R*(w(q.angVelA)+w(q.angVelB))
  maxEnergyIncrease=max(maxEnergyIncrease,(after-before)/before);precondition(after<=before*(1+1e-6))
  InvarianceTrace.mode=0
  let old=CollisionResolver.resolveBallBallPure(posA:a,posB:b,velA:va,velB:vb,angVelA:wa,angVelB:wb)
  maxOldDelta=max(maxOldDelta,(old.velA-q.velA).length(),(old.velB-q.velB).length())
  InvarianceTrace.mode=2
 }
 let R=BallPhysics.radius,a=BallState(position:SCNVector3(0,0,0),velocity:SCNVector3(5,0,0),angularVelocity:SCNVector3Zero,state:.sliding,name:"a")
 let b=BallState(position:SCNVector3(2*R+0.0002,0,0),velocity:SCNVector3Zero,angularVelocity:SCNVector3Zero,state:.stationary,name:"b")
 precondition(!EngineNumerics.isBallPairOverlappingOrTouching(a,b))
 let time=CollisionDetector.ballBallCollisionTime(p1:a.position,p2:b.position,v1:a.velocity,v2:b.velocity,a1:SCNVector3Zero,a2:SCNVector3Zero,R:Double(R),maxTime:1)!
 let expected=(Double(b.position.x)-2*Double(R))/5
 precondition(abs(Double(time)-expected)<1e-10)
 precondition(CollisionDetector.ballBallCollisionTime(p1:a.position,p2:b.position,v1:SCNVector3(-5,0,0),v2:b.velocity,a1:SCNVector3Zero,a2:SCNVector3Zero,R:Double(R),maxTime:1)==nil)
 InvarianceTrace.mode=0
 return ["pairCases":300,"exchangeExact":true,"reflectionExact":true,"maxEnergyIncrease":maxEnergyIncrease,"maxLegacyVelocityDelta":Double(maxOldDelta),"gapTimeActual":Double(time),"gapTimeExpected":expected,"separatingPairHasNoImpact":true]
}

// Algorithm fixtures use the same production constants; tolerance is numerical only.
func fixedPhysicsProbe()->[String:Any] {
 typealias V=SIMD3<Double>
 typealias M=SpatialBallContact.Motion
 typealias C=SpatialBallContact.Constraint
 let R=Double(BallPhysics.radius),e=Double(TablePhysics.cushionRestitution)
 let s=Double(TablePhysics.cushionHeight)/R-1,c=sqrt(1-s*s),U=V(0,1,0),N=V(-c,-s,0)
 let wall=C(a:0,b:nil,normal:N,restitution:e,friction:Double(TablePhysics.cushionFriction))
 let floor=C(a:0,b:nil,normal:U,restitution:0,friction:Double(SpinPhysics.slidingFriction))
 func dot(_ a:V,_ b:V)->Double {FixedPhysicsResearch.dot(a,b)}
 func norm(_ v:V)->Double {sqrt(dot(v,v))}
 func mirrorV(_ v:V)->V {V(v.x,v.y,-v.z)}
 func mirrorW(_ v:V)->V {V(-v.x,-v.y,v.z)}
 func E(_ q:[M])->Double {q.reduce(0){$0+dot($1.velocity,$1.velocity)+0.4*R*R*dot($1.angularVelocity,$1.angularVelocity)}}
 var count=0,failures:[String]=[],maxMirror=0.0,maxOrder=0.0,maxEnergyRatio=0.0,maxRestitution=0.0,maxVertical=0.0
 for speed in [0.05,0.5,2.0,5.0,10.0,15.0] {for tangent in [-10.0,-2.0,0.0,2.0,10.0] {for wy in [-300.0,-100.0,0.0,100.0,300.0] {for wx in [-200.0,0.0,200.0] {
  let initial=[M(velocity:V(speed,0,tangent),angularVelocity:V(wx,wy,-speed/R))]
  count+=1
  do {
   let q=try SpatialBallContact.resolveCoupled(initial,constraints:[wall,floor],radius:R)[0]
   let rev=try SpatialBallContact.resolveCoupled(initial,constraints:[floor,wall],radius:R)[0]
   let mir=try SpatialBallContact.resolveCoupled([M(velocity:mirrorV(initial[0].velocity),angularVelocity:mirrorW(initial[0].angularVelocity))],constraints:[wall,floor],radius:R)[0]
   maxMirror=max(maxMirror,norm(mirrorV(q.velocity)-mir.velocity),R*norm(mirrorW(q.angularVelocity)-mir.angularVelocity))
   maxOrder=max(maxOrder,norm(q.velocity-rev.velocity),R*norm(q.angularVelocity-rev.angularVelocity))
   maxEnergyRatio=max(maxEnergyRatio,(E([q])-E(initial))/E(initial))
   maxRestitution=max(maxRestitution,abs(dot(q.velocity,N)+e*dot(initial[0].velocity,N)))
   maxVertical=max(maxVertical,abs(q.velocity.y))
  } catch {failures.append("support \(count): \(error)")}
 }}}}
 // Truly touching line: zero-gap response is a model fixture, not a claim
 // that the positive-gap rack experiences this simultaneous impact.
 let eb=Double(BallPhysics.restitution),mu=Double(BallPhysics.contactFriction(relativeSurfaceSpeed:0))
 let start=[M(velocity:V(6,0,0),angularVelocity:.zero),M(velocity:.zero,angularVelocity:.zero),M(velocity:.zero,angularVelocity:.zero)]
 let cs=[C(a:0,b:1,normal:V(-1,0,0),restitution:eb,friction:mu),C(a:1,b:2,normal:V(-1,0,0),restitution:eb,friction:mu)]
 var joint:[String:Any]=[:]
 do {
  let q=try SpatialBallContact.resolveInstant(start,constraints:cs,radius:R)
  let rev=try SpatialBallContact.resolveInstant(start,constraints:Array(cs.reversed()),radius:R)
  let reindex=try SpatialBallContact.resolveInstant(Array(start.reversed()),constraints:[C(a:2,b:1,normal:V(-1,0,0),restitution:eb,friction:mu),C(a:1,b:0,normal:V(-1,0,0),restitution:eb,friction:mu)],radius:R)
  let mirrored=try SpatialBallContact.resolveInstant(start.map{M(velocity:-$0.velocity,angularVelocity:$0.angularVelocity)},constraints:cs.map{C(a:$0.a,b:$0.b,normal:-$0.normal,restitution:$0.restitution,friction:$0.friction)},radius:R)
  let orderDelta=q.motions.indices.map{norm(q.motions[$0].velocity-rev.motions[$0].velocity)}.max()!
  let bodyDelta=q.motions.indices.map{norm(q.motions[$0].velocity-reindex.motions[2-$0].velocity)}.max()!
  let mirrorDelta=q.motions.indices.map{norm(q.motions[$0].velocity+mirrored.motions[$0].velocity)}.max()!
  let momentum=norm(q.motions.reduce(V.zero){$0+$1.velocity}-V(6,0,0))
  precondition(max(orderDelta,bodyDelta,mirrorDelta,momentum)<1e-9 && E(q.motions)<=E(start)+1e-9)
  joint=["velocities":q.motions.map{[$0.velocity.x,$0.velocity.y,$0.velocity.z]},"rounds":q.rounds.count,"momentumResidual":momentum,"constraintOrderDelta":orderDelta,"bodyOrderDelta":bodyDelta,"mirrorDelta":mirrorDelta,"energyRatio":E(q.motions)/E(start)]
 } catch {failures.append("joint: \(error)")}
 FixedPhysicsResearch.variant="coulomb"
 let coulomb=repairProbe()
 FixedPhysicsResearch.variant="baseline";FixedPhysicsResearch.reset();InvarianceTrace.mode=0
 return ["supportCases":count,"failures":failures,"mirrorDelta":maxMirror,"constraintOrderDelta":maxOrder,"maxEnergyIncreaseFraction":maxEnergyRatio,"restitutionResidual":maxRestitution,"verticalResidual":maxVertical,"passed":failures.isEmpty && max(maxMirror,maxOrder,maxRestitution,maxVertical)<1e-9 && maxEnergyRatio<1e-9,"touchingThreeBall":joint,"coulombPair":coulomb]
}

let fixedProbe=fixedPhysicsProbe()
let probe=repairProbe()
let profile = AccuracyTipSelector.renderedProfile()
let length = Double(TablePhysics.innerLength), width = Double(TablePhysics.innerWidth)
let radius = Double(BallPhysics.radius), surface = BTTablePhysics.surfaceY
try emit("READY", ["pid": ProcessInfo.processInfo.processIdentifier, "probe":probe,"fixedProbe":fixedProbe,"parameters":FixedPhysicsResearch.parameters,"length": length,
                   "defaultBreakVelocity": BreakFlowRunner.defaultBreakVelocity, "width": width, "radius": radius, "surfaceY": Double(surface),
                   "pockets": AngleSceneCalculator.pocketPositions(surfaceY: surface).map { [Double($0.x), Double($0.z)] }])
while let line = readLine() {
    do {
        try autoreleasepool {
            let input = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let n = input["n"] as! Int, seed = UInt64(input["seed"] as! String)!
            let game: RackGame = n == 15 ? .chineseEightBall : (n == 9 ? .nineBall : .zhuifen(balls: n))
            InvarianceTrace.mode = input["mode"] as! Int
            FixedPhysicsResearch.variant=input["experiment"] as! String
            FixedPhysicsResearch.reset()
            let original = RackLayout.make(game, seed: seed)
            let mirror = input["mirror"] as! Bool
            let reverse = input["reverse"] as! Bool
            let canonical = original.balls.map { b -> RackBall in
                var p=b.position; if mirror { p.z = -p.z }
                return RackBall(key:b.key,number:b.number,position:p)
            }
            let ordered = (input["permutation"] as? [Int]).map { p in p.map{canonical[$0]} } ?? (reverse ? Array(canonical.reversed()):canonical)
            let rack = Rack(game:game,cue:original.cue,balls:ordered,surfaceY:original.surfaceY)
            let cue = SCNVector3(Float(input["x"] as! Double), surface + BallPhysics.radius, Float(input["z"] as! Double))
            let power = Float(input["power"] as! Double)
            let aim = BreakSimulator.aimAtApex(rack: rack, from: cue)
            let safe = AngleSceneCalculator.clampAwayFromPockets(cue, surfaceY: surface)
            let access = CueStrikeAccess(cue: cue, aim: aim, obstacles: rack.balls.map(\.position), surfaceY: surface, profile: profile)
            let pose = access.resolvedPose(spinX: 0, spinY: 0)
            var row: [String: Any] = ["input": input, "rack": rack.balls.map { ["number": $0.number, "x": Double($0.position.x), "z": Double($0.position.z)] },
                                      "cue": [Double(cue.x), Double(cue.z)], "power": Double(power),
                                      "direction": [Double(aim.x), Double(aim.z)], "spin": [0, 0], "simulatedElevation": 0]
            let initialStrike = CueBallStrike.executeStrike(aimDirection: aim, velocity: power, spinX: 0, spinY: 0)
            row["initialCueVelocity"] = vec(initialStrike.velocity)
            let validBox = cue.x >= TablePhysics.innerLength / 4 && cue.x <= TablePhysics.innerLength / 2 - BallPhysics.radius && abs(cue.z) <= TablePhysics.innerWidth / 2 - BallPhysics.radius
            if !validBox || (safe - cue).length() > 0.000001 || pose == nil {
                row["status"] = "invalid_input"
                row["reason"] = !validBox ? "outside_break_box" : ((safe - cue).length() > 0.000001 ? "pocket_clearance" : "cue_access")
            } else {
                row["accessElevation"] = Double(pose!.elevation)
                let start = DispatchTime.now().uptimeNanoseconds
                let cpuStart = cpuSeconds()
                InvarianceTrace.reset()
                let override = input["exactCueVelocity"] as! [Double]
                InvarianceTrace.cueVelocityOverride = SCNVector3(Float(override[0]),Float(override[1]),Float(override[2]))
                let result = BreakSimulator.breakShot(rack: rack, cuePosition: cue, aimDirection: aim,
                    power: power, spinX: 0, spinY: 0, maxEvents: 8000, maxTime: 30)
                row["initialCueVelocity"] = vec(InvarianceTrace.cueVelocityOverride!)
                row["rejectedPairs"] = InvarianceTrace.rejected
                row["pairTrace"] = InvarianceTrace.rows
                row["cushionTrace"] = FixedPhysicsResearch.cushionRows
                row["jointTrace"] = FixedPhysicsResearch.jointRows
                row["contactComponents"] = Dictionary(uniqueKeysWithValues:FixedPhysicsResearch.clusters.map{(String($0.key),$0.value)})
                row["researchFailures"] = FixedPhysicsResearch.failures
                row["parameters"] = FixedPhysicsResearch.parameters
                row["canonicalNames"] = canonical.map(\.key)
                row["seconds"] = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
                row["cpuSeconds"] = cpuSeconds() - cpuStart
                row["status"] = !FixedPhysicsResearch.failures.isEmpty ? "research_failed" : (result.settled ? "settled" : "incomplete")
                row["termination"] = String(describing: result.termination)
                row["pocketed"] = result.pocketed
                row["cueScratched"] = result.cueScratched
                row["duration"] = Double(result.recorder.duration)
                row["board"] = result.board.onTable.mapValues { [$0.x, $0.y] }
                let names = [PositionPlayBall.cueKey] + rack.balls.map(\.key)
                let rec = result.recorder
                let sounds = rec.contactSounds
                let t0 = sounds.first(where: { $0.surface == .ball })!.time
                let frames = names.map { rec.framesByBallName[$0]! }
                precondition(frames.allSatisfy { $0.count == frames[0].count })
                row["t0"] = Double(t0)
                row["names"] = names
                row["contacts"] = sounds.map { ["t": Double($0.time-t0), "a": $0.ball, "b": $0.other, "kind": $0.surface.rawValue, "approach": Double($0.approachSpeed)] as [String: Any] }
                var traces: [[String: Any]] = []
                for k in 1..<frames[0].count {
                    let t = frames[0][k].time
                    if t < t0 { continue }; if t > t0 + 0.02 { break }
                    var changed: [[String: Any]] = []
                    for i in names.indices {
                        let prev = frames[i][k-1], post = frames[i][k]
                        precondition(post.time == t)
                        let pre = evolved(prev, dt: t-prev.time)
                        let dv = post.velocity-pre.velocity
                        if dv.length() > 0.00001 {
                            changed.append(["slot": i-1, "p": vec(post.position), "preV": vec(pre.velocity), "postV": vec(post.velocity), "preW": vec3(pre.angularVelocity), "postW": vec3(post.angularVelocity)])
                        }
                    }
                    if !changed.isEmpty { traces.append(["frameIndex": k, "t": Double(t-t0), "changed": changed]) }
                }
                row["impulseTrace"] = traces
                var samples: [[String: Any]] = []
                for delay: Float in [0.001,0.005,0.02,0.05,0.1] {
                    let target = t0 + delay
                    let states = frames.map { list -> [String: Any] in
                        let prev = list.last(where: { $0.time <= target })!
                        let f = evolved(prev, dt: target-prev.time)
                        return ["p": vec(f.position), "v": vec(f.velocity), "w": vec3(f.angularVelocity), "state": f.state.rawValue]
                    }
                    samples.append(["delay": Double(delay), "states": states])
                }
                row["samples"] = samples
                let lastMoving = frames[0].indices.last { k in frames.contains { $0[k].state == .sliding || $0[k].state == .rolling } }
                let stopIndex = min((lastMoving ?? 0)+1,frames[0].count-1)
                let lastTranslation=frames[0][stopIndex].time
                row["lastTranslation"] = Double(lastTranslation)
                row["spinTail"] = names.indices.map { i -> [String:Any] in
                    let f=frames[i],at=f[stopIndex]
                    let end=f[stopIndex...].first(where:{$0.state == .stationary})?.time ?? at.time
                    let tail=at.state == .spinning && abs(at.angularVelocity.y)>0.0001 ? max(0,end-lastTranslation):0
                    return ["name":names[i],"tail":Double(tail),"wy":Double(at.angularVelocity.y),"peakWy":Double(f.map{abs($0.angularVelocity.y)}.max()!)]
                }
                row["firstContacts"] = rec.firstBallContacts.mapValues { c in ["time": Double(c.time-t0), "other": c.other.name, "incomingV": vec(c.incoming.velocity), "otherV": vec(c.other.velocity)] as [String: Any] }

            }
            try emit("RESULT", row)
        }
    } catch {
        try emit("ERROR", ["error": String(describing: error)])
        exit(1)
    }
}
