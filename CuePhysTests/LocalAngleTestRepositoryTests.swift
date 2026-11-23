import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class LocalAngleTestRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: LocalAngleTestRepository!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
        repo = LocalAngleTestRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        container = nil
        context = nil
        super.tearDown()
    }

    func test_save_and_fetchAll() async throws {
        let result = AngleTestResult(actualAngle: 45.0, userAngle: 42.0, pocketType: "corner")
        try await repo.save(result)

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.actualAngle, 45.0)
    }

    func test_fetchAll_empty() async throws {
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_fetchInRange_matching() async throws {
        let result = AngleTestResult(actualAngle: 30.0, userAngle: 28.0, pocketType: "side")
        try await repo.save(result)

        let now = Date()
        let from = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let to = Calendar.current.date(byAdding: .hour, value: 1, to: now)!

        let results = try await repo.fetchInRange(from: from, to: to)
        XCTAssertEqual(results.count, 1)
    }

    func test_fetchInRange_outOfRange() async throws {
        let result = AngleTestResult(actualAngle: 30.0, userAngle: 28.0, pocketType: "side")
        try await repo.save(result)

        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let farFuture = Calendar.current.date(byAdding: .day, value: 2, to: Date())!

        let results = try await repo.fetchInRange(from: future, to: farFuture)
        XCTAssertTrue(results.isEmpty)
    }

    func test_deleteAll() async throws {
        let r1 = AngleTestResult(actualAngle: 30.0, userAngle: 28.0, pocketType: "corner")
        let r2 = AngleTestResult(actualAngle: 45.0, userAngle: 43.0, pocketType: "side")
        try await repo.save(r1)
        try await repo.save(r2)

        var all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 2)

        try await repo.deleteAll()
        all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_deleteAll_empty_noError() async throws {
        try await repo.deleteAll()
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }
}
