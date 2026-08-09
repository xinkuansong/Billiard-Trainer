import Foundation
import SwiftData

/// V3 = 自定义计划改存强度系数后的当前形态（v31 W0，ADR-v31-01）。
/// `CustomPlanDrill.sets` / `ballsPerSet` → `roundsPerFormation`；其余实体与 V2 同形。
enum QiuJiSchemaV3: VersionedSchema {

    static var versionIdentifier = Schema.Version(3, 0, 0)

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
        [QiuJiSchemaV1.self, QiuJiSchemaV2.self, QiuJiSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: QiuJiSchemaV1.self, toVersion: QiuJiSchemaV2.self),
            .custom(
                fromVersion: QiuJiSchemaV2.self,
                toVersion: QiuJiSchemaV3.self,
                willMigrate: CustomPlanDoseMigration.captureLegacyVolume,
                didMigrate: CustomPlanDoseMigration.applyRounds
            )
        ]
    }
}

/// V2 → V3 的值折算（ADR-v31-01）。
///
/// 不能用轻量迁移：`roundsPerFormation` 的值要由旧 `sets` 与该 drill 的球形数算出，
/// 而旧列在 V3 形态里已不存在。故 `willMigrate` 先把折算结果按行 id 记下，
/// `didMigrate` 再写回新列。折算规则见契约 §6.6：`rounds = max(1, sets / 球形数)`，
/// 无球形声明按 1 球形算（即 rounds = sets）。
enum CustomPlanDoseMigration {

    /// 行 id → 折算后的轮数。仅在一次迁移的 will/did 之间存活。
    nonisolated(unsafe) private static var pendingRounds: [UUID: Int] = [:]

    static func captureLegacyVolume(context: ModelContext) throws {
        pendingRounds = [:]
        let legacyDrills = try context.fetch(FetchDescriptor<QiuJiSchemaV2.CustomPlanDrill>())
        for drill in legacyDrills {
            let formationCount = max(1, DrillContentService.formationCount(forDrillId: drill.drillId))
            pendingRounds[drill.id] = max(1, drill.sets / formationCount)
        }
    }

    static func applyRounds(context: ModelContext) throws {
        defer { pendingRounds = [:] }
        guard !pendingRounds.isEmpty else { return }
        let migrated = try context.fetch(FetchDescriptor<CustomPlanDrill>())
        for drill in migrated {
            guard let rounds = pendingRounds[drill.id] else { continue }
            drill.roundsPerFormation = rounds
        }
        try context.save()
    }
}
