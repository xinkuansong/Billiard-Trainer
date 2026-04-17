import Foundation
import SwiftData

@Model
final class AngleTestResult {
    var id: UUID
    var date: Date
    var actualAngle: Double
    var userAngle: Double
    var pocketType: String
    /// Quiz source: "table2D" (legacy default), "geometric", "scene2D", "scene3D"
    var quizType: String = "table2D"

    var error: Double { abs(actualAngle - userAngle) }

    init(actualAngle: Double, userAngle: Double, pocketType: String, quizType: String = "table2D") {
        self.id = UUID()
        self.date = Date()
        self.actualAngle = actualAngle
        self.userAngle = userAngle
        self.pocketType = pocketType
        self.quizType = quizType
    }
}
