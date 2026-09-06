import Foundation
import SwiftData

// MARK: - View Data

struct TodayDrillItem: Identifiable {
    let id: String
    let drillId: String
    let nameZh: String
    let phaseType: String
    let phaseZh: String
    let phaseIcon: String
    /// 展开后的组序列：球形 1 轮 1 → … → 球形 N 轮 M，逐组带球形与目标球数（v31 R6）。
    let plannedSets: [PlannedTrainingSet]
    /// 展示文案（同构「N 轮 × N 球/杆」，异构多球形出汇总），口径见 `ResolvedDose`。
    let volumeText: String
    let isCompleted: Bool

    var setCount: Int { plannedSets.count }
    var totalBalls: Int { plannedSets.reduce(0) { $0 + $1.targetBalls } }
}

struct TodaySessionInfo {
    /// 当前激活计划 id（`UserActivePlan.planId`），随训练一起落 `TrainingSession.planId`。
    let planId: String
    let planNameZh: String
    let weekNumber: Int
    let dayNumber: Int
    let weekTheme: String
    let totalMinutes: Int
    let drills: [TodayDrillItem]
    /// `UserActivePlan.isCustom`：模版今日藏周/天与进度菜单（D-v43-9）。
    let isFromTemplate: Bool
    var lessonID: String? = nil

    var completedCount: Int { drills.filter(\.isCompleted).count }
    var totalCount: Int { drills.count }
    var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }
    var isAllCompleted: Bool { totalCount > 0 && completedCount == totalCount }
}

struct PlanBrowseItem: Identifiable {
    let id: String
    let nameZh: String
    let description: String
    let targetLevel: String
    let isPremium: Bool
    let durationWeeks: Int
    let sessionsPerWeek: Int
    let lessonCount: Int
}

enum PlanBrowseTab: String, CaseIterable {
    case official = "官方计划"
    /// F-PL-09 当年统一成「我的计划」；本轮 D-v43-7 改回界面用字「我的模版」。
    case custom = "我的模版"
}

/// Read-only projection: queue identity, suggestions and saved facts remain distinct.
@MainActor
struct TodayTrainingProjection {
    struct QueuedLesson: Identifiable {
        let item: TodayScheduleItem
        let drills: [ScheduledDrillSnapshot]
        let completedDrills: [Bool]
        let extraCompletedCount: Int
        let estimatedMinutes: Int
        let unavailableReason: String?
        var id: UUID { item.id }
        var countsTowardToday: Bool { item.state != TodayScheduleItemState.abandoned }
        var totalCount: Int { drills.count + extraCompletedCount }
        var completedCount: Int { completedDrills.filter { $0 }.count + extraCompletedCount }
    }

    struct SavedTraining: Identifiable {
        let session: TrainingSession
        let entries: [DrillEntry]
        var id: UUID { session.id }
    }

    let queued: [QueuedLesson]
    let suggestion: TodaySessionInfo?
    let history: [SavedTraining]

    var totalCount: Int {
        queued.filter(\.countsTowardToday).reduce(0) { $0 + $1.totalCount }
            + history.reduce(0) { $0 + $1.entries.count }
    }
    var completedCount: Int {
        queued.filter(\.countsTowardToday).reduce(0) { $0 + $1.completedCount }
            + history.reduce(0) { $0 + $1.entries.count }
    }
    var estimatedMinutes: Int {
        queued.filter(\.countsTowardToday).reduce(0) { $0 + $1.estimatedMinutes }
    }
    var recordedMinutes: Int { history.reduce(0) { $0 + max(0, $1.session.totalDurationMinutes) } }
    var hasUnavailableContent: Bool { queued.contains { $0.countsTowardToday && $0.unavailableReason != nil } }
    var hasFinishedTraining: Bool { completedCount > 0 }
    var allActionsCompleted: Bool { totalCount > 0 && completedCount == totalCount && !hasUnavailableContent }
    var allArrangedTrainingEnded: Bool {
        let visible = queued.filter(\.countsTowardToday)
        return (!visible.isEmpty || !history.isEmpty) && !hasUnavailableContent
            && visible.allSatisfy { $0.item.state == TodayScheduleItemState.completed }
    }

    static func make(
        ownerKey: String,
        schedules: [TodayTrainingSchedule],
        sessions: [TrainingSession],
        suggestion: TodaySessionInfo?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> TodayTrainingProjection {
        let dayKey = TodayTrainingScheduleService.localDayKey(for: now, timeZone: timeZone)
        let schedule = TodayTrainingScheduleService.currentSchedule(
            in: schedules, ownerKey: ownerKey, dayKey: dayKey
        )
        let items = (schedule?.items ?? []).sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
        var sessionIDs = Set<UUID>()
        let owned = sessions.filter {
            $0.ownerKey == ownerKey && $0.kind == TrainingSessionKind.drill && sessionIDs.insert($0.id).inserted
        }
        let queued = items.map { item -> QueuedLesson in
            do {
                guard item.payloadVersion == 1 else { throw ScheduledTrainingBlock.DecodeError.invalidPayload }
                let block = try ScheduledTrainingBlock(item: item)
                guard !block.drills.isEmpty else { throw ScheduledTrainingBlock.DecodeError.invalidPayload }
                let saved = owned.filter {
                    $0.scheduleItemId == item.id || $0.id == item.trainingSessionId
                }
                let entries = uniqueEntries(in: saved)
                var remaining = Dictionary(grouping: entries, by: \.drillId).mapValues(\.count)
                let completed = block.drills.map { drill -> Bool in
                    guard item.state == TodayScheduleItemState.completed,
                          remaining[drill.drillID, default: 0] > 0 else { return false }
                    remaining[drill.drillID, default: 0] -= 1
                    return true
                }
                let extras = item.state == TodayScheduleItemState.completed
                    ? remaining.values.reduce(0, +) : 0
                return QueuedLesson(item: item, drills: block.drills, completedDrills: completed,
                                    extraCompletedCount: extras, estimatedMinutes: try estimate(block),
                                    unavailableReason: item.state == TodayScheduleItemState.completed && saved.isEmpty
                                        ? "已结束，但训练记录暂时无法读取" : nil)
            } catch {
                return QueuedLesson(item: item, drills: [], completedDrills: [], extraCompletedCount: 0,
                                    estimatedMinutes: 0, unavailableReason: "训练内容暂时无法读取，请重新加入")
            }
        }
        let itemIDs = Set(items.map(\.id))
        let linkedSessionIDs = Set(items.compactMap(\.trainingSessionId))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let history = owned.filter {
            calendar.isDate($0.date, inSameDayAs: now)
                && !linkedSessionIDs.contains($0.id)
                && !($0.scheduleItemId.map { itemIDs.contains($0) } ?? false)
        }.sorted { $0.date < $1.date }.compactMap { session -> SavedTraining? in
            let entries = uniqueEntries(in: [session])
            return entries.isEmpty ? nil : SavedTraining(session: session, entries: entries)
        }
        let visible = queued.filter(\.countsTowardToday)
        let dayEnded = (!visible.isEmpty || !history.isEmpty)
            && visible.allSatisfy { $0.item.state == TodayScheduleItemState.completed }
        let suggestionAlreadyQueued = suggestion.map { proposed in
            items.contains { $0.planId == proposed.planId && $0.lessonId == proposed.lessonID }
        } ?? false
        return TodayTrainingProjection(queued: queued,
            suggestion: dayEnded || suggestionAlreadyQueued ? nil : suggestion, history: history)
    }

    private static func uniqueEntries(in sessions: [TrainingSession]) -> [DrillEntry] {
        var ids = Set<UUID>()
        return sessions.flatMap(\.drillEntries).filter { ids.insert($0.id).inserted }.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func estimate(_ block: ScheduledTrainingBlock) throws -> Int {
        if block.sourceKind == TodayScheduleSourceKind.officialLesson {
            let payload = try JSONDecoder().decode(ScheduledLessonPayload.self, from: block.payloadSnapshot)
            var offset = 0
            return payload.lesson.phases.reduce(0) { minutes, phase in
                let drills = block.drills.dropFirst(offset).prefix(phase.drills.count)
                offset += phase.drills.count
                guard phase.countsTowardSessionMinutes else { return minutes }
                if phase.drills.isEmpty { return minutes + phase.durationMinutes }
                let balls = drills.flatMap(\.sets).reduce(0) { $0 + max(0, $1.targetBalls) }
                return minutes + ResolvedDose.estimatedMinutes(forBalls: balls)
            }
        }
        let balls = block.drills.flatMap(\.sets).reduce(0) { $0 + max(0, $1.targetBalls) }
        return ResolvedDose.estimatedMinutes(forBalls: balls)
    }
}

enum PlanLevelFilter: String, CaseIterable {
    case all = "全部"
    case beginner = "入门"
    case elementary = "初级"
    case intermediate = "中级"
    case advanced = "高级"
    case combined = "综合"

    func matches(_ targetLevel: String) -> Bool {
        switch self {
        case .all: return true
        case .beginner: return targetLevel.contains("L0")
        case .elementary: return targetLevel.contains("L1") && !targetLevel.contains("L2")
        case .intermediate: return targetLevel.contains("L2")
        case .advanced: return targetLevel.contains("L3") || targetLevel.contains("L4")
        case .combined: return targetLevel.contains("→")
        }
    }
}

// MARK: - ViewModel

@MainActor
final class TrainingHomeViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var todaySession: TodaySessionInfo?
    /// 当天已保存、但不属于当前激活计划的真实球台训练。
    /// 自由选择动作也必须回显在首页「今日训练」，同时由 TrainingGoalMetrics 计入本周训练。
    @Published var todaySupplementalDrills: [TodayDrillItem] = []
    @Published var hasActivePlan = false
    @Published var officialPlans: [PlanBrowseItem] = []
    @Published var selectedTab: PlanBrowseTab = .official
    @Published var selectedFilter: PlanLevelFilter = .all
    /// 手动跳过 / 回退失败时的可见提示（计划结构不可读等），nil 表示无错误。
    @Published var progressError: String?

    /// 货架滚动锚点：顶 / 浏览区 / 官方计划 id / 自定义计划 UUID 串。
    static let scrollTopID = "trainingHomeTop"
    static let scrollBrowsingID = "planBrowsing"

    /// 从计划详情返回时要滚回的计划 id；激活计划后清掉，改为回顶。
    var restorePlanID: String?

    /// 一次性滚动请求：递增 tick，首页 `ScrollViewReader` 滚到 `browseScrollTarget`。
    @Published var browseScrollTarget: String = TrainingHomeViewModel.scrollTopID
    @Published var browseScrollTick: UInt = 0

    func requestBrowseScroll(to id: String) {
        browseScrollTarget = id
        browseScrollTick &+= 1
    }

    /// 第 1 周第 1 天已无可回退。
    var canRollbackDay: Bool {
        guard let session = todaySession else { return false }
        return session.weekNumber > 1 || session.dayNumber > 1
    }

    var filteredPlans: [PlanBrowseItem] {
        guard selectedFilter != .all else { return officialPlans }
        return officialPlans.filter { selectedFilter.matches($0.targetLevel) }
    }

    func load(context: ModelContext) async {
        await load(context: context, ownerKey: CurrentOwnerContext.shared.ownerKey)
    }

    func load(context: ModelContext, ownerKey: String) async {
        // 二次刷新禁止出骨架：骨架与货架互斥会拆掉 ScrollView 内容，返回后滚回顶部。
        let shouldShowSkeleton = officialPlans.isEmpty && todaySession == nil
        if shouldShowSkeleton { isLoading = true }
        // View animates via `.animation(BTMotion.easeFast, value: isLoading)` (F-ST-03).
        defer { isLoading = false }

        let records: [UserActivePlan]
        do {
            records = try PlanProgressService.normalizeOfficialMainline(ownerKey: ownerKey, context: context)
            progressError = nil
        } catch {
            progressError = "计划读取失败，请稍后重试"
            hasActivePlan = false
            todaySession = nil
            return
        }
        guard let activePlan = PlanProgressService.currentOfficialPlan(in: records) else {
            hasActivePlan = false
            todaySession = nil
            todaySupplementalDrills = fetchTodaySupplementalDrills(
                context: context,
                excludingPlanId: nil,
                ownerKey: ownerKey
            )
            await loadPlansForBrowsing()
            return
        }

        hasActivePlan = true
        todaySupplementalDrills = fetchTodaySupplementalDrills(
            context: context,
            excludingPlanId: activePlan.planId,
            ownerKey: ownerKey
        )

        await loadOfficialPlan(activePlan: activePlan, context: context, ownerKey: ownerKey)

        await loadPlansForBrowsing()
    }

    // MARK: - 手动跳过 / 回退（D-v29-3）

    func skipCurrentDay(context: ModelContext) async {
        progressError = nil
        do {
            _ = try PlanProgressService.skipCurrentDay(context: context)
        } catch {
            progressError = "计划结构读取失败，无法跳过这一天"
            return
        }
        await load(context: context)
    }

    func rollbackCurrentDay(context: ModelContext) async {
        progressError = nil
        do {
            _ = try PlanProgressService.rollbackCurrentDay(context: context)
        } catch {
            progressError = "计划结构读取失败，无法回退这一天"
            return
        }
        await load(context: context)
    }

    private func loadPlansForBrowsing() async {
        let plans = await PlanContentService.shared.loadAllPlans()
        officialPlans = plans.map { plan in
            PlanBrowseItem(
                id: plan.id,
                nameZh: plan.nameZh,
                description: plan.description,
                targetLevel: plan.targetLevel,
                isPremium: plan.isPremium,
                durationWeeks: plan.durationWeeks,
                sessionsPerWeek: plan.sessionsPerWeek,
                lessonCount: plan.lessonCount
            )
        }
    }

    private func loadOfficialPlan(activePlan: UserActivePlan, context: ModelContext,
                                  ownerKey: String) async {
        let planService = PlanContentService.shared
        guard let plan = await planService.loadPlanFromBundle(id: activePlan.planId) else {
            todaySession = nil
            return
        }

        guard let lessonID = activePlan.currentLessonId,
              let stage = plan.stages.first(where: { $0.lessons.contains { $0.id == lessonID } }),
              let session = stage.lessons.first(where: { $0.id == lessonID }) else {
            todaySession = nil
            return
        }

        var completedCounts: [String: Int]
        do {
            completedCounts = try fetchTodayCompletedDrillCounts(
                context: context, planId: activePlan.planId, ownerKey: ownerKey, lessonID: session.id
            )
        } catch {
            todaySession = nil
            progressError = "训练记录读取失败，请稍后重试"
            return
        }
        let drillService = DrillContentService.shared

        var items: [TodayDrillItem] = []
        var totalMinutes = 0
        for phase in session.phases {
            var phaseBalls = 0
            for ref in phase.drills {
                let content = await drillService.loadDrillFromBundle(id: ref.drillId)
                // 计划 dose × drill perFormation → 组序列（契约 §6.6）。
                let resolved = TrainingDoseResolver.resolve(
                    content: content,
                    dose: ref.dose,
                    formationOptions: TrainingDoseResolver.formationOptions(forDrillId: ref.drillId)
                )
                phaseBalls += resolved.totalBalls
                let completed = completedCounts[ref.drillId, default: 0] > 0
                if completed { completedCounts[ref.drillId, default: 0] -= 1 }
                items.append(TodayDrillItem(
                    id: "\(session.id)_\(items.count)",
                    drillId: ref.drillId,
                    nameZh: content?.nameZh ?? ref.drillId,
                    phaseType: phase.type,
                    phaseZh: phase.typeZh,
                    phaseIcon: phase.icon,
                    plannedSets: resolved.plannedSets,
                    volumeText: resolved.volumeText(unitLabel: Self.unitLabel(for: content)),
                    isCompleted: completed
                ))
            }
            if phase.countsTowardSessionMinutes {
                totalMinutes += phase.drills.isEmpty ? phase.durationMinutes
                    : ResolvedDose.estimatedMinutes(forBalls: phaseBalls)
            }
        }

        todaySession = TodaySessionInfo(
            planId: activePlan.planId,
            planNameZh: plan.nameZh,
            weekNumber: stage.order,
            dayNumber: session.order,
            weekTheme: stage.title,
            totalMinutes: totalMinutes,
            drills: items,
            isFromTemplate: false,
            lessonID: session.id
        )
    }

    private static func unitLabel(for content: DrillContent?) -> String {
        DrillUnitLabel.label(category: content?.category ?? "",
                             subcategory: content?.subcategory ?? "")
    }

    private func fetchTodayCompletedDrillCounts(
        context: ModelContext,
        planId: String,
        ownerKey: String,
        lessonID: String
    ) throws -> [String: Int] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [:] }

        let predicate = #Predicate<TrainingSession> {
            $0.ownerKey == ownerKey && $0.date >= start && $0.date < end
        }
        let descriptor = FetchDescriptor<TrainingSession>(predicate: predicate)

        let sessions = try context.fetch(descriptor)
        var entryIDs = Set<UUID>()
        let entries = sessions.filter { $0.kind == TrainingSessionKind.drill && $0.planId == planId && $0.lessonId == lessonID }
            .flatMap(\.drillEntries).filter { entryIDs.insert($0.id).inserted }
        return Dictionary(grouping: entries, by: \.drillId).mapValues(\.count)
    }

    /// 读取今天所有不属于当前计划的真实动作记录。
    ///
    /// 计划会话继续由 `todaySession.drills` 负责展示，避免同一条落库记录重复出现；
    /// 自由训练或今天更换计划前的训练则按真实 `DrillEntry` 逐行追加。
    private func fetchTodaySupplementalDrills(
        context: ModelContext,
        excludingPlanId: String?,
        ownerKey: String
    ) -> [TodayDrillItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = #Predicate<TrainingSession> {
            $0.ownerKey == ownerKey && $0.date >= start && $0.date < end
        }
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        guard let fetched = try? context.fetch(descriptor) else { return [] }
        let sessions = fetched.filter { session in
            guard session.kind == TrainingSessionKind.drill else { return false }
            guard let excludingPlanId else { return true }
            return session.planId != excludingPlanId
        }

        return sessions.flatMap { session in
            session.drillEntries
                .sorted { lhs, rhs in
                    if lhs.orderIndex == rhs.orderIndex {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.orderIndex < rhs.orderIndex
                }
                .map { entry in
                    let storedSets = entry.sets.sorted { $0.setNumber < $1.setNumber }
                    let plannedSets = storedSets.map { set in
                        PlannedTrainingSet(
                            formationToken: set.formationToken,
                            formationName: set.formationName,
                            targetBalls: set.targetBalls,
                            mode: nil
                        )
                    }
                    return TodayDrillItem(
                        id: "record_\(entry.id.uuidString)",
                        drillId: entry.drillId,
                        nameZh: entry.drillNameZh,
                        phaseType: "free",
                        phaseZh: "自由训练",
                        phaseIcon: "plus.circle",
                        plannedSets: plannedSets,
                        volumeText: Self.recordedVolumeText(for: storedSets),
                        isCompleted: true
                    )
                }
        }
    }

    private static func recordedVolumeText(for sets: [DrillSet]) -> String {
        guard let first = sets.first else { return "已完成" }
        let unit = first.unitLabel
        if sets.allSatisfy({ $0.targetBalls == first.targetBalls }) {
            return "\(sets.count) × \(first.targetBalls)"
        }
        let total = sets.reduce(0) { $0 + $1.targetBalls }
        return "\(sets.count) 组 · 共 \(total) \(unit)"
    }
}
