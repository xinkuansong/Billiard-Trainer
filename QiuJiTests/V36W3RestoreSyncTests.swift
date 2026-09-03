import XCTest
import SwiftData
@testable import QiuJi

/// v36 W3：下行恢复（Q3 / D-v36-1）。
///
/// 网络层用 `SyncRestoreBackend` 协议注入 mock —— 完成标准明令禁止真打服务器。
/// 所有服务端回包都由「本地实体 → DTO → JSON」真实走一遍编码路径构造，
/// 这样往返测试证明的是**上行编码 → 下行解码 → 实体重建**整条链路，而不是
/// 手搓一个恰好能过的 DTO。
@MainActor
final class V36W3RestoreSyncTests: XCTestCase {

    /// 记录调用参数并按需抛错的假后端。
    actor MockRestoreBackend: SyncRestoreBackend {
        private var sessionRecords: [SyncedRecord<TrainingSessionDTO>]
        private var angleRecords: [SyncedRecord<AngleTestDTO>]
        private var errorToThrow: Error?
        private(set) var sessionAfterArgs: [Date?] = []
        private(set) var angleAfterArgs: [Date?] = []

        init(sessions: [SyncedRecord<TrainingSessionDTO>] = [],
             angleTests: [SyncedRecord<AngleTestDTO>] = [],
             errorToThrow: Error? = nil) {
            self.sessionRecords = sessions
            self.angleRecords = angleTests
            self.errorToThrow = errorToThrow
        }

        func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
            sessionAfterArgs.append(after)
            if let errorToThrow { throw errorToThrow }
            return sessionRecords
        }

        func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] {
            angleAfterArgs.append(after)
            if let errorToThrow { throw errorToThrow }
            return angleRecords
        }
    }

    var container: ModelContainer!
    var context: ModelContext!
    var defaults: UserDefaults!
    var suiteName: String!
    let userId = "u-w3"

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        suiteName = "V36W3RestoreSyncTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        // v53 起本地实体按 owner 隔离。本组用例验证的是账号 u-w3 的恢复语义，
        // 因此夹具必须在创建本地实体/删除队列之前就进入该账号域。
        CurrentOwnerContext.shared.useAccount(userID: userId)
        SyncQueueManager.shared.configure(context: context)
        SyncRestoreService.shared.configure(context: context)
        SyncRestoreService.shared.defaults = defaults
    }

    override func tearDown() {
        // 单例上的注入必须还原，否则会渗到同进程内其它测试。
        SyncRestoreService.shared.backend = LiveSyncRestoreBackend()
        SyncRestoreService.shared.defaults = .standard
        SyncQueueManager.shared.backend = LiveSyncBackend()
        CurrentOwnerContext.shared.useGuest()
        UserDefaults.standard.removeSuite(named: suiteName)
        defaults = nil
        suiteName = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixture

    /// 一条字段全非默认值的本地训练：9 个 v36 W1 新字段都要有可辨识的取值，
    /// 否则「往返无损」可能只是默认值恰好相等。
    private func makeLocalSession(
        note: String = "本地训练心得",
        totalDurationMinutes: Int = 47,
        id: UUID? = nil
    ) -> TrainingSession {
        let session = TrainingSession(
            ballType: "snooker",
            kind: "drill",
            ownerKey: OwnerKey.account(userId)
        )
        if let id { session.id = id }
        session.date = Date(timeIntervalSince1970: 1_770_000_000)
        session.totalDurationMinutes = totalDurationMinutes
        session.note = note
        session.planId = "plan_beginner_12w"
        session.scheduleItemId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        session.sourceKind = TodayScheduleSourceKind.officialLesson
        session.sourceId = "plan_beginner.stage01.lesson01"
        session.sourceParentId = "plan_beginner"
        session.sourceTitleSnapshot = "第 1 课"
        session.sourceSubtitleSnapshot = "基本功 · 第 1 课"
        session.sourcePayloadVersion = 1
        session.sourcePayloadSnapshot = Data("frozen-v54".utf8)
        session.setProgress(role: TodayScheduleProgressRole.advanceEligible, effect: "advanced:1")
        session.lessonId = "plan_beginner.stage01.lesson01"

        let entry = DrillEntry(
            drillId: "drill_c065",
            drillNameZh: "Ghost Game 对抗",
            orderIndex: 3,
            note: "第三局手感回来了",
            criteriaText: "10局Ghost Game中赢3局以上"
        )
        let firstSet = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 4,
                                formationToken: "gg_break_a", formationName: "开球球形 A",
                                unitLabel: "局", passMade: 3, passTotal: 10,
                                durationSeconds: 612)
        let secondSet = DrillSet(setNumber: 2, targetBalls: 8, madeBalls: 6,
                                 formationToken: nil, formationName: nil,
                                 unitLabel: "次", passMade: 5, passTotal: 8,
                                 durationSeconds: nil)
        context.insert(session)
        context.insert(entry)
        context.insert(firstSet)
        context.insert(secondSet)
        entry.session = session
        firstSet.entry = entry
        secondSet.entry = entry
        return session
    }

    /// Build the server fixture through the real entity → DTO path, then remove
    /// the source graph so the destination remains a clean-device store.
    private func makeSourceDTO(
        note: String = "本地训练心得",
        totalDurationMinutes: Int = 47
    ) throws -> TrainingSessionDTO {
        let source = makeLocalSession(note: note, totalDurationMinutes: totalDurationMinutes)
        let dto = TrainingSessionDTO(from: source)
        for entry in source.drillEntries {
            for drillSet in entry.sets {
                context.delete(drillSet)
            }
            context.delete(entry)
        }
        context.delete(source)
        try context.save()
        return dto
    }

    /// 真实走一遍上行编码：DTO → JSON（`JSONEncoder` 与 `APIClient` 同款 `.iso8601`），
    /// 再补上服务端 `timestamps: true` 会带的 `updatedAt`（**带毫秒**，与 Mongoose
    /// `res.json()` 的实际输出一致），最后按下行口径解码成信封。
    private func serverRecords(
        _ dtos: [TrainingSessionDTO],
        updatedAt: [Date]
    ) throws -> [SyncedRecord<TrainingSessionDTO>] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var objects: [Any] = []
        for (index, dto) in dtos.enumerated() {
            let data = try encoder.encode(dto)
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any],
                "DTO 编码结果不是 JSON 对象"
            )
            object["updatedAt"] = iso.string(from: updatedAt[index])
            objects.append(object)
        }

        let payload = try JSONSerialization.data(withJSONObject: objects)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy
        return try decoder.decode([SyncedRecord<TrainingSessionDTO>].self, from: payload)
    }

    private func serverAngleRecords(
        _ dtos: [AngleTestDTO],
        updatedAt: [Date]
    ) throws -> [SyncedRecord<AngleTestDTO>] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var objects: [Any] = []
        for (index, dto) in dtos.enumerated() {
            let data = try encoder.encode(dto)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object["updatedAt"] = iso.string(from: updatedAt[index])
            objects.append(object)
        }
        let payload = try JSONSerialization.data(withJSONObject: objects)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy
        return try decoder.decode([SyncedRecord<AngleTestDTO>].self, from: payload)
    }

    private func localSessions() throws -> [TrainingSession] {
        try context.fetch(FetchDescriptor<TrainingSession>())
    }

    // MARK: - 完成标准 ①：clientId 幂等

    func test_restore_sameBatchTwice_doesNotDuplicateEntities() async throws {
        let dto = try makeSourceDTO()
        let records = try serverRecords([dto], updatedAt: [Date(timeIntervalSince1970: 1_770_000_100)])
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)

        let first = await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        let afterFirst = try localSessions().count
        let second = await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        let afterSecond = try localSessions()

        print("[W3-幂等] 首轮=\(first) 次轮=\(second) 实体数 首=\(afterFirst) 次=\(afterSecond.count)")
        XCTAssertEqual(afterFirst, 1, "首轮应插入 1 条")
        XCTAssertEqual(afterSecond.count, 1, "同一批 DTO 拉两次，实体数不得翻倍")
        XCTAssertEqual(second.insertedSessions, 0)
        XCTAssertEqual(second.skippedSessions, 1)
        // 子实体同样不得翻倍（父去重了但子还挂两份 = 假幂等）。
        XCTAssertEqual(try context.fetch(FetchDescriptor<DrillEntry>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DrillSet>()).count, 2)
    }

    func test_restore_duplicateClientIdWithinOneBatch_insertsOnce() async throws {
        let dto = try makeSourceDTO()
        let records = try serverRecords(
            [dto, dto],
            updatedAt: [Date(timeIntervalSince1970: 1_770_000_100),
                        Date(timeIntervalSince1970: 1_770_000_200)]
        )
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)

        let summary = await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        print("[W3-幂等] 单批内重复 clientId summary=\(summary) 实体数=\(try localSessions().count)")
        XCTAssertEqual(try localSessions().count, 1, "同一批里重复的 clientId 只建一条")
    }

    // MARK: - 完成标准 ②：往返语义无损

    func test_roundTrip_encodeDecodeRebuild_preservesAllFields() async throws {
        let dto = try makeSourceDTO()
        let sourceId = try XCTUnwrap(UUID(uuidString: dto.clientId))
        let records = try serverRecords([dto], updatedAt: [Date(timeIntervalSince1970: 1_770_000_100)])
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)

        // 恢复到一个「干净设备」：source 已在实体→DTO 后从目的 context 显式清理。
        await SyncRestoreService.shared.restore(userId: userId, mode: .full)

        let restored = try XCTUnwrap(try localSessions().first, "恢复后本地应有 1 条训练")
        print("[W3-往返] clientId=\(restored.id.uuidString) kind=\(restored.kind) " +
              "planId=\(restored.planId ?? "nil") entries=\(restored.drillEntries.count)")

        XCTAssertEqual(restored.id, sourceId, "clientId 即本地 id，必须原样还原")
        XCTAssertEqual(restored.date.timeIntervalSince1970,
                       dto.date.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(restored.ballType, "snooker")
        XCTAssertEqual(restored.totalDurationMinutes, 47)
        XCTAssertEqual(restored.note, "本地训练心得")
        XCTAssertEqual(restored.planId, "plan_beginner_12w")
        XCTAssertEqual(restored.kind, "drill")
        XCTAssertEqual(restored.scheduleItemId,
                       UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        XCTAssertEqual(restored.sourceKind, TodayScheduleSourceKind.officialLesson)
        XCTAssertEqual(restored.sourceId, "plan_beginner.stage01.lesson01")
        XCTAssertEqual(restored.sourceParentId, "plan_beginner")
        XCTAssertEqual(restored.sourceTitleSnapshot, "第 1 课")
        XCTAssertEqual(restored.sourceSubtitleSnapshot, "基本功 · 第 1 课")
        XCTAssertEqual(restored.sourcePayloadVersion, 1)
        XCTAssertEqual(restored.sourcePayloadSnapshot, Data("frozen-v54".utf8))
        XCTAssertEqual(restored.frozenProgressRole, TodayScheduleProgressRole.advanceEligible)
        XCTAssertEqual(restored.appliedProgressEffect, "advanced:1")
        XCTAssertEqual(restored.lessonId, "plan_beginner.stage01.lesson01")

        let entry = try XCTUnwrap(restored.drillEntries.first)
        XCTAssertEqual(entry.drillId, "drill_c065")
        XCTAssertEqual(entry.drillNameZh, "Ghost Game 对抗")
        XCTAssertEqual(entry.orderIndex, 3, "W1 新字段 orderIndex 不得丢")
        XCTAssertEqual(entry.note, "第三局手感回来了", "W1 新字段 note 不得丢")
        XCTAssertEqual(entry.criteriaText, "10局Ghost Game中赢3局以上", "W1 新字段 criteriaText 不得丢")

        let sets = entry.sets.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(sets.count, 2)
        print("[W3-往返] set1 unitLabel=\(sets[0].unitLabel) formation=\(sets[0].formationToken ?? "nil") " +
              "pass=\(sets[0].passMade)/\(sets[0].passTotal) dur=\(String(describing: sets[0].durationSeconds))")
        XCTAssertEqual(sets[0].setNumber, 1)
        XCTAssertEqual(sets[0].targetBalls, 10)
        XCTAssertEqual(sets[0].madeBalls, 4)
        XCTAssertEqual(sets[0].formationToken, "gg_break_a")
        XCTAssertEqual(sets[0].formationName, "开球球形 A")
        XCTAssertEqual(sets[0].unitLabel, "局",
                       "unitLabel 丢失=语义错误：「局」被当成「球」（契约 §5.2）")
        XCTAssertEqual(sets[0].passMade, 3)
        XCTAssertEqual(sets[0].passTotal, 10)
        XCTAssertEqual(sets[0].durationSeconds, 612)

        XCTAssertEqual(sets[1].unitLabel, "次")
        XCTAssertNil(sets[1].formationToken, "服务端 null 必须还原成 nil，不得变成空串")
        XCTAssertNil(sets[1].formationName)
        XCTAssertNil(sets[1].durationSeconds, "未采集用时必须仍是 nil，不得变成 0")
    }

    // MARK: - 完成标准 ③：已删除项不复活

    func test_deletedSession_isNotResurrected_whileDeleteItemPending() async throws {
        // 队列推送失败（离线），delete 项留在队列里 —— 这正是竞态窗口。
        SyncQueueManager.shared.backend = FailingSyncBackend()
        let repo = LocalTrainingSessionRepository(context: context)
        let session = try await repo.create(ballType: "chinese8")
        let dto = TrainingSessionDTO(from: session)
        try await repo.delete(session)
        XCTAssertEqual(try localSessions().count, 0, "本地已删除")

        let authState = AuthState()
        authState.login(user: AppUser(id: userId, provider: .apple))
        await SyncQueueManager.shared.processQueue(authState: authState)
        let stillPending = try context.fetch(
            FetchDescriptor<SyncPendingItem>()
        ).filter { $0.operation == SyncOperation.delete }
        XCTAssertEqual(stillPending.count, 1, "推送失败，delete 项应保留（竞态前提）")

        // 服务端此刻仍持有该条（删除请求没发出去），拉取会把它带回来。
        let records = try serverRecords([dto], updatedAt: [Date(timeIntervalSince1970: 1_770_000_100)])
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)

        let summary = await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        print("[W3-删除竞态] summary=\(summary) 恢复后实体数=\(try localSessions().count)")
        XCTAssertEqual(try localSessions().count, 0, "队列中仍有 delete 项的 clientId 不得被拉回")
        XCTAssertEqual(summary.insertedSessions, 0)
        XCTAssertEqual(summary.skippedSessions, 1)
    }

    func test_deleteSucceeded_thenRestore_doesNotResurrect() async throws {
        // 正常路径：先推（删除成功、队列清空），再拉（服务端已无该条）。
        let mock = MockSuccessSyncBackend()
        SyncQueueManager.shared.backend = mock
        let repo = LocalTrainingSessionRepository(context: context)
        let session = try await repo.create(ballType: "chinese8")
        try await repo.delete(session)

        let authState = AuthState()
        authState.login(user: AppUser(id: userId, provider: .apple))
        await SyncQueueManager.shared.processQueue(authState: authState)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncPendingItem>()).isEmpty)

        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: [])
        await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        print("[W3-删除竞态] 推送成功后恢复，实体数=\(try localSessions().count)")
        XCTAssertEqual(try localSessions().count, 0)
    }

    // MARK: - 冲突策略：本地不被远端覆盖

    func test_existingLocalSession_isNotOverwrittenByRemote() async throws {
        let staleDTO = try makeSourceDTO(note: "服务端旧版本", totalDurationMinutes: 1)
        _ = makeLocalSession(
            note: "本地最新心得",
            id: try XCTUnwrap(UUID(uuidString: staleDTO.clientId))
        )
        try context.save()

        // 服务端副本是同一 clientId 的旧版本。
        let records = try serverRecords([staleDTO],
                                        updatedAt: [Date(timeIntervalSince1970: 1_780_000_000)])
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)

        await SyncRestoreService.shared.restore(userId: userId, mode: .full)

        let after = try XCTUnwrap(try localSessions().first)
        print("[W3-冲突] 恢复后 note=\(after.note) 时长=\(after.totalDurationMinutes) " +
              "entries=\(after.drillEntries.count)")
        XCTAssertEqual(try localSessions().count, 1)
        XCTAssertEqual(after.note, "本地最新心得", "本地已有记录不得被服务端副本覆盖")
        XCTAssertEqual(after.totalDurationMinutes, 47)
        XCTAssertEqual(after.drillEntries.count, 1)
    }

    // MARK: - 增量锚点

    func test_incrementalAnchor_usesServerUpdatedAt() async throws {
        let older = Date(timeIntervalSince1970: 1_770_000_100)
        let newer = Date(timeIntervalSince1970: 1_770_009_999)
        let records = try serverRecords(
            [try makeSourceDTO(), try makeSourceDTO()],
            updatedAt: [older, newer]
        )
        let mock = MockRestoreBackend(sessions: records)
        SyncRestoreService.shared.backend = mock

        await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        let stored = SyncRestoreService.shared.anchor(.sessions, userId: userId)
        await SyncRestoreService.shared.restore(userId: userId, mode: .incremental)
        let args = await mock.sessionAfterArgs

        print("[W3-锚点] 锚点=\(String(describing: stored)) 两次调用 after=\(args)")
        XCTAssertNil(args[0], "全量拉取不带 after")
        XCTAssertEqual(stored?.timeIntervalSince1970 ?? 0, newer.timeIntervalSince1970, accuracy: 0.001,
                       "锚点取服务端 updatedAt 的最大值")
        XCTAssertEqual(args[1]?.timeIntervalSince1970 ?? 0, newer.timeIntervalSince1970, accuracy: 0.001,
                       "增量拉取须带上锚点")
    }

    func test_anchorIsPerUser() async throws {
        let records = try serverRecords([try makeSourceDTO()],
                                        updatedAt: [Date(timeIntervalSince1970: 1_770_000_100)])
        SyncRestoreService.shared.backend = MockRestoreBackend(sessions: records)
        await SyncRestoreService.shared.restore(userId: userId, mode: .full)

        let other = SyncRestoreService.shared.anchor(.sessions, userId: "u-other")
        print("[W3-锚点] 另一账号锚点=\(String(describing: other))")
        XCTAssertNil(other, "锚点按账号分键，换号不得沿用（否则新账号历史永远拉不到）")
    }

    func test_fetchFailure_doesNotAdvanceAnchor() async throws {
        SyncRestoreService.shared.backend = MockRestoreBackend(
            errorToThrow: AppError.networkError("网络连接失败")
        )
        let summary = await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        print("[W3-失败] summary=\(summary) 锚点=" +
              "\(String(describing: SyncRestoreService.shared.anchor(.sessions, userId: userId)))")
        XCTAssertEqual(summary, SyncRestoreService.RestoreSummary())
        XCTAssertNil(SyncRestoreService.shared.anchor(.sessions, userId: userId))
        XCTAssertEqual(try localSessions().count, 0)
    }

    // MARK: - AngleTest 下行

    func test_angleTestRestore_isIdempotentAndPreservesFields() async throws {
        let sessionUUID = UUID()
        let source = AngleTestResult(actualAngle: 33.5, userAngle: 30.25, pocketType: "corner",
                                     quizType: "aimPoint3D", errorMM: -4.5, sessionId: sessionUUID)
        source.date = Date(timeIntervalSince1970: 1_770_000_500)
        let records = try serverAngleRecords([AngleTestDTO(from: source)],
                                             updatedAt: [Date(timeIntervalSince1970: 1_770_000_600)])
        SyncRestoreService.shared.backend = MockRestoreBackend(angleTests: records)

        await SyncRestoreService.shared.restore(userId: userId, mode: .full)
        await SyncRestoreService.shared.restore(userId: userId, mode: .full)

        let restored = try context.fetch(FetchDescriptor<AngleTestResult>())
        print("[W3-角度] 两轮恢复后条数=\(restored.count) quizType=\(restored.first?.quizType ?? "nil") " +
              "errorMM=\(restored.first?.errorMM ?? 0)")
        XCTAssertEqual(restored.count, 1, "同一批拉两次不得翻倍")
        let one = try XCTUnwrap(restored.first)
        XCTAssertEqual(one.id, source.id)
        XCTAssertEqual(one.actualAngle, 33.5, accuracy: 0.0001)
        XCTAssertEqual(one.userAngle, 30.25, accuracy: 0.0001)
        XCTAssertEqual(one.pocketType, "corner")
        XCTAssertEqual(one.quizType, "aimPoint3D")
        XCTAssertEqual(one.errorMM, -4.5, accuracy: 0.0001)
        XCTAssertEqual(one.sessionId, sessionUUID)
        XCTAssertEqual(one.date.timeIntervalSince1970, 1_770_000_500, accuracy: 1.0)
    }

    // MARK: - 日期解码口径（下行的隐性前提）

    func test_apiDateDecoding_acceptsFractionalAndPlainISO8601() throws {
        struct Box: Decodable { let date: Date }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = APIDateCoding.decodingStrategy

        // Mongoose `res.json()` 的实际输出带毫秒；`.iso8601` 策略解不了它。
        let withMillis = try decoder.decode(
            Box.self, from: Data(#"{"date":"2026-08-12T03:00:00.000Z"}"#.utf8))
        let withoutMillis = try decoder.decode(
            Box.self, from: Data(#"{"date":"2026-08-12T03:00:00Z"}"#.utf8))
        print("[W3-日期] 带毫秒=\(withMillis.date) 不带毫秒=\(withoutMillis.date)")
        XCTAssertEqual(withMillis.date.timeIntervalSince1970,
                       withoutMillis.date.timeIntervalSince1970, accuracy: 0.001)

        // 解不了必须抛带 codingPath 的错误，不得静默给默认值（FL-029）。
        XCTAssertThrowsError(
            try decoder.decode(Box.self, from: Data(#"{"date":"not-a-date"}"#.utf8))
        ) { error in
            guard case DecodingError.dataCorrupted(let ctx) = error else {
                return XCTFail("应抛 dataCorrupted，实际 \(error)")
            }
            print("[W3-日期] 非法日期报错 codingPath=\(ctx.codingPath.map(\.stringValue)) " +
                  "debug=\(ctx.debugDescription)")
            XCTAssertEqual(ctx.codingPath.map(\.stringValue), ["date"])
        }
    }
}

// MARK: - 队列侧假后端

/// 推送一律失败（模拟离线），用于制造「delete 项仍在队列」的竞态前提。
private struct FailingSyncBackend: SyncBackend {
    func uploadSession(_ dto: TrainingSessionDTO) async throws {
        throw AppError.networkError("网络连接失败")
    }
    func uploadAngleTest(_ dto: AngleTestDTO) async throws {
        throw AppError.networkError("网络连接失败")
    }
    func deleteSession(clientId: String) async throws {
        throw AppError.networkError("网络连接失败")
    }
}

/// 推送一律成功，用于验证「先推后拉」的正常路径。
private struct MockSuccessSyncBackend: SyncBackend {
    func uploadSession(_ dto: TrainingSessionDTO) async throws {}
    func uploadAngleTest(_ dto: AngleTestDTO) async throws {}
    func deleteSession(clientId: String) async throws {}
}
