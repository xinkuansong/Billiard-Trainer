import Foundation
import SceneKit

let output = URL(fileURLWithPath: CommandLine.arguments[2])
let samples = try JSONDecoder().decode([TrainingBankBoard].self,
    from: Data(contentsOf: output.appendingPathComponent("boards.json")))
let parameters: [(Float, Float, Float)] = [Float(1), 1.5, 2, 2.5, 3, 4, 6].map { ($0, 0, 0) }
    + [Float(2), 3].flatMap { v in [Float(-0.5), -0.25, 0.25, 0.5].map { (v, $0, Float(0)) } }
func facts(_ p: ShotPrediction, _ pocket: Int, _ elapsed: Double) -> [String: Any] {
    ["direct": ShotPredictor.isDirectPot(p, pocketIndex: pocket),
     "outcome": AccuracyShotJudgement.evaluate(p, pocketIndex: pocket).rawValue,
     "settled": p.hasFinalTableState, "ms": elapsed * 1000,
     "offset": p.aimOffsetUsed ?? 0,
     "events": p.events.map { ["time": $0.time, "kind": String(describing: $0.kind),
                               "cushion": $0.cushionIndex ?? -1] as [String: Any] }]
}
func emit(_ row: [String: Any]) throws {
    var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]); data.append(10)
    let url = output.appendingPathComponent("results.jsonl")
    if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
    let f = try FileHandle(forWritingTo: url); try f.seekToEnd(); try f.write(contentsOf: data); try f.close()
}
for (index, b) in samples.enumerated() {
    for (v, sx, sy) in parameters {
        try autoreleasepool {
            let input = ShotInput(cueBall: b.cue.vector, targetBall: b.target.vector,
                pocketIndex: b.pocketIndex, velocity: v, spinX: sx, spinY: sy, surfaceY: 0)
            let start = Date()
            let p = ShotPredictor.predict(input, maxEvents: 2000, maxTime: 45)
            let t1 = Date()
            let q = ShotPredictor.predictForPositionSolve(input, maxEvents: 2000, maxTime: 45)
            let t2 = Date()
            let scoring = ShotPredictor.predictForPositionSolve(input, maxEvents: 2000, maxTime: 45, includePresentation: false)
            let replay = ShotPredictor.predictForPositionSolve(input, aimOffset: q.aimOffsetUsed, maxEvents: 2000, maxTime: 45)
            try emit(["index": index, "board": b.id, "combination": b.combinationID ?? "",
                "speed": v, "spinX": sx, "spinY": sy,
                "predict": facts(p, b.pocketIndex, t1.timeIntervalSince(start)),
                "position": facts(q, b.pocketIndex, t2.timeIntervalSince(t1)),
                "scoringDirect": ShotPredictor.isDirectPot(scoring, pocketIndex: b.pocketIndex),
                "replayExact": replay.aimOffsetUsed == q.aimOffsetUsed
                    && String(describing: replay.events) == String(describing: q.events)])
        }
    }
    print("REPAIR \(index + 1)/\(samples.count)"); fflush(stdout)
}

// Boundary and actual planner integration checks. Mirroring reverses side spin
// under one reflection, but keeps top/draw spin unchanged (world XZ, Y up).
var extended: [[String: Any]] = []
for index in [2, 9] {
    let b = samples[index]
    for (mx, mz): (Float, Float) in [(1, 1), (-1, 1), (1, -1), (-1, -1)] {
        var pocket = b.pocketIndex
        if mx < 0 { pocket = [1, 0, 3, 2, 4, 5][pocket] }
        if mz < 0 { pocket = [2, 3, 0, 1, 5, 4][pocket] }
        let cue = SCNVector3(b.cue.vector.x * mx, BallPhysics.radius, b.cue.vector.z * mz)
        let target = SCNVector3(b.target.vector.x * mx, BallPhysics.radius, b.target.vector.z * mz)
        for v: Float in [2, 3] {
            for (sx, sy): (Float, Float) in [(0, -0.4), (0, 0.4), (-0.3, -0.3), (-0.3, 0.3), (0.3, -0.3), (0.3, 0.3)] {
                let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocket,
                    velocity: v, spinX: sx * mx * mz, spinY: sy, surfaceY: 0)
                var seed = ShotPrediction()
                let ctx = ShotPredictor.prepareAim(input, into: &seed)!
                let offset = ShotPredictor.positionAimOffset(input: input, context: ctx)
                let raw = ShotPredictor.predictForPositionSolve(input, aimOffset: offset)
                let p = ShotPredictor.predictForPositionSolve(input)
                let q = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                precondition(p.hasFinalTableState)
                precondition(!ShotPredictor.isDirectPot(raw, pocketIndex: pocket)
                             || ShotPredictor.isDirectPot(p, pocketIndex: pocket), "lost seed pot")
                precondition(ShotPredictor.isDirectPot(p, pocketIndex: pocket)
                             == ShotPredictor.isDirectPot(q, pocketIndex: pocket), "scoring drift")
                if p.aimOffsetUsed != raw.aimOffsetUsed {
                    precondition(ShotPredictor.isDirectPot(p, pocketIndex: pocket), "invalid rescue")
                }
                extended.append(["index": index, "mx": mx, "mz": mz, "speed": v, "spinX": sx, "spinY": sy,
                    "seedDirect": ShotPredictor.isDirectPot(raw, pocketIndex: pocket),
                    "direct": ShotPredictor.isDirectPot(p, pocketIndex: pocket)])
            }
        }
    }
}
let b = samples[9]
let input = ShotInput(cueBall: b.cue.vector, targetBall: b.target.vector, pocketIndex: b.pocketIndex,
                      velocity: 3, spinX: 0, spinY: 0, surfaceY: 0)
let solved = ShotPredictor.predictForPositionSolve(input)
precondition(ShotPredictor.isDirectPot(solved, pocketIndex: 4))
var contextSeed = ShotPrediction()
let ctx = ShotPredictor.prepareAim(input, into: &contextSeed)!
let oldOffset = ShotPredictor.positionAimOffset(input: input, context: ctx)
let explicit = ShotPredictor.predictForPositionSolve(input, aimOffset: oldOffset)
precondition(explicit.aimOffsetUsed == oldOffset && !explicit.objectPocketed, "explicit direction silently repaired")
let cancel = PredictionCancellation(); cancel.cancel()
precondition(ShotPredictor.predictForPositionSolve(input, cancellation: cancel).termination == .cancelled)
precondition(ShotPredictor.predict(input, bankCancellation: cancel).termination == .cancelled)
let limited = ShotPredictor.predictForPositionSolve(input, maxTime: 0.001)
precondition(!limited.hasResolvedSearchState && !limited.objectPocketed)
var repeated = solved
repeated.events.insert(ShotEvent(time: 1, kind: .ballBall(ballA: "cueBall", ballB: "object")), at: 1)
precondition(!ShotPredictor.isDirectPot(repeated, pocketIndex: 4), "second target contact accepted")
var wrongMouth = solved
wrongMouth.events.insert(ShotEvent(time: 1, kind: .ballCushion(ball: "object"), cushionIndex: 44), at: 1)
precondition(!ShotPredictor.isDirectPot(wrongMouth, pocketIndex: 4), "other pocket jaw accepted")
let cueFinal = solved.finalPositions[ShotInput.cueBallName]!
let normalized = AngleSceneCalculator.sceneToNormalized(position: cueFinal)
let region = SolveRegion.circle(center: CanvasPoint(x: normalized.x, y: normalized.y), radius: 0.02)
var params = PositionPlaySolver.SearchParams.standard
params.spinXValues = [0]; params.spinYValues = [0]
params.velocityMin = 3; params.velocityMax = 3; params.velocityStep = 0.3
params.refineEnabled = false; params.allowsMissedPotFallback = false; params.requiresDirectPot = true
let start = Date()
let solutions = PositionPlaySolver.solve(setup: .init(cue: b.cue.vector, target: b.target.vector,
    pocketIndex: 4, obstacles: [], surfaceY: 0), targetKey: "_1", pocket: "topCenter",
    constraint: .restRegion(region), params: params)
precondition(solutions.contains { $0.satisfiesConstraint && ShotPredictor.isDirectPot($0.prediction, pocketIndex: 4) },
             "planner memoized scan did not consume route refinement")
let details: [String: Any] = ["variants": extended, "plannerSolutions": solutions.count,
    "plannerMs": Date().timeIntervalSince(start) * 1000,
    "explicitDirection": true, "cancellation": true, "truncation": true,
    "secondContactRejected": true, "wrongMouthRejected": true]
try JSONSerialization.data(withJSONObject: details, options: [.sortedKeys, .prettyPrinted])
    .write(to: output.appendingPathComponent("boundaries.json"))
print("BOUNDARIES PASS variants=\(extended.count), planner=\(solutions.count)")
