import Foundation
import SwiftData

/// 同步队列真正需要的窄接口（v36 W2）：上传一条训练、上传一条角度成绩、删除服务端训练副本。
/// 抽出它是为了让队列的 operation 分发与失败分类可单测而不必真打服务器；
/// 生产实现是 `BackendSyncService.shared` 的薄包装。
protocol SyncBackend: Sendable {
    func uploadSession(_ dto: TrainingSessionDTO) async throws
    func uploadAngleTest(_ dto: AngleTestDTO) async throws
    func deleteSession(clientId: String) async throws
}

struct LiveSyncBackend: SyncBackend {
    func uploadSession(_ dto: TrainingSessionDTO) async throws {
        try await BackendSyncService.shared.uploadSession(dto)
    }

    func uploadAngleTest(_ dto: AngleTestDTO) async throws {
        try await BackendSyncService.shared.uploadAngleTest(dto)
    }

    func deleteSession(clientId: String) async throws {
        try await BackendSyncService.shared.deleteSession(clientId: clientId)
    }
}

@MainActor
final class SyncQueueManager: ObservableObject {

    static let shared = SyncQueueManager()
    private init() {}

    private var context: ModelContext?

    /// 队列使用的后端。生产为 `LiveSyncBackend`；单测注入 mock（完成标准禁止真打服务器）。
    var backend: SyncBackend = LiveSyncBackend()

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: - Enqueue

    func enqueue(entityType: String, entityId: UUID, operation: String,
                 ownerKey: String? = nil) {
        guard let context else { return }
        let resolvedOwner = ownerKey ?? CurrentOwnerContext.shared.ownerKey
        let item = SyncPendingItem(entityType: entityType, entityId: entityId,
                                   operation: operation, ownerKey: resolvedOwner)
        context.insert(item)
        do {
            try context.save()
        } catch {
            // 静默吞这里等于「同步项凭空消失」（FL-029）。没有可自动恢复的路径，
            // 至少让失败可定位：下次入队/保存成功时未落盘的项会一并写入。
            print("[SyncQueue] 入队保存失败 entityType=\(entityType) entityId=\(entityId) " +
                  "operation=\(operation) error=\(error)")
        }
    }

    // MARK: - Process Queue

    /// 一个队列项的处理结果。`permanentFailure` 与 `succeeded` 都会出队，
    /// 区别只在前者要打日志——服务端明确拒绝时重试永远不会变成功。
    private enum ItemOutcome {
        case succeeded
        case permanentFailure(String)
        case retryLater(String)
    }

    func processQueue(authState: AuthState, shouldContinue: () -> Bool = { true }) async {
        guard shouldContinue() else { return }
        guard authState.isLoggedIn, let userID = authState.currentUser?.id else { return }
        guard let context else { return }
        let ownerKey = OwnerKey.account(userID)

        let descriptor = FetchDescriptor<SyncPendingItem>(
            predicate: #Predicate { $0.ownerKey == ownerKey },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let pending: [SyncPendingItem]
        do {
            pending = try context.fetch(descriptor)
        } catch {
            // 取不出队列 = 整条同步链路静默停摆，必须留痕（FL-029）。
            print("[SyncQueue] 读取待同步队列失败 error=\(error)")
            return
        }
        guard !pending.isEmpty else { return }

        for item in pending {
            guard shouldContinue(), authState.isLoggedIn, authState.currentUser?.id == userID else { break }
            let outcome = await process(item, ownerKey: ownerKey, context: context)
            switch outcome {
            case .succeeded:
                context.delete(item)
            case .permanentFailure(let reason):
                print("[SyncQueue] 永久失败，丢弃队列项 entityType=\(item.entityType) " +
                      "entityId=\(item.entityId) operation=\(item.operation) \(reason)")
                context.delete(item)
            case .retryLater(let reason):
                print("[SyncQueue] 暂时失败，保留重试 entityType=\(item.entityType) " +
                      "entityId=\(item.entityId) operation=\(item.operation) \(reason)")
            }
        }

        do {
            try context.save()
        } catch {
            // 出队没落盘 ⇒ 下次激活会重复上传。上传端点按 clientId upsert、删除端点幂等，
            // 重复不产生脏数据，但必须能看见，否则队列「删不掉」会变成无声的死循环。
            print("[SyncQueue] 队列出队保存失败，本轮出队未落盘（下次激活会重跑）error=\(error)")
        }
    }

    private func process(_ item: SyncPendingItem, ownerKey: String,
                         context: ModelContext) async -> ItemOutcome {
        switch (item.entityType, item.operation) {
        case (SyncEntityType.trainingSession, SyncOperation.delete):
            return await deleteTrainingSession(clientId: item.entityId)
        case (SyncEntityType.trainingSession, _):
            return await uploadTrainingSession(clientId: item.entityId, ownerKey: ownerKey,
                                               context: context)
        case (SyncEntityType.angleTestResult, SyncOperation.delete):
            // 客户端目前没有单条角度成绩的删除入口（v36 W2 走查确认），后端也没有对应端点。
            // 真出现这种项只能是脏数据：留着会每次激活重试，故直接丢弃并留痕。
            return .permanentFailure("AngleTestResult 删除同步未实现")
        case (SyncEntityType.angleTestResult, _):
            return await uploadAngleTest(clientId: item.entityId, ownerKey: ownerKey,
                                         context: context)
        default:
            return .permanentFailure("未知 entityType，无处理路径")
        }
    }

    private func uploadTrainingSession(clientId: UUID, ownerKey: String,
                                       context: ModelContext) async -> ItemOutcome {
        var descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.id == clientId && $0.ownerKey == ownerKey }
        )
        descriptor.fetchLimit = 1
        // 实体已不在本地 ⇒ 它在入队之后被删除了。此时 create/update 项无内容可传，
        // 直接出队；服务端副本由随后那条（createdAt 更晚的）delete 项负责清理，
        // 而删除端点对「服务端本就没有」也返回 2xx，故两种顺序都收敛到正确结果。
        guard let session = (try? context.fetch(descriptor))?.first else { return .succeeded }
        let dto = TrainingSessionDTO(from: session)
        do {
            try await backend.uploadSession(dto)
            return .succeeded
        } catch {
            return classify(error)
        }
    }

    private func uploadAngleTest(clientId: UUID, ownerKey: String,
                                 context: ModelContext) async -> ItemOutcome {
        var descriptor = FetchDescriptor<AngleTestResult>(
            predicate: #Predicate { $0.id == clientId && $0.ownerKey == ownerKey }
        )
        descriptor.fetchLimit = 1
        // 同 `uploadTrainingSession`：本地已删除 ⇒ 无内容可传，出队。
        guard let result = (try? context.fetch(descriptor))?.first else { return .succeeded }
        let dto = AngleTestDTO(from: result)
        do {
            try await backend.uploadAngleTest(dto)
            return .succeeded
        } catch {
            return classify(error)
        }
    }

    /// delete 项不回查实体：实体已被删除，回查必然落空。payload 只需 clientId。
    private func deleteTrainingSession(clientId: UUID) async -> ItemOutcome {
        do {
            try await backend.deleteSession(clientId: clientId.uuidString)
            return .succeeded
        } catch {
            return classify(error)
        }
    }

    /// 失败分类（v36 Q4）：只有「服务端明确拒绝且重试不会改变结果」才算永久失败。
    /// - 4xx：请求本身有问题（如字段非法），重试多少次都一样 ⇒ 出队。
    ///   例外 401 / 408 / 429：分别是 token 过期、超时、限流，都会随时间/重新登录恢复 ⇒ 保留。
    /// - 5xx / 网络错误 / 解码失败：服务端或链路问题，可能自愈 ⇒ 保留重试。
    private func classify(_ error: Error) -> ItemOutcome {
        if case AppError.serverError(let statusCode, let message) = error,
           Self.isPermanentStatus(statusCode) {
            return .permanentFailure("status=\(statusCode) body=\(message.prefix(200))")
        }
        return .retryLater("error=\(error)")
    }

    private static func isPermanentStatus(_ statusCode: Int) -> Bool {
        guard (400..<500).contains(statusCode) else { return false }
        return ![401, 408, 429].contains(statusCode)
    }

    // MARK: - Queue Count (for UI badges)

    func pendingCount(ownerKey: String? = nil) -> Int {
        guard let context else { return 0 }
        let resolvedOwner = ownerKey ?? CurrentOwnerContext.shared.ownerKey
        let descriptor = FetchDescriptor<SyncPendingItem>(
            predicate: #Predicate { $0.ownerKey == resolvedOwner }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
