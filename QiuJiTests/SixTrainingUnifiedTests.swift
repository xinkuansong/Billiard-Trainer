import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

@MainActor
final class SixTrainingUnifiedTests: XCTestCase {
    func testAccuracyReplayRestoresTableAndNeverChangesFirstAttempt() async throws {
        for is3D in [false, true] {
            let container = ModelContainerFactory.makeInMemoryContainer()
            let vm = AccuracyPracticeViewModel(is3D: is3D)
            let wasPremium = vm.limiter.isPremium
            vm.limiter.isPremium = true
            defer { vm.suspendTeachingActivity(); vm.limiter.isPremium = wasPremium }
            vm.attach(context: ModelContext(container))
            vm.start(.init(), prepared: try AccuracyPreparedRound.prepare(.init(), excluding: [], seed: 20261021))
            vm.setupScene(); vm.setCameraMode(vm.cameraMode); vm.cameraTransitionBusy = false
            XCTAssertFalse(vm.canPlayback); XCTAssertFalse(vm.canRetry)
            vm.strike()
            let deadline = Date().addingTimeInterval(20)
            while vm.phase == .computing && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertEqual(vm.phase, .playing)
            vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
            XCTAssertTrue(vm.canPlayback); XCTAssertTrue(vm.canRetry)
            let first = try XCTUnwrap(vm.record)
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            let encoded = try encoder.encode(first)
            let quota = vm.limiter.remainingToday
            let cue = try XCTUnwrap(vm.scene.cueBallNode), target = try XCTUnwrap(vm.targetNode)
            let cuePosition = cue.simdPosition, targetPosition = target.simdPosition
            let cueHidden = cue.isHidden, targetHidden = target.isHidden
            cue.opacity = 0.6
            let opacity = cue.opacity
            cue.eulerAngles = SCNVector3(0.3, 0.6, 0.2)
            let pose = cue.simdOrientation.vector
            let camera = vm.scene.cameraNode.simdTransform
            vm.replayLastShot()
            XCTAssertTrue(vm.isReplaying); XCTAssertFalse(vm.canRetry); XCTAssertFalse(vm.canPlayback)
            XCTAssertEqual(vm.primaryTitle, "停止回放")
            XCTAssertEqual(vm.scene.currentCameraMode, is3D ? .perspective3D : .topDown2D)
            vm.stopPlayback()
            XCTAssertFalse(vm.isReplaying); XCTAssertEqual(vm.phase, .result)
            XCTAssertEqual(cue.simdPosition, cuePosition); XCTAssertEqual(target.simdPosition, targetPosition)
            XCTAssertEqual(cue.isHidden, cueHidden); XCTAssertEqual(target.isHidden, targetHidden)
            XCTAssertEqual(cue.opacity, opacity); XCTAssertEqual(cue.simdOrientation.vector, pose)
            XCTAssertEqual(vm.scene.cameraNode.simdTransform, camera)
            XCTAssertEqual(try encoder.encode(vm.record), encoded)
            XCTAssertEqual(vm.limiter.remainingToday, quota)

            vm.retry(); vm.nudgeAim(2); vm.velocity = 2.25
            let draft = vm.record?.draftDirection, retryPosition = cue.simdPosition
            vm.replayLastShot(); vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
            XCTAssertFalse(vm.isReplaying); XCTAssertEqual(vm.phase, .aiming)
            XCTAssertTrue(vm.isRetrying); XCTAssertEqual(vm.record?.draftDirection, draft)
            XCTAssertEqual(vm.velocity, 2.25); XCTAssertEqual(cue.simdPosition, retryPosition)
            XCTAssertEqual(vm.record?.currentAttempt?.id, first.currentAttempt?.id)
            XCTAssertEqual(vm.record?.validAttempts.count, 1); XCTAssertEqual(vm.limiter.remainingToday, quota)
            XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
            vm.ownerChanged(); XCTAssertFalse(vm.canPlayback)
            withExtendedLifetime(container) {}
        }
    }

    private func withAccuracyScene(is3D: Bool, _ check: (AccuracyPracticeViewModel) throws -> Void) throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = AccuracyPracticeViewModel(is3D: is3D)
        let wasPremium = vm.limiter.isPremium
        vm.limiter.isPremium = true
        defer { vm.suspendTeachingActivity(); vm.limiter.isPremium = wasPremium }
        vm.attach(context: context)
        vm.start(.init(), prepared: try AccuracyPreparedRound.prepare(.init(), excluding: [], seed: 20261021))
        vm.setupScene()
        vm.cameraTransitionBusy = false
        try check(vm)
        withExtendedLifetime(container) {}
    }

    func testBackgroundRestoresAimWithoutChangingQuestionDraftOrPoses() throws {
        for is3D in [false, true] {
            try withAccuracyScene(is3D: is3D) { vm in
                vm.nudgeAim(1.5); vm.velocity = 2.25
                let record = try XCTUnwrap(vm.record)
                let cue = try XCTUnwrap(vm.scene.cueBallNode)
                let target = try XCTUnwrap(vm.targetNode)
                let cuePosition = cue.simdPosition, targetPosition = target.simdPosition
                let cuePose = cue.simdOrientation, targetPose = target.simdOrientation
                for _ in 0..<3 {
                    XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
                    vm.suspendTeachingActivity()
                    XCTAssertNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
                    vm.resumeTeachingActivity()
                    XCTAssertEqual(vm.phase, .aiming)
                    XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
                    XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
                    XCTAssertEqual(vm.record?.id, record.id)
                    XCTAssertEqual(vm.record?.cursor, record.cursor)
                    XCTAssertEqual(vm.record?.draftDirection, record.draftDirection)
                    XCTAssertEqual(vm.velocity, 2.25)
                    XCTAssertEqual(vm.tip.x, record.current?.fixedTip.x)
                    XCTAssertEqual(vm.tip.y, record.current?.fixedTip.y)
                    XCTAssertEqual(vm.record?.validAttempts.count, 0)
                    XCTAssertEqual(cue.simdPosition, cuePosition); XCTAssertEqual(target.simdPosition, targetPosition)
                    XCTAssertEqual(cue.simdOrientation.vector, cuePose.vector)
                    XCTAssertEqual(target.simdOrientation.vector, targetPose.vector)
                }
            }
        }
    }

    func testInterruptedCalculationRetainsFrozenAttemptWithoutScoringIt() throws {
        for is3D in [false, true] {
            try withAccuracyScene(is3D: is3D) { vm in
                vm.strike()
                XCTAssertEqual(vm.phase, .computing)
                let record = try XCTUnwrap(vm.record)
                let attempt = try XCTUnwrap(record.currentAttempt)
                vm.suspendTeachingActivity()
                vm.setupScene(); vm.resumeTeachingActivity()
                XCTAssertEqual(vm.phase, .result)
                XCTAssertEqual(vm.primaryTitle, "重试")
                XCTAssertEqual(vm.record?.currentAttempt?.id, attempt.id)
                XCTAssertEqual(vm.record?.cursor, record.cursor)
                XCTAssertEqual(vm.record?.draftDirection, record.draftDirection)
                XCTAssertNil(vm.record?.currentAttempt?.result)
                XCTAssertEqual(vm.record?.validAttempts.count, 0)
                XCTAssertNil(vm.scene.rootNode.action(forKey: "accuracy.clock"))
            }
        }
    }

    func testCancellingRestartPreservesSummaryAcrossHostRecreation() throws {
        for is3D in [false, true] {
            try withAccuracyScene(is3D: is3D) { vm in
                vm.finish()
                let record = try XCTUnwrap(vm.record)
                XCTAssertEqual(vm.phase, .summary)
                vm.openSettings(); vm.suspendTeachingActivity()
                XCTAssertTrue(vm.cancelSettings())
                vm.setupScene()
                vm.resumeTeachingActivity()
                XCTAssertEqual(vm.phase, .summary)
                XCTAssertEqual(vm.record?.id, record.id)
                XCTAssertEqual(vm.record?.status, .ended)
                XCTAssertEqual(vm.record?.validAttempts.count, 0)
                XCTAssertNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
            }
        }
    }

    func testCancellingSettingsDuringAimingPreservesDraftAcrossHostRecreation() throws {
        for is3D in [false, true] {
            try withAccuracyScene(is3D: is3D) { vm in
                vm.nudgeAim(-2); vm.velocity = 3
                let direction = vm.record?.draftDirection
                let question = vm.record?.current?.id
                vm.openSettings(); vm.suspendTeachingActivity()
                XCTAssertTrue(vm.cancelSettings())
                vm.setupScene()
                XCTAssertEqual(vm.phase, .aiming)
                XCTAssertEqual(vm.record?.draftDirection, direction)
                XCTAssertEqual(vm.record?.current?.id, question)
                XCTAssertEqual(vm.velocity, 3)
                XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "accuracy.aimLine", recursively: true))
            }
        }
    }
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
