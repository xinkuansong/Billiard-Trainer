import XCTest
import SwiftData
@testable import QiuJi

/// v36 W2：删除同步（Q2）与队列失败分类（Q4）。
///
/// 网络层用 `SyncBackend` 协议注入 mock —— 完成标准明令禁止真打服务器。
@MainActor
final class V36W2DeleteSyncTests: XCTestCase {

    /// 记录调用并按需抛错的假后端。用 actor 而非 class：`SyncBackend: Sendable`，
    /// 带可变状态的 class 无法安全满足该约束。
    actor MockSyncBackend: SyncBackend {
        private(set) var uploadedSessionClientIds: [String] = []
        private(set) var uploadedAngleTestClientIds: [String] = []
        private(set) var deletedClientIds: [String] = []
        private var errorToThrow: Error?

        init(errorToThrow: Error? = nil) {
            self.errorToThrow = errorToThrow
        }

        func uploadSession(_ dto: TrainingSessionDTO) async throws {
            uploadedSessionClientIds.append(dto.clientId)
            if let errorToThrow { throw errorToThrow }
        }

        func uploadAngleTest(_ dto: AngleTestDTO) async throws {
            uploadedAngleTestClientIds.append(dto.clientId)
            if let errorToThrow { throw errorToThrow }
        }

        func deleteSession(clientId: String) async throws {
            deletedClientIds.append(clientId)
            if let errorToThrow { throw errorToThrow }
        }
    }

    var container: ModelContainer!
    var context: ModelContext!
    var repo: LocalTrainingSessionRepository!
    var authState: AuthState!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
        repo = LocalTrainingSessionRepository(context: context)
        authState = AuthState()
        authState.login(user: AppUser(id: "u1", provider: .apple))
    }

    override func tearDown() {
        // 单例上的注入必须还原，否则会渗到同进程内其它测试。
        SyncQueueManager.shared.backend = LiveSyncBackend()
        repo = nil
        authState = nil
        context = nil
        container = nil
        super.tearDown()
    }

    private func pendingItems() throws -> [SyncPendingItem] {
        try context.fetch(FetchDescriptor<SyncPendingItem>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    // MARK: - 删除入队 → 调用删除端点 → 出队

    func test_repositoryDelete_enqueuesDeleteItem() async throws {
        let session = try await repo.create(ballType: "chinese8")
        let sessionId = session.id
        try await repo.delete(session)

        let items = try pendingItems()
        print("[W2-删除] 入队项=\(items.map { "\($0.entityType)/\($0.operation)" })")
        let deleteItems = items.filter { $0.operation == SyncOperation.delete }
        XCTAssertEqual(deleteItems.count, 1, "删除训练必须入队一条 delete 项")
        XCTAssertEqual(deleteItems.first?.entityType, SyncEntityType.trainingSession)
        XCTAssertEqual(deleteItems.first?.entityId, sessionId)
    }

    func test_processQueue_deleteItem_callsDeleteEndpointAndDequeues() async throws {
        let mock = MockSyncBackend()
        SyncQueueManager.shared.backend = mock

        let session = try await repo.create(ballType: "chinese8")
        let sessionId = session.id
        try await repo.delete(session)
        XCTAssertEqual(try pendingItems().count, 2, "create + delete 两条待同步项")

        await SyncQueueManager.shared.processQueue(authState: authState)

        let deleted = await mock.deletedClientIds
        let uploaded = await mock.uploadedSessionClientIds
        let remaining = try pendingItems()
        print("[W2-删除] 删除端点收到=\(deleted) 上传端点收到=\(uploaded) 剩余队列=\(remaining.count)")

        XCTAssertEqual(deleted, [sessionId.uuidString], "delete 项必须走删除端点，且 payload 是 clientId")
        XCTAssertTrue(uploaded.isEmpty, "实体已删除，create 项不应再上传")
        XCTAssertTrue(remaining.isEmpty, "成功后两条项都应出队")
    }

    func test_processQueue_deleteItem_doesNotRequireLocalEntity() async throws {
        // delete 项不回查实体：实体早已被删掉，回查必然落空。
        let mock = MockSyncBackend()
        SyncQueueManager.shared.backend = mock
        let orphanId = UUID()
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: orphanId, operation: SyncOperation.delete)

        await SyncQueueManager.shared.processQueue(authState: authState)

        let deleted = await mock.deletedClientIds
        print("[W2-删除] 无本地实体时删除端点收到=\(deleted)")
        XCTAssertEqual(deleted, [orphanId.uuidString])
        XCTAssertTrue(try pendingItems().isEmpty)
    }

    // MARK: - 失败分类（Q4）

    func test_permanentFailure_4xx_dequeuesWithoutRetry() async throws {
        let mock = MockSyncBackend(
            errorToThrow: AppError.serverError(statusCode: 400, message: "clientId 非法")
        )
        SyncQueueManager.shared.backend = mock
        let sessionId = UUID()
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: sessionId, operation: SyncOperation.delete)

        await SyncQueueManager.shared.processQueue(authState: authState)
        let afterFirst = try pendingItems().count

        // 再跑一轮：项已出队，后端不应被二次调用。
        await SyncQueueManager.shared.processQueue(authState: authState)
        let calls = await mock.deletedClientIds
        print("[W2-分类] 4xx 后剩余队列=\(afterFirst) 后端累计调用=\(calls.count)")

        XCTAssertEqual(afterFirst, 0, "4xx 是永久失败，必须出队")
        XCTAssertEqual(calls.count, 1, "出队后不得再重试")
    }

    func test_networkError_keepsItemForRetry() async throws {
        let mock = MockSyncBackend(errorToThrow: AppError.networkError("网络连接失败"))
        SyncQueueManager.shared.backend = mock
        let sessionId = UUID()
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: sessionId, operation: SyncOperation.delete)

        await SyncQueueManager.shared.processQueue(authState: authState)
        let afterFirst = try pendingItems().count
        await SyncQueueManager.shared.processQueue(authState: authState)
        let calls = await mock.deletedClientIds
        print("[W2-分类] 网络错误后剩余队列=\(afterFirst) 后端累计调用=\(calls.count)")

        XCTAssertEqual(afterFirst, 1, "网络错误须保留队列项")
        XCTAssertEqual(calls.count, 2, "保留的项下次激活会重试")
    }

    func test_serverError_5xx_keepsItemForRetry() async throws {
        let mock = MockSyncBackend(
            errorToThrow: AppError.serverError(statusCode: 503, message: "Service Unavailable")
        )
        SyncQueueManager.shared.backend = mock
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: UUID(), operation: SyncOperation.delete)

        await SyncQueueManager.shared.processQueue(authState: authState)
        let remaining = try pendingItems().count
        print("[W2-分类] 5xx 后剩余队列=\(remaining)")
        XCTAssertEqual(remaining, 1, "5xx 可能自愈，须保留重试")
    }

    func test_serverError_401_keepsItemForRetry() async throws {
        // 401 落在 4xx 区间，但它随「重新登录」自愈，丢弃会真丢用户数据。
        let mock = MockSyncBackend(
            errorToThrow: AppError.serverError(statusCode: 401, message: "Unauthorized")
        )
        SyncQueueManager.shared.backend = mock
        SyncQueueManager.shared.enqueue(entityType: SyncEntityType.trainingSession,
                                        entityId: UUID(), operation: SyncOperation.delete)

        await SyncQueueManager.shared.processQueue(authState: authState)
        let remaining = try pendingItems().count
        print("[W2-分类] 401 后剩余队列=\(remaining)")
        XCTAssertEqual(remaining, 1, "401 须保留，等重新登录后重试")
    }

    // MARK: - create/update 分发未受影响

    func test_createItem_stillUploadsSession() async throws {
        let mock = MockSyncBackend()
        SyncQueueManager.shared.backend = mock
        let session = try await repo.create(ballType: "snooker")

        await SyncQueueManager.shared.processQueue(authState: authState)

        let uploaded = await mock.uploadedSessionClientIds
        let deleted = await mock.deletedClientIds
        print("[W2-分发] create 项 上传=\(uploaded) 删除=\(deleted)")
        XCTAssertEqual(uploaded, [session.id.uuidString])
        XCTAssertTrue(deleted.isEmpty, "create 项不得走删除端点")
        XCTAssertTrue(try pendingItems().isEmpty)
    }
}
