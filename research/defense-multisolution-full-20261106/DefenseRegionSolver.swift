import Foundation
import SceneKit

// Research-only specialization. Actual table pockets and all three balls remain physical.
struct DefenseRegionBlock {
    let id:Int, region:SolveRegion, centre:SIMD2<Double>, area:Double, cells:Int
}
struct DefenseRegionMap {
    let nx=50,nz=25
    let hx=Double(AngleSceneCalculator.innerLength/2-AngleSceneCalculator.ballRadius)
    let hz=Double(AngleSceneCalculator.innerWidth/2-AngleSceneCalculator.ballRadius)
    var scores=[Double](repeating:-1,count:50*25)
    var membership=[Int](repeating:-1,count:50*25)
    var blocks=[DefenseRegionBlock]()
    init(scan:[String:Any],threshold:Double) {
        let dx=2*hx/Double(nx),dz=2*hz/Double(nz)
        for row in scan["rows"] as! [[String:Any]] {
            guard let score=row["score"] as? Double else {continue}
            let b=row["bounds"] as! [Double]
            let x0=Int(((b[0]+hx)/dx).rounded()),x1=Int(((b[2]+hx)/dx).rounded())
            let z0=Int(((b[1]+hz)/dz).rounded()),z1=Int(((b[3]+hz)/dz).rounded())
            for z in z0..<z1 {for x in x0..<x1 {scores[z*nx+x]=score}}
        }
        let target=scan["target"] as! [Double]
        for k in scores.indices {
            let x = -hx+(Double(k%nx)+0.5)*dx,z = -hz+(Double(k/nx)+0.5)*dz
            if hypot(x-target[0],z-target[1])<0.30 {scores[k] = -1}
        }
        for start in scores.indices where scores[start]>=threshold && membership[start]<0 {
            // Full connected score region; width is not limited by artificial tile seams.
            let id=blocks.count
            var queue=[start],cursor=0;membership[start]=id
            while cursor<queue.count {
                let k=queue[cursor];cursor+=1;let x=k%nx,z=k/nx
                for (xx,zz) in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)] {
                    guard (0..<nx).contains(xx),(0..<nz).contains(zz) else{continue}
                    let j=zz*nx+xx
                    if membership[j]<0 && scores[j]>=threshold {membership[j]=id;queue.append(j)}
                }
            }
            let polygons:[[SIMD2<Double>]]=queue.map { k in
                let x = -hx+Double(k%nx)*dx,z = -hz+Double(k/nx)*dz
                return [SIMD2(x,z),SIMD2(x+dx,z),SIMD2(x+dx,z+dz),SIMD2(x,z+dz)]
            }
            let mesh=SampledSolveRegion(polygons:polygons)!
            let region=SolveRegion.sampled(mesh)
            let centres=queue.map{SIMD2(-hx+(Double($0%nx)+0.5)*dx,-hz+(Double($0/nx)+0.5)*dz)}
            let centre=centres.min {mesh.signedDistance($0)<mesh.signedDistance($1)}!
            blocks.append(.init(id:id,region:region,centre:centre,area:Double(queue.count)*dx*dz,cells:queue.count))
        }
    }
    func block(at p:SCNVector3)->Int? {
        let x=Int(floor((Double(p.x)+hx)/(2*hx)*Double(nx))),z=Int(floor((Double(p.z)+hz)/(2*hz)*Double(nz)))
        guard (0..<nx).contains(x),(0..<nz).contains(z),membership[z*nx+x]>=0 else{return nil}
        return membership[z*nx+x]
    }
    var json:[[String:Any]] {blocks.map{b in
        let shape: [[SIMD2<Double>]];if case let .sampled(m)=b.region {shape=m.boundaryLoops}else{shape=[]}
        return ["id":b.id,"area":b.area,"sample":[b.centre.x,b.centre.y],"cells":b.cells,"sampledCoreRadius":-Double(b.region.signedDistanceMeters(fromScene:SCNVector3(Float(b.centre.x),BTTablePhysics.surfaceY+BallPhysics.radius,Float(b.centre.y)),surfaceY:BTTablePhysics.surfaceY)),
                "loops":shape.map{$0.map{[$0.x,$0.y]}}]
    }}
}
struct DefenseRegionStroke {
    let cut:Int,side:Int,angle:Double,speed:Double,spinX:Double,spinY:Double
    var direction:SCNVector3 {SCNVector3(Float(cos(angle)),0,Float(sin(angle)))}
    var key:String {"\(cut):\(side):\(speed):\(spinX):\(spinY)"}
    var json:[String:Any] {["cutDegrees":cut,"side":side,"angle":angle,"speed":speed,"spinX":spinX,"spinY":spinY,"direction":[Double(direction.x),Double(direction.z)]]}
}
struct DefenseRegionCandidate {
    let stroke:DefenseRegionStroke,prediction:ShotPrediction,block:Int,base:DefenseEffect,effect:DefenseEffect,measuredCut:Double
    let margin:Double
    let own:OwnPotential
}
func defensePoint(_ p:SCNVector3)->[Double] {[Double(p.x),Double(p.z)]}
func defenseDistance(_ a:SCNVector3,_ b:SCNVector3)->Double {hypot(Double(a.x-b.x),Double(a.z-b.z))}
func defenseEncode<T:Encodable>(_ v:T)throws->Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(v))}

extension PositionPlaySolver {
 static func solveDefenseResearch(question q:DefenseBankQuestion,map:DefenseRegionMap,profile:[CueSection],output:URL) throws -> [String:Any] {
    let started=ProcessInfo.processInfo.systemUptime,surface=BTTablePhysics.surfaceY,r=Double(BallPhysics.radius),cueKey=ShotInput.cueBallName
    func vec(_ p:[Double])->SCNVector3 {SCNVector3(Float(p[0]),surface+BallPhysics.radius,Float(p[1]))}
    let ownKey="_\(q.ownBallNumber)",enemyKey="_\(q.opponentBallNumber)"
    let fixedKeys=q.keys.filter{$0 != ownKey}
    let cue=vec(q.cue),own=vec(q.balls.first{$0.number==q.ownBallNumber}!.position),enemy=vec(q.balls.first{$0.number==q.opponentBallNumber}!.position)
    let fixedPositions=Dictionary(uniqueKeysWithValues:q.balls.filter{$0.number != q.ownBallNumber}.map{("_\($0.number)",vec($0.position))})
    let staticBlockers=fixedKeys.filter{$0 != enemyKey}.map{fixedPositions[$0]!}
    let ownBlockers=fixedKeys.map{fixedPositions[$0]!}
    let balls=q.balls.map{ObstacleBall(name:"_\($0.number)",position:vec($0.position))}
    let d=defenseDistance(cue,own),baseAngle=atan2(Double(own.z-cue.z),Double(own.x-cue.x))
    let params=SearchParams.standard
    var windows=DefenseAttackAssessment();for i in 0..<6 {_=windows.window(.init(Double(enemy.x),Double(enemy.z)),i)}
    var counts=[String:Int](),visited=Set<String>(),dedup=[String:DefenseRegionCandidate]()
    var ownEvaluator=OwnPotentialEvaluator()
    let ownBefore=ownEvaluator.evaluate(own,blockers:ownBlockers)
    var probeCache=[String:[[String:Any]]]()
    var tiers=[[String:Any]]()
    var seeds=[String:(Double,DefenseRegionStroke)]()
    var blockingSeeds=[String:(Double,DefenseRegionStroke)]()
    let sampleBlocks=Array(map.blocks.sorted{$0.area>$1.area}.prefix(12))
    func fail(_ reason:String) {counts[reason,default:0]+=1}
    func stroke(_ cut:Int,_ side:Int,_ speed:Double,_ sx:Double,_ sy:Double)->DefenseRegionStroke {
        let desired=baseAngle+Double(side)*asin(2*r*sin(Double(cut)*Double.pi/180)/d)
        let v=CueBallStrike.executeStrike(aimDirection:SCNVector3(Float(cos(desired)),0,Float(sin(desired))),velocity:Float(speed),spinX:Float(sx),spinY:Float(sy),elevation:0).velocity
        let delta=atan2(Double(v.z),Double(v.x))-desired
        return .init(cut:cut,side:side,angle:desired-atan2(sin(delta),cos(delta)),speed:speed,spinX:sx,spinY:sy)
    }
    func simulate(_ s:DefenseRegionStroke,_ presentation:Bool=false)->ShotPrediction {
        ShotPredictor.simulateFree(cueBall:cue,aimDir:s.direction,velocity:Float(s.speed),spinX:Float(s.spinX),spinY:Float(s.spinY),surfaceY:surface,balls:balls,maxEvents:1500,maxTime:60,includePresentation:presentation,recordedStrikeDirection:s.direction)
    }
    func invalid(_ p:ShotPrediction)->String? {
        if !p.hasFinalTableState {return "incomplete"}
        guard let end=p.finalPositions[cueKey],defenseDistance(end,enemy)>=0.30 else{return "cue-opponent-under-30cm"}
        if let reason=DefenseEffect.failure(q,p) {return reason}
        if !p.pocketedBalls.isEmpty{return "any-ball-potted"}
        if p.events.contains(where:{if case let .ballBall(a,b)=$0.kind{return fixedKeys.contains(a) || fixedKeys.contains(b)};return false}) {return "opponent-contact"}
        for key in fixedKeys {guard let e=p.finalPositions[key],defenseDistance(e,fixedPositions[key]!)<1e-6 else{return "fixed-ball-moved"}}
        if p.events.contains(where:{if case .ballCushion=$0.kind{return !DefenseReferenceRoute.isMainCushion($0.cushionIndex)};return false}) {return "pocket-jaw-contact"}
        var ownHitRail=false,firstContact=false
        for event in p.events {
            if case let .ballCushion(b)=event.kind,b==ownKey,firstContact {ownHitRail=true}
            if case .ballBall=event.kind {if ownHitRail{return "own-rail-cue-recontact"};firstContact=true}
        }
        for (i,k) in ([cueKey]+q.keys).enumerated() {
            guard let v=p.finalPositions[k],v.x.isFinite,v.z.isFinite else{return "bad-final"}
            for k2 in ([cueKey]+q.keys).dropFirst(i+1) {guard let v2=p.finalPositions[k2],defenseDistance(v,v2)>=2*r-1e-5 else{return "overlap"}}
        }
        return nil
    }
    func cutAngle(_ p:ShotPrediction)->Double? {
        guard let event=p.events.first(where:{if case .ballBall=$0.kind{return true};return false}),
              let frames=p.recorder?.framesByBallName[cueKey],
              let hit=frames.first(where:{$0.time>=event.time-1e-6}),
              let before=frames.last(where:{$0.time<event.time-1e-6}) else{return nil}
        let normal=own-hit.position,vel=before.velocity
        let len=hypot(Double(normal.x),Double(normal.z))*hypot(Double(vel.x),Double(vel.z))
        guard len>1e-10 else{return nil}
        return acos(max(-1,min(1,(Double(normal.x)*Double(vel.x)+Double(normal.z)*Double(vel.z))/len)))*180/Double.pi
    }
    func signature(_ p:ShotPrediction,_ block:Int)->String {
        let events=p.events.map {event->String in
            switch event.kind {
            case let .ballBall(a,b):return "B:"+[a,b].sorted().joined(separator:",")
            case let .ballCushion(b):return "C:\(b):\(event.cushionIndex ?? -1)"
            case let .pocket(b,k):return "P:\(b):\(k)"
            }
        }.joined(separator:"/")
        let c=p.finalPositions[cueKey]!,b=p.finalPositions[ownKey]!
        return "\(block)|\(events)|\(Int(floor(Double(c.x)/0.08))):\(Int(floor(Double(c.z)/0.08)))|\(Int(floor(Double(b.x)/0.1))):\(Int(floor(Double(b.z)/0.1)))"
    }
    func evaluate(_ s:DefenseRegionStroke)throws {
        guard visited.insert(s.key).inserted else{return}
        counts["parameters",default:0]+=1
        let access=CueStrikeAccess(cue:cue,aim:s.direction,obstacles:balls.map(\.position),surfaceY:surface,profile:profile)
        guard access.isAvailable(spinX:s.spinX,spinY:s.spinY),(access.resolvedPose(spinX:s.spinX,spinY:s.spinY)?.elevation ?? 100)<=CueStick.minElevationRadians+1e-6 else{fail("cue-access");return}
        let p=autoreleasepool{simulate(s)};counts["physics",default:0]+=1
        if let reason=invalid(p){fail(reason);return}
        guard let measured=cutAngle(p),abs(measured-Double(s.cut))<=0.5 else{fail("cut-angle-outside-0.5deg");return}
        let stop=p.finalPositions[cueKey]!
        for block in sampleBlocks {
            let distance=Double(block.region.signedDistanceMeters(fromScene:stop,surfaceY:surface))
            let key="\(block.id):\(s.cut):\(s.side):\(s.spinX)"
            if seeds[key]==nil || distance<seeds[key]!.0 {seeds[key]=(distance,s)}
        }
        // Both pathways share a candidate pool. Never reject before considering moved 8.
        let block=map.block(at:stop) ?? -1
        let base=try DefenseEffect.regionState(cue:stop,target:enemy,blockers:staticBlockers,windows:windows,opponent:q.opponentBallNumber)
        let effect=try DefenseEffect.regionState(cue:stop,target:enemy,blockers:staticBlockers+[p.finalPositions[ownKey]!],windows:windows,opponent:q.opponentBallNumber)
        guard let total=effect.score else {throw NSError(domain:"missing-terminal-score",code:1)}
        // Seed 8-to-cue/9-line proximity separately from intrinsic difficult regions.
        let o=p.finalPositions[ownKey]!,vx=Double(enemy.x-stop.x),vz=Double(enemy.z-stop.z)
        let t=max(0,min(1,(Double(o.x-stop.x)*vx+Double(o.z-stop.z)*vz)/(vx*vx+vz*vz)))
        let lineGap=hypot(Double(o.x-stop.x)-t*vx,Double(o.z-stop.z)-t*vz)-2*r
        let sk="\(s.cut):\(s.side):\(s.spinX):\(s.spinY)"
        for (suffix,objective) in [("line",lineGap),("score",-total)] {
            let k=sk+suffix
            if blockingSeeds[k]==nil || objective<blockingSeeds[k]!.0 {blockingSeeds[k]=(objective,s)}
        }
        guard total>=80 else {fail("final-below-80");return}
        let margin=block>=0 ? -Double(map.blocks[block].region.signedDistanceMeters(fromScene:stop,surfaceY:surface)) : 0
        let potential=ownEvaluator.evaluate(p.finalPositions[ownKey]!,blockers:ownBlockers)
        let candidate=DefenseRegionCandidate(stroke:s,prediction:p,block:block,base:base,effect:effect,measuredCut:measured,margin:margin,own:potential)
        counts["qualifiedBeforeDedup",default:0]+=1
        let key=signature(p,block)+"|band:\(Int(total/10))|block:\(effect.fullDirectBlock || effect.potContactsBlocked==true)"
        if dedup[key]==nil || qualityLess(candidate,dedup[key]!) {dedup[key]=candidate}
    }
    func effort(_ c:DefenseRegionCandidate)->Double {
        DifficultyModel.executionEffort(spinX:c.stroke.spinX,spinY:c.stroke.spinY,velocity:c.stroke.speed)
    }
    func qualityLess(_ a:DefenseRegionCandidate,_ b:DefenseRegionCandidate)->Bool {
        if a.own.preserves(ownBefore) != b.own.preserves(ownBefore) {return a.own.preserves(ownBefore)}
        if effort(a) != effort(b) {return effort(a)<effort(b)}
        if a.stroke.speed != b.stroke.speed {return a.stroke.speed<b.stroke.speed}
        let ac=a.prediction.events.filter{if case .ballCushion=$0.kind{return true};return false}.count
        let bc=b.prediction.events.filter{if case .ballCushion=$0.kind{return true};return false}.count
        if ac != bc {return ac<bc}
        if a.margin != b.margin {return a.margin>b.margin}
        return a.stroke.key < b.stroke.key
    }
    func probes(_ c:DefenseRegionCandidate) throws -> [[String:Any]] {
        if let cached=probeCache[c.stroke.key] {return cached}
        var result=[[String:Any]]()
        for (da,factor) in [(-0.1,1.0),(0.1,1.0),(0.0,0.95),(0.0,1.05)] {
            let s=DefenseRegionStroke(cut:c.stroke.cut,side:c.stroke.side,angle:c.stroke.angle+da*Double.pi/180,speed:c.stroke.speed*factor,spinX:c.stroke.spinX,spinY:c.stroke.spinY)
            var rec:[String:Any]=["angleDelta":da,"speedScale":factor,"passes":false,"defensePasses":false]
            let access=CueStrikeAccess(cue:cue,aim:s.direction,obstacles:balls.map(\.position),surfaceY:surface,profile:profile)
            guard access.isAvailable(spinX:s.spinX,spinY:s.spinY),(access.resolvedPose(spinX:s.spinX,spinY:s.spinY)?.elevation ?? 100)<=CueStick.minElevationRadians+1e-6 else {
                rec["reason"]="cue-access";result.append(rec);continue
            }
            let pp=simulate(s)
            if let reason=invalid(pp) {rec["reason"]=reason}
            else {
                let end=pp.finalPositions[cueKey]!
                let e=try DefenseEffect.regionState(cue:end,target:enemy,blockers:staticBlockers+[pp.finalPositions[ownKey]!],windows:windows,opponent:q.opponentBallNumber)
                let b=try DefenseEffect.regionState(cue:end,target:enemy,blockers:staticBlockers,windows:windows,opponent:q.opponentBallNumber)
                let potential=ownEvaluator.evaluate(pp.finalPositions[ownKey]!,blockers:ownBlockers)
                let good=e.score!>=80
                rec["score"]=e.score!;rec["baseScore"]=b.score!;rec["defensePasses"]=good
                rec["effect"]=try defenseEncode(e);rec["baseEffect"]=try defenseEncode(b)
                rec["own"]=potential.json;rec["ownPreserved"]=potential.preserves(ownBefore)
                rec["passes"]=good && potential.preserves(ownBefore)
                rec["finalPositions"]=pp.finalPositions.mapValues{defensePoint($0)}
                rec["physicalVerified"]=true
                rec["events"]=pp.events.map {ev->[String:Any] in
                    switch ev.kind {
                    case let .ballBall(a,b):return ["kind":"ballBall","balls":[a,b],"time":Double(ev.time)]
                    case let .ballCushion(b):return ["kind":"cushion","ball":b,"index":ev.cushionIndex ?? -1,"time":Double(ev.time)]
                    case let .pocket(b,k):return ["kind":"pocket","ball":b,"pocket":k,"time":Double(ev.time)]
                    }
                }
            }
            result.append(rec)
        }
        probeCache[c.stroke.key]=result;return result
    }
    func stableAt(_ c:DefenseRegionCandidate,_ threshold:Double)->Bool {
        c.effect.score!>=threshold && c.own.preserves(ownBefore) &&
        probeCache[c.stroke.key]?.filter{($0["score"] as? Double ?? -1)>=threshold && ($0["ownPreserved"] as? Bool ?? false)}.count==4
    }
    func pathway(_ c:DefenseRegionCandidate,_ threshold:Double)->String {
        c.base.score!>=threshold ? "intrinsic" : "blocking-added"
    }
    func topology(_ c:DefenseRegionCandidate)->[String] {c.prediction.events.map {e in
        switch e.kind {
        case let .ballBall(a,b):return "B:"+[a,b].sorted().joined(separator:",")
        case let .ballCushion(b):return "C:\(b):\(e.cushionIndex ?? -1)"
        case let .pocket(b,k):return "P:\(b):\(k)"
        }
    }}
    func different(_ a:DefenseRegionCandidate,_ b:DefenseRegionCandidate)->Bool {
        topology(a) != topology(b) || defenseDistance(a.prediction.finalPositions[cueKey]!,b.prediction.finalPositions[cueKey]!)>=0.08 || defenseDistance(a.prediction.finalPositions[ownKey]!,b.prediction.finalPositions[ownKey]!)>=0.10
    }
    func diverse(_ pool:[DefenseRegionCandidate])->[DefenseRegionCandidate] {
        var chosen=[DefenseRegionCandidate]()
        for c in pool.sorted(by:qualityLess) where chosen.allSatisfy({different(c,$0)}) {
            chosen.append(c);if chosen.count==6 {break}
        };return chosen
    }
    // Expand only while fewer than two distinct four-probe 80-point solutions exist.
    // All thresholds are evaluated on exactly the same final parameter pool.
    let spinTiers:[[(Double,Double)]]=[[(0,0)],[(0,-0.2),(0,0.2)],[(0,-0.4),(0,0.4)],
        [(-0.3,0),(0.3,0),(-0.3,-0.2),(-0.3,0.2),(0.3,-0.2),(0.3,0.2),(-0.3,-0.4),(-0.3,0.4),(0.3,-0.4),(0.3,0.4)]]
    for (tier,spins) in spinTiers.enumerated() {
        for (sx,sy) in spins {for cut in [15,30,45,60] {for side in [-1,1] {
            for i in 0...Int(((params.velocityMax-params.velocityMin)/params.velocityStep).rounded()) {
                try evaluate(stroke(cut,side,params.velocityMin+Double(i)*params.velocityStep,sx,sy))
            }
        }}}
        let regionStarts=seeds.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(24).map{$0.1}
        // Distances and scores have different units; rank the two seed objectives separately.
        let blockStarts=["line","score"].flatMap { kind in
            blockingSeeds.filter{$0.key.hasSuffix(kind)}.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(12).map{$0.1}
        }
        let starts=regionStarts+blockStarts
        for seed in starts {for step in [params.velocityStep/4,params.velocityStep/16] {for offset in [-2.0,-1,0,1,2] {
            let v=seed.speed+offset*step
            if v>=params.velocityMin && v<=params.velocityMax {try evaluate(stroke(seed.cut,seed.side,v,seed.spinX,seed.spinY))}
        }}}
        // Bounded validation shortlist: simple execution with preserved own potential,
        // not specific spins, cushions, angle bins or twelve-per-case targets.
        let eligible=dedup.values.filter{$0.own.preserves(ownBefore)}
        var shortlist=[DefenseRegionCandidate]()
        for threshold in [80.0,85] {for path in ["intrinsic","blocking-added"] {
            let group=eligible.filter{$0.effect.score!>=threshold && pathway($0,threshold)==path}
            let easy=group.sorted(by:qualityLess).prefix(24)
            for c in easy where !shortlist.contains(where:{$0.stroke.key==c.stroke.key}) {shortlist.append(c)}
        }}
        for c in shortlist {_=try probes(c)}
        let stable=diverse(dedup.values.filter{stableAt($0,80)}).count
        tiers.append(["tier":tier,"spins":spins.map{[$0.0,$0.1]},"parameters":visited.count,"deduplicated":dedup.count,"preservingCandidates":eligible.count,"stableJointCandidates":stable,"probeCandidates":probeCache.count])
        print("TIER \(q.sampleID) \(tier) candidates=\(dedup.count) preserving=\(eligible.count) stable=\(stable)");fflush(stdout)
        if stable>=2 {break}
    }
    let eligible=dedup.values.filter{stableAt($0,80)}
    let selected=diverse(Array(eligible));var thresholdResults=[[String:Any]]()
    for threshold in [80.0,85] {
        let qualified=dedup.values.filter{$0.effect.score!>=threshold}
        let stable=qualified.filter{stableAt($0,threshold)}
        var paths=[String:Int]()
        for path in ["intrinsic","blocking-added"] {
            let group=stable.filter{pathway($0,threshold)==path}
            paths[path]=group.count
        }
        thresholdResults.append(["threshold":threshold,"nominal":qualified.count,"preservesOwn":qualified.filter{$0.own.preserves(ownBefore)}.count,"robust":stable.count,"paths":paths])
    }
    let summaries=dedup.values.sorted(by:qualityLess).map {c -> [String:Any] in
        var row:[String:Any]=["shot":c.stroke.json,"block":c.block,"finalPositions":c.prediction.finalPositions.mapValues{defensePoint($0)},"defenseScore":c.effect.score!,"baseScore":c.base.score!,"effect":try! defenseEncode(c.effect),"baseEffect":try! defenseEncode(c.base),"stableThresholds":[80.0,85].filter{stableAt(c,$0)},"own":c.own.json,"ownPreserved":c.own.preserves(ownBefore),"effort":effort(c)]
        if let p=probeCache[c.stroke.key] {row["probes"]=p;row["jointPasses"]=p.filter{$0["passes"] as! Bool}.count}
        return row
    }
    try JSONSerialization.data(withJSONObject:summaries,options:[.sortedKeys]).write(to:output.appendingPathComponent("candidate-metrics.json"))
    var records=[[String:Any]]()
    for (i,c) in selected.enumerated() {
        let p=simulate(c.stroke,true)
        guard invalid(p)==nil,let stop=p.finalPositions[cueKey],(map.block(at:stop) ?? -1)==c.block else{throw NSError(domain:"final-replay-failed",code:i)}
        guard defenseDistance(stop,c.prediction.finalPositions[cueKey]!)<1e-5,defenseDistance(p.finalPositions[ownKey]!,c.prediction.finalPositions[ownKey]!)<1e-5 else{throw NSError(domain:"replay-drift",code:i)}
        let final=try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:false)
        guard let score=final.score,score>=80,abs(score-c.effect.score!)<1e-7 else{throw NSError(domain:"production-score-parity",code:i)}
        let checkedProbes=try probes(c)
        let ownFinal=ownEvaluator.evaluate(p.finalPositions[ownKey]!,blockers:ownBlockers)
        precondition(ownFinal.preserves(ownBefore) && checkedProbes.allSatisfy{$0["passes"] as! Bool})
        let paths=p.recorder!.framesByBallName.mapValues{$0.map{[Double($0.time),Double($0.position.x),Double($0.position.z)]}}
        let ev=p.events.map {e->[String:Any] in
            switch e.kind {
            case let .ballBall(a,b):return ["time":Double(e.time),"kind":"ballBall","balls":[a,b]]
            case let .ballCushion(b):return ["time":Double(e.time),"kind":"cushion","ball":b,"index":e.cushionIndex ?? -1]
            case let .pocket(b,k):return ["time":Double(e.time),"kind":"pocket","ball":b,"pocket":k]
            }
        }
        let end=stop,target=enemy
        var tags=[String]();if defenseDistance(end,target)>=1.2 {tags.append("长台")}
        if let route=final.pipeRoute {
            let aim=route.aim,u=SIMD2(aim[0]-Double(target.x),aim[1]-Double(target.z));let length=sqrt(u.x*u.x+u.y*u.y)
            let n=u/length,ghost=SIMD2(Double(target.x),Double(target.z))-n*(2*r),v=ghost-SIMD2(Double(end.x),Double(end.z))
            let cut=acos(max(-1,min(1,(v.x*n.x+v.y*n.y)/sqrt(v.x*v.x+v.y*v.y))))*180/Double.pi
            if cut>=45 {tags.append("大角度")}
        }
        if min(Double(AngleSceneCalculator.innerLength/2)-abs(Double(end.x)),Double(AngleSceneCalculator.innerWidth/2)-abs(Double(end.z)))-r<0.08 {tags.append("母球近库")}
        if final.fullDirectBlock || final.potContactsBlocked==true {tags.append("线路封锁")}
        records.append(["id":i+1,"stableThresholds":[80.0,85].filter{stableAt(c,$0)},"block":c.block,"shot":c.stroke.json,"measuredCutDegrees":c.measuredCut,"baseScore":c.base.score!,"effect":try defenseEncode(final),"regionMarginMeters":c.margin,"finalPositions":p.finalPositions.mapValues{defensePoint($0)},"events":ev,"tracks":paths,"tags":tags,"probes":checkedProbes,"probePasses":checkedProbes.filter{$0["passes"] as! Bool}.count,"ownBefore":ownBefore.json,"ownAfter":ownFinal.json,"ownPreserved":true,"effort":effort(c),"replayVerified":true,"signature":signature(p,c.block)])
    }
    return ["questionID":q.id,"ownBallNumber":q.ownBallNumber,"opponentBallNumber":q.opponentBallNumber,"admitted":records.count>=2,"ownBefore":ownBefore.json,"tiers":tiers,"stableJointCandidates":eligible.count,"thresholdResults":thresholdResults,"probedCandidates":probeCache.count,"counts":counts,"deduplicatedCount":dedup.count,"retainedCount":records.count,"routes":records,"seconds":ProcessInfo.processInfo.systemUptime-started,"scope":"Research specialization of PositionPlaySolver; actual pockets unchanged, no target ball removal; bounded search, no solution is not proof of impossibility."]
 }
}
