import Foundation
import SwiftData

@Model
final class DrillEntry {
    var id: UUID
    var drillId: String
    var drillNameZh: String

    @Relationship(deleteRule: .cascade, inverse: \DrillSet.entry)
    var sets: [DrillSet]

    var session: TrainingSession?

    var successRate: Double {
        let total = sets.reduce(0) { $0 + $1.targetBalls }
        let made  = sets.reduce(0) { $0 + $1.madeBalls }
        return total > 0 ? Double(made) / Double(total) : 0
    }

    init(drillId: String, drillNameZh: String) {
        self.id = UUID()
        self.drillId = drillId
        self.drillNameZh = drillNameZh
        self.sets = []
    }
}
