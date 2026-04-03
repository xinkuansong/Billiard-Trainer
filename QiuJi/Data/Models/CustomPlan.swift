import Foundation
import SwiftData

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
