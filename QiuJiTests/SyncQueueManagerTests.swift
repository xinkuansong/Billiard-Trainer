import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class SyncQueueManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func test_pendingCount_initiallyZero() {
        let count = SyncQueueManager.shared.pendingCount()
        XCTAssertEqual(count, 0)
    }

    func test_enqueue_incrementsCount() {
        SyncQueueManager.shared.enqueue(
            entityType: "TrainingSession", entityId: UUID(), operation: "create"
        )
        let count = SyncQueueManager.shared.pendingCount()
        XCTAssertEqual(count, 1)
    }

    func test_enqueue_multiple() {
        SyncQueueManager.shared.enqueue(
            entityType: "TrainingSession", entityId: UUID(), operation: "create"
        )
        SyncQueueManager.shared.enqueue(
            entityType: "AngleTestResult", entityId: UUID(), operation: "create"
        )
        SyncQueueManager.shared.enqueue(
            entityType: "TrainingSession", entityId: UUID(), operation: "update"
        )
        let count = SyncQueueManager.shared.pendingCount()
        XCTAssertEqual(count, 3)
    }

    func test_enqueue_storesCorrectData() throws {
        let entityId = UUID()
        SyncQueueManager.shared.enqueue(
            entityType: "TrainingSession", entityId: entityId, operation: "create"
        )

        let descriptor = FetchDescriptor<SyncPendingItem>()
        let items = try context.fetch(descriptor)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.entityType, "TrainingSession")
        XCTAssertEqual(items.first?.entityId, entityId)
        XCTAssertEqual(items.first?.operation, "create")
    }
}
