import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V54ScheduleDomainTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let owner = "guest:v54-domain"
    private let planID = "plan_beginner"

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() {
        context = nil; container = nil
        super.tearDown()
    }

    func test_classification_matchesAllFrozenSelectionCases() {
        let cases: [(Int?, Set<Int>, [Int: String])] = [
            (4, [1, 4], [1: "review", 4: "advanceEligible"]),
            (4, [4, 5], [4: "advanceEligible", 5: "advanceEligible"]),
            (4, [4, 6], [4: "advanceEligible", 6: "preview"]),
            (4, [6], [6: "preview"]),
            (4, [4], [4: "advanceEligible"]),
            (8, [8], [8: "advanceEligible"]),
            (nil, [2], [2: "review"]),
        ]
        for (current, selected, expected) in cases {
            XCTAssertEqual(
                OfficialLessonRoleRules.classify(
                    currentOrdinal: current, selectedOrdinals: selected, lessonCount: 9
                ),
                expected
            )
        }
    }

    func test_progressRules_reverseCompletion_switchAndTwentyReplays() {
        let items = [
            ProgressSettlementInput(ordinal: 4, role: "advanceEligible", isCompleted: true),
            ProgressSettlementInput(ordinal: 5, role: "advanceEligible", isCompleted: true),
        ]
        XCTAssertEqual(
            OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: planID, currentOrdinal: 4,
                lessonCount: 9, items: items
            ),
            ProgressSettlementResult(currentOrdinal: 6, isCompleted: false, advancedCount: 2)
        )
        XCTAssertEqual(
            OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: "plan_cueball", currentOrdinal: 4,
                lessonCount: 9, items: items
            ).advancedCount,
            0
        )
        var current: Int? = 4
        for _ in 0..<20 {
            current = OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: planID, currentOrdinal: current,
                lessonCount: 9, items: items
            ).currentOrdinal
        }
        XCTAssertEqual(current, 6)
    }

    func test_service_freezesRoles_deduplicatesUnfinished_andAllowsRepeatAfterCompletion() throws {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 4)
        let service = TodayTrainingScheduleService(
            context: context,
            now: { Date(timeIntervalSince1970: 1_788_393_600) },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let selected = Set([plan.lessons[4].id, plan.lessons[6].id])
        let first = try service.addOfficialLessons(plan: plan, lessonIDs: selected, activePlan: active)
        XCTAssertEqual(first.count, 2)
        let schedule = try XCTUnwrap(try service.today(ownerKey: owner, createIfNeeded: false))
        XCTAssertEqual(schedule.items.first(where: { $0.lessonId == plan.lessons[4].id })?.progressRole,
                       TodayScheduleProgressRole.advanceEligible)
        XCTAssertEqual(schedule.items.first(where: { $0.lessonId == plan.lessons[6].id })?.progressRole,
                       TodayScheduleProgressRole.preview)

        let second = try service.addOfficialLessons(plan: plan, lessonIDs: selected, activePlan: active)
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(schedule.items.count, 2, "unfinished source must deduplicate")

        let current = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[4].id })
        current.state = TodayScheduleItemState.completed
        current.completedAt = Date()
        try context.save()
        _ = try service.addOfficialLessons(
            plan: plan, lessonIDs: [plan.lessons[4].id], activePlan: active
        )
        XCTAssertEqual(schedule.items.filter { $0.lessonId == plan.lessons[4].id }.count, 2,
                       "completed source can be scheduled as a real repeat")
    }

    func test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay() throws {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 4)
        let service = TodayTrainingScheduleService(context: context)
        _ = try service.addOfficialLessons(
            plan: plan,
            lessonIDs: [plan.lessons[4].id, plan.lessons[5].id],
            activePlan: active
        )
        let schedule = try XCTUnwrap(try service.today(ownerKey: owner, createIfNeeded: false))
        let current = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[4].id })
        let next = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[5].id })

        next.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(next, context: context), .none)
        XCTAssertEqual(active.currentLessonId, plan.lessons[4].id)
        current.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(current, context: context),
                       .advanced(2))
        XCTAssertEqual(active.currentLessonId, plan.lessons[6].id)
        for _ in 0..<20 {
            XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(current, context: context), .none)
        }
        XCTAssertEqual(active.currentLessonId, plan.lessons[6].id)

        let finalActive = activePlan(plan: plan, ordinal: plan.lessons.count - 1,
                                     replacing: active)
        _ = try service.addOfficialLessons(
            plan: plan, lessonIDs: [plan.lessons.last!.id], activePlan: finalActive
        )
        let finalItem = try XCTUnwrap(schedule.items.last { $0.lessonId == plan.lessons.last!.id })
        finalItem.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(finalItem, context: context),
                       .completed)
        XCTAssertNil(finalActive.currentLessonId)
        XCTAssertEqual(finalActive.status, "completed")
        XCTAssertNotNil(finalActive.completedAt)
    }

    func test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted() throws {
        let service = TodayTrainingScheduleService(context: context)
        let first = try addedItem(service.addLibraryDrill(id: "drill_c001", title: "直线球",
                                                          ownerKey: owner))
        let second = try addedItem(service.addLibraryDrill(id: "drill_c002", title: "定杆",
                                                           ownerKey: owner))
        let frozen = first.progressRole
        let schedule = try XCTUnwrap(first.schedule)
        try service.reorderUnfinished([second.id, first.id], in: schedule)
        XCTAssertEqual(schedule.items.sorted { $0.orderIndex < $1.orderIndex }.map(\.id),
                       [second.id, first.id])
        XCTAssertEqual(first.progressRole, frozen)
        try service.markStarted(first)
        XCTAssertThrowsError(try service.removePending(first))
        try service.abandon(first)
        XCTAssertEqual(first.state, TodayScheduleItemState.abandoned)
    }

    func test_crossDayArchivesWithoutAutoCarry_thenCopiesFreshItems() throws {
        var clock = Date(timeIntervalSince1970: 1_788_393_600)
        let utc = TimeZone(secondsFromGMT: 0)!
        let service = TodayTrainingScheduleService(context: context, now: { clock }, timeZone: utc)
        let oldItem = try addedItem(service.addLibraryDrill(id: "drill_c010", title: "定杆",
                                                            ownerKey: owner))
        let yesterday = try XCTUnwrap(oldItem.schedule)

        clock = clock.addingTimeInterval(86_400)
        let today = try XCTUnwrap(try service.today(ownerKey: owner))
        XCTAssertNotNil(yesterday.archivedAt)
        XCTAssertTrue(today.items.isEmpty, "unfinished items must not auto-pile into a new day")
        XCTAssertEqual(try service.latestArchivedWithUnfinished(ownerKey: owner)?.id, yesterday.id)

        let copied = try service.carryForwardLatestUnfinished(
            ownerKey: owner, activePlan: nil, officialPlan: nil
        )
        XCTAssertEqual(copied.count, 1)
        XCTAssertEqual(today.items.count, 1)
        XCTAssertNotEqual(today.items[0].id, oldItem.id)
        XCTAssertEqual(today.items[0].payloadSnapshot, oldItem.payloadSnapshot)
        XCTAssertEqual(oldItem.state, TodayScheduleItemState.pending)
    }

    func test_timezoneBoundary_andEstimateAreDeterministic() {
        let instant = Date(timeIntervalSince1970: 1_788_393_600)
        XCTAssertNotEqual(
            TodayTrainingScheduleService.localDayKey(
                for: instant, timeZone: TimeZone(secondsFromGMT: 14 * 3600)!
            ),
            TodayTrainingScheduleService.localDayKey(
                for: instant, timeZone: TimeZone(secondsFromGMT: -10 * 3600)!
            )
        )
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 0, weeklyGoalDays: 4
        ), 3)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 5, weeklyGoalDays: 4
        ), 1)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 5, weeklyGoalDays: 3
        ), 2)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: nil, weeklyGoalDays: 4
        ), 0)
    }

    private func activePlan(
        plan: OfficialPlan,
        ordinal: Int,
        replacing old: UserActivePlan? = nil
    ) -> UserActivePlan {
        if let old { context.delete(old) }
        let active = UserActivePlan(planId: plan.id, ownerKey: owner)
        active.currentLessonId = plan.lessons[ordinal].id
        active.status = "active"
        if let stage = plan.stages.first(where: { $0.lessons.contains(where: { $0.id == active.currentLessonId }) }) {
            active.currentWeek = stage.order
            active.currentDay = plan.lessons[ordinal].order
        }
        context.insert(active)
        try? context.save()
        return active
    }

    private func addedItem(_ result: TodayTrainingScheduleService.AddResult) throws -> TodayScheduleItem {
        switch result {
        case .added(let item): return item
        case .alreadyPresent: throw XCTSkip("expected a newly added item")
        }
    }
}
