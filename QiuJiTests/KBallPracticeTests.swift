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
    func testShotEnforcesObservedRailAndLegacyHistoryIsPreserved() throws {
        let prepared = try KBallQuestionPreparer.prepare(.init(), seed: 30)
        let q = prepared.question
        for approaching in [true, false] {
            let rails = Array(repeating: q.source.railID, count: q.source.rail - (approaching ? 1 : 0))
            let prediction = kBallRailPrediction(railID: q.source.railID, priorRails: rails,
                approaching: approaching, pocket: q.board.pocketIndex)
            let accepted = try KBallShot(question: q, input: .init(), prediction: prediction, surfaceY: BTTablePhysics.surfaceY)
            XCTAssertNil(accepted.failure)
            XCTAssertEqual(accepted.observedRail, q.source.rail)
            var wrong = prediction
            wrong.events.insert(.init(time: 1.01, kind: .ballCushion(ball: ShotInput.cueBallName), cushionIndex: q.source.railID), at: 1)
            let rejected = try KBallShot(question: q, input: .init(), prediction: wrong, surfaceY: BTTablePhysics.surfaceY)
            XCTAssertEqual(rejected.failure, .rail)
            XCTAssertEqual(rejected.observedRail, q.source.rail + 1)
            var noFacts = prediction; noFacts.recorder = TrajectoryRecorder()
            XCTAssertEqual(try KBallShot(question: q, input: .init(), prediction: noFacts,
                surfaceY: BTTablePhysics.surfaceY).failure, .railFacts)
        }
        var record = KBallPracticeRecord(ownerKey: "test", is3D: false, configuration: .init(), prepared: prepared)
        record.accept(try shot(q, succeeds: true))
        XCTAssertTrue(record.canResumeCurrentTraining)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        json.removeValue(forKey: "judgementVersion")
        var oldShot = try XCTUnwrap(json["latestShot"] as? [String: Any]); oldShot.removeValue(forKey: "observedRail")
        json["latestShot"] = oldShot
        let old = try JSONDecoder().decode(KBallPracticeRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.isCompatible)
        XCTAssertFalse(old.canResumeCurrentTraining)
        XCTAssertEqual(old.successCount, 1)
        XCTAssertNil(old.latestShot?.observedRail)
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
    @MainActor func testBaselineUsesNeutralInputRatherThanSavedSolutionOrDraft() async throws {
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
        for _ in 0..<300 where vm.referenceTrajectory == nil && vm.message == nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        let actual = try XCTUnwrap(vm.referenceTrajectory, vm.message ?? "Missing neutral baseline")
        let expected = try SeparationTrajectory.extract(KBallQuestionPreparer.solve(
            layout: prepared.question.layout, question: prepared.question.source, input: .init(),
            surfaceY: vm.scene.surfaceY, profile: AccuracyTipSelector.renderedProfile()))
        XCTAssertEqual(actual.count, expected.count)
        for (a, b) in zip(actual, expected) {
            XCTAssertEqual(a.time, b.time, accuracy: 0.00001)
            XCTAssertEqual(a.position.x, b.position.x, accuracy: 0.00001)
            XCTAssertEqual(a.position.z, b.position.z, accuracy: 0.00001)
        }
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
                priorRails: Array(repeating: question.source.railID, count: question.source.rail),
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
