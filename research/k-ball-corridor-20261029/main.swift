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
    return ["id":row["id"]!,"exactReplay":exact,"success":true]

}
let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: surface)
func gap(_ xy: [Double]) -> Double {
    geometry.linearCushions.prefix(6).map { rail in
        let a=point(rail.start),b=point(rail.end),dx=b[0]-a[0],dz=b[1]-a[1]
        let u=max(0,min(1,((xy[0]-a[0])*dx+(xy[1]-a[1])*dz)/(dx*dx+dz*dz)))
        return hypot(xy[0]-a[0]-u*dx,xy[1]-a[1]-u*dz)-Double(radius)
    }.min()!
}
do {
    let args=CommandLine.arguments
    if args[1] == "geometry" {
        try writeJSON(["radius":Double(radius),"length":Double(TablePhysics.innerLength),"width":Double(TablePhysics.innerWidth),
            "rails":geometry.linearCushions.prefix(6).enumerated().map { i,r in ["id":i,"start":point(r.start),"end":point(r.end),"normal":point(r.normal)] as [String:Any] },
            "pockets":geometry.pockets.map { ["id":$0.id,"center":point($0.center),"radius":Double($0.radius),"lip":$0.captureLip.map{[$0.x,$0.y]}] as [String:Any] }],args[2]);exit(0)
    }
    let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [[String:Any]]
    if args[1] == "verify" {
        var results=[[String:Any]]()
        for row in rows { results.append(try autoreleasepool { try verify(row) }) }
        try writeJSON(results,args[3]);print("VERIFIED \(results.count)");exit(0)
    }
    var results=[[String:Any]](), bases=[String:[String:Any]]()
    for (i,row) in rows.enumerated() {
        try autoreleasepool {
            let s=try JSONDecoder().decode(Seed.self,from:JSONSerialization.data(withJSONObject:row["seed"]!))
            let b=(row["B"] as! [Double]).map(Float.init)
            let key="\(s.layout)/\(s.route)"
            if bases[key] == nil {
                if let p=simulate(s,nil) {
                    bases[key] = ["complete":p.hasFinalTableState,"events":events(p),"tracks":tracks(p),"pocketedBalls":p.pocketedBalls,"duration":Double(p.duration)]
                } else { bases[key] = ["complete":false,"reason":"inaccessible"] }
            }
            var result=row
            guard let p=simulate(s,b) else { result["success"]=false;result["reason"]="inaccessible";results.append(result);return }
            let (reason,first,hit,rails)=evaluate(p,s.pocket)
            let failure=reason
            if hit >= 0 && first >= 0 {
                let t=max(0,p.events[hit].time-0.00001)
                let playback=TrajectoryPlayback(recorder:p.recorder!,surfaceY:surface+radius)
                if let state=playback.stateAt(ballName:cueName,time:t) {
                    let v=point(state.velocity),tan=row["tangent"] as! [Double]
                    let angle=atan2(abs(v[0]*tan[1]-v[1]*tan[0]),abs(v[0]*tan[0]+v[1]*tan[1]))*180/Double.pi
                    result["actualApproachAngle"]=angle;result["contactSpeed"]=hypot(v[0],v[1]);result["contactPosition"]=point(state.position)
                }
            }
            result["success"]=failure == nil;result["reason"]=failure as Any? ?? NSNull()
            result["railsBeforeK"]=rails;result["firstAEvent"]=first;result["firstBEvent"]=hit
            result["events"]=events(p);result["tracks"]=tracks(p);result["duration"]=Double(p.duration)
            result["finalPositions"]=p.finalPositions.mapValues(point);result["pocketedBalls"]=p.pocketedBalls
            result["complete"]=p.hasFinalTableState;result["termination"]=String(describing:p.termination)
            if let final=p.finalPositions[bName],!p.pocketedBalls.contains(bName) {
                result["finalBGap"]=gap(point(final));result["BDisplacementMeters"]=hypot(Double(final.x-b[0]),Double(final.z-b[1]))
            }
            results.append(result)
        }
        if i%10 == 0 { try writeJSON(results,args[3]);print("TRIAL \(i+1)/\(rows.count)");fflush(stdout) }
    }
    try writeJSON(results,args[3]);try writeJSON(bases,args[4])
    print("DONE \(results.count) passed=\(results.filter{$0["success"] as? Bool == true}.count)")
} catch { fputs("ERROR \(error)\n",stderr);exit(1) }
