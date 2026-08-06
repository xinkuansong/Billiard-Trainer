import Foundation
import SwiftData

@Model
final class DrillSet {
    var id: UUID
    var setNumber: Int
    var targetBalls: Int
    var madeBalls: Int
    /// 球形归属（契约 §4.1）。单球形 drill 与旧库为 nil。
    var formationToken: String?
    /// 球形显示名快照（契约 §6.5：写入即冻结）。
    var formationName: String?
    /// made/target 的单位语义（契约 §5.2）："球" | "局" | "次"，仅影响展示文案。
    /// 旧库组次一律按「球」计数，故默认 "球"。
    var unitLabel: String = "球"
    /// 达标线快照（契约 §5.5）。0/0 表示「未设定」。
    var passMade: Int = 0
    var passTotal: Int = 0
    /// 每组用时（契约 §8.7，此前采集后被丢弃）。旧库为 nil。
    var durationSeconds: Int?

    var entry: DrillEntry?

    init(setNumber: Int, targetBalls: Int, madeBalls: Int = 0,
         formationToken: String? = nil, formationName: String? = nil,
         unitLabel: String = "球", passMade: Int = 0, passTotal: Int = 0,
         durationSeconds: Int? = nil) {
        self.id = UUID()
        self.setNumber = setNumber
        self.targetBalls = targetBalls
        self.madeBalls = madeBalls
        self.formationToken = formationToken
        self.formationName = formationName
        self.unitLabel = unitLabel
        self.passMade = passMade
        self.passTotal = passTotal
        self.durationSeconds = durationSeconds
    }
}
