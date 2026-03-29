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

    func processQueue(authState: AuthState) async {
        guard authState.isLoggedIn else { return }
        guard let context else { return }

        let descriptor = FetchDescriptor<SyncPendingItem>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }

        for item in pending {
            let success = await uploadItem(item, context: context)
            if success {
                context.delete(item)
            }
        }
        try? context.save()
    }

    private func uploadItem(_ item: SyncPendingItem, context: ModelContext) async -> Bool {
        switch item.entityType {
        case "TrainingSession":
            return await uploadTrainingSession(clientId: item.entityId, context: context)
        case "AngleTestResult":
            return await uploadAngleTest(clientId: item.entityId, context: context)
        default:
            return false
        }
    }

    private func uploadTrainingSession(clientId: UUID, context: ModelContext) async -> Bool {
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == clientId }
        )
        descriptor.fetchLimit = 1
        guard let session = (try? context.fetch(descriptor))?.first else { return true }
        do {
            try await BackendSyncService.shared.syncSession(session)
            return true
        } catch {
            print("[SyncQueue] Upload session failed: \(error.localizedDescription)")
            return false
        }
    }

    private func uploadAngleTest(clientId: UUID, context: ModelContext) async -> Bool {
        var descriptor = FetchDescriptor<AngleTestResult>(
            predicate: #Predicate { $0.id == clientId }
        )
        descriptor.fetchLimit = 1
        guard let result = (try? context.fetch(descriptor))?.first else { return true }
        do {
            try await BackendSyncService.shared.syncAngleTest(result)
            return true
        } catch {
            print("[SyncQueue] Upload angle test failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Queue Count (for UI badges)

    func pendingCount() -> Int {
        guard let context else { return 0 }
        let descriptor = FetchDescriptor<SyncPendingItem>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
