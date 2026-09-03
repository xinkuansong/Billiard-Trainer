import SwiftUI
import SwiftData

@main
struct QiuJiApp: App {
    @StateObject private var authState = AuthState()
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
                    // 预热球桌 USDZ 模型缓存：解析 94 MB 模型需数秒，若留到首次进
                    // 2D/3D 球桌页会同步阻塞主线程（进页卡顿根因）。启动即在后台
                    // 线程解析入缓存，之后各页 setupScene 只做毫秒级 clone。
                    await Task.detached(priority: .userInitiated) {
                        TableModelLoader.preloadModel()
                    }.value
                }
                .task {
                    // 预热击球音频引擎：AVAudioEngine 首次冷启动会同步阻塞主线程，
                    // 若发生在首杆触球瞬间会让跟杆动画先于球体推进（视觉上球杆穿过母球）。
                    // 启动后延迟一拍预热，把这次冷启动挪出「首次击球」的动画临界区。
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard UserPreferences.shared.soundEffectsEnabled else { return }
                    ShotSoundBank.shared.prepare()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await dataCoordinator.syncActiveAccount(mode: .incremental,
                                                                    authState: authState)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didCompleteLogin)) { note in
                    guard let userId = note.object as? String else { return }
                    Task {
                        await dataCoordinator.handleCompletedLogin(userId: userId,
                                                                   authState: authState)
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
