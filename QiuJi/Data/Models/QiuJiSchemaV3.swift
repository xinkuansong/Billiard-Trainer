import Foundation
import SwiftData
import SQLite3

/// V3 = 自定义计划改存强度系数后的历史快照（v31 W0，ADR-v31-01）。
/// 嵌套类型禁止再改；V4 起顶层实体增加 ownerKey。
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

    @Model
    final class TrainingSession {
        var id: UUID
        var date: Date
        var ballType: String
        var totalDurationMinutes: Int
        var note: String
        var planId: String?
        var kind: String = "drill"
        @Relationship(deleteRule: .cascade, inverse: \DrillEntry.session)
        var drillEntries: [DrillEntry]

        init(ballType: String = "chinese8", kind: String = "drill") {
            id = UUID()
            date = Date()
            self.ballType = ballType
            totalDurationMinutes = 0
            note = ""
            self.kind = kind
            drillEntries = []
        }
    }

    @Model
    final class DrillEntry {
        var id: UUID
        var drillId: String
        var drillNameZh: String
        var orderIndex: Int = 0
        var note: String = ""
        var criteriaText: String = ""
        @Relationship(deleteRule: .cascade, inverse: \DrillSet.entry)
        var sets: [DrillSet]
        var session: TrainingSession?

        init(drillId: String, drillNameZh: String) {
            id = UUID()
            self.drillId = drillId
            self.drillNameZh = drillNameZh
            sets = []
        }
    }

    @Model
    final class DrillSet {
        var id: UUID
        var setNumber: Int
        var targetBalls: Int
        var madeBalls: Int
        var formationToken: String?
        var formationName: String?
        var unitLabel: String = "球"
        var passMade: Int = 0
        var passTotal: Int = 0
        var durationSeconds: Int?
        var entry: DrillEntry?

        init(setNumber: Int, targetBalls: Int, madeBalls: Int = 0) {
            id = UUID()
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
        var sessionId: UUID?

        init(actualAngle: Double, userAngle: Double, pocketType: String) {
            id = UUID()
            date = Date()
            self.actualAngle = actualAngle
            self.userAngle = userAngle
            self.pocketType = pocketType
        }
    }

    @Model
    final class UserActivePlan {
        var id: UUID
        var planId: String
        var isCustom: Bool
        var startDate: Date
        var currentWeek: Int
        var currentDay: Int

        init(planId: String, isCustom: Bool = false) {
            id = UUID()
            self.planId = planId
            self.isCustom = isCustom
            startDate = Date()
            currentWeek = 1
            currentDay = 1
        }
    }

    @Model
    final class DrillFavorite {
        var drillId: String
        var addedAt: Date

        init(drillId: String) {
            self.drillId = drillId
            addedAt = Date()
        }
    }

    @Model
    final class SyncPendingItem {
        var id: UUID
        var entityType: String
        var entityId: UUID
        var operation: String
        var createdAt: Date

        init(entityType: String, entityId: UUID, operation: String) {
            id = UUID()
            self.entityType = entityType
            self.entityId = entityId
            self.operation = operation
            createdAt = Date()
        }
    }

    @Model
    final class CustomPlan {
        var id: UUID
        var name: String
        var sessionsPerWeek: Int
        var createdAt: Date
        @Relationship(deleteRule: .cascade) var drills: [CustomPlanDrill]

        init(name: String, sessionsPerWeek: Int) {
            id = UUID()
            self.name = name
            self.sessionsPerWeek = sessionsPerWeek
            createdAt = Date()
            drills = []
        }
    }

    @Model
    final class CustomPlanDrill {
        var id: UUID
        var drillId: String
        var drillNameZh: String
        @Attribute(originalName: "sets")
        var roundsPerFormation: Int = 1
        var order: Int

        init(drillId: String, drillNameZh: String, roundsPerFormation: Int, order: Int) {
            id = UUID()
            self.drillId = drillId
            self.drillNameZh = drillNameZh
            self.roundsPerFormation = roundsPerFormation
            self.order = order
        }
    }
}

enum QiuJiMigrationPlan: SchemaMigrationPlan {

    static var schemas: [any VersionedSchema.Type] {
        [QiuJiSchemaV1.self, QiuJiSchemaV2.self, QiuJiSchemaV3.self,
         QiuJiSchemaV4.self, QiuJiSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: QiuJiSchemaV1.self, toVersion: QiuJiSchemaV2.self),
            .lightweight(fromVersion: QiuJiSchemaV2.self, toVersion: QiuJiSchemaV3.self),
            .lightweight(fromVersion: QiuJiSchemaV3.self, toVersion: QiuJiSchemaV4.self),
            .lightweight(fromVersion: QiuJiSchemaV4.self, toVersion: QiuJiSchemaV5.self)
        ]
    }
}

/// V2 → V3 的值折算（ADR-v31-01）。
///
/// 不能只靠轻量迁移完成值折算：`roundsPerFormation` 要由旧 `sets` 与该 drill 的
/// 历史球形数算出。V3 的 `roundsPerFormation` 先通过轻量迁移中的
/// `@Attribute(originalName: "sets")` 继承旧值。iOS 17 的 custom migration 回调中
/// 目标对象写入不会可靠落盘，因此 `ModelContainerFactory` 在容器正常打开后，以迁移前
/// 物理列为一次性判据执行折算。这样不依赖 Bundle 或 Runtime 回调差异。规则见契约 §6.6：
/// `rounds = max(1, sets / 球形数)`，
/// 无球形声明按 1 球形算（即 rounds = sets）。
enum CustomPlanDoseMigration {

    /// V2 → V3 发布时的球形数快照。迁移必须能在 App Bundle 尚不可访问的 iOS 17
    /// migration process 中完成，也不能随以后动作上下架或球形调整而改变历史折算。
    /// 只列多球形动作；其余（含未知/已退役但当时为单球形的动作）均按 1。
    private static let multipleFormationCounts: [String: Int] = [
        "drill_c003": 2, "drill_c004": 2, "drill_c006": 2,
        "drill_c013": 2, "drill_c022": 2, "drill_c024": 2,
        "drill_c025": 2, "drill_c026": 3, "drill_c042": 2,
        "drill_c053": 2, "drill_c056": 3, "drill_c057": 3,
        "drill_c058": 2, "drill_c069": 2, "drill_c071": 2,
        "drill_c073": 2, "drill_c074": 2, "drill_c075": 3,
        "drill_c076": 2
    ]

    static func legacyFormationCount(forDrillId id: String) -> Int {
        multipleFormationCounts[id] ?? 1
    }

    /// 必须在打开当前容器前调用；V2 有 ZSETS 而 V3 已重命名为 ZROUNDSPERFORMATION。
    static func storeNeedsNormalization(at storeURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return false }
        var database: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return false
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA table_info(ZCUSTOMPLANDRILL)", -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        var columns: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let rawName = sqlite3_column_text(statement, 1) {
                columns.insert(String(cString: rawName).uppercased())
            }
        }
        return columns.contains("ZSETS") && !columns.contains("ZROUNDSPERFORMATION")
    }

    static func normalizeMigratedVolume(in container: ModelContainer) throws {
        let context = ModelContext(container)
        let migratedDrills = try context.fetch(FetchDescriptor<CustomPlanDrill>())
        for drill in migratedDrills {
            let formationCount = legacyFormationCount(forDrillId: drill.drillId)
            drill.roundsPerFormation = max(1, drill.roundsPerFormation / formationCount)
        }
        try context.save()
    }
}
