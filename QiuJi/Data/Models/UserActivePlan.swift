import Foundation
import SwiftData

@Model
final class UserActivePlan {
    var ownerKey: String = OwnerKey.unassigned
    var id: UUID
    var planId: String
    var isCustom: Bool
    var startDate: Date
    var currentWeek: Int
    var currentDay: Int
    var currentLessonId: String?
    var status: String = "active"
    var updatedAt: Date = Date()
    var completedAt: Date?
    /// 0 = legacy V4 row awaiting v54 normalization; 1 = official-mainline semantics.
    var migrationVersion: Int = 0

    init(planId: String, isCustom: Bool = false,
         ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.id = UUID()
        self.planId = planId
        self.isCustom = isCustom
        self.startDate = Date()
        self.currentWeek = 1
        self.currentDay = 1
        self.currentLessonId = nil
        self.status = "active"
        self.updatedAt = self.startDate
        self.migrationVersion = 1
    }
}
