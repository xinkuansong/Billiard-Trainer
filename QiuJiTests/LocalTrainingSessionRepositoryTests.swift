import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class LocalTrainingSessionRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: LocalTrainingSessionRepository!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
        repo = LocalTrainingSessionRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        container = nil
        context = nil
        super.tearDown()
    }

    func test_create_and_fetchAll() async throws {
        let session = try await repo.create(ballType: "chinese8")
        XCTAssertEqual(session.ballType, "chinese8")

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, session.id)
    }

    func test_fetchAll_empty() async throws {
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_fetchByDate_inRange() async throws {
        let session = try await repo.create(ballType: "chinese8")

        let now = Date()
        let from = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let to = Calendar.current.date(byAdding: .hour, value: 1, to: now)!

        let results = try await repo.fetchByDate(from: from, to: to)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, session.id)
    }

    func test_fetchByDate_outOfRange() async throws {
        _ = try await repo.create(ballType: "chinese8")

        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let farFuture = Calendar.current.date(byAdding: .day, value: 2, to: Date())!

        let results = try await repo.fetchByDate(from: future, to: farFuture)
        XCTAssertTrue(results.isEmpty)
    }

    func test_delete() async throws {
        let session = try await repo.create(ballType: "chinese8")
        var all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)

        try await repo.delete(session)
        all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_update_changes_persist() async throws {
        let session = try await repo.create(ballType: "chinese8")
        XCTAssertEqual(session.note, "")

        session.note = "今天练球手感不错"
        session.totalDurationMinutes = 45
        try await repo.update(session)

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.note, "今天练球手感不错")
        XCTAssertEqual(all.first?.totalDurationMinutes, 45)
    }

    func test_create_multiple_sessions() async throws {
        _ = try await repo.create(ballType: "chinese8")
        _ = try await repo.create(ballType: "snooker")
        _ = try await repo.create(ballType: "9ball")

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 3)
    }
}
