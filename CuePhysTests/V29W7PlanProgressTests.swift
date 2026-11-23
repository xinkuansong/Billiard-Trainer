import XCTest
import SwiftData
@testable import QiuJi

/// 问题集合 v29 W7：`UserActivePlan.currentWeek/currentDay` 按完成推进（D-v29-3）。
///
/// 覆盖完成标准 3 的六类场景：正常进位、跨周进位、计划末尾封顶、自由训练不推进、
/// 他计划 session 不推进、手动跳过 / 回退。官方计划的周 / 天结构直接读 Bundle 里的
/// `Resources/Plans/*.json`（真实内容，不用 stub），自定义计划读 `CustomPlan.sessionsPerWeek`。
@MainActor
final class V29W7PlanProgressTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    /// 官方计划真源：`plan_beginner` = 8 周 × 每周 3 天（下面 setUp 里实测断言）。
    private let officialPlanId = "plan_beginner"
    private var officialWeeks = 0
    private var officialDaysInWeek1 = 0

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext

        guard let plan = PlanContentService.decodePlanFromBundle(id: officialPlanId) else {
            XCTFail("Bundle 内缺少 \(officialPlanId).json，无法验证官方计划推进")
            return
        }
        officialWeeks = plan.weeks.count
        officialDaysInWeek1 = plan.weeks.first?.sessions.count ?? 0
        XCTAssertGreaterThan(officialWeeks, 1, "该计划需多于 1 周才能验证跨周进位")
        XCTAssertGreaterThan(officialDaysInWeek1, 1, "该计划第 1 周需多于 1 天才能验证日内进位")
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func activateOfficialPlan(week: Int = 1, day: Int = 1) -> UserActivePlan {
        let active = UserActivePlan(planId: officialPlanId)
        active.currentWeek = week
        active.currentDay = day
        context.insert(active)
        try? context.save()
        return active
    }

    private func activateCustomPlan(sessionsPerWeek: Int, week: Int = 1, day: Int = 1) -> UserActivePlan {
        let plan = CustomPlan(name: "自定义测试计划", sessionsPerWeek: sessionsPerWeek)
        context.insert(plan)
        let active = UserActivePlan(planId: plan.id.uuidString, isCustom: true)
        active.currentWeek = week
        active.currentDay = day
        context.insert(active)
        try? context.save()
        return active
    }

    /// 落一条训练记录（planId 为 nil 即自由训练）。
    @discardableResult
    private func saveSession(planId: String?) throws -> TrainingSession {
        let session = TrainingSession(kind: TrainingSessionKind.drill)
        session.planId = planId
        context.insert(session)
        try context.save()
        return session
    }

    // MARK: - 场景 1：正常进位（同周内 day + 1）

    func test_planSession_advancesDayWithinWeek() throws {
        let active = activateOfficialPlan(week: 1, day: 1)
        let session = try saveSession(planId: officialPlanId)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertEqual(outcome, .advanced(PlanPosition(week: 1, day: 2)))
        XCTAssertEqual(active.currentWeek, 1)
        XCTAssertEqual(active.currentDay, 2)
    }

    // MARK: - 场景 2：跨周进位（本周最后一天 → 下周第 1 天）

    func test_planSession_atLastDayOfWeek_advancesToNextWeekDayOne() throws {
        let active = activateOfficialPlan(week: 1, day: officialDaysInWeek1)
        let session = try saveSession(planId: officialPlanId)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertEqual(outcome, .advanced(PlanPosition(week: 2, day: 1)))
        XCTAssertEqual(active.currentWeek, 2)
        XCTAssertEqual(active.currentDay, 1)
    }

    // MARK: - 场景 3：计划末尾封顶（停在最后一天，游标不动）

    func test_planSession_atFinalDay_staysAtFinalDay() throws {
        guard let plan = PlanContentService.decodePlanFromBundle(id: officialPlanId),
              let lastWeek = plan.weeks.max(by: { $0.weekNumber < $1.weekNumber }) else {
            return XCTFail("无法读取官方计划末周")
        }
        let lastDay = lastWeek.sessions.count
        let active = activateOfficialPlan(week: lastWeek.weekNumber, day: lastDay)
        let session = try saveSession(planId: officialPlanId)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertEqual(outcome, .reachedEnd(PlanPosition(week: lastWeek.weekNumber, day: lastDay)))
        XCTAssertEqual(active.currentWeek, lastWeek.weekNumber)
        XCTAssertEqual(active.currentDay, lastDay)
    }

    // MARK: - 场景 4：自由训练（planId = nil）不推进

    func test_freeTrainingSession_doesNotAdvance() throws {
        let active = activateOfficialPlan(week: 2, day: 2)
        let session = try saveSession(planId: nil)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertNil(outcome)
        XCTAssertEqual(active.currentWeek, 2)
        XCTAssertEqual(active.currentDay, 2)
    }

    // MARK: - 场景 5：他计划的 session 不推进

    func test_sessionOfAnotherPlan_doesNotAdvance() throws {
        let active = activateOfficialPlan(week: 1, day: 1)
        let session = try saveSession(planId: "plan_accuracy")

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertNil(outcome)
        XCTAssertEqual(active.currentWeek, 1)
        XCTAssertEqual(active.currentDay, 1)
    }

    // MARK: - 场景 6：手动跳过 / 回退

    func test_skipCurrentDay_advancesWithoutAnySession() throws {
        let active = activateOfficialPlan(week: 1, day: 1)

        let outcome = try PlanProgressService.skipCurrentDay(context: context)

        XCTAssertEqual(outcome, .advanced(PlanPosition(week: 1, day: 2)))
        XCTAssertEqual(active.currentDay, 2)
        XCTAssertTrue(
            try context.fetch(FetchDescriptor<TrainingSession>()).isEmpty,
            "跳过不得伪造训练记录"
        )
    }

    func test_rollbackCurrentDay_withinWeek() throws {
        let active = activateOfficialPlan(week: 2, day: 3)

        let position = try PlanProgressService.rollbackCurrentDay(context: context)

        XCTAssertEqual(position, PlanPosition(week: 2, day: 2))
        XCTAssertEqual(active.currentWeek, 2)
        XCTAssertEqual(active.currentDay, 2)
    }

    func test_rollbackCurrentDay_crossesToPreviousWeekLastDay() throws {
        let active = activateOfficialPlan(week: 3, day: 1)

        let position = try PlanProgressService.rollbackCurrentDay(context: context)

        let daysInWeek2 = PlanContentService.decodePlanFromBundle(id: officialPlanId)?
            .weeks.first { $0.weekNumber == 2 }?.sessions.count
        XCTAssertEqual(daysInWeek2, officialDaysInWeek1, "本计划各周天数一致，作为回退落点的前提")
        XCTAssertEqual(position, PlanPosition(week: 2, day: officialDaysInWeek1))
        XCTAssertEqual(active.currentWeek, 2)
        XCTAssertEqual(active.currentDay, officialDaysInWeek1)
    }

    func test_rollbackCurrentDay_atFirstDay_isNoOp() throws {
        let active = activateOfficialPlan(week: 1, day: 1)

        let position = try PlanProgressService.rollbackCurrentDay(context: context)

        XCTAssertNil(position)
        XCTAssertEqual(active.currentWeek, 1)
        XCTAssertEqual(active.currentDay, 1)
    }

    // MARK: - 自定义计划（无周结构，按 sessionsPerWeek 天/周无限循环）

    func test_customPlanSession_advancesAndCrossesWeek() throws {
        let active = activateCustomPlan(sessionsPerWeek: 2, week: 1, day: 2)
        let session = try saveSession(planId: active.planId)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertEqual(outcome, .advanced(PlanPosition(week: 2, day: 1)))
        XCTAssertEqual(active.currentWeek, 2)
        XCTAssertEqual(active.currentDay, 1)
    }

    func test_customPlan_hasNoEnd() throws {
        let active = activateCustomPlan(sessionsPerWeek: 1, week: 99, day: 1)
        let session = try saveSession(planId: active.planId)

        let outcome = try PlanProgressService.advanceAfterPlanSession(session, context: context)

        XCTAssertEqual(outcome, .advanced(PlanPosition(week: 100, day: 1)))
    }

    // MARK: - 训练首页「今日安排」随游标变化（完成标准 3 的读取侧）

    func test_trainingHome_todaySchedule_followsCursor() async throws {
        let active = activateOfficialPlan(week: 2, day: 2)
        let curriculum = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: officialPlanId))
        let lesson = try XCTUnwrap(curriculum.stages.first { $0.order == 2 }?.lessons.first { $0.order == 2 })
        active.currentLessonId = lesson.id
        let viewModel = TrainingHomeViewModel()

        await viewModel.load(context: context)
        XCTAssertEqual(viewModel.todaySession?.weekNumber, 2)
        XCTAssertEqual(viewModel.todaySession?.dayNumber, 2)
        XCTAssertTrue(viewModel.canRollbackDay)

        // v54/v57: only completed, advance-eligible scheduled lessons move the stable cursor.
        let result = try TodayTrainingScheduleService(context: context).addOfficialLessons(
            plan: curriculum, lessonIDs: [lesson.id], activePlan: active
        )
        let first = try XCTUnwrap(result.first)
        let item: TodayScheduleItem
        switch first {
        case .added(let added), .alreadyPresent(let added): item = added
        }
        item.state = TodayScheduleItemState.completed
        _ = try PlanProgressService.settleCompletedScheduleItem(item, context: context)
        try context.save()
        await viewModel.load(context: context)
        XCTAssertNil(viewModel.progressError)
        XCTAssertEqual(viewModel.todaySession?.weekNumber, 2)
        XCTAssertEqual(viewModel.todaySession?.dayNumber, 3)

        // 「今日安排」的动作表也要跟着换成新那天的内容
        guard let plan = PlanContentService.decodePlanFromBundle(id: officialPlanId),
              let day3 = plan.weeks.first(where: { $0.weekNumber == 2 })?
                  .sessions.first(where: { $0.dayNumber == 3 }) else {
            return XCTFail("无法读取第 2 周第 3 天")
        }
        let expectedDrillIds = day3.phases.flatMap { $0.drills.map(\.drillId) }
        XCTAssertEqual(viewModel.todaySession?.drills.map(\.drillId), expectedDrillIds)
    }

    func test_trainingHome_atFirstDay_cannotRollback() async throws {
        let active = activateOfficialPlan(week: 1, day: 1)
        active.currentLessonId = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: officialPlanId)?.lessons.first?.id)
        let viewModel = TrainingHomeViewModel()

        await viewModel.load(context: context)

        XCTAssertFalse(viewModel.canRollbackDay)
    }

    // MARK: - 规则纯函数（不依赖 Bundle / SwiftData 的边界断言）

    func test_rules_boundedSchedule() {
        let schedule = PlanSchedule(daysPerWeek: [2, 3], unboundedDaysPerWeek: nil)

        XCTAssertEqual(PlanProgressRules.next(after: PlanPosition(week: 1, day: 1), in: schedule),
                       .advanced(PlanPosition(week: 1, day: 2)))
        XCTAssertEqual(PlanProgressRules.next(after: PlanPosition(week: 1, day: 2), in: schedule),
                       .advanced(PlanPosition(week: 2, day: 1)))
        XCTAssertEqual(PlanProgressRules.next(after: PlanPosition(week: 2, day: 3), in: schedule),
                       .reachedEnd(PlanPosition(week: 2, day: 3)))
        // 游标越界（数据异常）不做猜测式修正
        XCTAssertEqual(PlanProgressRules.next(after: PlanPosition(week: 9, day: 1), in: schedule),
                       .reachedEnd(PlanPosition(week: 9, day: 1)))

        XCTAssertEqual(PlanProgressRules.previous(before: PlanPosition(week: 2, day: 1), in: schedule),
                       PlanPosition(week: 1, day: 2))
        XCTAssertNil(PlanProgressRules.previous(before: PlanPosition(week: 1, day: 1), in: schedule))
    }

    func test_officialSchedule_matchesPlanJSON() {
        guard let plan = PlanContentService.decodePlanFromBundle(id: officialPlanId) else {
            return XCTFail("无法读取官方计划")
        }
        let schedule = PlanSchedule.official(plan)

        XCTAssertEqual(schedule.totalWeeks, plan.weeks.count)
        for week in plan.weeks {
            XCTAssertEqual(schedule.days(inWeek: week.weekNumber), week.sessions.count)
        }
        XCTAssertNil(schedule.days(inWeek: plan.weeks.count + 1))
    }
}
