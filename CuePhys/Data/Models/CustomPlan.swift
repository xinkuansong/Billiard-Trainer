import Foundation
import SwiftData

@Model
final class CustomPlan {
    var ownerKey: String = OwnerKey.unassigned
    var id: UUID
    var name: String
    var sessionsPerWeek: Int
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var drills: [CustomPlanDrill]

    init(name: String, sessionsPerWeek: Int,
         ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
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
    /// 强度系数：每个球形练多少轮（v31 R4，schema V3）。
    /// 实际球数不再存在计划里，训练激活时由 drill 内容的 `sets.perFormation` 解析。
    /// 默认值 1 同时是 V2→V3 迁移的存储默认值。
    @Attribute(originalName: "sets")
    var roundsPerFormation: Int = 1
    var order: Int

    init(drillId: String, drillNameZh: String, roundsPerFormation: Int, order: Int) {
        self.id = UUID()
        self.drillId = drillId
        self.drillNameZh = drillNameZh
        self.roundsPerFormation = roundsPerFormation
        self.order = order
    }
}
