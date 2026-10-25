
final class SeparationPositionResearchTests: XCTestCase {
    let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/research/separation-position-20261021")
    func xy(_ p: SCNVector3) -> [Float] { [p.x,p.z] }
    func vec(_ p: [String:Double]) -> SCNVector3 { SCNVector3(Float(p["x"]!),0,Float(p["z"]!)) }
    func pot(_ p: ShotPrediction, _ pocket: Int) -> Bool {
        p.events.contains { if case let .pocket(ball,id) = $0.kind { return ball == ShotInput.targetBallName && id == "pocket_\(pocket)" }; return false }
    }
    func write(_ name: String,_ value: Any) throws {
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]).write(to:out.appendingPathComponent(name),options:.atomic)
    }
    func testResearch() throws {
        let sample = try JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent("sample.json"))) as! [String:Any]
        let cue=vec(sample["cue"] as! [String:Double]), target=vec(sample["target"] as! [String:Double]), pocket=sample["pocket"] as! Int
        let aim=AngleSceneCalculator.effectivePocketAimPoint(targetBall:target,pocketIndex:pocket,surfaceY:0)
        let angle=AngleSceneCalculator.cutAngle(cueBall:cue,targetBall:target,pocket:aim)
        let speeds:[Float]=[0.75,1,1.5,2,2.5,3,3.5,4,4.5,5,6,7,8]
        let tips:[Float]=[-0.5,-0.25,0,0.25,0.5]
        var rows:[[String:Any]]=[], accepted:[(ShotInput,ShotPrediction,Int)]=[]
        for sx in tips { for sy in tips where hypot(sx,sy)<=CuePhysics.miscueLimitFraction+0.000001 { for v in speeds {
            let input=ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:v,spinX:sx,spinY:sy,surfaceY:0)
            let p=ShotPredictor.predict(input,maxEvents:1500,maxTime:60)
            var rails:[Int]=[], jaw=0, before=0, contacts=0
            for e in p.events {
                switch e.kind {
                case .ballBall: contacts+=1
                case let .ballCushion(ball):
                    if ball==ShotInput.cueBallName { if contacts==0 {before+=1}; if let i=e.cushionIndex,i<6 {rails.append(i)} else {jaw+=1} }
                default: break
                }
            }
            let ok=p.hasFinalTableState && pot(p,pocket) && !p.cuePocketed && before==0 && jaw==0 && contacts==1 && p.objectCushionCount==0
            var row:[String:Any]=["id":rows.count,"v":v,"sx":sx,"sy":sy,"settled":p.hasFinalTableState,"pot":pot(p,pocket),"scratch":p.cuePocketed,"rails":rails,"jaw":jaw,"before":before,"contacts":contacts,"accepted":ok,"termination":String(describing:p.termination)]
            if ok,let stop=p.finalPositions[ShotInput.cueBallName] {
                row["stop"]=xy(stop);row["cuePath"]=p.cuePath.map(xy);row["objectPath"]=p.objectPath.map(xy);row["direction"]=xy(p.strikeDirection!);row["duration"]=p.duration
                row["contact"]=p.firstContact.map(xy)
                accepted.append((input,p,rows.count))
            }
            rows.append(row)
        } } }
        try write("scan.json",["cue":xy(cue),"target":xy(target),"pocket":pocket,"effectiveAim":xy(aim),"actualAngle":angle,"rows":rows])
        XCTAssertFalse(accepted.isEmpty)
        // Fixed second-ball grid, with the production effective aim point for each pocket.
        var grid:[[String:Any]]=[]
        for ix in 0...80 { for iz in 0...40 {
            let o=SCNVector3(-1.20+Float(ix)*0.03,0,-0.60+Float(iz)*0.03)
            var aims:[[Float]]=[]
            for k in 0..<6 { aims.append(xy(AngleSceneCalculator.effectivePocketAimPoint(targetBall:o,pocketIndex:k,surfaceY:0))) }
            grid.append(["p":xy(o),"aims":aims])
        } }
        try write("grid.json",grid)
        // Keep up to three contrasting actual routes per main-rail-count for review.
        var chosen:[(ShotInput,ShotPrediction,Int)]=[]
        for count in 0...5 {
            let pool=accepted.filter { min(5,($0.1.events.filter { e in if case let .ballCushion(ball)=e.kind { return ball==ShotInput.cueBallName && (e.cushionIndex ?? 99)<6 };return false }).count)==count }
            var group:[(ShotInput,ShotPrediction,Int)]=[]
            if let first=pool.min(by: { $0.0.velocity < $1.0.velocity }) { group.append(first) }
            while group.count<3 {
                let rest=pool.filter { c in !group.contains(where:{$0.2==c.2}) }
                guard let next=rest.max(by: { a,b in
                    func distance(_ c:(ShotInput,ShotPrediction,Int))->Float { group.map { ($0.1.finalPositions[ShotInput.cueBallName]!-c.1.finalPositions[ShotInput.cueBallName]!).length() }.min()! }
                    return distance(a)<distance(b)
                }) else { break }
                group.append(next)
            }
            chosen+=group
        }
        try write("selected.json",chosen.map{$0.2})
        print("RESEARCH_SCAN trials=\(rows.count) accepted=\(accepted.count) selected=\(chosen.count) angle=\(angle)")
    }
}
