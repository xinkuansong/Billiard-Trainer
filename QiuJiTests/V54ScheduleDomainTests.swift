import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V54ScheduleDomainTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let owner = "guest:v54-domain"
    private let planID = "plan_beginner"

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() {
        context = nil; container = nil
        super.tearDown()
    }

    func testTemplateSessionCountsRemainSeparateFromDrillCounts() throws {
        let template = UUID()
        func saved(_ source: String?, _ key: String, entries: Int = 2) -> TrainingSession {
            let session = TrainingSession(ownerKey: key)
            context.insert(session)
            session.sourceKind = source
            session.sourceId = template.uuidString
            session.planId = template.uuidString
            for index in 0..<entries {
                let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球", orderIndex: index)
                context.insert(entry)
                session.drillEntries.append(entry)
            }
            return session
        }
        let first = saved(TodayScheduleSourceKind.template, owner)
        let legacy = saved(nil, owner)
        let foreign = saved(TodayScheduleSourceKind.template, "other")
        let empty = saved(TodayScheduleSourceKind.template, owner, entries: 0)
        let official = saved(TodayScheduleSourceKind.officialLesson, owner)
        let sessions = [first, legacy, foreign, empty, official, first]
        XCTAssertEqual(TemplatePracticeCounts.make(sessions: sessions, ownerKey: owner), [template: 2])
        XCTAssertEqual(DrillPracticeCounts.make(sessions: sessions, ownerKey: owner), ["drill_c001": 6])
        context.delete(first)
        try context.save()
        let remaining = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(TemplatePracticeCounts.make(sessions: remaining, ownerKey: owner), [template: 1])
        XCTAssertEqual(TemplatePracticeCounts.make(sessions: remaining, ownerKey: "other"), [template: 1])
    }

    func testPlanSuggestionIsOncePerDayAcrossLessonAndPlanSwitches() throws {
        var clock = Date(timeIntervalSince1970: 1_788_393_600)
        let utc = TimeZone(secondsFromGMT: 0)!
        let service = TodayTrainingScheduleService(context: context, now: { clock }, timeZone: utc)
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 0)
        _ = try service.addOfficialLessons(plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active)
        let today = try XCTUnwrap(try service.today(ownerKey: owner))
        today.items[0].state = TodayScheduleItemState.completed
        func proposal(_ id: String) -> TodaySessionInfo {
            TodaySessionInfo(planId: id, planNameZh: id, weekNumber: 1, dayNumber: 2,
                weekTheme: "阶段", totalMinutes: 20, drills: [], isFromTemplate: false,
                lessonID: plan.lessons[1].id)
        }
        func projected(_ id: String) throws -> TodayTrainingProjection {
            TodayTrainingProjection.make(ownerKey: owner,
                schedules: try context.fetch(FetchDescriptor<TodayTrainingSchedule>()), sessions: [],
                suggestion: proposal(id), now: clock, timeZone: utc)
        }
        XCTAssertNil(try projected(plan.id).suggestion, "下一课也不能在同日再次自动提示")
        XCTAssertNotNil(try projected("plan_other").suggestion, "换新计划仍可建议加入")
        XCTAssertNil(try projected(plan.id).suggestion, "切回已加入计划不再提示")
        clock = clock.addingTimeInterval(86400)
        _ = try service.today(ownerKey: owner)
        XCTAssertNotNil(try projected(plan.id).suggestion, "新一天重新提供建议")
    }

    func testCarryForwardDoesNotCopyTodaysCompletedPlanAgain() throws {
        var clock = Date(timeIntervalSince1970: 1_788_393_600)
        let service = TodayTrainingScheduleService(context: context, now: { clock }, timeZone: TimeZone(secondsFromGMT: 0)!)
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 0)
        _ = try service.addOfficialLessons(plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active)
        let yesterday = try XCTUnwrap(try service.today(ownerKey: owner))
        clock = clock.addingTimeInterval(86400)
        let today = try XCTUnwrap(try service.today(ownerKey: owner))
        _ = try service.addOfficialLessons(plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active)
        today.items[0].state = TodayScheduleItemState.completed
        XCTAssertTrue(TodayTrainingScheduleService.carryForwardCandidates(
            from: yesterday, todayItems: today.items, activePlanID: plan.id).isEmpty)
        XCTAssertTrue(try service.carryForwardLatestUnfinished(
            ownerKey: owner, activePlan: active, officialPlan: plan).isEmpty)
        XCTAssertEqual(today.items.count, 1)
        XCTAssertTrue(try service.carryForwardLatestUnfinished(
            ownerKey: owner, activePlan: active, officialPlan: plan).isEmpty)
        XCTAssertEqual(today.items.count, 1, "重复点击补入也不能复制完成项")
    }

    func testFreeTrainingOrdinalsResetDailyAndExcludeOtherSources() throws {
        let zone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3600))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6)))
        func session(_ seconds: TimeInterval, source: String? = nil, plan: String? = nil,
                     kind: String = "drill", ownerKey: String? = nil) -> TrainingSession {
            let value = TrainingSession(kind: kind, ownerKey: ownerKey ?? owner)
            value.date = day.addingTimeInterval(seconds)
            value.sourceKind = source
            value.planId = plan
            context.insert(value)
            let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球")
            context.insert(entry)
            value.drillEntries = [entry]
            return value
        }
        let yesterday = session(-30)
        let first = session(30)
        let second = session(90, source: TodayScheduleSourceKind.libraryDrill)
        second.scheduleItemId = UUID()
        let official = session(10, source: TodayScheduleSourceKind.officialLesson)
        let template = session(15, source: TodayScheduleSourceKind.template)
        let legacyPlan = session(20, plan: "legacy-plan")
        let cognitive = session(21, kind: "cognitive")
        let foreign = session(22, ownerKey: "guest:other")
        let empty = TrainingSession(ownerKey: owner)
        empty.date = day
        context.insert(empty)
        let sessions = [second, official, yesterday, foreign, first, legacyPlan, cognitive, template, empty, first]
        let ordinals = TodayTrainingProjection.freeTrainingOrdinals(sessions: sessions, ownerKey: owner, day: day, timeZone: zone)
        XCTAssertEqual(ordinals, [first.id: 1, second.id: 2])
        XCTAssertEqual(TodayTrainingProjection.freeTrainingOrdinals(sessions: Array(sessions.reversed()), ownerKey: owner, day: day, timeZone: zone), ordinals)
        XCTAssertEqual(TodayTrainingProjection.freeTrainingOrdinals(sessions: sessions, ownerKey: owner, day: yesterday.date, timeZone: zone), [yesterday.id: 1])
        second.date = first.date
        let tied = TodayTrainingProjection.freeTrainingOrdinals(sessions: sessions, ownerKey: owner, day: day, timeZone: zone)
        let sortedIDs = [first.id, second.id].sorted { $0.uuidString < $1.uuidString }
        XCTAssertEqual(tied, [sortedIDs[0]: 1, sortedIDs[1]: 2])
    }

    func test_v57_switchRestoresCursorAndIsolatesOwners() throws {
        let a = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let b = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: "plan_intermediate"))
        let first = try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context)
        first.currentLessonId = a.lessons[2].id
        first.currentWeek = 2
        first.currentDay = 3
        let foreign = UserActivePlan(planId: a.id, ownerKey: "guest:other")
        foreign.currentLessonId = a.lessons[1].id
        context.insert(foreign)
        try context.save()
        let second = try PlanProgressService.activateOfficialPlan(b, ownerKey: owner, context: context)
        XCTAssertEqual(first.status, "paused")
        XCTAssertEqual(second.status, "active")
        let restored = try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context)
        XCTAssertEqual(restored.id, first.id)
        XCTAssertEqual(restored.currentLessonId, a.lessons[2].id)
        XCTAssertEqual(restored.currentWeek, 2)
        XCTAssertEqual(restored.currentDay, 3)
        XCTAssertEqual(second.status, "paused")
        XCTAssertEqual(foreign.status, "active")
        XCTAssertEqual(foreign.currentLessonId, a.lessons[1].id)
        _ = try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context)
        XCTAssertEqual(try PlanProgressService.officialRecords(ownerKey: owner, context: context).count, 2)
    }

    func test_v57_failedSwitchRestoresSavedAndInMemoryState() throws {
        enum Failure: Error { case disk }
        let a = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let b = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: "plan_intermediate"))
        let first = try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context)
        let second = try PlanProgressService.activateOfficialPlan(b, ownerKey: owner, context: context)
        let previousDate = first.updatedAt
        XCTAssertThrowsError(try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context,
            save: { throw Failure.disk }))
        XCTAssertEqual(first.status, "paused")
        XCTAssertEqual(first.updatedAt, previousDate)
        XCTAssertEqual(second.status, "active")
        let independent = ModelContext(container)
        let persisted = try PlanProgressService.officialRecords(ownerKey: owner, context: independent)
        XCTAssertEqual(PlanProgressService.currentOfficialPlan(in: persisted)?.planId, b.id)
    }

    func test_v57_oldQueuedLessonCannotAdvanceNewMainline() throws {
        let a = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let b = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: "plan_intermediate"))
        let old = try PlanProgressService.activateOfficialPlan(a, ownerKey: owner, context: context)
        let result = try TodayTrainingScheduleService(context: context).addOfficialLessons(
            plan: a, lessonIDs: [a.lessons[0].id], activePlan: old
        )
        let item = try addedItem(XCTUnwrap(result.first))
        let current = try PlanProgressService.activateOfficialPlan(b, ownerKey: owner, context: context)
        item.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(item, context: context), .none)
        XCTAssertEqual(current.currentLessonId, b.lessons[0].id)
        XCTAssertEqual(old.currentLessonId, a.lessons[0].id)
    }

    func test_v57_failedFirstActivationDoesNotLeaveAnActiveDraft() throws {
        enum Failure: Error { case disk }
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        XCTAssertThrowsError(try PlanProgressService.activateOfficialPlan(plan, ownerKey: owner, context: context,
            save: { throw Failure.disk }))
        XCTAssertTrue(try PlanProgressService.officialRecords(ownerKey: owner, context: context).isEmpty)
        XCTAssertTrue(try PlanProgressService.officialRecords(ownerKey: owner, context: ModelContext(container)).isEmpty)
    }

    func test_v57_selectionIgnoresPausedCompletedAndCustomAndIsStable() {
        let a = UserActivePlan(planId: "a", ownerKey: owner)
        let b = UserActivePlan(planId: "b", ownerKey: owner)
        a.startDate = Date(timeIntervalSince1970: 1)
        b.startDate = Date(timeIntervalSince1970: 2)
        XCTAssertEqual(PlanProgressService.currentOfficialPlan(in: [a, b])?.id, b.id)
        XCTAssertEqual(PlanProgressService.currentOfficialPlan(in: [b, a])?.id, b.id)
        b.status = "paused"
        a.status = "completed"
        let custom = UserActivePlan(planId: "template", isCustom: true, ownerKey: owner)
        XCTAssertNil(PlanProgressService.currentOfficialPlan(in: [a, b, custom]))
    }

    func test_v57_normalizationPersistsSingleActiveWithoutLosingCursors() throws {
        let a = UserActivePlan(planId: "a", ownerKey: owner)
        let b = UserActivePlan(planId: "b", ownerKey: owner)
        a.startDate = Date(timeIntervalSince1970: 1)
        b.startDate = Date(timeIntervalSince1970: 2)
        a.currentLessonId = "a.lesson2"
        b.currentLessonId = "b.lesson3"
        context.insert(a); context.insert(b)
        try context.save()
        _ = try PlanProgressService.normalizeOfficialMainline(ownerKey: owner, context: context)
        let restored = try PlanProgressService.officialRecords(ownerKey: owner, context: ModelContext(container))
        XCTAssertEqual(restored.filter { $0.status == "active" }.map(\.planId), ["b"])
        XCTAssertEqual(restored.first { $0.planId == "a" }?.currentLessonId, "a.lesson2")
        XCTAssertEqual(restored.first { $0.planId == "b" }?.currentLessonId, "b.lesson3")
    }

    func test_v57_homeUsesLessonIdentityWhenLegacyCursorDisagrees() async throws {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = try PlanProgressService.activateOfficialPlan(plan, ownerKey: owner, context: context)
        let stage = try XCTUnwrap(plan.stages.last)
        let lesson = try XCTUnwrap(stage.lessons.last)
        active.currentLessonId = lesson.id
        active.currentWeek = 1
        active.currentDay = 1
        try context.save()
        let vm = TrainingHomeViewModel()
        await vm.load(context: context, ownerKey: owner)
        let actual = try XCTUnwrap(vm.todaySession)
        XCTAssertEqual(actual.weekNumber, stage.order)
        XCTAssertEqual(actual.dayNumber, lesson.order)
        XCTAssertEqual(actual.drills.map(\.drillId), lesson.phases.flatMap { $0.drills.map(\.drillId) })
        active.status = "paused"
        try context.save()
        await vm.load(context: context, ownerKey: owner)
        XCTAssertFalse(vm.hasActivePlan)
        XCTAssertNil(vm.todaySession)
    }

    func test_v57_projectionKeepsOfficialAndTemplateInBothInsertionOrders() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        for templateFirst in [false, true] {
            let store = ModelContainerFactory.makeInMemoryContainer()
            let db = store.mainContext
            let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
            let lesson = plan.lessons[0]
            let active = try PlanProgressService.activateOfficialPlan(plan, ownerKey: owner, context: db)
            let service = TodayTrainingScheduleService(context: db, now: { date }, timeZone: TimeZone(secondsFromGMT: 0)!)
            let drillID = try XCTUnwrap(lesson.phases.flatMap(\.drills).first?.drillId)
            let template = CustomPlan(name: "并列模板", sessionsPerWeek: 3, ownerKey: owner)
            template.drills = [CustomPlanDrill(drillId: drillID, drillNameZh: "同一动作", roundsPerFormation: 1, order: 0)]
            db.insert(template)
            if templateFirst { _ = try service.addTemplate(template) }
            _ = try service.addOfficialLessons(plan: plan, lessonIDs: [lesson.id], activePlan: active)
            if !templateFirst { _ = try service.addTemplate(template) }
            let schedule = try XCTUnwrap(try service.today(ownerKey: owner, createIfNeeded: false))
            let official = try XCTUnwrap(schedule.items.first { $0.sourceKind == TodayScheduleSourceKind.officialLesson })
            let block = try ScheduledTrainingBlock(item: official)
            XCTAssertEqual(ActiveTrainingViewModel(mode: .scheduled(block)).trainingTitle, plan.nameZh)
            let templateItem = try XCTUnwrap(schedule.items.first { $0.sourceKind == TodayScheduleSourceKind.template })
            let templateBlock = try ScheduledTrainingBlock(item: templateItem)
            XCTAssertEqual(ActiveTrainingViewModel(mode: .scheduled(templateBlock)).trainingTitle, "并列模板")
            let saved = TrainingSession(ownerKey: owner)
            saved.date = date
            saved.scheduleItemId = official.id
            saved.planId = plan.id
            saved.lessonId = lesson.id
            saved.drillEntries = block.drills.map { DrillEntry(drillId: $0.drillID, drillNameZh: $0.name) }
            db.insert(saved)
            official.state = TodayScheduleItemState.completed
            official.trainingSessionId = saved.id
            try db.save()
            // A fresh context exercises persisted relationships, not just the original object array.
            let fresh = ModelContext(store)
            let projection = TodayTrainingProjection.make(ownerKey: owner,
                schedules: try fresh.fetch(FetchDescriptor<TodayTrainingSchedule>()),
                sessions: try fresh.fetch(FetchDescriptor<TrainingSession>()),
                suggestion: TodaySessionInfo(planId: plan.id, planNameZh: plan.nameZh, weekNumber: 1,
                    dayNumber: 1, weekTheme: "阶段", totalMinutes: 20, drills: [], isFromTemplate: false,
                    lessonID: lesson.id),
                now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
            XCTAssertEqual(projection.queued.count, 2)
            XCTAssertNil(projection.suggestion, "已入队的官方课不能重复出现建议")
            XCTAssertEqual(projection.totalCount, block.drills.count + 1)
            XCTAssertEqual(projection.completedCount, block.drills.count)
            XCTAssertEqual(projection.queued.first { $0.item.sourceKind == TodayScheduleSourceKind.template }?.completedCount, 0)
            XCTAssertTrue(projection.history.isEmpty, "队列 session 不得重复算成自由历史")
            XCTAssertFalse(projection.allArrangedTrainingEnded)
        }
    }

    func test_v57_projectionOtherPlanSuggestionSurvivesFreeTrainingCompletion() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let service = TodayTrainingScheduleService(context: context, now: { date }, timeZone: TimeZone(secondsFromGMT: 0)!)
        let item = try addedItem(service.addLibraryDrill(id: "drill_c001", title: "直线球", ownerKey: owner))
        let suggestion = TodaySessionInfo(planId: "plan_beginner", planNameZh: "基本功", weekNumber: 1,
            dayNumber: 1, weekTheme: "阶段", totalMinutes: 20, drills: [], isFromTemplate: false,
            lessonID: "plan_beginner.stage01.lesson01")
        let schedules = try context.fetch(FetchDescriptor<TodayTrainingSchedule>())
        let pending = TodayTrainingProjection.make(ownerKey: owner, schedules: schedules, sessions: [],
            suggestion: suggestion, now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertNotNil(pending.suggestion)
        XCTAssertEqual(pending.totalCount, 1)
        item.state = TodayScheduleItemState.completed
        let done = TrainingSession(ownerKey: owner)
        done.date = date; done.scheduleItemId = item.id
        done.drillEntries = [DrillEntry(drillId: "drill_c001", drillNameZh: "直线球")]
        context.insert(done); try context.save()
        let finished = TodayTrainingProjection.make(ownerKey: owner, schedules: schedules, sessions: [done],
            suggestion: suggestion, now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertNotNil(finished.suggestion, "自由训练完成不应隐藏尚未加入的计划建议")
        XCTAssertTrue(finished.allArrangedTrainingEnded)
        XCTAssertEqual(finished.completedCount, 1)
    }

    func test_v57_projectionSavedHistoryUsesEntryIdentityOwnerAndLocalDay() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let saved = TrainingSession(ownerKey: owner)
        saved.date = date; saved.totalDurationMinutes = 17
        saved.drillEntries = [DrillEntry(drillId: "same", drillNameZh: "同动作"),
                              DrillEntry(drillId: "same", drillNameZh: "同动作")]
        let yesterday = TrainingSession(ownerKey: owner)
        yesterday.date = date.addingTimeInterval(-86400)
        yesterday.drillEntries = [DrillEntry(drillId: "yesterday", drillNameZh: "昨日")]
        let other = TrainingSession(ownerKey: "guest:other")
        other.date = date; other.drillEntries = [DrillEntry(drillId: "other", drillNameZh: "另一账号")]
        for session in [saved, yesterday, other] { context.insert(session) }
        try context.save()
        let projection = TodayTrainingProjection.make(ownerKey: owner, schedules: [],
            sessions: [saved, saved, yesterday, other], suggestion: nil,
            now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(projection.history.count, 1)
        XCTAssertEqual(projection.totalCount, 2)
        XCTAssertEqual(projection.completedCount, 2)
        XCTAssertEqual(projection.recordedMinutes, 17)
        XCTAssertEqual(projection.estimatedMinutes, 0)
        XCTAssertTrue(projection.allArrangedTrainingEnded)
    }

    func test_v57_projectionCorruptionCannotLookLikeAnEmptyCompletedLesson() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let service = TodayTrainingScheduleService(context: context, now: { date }, timeZone: TimeZone(secondsFromGMT: 0)!)
        let item = try addedItem(service.addLibraryDrill(id: "drill_c001", title: "直线球", ownerKey: owner))
        item.payloadSnapshot = Data("invalid".utf8)
        item.state = TodayScheduleItemState.completed
        let projection = TodayTrainingProjection.make(ownerKey: owner,
            schedules: try context.fetch(FetchDescriptor<TodayTrainingSchedule>()), sessions: [], suggestion: nil,
            now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(projection.hasUnavailableContent)
        XCTAssertNotNil(projection.queued.first?.unavailableReason)
        XCTAssertFalse(projection.allArrangedTrainingEnded)
    }

    func test_v57_projectionReopensDiskStoreAfterTemplateDeletion() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("v57-projection-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) }
            catch { XCTFail("Unable to remove isolated test store: \(error)") }
        }
        let url = directory.appendingPathComponent("test.store")
        func populate() throws -> Data {
            let store = try ModelContainerFactory.makeContainer(at: url)
            let db = store.mainContext
            let template = CustomPlan(name: "冻结标题", sessionsPerWeek: 3, ownerKey: owner)
            template.drills = [CustomPlanDrill(drillId: "drill_c001", drillNameZh: "直线球", roundsPerFormation: 2, order: 0)]
            db.insert(template)
            let service = TodayTrainingScheduleService(context: db, now: { date }, timeZone: TimeZone(secondsFromGMT: 0)!)
            let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
            let active = try PlanProgressService.activateOfficialPlan(plan, ownerKey: owner, context: db)
            _ = try service.addOfficialLessons(plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active)
            let result = try service.addTemplate(template)
            let item: TodayScheduleItem
            switch result {
            case .added(let value), .alreadyPresent(let value): item = value
            }
            let frozen = item.payloadSnapshot
            template.name = "源已修改"
            template.drills[0].roundsPerFormation = 9
            try db.save()
            db.delete(template)
            try db.save()
            return frozen
        }
        let expectedPayload = try populate()
        let reopened = try ModelContainerFactory.makeContainer(at: url)
        let db = reopened.mainContext
        XCTAssertEqual(try db.fetchCount(FetchDescriptor<CustomPlan>()), 0)
        let projection = TodayTrainingProjection.make(ownerKey: owner,
            schedules: try db.fetch(FetchDescriptor<TodayTrainingSchedule>()), sessions: [], suggestion: nil,
            now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertEqual(projection.queued.count, 2)
        XCTAssertTrue(projection.queued.contains { $0.item.sourceKind == TodayScheduleSourceKind.officialLesson })
        let restored = try XCTUnwrap(projection.queued.first { $0.item.sourceKind == TodayScheduleSourceKind.template })
        XCTAssertEqual(restored.item.sourceTitleSnapshot, "冻结标题")
        XCTAssertEqual(restored.item.payloadSnapshot, expectedPayload)
        XCTAssertEqual(restored.totalCount, 1)
        XCTAssertGreaterThan(restored.estimatedMinutes, 0)
        XCTAssertNil(restored.unavailableReason)
    }

    func test_v57_projectionAbandonAndDeleteRemovePendingDenominator() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let utc = TimeZone(secondsFromGMT: 0)!
        let service = TodayTrainingScheduleService(context: context, now: { date }, timeZone: utc)
        let a = try addedItem(service.addLibraryDrill(id: "drill_c001", title: "a", ownerKey: owner))
        let b = try addedItem(service.addLibraryDrill(id: "drill_c002", title: "b", ownerKey: owner))
        let schedule = try XCTUnwrap(a.schedule)
        try service.markStarted(a)
        try service.abandon(a)
        var projection = TodayTrainingProjection.make(ownerKey: owner, schedules: [schedule], sessions: [],
            suggestion: nil, now: date, timeZone: utc)
        XCTAssertEqual(projection.totalCount, 1)
        XCTAssertEqual(projection.queued.count, 2, "放弃记录仍可回看")
        try service.removePending(b)
        projection = TodayTrainingProjection.make(ownerKey: owner, schedules: [schedule], sessions: [],
            suggestion: nil, now: date, timeZone: utc)
        XCTAssertEqual(projection.totalCount, 0)
        XCTAssertFalse(projection.allArrangedTrainingEnded)
    }

    func test_v57_endedLessonCountsOnlySavedActions() throws {
        let date = Date(timeIntervalSince1970: 1_788_393_600)
        let utc = TimeZone(secondsFromGMT: 0)!
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = try PlanProgressService.activateOfficialPlan(plan, ownerKey: owner, context: context)
        let service = TodayTrainingScheduleService(context: context, now: { date }, timeZone: utc)
        let results = try service.addOfficialLessons(plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active)
        let item = try addedItem(XCTUnwrap(results.first))
        let block = try ScheduledTrainingBlock(item: item)
        XCTAssertGreaterThan(block.drills.count, 1)
        let saved = TrainingSession(ownerKey: owner)
        saved.date = date; saved.scheduleItemId = item.id
        saved.drillEntries = [DrillEntry(drillId: block.drills[0].drillID, drillNameZh: block.drills[0].name)]
        context.insert(saved)
        item.state = TodayScheduleItemState.completed
        try context.save()
        let projection = TodayTrainingProjection.make(ownerKey: owner,
            schedules: try context.fetch(FetchDescriptor<TodayTrainingSchedule>()), sessions: [saved], suggestion: nil,
            now: date, timeZone: utc)
        XCTAssertEqual(projection.completedCount, 1)
        XCTAssertEqual(projection.totalCount, block.drills.count)
        XCTAssertTrue(projection.allArrangedTrainingEnded)
        XCTAssertFalse(projection.allActionsCompleted)
        XCTAssertEqual(projection.queued[0].completedDrills.filter { $0 }.count, 1)
    }

    func test_classification_matchesAllFrozenSelectionCases() {
        let cases: [(Int?, Set<Int>, [Int: String])] = [
            (4, [1, 4], [1: "review", 4: "advanceEligible"]),
            (4, [4, 5], [4: "advanceEligible", 5: "advanceEligible"]),
            (4, [4, 6], [4: "advanceEligible", 6: "preview"]),
            (4, [6], [6: "preview"]),
            (4, [4], [4: "advanceEligible"]),
            (8, [8], [8: "advanceEligible"]),
            (nil, [2], [2: "review"]),
        ]
        for (current, selected, expected) in cases {
            XCTAssertEqual(
                OfficialLessonRoleRules.classify(
                    currentOrdinal: current, selectedOrdinals: selected, lessonCount: 9
                ),
                expected
            )
        }
    }

    func test_progressRules_reverseCompletion_switchAndTwentyReplays() {
        let items = [
            ProgressSettlementInput(ordinal: 4, role: "advanceEligible", isCompleted: true),
            ProgressSettlementInput(ordinal: 5, role: "advanceEligible", isCompleted: true),
        ]
        XCTAssertEqual(
            OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: planID, currentOrdinal: 4,
                lessonCount: 9, items: items
            ),
            ProgressSettlementResult(currentOrdinal: 6, isCompleted: false, advancedCount: 2)
        )
        XCTAssertEqual(
            OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: "plan_cueball", currentOrdinal: 4,
                lessonCount: 9, items: items
            ).advancedCount,
            0
        )
        var current: Int? = 4
        for _ in 0..<20 {
            current = OfficialPlanProgressRules.settle(
                planID: planID, activePlanID: planID, currentOrdinal: current,
                lessonCount: 9, items: items
            ).currentOrdinal
        }
        XCTAssertEqual(current, 6)
    }

    func test_service_freezesRoles_deduplicatesUnfinished_andAllowsRepeatAfterCompletion() throws {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 4)
        let service = TodayTrainingScheduleService(
            context: context,
            now: { Date(timeIntervalSince1970: 1_788_393_600) },
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let selected = Set([plan.lessons[4].id, plan.lessons[6].id])
        let first = try service.addOfficialLessons(plan: plan, lessonIDs: selected, activePlan: active)
        XCTAssertEqual(first.count, 2)
        let schedule = try XCTUnwrap(try service.today(ownerKey: owner, createIfNeeded: false))
        XCTAssertEqual(schedule.items.first(where: { $0.lessonId == plan.lessons[4].id })?.progressRole,
                       TodayScheduleProgressRole.advanceEligible)
        XCTAssertEqual(schedule.items.first(where: { $0.lessonId == plan.lessons[6].id })?.progressRole,
                       TodayScheduleProgressRole.preview)

        let second = try service.addOfficialLessons(plan: plan, lessonIDs: selected, activePlan: active)
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(schedule.items.count, 2, "unfinished source must deduplicate")

        let current = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[4].id })
        current.state = TodayScheduleItemState.completed
        current.completedAt = Date()
        try context.save()
        _ = try service.addOfficialLessons(
            plan: plan, lessonIDs: [plan.lessons[4].id], activePlan: active
        )
        XCTAssertEqual(schedule.items.filter { $0.lessonId == plan.lessons[4].id }.count, 2,
                       "completed source can be scheduled as a real repeat")
    }

    func test_persistentSettlement_handlesReverseOrder_finalCompletion_andReplay() throws {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: planID))
        let active = activePlan(plan: plan, ordinal: 4)
        let service = TodayTrainingScheduleService(context: context)
        _ = try service.addOfficialLessons(
            plan: plan,
            lessonIDs: [plan.lessons[4].id, plan.lessons[5].id],
            activePlan: active
        )
        let schedule = try XCTUnwrap(try service.today(ownerKey: owner, createIfNeeded: false))
        let current = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[4].id })
        let next = try XCTUnwrap(schedule.items.first { $0.lessonId == plan.lessons[5].id })

        next.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(next, context: context), .none)
        XCTAssertEqual(active.currentLessonId, plan.lessons[4].id)
        current.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(current, context: context),
                       .advanced(2))
        XCTAssertEqual(active.currentLessonId, plan.lessons[6].id)
        for _ in 0..<20 {
            XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(current, context: context), .none)
        }
        XCTAssertEqual(active.currentLessonId, plan.lessons[6].id)

        let finalActive = activePlan(plan: plan, ordinal: plan.lessons.count - 1,
                                     replacing: active)
        _ = try service.addOfficialLessons(
            plan: plan, lessonIDs: [plan.lessons.last!.id], activePlan: finalActive
        )
        let finalItem = try XCTUnwrap(schedule.items.last { $0.lessonId == plan.lessons.last!.id })
        finalItem.state = TodayScheduleItemState.completed
        XCTAssertEqual(try PlanProgressService.settleCompletedScheduleItem(finalItem, context: context),
                       .completed)
        XCTAssertNil(finalActive.currentLessonId)
        XCTAssertEqual(finalActive.status, "completed")
        XCTAssertNotNil(finalActive.completedAt)
    }

    func test_reorderDoesNotChangeFrozenRole_andStartedItemCannotBeDeleted() throws {
        let service = TodayTrainingScheduleService(context: context)
        let first = try addedItem(service.addLibraryDrill(id: "drill_c001", title: "直线球",
                                                          ownerKey: owner))
        let second = try addedItem(service.addLibraryDrill(id: "drill_c002", title: "定杆",
                                                           ownerKey: owner))
        let frozen = first.progressRole
        let schedule = try XCTUnwrap(first.schedule)
        try service.reorderUnfinished([second.id, first.id], in: schedule)
        XCTAssertEqual(schedule.items.sorted { $0.orderIndex < $1.orderIndex }.map(\.id),
                       [second.id, first.id])
        XCTAssertEqual(first.progressRole, frozen)
        try service.markStarted(first)
        XCTAssertThrowsError(try service.removePending(first))
        try service.abandon(first)
        XCTAssertEqual(first.state, TodayScheduleItemState.abandoned)
    }

    func test_crossDayArchivesWithoutAutoCarry_thenCopiesFreshItems() throws {
        var clock = Date(timeIntervalSince1970: 1_788_393_600)
        let utc = TimeZone(secondsFromGMT: 0)!
        let service = TodayTrainingScheduleService(context: context, now: { clock }, timeZone: utc)
        let oldItem = try addedItem(service.addLibraryDrill(id: "drill_c010", title: "定杆",
                                                            ownerKey: owner))
        let yesterday = try XCTUnwrap(oldItem.schedule)

        clock = clock.addingTimeInterval(86_400)
        let today = try XCTUnwrap(try service.today(ownerKey: owner))
        XCTAssertNotNil(yesterday.archivedAt)
        XCTAssertTrue(today.items.isEmpty, "unfinished items must not auto-pile into a new day")
        XCTAssertEqual(try service.latestArchivedWithUnfinished(ownerKey: owner)?.id, yesterday.id)

        let copied = try service.carryForwardLatestUnfinished(
            ownerKey: owner, activePlan: nil, officialPlan: nil
        )
        XCTAssertEqual(copied.count, 1)
        XCTAssertEqual(today.items.count, 1)
        XCTAssertNotEqual(today.items[0].id, oldItem.id)
        XCTAssertEqual(today.items[0].payloadSnapshot, oldItem.payloadSnapshot)
        XCTAssertEqual(oldItem.state, TodayScheduleItemState.pending)
    }

    func test_timezoneBoundary_andEstimateAreDeterministic() {
        let instant = Date(timeIntervalSince1970: 1_788_393_600)
        XCTAssertNotEqual(
            TodayTrainingScheduleService.localDayKey(
                for: instant, timeZone: TimeZone(secondsFromGMT: 14 * 3600)!
            ),
            TodayTrainingScheduleService.localDayKey(
                for: instant, timeZone: TimeZone(secondsFromGMT: -10 * 3600)!
            )
        )
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 0, weeklyGoalDays: 4
        ), 3)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 5, weeklyGoalDays: 4
        ), 1)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: 5, weeklyGoalDays: 3
        ), 2)
        XCTAssertEqual(PlanDurationEstimate.remainingWeeks(
            lessonCount: 9, currentOrdinal: nil, weeklyGoalDays: 4
        ), 0)
    }

    private func activePlan(
        plan: OfficialPlan,
        ordinal: Int,
        replacing old: UserActivePlan? = nil
    ) -> UserActivePlan {
        if let old { context.delete(old) }
        let active = UserActivePlan(planId: plan.id, ownerKey: owner)
        active.currentLessonId = plan.lessons[ordinal].id
        active.status = "active"
        if let stage = plan.stages.first(where: { $0.lessons.contains(where: { $0.id == active.currentLessonId }) }) {
            active.currentWeek = stage.order
            active.currentDay = plan.lessons[ordinal].order
        }
        context.insert(active)
        try? context.save()
        return active
    }

    private func addedItem(_ result: TodayTrainingScheduleService.AddResult) throws -> TodayScheduleItem {
        switch result {
        case .added(let item): return item
        case .alreadyPresent: throw XCTSkip("expected a newly added item")
        }
    }
}
