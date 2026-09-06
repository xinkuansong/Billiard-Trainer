import XCTest
@testable import QiuJi

@MainActor
final class AuthStateTests: XCTestCase {
    private actor MockBackend: AuthSessionBackend {
        enum Behavior {
            case success(UserDTO)
            case authRequired
            case networkFailure
        }

        let behavior: Behavior
        let delayNanoseconds: UInt64
        private(set) var fetchCount = 0
        private(set) var logoutCount = 0

        init(behavior: Behavior, delayNanoseconds: UInt64 = 0) {
            self.behavior = behavior
            self.delayNanoseconds = delayNanoseconds
        }

        func fetchProfile() async throws -> UserDTO {
            fetchCount += 1
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            switch behavior {
            case .success(let user): return user
            case .authRequired: throw AppError.authRequired
            case .networkFailure: throw AppError.networkError("offline")
            }
        }

        func logout() async {
            logoutCount += 1
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
    }

    private final class MockCredentials: AuthCredentialStore, @unchecked Sendable {
        private let lock = NSLock()
        private var refreshTokenPresent: Bool
        private(set) var clearCount = 0

        init(hasRefreshToken: Bool) {
            self.refreshTokenPresent = hasRefreshToken
        }

        var hasRefreshToken: Bool {
            lock.lock()
            defer { lock.unlock() }
            return refreshTokenPresent
        }

        func clearAll() {
            lock.lock()
            refreshTokenPresent = false
            clearCount += 1
            lock.unlock()
        }
    }

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AuthStateTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removeSuite(named: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSubscriptionAuthState() -> AuthState {
        AuthState(
            backend: MockBackend(behavior: .networkFailure),
            credentials: MockCredentials(hasRefreshToken: false),
            defaults: defaults,
            ownerContext: CurrentOwnerContext(defaults: defaults)
        )
    }

    private var purchasedEntitlements: [StoreEntitlementSnapshot] {
        [StoreEntitlementSnapshot(productID: StoreKitService.lifetimeID,
                                  expirationDate: nil, revocationDate: nil)]
    }

    func testProLogoutClearsEntitlementsAndReloginRefreshesPurchase() async {
        let state = makeSubscriptionAuthState()
        let snapshots = purchasedEntitlements
        let manager = SubscriptionManager(entitlementLoader: { snapshots },
                                          listenForUpdates: false, useDebugOverrides: false)
        manager.bind(to: state)
        state.login(user: AppUser(id: "pro-user", provider: .apple))
        await manager.checkEntitlements()
        XCTAssertTrue(manager.isPremium)
        XCTAssertEqual(manager.entitlementStatusLabel, "永久有效")

        await state.logout()
        XCTAssertFalse(manager.isPremium)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
        XCTAssertTrue(manager.entitlementSnapshots.isEmpty)
        XCTAssertEqual(manager.entitlementStatusLabel, "未订阅")
        await manager.checkEntitlements() // A transaction update after logout must stay locked.
        XCTAssertFalse(manager.isPremium)
        let restored = await manager.restorePurchases()
        XCTAssertFalse(restored)
        XCTAssertEqual(manager.errorMessage, "请先登录后再恢复购买")

        state.login(user: AppUser(id: "pro-user", provider: .apple))
        await manager.checkEntitlements()
        XCTAssertTrue(manager.isPremium)
    }

    func testProIsClearedForExpiredSessionAndAccountDeletion() async {
        for deleteAccount in [false, true] {
            let state = makeSubscriptionAuthState()
            let snapshots = purchasedEntitlements
            let manager = SubscriptionManager(entitlementLoader: { snapshots },
                                              listenForUpdates: false, useDebugOverrides: false)
            manager.bind(to: state)
            state.login(user: AppUser(id: "pro-user", provider: .apple))
            await manager.checkEntitlements()
            XCTAssertTrue(manager.isPremium)
            if deleteAccount { state.finishAccountDeletion() }
            else { state.invalidateSession() }
            XCTAssertFalse(manager.isPremium)
            await manager.checkEntitlements()
            XCTAssertFalse(manager.isPremium)
        }
    }

    func testGuestColdLaunchCannotReuseAppleEntitlement() async {
        let state = makeSubscriptionAuthState()
        var reads = 0
        let snapshots = purchasedEntitlements
        let manager = SubscriptionManager(entitlementLoader: { reads += 1; return snapshots },
                                          listenForUpdates: false, useDebugOverrides: false)
        manager.bind(to: state)
        state.loginAnonymously()
        await manager.checkEntitlements()
        XCTAssertFalse(manager.isPremium)
        XCTAssertEqual(reads, 0)
    }

    func testProLateEntitlementResultCannotUnlockLoggedOutSession() async {
        let state = makeSubscriptionAuthState()
        var pending: [CheckedContinuation<[StoreEntitlementSnapshot], Never>] = []
        let manager = SubscriptionManager(entitlementLoader: {
            await withCheckedContinuation { pending.append($0) }
        }, listenForUpdates: false, useDebugOverrides: false)
        manager.bind(to: state)
        state.login(user: AppUser(id: "pro-user", provider: .apple))
        let refresh = Task { await manager.checkEntitlements() }
        // Both the login read and explicit refresh are suspended until after logout.
        while pending.count < 2 { await Task.yield() }
        await state.logout()
        for continuation in pending { continuation.resume(returning: purchasedEntitlements) }
        await refresh.value
        await manager.checkEntitlements()
        XCTAssertFalse(manager.isPremium)
        XCTAssertTrue(manager.purchasedProductIDs.isEmpty)
    }

    func testBootstrapWithoutTokenReturnsStableGuestAfterOnboarding() async {
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let backend = MockBackend(behavior: .networkFailure)
        let credentials = MockCredentials(hasRefreshToken: false)
        let state = AuthState(backend: backend, credentials: credentials, defaults: defaults)

        await state.bootstrap()
        let firstID = state.currentUser?.id

        XCTAssertTrue(state.isAnonymous)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertNotNil(firstID)
        let fetchCount = await backend.fetchCount
        XCTAssertEqual(fetchCount, 0)

        let second = AuthState(backend: backend, credentials: credentials, defaults: defaults)
        await second.bootstrap()
        XCTAssertEqual(second.currentUser?.id, firstID)
    }

    func testBootstrapRestoresNormalizedServerUser() async {
        let user = fixtureUser()
        let backend = MockBackend(behavior: .success(user))
        let state = AuthState(
            backend: backend,
            credentials: MockCredentials(hasRefreshToken: true),
            defaults: defaults
        )

        await state.bootstrap()

        XCTAssertEqual(state.phase, .authenticated(AppUser(dto: user)))
        XCTAssertEqual(state.currentUser?.displayName, "球徒")
        XCTAssertFalse(state.showCloudSyncPrompt)
        XCTAssertFalse(state.cloudSyncEnabled)
        let fetchCount = await backend.fetchCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testDefinitiveAuthFailureClearsCredentialsAndSignsOut() async {
        let credentials = MockCredentials(hasRefreshToken: true)
        let state = AuthState(
            backend: MockBackend(behavior: .authRequired),
            credentials: credentials,
            defaults: defaults
        )

        await state.bootstrap()

        XCTAssertEqual(state.phase, .signedOut)
        XCTAssertEqual(credentials.clearCount, 1)
        XCTAssertFalse(credentials.hasRefreshToken)
    }

    func testTemporaryNetworkFailureDoesNotClearCredentialsOrClaimAccount() async {
        let credentials = MockCredentials(hasRefreshToken: true)
        let state = AuthState(
            backend: MockBackend(behavior: .networkFailure),
            credentials: credentials,
            defaults: defaults
        )

        await state.bootstrap()

        guard case .sessionUnavailable = state.phase else {
            return XCTFail("网络失败应进入 sessionUnavailable")
        }
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertEqual(credentials.clearCount, 0)
        XCTAssertTrue(credentials.hasRefreshToken)
    }

    func testConcurrentBootstrapOnlyFetchesOnce() async {
        let backend = MockBackend(
            behavior: .success(fixtureUser()),
            delayNanoseconds: 100_000_000
        )
        let state = AuthState(
            backend: backend,
            credentials: MockCredentials(hasRefreshToken: true),
            defaults: defaults
        )

        async let first: Void = state.bootstrap()
        async let second: Void = state.bootstrap()
        _ = await (first, second)

        let fetchCount = await backend.fetchCount
        XCTAssertEqual(fetchCount, 1)
        XCTAssertTrue(state.isLoggedIn)
    }

    func testConcurrentLogoutRevokesOnceAndAlwaysClearsLocalSession() async {
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let backend = MockBackend(
            behavior: .success(fixtureUser()),
            delayNanoseconds: 100_000_000
        )
        let credentials = MockCredentials(hasRefreshToken: true)
        let state = AuthState(backend: backend, credentials: credentials, defaults: defaults)
        state.login(user: AppUser(dto: fixtureUser()))

        async let first: Void = state.logout()
        async let second: Void = state.logout()
        _ = await (first, second)

        let logoutCount = await backend.logoutCount
        XCTAssertEqual(logoutCount, 1)
        XCTAssertEqual(credentials.clearCount, 1)
        XCTAssertTrue(state.isAnonymous)
    }

    func testSyncChoiceIsPerAccountAndPersistsAcrossAuthStateInstances() {
        let state = makeSubscriptionAuthState()
        state.login(user: AppUser(id: "choice-a", provider: .apple))
        XCTAssertFalse(state.cloudSyncEnabled)
        XCTAssertTrue(state.showCloudSyncPrompt)
        state.setCloudSyncEnabled(false)
        state.login(user: AppUser(id: "choice-b", provider: .apple))
        XCTAssertTrue(state.showCloudSyncPrompt)
        state.setCloudSyncEnabled(true)
        state.login(user: AppUser(id: "choice-a", provider: .apple))
        XCTAssertFalse(state.cloudSyncEnabled)
        XCTAssertFalse(state.showCloudSyncPrompt)
        let second = makeSubscriptionAuthState()
        second.login(user: AppUser(id: "choice-b", provider: .apple))
        XCTAssertTrue(second.cloudSyncEnabled)
        XCTAssertFalse(second.showCloudSyncPrompt)
    }

    func testLateBootstrapCannotReplaceUserWhoJustLoggedIn() async {
        let backend = MockBackend(behavior: .success(fixtureUser()), delayNanoseconds: 100_000_000)
        let state = AuthState(backend: backend, credentials: MockCredentials(hasRefreshToken: true), defaults: defaults)
        let task = Task { await state.bootstrap() }
        while await backend.fetchCount == 0 { await Task.yield() }
        state.login(user: AppUser(id: "new-user", provider: .apple))
        await task.value
        XCTAssertEqual(state.currentUser?.id, "new-user")
    }

    private func fixtureUser() -> UserDTO {
        UserDTO(
            id: "account-1",
            displayName: "球徒",
            email: "player@example.com",
            provider: "apple",
            avatarRevision: 2,
            preferredSport: "chinese8",
            skillLevel: "intermediate",
            yearsPlaying: "threeToFive",
            weeklyGoalDays: 4
        )
    }
}
