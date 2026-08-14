import Foundation

// MARK: - Plan DTOs (Bundle JSON; future: REST API OTA)

struct OfficialPlan: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let targetLevel: String
    let durationWeeks: Int
    let sessionsPerWeek: Int
    let minutesPerSession: Int
    let isPremium: Bool
    let description: String
    let weeks: [PlanWeek]
}

struct PlanWeek: Codable, Identifiable {
    var id: Int { weekNumber }
    let weekNumber: Int
    let theme: String
    let sessions: [PlanSession]
}

struct PlanSession: Codable, Identifiable {
    var id: Int { dayNumber }
    let dayNumber: Int
    let phases: [SessionPhase]
}

struct SessionPhase: Codable, Identifiable {
    var id: String { type }
    let type: String          // warmup | focused | combined | review
    let durationMinutes: Int
    let drills: [PlanDrillRef]

    var typeZh: String {
        switch type {
        case "warmup":   return "热身"
        case "focused":  return "专项训练"
        case "combined": return "综合/实战"
        case "review":   return "复盘记录"
        default:         return type
        }
    }

    var icon: String {
        switch type {
        case "warmup":   return "flame"
        case "focused":  return "target"
        case "combined": return "square.grid.3x3"
        case "review":   return "pencil.and.list.clipboard"
        default:         return "circle"
        }
    }
}

struct PlanDrillRef: Codable, Identifiable {
    var id: String { drillId }
    let drillId: String
    /// 计划只存强度系数，实际球数在激活训练时由 drill `sets.perFormation` 解析（v31 R4，契约 §6.6）。
    let dose: PlanDrillDose?

    init(drillId: String, dose: PlanDrillDose? = nil) {
        self.drillId = drillId
        self.dose = dose
    }
}

/// 计划条目的剂量引用（v31 R4）。二选一：统一轮数，或按球形逐条给轮数（球形即难度阶梯）。
struct PlanDrillDose: Codable, Equatable {
    /// 每个球形都练这么多轮。与 `formations` 二选一。
    let roundsPerFormation: Int?
    /// 按球形 token 逐条给轮数；未列出的球形本次不练。与 `roundsPerFormation` 二选一。
    let formations: [FormationRounds]?
    /// 复习课次减量标记（v37 D-v37-2=B）。`true` 时允许 `formations[].rounds` 低于内容 `defaultRounds`。
    /// 缺省 / `false` = 非衰减（仍钳到下限）。同一计划内该 drill 第一次出现禁止为 `true`。
    let decay: Bool?
    /// 跨计划咬合的复习来源计划 id（R6）。仅咬合条目填写，例如 `"plan_accuracy"`。
    let reviewFrom: String?

    struct FormationRounds: Codable, Equatable, Identifiable {
        let token: String
        let rounds: Int

        var id: String { token }
    }

    init(
        roundsPerFormation: Int? = nil,
        formations: [FormationRounds]? = nil,
        decay: Bool? = nil,
        reviewFrom: String? = nil
    ) {
        self.roundsPerFormation = roundsPerFormation
        self.formations = formations
        self.decay = decay
        self.reviewFrom = reviewFrom
    }
}

// MARK: - Plan Index

struct PlanIndex: Codable {
    let version: Int
    let plans: [PlanIndexEntry]
}

struct PlanIndexEntry: Codable {
    let id: String
    let nameZh: String
    let targetLevel: String
    let isPremium: Bool
}

// MARK: - Service

actor PlanContentService {

    static let shared = PlanContentService()
    private init() {}

    func loadPlanIndex() -> PlanIndex? {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Plans") else {
            DrillContentDiagnostics.logMissingResource(name: "Plans/index.json")
            return nil
        }
        do {
            return try JSONDecoder().decode(PlanIndex.self, from: try Data(contentsOf: url))
        } catch {
            DrillContentDiagnostics.logDecodeFailure(resource: "Plans/index.json", error: error)
            return nil
        }
    }

    func loadAllPlans() -> [OfficialPlan] {
        guard let index = loadPlanIndex() else { return [] }
        return index.plans.compactMap { entry in
            loadPlanFromBundle(id: entry.id)
        }
    }

    func loadPlanFromBundle(id: String) -> OfficialPlan? {
        Self.decodePlanFromBundle(id: id)
    }

    /// 同步读取（只读 Bundle，不访问 actor 状态）。计划推进要在训练落库的同一步内
    /// 取到周 / 天结构，故需要一条不经 `await` 的入口。
    nonisolated static func decodePlanFromBundle(id: String) -> OfficialPlan? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Plans") else {
            DrillContentDiagnostics.logMissingResource(name: "Plans/\(id).json")
            return nil
        }
        do {
            return try JSONDecoder().decode(OfficialPlan.self, from: try Data(contentsOf: url))
        } catch {
            DrillContentDiagnostics.logDecodeFailure(resource: "Plans/\(id).json", error: error)
            return nil
        }
    }

    func loadFreePlans() -> [OfficialPlan] {
        loadAllPlans().filter { !$0.isPremium }
    }
}
