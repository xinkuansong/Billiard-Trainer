import Foundation
import SwiftData

// MARK: - Schedule Shape

/// 计划的周 / 天结构，是推进边界的唯一依据。
///
/// - 官方计划：来自 `Resources/Plans/<id>.json`，每周天数 = `weeks[].sessions.count`，
///   总周数有限（末尾封顶）。
/// - 自定义计划：`CustomPlan` 只有一张扁平动作表 + `sessionsPerWeek`，没有周结构，
///   故按 `sessionsPerWeek` 天/周无限循环（无末尾，不封顶）。
struct PlanSchedule: Equatable {
    /// 每周天数，index 0 = 第 1 周。仅有限周数的计划（官方计划）使用。
    let daysPerWeek: [Int]
    /// 非 nil 表示无固定周数：每周固定这么多天，可无限进位。
    let unboundedDaysPerWeek: Int?

    /// 有限计划的总周数；无固定周数时为 nil。
    var totalWeeks: Int? {
        unboundedDaysPerWeek == nil ? daysPerWeek.count : nil
    }

    /// 第 `week` 周的天数；超出计划范围时为 nil。
    func days(inWeek week: Int) -> Int? {
        guard week >= 1 else { return nil }
        if let unbounded = unboundedDaysPerWeek {
            return max(1, unbounded)
        }
        guard week <= daysPerWeek.count else { return nil }
        let days = daysPerWeek[week - 1]
        return days > 0 ? days : nil
    }

    static func official(_ plan: OfficialPlan) -> PlanSchedule {
        PlanSchedule(
            daysPerWeek: plan.weeks
                .sorted { $0.weekNumber < $1.weekNumber }
                .map { $0.sessions.count },
            unboundedDaysPerWeek: nil
        )
    }

    static func custom(sessionsPerWeek: Int) -> PlanSchedule {
        PlanSchedule(daysPerWeek: [], unboundedDaysPerWeek: max(1, sessionsPerWeek))
    }
}

// MARK: - Position & Rules

/// 计划游标。语义与 `UserActivePlan.currentWeek/currentDay` 及训练首页「今日安排」一致：
/// 指向**待完成**的那一天，不是已完成的那一天。
struct PlanPosition: Equatable {
    var week: Int
    var day: Int
}

/// 一次推进的结果。
enum PlanAdvanceOutcome: Equatable {
    /// 游标前移到新的周 / 天。
    case advanced(PlanPosition)
    /// 已在计划最后一天：封顶不再前移，游标保持不变（见 `PlanProgressRules` 文件头口径）。
    case reachedEnd(PlanPosition)
}

/// 推进规则（纯函数，不依赖 SwiftData / Bundle，便于逐条断言）。
///
/// 口径（D-v29-3「按完成推进，不按自然日」）：
/// 1. 完成一次计划训练 → `day + 1`；
/// 2. 已是本周最后一天 → `week + 1, day = 1`；
/// 3. 已是计划最后一周的最后一天 → **封顶**：游标停在该天不动（`reachedEnd`）。
///    选择「停在最后一天」而不是新增完成态字段，因为 schema 归 W3，本批不动模型；
///    停在最后一天时「今日安排」仍展示最后一天，可反复复训。
/// 4. 自定义计划无末尾（`unboundedDaysPerWeek`），永远走 1 / 2 两条。
/// 5. 游标越出计划范围（数据异常）时不做任何猜测式修正，按 `reachedEnd` 原样返回。
enum PlanProgressRules {

    static func next(after position: PlanPosition, in schedule: PlanSchedule) -> PlanAdvanceOutcome {
        guard let daysThisWeek = schedule.days(inWeek: position.week) else {
            return .reachedEnd(position)
        }
        if position.day < daysThisWeek {
            return .advanced(PlanPosition(week: position.week, day: position.day + 1))
        }
        if let totalWeeks = schedule.totalWeeks, position.week >= totalWeeks {
            return .reachedEnd(position)
        }
        return .advanced(PlanPosition(week: position.week + 1, day: 1))
    }

    /// 回退一天；已在第 1 周第 1 天时返回 nil（无可回退）。
    static func previous(before position: PlanPosition, in schedule: PlanSchedule) -> PlanPosition? {
        if position.day > 1 {
            return PlanPosition(week: position.week, day: position.day - 1)
        }
        guard position.week > 1, let daysPrevWeek = schedule.days(inWeek: position.week - 1) else {
            return nil
        }
        return PlanPosition(week: position.week - 1, day: daysPrevWeek)
    }
}

// MARK: - Service

enum PlanProgressError: Error {
    /// 计划结构不可读（官方 JSON 缺失 / 自定义计划已删除）。
    case scheduleUnavailable
}

enum PlanProgressEffect: Equatable {
    case none
    case advanced(Int)
    case completed
}

/// `UserActivePlan.currentWeek/currentDay` 的唯一写入方。
///
/// ⛔ 判定依据只有一条：保存下来的 `TrainingSession.planId`（W4 落地）与当前激活计划
/// 的 `planId` 相等。绝不用「当天有训练记录」之类启发式——自由训练 `planId` 为 nil，
/// 会被误算成计划完成。
@MainActor
enum PlanProgressService {

    /// Stable selection also handles old stores containing more than one active row.
    static func currentOfficialPlan(in records: [UserActivePlan]) -> UserActivePlan? {
        records.filter { !$0.isCustom && $0.status == "active" }
            .sorted(by: recordIsNewer).first
    }

    static func displayState(for planID: String, in records: [UserActivePlan]) -> String? {
        if currentOfficialPlan(in: records)?.planId == planID { return "active" }
        guard let saved = records.filter({ !$0.isCustom && $0.planId == planID })
            .sorted(by: recordIsNewer).first else { return nil }
        return saved.status == "active" ? "paused" : saved.status
    }

    private static func recordIsNewer(_ lhs: UserActivePlan, _ rhs: UserActivePlan) -> Bool {
        if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    static func officialRecords(ownerKey: String, context: ModelContext) throws -> [UserActivePlan] {
        try context.fetch(FetchDescriptor<UserActivePlan>(predicate: #Predicate {
            $0.ownerKey == ownerKey && !$0.isCustom
        }))
    }

    /// Repair historical multi-active rows using the same ordering as the v54 migration.
    static func normalizeOfficialMainline(ownerKey: String, context: ModelContext) throws -> [UserActivePlan] {
        let records = try officialRecords(ownerKey: ownerKey, context: context)
        guard let selected = currentOfficialPlan(in: records) else { return records }
        let others = records.filter { $0.status == "active" && $0.id != selected.id }
        guard !others.isEmpty else { return records }
        for row in others { row.status = "paused" }
        do {
            try context.save()
        } catch {
            for row in others { row.status = "active" }
            throw error
        }
        return records
    }

    /// Commit a switch without discarding either curriculum's cursor or unrelated pending edits.
    @discardableResult
    static func activateOfficialPlan(
        _ plan: OfficialPlan,
        ownerKey: String,
        context: ModelContext,
        now: Date = Date(),
        save: (() throws -> Void)? = nil
    ) throws -> UserActivePlan {
        let records = try officialRecords(ownerKey: ownerKey, context: context)
        let saved = records.filter { $0.planId == plan.id }.sorted(by: recordIsNewer).first
        let target = saved ?? UserActivePlan(planId: plan.id, ownerKey: ownerKey)
        let before = records.map { ($0, $0.status, $0.currentLessonId, $0.completedAt, $0.updatedAt) }
        if saved == nil { context.insert(target) }
        for row in records where row.status == "active" && row.id != target.id {
            row.status = "paused"
            row.updatedAt = now
        }
        target.status = "active"
        target.completedAt = nil
        if target.currentLessonId == nil { target.currentLessonId = plan.lessons.first?.id }
        target.updatedAt = now
        do {
            if let save { try save() } else { try context.save() }
            return target
        } catch {
            for (row, status, lesson, completed, updated) in before {
                row.status = status
                row.currentLessonId = lesson
                row.completedAt = completed
                row.updatedAt = updated
            }
            if saved == nil { context.delete(target) }
            throw error
        }
    }

    // MARK: v54 lesson cursor

    /// Applies only a completed item's frozen `advanceEligible` effect. This mutates the current
    /// context but deliberately does not save, so W6 can commit session + item + cursor atomically.
    @discardableResult
    static func settleCompletedScheduleItem(
        _ item: TodayScheduleItem,
        context: ModelContext,
        now: Date = Date()
    ) throws -> PlanProgressEffect {
        guard item.state == TodayScheduleItemState.completed,
              item.progressRole == TodayScheduleProgressRole.advanceEligible,
              let planID = item.planId,
              item.lessonId != nil,
              let activePlan = try fetchOfficialMainline(ownerKey: item.schedule?.ownerKey, context: context),
              activePlan.planId == planID,
              activePlan.status == "active",
              let currentLessonID = activePlan.currentLessonId,
              let plan = PlanContentService.decodePlanFromBundle(id: planID) else {
            return .none
        }

        let lessons = plan.lessons
        let ordinalByID = Dictionary(uniqueKeysWithValues: lessons.enumerated().map { ($0.element.id, $0.offset) })
        guard let currentOrdinal = ordinalByID[currentLessonID] else {
            throw PlanProgressError.scheduleUnavailable
        }
        let inputs = (item.schedule?.items ?? []).compactMap { scheduled -> ProgressSettlementInput? in
            guard scheduled.planId == planID,
                  let lessonID = scheduled.lessonId,
                  let ordinal = ordinalByID[lessonID] else { return nil }
            return ProgressSettlementInput(
                ordinal: ordinal,
                role: scheduled.progressRole,
                isCompleted: scheduled.state == TodayScheduleItemState.completed
            )
        }
        let result = OfficialPlanProgressRules.settle(
            planID: planID,
            activePlanID: activePlan.planId,
            currentOrdinal: currentOrdinal,
            lessonCount: lessons.count,
            items: inputs
        )
        guard result.advancedCount > 0 else { return .none }

        activePlan.updatedAt = now
        if result.isCompleted {
            activePlan.currentLessonId = nil
            activePlan.status = "completed"
            activePlan.completedAt = now
            return .completed
        }
        guard let nextOrdinal = result.currentOrdinal else {
            throw PlanProgressError.scheduleUnavailable
        }
        let next = lessons[nextOrdinal]
        activePlan.currentLessonId = next.id
        activePlan.status = "active"
        activePlan.completedAt = nil
        if let stage = plan.stages.first(where: { stage in
            stage.lessons.contains(where: { $0.id == next.id })
        }) {
            // Compatibility shadow only; new business logic reads currentLessonId.
            activePlan.currentWeek = stage.order
            activePlan.currentDay = next.order
        }
        return .advanced(result.advancedCount)
    }

    static func estimatedRemainingWeeks(
        for activePlan: UserActivePlan,
        plan: OfficialPlan,
        weeklyGoalDays: Int
    ) -> Int {
        let ordinalByID = Dictionary(uniqueKeysWithValues: plan.lessons.enumerated().map {
            ($0.element.id, $0.offset)
        })
        let currentOrdinal = activePlan.status == "completed"
            ? nil
            : activePlan.currentLessonId.flatMap { ordinalByID[$0] }
        return PlanDurationEstimate.remainingWeeks(
            lessonCount: plan.lessonCount,
            currentOrdinal: currentOrdinal,
            weeklyGoalDays: weeklyGoalDays
        )
    }

    // MARK: 结构解析

    static func schedule(for activePlan: UserActivePlan, context: ModelContext) -> PlanSchedule? {
        if activePlan.isCustom {
            guard let uuid = UUID(uuidString: activePlan.planId) else { return nil }
            let ownerKey = activePlan.ownerKey
            let descriptor = FetchDescriptor<CustomPlan>(
                predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == uuid }
            )
            guard let plan = try? context.fetch(descriptor).first else { return nil }
            return .custom(sessionsPerWeek: plan.sessionsPerWeek)
        }
        guard let plan = PlanContentService.decodePlanFromBundle(id: activePlan.planId) else {
            return nil
        }
        return .official(plan)
    }

    // MARK: 按完成推进

    /// 训练落库成功后调用。仅在「该 session 属于当前激活计划」时推进一天。
    ///
    /// - Returns: 实际发生的推进结果；session 不属于任何激活计划时返回 nil（自由训练、
    ///   他计划的历史记录都走这条）。
    @discardableResult
    static func advanceAfterPlanSession(
        _ session: TrainingSession,
        context: ModelContext
    ) throws -> PlanAdvanceOutcome? {
        guard let sessionPlanId = session.planId, !sessionPlanId.isEmpty else { return nil }
        guard let activePlan = try fetchActivePlan(ownerKey: session.ownerKey, context: context),
              activePlan.planId == sessionPlanId else { return nil }
        guard let schedule = schedule(for: activePlan, context: context) else {
            throw PlanProgressError.scheduleUnavailable
        }

        let outcome = PlanProgressRules.next(after: position(of: activePlan), in: schedule)
        if case .advanced(let next) = outcome {
            try apply(next, to: activePlan, context: context)
        }
        return outcome
    }

    // MARK: 手动跳过 / 回退

    /// 跳过当前这一天（不做训练直接前移游标）。
    @discardableResult
    static func skipCurrentDay(context: ModelContext) throws -> PlanAdvanceOutcome? {
        guard let activePlan = try fetchActivePlan(ownerKey: CurrentOwnerContext.shared.ownerKey,
                                               context: context) else { return nil }
        guard let schedule = schedule(for: activePlan, context: context) else {
            throw PlanProgressError.scheduleUnavailable
        }
        let outcome = PlanProgressRules.next(after: position(of: activePlan), in: schedule)
        if case .advanced(let next) = outcome {
            try apply(next, to: activePlan, context: context)
        }
        return outcome
    }

    /// 回退一天。已在第 1 周第 1 天时不动，返回 nil。
    @discardableResult
    static func rollbackCurrentDay(context: ModelContext) throws -> PlanPosition? {
        guard let activePlan = try fetchActivePlan(ownerKey: CurrentOwnerContext.shared.ownerKey,
                                               context: context) else { return nil }
        guard let schedule = schedule(for: activePlan, context: context) else {
            throw PlanProgressError.scheduleUnavailable
        }
        guard let previous = PlanProgressRules.previous(
            before: position(of: activePlan),
            in: schedule
        ) else { return nil }
        try apply(previous, to: activePlan, context: context)
        return previous
    }

    // MARK: - Internals

    private static func fetchActivePlan(ownerKey: String,
                                        context: ModelContext) throws -> UserActivePlan? {
        let descriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey && $0.status == "active" }
        )
        let records = try context.fetch(descriptor)
        // The legacy API remains available for unmigrated custom-plan history.
        return currentOfficialPlan(in: records) ?? records.sorted(by: recordIsNewer).first
    }

    private static func fetchOfficialMainline(
        ownerKey: String?,
        context: ModelContext
    ) throws -> UserActivePlan? {
        guard let ownerKey else { return nil }
        return currentOfficialPlan(in: try officialRecords(ownerKey: ownerKey, context: context))
    }

    private static func position(of activePlan: UserActivePlan) -> PlanPosition {
        PlanPosition(week: activePlan.currentWeek, day: activePlan.currentDay)
    }

    private static func apply(
        _ position: PlanPosition,
        to activePlan: UserActivePlan,
        context: ModelContext
    ) throws {
        activePlan.currentWeek = position.week
        activePlan.currentDay = position.day
        try context.save()
    }
}
