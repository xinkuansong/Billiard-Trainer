import XCTest
import SwiftData
@testable import QiuJi

/// SC07 service boundaries only, using real Bundle lessons and an isolated in-memory store.
/// Direct completed-state assignment is a settlement input, not UI dose completion evidence.
/// Does not establish disk/process restart, sync, or physical training correctness.
@MainActor
final class ScheduleBoundaryDiagnosticTests: XCTestCase {
    private struct Stop: Error { let reason: String }
    private struct Fixture {
        let container: ModelContainer // Retain the store for every model/context lifetime.
        let context: ModelContext
        let plan: OfficialPlan
        let active: UserActivePlan
        let service: TodayTrainingScheduleService
    }

    func testFrozenPreviewAfterReorderAndGapCompletionCannotSkipCurrentLesson() throws {
        let f = try fixture(currentOrdinal: 4)
        let results = try f.service.addOfficialLessons(plan: f.plan,
            lessonIDs: [f.plan.lessons[4].id, f.plan.lessons[6].id], activePlan: f.active)
        try require(results.count == 2, "Expected two newly queued official lessons")
        let current = try newItem(results, lessonID: f.plan.lessons[4].id)
        let preview = try newItem(results, lessonID: f.plan.lessons[6].id)
        try require(current.progressRole == "advanceEligible" && preview.progressRole == "preview", "Expected literal frozen roles for selection 4 + 6")
        let schedule = try XCTUnwrap(current.schedule)
        try require(preview.schedule?.id == schedule.id, "Both items must belong to the same schedule")
        try f.service.reorderUnfinished([preview.id, current.id], in: schedule)
        try require(schedule.items.sorted { $0.orderIndex < $1.orderIndex }.map(\.id) == [preview.id, current.id], "Mixed official items were not reordered")
        try require(current.progressRole == "advanceEligible" && preview.progressRole == "preview", "Reorder changed frozen official roles")
        try cursor(f, is: 4)

        preview.state = TodayScheduleItemState.completed
        try f.context.save()
        try require(try PlanProgressService.settleCompletedScheduleItem(preview, context: f.context) == .none, "Completed preview must not advance")
        try cursor(f, is: 4)
        current.state = TodayScheduleItemState.completed
        try f.context.save()
        try require(try PlanProgressService.settleCompletedScheduleItem(current, context: f.context) == .advanced(1), "Completing ordinal 4 must advance only to 5")
        try cursor(f, is: 5)

        let gap = try newItem(f.service.addOfficialLessons(plan: f.plan,
            lessonIDs: [f.plan.lessons[5].id], activePlan: f.active), lessonID: f.plan.lessons[5].id)
        try require(gap.progressRole == "advanceEligible", "New current gap must be eligible")
        gap.state = TodayScheduleItemState.completed
        try f.context.save()
        try require(try PlanProgressService.settleCompletedScheduleItem(gap, context: f.context) == .advanced(1), "Completed frozen preview 6 must NOT make gap completion advance twice")
        try cursor(f, is: 6)
        try require(preview.progressRole == "preview", "Filling the gap must not upgrade the old frozen preview")
        try require(try PlanProgressService.settleCompletedScheduleItem(preview, context: f.context) == .none, "Re-callback on old preview at the cursor must still not advance")
        try cursor(f, is: 6)

        let fresh = try newItem(f.service.addOfficialLessons(plan: f.plan,
            lessonIDs: [f.plan.lessons[6].id], activePlan: f.active), lessonID: f.plan.lessons[6].id)
        try require(fresh.id != preview.id && fresh.progressRole == "advanceEligible", "Explicitly requeue current lesson as a distinct eligible item")
        try require(schedule.items.filter { $0.lessonId == f.plan.lessons[6].id }.count == 2, "Old preview evidence must remain alongside new item")
        fresh.state = TodayScheduleItemState.completed
        try f.context.save()
        try require(try PlanProgressService.settleCompletedScheduleItem(fresh, context: f.context) == .advanced(1), "Only new eligible completion may advance to ordinal 7")
        try cursor(f, is: 7)
    }

    func testReviewCannotRollbackAndOnlyCompletedEligibleStateAdvances() throws {
        // Each row has its own store. Never revive an abandoned item to manufacture completion.
        let rows: [(state: String, expectedOrdinal: Int, expectedEffect: PlanProgressEffect)] = [
            ("pending", 6, .none), ("inProgress", 6, .none),
            ("abandoned", 6, .none), ("completed", 7, .advanced(1))
        ]
        for row in rows {
            let f = try fixture(currentOrdinal: 6)
            let results = try f.service.addOfficialLessons(plan: f.plan,
                lessonIDs: [f.plan.lessons[1].id, f.plan.lessons[6].id], activePlan: f.active)
            try require(results.count == 2, "Expected review and current item")
            let review = try newItem(results, lessonID: f.plan.lessons[1].id)
            let eligible = try newItem(results, lessonID: f.plan.lessons[6].id)
            try require(review.progressRole == "review" && eligible.progressRole == "advanceEligible", "Role precondition failed")
            try cursor(f, is: 6) // Merely adding these lessons must not move the cursor.
            review.state = TodayScheduleItemState.completed
            try f.context.save()
            try require(try PlanProgressService.settleCompletedScheduleItem(review, context: f.context) == .none, "Completing historical review cannot roll back/advance the cursor")
            try cursor(f, is: 6)
            switch row.state {
            case "pending": break
            case "inProgress": try f.service.markStarted(eligible)
            case "abandoned":
                try f.service.markStarted(eligible)
                try f.service.abandon(eligible)
            case "completed":
                try f.service.markStarted(eligible)
                eligible.state = TodayScheduleItemState.completed
                try f.context.save()
            default: throw Stop(reason: "Unknown explicit table state")
            }
            try require(eligible.state == row.state, "Actual state differs from the independent test row")
            try require(try PlanProgressService.settleCompletedScheduleItem(eligible, context: f.context) == row.expectedEffect,
                        "Unexpected settlement effect for " + row.state)
            try cursor(f, is: row.expectedOrdinal)
            try require(try PlanProgressService.settleCompletedScheduleItem(review, context: f.context) == .none,
                        "Review re-callback must remain neutral after " + row.state)
            try cursor(f, is: row.expectedOrdinal)
        }
    }

    private func fixture(currentOrdinal: Int) throws -> Fixture {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        guard let plan = PlanContentService.decodePlanFromBundle(id: "plan_beginner") else {
            throw Stop(reason: "Real plan_beginner Bundle content missing")
        }
        try require(plan.lessons.count > 7, "Need the real ordered lessons through ordinal 7")
        let active = UserActivePlan(planId: plan.id, ownerKey: "guest:sc07-boundary-" + UUID().uuidString)
        active.currentLessonId = plan.lessons[currentOrdinal].id
        active.status = "active"
        guard let stage = plan.stages.first(where: { $0.lessons.contains { $0.id == active.currentLessonId } }) else {
            throw Stop(reason: "Current real lesson is not in a stage")
        }
        active.currentWeek = stage.order
        active.currentDay = plan.lessons[currentOrdinal].order
        context.insert(active)
        try context.save()
        let service = TodayTrainingScheduleService(context: context,
            now: { Date(timeIntervalSince1970: 1_788_393_600) }, timeZone: TimeZone(secondsFromGMT: 0)!)
        return Fixture(container: container, context: context, plan: plan, active: active, service: service)
    }

    private func newItem(_ results: [TodayTrainingScheduleService.AddResult], lessonID: String) throws -> TodayScheduleItem {
        var found: [TodayScheduleItem] = []
        for result in results {
            switch result {
            case .added(let item): if item.lessonId == lessonID { found.append(item) }
            case .alreadyPresent: throw Stop(reason: "Expected only newly added items, not a skipped duplicate")
            }
        }
        try require(found.count == 1, "Expected exactly one new item for the literal lesson")
        guard let item = found.first else { throw Stop(reason: "Missing item") }
        return item
    }

    private func cursor(_ f: Fixture, is ordinal: Int) throws {
        // Expected ordinal is literal in the test, never calculated using production settle.
        try require(f.active.currentLessonId == f.plan.lessons[ordinal].id, "Unexpected currentLessonId; expected ordinal " + String(ordinal))
        try require(f.active.status == "active" && f.active.completedAt == nil, "Mid-plan sample must remain active")
        try f.context.save()
        let independent = ModelContext(f.container)
        let records = try PlanProgressService.officialRecords(ownerKey: f.active.ownerKey, context: independent)
        try require(records.count == 1 && records.first?.currentLessonId == f.plan.lessons[ordinal].id,
                    "Saved in-memory context disagrees with expected cursor")
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else { XCTFail(message); throw Stop(reason: message) }
    }
}
