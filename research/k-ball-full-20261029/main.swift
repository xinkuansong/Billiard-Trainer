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

let baselineProbe:[String:Any] = ["id":"baseline","level":"baseline","kind":"baseline","axis":"none","delta":[0.0,0.0,0.0,0.0]]
var simulations = 0
func trial(_ seed: Seed, _ b: [Float], _ probe: [String:Any]) -> [String:Any] {
    let delta=(probe["delta"] as! [Double]).map(Float.init)
    let theta=atan2(seed.dir[1],seed.dir[0])+delta[0]*Float.pi/180
    let aim=delta[0]==0 ? SCNVector3(seed.dir[0],0,seed.dir[1]) : SCNVector3(cos(theta),0,sin(theta))
    let v=seed.v*(1+delta[1]),sx=seed.sx+delta[2],sy=seed.sy+delta[3]
    var result:[String:Any] = ["probeID":probe["id"]!,"input":["dir":point(aim),"v":Double(v),"sx":Double(sx),"sy":Double(sy)]]
    if let p=simulate(seed,b,direction:aim,speed:v,sx:sx,sy:sy) {
        result.merge(outcome(p,pocket:seed.pocket)) { _,new in new }
    } else {
        result.merge(["success":false,"reasons":["inaccessible"],"complete":false,"firstA":false,"potA":false,"laterB":false,"scratch":false,"railsBeforeK":[Int](),"events":[[String:Any]]()]) { _,new in new }
    }
    simulations += 1
    return result
}

do {
    let args=CommandLine.arguments
    let jobs=try String(contentsOfFile:args[1]).split(separator:"\n")
    let protocolData=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [String:Any]
    let probes=protocolData["probes"] as! [[String:Any]]
    guard !FileManager.default.fileExists(atPath:args[3]) else { throw NSError(domain:"output-exists",code:1) }
    guard FileManager.default.createFile(atPath:args[3],contents:nil) else { throw NSError(domain:"create-output",code:1) }
    let file=try FileHandle(forWritingTo:URL(fileURLWithPath:args[3]))
    for (number,line) in jobs.enumerated() {
        try autoreleasepool {
            let job=try JSONSerialization.jsonObject(with:Data(line.utf8)) as! [String:Any]
            let seed=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:job["seed"]!))
            var attempted=[[String:Any]](),selected=[[String:Any]](),untested=[String]()
            for group in job["groups"] as! [[String:Any]] {
                let candidates=group["candidates"] as! [[String:Any]]
                var winner:[String:Any]? = nil
                var winningGrade=0, winningSmallJoint = -1
                var searchFinished=false
                for candidate in candidates {
                    if searchFinished { untested.append(candidate["id"] as! String);continue }
                    let b=(candidate["B"] as! [Double]).map(Float.init)
                    let baseline=autoreleasepool { trial(seed,b,baselineProbe) }
                    var results=[baseline],grade=0,smallJoint = -1
                    let expected=candidate["expectedRails"] as! Int
                    let reference=Array((job["referenceRailIDs"] as! [Int]).prefix(expected))
                    let nominalMatch=(baseline["railsBeforeK"] as! [Int]) == reference
                    if baseline["success"] as! Bool && nominalMatch {
                        for (levelIndex,level) in ["small","medium","large"].enumerated() {
                            var axisFail=false,jointFail=0,jointPass=0
                            for probe in probes where probe["level"] as! String == level {
                                let r=autoreleasepool { trial(seed,b,probe) };results.append(r)
                                let ok=r["success"] as! Bool
                                if probe["kind"] as! String == "axis" && !ok { axisFail=true;break }
                                if probe["kind"] as! String == "joint" {
                                    if ok { jointPass+=1 } else { jointFail+=1 }
                                    if jointFail>6 { break }
                                }
                            }
                            if level == "small" { smallJoint=jointPass }
                            if axisFail || jointFail>6 { break }
                            guard jointPass+jointFail==32 else { throw NSError(domain:"missing-probes",code:1) }
                            grade=levelIndex+1
                        }
                    }
                    let record:[String:Any] = ["id":candidate["id"]!,"nominalRouteMatch":nominalMatch,"grade":grade,"smallJointPass":smallJoint,"results":results]
                    attempted.append(record)
                    if grade>winningGrade || (grade==winningGrade && grade>0 && smallJoint>winningSmallJoint) {
                        winningGrade=grade;winningSmallJoint=smallJoint
                        winner=["candidate":candidate,"grade":grade,"baseline":baseline]
                    }
                    if grade>=2 { searchFinished=true }
                }
                if var winner {
                    let candidate=winner["candidate"] as! [String:Any]
                    let b=(candidate["B"] as! [Double]).map(Float.init)
                    guard let p=simulate(seed,b) else { throw NSError(domain:"selected-replay-inaccessible",code:1) }
                    simulations+=1
                    let baseline=winner["baseline"] as! [String:Any]
                    let actual=try JSONSerialization.data(withJSONObject:events(p),options:.sortedKeys)
                    let expected=try JSONSerialization.data(withJSONObject:baseline["events"]!,options:.sortedKeys)
                    guard actual==expected else { throw NSError(domain:"selected-replay-drift",code:1) }
                    winner["tracks"]=tracks(p);winner["exactReplay"]=true
                    selected.append(winner)
                }
            }
            let result:[String:Any] = ["key":job["key"]!,"attempted":attempted,"selected":selected,"untestedAfterGoodCandidate":untested]
            var data=try JSONSerialization.data(withJSONObject:result,options:.sortedKeys);data.append(10);try file.write(contentsOf:data)
        }
        if number%50==0 || number==jobs.count-1 {
            print("FULL \(number+1)/\(jobs.count) simulations=\(simulations)");fflush(stdout);try file.synchronize()
        }
    }
    try file.close()
    print("DONE \(jobs.count) routes \(simulations) simulations")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
