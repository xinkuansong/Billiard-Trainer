import XCTest
import SceneKit
import SwiftData
@testable import QiuJi

final class KBallPracticeTests: XCTestCase {
    func testFilteringUsesObservedRailAndSelectedTiming() throws {
        var config = KBallConfiguration()
        config.filter = .init(rail: 3, timing: .before, grade: nil, pocket: .middle)
        let first = try KBallQuestionPreparer.prepare(config, seed: 29)
        XCTAssertEqual(first.question.source.rail, 3)
        XCTAssertEqual(first.question.source.railsBeforeK.count, 2)
        XCTAssertEqual(first.question.source.timing, .before)
        XCTAssertGreaterThanOrEqual(first.question.board.pocketIndex, 4)
        XCTAssertEqual(first.question.layout.questions.count, 1)
        let next = try KBallQuestionPreparer.prepare(config, excluding: [first.question.contentID], seed: 29)
        XCTAssertNotEqual(first.question.contentID, next.question.contentID)
    }
    func testRetryCannotChangeFirstAnswerAndPayloadRoundTrips() throws {
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 30)
        var record = KBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        let failed = try shot(prepared.question, succeeds: false)
        record.accept(failed)
        let success = try shot(prepared.question, succeeds: true)
        record.accept(success); record.accept(success)
        XCTAssertEqual(record.attempts.count, 1)
        XCTAssertEqual(record.successCount, 0)
        XCTAssertEqual(record.latestShot?.id, success.id)
        XCTAssertEqual(record.currentAttempt?.id, failed.id)
        let restored = try KBallPracticeRecord.decodePayload(record.encodedPayload())
        XCTAssertTrue(restored.isCompatible)
        XCTAssertEqual(restored.attempts.count, 1)
        XCTAssertEqual(restored.latestShot?.id, success.id)
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(TrainingSessionKind.kBallPractice))
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(TrainingSessionKind.kBallPractice))
    }
    func testShotUsesOrderedRailsWithoutIncomingDirectionAndPreservesLegacyHistory() throws {
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 30)
        let q = prepared.question
        for rails in [q.railHintSegments, Array(q.railHintSegments.dropLast())] {
            for approaching in [true, false] {
                let prediction = kBallRailPrediction(railID: q.source.railID, priorRails: rails,
                    approaching: approaching, pocket: q.board.pocketIndex)
                let accepted = try KBallShot(question: q, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
                XCTAssertNil(accepted.failure)
                var wrong = prediction
                wrong.events.insert(.init(time: 1.01, kind: .ballCushion(ball: ShotInput.cueBallName), cushionIndex: 6), at: 1)
                // Pocket jaws retain their previous non-main-rail treatment.
                XCTAssertNil(KBallJudgement.failure(wrong, pocket: q.board.pocketIndex, question: q.source))
                wrong.events.insert(.init(time: 1.02, kind: .ballCushion(ball: ShotInput.cueBallName), cushionIndex: nil), at: 2)
                XCTAssertEqual(KBallJudgement.failure(wrong, pocket: q.board.pocketIndex, question: q.source), .railFacts)
                var noIncomingState = prediction; noIncomingState.recorder = TrajectoryRecorder()
                XCTAssertNil(KBallJudgement.failure(noIncomingState, pocket: q.board.pocketIndex, question: q.source))
            }
        }
        var record = KBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try shot(q, succeeds: true))
        XCTAssertTrue(record.canResumeCurrentTraining)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        var versionTwo = record; versionTwo.judgementVersion = 2
        XCTAssertTrue(versionTwo.isCompatible); XCTAssertFalse(versionTwo.canResumeCurrentTraining)
        XCTAssertEqual(versionTwo.successCount, 1)
        json.removeValue(forKey: "judgementVersion")
        var oldShot = try XCTUnwrap(json["latestShot"] as? [String: Any]); oldShot.removeValue(forKey: "observedRail")
        json["latestShot"] = oldShot
        let old = try JSONDecoder().decode(KBallPracticeRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.isCompatible)
        XCTAssertFalse(old.canResumeCurrentTraining)
        XCTAssertEqual(old.successCount, 1)
        XCTAssertNil(old.latestShot?.observedRail)
    }
    func testOptionalLastRailAndStrictPrefixForEveryKBallCategory() throws {
        for count in 1...3 {
            for timing in KBallTiming.allCases {
                var config = KBallConfiguration(); config.filter.rail = count; config.filter.timing = timing
                let q = try KBallQuestionPreparer.prepare(config, seed: 31).question
                let expected = q.railHintSegments, prefix = Array(expected.dropLast())
                XCTAssertEqual(expected.count, count)
                func failure(_ rails: [Int], post: Bool = false) -> KBallJudgement.Failure? {
                    var prediction = kBallRailPrediction(railID: q.source.railID, priorRails: rails,
                        approaching: false, pocket: q.board.pocketIndex)
                    if post { prediction.events.append(.init(time: 6, kind: .ballCushion(ball: ShotInput.cueBallName), cushionIndex: q.source.railID)) }
                    return KBallJudgement.failure(prediction, pocket: q.board.pocketIndex, question: q.source)
                }
                XCTAssertNil(failure(prefix)) // includes direct K with no rails for one-rail questions
                XCTAssertNil(failure(prefix, post: true))
                XCTAssertNil(failure(expected))
                XCTAssertEqual(failure(expected + [expected.last!]), .railOrder)
                XCTAssertEqual(failure(prefix + [(expected.last! + 1) % 6]), .railOrder)
                if count > 1 { XCTAssertEqual(failure(Array(prefix.dropLast())), .railOrder) }
                if prefix.count > 1, prefix != Array(prefix.reversed()) {
                    XCTAssertEqual(failure(Array(prefix.reversed())), .railOrder)
                }
                let reference = try KBallQuestionPreparer.solve(layout: q.layout, question: q.source,
                    input: .init(), surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile(), reference: true)
                XCTAssertNil(KBallJudgement.failure(reference, pocket: q.board.pocketIndex, question: q.source), q.contentID)
            }
        }
    }
    @MainActor func testReferenceGateSettingsCancelAndSharedViewKeepQuestion() throws {
        let suite = "KBallPracticeTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "kBallTests.\(UUID())", limit: 15)
        limiter.isPremium = true
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 31)
        let repo = MemoryKBallRepository()
        let vm = KBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: repo); vm.start(.init(), prepared: prepared)
        let id = vm.record?.id, question = vm.record?.current?.id
        XCTAssertTrue(vm.shouldShowReference)
        vm.velocity = 2.5; vm.setSpin(0.1, -0.1)
        let input = vm.input
        vm.openSettings(); XCTAssertTrue(vm.cancelSettings())
        XCTAssertEqual(vm.record?.id, id); XCTAssertEqual(vm.input, input)
        XCTAssertTrue(vm.switchTrainingView(to: true))
        XCTAssertEqual(vm.record?.current?.id, question); XCTAssertEqual(vm.input, input)
        XCTAssertEqual(vm.record?.attempts.count, 0)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
        vm.ownerChanged()
        XCTAssertNil(vm.record)
    }
    @MainActor func testNeutralBaselinePersistsAcrossInputViewAndResume() async throws {
        let suite = "KBallBaselineTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: suite, limit: 15)
        limiter.isPremium = true
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 31)
        let vm = KBallPracticeViewModel(is3D: false, limiter: limiter, defaults: defaults)
        vm.attach(repository: MemoryKBallRepository()); vm.start(.init(), prepared: prepared)
        vm.velocity = 3; vm.setSpin(0.2, -0.2)
        vm.setupScene()
        defer { vm.suspendTeachingActivity() }
        XCTAssertTrue(vm.shouldShowReference)
        for _ in 0..<200 where vm.referenceTrajectory == nil { try await Task.sleep(for: .milliseconds(50)) }
        let baseline = try XCTUnwrap(vm.referenceTrajectory)
        let neutral = try KBallQuestionPreparer.solve(layout: prepared.question.layout,
            question: prepared.question.source, input: .init(), surfaceY: vm.scene.surfaceY,
            profile: AccuracyTipSelector.renderedProfile())
        let expected = try SeparationTrajectory.extract(neutral)
        XCTAssertEqual(baseline.count, expected.count)
        for (actual, point) in zip(baseline, expected) {
            XCTAssertEqual(actual.time, point.time, accuracy: 0.00001)
            XCTAssertEqual(actual.position.x, point.position.x, accuracy: 0.00001)
            XCTAssertEqual(actual.position.z, point.position.z, accuracy: 0.00001)
        }
        XCTAssertTrue(vm.switchTrainingView(to: true))
        vm.suspendTeachingActivity(); vm.resumeTeachingActivity()
        for _ in 0..<200 where vm.referenceTrajectory == nil { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(vm.shouldShowReference)
        XCTAssertEqual(vm.referenceTrajectory?.count, baseline.count)
        XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "kBall.reference", recursively: true))
        XCTAssertEqual(vm.input.velocity, 3)
        XCTAssertEqual(vm.record?.attempts.count, 0)
        XCTAssertEqual(limiter.questionsUsedToday, 0)
    }
    func testKLayoutAndPreferencesRemainIndependent() {
        XCTAssertEqual(TrainingProject.from(route: "kBallPractice3D"), .kBall)
        XCTAssertEqual(TablePreferencePage.kBallPractice2D.trainingProject, .kBall)
        XCTAssertTrue(FreeControlCatalog.ids(page: .kBallPractice2D, mode: .twoD).contains("shot.strike"))
        XCTAssertTrue(FreeControlCatalog.ids(page: .kBallPractice3D, mode: .threeD).contains("shot.strike"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .kBallPractice2D, mode: .threeD).contains("shot.strike"))
    }
    @MainActor func testRepositoryRestorationOwnerIsolationAndAtomicRollback() throws {
        let suite = "KBallRepoTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let context = ModelContext(ModelContainerFactory.makeInMemoryContainer())
        var uploads = 0
        let repository = LocalKBallPracticeRepository(context: context, owner: owner, enqueue: { _, _ in uploads += 1 })
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 32)
        var record = KBallPracticeRecord(ownerKey: owner.ownerKey, is3D: false, configuration: .init(), prepared: prepared)
        try repository.save(record); XCTAssertEqual(uploads, 0)
        record.accept(try shot(prepared.question, succeeds: true)); try repository.save(record)
        var changed = record; changed.activeSeconds = 120
        var invalid = record.continuation(prepared: prepared); invalid.ownerKey = "other-owner"
        XCTAssertThrowsError(try repository.saveAtomically([changed, invalid]))
        XCTAssertEqual(try repository.resumable(is3D: true)?.activeSeconds, 0)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count, 1); XCTAssertEqual(uploads, 1)
        XCTAssertEqual(HistoryViewModel.assembleKBallSessions(sessions: sessions).records.count, 1)
        let dto = TrainingSessionDTO(from: sessions[0])
        XCTAssertEqual(try JSONDecoder().decode(TrainingSessionDTO.self, from: JSONEncoder().encode(dto)).sourcePayloadSnapshot,
                       sessions[0].sourcePayloadSnapshot)
        sessions[0].sourcePayloadSnapshot = Data("broken".utf8)
        XCTAssertThrowsError(try repository.resumable(is3D: false))
        XCTAssertEqual(HistoryViewModel.assembleKBallSessions(sessions: sessions).unreadableCount, 1)
    }
    private func shot(_ question: KBallQuestion, succeeds: Bool) throws -> KBallShot {
        var prediction = ShotPrediction()
        prediction.termination = .settled; prediction.recorder = TrajectoryRecorder()
        prediction.strikeDirection = .init(1, 0, 0)
        prediction.finalPositions = [ShotInput.cueBallName: .init(0,0,0)]
        prediction.events = [
            .init(time: 1, kind: .ballBall(ballA: ShotInput.cueBallName, ballB: ShotInput.targetBallName)),
            .init(time: 3, kind: .pocket(ball: ShotInput.targetBallName, pocketId: "pocket_\(question.board.pocketIndex)"))]
        if succeeds {
            prediction = kBallRailPrediction(railID: question.source.railID,
                priorRails: question.railHintSegments,
                approaching: false, pocket: question.board.pocketIndex)
        }
        return try .init(question: question, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
    }
}

@MainActor private final class MemoryKBallRepository: KBallPracticeRepository {
    var ownerKey = "test"
    var records: [UUID: KBallPracticeRecord] = [:]
    func save(_ record: KBallPracticeRecord) throws { records[record.id] = record }
    func saveAtomically(_ records: [KBallPracticeRecord]) throws { for record in records { try save(record) } }
    func resumable(is3D: Bool) throws -> KBallPracticeRecord? { records.values.first { $0.status == .active } }
}
