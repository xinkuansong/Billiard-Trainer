import Foundation
import SwiftData

@MainActor
final class LocalAngleTestRepository: AngleTestRepositoryProtocol {
    private let context: ModelContext
    private let sessionRecorder: CognitiveSessionRecorder
    private let ownerContext: CurrentOwnerContext

    init(context: ModelContext, ownerContext: CurrentOwnerContext? = nil) {
        self.context = context
        let resolvedOwnerContext = ownerContext ?? .shared
        self.ownerContext = resolvedOwnerContext
        self.sessionRecorder = CognitiveSessionRecorder(context: context,
                                                        ownerContext: resolvedOwnerContext)
    }

    /// 落库同时把成绩归入 `kind="cognitive"` 会话（契约 §5.3）。
    /// 这里是「练」分区 4 个写入点（角度预测 / 2D·3D 角度 / 瞄准点 / 2D·3D 瞄准点）
    /// 的唯一收敛处，故归属逻辑放在此处而非逐个 VM。
    /// 已带 `sessionId` 的成绩（保存失败后重试）保持原归属不变。
    func save(_ result: AngleTestResult) async throws {
        let ownerKey = ownerContext.ownerKey
        if result.trainingMetadata?.project != nil {
            guard result.ownerKey == ownerKey else { throw TrainingQuotaLedger.Failure.unreadable }
            let id = result.id
            if let existing = try context.fetch(FetchDescriptor<AngleTestResult>(predicate: #Predicate { $0.id == id })).first {
                guard existing.ownerKey == ownerKey else { throw TrainingQuotaLedger.Failure.unreadable }
                // A failed save can leave an inserted model in this context. Flush it
                // before acknowledging the durable pending-answer receipt.
                try context.save()
                if let sessionID = existing.sessionId {
                    SyncQueueManager.shared.enqueue(entityType: "TrainingSession", entityId: sessionID,
                                                    operation: "create", ownerKey: ownerKey)
                }
                SyncQueueManager.shared.enqueue(entityType: "AngleTestResult", entityId: id,
                                                operation: "create", ownerKey: ownerKey)
                return
            }
        } else { result.ownerKey = ownerKey }
        // 会话新建、或复用会话时时长跨过一分钟边界，都要（重新）入队——
        // 否则服务端只会拿到第一题时刻的时长，永远停在 1 分钟。
        // POST /training-sessions 按 clientId upsert，重复入队是幂等的。
        var sessionIdToUpload: UUID?
        if result.sessionId == nil {
            let resolution = try sessionRecorder.resolveSession(for: result)
            result.sessionId = resolution.session.id
            if resolution.needsUpload { sessionIdToUpload = resolution.session.id }
        }

        context.insert(result)
        try context.save()

        if let sessionIdToUpload {
            SyncQueueManager.shared.enqueue(entityType: "TrainingSession",
                                            entityId: sessionIdToUpload, operation: "create",
                                            ownerKey: ownerKey)
        }
        SyncQueueManager.shared.enqueue(entityType: "AngleTestResult", entityId: result.id,
                                        operation: "create", ownerKey: ownerKey)
    }

    func fetchAll() async throws -> [AngleTestResult] {
        let ownerKey = ownerContext.ownerKey
        let descriptor = FetchDescriptor<AngleTestResult>(
            predicate: #Predicate { $0.ownerKey == ownerKey },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
        let ownerKey = ownerContext.ownerKey
        let predicate = #Predicate<AngleTestResult> { result in
            result.ownerKey == ownerKey && result.date >= from && result.date <= to
        }
        let descriptor = FetchDescriptor<AngleTestResult>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func deleteAll() async throws {
        let all = try await fetchAll()
        all.forEach { context.delete($0) }
        try context.save()
    }
}
