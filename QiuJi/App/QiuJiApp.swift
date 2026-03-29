import SwiftUI
import SwiftData

@main
struct QiuJiApp: App {
    @StateObject private var authState = AuthState()
    @StateObject private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer = ModelContainerFactory.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authState)
                .environmentObject(appRouter)
                .tint(.btPrimary)
                .onAppear {
                    SyncQueueManager.shared.configure(context: modelContainer.mainContext)
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
