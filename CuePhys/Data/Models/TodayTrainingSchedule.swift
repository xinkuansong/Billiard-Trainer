import Foundation
import SwiftData

enum TodayScheduleSourceKind {
    static let officialLesson = "officialLesson"
    static let template = "template"
    static let libraryDrill = "libraryDrill"
}

enum TodayScheduleProgressRole {
    static let review = "review"
    static let advanceEligible = "advanceEligible"
    static let preview = "preview"
    static let neutral = "neutral"
}

enum TodayScheduleItemState {
    static let pending = "pending"
    static let inProgress = "inProgress"
    static let completed = "completed"
    static let abandoned = "abandoned"
}

@Model
final class TodayTrainingSchedule {
    var ownerKey: String = OwnerKey.unassigned
    var id: UUID
    var localDayKey: String
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TodayScheduleItem.schedule)
    var items: [TodayScheduleItem]

    init(
        ownerKey: String = DeviceGuestIdentity.ownerKey(),
        localDayKey: String,
        calendarIdentifier: String = "gregorian",
        timeZoneIdentifier: String = TimeZone.current.identifier,
        createdAt: Date = Date()
    ) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.id = UUID()
        self.localDayKey = localDayKey
        self.calendarIdentifier = calendarIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.items = []
    }
}

@Model
final class TodayScheduleItem {
    var id: UUID
    var orderIndex: Int
    var sourceKind: String
    var sourceId: String
    var sourceParentId: String?
    var sourceTitleSnapshot: String
    var sourceSubtitleSnapshot: String?
    var payloadVersion: Int
    var payloadSnapshot: Data
    var progressRole: String
    var planId: String?
    var lessonId: String?
    var state: String
    var startedAt: Date?
    var completedAt: Date?
    var trainingSessionId: UUID?
    var createdAt: Date
    /// Stable key used only by one-time migrations so interrupted normalization is replay-safe.
    var migrationKey: String?
    var schedule: TodayTrainingSchedule?

    init(
        orderIndex: Int,
        sourceKind: String,
        sourceId: String,
        sourceParentId: String? = nil,
        sourceTitleSnapshot: String,
        sourceSubtitleSnapshot: String? = nil,
        payloadVersion: Int = 1,
        payloadSnapshot: Data,
        progressRole: String,
        planId: String? = nil,
        lessonId: String? = nil,
        state: String = TodayScheduleItemState.pending,
        createdAt: Date = Date(),
        migrationKey: String? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.sourceKind = sourceKind
        self.sourceId = sourceId
        self.sourceParentId = sourceParentId
        self.sourceTitleSnapshot = sourceTitleSnapshot
        self.sourceSubtitleSnapshot = sourceSubtitleSnapshot
        self.payloadVersion = payloadVersion
        self.payloadSnapshot = payloadSnapshot
        self.progressRole = progressRole
        self.planId = planId
        self.lessonId = lessonId
        self.state = state
        self.createdAt = createdAt
        self.migrationKey = migrationKey
    }
}
