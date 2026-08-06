import Foundation
import SwiftData

/// V2 = 契约 §4.1 字段扩展后的当前形态（v29 W3）。
/// 新增字段全部可选或带默认值，故 V1 → V2 为轻量迁移，旧库数据原地保留。
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
            CustomPlan.self,
            CustomPlanDrill.self
        ]
    }
}

enum QiuJiMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [QiuJiSchemaV1.self, QiuJiSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: QiuJiSchemaV1.self, toVersion: QiuJiSchemaV2.self)]
    }
}
