// Research-only harness, appended to an immutable test snapshot by run.py.
final class TwoBallPrecomputeResearchTests: XCTestCase {
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/two-ball-precompute-20261023")
    let radius = BallPhysics.radius
    func xy(_ p: SCNVector3) -> [Float] { [p.x, p.z] }
    func vec(_ p: [Double]) -> SCNVector3 { SCNVector3(Float(p[0]), 0, Float(p[1])) }
    func read(_ name: String) throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(contentsOf: out.appendingPathComponent(name))) as! [String: Any] }
    func array(_ name: String) throws -> [[String: Any]] { try JSONSerialization.jsonObject(with: Data(contentsOf: out.appendingPathComponent(name))) as! [[String: Any]] }
    func write(_ name: String, _ value: Any) throws { try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: out.appendingPathComponent(name), options: .atomic) }
    func pot(_ p: ShotPrediction, _ pocket: Int) -> Bool {
        p.events.contains { if case let .pocket(n, id) = $0.kind { return n == ShotInput.targetBallName && id == "pocket_\(pocket)" }; return false }
    }
    func info(_ p: ShotPrediction, _ pocket: Int, paths: Bool) -> [String: Any] {
        var rails: [Int] = [], jaw = 0, before = 0, contacts = 0, objectRails = 0, otherHit = false, firstPair = false
        for e in p.events {
            switch e.kind {
            case let .ballBall(a,b):
                if contacts == 0 { firstPair = Set([a,b]) == Set([ShotInput.cueBallName,ShotInput.targetBallName]) }
                contacts += 1; if a == "second" || b == "second" { otherHit = true }
            case let .ballCushion(ball):
                if ball == ShotInput.cueBallName { if contacts == 0 { before += 1 }; if let i=e.cushionIndex, i<6 { rails.append(i) } else { jaw += 1 } }
                if ball == ShotInput.targetBallName { objectRails += 1 }
            default: break
            }
        }
        let ok = p.hasFinalTableState && pot(p,pocket) && !p.cuePocketed && before == 0 && jaw == 0 && contacts == 1 && objectRails == 0 && !otherHit && firstPair
        var r: [String: Any] = ["physicsPass": ok, "pot": pot(p,pocket), "scratch": p.cuePocketed, "settled": p.hasFinalTableState, "rails": rails, "jaw": jaw, "before": before, "contacts": contacts, "objectRails": objectRails, "otherHit": otherHit, "termination": String(describing:p.termination)]
        if let stop=p.finalPositions[ShotInput.cueBallName] { r["stop"]=xy(stop); r["clearance"]=SceneTrainingRailGeometry.clearance(stop) }
        if paths {
            for (key,name) in [("cuePath",ShotInput.cueBallName),("objectPath",ShotInput.targetBallName)] {
                let end=p.events.first { if case let .pocket(n,_)=$0.kind { return n==name }; return false }?.time ?? Float.infinity
                r[key]=(p.recorder?.framesByBallName[name] ?? []).filter{$0.time<=end}.map{xy($0.position)}
            }
        }
        return r
    }
    func rule(_ cue: SCNVector3, _ target: SCNVector3, _ pocket: Int) -> (Bool,Double) {
        let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:pocket,surfaceY:0)
        let angle=AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:target,pocket:aim)
        let d=hypot(cue.x-target.x,cue.z-target.z)
        return (d >= 0.15 && d <= 1.20 && angle <= 35 && SceneTrainingRailGeometry.clearance(cue) >= 0.05,angle)
    }
    func solveSecond(_ cue: SCNVector3, _ target: SCNVector3, _ pocket: Int, paths: Bool) -> [String: Any] {
        let (eligible,angle)=rule(cue,target,pocket)
        guard eligible else { return ["pass":false,"status":"outside_pilot_rules","attempts":0,"cutDegrees":angle] }
        var attempts=0
        for tip: Float in [0,0.25,-0.25] { for speed: Float in [1,1.5,2,2.5] {
            attempts += 1
            let input=ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:speed,spinX:0,spinY:tip,surfaceY:0)
            let solved=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
            guard let direction=solved.strikeDirection, info(solved,pocket,paths:false)["physicsPass"] as! Bool else { continue }
            let access=CueStrikeAccess(cue:SCNVector3(cue.x,radius,cue.z),aim:direction,obstacles:[SCNVector3(target.x,radius,target.z)],surfaceY:0)
            guard let pose=access.resolvedPose(spinX:0,spinY:Double(tip)) else { continue }
            // Independently execute the saved witness, with no aim re-solving.
            let replay=ShotPredictor.simulateFree(cueBall:cue,aimDir:direction,velocity:speed,spinX:0,spinY:tip,surfaceY:0,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:direction)
            let check=info(replay,pocket,paths:paths)
            guard check["physicsPass"] as! Bool else { continue }
            return ["pass":true,"status":"witness_replayed","attempts":attempts,"cutDegrees":angle,"v":speed,"sx":0,"sy":tip,"direction":xy(direction),"elevationDegrees":pose.elevation*180 / .pi,"replay":check]
        }}
        return ["pass":false,"status":"budget_exhausted","attempts":attempts,"cutDegrees":angle]
    }
    func first(_ cue: SCNVector3, _ target: SCNVector3, _ pocket: Int, _ route: [String:Any], _ offset: [Double], second: SCNVector3?, paths: Bool) -> (ShotPrediction?,[String:Any]) {
        let speed=Float(route["v"] as! Double)*(1+Float(offset[0])*0.04)
        let sx=Float(route["sx"] as! Double)+Float(offset[2])*0.025
        let sy=Float(route["sy"] as! Double)+Float(offset[3])*0.025
        let aim=vec(route["direction"] as! [Double]), delta=Float(offset[1])*0.25 * .pi / 180
        let dir=SCNVector3(aim.x*cosf(delta)-aim.z*sinf(delta),0,aim.x*sinf(delta)+aim.z*cosf(delta))
        var row:[String:Any]=["offset":offset,"v":speed,"sx":sx,"sy":sy,"direction":xy(dir)]
        guard speed>0 && speed<=4.5 && hypot(sx,sy)<=CuePhysics.miscueLimitFraction else { row["accepted"]=false;row["status"]="invalid_input";return(nil,row) }
        var balls=[ObstacleBall(name:ShotInput.targetBallName,position:target)]
        if let second { balls.append(ObstacleBall(name:"second",position:second)) }
        let access=CueStrikeAccess(cue:SCNVector3(cue.x,radius,cue.z),aim:dir,obstacles:balls.map{SCNVector3($0.position.x,radius,$0.position.z)},surfaceY:0)
        let pose=access.resolvedPose(spinX:Double(sx),spinY:Double(sy))
        let prediction=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:speed,spinX:sx,spinY:sy,surfaceY:0,balls:balls,maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:dir)
        XCTAssertEqual(xy(prediction.strikeDirection!),xy(dir))
        row.merge(info(prediction,pocket,paths:paths)){_,v in v}
        row["access"]=pose != nil;row["accepted"]=(row["physicsPass"] as! Bool) && pose != nil
        if let pose { row["elevationDegrees"]=pose.elevation*180 / .pi }
        return(prediction,row)
    }
    func testResearch() throws {
        let mode=try read("request.json")["mode"] as! String, protocolData=try read("protocol.json"), sample=try read("sample.json")
        func sv(_ key:String)->SCNVector3 {let p=sample[key] as! [String:Double];return SCNVector3(Float(p["x"]!),0,Float(p["z"]!))}
        let cue=sv("cue"), target=sv("target"), pocket=sample["pocket"] as! Int
        let design=protocolData["designOffsets"] as! [[Double]]
        if mode=="scan" {
            var metadata=try array("targets.json")
            for i in metadata.indices {
                let p=vec(metadata[i]["point"] as! [Double]), pk=metadata[i]["pocket"] as! Int
                metadata[i]["aim"]=xy(AngleSceneCalculator.effectivePocketAimPoint(targetBall:p,pocketIndex:pk,surfaceY:0))
                metadata[i]["railClearance"]=SceneTrainingRailGeometry.clearance(p)
            }
            try write("target-metadata.json",metadata)
            var routes=protocolData["routes"] as! [[String:Any]], rows:[[String:Any]]=[]
            for i in routes.indices {
                let r=routes[i]
                let prediction=ShotPredictor.predict(ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:Float(r["v"] as! Double),spinX:Float(r["sx"] as! Double),spinY:Float(r["sy"] as! Double),surfaceY:0),maxEvents:1500,maxTime:60)
                let direction=try XCTUnwrap(prediction.strikeDirection)
                XCTAssertTrue(pot(prediction,pocket));routes[i]["direction"]=xy(direction).map(Double.init)
                for (j,offset) in design.enumerated() {
                    var row=first(cue,target,pocket,routes[i],offset,second:nil,paths:true).1
                    row["route"]=r["id"];row["sampleIndex"]=j;rows.append(row)
                }
                print("PILOT scan \(i+1)/\(routes.count)")
            }
            try write("scan-results.json",["routes":routes,"rows":rows,"radius":radius]);XCTAssertEqual(rows.count,243)
        } else if mode=="map" {
            let candidates=try array("candidates.json");var maps:[[String:Any]]=[]
            for c in candidates {
                let second=vec(c["point"] as! [Double]), pk=c["pocket"] as! Int
                var rows:[[String:Any]]=[]
                for ix in 0...40 { for iz in 0...20 {
                    let p=SCNVector3(-1.20+Float(ix)*0.06,0,-0.60+Float(iz)*0.06)
                    var row=solveSecond(p,second,pk,paths:false);row["cell"]=ix*21+iz;row["point"]=xy(p);rows.append(row)
                }}
                maps.append(["id":c["id"]!,"rows":rows]);try write("map-partial.json",["maps":maps])
                print("PILOT map \(maps.count)/\(candidates.count)")
            }
            try write("map-results.json",["maps":maps]);XCTAssertEqual(maps.count,candidates.count)
        } else if mode=="validate" {
            let ranks=try read("rankings.json"), scan=try read("scan-results.json"), candidates=try array("candidates.json")
            let selections=ranks["selections"] as! [[String:Any]], routes=scan["routes"] as! [[String:Any]]
            let holdout=protocolData["holdoutOffsets"] as! [[Double]]
            var result:[[String:Any]]=[]
            for selection in selections {
                let r=routes.first{($0["id"] as! String)==(selection["route"] as! String)}!
                for id in selection["candidateIDs"] as! [Int] {
                    let c=candidates.first{($0["id"] as! Int)==id}!, second=vec(candidates.first{($0["id"] as! Int)==id}!["point"] as! [Double])
                    var rows:[[String:Any]]=[], savedPath=false
                    for (split, offsets) in [("design",design),("holdout",holdout)] {
                        for (i,offset) in offsets.enumerated() {
                            let wantPaths = !savedPath || offset.allSatisfy{$0==0}
                            let (p,row0)=first(cue,target,pocket,r,offset,second:second,paths:wantPaths)
                            var row=row0;row["split"]=split;row["sampleIndex"]=i
                            let unchanged=p?.finalPositions["second"].map{hypot($0.x-second.x,$0.z-second.z)<0.00001} ?? false
                            row["secondUnchanged"]=unchanged;row["complete"]=false
                            if let p, row["accepted"] as! Bool, unchanged, let stop=p.finalPositions[ShotInput.cueBallName], let next=p.finalPositions["second"] {
                                let check=solveSecond(stop,next,c["pocket"] as! Int,paths:wantPaths)
                                row["second"]=check;row["complete"]=check["pass"]
                                if check["pass"] as! Bool { savedPath=true }
                            }
                            rows.append(row)
                        }
                    }
                    result.append(["route":r["id"]!,"id":id,"rows":rows]);try write("validate-partial.json",["results":result])
                    print("PILOT validate \(r["id"]!) candidate \(id), pairs \(result.count)")
                }
            }
            try write("validate-results.json",["results":result]);XCTAssertGreaterThan(result.count,0)
        } else { XCTFail("Unknown research phase") }
        print("PILOT_DONE \(mode)")
    }
}
