import Foundation
import SwiftData

@MainActor
final class LocalAngleTestRepository: AngleTestRepositoryProtocol {
    private let context: ModelContext
    private let sessionRecorder: CognitiveSessionRecorder

    init(context: ModelContext) {
        self.context = context
        self.sessionRecorder = CognitiveSessionRecorder(context: context)
    }

    /// 落库同时把成绩归入 `kind="cognitive"` 会话（契约 §5.3）。
    /// 这里是「练」分区 4 个写入点（角度预测 / 2D·3D 角度 / 瞄准点 / 2D·3D 瞄准点）
    /// 的唯一收敛处，故归属逻辑放在此处而非逐个 VM。
    /// 已带 `sessionId` 的成绩（保存失败后重试）保持原归属不变。
    func save(_ result: AngleTestResult) async throws {
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
                                            entityId: sessionIdToUpload, operation: "create")
        }
        SyncQueueManager.shared.enqueue(entityType: "AngleTestResult", entityId: result.id, operation: "create")
    }

    func fetchAll() async throws -> [AngleTestResult] {
        let descriptor = FetchDescriptor<AngleTestResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
        let predicate = #Predicate<AngleTestResult> { result in
            result.date >= from && result.date <= to
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
