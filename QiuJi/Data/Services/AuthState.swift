import Foundation

enum AuthProvider {
    case apple
    case phone
    case wechat
    case anonymous
}

struct AppUser {
    let id: String
    let provider: AuthProvider
    var displayName: String?
    var phoneNumber: String?
}

@MainActor
final class AuthState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showMigrationPrompt: Bool = false

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var isLoggedIn: Bool { currentUser != nil && currentUser?.provider != .anonymous }
    var isAnonymous: Bool { currentUser?.provider == .anonymous }
    var displayNameOrDefault: String { currentUser?.displayName ?? "球迹用户" }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func login(user: AppUser) {
        let wasAnonymous = isAnonymous
        currentUser = user
        hasCompletedOnboarding = true
        if wasAnonymous {
            showMigrationPrompt = true
        }
    }

    func loginAnonymously() {
        currentUser = AppUser(id: UUID().uuidString, provider: .anonymous)
        hasCompletedOnboarding = true
    }

    func logout() {
        currentUser = nil
    }

    // Called when user confirms migration prompt
    // Actual upload is implemented in T-P2-05 BackendSyncService
    func confirmMigration() {
        showMigrationPrompt = false
        NotificationCenter.default.post(name: .didRequestDataMigration, object: nil)
    }

    func dismissMigration() {
        showMigrationPrompt = false
    }
}

extension Notification.Name {
    static let didRequestDataMigration = Notification.Name("didRequestDataMigration")
    static let didRequestResumeTraining = Notification.Name("didRequestResumeTraining")
}
