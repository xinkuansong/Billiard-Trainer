import Foundation
import SwiftData

@Model
final class UserActivePlan {
    var id: UUID
    var planId: String
    var isCustom: Bool
    var startDate: Date
    var currentWeek: Int
    var currentDay: Int

    init(planId: String, isCustom: Bool = false) {
        self.id = UUID()
        self.planId = planId
        self.isCustom = isCustom
        self.startDate = Date()
        self.currentWeek = 1
        self.currentDay = 1
    }
}
