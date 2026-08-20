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
}

enum PlanBrowseTab: String, CaseIterable {
    case official = "官方计划"
    /// F-PL-09: align wording with PlanListView「我的计划」(was「自定义模版」)
    case custom = "我的计划"
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
        // 二次刷新禁止出骨架：骨架与货架互斥会拆掉 ScrollView 内容，返回后滚回顶部。
        let shouldShowSkeleton = officialPlans.isEmpty && todaySession == nil
        if shouldShowSkeleton { isLoading = true }
        // View animates via `.animation(BTMotion.easeFast, value: isLoading)` (F-ST-03).
        defer { isLoading = false }

        let descriptor = FetchDescriptor<UserActivePlan>()
        guard let activePlan = try? context.fetch(descriptor).first else {
            hasActivePlan = false
            todaySession = nil
            await loadPlansForBrowsing()
            return
        }

        hasActivePlan = true

        if activePlan.isCustom {
            await loadCustomPlan(activePlan: activePlan, context: context)
        } else {
            await loadOfficialPlan(activePlan: activePlan, context: context)
        }

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
                sessionsPerWeek: plan.sessionsPerWeek
            )
        }
    }

    private func loadOfficialPlan(activePlan: UserActivePlan, context: ModelContext) async {
        let planService = PlanContentService.shared
        guard let plan = await planService.loadPlanFromBundle(id: activePlan.planId) else {
            todaySession = nil
            return
        }

        let weekIndex = activePlan.currentWeek - 1
        let dayIndex = activePlan.currentDay - 1

        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            todaySession = nil
            return
        }
        let week = plan.weeks[weekIndex]

        guard dayIndex >= 0, dayIndex < week.sessions.count else {
            todaySession = nil
            return
        }
        let session = week.sessions[dayIndex]

        let completedIds = fetchTodayCompletedDrillIds(context: context)
        let drillService = DrillContentService.shared

        var items: [TodayDrillItem] = []
        for phase in session.phases {
            for ref in phase.drills {
                let content = await drillService.loadDrillFromBundle(id: ref.drillId)
                // 计划 dose × drill perFormation → 组序列（契约 §6.6）。
                let resolved = TrainingDoseResolver.resolve(
                    content: content,
                    dose: ref.dose,
                    formationOptions: TrainingDoseResolver.formationOptions(forDrillId: ref.drillId)
                )
                items.append(TodayDrillItem(
                    id: "\(phase.type)_\(ref.drillId)",
                    drillId: ref.drillId,
                    nameZh: content?.nameZh ?? ref.drillId,
                    phaseType: phase.type,
                    phaseZh: phase.typeZh,
                    phaseIcon: phase.icon,
                    plannedSets: resolved.plannedSets,
                    volumeText: resolved.volumeText(unitLabel: Self.unitLabel(for: content)),
                    isCompleted: completedIds.contains(ref.drillId)
                ))
            }
        }

        let totalMinutes = session.phases.reduce(0) { $0 + $1.durationMinutes }

        todaySession = TodaySessionInfo(
            planId: activePlan.planId,
            planNameZh: plan.nameZh,
            weekNumber: activePlan.currentWeek,
            dayNumber: activePlan.currentDay,
            weekTheme: week.theme,
            totalMinutes: totalMinutes,
            drills: items
        )
    }

    private func loadCustomPlan(activePlan: UserActivePlan, context: ModelContext) async {
        guard let planUUID = UUID(uuidString: activePlan.planId) else {
            todaySession = nil
            return
        }

        let descriptor = FetchDescriptor<CustomPlan>(
            predicate: #Predicate { $0.id == planUUID }
        )
        guard let customPlan = try? context.fetch(descriptor).first else {
            todaySession = nil
            return
        }

        let completedIds = fetchTodayCompletedDrillIds(context: context)
        let sortedDrills = customPlan.drills.sorted { $0.order < $1.order }

        var items: [TodayDrillItem] = []
        for drill in sortedDrills {
            // 自定义计划只存每球形轮数（schema V3）；球数同样由内容派生。
            let content = DrillContentService.decodeDrillFromBundle(id: drill.drillId)
            let resolved = TrainingDoseResolver.resolve(
                content: content,
                dose: PlanDrillDose(roundsPerFormation: drill.roundsPerFormation),
                formationOptions: TrainingDoseResolver.formationOptions(forDrillId: drill.drillId)
            )
            items.append(TodayDrillItem(
                id: "custom_\(drill.drillId)",
                drillId: drill.drillId,
                nameZh: drill.drillNameZh,
                phaseType: "focused",
                phaseZh: "专项训练",
                phaseIcon: "target",
                plannedSets: resolved.plannedSets,
                volumeText: resolved.volumeText(unitLabel: Self.unitLabel(for: content)),
                isCompleted: completedIds.contains(drill.drillId)
            ))
        }

        // 自定义计划没有周结构：每天同一张动作表，周 / 天只作推进计数（W7）。
        todaySession = TodaySessionInfo(
            planId: activePlan.planId,
            planNameZh: customPlan.name,
            weekNumber: activePlan.currentWeek,
            dayNumber: activePlan.currentDay,
            weekTheme: "自定义训练",
            totalMinutes: 0,
            drills: items
        )
    }

    /// 录入单位（契约 §5.2）。内容缺失时按「球」。
    private static func unitLabel(for content: DrillContent?) -> String {
        DrillUnitLabel.label(category: content?.category ?? "",
                             subcategory: content?.subcategory ?? "")
    }

    private func fetchTodayCompletedDrillIds(context: ModelContext) -> Set<String> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = #Predicate<TrainingSession> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor<TrainingSession>(predicate: predicate)

        guard let sessions = try? context.fetch(descriptor) else { return [] }
        return Set(sessions.flatMap(\.drillEntries).map(\.drillId))
    }
}
