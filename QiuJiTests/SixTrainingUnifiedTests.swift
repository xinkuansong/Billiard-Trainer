import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class SixTrainingUnifiedTests: XCTestCase {
    func testIndependentAllowancesPersistAndRollOverWithoutChangingPredictionQuota() throws {
        let name = "six-training-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var now = Date(timeIntervalSince1970: 1_790_000_000)
        let prediction = AngleUsageLimiter(defaults: defaults, now: { now })
        let angle = AngleUsageLimiter(defaults: defaults, now: { now }, namespace: "scene2D")
        let aim = AngleUsageLimiter(defaults: defaults, now: { now }, namespace: "aimPoint2D")
        let accuracy = AngleUsageLimiter(defaults: defaults, now: { now }, namespace: "accuracy2D")
        for _ in 0..<20 { angle.recordQuestion() }
        XCTAssertTrue(angle.isLimitReached)
        XCTAssertEqual(aim.remainingToday, 20); XCTAssertEqual(accuracy.remainingToday, 20)
        XCTAssertEqual(prediction.remainingToday, 20)
        let id = UUID(), submitted = now
        accuracy.recordQuestion(attemptID: id, submittedAt: now)
        let restored = AngleUsageLimiter(defaults: defaults, now: { now }, namespace: "accuracy2D")
        restored.recordQuestion(attemptID: id, submittedAt: now)
        XCTAssertEqual(restored.remainingToday, 19)
        XCTAssertEqual(AngleUsageLimiter(defaults: defaults, now: { now }, namespace: "scene2D").remainingToday, 0)
        angle.isPremium = true; XCTAssertFalse(angle.isLimitReached)
        angle.isPremium = false; XCTAssertTrue(angle.isLimitReached)
        now = now.addingTimeInterval(86400)
        angle.refreshDay(); XCTAssertEqual(angle.remainingToday, 20)
        restored.recordQuestion(attemptID: id, submittedAt: submitted)
        XCTAssertEqual(restored.remainingToday, 20)
    }

    func testMetricsCountInvalidAnswersButAverageOnlyFiniteAbsoluteErrors() {
        let samples: [SceneTrainingSample] = [2.0, -4.0, nil, .nan].map {
            .init(angle: 20, error: $0, signedError: $0, assisted: false)
        }
        let metrics = SceneTrainingMetrics(samples: samples, unit: "mm")
        XCTAssertEqual(metrics.rate, "25.0%")
        XCTAssertEqual(metrics.mean, "3.0mm")
        XCTAssertEqual(SceneTrainingMetrics(samples: [], unit: "°").rate, "—")
        XCTAssertEqual(SceneTrainingMetrics(samples: [], unit: "°").mean, "—")
        XCTAssertEqual(SceneTrainingMetrics.percentage(7, of: 8), "87.5%")
    }

    func testAccuracyTransparencyPersistsSeparatelyForBothModes() throws {
        let name = "six-preferences-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TablePreferencesStore(defaults: defaults)
        store.apply(.transparency, value: 0.25, to: .accuracy2D)
        store.apply(.transparency, value: 0.75, to: .accuracy3D)
        let restored = TablePreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.snapshot(for: .accuracy2D)[.transparency], 0.25)
        XCTAssertEqual(restored.snapshot(for: .accuracy3D)[.transparency], 0.75)
        XCTAssertEqual(restored.snapshot(for: .freePlay)[.transparency], 0.5)
    }

    func testStatisticsUseActualAngleAndMeanErrorWithoutCombiningAssistance() throws {
        var generator = SceneTrainingGenerator(seed: 15)
        var run = SceneTrainingRun(queue: try generator.batch(.init()))
        let question = try run.next()
        let values: [Double?] = [1, -5, nil]
        let results = try values.map { value -> AngleTestResult in
            let result = AngleTestResult(actualAngle: 0, userAngle: 0, pocketType: "corner", quizType: "aimPoint2D")
            let score = SceneAimScore(status: value == nil ? .backwards : .valid, millimetres: value, straight: false)
            result.trainingMetadataJSON = try XCTUnwrap(run.metadata(unit: "mm", score: score)).json
            return result
        }
        let history = AngleHistoryViewModel()
        history.allResults = results; history.timeRange = .all
        let range = try XCTUnwrap(history.rangeStats.first { $0.sampleCount == 3 })
        XCTAssertEqual(try XCTUnwrap(range.meanError), 3, accuracy: 0.0001)
        XCTAssertEqual(history.invalidCount, 1)
        XCTAssertEqual(history.unit, "mm")
        XCTAssertEqual(results[0].trainingMetadata?.angle, question.actualAngle)
        XCTAssertEqual(history.rangeStats.compactMap(\.sampleCount).reduce(0,+), 3)
        run.assistance.insert("angleHint")
        let assisted = AngleTestResult(actualAngle: 0, userAngle: 0, pocketType: "corner", quizType: "aimPoint2D")
        assisted.trainingMetadataJSON = try XCTUnwrap(run.metadata(unit: "mm", score: .init(status: .valid, millimetres: 30, straight: false))).json
        XCTAssertNotEqual(assisted.cohort, results[0].cohort)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(results[0].trainingMetadataJSON).utf8)) as? [String: Any])
        payload["angle"] = 90
        results[0].trainingMetadataJSON = String(data: try JSONSerialization.data(withJSONObject: payload), encoding: .utf8)
        history.allResults = [results[0]]
        history.timeRange = .all
        XCTAssertEqual(history.rangeStats.last?.sampleCount, 1)
        XCTAssertTrue(history.rangeStats.last?.label.contains("90") == true)
    }

    func testRetryKeepsFirstMissAndExactTipIncludingLastQuestion() throws {
        var generator = SceneTrainingGenerator(seed: 20261021)
        let tip = AccuracyTip(x: 0, y: 0.4)
        let questions = try generator.batch(.init()).enumerated().map {
            AccuracyPracticeQuestion(board: TrainingBankBoard(question: $0.element, seed: UInt64($0.offset)), selectedTip: tip)
        }
        var record = try AccuracyPracticeRecord(ownerKey: "guest:test", is3D: false,
            configuration: .init(), bankFingerprint: "fixture", questions: questions)
        for _ in 0..<20 {
            let first = try record.freezeAttempt()
            var missed = ShotPrediction(); missed.termination = .settled
            let pocket = try XCTUnwrap(record.current).board.pocketIndex
            XCTAssertTrue(record.accept(.init(prediction: missed, pocketIndex: pocket), attemptID: first.id))
            let count = record.validAttempts.count
            record.draftVelocity = 2
            let retry = try record.practiceAttempt()
            XCTAssertNotEqual(retry.id, first.id)
            XCTAssertEqual(retry.fixedTip.x, tip.x); XCTAssertEqual(retry.fixedTip.y, tip.y)
            XCTAssertEqual(retry.velocity, 2)
            var success = missed
            success.events = [.init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
                .init(time: 2, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_\(pocket)"))]
            let result = AccuracyPracticeAttempt.Result(prediction: success, pocketIndex: pocket)
            XCTAssertFalse(record.accept(result, attemptID: retry.id))
            XCTAssertFalse(record.accept(result, attemptID: first.id))
            XCTAssertEqual(record.validAttempts.count, count)
            XCTAssertEqual(record.successCount, 0)
            try record.advance()
        }
        XCTAssertEqual(record.status, .completed)
        XCTAssertNoThrow(try record.practiceAttempt(), "The twentieth question can still be retried")
        let restored = try JSONDecoder().decode(AccuracyPracticeRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored.validAttempts.count, 20); XCTAssertEqual(restored.successCount, 0)
    }
}
