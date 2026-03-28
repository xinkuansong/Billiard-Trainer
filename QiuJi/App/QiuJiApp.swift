import SwiftUI
import SwiftData

@main
struct QiuJiApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .environmentObject(appRouter)
                .tint(.btPrimary)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await SyncQueueManager.shared.processQueue(authState: authState)
                        }
                    }
                }
        }
        .modelContainer(ModelContainerFactory.makeContainer())
    }
}
