import Foundation
import SwiftData

struct CustomDrillItem: Identifiable {
    let id = UUID()
    let drillId: String
    let nameZh: String
    let category: String
    var sets: Int
    var ballsPerSet: Int
}

@MainActor
final class CustomPlanBuilderViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var sessionsPerWeek: Int = 3
    @Published var drillItems: [CustomDrillItem] = []
    @Published var showDrillPicker = false
    @Published var saveError: String?

    let editingPlanId: UUID?

    var isEditing: Bool { editingPlanId != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !drillItems.isEmpty
    }

    var totalSetsCount: Int {
        drillItems.reduce(0) { $0 + $1.sets }
    }

    var totalBallsCount: Int {
        drillItems.reduce(0) { $0 + ($1.sets * $1.ballsPerSet) }
    }

    init(editingPlanId: UUID? = nil) {
        self.editingPlanId = editingPlanId
    }

    func loadExistingPlan(context: ModelContext) {
        guard let planId = editingPlanId else { return }
        let descriptor = FetchDescriptor<CustomPlan>(
            predicate: #Predicate { $0.id == planId }
        )
        guard let plan = try? context.fetch(descriptor).first else { return }

        name = plan.name
        sessionsPerWeek = plan.sessionsPerWeek
        drillItems = plan.drills
            .sorted { $0.order < $1.order }
            .map { CustomDrillItem(
                drillId: $0.drillId,
                nameZh: $0.drillNameZh,
                category: "",
                sets: $0.sets,
                ballsPerSet: $0.ballsPerSet
            )}
    }

    func addDrill(_ content: DrillContent) {
        let item = CustomDrillItem(
            drillId: content.id,
            nameZh: content.nameZh,
            category: content.category,
            sets: content.sets.defaultSets,
            ballsPerSet: content.sets.defaultBallsPerSet
        )
        drillItems.append(item)
    }

    func removeDrills(at offsets: IndexSet) {
        drillItems.remove(atOffsets: offsets)
    }

    func removeDrill(at index: Int) {
        guard index >= 0, index < drillItems.count else { return }
        drillItems.remove(at: index)
    }

    func moveDrills(from source: IndexSet, to destination: Int) {
        drillItems.move(fromOffsets: source, toOffset: destination)
    }

    func updateSets(for itemId: UUID, sets: Int) {
        guard let idx = drillItems.firstIndex(where: { $0.id == itemId }) else { return }
        drillItems[idx].sets = max(1, min(sets, 20))
    }

    func updateBallsPerSet(for itemId: UUID, balls: Int) {
        guard let idx = drillItems.firstIndex(where: { $0.id == itemId }) else { return }
        drillItems[idx].ballsPerSet = max(1, min(balls, 50))
    }

    func updateDrillSettings(at index: Int, sets: Int, ballsPerSet: Int) {
        guard index >= 0, index < drillItems.count else { return }
        drillItems[index].sets = max(1, min(sets, 20))
        drillItems[index].ballsPerSet = max(1, min(ballsPerSet, 50))
    }

    /// Saves plan and returns the saved plan's UUID for activation, or nil on failure.
    func save(context: ModelContext) -> UUID? {
        saveError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !drillItems.isEmpty else {
            saveError = "请填写计划名称并至少添加一个训练项目"
            return nil
        }

        do {
            if let existingId = editingPlanId {
                let descriptor = FetchDescriptor<CustomPlan>(
                    predicate: #Predicate { $0.id == existingId }
                )
                if let existing = try context.fetch(descriptor).first {
                    existing.name = trimmedName
                    existing.sessionsPerWeek = sessionsPerWeek
                    for drill in existing.drills {
                        context.delete(drill)
                    }
                    existing.drills = buildDrillModels()
                    try context.save()
                    return existing.id
                }
            }

            let plan = CustomPlan(name: trimmedName, sessionsPerWeek: sessionsPerWeek)
            plan.drills = buildDrillModels()
            context.insert(plan)
            try context.save()
            return plan.id
        } catch {
            saveError = "保存失败，请确认设备存储空间充足后重试"
            return nil
        }
    }

    func activate(planId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<UserActivePlan>()
        if let existing = try? context.fetch(descriptor) {
            for old in existing { context.delete(old) }
        }
        let active = UserActivePlan(planId: planId.uuidString, isCustom: true)
        context.insert(active)
        try? context.save()
    }

    private func buildDrillModels() -> [CustomPlanDrill] {
        drillItems.enumerated().map { index, item in
            CustomPlanDrill(
                drillId: item.drillId,
                drillNameZh: item.nameZh,
                sets: item.sets,
                ballsPerSet: item.ballsPerSet,
                order: index
            )
        }
    }
}
