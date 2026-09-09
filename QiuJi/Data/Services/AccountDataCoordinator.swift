import Foundation
import SwiftData

/// 认证身份与本地 owner 数据之间的唯一编排入口。
///
/// 登录后先检查 guest 数据；在用户明确选择之前不触碰 guest owner，也不发上传请求。
/// 每次身份事件递增 generation，旧账号的异步结果只能落回它自己的 owner，不能污染新账号。
@MainActor
final class AccountDataCoordinator: ObservableObject {
    private static let pendingDeletionCleanupKey = "account.pendingDeletionCleanupUserIds"

    private let ownerContext: CurrentOwnerContext
    private let defaults: UserDefaults
    private var context: ModelContext?
    private var generation: UInt = 0
    private var offeredMigrationUserId: String?
    @Published private(set) var syncingOwnerKey: String?
    @Published private(set) var statusOwnerKey: String?
    @Published private(set) var statusMessage: String?

    init(ownerContext: CurrentOwnerContext? = nil, defaults: UserDefaults = .standard) {
        self.ownerContext = ownerContext ?? .shared
        self.defaults = defaults
    }

    func configure(context: ModelContext) {
        self.context = context
        retryPendingDeletionCleanups()
    }

    /// 云端删号成功后先持久化补偿标记，再进行本地 owner 迁移。
    /// 即使 App 在迁移中退出，下次 configure 也会幂等重试，避免训练数据成为孤儿。
    func markAccountDeletionForLocalCleanup(userId: String) {
        guard !userId.isEmpty else { return }
        var ids = pendingDeletionCleanupUserIds
        ids.insert(userId)
        persistPendingDeletionCleanupUserIds(ids)
    }

    func preserveDeletedAccountDataAsGuest(userId: String) throws {
        guard let context else { throw AccountDeletionCleanupError.notConfigured }
        _ = try OwnerTransferService(context: context)
            .transfer(from: OwnerKey.account(userId),
                      to: ownerContext.guestOwnerKey,
                      queuePolicy: .discardSource)
        var ids = pendingDeletionCleanupUserIds
        ids.remove(userId)
        persistPendingDeletionCleanupUserIds(ids)
    }

    var pendingDeletionCleanupUserIds: Set<String> {
        Set(defaults.stringArray(forKey: Self.pendingDeletionCleanupKey) ?? [])
    }

    private func retryPendingDeletionCleanups() {
        for userId in pendingDeletionCleanupUserIds.sorted() {
            try? preserveDeletedAccountDataAsGuest(userId: userId)
        }
    }

    private func persistPendingDeletionCleanupUserIds(_ ids: Set<String>) {
        if ids.isEmpty {
            defaults.removeObject(forKey: Self.pendingDeletionCleanupKey)
        } else {
            defaults.set(ids.sorted(), forKey: Self.pendingDeletionCleanupKey)
        }
    }

    func handleCompletedLogin(userId: String, authState: AuthState, offerGuestMigration: Bool = true) async {
        let operation = beginOperation()
        guard isCurrent(userId: userId, operation: operation, authState: authState),
              let context else { return }

        guard authState.cloudSyncEnabled else { return }
        let guestOwner = ownerContext.guestOwnerKey
        do {
            if offerGuestMigration, try OwnerTransferService(context: context).hasOwnedData(ownerKey: guestOwner) {
                // 硬门禁：这里只展示确认；0 次 transfer，0 次 guest upload。
                offeredMigrationUserId = userId
                statusOwnerKey = OwnerKey.account(userId)
                statusMessage = "请选择是否合并游客记录，再继续同步"
                authState.offerMigration()
                return
            }
        } catch {
            authState.errorMessage = "无法检查本机训练数据，请稍后重试"
            return
        }

        authState.pendingMigration = false
        await pushThenPull(userId: userId, mode: .full,
                           operation: operation, authState: authState)
    }

    func confirmGuestMigration(userId: String, authState: AuthState) async {
        let operation = beginOperation()
        guard authState.cloudSyncEnabled, offeredMigrationUserId == userId,
              isCurrent(userId: userId, operation: operation, authState: authState),
              let context else { return }
        let guestOwner = ownerContext.guestOwnerKey
        let accountOwner = OwnerKey.account(userId)
        do {
            _ = try OwnerTransferService(context: context)
                .transfer(from: guestOwner, to: accountOwner)
        } catch {
            authState.errorMessage = "本机数据迁移失败，尚未上传，请稍后重试"
            return
        }
        offeredMigrationUserId = nil
        guard isCurrent(userId: userId, operation: operation, authState: authState) else { return }
        NotificationCenter.default.post(name: .didRestoreAccountData, object: accountOwner)
        await pushThenPull(userId: userId, mode: .full,
                           operation: operation, authState: authState)
    }

    /// 用户拒绝合并时仍同步账号数据；guest 数据和 guest 队列均保持原样。
    func declineGuestMigration(userId: String, authState: AuthState) async {
        let operation = beginOperation()
        guard authState.cloudSyncEnabled, offeredMigrationUserId == userId,
              isCurrent(userId: userId, operation: operation, authState: authState) else { return }
        offeredMigrationUserId = nil
        await pushThenPull(userId: userId, mode: .full,
                           operation: operation, authState: authState)
    }

    func syncActiveAccount(mode: SyncRestoreService.Mode, authState: AuthState) async {
        guard authState.cloudSyncEnabled, authState.isLoggedIn, let userId = authState.currentUser?.id else {
            _ = beginOperation()
            return
        }
        // 有迁移选择尚未完成时，前台激活同样不得绕过同意门禁。
        guard !authState.pendingMigration && !authState.showMigrationPrompt else { return }
        // 前台事件不能作废尚在下载的全量恢复。
        guard syncingOwnerKey != OwnerKey.account(userId) else { return }
        let operation = beginOperation()
        await pushThenPull(userId: userId, mode: mode,
                           operation: operation, authState: authState)
    }

    private func pushThenPull(userId: String,
                              mode: SyncRestoreService.Mode,
                              operation: UInt,
                              authState: AuthState) async {
        guard isCurrent(userId: userId, operation: operation, authState: authState) else { return }
        let ownerKey = OwnerKey.account(userId)
        syncingOwnerKey = ownerKey
        statusOwnerKey = ownerKey
        statusMessage = "正在同步训练记录…"
        authState.errorMessage = nil
        defer {
            if generation == operation { syncingOwnerKey = nil }
        }
        #if DEBUG
        // Identity-only UI fixtures have no server credential. Exercise the controls offline.
        if ProcessInfo.processInfo.arguments.contains("-v53.authenticatedProfileFixture") {
            statusMessage = "测试账号未连接云端"
            return
        }
        #endif
        let choiceRevision = authState.syncChoiceRevision
        let upload = await SyncQueueManager.shared.processQueue(authState: authState) {
            authState.syncChoiceRevision == choiceRevision && authState.cloudSyncEnabled && self.isCurrent(userId: userId, operation: operation, authState: authState)
        }
        guard authState.syncChoiceRevision == choiceRevision,
              isCurrent(userId: userId, operation: operation, authState: authState) else { return }
        let restore = await pull(userId: userId, mode: mode, operation: operation, authState: authState)
        guard authState.syncChoiceRevision == choiceRevision, authState.cloudSyncEnabled,
              isCurrent(userId: userId, operation: operation, authState: authState),
              let restore else { return }
        if upload.failedItems > 0 || restore.hasFailures {
            statusMessage = "同步未完成，请重试。本机记录已保留。"
            authState.errorMessage = statusMessage
        } else {
            statusMessage = "同步完成，本次恢复 \(restore.insertedSessions) 条训练记录、\(restore.insertedAngleTests) 条成绩。"
        }
    }

    private func pull(userId: String,
                      mode: SyncRestoreService.Mode,
                      operation: UInt,
                      authState: AuthState) async -> SyncRestoreService.RestoreSummary? {
        guard isCurrent(userId: userId, operation: operation, authState: authState) else { return nil }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-v53.authenticatedProfileFixture") { return nil }
        #endif
        let choiceRevision = authState.syncChoiceRevision
        return await SyncRestoreService.shared.restore(
            userId: userId,
            mode: mode,
            expectedOwnerContext: ownerContext,
            shouldContinue: {
                authState.syncChoiceRevision == choiceRevision && authState.cloudSyncEnabled && self.isCurrent(userId: userId, operation: operation, authState: authState)
            }
        )
    }

    private func beginOperation() -> UInt {
        generation &+= 1
        syncingOwnerKey = nil
        return generation
    }

    private func isCurrent(userId: String, operation: UInt, authState: AuthState) -> Bool {
        generation == operation
            && authState.isLoggedIn
            && authState.currentUser?.id == userId
            && ownerContext.ownerKey == OwnerKey.account(userId)
    }
}

private enum AccountDeletionCleanupError: Error {
    case notConfigured
}
