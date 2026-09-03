import Foundation
import SwiftData

/// 顶层用户数据的 owner 事务。关系子树随父对象继承归属。
@MainActor
final class OwnerTransferService {
    enum QueuePolicy {
        case transfer
        case discardSource
    }

    struct Result: Equatable {
        var sessions = 0
        var angleTests = 0
        var favorites = 0
        var activePlans = 0
        var customPlans = 0
        var queueItems = 0
        var schedules = 0

        var total: Int {
            sessions + angleTests + favorites + activePlans + customPlans + queueItems + schedules
        }
    }

    typealias SaveAction = @MainActor (ModelContext) throws -> Void

    private let context: ModelContext
    private let saveAction: SaveAction

    init(context: ModelContext,
         saveAction: @escaping SaveAction = { try $0.save() }) {
        self.context = context
        self.saveAction = saveAction
    }

    func hasOwnedData(ownerKey: String) throws -> Bool {
        try !sessions(ownerKey).isEmpty
            || !angleTests(ownerKey).isEmpty
            || !favorites(ownerKey).isEmpty
            || !activePlans(ownerKey).isEmpty
            || !customPlans(ownerKey).isEmpty
            || !queueItems(ownerKey).isEmpty
            || !schedules(ownerKey).isEmpty
    }

    /// 同一 from→to 可重复调用；第二次没有 source 数据，结果为 0，不制造重复。
    @discardableResult
    func transfer(from sourceOwner: String,
                  to destinationOwner: String,
                  queuePolicy: QueuePolicy = .transfer) throws -> Result {
        precondition(!sourceOwner.isEmpty && sourceOwner != OwnerKey.unassigned)
        precondition(!destinationOwner.isEmpty && destinationOwner != OwnerKey.unassigned)
        guard sourceOwner != destinationOwner else { return Result() }

        let sourceSessions = try sessions(sourceOwner)
        let sourceAngles = try angleTests(sourceOwner)
        let sourceFavorites = try favorites(sourceOwner)
        let sourceActivePlans = try activePlans(sourceOwner)
        let sourceCustomPlans = try customPlans(sourceOwner)
        let sourceQueueItems = try queueItems(sourceOwner)
        let sourceSchedules = try schedules(sourceOwner)
        let destinationSchedulesBeforeTransfer = try schedules(destinationOwner)
        let sourceScheduleSnapshots = sourceSchedules.map { schedule in
            (schedule, schedule.items.map { ($0, $0.orderIndex) })
        }
        let destinationScheduleSnapshots = destinationSchedulesBeforeTransfer.map { schedule in
            (schedule, schedule.items.map { ($0, $0.orderIndex) })
        }

        do {
            var result = Result()

            var destinationSessionIDs = Set(try sessions(destinationOwner).map(\.id))
            for session in sourceSessions {
                if destinationSessionIDs.contains(session.id) {
                    context.delete(session)
                } else {
                    session.ownerKey = destinationOwner
                    destinationSessionIDs.insert(session.id)
                    result.sessions += 1
                }
            }

            var destinationAngleIDs = Set(try angleTests(destinationOwner).map(\.id))
            for angle in sourceAngles {
                if destinationAngleIDs.contains(angle.id) {
                    context.delete(angle)
                } else {
                    angle.ownerKey = destinationOwner
                    destinationAngleIDs.insert(angle.id)
                    result.angleTests += 1
                }
            }

            let destinationFavoriteIDs = Set(try favorites(destinationOwner).map(\.drillId))
            for favorite in sourceFavorites {
                if destinationFavoriteIDs.contains(favorite.drillId) {
                    context.delete(favorite)
                } else {
                    favorite.ownerKey = destinationOwner
                    result.favorites += 1
                }
            }

            var destinationActivePlanKeys = Set(try activePlans(destinationOwner).map(Self.activePlanIdentity))
            for plan in sourceActivePlans {
                let key = Self.activePlanIdentity(plan)
                if destinationActivePlanKeys.contains(key) {
                    context.delete(plan)
                } else {
                    plan.ownerKey = destinationOwner
                    destinationActivePlanKeys.insert(key)
                    result.activePlans += 1
                }
            }

            var destinationCustomPlanIDs = Set(try customPlans(destinationOwner).map(\.id))
            for plan in sourceCustomPlans {
                if destinationCustomPlanIDs.contains(plan.id) {
                    context.delete(plan)
                } else {
                    plan.ownerKey = destinationOwner
                    destinationCustomPlanIDs.insert(plan.id)
                    result.customPlans += 1
                }
            }

            var destinationSchedules = Dictionary(
                uniqueKeysWithValues: destinationSchedulesBeforeTransfer.map {
                    (Self.scheduleIdentity($0), $0)
                }
            )
            for schedule in sourceSchedules.sorted(by: { $0.createdAt < $1.createdAt }) {
                let key = Self.scheduleIdentity(schedule)
                if let destination = destinationSchedules[key] {
                    var destinationItemKeys = Set(destination.items.map(Self.scheduleItemIdentity))
                    for item in schedule.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                        let itemKey = Self.scheduleItemIdentity(item)
                        if destinationItemKeys.contains(itemKey) {
                            context.delete(item)
                        } else {
                            item.schedule = destination
                            item.orderIndex = (destination.items.map(\.orderIndex).max() ?? -1) + 1
                            destination.items.append(item)
                            destinationItemKeys.insert(itemKey)
                        }
                    }
                    destination.updatedAt = max(destination.updatedAt, schedule.updatedAt)
                    context.delete(schedule)
                } else {
                    schedule.ownerKey = destinationOwner
                    destinationSchedules[key] = schedule
                }
                result.schedules += 1
            }

            if case .discardSource = queuePolicy {
                sourceQueueItems.forEach(context.delete)
            } else {
                let destinationQueueKeys = Set(try queueItems(destinationOwner).map(Self.queueIdentity))
                var seenQueueKeys = destinationQueueKeys
                for item in sourceQueueItems.sorted(by: { $0.createdAt < $1.createdAt }) {
                    let key = Self.queueIdentity(item)
                    if seenQueueKeys.contains(key) {
                        context.delete(item)
                    } else {
                        item.ownerKey = destinationOwner
                        seenQueueKeys.insert(key)
                        result.queueItems += 1
                    }
                }
            }

            try saveAction(context)
            return result
        } catch {
            context.rollback()
            // SwiftData rollback restores the store transaction, but registered model objects can
            // retain their last in-memory owner until refreshed. Restore them explicitly so callers
            // cannot observe a half-transferred graph after a failed save.
            sourceSessions.forEach { $0.ownerKey = sourceOwner }
            sourceAngles.forEach { $0.ownerKey = sourceOwner }
            sourceFavorites.forEach { $0.ownerKey = sourceOwner }
            sourceActivePlans.forEach { $0.ownerKey = sourceOwner }
            sourceCustomPlans.forEach { $0.ownerKey = sourceOwner }
            sourceQueueItems.forEach { $0.ownerKey = sourceOwner }
            sourceSchedules.forEach { $0.ownerKey = sourceOwner }
            for (schedule, itemSnapshots) in sourceScheduleSnapshots {
                schedule.items = itemSnapshots.map(\.0)
                for (item, orderIndex) in itemSnapshots {
                    item.schedule = schedule
                    item.orderIndex = orderIndex
                }
            }
            for (schedule, itemSnapshots) in destinationScheduleSnapshots {
                schedule.items = itemSnapshots.map(\.0)
                for (item, orderIndex) in itemSnapshots {
                    item.schedule = schedule
                    item.orderIndex = orderIndex
                }
            }
            throw error
        }
    }

    private static func queueIdentity(_ item: SyncPendingItem) -> String {
        "\(item.entityType)|\(item.entityId.uuidString)|\(item.operation)"
    }

    private static func activePlanIdentity(_ plan: UserActivePlan) -> String {
        plan.planId
    }

    private static func scheduleIdentity(_ schedule: TodayTrainingSchedule) -> String {
        "\(schedule.localDayKey)|\(schedule.calendarIdentifier)|\(schedule.timeZoneIdentifier)"
    }

    private static func scheduleItemIdentity(_ item: TodayScheduleItem) -> String {
        item.migrationKey ?? item.id.uuidString
    }

    private func sessions(_ ownerKey: String) throws -> [TrainingSession] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<TrainingSession> {
            $0.ownerKey == ownerKey
        }))
    }

    private func angleTests(_ ownerKey: String) throws -> [AngleTestResult] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<AngleTestResult> {
            $0.ownerKey == ownerKey
        }))
    }

    private func favorites(_ ownerKey: String) throws -> [DrillFavorite] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<DrillFavorite> {
            $0.ownerKey == ownerKey
        }))
    }

    private func activePlans(_ ownerKey: String) throws -> [UserActivePlan] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<UserActivePlan> {
            $0.ownerKey == ownerKey
        }))
    }

    private func customPlans(_ ownerKey: String) throws -> [CustomPlan] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<CustomPlan> {
            $0.ownerKey == ownerKey
        }))
    }

    private func queueItems(_ ownerKey: String) throws -> [SyncPendingItem] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<SyncPendingItem> {
            $0.ownerKey == ownerKey
        }))
    }

    private func schedules(_ ownerKey: String) throws -> [TodayTrainingSchedule] {
        try context.fetch(FetchDescriptor(predicate: #Predicate<TodayTrainingSchedule> {
            $0.ownerKey == ownerKey
        }))
    }
}
