import SwiftUI
import SwiftData

@main
struct QiuJiApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var appRouter = AppRouter()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = ModelContainerFactory.makeContainer()

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
                .environmentObject(appRouter)
                .environmentObject(subscriptionManager)
                .tint(.btPrimary)
                .onAppear {
                    SyncQueueManager.shared.configure(context: modelContainer.mainContext)
                    // v29 W5：给 W5 之前落库的角度成绩补建 cognitive 会话归属。
                    // 幂等（只处理 sessionId == nil），标志丢失也不会重复建会话。
                    CognitiveSessionBackfill.runOnceIfNeeded(context: modelContainer.mainContext)
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
                            await SyncQueueManager.shared.processQueue(authState: authState)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didRequestDataMigration)) { _ in
                    Task { await migrateAnonymousData() }
                }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func migrateAnonymousData() async {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<TrainingSession>(
            sortBy: [SortDescriptor(\.date)]
        )
        guard let sessions = try? context.fetch(descriptor), !sessions.isEmpty else { return }
        do {
            let result = try await BackendSyncService.shared.migrateLocalSessions(sessions)
            print("[Migration] Uploaded \(result.upserted) sessions")
        } catch {
            print("[Migration] Failed: \(error.localizedDescription)")
            authState.errorMessage = "数据同步失败，稍后会自动重试"
        }
    }
}
