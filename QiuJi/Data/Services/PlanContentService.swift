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
    let sets: Int
    let ballsPerSet: Int
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
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Plans"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(PlanIndex.self, from: data)
    }

    func loadAllPlans() -> [OfficialPlan] {
        guard let index = loadPlanIndex() else { return [] }
        return index.plans.compactMap { entry in
            loadPlanFromBundle(id: entry.id)
        }
    }

    func loadPlanFromBundle(id: String) -> OfficialPlan? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Plans"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(OfficialPlan.self, from: data)
    }

    func loadFreePlans() -> [OfficialPlan] {
        loadAllPlans().filter { !$0.isPremium }
    }
}
