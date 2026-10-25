import Foundation
import SceneKit
// Research-only harness. App physics sources are not modified.
final class StrikeGridWorker {
    let profile = AccuracyTipSelector.renderedProfile()
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/two-ball-strike-pilot-20261024")
    func xy(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
    func write(_ name: String, _ value: Any) throws { try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic) }
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
                let p=ShotPredictor.predictForPositionSolve(input,maxEvents:500,maxTime:15,includePresentation:false)
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
            let result=try worker.run(input)
            try emit("RESULT\t",result)
        }
    } catch {
        try emit("ERROR\t",["error":String(describing:error)])
        exit(1)
    }
}
