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
    /// 会话分类（契约 §5.3）："drill" 真实球台成绩 / "cognitive" 屏内认知测验 / "tool" 工具活跃度。
    /// 带默认值的新增属性，SwiftData 轻量迁移把旧库会话一律视为 "drill"。
    var kind: String = "drill"

    @Relationship(deleteRule: .cascade, inverse: \DrillEntry.session)
    var drillEntries: [DrillEntry]

    init(ballType: String = "chinese8", kind: String = "drill") {
        self.id = UUID()
        self.date = Date()
        self.ballType = ballType
        self.totalDurationMinutes = 0
        self.note = ""
        self.kind = kind
        self.drillEntries = []
    }
}
