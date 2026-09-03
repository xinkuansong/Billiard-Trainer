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
