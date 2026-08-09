import Foundation
import SwiftData

/// V2 = 契约 §4.1 字段扩展后的形态（v29 W3）。当前形态见 `QiuJiSchemaV3`。
///
/// 这里的嵌套类型是**历史快照，禁止再修改**：`CustomPlan` / `CustomPlanDrill` 在 V3
/// 用 `roundsPerFormation` 取代了 `sets` / `ballsPerSet`（v31 W0，ADR-v31-01），
/// 故 V1 / V2 需要保留旧形状，迁移计划才能读到旧值做折算。
/// 未变更的模型（TrainingSession / DrillEntry / DrillSet / AngleTestResult / UserActivePlan /
/// DrillFavorite / SyncPendingItem）直接复用顶层类型，V2 与 V3 共享同一形状。
enum QiuJiSchemaV2: VersionedSchema {

    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TrainingSession.self,
            DrillEntry.self,
            DrillSet.self,
            AngleTestResult.self,
            UserActivePlan.self,
            DrillFavorite.self,
            SyncPendingItem.self,
            QiuJiSchemaV2.CustomPlan.self,
            QiuJiSchemaV2.CustomPlanDrill.self
        ]
    }

    @Model
    final class CustomPlan {
        var id: UUID
        var name: String
        var sessionsPerWeek: Int
        var createdAt: Date
        @Relationship(deleteRule: .cascade) var drills: [CustomPlanDrill]

        init(name: String, sessionsPerWeek: Int) {
            self.id = UUID()
            self.name = name
            self.sessionsPerWeek = sessionsPerWeek
            self.createdAt = Date()
            self.drills = []
        }
    }

    @Model
    final class CustomPlanDrill {
        var id: UUID
        var drillId: String
        var drillNameZh: String
        var sets: Int
        var ballsPerSet: Int
        var order: Int

        init(drillId: String, drillNameZh: String, sets: Int, ballsPerSet: Int, order: Int) {
            self.id = UUID()
            self.drillId = drillId
            self.drillNameZh = drillNameZh
            self.sets = sets
            self.ballsPerSet = ballsPerSet
            self.order = order
        }
    }
}
