import Foundation
import SwiftData

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
        context: ModelContext
    ) throws -> AddResult {
        let appearsInToday = try isActiveCustomPlan(plan, context: context)
        if planContainsDrill(plan, drillId: drill.id) {
            return .alreadyPresent(planName: plan.name, appearsInToday: appearsInToday)
        }

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
        context: ModelContext
    ) throws -> (plan: CustomPlan, result: AddResult) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyName }

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
            try activate(plan: plan, context: context)
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
    static func activate(plan: CustomPlan, context: ModelContext) throws {
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
