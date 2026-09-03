import Foundation
import SwiftData

/// 自定义计划的一条动作。用户只调**遍数倍数**（强度系数），球数由 drill 内容派生（契约 §6.6 / v34 R9）。
struct CustomDrillItem: Identifiable {
    let id: UUID
    let drillId: String
    let nameZh: String
    let category: String
    /// 录入单位（契约 §5.2），派生自内容。
    let unitLabel: String
    /// 遍数倍数 —— 落 `CustomPlanDrill.roundsPerFormation`（v34 R9：整套完整剂量 × N）。
    var rounds: Int
    /// 按当前遍数展开后的逐球形剂量块（只读派生值，来自 drill 内容）。
    var groups: [ResolvedDose.Group]
    /// 展示文案，口径同今日安排（`ResolvedDose.volumeText`）。
    var volumeText: String

    var resolved: ResolvedDose { ResolvedDose(groups: groups) }
    /// 组数（展开后的 plannedSets 条数）。
    var setCount: Int { resolved.totalRounds }
    var totalBalls: Int { resolved.totalBalls }
    var plannedSets: [PlannedTrainingSet] { resolved.plannedSets }

    init(
        id: UUID = UUID(),
        drillId: String,
        nameZh: String,
        category: String,
        unitLabel: String,
        rounds: Int,
        groups: [ResolvedDose.Group],
        volumeText: String
    ) {
        self.id = id
        self.drillId = drillId
        self.nameZh = nameZh
        self.category = category
        self.unitLabel = unitLabel
        self.rounds = rounds
        self.groups = groups
        self.volumeText = volumeText
    }
}

@MainActor
final class CustomPlanBuilderViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var drillItems: [CustomDrillItem] = []
    @Published var showDrillPicker = false
    @Published var saveError: String?

    /// D-v43-3：周次不再暴露给 UI；落库冻写 1，仅供内部进位。
    private static let frozenSessionsPerWeek = 1

    let editingPlanId: UUID?

    var isEditing: Bool { editingPlanId != nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !drillItems.isEmpty
    }

    var totalSetsCount: Int {
        drillItems.reduce(0) { $0 + $1.setCount }
    }

    var totalBallsCount: Int {
        drillItems.reduce(0) { $0 + $1.totalBalls }
    }

    init(editingPlanId: UUID? = nil) {
        self.editingPlanId = editingPlanId
    }

    func loadExistingPlan(context: ModelContext) {
        guard let planId = editingPlanId else { return }
        let ownerKey = CurrentOwnerContext.shared.ownerKey
        let descriptor = FetchDescriptor<CustomPlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == planId }
        )
        guard let plan = try? context.fetch(descriptor).first else { return }

        name = plan.name
        drillItems = plan.drills
            .sorted { $0.order < $1.order }
            .map { drill in
                // 球数不再存库（schema V3）：按 drill 完整剂量 × 遍数派生（契约 §6.6 / v34 R9）。
                Self.makeItem(
                    drillId: drill.drillId,
                    nameZh: drill.drillNameZh,
                    content: DrillContentService.decodeDrillFromBundle(id: drill.drillId),
                    rounds: drill.roundsPerFormation
                )
            }
    }

    func addDrill(_ content: DrillContent) {
        guard !drillItems.contains(where: { $0.drillId == content.id }) else { return }
        // 默认遍数 = 1（完整剂量，位置全覆盖）。
        drillItems.append(Self.makeItem(
            drillId: content.id,
            nameZh: content.nameZh,
            content: content,
            rounds: 1
        ))
    }

    /// 遍数倍数 → 组序列的唯一派生入口（内容缺失时回落到汇总兜底，见 `TrainingDoseResolver`）。
    static func makeItem(
        id: UUID = UUID(),
        drillId: String,
        nameZh: String,
        content: DrillContent?,
        rounds: Int
    ) -> CustomDrillItem {
        let clamped = clampRounds(rounds)
        let unitLabel = DrillUnitLabel.label(category: content?.category ?? "",
                                             subcategory: content?.subcategory ?? "")
        let resolved = TrainingDoseResolver.resolve(
            content: content,
            dose: PlanDrillDose(roundsPerFormation: clamped)
        )
        return CustomDrillItem(
            id: id,
            drillId: drillId,
            nameZh: nameZh,
            category: content?.category ?? "",
            unitLabel: unitLabel,
            rounds: clamped,
            groups: resolved.groups,
            volumeText: resolved.volumeText(unitLabel: unitLabel)
        )
    }

    static func clampRounds(_ rounds: Int) -> Int { max(1, min(rounds, 20)) }

    func removeDrills(at offsets: IndexSet) {
        drillItems.remove(atOffsets: offsets)
    }

    func removeDrill(at index: Int) {
        guard index >= 0, index < drillItems.count else { return }
        drillItems.remove(at: index)
    }

    /// Picker toggle deselect — remove first row matching content id.
    func removeDrill(drillId: String) {
        guard let index = drillItems.firstIndex(where: { $0.drillId == drillId }) else { return }
        drillItems.remove(at: index)
    }

    func moveDrills(from source: IndexSet, to destination: Int) {
        drillItems.move(fromOffsets: source, toOffset: destination)
    }

    /// 只调遍数倍数（v34 R9：计划存倍数，球数改内容真源 × 倍数派生）。
    func updateRounds(for itemId: UUID, rounds: Int) {
        guard let idx = drillItems.firstIndex(where: { $0.id == itemId }) else { return }
        updateRounds(at: idx, rounds: rounds)
    }

    func updateRounds(at index: Int, rounds: Int) {
        guard index >= 0, index < drillItems.count else { return }
        let item = drillItems[index]
        drillItems[index] = Self.makeItem(
            id: item.id,
            drillId: item.drillId,
            nameZh: item.nameZh,
            content: DrillContentService.decodeDrillFromBundle(id: item.drillId),
            rounds: rounds
        )
    }

    /// Saves plan and returns the saved plan's UUID for activation, or nil on failure.
    func save(context: ModelContext) -> UUID? {
        saveError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !drillItems.isEmpty else {
            saveError = "请填写模版名称并至少添加一个训练项目"
            return nil
        }

        do {
            let ownerKey = CurrentOwnerContext.shared.ownerKey
            if let existingId = editingPlanId {
                let descriptor = FetchDescriptor<CustomPlan>(
                    predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == existingId }
                )
                if let existing = try context.fetch(descriptor).first {
                    existing.name = trimmedName
                    existing.sessionsPerWeek = Self.frozenSessionsPerWeek
                    for drill in existing.drills {
                        context.delete(drill)
                    }
                    existing.drills = buildDrillModels()
                    try context.save()
                    return existing.id
                }
            }

            let plan = CustomPlan(name: trimmedName,
                                  sessionsPerWeek: Self.frozenSessionsPerWeek,
                                  ownerKey: ownerKey)
            plan.drills = buildDrillModels()
            context.insert(plan)
            try context.save()
            return plan.id
        } catch {
            saveError = "保存失败，请确认设备存储空间充足后重试"
            return nil
        }
    }

    func activate(planId: UUID, context: ModelContext) throws {
        saveError = nil
        do {
            let ownerKey = CurrentOwnerContext.shared.ownerKey
            let descriptor = FetchDescriptor<CustomPlan>(
                predicate: #Predicate { $0.ownerKey == ownerKey && $0.id == planId }
            )
            guard let plan = try context.fetch(descriptor).first else {
                throw DrillTrainingPlanService.ServiceError.planNotFound
            }
            try DrillTrainingPlanService.activate(plan: plan, context: context)
            try context.save()
        } catch {
            if saveError == nil {
                saveError = "保存失败，请确认设备存储空间充足后重试"
            }
            throw error
        }
    }

    private func buildDrillModels() -> [CustomPlanDrill] {
        drillItems.enumerated().map { index, item in
            CustomPlanDrill(
                drillId: item.drillId,
                drillNameZh: item.nameZh,
                roundsPerFormation: item.rounds,
                order: index
            )
        }
    }
}
