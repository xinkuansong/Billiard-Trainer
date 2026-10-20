import XCTest
import SceneKit
@testable import QiuJi

/// Explicit resumable offline production. Every saved proof uses raw forward input.
final class TrainingBankExpansionTests: XCTestCase {
    struct Request: Codable {
        let sourceFingerprint: String
        let minimumBoards: Int
        let seed: UInt64
        let resume: Bool
    }
    struct Checkpoint: Codable {
        let bank: TrainingQuestionBank
        let randomState: UInt64
        let attempts: Int
    }
    private let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("output/accuracy-bank-expansion-20261020")

    private func actual(_ board: TrainingBankBoard, tip: TrainingFixedTip, direction: SCNVector3, speed: Float) -> ShotPrediction {
        ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction, velocity: speed,
            spinX: tip.x, spinY: tip.y, surfaceY: 0,
            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)], recordedStrikeDirection: direction)
    }
    private func verified(_ board: TrainingBankBoard, tip: TrainingFixedTip,
                          direction: SCNVector3, speed: Float) -> TrainingPotProof? {
        let shot = actual(board, tip: tip, direction: direction, speed: speed)
        guard shot.hasFinalTableState, AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex) == .success else { return nil }
        var samples: [TrainingToleranceSample] = []
        for angle: Float in [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius] {
            for delta: Float in [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius] {
                let result = angle == 0 && delta == 0 ? shot : actual(board, tip: tip,
                    direction: direction.rotatedY(angle * .pi / 180), speed: speed + delta)
                let outcome = AccuracyShotJudgement.evaluate(result, pocketIndex: board.pocketIndex)
                guard result.hasFinalTableState, outcome == .success else { return nil }
                samples.append(.init(angleDeltaDegrees: angle, velocityDelta: delta, outcome: outcome))
            }
        }
        return .init(board: board, prediction: shot, velocity: speed, tip: tip, samples: samples)
    }
    private func reachable(_ b: TrainingBankBoard, _ p: TrainingPotProof, profile: [CueSection]) -> Bool {
        CueStrikeAccess(cue: SCNVector3(b.cue.x, BallPhysics.radius, b.cue.z), aim: p.direction.vector,
            obstacles: [SCNVector3(b.target.x, BallPhysics.radius, b.target.z)], surfaceY: 0, profile: profile)
            .isAvailable(spinX: Double(p.tip.x), spinY: Double(p.tip.y))
    }
    private func search(_ b: TrainingBankBoard, tip: TrainingFixedTip,
                        preferred: TrainingPotProof?, profile: [CueSection]) -> TrainingPotProof? {
        // Cheap, bounded search: a missed candidate is discarded, never labelled impossible.
        var speeds: [Float] = []
        let options: [Float] = b.angle >= 71 ? [2.5, 3.5, 1.5, 5, 1] : [1, 1.5, 0.7, 2.5, 3.5]
        for speed in (preferred.map { [$0.velocity] } ?? []) + options where !speeds.contains(speed) { speeds.append(speed) }
        let pocket = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).pockets[b.pocketIndex].center
        for speed in speeds {
            for aim: SCNVector3? in [nil, pocket] {
                let input = ShotInput(cueBall: b.cue.vector, targetBall: b.target.vector, pocketIndex: b.pocketIndex,
                    velocity: speed, spinX: tip.x, spinY: tip.y, surfaceY: 0, pocketAimOverride: aim)
                let solved = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                guard solved.feasible else { continue }
                for offset: Float in [0, 0.025, -0.025, 0.075, -0.075] {
                    if let p = verified(b, tip: tip, direction: solved.aimDirection.rotatedY(offset * .pi / 180), speed: speed),
                       reachable(b, p, profile: profile) { return p }
                }
            }
        }
        return nil
    }
    private func cell(_ b: TrainingBankBoard) -> Int {
        let a = Int(b.angle.rounded())
        let band = a <= 10 ? 0 : a <= 30 ? 1 : a <= 50 ? 2 : a <= 70 ? 3 : 4
        let gap = SceneTrainingRailGeometry.clearance(b.target.vector)
        let rail = abs(gap) <= SceneTrainingRailGeometry.contactRoundoff ? 2 : gap <= 0.10 ? 1 : 0
        return rail * 5 + band
    }
    /// Compare all rectangle symmetries, including pocket identity, before admitting a new board.
    private func isDistinct(_ b: TrainingBankBoard, from existing: [TrainingBankBoard]) -> Bool {
        let pockets = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).pockets
        for (sx, sz): (Float, Float) in [(1,1),(-1,1),(1,-1),(-1,-1)] {
            let destination = pockets[b.pocketIndex].center
            let index = pockets.indices.min { a,c in
                hypot(pockets[a].center.x-destination.x*sx,pockets[a].center.z-destination.z*sz) <
                hypot(pockets[c].center.x-destination.x*sx,pockets[c].center.z-destination.z*sz)
            }!
            if existing.contains(where: { $0.pocketIndex == index &&
                max(hypot($0.cue.x-b.cue.x*sx,$0.cue.z-b.cue.z*sz),
                    hypot($0.target.x-b.target.x*sx,$0.target.z-b.target.z*sz)) < 0.03 }) { return false }
        }
        return true
    }

    @MainActor func testExpandVerifiedBank() throws {
        let requestURL = directory.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else { throw XCTSkip("Explicit bank expansion request required") }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        let model = try XCTUnwrap(TableModelLoader.loadTable(includeVisual: false))
        let cue = CueStick(modelCueStickNode: try XCTUnwrap(model.cueStickNode))
        let profile = cue.clearanceProfile
        var boards: [TrainingBankBoard] = [], proofs: [TrainingPotProof] = []
        var rng = SceneTrainingGenerator.SeededRandom(state: request.seed)
        var attempts = 0
        let checkpointURL = directory.appendingPathComponent("checkpoint.json")
        if request.resume {
            let previous = try JSONDecoder().decode(Checkpoint.self, from: Data(contentsOf: checkpointURL))
            try previous.bank.validate(expectedFingerprint: request.sourceFingerprint)
            boards = previous.bank.boards; proofs = previous.bank.proofs
            rng.state = previous.randomState; attempts = previous.attempts
        } else {
            let old = try JSONDecoder().decode(TrainingQuestionBank.self,
                from: Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))))
            let grouped = Dictionary(grouping: old.proofs, by: \.boardID)
            for (index, b) in old.boards.enumerated() {
                guard isDistinct(b, from: boards) else { continue }
                var accepted: [TrainingPotProof] = []
                for p in grouped[b.id, default: []] {
                    if let replay = verified(b, tip: p.tip, direction: p.direction.vector, speed: p.velocity),
                       reachable(b, replay, profile: profile) { accepted.append(replay) }
                }
                if !accepted.isEmpty { boards.append(b); proofs += accepted }
                if index % 100 == 0 { print("EXPANSION replay \(index)/\(old.boards.count) retained=\(boards.count)") }
            }
        }
        func bank() -> TrainingQuestionBank {
            .init(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
                boards: boards, proofs: proofs, variants: proofs.map { .init(boardID: $0.boardID, proofID: $0.id, tip: $0.tip) })
        }
        func checkpoint() throws {
            try JSONEncoder().encode(Checkpoint(bank: bank(), randomState: rng.state, attempts: attempts))
                .write(to: checkpointURL, options: .atomic)
        }
        try checkpoint()
        // 50% open rail, 33% near, 17% frozen; equal five angle-band floors.
        let proportions: [Double] = [0.5, 1.0 / 3.0, 1.0 / 6.0]
        var goals: [Int] = []
        for index in 0..<15 {
            let fraction: Double = proportions[index / 5] / 5.0
            goals.append(Int(ceil(Double(request.minimumBoards) * fraction)))
        }
        var counts = (0..<15).map { c in boards.filter { cell($0) == c }.count }
        var tries = Array(repeating: 0, count: 15)
        let angleRanges = [0...10, 11...30, 31...50, 51...70, 71...85]
        let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
        let start = Date()
        func nextCell() -> Int? {
            var chosen: Int?
            var leastRatio = Double.infinity
            for index in 0..<15 where counts[index] < goals[index] && tries[index] < 12000 {
                let ratio = Double(counts[index]) / Double(goals[index])
                if ratio < leastRatio { chosen = index; leastRatio = ratio }
            }
            return chosen
        }
        while let c = nextCell() {
            attempts += 1; tries[c] += 1
            let seed = rng.next()
            var generator = SceneTrainingGenerator(seed: seed)
            let rail = c/5, band = c%5
            let angle = Int.random(in: angleRanges[band], using: &rng)
            let pocket = Int.random(in: 0..<6, using: &rng)
            // Cycle distances instead of letting common short shots consume every slot.
            let cueBand = distances[Int.random(in: 0..<3, using: &rng)]
            let pocketBand = rail == 2 ? distances[Int.random(in: 0..<2, using: &rng)] : distances[Int.random(in: 0..<3, using: &rng)]
            let selected: Set<SceneTrainingConfiguration.RailDistance> = rail == 2 ? [.frozen] : rail == 1 ? [.near] : [.mixed]
            if let q = generator.question(angle: angle, side: attempts % 2 == 0 ? 1 : -1, pocket: pocket,
                cueBand: cueBand, pocketBand: pocketBand, railSelection: selected, allowsTargetJawContact: true) {
                let b = TrainingBankBoard(question: q, seed: seed)
                if cell(b) == c, isDistinct(b, from: boards), let center = search(b, tip: .center, preferred: nil, profile: profile) {
                    var accepted = [center]
                    for tip in TrainingFixedTip.allCases where tip != .center {
                        if let p = search(b, tip: tip, preferred: center, profile: profile) { accepted.append(p) }
                    }
                    boards.append(b); proofs += accepted; counts[c] += 1
                    if boards.count % 25 == 0 {
                        try checkpoint()
                        print("EXPANSION accepted=\(boards.count) variants=\(proofs.count) attempts=\(attempts) cells=\(counts) seconds=\(Int(Date().timeIntervalSince(start)))")
                    }
                }
            }
            if attempts % 250 == 0 {
                try checkpoint()
                print("EXPANSION searching accepted=\(boards.count) attempts=\(attempts) cells=\(counts) tries=\(tries)")
            }
        }
        try checkpoint()
        let result = bank()
        try result.validate(expectedFingerprint: request.sourceFingerprint)
        try JSONEncoder().encode(result).write(to: directory.appendingPathComponent("bank.json"), options: .atomic)
        var coverage: [String: String] = [:]
        for vertical in [false, true] {
            for lateral in [false, true] {
                for (label, rail): (String, SceneTrainingConfiguration.RailDistance) in [("random", .mixed),("near", .near),("frozen", .frozen)] {
                    var config = SceneTrainingConfiguration()
                    config.allowsVerticalSpin = vertical; config.allowsSideSpin = lateral; config.railDistanceSelection = [rail]
                    for seed in 1...10 {
                        let round = try result.accuracyBatch(config, seed: UInt64(seed))
                        XCTAssertEqual(Set(round.map { $0.0.id }).count, 20)
                        XCTAssertTrue(round.allSatisfy { $0.0.matches(config) })
                        XCTAssertEqual(round.map { $0.1.tip.rawValue }.sorted(), TrainingFixedTip.quota(config).map(\.rawValue).sorted())
                    }
                    coverage["\(label):vertical=\(vertical),side=\(lateral)"] = "10 seeds passed"
                }
            }
        }
        try JSONEncoder().encode(coverage).write(to: directory.appendingPathComponent("coverage.json"), options: .atomic)
        print("EXPANSION final=\(boards.count) variants=\(proofs.count) cells=\(counts) goals=\(goals)")
        for c in 0..<15 { XCTAssertGreaterThanOrEqual(counts[c], goals[c], "Search budget exhausted in cell \(c), not proof of impossibility") }
        XCTAssertGreaterThanOrEqual(Set(result.variants.map(\.boardID)).count, request.minimumBoards)
    }
}
