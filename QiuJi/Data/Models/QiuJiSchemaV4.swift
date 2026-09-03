import Foundation
import SwiftData

/// V4 = 六类顶层用户数据增加非空 ownerKey 的历史快照（v53 W2）。
/// 这些嵌套类型是已经发布的持久化形态，禁止再跟随当前顶层 model 改动。
enum QiuJiSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [TrainingSession.self, DrillEntry.self, DrillSet.self, AngleTestResult.self,
         UserActivePlan.self, DrillFavorite.self, SyncPendingItem.self,
         CustomPlan.self, CustomPlanDrill.self]
    }

    @Model final class TrainingSession {
        var ownerKey: String = OwnerKey.unassigned
        var id: UUID
        var date: Date
        var ballType: String
        var totalDurationMinutes: Int
        var note: String
        var planId: String?
        var kind: String = "drill"
        @Relationship(deleteRule: .cascade, inverse: \DrillEntry.session)
        var drillEntries: [DrillEntry]

        init(ballType: String = "chinese8", kind: String = "drill",
             ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey
            id = UUID(); date = Date(); self.ballType = ballType
            totalDurationMinutes = 0; note = ""; self.kind = kind; drillEntries = []
        }
    }

    @Model final class DrillEntry {
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
            id = UUID(); self.drillId = drillId; self.drillNameZh = drillNameZh; sets = []
        }
    }

    @Model final class DrillSet {
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
            id = UUID(); self.setNumber = setNumber
            self.targetBalls = targetBalls; self.madeBalls = madeBalls
        }
    }

    @Model final class AngleTestResult {
        var ownerKey: String = OwnerKey.unassigned
        var id: UUID
        var date: Date
        var actualAngle: Double
        var userAngle: Double
        var pocketType: String
        var quizType: String = "table2D"
        var errorMM: Double = 0
        var sessionId: UUID?

        init(actualAngle: Double, userAngle: Double, pocketType: String,
             ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey; id = UUID(); date = Date()
            self.actualAngle = actualAngle; self.userAngle = userAngle
            self.pocketType = pocketType
        }
    }

    @Model final class UserActivePlan {
        var ownerKey: String = OwnerKey.unassigned
        var id: UUID
        var planId: String
        var isCustom: Bool
        var startDate: Date
        var currentWeek: Int
        var currentDay: Int

        init(planId: String, isCustom: Bool = false,
             ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey; id = UUID(); self.planId = planId
            self.isCustom = isCustom; startDate = Date(); currentWeek = 1; currentDay = 1
        }
    }

    @Model final class DrillFavorite {
        var ownerKey: String = OwnerKey.unassigned
        var drillId: String
        var addedAt: Date

        init(drillId: String, ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey; self.drillId = drillId; addedAt = Date()
        }
    }

    @Model final class SyncPendingItem {
        var ownerKey: String = OwnerKey.unassigned
        var id: UUID
        var entityType: String
        var entityId: UUID
        var operation: String
        var createdAt: Date

        init(entityType: String, entityId: UUID, operation: String,
             ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey; id = UUID(); self.entityType = entityType
            self.entityId = entityId; self.operation = operation; createdAt = Date()
        }
    }

    @Model final class CustomPlan {
        var ownerKey: String = OwnerKey.unassigned
        var id: UUID
        var name: String
        var sessionsPerWeek: Int
        var createdAt: Date
        @Relationship(deleteRule: .cascade) var drills: [CustomPlanDrill]

        init(name: String, sessionsPerWeek: Int,
             ownerKey: String = OwnerKey.unassigned) {
            self.ownerKey = ownerKey; id = UUID(); self.name = name
            self.sessionsPerWeek = sessionsPerWeek; createdAt = Date(); drills = []
        }
    }

    @Model final class CustomPlanDrill {
        var id: UUID
        var drillId: String
        var drillNameZh: String
        @Attribute(originalName: "sets") var roundsPerFormation: Int = 1
        var order: Int

        init(drillId: String, drillNameZh: String, roundsPerFormation: Int, order: Int) {
            id = UUID(); self.drillId = drillId; self.drillNameZh = drillNameZh
            self.roundsPerFormation = roundsPerFormation; self.order = order
        }
    }
}

/// V3→V4 轻量迁移先把新增字段写为 sentinel；容器打开后再统一归到稳定游客 owner。
/// 始终扫描而不是只看 schema 版本，可修复一次迁移后、归属保存前异常退出的半成品库。
enum OwnerV4Migration {
    static func normalizeUnassigned(in container: ModelContainer, guestOwnerKey: String) throws {
        precondition(!guestOwnerKey.isEmpty && guestOwnerKey != OwnerKey.unassigned)
        let context = ModelContext(container)

        do {
            for value in try context.fetch(FetchDescriptor<TrainingSession>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            for value in try context.fetch(FetchDescriptor<AngleTestResult>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            for value in try context.fetch(FetchDescriptor<DrillFavorite>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            for value in try context.fetch(FetchDescriptor<UserActivePlan>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            for value in try context.fetch(FetchDescriptor<CustomPlan>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            for value in try context.fetch(FetchDescriptor<SyncPendingItem>())
                where value.ownerKey.isEmpty || value.ownerKey == OwnerKey.unassigned {
                value.ownerKey = guestOwnerKey
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }
}
