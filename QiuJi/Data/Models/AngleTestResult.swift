import Foundation
import SwiftData

@Model
final class AngleTestResult {
    var ownerKey: String = OwnerKey.unassigned
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
    /// 归属的 `kind="cognitive"` 会话 id（契约 §4.1/§5.3）。历史数据为 nil，W5 一次性回填。
    var sessionId: UUID?
    /// v2 scene training contract; nil means legacy/unknown, never independent.
    var trainingMetadataJSON: String?

    var trainingMetadata: SceneTrainingMetadata? {
        guard let data = trainingMetadataJSON?.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SceneTrainingMetadata.self, from: data)
    }
    var isFirstAnswer: Bool { trainingMetadata?.firstAttempt ?? true }
    var measurementError: Double? {
        if let metadata = trainingMetadata, metadata.unit == "mm" { return metadata.score?.millimetres.map(abs) }
        return quizType.hasPrefix("aimPoint") ? abs(errorMM) : error
    }
    var measurementUnit: String { quizType.hasPrefix("aimPoint") ? "mm" : "°" }
    var measurementThreshold: Double { measurementUnit == "mm" ? 2 : 3 }
    var cohort: String {
        let version = trainingMetadata?.scoringVersion ?? "legacy"
        let mode = trainingMetadata.map { $0.firstAttempt ? ($0.independent ? "独立" : "辅助") : "复练" } ?? "辅助状态未知"
        return quizType + " · " + version + " · " + mode
    }
    var error: Double { abs(actualAngle - userAngle) }

    init(actualAngle: Double, userAngle: Double, pocketType: String,
         quizType: String = "table2D", errorMM: Double = 0, sessionId: UUID? = nil,
         ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.id = UUID()
        self.date = Date()
        self.actualAngle = actualAngle
        self.userAngle = userAngle
        self.pocketType = pocketType
        self.quizType = quizType
        self.errorMM = errorMM
        self.sessionId = sessionId
    }
}
