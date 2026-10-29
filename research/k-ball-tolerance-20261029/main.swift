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
              sx: Float? = nil, sy: Float? = nil) -> ShotPrediction? {
    let d = direction ?? vector(s.dir)
    let aim = SCNVector3(d.x, 0, d.z)
    var balls = [ObstacleBall(name: aName, position: vector(s.object))]
    if let b { balls.append(.init(name: bName, position: vector(b))) }
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
    guard !p.pocketedBalls.contains(cueName) else { return ("scratch",first,hit,[]) }
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
    let ok=complete && firstA && laterB && potA && !scratch
    var reasons=[String]()
    if !complete { reasons.append("incomplete") }
    if !firstA { reasons.append("wrong-first-ball") }
    if !laterB { reasons.append("no-cue-B-contact") }
    if !potA { reasons.append("A-not-in-specified-pocket") }
    if scratch { reasons.append("scratch") }
    var rails=[Int]()
    if firstA, let hit {
        for i in (first+1)..<hit {
            if case let .ballCushion(ball)=ev[i].kind, ball==cueName,
               let id=ev[i].cushionIndex, id<6 { rails.append(id) }
        }
    }
    return ["success":ok,"reasons":reasons,"complete":complete,"firstA":firstA,"potA":potA,"laterB":laterB,"scratch":scratch,"railsBeforeK":rails,"events":events(p),"duration":Double(p.duration)]
}
do {
    let args=CommandLine.arguments
    let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[1]))) as! [[String:Any]]
    let protocolData=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [String:Any]
    let probes=protocolData["probes"] as! [[String:Any]]
    let baseline:[String:Any] = ["id":"baseline","level":"baseline","kind":"baseline","axis":"none","normalized":[0,0,0,0],"delta":[0.0,0.0,0.0,0.0]]
    FileManager.default.createFile(atPath:args[3],contents:nil)
    let file=try FileHandle(forWritingTo:URL(fileURLWithPath:args[3]));defer { try? file.close() }
    var total=0
    for (i,row) in rows.enumerated() {
        let seed=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:row["seed"]!))
        let b=(row["B"] as! [Double]).map(Float.init)
        let cases=[baseline]+((row["success"] as! Bool) ? probes : [])
        for probe in cases {
            try autoreleasepool {
                let delta=(probe["delta"] as! [Double]).map(Float.init)
                let theta=atan2(seed.dir[1],seed.dir[0])+delta[0]*Float.pi/180
                let aim=delta[0]==0 ? SCNVector3(seed.dir[0],0,seed.dir[1]) : SCNVector3(cos(theta),0,sin(theta))
                let v=seed.v*(1+delta[1]),sx=seed.sx+delta[2],sy=seed.sy+delta[3]
                var result:[String:Any] = ["sampleID":row["id"]!,"probeID":probe["id"]!,"input":["dir":point(aim),"v":Double(v),"sx":Double(sx),"sy":Double(sy)]]
                if let p=simulate(seed,b,direction:aim,speed:v,sx:sx,sy:sy) {
                    result.merge(outcome(p,pocket:seed.pocket)) { _,new in new }
                    if probe["id"] as! String == "baseline" {
                        let actual=try JSONSerialization.data(withJSONObject:events(p),options:.sortedKeys)
                        let expected=try JSONSerialization.data(withJSONObject:row["events"]!,options:.sortedKeys)
                        guard actual==expected, result["success"] as! Bool == row["success"] as! Bool else { throw NSError(domain:"baseline-drift",code:1,userInfo:["sample":row["id"]!]) }
                        result["exactBaselineReplay"]=true
                    }
                } else {
                    result.merge(["success":false,"reasons":["inaccessible"],"complete":false,"firstA":false,"potA":false,"laterB":false,"scratch":false,"railsBeforeK":[Int](),"events":[[String:Any]]()]) { _,new in new }
                    if probe["id"] as! String == "baseline" { throw NSError(domain:"baseline-access-drift",code:2) }
                }
                var line=try JSONSerialization.data(withJSONObject:result,options:.sortedKeys);line.append(10);try file.write(contentsOf:line)
            }
            total+=1
        }
        if i%5==0 || i==rows.count-1 { print("TOLERANCE \(i+1)/\(rows.count) simulations=\(total)");fflush(stdout);try file.synchronize() }
    }
    print("TOLERANCE DONE \(total)")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
