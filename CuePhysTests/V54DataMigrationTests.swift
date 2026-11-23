import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V54DataMigrationTests: XCTestCase {
    private let owner = "guest:v54-migration"
    private let migrationDate = Date(timeIntervalSince1970: 1_788_393_600) // 2026-09-03 UTC
    private let utc = TimeZone(secondsFromGMT: 0)!

    func test_officialOnly_mapsLegacyCursor_andKeepsExactlyOneMainline() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        let row = legacyActive(planID: "plan_beginner", week: 2, day: 1)
        context.insert(row)
        try context.save()

        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)

        let plans = try context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].currentLessonId, "plan_beginner.stage02.lesson01")
        XCTAssertEqual(plans[0].status, "active")
        XCTAssertEqual(plans[0].migrationVersion, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TodayTrainingSchedule>()).isEmpty)
    }

    func test_customOnly_becomesFrozenTodayTemplate_withoutDeletingTemplate() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        let template = CustomPlan(name: "中袋专项", sessionsPerWeek: 4, ownerKey: owner)
        template.id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let first = CustomPlanDrill(drillId: "drill_c012", drillNameZh: "中袋球", roundsPerFormation: 2, order: 0)
        let second = CustomPlanDrill(drillId: "drill_c013", drillNameZh: "分离角", roundsPerFormation: 3, order: 1)
        template.drills = [first, second]
        context.insert(template); context.insert(first); context.insert(second)
        let row = legacyActive(planID: template.id.uuidString, isCustom: true)
        context.insert(row)
        try context.save()

        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CustomPlan>()), 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<UserActivePlan>()).isEmpty)
        let schedule = try XCTUnwrap(try context.fetch(FetchDescriptor<TodayTrainingSchedule>()).first)
        XCTAssertEqual(schedule.localDayKey, "2026-09-03")
        XCTAssertEqual(schedule.items.count, 1)
        let item = try XCTUnwrap(schedule.items.first)
        XCTAssertEqual(item.sourceKind, TodayScheduleSourceKind.template)
        XCTAssertEqual(item.sourceId, template.id.uuidString)
        XCTAssertEqual(item.sourceTitleSnapshot, "中袋专项")
        XCTAssertEqual(item.migrationKey, "v54:\(row.id.uuidString)")
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: item.payloadSnapshot) as? [String: Any])
        XCTAssertEqual(payload["title"] as? String, "中袋专项")
        XCTAssertEqual((payload["drills"] as? [[String: Any]])?.count, 2)
    }

    func test_officialAndCustom_areNormalizedInParallel() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        let template = CustomPlan(name: "低杆复练", sessionsPerWeek: 3, ownerKey: owner)
        context.insert(template)
        context.insert(legacyActive(planID: "plan_cueball", week: 1, day: 3,
                                    startDate: migrationDate.addingTimeInterval(-7200)))
        context.insert(legacyActive(planID: template.id.uuidString, isCustom: true,
                                    startDate: migrationDate.addingTimeInterval(-3600)))
        try context.save()

        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)

        let plans = try context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(plans.map(\.planId), ["plan_cueball"])
        XCTAssertEqual(plans.first?.currentLessonId, "plan_cueball.stage01.lesson03")
        let items = try context.fetch(FetchDescriptor<TodayScheduleItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sourceId, template.id.uuidString)
    }

    func test_duplicateOfficial_latestPlanWins_andEarlierProgressIsPaused() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        context.insert(legacyActive(planID: "plan_beginner", week: 3, day: 1,
                                    startDate: migrationDate.addingTimeInterval(-7200)))
        context.insert(legacyActive(planID: "plan_english", week: 2, day: 2,
                                    startDate: migrationDate.addingTimeInterval(-3600)))
        try context.save()

        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)

        let plans = try context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans.first(where: { $0.status == "active" })?.planId, "plan_english")
        XCTAssertEqual(plans.first(where: { $0.planId == "plan_english" })?.currentLessonId,
                       "plan_english.stage02.lesson02")
        XCTAssertEqual(plans.first(where: { $0.planId == "plan_beginner" })?.status, "paused")
        XCTAssertEqual(plans.first(where: { $0.planId == "plan_beginner" })?.currentLessonId,
                       "plan_beginner.stage03.lesson01")
    }

    func test_missingLegacyLesson_isKeptAsDiagnosableInvalidRow() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        let row = legacyActive(planID: "plan_removed", week: 99, day: 99)
        context.insert(row)
        try context.save()

        try V54DataMigration.normalize(
            in: container, now: migrationDate, timeZone: utc,
            lessonResolver: { _, _, _ in nil }
        )

        let migrated = try XCTUnwrap(context.fetch(FetchDescriptor<UserActivePlan>()).first)
        XCTAssertEqual(migrated.status, "invalid")
        XCTAssertNil(migrated.currentLessonId)
        XCTAssertEqual(migrated.migrationVersion, 1)
    }

    func test_halfMigratedCustom_reopenDoesNotDuplicateItem() throws {
        let container = try makeRawV5Container()
        let context = container.mainContext
        let row = legacyActive(planID: UUID().uuidString, isCustom: true)
        let schedule = TodayTrainingSchedule(ownerKey: owner, localDayKey: "2026-09-03",
                                             timeZoneIdentifier: utc.identifier,
                                             createdAt: migrationDate)
        let existing = TodayScheduleItem(
            orderIndex: 0, sourceKind: TodayScheduleSourceKind.template,
            sourceId: row.planId, sourceTitleSnapshot: "定杆复练",
            payloadSnapshot: Data("{}".utf8), progressRole: TodayScheduleProgressRole.neutral,
            createdAt: migrationDate, migrationKey: "v54:\(row.id.uuidString)"
        )
        existing.schedule = schedule; schedule.items = [existing]
        context.insert(row); context.insert(schedule); context.insert(existing)
        try context.save()

        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)
        try V54DataMigration.normalize(in: container, now: migrationDate, timeZone: utc)

        XCTAssertTrue(try context.fetch(FetchDescriptor<UserActivePlan>()).isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodayTrainingSchedule>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TodayScheduleItem>()), 1)
    }

    func test_normalize_saveFailureRollsBackStore() throws {
        enum Expected: Error { case saveFailed }
        let container = try makeRawV5Container()
        let context = container.mainContext
        let row = legacyActive(planID: UUID().uuidString, isCustom: true)
        context.insert(row)
        try context.save()

        XCTAssertThrowsError(try V54DataMigration.normalize(
            in: container, now: migrationDate, timeZone: utc,
            saveAction: { _ in throw Expected.saveFailed }
        ))

        let verification = ModelContext(container)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<UserActivePlan>()), 1)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<TodayTrainingSchedule>()), 0)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<TodayScheduleItem>()), 0)
    }

    func test_ownerTransfer_mergesSameDaySchedule_andRollsBackOnFailure() throws {
        enum Expected: Error { case saveFailed }
        let container = try makeRawV5Container()
        let context = container.mainContext
        let account = "account:v54"
        let source = TodayTrainingSchedule(ownerKey: owner, localDayKey: "2026-09-03",
                                           timeZoneIdentifier: utc.identifier)
        let destination = TodayTrainingSchedule(ownerKey: account, localDayKey: "2026-09-03",
                                                timeZoneIdentifier: utc.identifier)
        let sourceItem = item(title: "来源", migrationKey: "source-key")
        let destinationItem = item(title: "目标", migrationKey: "destination-key")
        sourceItem.schedule = source; source.items = [sourceItem]
        destinationItem.schedule = destination; destination.items = [destinationItem]
        context.insert(source); context.insert(destination); context.insert(sourceItem); context.insert(destinationItem)
        try context.save()

        let failed = OwnerTransferService(context: context) { _ in throw Expected.saveFailed }
        XCTAssertThrowsError(try failed.transfer(from: owner, to: account))
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<TodayTrainingSchedule>()).map(\.ownerKey)),
                       [owner, account])

        let result = try OwnerTransferService(context: context).transfer(from: owner, to: account)
        XCTAssertEqual(result.schedules, 1)
        let schedules = try context.fetch(FetchDescriptor<TodayTrainingSchedule>())
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules[0].ownerKey, account)
        XCTAssertEqual(Set(schedules[0].items.compactMap(\.migrationKey)),
                       ["source-key", "destination-key"])
        XCTAssertEqual(try OwnerTransferService(context: context).transfer(from: owner, to: account).total, 0)
    }

    func test_V4ToV5_preservesTrainingHistory_andIsReopenSafe() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("V54-V4Store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("V4.store")

        do {
            let schema = Schema(versionedSchema: QiuJiSchemaV4.self)
            let oldContainer = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: url)
            )
            let old = ModelContext(oldContainer)
            let session = QiuJiSchemaV4.TrainingSession(ownerKey: owner)
            session.note = "V4 历史不可丢"
            let entry = QiuJiSchemaV4.DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线")
            let set = QiuJiSchemaV4.DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7)
            entry.session = session; session.drillEntries = [entry]
            set.entry = entry; entry.sets = [set]
            old.insert(session); old.insert(entry); old.insert(set)

            let template = QiuJiSchemaV4.CustomPlan(name: "V4 模版", sessionsPerWeek: 4, ownerKey: owner)
            old.insert(template)
            let official = QiuJiSchemaV4.UserActivePlan(planId: "plan_beginner", ownerKey: owner)
            official.currentWeek = 2; official.currentDay = 1
            let custom = QiuJiSchemaV4.UserActivePlan(planId: template.id.uuidString,
                                                      isCustom: true, ownerKey: owner)
            old.insert(official); old.insert(custom)
            try old.save()
        }

        do {
            let migrated = try ModelContainerFactory.makeContainer(at: url)
            let current = ModelContext(migrated)
            XCTAssertEqual(try current.fetchCount(FetchDescriptor<TrainingSession>()), 1)
            XCTAssertEqual(try XCTUnwrap(current.fetch(FetchDescriptor<TrainingSession>()).first).note,
                           "V4 历史不可丢")
            XCTAssertEqual(try current.fetchCount(FetchDescriptor<DrillEntry>()), 1)
            XCTAssertEqual(try current.fetchCount(FetchDescriptor<DrillSet>()), 1)
            XCTAssertEqual(try current.fetchCount(FetchDescriptor<UserActivePlan>()), 1)
            XCTAssertEqual(try current.fetch(FetchDescriptor<UserActivePlan>()).first?.currentLessonId,
                           "plan_beginner.stage02.lesson01")
            XCTAssertEqual(try current.fetchCount(FetchDescriptor<TodayScheduleItem>()), 1)
        }

        let reopened = try ModelContainerFactory.makeContainer(at: url)
        let reopenedContext = ModelContext(reopened)
        XCTAssertEqual(try reopenedContext.fetchCount(FetchDescriptor<TrainingSession>()), 1)
        XCTAssertEqual(try reopenedContext.fetchCount(FetchDescriptor<TodayScheduleItem>()), 1)
    }

    private func makeRawV5Container() throws -> ModelContainer {
        let schema = Schema(versionedSchema: QiuJiSchemaV5.self)
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private func legacyActive(
        planID: String,
        isCustom: Bool = false,
        week: Int = 1,
        day: Int = 1,
        startDate: Date? = nil
    ) -> UserActivePlan {
        let row = UserActivePlan(planId: planID, isCustom: isCustom, ownerKey: owner)
        row.currentWeek = week; row.currentDay = day
        row.startDate = startDate ?? migrationDate.addingTimeInterval(-3600)
        row.updatedAt = row.startDate
        row.migrationVersion = 0
        return row
    }

    private func item(title: String, migrationKey: String) -> TodayScheduleItem {
        TodayScheduleItem(
            orderIndex: 0, sourceKind: TodayScheduleSourceKind.template,
            sourceId: UUID().uuidString, sourceTitleSnapshot: title,
            payloadSnapshot: Data("{}".utf8), progressRole: TodayScheduleProgressRole.neutral,
            migrationKey: migrationKey
        )
    }
}
