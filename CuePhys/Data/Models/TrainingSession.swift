import Foundation
import SwiftData

@Model
final class TrainingSession {
    /// 本地数据归属：`guest:<deviceUUID>` 或 `account:<serverUserId>`。
    var ownerKey: String = OwnerKey.unassigned
    var id: UUID
    var date: Date
    var ballType: String
    var totalDurationMinutes: Int
    var note: String
    var planId: String?
    var scheduleItemId: UUID?
    var sourceKind: String?
    var sourceId: String?
    var sourceParentId: String?
    var sourceTitleSnapshot: String?
    var sourceSubtitleSnapshot: String?
    var sourcePayloadVersion: Int?
    var sourcePayloadSnapshot: Data?
    var progressRole: String?
    var lessonId: String?
    /// 会话分类（契约 §5.3）："drill" 真实球台成绩 / "cognitive" 屏内认知测验 / "tool" 工具活跃度。
    /// 带默认值的新增属性，SwiftData 轻量迁移把旧库会话一律视为 "drill"。
    var kind: String = "drill"

    @Relationship(deleteRule: .cascade, inverse: \DrillEntry.session)
    var drillEntries: [DrillEntry]

    init(
        ballType: String = "chinese8",
        kind: String = "drill",
        ownerKey: String = DeviceGuestIdentity.ownerKey()
    ) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.id = UUID()
        self.date = Date()
        self.ballType = ballType
        self.totalDurationMinutes = 0
        self.note = ""
        self.kind = kind
        self.drillEntries = []
    }
}

extension TrainingSession {
    /// V5 stores role and actual effect in one existing column to keep its schema hash stable.
    var frozenProgressRole: String? { progressRole?.split(separator: "|").first.map(String.init) }

    var appliedProgressEffect: String? {
        guard let raw = progressRole, let separator = raw.firstIndex(of: "|") else { return nil }
        return String(raw[raw.index(after: separator)...])
    }

    func setProgress(role: String, effect: String?) {
        progressRole = effect.map { "\(role)|\($0)" } ?? role
    }
}
