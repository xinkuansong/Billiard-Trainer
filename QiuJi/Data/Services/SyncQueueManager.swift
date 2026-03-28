import Foundation
import SwiftData

@MainActor
final class SyncQueueManager: ObservableObject {

    static let shared = SyncQueueManager()
    private init() {}

    private var context: ModelContext?

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: - Enqueue

    func enqueue(entityType: String, entityId: UUID, operation: String) {
        guard let context else { return }
        let item = SyncPendingItem(entityType: entityType, entityId: entityId, operation: operation)
        context.insert(item)
        try? context.save()
    }

    // MARK: - Process Queue

    /// Called when app returns to foreground (scenePhase == .active) and user is logged in.
    /// Actual upload is delegated to BackendSyncService (T-P2-05).
    func processQueue(authState: AuthState) async {
        guard authState.isLoggedIn else { return }
        guard let context else { return }

        let descriptor = FetchDescriptor<SyncPendingItem>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }

        for item in pending {
            let success = await uploadItem(item)
            if success {
                context.delete(item)
            }
        }
        try? context.save()
    }

    private func uploadItem(_ item: SyncPendingItem) async -> Bool {
        // Stub: real implementation in T-P2-05 BackendSyncService
        return false
    }

    // MARK: - Queue Count (for UI badges)

    func pendingCount() -> Int {
        guard let context else { return 0 }
        let descriptor = FetchDescriptor<SyncPendingItem>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
