import XCTest
import SwiftData
@testable import QiuJi

/// Diagnostic draft. Register only in the frozen diagnostic unit-test target.
/// A protocol-layer failure is deliberately NOT described as a failed SQLite save.
@MainActor
final class CognitiveRepositoryDiagnosticTests: XCTestCase {
    private var owner: CurrentOwnerContext!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let environment = ProcessInfo.processInfo.environment
        let boundary = environment["QD_COGNITIVE_REPOSITORY_ENVIRONMENT"]
            ?? environment["TEST_RUNNER_QD_COGNITIVE_REPOSITORY_ENVIRONMENT"]
        XCTAssertEqual(boundary, "DEDICATED_GUEST_MEMORY_HOST")
        guard boundary == "DEDICATED_GUEST_MEMORY_HOST" else {
            throw DiagnosticError.missingIsolation
        }
        defaults = try XCTUnwrap(UserDefaults(suiteName: "QD-CognitiveRepository-\(UUID().uuidString)"))
        owner = CurrentOwnerContext(defaults: defaults)
    }

    override func tearDownWithError() throws {
        // Release the singleton's reference to the tested disk container. Keep
        // a new empty memory context, never restore a real user's context.
        let sink = ModelContainerFactory.makeInMemoryContainer()
        SyncQueueManager.shared.configure(context: ModelContext(sink))
        owner = nil
        defaults = nil
        try super.tearDownWithError()
    }

    func test_sameResultObjectSavedTwice_keepsOneResultAndOneSession() async throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        SyncQueueManager.shared.configure(context: context)
        let repository = LocalAngleTestRepository(context: context, ownerContext: owner)
        let result = makeResult()
        try await repository.save(result)
        let resultID = result.id
        let sessionID = try XCTUnwrap(result.sessionId)
        try await repository.save(result)
        let results = try await repository.fetchAll()
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        print("[QD-CognitiveRepository] sameObject resultCount=\(results.count) sessionCount=\(sessions.count) id=\(resultID)")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, resultID)
        XCTAssertEqual(results.first?.sessionId, sessionID)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, sessionID)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DrillEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DrillSet>()).isEmpty)
        // Queue duplication is observed, not confused with duplicate results.
        let queue = try context.fetch(FetchDescriptor<SyncPendingItem>())
        print("[QD-CognitiveRepository] sameObject pendingCount=\(queue.count)")
    }

    func test_protocolFailureThenRetry_persistsExactlyOneAnswerInRealMemoryRepository() async throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        SyncQueueManager.shared.configure(context: context)
        let repository = LocalAngleTestRepository(context: context, ownerContext: owner)
        let wrapper = FailFirstRepository(base: repository)
        let limiter = AngleUsageLimiter(defaults: defaults)
        limiter.isPremium = true
        let vm = GeometricAngleViewModel(limiter: limiter)
        vm.configure(repository: wrapper)
        vm.currentAngle = 42
        vm.userInput = "35"
        vm.submitAnswer()
        try await waitUntil { vm.saveErrorMessage != nil }
        XCTAssertEqual(wrapper.attempts, 1)
        XCTAssertEqual(vm.unsavedResults.count, 1)
        let failedID = try XCTUnwrap(vm.unsavedResults.first).id
        let before = try await repository.fetchAll()
        XCTAssertTrue(before.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrainingSession>()).isEmpty)
        vm.retryFailedSaves()
        // retryFailedSaves clears UI state synchronously before its Task saves.
        // Wait for the wrapper's actual successful return, not that early clear.
        try await waitUntil { wrapper.successes == 1 }
        let after = try await repository.fetchAll()
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        print("[QD-CognitiveRepository] protocolFailure attempts=\(wrapper.attempts) successes=\(wrapper.successes) results=\(after.count) sessions=\(sessions.count)")
        XCTAssertEqual(wrapper.attempts, 2)
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.id, failedID)
        XCTAssertEqual(after.first?.actualAngle, 42)
        XCTAssertEqual(after.first?.userAngle, 35)
        XCTAssertEqual(after.first?.quizType, "geometric")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(after.first?.sessionId, sessions.first?.id)
        XCTAssertNotNil(after.first?.sessionId)
        XCTAssertNil(vm.saveErrorMessage)
        XCTAssertTrue(vm.unsavedResults.isEmpty)
        XCTAssertEqual(vm.sessionResults.count, 1)
        XCTAssertEqual(vm.userInput, "35")
    }

    func test_geometricAnswer_reopensIndependentDiskStoreWithOriginalSessionAndValues() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QD-CognitiveRepository-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let url = directory.appendingPathComponent("cognitive.store")
        // Print before work so failed tests also identify the preserved store.
        print("[QD-CognitiveRepository] retainedStore=\(url.path)")
        let identity = try await saveIntoIndependentStore(at: url)
        // The saving helper releases its repository, result, context and container.
        // This reopens the same disk file in a new container, in the same process.
        let reopened = try ModelContainerFactory.makeContainer(at: url)
        let context = ModelContext(reopened)
        let repository = LocalAngleTestRepository(context: context, ownerContext: owner)
        let results = try await repository.fetchAll()
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        print("[QD-CognitiveRepository] reopened results=\(results.count) sessions=\(sessions.count) resultId=\(identity.resultID) sessionId=\(identity.sessionID)")
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.id, identity.resultID)
        XCTAssertEqual(result.sessionId, identity.sessionID)
        XCTAssertEqual(result.ownerKey, owner.ownerKey)
        XCTAssertEqual(result.actualAngle, 42)
        XCTAssertEqual(result.userAngle, 35)
        XCTAssertEqual(result.error, 7)
        XCTAssertEqual(result.quizType, "geometric")
        XCTAssertEqual(result.date, identity.date)
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.id, identity.sessionID)
        XCTAssertEqual(session.ownerKey, owner.ownerKey)
        XCTAssertEqual(session.kind, TrainingSessionKind.cognitive)
        XCTAssertEqual(session.note, "角度预测")
        XCTAssertEqual(session.totalDurationMinutes, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DrillEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DrillSet>()).isEmpty)
        let queue = try context.fetch(FetchDescriptor<SyncPendingItem>())
        XCTAssertEqual(queue.filter { $0.entityType == "AngleTestResult" && $0.entityId == identity.resultID }.count, 1)
        XCTAssertEqual(queue.filter { $0.entityType == "TrainingSession" && $0.entityId == identity.sessionID }.count, 1)
        XCTAssertTrue(queue.allSatisfy { $0.ownerKey == owner.ownerKey })
        let attachment = XCTAttachment(string: "retainedStore=\(url.path)\nresultId=\(identity.resultID)\nsessionId=\(identity.sessionID)")
        attachment.name = "Cognitive independent disk identity"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeResult() -> AngleTestResult {
        let result = AngleTestResult(actualAngle: 42, userAngle: 35, pocketType: "geometric",
                                     quizType: "geometric", ownerKey: owner.ownerKey)
        result.date = Date(timeIntervalSince1970: 1_788_825_600)
        return result
    }

    private func saveIntoIndependentStore(at url: URL) async throws -> (resultID: UUID, sessionID: UUID, date: Date) {
        let container = try ModelContainerFactory.makeContainer(at: url)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        SyncQueueManager.shared.configure(context: context)
        defer {
            let sink = ModelContainerFactory.makeInMemoryContainer()
            SyncQueueManager.shared.configure(context: ModelContext(sink))
        }
        let repository = LocalAngleTestRepository(context: context, ownerContext: owner)
        let initialResults = try await repository.fetchAll()
        XCTAssertTrue(initialResults.isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrainingSession>()).isEmpty)
        let result = makeResult()
        try await repository.save(result)
        return (result.id, try XCTUnwrap(result.sessionId), result.date)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<250 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Expected asynchronous persistence state was not reached")
        throw DiagnosticError.timeout
    }

    private enum DiagnosticError: Error { case missingIsolation, timeout }

    @MainActor
    private final class FailFirstRepository: AngleTestRepositoryProtocol {
        struct InjectedProtocolFailure: LocalizedError {
            var errorDescription: String? { "QD injected protocol failure before repository save" }
        }
        let base: LocalAngleTestRepository
        private(set) var attempts = 0
        private(set) var successes = 0
        init(base: LocalAngleTestRepository) { self.base = base }
        func save(_ result: AngleTestResult) async throws {
            attempts += 1
            if attempts == 1 { throw InjectedProtocolFailure() }
            try await base.save(result)
            successes += 1
        }
        func fetchAll() async throws -> [AngleTestResult] { try await base.fetchAll() }
        func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
            try await base.fetchInRange(from: from, to: to)
        }
        func deleteAll() async throws { try await base.deleteAll() }
    }
}
