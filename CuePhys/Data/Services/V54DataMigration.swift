import Foundation
import SwiftData

/// Post-lightweight normalization for v54. It is replay-safe and intentionally
/// runs whenever the container opens so an interrupted save can recover.
enum V54DataMigration {
    typealias SaveAction = (ModelContext) throws -> Void
    typealias LessonResolver = (_ planID: String, _ stageOrder: Int, _ lessonOrder: Int) -> String?

    static func normalize(
        in container: ModelContainer,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        calendarIdentifier: String = "gregorian",
        lessonResolver: LessonResolver? = nil,
        saveAction: SaveAction = { try $0.save() }
    ) throws {
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<UserActivePlan>())
        guard rows.contains(where: { $0.migrationVersion < 1 }) else { return }
        let resolveLesson = lessonResolver ?? resolveLegacyLesson

        do {
            let customPlans = try context.fetch(FetchDescriptor<CustomPlan>())
            let customByIdentity = Dictionary(
                uniqueKeysWithValues: customPlans.map { ("\($0.ownerKey)|\($0.id.uuidString)", $0) }
            )
            let existingItems = try context.fetch(FetchDescriptor<TodayScheduleItem>())
            var migrationKeys = Set(existingItems.compactMap(\.migrationKey))
            var schedules = try context.fetch(FetchDescriptor<TodayTrainingSchedule>())

            for row in rows where row.migrationVersion < 1 && row.isCustom {
                let migrationKey = "v54:\(row.id.uuidString)"
                if !migrationKeys.contains(migrationKey) {
                    let localDayKey = localDayKey(for: now, timeZone: timeZone)
                    let schedule = schedule(
                        ownerKey: row.ownerKey,
                        localDayKey: localDayKey,
                        calendarIdentifier: calendarIdentifier,
                        timeZone: timeZone,
                        now: now,
                        schedules: &schedules,
                        context: context
                    )
                    let custom = customByIdentity["\(row.ownerKey)|\(row.planId)"]
                    let item = TodayScheduleItem(
                        orderIndex: nextOrder(in: schedule),
                        sourceKind: TodayScheduleSourceKind.template,
                        sourceId: row.planId,
                        sourceTitleSnapshot: custom?.name ?? "原模版训练",
                        sourceSubtitleSnapshot: custom.map { "\($0.drills.count) 个动作" },
                        payloadSnapshot: templateSnapshot(custom),
                        progressRole: TodayScheduleProgressRole.neutral,
                        createdAt: now,
                        migrationKey: migrationKey
                    )
                    item.schedule = schedule
                    schedule.items.append(item)
                    schedule.updatedAt = now
                    context.insert(item)
                    migrationKeys.insert(migrationKey)
                }
                context.delete(row)
            }

            let legacyOfficial = rows.filter { $0.migrationVersion < 1 && !$0.isCustom }
            for ownerRows in Dictionary(grouping: legacyOfficial, by: \.ownerKey).values {
                var winners: [UserActivePlan] = []
                for samePlanRows in Dictionary(grouping: ownerRows, by: \.planId).values {
                    let sorted = samePlanRows.sorted(by: legacyRowIsNewer)
                    if let winner = sorted.first { winners.append(winner) }
                    sorted.dropFirst().forEach(context.delete)
                }
                var resolved: [UUID: String] = [:]
                for row in winners {
                    if let lessonID = resolveLesson(row.planId, row.currentWeek, row.currentDay) {
                        resolved[row.id] = lessonID
                    }
                }
                let activeID = winners
                    .filter { resolved[$0.id] != nil }
                    .sorted(by: legacyRowIsNewer)
                    .first?.id
                for row in winners {
                    row.isCustom = false
                    row.currentLessonId = resolved[row.id]
                    row.status = row.currentLessonId == nil
                        ? "invalid"
                        : (row.id == activeID ? "active" : "paused")
                    row.updatedAt = max(row.startDate, now)
                    row.completedAt = nil
                    row.migrationVersion = 1
                }
            }

            try saveAction(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func localDayKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func stableLessonID(planID: String, stage: Int, lesson: Int) -> String {
        "\(planID).stage\(String(format: "%02d", max(stage, 1))).lesson\(String(format: "%02d", max(lesson, 1)))"
    }

    private static func resolveLegacyLesson(
        planID: String,
        stageOrder: Int,
        lessonOrder: Int
    ) -> String? {
        guard stageOrder > 0, lessonOrder > 0,
              let plan = PlanContentService.decodePlanFromBundle(id: planID),
              let stage = plan.stages.first(where: { $0.order == stageOrder }),
              let lesson = stage.lessons.first(where: { $0.order == lessonOrder }) else {
            return nil
        }
        return lesson.id
    }

    private static func legacyRowIsNewer(_ lhs: UserActivePlan, _ rhs: UserActivePlan) -> Bool {
        if lhs.startDate != rhs.startDate { return lhs.startDate > rhs.startDate }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func nextOrder(in schedule: TodayTrainingSchedule) -> Int {
        (schedule.items.map(\.orderIndex).max() ?? -1) + 1
    }

    private static func schedule(
        ownerKey: String,
        localDayKey: String,
        calendarIdentifier: String,
        timeZone: TimeZone,
        now: Date,
        schedules: inout [TodayTrainingSchedule],
        context: ModelContext
    ) -> TodayTrainingSchedule {
        if let existing = schedules.first(where: {
            $0.ownerKey == ownerKey && $0.localDayKey == localDayKey && $0.archivedAt == nil
        }) {
            return existing
        }
        let created = TodayTrainingSchedule(
            ownerKey: ownerKey,
            localDayKey: localDayKey,
            calendarIdentifier: calendarIdentifier,
            timeZoneIdentifier: timeZone.identifier,
            createdAt: now
        )
        context.insert(created)
        schedules.append(created)
        return created
    }

    private static func templateSnapshot(_ plan: CustomPlan?) -> Data {
        let payload: [String: Any] = [
            "version": 1,
            "templateId": plan?.id.uuidString ?? "",
            "title": plan?.name ?? "原模版训练",
            "drills": (plan?.drills ?? []).sorted(by: { $0.order < $1.order }).map {
                [
                    "drillId": $0.drillId,
                    "drillNameZh": $0.drillNameZh,
                    "roundsPerFormation": $0.roundsPerFormation,
                    "order": $0.order,
                ] as [String: Any]
            },
        ]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }
}
