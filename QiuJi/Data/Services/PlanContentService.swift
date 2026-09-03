import Foundation

// MARK: - Plan DTOs (Bundle JSON; future: REST API OTA)

struct OfficialPlan: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let targetLevel: String
    let minutesPerSession: Int
    let isPremium: Bool
    let description: String
    let stages: [PlanStage]

    var lessonCount: Int { stages.reduce(0) { $0 + $1.lessons.count } }
    var lessons: [PlanLesson] {
        stages.sorted { $0.order < $1.order }
            .flatMap { $0.lessons.sorted { $0.order < $1.order } }
    }

    // Transitional read API. W2/W3 migrate bundled content and downstream callers to stages/lessons.
    @available(*, deprecated, message: "Use stages.count")
    var durationWeeks: Int { stages.count }

    @available(*, deprecated, message: "A plan is a curriculum, not a weekly calendar")
    var sessionsPerWeek: Int { stages.map(\.lessons.count).max() ?? 0 }

    @available(*, deprecated, message: "Use stages")
    var weeks: [PlanWeek] { stages.map(PlanWeek.init(stage:)) }

    private enum CodingKeys: String, CodingKey {
        case id, nameZh, nameEn, targetLevel, minutesPerSession, estimatedMinutesPerLesson
        case isPremium, description, stages
        case durationWeeks, sessionsPerWeek, weeks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let planID = try container.decode(String.self, forKey: .id)
        id = planID
        nameZh = try container.decode(String.self, forKey: .nameZh)
        nameEn = try container.decode(String.self, forKey: .nameEn)
        targetLevel = try container.decode(String.self, forKey: .targetLevel)
        if let estimate = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutesPerLesson) {
            minutesPerSession = estimate
        } else {
            minutesPerSession = try container.decode(Int.self, forKey: .minutesPerSession)
        }
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        description = try container.decode(String.self, forKey: .description)

        let decodedStages = try container.decodeIfPresent([PlanStage].self, forKey: .stages)
        let legacyWeeks = try container.decodeIfPresent([PlanWeek].self, forKey: .weeks)
        guard decodedStages == nil || legacyWeeks == nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .stages,
                in: container,
                debugDescription: "OfficialPlan cannot contain both stages and legacy weeks"
            )
        }
        if let decodedStages {
            stages = decodedStages
        } else if let legacyWeeks {
            stages = legacyWeeks.map { PlanStage(legacyWeek: $0, planId: planID) }
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.stages,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "OfficialPlan requires stages or legacy weeks"
                )
            )
        }
        try Self.validate(stages: stages, container: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nameZh, forKey: .nameZh)
        try container.encode(nameEn, forKey: .nameEn)
        try container.encode(targetLevel, forKey: .targetLevel)
        try container.encode(minutesPerSession, forKey: .estimatedMinutesPerLesson)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(description, forKey: .description)
        try container.encode(stages, forKey: .stages)
    }

    private static func validate(
        stages: [PlanStage],
        container: KeyedDecodingContainer<CodingKeys>
    ) throws {
        func fail(_ message: String) throws -> Never {
            throw DecodingError.dataCorruptedError(
                forKey: .stages,
                in: container,
                debugDescription: message
            )
        }
        guard !stages.isEmpty else { try fail("OfficialPlan stages cannot be empty") }
        guard Set(stages.map(\.id)).count == stages.count,
              stages.allSatisfy({ !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            try fail("PlanStage ids must be non-empty and unique")
        }
        guard Set(stages.map(\.order)).count == stages.count,
              stages.allSatisfy({ $0.order > 0 }) else {
            try fail("PlanStage order values must be positive and unique")
        }

        var lessonIDs = Set<String>()
        for stage in stages {
            guard !stage.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                try fail("PlanStage title cannot be empty")
            }
            guard !stage.lessons.isEmpty else { try fail("PlanStage lessons cannot be empty") }
            guard Set(stage.lessons.map(\.order)).count == stage.lessons.count,
                  stage.lessons.allSatisfy({ $0.order > 0 }) else {
                try fail("PlanLesson order values must be positive and unique within a stage")
            }
            for lesson in stage.lessons {
                guard !lesson.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      lessonIDs.insert(lesson.id).inserted else {
                    try fail("PlanLesson ids must be non-empty and unique across the plan")
                }
                guard !lesson.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    try fail("PlanLesson title cannot be empty")
                }
                guard !lesson.phases.isEmpty else { try fail("PlanLesson phases cannot be empty") }
            }
        }
    }
}

struct PlanStage: Codable, Identifiable {
    let id: String
    let order: Int
    let title: String
    let goal: String?
    let lessons: [PlanLesson]

    fileprivate init(legacyWeek: PlanWeek, planId: String) {
        id = "\(planId).stage\(String(format: "%02d", legacyWeek.weekNumber))"
        order = legacyWeek.weekNumber
        title = legacyWeek.theme
        goal = nil
        lessons = legacyWeek.sessions.map {
            PlanLesson(legacySession: $0, planId: planId, stageOrder: legacyWeek.weekNumber)
        }
    }
}

struct PlanLesson: Codable, Identifiable {
    let id: String
    let order: Int
    let title: String
    let summary: String?
    let phases: [SessionPhase]

    fileprivate init(legacySession: PlanSession, planId: String, stageOrder: Int) {
        id = "\(planId).stage\(String(format: "%02d", stageOrder)).lesson\(String(format: "%02d", legacySession.dayNumber))"
        order = legacySession.dayNumber
        title = "第 \(legacySession.dayNumber) 课"
        summary = nil
        phases = legacySession.phases
    }
}

// Legacy bundle DTOs. Production consumers migrate away in W2/W3.
struct PlanWeek: Codable, Identifiable {
    var id: Int { weekNumber }
    let weekNumber: Int
    let theme: String
    let sessions: [PlanSession]

    fileprivate init(stage: PlanStage) {
        weekNumber = stage.order
        theme = stage.title
        sessions = stage.lessons.map(PlanSession.init(lesson:))
    }
}

struct PlanSession: Codable, Identifiable {
    var id: Int { dayNumber }
    let dayNumber: Int
    let phases: [SessionPhase]

    fileprivate init(lesson: PlanLesson) {
        dayNumber = lesson.order
        phases = lesson.phases
    }
}

struct SessionPhase: Codable, Identifiable {
    var id: String { type }
    let type: String          // warmup | focused | combined | review | ritual
    let durationMinutes: Int
    /// 缺省 = `type != ritual`。`false` 时首页/详情日合计与 I13 ⑦ 不计此时长。
    let countsTowardMinutes: Bool?
    let drills: [PlanDrillRef]

    var countsTowardSessionMinutes: Bool {
        countsTowardMinutes ?? (type != "ritual")
    }

    var typeZh: String {
        switch type {
        case "warmup":   return "热身"
        case "focused":  return "专项训练"
        case "combined": return "综合/实战"
        case "review":   return "复盘记录"
        case "ritual":   return "开场"
        default:         return type
        }
    }

    var icon: String {
        switch type {
        case "warmup":   return "flame"
        case "focused":  return "target"
        case "combined": return "square.grid.3x3"
        case "review":   return "pencil.and.list.clipboard"
        case "ritual":   return "circle.grid.3x3"
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
    /// 复习课次减量标记（v37 D-v37-2=B / v38 R7）。
    /// `sequence`：`true` 时允许 `formations[].rounds` 低于内容 `defaultRounds`（降遍数）。
    /// `repetition`：不得靠降 `rounds` 砍位置；减量写可选 `ballsPerRound`（降每位置颗数）。
    /// 缺省 / `false` = 非衰减。同一计划内该 drill 第一次出现禁止为 `true`。
    let decay: Bool?
    /// 跨计划咬合的复习来源计划 id（R6）。仅咬合条目填写，例如 `"plan_accuracy"`。
    let reviewFrom: String?
    /// 五分点开场白名单（v44）。仅 `drill_c023` + `reviewFrom: plan_beginner` + rounds ∈ {4,6}。
    let ritual: Bool?

    struct FormationRounds: Codable, Equatable, Identifiable {
        let token: String
        let rounds: Int
        /// 计划侧覆盖每轮球数（v38 D-v38-4=A）。仅 `repetition` + `decay` 用于压每位置颗数；
        /// `sequence` 禁止写出与内容不等的值（杆数 = 链长，I6b 锁死）。
        let ballsPerRound: Int?

        var id: String { token }

        init(token: String, rounds: Int, ballsPerRound: Int? = nil) {
            self.token = token
            self.rounds = rounds
            self.ballsPerRound = ballsPerRound
        }
    }

    init(
        roundsPerFormation: Int? = nil,
        formations: [FormationRounds]? = nil,
        decay: Bool? = nil,
        reviewFrom: String? = nil,
        ritual: Bool? = nil
    ) {
        self.roundsPerFormation = roundsPerFormation
        self.formations = formations
        self.decay = decay
        self.reviewFrom = reviewFrom
        self.ritual = ritual
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
