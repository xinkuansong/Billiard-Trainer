import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class TrainingUtilitiesTests: XCTestCase {
    func testManualCreatesOneOwnedSessionAndQueueWithoutScoresOrProgress() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let owner = CurrentOwnerContext.shared.ownerKey
        try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner, date: Date(), minutes: 45,
                                            ballType: "chinese8", content: " 定杆练习 ", note: "出杆保持平稳")
        let reader = ModelContext(container)
        let session = try XCTUnwrap(try reader.fetch(FetchDescriptor<TrainingSession>()).first)
        XCTAssertEqual(session.ownerKey, owner)
        XCTAssertEqual(session.sourceTitleSnapshot, "定杆练习")
        XCTAssertEqual(session.totalDurationMinutes, 45)
        XCTAssertTrue(session.isManualTraining)
        XCTAssertTrue(session.drillEntries.isEmpty)
        XCTAssertNil(session.planId)
        XCTAssertNil(session.scheduleItemId)
        XCTAssertNil(session.progressRole)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<SyncPendingItem>()).map(\.operation), [SyncOperation.create])
        XCTAssertEqual(TrainingGoalMetrics.daysTrained([session], since: Calendar.current.startOfDay(for: Date()), calendar: .current), 1)
        let source = try JSONDecoder().decode(ManualTrainingSource.self, from: XCTUnwrap(session.sourcePayloadSnapshot))
        XCTAssertEqual(source.day, Calendar.current.component(.day, from: Date()))
    }

    func testInvalidManualAndOwnerMismatchLeaveNoRows() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        for (owner, minutes, title) in [(CurrentOwnerContext.shared.ownerKey, 0, "练球"), (CurrentOwnerContext.shared.ownerKey, 30, "  "), ("guest:other", 30, "练球")] {
            XCTAssertThrowsError(try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner,
                date: Date(), minutes: minutes, ballType: "chinese8", content: title, note: ""))
        }
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<TrainingSession>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)
    }

    func testManualEditPreservesIdentityAndDoesNotCreateSecondSession() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let owner = CurrentOwnerContext.shared.ownerKey
        try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner, date: Date(), minutes: 30,
                                            ballType: "chinese8", content: "定杆", note: "")
        let session = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<TrainingSession>()).first)
        try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner, existing: session, date: Date(), minutes: 60,
                                            ballType: "nineBall", content: "走位", note: "先看线路")
        let rows = try ModelContext(container).fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, session.id)
        XCTAssertEqual(rows.first?.totalDurationMinutes, 60)
    }

    func testFailedSaveAndRetryAreAtomicAndIdempotent() throws {
        enum Expected: Error { case diskFull }
        let container = ModelContainerFactory.makeInMemoryContainer()
        let owner = CurrentOwnerContext.shared.ownerKey
        let id = UUID()
        XCTAssertThrowsError(try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner,
            date: Date(), minutes: 30, ballType: "chinese8", content: "直线球", note: "", recordID: id,
            save: { _ in throw Expected.diskFull }))
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<TrainingSession>()).isEmpty)
        XCTAssertTrue(try ModelContext(container).fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)
        for _ in 0..<2 {
            try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: owner,
                date: Date(), minutes: 30, ballType: "chinese8", content: "直线球", note: "", recordID: id)
        }
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<TrainingSession>()), 1)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<SyncPendingItem>()), 1)
    }

    func testManualStatisticsAndSyncPayloadDoNotInventScores() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        try TrainingUtilityStore.saveManual(context: container.mainContext, ownerKey: CurrentOwnerContext.shared.ownerKey,
            date: Date(), minutes: 30, ballType: "chinese8", content: "定杆", note: "注意停顿")
        let session = try XCTUnwrap(try ModelContext(container).fetch(FetchDescriptor<TrainingSession>()).first)
        let vm = StatisticsViewModel()
        vm.sessions = [session]
        XCTAssertEqual(vm.totalDurationMinutes, 30)
        XCTAssertFalse(vm.hasDrillScores)
        XCTAssertTrue(vm.categorySuccessRates.isEmpty)
        XCTAssertTrue(vm.trainingDaysBreakdown.isEmpty)
        let dto = TrainingSessionDTO(from: session)
        let decoded = try JSONDecoder().decode(TrainingSessionDTO.self, from: JSONEncoder().encode(dto))
        XCTAssertEqual(decoded.sourceKind, "manualTraining")
        XCTAssertEqual(decoded.sourceTitleSnapshot, "定杆")
        XCTAssertEqual(decoded.sourcePayloadSnapshot, session.sourcePayloadSnapshot)
    }

    func testNoteFailureRestoresTextAndRetryQueuesUpdate() throws {
        enum Expected: Error { case diskFull }
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let session = TrainingSession(ownerKey: CurrentOwnerContext.shared.ownerKey)
        session.note = "原心得"
        context.insert(session)
        try context.save()
        XCTAssertThrowsError(try TrainingUtilityStore.saveNote(context: context, session: session, entryID: nil,
            text: "新心得", isPremium: false, save: { _ in throw Expected.diskFull }))
        XCTAssertEqual(session.note, "原心得")
        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)
        try TrainingUtilityStore.saveNote(context: context, session: session, entryID: nil, text: "新心得", isPremium: false)
        XCTAssertEqual(session.note, "新心得")
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncPendingItem>()).count, 1)
        session.date = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        XCTAssertThrowsError(try TrainingUtilityStore.saveNote(context: context, session: session, entryID: nil, text: "超期", isPremium: false))
        XCTAssertEqual(session.note, "新心得")
    }

    func testReminderWeekdaysAndPermissionHandling() async {
        let center = UtilityReminderMock()
        let scheduler = TrainingReminderScheduler(center: center)
        let empty = await scheduler.enable(at: Date(), weekdays: [])
        XCTAssertEqual(empty, .failed("请至少选择一天"))
        XCTAssertEqual(center.schedules, 0)
        let result = await scheduler.enable(at: Date(), weekdays: [2, 4, 6])
        XCTAssertEqual(result, .scheduled)
        XCTAssertEqual(center.days, [2, 4, 6])
        center.status = .denied
        let denied = await scheduler.enable(at: Date(), weekdays: [1])
        XCTAssertEqual(denied, .permissionDenied)
        XCTAssertEqual(center.schedules, 1)
        scheduler.disable()
        XCTAssertTrue(center.cancelled)
    }
}

@MainActor
private final class UtilityReminderMock: TrainingReminderCenter {
    var status: TrainingReminderAuthorization = .allowed
    var days: Set<Int> = []
    var schedules = 0
    var cancelled = false
    func authorization() async -> TrainingReminderAuthorization { status }
    func requestAuthorization() async throws -> Bool { true }
    func schedule(hour: Int, minute: Int) async throws { schedules += 1 }
    func schedule(hour: Int, minute: Int, weekdays: Set<Int>) async throws { schedules += 1; days = weekdays }
    func cancel() { cancelled = true }
}
