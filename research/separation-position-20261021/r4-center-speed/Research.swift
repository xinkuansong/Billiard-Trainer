final class CenterSpeedResearchTests: XCTestCase {
    func testResearch() throws {
        let out=URL(fileURLWithPath:"/Users/song/projects/13.billiard_trainer/research/separation-position-20261021/r4-center-speed")
        func xy(_ p:SCNVector3)->[Float]{[p.x,p.z]}
        let req=try JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent("request.json"))) as! [String:Any]
        func vec(_ key:String)->SCNVector3 {let a=req[key] as! [Double];return SCNVector3(Float(a[0]),0,Float(a[1]))}
        let cue=vec("cue"),target=vec("target"),dir=vec("direction")
        var rows:[[String:Any]]=[]
        for speed in req["speeds"] as! [Double] {
            let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:dir,velocity:Float(speed),spinX:0,spinY:0,surfaceY:0,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxEvents:1500,maxTime:60,includePresentation:false,recordedStrikeDirection:dir)
            XCTAssertEqual(xy(p.strikeDirection!),xy(dir));XCTAssertTrue(p.hasFinalTableState)
            let hit=p.events.first{if case .ballBall=$0.kind{return true};return false}?.time
            func frames(_ name:String)->[BallFrame]{let end=p.events.first{if case let .pocket(n,_)=$0.kind{return n==name};return false}?.time ?? Float.infinity;return (p.recorder?.framesByBallName[name] ?? []).filter{$0.time<=end}}
            let cf=frames(ShotInput.cueBallName),of=frames(ShotInput.targetBallName)
            let rails=p.events.compactMap{e -> Int? in if case let .ballCushion(n)=e.kind,n==ShotInput.cueBallName,let i=e.cushionIndex,i<6{return i};return nil}
            let pot=p.events.contains{if case let .pocket(n,id)=$0.kind{return n==ShotInput.targetBallName && id=="pocket_2"};return false}
            let post=cf.filter{$0.time >= (hit ?? Float.infinity)}
            var length:Float=0;for (a,b) in zip(post,post.dropFirst()){length+=hypot(b.position.x-a.position.x,b.position.z-a.position.z)}
            let stop=p.finalPositions[ShotInput.cueBallName]!
            var row:[String:Any]=["v":speed,"sx":0,"sy":0,"direction":xy(p.strikeDirection!),"rails":rails,"pot":pot,"scratch":p.cuePocketed,"settled":p.hasFinalTableState,"cuePath":cf.map{xy($0.position)},"objectPath":of.map{xy($0.position)},"cueTimes":cf.map{$0.time},"stop":xy(stop),"length":length,"gap":SceneTrainingRailGeometry.clearance(stop)]
            if let h=hit {row["hitTime"]=h;row["contact"]=xy(post.first!.position)}
            rows.append(row)
        }
        XCTAssertEqual(rows.count,13)
        try JSONSerialization.data(withJSONObject:["rows":rows],options:[.sortedKeys]).write(to:out.appendingPathComponent("results.json"),options:.atomic)
        print("CENTER_SPEED_RESEARCH rows=\(rows.count) fixed spinX=0 spinY=0 direction=\(xy(dir))")
    }
}
