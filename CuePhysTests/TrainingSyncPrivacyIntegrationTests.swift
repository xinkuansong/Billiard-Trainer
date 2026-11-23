import SwiftData
import XCTest
@testable import QiuJi

/// Launch with the private fixture produced by tasks/launch-20261110/verify-sync-privacy.cjs.
@MainActor
final class TrainingSyncPrivacyIntegrationTests: XCTestCase {
    private struct Actor: Decodable { let id: String; let token: String }
    private struct Fixture: Decodable { let url: URL; let A: Actor; let B: Actor }
    private struct TokenStore: APITokenStore {
        let token: String?
        func load(_ key: KeychainService.Key) -> String? { key == .accessToken ? token : nil }
        func save(_ value: String, for key: KeychainService.Key) -> Bool { false }
    }
    private struct Session: AuthSessionBackend, AuthCredentialStore {
        var hasRefreshToken: Bool { false }
        func clearAll() {}
        func logout() async {}
        func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    }

    func testGuestConsentAndOwnerIsolationAgainstLocalDatabase() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["CUEPHYS_SYNC_FIXTURE"] ?? env["TEST_RUNNER_CUEPHYS_SYNC_FIXTURE"] else {
            throw XCTSkip("Requires the disposable loopback MongoDB fixture")
        }
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(f.url.host, "127.0.0.1")
        guard f.url.host == "127.0.0.1", f.url.scheme == "http" else { throw URLError(.badURL) }

        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let owner = CurrentOwnerContext.shared
        let guest = owner.guestOwnerKey
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let history = LocalTrainingSessionRepository(context: context, ownerContext: owner)
        let auth = AuthState(backend: Session(), credentials: Session(), defaults: defaults, ownerContext: owner)
        let queue = SyncQueueManager.shared
        let restore = SyncRestoreService.shared
        let previousDefaults = restore.defaults
        queue.configure(context: context)
        restore.configure(context: context)
        restore.defaults = defaults
        defer {
            queue.backend = LiveSyncBackend()
            restore.backend = LiveSyncRestoreBackend()
            restore.defaults = previousDefaults
            owner.useGuest()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }

        // Real REST clients. Change the synthetic credential only on a login transition.
        func connect(_ actor: Actor?) -> AccountDataCoordinator {
            let api = APIClient(baseURL: f.url, tokenStore: TokenStore(token: actor?.token))
            let service = BackendSyncService(api: api)
            queue.backend = LiveSyncBackend(service: service)
            restore.backend = LiveSyncRestoreBackend(service: service)
            let coordinator = AccountDataCoordinator(ownerContext: owner, defaults: defaults,
                formationService: CustomFormationSyncService(backend: FormationRESTBackend(client: api)),
                formationDirectory: folder, monitorNetwork: false)
            coordinator.configure(context: context)
            return coordinator
        }
        func checkpoint(_ phase: String) async throws {
            var request = URLRequest(url: f.url.appendingPathComponent("fixture/" + phase))
            request.httpMethod = "POST"
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                XCTFail("Unexpected request or server record in the phase preceding " + phase)
                throw URLError(.badServerResponse)
            }
        }
        func practice(_ note: String) async throws {
            let vm = ActiveTrainingViewModel(mode: .free)
            defer { vm.cleanup() }
            vm.restDuration = 0
            await vm.loadDrills()
            vm.addDrill(try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c001")))
            XCTAssertFalse(vm.drillSetsData.first?.isEmpty ?? true)
            vm.completeSet(drillIndex: 0, setIndex: 0)
            vm.saveTrainingNote(note)
            vm.saveTraining(context: context)
            XCTAssertTrue(vm.didSaveSuccessfully, vm.saveError ?? note)
        }
        func visible(_ notes: [String]) async throws {
            let rows = try await history.fetchAll()
            XCTAssertEqual(rows.map(\.note).sorted(), notes.sorted())
            XCTAssertTrue(rows.allSatisfy { $0.ownerKey == owner.ownerKey })
        }

        try await checkpoint("guest")
        var sync = connect(nil)
        auth.loginAnonymously()
        try await practice("guest")
        await sync.syncActiveAccount(mode: .full, authState: auth)
        try await visible(["guest"])

        try await checkpoint("offA")
        sync = connect(f.A)
        auth.login(user: AppUser(id: f.A.id, provider: .apple))
        XCTAssertFalse(auth.cloudSyncEnabled)
        auth.setCloudSyncEnabled(false)
        await sync.handleCompletedLogin(userId: f.A.id, authState: auth)
        try await visible([])
        try await practice("account-a")
        await sync.syncActiveAccount(mode: .incremental, authState: auth)

        try await checkpoint("offB")
        await auth.logout()
        try await visible(["guest"])
        sync = connect(f.B)
        auth.login(user: AppUser(id: f.B.id, provider: .wechat))
        XCTAssertFalse(auth.cloudSyncEnabled)
        try await visible([])
        try await practice("account-b")
        await sync.syncActiveAccount(mode: .full, authState: auth)
        try await visible(["account-b"])

        try await checkpoint("beforeDecline")
        await auth.logout()
        sync = connect(f.A)
        auth.login(user: AppUser(id: f.A.id, provider: .apple))
        try await visible(["account-a"])
        auth.setCloudSyncEnabled(true)
        await sync.handleCompletedLogin(userId: f.A.id, authState: auth)
        XCTAssertTrue(auth.showMigrationPrompt)
        await sync.syncActiveAccount(mode: .incremental, authState: auth)

        try await checkpoint("decline")
        auth.dismissMigration()
        await sync.declineGuestMigration(userId: f.A.id, authState: auth)
        try await visible(["account-a"])
        XCTAssertEqual(queue.pendingCount(ownerKey: guest), 1)

        try await checkpoint("disabled")
        auth.setCloudSyncEnabled(false)
        try await practice("deferred-a")
        await sync.syncActiveAccount(mode: .full, authState: auth)
        try await visible(["account-a","deferred-a"])

        try await checkpoint("beforeAccept")
        auth.setCloudSyncEnabled(true)
        await sync.handleCompletedLogin(userId: f.A.id, authState: auth)
        XCTAssertTrue(auth.showMigrationPrompt)
        await sync.syncActiveAccount(mode: .incremental, authState: auth)

        try await checkpoint("accept")
        auth.confirmMigration()
        await sync.confirmGuestMigration(userId: f.A.id, authState: auth)
        try await visible(["account-a","deferred-a","guest"])
        XCTAssertEqual(queue.pendingCount(ownerKey: guest), 0)
        XCTAssertEqual(queue.pendingCount(ownerKey: owner.ownerKey), 0)

        try await checkpoint("syncB")
        await auth.logout()
        try await visible([])
        sync = connect(f.B)
        auth.login(user: AppUser(id: f.B.id, provider: .wechat))
        XCTAssertFalse(auth.cloudSyncEnabled)
        auth.setCloudSyncEnabled(true)
        await sync.handleCompletedLogin(userId: f.B.id, authState: auth)
        try await visible(["account-b","cloud-b"])

        try await checkpoint("offAgain")
        auth.setCloudSyncEnabled(false)
        try await practice("only-local-b")
        await sync.syncActiveAccount(mode: .incremental, authState: auth)
        try await visible(["account-b","cloud-b","only-local-b"])
        try await checkpoint("childGuest")
        await auth.logout()
        sync = connect(nil)
        auth.chooseLocalTrainingForAge()
        try await practice("private-child")
        await sync.syncActiveAccount(mode: .full, authState: auth)
        try await visible(["private-child"])
        XCTAssertFalse(auth.canImportGuestData)

        // A later eligible login on this installation may sync its own account only.
        try await checkpoint("afterChildGuest")
        defaults.set("2000-01-01", forKey: AuthState.localOnlyDayKey(in: defaults))
        sync = connect(f.A)
        auth.login(user: AppUser(id: f.A.id, provider: .apple))
        XCTAssertNil(auth.initialProfileImport)
        await sync.handleCompletedLogin(userId: f.A.id, authState: auth)
        XCTAssertFalse(auth.showMigrationPrompt)
        await sync.confirmGuestMigration(userId: f.A.id, authState: auth)
        try await visible(["account-a","deferred-a","guest"])
        await auth.logout()
        try await visible(["private-child"])
        try await checkpoint("done")
    }
}
