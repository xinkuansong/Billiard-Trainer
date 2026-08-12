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
    /// Set during login; ProfileView reads this in sheet onDismiss to show the alert after the sheet is gone.
    @Published var pendingMigration: Bool = false

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
        let wasLocalOnly = !isLoggedIn
        currentUser = user
        hasCompletedOnboarding = true
        if wasLocalOnly {
            pendingMigration = true
        }
        // 登录成功是「换机/重装后把数据拉回来」的唯一时机（v36 W3）。
        // 用通知而不是让 LoginView 直接调恢复服务：登录入口不止一个（Apple / 未来
        // 手机号、微信），挂在这里才不会漏。
        NotificationCenter.default.post(name: .didCompleteLogin, object: nil)
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
    /// 登录成功（非匿名）。监听方：`QiuJiApp` 的全量下行恢复。
    static let didCompleteLogin = Notification.Name("didCompleteLogin")
    static let didRequestResumeTraining = Notification.Name("didRequestResumeTraining")
    /// Posted when ActiveTraining fullScreenCover dismisses (MainTabView → TrainingHome reload).
    static let didDismissActiveTraining = Notification.Name("didDismissActiveTraining")
}
