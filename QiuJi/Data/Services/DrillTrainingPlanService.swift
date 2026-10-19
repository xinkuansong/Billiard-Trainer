import Foundation
import SwiftData

/// Shared content authorization. Missing catalog entries are never assumed to be free.
@MainActor
struct ProContentAccess {
    enum Failure: LocalizedError, Equatable {
        case unavailable, loginRequired, checking, proRequired
        var errorDescription: String? {
            switch self {
            case .unavailable: return "训练内容暂不可用，请重新选择"
            case .loginRequired: return "请先登录并确认 Pro 权益"
            case .checking: return "正在确认 Pro 权益，请稍后重试"
            case .proRequired: return "所选内容需要 Pro，请先开通或恢复购买"
            }
        }
    }
    var decision: (Bool) -> ProAccessPolicy.Decision
    var drillRequirement: (String) -> Bool?

    static var live: Self {
        Self(decision: { SubscriptionManager.shared.accessDecision(requiresPremium: $0) },
             drillRequirement: { DrillContentService.decodeDrillFromBundle(id: $0)?.isPremium })
    }

    func require(_ premium: Bool) throws {
        switch decision(premium) {
        case .allowed: return
        case .requiresLogin: throw Failure.loginRequired
        case .checkingEntitlements: throw Failure.checking
        case .requiresPro: throw Failure.proRequired
        }
    }

    func requireDrills(_ ids: [String]) throws {
        let requirements = try ids.map { id -> Bool in
            guard let premium = drillRequirement(id) else { throw Failure.unavailable }
            return premium
        }
        try require(requirements.contains(true))
    }

    func require(_ block: ScheduledTrainingBlock) throws {
        guard block.ownerKey == CurrentOwnerContext.shared.ownerKey else { throw Failure.unavailable }
        if block.sourceKind == TodayScheduleSourceKind.officialLesson {
            let payload = try JSONDecoder().decode(ScheduledLessonPayload.self, from: block.payloadSnapshot)
            guard let premium = PlanContentService.decodePlanFromBundle(id: payload.planID)?.isPremium
                    ?? payload.requiresPremium else { throw Failure.unavailable }
            try require(premium)
        }
        for drill in block.drills {
            guard let premium = drillRequirement(drill.drillID) ?? drill.requiresPremium else { throw Failure.unavailable }
            try require(premium)
        }
    }

    func require(_ mode: TrainingMode) throws {
        switch mode {
        case .free: break
        case .plan(let drills, let planID):
            if let planID, UUID(uuidString: planID) == nil {
                guard let plan = PlanContentService.decodePlanFromBundle(id: planID) else { throw Failure.unavailable }
                try require(plan.isPremium)
            }
            try requireDrills(drills.map(\.drillId))
        case .scheduled, .scheduledSequence:
            for block in mode.scheduledBlocks { try require(block) }
        }
    }
}

/// Adds a drill into a `CustomPlan` (the only mutable path that can appear in「今日训练」).
/// Official bundle plans are immutable JSON — they are never mutated here.
@MainActor
enum DrillTrainingPlanService {

    enum AddResult: Equatable {
        /// Drill appended and saved.
        case added(planName: String, appearsInToday: Bool)
        /// Drill already listed in the plan; no duplicate write.
        case alreadyPresent(planName: String, appearsInToday: Bool)
    }

    enum ServiceError: Error, Equatable {
        case planNotFound
        case emptyName
        case saveFailed
    }

    // MARK: - Queries

    static func fetchCustomPlans(context: ModelContext) throws -> [CustomPlan] {
        let ownerKey = CurrentOwnerContext.shared.ownerKey
        let descriptor = FetchDescriptor<CustomPlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Active custom plan driving「今日训练」, if any.
    static func activeCustomPlan(context: ModelContext) throws -> CustomPlan? {
        let ownerKey = CurrentOwnerContext.shared.ownerKey
        let activeDescriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        guard let active = try context.fetch(activeDescriptor).first, active.isCustom,
              let uuid = UUID(uuidString: active.planId) else { return nil }
        let planDescriptor = FetchDescriptor<CustomPlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == uuid }
        )
        return try context.fetch(planDescriptor).first
    }

    static func planContainsDrill(_ plan: CustomPlan, drillId: String) -> Bool {
        plan.drills.contains { $0.drillId == drillId }
    }

    // MARK: - Mutations

    /// Append `drill` to an existing custom plan and save.
    @discardableResult
    static func addDrill(
        _ drill: DrillContent,
        to plan: CustomPlan,
        context: ModelContext,
        access: ProContentAccess? = nil
    ) throws -> AddResult {
        let appearsInToday = try isActiveCustomPlan(plan, context: context)
        if planContainsDrill(plan, drillId: drill.id) {
            return .alreadyPresent(planName: plan.name, appearsInToday: appearsInToday)
        }
        try (access ?? .live).requireDrills([drill.id])

        let nextOrder = (plan.drills.map(\.order).max() ?? -1) + 1
        let entry = CustomPlanDrill(
            drillId: drill.id,
            drillNameZh: drill.nameZh,
            // v34 R9：倍数语义，默认 1 = 完整剂量（位置全覆盖）。
            roundsPerFormation: 1,
            order: nextOrder
        )
        plan.drills.append(entry)
        context.insert(entry)
        do {
            try context.save()
        } catch {
            throw ServiceError.saveFailed
        }
        return .added(planName: plan.name, appearsInToday: appearsInToday)
    }

    /// Create a new custom plan containing only this drill; optionally activate as今日训练.
    @discardableResult
    static func createPlan(
        name: String,
        drill: DrillContent,
        activateAsToday: Bool,
        context: ModelContext,
        access: ProContentAccess? = nil
    ) throws -> (plan: CustomPlan, result: AddResult) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyName }
        try (access ?? .live).requireDrills([drill.id])

        let ownerKey = CurrentOwnerContext.shared.ownerKey
        let plan = CustomPlan(name: trimmed, sessionsPerWeek: 1, ownerKey: ownerKey)
        let entry = CustomPlanDrill(
            drillId: drill.id,
            drillNameZh: drill.nameZh,
            // v34 R9：倍数语义，默认 1 = 完整剂量（位置全覆盖）。
            roundsPerFormation: 1,
            order: 0
        )
        plan.drills = [entry]
        context.insert(plan)

        if activateAsToday {
            try activate(plan: plan, context: context, access: access)
        }

        do {
            try context.save()
        } catch {
            throw ServiceError.saveFailed
        }

        return (
            plan,
            .added(planName: plan.name, appearsInToday: activateAsToday)
        )
    }

    /// Replace `UserActivePlan` so this custom plan becomes「今日训练」.
    static func activate(plan: CustomPlan, context: ModelContext, access: ProContentAccess? = nil) throws {
        try (access ?? .live).requireDrills(plan.drills.map(\.drillId))
        let ownerKey = plan.ownerKey
        let descriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        for old in (try? context.fetch(descriptor)) ?? [] {
            context.delete(old)
        }
        context.insert(UserActivePlan(planId: plan.id.uuidString, isCustom: true,
                                      ownerKey: ownerKey))
    }

    // MARK: - Private

    private static func isActiveCustomPlan(_ plan: CustomPlan, context: ModelContext) throws -> Bool {
        guard let active = try activeCustomPlan(context: context) else { return false }
        return active.id == plan.id
    }
}
