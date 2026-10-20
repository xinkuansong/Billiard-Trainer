import XCTest
import SceneKit
@testable import QiuJi

final class TrainingQuestionBankTests: XCTestCase {
    func testMouthOwnershipAgainstEveryProductionCushion() throws {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        let samples = geometry.linearCushions.map { ($0.start + $0.end) * 0.5 }
            + geometry.circularCushions.map(\.center)
        for (index, point) in samples.enumerated() {
            if index < 6 {
                XCTAssertNil(AccuracyShotJudgement.mouthOwner(cushionIndex: index)); continue
            }
            let nearest = try XCTUnwrap(geometry.pockets.min {
                hypot($0.center.x-point.x, $0.center.z-point.z) < hypot($1.center.x-point.x, $1.center.z-point.z)
            })
            let owner = try XCTUnwrap(AccuracyShotJudgement.mouthOwner(cushionIndex: index))
            XCTAssertEqual(nearest.id, "pocket_\(owner)", "Production segment \(index)")
        }
        XCTAssertNil(AccuracyShotJudgement.mouthOwner(cushionIndex: samples.count))
    }
    func testTipQuotasDisableAxesAndRetainExactFixedContacts() {
        for vertical in [false, true] {
            for lateral in [false, true] {
                var c = SceneTrainingConfiguration(); c.allowsVerticalSpin = vertical; c.allowsSideSpin = lateral
                let tips = TrainingFixedTip.quota(c)
                XCTAssertEqual(tips.count, 20)
                XCTAssertEqual(tips.filter { $0 == .center }.count, vertical || lateral ? 4 : 20)
                XCTAssertTrue(tips.allSatisfy { vertical || $0.y == 0 })
                XCTAssertTrue(tips.allSatisfy { lateral || $0.x == 0 })
                XCTAssertTrue(tips.allSatisfy { hypot($0.x, $0.y) <= 0.5 })
            }
        }
    }

    func testQualificationNeighbourhoodSpansSeveralRealFineDragPoints() {
        var drag = AdaptiveShotDrag()
        let sample = drag.update(translation: 3, time: 1)
        let smallestDistance: Float = 0.30
        let movement = Float(sample.delta) * AimWheelGain.degreesPerPoint(distanceMeters: smallestDistance)
        XCTAssertGreaterThanOrEqual(TrainingPotProof.angleRadius, movement)
        XCTAssertGreaterThan(movement, 0)
    }

    func testScoringUsesSettledSpecifiedPocketAndActualRoute() {
        let cue = ShotInput.cueBallName, object = ShotInput.targetBallName
        var shot = ShotPrediction(); shot.termination = .settled
        let contact = ShotEvent(time: 1, kind: .ballBall(ballA: cue, ballB: object))
        let pot = ShotEvent(time: 2, kind: .pocket(ball: object, pocketId: "pocket_0"))
        shot.events = [contact, pot]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .success)
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 1), .wrongPocket)
        shot.events = [contact, .init(time: 1.8, kind: .ballCushion(ball: object), cushionIndex: 6), pot]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .success, "Target jaw is part of normal entry")
        shot.events = [contact, .init(time: 1.8, kind: .ballCushion(ball: object), cushionIndex: 8), pot]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .indirect, "Another pocket mouth cannot be a bank")
        shot.events = [contact, .init(time: 1.8, kind: .ballCushion(ball: object), cushionIndex: 0), pot]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .indirect)
        shot.events = [.init(time: 0, kind: .ballCushion(ball: object), cushionIndex: 0), contact, pot]
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .success, "Initial frozen contact is not a bank")
        shot.cuePocketed = true
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .scratch)
        shot.termination = nil
        XCTAssertEqual(AccuracyShotJudgement.evaluate(shot, pocketIndex: 0), .technicalFailure)
    }

    func testBaseProofCannotAuthorizeADifferentFixedTip() throws {
        var generator = SceneTrainingGenerator(seed: 20261020)
        let q = try XCTUnwrap(generator.question(angle: 30, side: 1, pocket: 0, cueBand: .short, pocketBand: .short))
        let board = TrainingBankBoard(question: q, seed: 20261020)
        var prediction = ShotPrediction(); prediction.termination = .settled
        prediction.events = [.init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
                             .init(time: 2, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_0"))]
        let samples = [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius].flatMap { angle in
            [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius].map {
                TrainingToleranceSample(angleDeltaDegrees: angle, velocityDelta: $0, outcome: .success)
            }
        }
        let proof = TrainingPotProof(board: board, prediction: prediction, velocity: 1, tip: .right, samples: samples)
        let valid = TrainingQuestionBank(schemaVersion: 1, sourceFingerprint: "test", boards: [board], proofs: [proof],
            variants: [.init(boardID: board.id, proofID: proof.id, tip: .right)])
        try valid.validate(expectedFingerprint: "test")
        XCTAssertThrowsError(try valid.validate(expectedFingerprint: "changed-physics"))
        let wrong = TrainingQuestionBank(schemaVersion: 1, sourceFingerprint: "test", boards: [board], proofs: [proof],
            variants: [.init(boardID: board.id, proofID: proof.id, tip: .center)])
        XCTAssertThrowsError(try wrong.validate(expectedFingerprint: "test"))
        XCTAssertThrowsError(try valid.accuracyBatch(SceneTrainingConfiguration(), seed: 1))
    }

    func testInitiallyFrozenCompressionIsNotABankButLeavingAndReturningIs() {
        let rail = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).linearCushions[0]
        let frozen = (rail.start + rail.end) * 0.5 + rail.normal * BallPhysics.radius
        func prediction(departs: Bool) -> ShotPrediction {
            var shot = ShotPrediction(); shot.termination = .settled
            let recorder = TrajectoryRecorder()
            for (time, position): (Float, SCNVector3) in [(0, frozen),
                (0.5, departs ? frozen + rail.normal * 0.03 : frozen), (1, frozen)] {
                recorder.recordFrame(ballName: ShotInput.targetBallName,
                    frame: .init(time: time, position: position, velocity: SCNVector3Zero,
                        angularVelocity: SCNVector4Zero, state: .stationary))
            }
            shot.recorder = recorder
            shot.events = [
                .init(time: 0.1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
                .init(time: 1, kind: .ballCushion(ball: ShotInput.targetBallName), cushionIndex: 0),
                .init(time: 2, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_0"))
            ]
            return shot
        }
        XCTAssertEqual(AccuracyShotJudgement.evaluate(prediction(departs: false), pocketIndex: 0), .success)
        XCTAssertEqual(AccuracyShotJudgement.evaluate(prediction(departs: true), pocketIndex: 0), .indirect)
    }

    /// Explicit offline job only. The request is consumed once; regular tests skip production work.
    func testGenerateOfflinePilot() throws {
        struct Request: Decodable { let count: Int; let sourceFingerprint: String; let seed: UInt64 }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let requestURL = root.appendingPathComponent("output/accuracy-practice-20261020/generator-request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else { throw XCTSkip("Offline generator requires an explicit request") }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        XCTAssertTrue((1...1000).contains(request.count))
        var boards: [TrainingBankBoard] = [], proofs: [TrainingPotProof] = [], variants: [TrainingAccuracyVariant] = []
        var attempted = 0, unsolved = 0
        let start = Date()
        let bands = SceneTrainingConfiguration.AngleRange.allCases.filter { $0 != .mixed }
        let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
        let rails: [SceneTrainingConfiguration.RailDistance] = [.mixed, .near, .frozen]
        var rng = SceneTrainingGenerator.SeededRandom(state: request.seed)
        while boards.count < request.count && attempted < request.count * 30 {
            let index = attempted
            attempted += 1
            let seed = rng.next()
            var generator = SceneTrainingGenerator(seed: seed)
            let band = bands[boards.count % bands.count]
            let angle = Int.random(in: band.degrees, using: &rng)
            let pocket = Int.random(in: 0..<6, using: &rng)
            guard let q = generator.question(angle: angle, side: index % 2 == 0 ? 1 : -1, pocket: pocket,
                cueBand: distances[(index / 3) % 3], pocketBand: distances[index % 3], railSelection: [rails[(index / 9) % 3]]) else { continue }
            let board = TrainingBankBoard(question: q, seed: seed)
            var boardProofs: [TrainingPotProof] = []
            for tip in TrainingFixedTip.allCases {
                var accepted: TrainingPotProof?
                for speed: Float in [0.6, 1.0, 1.5, 2.2, 3.2, 4.5, 6.0] {
                    let input = ShotInput(cueBall: board.cue.vector, targetBall: board.target.vector,
                        pocketIndex: pocket, velocity: speed, spinX: tip.x, spinY: tip.y, surfaceY: 0)
                    let candidate = ShotPredictor.predictForPositionSolve(input, includePresentation: false)
                    guard candidate.objectPocketed else { continue }
                    let direction = candidate.aimDirection
                    func simulate(_ angleDelta: Float, _ speedDelta: Float) -> ShotPrediction {
                        ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction.rotatedY(angleDelta * .pi / 180),
                            velocity: speed + speedDelta, spinX: tip.x, spinY: tip.y, surfaceY: 0,
                            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)])
                    }
                    let actual = simulate(0, 0)
                    guard actual.hasFinalTableState, actual.events.contains(where: {
                        if case let .pocket(ball, id) = $0.kind { return ball == ShotInput.targetBallName && id == "pocket_\(pocket)" }; return false
                    }) else { continue }
                    let success = AccuracyShotJudgement.evaluate(actual, pocketIndex: pocket) == .success
                    var samples = [TrainingToleranceSample(angleDeltaDegrees: 0, velocityDelta: 0,
                        outcome: AccuracyShotJudgement.evaluate(actual, pocketIndex: pocket))]
                    if success {
                        for delta: Float in [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius] {
                            for power: Float in [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius] where delta != 0 || power != 0 {
                                samples.append(.init(angleDeltaDegrees: delta, velocityDelta: power,
                                    outcome: AccuracyShotJudgement.evaluate(simulate(delta, power), pocketIndex: pocket)))
                            }
                        }
                    }
                    let proof = TrainingPotProof(board: board, prediction: actual, velocity: speed, tip: tip, samples: samples)
                    if accepted == nil || proof.perturbationSuccesses > accepted!.perturbationSuccesses { accepted = proof }
                    if proof.qualifiesForAccuracy { break }
                }
                if let accepted { boardProofs.append(accepted) }
            }
            guard !boardProofs.isEmpty else { unsolved += 1; continue }
            boards.append(board); proofs += boardProofs
            variants += boardProofs.filter(\.qualifiesForAccuracy).map { .init(boardID: board.id, proofID: $0.id, tip: $0.tip) }
            if boards.count % 10 == 0 {
                let checkpoint = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
                    boards: boards, proofs: proofs, variants: variants)
                try JSONEncoder().encode(checkpoint).write(to: root.appendingPathComponent("output/accuracy-practice-20261020/checkpoint-bank.json"), options: .atomic)
            }
            print("ACCURACY_BANK progress boards=\(boards.count) proofs=\(proofs.count) variants=\(variants.count) attempts=\(attempted) seconds=\(Date().timeIntervalSince(start))")
        }
        let bank = TrainingQuestionBank(schemaVersion: TrainingQuestionBank.schema, sourceFingerprint: request.sourceFingerprint,
                                       boards: boards, proofs: proofs, variants: variants)
        try bank.validate(expectedFingerprint: request.sourceFingerprint)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let output = root.appendingPathComponent("output/accuracy-practice-20261020/pilot-bank.json")
        try encoder.encode(bank).write(to: output, options: .atomic)
        print("ACCURACY_BANK output=\(output.path) boards=\(boards.count) unsolvedWithinBudget=\(unsolved) seconds=\(Date().timeIntervalSince(start))")
        if request.count >= 100 {
            var coverage: [String: String] = [:]
            for vertical in [false, true] {
                for lateral in [false, true] {
                    var config = SceneTrainingConfiguration()
                    config.allowsVerticalSpin = vertical; config.allowsSideSpin = lateral
                    let key = "vertical=\(vertical),side=\(lateral)"
                    do {
                        for seed in 1...10 {
                            let batch = try bank.accuracyBatch(config, seed: UInt64(seed))
                            XCTAssertEqual(Set(batch.map { $0.0.id }).count, 20)
                            XCTAssertEqual(batch.map { $0.1.tip.rawValue }.sorted(), TrainingFixedTip.quota(config).map(\.rawValue).sorted())
                            XCTAssertTrue(batch.allSatisfy { $0.0.matches(config) })
                        }
                        coverage[key] = "10 seeds passed"
                    } catch { coverage[key] = error.localizedDescription }
                }
            }
            let report = root.appendingPathComponent("output/accuracy-practice-20261020/sampling-report.json")
            try encoder.encode(coverage).write(to: report, options: .atomic)
            print("ACCURACY_BANK sampling=\(coverage)")
            XCTAssertTrue(coverage.values.allSatisfy { $0 == "10 seeds passed" }, "Pilot exists but default twenty-question coverage is not ready")
        }
        XCTAssertEqual(boards.count, request.count, "Finite search budget exhausted; not a proof of impossibility")
    }
}
