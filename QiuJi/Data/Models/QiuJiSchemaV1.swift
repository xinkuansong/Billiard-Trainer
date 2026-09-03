import Foundation
import SwiftData

/// V1 = 字段扩展（v29 W3）之前已发布的持久化形态。
///
/// 这里的嵌套类型是**历史快照，禁止再修改**：它们只用于声明 V1 的实体形状，
/// 使 `QiuJiMigrationPlan` 能从真实旧库轻量迁移到 V2，并让迁移测试可以构造真正的旧库。
/// 未变更的模型（UserActivePlan / DrillFavorite / SyncPendingItem）直接复用顶层类型；
/// `CustomPlan(Drill)` V1 与 V2 同形，复用 `QiuJiSchemaV2` 的历史快照（V3 才变形，见 ADR-v31-01）。
enum QiuJiSchemaV1: VersionedSchema {

    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TrainingSession.self,
            DrillEntry.self,
            DrillSet.self,
            AngleTestResult.self,
            QiuJiSchemaV3.UserActivePlan.self,
            QiuJiSchemaV3.DrillFavorite.self,
            QiuJiSchemaV3.SyncPendingItem.self,
            QiuJiSchemaV2.CustomPlan.self,
            QiuJiSchemaV2.CustomPlanDrill.self
        ]
    }

    @Model
    final class TrainingSession {
        var id: UUID
        var date: Date
        var ballType: String
        var totalDurationMinutes: Int
        var note: String
        var planId: String?

        @Relationship(deleteRule: .cascade, inverse: \DrillEntry.session)
        var drillEntries: [DrillEntry]

        init(ballType: String = "chinese8") {
            self.id = UUID()
            self.date = Date()
            self.ballType = ballType
            self.totalDurationMinutes = 0
            self.note = ""
            self.drillEntries = []
        }
    }

    @Model
    final class DrillEntry {
        var id: UUID
        var drillId: String
        var drillNameZh: String

        @Relationship(deleteRule: .cascade, inverse: \DrillSet.entry)
        var sets: [DrillSet]

        var session: TrainingSession?

        init(drillId: String, drillNameZh: String) {
            self.id = UUID()
            self.drillId = drillId
            self.drillNameZh = drillNameZh
            self.sets = []
        }
    }

    @Model
    final class DrillSet {
        var id: UUID
        var setNumber: Int
        var targetBalls: Int
        var madeBalls: Int

        var entry: DrillEntry?

        init(setNumber: Int, targetBalls: Int, madeBalls: Int = 0) {
            self.id = UUID()
            self.setNumber = setNumber
            self.targetBalls = targetBalls
            self.madeBalls = madeBalls
        }
    }

    @Model
    final class AngleTestResult {
        var id: UUID
        var date: Date
        var actualAngle: Double
        var userAngle: Double
        var pocketType: String
        var quizType: String = "table2D"
        var errorMM: Double = 0

        init(actualAngle: Double, userAngle: Double, pocketType: String,
             quizType: String = "table2D", errorMM: Double = 0) {
            self.id = UUID()
            self.date = Date()
            self.actualAngle = actualAngle
            self.userAngle = userAngle
            self.pocketType = pocketType
            self.quizType = quizType
            self.errorMM = errorMM
        }
    }
}
