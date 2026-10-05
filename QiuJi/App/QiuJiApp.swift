import SwiftUI
import SwiftData
import UserNotifications

@main
struct QiuJiApp: App {
    @UIApplicationDelegateAdaptor(QiuJiOrientationDelegate.self) private var orientationDelegate
    @StateObject private var authState: AuthState
    @StateObject private var ownerContext = CurrentOwnerContext.shared
    @StateObject private var dataCoordinator = AccountDataCoordinator()
    @StateObject private var appRouter = AppRouter()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var avatarStore = AvatarStore.shared
    @Environment(\.scenePhase) private var scenePhase

    /// v50 状态矩阵可显式要求一次性内存库，避免上一轮模拟器里的训练记录
    /// 把“空数据 / 免费门控”用例污染成另一种状态。生产启动没有该参数，仍使用磁盘库。
    let modelContainer = ProcessInfo.processInfo.arguments.contains("-v50.inMemoryStore")
        ? ModelContainerFactory.makeInMemoryContainer()
        : ModelContainerFactory.makeContainer()

    init() {
        UNUserNotificationCenter.current().delegate = TrainingReminderNavigation.shared
        #if DEBUG && targetEnvironment(simulator)
        let authState: AuthState
        if ProcessInfo.processInfo.arguments.contains("-syncRepair.loginSheet") {
            let backend = SyncRepairUITestBackend()
            authState = AuthState(backend: backend)
            SyncQueueManager.shared.backend = backend
            SyncRestoreService.shared.backend = backend
        } else {
            authState = AuthState()
        }
        #else
        let authState = AuthState()
        #endif
        _authState = StateObject(wrappedValue: authState)
        SubscriptionManager.shared.bind(to: authState)

        let brandGreen = UIColor(Color.btPrimary)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let descriptor = UIFont.systemFont(ofSize: 34, weight: .bold)
            .fontDescriptor.withDesign(.rounded) {
            appearance.largeTitleTextAttributes = [
                .font: UIFont(descriptor: descriptor, size: 34),
                .foregroundColor: brandGreen,
            ]
        }
        if let inlineDescriptor = UIFont.systemFont(ofSize: 17, weight: .semibold)
            .fontDescriptor.withDesign(.default) {
            appearance.titleTextAttributes = [
                .font: UIFont(descriptor: inlineDescriptor, size: 17),
                .foregroundColor: brandGreen,
            ]
        }
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().standardAppearance = appearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .environmentObject(ownerContext)
                .environmentObject(dataCoordinator)
                .environmentObject(appRouter)
                .environmentObject(subscriptionManager)
                .environmentObject(avatarStore)
                .tint(.btPrimary)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await TrainingReminderScheduler.shared.reconcile() }
                }
                .onReceive(TrainingReminderNavigation.shared.$pending) { pending in
                    if pending { TrainingReminderNavigation.shared.consume(router: appRouter) }
                }
                .onAppear {
                    SyncQueueManager.shared.configure(context: modelContainer.mainContext)
                    SyncRestoreService.shared.configure(context: modelContainer.mainContext)
                    // v29 W5：给 W5 之前落库的角度成绩补建 cognitive 会话归属。
                    // 幂等（只处理 sessionId == nil），标志丢失也不会重复建会话。
                    CognitiveSessionBackfill.runOnceIfNeeded(context: modelContainer.mainContext)
                }
                .task {
                    // 与 bootstrap 串行配置，避免冷启动 profile 恢复通知先于 coordinator
                    // 拿到 ModelContext，导致首次同步/迁移确认被静默丢弃。
                    dataCoordinator.configure(context: modelContainer.mainContext)
                    #if DEBUG && targetEnvironment(simulator)
                    if ProcessInfo.processInfo.arguments.contains("-syncRepair.loginSheet"),
                       ProcessInfo.processInfo.arguments.contains("-syncRepair.guestData") {
                        let guestRecord = TrainingSession(ownerKey: ownerContext.guestOwnerKey)
                        guestRecord.note = "游客训练记录"
                        modelContainer.mainContext.insert(guestRecord)
                        do { try modelContainer.mainContext.save() }
                        catch { preconditionFailure("Invalid guest UI fixture: \(error)") }
                    }
                    #endif
                    await authState.bootstrap()
                }
                .task {
                    #if DEBUG
                    // Keep premium-gate UI tests deterministic when StoreKit
                    // transactions persist across simulator launches.
                    if ProcessInfo.processInfo.arguments.contains("-forceNonPremium") {
                        return
                    }
                    #endif
                    await subscriptionManager.checkEntitlements()
                }
                .task {
                    DailyClearancePreloader.shared.setForeground(scenePhase != .background)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    DailyClearancePreloader.shared.discard()
                }
                .task {
                    // 预热击球音频引擎：AVAudioEngine 首次冷启动会同步阻塞主线程，
                    // 若发生在首杆触球瞬间会让跟杆动画先于球体推进（视觉上球杆穿过母球）。
                    // 启动后延迟一拍预热，把这次冷启动挪出「首次击球」的动画临界区。
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard UserPreferences.shared.soundEffectsEnabled else { return }
                    ShotSoundBank.shared.prepare()
                }
                .onReceive(UserPreferences.shared.$soundEffectsEnabled) { enabled in
                    if !enabled { ShotAudioScheduler.shared.cancel() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active { DailyClearancePreloader.shared.setForeground(true) }
                    else if newPhase == .background { DailyClearancePreloader.shared.setForeground(false) }
                    if newPhase != .active { ShotAudioScheduler.shared.cancel() }
                    if newPhase == .active {
                        if UserPreferences.shared.soundEffectsEnabled { ShotSoundBank.shared.prepare() }
                        Task {
                            await TrainingReminderScheduler.shared.reconcile()
                            await dataCoordinator.syncActiveAccount(mode: .incremental,
                                                                    authState: authState)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didCompleteLogin)) { note in
                    guard let userId = note.object as? String else { return }
                    Task {
                        await dataCoordinator.handleCompletedLogin(userId: userId,
                                                                   authState: authState,
                                                                   offerGuestMigration: false)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didChangeCloudSync)) { note in
                    guard let userId = note.object as? String else { return }
                    Task {
                        await dataCoordinator.handleCompletedLogin(userId: userId, authState: authState)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .authSessionInvalidated)) { _ in
                    authState.invalidateSession()
                }
                .onReceive(NotificationCenter.default.publisher(for: .didRequestDataMigration)) { note in
                    guard let userId = note.object as? String else { return }
                    Task {
                        await dataCoordinator.confirmGuestMigration(userId: userId,
                                                                    authState: authState)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didDeclineDataMigration)) { note in
                    guard let userId = note.object as? String else { return }
                    Task {
                        await dataCoordinator.declineGuestMigration(userId: userId,
                                                                    authState: authState)
                    }
                }
        }
        .modelContainer(modelContainer)
    }

}

/// Ordinary pages stay portrait; landscape tools own a scene-local override.
@MainActor
final class QiuJiOrientationDelegate: NSObject, UIApplicationDelegate {
    static var masks: [ObjectIdentifier: UIInterfaceOrientationMask] = [:]
    static var owners: [ObjectIdentifier: UUID] = [:]

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let scene = window?.windowScene else { return .portrait }
        return Self.masks[ObjectIdentifier(scene)] ?? .portrait
    }
}

struct DailyTableOrientation: UIViewControllerRepresentable {
    var landscape: Bool
    var onReady: (() -> Void)? = nil
    var onFailure: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.landscape = landscape
        controller.onReady = onReady
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.landscape = landscape
        controller.onReady = onReady
        controller.onFailure = onFailure
        controller.applyOrientation()
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.restorePortrait()
    }

    final class Controller: UIViewController {
        var landscape = false
        var onReady: (() -> Void)?
        var onFailure: (() -> Void)?
        private let owner = UUID()
        private weak var ownedScene: UIWindowScene?
        private var appliedLandscape: Bool?
        private var hasAppeared = false
        private var isRotating = false
        private var deliveredReady = false

        override func viewIsAppearing(_ animated: Bool) {
            super.viewIsAppearing(animated)
            // The lightweight entry can request rotation before navigation finishes.
            // Existing consumers without a readiness gate retain their lifecycle.
            if onReady != nil { applyOrientation() }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
            applyOrientation()
            notifyWhenReady()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            notifyWhenReady()
        }

        override func viewWillTransition(to size: CGSize,
                                         with coordinator: UIViewControllerTransitionCoordinator) {
            isRotating = true
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.isRotating = false
                self?.notifyWhenReady()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            hasAppeared = false
            super.viewWillDisappear(animated)
        }

        private func notifyWhenReady() {
            guard onReady != nil, !deliveredReady else { return }
            // Leave the UIKit layout transaction before publishing SwiftUI state.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.hasAppeared, !self.isRotating, !self.deliveredReady,
                      let scene = self.ownedScene, let window = self.view.window,
                      QiuJiOrientationDelegate.owners[ObjectIdentifier(scene)] == self.owner,
                      scene.interfaceOrientation.isLandscape == self.landscape,
                      (window.bounds.width > window.bounds.height) == self.landscape,
                      (self.view.bounds.width > self.view.bounds.height) == self.landscape,
                      let onReady = self.onReady else { return }
                self.deliveredReady = true
                onReady()
            }
        }

        func applyOrientation() {
            guard let scene = view.window?.windowScene,
                  appliedLandscape != landscape || ownedScene !== scene else { return }
            ownedScene = scene
            appliedLandscape = landscape
            QiuJiOrientationDelegate.owners[ObjectIdentifier(scene)] = owner
            request(landscape ? .landscapeRight : .portrait, in: scene)
        }

        func restorePortrait() {
            guard let scene = ownedScene else { return }
            hasAppeared = false
            if QiuJiOrientationDelegate.owners[ObjectIdentifier(scene)] == owner {
                request(.portrait, in: scene)
                QiuJiOrientationDelegate.masks.removeValue(forKey: ObjectIdentifier(scene))
                QiuJiOrientationDelegate.owners.removeValue(forKey: ObjectIdentifier(scene))
            }
            ownedScene = nil
            appliedLandscape = nil
        }

        private func request(_ mask: UIInterfaceOrientationMask, in scene: UIWindowScene) {
            QiuJiOrientationDelegate.masks[ObjectIdentifier(scene)] = mask
            let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
            root?.setNeedsUpdateOfSupportedInterfaceOrientations()
            root?.presentedViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { [weak self] error in
                NSLog("[DailyTableOrientation] %@", error.localizedDescription)
                guard let self,
                      QiuJiOrientationDelegate.owners[ObjectIdentifier(scene)] == self.owner else { return }
                self.onFailure?()
            }
        }
    }
}
