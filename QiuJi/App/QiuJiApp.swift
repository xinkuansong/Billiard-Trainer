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
                }
                .task {
                    await subscriptionManager.checkEntitlements()
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
