import Foundation
import SwiftData

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
