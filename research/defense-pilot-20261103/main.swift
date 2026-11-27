import Foundation
import SceneKit

// Research-only, one object ball. XZ metres, Y up; portrait plot: up +X, right +Z.
let surface = BTTablePhysics.surfaceY
let radius = BallPhysics.radius
let cueKey = ShotInput.cueBallName
let ballKey = "_8"
let table = TableGeometry.chineseEightBallQiuJi(surfaceY: surface)
func point(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
func vector(_ p: [Double]) -> SCNVector3 { SCNVector3(Float(p[0]), surface + radius, Float(p[1])) }
func write(_ x: Any, _ path: String) throws {
    try JSONSerialization.data(withJSONObject: x, options: [.sortedKeys, .prettyPrinted])
        .write(to: URL(fileURLWithPath: path), options: .atomic)
}
func gap(_ p: SCNVector3) -> Double {
    Double(min(TablePhysics.innerLength / 2 - abs(p.x), TablePhysics.innerWidth / 2 - abs(p.z)) - radius)
}
func placement(_ c: SCNVector3, _ b: SCNVector3) -> Bool {
    guard gap(c) >= 0.003, gap(b) >= 0.003,
          hypot(c.x-b.x, c.z-b.z) > 2 * radius + 0.03 else { return false }
    return [c,b].allSatisfy { p in table.pockets.allSatisfy {
        hypot(p.x-$0.center.x, p.z-$0.center.z) > $0.radius + radius + 0.05
    } }
}
func opportunities(_ c: SCNVector3, _ b: SCNVector3) -> [[String: Any]] {
    (0..<6).compactMap { index in
        guard let candidate = DailyShotRecommendation.candidate(cue: c, target: b,
            targetKey: ballKey, pocketIndex: index, obstacles: [], surfaceY: surface),
              let score = ShotComfortScore.evaluate(cue: (Double(c.x),Double(c.z)),
                ball: (Double(b.x),Double(b.z)), aim: (Double(candidate.aim.x),Double(candidate.aim.z))) else { return nil }
        return ["pocket": index, "aim": point(candidate.aim), "score": score.total,
                "distance": score.distance, "space": score.space, "angle": score.angle,
                "cutDegrees": Double(candidate.cutDegrees)] as [String: Any]
    }.sorted { ($0["score"] as! Double) > ($1["score"] as! Double) }
}
func bestComfort(_ rows: [[String: Any]]) -> Double? { rows.first?["score"] as? Double }
struct Stroke {
    let direction: SCNVector3
    let speed: Float
    let spinY: Float
    var json: [String: Any] { ["direction": point(direction), "speed": Double(speed), "spinX": 0, "spinY": Double(spinY)] }
}
func simulate(_ c: SCNVector3, _ b: SCNVector3, _ shot: Stroke) -> ShotPrediction {
    ShotPredictor.simulateFree(cueBall: c, aimDir: shot.direction, velocity: shot.speed,
        spinX: 0, spinY: shot.spinY, surfaceY: surface,
        balls: [ObstacleBall(name: ballKey, position: b)], maxEvents: 1500, maxTime: 60,
        recordedStrikeDirection: shot.direction)
}
func reject(_ p: ShotPrediction) -> String? {
    guard p.hasFinalTableState else { return "incomplete" }
    guard !p.cuePocketed, p.pocketedBalls.isEmpty else { return "pocketed" }
    guard let hit = p.events.first(where: { if case .ballBall = $0.kind { return true }; return false }),
          case let .ballBall(a,b) = hit.kind, Set([a,b]) == Set([cueKey,ballKey]) else { return "no-first-contact" }
    guard p.events.contains(where: { e in
        guard e.time > hit.time else { return false }
        if case .ballCushion = e.kind { return true }; return false
    }) else { return "no-rail-after-contact" }
    guard let c = p.finalPositions[cueKey], let b = p.finalPositions[ballKey],
          gap(c) > -0.00001, gap(b) > -0.00001,
          hypot(c.x-b.x,c.z-b.z) >= 2 * radius - 0.00001 else { return "invalid-final" }
    return nil
}
func eventRows(_ p: ShotPrediction) -> [[String: Any]] {
    p.events.map { e in
        var row: [String: Any] = ["time": Double(e.time)]
        switch e.kind {
        case let .ballBall(a,b): row["kind"] = "ballBall"; row["balls"] = [a,b]
        case let .ballCushion(b): row["kind"] = "cushion"; row["ball"] = b; row["index"] = e.cushionIndex ?? -1
        case let .pocket(b,id): row["kind"] = "pocket"; row["ball"] = b; row["pocket"] = id
        }
        return row
    }
}
func record(_ p: ShotPrediction, _ shot: Stroke) -> [String: Any] {
    let c = p.finalPositions[cueKey]!, b = p.finalPositions[ballKey]!
    let options = opportunities(c,b)
    var row: [String: Any] = ["shot": shot.json, "finalCue": point(c), "finalBlack": point(b),
        "settled": p.hasFinalTableState, "events": eventRows(p), "opportunities": options,
        "duration": Double(p.duration), "cueRailGap": gap(c), "blackRailGap": gap(b),
        "ballDistance": Double(hypot(c.x-b.x,c.z-b.z)), "pocketed": p.pocketedBalls]
    if let s = bestComfort(options) { row["defenseScore"] = 100-s }
    var tracks = [String: [[Double]]]()
    // Physical recorder frames, not an invented route or post-pocket animation.
    for name in [cueKey,ballKey] {
        tracks[name] = p.recorder!.framesByBallName[name]!.map {
            [Double($0.time),Double($0.position.x),Double($0.position.z)]
        }
    }
    row["tracks"] = tracks
    return row
}
struct Choice {
    let shot: Stroke
    let score: Double
    let prediction: ShotPrediction
}
func tactical(_ p: ShotPrediction) -> Bool {
    let c=p.finalPositions[cueKey]!, b=p.finalPositions[ballKey]!
    return hypot(c.x-b.x,c.z-b.z) >= 1.2 || gap(c) <= 0.04
}
func prefer(_ shot: Stroke, score: Double, prediction: ShotPrediction, over old: Choice) -> Bool {
    // Equal five-point effect bands: favour less spin, fewer cushion contacts, lower speed.
    let a=Int(min(99,score)/5), b=Int(min(99,old.score)/5)
    if a != b { return a>b }
    if abs(shot.spinY) != abs(old.shot.spinY) { return abs(shot.spinY)<abs(old.shot.spinY) }
    if prediction.cueCushionCount != old.prediction.cueCushionCount {
        return prediction.cueCushionCount < old.prediction.cueCushionCount
    }
    if shot.speed != old.shot.speed { return shot.speed<old.shot.speed }
    return score>old.score
}

do {
    let out = CommandLine.arguments[1]
    guard let model = TableModelLoader.loadTable(includeVisual: false), let node = model.cueStickNode else {
        throw NSError(domain: "real-cue-profile-unavailable", code: 1)
    }
    let profile = CueStick(modelCueStickNode: node).clearanceProfile
    precondition(!profile.isEmpty)
    try write(["length": Double(TablePhysics.innerLength), "width": Double(TablePhysics.innerWidth),
        "radius": Double(radius), "cueKey": cueKey,
        "pockets": table.pockets.map { ["id": $0.id,"center": point($0.center)] },
        "railSegments": table.linearCushions.prefix(6).map { ["start":point($0.start),"end":point($0.end)] },
        "cueProfileSections": profile.count], out + "/geometry.json")

    let seed = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: out + "/seed.json"))) as! [String: Any]
    let seedStep = seed["data"] as! [String: Any]
    let before = (seedStep["before"] as! [String: Any])["onTable"] as! [String: [String: Double]]
    func scene(_ p: [String: Double]) -> SCNVector3 { vector([(p["x"]!-0.5)*2.54,(p["y"]!-0.25)*2.54]) }
    let seedCue = scene(before["cueBall"]!), seedBlack = scene(before["_8"]!)
    // Finite, deterministic variations of c060 s03, plus a long-rail orientation.
    var layouts: [(String,SCNVector3,SCNVector3)] = [("c060-s03",seedCue,seedBlack)]
    for bx: Double in [-1.225,-1.19,-1.12] {
        for bz: Double in [-0.20,0,0.20] {
            for c in [[-0.78,-0.30],[-0.55,0.30],[0.1,-0.42],[0.65,0.22]] {
                layouts.append(("short-rail",vector(c),vector([bx,bz])))
            }
        }
    }
    for bx: Double in [-0.7,-0.25,0.25,0.7] {
        for c in [[-0.9,-0.25],[0.0,-0.25],[0.9,0.25]] {
            layouts.append(("long-rail",vector(c),vector([bx,0.59])))
        }
    }
    var selected = [[String: Any]](), inventory = [[String: Any]](), rejected = [String: Int]()
    var simulations = 0
    for (layoutIndex, layout) in layouts.enumerated() {
        if selected.count >= 6 { break }
        let (family,c,b) = layout
        guard placement(c,b) else { rejected["placement",default:0] += 1; continue }
        let opening = opportunities(c,b)
        guard let initial = bestComfort(opening) else { rejected["opening-unrated",default:0] += 1; continue }
        guard initial <= 40 else { rejected["opening-too-easy",default:0] += 1; continue }
        // Avoid accepting minor variants of the same opening.
        if selected.contains(where: {
            let oldC = vector($0["cue"] as! [Double]), oldB = vector($0["black"] as! [Double])
            return hypot(c.x-oldC.x,c.z-oldC.z)<0.25 && hypot(b.x-oldB.x,b.z-oldB.z)<0.15
        }) { rejected["near-duplicate",default:0] += 1; continue }
        let base = atan2f(b.z-c.z,b.x-c.x)
        let half = asinf(2*radius/hypot(b.x-c.x,b.z-c.z))
        var best: Choice?, worst: Choice?
        var validScores = [Double](), reasons = [String:Int]()
        print("LAYOUT \(layoutIndex) \(family) initial=\(initial)"); fflush(stdout)
        for sy: Float in [0,-0.2,0.2] {
            for index in -20...20 {
                let angle = base + half * Float(index) / 20 * 0.98
                let direction = SCNVector3(cosf(angle),0,sinf(angle))
                let access = CueStrikeAccess(cue:c,aim:direction,obstacles:[b],surfaceY:surface,profile:profile)
                guard access.isAvailable(spinX:0,spinY:Double(sy)),
                      let pose = access.resolvedPose(spinX:0,spinY:Double(sy)),
                      pose.elevation <= CueStick.minElevationRadians + 0.000001 else {
                    reasons["requires-elevated-cue",default:0] += 1; continue
                }
                for speed: Float in [0.6,1.0,1.4,1.8,2.2] {
                    let shot = Stroke(direction: direction,speed:speed,spinY:sy)
                    autoreleasepool {
                        simulations += 1
                        let p = simulate(c,b,shot)
                        if let why = reject(p) { reasons[why,default:0] += 1; return }
                        guard let s = bestComfort(opportunities(p.finalPositions[cueKey]!,p.finalPositions[ballKey]!)) else {
                            reasons["final-unrated",default:0] += 1; return
                        }
                        let score = 100-s
                        validScores.append(score)
                        if score >= 70, score-(100-initial) >= 10, tactical(p),
                           best == nil || prefer(shot,score:score,prediction:p,over:best!) {
                            best = Choice(shot:shot,score:score,prediction:p)
                        }
                        if worst == nil || score < worst!.score { worst = Choice(shot:shot,score:score,prediction:p) }
                    }
                }
            }
        }
        inventory.append(["layoutIndex":layoutIndex,"family":family,"cue":point(c),"black":point(b),
            "openingComfort":initial,"validShots":validScores.count,"rejections":reasons,
            "bestScore":best?.score ?? -1,"worstScore":worst?.score ?? -1])
        try write(inventory,out+"/inventory.json")
        guard let winner=best, let loser=worst, winner.score >= 70,
              winner.score-(100-initial) >= 10, winner.score-loser.score >= 20 else { continue }
        let replay = simulate(c,b,winner.shot)
        guard reject(replay)==nil,
              point(replay.finalPositions[cueKey]!)==point(winner.prediction.finalPositions[cueKey]!),
              point(replay.finalPositions[ballKey]!)==point(winner.prediction.finalPositions[ballKey]!),
              try JSONSerialization.data(withJSONObject:eventRows(replay),options:.sortedKeys) ==
                  JSONSerialization.data(withJSONObject:eventRows(winner.prediction),options:.sortedKeys) else {
            throw NSError(domain:"exact-replay-mismatch",code:2)
        }
        var probes = [[String: Any]]()
        let a=atan2f(winner.shot.direction.z,winner.shot.direction.x)
        for (label,delta,multiplier) in [("aim-0.15deg",Float(-0.15),Float(1)),
            ("aim+0.15deg",Float(0.15),Float(1)),("speed-5pct",Float(0),Float(0.95)),
            ("speed+5pct",Float(0),Float(1.05))] {
            let angle=a+delta*Float.pi/180
            let shot=Stroke(direction:SCNVector3(cosf(angle),0,sinf(angle)),speed:winner.shot.speed*multiplier,spinY:winner.shot.spinY)
            let p=simulate(c,b,shot)
            var row:[String:Any] = ["label":label,"shot":shot.json]
            if let why=reject(p) { row["rejection"]=why }
            else if let s=bestComfort(opportunities(p.finalPositions[cueKey]!,p.finalPositions[ballKey]!)) { row["score"]=100-s }
            else { row["rejection"]="unrated" }
            probes.append(row)
        }
        let id=String(format:"D1-%02d",selected.count+1)
        selected.append(["id":id,"layoutIndex":layoutIndex,"family":family,"cue":point(c),"black":point(b),
            "openingOpportunities":opening,"openingComfort":initial,"openingDefense":100-initial,
            "reference":record(replay,winner.shot),"poorComparison":record(loser.prediction,loser.shot),
            "exactReplay":true,"tacticalFilter":"ball distance >= 1.2m OR cue surface rail gap <= 4cm",
            "fullyBlocked":false,"perturbations":probes,"validCandidateCount":validScores.count,
            "scoreSamples":validScores.sorted()])
        try write(selected,out+"/questions.json")
        print("ACCEPT \(id) \(initial) -> \(winner.score) contrast=\(loser.score)");fflush(stdout)
    }
    try write(["selected":selected.count,"simulations":simulations,"layoutRejections":rejected,
        "evaluatedLayouts":inventory.count,"thresholds":["openingComfortMax":40,"defenseMin":70,"improvementMin":10],
        "search":["aimSamples":41,"speed":[0.6,1.0,1.4,1.8,2.2],"spinY":[0,-0.2,0.2],"spinX":[0]],
        "scope":"sampled candidates, not global optimum; no full-snooker case with one black"],out+"/summary.json")
    guard selected.count >= 3 else { throw NSError(domain:"insufficient-qualified-pilot",code:selected.count) }
    print("DONE \(selected.count) questions / \(simulations) simulations / exact replays passed")
} catch {
    fputs("ERROR \(error)\n",stderr); exit(1)
}
