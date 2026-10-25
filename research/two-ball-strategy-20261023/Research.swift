// Research-only harness, appended to an immutable test snapshot by run.py.
final class TwoBallStrategyResearchTests: XCTestCase {
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/two-ball-strategy-20261023")
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
        return (d >= 0.15 && d <= 2.54 && angle <= 75 && SceneTrainingRailGeometry.clearance(cue) >= 0.05,angle)
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
    let zero = [0.0,0,0,0]
    func plan(_ cue: SCNVector3, _ target: SCNVector3, _ pk: Int, _ v: Double, _ sx: Double, _ sy: Double) -> [String:Any]? {
        guard rule(cue,target,pk).0 else { return nil }
        let p=ShotPredictor.predict(ShotInput(cueBall:cue,targetBall:target,pocketIndex:pk,velocity:Float(v),spinX:Float(sx),spinY:Float(sy),surfaceY:0),maxEvents:1500,maxTime:60)
        guard let dir=p.strikeDirection else {return nil}
        return ["v":v,"sx":sx,"sy":sy,"direction":xy(dir).map(Double.init)]
    }
    func checked(_ cue:SCNVector3,_ target:SCNVector3,_ pk:Int,_ controls:[String:Any],_ offset:[Double],other:SCNVector3?,paths:Bool)->[String:Any] {
        let (p,r)=first(cue,target,pk,controls,offset,second:other,paths:paths)
        var row=r
        if let other {
            let unchanged=p?.finalPositions["second"].map{hypot($0.x-other.x,$0.z-other.z)<0.00001} ?? false
            row["otherUnchanged"]=unchanged
            row["accepted"]=(r["accepted"] as! Bool) && unchanged
        }
        return row
    }
    func testResearch() throws {
        let protocolData=try read("protocol.json"), sample=try read("sample.json"), mode=try read("request.json")["mode"] as! String
        let cue=vec(sample["cue"] as! [Double]), a=vec(sample["a"] as! [Double]), b=vec(sample["b"] as! [Double])
        let axes=protocolData["axisOffsets"] as! [[Double]]
        if mode=="scan" {
            var results:[[String:Any]]=[], firstRows:[[String:Any]]=[], serial=0
            let styles=protocolData["styles"] as! [[String:Any]], speeds=protocolData["speeds"] as! [Double]
            for order in ["AB","BA"] {
                let target=order=="AB" ? a:b, other=order=="AB" ? b:a
                for p1 in 0..<6 {
                    for style in styles {for speed in speeds {
                        serial += 1
                        let sid=style["id"] as! String, sx=style["sx"] as! Double, sy=style["sy"] as! Double
                        var base:[String:Any]=["id":serial,"order":order,"p1":p1,"style":sid,"v":speed,"sx":sx,"sy":sy,"eligible":rule(cue,target,p1).0,"cutDegrees":rule(cue,target,p1).1]
                        guard let ctrl=plan(cue,target,p1,speed,sx,sy) else {base["status"]="geometry_excluded";firstRows.append(base);continue}
                        let nominal=checked(cue,target,p1,ctrl,zero,other:other,paths:true)
                        base["firstControl"]=ctrl;base["nominal"]=nominal
                        guard nominal["accepted"] as! Bool else {base["status"]="nominal_first_failed";firstRows.append(base);continue}
                        var firstAxes:[[String:Any]]=[]
                        for off in axes {firstAxes.append(checked(cue,target,p1,ctrl,off,other:other,paths:false))}
                        let k=firstAxes.filter{$0["accepted"] as! Bool}.count
                        base["status"]="nominal_first_passed";base["axisPass"]=k;base["axisTrials"]=firstAxes;firstRows.append(base)
                        let stop=vec((nominal["stop"] as! [Float]).map(Double.init))
                        for p2 in 0..<6 {
                            var secondOptions:[[String:Any]]=[]
                            for ty in [0.0,0.25,-0.25] {for v in [1.0,1.5,2.0,2.5] {
                                guard let ctl=plan(stop,other,p2,v,0,ty) else {continue}
                                let replay=checked(stop,other,p2,ctl,zero,other:nil,paths:true)
                                guard replay["accepted"] as! Bool else {continue}
                                let rows=axes.map{checked(stop,other,p2,ctl,$0,other:nil,paths:false)}
                                secondOptions.append(["control":ctl,"nominal":replay,"axisPass":rows.filter{$0["accepted"] as! Bool}.count,"axisTrials":rows])
                            }}
                            secondOptions.sort{($0["axisPass"] as! Int)>($1["axisPass"] as! Int)}
                            // Explicit deterministic tie order, independent of dictionary/sort stability.
                            secondOptions.sort {
                                let l=$0["axisPass"] as! Int,r=$1["axisPass"] as! Int
                                if l != r {return l>r}
                                let lc=$0["control"] as! [String:Any],rc=$1["control"] as! [String:Any]
                                let lt=[0.0,0.25,-0.25].firstIndex(of:lc["sy"] as! Double)!,rt=[0.0,0.25,-0.25].firstIndex(of:rc["sy"] as! Double)!
                                return lt != rt ? lt<rt : (lc["v"] as! Double)<(rc["v"] as! Double)
                            }
                            var candidate=base;candidate["id"]="\(order)-p\(p1)-p\(p2)-\(sid)-v\(speed)";candidate["p2"]=p2
                            candidate["secondOptions"]=secondOptions;candidate["status"]=secondOptions.isEmpty ? "second_budget_exhausted":"nominal_both_passed"
                            if let best=secondOptions.first {candidate["secondControl"]=best["control"];candidate["secondNominal"]=best["nominal"];candidate["secondAxisPass"]=best["axisPass"];candidate["proxy"]=k*(best["axisPass"] as! Int)}
                            results.append(candidate)
                        }
                    }}
                    try write("scan-partial.json",["firstRows":firstRows,"candidates":results]);print("STRATEGY scan \(order) pocket \(p1), first slots \(firstRows.count), candidates \(results.count)")
                }
            }
            XCTAssertEqual(firstRows.count,2*6*styles.count*speeds.count)
            try write("scan-results.json",["firstRows":firstRows,"candidates":results,"radius":radius])
        } else if mode=="design" || mode=="holdout" {
            let choices=try array("selected.json"), offsets=protocolData[mode+"Offsets"] as! [[Double]]
            var all:[[String:Any]]=[]
            for c in choices {
                let order=c["order"] as! String,target=order=="AB" ? a:b,other=order=="AB" ? b:a
                let p1=c["p1"] as! Int,p2=c["p2"] as! Int,ctl=c["firstControl"] as! [String:Any],next=c["secondControl"] as! [String:Any]
                var rows:[[String:Any]]=[]
                for (i,off) in offsets.enumerated() {
                    var row:[String:Any]=["sampleIndex":i,"offset":off,"complete":false]
                    let f=checked(cue,target,p1,ctl,Array(off[0..<4]),other:other,paths:i<8)
                    row["first"]=f;row["status"]="first_failed"
                    if f["accepted"] as! Bool {
                        let stop=vec((f["stop"] as! [Float]).map(Double.init))
                        row["status"]="second_geometry_excluded"
                        if let second=plan(stop,other,p2,next["v"] as! Double,next["sx"] as! Double,next["sy"] as! Double) {
                            let baseline=checked(stop,other,p2,second,zero,other:nil,paths:false)
                            row["secondBaselinePass"]=baseline["accepted"];row["secondControl"]=second
                            // Aim adapts to the observed stop; speed/tip were frozen before this trial.
                            // Execute the noisy shot even if its zero-error baseline failed.
                            let s=checked(stop,other,p2,second,Array(off[4..<8]),other:nil,paths:i<8)
                            row["second"]=s;row["complete"]=s["accepted"];row["status"]=(s["accepted"] as! Bool) ? "complete":"second_execution_failed"
                        }
                    }
                    rows.append(row)
                }
                all.append(["id":c["id"]!,"rows":rows]);try write(mode+"-partial.json",["results":all])
                print("STRATEGY \(mode) \(all.count)/\(choices.count), \(c["id"]!)")
            }
            XCTAssertEqual(all.count,choices.count)
            try write(mode+"-results.json",["results":all])
        } else {XCTFail("unknown phase")}
        print("STRATEGY_DONE \(mode)")
    }
}
