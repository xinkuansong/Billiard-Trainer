import Foundation
import SwiftData

// MARK: - 服务端记录信封

/// 服务端记录 = 既有 DTO（W1 定稿，本轮不改其字段集）+ Mongoose `timestamps: true`
/// 自动维护的 `updatedAt`。增量锚点必须用**服务端时钟**：后端 GET 过滤的是
/// `updatedAt > after`，若拿客户端时钟当锚点，客户端快于服务端时会永久漏掉
/// 那段时间差内落库的记录（且没有任何报错，属静默丢数据）。
///
/// 用外层信封而不是给 DTO 加字段：`updatedAt` 是传输层元数据，不属于业务 DTO，
/// 且本批红线明令不改 DTO 字段集。
struct SyncedRecord<Payload: Decodable>: Decodable {
    let payload: Payload
    /// 旧后端/未来精简响应可能没有它。缺失时不推进锚点（宁可下次重拉，不可跳过）。
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey { case updatedAt }

    init(from decoder: Decoder) throws {
        payload = try Payload(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

extension SyncedRecord: Sendable where Payload: Sendable {}

/// 下行恢复需要的窄接口（v36 W3）。与 W2 的 `SyncBackend` 同构：抽出它是为了让
/// 合并/幂等/删除竞态逻辑可单测而不必真打服务器。
protocol SyncRestoreBackend: Sendable {
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>]
    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>]
}

struct LiveSyncRestoreBackend: SyncRestoreBackend {
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
        try await BackendSyncService.shared.fetchSessionsAfter(after)
    }

    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] {
        try await BackendSyncService.shared.fetchAngleTestsAfter(after)
    }
}

// MARK: - 下行恢复

/// 服务端副本 → 本地 SwiftData 的恢复链路（v36 Q3 / D-v36-1）。
///
/// **合并语义：insert-if-absent，本地永不被远端覆盖。**
/// 依据：本地模型没有 `updatedAt`（本轮红线：不做 Schema V4），无法与服务端
/// `updatedAt` 做「谁更新」的比较；在拿不到可信比较依据时覆盖本地 = 有可能用旧的
/// 服务端副本盖掉刚编辑过的本地记录，那是真丢用户数据。反过来「不覆盖」的代价
/// 只是服务端上更新的版本晚一点才体现——而本地任何一次编辑都会入队上传，
/// 服务端最终会被本地版本覆盖，方向自洽（当前是单设备模型；多设备合并按
/// D-v36-2 的同款结论，属未来需求）。
///
/// **删除竞态**：本地删了一条、delete 队列项还没发出去时拉取，会把它拉回来
/// （「删除后无法恢复」的承诺被打破）。两道处置：
/// 1. 调用方顺序固定为「先 `processQueue` 推、再 `restore` 拉」——推成功后服务端
///    副本已消失，拉取自然拉不到；
/// 2. 推失败（离线/5xx）时队列项会保留，本服务在合并前把队列里所有 delete 项的
///    clientId 收进跳过集合。两道叠加后，只有「delete 项彻底丢失」才会复活，
///    而那已是队列本身的数据丢失，不在本层可控范围。
@MainActor
final class SyncRestoreService: ObservableObject {

    static let shared = SyncRestoreService()
    private init() {}

    private var context: ModelContext?

    /// 生产为 `LiveSyncRestoreBackend`；单测注入 mock（完成标准禁止真打服务器）。
    var backend: SyncRestoreBackend = LiveSyncRestoreBackend()

    /// 增量锚点存储。UserDefaults 而非新增 SwiftData 记录：锚点是纯客户端同步元数据、
    /// 单键值、丢了只会多拉一次（合并幂等），为它加实体就要动 Schema，
    /// 而本轮红线是不做 Schema V4。测试注入独立 suite 以免污染。
    var defaults: UserDefaults = .standard

    enum Mode {
        /// 登录成功后：`after=nil`，把服务端该账号的记录全量拉回。
        case full
        /// 前台激活：`after=` 上次拉取到的服务端 `updatedAt` 最大值。
        case incremental
    }

    struct RestoreSummary: Equatable {
        var insertedSessions = 0
        var skippedSessions = 0
        var insertedAngleTests = 0
        var skippedAngleTests = 0
    }

    func configure(context: ModelContext) {
        self.context = context
    }

    // MARK: - 锚点

    /// 锚点按 userId 分键：换账号登录若共用一个锚点，新账号的历史数据会被判为
    /// 「早于锚点」而永远拉不到。
    private func anchorKey(_ kind: String, userId: String) -> String {
        "sync.restore.anchor.\(kind).\(userId)"
    }

    func anchor(_ kind: AnchorKind, userId: String) -> Date? {
        let raw = defaults.double(forKey: anchorKey(kind.rawValue, userId: userId))
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    private func setAnchor(_ date: Date, _ kind: AnchorKind, userId: String) {
        defaults.set(date.timeIntervalSince1970, forKey: anchorKey(kind.rawValue, userId: userId))
    }

    enum AnchorKind: String {
        case sessions
        case angleTests
    }

    // MARK: - 入口

    @discardableResult
    func restore(userId: String, mode: Mode) async -> RestoreSummary {
        var summary = RestoreSummary()
        guard let context else {
            print("[SyncRestore] 未 configure(context:)，跳过恢复 userId=\(userId)")
            return summary
        }

        await restoreSessions(userId: userId, mode: mode, context: context, summary: &summary)
        await restoreAngleTests(userId: userId, mode: mode, context: context, summary: &summary)
        return summary
    }

    private func restoreSessions(userId: String, mode: Mode,
                                 context: ModelContext, summary: inout RestoreSummary) async {
        let after = (mode == .full) ? nil : anchor(.sessions, userId: userId)
        let records: [SyncedRecord<TrainingSessionDTO>]
        do {
            records = try await backend.fetchSessions(after: after)
        } catch {
            // 静默吞下等于「恢复功能看起来跑过了其实什么都没拉」（FL-029）。
            print("[SyncRestore] 拉取训练记录失败 after=\(String(describing: after)) " +
                  "error=\(describe(error))")
            return
        }
        guard !records.isEmpty else { return }

        guard let skipIds = pendingDeleteSessionIds(context: context) else { return }
        var insertedThisBatch = Set<UUID>()

        for record in records {
            let dto = record.payload
            guard let uuid = UUID(uuidString: dto.clientId) else {
                print("[SyncRestore] 跳过：clientId 不是合法 UUID clientId=\(dto.clientId)")
                summary.skippedSessions += 1
                continue
            }
            if skipIds.contains(uuid) {
                print("[SyncRestore] 跳过：本地已删除且 delete 队列项尚未发出 clientId=\(dto.clientId)")
                summary.skippedSessions += 1
                continue
            }
            if insertedThisBatch.contains(uuid) || sessionExists(uuid, context: context) {
                // 幂等：同一 clientId 重复拉取不重复建；本地已有则本地版本优先（见类型注释）。
                summary.skippedSessions += 1
                continue
            }
            context.insert(makeSession(from: dto, id: uuid))
            insertedThisBatch.insert(uuid)
            summary.insertedSessions += 1
        }

        guard save(context: context, what: "训练记录") else { return }
        advanceAnchor(from: records.map(\.updatedAt), kind: .sessions, userId: userId)
    }

    private func restoreAngleTests(userId: String, mode: Mode,
                                   context: ModelContext, summary: inout RestoreSummary) async {
        let after = (mode == .full) ? nil : anchor(.angleTests, userId: userId)
        let records: [SyncedRecord<AngleTestDTO>]
        do {
            records = try await backend.fetchAngleTests(after: after)
        } catch {
            print("[SyncRestore] 拉取角度成绩失败 after=\(String(describing: after)) " +
                  "error=\(describe(error))")
            return
        }
        guard !records.isEmpty else { return }

        var insertedThisBatch = Set<UUID>()
        for record in records {
            let dto = record.payload
            guard let uuid = UUID(uuidString: dto.clientId) else {
                print("[SyncRestore] 跳过：角度成绩 clientId 不是合法 UUID clientId=\(dto.clientId)")
                summary.skippedAngleTests += 1
                continue
            }
            if insertedThisBatch.contains(uuid) || angleTestExists(uuid, context: context) {
                summary.skippedAngleTests += 1
                continue
            }
            context.insert(makeAngleTest(from: dto, id: uuid))
            insertedThisBatch.insert(uuid)
            summary.insertedAngleTests += 1
        }

        guard save(context: context, what: "角度成绩") else { return }
        advanceAnchor(from: records.map(\.updatedAt), kind: .angleTests, userId: userId)
    }

    // MARK: - 合并辅助

    /// 返回队列中所有待发出的 delete 项 clientId；读队列失败返回 `nil`，
    /// 调用方据此**整轮放弃恢复**——判断不了「哪些是已删待推」还照插，就是让
    /// 已删记录复活（用户看到的是「删了又回来」）。少恢复一轮下次激活会重来。
    private func pendingDeleteSessionIds(context: ModelContext) -> Set<UUID>? {
        let deleteOp = SyncOperation.delete
        let entityType = SyncEntityType.trainingSession
        let descriptor = FetchDescriptor<SyncPendingItem>(
            predicate: #Predicate { $0.operation == deleteOp && $0.entityType == entityType }
        )
        do {
            return Set(try context.fetch(descriptor).map(\.entityId))
        } catch {
            print("[SyncRestore] 读取删除队列失败，为避免已删记录复活，本轮放弃恢复 " +
                  "error=\(describe(error))")
            return nil
        }
    }

    private func sessionExists(_ id: UUID, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            // 查不到不等于不存在。判「不存在」会重复插入，判「存在」只是少恢复一条
            // （下次激活还会再拉），故取后者。
            print("[SyncRestore] 查重失败，按已存在处理 clientId=\(id.uuidString) error=\(describe(error))")
            return true
        }
    }

    private func angleTestExists(_ id: UUID, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<AngleTestResult>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try !context.fetch(descriptor).isEmpty
        } catch {
            print("[SyncRestore] 角度成绩查重失败，按已存在处理 clientId=\(id.uuidString) " +
                  "error=\(describe(error))")
            return true
        }
    }

    /// DTO → 实体重建。9 个 v36 W1 新字段全部还原，`unitLabel` 尤其不能丢：
    /// 「局/次」被当「球」是语义错误（契约 §5.2）。
    /// `DrillEntry`/`DrillSet` 的本地 id 是新生成的——服务端子文档 `_id: false`，
    /// 本就没有可还原的 id，且它们只被父对象引用，不参与任何跨端标识。
    private func makeSession(from dto: TrainingSessionDTO, id: UUID) -> TrainingSession {
        let session = TrainingSession(ballType: dto.ballType, kind: dto.kind)
        session.id = id
        session.date = dto.date
        session.totalDurationMinutes = dto.totalDurationMinutes
        session.note = dto.note
        session.planId = dto.planId
        session.drillEntries = dto.drillEntries.map { entryDTO in
            let entry = DrillEntry(
                drillId: entryDTO.drillId,
                drillNameZh: entryDTO.drillNameZh,
                orderIndex: entryDTO.orderIndex,
                note: entryDTO.note,
                criteriaText: entryDTO.criteriaText
            )
            entry.sets = entryDTO.sets.map { setDTO in
                DrillSet(
                    setNumber: setDTO.setNumber,
                    targetBalls: setDTO.targetBalls,
                    madeBalls: setDTO.madeBalls,
                    formationToken: setDTO.formationToken,
                    formationName: setDTO.formationName,
                    unitLabel: setDTO.unitLabel,
                    passMade: setDTO.passMade,
                    passTotal: setDTO.passTotal,
                    durationSeconds: setDTO.durationSeconds
                )
            }
            return entry
        }
        return session
    }

    private func makeAngleTest(from dto: AngleTestDTO, id: UUID) -> AngleTestResult {
        let result = AngleTestResult(
            actualAngle: dto.actualAngle,
            userAngle: dto.userAngle,
            pocketType: dto.pocketType,
            quizType: dto.quizType,
            errorMM: dto.errorMM,
            sessionId: dto.sessionId.flatMap(UUID.init(uuidString:))
        )
        result.id = id
        result.date = dto.date
        return result
    }

    private func save(context: ModelContext, what: String) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            // 没落盘却推进锚点 = 这批数据永远拉不回来了，故失败即不推进锚点。
            print("[SyncRestore] 恢复\(what)落盘失败，锚点不推进（下次会重拉）error=\(describe(error))")
            return false
        }
    }

    /// 锚点只取服务端 `updatedAt` 的最大值，且只前进不后退。
    /// 整批都没有 `updatedAt`（旧后端）时保持原值：代价是下次重拉同一窗口，
    /// 而合并是幂等的，不会产生重复实体。
    private func advanceAnchor(from updatedAts: [Date?], kind: AnchorKind, userId: String) {
        guard let maxUpdatedAt = updatedAts.compactMap({ $0 }).max() else { return }
        let current = anchor(kind, userId: userId)
        if current == nil || maxUpdatedAt > current! {
            setAnchor(maxUpdatedAt, kind, userId: userId)
        }
    }

    /// FL-029：解码失败要说清是哪个字段，不能只说「失败了」。
    private func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "\(error)" }
        switch decodingError {
        case .keyNotFound(let key, let ctx):
            return "DecodingError.keyNotFound key=\(key.stringValue) codingPath=\(path(ctx))"
        case .typeMismatch(let type, let ctx):
            return "DecodingError.typeMismatch type=\(type) codingPath=\(path(ctx))"
        case .valueNotFound(let type, let ctx):
            return "DecodingError.valueNotFound type=\(type) codingPath=\(path(ctx))"
        case .dataCorrupted(let ctx):
            return "DecodingError.dataCorrupted codingPath=\(path(ctx)) debug=\(ctx.debugDescription)"
        @unknown default:
            return "DecodingError(未知) \(decodingError)"
        }
    }

    private func path(_ ctx: DecodingError.Context) -> String {
        ctx.codingPath.map(\.stringValue).joined(separator: ".")
    }
}
