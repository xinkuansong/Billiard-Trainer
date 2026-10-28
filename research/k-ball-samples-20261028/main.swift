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
func verify(_ row:[String:Any]) throws -> [String:Any] {
    let seed = try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:row["seed"]!))
    let b = (row["B"] as! [Double]).map(Float.init)
    guard let p = simulate(seed,b), evaluate(p,seed.pocket).0 == nil else { throw NSError(domain:"replay-failed",code:1) }
    let outcome = evaluate(p,seed.pocket)
    let actual = events(p)
    let exact = try JSONSerialization.data(withJSONObject:actual,options:.sortedKeys) == JSONSerialization.data(withJSONObject:row["events"]!,options:.sortedKeys)
    guard exact, outcome.3 == row["railsBeforeK"] as! [Int] else { throw NSError(domain:"replay-drift",code:2) }
    var perturbations = [[String:Any]]()
    for axis in ["aim", "speed", "sx", "sy"] {
        for sign:Float in [-1,1] {
            let angle = atan2(seed.dir[1],seed.dir[0]) + (axis == "aim" ? sign * Float.pi / 1800 : 0)
            let d = axis == "aim" ? SCNVector3(cos(angle),0,sin(angle)) : SCNVector3(seed.dir[0],0,seed.dir[1])
            let pp = simulate(seed,b,direction:d,speed:seed.v * (axis == "speed" ? 1+sign*0.03 : 1),
                              sx:seed.sx+(axis == "sx" ? sign*0.02 : 0),sy:seed.sy+(axis == "sy" ? sign*0.02 : 0))
            let reason = pp.map { evaluate($0,seed.pocket).0 } ?? "inaccessible"
            perturbations.append(["axis":axis,"sign":Double(sign),"success":reason == nil,"reason":reason as Any? ?? NSNull()])
        }
    }
    return ["id":row["id"]!,"exactReplay":exact,"success":true,"perturbations":perturbations]
}
do {
    let args = CommandLine.arguments
    if args[1] == "verify" {
        let rows = try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [[String:Any]]
        let results = try rows.map { row in try autoreleasepool { try verify(row) } }
        try writeJSON(results,args[3]); print("VERIFIED \(results.count)");exit(0)
    }
    let seeds = try JSONDecoder().decode([Seed].self,from:Data(contentsOf:URL(fileURLWithPath:args[2])))
    var samples = [[String:Any]](), counts = [0,0,0], rejections:[String:Int] = [:], used = Set<String>(), trials = 0
    for (si,s) in seeds.enumerated() {
        if counts.allSatisfy({$0>=10}) { break }
        if used.contains(s.layout) { continue }
        try autoreleasepool {
            guard let base = simulate(s,nil), base.hasFinalTableState,
                  let first = base.events.first(where: { collision($0,cueName,aName) }),
                  base.pocketedBalls.contains(aName) else { return }
            let playback = TrajectoryPlayback(recorder:base.recorder!,surfaceY:surface+radius)
            let end = min(base.duration,Float(12))
            guard end > first.time+0.25 else { return }
            // Place B along the cue's actual post-A path. This is only a candidate proposal.
            for step in 1...40 {
                let t = first.time + (end-first.time)*Float(step)/41
                guard let state = playback.stateAt(ballName:cueName,time:t) else { continue }
                let pos = state.position
                guard abs(pos.x)<TablePhysics.innerLength/2-radius-0.01,
                      abs(pos.z)<TablePhysics.innerWidth/2-radius-0.01,
                      hypot(pos.x-s.cue[0],pos.z-s.cue[1])>2*radius+0.01,
                      hypot(pos.x-s.object[0],pos.z-s.object[1])>2*radius+0.05 else { continue }
                let b:[Float]=[pos.x,pos.z]
                trials += 1
                guard let p = simulate(s,b) else { rejections["inaccessible",default:0]+=1;continue }
                let (reason,firstIndex,hitIndex,rails) = evaluate(p,s.pocket)
                if let reason { rejections[reason,default:0]+=1;continue }
                let bucket = min(rails.count,2)
                guard counts[bucket]<10 else { continue }
                // Representative single-K samples avoid incidental A-B hits, pre-A rails and jaw routes.
                let unclear = p.events[..<hitIndex].enumerated().contains { i,e in
                    if collision(e,aName,bName) { return true }
                    if case let .ballCushion(ball) = e.kind, ball == cueName {
                        return i<firstIndex || (e.cushionIndex ?? 99)>=6
                    }
                    return false
                }
                guard !unclear else { rejections["sample-incidental-contact",default:0]+=1;continue }
                let rawSeed = try JSONSerialization.jsonObject(with:JSONEncoder().encode(s))
                let row:[String:Any] = ["id":String(format:"K%03d",samples.count+1),"seed":rawSeed,"B":b.map(Double.init),
                    "category":bucket,"railsBeforeK":rails,"firstAEvent":firstIndex,"firstBEvent":hitIndex,
                    "events":events(p),"tracks":tracks(p),"duration":Double(p.duration),"termination":String(describing:p.termination!),
                    "finalPositions":p.finalPositions.mapValues(point),"pocketedBalls":p.pocketedBalls,
                    "candidateTime":Double(t),"BDisplacementMeters":hypot(Double(p.finalPositions[bName]!.x-pos.x),Double(p.finalPositions[bName]!.z-pos.z))]
                samples.append(row);counts[bucket]+=1;used.insert(s.layout)
                try writeJSON(samples,args[3]);print("ACCEPT \(samples.count) categories=\(counts) seed=\(si)");fflush(stdout)
                break
            }
        }
    }
    try writeJSON(["counts":counts,"trials":trials,"rejections":rejections,"samples":samples.count,
                   "surfaceY":Double(surface),"radius":Double(radius),"table":[Double(TablePhysics.innerLength),Double(TablePhysics.innerWidth)],
                   "pockets":AngleSceneCalculator.pocketPositions(surfaceY:surface).map(point),
                   "model":String(describing:EventDrivenEngine.SimulationModel.appDefault)],args[4])
    guard counts.allSatisfy({$0>=10}) else { throw NSError(domain:"insufficient-samples",code:samples.count) }
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
