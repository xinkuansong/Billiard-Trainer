// Research-only harness, appended to a frozen test snapshot by run.py.
final class JointTrajectoryResearchTests: XCTestCase {
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/joint-trajectory-20261022")
    let radius = BallPhysics.radius
    func xy(_ p: SCNVector3) -> [Float] { [p.x,p.z] }
    func vec(_ p: [Double]) -> SCNVector3 { SCNVector3(Float(p[0]),0,Float(p[1])) }
    func read(_ name: String) throws -> [String:Any] { try JSONSerialization.jsonObject(with: Data(contentsOf:out.appendingPathComponent(name))) as! [String:Any] }
    func write(_ name: String,_ value: Any) throws { try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic) }
    func pot(_ p: ShotPrediction,_ pocket: Int) -> Bool { p.events.contains { if case let .pocket(n,id)=$0.kind { return n==ShotInput.targetBallName && id=="pocket_\(pocket)" };return false } }
    func frames(_ p:ShotPrediction,_ name:String) -> [BallFrame] {
        let end=p.events.first { if case let .pocket(n,_)=$0.kind{return n==name};return false }?.time ?? Float.infinity
        return (p.recorder?.framesByBallName[name] ?? []).filter{$0.time<=end}
    }
    func info(_ p:ShotPrediction,_ pocket:Int,paths:Bool=true)->[String:Any] {
        var rails:[Int]=[],jaw=0,before=0,contacts=0,objectRails=0,otherHit=false,firstPair=false
        for e in p.events { switch e.kind {
        case let .ballBall(a,b):
            if contacts==0 { firstPair=Set([a,b])==Set([ShotInput.cueBallName,ShotInput.targetBallName]) }
            contacts+=1;if a=="second" || b=="second" {otherHit=true}
        case let .ballCushion(ball):
            if ball==ShotInput.cueBallName {if contacts==0{before+=1};if let i=e.cushionIndex,i<6{rails.append(i)}else{jaw+=1}}
            if ball==ShotInput.targetBallName{objectRails+=1}
        default:break}}
        let ok=p.hasFinalTableState && pot(p,pocket) && !p.cuePocketed && before==0 && jaw==0 && contacts==1 && objectRails==0 && !otherHit && firstPair
        var r:[String:Any]=["physicsPass":ok,"pot":pot(p,pocket),"scratch":p.cuePocketed,"settled":p.hasFinalTableState,"rails":rails,"jaw":jaw,"before":before,"contacts":contacts,"objectRails":objectRails,"otherHit":otherHit,"termination":String(describing:p.termination),"duration":p.duration]
        if let stop=p.finalPositions[ShotInput.cueBallName] {r["stop"]=xy(stop);r["clearance"]=SceneTrainingRailGeometry.clearance(stop)}
        if paths {
            let cueFrames=frames(p,ShotInput.cueBallName), objectFrames=frames(p,ShotInput.targetBallName)
            r["cuePath"]=cueFrames.map{xy($0.position)};r["objectPath"]=objectFrames.map{xy($0.position)}
            let hitTime=p.events.first{if case .ballBall=$0.kind{return true};return false}?.time ?? Float.infinity
            let post=cueFrames.filter{$0.time>=hitTime};var length:Float=0
            for (a,b) in zip(post,post.dropFirst()){length+=hypot(b.position.x-a.position.x,b.position.z-a.position.z)}
            r["postContactLength"]=length
            r["railEvents"]=p.events.compactMap{e -> [String:Any]? in
                guard case let .ballCushion(ball)=e.kind,ball==ShotInput.cueBallName else{return nil}
                var event:[String:Any]=["time":e.time,"rail":e.cushionIndex ?? -1]
                if let f=cueFrames.last(where:{$0.time<=e.time}){event["position"]=xy(f.position)}
                return event
            }
        }
        return r
    }
    func testResearch() throws {
        let req=try read("request.json"),sample=try read("sample.json")
        func sv(_ key:String)->SCNVector3 {let p=sample[key] as! [String:Double];return SCNVector3(Float(p["x"]!),0,Float(p["z"]!))}
        let cue=sv("cue"),target=sv("target"),pocket=sample["pocket"] as! Int
        let mode=req["mode"] as! String
        let jobs=req["jobs"] as! [[String:Any]]
        var rows:[[String:Any]]=[]
        var solvedDirections:[String:SCNVector3]=[:]
        var solvedPots:[String:Bool]=[:]
        if mode=="scan" {
            var grid:[[String:Any]]=[]
            for ix in 0...80 {for iz in 0...40 {
                let p=SCNVector3(-1.20+Float(ix)*0.03,0,-0.60+Float(iz)*0.03)
                grid.append(["p":xy(p),"aims":(0..<6).map{xy(AngleSceneCalculator.effectivePocketAimPoint(targetBall:p,pocketIndex:$0,surfaceY:0))}])
            }}
            try write("grid.json",grid)
        }
        for (index,j) in jobs.enumerated() {
            let speed=Float(j["v"] as! Double),sx=Float(j["sx"] as! Double),sy=Float(j["sy"] as! Double)
            var dir=vec(j["direction"] as! [Double])
            var row=j
            let inputValid=speed>0 && speed<=4.500001 && sx*sx+sy*sy<=CuePhysics.miscueLimitFraction*CuePhysics.miscueLimitFraction
            row["inputValid"]=inputValid;row["miscueMargin"]=CuePhysics.miscueLimitFraction-hypot(sx,sy)
            guard inputValid else {row["accepted"]=false;row["physicsPass"]=false;row["inputFailure"]="outside_input_domain";rows.append(row);continue}
            if mode=="scan" {
                let key="\(j["route"]!)-\(speed)-\(sx)-\(sy)"
                if solvedPots[key]==nil {
                    let input=ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:speed,spinX:sx,spinY:sy,surfaceY:0)
                    let solved=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
                    solvedDirections[key]=solved.strikeDirection
                    solvedPots[key]=pot(solved,pocket) && solved.strikeDirection != nil
                }
                row["solverPotFound"]=solvedPots[key] ?? false
                guard let aim=solvedDirections[key],solvedPots[key]==true else {
                    row["accepted"]=false;row["physicsPass"]=false;row["inputFailure"]="solver_no_pot_witness";rows.append(row);continue
                }
                let delta=Float(j["directionDeltaDegrees"] as! Double) * .pi / 180
                dir=delta==0 ? aim : SCNVector3(aim.x*cosf(delta)-aim.z*sinf(delta),0,aim.x*sinf(delta)+aim.z*cosf(delta))
                row["solverDirection"]=xy(aim);row["direction"]=xy(dir)
            }
            let second=(j["point"] as? [Double]).map(vec)
            var balls=[ObstacleBall(name:ShotInput.targetBallName,position:target)]
            if let second {balls.append(ObstacleBall(name:"second",position:second))}
            let access=CueStrikeAccess(cue:SCNVector3(cue.x,radius,cue.z),aim:dir,obstacles:balls.map{SCNVector3($0.position.x,radius,$0.position.z)},surfaceY:0)
            let pose=access.resolvedPose(spinX:Double(sx),spinY:Double(sy))
            row["firstAccess"]=pose != nil
            if let pose {row["firstElevationDegrees"]=pose.elevation*180 / .pi}
            let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:speed,spinX:sx,spinY:sy,surfaceY:0,balls:balls,maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:dir)
            XCTAssertEqual(xy(p.strikeDirection!),xy(dir))
            row.merge(info(p,pocket,paths:mode=="scan")){_,new in new}
            row["accepted"]=(row["physicsPass"] as! Bool) && pose != nil
            if j["baselineCheck"] as? Bool == true {
                let expected=vec(j["expectedStop"] as! [Double]);let actual=p.finalPositions[ShotInput.cueBallName]!
                XCTAssertLessThan(hypot(expected.x-actual.x,expected.z-actual.z),0.0001)
                XCTAssertEqual(row["rails"] as! [Int],j["expectedRails"] as! [Int])
            }
            if mode=="validate",let second {
                var attempts=0,witness:[String:Any]?=nil
                let secondPocket=j["pocket2"] as! Int
                let unchanged=p.finalPositions["second"].map{hypot($0.x-second.x,$0.z-second.z)<0.00001} ?? false
                row["secondUnchanged"]=unchanged
                if row["accepted"] as! Bool,unchanged,let stop=p.finalPositions[ShotInput.cueBallName],let next=p.finalPositions["second"] {
                    let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:next,pocketIndex:secondPocket,surfaceY:0)
                    row["secondGeometricAngle"]=AngleSceneCalculator.cutAngle(cueBall:stop,targetBall:next,pocket:aim)
                    row["cueToSecond"]=hypot(next.x-stop.x,next.z-stop.z)
                    row["secondToAim"]=hypot(aim.x-next.x,aim.z-next.z)
                    for tip:Float in [0,0.25,-0.25] {
                        for speed2:Float in [1,1.5,2,2.5] {
                            attempts+=1
                            let input=ShotInput(cueBall:stop,targetBall:next,pocketIndex:secondPocket,velocity:speed2,spinX:0,spinY:tip,surfaceY:0)
                            let p2=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
                            guard let dir2=p2.strikeDirection else{continue}
                            let a2=CueStrikeAccess(cue:SCNVector3(stop.x,radius,stop.z),aim:dir2,obstacles:[SCNVector3(next.x,radius,next.z)],surfaceY:0)
                            let pose2=a2.resolvedPose(spinX:0,spinY:Double(tip))
                            let check=info(p2,secondPocket,paths:false)
                            if check["physicsPass"] as! Bool,let pose2,let secondAngle=row["secondGeometricAngle"] as? Double,abs(secondAngle)<=20.000001 {
                                witness=["v":speed2,"sy":tip,"direction":xy(dir2),"elevationDegrees":pose2.elevation*180 / .pi,"firstAngle":secondAngle]
                                break
                            }
                        };if witness != nil{break}
                    }
                }
                row["secondAttempts"]=attempts;row["secondPass"]=witness != nil;row["secondWitness"]=witness ?? [:]
            }
            rows.append(row)
            if index % 500 == 0 {print("JOINT \(mode) \(index)/\(jobs.count)")}
        }
        try write("\(mode)-results.json",["rows":rows,"count":rows.count,"miscueLimit":CuePhysics.miscueLimitFraction,"radius":radius])
        XCTAssertEqual(rows.count,jobs.count);XCTAssertGreaterThan(rows.count,0)
        print("JOINT_DONE \(mode) rows=\(rows.count)")
    }
}
