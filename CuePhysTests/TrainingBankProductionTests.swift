import XCTest
import SceneKit
@testable import QiuJi

final class TrainingBankProductionTests: XCTestCase {
    private func actual(_ board: TrainingBankBoard, tip: TrainingFixedTip,
                        direction: SCNVector3, speed: Float) -> ShotPrediction {
        ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction,
            velocity: speed, spinX: tip.x, spinY: tip.y, surfaceY: 0,
            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)], recordedStrikeDirection: direction)
    }
    private func proof(_ board: TrainingBankBoard, tip: TrainingFixedTip,
                       direction: SCNVector3, speed: Float, requireStable: Bool) -> TrainingPotProof? {
        let shot = actual(board, tip: tip, direction: direction, speed: speed)
        guard shot.hasFinalTableState, shot.events.contains(where: {
            if case let .pocket(ball, id) = $0.kind {
                return ball == ShotInput.targetBallName && id == "pocket_\(board.pocketIndex)"
            }
            return false
        }) else { return nil }
        var samples: [TrainingToleranceSample] = []
        if requireStable && AccuracyShotJudgement.evaluate(shot, pocketIndex: board.pocketIndex) == .success {
            for angle: Float in [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius] {
                for power: Float in [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius] {
                    let sample = angle == 0 && power == 0 ? shot :
                        actual(board, tip: tip, direction: direction.rotatedY(angle * .pi / 180), speed: speed + power)
                    let outcome = AccuracyShotJudgement.evaluate(sample, pocketIndex: board.pocketIndex)
                    samples.append(.init(angleDeltaDegrees: angle, velocityDelta: power, outcome: outcome))
                    if outcome != .success {
                        return .init(board: board, prediction: shot, velocity: speed, tip: tip, samples: samples)
                    }
                }
            }
        }
        return .init(board: board, prediction: shot, velocity: speed, tip: tip, samples: samples)
    }
    private func reachable(_ board: TrainingBankBoard, _ proof: TrainingPotProof) -> Bool {
        let cue = SCNVector3(board.cue.x, BallPhysics.radius, board.cue.z)
        let target = SCNVector3(board.target.x, BallPhysics.radius, board.target.z)
        return CueStrikeAccess(cue: cue, aim: proof.direction.vector, obstacles: [target], surfaceY: 0)
            .isAvailable(spinX: Double(proof.tip.x), spinY: Double(proof.tip.y))
    }
    private func search(_ board: TrainingBankBoard, tip: TrainingFixedTip) -> TrainingPotProof? {
        let pocket = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).pockets[board.pocketIndex].center
        let points: [SCNVector3?] = [nil, pocket]
        var pots = 0, direct = 0, best = 0
        for speed: Float in [1, 1.1, 0.9, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2, 0.8, 0.7, 0.6, 2.5, 3.5, 5] {
            for point in points {
                let input = ShotInput(cueBall: board.cue.vector, targetBall: board.target.vector,
                    pocketIndex: board.pocketIndex, velocity: speed, spinX: tip.x, spinY: tip.y,
                    surfaceY: 0, pocketAimOverride: point)
                let candidate = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                guard candidate.feasible else { continue }
                for offset: Float in [0, 0.0125, -0.0125, 0.025, -0.025, 0.0375, -0.0375, 0.05, -0.05, 0.0625, -0.0625, 0.075, -0.075, 0.0875, -0.0875, 0.1, -0.1, 0.125, -0.125, 0.15, -0.15, 0.175, -0.175, 0.2, -0.2, 0.3, -0.3, 0.4, -0.4] {
                    if let p = proof(board, tip: tip,
                        direction: candidate.aimDirection.rotatedY(offset * .pi / 180), speed: speed, requireStable: true) {
                        pots += 1
                        if p.accuracySuccess { direct += 1 }
                        best = max(best, p.perturbationSuccesses)
                        if p.qualifiesForAccuracy, reachable(board, p) { return p }
                    }
                }
            }
        }
        print("BANK_SEARCH miss angle=\(board.angle) pocket=\(board.pocketIndex) tip=\(tip.rawValue) pots=\(pots) direct=\(direct) best=\(best) gap=\(SceneTrainingRailGeometry.clearance(board.target.vector))")
        return nil
    }
    func testFrozenSearchProbe() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let request = root.appendingPathComponent("output/accuracy-practice-20261020/frozen-probe-request")
        guard FileManager.default.fileExists(atPath: request.path) else { throw XCTSkip("Explicit offline probe required") }
        try FileManager.default.removeItem(at: request)
        var generator = SceneTrainingGenerator(seed: 20261025)
        var found: [TrainingBankBoard] = [], proofs: [TrainingPotProof] = []
        for angle in [55, 75] {
            var searched = 0
            for candidate in 0..<2000 {
                guard let q = generator.question(angle: angle, side: candidate % 2 == 0 ? 1 : -1,
                    pocket: candidate % 4, cueBand: .short, pocketBand: .short,
                    railSelection: [.frozen], allowsTargetJawContact: true) else { continue }
                let board = TrainingBankBoard(question: q, seed: UInt64(candidate))
                guard hypot(board.cue.x-board.target.x, board.cue.z-board.target.z) <= 0.40,
                      hypot(board.effectiveAim.x-board.target.x, board.effectiveAim.z-board.target.z) <= 0.30 else { continue }
                searched += 1
                if let p = search(board, tip: .center) {
                    found.append(board); proofs.append(p)
                    for tip in TrainingFixedTip.allCases where tip != .center {
                        if let other = search(board, tip: tip) { proofs.append(other) }
                    }
                    print("FROZEN_PROBE success angle=\(angle) speed=\(p.velocity) samples=\(p.perturbationSuccesses) searched=\(searched)")
                    break
                }
                if searched == 30 { break }
            }
        }
        let bank = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: "probe-requires-revalidation",
            boards: found, proofs: proofs, variants: proofs.map { TrainingAccuracyVariant(boardID: $0.boardID, proofID: $0.id, tip: $0.tip) })
        try JSONEncoder().encode(bank).write(to: root.appendingPathComponent("output/accuracy-practice-20261020/frozen-probe-bank.json"))
        XCTAssertEqual(found.count, 2, "Finite candidate search is not an impossibility proof")
    }

    func testRevalidateAndSupplementOfflineBank() throws {
        struct Request: Decodable {
            let sourceFingerprint: String
            let addThin: Int
            let addFrozen: Int
            let addDistances: Int?
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("output/accuracy-practice-20261020")
        let requestURL = directory.appendingPathComponent("production-request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else { throw XCTSkip("Explicit offline request required") }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        let inputName = ["frozen-search-seed-bank.json", "production-bank.json", "refined-bank.json"].first {
            FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path)
        }!
        let old = try JSONDecoder().decode(TrainingQuestionBank.self, from: Data(contentsOf: directory.appendingPathComponent(inputName)))
        var boards = old.boards, proofs: [TrainingPotProof] = []
        let byID = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
        for (index, previous) in old.proofs.enumerated() {
            guard let board = byID[previous.boardID] else { XCTFail("Missing board"); continue }
            if let p = proof(board, tip: previous.tip, direction: previous.direction.vector,
                speed: previous.velocity, requireStable: true) { proofs.append(p) }
            if index % 200 == 0 { print("BANK_PRODUCTION replayed=\(index)/\(old.proofs.count)") }
        }
        // A reflected board is a new physical candidate, never an inherited proof.
        // Replay every mirrored input and its neighbourhood against the real geometry.
        let frozenSeeds = boards.filter { SceneTrainingRailGeometry.matches($0.target.vector, selection: [.frozen]) }
        let seedProofs = proofs
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: 0)
        var reflectedCount = 0
        for original in frozenSeeds {
            for (sx, sz): (Float, Float) in [(-1, 1), (1, -1), (-1, -1)] {
                func reflected(_ p: SCNVector3) -> SCNVector3 { SCNVector3(p.x * sx, 0, p.z * sz) }
                let cue = reflected(original.cue.vector), target = reflected(original.target.vector)
                let destination = reflected(pockets[original.pocketIndex])
                guard let pocket = pockets.indices.min(by: {
                    hypot(pockets[$0].x-destination.x, pockets[$0].z-destination.z) <
                    hypot(pockets[$1].x-destination.x, pockets[$1].z-destination.z)
                }) else { continue }
                let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
                let q = SceneTrainingQuestion(id: UUID(), geometry: .init(
                    targetBall: AngleSceneCalculator.sceneToNormalized(position: target),
                    cueBall: AngleSceneCalculator.sceneToNormalized(position: cue), pocket: AngleCalculator.pockets[pocket],
                    actualAngle: AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim),
                    pocketType: pocket < 4 ? .corner : .side, pocketIndex: pocket),
                    side: original.side * Int(sx * sz), cueBand: original.cueBand, pocketBand: original.pocketBand)
                let board = TrainingBankBoard(question: q, seed: original.seed)
                guard !boards.contains(where: { $0.id == board.id || ($0.pocketIndex == board.pocketIndex &&
                    max(hypot($0.cue.x-board.cue.x, $0.cue.z-board.cue.z),
                        hypot($0.target.x-board.target.x, $0.target.z-board.target.z)) < 0.01) }) else { continue }
                var verified: [TrainingPotProof] = []
                for previous in seedProofs where previous.boardID == original.id {
                    guard let tip = TrainingFixedTip.allCases.first(where: {
                        $0.x == previous.tip.x * sx * sz && $0.y == previous.tip.y
                    }) else { continue }
                    if let p = proof(board, tip: tip, direction: reflected(previous.direction.vector),
                                     speed: previous.velocity, requireStable: true) { verified.append(p) }
                }
                if !verified.isEmpty { boards.append(board); proofs += verified; reflectedCount += 1 }
            }
        }
        print("BANK_PRODUCTION reflectedAndRevalidated=\(reflectedCount)")
        let represented = Set(proofs.map(\.boardID))
        boards.removeAll { !represented.contains($0.id) }
        var rng = SceneTrainingGenerator.SeededRandom(state: 20261024)
        var supplemental: [String: Int] = [:]
        let categories = [("thin", request.addThin), ("frozen", request.addFrozen)] +
            ["cueLong", "pocketMiddle", "pocketLong"].map { ($0, request.addDistances ?? 0) }
        for (category, count) in categories {
            var accepted = 0, attempts = 0, candidates = 0
            while accepted < count && attempts < max(1, count) * 40 {
                attempts += 1
                if attempts % 20 == 0 {
                    print("BANK_PRODUCTION search category=\(category) accepted=\(accepted) attempts=\(attempts) candidates=\(candidates)")
                }
                let seed = rng.next()
                var generator = SceneTrainingGenerator(seed: seed)
                let angle = category == "frozen"
                    ? Int.random(in: [5...10, 11...30, 31...50, 51...70, 71...85][accepted % 5], using: &rng)
                    : Int.random(in: 71...(category == "thin" ? 85 : 75), using: &rng)
                let pocket = Int.random(in: 0..<6, using: &rng)
                guard let q = generator.question(angle: angle, side: attempts % 2 == 0 ? 1 : -1,
                    pocket: pocket, cueBand: category == "cueLong" ? .long : .short,
                    pocketBand: category == "pocketLong" ? .long : (category == "pocketMiddle" ? .middle : .short),
                    railSelection: category == "frozen" ? [.frozen] : [.mixed],
                    allowsTargetJawContact: true) else { continue }
                candidates += 1
                let board = TrainingBankBoard(question: q, seed: seed)
                if category == "frozen" && (hypot(board.cue.x-board.target.x, board.cue.z-board.target.z) > 0.45 ||
                    hypot(board.effectiveAim.x-board.target.x, board.effectiveAim.z-board.target.z) > 0.35) { continue }
                guard !boards.contains(where: {
                    $0.pocketIndex == board.pocketIndex &&
                    max(hypot($0.cue.x - board.cue.x, $0.cue.z - board.cue.z),
                        hypot($0.target.x - board.target.x, $0.target.z - board.target.z)) < 0.01
                }), let center = search(board, tip: .center) else { continue }
                boards.append(board); proofs.append(center); accepted += 1
                for tip in TrainingFixedTip.allCases where tip != .center {
                    if let p = search(board, tip: tip) { proofs.append(p) }
                }
                let checkpoint = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
                    boards: boards, proofs: proofs, variants: proofs.filter(\.qualifiesForAccuracy).map {
                        TrainingAccuracyVariant(boardID: $0.boardID, proofID: $0.id, tip: $0.tip)
                    })
                try JSONEncoder().encode(checkpoint).write(to: directory.appendingPathComponent("production-checkpoint.json"), options: .atomic)
                print("BANK_PRODUCTION category=\(category) accepted=\(accepted) attempts=\(attempts) candidates=\(candidates)")
            }
            supplemental[category] = accepted
        }
        let lookup = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
        let variants = proofs.filter { p in
            p.qualifiesForAccuracy && lookup[p.boardID].map { reachable($0, p) } == true
        }.map { TrainingAccuracyVariant(boardID: $0.boardID, proofID: $0.id, tip: $0.tip) }
        let bank = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
            boards: boards, proofs: proofs, variants: variants)
        try bank.validate(expectedFingerprint: request.sourceFingerprint)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(bank).write(to: directory.appendingPathComponent("production-bank.json"), options: .atomic)
        var coverage: [String: String] = [:]
        for vertical in [false, true] {
            for lateral in [false, true] {
                var config = SceneTrainingConfiguration()
                config.allowsVerticalSpin = vertical; config.allowsSideSpin = lateral
                for (label, selection): (String, Set<SceneTrainingConfiguration.RailDistance>) in
                    [("random", [.mixed]), ("near", [.near]), ("frozen", [.frozen])] {
                    config.railDistanceSelection = selection
                    let key = "\(label):vertical=\(vertical),side=\(lateral)"
                    do {
                        for seed in 1...10 {
                            let batch = try bank.accuracyBatch(config, seed: UInt64(seed))
                            XCTAssertEqual(Set(batch.map { $0.0.id }).count, 20)
                            XCTAssertTrue(batch.allSatisfy { $0.0.matches(config) })
                        }
                        coverage[key] = "10 seeds passed"
                    } catch { coverage[key] = error.localizedDescription }
                }
            }
        }
        try encoder.encode(coverage).write(to: directory.appendingPathComponent("production-coverage.json"), options: .atomic)
        print("BANK_PRODUCTION supplemental=\(supplemental) coverage=\(coverage)")
        XCTAssertEqual(supplemental["thin"], request.addThin, "Budget exhausted is not proof of impossibility")
        XCTAssertEqual(supplemental["frozen"], request.addFrozen, "Budget exhausted is not proof of impossibility")
        for category in ["cueLong", "pocketMiddle", "pocketLong"] {
            XCTAssertEqual(supplemental[category], request.addDistances ?? 0, "Budget exhausted is not proof of impossibility")
        }
    }
}
