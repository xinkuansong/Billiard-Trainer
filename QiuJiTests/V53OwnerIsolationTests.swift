import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V53OwnerIsolationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var ownerContext: CurrentOwnerContext!

    override func setUp() {
        super.setUp()
        suiteName = "V53OwnerIsolationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        ownerContext = CurrentOwnerContext(defaults: defaults)
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
        SyncRestoreService.shared.configure(context: context)
        SyncRestoreService.shared.defaults = defaults
    }

    override func tearDown() {
        SyncQueueManager.shared.backend = LiveSyncBackend()
        SyncRestoreService.shared.backend = LiveSyncRestoreBackend()
        SyncRestoreService.shared.defaults = .standard
        defaults.removePersistentDomain(forName: suiteName)
        ownerContext = nil
        context = nil
        container = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_deviceGuestOwner_isStableAcrossContextRestart() {
        let first = ownerContext.ownerKey
        let restarted = CurrentOwnerContext(defaults: defaults)
        XCTAssertEqual(first, restarted.ownerKey)
        XCTAssertTrue(first.hasPrefix("guest:"))
        XCTAssertFalse(first.contains(OwnerKey.unassigned))
    }

    func test_queueProcessesOnlyCurrentAccountOwner() async throws {
        let ownerA = OwnerKey.account("user-a")
        let ownerB = OwnerKey.account("user-b")
        let guest = ownerContext.ownerKey
        let a = TrainingSession(ownerKey: ownerA)
        let b = TrainingSession(ownerKey: ownerB)
        let g = TrainingSession(ownerKey: guest)
        context.insert(a); context.insert(b); context.insert(g)
        try context.save()

        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: a.id, operation: SyncOperation.create,
                                        ownerKey: ownerA)
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: b.id, operation: SyncOperation.create,
                                        ownerKey: ownerB)
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: g.id, operation: SyncOperation.create,
                                        ownerKey: guest)

        let backend = V53RecordingSyncBackend()
        SyncQueueManager.shared.backend = backend
        let auth = AuthState(defaults: defaults, ownerContext: ownerContext)
        auth.login(user: AppUser(id: "user-a", provider: .apple))
        await SyncQueueManager.shared.processQueue(authState: auth)

        let uploadedSessionIDs = await backend.uploadedSessionIDs
        XCTAssertEqual(uploadedSessionIDs, [a.id.uuidString])
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: ownerA), 0)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: ownerB), 1)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: guest), 1)
    }

    func test_restoreSameClientID_isSeparatedByAccountOwner() async throws {
        let source = TrainingSession(ownerKey: ownerContext.ownerKey)
        source.note = "same-client-id"
        let dto = TrainingSessionDTO(from: source)
        let records = try makeRecords([dto])
        SyncRestoreService.shared.backend = V53RestoreBackend(records: records)

        await SyncRestoreService.shared.restore(userId: "user-a", mode: .full)
        await SyncRestoreService.shared.restore(userId: "user-b", mode: .full)

        let rows = try context.fetch(FetchDescriptor<TrainingSession>())
            .filter { $0.id.uuidString == dto.clientId }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.ownerKey)),
                       [OwnerKey.account("user-a"), OwnerKey.account("user-b")])
    }

    func test_ownerTransfer_isIdempotent_andMovesQueueWithData() throws {
        let guest = ownerContext.ownerKey
        let account = OwnerKey.account("user-a")
        let session = TrainingSession(ownerKey: guest)
        let favorite = DrillFavorite(drillId: "drill_c001", ownerKey: guest)
        let queue = SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                    entityId: session.id, operation: SyncOperation.create,
                                    ownerKey: guest)
        context.insert(session); context.insert(favorite); context.insert(queue)
        try context.save()

        let service = OwnerTransferService(context: context)
        let first = try service.transfer(from: guest, to: account)
        let second = try service.transfer(from: guest, to: account)

        XCTAssertEqual(first.sessions, 1)
        XCTAssertEqual(first.favorites, 1)
        XCTAssertEqual(first.queueItems, 1)
        XCTAssertEqual(second.total, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TrainingSession>()).map(\.ownerKey), [account])
        XCTAssertEqual(try context.fetch(FetchDescriptor<DrillFavorite>()).map(\.ownerKey), [account])
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncPendingItem>()).map(\.ownerKey), [account])
    }

    func test_ownerTransfer_saveFailure_rollsBackEveryType() throws {
        enum Expected: Error { case saveFailed }
        let guest = ownerContext.ownerKey
        let account = OwnerKey.account("user-a")
        let session = TrainingSession(ownerKey: guest)
        context.insert(session)
        context.insert(AngleTestResult(actualAngle: 30, userAngle: 29,
                                       pocketType: "corner", ownerKey: guest))
        context.insert(CustomPlan(name: "游客计划", sessionsPerWeek: 3, ownerKey: guest))
        context.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                       entityId: session.id,
                                       operation: SyncOperation.update,
                                       ownerKey: guest))
        try context.save()

        let service = OwnerTransferService(context: context) { _ in throw Expected.saveFailed }
        XCTAssertThrowsError(try service.transfer(from: guest, to: account,
                                                  queuePolicy: .discardSource))

        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<TrainingSession>()).map(\.ownerKey)), [guest])
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<AngleTestResult>()).map(\.ownerKey)), [guest])
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<CustomPlan>()).map(\.ownerKey)), [guest])
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<SyncPendingItem>()).map(\.ownerKey)), [guest])
    }

    private func makeRecords(_ dtos: [TrainingSessionDTO]) throws
        -> [SyncedRecord<TrainingSessionDTO>] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let objects: [[String: Any]] = try dtos.enumerated().map { index, dto in
            let data = try encoder.encode(dto)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object["updatedAt"] = iso.string(from: Date(timeIntervalSince1970: 1_780_000_000 + Double(index)))
            return object
        }
        let data = try JSONSerialization.data(withJSONObject: objects)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy
        return try decoder.decode([SyncedRecord<TrainingSessionDTO>].self, from: data)
    }
}

private actor V53RecordingSyncBackend: SyncBackend {
    private(set) var uploadedSessionIDs: [String] = []
    func uploadSession(_ dto: TrainingSessionDTO) async throws {
        uploadedSessionIDs.append(dto.clientId)
    }
    func uploadAngleTest(_ dto: AngleTestDTO) async throws {}
    func deleteSession(clientId: String) async throws {}
}

private struct V53RestoreBackend: SyncRestoreBackend {
    let records: [SyncedRecord<TrainingSessionDTO>]
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] { records }
    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] { [] }
}

final class V53OwnerMigrationTests: XCTestCase {
    private var directory: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("V53OwnerMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("V3.store")
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    func test_V3ToV4_preservesAllTopLevelData_andAssignsOneGuestOwner() throws {
        let v3Schema = Schema(versionedSchema: QiuJiSchemaV3.self)
        let oldContainer = try ModelContainer(
            for: v3Schema,
            configurations: ModelConfiguration(schema: v3Schema, url: storeURL)
        )
        let old = ModelContext(oldContainer)

        let session = QiuJiSchemaV3.TrainingSession(ballType: "snooker", kind: "tool")
        session.note = "V3 session"
        let entry = QiuJiSchemaV3.DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线")
        let set = QiuJiSchemaV3.DrillSet(setNumber: 2, targetBalls: 15, madeBalls: 9)
        old.insert(session); old.insert(entry); old.insert(set)
        entry.session = session; set.entry = entry

        let angle = QiuJiSchemaV3.AngleTestResult(actualAngle: 30, userAngle: 28,
                                                   pocketType: "corner")
        angle.quizType = "geometric"
        old.insert(angle)
        old.insert(QiuJiSchemaV3.DrillFavorite(drillId: "drill_c001"))
        old.insert(QiuJiSchemaV3.UserActivePlan(planId: "plan_beginner"))
        let plan = QiuJiSchemaV3.CustomPlan(name: "V3 plan", sessionsPerWeek: 4)
        let planDrill = QiuJiSchemaV3.CustomPlanDrill(
            drillId: "drill_c013", drillNameZh: "分离角", roundsPerFormation: 3, order: 0
        )
        old.insert(plan); old.insert(planDrill); plan.drills = [planDrill]
        old.insert(QiuJiSchemaV3.SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                                 entityId: session.id,
                                                 operation: SyncOperation.create))
        try old.save()

        let container = try ModelContainerFactory.makeContainer(at: storeURL)
        let current = ModelContext(container)
        let owners = try allOwners(current)
        XCTAssertEqual(owners.count, 1)
        XCTAssertTrue(try XCTUnwrap(owners.first).hasPrefix("guest:"))
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<TrainingSession>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<DrillEntry>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<DrillSet>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<AngleTestResult>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<DrillFavorite>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<UserActivePlan>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<CustomPlan>()), 1)
        XCTAssertEqual(try current.fetchCount(FetchDescriptor<SyncPendingItem>()), 1)
        XCTAssertEqual(try XCTUnwrap(current.fetch(FetchDescriptor<TrainingSession>()).first).note,
                       "V3 session")
        XCTAssertEqual(try XCTUnwrap(current.fetch(FetchDescriptor<CustomPlan>()).first)
            .drills.first?.roundsPerFormation, 3)
    }

    private func allOwners(_ context: ModelContext) throws -> Set<String> {
        var values = Set(try context.fetch(FetchDescriptor<TrainingSession>()).map(\.ownerKey))
        values.formUnion(try context.fetch(FetchDescriptor<AngleTestResult>()).map(\.ownerKey))
        values.formUnion(try context.fetch(FetchDescriptor<DrillFavorite>()).map(\.ownerKey))
        values.formUnion(try context.fetch(FetchDescriptor<UserActivePlan>()).map(\.ownerKey))
        values.formUnion(try context.fetch(FetchDescriptor<CustomPlan>()).map(\.ownerKey))
        values.formUnion(try context.fetch(FetchDescriptor<SyncPendingItem>()).map(\.ownerKey))
        return values
    }
}
