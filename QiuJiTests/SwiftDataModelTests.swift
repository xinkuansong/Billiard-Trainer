import XCTest
import SwiftData
@testable import QiuJi

final class SwiftDataModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - TrainingSession

    @MainActor
    func test_TrainingSession_defaultValues() {
        let session = TrainingSession()
        XCTAssertEqual(session.ballType, "chinese8")
        XCTAssertEqual(session.totalDurationMinutes, 0)
        XCTAssertEqual(session.note, "")
        XCTAssertNil(session.planId)
        XCTAssertTrue(session.drillEntries.isEmpty)
    }

    @MainActor
    func test_TrainingSession_customBallType() {
        let session = TrainingSession(ballType: "snooker")
        XCTAssertEqual(session.ballType, "snooker")
    }

    // MARK: - DrillEntry

    @MainActor
    func test_DrillEntry_successRate_noSets() {
        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "测试动作")
        XCTAssertEqual(entry.successRate, 0)
    }

    @MainActor
    func test_DrillEntry_successRate_withSets() {
        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "测试动作")
        let set1 = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7)
        let set2 = DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 8)
        entry.sets = [set1, set2]
        XCTAssertEqual(entry.successRate, 0.75, accuracy: 0.001)
    }

    // MARK: - DrillSet

    @MainActor
    func test_DrillSet_defaultMadeBalls() {
        let set = DrillSet(setNumber: 1, targetBalls: 10)
        XCTAssertEqual(set.madeBalls, 0)
        XCTAssertEqual(set.setNumber, 1)
        XCTAssertEqual(set.targetBalls, 10)
    }

    // MARK: - Cascade Delete

    @MainActor
    func test_cascade_delete_session_removes_entries_and_sets() throws {
        let session = TrainingSession()
        context.insert(session)

        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
        entry.session = session
        session.drillEntries.append(entry)
        context.insert(entry)

        let set1 = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 5)
        set1.entry = entry
        entry.sets.append(set1)
        context.insert(set1)

        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrainingSession>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DrillEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DrillSet>()), 1)

        context.delete(session)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TrainingSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DrillEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DrillSet>()), 0)
    }

    // MARK: - AngleTestResult

    @MainActor
    func test_AngleTestResult_errorComputed() {
        let result = AngleTestResult(actualAngle: 45.0, userAngle: 42.0, pocketType: "corner")
        XCTAssertEqual(result.error, 3.0, accuracy: 0.001)
    }

    @MainActor
    func test_AngleTestResult_errorSymmetric() {
        let result = AngleTestResult(actualAngle: 30.0, userAngle: 35.0, pocketType: "side")
        XCTAssertEqual(result.error, 5.0, accuracy: 0.001)
    }

    // MARK: - DrillFavorite

    @MainActor
    func test_DrillFavorite_init() {
        let fav = DrillFavorite(drillId: "drill_c001")
        XCTAssertEqual(fav.drillId, "drill_c001")
        XCTAssertNotNil(fav.addedAt)
    }

    // MARK: - UserActivePlan

    @MainActor
    func test_UserActivePlan_defaults() {
        let plan = UserActivePlan(planId: "plan_beginner")
        XCTAssertEqual(plan.planId, "plan_beginner")
        XCTAssertEqual(plan.currentWeek, 1)
        XCTAssertEqual(plan.currentDay, 1)
    }

    // MARK: - SyncPendingItem

    @MainActor
    func test_SyncPendingItem_init() {
        let entityId = UUID()
        let item = SyncPendingItem(entityType: "TrainingSession", entityId: entityId, operation: "create")
        XCTAssertEqual(item.entityType, "TrainingSession")
        XCTAssertEqual(item.entityId, entityId)
        XCTAssertEqual(item.operation, "create")
    }
}
