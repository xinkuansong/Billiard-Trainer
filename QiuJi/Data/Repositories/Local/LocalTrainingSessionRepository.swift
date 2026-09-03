import Foundation
import SwiftData

@MainActor
final class LocalTrainingSessionRepository: TrainingSessionRepositoryProtocol {
    private let context: ModelContext
    private let ownerContext: CurrentOwnerContext

    init(context: ModelContext, ownerContext: CurrentOwnerContext? = nil) {
        self.context = context
        self.ownerContext = ownerContext ?? .shared
    }

    func create(ballType: String) async throws -> TrainingSession {
        let ownerKey = ownerContext.ownerKey
        let session = TrainingSession(ballType: ballType, ownerKey: ownerKey)
        context.insert(session)
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: session.id,
                                        operation: "create", ownerKey: ownerKey)
        return session
    }

    func fetchAll() async throws -> [TrainingSession] {
        let ownerKey = ownerContext.ownerKey
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.ownerKey == ownerKey },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByDate(from: Date, to: Date) async throws -> [TrainingSession] {
        let ownerKey = ownerContext.ownerKey
        let predicate = #Predicate<TrainingSession> { session in
            session.ownerKey == ownerKey && session.date >= from && session.date <= to
        }
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func update(_ session: TrainingSession) async throws {
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: session.id,
                                        operation: "update", ownerKey: session.ownerKey)
    }

    func delete(_ session: TrainingSession) async throws {
        // id 必须在 delete 之前取：删除后再读已删除的模型对象会崩。
        let sessionId = session.id
        let ownerKey = session.ownerKey
        // iOS 17 的 SwiftData 关系级联在保存后仍可能把子对象留在 store；仓储层显式
        // 删除整棵关系图，保证最低支持 Runtime 与新 Runtime 的持久化语义一致。
        for entry in session.drillEntries {
            for set in entry.sets {
                context.delete(set)
            }
            context.delete(entry)
        }
        context.delete(session)
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: sessionId, operation: SyncOperation.delete,
                                        ownerKey: ownerKey)
    }
}
