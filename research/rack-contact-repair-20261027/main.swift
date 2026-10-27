import Foundation
import SceneKit
import Darwin
func cpuSeconds() -> Double {
    var t = timespec(); clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t)
    return Double(t.tv_sec) + Double(t.tv_nsec) / 1e9
}

// Research entry only. All rack/strike/collision/pocket/settlement code is production code.
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

let probe=repairProbe()
let profile = AccuracyTipSelector.renderedProfile()
let length = Double(TablePhysics.innerLength), width = Double(TablePhysics.innerWidth)
let radius = Double(BallPhysics.radius), surface = BTTablePhysics.surfaceY
try emit("READY", ["pid": ProcessInfo.processInfo.processIdentifier, "probe":probe,"length": length,
                   "defaultBreakVelocity": BreakFlowRunner.defaultBreakVelocity, "width": width, "radius": radius, "surfaceY": Double(surface),
                   "pockets": AngleSceneCalculator.pocketPositions(surfaceY: surface).map { [Double($0.x), Double($0.z)] }])
while let line = readLine() {
    do {
        try autoreleasepool {
            let backendLabel="repair"
            let input = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let n = input["n"] as! Int, seed = UInt64(input["seed"] as! String)!
            let game: RackGame = n == 15 ? .chineseEightBall : (n == 9 ? .nineBall : .zhuifen(balls: n))
            ContactToleranceResearch.value = Float(input["toleranceM"] as! Double)
            InvarianceTrace.mode = input["mode"] as! Int
            let originalRack=RackLayout.make(game,seed:seed)
            let mirror=input["mirror"] as! Bool,reverse=input["reverse"] as! Bool
            let canonical=originalRack.balls.map { b -> RackBall in
                var p=b.position;if mirror {p.z = -p.z}
                return RackBall(key:b.key,number:b.number,position:p)
            }
            let ordered=(input["permutation"] as? [Int]).map {p in p.map{canonical[$0]}} ?? (reverse ? Array(canonical.reversed()):canonical)
            let rack=Rack(game:game,cue:originalRack.cue,balls:ordered,surfaceY:originalRack.surfaceY)
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
                ForensicTrace.rows=[]
                InvarianceTrace.reset()
                StudyPrediction.rows=[];StudyPrediction.enabled=input["diagnostic"] as? Bool ?? false
                let override=input["exactCueVelocity"] as? [Double] ?? vec(initialStrike.velocity)
                InvarianceTrace.cueVelocityOverride=SCNVector3(Float(override[0]),Float(override[1]),Float(override[2]))
                row["initialCueVelocity"]=vec(InvarianceTrace.cueVelocityOverride!)
                let result = BreakSimulator.breakShot(rack: rack, cuePosition: cue, aimDirection: aim,
                    power: power, spinX: 0, spinY: 0, maxEvents: 8000, maxTime: 30)
                row["seconds"] = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
                row["cpuSeconds"] = cpuSeconds() - cpuStart
                row["status"] = result.settled ? "settled" : "incomplete"
                row["termination"] = String(describing: result.termination)
                row["pocketed"] = result.pocketed
                row["cueScratched"] = result.cueScratched
                row["duration"] = Double(result.recorder.duration)
                row["parameters"] = ["ballRadius":Double(BallPhysics.radius),"ballMass":Double(BallPhysics.mass),"ballRestitution":Double(BallPhysics.restitution),"cushionRestitution":Double(TablePhysics.cushionRestitution),"cushionFriction":Double(TablePhysics.cushionFriction),"cushionHeight":Double(TablePhysics.cushionHeight),"slidingFriction":Double(SpinPhysics.slidingFriction),"rollingFriction":Double(SpinPhysics.rollingFriction),"spinFriction":Double(SpinPhysics.spinFriction),"gravity":Double(TablePhysics.gravity),"rackGap":Double(RackLayout.gap),"jitterRadius":Double(RackLayout.jitterRadius)]
                row["eventTrace"] = ForensicTrace.rows
                row["rejectedPairs"] = InvarianceTrace.rejected
                row["predictions"] = StudyPrediction.rows
                row["canonicalNames"] = canonical.map(\.key)
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
                row["frameCount"] = frames[0].count
                row["toleranceM"] = Double(ContactToleranceResearch.value)
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
                var samples: [[String:Any]]=[]
                for delay:Float in [0.001,0.005,0.02,0.1] {
                    let target=t0+delay
                    samples.append(["delay":Double(delay),"states":frames.map { list -> [String:Any] in
                        let prev=list.last(where:{$0.time<=target})!
                        let f=evolved(prev,dt:target-prev.time)
                        return ["p":vec(f.position),"v":vec(f.velocity),"w":vec3(f.angularVelocity),"state":f.state.rawValue]
                    }])
                }
                row["samples"]=samples
                var worstOverlap:Double=0
                var overlapFrames=0
                for k in frames[0].indices {
                    var hasOverlap=false
                    for i in names.indices where frames[i][k].state != .pocketed {
                        for j in names.indices where j>i && frames[j][k].state != .pocketed {
                            let a=frames[i][k].position,b=frames[j][k].position
                            let dx=Double(a.x)-Double(b.x),dz=Double(a.z)-Double(b.z)
                            let overlap=2*radius-sqrt(dx*dx+dz*dz)
                            worstOverlap=max(worstOverlap,overlap)
                            if overlap>0.00001 {hasOverlap=true}
                        }
                    }
                    if hasOverlap {overlapFrames+=1}
                }
                row["overlapAudit"]=["maxM":worstOverlap,"framesOver10um":Double(overlapFrames)]
                if [11304,11331].contains(input["rackID"] as! Int) {
                row["frames"] = frames.map { list in list.map { f -> [String: Any] in
                    ["t":Double(f.time),"p":vec(f.position),"v":vec(f.velocity),"w":vec3(f.angularVelocity),"state":f.state.rawValue]
                } }
                }
                let playback = TrajectoryPlayback(recorder:rec, surfaceY:surface)
                row["playbackEnd"] = names.map { name -> [String:Any] in
                    let state = playback.stateAt(ballName:name,time:rec.duration+1)!
                    return ["name":name,"v":vec(state.velocity),"w":vec(state.angularVelocity),"state":state.motionState.rawValue]
                }

            }
            row["backend"]=backendLabel
            try emit("RESULT", row)
        }
    } catch {
        try emit("ERROR", ["error": String(describing: error)])
        exit(1)
    }
}
