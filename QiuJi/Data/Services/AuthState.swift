import Foundation

enum AuthProvider: String, Codable, Equatable, Sendable {
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
    var gender: String?
    var birthDate: String?

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
        weeklyGoalDays: Int? = nil,
        gender: String? = nil,
        birthDate: String? = nil
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
        self.gender = gender
        self.birthDate = birthDate
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
            weeklyGoalDays: dto.weeklyGoalDays,
            gender: dto.gender,
            birthDate: dto.birthDate
        )
    }
}

enum AuthPhase: Equatable, Sendable {
    case launching
    case restoring
    case guest(AppUser)
    case signedOut
    case authenticated(AppUser)
    case offlineAccount(AppUser)
    case sessionUnavailable(message: String)
}

protocol AuthSessionBackend: Sendable {
    func fetchProfile() async throws -> UserDTO
    func logout() async
}

extension BackendSyncService: AuthSessionBackend {}

protocol AuthCredentialStore: Sendable {
    var hasRefreshToken: Bool { get }
    var trustedLocalAccount: LocalAccountIdentity? { get }
    func saveTrustedLocalAccount(_ identity: LocalAccountIdentity)
    func clearAll()
}

/// Identity only: never stores or grants Pro, and never authorizes a server request.
struct LocalAccountIdentity: Codable, Equatable, Sendable {
    let userID: String
    let provider: AuthProvider
}

extension AuthCredentialStore {
    var trustedLocalAccount: LocalAccountIdentity? { nil }
    func saveTrustedLocalAccount(_ identity: LocalAccountIdentity) {}
}

struct KeychainAuthCredentialStore: AuthCredentialStore {
    var hasRefreshToken: Bool { KeychainService.load(key: .refreshToken) != nil }
    var trustedLocalAccount: LocalAccountIdentity? {
        guard let value = KeychainService.load(key: .trustedLocalAccount) else { return nil }
        do { return try JSONDecoder().decode(LocalAccountIdentity.self, from: Data(value.utf8)) }
        catch { return nil } // Corrupt identity is fail-closed; do not log account data.
    }
    func saveTrustedLocalAccount(_ identity: LocalAccountIdentity) {
        do {
            let data = try JSONEncoder().encode(identity)
            if !KeychainService.save(key: .trustedLocalAccount, value: String(decoding: data, as: UTF8.self)) {
                print("[Auth] Unable to persist local account identity")
            }
        } catch { print("[Auth] Unable to encode local account identity") }
    }
    func clearAll() { KeychainService.clearAll() }
}

@MainActor
final class AuthState: ObservableObject {
    @Published private(set) var phase: AuthPhase = .launching
    @Published var errorMessage: String?
    @Published var showMigrationPrompt: Bool = false
    @Published var pendingMigration: Bool = false
    @Published var showCloudSyncPrompt = false
    @Published private(set) var cloudSyncEnabled = false
    @Published private(set) var initialProfileImport: InitialProfileImport?
    @Published private(set) var isImportingInitialProfile = false
    @Published private(set) var initialProfileImportError: String?
    private var profileImportTask: Task<Void, Never>?
    private let profileImportBackend: any InitialProfileImportBackend
    private var sessionGeneration: UInt = 0
    private(set) var syncChoiceRevision: UInt = 0

    private func syncPreferenceKey(_ userID: String) -> String { "account.cloudSync.enabled.\(userID)" }

    func setCloudSyncEnabled(_ enabled: Bool) {
        guard isLoggedIn, let userID = currentUser?.id else { return }
        syncChoiceRevision &+= 1
        defaults.set(enabled, forKey: syncPreferenceKey(userID))
        cloudSyncEnabled = enabled
        showCloudSyncPrompt = false
        pendingMigration = enabled
        if !enabled {
            showMigrationPrompt = false
            pendingMigration = false
        }
        NotificationCenter.default.post(name: .didChangeCloudSync, object: userID)
    }

    private func loadSyncPreference(userID: String, offerChoice: Bool) {
        cloudSyncEnabled = defaults.bool(forKey: syncPreferenceKey(userID))
        showCloudSyncPrompt = offerChoice && defaults.object(forKey: syncPreferenceKey(userID)) == nil
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    var currentUser: AppUser? {
        switch phase {
        case .guest(let user), .authenticated(let user), .offlineAccount(let user): return user
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
    var hasLocalAccount: Bool {
        switch phase {
        case .authenticated, .offlineAccount: return true
        default: return false
        }
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
        ownerContext: CurrentOwnerContext? = nil,
        profileImportBackend: any InitialProfileImportBackend = BackendSyncService.shared
    ) {
        self.backend = backend
        self.profileImportBackend = profileImportBackend
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
        let operation = sessionGeneration
        defer {
            isBootstrapping = false
            hasBootstrapped = true
        }

        #if DEBUG
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-syncRepair.loginSheet") {
            defaults.removeObject(forKey: syncPreferenceKey("sync-repair-user"))
            if ProcessInfo.processInfo.arguments.contains("-profileImport.fixture") {
                let guest = DeviceGuestIdentity.ownerKey(in: defaults)
                for (field, value) in ["preferredSport": "zhuifen", "yearsPlaying": "threeToFive",
                                       "gender": "male", "birthDate": "2000-02-29"] {
                    defaults.set(value, forKey: "ownerProfile.\(guest).\(field)")
                }
                let decision = InitialProfileImport(accountID: "sync-repair-user", guestOwner: guest, fields: [:])
                defaults.removeObject(forKey: decision.completionKey)
            }
            loginAnonymously()
            return
        }
        #endif
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
                preferredSport: ProcessInfo.processInfo.arguments.contains("-profile.fixtureChinese8")
                    ? PreferredSport.chinese8.rawValue : PreferredSport.nineBall.rawValue,
                skillLevel: SkillLevel.intermediate.rawValue,
                yearsPlaying: YearsPlaying.threeToFive.rawValue,
                weeklyGoalDays: 4,
                gender: ProcessInfo.processInfo.arguments.contains("-profile.fixtureBasics") ? "female" : nil,
                birthDate: ProcessInfo.processInfo.arguments.contains("-profile.fixtureBasics") ? "2000-01-01" : nil
            )
            ownerContext.useAccount(userID: user.id)
            hasCompletedOnboarding = true
            phase = .authenticated(user)
            loadSyncPreference(userID: user.id, offerChoice: false)
            if ProcessInfo.processInfo.arguments.contains("-syncChoice.explicitLogin") {
                defaults.removeObject(forKey: syncPreferenceKey(user.id))
                login(user: user)
            } else {
                NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
            }
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
            guard operation == sessionGeneration else { return }
            guard user.provider != .anonymous else {
                credentials.clearAll()
                ownerContext.useGuest()
                phase = .signedOut
                return
            }
            ownerContext.useAccount(userID: user.id)
            credentials.saveTrustedLocalAccount(LocalAccountIdentity(userID: user.id, provider: user.provider))
            phase = .authenticated(user)
            loadSyncPreference(userID: user.id, offerChoice: false)
            prepareInitialProfileImport(for: user)
            NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
        } catch AppError.authRequired {
            guard operation == sessionGeneration else { return }
            credentials.clearAll()
            ownerContext.useGuest()
            phase = .signedOut
        } catch {
            guard operation == sessionGeneration else { return }
            if credentials.hasRefreshToken,
               let identity = credentials.trustedLocalAccount,
               !identity.userID.isEmpty, identity.provider != .anonymous {
                ownerContext.useAccount(userID: identity.userID)
                phase = .offlineAccount(AppUser(id: identity.userID, provider: identity.provider))
            } else {
                ownerContext.useGuest()
                phase = .sessionUnavailable(message: "网络暂不可用")
            }
        }
    }

    func retryBootstrap() async {
        switch phase {
        case .sessionUnavailable, .offlineAccount: break
        default: return
        }
        hasBootstrapped = false
        await bootstrap()
    }

    func continueAsGuest() {
        loginAnonymously()
    }

    /// Called only after the backend exchanged a third-party credential for app JWTs.
    func login(user: AppUser) {
        sessionGeneration &+= 1
        resetInitialProfileImport()
        guard user.provider != .anonymous else {
            loginAnonymously()
            return
        }
        ownerContext.useAccount(userID: user.id)
        credentials.saveTrustedLocalAccount(LocalAccountIdentity(userID: user.id, provider: user.provider))
        phase = .authenticated(user)
        loadSyncPreference(userID: user.id, offerChoice: true)
        prepareInitialProfileImport(for: user)
        hasBootstrapped = true
        hasCompletedOnboarding = true
        pendingMigration = false
        showMigrationPrompt = false
        NotificationCenter.default.post(name: .didCompleteLogin, object: user.id)
    }

    func loginAnonymously() {
        sessionGeneration &+= 1
        resetInitialProfileImport()
        credentials.clearAll()
        cloudSyncEnabled = false
        showCloudSyncPrompt = false
        pendingMigration = false
        showMigrationPrompt = false
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
        guard hasLocalAccount || phase == .restoring else { return }
        sessionGeneration &+= 1
        resetInitialProfileImport()
        credentials.clearAll()
        cloudSyncEnabled = false
        showCloudSyncPrompt = false
        pendingMigration = false
        showMigrationPrompt = false
        ownerContext.useGuest()
        phase = .signedOut
        errorMessage = nil
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
        sessionGeneration &+= 1
        resetInitialProfileImport()
        credentials.clearAll()
        cloudSyncEnabled = false
        showCloudSyncPrompt = false
        pendingMigration = false
        showMigrationPrompt = false
        ownerContext.useGuest()
        phase = hasCompletedOnboarding ? .guest(makeGuestUser()) : .signedOut
    }

    private func resetInitialProfileImport() {
        profileImportTask?.cancel()
        profileImportTask = nil
        initialProfileImport = nil
        initialProfileImportError = nil
        isImportingInitialProfile = false
    }

    private func prepareInitialProfileImport(for user: AppUser) {
        initialProfileImport = InitialProfileImport.proposal(for: user, defaults: defaults)
        retryPendingInitialProfileImport()
    }

    /// Login imports the saved onboarding details automatically. A failed attempt keeps
    /// the guest copy and retries when the app becomes active or the user signs in again.
    func retryPendingInitialProfileImport() {
        guard profileImportTask == nil, initialProfileImport != nil, isLoggedIn else { return }
        initialProfileImportError = nil
        let operation = sessionGeneration
        profileImportTask = Task { [weak self] in
            guard let self, self.sessionGeneration == operation, !Task.isCancelled else { return }
            await self.importPendingInitialProfile()
            if self.sessionGeneration == operation { self.profileImportTask = nil }
        }
    }

    private func importPendingInitialProfile() async {
        guard !isImportingInitialProfile, let proposal = initialProfileImport,
              isLoggedIn, let original = currentUser, original.id == proposal.accountID else { return }
        let operation = sessionGeneration
        isImportingInitialProfile = true
        initialProfileImportError = nil
        defer {
            if sessionGeneration == operation { isImportingInitialProfile = false }
        }
        do {
            let dto = try await profileImportBackend.importInitialProfile(proposal)
            guard operation == sessionGeneration, isLoggedIn,
                  currentUser?.id == proposal.accountID else { return }
            guard dto.id == proposal.accountID else { throw AppError.authRequired }
            // Import only profile fields, preserving edits made while this request was in flight.
            guard var merged = currentUser else { return }
            if merged.preferredSport == original.preferredSport { merged.preferredSport = dto.preferredSport }
            if merged.yearsPlaying == original.yearsPlaying { merged.yearsPlaying = dto.yearsPlaying }
            if merged.gender == original.gender { merged.gender = dto.gender }
            if merged.birthDate == original.birthDate { merged.birthDate = dto.birthDate }
            replaceAuthenticatedUser(merged)
            OwnerProfileStore(ownerKey: OwnerKey.account(dto.id), defaults: defaults).load(from: currentUser)
            defaults.set(true, forKey: proposal.completionKey)
            initialProfileImport = nil
        } catch {
            guard operation == sessionGeneration, isLoggedIn,
                  currentUser?.id == proposal.accountID else { return }
            initialProfileImportError = "资料尚未同步，本机资料已保留，将自动重试。"
        }
    }

    private func makeGuestUser() -> AppUser {
        AppUser(id: DeviceGuestIdentity.id(in: defaults), provider: .anonymous)
    }
}

extension Notification.Name {
    static let didRestoreAccountData = Notification.Name("didRestoreAccountData")
    static let didRequestDataMigration = Notification.Name("didRequestDataMigration")
    static let didDeclineDataMigration = Notification.Name("didDeclineDataMigration")
    static let didChangeCloudSync = Notification.Name("didChangeCloudSync")
    static let didCompleteLogin = Notification.Name("didCompleteLogin")
    static let authSessionInvalidated = Notification.Name("authSessionInvalidated")
    static let didRequestResumeTraining = Notification.Name("didRequestResumeTraining")
    static let didDismissActiveTraining = Notification.Name("didDismissActiveTraining")
}

#if DEBUG && targetEnvironment(simulator)
/// UI regression fixture: exercises the real login sheet, consent and restore flow
/// with an isolated backend. Never exchanges credentials or reaches the network.
struct SyncRepairUITestBackend: AuthSessionBackend, SyncBackend, SyncRestoreBackend, InitialProfileImportBackend {
    let sessions: [SyncedRecord<TrainingSessionDTO>]

    @MainActor
    init() {
        let record = TrainingSession(ownerKey: OwnerKey.account("sync-repair-user"))
        record.note = "云端恢复测试记录"
        record.totalDurationMinutes = 23
        record.kind = TrainingSessionKind.drill
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy
        do {
            sessions = try decoder.decode([SyncedRecord<TrainingSessionDTO>].self,
                                          from: encoder.encode([TrainingSessionDTO(from: record)]))
        } catch {
            preconditionFailure("Invalid sync UI fixture: \(error)")
        }
    }

    func importInitialProfile(_ proposal: InitialProfileImport) async throws -> UserDTO {
        if ProcessInfo.processInfo.arguments.contains("-profileImport.failure") {
            throw AppError.networkError("Fixture offline")
        }
        return UserDTO(id: proposal.accountID, displayName: "同步测试用户", email: nil, provider: "apple",
                       avatarRevision: nil, preferredSport: proposal.fields["preferredSport"], skillLevel: nil,
                       yearsPlaying: proposal.fields["yearsPlaying"], weeklyGoalDays: nil,
                       gender: proposal.fields["gender"], birthDate: proposal.fields["birthDate"])
    }
    func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    func logout() async {}
    func uploadSession(_ dto: TrainingSessionDTO) async throws {}
    func uploadAngleTest(_ dto: AngleTestDTO) async throws {}
    func deleteSession(clientId: String) async throws {}
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
        if ProcessInfo.processInfo.arguments.contains("-syncRepair.restoreFailure") {
            throw AppError.networkError("UI fixture offline")
        }
        return sessions
    }
    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] { [] }
}
#endif
