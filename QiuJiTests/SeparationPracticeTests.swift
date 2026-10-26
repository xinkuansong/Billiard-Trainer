import XCTest
import SwiftData
import SceneKit
@testable import QiuJi

@MainActor
final class SeparationPracticeTests: XCTestCase {
    func testTrajectoryScoreGeometryAndInvalidInputs() throws {
        func line(_ p: [(Float, Float)], timeScale: Float = 1) -> [SeparationTrajectory.Point] {
            p.enumerated().map { .init(time: Float($0.offset) * timeScale,
                position: .init(SCNVector3($0.element.0, 0, $0.element.1)), isEvent: true) }
        }
        let straight = line([(0, 0), (1, 0)])
        let same = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: straight, actual: straight))
        XCTAssertEqual(same.value, 100, accuracy: 1e-10)
        let offset = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: straight, actual: line([(0, 0.2), (1, 0.2)])))
        XCTAssertEqual(try XCTUnwrap(offset.rmsDistanceCM), 20, accuracy: 1e-5)
        XCTAssertNil(offset.meanDTWCM); XCTAssertNil(offset.frechetCM)
        XCTAssertEqual(offset.version, "arc1cm-rms-p2-t20-potgate-v3")
        XCTAssertEqual(offset.value, 50, accuracy: 1e-5)
        let reverse = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: straight, actual: line([(1, 0), (0, 0)])))
        XCTAssertGreaterThan(reverse.distanceCM, 50)
        XCTAssertLessThan(reverse.value, 30)
        let longer = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: straight, actual: line([(0, 0), (1.6, 0)])))
        XCTAssertGreaterThan(longer.distanceCM, 0)
        XCTAssertEqual(try SeparationTrajectoryScore.evaluate(target: straight, actual: line([(0, 0), (1, 0)], timeScale: 9))?.value, 100)
        XCTAssertNil(try SeparationTrajectoryScore.evaluate(target: straight, actual: []))
        XCTAssertThrowsError(try SeparationTrajectoryScore.evaluate(target: straight, actual: line([(.nan, 0)])))
        let stationary = try XCTUnwrap(SeparationTrajectoryScore.evaluate(target: line([(0, 0), (0, 0)]), actual: line([(0.03, 0.04)])))
        XCTAssertEqual(stationary.distanceCM, 5, accuracy: 1e-6)
        let corners: [SIMD2<Double>] = [.init(0, 0), .init(10, 0), .init(10, 20)]
        let sampled = try SeparationTrajectoryMetric.resample(corners, budget: 8, mandatory: [1])
        XCTAssertTrue(sampled.contains(corners[1])); XCTAssertEqual(sampled.first, corners.first)
        XCTAssertEqual(sampled.last, corners.last)
    }
    func testRMSFullPathAnalyticCasesAndPolylineDensity() throws {
        func distance(_ a: [SIMD2<Double>], _ b: [SIMD2<Double>]) throws -> Double {
            try SeparationArcRMSMetric.distance(SeparationArcRMSMetric.sample(a), SeparationArcRMSMetric.sample(b))
        }
        let full: [SIMD2<Double>] = [.init(0, 0), .init(200, 0)]
        let half: [SIMD2<Double>] = [.init(0, 0), .init(100, 0)]
        // Analytic integral: integral(0...100) x² dx / (200+100).
        XCTAssertEqual(try distance(full, half), 100.0 / 3, accuracy: 0.001)
        XCTAssertEqual(try distance(full, half), try distance(half, full), accuracy: 1e-10)
        let shortTail = try distance(full, [.init(0, 0), .init(220, 0)])
        XCTAssertEqual(shortTail, sqrt(pow(20, 3) / (3 * 420)), accuracy: 0.002)
        XCTAssertGreaterThan(100 * exp2(-shortTail / 20), 90)
        XCTAssertEqual(try distance([.zero], full), 200 / sqrt(3), accuracy: 0.001)
        let corners: [SIMD2<Double>] = [.zero, .init(100, 0), .init(100, 100)]
        let dense: [SIMD2<Double>] = [.zero, .zero, .init(50, 0), .init(100, 0), .init(100, 40), .init(100, 100)]
        XCTAssertEqual(try distance(corners, dense), 0, accuracy: 1e-10)
        // Equivalent polylines can differ by Double interpolation roundoff (~1e-15 cm).
        XCTAssertEqual(try distance(corners.map { $0 + .init(20, -30) }, dense.map { $0 + .init(20, -30) }), 0, accuracy: 1e-10)
        let detour: [SIMD2<Double>] = [.zero, .init(100, 0), .init(100, 50), .init(100, 0), .init(200, 0)]
        XCTAssertLessThan(100 * exp2(-(try distance(full, detour)) / 20), 65)
    }
    func testRMSAndLegacyScoresRoundTripWithoutRegrading() throws {
        let legacyJSON = Data(#"{"version":"arc512-dtw70-frechet30-t20-potgate-v2","meanDTWCM":10,"frechetCM":30,"matchingLength":520,"targetSampleCount":512,"actualSampleCount":514}"#.utf8)
        let legacy = try JSONDecoder().decode(SeparationTrajectoryScore.self, from: legacyJSON)
        XCTAssertNil(legacy.rmsDistanceCM)
        XCTAssertEqual(legacy.distanceCM, 16)
        XCTAssertEqual(legacy.value, 100 * exp2(-16.0 / 20), accuracy: 1e-10)
        let current = SeparationTrajectoryScore(rmsDistanceCM: 20, targetSampleCount: 200, actualSampleCount: 200)
        for score in [legacy, current] {
            XCTAssertEqual(try JSONDecoder().decode(SeparationTrajectoryScore.self, from: JSONEncoder().encode(score)), score)
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        XCTAssertNil(json["meanDTWCM"]); XCTAssertNil(json["frechetCM"])
        var corrupt = json; corrupt.removeValue(forKey: "rmsDistanceCM")
        XCTAssertThrowsError(try JSONDecoder().decode(SeparationTrajectoryScore.self,
            from: JSONSerialization.data(withJSONObject: corrupt)))
    }
    func testRMSCalculationHonorsCancellation() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try SeparationArcRMSMetric.sample([.zero, .init(400, 0)])
        }
        do { _ = try await task.value; XCTFail("Cancelled score computation must stop") }
        catch is CancellationError {} // Expected cancellation, not a grading failure.
    }
    func testScoreSnapshotsFirstAttemptRetryLegacyAndFreeContinuation() throws {
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let q = prepared.question
        let prediction = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        let first = try SeparationShot(question: q, input: q.answer, prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(try XCTUnwrap(first.score).value, 100, accuracy: 0.0001)
        XCTAssertEqual(first.score?.version, SeparationTrajectoryScore.algorithm)
        var record = SeparationPracticeRecord(ownerKey: "score-fixture", is3D: true, configuration: .init(), prepared: prepared)
        record.accept(first)
        var retry = first
        retry.score = .init(rmsDistanceCM: 16, targetSampleCount: 200, actualSampleCount: 200)
        record.accept(retry)
        XCTAssertEqual(record.averageScore, first.score?.value)
        XCTAssertEqual(record.latestShot?.score, retry.score)
        XCTAssertEqual(record.attempts.count, 1)
        let decoded = try SeparationPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(decoded.attempts.first?.score, first.score)
        XCTAssertEqual(decoded.latestShot?.score, retry.score)
        let next = record.continuation(prepared: prepared)
        XCTAssertEqual(next.totalScoredCount, 1); XCTAssertEqual(next.averageScore, record.averageScore)
        XCTAssertNil(next.segmentAverageScore)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as? [String: Any])
        json.removeValue(forKey: "score")
        let legacy = try JSONDecoder().decode(SeparationShot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.score); XCTAssertEqual(legacy.scoreText, "未评分")
        XCTAssertEqual(legacy.trajectory.count, first.trajectory.count)
        XCTAssertTrue(q.target.contains { $0.isEvent == true })
    }
    func testCueBallPocketedScoresZeroIncludingNoContactAndCountsInAverages() throws {
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let q = prepared.question
        let prediction = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        let good = try SeparationShot(question: q, input: q.answer, prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(try XCTUnwrap(good.score).value, 100, accuracy: 0.0001)
        // Isolate the scoring policy from the physical solver: even a matching route loses on a scratch.
        var scratched = prediction
        scratched.cuePocketed = true
        scratched.pocketedBalls.append(ShotInput.cueBallName)
        let foul = try SeparationShot(question: q, input: q.answer, prediction: scratched, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(foul.score?.value, 0)
        XCTAssertEqual(foul.score?.zeroReason, .cuePocketed)
        XCTAssertEqual(foul.resultText, "本杆得分 0.0分 · 母球落袋")
        for is3D in [false, true] {
            var record = SeparationPracticeRecord(ownerKey: "scratch-zero", is3D: is3D,
                configuration: .init(), prepared: prepared)
            var first = foul; first.playsStroke = is3D
            record.accept(first); record.accept(good); record.accept(good)
            XCTAssertEqual(record.averageScore, 0)
            XCTAssertEqual(record.totalScoredCount, 1)
            XCTAssertEqual(try XCTUnwrap(record.currentQuestionAverage()), 50, accuracy: 0.0001)
            let restored = try SeparationPracticeRecord.decodePayload(record.encodedPayload())
            XCTAssertEqual(restored.attempts.first?.score?.value, 0)
            XCTAssertEqual(restored.currentQuestionAverage(), record.currentQuestionAverage())
            XCTAssertEqual(restored.continuation(prepared: prepared).averageScore, 0)
            XCTAssertTrue(restored.historyDetail.contains("首杆均分 0.0"))
            var retryRecord = SeparationPracticeRecord(ownerKey: "scratch-retry", is3D: is3D,
                configuration: .init(), prepared: prepared)
            retryRecord.accept(good); retryRecord.accept(foul)
            XCTAssertEqual(retryRecord.latestShot?.score?.value, 0)
            XCTAssertEqual(try XCTUnwrap(retryRecord.currentQuestionAverage()), 50, accuracy: 0.0001)
            XCTAssertEqual(try XCTUnwrap(retryRecord.averageScore), 100, accuracy: 0.0001)
        }
        scratched.recorder = TrajectoryRecorder() // no ball-ball contact, but a settled scratch
        let noContact = try SeparationShot(question: q, input: q.answer, prediction: scratched, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertTrue(noContact.trajectory.isEmpty)
        XCTAssertEqual(noContact.score?.value, 0)
        XCTAssertEqual(noContact.resultText, "本杆得分 0.0分 · 母球落袋")
        // Old immutable snapshots keep their recorded grading policy.
        let oldScore = SeparationTrajectoryScore(version: SeparationTrajectoryScore.legacyAlgorithm,
            meanDTWCM: 0, frechetCM: 0, matchingLength: 512, targetSampleCount: 512, actualSampleCount: 512)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldScore)) as? [String: Any])
        legacy.removeValue(forKey: "zeroReason"); legacy["version"] = "arc512-dtw70-frechet30-t20-v1"
        XCTAssertEqual(try JSONDecoder().decode(SeparationTrajectoryScore.self,
            from: JSONSerialization.data(withJSONObject: legacy)).value, 100, accuracy: 0.0001)
    }
    func testMissedTargetScoresZeroWithRealLowPowerAndNoContact() throws {
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let q = prepared.question
        let input = SeparationInput(velocity: 0.5)
        var weak = try SeparationQuestionGenerator.solve(board: q.board, input: input,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        XCTAssertFalse(SeparationQuestionGenerator.potsSpecifiedPocket(weak, pocket: q.board.pocketIndex))
        XCTAssertFalse(weak.cuePocketed)
        let missed = try SeparationShot(question: q, input: input, prediction: weak, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(missed.score?.value, 0)
        XCTAssertEqual(missed.score?.zeroReason, .targetNotPotted)
        XCTAssertEqual(missed.resultText, "本杆得分 0.0分 · 目标球未进指定袋")
        for is3D in [false, true] {
            var record = SeparationPracticeRecord(ownerKey: "missed-target", is3D: is3D,
                configuration: .init(), prepared: prepared)
            record.accept(missed); record.accept(missed)
            let restored = try SeparationPracticeRecord.decodePayload(record.encodedPayload())
            XCTAssertEqual(restored.averageScore, 0)
            XCTAssertEqual(restored.currentQuestionAverage(), 0)
            XCTAssertEqual(restored.totalScoredCount, 1)
            XCTAssertEqual(restored.latestShot?.resultText, missed.resultText)
            XCTAssertEqual(restored.continuation(prepared: prepared).averageScore, 0)
        }
        weak.recorder = TrajectoryRecorder(); weak.events = []
        let noContact = try SeparationShot(question: q, input: input, prediction: weak, surfaceY: BTTablePhysics.surfaceY)
        XCTAssertTrue(noContact.trajectory.isEmpty)
        XCTAssertEqual(noContact.score?.value, 0)
        XCTAssertEqual(noContact.resultText, missed.resultText)
        // A scratch takes priority when both conditions fail.
        weak.cuePocketed = true
        XCTAssertEqual(try SeparationShot(question: q, input: input, prediction: weak,
            surfaceY: BTTablePhysics.surfaceY).score?.zeroReason, .cuePocketed)
    }
    func testResizedCustomControlsUseNativeSlotsWithoutChangingSavedIntent() {
        let values: FreeControlValues = ["power": .init(x: 0.9, y: 0.55), "strike": .init(x: 0.9, y: 0.8)]
        let frames = ["power": CGRect(x: 700, y: 300, width: 44, height: 200),
                      "strike": CGRect(x: 700, y: 600, width: 60, height: 60)]
        let source = FreeControlWindow(width: 1000, height: 800)
        XCTAssertTrue(FreeControlResizeSafety.needsNativeSlots(values: values, frames: frames,
            window: CGSize(width: 500, height: 400), source: source))
        XCTAssertFalse(FreeControlResizeSafety.needsNativeSlots(values: values, frames: frames,
            window: CGSize(width: 1000, height: 800), source: source))
        XCTAssertTrue(FreeControlResizeSafety.needsNativeSlots(values: values, frames: frames,
            window: CGSize(width: 500, height: 400), source: nil))
        XCTAssertEqual(values["strike"]?.scale, 1)
    }
    func testQuestionRepeatMeanIsDurableIdempotentAndSeparateFromFirstShotMean() throws {
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let question = prepared.question
        let prediction = try SeparationQuestionGenerator.solve(board: question.board, input: question.answer,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        func shot(distance: Double?) throws -> SeparationShot {
            var shot = try SeparationShot(question: question, input: question.answer, prediction: prediction,
                surfaceY: BTTablePhysics.surfaceY)
            shot.score = distance.map { .init(rmsDistanceCM: $0, targetSampleCount: 200, actualSampleCount: 200) }
            return shot
        }
        let first = try shot(distance: 0), retry = try shot(distance: 20), third = try shot(distance: 40)
        var record = SeparationPracticeRecord(ownerKey: "repeat-scores", is3D: false, configuration: .init(), prepared: prepared)
        record.accept(first); record.accept(retry); record.accept(third); record.accept(third)
        XCTAssertEqual(try XCTUnwrap(record.currentQuestionAverage()), 175.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(record.currentQuestionAverage(excluding: third.id), 75)
        XCTAssertEqual(record.averageScore, 100)
        XCTAssertEqual(record.latestShot?.score?.value, 25)
        XCTAssertEqual(record.attempts.count, 1)
        let decoded = try SeparationPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertEqual(decoded.currentQuestionAverage(), record.currentQuestionAverage())
        record.accept(try shot(distance: nil))
        XCTAssertEqual(record.currentQuestionAverage(), decoded.currentQuestionAverage())
        XCTAssertNil(record.latestShot?.score)
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
        legacyJSON.removeValue(forKey: "currentQuestionScores")
        let legacy = try JSONDecoder().decode(SeparationPracticeRecord.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertEqual(legacy.currentQuestionAverage(), 62.5) // Only first/latest survive in the old format.
        let nextPrepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261023)
        record.questions.append(nextPrepared.question); record.cursor += 1; record.latestShot = nil
        XCTAssertNil(record.currentQuestionAverage()); XCTAssertEqual(record.averageScore, 100)
        XCTAssertNil(decoded.continuation(prepared: nextPrepared).currentQuestionAverage())
    }
    func testPlayerPowerUsesStandardRangeWhileQuestionSamplingRetainsItsCap() throws {
        XCTAssertTrue(SeparationInput(velocity: 8).isValid)
        XCTAssertFalse(SeparationInput(velocity: 8.01).isValid)
        XCTAssertFalse(SeparationInput(velocity: 0.49).isValid)
        XCTAssertEqual(SeparationQuestionGenerator.speedRange.upperBound, 4.5)
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        XCTAssertLessThanOrEqual(prepared.question.answer.velocity, 4.5)
        let prediction = try SeparationQuestionGenerator.solve(board: prepared.question.board, input: .init(velocity: 8),
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        XCTAssertTrue(prediction.hasFinalTableState)
        XCTAssertEqual(prediction.recorder?.cueStrikeSpeed, 8)
    }
    func testMinimumSpeedDenseAuditLowTipCounterexampleAndAcceptedDistribution() throws {
        var config = SceneTrainingConfiguration(); config.allowsVerticalSpin = true; config.allowsSideSpin = true
        let profile = AccuracyTipSelector.renderedProfile()
        var counterexamples = 0, bytes = 0
        var round: SeparationPracticeRecord?
        var rows: [[String: Any]] = []
        for seed in 0..<24 {
            let start = Date()
            let prepared = try SeparationQuestionGenerator.prepare(config, seed: UInt64(20261022 + seed))
            let q = prepared.question
            let answer = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer,
                surfaceY: BTTablePhysics.surfaceY, profile: profile)
            XCTAssertEqual(AccuracyShotJudgement.evaluate(answer, pocketIndex: q.board.pocketIndex), .success)
            let shot = try SeparationShot(question: q, input: q.answer, prediction: answer, surfaceY: BTTablePhysics.surfaceY)
            if round == nil { round = .init(ownerKey: "fixture", is3D: false, configuration: config, prepared: prepared) }
            else { round?.questions.append(q); round?.cursor += 1 }
            round?.accept(shot)
            bytes += try JSONEncoder().encode(shot).count + JSONEncoder().encode(q).count
            if seed < 3 {
                var first: Float?
                for step in 0...Int(((q.minimumCenterSpeed-Float(SeparationQuestionGenerator.speedRange.lowerBound))/0.005).rounded(.up)) {
                    let v = Float(SeparationQuestionGenerator.speedRange.lowerBound) + Float(step)*0.005
                    if let p = try? SeparationQuestionGenerator.solve(board: q.board, input: .init(velocity: v),
                        surfaceY: BTTablePhysics.surfaceY, profile: profile),
                        SeparationQuestionGenerator.potsSpecifiedPocket(p, pocket: q.board.pocketIndex) { first = v; break }
                }
                XCTAssertEqual(q.minimumCenterSpeed, try XCTUnwrap(first), accuracy: 0.011,
                    "Coarse search must not skip an earlier physical pocketing interval")
            }
            if let low = try? SeparationQuestionGenerator.solve(board: q.board,
                input: .init(spinX: 0, spinY: -0.3, velocity: q.minimumCenterSpeed),
                surfaceY: BTTablePhysics.surfaceY, profile: profile),
                !SeparationQuestionGenerator.potsSpecifiedPocket(low, pocket: q.board.pocketIndex) { counterexamples += 1 }
            rows.append(["seed": seed, "board": q.board.id, "minimum": q.minimumCenterSpeed,
                "accepted": [q.answer.spinX, q.answer.spinY, q.answer.velocity],
                "candidates": q.audit.sampledInputs.map { [$0.spinX, $0.spinY, $0.velocity] },
                "rejected": q.audit.rejectedInputs, "generationSeconds": q.audit.elapsedSeconds,
                "totalAuditSeconds": Date().timeIntervalSince(start)])
        }
        XCTAssertGreaterThan(counterexamples, 0, "Same-speed low-tip misses must exist and must be independently filtered")
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]),
            uniformTypeIdentifier: "public.json")
        attachment.name = "separation-24-physical-samples"; attachment.lifetime = .keepAlways; add(attachment)
        print("SEPARATION_AUDIT lowTipMisses=\(counterexamples) estimated20QuestionBase64Bytes=\(bytes*20/24*4/3)")
        let original = try XCTUnwrap(round), payload = try original.encodedPayload()
        let restored = try SeparationPracticeRecord.decodePayload(payload)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(original), try encoder.encode(restored))
        XCTAssertLessThan(payload.count*4/3, 1_900_000, "24-question sample must fit the existing 2 MB sync envelope")
        print("SEPARATION_COMPRESSED 24QuestionBase64Bytes=\(payload.count*4/3)")
    }

    private final class MemoryRepository: SeparationPracticeRepository {
        let ownerKey = "separation-test-owner"
        var saved: SeparationPracticeRecord?
        var failSubmissions = false
        var failAtomic = false
        var lastBatch: [SeparationPracticeRecord] = []
        func save(_ record: SeparationPracticeRecord) throws {
            if failSubmissions && !record.attempts.isEmpty { throw CocoaError(.fileWriteOutOfSpace) }
            saved = record
        }
        func saveAtomically(_ records: [SeparationPracticeRecord]) throws {
            if failAtomic { throw CocoaError(.fileWriteOutOfSpace) }
            if let last = records.last { try save(last) }; lastBatch = records
        }
        func resumable(is3D: Bool) throws -> SeparationPracticeRecord? { saved?.is3D == is3D ? saved : nil }
    }
    private struct PrefetchFixture {
        let vm: SeparationPracticeViewModel, repo: MemoryRepository, probe: SeparationPrefetchProbe
        let first: SeparationQuestionGenerator.Prepared, next: SeparationQuestionGenerator.Prepared
        let suite: String, defaults: UserDefaults
        @MainActor func close() { probe.releaseAll(); vm.suspendTeachingActivity(); defaults.removePersistentDomain(forName: suite) }
    }
    private func prefetchFixture(count: Int = 1, answered: Bool = true, free: Bool = false,
                                 premium: Bool = true, is3D: Bool = false, used: Int? = nil) throws -> PrefetchFixture {
        let suite = "prefetch-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = premium
        var configuration = SceneTrainingConfiguration(); configuration.freePractice = free
        let first = try SeparationQuestionGenerator.prepare(configuration, seed: 20261022)
        let next = try SeparationQuestionGenerator.prepare(configuration, excluding: [first.question.board.id], seed: 20261023)
        let prediction = try SeparationQuestionGenerator.solve(board: first.question.board, input: first.question.answer,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        let repo = MemoryRepository(), probe = SeparationPrefetchProbe(prepared: next)
        var record = SeparationPracticeRecord(ownerKey: repo.ownerKey, is3D: is3D, configuration: configuration, prepared: first)
        for i in 0..<count {
            if i > 0 {
                let q = first.question
                record.questions.append(.init(id: UUID(), board: q.board, minimumCenterSpeed: q.minimumCenterSpeed,
                    answer: q.answer, answerDirection: q.answerDirection, target: q.target, audit: q.audit))
                record.cursor += 1
            }
            if i < count - 1 || answered {
                record.accept(try SeparationShot(question: record.current!, input: first.question.answer,
                    prediction: prediction, surfaceY: BTTablePhysics.surfaceY))
            }
        }
        if !answered { record.latestShot = nil }
        record.showingResult = answered; repo.saved = record
        if let used { for _ in 0..<max(0, used - (is3D ? 0 : record.attempts.count)) { limiter.recordQuestion() } }
        let vm = SeparationPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults,
            prepareQuestion: { configuration, excluded in try probe.generate(configuration, excluded) })
        vm.setShowsReference(false); vm.setPlaysStroke(false)
        vm.attach(repository: repo); vm.setupScene()
        return .init(vm: vm, repo: repo, probe: probe, first: first, next: next, suite: suite, defaults: defaults)
    }
    private func waitForPrefetch(_ condition: () -> Bool) async throws {
        for _ in 0..<500 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition())
    }
    func testPrefetchedNextIsImmediateSingleSlotAndSaveRetryKeepsIt() async throws {
        let f = try prefetchFixture(); defer { f.close() }
        try await waitForPrefetch { f.probe.count == 1 }
        XCTAssertEqual(f.vm.record?.questions.count, 1); XCTAssertEqual(f.vm.limiter.questionsUsedToday, 1)
        XCTAssertEqual(f.probe.excluded(at: 0), [f.first.question.board.id])
        f.probe.release(0); try await waitForPrefetch { f.vm.nextQuestionReady }
        let oldID = f.vm.record?.current?.id
        f.repo.failAtomic = true; f.vm.next()
        XCTAssertEqual(f.vm.phase, .result); XCTAssertEqual(f.vm.record?.current?.id, oldID)
        XCTAssertTrue(f.vm.nextQuestionReady); XCTAssertEqual(f.probe.count, 1)
        f.repo.failAtomic = false
        let start = ProcessInfo.processInfo.systemUptime
        f.vm.next()
        XCTAssertEqual(f.vm.phase, .aiming, "A ready slot is installed in this call, without awaiting generation")
        print("PREFETCH_CACHED_NEXT_MS=\((ProcessInfo.processInfo.systemUptime - start) * 1000)")
        XCTAssertEqual(f.vm.record?.current?.id, f.next.question.id)
        XCTAssertEqual(f.vm.record?.attempts.count, 1); XCTAssertEqual(f.vm.limiter.questionsUsedToday, 1)
        f.vm.next() // Double tap cannot skip an unanswered question.
        try await waitForPrefetch { f.probe.count == 2 }
        XCTAssertEqual(f.vm.record?.questionNumber, 2)
        XCTAssertEqual(f.probe.excluded(at: 1), [f.first.question.board.id, f.next.question.board.id])
        f.vm.finish(); XCTAssertFalse(f.vm.nextQuestionReady)
    }
    func testNextAwaitsExistingPrefetchAndGenerationFailureCanRetry() async throws {
        let f = try prefetchFixture(); defer { f.close() }
        try await waitForPrefetch { f.probe.count == 1 }
        f.probe.fail(0); f.vm.next(); f.vm.next()
        XCTAssertEqual(f.vm.phase, .preparing); XCTAssertEqual(f.probe.count, 1)
        f.probe.release(0); try await waitForPrefetch { f.vm.phase == .result }
        XCTAssertEqual(f.vm.record?.questionNumber, 1); XCTAssertNotNil(f.vm.message)
        f.vm.next(); try await waitForPrefetch { f.probe.count == 2 }
        f.probe.release(1); try await waitForPrefetch { f.vm.phase == .aiming }
        XCTAssertEqual(f.vm.record?.current?.id, f.next.question.id)
        XCTAssertEqual(f.vm.limiter.questionsUsedToday, 1)
    }
    func testPrefetchDiscardedBySettingsRestartExitAndOwnerChange() async throws {
        let f = try prefetchFixture(); defer { f.close() }
        f.probe.ignoreCancellation = true
        try await waitForPrefetch { f.probe.count == 1 }
        f.vm.openSettings(); f.probe.release(0)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(f.vm.nextQuestionReady); XCTAssertEqual(f.vm.phase, .settings)
        XCTAssertTrue(f.vm.cancelSettings())
        try await waitForPrefetch { f.probe.count == 2 }
        var configuration = SceneTrainingConfiguration(); configuration.angleSelection = [.large]
        f.vm.start(configuration, prepared: f.first)
        try await waitForPrefetch { f.probe.count == 3 }
        XCTAssertEqual(f.probe.configuration(at: 2).angleSelection, [.large])
        f.probe.release(1); try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(f.vm.nextQuestionReady, "Old session result cannot fill a restarted session's slot")
        f.vm.suspendTeachingActivity(); f.probe.release(2)
        try await Task.sleep(for: .milliseconds(50)); XCTAssertFalse(f.vm.nextQuestionReady)
        f.vm.resumeTeachingActivity(); try await waitForPrefetch { f.probe.count == 4 }
        f.vm.ownerChanged(); f.probe.release(3)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(f.vm.record); XCTAssertFalse(f.vm.nextQuestionReady)
        XCTAssertEqual(f.vm.phase, .settings)
    }
    func testPrefetchStopsBeforeQuestion21AndReservesLastFreeAllowance() async throws {
        for (count, answered, premium, used) in [(20, false, true, 0), (20, true, true, 0),
                                                (1, false, false, 19), (1, true, false, 20)] {
            let f = try prefetchFixture(count: count, answered: answered, premium: premium, used: used)
            defer { f.close() }
            try await Task.sleep(for: .milliseconds(50))
            XCTAssertEqual(f.probe.count, 0); XCTAssertFalse(f.vm.nextQuestionReady)
            if answered { f.vm.next(); XCTAssertEqual(f.vm.phase, .summary) }
        }
        // Question 19 may prepare question 20; installing it must not prepare 21.
        let f = try prefetchFixture(count: 19, premium: false, used: 19); defer { f.close() }
        try await waitForPrefetch { f.probe.count == 1 }
        f.probe.release(0); try await waitForPrefetch { f.vm.nextQuestionReady }
        f.vm.next(); XCTAssertEqual(f.vm.record?.questionNumber, 20)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(f.probe.count, 1); XCTAssertEqual(f.vm.limiter.questionsUsedToday, 19)
        XCTAssertFalse(f.vm.nextQuestionReady)
    }
    func testCooperativeCancellationForRightsAndQuotaHasNoTechnicalError() async throws {
        let f = try prefetchFixture(is3D: true); defer { f.close() }
        try await waitForPrefetch { f.probe.count == 1 }; f.vm.next()
        f.vm.limiter.isPremium = false; f.vm.refreshNextQuestion()
        try await waitForPrefetch { f.vm.phase == .result }
        XCTAssertTrue(f.vm.needsSubscription); XCTAssertNil(f.vm.message)
        XCTAssertEqual(f.vm.record?.questionNumber, 1)
        let free = try prefetchFixture(premium: false, used: 18); defer { free.close() }
        try await waitForPrefetch { free.probe.count == 1 }; free.vm.next()
        free.vm.limiter.recordQuestion(); free.vm.limiter.recordQuestion(); free.vm.refreshNextQuestion()
        try await waitForPrefetch { free.vm.phase == .summary }
        XCTAssertNil(free.vm.message); XCTAssertEqual(free.vm.record?.questionNumber, 1)
    }
    func testRestoredRightsDoNotResurrectCancelledRequestWithSameQuestionKey() async throws {
        let f = try prefetchFixture(is3D: true); defer { f.close() }
        f.probe.ignoreCancellation = true
        try await waitForPrefetch { f.probe.count == 1 }; f.vm.next()
        f.vm.limiter.isPremium = false; f.vm.refreshNextQuestion()
        f.vm.limiter.isPremium = true; f.vm.refreshNextQuestion()
        try await waitForPrefetch { f.probe.count == 2 }
        f.probe.release(0); try await waitForPrefetch { f.vm.phase == .result }
        XCTAssertEqual(f.vm.record?.questionNumber, 1); XCTAssertFalse(f.vm.nextQuestionReady)
        f.probe.release(1); try await waitForPrefetch { f.vm.nextQuestionReady }
        f.vm.next(); XCTAssertEqual(f.vm.record?.questionNumber, 2)
    }
    func testRightsOrQuotaChangeWhileNextIsPendingCannotConsumeCache() async throws {
        let f = try prefetchFixture(is3D: true); defer { f.close() }
        f.probe.ignoreCancellation = true
        try await waitForPrefetch { f.probe.count == 1 }; f.vm.next()
        f.vm.limiter.isPremium = false; f.vm.refreshNextQuestion(); f.probe.release(0)
        try await waitForPrefetch { f.vm.phase == .result }
        XCTAssertEqual(f.vm.record?.questionNumber, 1); XCTAssertTrue(f.vm.needsSubscription)
        XCTAssertFalse(f.vm.nextQuestionReady)
        let free = try prefetchFixture(premium: false, used: 18); defer { free.close() }
        free.probe.ignoreCancellation = true
        try await waitForPrefetch { free.probe.count == 1 }; free.vm.next()
        free.vm.limiter.recordQuestion(); free.vm.limiter.recordQuestion(); free.vm.refreshNextQuestion()
        free.probe.release(0); try await waitForPrefetch { free.vm.phase == .summary }
        XCTAssertEqual(free.vm.record?.questionNumber, 1); XCTAssertEqual(free.vm.limiter.questionsUsedToday, 20)
        XCTAssertFalse(free.vm.nextQuestionReady)
    }
    func testDefaultReferenceIsFixedPhysicalRouteWithoutAttemptsAndClearsOnOwnerChange() async throws {
        let suite = "separation-reference-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
        let repo = MemoryRepository()
        let vm = SeparationPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        XCTAssertFalse(vm.showsReference)
        vm.setShowsReference(false)
        XCTAssertFalse(SeparationPracticeViewModel(is3D: false, defaults: defaults).showsReference)
        XCTAssertFalse(SeparationPracticeViewModel(is3D: true, defaults: defaults).showsReference)
        vm.attach(repository: repo)
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        vm.start(.init(), prepared: prepared); vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        vm.resumeTeachingActivity()
        XCTAssertTrue(vm.shouldShowReference, "The first-shot baseline does not depend on the retention switch")
        for _ in 0..<1000 where vm.referenceTrajectory == nil { try await Task.sleep(for: .milliseconds(10)) }
        let line = try XCTUnwrap(vm.referenceTrajectory)
        XCTAssertGreaterThan(line.count, 2)
        let prediction = try SeparationQuestionGenerator.solve(board: prepared.question.board,
            input: .init(spinX: 0, spinY: 0, velocity: 2.5), surfaceY: vm.scene.surfaceY,
            profile: AccuracyTipSelector.renderedProfile())
        let expected = try SeparationTrajectory.extract(prediction)
        XCTAssertEqual(line.count, expected.count)
        for (actual, expected) in zip(line, expected) {
            XCTAssertEqual(actual.position.x, expected.position.x, accuracy: 1e-6)
            XCTAssertEqual(actual.position.z, expected.position.z, accuracy: 1e-6)
            XCTAssertEqual(actual.time, expected.time, accuracy: 1e-6)
        }
        let node = try XCTUnwrap(vm.scene.rootNode.childNode(withName: "separation.reference", recursively: false))
        let color = try XCTUnwrap(node.geometry?.firstMaterial?.diffuse.contents as? UIColor)
        XCTAssertEqual(color, TrajectoryStyle.TrainingAssist.centerReference)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let frozen = try encoder.encode(line)
        vm.setSpin(0.15, -0.2); vm.velocity = 0.5
        vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
        XCTAssertEqual(try encoder.encode(XCTUnwrap(vm.referenceTrajectory)), frozen)
        XCTAssertTrue(vm.scene.rootNode.childNode(withName: "separation.reference", recursively: false) === node)
        XCTAssertEqual(vm.record?.attempts.count, 0); XCTAssertNil(vm.record?.latestShot)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        vm.setShowsReference(true); vm.setShowsReference(false)
        XCTAssertEqual(try encoder.encode(XCTUnwrap(vm.referenceTrajectory)), frozen)
        XCTAssertTrue(vm.scene.rootNode.childNode(withName: "separation.reference", recursively: false) === node)
        vm.ownerChanged()
        XCTAssertNil(vm.referenceTrajectory)
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "separation.reference", recursively: false))
        // Cancel a freshly started calculation before it can publish into a different owner's scene.
        vm.start(.init(), prepared: prepared); vm.ownerChanged()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(vm.referenceTrajectory)
        XCTAssertNil(vm.scene.rootNode.childNode(withName: "separation.reference", recursively: false))
    }
    func testReferenceStagesAcrossRetryReplayRestorationAndNextQuestion() async throws {
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let nextPrepared = try SeparationQuestionGenerator.prepare(.init(),
            excluding: [prepared.question.board.id], seed: 20261023)
        // Keep this lifecycle test independent of random generation latency/failure.
        let prepareNext: SeparationPracticeViewModel.QuestionPreparer = { _, excluded in
            try Task.checkCancellation()
            guard !excluded.contains(nextPrepared.question.board.id) else {
                throw SeparationQuestionGenerator.Failure.incompatible
            }
            return nextPrepared
        }
        for is3D in [false, true] {
            for keepReference in [false, true] {
                let suite = "reference-stages-" + UUID().uuidString
                let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
                defer { defaults.removePersistentDomain(forName: suite) }
                // Old visibility preference has a different meaning and must not defeat the new default.
                defaults.set(true, forKey: "separationPractice.\(is3D ? "3D" : "2D").showsReference")
                let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
                let repo = MemoryRepository()
                let vm = SeparationPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults, prepareQuestion: prepareNext)
                defer { vm.suspendTeachingActivity() }
                XCTAssertFalse(vm.showsReference)
                vm.setShowsReference(keepReference); vm.setPlaysStroke(false)
                vm.attach(repository: repo); vm.start(.init(), prepared: prepared); vm.setupScene()
                try await waitForPrefetch { vm.referenceTrajectory != nil }
                XCTAssertTrue(vm.shouldShowReference)
                func visible(_ vm: SeparationPracticeViewModel, _ name: String) -> Bool {
                    vm.scene.rootNode.childNode(withName: "separation." + name, recursively: false) != nil
                }
                XCTAssertTrue(visible(vm, "reference")); XCTAssertFalse(visible(vm, "actual"))
                repo.failSubmissions = true; vm.strike()
                try await waitForPrefetch { vm.phase == .saveFailed }
                XCTAssertTrue(visible(vm, "reference")); XCTAssertFalse(visible(vm, "actual"))
                repo.failSubmissions = false; vm.retrySave()
                XCTAssertEqual(vm.phase, .result)
                XCTAssertEqual(visible(vm, "reference"), keepReference); XCTAssertTrue(visible(vm, "actual"))
                let firstShot = vm.record?.latestShot?.id
                vm.retry(); XCTAssertEqual(vm.phase, .aiming)
                XCTAssertTrue(visible(vm, "actual")); XCTAssertEqual(visible(vm, "reference"), keepReference)
                vm.replayLastShot(); vm.stopPlayback()
                XCTAssertEqual(vm.phase, .aiming); XCTAssertTrue(visible(vm, "actual"))
                XCTAssertEqual(visible(vm, "reference"), keepReference)
                vm.replayLastShot(); vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
                XCTAssertEqual(vm.phase, .aiming); XCTAssertEqual(vm.record?.latestShot?.id, firstShot)
                XCTAssertTrue(visible(vm, "actual")); XCTAssertEqual(vm.record?.attempts.count, 1)
                vm.suspendTeachingActivity()
                let restored = SeparationPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults, prepareQuestion: prepareNext)
                defer { restored.suspendTeachingActivity() }
                restored.attach(repository: repo); restored.setupScene()
                if keepReference { try await waitForPrefetch { restored.referenceTrajectory != nil } }
                XCTAssertEqual(restored.phase, .aiming); XCTAssertTrue(visible(restored, "actual"))
                XCTAssertEqual(visible(restored, "reference"), keepReference)
                // A replacement appears only after a successful save; its route replaces the previous one.
                restored.velocity = 2.8; restored.strike()
                try await waitForPrefetch { restored.phase == .result }
                XCTAssertNotEqual(restored.record?.latestShot?.id, firstShot)
                XCTAssertEqual(restored.record?.attempts.count, 1)
                XCTAssertEqual(limiter.questionsUsedToday, is3D ? 0 : 1, "3D uses Pro access, not the 2D daily counter")
                restored.suspendTeachingActivity()
                let result = SeparationPracticeViewModel(is3D: is3D, limiter: limiter, defaults: defaults, prepareQuestion: prepareNext)
                defer { result.suspendTeachingActivity() }
                result.attach(repository: repo); result.setupScene()
                if keepReference { try await waitForPrefetch { result.referenceTrajectory != nil } }
                XCTAssertEqual(result.phase, .result); XCTAssertTrue(visible(result, "actual"))
                XCTAssertEqual(visible(result, "reference"), keepReference)
                result.replayLastShot(); result.stopPlayback()
                XCTAssertEqual(result.phase, .result); XCTAssertTrue(visible(result, "actual"))
                try await waitForPrefetch { result.nextQuestionReady }
                result.next(); XCTAssertEqual(result.phase, .aiming)
                try await waitForPrefetch { result.referenceTrajectory != nil }
                XCTAssertNil(result.record?.latestShot); XCTAssertTrue(visible(result, "reference"))
                XCTAssertFalse(visible(result, "actual"))
            }
        }
    }

    func testTrajectoryOnlySubmissionPersistsWithoutStrokeAndReplayRestoresBoard() async throws {
        let suite = "separation-submit-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
        let repo = MemoryRepository()
        let vm = SeparationPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        XCTAssertTrue(vm.playsStroke)
        vm.setPlaysStroke(false)
        XCTAssertFalse(SeparationPracticeViewModel(is3D: false, defaults: defaults).playsStroke)
        XCTAssertTrue(SeparationPracticeViewModel(is3D: true, defaults: defaults).playsStroke)
        vm.attach(repository: repo)
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        vm.start(.init(), prepared: prepared); vm.setupScene()
        let initialCue = try XCTUnwrap(vm.scene.cueBallNode).position
        let initialTarget = try XCTUnwrap(vm.targetNode).position
        XCTAssertEqual(vm.primaryTitle, "提交")
        let board = prepared.question.board
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: board.target.vector,
            pocketIndex: board.pocketIndex, surfaceY: vm.scene.surfaceY)
        XCTAssertEqual(try XCTUnwrap(vm.cutAngleDegrees), AngleSceneCalculator.cutAngle(
            cueBall: board.cue.vector, targetBall: board.target.vector, pocket: pocket), accuracy: 1e-6)
        repo.failSubmissions = true
        vm.strike(); vm.setPlaysStroke(true)
        XCTAssertFalse(vm.playsStroke, "An active submission freezes its presentation intent")
        for _ in 0..<3000 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(vm.phase, .saveFailed)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        repo.failSubmissions = false; vm.retrySave()
        XCTAssertEqual(vm.phase, .result)
        XCTAssertNil(vm.strokeStartedAt); XCTAssertNil(vm.revealedAt)
        XCTAssertEqual(limiter.questionsUsedToday, 1)
        XCTAssertEqual(vm.scene.cueBallNode?.position.x, initialCue.x)
        XCTAssertEqual(vm.scene.cueBallNode?.position.z, initialCue.z)
        XCTAssertEqual(vm.targetNode?.position.x, initialTarget.x)
        XCTAssertEqual(vm.targetNode?.position.z, initialTarget.z)
        XCTAssertNotNil(vm.record?.latestShot?.score)
        XCTAssertEqual(vm.latestScoreTitle, "本杆得分")
        XCTAssertEqual(vm.scene.pocketLineNode?.isHidden, true)
        XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "separation.objectActual", recursively: false))
        let decoded = try SeparationPracticeRecord.decodePayload(XCTUnwrap(repo.saved).encodedPayload())
        XCTAssertEqual(decoded.latestShot?.playsStroke, false)
        XCTAssertTrue(decoded.showingResult)
        let restored = SeparationPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        restored.attach(repository: repo); restored.setupScene()
        XCTAssertEqual(restored.phase, .result)
        XCTAssertEqual(restored.scene.cueBallNode?.position.x, initialCue.x)
        XCTAssertEqual(restored.scene.cueBallNode?.position.z, initialCue.z)
        restored.replayLastShot(); XCTAssertTrue(restored.isReplaying)
        restored.stopPlayback(); XCTAssertEqual(restored.phase, .result)
        XCTAssertEqual(restored.scene.cueBallNode?.position.x, initialCue.x)
        XCTAssertEqual(restored.scene.cueBallNode?.position.z, initialCue.z)
        restored.retry(); XCTAssertEqual(restored.primaryTitle, "提交")
        XCTAssertEqual(restored.latestScoreTitle, "上杆得分")
        XCTAssertEqual(restored.scene.pocketLineNode?.isHidden, false)
        XCTAssertNil(restored.scene.rootNode.childNode(withName: "separation.objectActual", recursively: false))
        restored.replayLastShot(); restored.stopPlayback()
        XCTAssertEqual(restored.latestScoreTitle, "上杆得分")
        XCTAssertEqual(restored.scene.pocketLineNode?.isHidden, false)
        restored.replayLastShot(); restored.suspendTeachingActivity()
        XCTAssertEqual(restored.phase, .aiming)
        XCTAssertEqual(restored.scene.pocketLineNode?.isHidden, false)
        XCTAssertNil(restored.scene.rootNode.childNode(withName: "separation.objectActual", recursively: false))
        restored.setPlaysStroke(true); XCTAssertEqual(restored.primaryTitle, "击球")
        restored.strike()
        for _ in 0..<3000 where restored.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(restored.phase, .playing)
        XCTAssertEqual(restored.record?.latestShot?.playsStroke, true)
        XCTAssertEqual(limiter.questionsUsedToday, 1)
        restored.suspendTeachingActivity()
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(XCTUnwrap(decoded.latestShot))) as? [String: Any])
        legacy.removeValue(forKey: "playsStroke")
        let legacyShot = try JSONDecoder().decode(SeparationShot.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertFalse(legacyShot.isTrajectoryOnly)
    }
    func testSaveFailureLatestInputCancellationAndRestorationAreAtomic() async throws {
        let suite = "separation-state-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
        let repo = MemoryRepository()
        let vm = SeparationPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repo)
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        vm.start(.init(), prepared: prepared); vm.setupScene()
        vm.velocity = 8; XCTAssertEqual(vm.velocity, 8)
        vm.velocity = 9; XCTAssertEqual(vm.velocity, 8)
        vm.setSpin(0.08, -0.08); vm.velocity = 2.1
        repo.failSubmissions = true
        vm.strike(); vm.setSpin(0.2, 0.2); vm.velocity = 4
        for _ in 0..<500 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(vm.phase, .saveFailed); XCTAssertEqual(limiter.questionsUsedToday, 0)
        XCTAssertEqual(repo.saved?.attempts.count, 0)
        repo.failSubmissions = false; vm.retrySave()
        XCTAssertEqual(vm.phase, .playing); XCTAssertEqual(limiter.questionsUsedToday, 1)
        XCTAssertEqual(vm.scene.cueStick?.rootNode.isHidden, false)
        XCTAssertEqual(vm.record?.latestShot?.input, .init(spinX: 0.08, spinY: -0.08, velocity: 2.1))
        let shotID = vm.record?.latestShot?.id, questionID = vm.record?.current?.id
        XCTAssertLessThan(try XCTUnwrap(vm.strokeStartedAt) - XCTUnwrap(vm.revealedAt), 0.1)
        vm.suspendTeachingActivity()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(vm.phase, .result); XCTAssertEqual(vm.record?.latestShot?.id, shotID)
        let restored = SeparationPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        restored.attach(repository: repo)
        XCTAssertEqual(restored.record?.current?.id, questionID)
        XCTAssertEqual(restored.record?.latestShot?.id, shotID)
        XCTAssertEqual(limiter.questionsUsedToday, 1)
        vm.resumeTeachingActivity(); vm.retry(); vm.strike(); vm.suspendTeachingActivity()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(vm.phase, .aiming); XCTAssertEqual(limiter.questionsUsedToday, 1)
        vm.ownerChanged(); XCTAssertNil(vm.record)
    }
    func testContinuousCandidatesConcentrateAtCenterAndRespectDisabledAxes() throws {
        var rng = SceneTrainingGenerator.SeededRandom(state: 20261022)
        var inside = 0, outer = 0, sumX = 0.0, sumY = 0.0, combined = 0
        for _ in 0..<20_000 {
            let sample = try XCTUnwrap(SeparationQuestionGenerator.sample(minimum: 0.5, vertical: true, lateral: true, random: &rng))
            XCTAssertTrue(sample.isValid)
            let radius = hypot(sample.spinX, sample.spinY)
            if radius < 0.18 { inside += 1 }
            // Same area annulus as the central disc, so compare density rather than raw radial mass.
            if radius >= 0.36 && radius < sqrt(0.36*0.36+0.18*0.18) { outer += 1 }
            sumX += Double(sample.spinX); sumY += Double(sample.spinY)
            if sample.spinX != 0 && sample.spinY != 0 { combined += 1 }
        }
        XCTAssertGreaterThan(inside, outer*4)
        XCTAssertEqual(sumX/20000, 0, accuracy: 0.005); XCTAssertEqual(sumY/20000, 0, accuracy: 0.005)
        XCTAssertEqual(combined, 20_000)
        for vertical in [false, true] { for lateral in [false, true] {
            for _ in 0..<200 {
                let s = try XCTUnwrap(SeparationQuestionGenerator.sample(minimum: 3.4, vertical: vertical, lateral: lateral, random: &rng))
                if !vertical { XCTAssertEqual(s.spinY, 0) }; if !lateral { XCTAssertEqual(s.spinX, 0) }
                XCTAssertGreaterThanOrEqual(s.velocity, 3.4); XCTAssertLessThanOrEqual(s.velocity, 4.5)
            }
        } }
    }
    func testObjectRouteStopsAtPhysicalEndpointAndSurvivesRestoration() throws {
        let q = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022).question
        let profile = AccuracyTipSelector.renderedProfile()
        for input in [SeparationInput(velocity: 0.5), SeparationInput(velocity: q.minimumCenterSpeed * 0.95), q.answer] {
            let prediction = try SeparationQuestionGenerator.solve(board: q.board, input: input,
                surfaceY: BTTablePhysics.surfaceY, profile: profile)
            let shot = try SeparationShot(question: q, input: input, prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
            let restored = try JSONDecoder().decode(SeparationShot.self, from: JSONEncoder().encode(shot))
            let path = restored.objectTrajectory
            let first = try XCTUnwrap(path.first), last = try XCTUnwrap(path.last)
            XCTAssertEqual(first.position.x, q.board.target.x, accuracy: 1e-6)
            XCTAssertEqual(first.position.z, q.board.target.z, accuracy: 1e-6)
            let capture = prediction.recorder?.pocketEntries.first { $0.ball.name == ShotInput.targetBallName }
            let end = try XCTUnwrap(capture?.ball.position ?? prediction.finalPositions[ShotInput.targetBallName])
            XCTAssertEqual(last.position.x, end.x, accuracy: 1e-5)
            XCTAssertEqual(last.position.z, end.z, accuracy: 1e-5)
            if input.velocity == 0.5 {
                XCTAssertFalse(shot.specifiedPocket)
                let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: q.board.target.vector,
                    pocketIndex: q.board.pocketIndex, surfaceY: BTTablePhysics.surfaceY)
                XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(end, pocket), 0.1)
            } else if input == q.answer {
                XCTAssertTrue(shot.specifiedPocket)
                XCTAssertEqual(last.time, try XCTUnwrap(capture).time, accuracy: 1e-6)
                XCTAssertTrue(path.allSatisfy { $0.time <= last.time })
            } else {
                XCTAssertFalse(shot.specifiedPocket)
                XCTAssertFalse(shot.trajectory.isEmpty, "The weak shot must still contact the object ball")
                XCTAssertGreaterThan(AngleSceneCalculator.horizontalDistance(first.position.vector, last.position.vector), 0.01)
            }
            XCTAssertEqual(path.count, shot.objectTrajectory.count)
            for (a, b) in zip(path, shot.objectTrajectory) {
                XCTAssertEqual(a.position.x, b.position.x); XCTAssertEqual(a.position.z, b.position.z)
                XCTAssertEqual(a.time, b.time)
            }
        }
    }

    func testTargetJawFilterDistinguishesCueObjectAndMainRails() throws {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        var prediction = ShotPrediction()
        func collision(_ ball: String, _ index: Int?) -> ShotEvent {
            .init(time: 1, kind: .ballCushion(ball: ball), cushionIndex: index)
        }
        for index in geometry.linearCushions.indices {
            prediction.events = [collision(ShotInput.cueBallName, index)]
            XCTAssertEqual(SeparationQuestionGenerator.hasCueJawContact(prediction),
                geometry.linearCushions[index].soundSurface == .jaw, "linear \(index)")
        }
        for arc in geometry.circularCushions.indices {
            let index = geometry.linearCushions.count + arc
            prediction.events = [collision(ShotInput.cueBallName, index)]
            XCTAssertTrue(SeparationQuestionGenerator.hasCueJawContact(prediction), "arc \(arc)")
            prediction.events = [collision(ShotInput.targetBallName, index)]
            XCTAssertFalse(SeparationQuestionGenerator.hasCueJawContact(prediction))
        }
        prediction.events = [collision(ShotInput.cueBallName, nil)]
        XCTAssertTrue(SeparationQuestionGenerator.hasCueJawContact(prediction))
        prediction.events = []
        XCTAssertFalse(SeparationQuestionGenerator.hasCueJawContact(prediction))
    }

    func testPhysicalCornerAndMiddlePocketFilletsAreRejected() throws {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        XCTAssertEqual(geometry.circularCushions.count, 12) // 8 corner and 4 middle-pocket noses.
        for (index, arc) in geometry.circularCushions.enumerated() {
            var span = arc.endAngle - arc.startAngle
            if span < 0 { span += 2 * .pi }
            let angle = arc.startAngle + span / 2
            let normal = SCNVector3(cos(angle), 0, sin(angle))
            let origin = arc.center + normal * (arc.radius + BallPhysics.radius + 0.05)
            let prediction = ShotPredictor.simulateFree(cueBall: origin, aimDir: normal * -1,
                velocity: 0.8, spinX: 0, spinY: 0, surfaceY: BTTablePhysics.surfaceY,
                balls: [], maxEvents: 1500, maxTime: 60)
            XCTAssertTrue(prediction.events.contains {
                if case .ballCushion(let ball) = $0.kind {
                    return ball == ShotInput.cueBallName && $0.cushionIndex == geometry.linearCushions.count + index
                }
                return false
            }, "Missing physical contact with arc \(index)")
            XCTAssertTrue(SeparationQuestionGenerator.hasCueJawContact(prediction), "arc \(index)")
        }
        print("PHYSICAL_JAW_FILTER cornerArcs=8 middleArcs=4")
    }

    func testGeneratedTargetsHaveNoPhysicalCueJawContacts() throws {
        var config = SceneTrainingConfiguration()
        config.allowsVerticalSpin = true; config.allowsSideSpin = true
        let profile = AccuracyTipSelector.renderedProfile()
        var excluded = Set<String>(), rejectedJaws = 0
        for seed: UInt64 in 20261022...20261029 {
            let prepared = try SeparationQuestionGenerator.prepare(config, excluding: excluded, seed: seed)
            let q = prepared.question
            excluded.insert(q.board.id)
            let answer = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer,
                surfaceY: BTTablePhysics.surfaceY, profile: profile)
            XCTAssertEqual(AccuracyShotJudgement.evaluate(answer, pocketIndex: q.board.pocketIndex), .success)
            // Independent witness: the engine records the impacted material when impulse is applied.
            let recorder = try XCTUnwrap(answer.recorder)
            XCTAssertFalse(recorder.contactSounds.contains { $0.ball == ShotInput.cueBallName && $0.surface == .jaw })
            XCTAssertFalse(SeparationQuestionGenerator.hasCueJawContact(answer))
            for input in q.audit.sampledInputs.dropLast() {
                let candidate: ShotPrediction
                do { candidate = try SeparationQuestionGenerator.solve(board: q.board, input: input,
                    surfaceY: BTTablePhysics.surfaceY, profile: profile) }
                catch { continue } // Some rejected inputs have no physically accessible strike.
                if AccuracyShotJudgement.evaluate(candidate, pocketIndex: q.board.pocketIndex) == .success,
                   candidate.recorder?.contactSounds.contains(where: { $0.ball == ShotInput.cueBallName && $0.surface == .jaw }) == true {
                    rejectedJaws += 1
                    XCTAssertTrue(SeparationQuestionGenerator.hasCueJawContact(candidate))
                    // The player's real shot still records its route and receives the unchanged score.
                    let actual = try SeparationShot(question: q, input: input, prediction: candidate,
                        surfaceY: BTTablePhysics.surfaceY)
                    XCTAssertFalse(actual.trajectory.isEmpty)
                    XCTAssertNotNil(actual.score)
                    print("REJECTED_CUE_JAW seed=\(seed) board=\(q.board.id) input=\(input)")
                }
            }
        }
        print("JAW_FREE_TARGETS=8 rejectedPottedJawCandidates=\(rejectedJaws)")
    }

    func testGeneratedAnswerHasIndependentPhysicalProofAndReplaySurvivesSerialization() throws {
        var config = SceneTrainingConfiguration(); config.allowsVerticalSpin = true; config.allowsSideSpin = true
        let start = Date()
        let prepared = try SeparationQuestionGenerator.prepare(config, seed: 20261022)
        let q = prepared.question
        let profile = AccuracyTipSelector.renderedProfile()
        let baseline = try SeparationQuestionGenerator.solve(board: q.board,
            input: .init(spinX: 0, spinY: 0, velocity: q.minimumCenterSpeed), surfaceY: BTTablePhysics.surfaceY, profile: profile)
        XCTAssertTrue(SeparationQuestionGenerator.potsSpecifiedPocket(baseline, pocket: q.board.pocketIndex))
        let answer = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer, surfaceY: BTTablePhysics.surfaceY, profile: profile)
        XCTAssertEqual(AccuracyShotJudgement.evaluate(answer, pocketIndex: q.board.pocketIndex), .success)
        XCTAssertGreaterThanOrEqual(q.answer.velocity, q.minimumCenterSpeed)
        XCTAssertFalse(q.target.isEmpty); XCTAssertEqual(q.target.first?.time, 0)
        let shot = try SeparationShot(question: q, input: q.answer, prediction: answer, surfaceY: BTTablePhysics.surfaceY)
        let restored = try JSONDecoder().decode(SeparationShot.self, from: JSONEncoder().encode(shot))
        XCTAssertEqual(restored.id, shot.id); XCTAssertEqual(restored.input, shot.input)
        XCTAssertEqual(restored.prediction().recorder?.framesByBallName[ShotInput.cueBallName]?.count,
                       answer.recorder?.framesByBallName[ShotInput.cueBallName]?.count)
        let a = TrajectoryPlayback(recorder: try XCTUnwrap(answer.recorder), surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        let b = TrajectoryPlayback(recorder: try XCTUnwrap(restored.prediction().recorder), surfaceY: BTTablePhysics.surfaceY + BallPhysics.radius)
        for step in 0...80 {
            let t = Float(step)*answer.duration/80
            for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
                let p = try XCTUnwrap(a.stateAt(ballName: name, time: t)), r = try XCTUnwrap(b.stateAt(ballName: name, time: t))
                XCTAssertEqual(p.position.x, r.position.x, accuracy: 1e-5)
                XCTAssertEqual(p.position.z, r.position.z, accuracy: 1e-5)
            }
        }
        print("SEPARATION_GENERATION seconds=\(Date().timeIntervalSince(start)) board=\(q.board.id) minimum=\(q.minimumCenterSpeed) audit=\(q.audit)")
    }
    func testIncompletePredictionNeverBecomesTrajectoryOrSubmission() throws {
        var p = ShotPrediction(); p.termination = .timeLimit
        XCTAssertThrowsError(try SeparationTrajectory.extract(p))
        XCTAssertFalse(SeparationQuestionGenerator.potsSpecifiedPocket(p, pocket: 0))
    }
    func testInFlightFrameCannotStartRevealAndCancelledReceiptCannotFire() async {
        let receipt = TableFrameReceipt()
        var calls = 0
        receipt.willRender()
        receipt.arm { calls += 1 }
        receipt.didRender()
        await Task.yield(); XCTAssertEqual(calls, 0)
        let received = expectation(description: "new rendered frame")
        receipt.arm { calls += 1; received.fulfill() }
        receipt.willRender(); receipt.didRender(); receipt.didRender()
        await fulfillment(of: [received], timeout: 1)
        XCTAssertEqual(calls, 1)
        receipt.arm { XCTFail("Cancelled receipt") }; receipt.willRender(); receipt.cancel(); receipt.didRender()
        await Task.yield()
    }
    func testRightsPreferencesAndLayoutsHaveSeparateIdentity() {
        XCTAssertFalse(AngleRoute.separationPractice2D.requiresPremium)
        XCTAssertTrue(AngleRoute.separationPractice3D.requiresPremium)
        XCTAssertTrue(AngleUsageLimiter.training(route: "separationPractice2D") === AngleUsageLimiter.separationTraining)
        XCTAssertFalse(AngleUsageLimiter.separationTraining === AngleUsageLimiter.accuracyTraining)
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(TrainingSessionKind.separationPractice))
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(TrainingSessionKind.separationPractice))
        let ids = FreeControlCatalog.ids(page: .separationPractice2D, mode: .twoD)
        XCTAssertTrue(ids.contains("shot.undo")); XCTAssertTrue(ids.contains("shot.replay")); XCTAssertFalse(ids.contains("shot.aim"))
        XCTAssertTrue(FreeControlCatalog.ids(page: .separationPractice2D, mode: .threeD).isEmpty)
        XCTAssertEqual(TablePreferencePage.separationPractice3D.fixedControlLayoutMode, .threeD)
    }
    func testDurableCameraBookmarkRestoresActualPoseAndLens() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: BTTablePhysics.surfaceY, config: .dailyClearance)
        rig.usesTwoViewCameraControls = true; rig.viewportSize = .init(width: 874, height: 402)
        rig.twoViewTableSightlinesClear = { _, _ in true }
        let cue = SCNVector3(0, BTTablePhysics.surfaceY + BallPhysics.radius, 0), aim = SCNVector3(1, 0, 0.6)
        for mode in [CameraRig.PlayerView.thirdPerson, .firstPerson] {
            XCTAssertTrue(rig.enterPlayerView(mode, cue: cue, aim: aim, duration: 0))
            rig.handleHorizontalSwipe(delta: 0.15)
            for _ in 0..<120 { rig.update(deltaTime: 1/60) }
            let saved = rig.trainingBookmark()
            let decoded = try JSONDecoder().decode(CameraRig.TrainingBookmark.self, from: JSONEncoder().encode(saved))
            _ = rig.enterPlayerView(.thirdPerson, cue: cue, aim: SCNVector3(-1, 0, 0), duration: 0)
            rig.restoreTrainingBookmark(decoded, cue: cue, aim: aim)
            let actual = rig.trainingBookmark()
            XCTAssertEqual(actual.mode, saved.mode)
            for (a, b) in zip(actual.pose, saved.pose) { XCTAssertEqual(a, b, accuracy: 0.00001) }
            for _ in 0..<60 { rig.update(deltaTime: 1/60) }
            for (a, b) in zip(rig.trainingBookmark().pose, saved.pose) { XCTAssertEqual(a, b, accuracy: 0.00001) }
        }
    }
    func testDraftPersistenceOwnerIsolationAndHistoryWithoutScores() throws {
        let suite = "separation-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        var uploads = 0
        let repo = LocalSeparationPracticeRepository(context: context, owner: owner, enqueue: { _, _ in uploads += 1 })
        let board = try XCTUnwrap(TrainingBankStore.load().draw(.init(), seed: 77).boards.first)
        let q = SeparationQuestion(id: UUID(), board: board, minimumCenterSpeed: 1, answer: .init(),
            answerDirection: .init(AccuracyTipSelector.referenceDirection(board)), target: [], audit: .init())
        var record = SeparationPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(),
            prepared: .init(fingerprint: "fixture", question: q))
        record.activeSeconds = 125
        try repo.save(record)
        XCTAssertEqual(uploads, 0); XCTAssertEqual(try repo.resumable(is3D: false)?.id, record.id)
        XCTAssertNil(try repo.resumable(is3D: true))
        var p = ShotPrediction(); p.termination = .settled; p.recorder = TrajectoryRecorder()
        p.strikeDirection = AccuracyTipSelector.referenceDirection(board)
        let shot = try SeparationShot(question: q, input: .init(), prediction: p, surfaceY: BTTablePhysics.surfaceY)
        record.accept(shot); record.accept(shot); try repo.save(record)
        XCTAssertEqual(record.attempts.count, 1)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count, 1); XCTAssertEqual(sessions[0].totalDurationMinutes, 2)
        let dto = TrainingSessionDTO(from: sessions[0])
        let decoded = try JSONDecoder().decode(TrainingSessionDTO.self, from: JSONEncoder().encode(dto))
        XCTAssertEqual(decoded.kind, TrainingSessionKind.separationPractice)
        XCTAssertEqual(decoded.sourcePayloadSnapshot, sessions[0].sourcePayloadSnapshot)
        XCTAssertEqual(HistoryViewModel.assembleSeparationSessions(sessions: sessions).records.count, 1)
        XCTAssertTrue(HistoryViewModel.assembleAccuracySessions(sessions: sessions).records.isEmpty)
        sessions[0].sourcePayloadSnapshot = Data("broken".utf8)
        XCTAssertThrowsError(try repo.resumable(is3D: false))
        XCTAssertEqual(HistoryViewModel.assembleSeparationSessions(sessions: sessions).unreadableCount, 1)
        owner.useAccount(userID: "second"); XCTAssertThrowsError(try repo.save(record))
        XCTAssertNil(try repo.resumable(is3D: false))
    }
    func testNextAfterTenFreeQuestionsContinuesWithoutSummaryOrExtraUsage() async throws {
        let suite = "separation-segment-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite); limiter.isPremium = true
        let repo = MemoryRepository()
        var config = SceneTrainingConfiguration(); config.freePractice = true
        let prepared = try SeparationQuestionGenerator.prepare(config, seed: 20261022)
        let q = prepared.question
        let prediction = try SeparationQuestionGenerator.solve(board: q.board, input: q.answer,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        var old = SeparationPracticeRecord(ownerKey: repo.ownerKey, is3D: false, configuration: config, prepared: prepared)
        for index in 0..<10 {
            let question = SeparationQuestion(id: UUID(), board: q.board, minimumCenterSpeed: q.minimumCenterSpeed,
                answer: q.answer, answerDirection: q.answerDirection, target: q.target, audit: q.audit)
            if index == 0 { old.questions = [question] }
            else { old.questions.append(question); old.cursor += 1 }
            old.accept(try SeparationShot(question: question, input: q.answer, prediction: prediction, surfaceY: BTTablePhysics.surfaceY))
        }
        old.showingResult = true; repo.saved = old
        let vm = SeparationPracticeViewModel(is3D: false, limiter: limiter)
        vm.attach(repository: repo); vm.setupScene(); XCTAssertEqual(vm.phase, .result)
        for _ in 0..<3000 where !vm.nextQuestionReady { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(vm.nextQuestionReady)
        vm.next()
        XCTAssertEqual(vm.phase, .aiming, "Free-practice segment rollover also consumes the ready slot")
        for _ in 0..<3000 where vm.phase == .preparing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(vm.phase, .aiming); XCTAssertEqual(vm.record?.questionNumber, 11)
        XCTAssertEqual(vm.record?.totalAttemptCount, 10); XCTAssertEqual(limiter.questionsUsedToday, 10)
        XCTAssertNotEqual(vm.record?.id, old.id); XCTAssertNil(vm.record?.latestShot)
        XCTAssertEqual(repo.lastBatch.count, 2); XCTAssertEqual(repo.lastBatch.first?.status, .completed)
        XCTAssertEqual(repo.lastBatch.last?.status, .active)
        vm.suspendTeachingActivity()
    }
    func testFreePracticeSegmentsKeepContinuousNumberAndAtomicHistory() throws {
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        let owner = CurrentOwnerContext.shared
        var uploaded: [UUID] = []
        let repo = LocalSeparationPracticeRepository(context: context, enqueue: { id, _ in uploaded.append(id) })
        var config = SceneTrainingConfiguration(); config.freePractice = true
        let prepared = try SeparationQuestionGenerator.prepare(config, seed: 20261022)
        var old = SeparationPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: config, prepared: prepared)
        old.completedQuestionOffset = 90
        let prediction = try SeparationQuestionGenerator.solve(board: prepared.question.board,
            input: prepared.question.answer, surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        old.accept(try SeparationShot(question: prepared.question, input: prepared.question.answer,
            prediction: prediction, surfaceY: BTTablePhysics.surfaceY))
        try repo.save(old)
        var archive = old; archive.status = .completed
        let continuation = old.continuation(prepared: prepared)
        var invalid = continuation; invalid.ownerKey = "different-owner"
        XCTAssertThrowsError(try repo.saveAtomically([archive, invalid]))
        XCTAssertEqual(try repo.resumable(is3D: false)?.id, old.id, "Failed continuation must not end the active segment")
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).count, 1)
        try repo.saveAtomically([archive, continuation])
        let resumed = try XCTUnwrap(repo.resumable(is3D: false))
        XCTAssertEqual(resumed.id, continuation.id); XCTAssertEqual(resumed.questionNumber, 92)
        XCTAssertEqual(resumed.totalAttemptCount, 91); XCTAssertEqual(resumed.attempts.count, 0)
        XCTAssertEqual(resumed.activeSeconds, 0)
        XCTAssertFalse(uploaded.contains(continuation.id), "Untouched continuation stays local")
        XCTAssertEqual(HistoryViewModel.assembleSeparationSessions(sessions:
            try context.fetch(FetchDescriptor<TrainingSession>())).records.count, 1)
    }
    func testDiskReopenAndExplicitOwnerTransferPreserveFrozenRecord() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("separation-disk-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "separation-owner-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults), source = owner.ownerKey
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        var record = SeparationPracticeRecord(ownerKey: source, is3D: true, configuration: .init(), prepared: prepared)
        record.draftInput = .init(spinX: 0.1, spinY: -0.2, velocity: 1.7)
        let url = folder.appendingPathComponent("practice.store")
        do {
            let container = try ModelContainerFactory.makeContainer(at: url)
            try LocalSeparationPracticeRepository(context: container.mainContext, owner: owner, enqueue: { _, _ in }).save(record)
        }
        let reopened = try ModelContainerFactory.makeContainer(at: url), context = reopened.mainContext
        let repo = LocalSeparationPracticeRepository(context: context, owner: owner, enqueue: { _, _ in })
        XCTAssertEqual(try repo.resumable(is3D: true)?.current?.id, record.current?.id)
        XCTAssertEqual(try repo.resumable(is3D: true)?.draftInput, record.draftInput)
        let destination = OwnerKey.account("separation-transfer")
        let failed = OwnerTransferService(context: context, saveAction: { _ in throw CocoaError(.fileWriteOutOfSpace) })
        XCTAssertThrowsError(try failed.transfer(from: source, to: destination))
        XCTAssertEqual(try repo.resumable(is3D: true)?.ownerKey, source)
        XCTAssertEqual(try OwnerTransferService(context: context).transfer(from: source, to: destination).sessions, 1)
        owner.useAccount(userID: "separation-transfer")
        let transferred = try XCTUnwrap(repo.resumable(is3D: true))
        XCTAssertEqual(transferred.ownerKey, destination)
        XCTAssertEqual(transferred.current?.id, record.current?.id); XCTAssertEqual(transferred.draftInput, record.draftInput)
    }
}

/// Deterministic worker gates exercise cancellation races without timing the production solver.
private final class SeparationPrefetchProbe: @unchecked Sendable {
    private let condition = NSCondition()
    private let prepared: SeparationQuestionGenerator.Prepared
    private var calls: [(SceneTrainingConfiguration, Set<String>)] = []
    private var released: Set<Int> = [], failures: Set<Int> = []
    private var allReleased = false, ignoresCancellation = false
    init(prepared: SeparationQuestionGenerator.Prepared) { self.prepared = prepared }
    var count: Int { condition.lock(); defer { condition.unlock() }; return calls.count }
    var ignoreCancellation: Bool {
        get { condition.lock(); defer { condition.unlock() }; return ignoresCancellation }
        set { condition.lock(); ignoresCancellation = newValue; condition.unlock() }
    }
    func excluded(at i: Int) -> Set<String> { condition.lock(); defer { condition.unlock() }; return calls[i].1 }
    func configuration(at i: Int) -> SceneTrainingConfiguration { condition.lock(); defer { condition.unlock() }; return calls[i].0 }
    func release(_ i: Int) { condition.lock(); released.insert(i); condition.broadcast(); condition.unlock() }
    func releaseAll() { condition.lock(); allReleased = true; condition.broadcast(); condition.unlock() }
    func fail(_ i: Int) { condition.lock(); failures.insert(i); condition.unlock() }
    func generate(_ configuration: SceneTrainingConfiguration, _ excluded: Set<String>) throws -> SeparationQuestionGenerator.Prepared {
        condition.lock(); defer { condition.unlock() }
        let i = calls.count; calls.append((configuration, excluded))
        while !allReleased && !released.contains(i) {
            if Task.isCancelled && !ignoresCancellation { throw CancellationError() }
            _ = condition.wait(until: Date().addingTimeInterval(0.02))
        }
        if failures.contains(i) { throw SeparationQuestionGenerator.Failure.unavailable }
        return prepared
    }
}
