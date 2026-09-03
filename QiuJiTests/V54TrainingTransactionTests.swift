import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V54TrainingTransactionTests: XCTestCase {
    private enum Expected: Error { case firstSaveFails }

    private actor RetryBackend: SyncBackend {
        private var shouldFail = true
        private(set) var uploaded: [TrainingSessionDTO] = []
        func allowSuccess() { shouldFail = false }
        func uploadSession(_ dto: TrainingSessionDTO) async throws {
            uploaded.append(dto)
            if shouldFail { throw AppError.networkError("offline") }
        }
        func uploadAngleTest(_ dto: AngleTestDTO) async throws {}
        func deleteSession(clientId: String) async throws {}
    }

    private var container: ModelContainer!
    private var context: ModelContext!
    private let owner = "guest:v54-transaction"

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
    }

    override func tearDown() {
        SyncQueueManager.shared.backend = LiveSyncBackend()
        context = nil
        container = nil
        super.tearDown()
    }

    func test_scheduledCompletion_commitsSessionItemCursorAndQueueTogether() async throws {
        let fixture = try arrangeCurrentOfficialLesson()
        let vm = ActiveTrainingViewModel(mode: .scheduled(try ScheduledTrainingBlock(item: fixture.item)))
        await vm.loadDrills()

        vm.saveTraining(context: context)

        XCTAssertTrue(vm.didSaveSuccessfully)
        XCTAssertNil(vm.saveError)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<TrainingSession>()).first)
        XCTAssertEqual(session.scheduleItemId, fixture.item.id)
        XCTAssertEqual(session.sourceTitleSnapshot, fixture.item.sourceTitleSnapshot)
        XCTAssertEqual(session.sourcePayloadSnapshot, fixture.item.payloadSnapshot)
        XCTAssertEqual(session.frozenProgressRole, TodayScheduleProgressRole.advanceEligible)
        XCTAssertEqual(session.appliedProgressEffect, "advanced:1")
        XCTAssertEqual(fixture.item.state, TodayScheduleItemState.completed)
        XCTAssertEqual(fixture.item.trainingSessionId, session.id)
        XCTAssertEqual(fixture.active.currentLessonId, fixture.plan.lessons[1].id)
        let queue = try context.fetch(FetchDescriptor<SyncPendingItem>())
        XCTAssertEqual(queue.map(\.entityId), [session.id])
    }

    func test_injectedSaveFailure_rollsBackEverything_andSameBlockCanRetry() async throws {
        let fixture = try arrangeCurrentOfficialLesson()
        let block = try ScheduledTrainingBlock(item: fixture.item)
        var attempts = 0
        let vm = ActiveTrainingViewModel(mode: .scheduled(block), saveAction: { context in
            attempts += 1
            if attempts == 1 { throw Expected.firstSaveFails }
            try context.save()
        })
        await vm.loadDrills()

        vm.saveTraining(context: context)

        XCTAssertFalse(vm.didSaveSuccessfully)
        XCTAssertNotNil(vm.saveError)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrainingSession>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)
        let afterFailure = try XCTUnwrap(try fetchItem(id: block.scheduleItemID))
        XCTAssertEqual(afterFailure.state, TodayScheduleItemState.pending)
        XCTAssertNil(afterFailure.trainingSessionId)
        let activeAfterFailure = try XCTUnwrap(try context.fetch(FetchDescriptor<UserActivePlan>()).first)
        XCTAssertEqual(activeAfterFailure.currentLessonId, fixture.plan.lessons[0].id)

        vm.saveTraining(context: context)

        XCTAssertTrue(vm.didSaveSuccessfully)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncPendingItem>()).count, 1)
        XCTAssertEqual(try fetchItem(id: block.scheduleItemID)?.state, TodayScheduleItemState.completed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserActivePlan>()).first?.currentLessonId,
                       fixture.plan.lessons[1].id)
    }

    func test_inProgressItem_rebuildsFrozenBlockAfterRestart() async throws {
        let fixture = try arrangeCurrentOfficialLesson()
        try TodayTrainingScheduleService(context: context).markStarted(fixture.item)

        let relaunchedItem = try XCTUnwrap(try fetchItem(id: fixture.item.id))
        let vm = ActiveTrainingViewModel(mode: .scheduled(try ScheduledTrainingBlock(item: relaunchedItem)))
        await vm.loadDrills()

        XCTAssertEqual(relaunchedItem.state, TodayScheduleItemState.inProgress)
        XCTAssertFalse(vm.drills.isEmpty)
        XCTAssertEqual(vm.drills.map(\.nameZh), fixture.frozenNames)
    }

    func test_payloadSnapshot_survivesSourceDeletionAndIsUsedForLaunch() async throws {
        let template = CustomPlan(name: "我的定杆复练", sessionsPerWeek: 3, ownerKey: owner)
        let drill = CustomPlanDrill(drillId: "drill_c001", drillNameZh: "冻结名称", roundsPerFormation: 2, order: 0)
        template.drills = [drill]
        context.insert(template)
        context.insert(drill)
        try context.save()
        let service = TodayTrainingScheduleService(context: context)
        let item: TodayScheduleItem
        switch try service.addTemplate(template) {
        case .added(let value): item = value
        case .alreadyPresent(let value): item = value
        }
        let frozen = item.payloadSnapshot
        context.delete(template)
        try context.save()

        let vm = ActiveTrainingViewModel(mode: .scheduled(try ScheduledTrainingBlock(item: item)))
        await vm.loadDrills()

        XCTAssertEqual(item.payloadSnapshot, frozen)
        XCTAssertEqual(vm.drills.first?.nameZh, "半台直线球")
        XCTAssertFalse(vm.drills.first?.plannedSets.isEmpty ?? true)
    }

    func test_oldDTOWithoutProvenance_decodesWithNilDefaults() throws {
        let payload = """
        {"clientId":"11111111-1111-1111-1111-111111111111",\
        "date":"2026-09-03T00:00:00Z","kind":"drill","drillEntries":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(TrainingSessionDTO.self, from: Data(payload.utf8))
        XCTAssertNil(dto.scheduleItemId)
        XCTAssertNil(dto.sourceKind)
        XCTAssertNil(dto.sourcePayloadSnapshot)
        XCTAssertNil(dto.progressRole)
        XCTAssertNil(dto.progressEffect)
        XCTAssertNil(dto.lessonId)
    }

    func test_uploadFailureKeepsAtomicQueue_andRetryCarriesProvenance() async throws {
        let accountOwner = OwnerKey.account("v54-user")
        let session = TrainingSession(ownerKey: accountOwner)
        session.scheduleItemId = UUID()
        session.sourceKind = TodayScheduleSourceKind.template
        session.sourceId = "template-1"
        session.sourceTitleSnapshot = "赛前热身"
        session.sourcePayloadVersion = 1
        session.sourcePayloadSnapshot = Data("snapshot".utf8)
        session.setProgress(role: TodayScheduleProgressRole.neutral, effect: "none")
        context.insert(session)
        context.insert(SyncPendingItem(
            entityType: SyncEntityType.trainingSession,
            entityId: session.id,
            operation: SyncOperation.create,
            ownerKey: accountOwner
        ))
        try context.save()

        let backend = RetryBackend()
        SyncQueueManager.shared.backend = backend
        let auth = AuthState()
        auth.login(user: AppUser(id: "v54-user", provider: .apple))
        await SyncQueueManager.shared.processQueue(authState: auth)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncPendingItem>()).count, 1)

        await backend.allowSuccess()
        await SyncQueueManager.shared.processQueue(authState: auth)

        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)
        let uploaded = await backend.uploaded
        XCTAssertEqual(uploaded.count, 2)
        XCTAssertEqual(uploaded.last?.scheduleItemId, session.scheduleItemId?.uuidString)
        XCTAssertEqual(uploaded.last?.sourceKind, TodayScheduleSourceKind.template)
        XCTAssertEqual(uploaded.last?.sourcePayloadSnapshot, Data("snapshot".utf8))
        XCTAssertEqual(uploaded.last?.progressEffect, "none")
    }

    private func arrangeCurrentOfficialLesson() throws -> (
        plan: OfficialPlan, active: UserActivePlan, item: TodayScheduleItem, frozenNames: [String]
    ) {
        let plan = try XCTUnwrap(PlanContentService.decodePlanFromBundle(id: "plan_beginner"))
        let active = UserActivePlan(planId: plan.id, ownerKey: owner)
        active.currentLessonId = plan.lessons[0].id
        active.currentWeek = plan.stages[0].order
        active.currentDay = plan.lessons[0].order
        context.insert(active)
        try context.save()
        let service = TodayTrainingScheduleService(context: context)
        let result = try service.addOfficialLessons(
            plan: plan, lessonIDs: [plan.lessons[0].id], activePlan: active
        ).first
        let item: TodayScheduleItem
        switch try XCTUnwrap(result) {
        case .added(let value): item = value
        case .alreadyPresent(let value): item = value
        }
        let payload = try JSONDecoder().decode(ScheduledLessonPayload.self, from: item.payloadSnapshot)
        return (plan, active, item, payload.drills?.map(\.name) ?? [])
    }

    private func fetchItem(id: UUID) throws -> TodayScheduleItem? {
        var descriptor = FetchDescriptor<TodayScheduleItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
