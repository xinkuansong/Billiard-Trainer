import Foundation
import SwiftData

@Model
final class AngleTestResult {
    var id: UUID
    var date: Date
    var actualAngle: Double
    var userAngle: Double
    var pocketType: String

    var error: Double { abs(actualAngle - userAngle) }

    init(actualAngle: Double, userAngle: Double, pocketType: String) {
        self.id = UUID()
        self.date = Date()
        self.actualAngle = actualAngle
        self.userAngle = userAngle
        self.pocketType = pocketType
    }
}
