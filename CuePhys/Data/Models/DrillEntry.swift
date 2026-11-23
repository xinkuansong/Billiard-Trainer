import Foundation
import SwiftData

@Model
final class DrillEntry {
    var id: UUID
    var drillId: String
    var drillNameZh: String
    /// 训练内顺序（契约 §4.1）。旧库统一为 0，展示层此时仍按数组顺序。
    var orderIndex: Int = 0
    /// 该 drill 的训练心得（契约 §8.7，此前采集后被丢弃）。
    var note: String = ""
    /// 达标说明快照，人类可读（契约 §6.5：写入即冻结，展示层禁止回查当前内容）。
    var criteriaText: String = ""

    @Relationship(deleteRule: .cascade, inverse: \DrillSet.entry)
    var sets: [DrillSet]

    var session: TrainingSession?

    var successRate: Double {
        let total = sets.reduce(0) { $0 + $1.targetBalls }
        let made  = sets.reduce(0) { $0 + $1.madeBalls }
        return total > 0 ? Double(made) / Double(total) : 0
    }

    init(drillId: String, drillNameZh: String,
         orderIndex: Int = 0, note: String = "", criteriaText: String = "") {
        self.id = UUID()
        self.drillId = drillId
        self.drillNameZh = drillNameZh
        self.orderIndex = orderIndex
        self.note = note
        self.criteriaText = criteriaText
        self.sets = []
    }
}
