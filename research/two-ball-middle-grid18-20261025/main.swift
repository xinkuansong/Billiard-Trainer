import Foundation
import SceneKit
// Research-only harness. App physics sources are not modified.

// The same event-constrained RDP / ordered-backtracking rule tested on the 95 paths.
func compactTrajectory(_ line:[SeparationTrajectory.Point], prediction:ShotPrediction) throws -> [String:Any] {
    guard !line.isEmpty else { throw NSError(domain:"empty-trajectory",code:1) }
    let pts = line.map {SIMD2<Double>(Double($0.position.x),Double($0.position.z))}
    func distance(_ a:SIMD2<Double>,_ b:SIMD2<Double>)->Double {hypot(a.x-b.x,a.y-b.y)}
    func segment(_ p:SIMD2<Double>,_ a:SIMD2<Double>,_ b:SIMD2<Double>)->(Double,Double) {
        let d=b-a, ll=d.x*d.x+d.y*d.y
        let u=ll>0 ? ((p.x-a.x)*d.x+(p.y-a.y)*d.y)/ll : 0
        return (distance(p,a+d*max(0,min(1,u))),u)
    }
    let anchors=Set([0,line.count-1]+line.indices.filter{line[$0].isEvent == true}).sorted()
    var keep=Set(anchors)
    let tolerance=0.002
    func simplify(_ a:Int,_ b:Int) {
        if b<=a+1{return}
        var err = -1.0, index=a+1
        for i in (a+1)..<b {
            let d=segment(pts[i],pts[a],pts[b]).0
            if d>=err {err=d;index=i}
        }
        var maxu=0.0,maxi=a
        let chord=distance(pts[a],pts[b])
        for i in (a+1)..<b {
            let u=segment(pts[i],pts[a],pts[b]).1
            if (maxu-u)*chord>tolerance && maxi>a && maxi<b {index=maxi;err=max(err,tolerance*2);break}
            if u>maxu {maxu=u;maxi=i}
        }
        if err>tolerance {keep.insert(index);simplify(a,index);simplify(index,b)}
    }
    for (a,b) in zip(anchors,anchors.dropFirst()) {simplify(a,b)}
    let indices=keep.sorted()
    var maxError=0.0
    for (a,b) in zip(indices,indices.dropFirst()) {
        for i in a...b {maxError=max(maxError,segment(pts[i],pts[a],pts[b]).0)}
    }
    guard maxError<=tolerance+1e-12,
          let end=prediction.finalPositions[ShotInput.cueBallName],
          distance(pts.last!,SIMD2(Double(end.x),Double(end.z)))<0.000001 else {
        throw NSError(domain:"compression-audit",code:2)
    }
    let contact=prediction.recorder!.firstBallContacts[ShotInput.cueBallName]!.time
    var cushionPoints:[[String:Any]]=[]
    for e in prediction.events {
        guard case .ballCushion(let ball)=e.kind,ball==ShotInput.cueBallName,e.time>=contact else {continue}
        let relative=e.time-contact
        let k=indices.indices.min{abs(line[indices[$0]].time-relative)<abs(line[indices[$1]].time-relative)}!
        guard abs(line[indices[k]].time-relative)<0.000002 else {throw NSError(domain:"event-anchor",code:3)}
        cushionPoints.append(["pointIndex":k,"time":Double(e.time),"cushionID":e.cushionIndex as Any? ?? NSNull()])
    }
    return ["schema":"cue-post-contact-rdp2mm-v1","toleranceMeters":tolerance,
            "coordinateUnit":"meter-XZ","timeOrigin":"firstTargetContact",
            "points":indices.map{[Double(line[$0].time),pts[$0].x,pts[$0].y]},
            "mandatoryPointIndices":indices.indices.filter{anchors.contains(indices[$0])},
            "sourcePointIndices":indices,"cushions":cushionPoints,
            "sourcePointCount":line.count,"maxDeviationMeters":maxError]
}

final class StrikeGridWorker {
    let profile = AccuracyTipSelector.renderedProfile()
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/two-ball-strike-pilot-20261024")
    func xy(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
    func write(_ name: String, _ value: Any) throws { try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic) }
    func directRoute(_ p: ShotPrediction, pocket: Int) -> String {
        guard p.hasFinalTableState else { return "incomplete" }
        var contacts = 0
        for event in p.events {
            switch event.kind {
            case let .ballBall(a,b):
                guard Set([a,b]) == Set([ShotInput.cueBallName,ShotInput.targetBallName]) else { return "other-ball" }
                contacts += 1
                if contacts > 1 { return "second-contact" }
            case let .ballCushion(ball):
                if ball == ShotInput.cueBallName && contacts == 0 { return "cue-bank" }
                if ball == ShotInput.targetBallName {
                    guard contacts == 1, let index = event.cushionIndex else { return "unknown-contact" }
                    if (0..<6).contains(index) {
                        guard initialFrozenCompression(p,event:event,index:index) else { return "target-bank" }
                    } else if AccuracyShotJudgement.mouthOwner(cushionIndex:index) != pocket {
                        return "other-pocket-mouth"
                    }
                }
            case let .pocket(ball,id):
                if ball == ShotInput.targetBallName {
                    return id == "pocket_\(pocket)" && contacts == 1 ? "direct-pot" : "wrong-pocket-or-contact"
                }
            }
        }
        return "missed"
    }

    func initialFrozenCompression(_ p: ShotPrediction, event: ShotEvent, index: Int) -> Bool {
        guard let frames = p.recorder?.framesByBallName[ShotInput.targetBallName],
              let first = frames.first, first.time <= 0.00001 else { return false }
        let rail = TableGeometry.chineseEightBallQiuJi(surfaceY:0).linearCushions[index]
        let delta = rail.end-rail.start
        let length2 = delta.x*delta.x+delta.z*delta.z
        let u = ((first.position.x-rail.start.x)*delta.x+(first.position.z-rail.start.z)*delta.z)/length2
        guard (0...1).contains(u),
              abs((first.position-rail.start).dot(rail.normal)-BallPhysics.radius) <= SceneTrainingRailGeometry.contactRoundoff else { return false }
        return frames.filter { $0.time <= event.time }.allSatisfy {
            ($0.position-rail.start).dot(rail.normal)-BallPhysics.radius <= 0.0001
        }
    }


    // Fixed center-hit direction, up to five legacy adaptive speed probes.
    // Second-shot validation additionally requires an accessible strike and no scratch.
    func middle(_ data:[String:Any]) throws -> [String:Any] {
        var results:[[String:Any]]=[]
        for request in data["requests"] as! [[String:Any]] {
            let result: [String:Any] = try autoreleasepool {
                let started=Date(), surfaceY=BTTablePhysics.surfaceY, y=surfaceY+BallPhysics.radius
                func point(_ key:String)->SCNVector3 {let a=request[key] as! [Double]; return SCNVector3(Float(a[0]),y,Float(a[1]))}
                let cue=point("cue"), target=point("object"), anchor=point("aim"), pocket=request["pocket"] as! Int
                precondition(pocket == 4 || pocket == 5)
                let forward=(anchor-target).normalized(), ghost=target-forward*(2*BallPhysics.radius)
                let direction=(ghost-cue).normalized()
                let access=CueStrikeAccess(cue:cue,aim:direction,obstacles:[target],surfaceY:surfaceY,profile:profile)
                var trials:[[String:Any]]=[],passed=false
                if access.resolvedPose(spinX:0,spinY:0) != nil {
                    var lo=Float(ShotTuning.velocityRange.lowerBound),hi=Float(ShotTuning.velocityRange.upperBound)
                    for _ in 0..<5 {
                        let v=(lo+hi)/2
                        let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:direction,velocity:v,spinX:0,spinY:0,surfaceY:surfaceY,balls:[.init(name:ShotInput.targetBallName,position:target)],recordedStrikeDirection:direction)
                        let route=directRoute(p,pocket:pocket)
                        let entered=p.events.contains {if case let .pocket(ball,id)=$0.kind {return ball==ShotInput.targetBallName && id=="pocket_\(pocket)"}; return false}
                        passed=entered && route=="direct-pot" && p.hasFinalTableState && !p.cuePocketed
                        let path=p.extraBallPaths[ShotInput.targetBallName] ?? [target]
                        var minimum=Float.greatestFiniteMagnitude,maximum:Float=0
                        for k in path.indices {
                            let pt=SCNVector3(path[k].x,y,path[k].z)
                            maximum=max(maximum,(pt-target).dot(forward));minimum=min(minimum,(pt-anchor).length())
                            if k>0 {let prev=SCNVector3(path[k-1].x,y,path[k-1].z),d=pt-prev,ll=d.dot(d)
                                if ll>0 {let u=max(0,min(1,(anchor-prev).dot(d)/ll));minimum=min(minimum,(prev+d*u-anchor).length())}}
                        }
                        let count=p.events.filter {if case let .ballCushion(ball)=$0.kind {return ball==ShotInput.targetBallName}; return false}.count
                        var feedback="pot"
                        if !passed {
                            if !p.hasFinalTableState {feedback="incomplete-stop"}
                            else if entered {feedback="indirect-or-scratch-probe-lower";hi=v}
                            else if minimum<=2*BallPhysics.radius {feedback="mouth-miss-decrease";hi=v}
                            else if count>0 || maximum >= (anchor-target).length() {feedback="deflection-probe-lower";hi=v}
                            else {feedback="short-increase";lo=v}
                        }
                        let ev:[[String:Any]]=p.events.map {e in
                            var d:[String:Any]=["time":Double(e.time)]
                            switch e.kind {
                            case let .ballBall(a,b):d["kind"]="ballBall";d["balls"]=[a,b]
                            case let .ballCushion(ball):d["kind"]="cushion";d["ball"]=ball;d["cushionID"]=e.cushionIndex as Any? ?? NSNull()
                            case let .pocket(ball,id):d["kind"]="pocket";d["ball"]=ball;d["pocketID"]=id
                            };return d
                        }
                        trials.append(["velocity":Double(v),"passed":passed,"targetPotted":entered,"cuePocketed":p.cuePocketed,"settled":p.hasFinalTableState,"route":route,"feedback":feedback,"events":ev])
                        if passed || !p.hasFinalTableState {break}
                    }
                }
                return ["key":request["key"]!,"request":request,"passed":passed,"direction":xy(direction),"spinX":0,"spinY":0,"trials":trials,"seconds":Date().timeIntervalSince(started)]
            }
            results.append(result)
        }
        return ["results":results]
    }
    func run(_ data: [String:Any]) throws -> [String:Any] {
        let board = data["board"] as! [String:Any], combinations = data["combinations"] as! [[String:Any]]
        let surfaceY = BTTablePhysics.surfaceY, y = surfaceY + BallPhysics.radius
        func point(_ key:String) -> SCNVector3 { let a=board[key] as! [Double];return SCNVector3(Float(a[0]),y,Float(a[1])) }
        let cue=point("cue"), target=point("object"), anchor=point("aim"), pocket=board["pocket"] as! Int
        let geometry=TableGeometry.chineseEightBallQiuJi(surfaceY:surfaceY)
        var rows:[[String:Any]]=[]
        let batchStart=Date()
        for (index,c) in combinations.enumerated() {
            try autoreleasepool {
                let start=Date(), sx=Float(c["spinX"] as! Double), sy=Float(c["spinY"] as! Double), v=Float(c["velocity"] as! Double)
                let input=ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:v,spinX:sx,spinY:sy,surfaceY:surfaceY,pocketAimOverride:anchor)
                var seed = ShotPrediction()
                let aimStart = Date()
                let ctx = ShotPredictor.prepareAim(input, into: &seed)
                var offset: Float? = nil
                if let ctx { offset = ShotPredictor.positionAimOffset(input: input, context: ctx) }
                let aimMS = Date().timeIntervalSince(aimStart)*1000
                let simStart = Date()
                let p: ShotPrediction
                if let ctx, let offset {
                    seed.aimOffsetUsed = offset
                    p = ShotPredictor.buildPrediction(finalAim:ctx.aimDir.rotatedY(offset), context:ctx, input:input,
                        result:seed, maxEvents:500, maxTime:15, includePresentation:false, searchEarlyStop:false)
                } else { p = seed }
                let simMS = Date().timeIntervalSince(simStart)*1000
                var row:[String:Any] = ["trialID":index+1,"comboIndex":c["comboIndex"] ?? index,"tipID":c["tipID"]!,"speedID":c["speedID"]!,"spinX":Double(sx),"spinY":Double(sy),"velocity":Double(v),"simulatedElevationRadians":0,"termination":p.termination.map{String(describing:$0)} ?? "not_simulated","feasible":p.feasible,"infeasibleReason":p.infeasibleReason,"resolved":p.hasResolvedSearchState,"cuePocketed":p.cuePocketed,"targetPottedSelected":p.objectPocketed,"simDurationSeconds":Double(p.duration),"cueEndSpeed":Double(p.cueFinalSpeed),"cueCushionTotal":p.cueCushionCount,"cueCushionsBeforeContact":p.cueCushionsBeforeContact,"objectCushionTotal":p.objectCushionCount,"pocketAim":xy(p.pocketAimPoint)]
                if let a=p.aimOffsetUsed { row["aimOffsetRadians"]=Double(a) }
                if let a=p.cutAngleDeg { row["actualAimCutDegrees"]=a }
                if let a=p.separationAngleDeg { row["separationAngleDegrees"]=a }
                var accessOK=false
                if let dir=p.strikeDirection {
                    row["strikeDirection"]=xy(dir)
                    let access=CueStrikeAccess(cue:cue,aim:dir,obstacles:[target],surfaceY:surfaceY,profile:profile)
                    if let pose=access.resolvedPose(spinX:Double(sx),spinY:Double(sy)) { accessOK=true;row["accessElevationRadians"]=Double(pose.elevation) }
                }
                row["cueAccessAvailable"]=accessOK
                var events:[[String:Any]]=[], contacted=false, contacts=0, mainAfter=0, jawAfter=0, otherAfter=0
                var targetPocket:String? = nil, cuePocket:String? = nil
                for e in p.events {
                    var event:[String:Any]=["time":Double(e.time)]
                    switch e.kind {
                    case let .ballBall(a,b):
                        event["kind"]="ballBall";event["balls"]=[a,b]
                        if Set([a,b])==Set([ShotInput.cueBallName,ShotInput.targetBallName]) {
                            if !contacted { row["firstContactTime"]=Double(e.time) }
                            contacted=true;contacts += 1
                        }
                    case let .ballCushion(ball):
                        event["kind"]="cushion";event["ball"]=ball
                        let id=e.cushionIndex
                        var type="unknown"
                        if let id {
                            event["cushionID"]=id
                            if id>=0 && id<geometry.linearCushions.count {
                                let s=geometry.linearCushions[id].soundSurface
                                type = s == .cushion ? "mainRail" : (s == .jaw ? "jaw" : "liner")
                            } else if id>=geometry.linearCushions.count && id<geometry.linearCushions.count+geometry.circularCushions.count { type="jaw" }
                        }
                        event["surface"]=type;event["afterFirstContact"]=contacted
                        if ball==ShotInput.cueBallName && contacted {
                            if type=="mainRail" { mainAfter += 1 } else if type=="jaw" { jawAfter += 1 } else { otherAfter += 1 }
                        }
                    case let .pocket(ball,id):
                        event["kind"]="pocket";event["ball"]=ball;event["pocketID"]=id
                        if ball==ShotInput.targetBallName { targetPocket=id }
                        if ball==ShotInput.cueBallName { cuePocket=id }
                    }
                    events.append(event)
                }
                row["events"]=events;row["cueTargetContactCount"]=contacts
                row["cueMainRailsAfterContact"]=mainAfter;row["cueJawsAfterContact"]=jawAfter;row["cueOtherCushionsAfterContact"]=otherAfter
                row["targetActualPocket"]=targetPocket ?? NSNull() as Any;row["cueActualPocket"]=cuePocket ?? NSNull() as Any
                if let end=p.finalPositions[ShotInput.cueBallName] { row["cueEndPosition"]=xy(end) }
                if let end=p.finalPositions[ShotInput.targetBallName] { row["objectEndPosition"]=xy(end) }
                let stopValid=p.hasResolvedSearchState && !p.cuePocketed && p.cueFinalSpeed<0.00001 && p.finalPositions[ShotInput.cueBallName] != nil
                row["cueStopValid"]=stopValid
                if stopValid, let end=p.finalPositions[ShotInput.cueBallName] { row["cueStop"]=xy(end) }
                var reasons:[String]=[]
                if !p.feasible { reasons.append("infeasible") }
                if !accessOK { reasons.append("cue_inaccessible") }
                if !p.hasResolvedSearchState { reasons.append("unresolved") }
                if targetPocket != "pocket_\(pocket)" { reasons.append("target_not_in_selected_pocket") }
                if p.cuePocketed { reasons.append("scratch") }
                if !stopValid { reasons.append("no_valid_cue_stop") }
                row["failureReasons"]=reasons;row["usableForPositionMatch"]=reasons.isEmpty
                row["wallMilliseconds"]=Date().timeIntervalSince(start)*1000
                precondition(p.objectPocketed == (targetPocket == "pocket_\(pocket)"))
                precondition(p.cuePath.isEmpty && p.objectPath.isEmpty)
                row["parameterStatus"] = accessOK ? "legal" : (p.strikeDirection == nil ? "undetermined" : "illegal")
                row["status"] = !accessOK && p.strikeDirection != nil ? "illegal_parameters" : (reasons.isEmpty ? "success" : (!p.hasResolvedSearchState ? "unresolved" : (p.cuePocketed ? "scratch" : (targetPocket != "pocket_\(pocket)" ? "target_miss" : "no_valid_stop"))))
                row["initialAimMilliseconds"] = aimMS
                row["physicsMilliseconds"] = simMS
                row["simulationCalls"] = ctx == nil ? 0 : 1
                row["directionRetries"] = 0
                if reasons.isEmpty {
                    let compressionStart = Date()
                    let line = try SeparationTrajectory.extract(p)
                    let compact = try compactTrajectory(line, prediction:p)
                    row["trajectory2mm"] = compact
                    row["extractionCompressionMilliseconds"] = Date().timeIntervalSince(compressionStart)*1000
                    if (data["captureAudit"] as? Bool == true) && rows.filter({$0["usableForPositionMatch"] as? Bool == true}).count < 5 {
                        row["auditFullLine"] = try JSONSerialization.jsonObject(with:JSONEncoder().encode(line))
                    }
                }
                row["wallMilliseconds"] = Date().timeIntervalSince(start)*1000
                rows.append(row)
            }
        }
        precondition(rows.count == combinations.count)
        return ["id":board["id"]!,"board":board,"rows":rows,"elapsedSeconds":Date().timeIntervalSince(batchStart)]
    }
}
let worker = StrikeGridWorker()
let metadata: [String:Any] = ["pid":ProcessInfo.processInfo.processIdentifier,"surfaceY":Double(BTTablePhysics.surfaceY),"profile":worker.profile.map{[Double($0.start),Double($0.end),Double($0.radius)]}]
func emit(_ prefix:String,_ value:Any) throws {
    let d=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
    FileHandle.standardOutput.write(Data((prefix+String(data:d,encoding:.utf8)!+"\n").utf8))
}
try emit("READY\t",metadata)
while let line=readLine() {
    do {
        try autoreleasepool {
            let input=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any]
            let result = try (input["command"] as? String == "middle" ? worker.middle(input) : worker.run(input))
            try emit("RESULT\t",result)
        }
    } catch {
        try emit("ERROR\t",["error":String(describing:error)])
        exit(1)
    }
}
