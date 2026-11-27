import Foundation
import SceneKit

struct Seed: Codable {
    let layout: String
    let route: Int
    let cue, object, dir: [Float]
    let pocket: Int
    let v, sx, sy: Float
}
let cueName = ShotInput.cueBallName
let aName = ShotInput.targetBallName
let bName = "kTarget"
let surface = BTTablePhysics.surfaceY
let radius = BallPhysics.radius
let profile = AccuracyTipSelector.renderedProfile()
func vector(_ p: [Float]) -> SCNVector3 { .init(p[0], surface + radius, p[1]) }
func point(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
func writeJSON(_ value: Any, _ path: String) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: URL(fileURLWithPath: path), options: .atomic)
}
func simulate(_ s: Seed, _ b: [Float]?, direction: SCNVector3? = nil, speed: Float? = nil,
              sx: Float? = nil, sy: Float? = nil, blockers: [[Float]] = []) -> ShotPrediction? {
    let d = direction ?? vector(s.dir)
    let aim = SCNVector3(d.x, 0, d.z)
    var balls = [ObstacleBall(name: aName, position: vector(s.object))]
    if let b { balls.append(.init(name: bName, position: vector(b))) }
    for (i,p) in blockers.enumerated() { balls.append(.init(name: "block_\(i)", position: vector(p))) }
    let x = sx ?? s.sx, y = sy ?? s.sy
    let access = CueStrikeAccess(cue: vector(s.cue), aim: aim, obstacles: balls.map(\.position), surfaceY: surface, profile: profile)
    guard access.isAvailable(spinX: Double(x), spinY: Double(y)),
          access.resolvedPose(spinX: Double(x), spinY: Double(y)) != nil else { return nil }
    return ShotPredictor.simulateFree(cueBall: vector(s.cue), aimDir: aim, velocity: speed ?? s.v,
        spinX: x, spinY: y, surfaceY: surface, balls: balls, maxEvents: 1500, maxTime: 60,
        recordedStrikeDirection: aim)
}
func collision(_ event: ShotEvent, _ a: String, _ b: String) -> Bool {
    if case let .ballBall(x,y) = event.kind { return Set([x,y]) == Set([a,b]) }
    return false
}
// Ordered event indices preserve ordering even when two events share a timestamp.
func evaluate(_ p: ShotPrediction, _ pocket: Int) -> (String?, Int, Int, [Int]) {
    guard p.hasFinalTableState, let recorder = p.recorder,
          p.finalPositions.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else { return ("incomplete", -1,-1,[]) }
    guard recorder.firstBallContacts[cueName]?.other.name == aName,
          let first = p.events.firstIndex(where: { collision($0,cueName,aName) }) else { return ("wrong-first-ball",-1,-1,[]) }
    guard let hit = p.events.indices.first(where: { $0 > first && collision(p.events[$0],cueName,bName) }) else { return ("no-cue-B-contact",first,-1,[]) }
    guard p.events.contains(where: { if case let .pocket(ball,id) = $0.kind { return ball == aName && id == "pocket_\(pocket)" }; return false }) else { return ("A-not-in-specified-pocket",first,hit,[]) }
    var rails = [Int]()
    for i in (first+1)..<hit {
        if case let .ballCushion(ball) = p.events[i].kind, ball == cueName,
           let id = p.events[i].cushionIndex, id < 6 { rails.append(id) }
    }
    return (nil,first,hit,rails)
}
func events(_ p: ShotPrediction) -> [[String:Any]] {
    p.events.enumerated().map { i,e in
        var row:[String:Any] = ["index":i,"time":Double(e.time)]
        switch e.kind {
        case let .ballBall(a,b): row["kind"]="ballBall";row["balls"]=[a,b]
        case let .ballCushion(ball): row["kind"]="cushion";row["ball"]=ball;row["cushion"]=e.cushionIndex ?? -1
        case let .pocket(ball,id): row["kind"]="pocket";row["ball"]=ball;row["pocket"]=id
        }
        return row
    }
}
func tracks(_ p: ShotPrediction) -> [String:[[Double]]] {
    let playback = TrajectoryPlayback(recorder:p.recorder!,surfaceY:surface+radius)
    var result:[String:[[Double]]] = [:]
    for name in [cueName,aName,bName] {
        let end = p.events.first(where: { if case let .pocket(ball,_) = $0.kind { return ball == name };return false })?.time ?? p.duration
        var times = Set((0...Int(ceil(Double(end)*60))).map { min(end,Float($0)/60) })
        for e in p.events where e.time <= end { times.insert(e.time) }
        result[name] = times.sorted().compactMap { t in
            guard let state = playback.stateAt(ballName:name,time:t) else { return nil }
            return [Double(t),Double(state.position.x),Double(state.position.z)]
        }
    }
    return result
}
func outcome(_ p: ShotPrediction, pocket: Int) -> [String:Any] {
    let ev=p.events
    let hits=ev.indices.filter { i in if case let .ballBall(a,b)=ev[i].kind { return a==cueName || b==cueName };return false }
    let firstA=hits.first.map { collision(ev[$0],cueName,aName) } ?? false
    let first=hits.first ?? -1
    let hit=hits.first { $0>first && collision(ev[$0],cueName,bName) }
    let laterB=firstA && hit != nil
    let potA=ev.contains { e in if case let .pocket(ball,id)=e.kind { return ball==aName && id=="pocket_\(pocket)" };return false }
    let scratch=p.pocketedBalls.contains(cueName)
    let complete=p.hasFinalTableState && p.finalPositions.values.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
    let ok=complete && firstA && laterB && potA
    var reasons=[String]()
    if !complete { reasons.append("incomplete") }
    if !firstA { reasons.append("wrong-first-ball") }
    if !laterB { reasons.append("no-cue-B-contact") }
    if !potA { reasons.append("A-not-in-specified-pocket") }
    var rails=[Int]()
    if firstA, let hit {
        for i in (first+1)..<hit {
            if case let .ballCushion(ball)=ev[i].kind, ball==cueName,
               let id=ev[i].cushionIndex, id<6 { rails.append(id) }
        }
    }
    return ["success":ok,"reasons":reasons,"complete":complete,"firstA":firstA,"potA":potA,"laterB":laterB,"scratch":scratch,"railsBeforeK":rails,"events":events(p),"duration":Double(p.duration)]
}

// Same observed-rail semantics as KBallJudgement; B keeps its fixed associated wall.
func observed(_ p: ShotPrediction, _ railID: Int) -> Int? {
    guard (0..<6).contains(railID),
          let first = p.events.firstIndex(where:{ collision($0,cueName,aName) }),
          let hit = p.events.firstIndex(where:{ collision($0,cueName,bName) }), first < hit,
          let contact = p.recorder?.firstBallContacts[bName], contact.other.name == cueName,
          abs(contact.time-p.events[hit].time)<0.00001 else { return nil }
    let v=contact.other.velocity
    guard v.x.isFinite, v.z.isFinite, v.x*v.x+v.z*v.z>0 else { return nil }
    let cushions=TableGeometry.chineseEightBallCushions(y:0).linear, n=cushions[railID].normal
    var rails=[Int]()
    for e in p.events[(first+1)..<hit] {
        if case let .ballCushion(ball)=e.kind, ball==cueName {
            guard let id=e.cushionIndex,id>=0 else{return nil}
            if id<6 {rails.append(id)}
        }
    }
    if v.x*n.x+v.z*n.z<0 { return rails.count+1 }
    guard let last=rails.last,cushions[last].normal.dot(n)>0.99 else{return 0}
    return rails.count
}
do {
    let args=CommandLine.arguments
    let lines=try String(contentsOfFile:args[1]).split(separator:"\n")
    guard !FileManager.default.fileExists(atPath:args[2]), FileManager.default.createFile(atPath:args[2],contents:nil) else {throw NSError(domain:"output-exists",code:1)}
    let f=try FileHandle(forWritingTo:URL(fileURLWithPath:args[2]))
    for (index,line) in lines.enumerated() {
        try autoreleasepool {
            let j=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any]
            let seed=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:j["seed"]!))
            let b=(j["B"] as! [Double]).map(Float.init), blockers=(j["blockers"] as? [[Double]] ?? []).map{$0.map(Float.init)}
            var r:[String:Any] = ["id":j["id"]!,"success":false,"reason":"inaccessible"]
            if let p=simulate(seed,b,blockers:blockers) {
                r.merge(outcome(p,pocket:seed.pocket)){_,new in new};r.removeValue(forKey:"reason")
                let hit=p.events.firstIndex(where:{collision($0,cueName,bName)})
                let pot=p.events.firstIndex(where:{if case let .pocket(ball,id)=$0.kind{return ball==aName && id=="pocket_\(seed.pocket)"};return false})
                let cutoff=max(hit ?? p.events.count,pot ?? p.events.count)
                let touched=p.events.enumerated().contains { i,e in
                    guard i<=cutoff else{return false}
                    if case let .ballBall(a,b)=e.kind {
                        return ((a==cueName || a==aName) && b.hasPrefix("block_")) || ((b==cueName || b==aName) && a.hasPrefix("block_"))
                    };return false
                }
                r["obstacleContactBeforeCompletion"]=touched
                r["success"]=(r["success"] as! Bool) && !touched
                r["observedRail"]=observed(p,j["railID"] as! Int) ?? -1
                if let c=p.recorder?.firstBallContacts[bName] {
                    r["BFirstContact"]=["time":Double(c.time),"other":c.other.name,"velocity":point(c.other.velocity)] as [String:Any]
                }
                if j["tracks"] as? Bool == true {r["tracks"]=tracks(p)}
            }
            var data=try JSONSerialization.data(withJSONObject:r,options:.sortedKeys);data.append(10);try f.write(contentsOf:data)
        }
        if index%100==0 {print("PROGRESS \(index+1)/\(lines.count)");fflush(stdout)}
    }
    try f.close();print("DONE \(lines.count)")
} catch {fputs("ERROR \(error)\n",stderr);exit(1)}
