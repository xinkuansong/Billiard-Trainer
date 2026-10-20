import XCTest
import SceneKit
@testable import QiuJi

final class AccuracyPracticeIntegrationTests: XCTestCase {
    /// One-use review export of the production draw, without a second generator or solver.
    func testExportCurrentTwentyQuestionReview() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/accuracy-runtime-twenty-20261021")
        let request = directory.appendingPathComponent("request.json")
        guard FileManager.default.fileExists(atPath: request.path) else { throw XCTSkip("Explicit review request required") }
        struct Request: Decodable { let seed: UInt64 }
        struct Sample: Encodable {
            let number: Int
            let board: TrainingBankBoard
            let generationP: TrainingBankPoint
            let generationGhost: TrainingBankPoint
            let actualGhost: TrainingBankPoint
            let railGap: Float
        }
        struct Export: Encodable {
            let seed: UInt64
            let bankSHA256: String
            let configuration: SceneTrainingConfiguration
            let weights: [[Double]]
            let samples: [Sample]
        }
        let spec = try JSONDecoder().decode(Request.self, from: Data(contentsOf: request))
        try FileManager.default.moveItem(at: request, to: directory.appendingPathComponent("consumed-request.json"))
        let config = SceneTrainingConfiguration(), bank = try TrainingBankStore.load()
        let batch = try bank.draw(config, seed: spec.seed)
        XCTAssertEqual(batch.boards.count, 20)
        XCTAssertEqual(Set(batch.boards.map(\.id)).count, 20)
        XCTAssertTrue(batch.distribution.calibrated)
        let targets = Dictionary(uniqueKeysWithValues: bank.payload.targets.map { ($0.inventoryTargetIndex, $0) })
        let samples = try batch.boards.enumerated().map { number, board -> Sample in
            let parts = board.id.split(separator: ":")
            let index = try XCTUnwrap(Int(parts[1])), target = try XCTUnwrap(targets[index])
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: board.target.vector,
                pocket: board.effectiveAim.vector, ballRadius: BallPhysics.radius)
            XCTAssertEqual(board.question.geometry.actualAngle, board.angle)
            return Sample(number: number + 1, board: board, generationP: .init(target.aim.vector),
                generationGhost: .init(target.ghost.vector), actualGhost: .init(ghost),
                railGap: SceneTrainingRailGeometry.clearance(board.target.vector))
        }
        let result = Export(seed: spec.seed, bankSHA256: bank.sourceFingerprint, configuration: config,
                            weights: TrainingCombinationWeights.defaults, samples: samples)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: directory.appendingPathComponent("native-twenty.json"), options: .atomic)
        print("RUNTIME_TWENTY_EXPORTED seed=\(spec.seed) count=\(samples.count)")
    }

    func testCurrentBundleIdentityAndNoLegacyFallback() throws {
        let bank = try TrainingBankStore.load()
        XCTAssertEqual(bank.sourceFingerprint, "dd1635cc831da18553a81ade07c9651dc4636c2598c00edfca2d0726ae8f1c35")
        XCTAssertEqual(bank.counts.reduce(0, +), 782_528)
        XCTAssertEqual(bank.counts.filter { $0 > 0 }.count, 178)
        XCTAssertEqual(bank.payload.counts, ["corner": 580804, "middle": 201724])
        XCTAssertNil(Bundle.main.url(forResource: "training-question-bank", withExtension: "json"))
        XCTAssertEqual(bank.payload.combinationTable.indices.filter {
            let c = bank.payload.combinationTable[$0]; return c.pocketType == 1 && c.railIndex == 2
        }.reduce(0) { $0 + bank.counts[$1] }, 0)
    }

    func testNativeProbabilitiesMatchIndependentPythonCalibration() throws {
        struct Golden: Decodable { let code: Int; let count: Int; let calibratedProbability: Double }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "grid-calibrated-probabilities", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let golden = try JSONDecoder().decode([Golden].self, from: data)
        let bank = try TrainingBankStore.load(), fit = try bank.distribution(.init())
        XCTAssertTrue(fit.calibrated); XCTAssertFalse(fit.restrictedSupport)
        XCTAssertLessThan(fit.maxError, 1e-10)
        for cell in golden {
            XCTAssertEqual(bank.counts[cell.code], cell.count)
            XCTAssertEqual(fit.probabilities[cell.code], cell.calibratedProbability, accuracy: 1e-9)
        }
        XCTAssertEqual(fit.probabilities.reduce(0, +), 1, accuracy: 1e-10)
    }

    func testTwoHundredThousandActualDrawsAndRoundUniqueness() throws {
        let bank = try TrainingBankStore.load()
        let byID = Dictionary(uniqueKeysWithValues: bank.payload.combinationTable.enumerated().map { ($0.element.id, $0.offset) })
        var observed = TrainingCombinationWeights.defaults.map { Array(repeating: 0, count: $0.count) }
        let start = Date()
        for round in 0..<10_000 {
            let draw = try bank.draw(.init(), seed: UInt64(20261021 + round))
            XCTAssertEqual(draw.boards.count, 20)
            XCTAssertEqual(Set(draw.boards.map(\.id)).count, 20)
            for board in draw.boards {
                let code = try XCTUnwrap(byID[try XCTUnwrap(board.combinationID)])
                for (axis, value) in bank.payload.combinationTable[code].axes.enumerated() { observed[axis][value] += 1 }
            }
        }
        let frequencies = observed.map { $0.map { Double($0) / 200_000 } }
        for axis in frequencies.indices {
            for value in frequencies[axis].indices {
                XCTAssertEqual(frequencies[axis][value], TrainingCombinationWeights.defaults[axis][value], accuracy: 0.004)
            }
        }
        let report: [String: Any] = ["draws": 200000, "rounds": 10000, "observed": frequencies,
                                   "weights": TrainingCombinationWeights.defaults, "seconds": Date().timeIntervalSince(start)]
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/accuracy-weight-integration-20261021")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("native-sampling.json"), options: .atomic)
        print("NATIVE_SAMPLING \(report)")
    }

    func testStoredCombinationRestorationAllCellsAndUnavailableCells() throws {
        let bank = try TrainingBankStore.load()
        var differentGenerationAngles = 0
        var maxAngleDifference = 0.0
        let angles: [SceneTrainingConfiguration.AngleRange] = [.straight, .small, .medium, .large, .thin]
        let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
        for code in bank.pools.indices {
            let cell = bank.payload.combinationTable[code]
            var config = SceneTrainingConfiguration()
            config.angleSelection = [angles[cell.angleIndex]]
            config.pocketSelection = [cell.pocketType == 0 ? .corner : .side]
            config.cueDistanceSelection = [distances[cell.cueIndex]]
            config.pocketDistanceSelection = [distances[cell.objectIndex]]
            // Off-rail is only selectable through random, so test its boards directly.
            if cell.railIndex != 0 {
                config.railDistanceSelection = [cell.railIndex == 1 ? .near : .frozen]
                if bank.counts[code] < 20 { XCTAssertThrowsError(try bank.draw(config, seed: 1)) }
                else {
                    let draw = try bank.draw(config, seed: 1)
                    XCTAssertTrue(draw.boards.allSatisfy { $0.combinationID == cell.id })
                    XCTAssertEqual(Set(draw.boards.map(\.id)).count, 20)
                }
            }
            for ref in [bank.pools[code].first, bank.pools[code].last].compactMap({ $0 }) {
                let b = bank.board(reference: ref, combination: code)
                XCTAssertTrue(b.matches(config), "\(cell.id): \(b.id)")
                let t = bank.payload.targets[Int(ref >> 12)]
                XCTAssertEqual(b.target.x, Float(t.object.x)); XCTAssertEqual(b.target.z, Float(t.object.z))
                let gc = hypot(Double(b.cue.x) - t.ghost.x, Double(b.cue.z) - t.ghost.z)
                XCTAssertEqual(gc, bank.payload.distanceSamples[Int(ref & 15)], accuracy: 2e-7)
                // Independently recover the signed angle from dot/cross products.
                let bx = t.ghost.x-t.object.x, bz = t.ghost.z-t.object.z
                let cx = Double(b.cue.x)-t.ghost.x, cz = Double(b.cue.z)-t.ghost.z
                let recovered = atan2(bx*cz-bz*cx, bx*cx+bz*cz) * 180 / .pi
                XCTAssertEqual(recovered, Double(Int((ref >> 4) & 255)-85), accuracy: 0.00003)
                let correctAim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: b.target.vector, pocketIndex: b.pocketIndex, surfaceY: 0)
                XCTAssertEqual(b.effectiveAim.x, correctAim.x); XCTAssertEqual(b.effectiveAim.z, correctAim.z)
                let actualAngle = AngleSceneCalculator.cutAngle(cueBall: b.cue.vector, targetBall: b.target.vector, pocket: correctAim)
                XCTAssertEqual(b.angle, actualAngle, accuracy: 1e-9)
                XCTAssertEqual(b.question.geometry.actualAngle, actualAngle, accuracy: 1e-9)
                XCTAssertEqual(b.generationAngle, Double(abs(Int((ref >> 4) & 255)-85)))
                let difference = abs(b.angle - (b.generationAngle ?? b.angle))
                if difference > 0.01 { differentGenerationAngles += 1 }
                maxAngleDifference = max(maxAngleDifference, difference)
                XCTAssertEqual(b.qualification, cell.pocketType == 0 ? "geometry-candidate" : "center-direct-five-v4")
            }
        }
        XCTAssertGreaterThan(differentGenerationAngles, 0, "Generation angle must not be used as the answer")
        print("GRID_ANSWER_AUDIT representativeAnglesDifferent=\(differentGenerationAngles) maxDifferenceDegrees=\(maxAngleDifference)")
    }

    func testRepeatabilityRecentExclusionMultiSelectionAndInfeasibleTargets() throws {
        let bank = try TrainingBankStore.load()
        var config = SceneTrainingConfiguration(); config.angleSelection = [.small, .large]
        let one = try bank.draw(config, seed: 42), two = try bank.draw(config, seed: 42)
        XCTAssertEqual(one.boards.map(\.id), two.boards.map(\.id))
        XCTAssertTrue(one.boards.allSatisfy { $0.matches(config) })
        let fit = try bank.distribution(config)
        XCTAssertTrue(fit.calibrated)
        for angle in [1, 3] {
            XCTAssertEqual(bank.payload.combinationTable.indices.filter { bank.payload.combinationTable[$0].angleIndex == angle }
                .reduce(0) { $0 + fit.probabilities[$1] }, 0.5, accuracy: 1e-9)
        }
        let seen = Set(one.boards.map(\.id)), next = try bank.draw(config, seed: 42, excluding: seen)
        XCTAssertTrue(Set(next.boards.map(\.id)).isDisjoint(with: seen))
        var middleFrozen = SceneTrainingConfiguration(); middleFrozen.pocketSelection = [.side]; middleFrozen.railDistanceSelection = [.frozen]
        XCTAssertThrowsError(try bank.draw(middleFrozen, seed: 42))
        let cells = [TrainingCombinationWeights.Cell(id: "x", angleIndex: 0, pocketType: 0, cueIndex: 0, objectIndex: 0, railIndex: 0),
                     .init(id: "y", angleIndex: 1, pocketType: 0, cueIndex: 1, objectIndex: 0, railIndex: 0)]
        let impossible = try TrainingCombinationWeights.fit(cells: cells, counts: [100,100],
            targets: [[0.5,0.5,0,0,0], [1,0], [0.9,0.1,0], [1,0,0], [1,0,0]])
        XCTAssertFalse(impossible.calibrated); XCTAssertNotNil(impossible.notice)
        XCTAssertEqual(impossible.probabilities, [0.9,0.1])
    }

    func testPreparedRoundsAssignTipsWithoutSavedSolutionsAndPersistBothModes() throws {
        for vertical in [false, true] {
            for lateral in [false, true] {
                var config = SceneTrainingConfiguration(); config.allowsVerticalSpin = vertical; config.allowsSideSpin = lateral
                for seed in 0..<20 {
                let prepared = try AccuracyPreparedRound.prepare(config, excluding: [], seed: UInt64(7000+seed))
                let profile = AccuracyTipSelector.renderedProfile()
                for question in prepared.questions {
                    let tip = try XCTUnwrap(question.exactTip)
                    let access = AccuracyTipSelector.access(question.board, profile: profile)
                    XCTAssertTrue(access.isAvailable(spinX: Double(tip.x), spinY: Double(tip.y)))
                    XCTAssertNotNil(access.resolvedPose(spinX: Double(tip.x), spinY: Double(tip.y)))
                    if !lateral { XCTAssertEqual(tip.x, 0) }
                    if !vertical && lateral { XCTAssertEqual(tip.y, 0) }
                    if !vertical && !lateral {
                        XCTAssertGreaterThanOrEqual(tip.y, 0)
                        XCTAssertEqual(tip.raisedForClearance, tip.y > 0)
                    }
                }
                XCTAssertTrue(prepared.questions.allSatisfy { $0.board.id.hasPrefix("grid-v3:") && $0.board.combinationID != nil })
                for mode in [false, true] {
                    let record = try AccuracyPracticeRecord(ownerKey: "sampler-test", is3D: mode, configuration: config,
                        bankFingerprint: prepared.fingerprint, questions: prepared.questions)
                    let decoded = try JSONDecoder().decode(AccuracyPracticeRecord.self, from: JSONEncoder().encode(record))
                    XCTAssertEqual(decoded.questions.map { $0.board.combinationID }, record.questions.map { $0.board.combinationID })
                    XCTAssertEqual(decoded.questions.map { $0.board.id }, record.questions.map { $0.board.id })
                    XCTAssertEqual(decoded.questions.map(\.exactTip), record.questions.map(\.exactTip))
                    XCTAssertEqual(decoded.is3D, mode)
                }
                }
            }
        }
    }
}
