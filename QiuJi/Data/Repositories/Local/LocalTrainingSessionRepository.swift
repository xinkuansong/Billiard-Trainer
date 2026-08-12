import Foundation
import SwiftData

@MainActor
final class LocalTrainingSessionRepository: TrainingSessionRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func create(ballType: String) async throws -> TrainingSession {
        let session = TrainingSession(ballType: ballType)
        context.insert(session)
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: session.id, operation: "create")
        return session
    }

    func fetchAll() async throws -> [TrainingSession] {
        let descriptor = FetchDescriptor<TrainingSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByDate(from: Date, to: Date) async throws -> [TrainingSession] {
        let predicate = #Predicate<TrainingSession> { session in
            session.date >= from && session.date <= to
        }
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func update(_ session: TrainingSession) async throws {
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: session.id, operation: "update")
    }

    func delete(_ session: TrainingSession) async throws {
        // id 必须在 delete 之前取：删除后再读已删除的模型对象会崩。
        let sessionId = session.id
        context.delete(session)
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: sessionId, operation: SyncOperation.delete)
    }
}
