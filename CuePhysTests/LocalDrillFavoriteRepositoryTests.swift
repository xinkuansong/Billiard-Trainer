import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class LocalDrillFavoriteRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repo: LocalDrillFavoriteRepository!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        repo = LocalDrillFavoriteRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        container = nil
        context = nil
        super.tearDown()
    }

    func test_add_and_fetchAll() async throws {
        try await repo.add(drillId: "drill_c001")

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.drillId, "drill_c001")
    }

    func test_fetchAll_empty() async throws {
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_isFavorited_true() async throws {
        try await repo.add(drillId: "drill_c001")
        let result = try await repo.isFavorited(drillId: "drill_c001")
        XCTAssertTrue(result)
    }

    func test_isFavorited_false() async throws {
        let result = try await repo.isFavorited(drillId: "drill_c999")
        XCTAssertFalse(result)
    }

    func test_remove() async throws {
        try await repo.add(drillId: "drill_c001")
        try await repo.remove(drillId: "drill_c001")

        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)

        let stillFav = try await repo.isFavorited(drillId: "drill_c001")
        XCTAssertFalse(stillFav)
    }

    func test_add_duplicate_ignored() async throws {
        try await repo.add(drillId: "drill_c001")
        try await repo.add(drillId: "drill_c001")

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func test_remove_nonexistent_noError() async throws {
        try await repo.remove(drillId: "drill_c999")
        let all = try await repo.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    func test_add_multiple_favorites() async throws {
        try await repo.add(drillId: "drill_c001")
        try await repo.add(drillId: "drill_c002")
        try await repo.add(drillId: "drill_c003")

        let all = try await repo.fetchAll()
        XCTAssertEqual(all.count, 3)
    }
}
