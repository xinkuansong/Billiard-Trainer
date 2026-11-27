import Foundation
import SceneKit

typealias Row = [String:Any]
let surface = BTTablePhysics.surfaceY
let radius = BallPhysics.radius
let cueKey = ShotInput.cueBallName
let eightKey = "_8"
let probes = [(-0.1,1.0),(0.1,1.0),(0.0,0.95),(0.0,1.05)]
func point(_ p: SCNVector3) -> [Double] { [Double(p.x), Double(p.z)] }
func vec(_ a: [Double]) -> SCNVector3 { SCNVector3(Float(a[0]),surface+radius,Float(a[1])) }
func encoded<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
}
struct Attempt {
    let prediction: ShotPrediction
    let effect: DefenseEffect
    let rails: [[Int]]
    let events: [Row]
    func row() throws -> Row {
        ["effect": try encoded(effect), "events": events, "finalPositions": prediction.finalPositions.mapValues(point)]
    }
}

func solve(_ q: DefenseBankQuestion, profile: [CueSection], seeds: [Row]? = nil) throws -> Row {
    precondition(q.kind == "one" && q.ownBallNumber == 8 && q.opponentBallNumber == 8 && q.balls.map(\.number) == [8])
    let cue = vec(q.cue), eight = vec(q.balls[0].position)
    let balls = [ObstacleBall(name: eightKey, position: eight)]
    let distance = Double(cue.distanceXZ(to: eight))
    let base = atan2(Double(eight.z-cue.z),Double(eight.x-cue.x))
    var routes = seeds ?? [], seen = Set<[[Int]]>(), trials = 0
    let deep = seeds != nil
    func sequence(_ row: Row) -> [[Int]] {
        let rails = row["railSequences"] as! [String:[Int]]
        return [rails["cue"]!, rails["target"]!]
    }
    if deep { routes.sort { evidenceRank($0).lexicographicallyPrecedes(evidenceRank($1)) } }
    var ranks = routes.map(evidenceRank)
    var spinX = 0.0
    func assess(_ angle: Double, _ speed: Double, _ spin: Double, replay: Bool = false) throws -> Attempt? {
        let direction = SCNVector3(Float(cos(angle)),0,Float(sin(angle)))
        let access = CueStrikeAccess(cue: cue, aim: direction, obstacles: [eight], surfaceY: surface, profile: profile)
        guard access.isAvailable(spinX: spinX, spinY: spin),
              let pose = access.resolvedPose(spinX: spinX, spinY: spin),
              pose.elevation <= CueStick.minElevationRadians + 1e-6 else { return nil }
        let p = ShotPredictor.simulateFree(cueBall: cue, aimDir: direction, velocity: Float(speed), spinX: Float(spinX),
            spinY: Float(spin), surfaceY: surface, balls: balls, maxEvents: 1500, maxTime: 60,
            includePresentation: replay, recordedStrikeDirection: direction)
        guard p.hasFinalTableState, p.pocketedBalls.isEmpty, DefenseEffect.failure(q,p)==nil,
              let endCue=p.finalPositions[cueKey], let endEight=p.finalPositions[eightKey],
              endEight.distanceXZ(to: endCue)>=0.30 else {return nil}
        var rails=[[Int](),[Int]()], events=[Row](), objectHitRail=false
        let sides=[0,0,1,1,2,3]
        for e in p.events {
            switch e.kind {
            case let .ballBall(a,b):
                guard !objectHitRail else {return nil}
                events.append(["kind":"ballBall","balls":[a,b],"time":Double(e.time)])
            case let .ballCushion(ball):
                guard DefenseReferenceRoute.isMainCushion(e.cushionIndex), let index=e.cushionIndex else {return nil}
                let k=ball==cueKey ? 0 : 1
                rails[k].append(index)
                if k==1 {objectHitRail=true}
                let last=rails[k].suffix(3).map {sides[$0]}
                if last.count==3 && last[0]==last[2] && last[1]==(last[0]^1) {return nil}
                events.append(["kind":"cushion","ball":ball,"index":index,"time":Double(e.time)])
            case .pocket: return nil
            }
        }
        let effect = try DefenseEffect.evaluate(question:q,prediction:p,usePrecomputedWindows:false)
        guard let score=effect.score, score>=80 else {return nil}
        return Attempt(prediction:p, effect:effect, rails:rails, events:events)
    }
    let params=PositionPlaySolver.SearchParams.standard
    let coarse = (0...18).map { params.velocityMin + Double($0)*params.velocityStep }
    let fine = (0...36).map { params.velocityMin + Double($0)*params.velocityStep/2 }
    let spinSpeeds = [0.6,0.75,0.9,1.05,1.2,1.35,1.5,1.65,1.8,2.1,2.4,2.7,3.0,3.6,4.2,5.1,6.0]
    let offsets = deep ? [(0.0,0.0),(0,-0.2),(0,0.2),(0,-0.4),(0,0.4),(-0.3,0),(0.3,0)] : [(0.0,0.0),(0,-0.2),(0,0.2)]
    search: for (sx,spin) in offsets {
        spinX = sx
        let speeds = deep ? (sx == 0 && spin == 0 ? fine : spinSpeeds) : coarse
        for speed in speeds {
            for cut in [15,30,45,60] {
                for side in [-1,1] {
                    let desired=base+Double(side)*asin(2*Double(radius)*sin(Double(cut)*Double.pi/180)/distance)
                    let strike = CueBallStrike.executeStrike(aimDirection:SCNVector3(Float(cos(desired)),0,Float(sin(desired))),
                        velocity:Float(speed),spinX:Float(sx),spinY:Float(spin),elevation:0)
                    let delta = atan2(Double(strike.velocity.z),Double(strike.velocity.x))-desired
                    let angle = sx == 0 ? desired : desired-atan2(sin(delta),cos(delta))
                    trials+=1
                    guard let a=try assess(angle,speed,spin), deep || !seen.contains(a.rails) else {continue}
                    // Even four perfect probes cannot improve on this optimistic rank.
                    if deep {
                        let estimated = a.effect.estimateReason != nil || a.effect.pipeRoute?.zeroWidthEstimate == true
                        let lower = [estimated ? 1.0 : 0.0,0,DifficultyModel.executionEffort(spinX:sx,spinY:spin,velocity:speed),
                                     speed,Double(a.rails.map(\.count).reduce(0,+)),-a.effect.score!]
                        let index = routes.firstIndex { sequence($0) == a.rails }
                        let limit = index.map { ranks[$0] } ?? (routes.count == 2 ? ranks.last : nil)
                        if let limit, !lower.lexicographicallyPrecedes(limit) { continue }
                    }
                    var checks=[Row]()
                    for (da,factor) in probes {
                        guard let v=try assess(angle+da*Double.pi/180,speed*factor,spin) else {break}
                        var row=try v.row();row["angleDelta"]=da;row["speedScale"]=factor
                        checks.append(row)
                    }
                    guard checks.count==4 else {continue}
                    guard let final=try assess(angle,speed,spin,replay:true), final.rails==a.rails,
                          let recorder=final.prediction.recorder,
                          abs(final.effect.score!-a.effect.score!)<1e-7 else {continue}
                    guard [cueKey,eightKey].allSatisfy({key in
                        final.prediction.finalPositions[key]!.distanceXZ(to:a.prediction.finalPositions[key]!)<1e-5
                    }) else {continue}
                    var row=try final.row()
                    row["id"]=routes.count+1
                    row["shot"]=["angle":angle,"direction":[Double(Float(cos(angle))),Double(Float(sin(angle)))],"cutDegrees":cut,"side":side,"speed":speed,"spinX":sx,"spinY":spin] as Row
                    row["tracks"]=recorder.framesByBallName.mapValues{$0.map{[Double($0.time),Double($0.position.x),Double($0.position.z)]}}
                    row["railSequences"]=["cue":a.rails[0],"target":a.rails[1]]
                    row["probes"]=checks;row["replayVerified"]=true
                    if deep {
                        let rank = evidenceRank(row)
                        if let index = routes.firstIndex(where: { sequence($0) == a.rails }) {
                            guard rank.lexicographicallyPrecedes(ranks[index]) else {continue}
                            routes.remove(at:index);ranks.remove(at:index)
                        }
                        let insert = ranks.firstIndex(where: {rank.lexicographicallyPrecedes($0)}) ?? ranks.count
                        routes.insert(row,at:insert);ranks.insert(rank,at:insert)
                        if routes.count>2 {routes.removeLast();ranks.removeLast()}
                        if ranks.count==2 && ranks.allSatisfy({$0[0]==0 && $0[1]==0}) {break search}
                    } else {
                        routes.append(row);seen.insert(a.rails)
                        if routes.count==2 {break search}
                    }
                }
            }
        }
    }
    for i in routes.indices {routes[i]["id"] = i+1}
    return ["question":try encoded(q),"routes":routes,"trials":trials]
}
let args=CommandLine.arguments
let input=try Data(contentsOf: URL(fileURLWithPath:args[1]))
let questions=try JSONDecoder().decode([DefenseBankQuestion].self,from:input)
guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else {fatalError("Missing cue geometry")}
let profile=CueStick(modelCueStickNode:node).clearanceProfile
precondition(!profile.isEmpty)
let seedRows: [String:[Row]]? = args.count > 3
    ? try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath:args[3]))) as? [String:[Row]] : nil
for q in questions {
    try autoreleasepool {
        let record=try solve(q,profile:profile,seeds:seedRows.map { $0[q.id]! })
        let url=URL(fileURLWithPath:args[2]).appendingPathComponent(q.id+".json")
        try JSONSerialization.data(withJSONObject:record).write(to:url,options:.atomic)
    }
}
