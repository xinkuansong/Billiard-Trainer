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
    let sets: Int
    let ballsPerSet: Int
    let isCompleted: Bool
}

struct TodaySessionInfo {
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
    case custom = "自定义模版"
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

    var filteredPlans: [PlanBrowseItem] {
        guard selectedFilter != .all else { return officialPlans }
        return officialPlans.filter { selectedFilter.matches($0.targetLevel) }
    }

    func load(context: ModelContext) async {
        isLoading = true
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
                items.append(TodayDrillItem(
                    id: "\(phase.type)_\(ref.drillId)",
                    drillId: ref.drillId,
                    nameZh: content?.nameZh ?? ref.drillId,
                    phaseType: phase.type,
                    phaseZh: phase.typeZh,
                    phaseIcon: phase.icon,
                    sets: ref.sets,
                    ballsPerSet: ref.ballsPerSet,
                    isCompleted: completedIds.contains(ref.drillId)
                ))
            }
        }

        let totalMinutes = session.phases.reduce(0) { $0 + $1.durationMinutes }

        todaySession = TodaySessionInfo(
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
            items.append(TodayDrillItem(
                id: "custom_\(drill.drillId)",
                drillId: drill.drillId,
                nameZh: drill.drillNameZh,
                phaseType: "focused",
                phaseZh: "专项训练",
                phaseIcon: "target",
                sets: drill.sets,
                ballsPerSet: drill.ballsPerSet,
                isCompleted: completedIds.contains(drill.drillId)
            ))
        }

        todaySession = TodaySessionInfo(
            planNameZh: customPlan.name,
            weekNumber: 1,
            dayNumber: 1,
            weekTheme: "自定义训练",
            totalMinutes: 0,
            drills: items
        )
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
