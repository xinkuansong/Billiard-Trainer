import Foundation
import SwiftData

@Model
final class AngleTestResult {
    var id: UUID
    var date: Date
    var actualAngle: Double
    var userAngle: Double
    var pocketType: String
    /// Quiz source: "table2D" (legacy default), "geometric", "scene2D", "scene3D",
    /// "aimPoint" / "aimPoint2D" / "aimPoint3D"（瞄准点训练家族，条 8–10）
    var quizType: String = "table2D"
    /// 瞄准点训练的有符号毫米误差（条 8.5：偏大为正、偏小为负）。
    /// 角度类测验恒为 0；带默认值的新增属性，SwiftData 轻量迁移自动兼容旧库。
    var errorMM: Double = 0

    var error: Double { abs(actualAngle - userAngle) }

    init(actualAngle: Double, userAngle: Double, pocketType: String,
         quizType: String = "table2D", errorMM: Double = 0) {
        self.id = UUID()
        self.date = Date()
        self.actualAngle = actualAngle
        self.userAngle = userAngle
        self.pocketType = pocketType
        self.quizType = quizType
        self.errorMM = errorMM
    }
}
