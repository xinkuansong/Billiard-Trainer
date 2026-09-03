import Foundation

protocol UserProfileBackend: Sendable {
    func updateProfile(_ update: UserProfileUpdate) async throws -> UserDTO
}

extension BackendSyncService: UserProfileBackend {}

/// 当前 owner 的资料状态。账号资料以服务端响应为真源；游客资料只存本机且按
/// guest ownerKey 隔离，切换账号不会互相覆盖。
@MainActor
final class OwnerProfileStore: ObservableObject {
    @Published private(set) var displayName: String
    @Published private(set) var preferredSport: PreferredSport
    @Published private(set) var skillLevel: SkillLevel
    @Published private(set) var yearsPlaying: YearsPlaying
    @Published private(set) var weeklyGoalDays: Int
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    let ownerKey: String
    private let defaults: UserDefaults
    private let backend: any UserProfileBackend
    private static let persistedFields = [
        "displayName", "preferredSport", "skillLevel", "yearsPlaying", "weeklyGoalDays",
    ]

    init(ownerKey: String,
         defaults: UserDefaults = .standard,
         backend: any UserProfileBackend = BackendSyncService.shared) {
        if ownerKey == DeviceGuestIdentity.ownerKey(in: defaults) {
            Self.migrateLegacyGuestProfile(in: defaults)
        }
        self.ownerKey = ownerKey
        self.defaults = defaults
        self.backend = backend
        displayName = defaults.string(forKey: Self.key(ownerKey, "displayName")) ?? "球迹用户"
        preferredSport = PreferredSport(rawValue:
            defaults.string(forKey: Self.key(ownerKey, "preferredSport")) ?? "") ?? .chinese8
        skillLevel = SkillLevel(rawValue:
            defaults.string(forKey: Self.key(ownerKey, "skillLevel")) ?? "") ?? .beginner
        yearsPlaying = YearsPlaying(rawValue:
            defaults.string(forKey: Self.key(ownerKey, "yearsPlaying")) ?? "") ?? .lessThan1
        let days = defaults.integer(forKey: Self.key(ownerKey, "weeklyGoalDays"))
        weeklyGoalDays = (1...7).contains(days) ? days : 3
    }

    var personalInfoSummary: String { "\(preferredSport.displayName) · \(skillLevel.displayName)" }
    var goalSummary: String { "每周 \(weeklyGoalDays) 天" }

    func load(from user: AppUser?) {
        guard let user, OwnerKey.account(user.id) == ownerKey else { return }
        displayName = user.displayName?.nilIfBlank ?? "球迹用户"
        preferredSport = user.preferredSport.flatMap(PreferredSport.init(rawValue:)) ?? .chinese8
        skillLevel = user.skillLevel.flatMap(SkillLevel.init(rawValue:)) ?? .beginner
        yearsPlaying = user.yearsPlaying.flatMap(YearsPlaying.init(rawValue:)) ?? .lessThan1
        weeklyGoalDays = user.weeklyGoalDays.flatMap { (1...7).contains($0) ? $0 : nil } ?? 3
        persistAll()
    }

    func saveDisplayName(_ value: String, authState: AuthState) async -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep this limit identical to backend/src/services/userProfile.js.
        // Validate before issuing the request so 21–40 character names cannot appear
        // accepted locally and then fail only after the server round trip.
        guard (1...20).contains(trimmed.count) else {
            errorMessage = "昵称需为 1–20 个字符"
            return false
        }
        return await save(
            update: UserProfileUpdate(displayName: trimmed),
            authState: authState,
            guestMutation: { self.displayName = trimmed }
        )
    }

    func setPreferredSport(_ value: PreferredSport, authState: AuthState) async {
        let old = preferredSport
        preferredSport = value
        if !(await save(update: UserProfileUpdate(preferredSport: value.rawValue), authState: authState)) {
            preferredSport = old
        }
    }

    func setSkillLevel(_ value: SkillLevel, authState: AuthState) async {
        let old = skillLevel
        skillLevel = value
        if !(await save(update: UserProfileUpdate(skillLevel: value.rawValue), authState: authState)) {
            skillLevel = old
        }
    }

    func setYearsPlaying(_ value: YearsPlaying, authState: AuthState) async {
        let old = yearsPlaying
        yearsPlaying = value
        if !(await save(update: UserProfileUpdate(yearsPlaying: value.rawValue), authState: authState)) {
            yearsPlaying = old
        }
    }

    func setWeeklyGoalDays(_ value: Int, authState: AuthState) async {
        guard (1...7).contains(value) else { return }
        let old = weeklyGoalDays
        weeklyGoalDays = value
        if !(await save(update: UserProfileUpdate(weeklyGoalDays: value), authState: authState)) {
            weeklyGoalDays = old
        }
    }

    @discardableResult
    private func save(update: UserProfileUpdate,
                      authState: AuthState,
                      guestMutation: (() -> Void)? = nil) async -> Bool {
        errorMessage = nil
        if !authState.isLoggedIn {
            guestMutation?()
            if var guest = authState.currentUser {
                guest.displayName = displayName
                authState.replaceGuestUser(guest)
            }
            persistAll()
            return true
        }

        isSaving = true
        defer { isSaving = false }
        do {
            let user = AppUser(dto: try await backend.updateProfile(update))
            guard authState.isLoggedIn,
                  authState.currentUser?.id == user.id,
                  OwnerKey.account(user.id) == ownerKey else {
                errorMessage = "账号已切换，本次修改未应用"
                return false
            }
            authState.replaceAuthenticatedUser(user)
            load(from: user)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func persistAll() {
        defaults.set(displayName, forKey: Self.key(ownerKey, "displayName"))
        defaults.set(preferredSport.rawValue, forKey: Self.key(ownerKey, "preferredSport"))
        defaults.set(skillLevel.rawValue, forKey: Self.key(ownerKey, "skillLevel"))
        defaults.set(yearsPlaying.rawValue, forKey: Self.key(ownerKey, "yearsPlaying"))
        defaults.set(weeklyGoalDays, forKey: Self.key(ownerKey, "weeklyGoalDays"))
    }

    private static func key(_ owner: String, _ field: String) -> String {
        "ownerProfile.\(owner).\(field)"
    }

    /// Account profile values are a server-backed cache. Once that account has been deleted,
    /// remove every account-scoped presentation value while leaving the device guest intact.
    static func removeLocalProfile(ownerKey: String, in defaults: UserDefaults = .standard) {
        guard ownerKey.hasPrefix("account:") else { return }
        persistedFields.forEach { defaults.removeObject(forKey: key(ownerKey, $0)) }
    }

    /// v53 之前个人资料误存为设备全局偏好。只迁到当前设备游客一次，避免登录账号
    /// 继承另一位用户的昵称、球种、水平和周目标。
    static func migrateLegacyGuestProfile(in defaults: UserDefaults = .standard) {
        let owner = DeviceGuestIdentity.ownerKey(in: defaults)
        let mappings = ["preferredSport", "skillLevel", "yearsPlaying"]
        for field in mappings {
            let destination = key(owner, field)
            if defaults.object(forKey: destination) == nil,
               let legacy = defaults.string(forKey: field) {
                defaults.set(legacy, forKey: destination)
            }
            defaults.removeObject(forKey: field)
        }

        let destination = key(owner, "weeklyGoalDays")
        if defaults.object(forKey: destination) == nil,
           let legacy = defaults.object(forKey: "weeklyGoalDays") as? Int,
           (1...7).contains(legacy) {
            defaults.set(legacy, forKey: destination)
        }
        defaults.removeObject(forKey: "weeklyGoalDays")
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
