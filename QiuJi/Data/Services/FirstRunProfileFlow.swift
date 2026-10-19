import Foundation
import SwiftData

/// Installation-level progress, independent of account profiles and display preferences.
@MainActor
final class FirstRunProfileFlow: ObservableObject {
    enum Stage: String { case introduction, profile, completed }
    static let progressKey = "firstRun.profileFlow.v1"
    @Published private(set) var stage: Stage
    private let defaults: UserDefaults

    init(defaults: UserDefaults, hasExistingData: Bool, hasCredentials: Bool = false) {
        self.defaults = defaults
        if hasCredentials {
            stage = .completed
            defaults.set(stage.rawValue, forKey: Self.progressKey)
        } else if let saved = defaults.string(forKey: Self.progressKey).flatMap(Stage.init(rawValue:)) {
            stage = saved
        } else {
            stage = hasExistingData ? .completed : .introduction
            defaults.set(stage.rawValue, forKey: Self.progressKey)
        }
    }

    /// Call before constructing the model container, guest identity or preference singletons.
    /// Those services write defaults even on a brand-new installation.
    static func prepareForLaunch() -> FirstRunProfileFlow {
        #if DEBUG && targetEnvironment(simulator)
        if let fixture = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-firstRun.fixture=") }) {
            // A separate progress domain lets UI tests resume the real flow without erasing
            // the simulator's profiles, credentials, game state or existing onboarding marker.
            let defaults = UserDefaults(suiteName: "com.xinkuan.qiuji.\(fixture)")!
            return FirstRunProfileFlow(defaults: defaults, hasExistingData: false)
        }
        #endif
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        let storeURL = ModelConfiguration(schema: ModelContainerFactory.currentSchema,
                                          isStoredInMemoryOnly: false).url
        let hasCredentials = KeychainAuthCredentialStore().hasRefreshToken
        let hasHistory = hasExistingInstallation(
            persistedKeys: Set(domain.keys),
            completedOnboarding: defaults.bool(forKey: "hasCompletedOnboarding"),
            hasStore: FileManager.default.fileExists(atPath: storeURL.path),
            hasCredentials: hasCredentials
        )
        return FirstRunProfileFlow(defaults: defaults, hasExistingData: hasHistory, hasCredentials: hasCredentials)
    }

    static func hasExistingInstallation(persistedKeys: Set<String>, completedOnboarding: Bool,
                                        hasStore: Bool, hasCredentials: Bool) -> Bool {
        if completedOnboarding || hasStore || hasCredentials { return true }
        // Conservatively preserve any existing app-owned preferences, including legacy guest
        // installations that never completed the former optional introduction. System-only
        // Apple/NS keys do not turn a fresh install into an existing user.
        return persistedKeys.contains {
            $0 != progressKey && !$0.hasPrefix("Apple") && !$0.hasPrefix("NS")
        }
    }

    func finishIntroduction() {
        guard stage == .introduction else { return }
        setStage(.profile)
    }

    func returnToIntroduction() {
        guard stage == .profile else { return }
        setStage(.introduction)
    }

    func finish() { setStage(.completed) }

    private func setStage(_ value: Stage) {
        defaults.set(value.rawValue, forKey: Self.progressKey)
        stage = value
    }
}

/// Nil means no choice was made; Values are submitted only after a choice or explicit confirmation.
struct InitialProfileDraft {
    var displayName = ""
    var preferredSport: PreferredSport?
    var skillLevel: SkillLevel?
    var yearsPlaying: YearsPlaying?
    var gender: ProfileGender?
    var birthDate: String?
}


/// Only values explicitly persisted for this guest are eligible. UI fallback defaults
/// and declined disclosure are never treated as user-supplied profile information.
struct InitialProfileImport: Encodable, Equatable, Identifiable, Sendable {
    let accountID: String
    let guestOwner: String
    let fields: [String: String]
    var id: String { accountID + ":" + guestOwner }
    var completionKey: String { "initialProfileImport.completed." + id }
    enum CodingKeys: String, CodingKey { case accountID, fields }

    @MainActor
    static func proposal(for user: AppUser, defaults: UserDefaults) -> Self? {
        let guest = DeviceGuestIdentity.ownerKey(in: defaults)
        let existing = ["preferredSport": user.preferredSport, "yearsPlaying": user.yearsPlaying,
                        "gender": user.gender, "birthDate": user.birthDate]
        var fields: [String: String] = [:]
        for (field, serverValue) in existing where serverValue == nil {
            guard let value = defaults.string(forKey: "ownerProfile.\(guest).\(field)") else { continue }
            let valid: Bool
            switch field {
            case "preferredSport": valid = PreferredSport(rawValue: value) != nil
            case "yearsPlaying": valid = YearsPlaying(rawValue: value) != nil
            case "gender": valid = value == "male" || value == "female"
            case "birthDate": valid = ProfileBirthday.date(value) != nil
            default: valid = false
            }
            if valid { fields[field] = value }
        }
        let proposal = Self(accountID: user.id, guestOwner: guest, fields: fields)
        guard !fields.isEmpty, !defaults.bool(forKey: proposal.completionKey) else { return nil }
        return proposal
    }


}

protocol InitialProfileImportBackend: Sendable {
    func importInitialProfile(_ proposal: InitialProfileImport) async throws -> UserDTO
}
