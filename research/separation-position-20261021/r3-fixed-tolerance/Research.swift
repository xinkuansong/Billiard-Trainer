
final class FixedDirectionToleranceResearchTests: XCTestCase {
    let out=URL(fileURLWithPath:"/Users/song/projects/13.billiard_trainer/research/separation-position-20261021/r3-fixed-tolerance")
    func xy(_ p:SCNVector3)->[Float]{[p.x,p.z]}
    func v(_ p:[Double])->SCNVector3{SCNVector3(Float(p[0]),0,Float(p[1]))}
    func write(_ name:String,_ value:Any)throws{try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic)}
    func read(_ name:String)throws->[String:Any]{try JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent(name))) as! [String:Any]}
    func pot(_ p:ShotPrediction,_ name:String,_ pocket:Int)->Bool{p.events.contains{if case let .pocket(n,id)=$0.kind{return n==name && id=="pocket_\(pocket)"};return false}}
    func path(_ p:ShotPrediction,_ name:String)->[[Float]]{
        let end=p.events.first{if case let .pocket(n,_)=$0.kind{return n==name};return false}?.time ?? Float.infinity
        return (p.recorder?.framesByBallName[name] ?? []).filter{$0.time<=end}.map{xy($0.position)}
    }
    func info(_ p:ShotPrediction,_ pocket:Int)->[String:Any]{
        var rails:[Int]=[],jaw=0,before=0,contacts=0,objectRails=0,otherHit=false
        for e in p.events {switch e.kind{
        case let .ballBall(a,b):contacts+=1;if a=="second" || b=="second" {otherHit=true}
        case let .ballCushion(ball):
            if ball==ShotInput.cueBallName {if contacts==0{before+=1};if let i=e.cushionIndex,i<6{rails.append(i)}else{jaw+=1}}
            if ball==ShotInput.targetBallName{objectRails+=1}
        default:break}}
        let ok=p.hasFinalTableState && pot(p,ShotInput.targetBallName,pocket) && !p.cuePocketed && before==0 && jaw==0 && contacts==1 && objectRails==0 && !otherHit
        var r:[String:Any]=["accepted":ok,"pot":pot(p,ShotInput.targetBallName,pocket),"scratch":p.cuePocketed,"settled":p.hasFinalTableState,"rails":rails,"jaw":jaw,"before":before,"contacts":contacts,"objectRails":objectRails,"otherHit":otherHit]
        if let stop=p.finalPositions[ShotInput.cueBallName]{r["stop"]=xy(stop);r["clearance"]=SceneTrainingRailGeometry.clearance(stop)}
        r["cuePath"]=path(p,ShotInput.cueBallName);r["objectPath"]=path(p,ShotInput.targetBallName)
        return r
    }
    func testExperiment()throws{
        let req=try read("request.json"),sample=try read("sample.json")
        func sv(_ key:String)->SCNVector3 {let p=sample[key] as! [String:Double];return SCNVector3(Float(p["x"]!),0,Float(p["z"]!))}
        let cue=sv("cue"),object=sv("target"),pocket=sample["pocket"] as! Int
        let mode=req["mode"] as! String
        var results:[[String:Any]]=[]
        for route in req["routes"] as! [[String:Any]] {
            let dir=v(route["direction"] as! [Double]),sx=Float(route["sx"] as! Double),sy=Float(route["sy"] as! Double),key=route["key"] as! String
            let speeds=(route["speeds"] ?? req["speeds"]) as! [Double]
            for speed in speeds {
                if mode=="scan" {
                    let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:Float(speed),spinX:sx,spinY:sy,surfaceY:0,balls:[ObstacleBall(name:ShotInput.targetBallName,position:object)],maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:dir)
                    var row=info(p,pocket);row["key"]=key;row["v"]=speed;row["direction"]=xy(p.strikeDirection!);results.append(row)
                    XCTAssertEqual(xy(p.strikeDirection!),xy(dir))
                    if abs(speed-4.5)<0.000001 {let stop=v(route["stop"] as! [Double]);let actual=p.finalPositions[ShotInput.cueBallName]!;XCTAssertLessThan(hypot(actual.x-stop.x,actual.z-stop.z),0.0001);XCTAssertEqual(row["rails"] as! [Int],route["rails"] as! [Int])}
                } else {
                    for point in route["points"] as! [[Double]] {
                        let second=v(point)
                        let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:Float(speed),spinX:sx,spinY:sy,surfaceY:0,balls:[ObstacleBall(name:ShotInput.targetBallName,position:object),ObstacleBall(name:"second",position:second)],maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:dir)
                        var row=info(p,pocket);row.removeValue(forKey:"cuePath");row.removeValue(forKey:"objectPath")
                        row["key"]=key;row["v"]=speed;row["point"]=point
                        var witness:[String:Any]?=nil;var attempts=0
                        if row["accepted"] as! Bool,let stop=p.finalPositions[ShotInput.cueBallName],let next=p.finalPositions["second"],hypot(next.x-second.x,next.z-second.z)<0.00001 {
                            for tip:Float in [0,0.25,-0.25] {
                                for speed2:Float in [1,1.5,2,2.5] {
                                    attempts+=1
                                    let input=ShotInput(cueBall:stop,targetBall:next,pocketIndex:1,velocity:speed2,spinX:0,spinY:tip,surfaceY:0)
                                    let p2=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
                                    guard let aim=p2.strikeDirection else{continue}
                                    let access=CueStrikeAccess(cue:SCNVector3(stop.x,BallPhysics.radius,stop.z),aim:aim,obstacles:[SCNVector3(next.x,BallPhysics.radius,next.z)],surfaceY:0)
                                    let check=info(p2,1)
                                    if check["accepted"] as! Bool,access.isAvailable(spinX:0,spinY:Double(tip)) {
                                        witness=["v":speed2,"sy":tip,"direction":xy(aim),"stop":xy(p2.finalPositions[ShotInput.cueBallName]!),"access":true];break
                                    }
                                };if witness != nil{break}
                            }
                        }
                        row["secondAttempts"]=attempts
                        if row["accepted"] as! Bool {XCTAssertGreaterThan(attempts,0)}
                        row["secondPass"]=witness != nil;row["secondWitness"]=witness ?? [:];results.append(row)
                    }
                }
            }
            try write("\(mode)-results.json",["rows":results]);print("TOLERANCE \(mode) \(key) rows=\(results.count)")
        }
        XCTAssertFalse(results.isEmpty)
    }
}
