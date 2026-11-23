import XCTest
import SceneKit
@testable import QiuJi

/// An offline second pass searches a neighbourhood of a real pot, rather than
/// accepting the first edge-of-pocket solution returned by the fast solver.
final class TrainingQuestionBankRefinementTests: XCTestCase {
    func testRefineOfflineBank() throws {
        struct Request: Decodable { let limit: Int; let sourceFingerprint: String }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("output/accuracy-practice-20261020")
        let requestURL = directory.appendingPathComponent("refinement-request.json")
        guard FileManager.default.fileExists(atPath: requestURL.path) else {
            throw XCTSkip("Offline refinement requires an explicit request")
        }
        let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL))
        try FileManager.default.removeItem(at: requestURL)
        let bank = try JSONDecoder().decode(TrainingQuestionBank.self,
            from: Data(contentsOf: directory.appendingPathComponent("pilot-bank.json")))
        try bank.validate(expectedFingerprint: request.sourceFingerprint)
        var proofs = bank.proofs
        var examined = 0, improved = 0
        let start = Date()
        // Centre-ball thin cuts first: the all-centre default is the pilot's
        // only missing default quota. Other tips already pass their batch gate.
        for tip in TrainingFixedTip.allCases {
            for board in bank.boards.sorted(by: { $0.angle > $1.angle }) {
                guard let index = proofs.firstIndex(where: { $0.boardID == board.id && $0.tip == tip }),
                      !proofs[index].qualifiesForAccuracy, examined < request.limit else { continue }
                examined += 1
                let original = proofs[index]
                let offsets: [Float] = [0, 0.025, -0.025, 0.05, -0.05, 0.075, -0.075,
                    0.1, -0.1, 0.15, -0.15, 0.2, -0.2, 0.3, -0.3]
                var accepted: TrainingPotProof?
                for offset in offsets {
                    let direction = original.direction.vector.rotatedY(offset * .pi / 180)
                    func simulate(_ delta: Float, _ power: Float) -> ShotPrediction {
                        ShotPredictor.simulateFree(cueBall: board.cue.vector,
                            aimDir: direction.rotatedY(delta * .pi / 180),
                            velocity: original.velocity + power, spinX: tip.x, spinY: tip.y, surfaceY: 0,
                            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector)])
                    }
                    let nominal = simulate(0, 0)
                    guard AccuracyShotJudgement.evaluate(nominal, pocketIndex: board.pocketIndex) == .success else { continue }
                    var samples = [TrainingToleranceSample(angleDeltaDegrees: 0, velocityDelta: 0, outcome: .success)]
                    var failed = false
                    for delta: Float in [-TrainingPotProof.angleRadius, 0, TrainingPotProof.angleRadius] {
                        for power: Float in [-TrainingPotProof.speedRadius, 0, TrainingPotProof.speedRadius]
                            where delta != 0 || power != 0 {
                            let outcome = AccuracyShotJudgement.evaluate(simulate(delta, power), pocketIndex: board.pocketIndex)
                            samples.append(.init(angleDeltaDegrees: delta, velocityDelta: power, outcome: outcome))
                            if outcome != .success { failed = true; break }
                        }
                        if failed { break }
                    }
                    guard !failed else { continue }
                    let candidate = TrainingPotProof(board: board, prediction: nominal,
                        velocity: original.velocity, tip: tip, samples: samples)
                    if candidate.qualifiesForAccuracy { accepted = candidate; break }
                }
                if let accepted { proofs[index] = accepted; improved += 1 }
                print("BANK_REFINE examined=\(examined) improved=\(improved) angle=\(board.angle) tip=\(tip.rawValue) seconds=\(Date().timeIntervalSince(start))")
            }
        }
        let refined = TrainingQuestionBank(schemaVersion: bank.schemaVersion, sourceFingerprint: bank.sourceFingerprint,
            boards: bank.boards, proofs: proofs, variants: proofs.filter(\.qualifiesForAccuracy).map {
                .init(boardID: $0.boardID, proofID: $0.id, tip: $0.tip)
            })
        try refined.validate(expectedFingerprint: request.sourceFingerprint)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(refined).write(to: directory.appendingPathComponent("refined-bank.json"), options: .atomic)
        var report: [String: String] = [:]
        for vertical in [false, true] {
            for lateral in [false, true] {
                var config = SceneTrainingConfiguration()
                config.allowsVerticalSpin = vertical; config.allowsSideSpin = lateral
                let key = "vertical=\(vertical),side=\(lateral)"
                do {
                    for seed in 1...10 {
                        let batch = try refined.accuracyBatch(config, seed: UInt64(seed))
                        XCTAssertEqual(Set(batch.map { $0.0.id }).count, 20)
                        XCTAssertEqual(batch.map { $0.1.tip.rawValue }.sorted(),
                            TrainingFixedTip.quota(config).map(\.rawValue).sorted())
                    }
                    report[key] = "10 seeds passed"
                } catch { report[key] = error.localizedDescription }
            }
        }
        try encoder.encode(report).write(to: directory.appendingPathComponent("refined-sampling-report.json"), options: .atomic)
        print("BANK_REFINE sampling=\(report)")
    }
}
