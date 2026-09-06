import Foundation

enum AuthProvider: String, Equatable, Sendable {
    case apple
    case phone
    case wechat
    case anonymous
}

struct AppUser: Equatable, Sendable {
    let id: String
    let provider: AuthProvider
    var displayName: String?
    var email: String?
    var phoneNumber: String?
    var avatarRevision: Int?
    var preferredSport: String?
    var skillLevel: String?
    var yearsPlaying: String?
    var weeklyGoalDays: Int?

    init(
        id: String,
        provider: AuthProvider,
        displayName: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        avatarRevision: Int? = nil,
        preferredSport: String? = nil,
        skillLevel: String? = nil,
        yearsPlaying: String? = nil,
        weeklyGoalDays: Int? = nil
    ) {
        self.id = id
        self.provider = provider
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.avatarRevision = avatarRevision
        self.preferredSport = preferredSport
        self.skillLevel = skillLevel
        self.yearsPlaying = yearsPlaying
        self.weeklyGoalDays = weeklyGoalDays
    }

    init(dto: UserDTO) {
        self.init(
            id: dto.id,
            provider: AuthProvider(rawValue: dto.provider) ?? .anonymous,
            displayName: dto.displayName,
            email: dto.email,
            avatarRevision: dto.avatarRevision,
            preferredSport: dto.preferredSport,
            skillLevel: dto.skillLevel,
            yearsPlaying: dto.yearsPlaying,
            weeklyGoalDays: dto.weeklyGoalDays
        )
    }
}

enum AuthPhase: Equatable, Sendable {
    case launching
    case restoring
    case guest(AppUser)
    case signedOut
    case authenticated(AppUser)
    case sessionUnavailable(message: String)
}

protocol AuthSessionBackend: Sendable {
    func fetchProfile() async throws -> UserDTO
    func logout() async
}

extension BackendSyncService: AuthSessionBackend {}

protocol AuthCredentialStore: Sendable {
    var hasRefreshToken: Bool { get }
    func clearAll()
}

struct KeychainAuthCredentialStore: AuthCredentialStore {
    var hasRefreshToken: Bool { KeychainService.load(key: .refreshToken) != nil }
    func clearAll() { KeychainService.clearAll() }
}

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var phase: AuthPhase = .launching
    @Published var errorMessage: String?
    @Published var showMigrationPrompt: Bool = false
    @Published var pendingMigration: Bool = false

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    var currentUser: AppUser? {
        switch phase {
        case .guest(let user), .authenticated(let user): return user
        default: return nil
        }
    }
    var isLoading: Bool { phase == .launching || phase == .restoring }
    var isLoggedIn: Bool {
        if case .authenticated = phase { return true }
        return false
    }
    var isAnonymous: Bool {
        if case .guest = phase { return true }
        return false
    }
    var displayNameOrDefault: String { currentUser?.displayName ?? "球迹用户" }

    private static let onboardingKey = "hasCompletedOnboarding"
    private let backend: any AuthSessionBackend
    private let credentials: any AuthCredentialStore
    private let defaults: UserDefaults
    private let ownerContext: CurrentOwnerContext
    private var isBootstrapping = false
    private var hasBootstrapped = false
    private var isLoggingOut = false

    init(
        backend: any AuthSessionBackend = BackendSyncService.shared,
        credentials: any AuthCredentialStore = KeychainAuthCredentialStore(),
        defaults: UserDefaults = .standard,
        ownerContext: CurrentOwnerContext? = nil
    ) {
        self.backend = backend
        self.credentials = credentials
        self.defaults = defaults
        self.ownerContext = ownerContext ?? .shared
        self.hasCompletedOnboarding = defaults.bool(forKey: Self.onboardingKey)
    }

    /// Restores the server-backed identity before account UI is shown. Calls are idempotent;
    /// scene/task duplication cannot issue a second profile request.
    func bootstrap() async {
        guard !hasBootstrapped, !isBootstrapping else { return }
        isBootstrapping = true
        defer {
            isBootstrapping = false
            hasBootstrapped = true
        }

        #if DEBUG
        // Deterministic UI-only fixture for proving that the account surface consumes the
        // server-normalized identity after bootstrap and again after a cold relaunch. This
        // branch is unreachable in Release builds and never creates a production login path.
        if ProcessInfo.processInfo.arguments.contains("-v53.authenticatedProfileFixture") {
            let fixtureName = ProcessInfo.processInfo.arguments.contains("-v57.longProfileName")
                ? String(repeating: "认真练球", count: 5)
                : "服务端球友"
            let user = AppUser(
                id: "v53-server-user",
                provider: .apple,
                displayName: fixtureName,
                // Keep nil so this identity-only fixture never performs an avatar network call.
                avatarRevision: nil,
                preferredSport: PreferredSport.nineBall.rawValue,
                skillLevel: SkillLevel.intermediate.rawValue,
                yearsPlaying: YearsPlaying.threeToFive.rawValue,
                weeklyGoalDays: 4
            )
            ownerContext.useAccount(userID: user.id)
            hasCompletedOnboarding = true
            phase = .authenticated(user)
            NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
            return
        }
        #endif

        guard credentials.hasRefreshToken else {
            ownerContext.useGuest()
            phase = hasCompletedOnboarding ? .guest(makeGuestUser()) : .signedOut
            return
        }

        phase = .restoring
        do {
            let user = AppUser(dto: try await backend.fetchProfile())
            guard user.provider != .anonymous else {
                credentials.clearAll()
                ownerContext.useGuest()
                phase = .signedOut
                return
            }
            ownerContext.useAccount(userID: user.id)
            phase = .authenticated(user)
            NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
        } catch AppError.authRequired {
            credentials.clearAll()
            ownerContext.useGuest()
            phase = .signedOut
        } catch {
            ownerContext.useGuest()
            phase = .sessionUnavailable(message: "暂时无法恢复账号，可稍后重试或继续游客使用")
        }
    }

    func retryBootstrap() async {
        guard case .sessionUnavailable = phase else { return }
        hasBootstrapped = false
        await bootstrap()
    }

    func continueAsGuest() {
        loginAnonymously()
    }

    /// Called only after the backend exchanged a third-party credential for app JWTs.
    func login(user: AppUser) {
        guard user.provider != .anonymous else {
            loginAnonymously()
            return
        }
        ownerContext.useAccount(userID: user.id)
        phase = .authenticated(user)
        hasBootstrapped = true
        hasCompletedOnboarding = true
        pendingMigration = false
        showMigrationPrompt = false
        NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
    }

    func loginAnonymously() {
        ownerContext.useGuest()
        phase = .guest(makeGuestUser())
        hasBootstrapped = true
        hasCompletedOnboarding = true
    }

    /// The single logout path. Server revocation is best-effort; local credentials and
    /// account presentation are always cleared, including while offline.
    func logout() async {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }
        await backend.logout()
        clearLocalSession()
    }

    /// Handles a definitive missing/invalid refresh credential reported by the API layer.
    func invalidateSession() {
        guard isLoggedIn || phase == .restoring else { return }
        credentials.clearAll()
        pendingMigration = false
        ownerContext.useGuest()
        phase = .signedOut
        errorMessage = "登录已过期，请重新登录"
    }

    /// Account deletion already performed its server mutation; W3 inserts the owner-transfer
    /// transaction immediately before this final local session cleanup.
    func finishAccountDeletion() {
        clearLocalSession()
    }

    func replaceAuthenticatedUser(_ user: AppUser) {
        guard case .authenticated(let current) = phase,
              current.id == user.id,
              user.provider != .anonymous else { return }
        phase = .authenticated(user)
    }

    func replaceGuestUser(_ user: AppUser) {
        guard isAnonymous, user.provider == .anonymous else { return }
        phase = .guest(user)
    }

    func confirmMigration() {
        showMigrationPrompt = false
        pendingMigration = false
        NotificationCenter.default.post(name: .didRequestDataMigration,
                                        object: currentUser?.id)
    }

    func dismissMigration() {
        showMigrationPrompt = false
        pendingMigration = false
        NotificationCenter.default.post(name: .didDeclineDataMigration,
                                        object: currentUser?.id)
    }

    func offerMigration() {
        guard isLoggedIn else { return }
        pendingMigration = true
        showMigrationPrompt = true
    }

    private func clearLocalSession() {
        credentials.clearAll()
        pendingMigration = false
        showMigrationPrompt = false
        ownerContext.useGuest()
        phase = hasCompletedOnboarding ? .guest(makeGuestUser()) : .signedOut
    }

    private func makeGuestUser() -> AppUser {
        AppUser(id: DeviceGuestIdentity.id(in: defaults), provider: .anonymous)
    }
}

extension Notification.Name {
    static let didRequestDataMigration = Notification.Name("didRequestDataMigration")
    static let didDeclineDataMigration = Notification.Name("didDeclineDataMigration")
    static let didCompleteLogin = Notification.Name("didCompleteLogin")
    static let authSessionInvalidated = Notification.Name("authSessionInvalidated")
    static let didRequestResumeTraining = Notification.Name("didRequestResumeTraining")
    static let didDismissActiveTraining = Notification.Name("didDismissActiveTraining")
}
