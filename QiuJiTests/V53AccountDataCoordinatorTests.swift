import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class V53AccountDataCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var ownerContext: CurrentOwnerContext!
    private var auth: AuthState!
    private var coordinator: AccountDataCoordinator!
    private var syncBackend: CoordinatorSyncBackend!
    private var restoreBackend: CoordinatorRestoreBackend!

    override func setUp() {
        super.setUp()
        suiteName = "V53AccountDataCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        ownerContext = CurrentOwnerContext(defaults: defaults)
        auth = AuthState(backend: CoordinatorAuthBackend(),
                         credentials: CoordinatorCredentialStore(),
                         defaults: defaults,
                         ownerContext: ownerContext)
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        coordinator = AccountDataCoordinator(ownerContext: ownerContext, defaults: defaults)
        coordinator.configure(context: context)
        SyncQueueManager.shared.configure(context: context)
        SyncRestoreService.shared.configure(context: context)
        SyncRestoreService.shared.defaults = defaults
        syncBackend = CoordinatorSyncBackend()
        restoreBackend = CoordinatorRestoreBackend()
        SyncQueueManager.shared.backend = syncBackend
        SyncRestoreService.shared.backend = restoreBackend
    }

    override func tearDown() {
        SyncQueueManager.shared.backend = LiveSyncBackend()
        SyncRestoreService.shared.backend = LiveSyncRestoreBackend()
        SyncRestoreService.shared.defaults = .standard
        defaults.removePersistentDomain(forName: suiteName)
        coordinator = nil
        auth = nil
        ownerContext = nil
        context = nil
        container = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_loginWithGuestData_waitsForConsentAndUploadsNothing() async throws {
        let guest = ownerContext.guestOwnerKey
        let session = TrainingSession(ownerKey: guest)
        context.insert(session)
        context.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                       entityId: session.id,
                                       operation: SyncOperation.create,
                                       ownerKey: guest))
        try context.save()

        auth.login(user: AppUser(id: "user-a", provider: .apple))
        await coordinator.handleCompletedLogin(userId: "user-a", authState: auth)

        XCTAssertTrue(auth.showMigrationPrompt)
        XCTAssertTrue(auth.pendingMigration)
        let uploads = await syncBackend.uploadCount
        let fetches = await restoreBackend.fetchCount
        XCTAssertEqual(uploads, 0)
        XCTAssertEqual(fetches, 0)
        XCTAssertEqual(session.ownerKey, guest)
    }

    func test_declineMigration_onlyPullsAccount_andLeavesGuestData() async throws {
        let guest = ownerContext.guestOwnerKey
        let session = TrainingSession(ownerKey: guest)
        context.insert(session)
        context.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                       entityId: session.id,
                                       operation: SyncOperation.create,
                                       ownerKey: guest))
        try context.save()
        auth.login(user: AppUser(id: "user-a", provider: .apple))
        await coordinator.handleCompletedLogin(userId: "user-a", authState: auth)

        auth.dismissMigration()
        await coordinator.declineGuestMigration(userId: "user-a", authState: auth)

        let uploads = await syncBackend.uploadCount
        let fetches = await restoreBackend.fetchCount
        XCTAssertEqual(uploads, 0)
        XCTAssertEqual(fetches, 2) // sessions + angle tests
        XCTAssertEqual(session.ownerKey, guest)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: guest), 1)
    }

    func test_confirmMigration_transfersOnce_thenUploadsAccountQueue() async throws {
        let guest = ownerContext.guestOwnerKey
        let account = OwnerKey.account("user-a")
        let session = TrainingSession(ownerKey: guest)
        context.insert(session)
        context.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                       entityId: session.id,
                                       operation: SyncOperation.create,
                                       ownerKey: guest))
        try context.save()
        auth.login(user: AppUser(id: "user-a", provider: .apple))
        await coordinator.handleCompletedLogin(userId: "user-a", authState: auth)

        auth.confirmMigration()
        await coordinator.confirmGuestMigration(userId: "user-a", authState: auth)
        await coordinator.confirmGuestMigration(userId: "user-a", authState: auth)

        XCTAssertEqual(session.ownerKey, account)
        let uploads = await syncBackend.uploadCount
        XCTAssertEqual(uploads, 1)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: account), 0)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: guest), 0)
    }

    func test_delayedRestoreFromA_isDiscardedAfterSwitchToB() async throws {
        let remote = TrainingSession(ownerKey: ownerContext.guestOwnerKey)
        let dto = TrainingSessionDTO(from: remote)
        let delayed = DelayedCoordinatorRestoreBackend(dto: dto)
        SyncRestoreService.shared.backend = delayed

        auth.login(user: AppUser(id: "user-a", provider: .apple))
        let task = Task {
            await coordinator.handleCompletedLogin(userId: "user-a", authState: auth)
        }
        await delayed.waitUntilRequested()

        auth.login(user: AppUser(id: "user-b", provider: .apple))
        await delayed.resume()
        await task.value

        let rows = try context.fetch(FetchDescriptor<TrainingSession>())
            .filter { $0.id.uuidString == dto.clientId }
        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(ownerContext.ownerKey, OwnerKey.account("user-b"))
    }

    func test_pendingDeletionCleanupRetriesOnNextConfigure() throws {
        let account = OwnerKey.account("deleted-user")
        let session = TrainingSession(ownerKey: account)
        context.insert(session)
        context.insert(SyncPendingItem(entityType: SyncEntityType.trainingSession,
                                       entityId: session.id,
                                       operation: SyncOperation.update,
                                       ownerKey: account))
        try context.save()

        let beforeRestart = AccountDataCoordinator(ownerContext: ownerContext, defaults: defaults)
        beforeRestart.markAccountDeletionForLocalCleanup(userId: "deleted-user")
        XCTAssertEqual(beforeRestart.pendingDeletionCleanupUserIds, Set(["deleted-user"]))

        let afterRestart = AccountDataCoordinator(ownerContext: ownerContext, defaults: defaults)
        afterRestart.configure(context: context)

        XCTAssertEqual(session.ownerKey, ownerContext.guestOwnerKey)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: account), 0)
        XCTAssertEqual(SyncQueueManager.shared.pendingCount(ownerKey: ownerContext.guestOwnerKey), 0)
        XCTAssertTrue(afterRestart.pendingDeletionCleanupUserIds.isEmpty)
    }
}

private struct CoordinatorAuthBackend: AuthSessionBackend {
    func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    func logout() async {}
}

private struct CoordinatorCredentialStore: AuthCredentialStore {
    var hasRefreshToken: Bool { false }
    func clearAll() {}
}

private actor CoordinatorSyncBackend: SyncBackend {
    private(set) var uploadCount = 0
    func uploadSession(_ dto: TrainingSessionDTO) async throws { uploadCount += 1 }
    func uploadAngleTest(_ dto: AngleTestDTO) async throws { uploadCount += 1 }
    func deleteSession(clientId: String) async throws { uploadCount += 1 }
}

private actor CoordinatorRestoreBackend: SyncRestoreBackend {
    private(set) var fetchCount = 0
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
        fetchCount += 1
        return []
    }
    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] {
        fetchCount += 1
        return []
    }
}

private actor DelayedCoordinatorRestoreBackend: SyncRestoreBackend {
    private let dto: TrainingSessionDTO
    private var requested = false
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    init(dto: TrainingSessionDTO) { self.dto = dto }

    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
        requested = true
        requestWaiters.forEach { $0.resume() }
        requestWaiters.removeAll()
        await withCheckedContinuation { resumeContinuation = $0 }
        return try Self.records(dto)
    }

    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] { [] }

    func waitUntilRequested() async {
        if requested { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }

    private static func records(_ dto: TrainingSessionDTO) throws
        -> [SyncedRecord<TrainingSessionDTO>] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["updatedAt"] = "2026-09-03T00:00:00.000Z"
        let payload = try JSONSerialization.data(withJSONObject: [object])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy
        return try decoder.decode([SyncedRecord<TrainingSessionDTO>].self, from: payload)
    }
}
