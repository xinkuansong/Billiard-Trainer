import XCTest
import SwiftData
@testable import QiuJi

/// 问题集合 v29 W5：练习 cognitive session + tool 活跃度。
///
/// 覆盖四条完成标准：
/// - 标准 2：答 3 题 → 1 条 cognitive session，3 条 `AngleTestResult.sessionId` 指向它；
/// - 标准 3：历史无 `sessionId` 记录的回填条数与幂等性；
/// - 标准 4：tool 会话 `drillEntries` 为空且无任何成绩字段；
/// - 顺带：同步 DTO 携带 `kind` / `quizType` / `errorMM` / `sessionId`，且缺字段回包仍能解码。
@MainActor
final class V29W5CognitiveToolSessionTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: LocalAngleTestRepository!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
        repo = LocalAngleTestRepository(context: context)
    }

    override func tearDown() {
        repo = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeResult(quizType: String, date: Date, errorMM: Double = 0) -> AngleTestResult {
        let r = AngleTestResult(actualAngle: 45, userAngle: 43,
                                pocketType: "corner", quizType: quizType, errorMM: errorMM)
        r.date = date
        return r
    }

    private func fetchSessions(kind: String) throws -> [TrainingSession] {
        try context.fetch(FetchDescriptor<TrainingSession>())
            .filter { $0.kind == kind }
            .sorted { $0.date < $1.date }
    }

    // MARK: - 标准 2：答题落 cognitive session

    func test_threeAnswers_createOneCognitiveSession_allResultsPointToIt() async throws {
        let t0 = Date()
        for i in 0..<3 {
            try await repo.save(makeResult(quizType: "geometric",
                                           date: t0.addingTimeInterval(Double(i) * 20)))
        }

        let sessions = try fetchSessions(kind: TrainingSessionKind.cognitive)
        let results = try await repo.fetchAll()

        print("""
        [W5-标准2] cognitiveSessions=\(sessions.count) \
        results=\(results.count) \
        sessionIds=\(Set(results.compactMap { $0.sessionId }).count)
        """)
        for s in sessions {
            print("[W5-标准2] session id=\(s.id) kind=\(s.kind) note=\(s.note) " +
                  "durationMinutes=\(s.totalDurationMinutes) drillEntries=\(s.drillEntries.count)")
        }
        for r in results {
            print("[W5-标准2] result quizType=\(r.quizType) sessionId=\(r.sessionId?.uuidString ?? "nil")")
        }

        XCTAssertEqual(sessions.count, 1, "同页连续答 3 题应只产生 1 条 cognitive 会话")
        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.sessionId == session.id },
                      "3 条成绩的 sessionId 都应指向这条会话")
        XCTAssertEqual(session.note, "角度预测")
        // ⛔ 契约 §5.3：会话本身不承载成绩。
        XCTAssertTrue(session.drillEntries.isEmpty, "cognitive 会话不得产生 DrillEntry")
    }

    func test_answerAfterGapExceeded_startsSecondSession() async throws {
        let t0 = Date()
        try await repo.save(makeResult(quizType: "geometric", date: t0))
        // 间隔 31 分钟 > 30 分钟窗口 ⇒ 新会话。
        try await repo.save(makeResult(quizType: "geometric",
                                       date: t0.addingTimeInterval(31 * 60)))

        let sessions = try fetchSessions(kind: TrainingSessionKind.cognitive)
        print("[W5-边界] 超窗后会话数=\(sessions.count)")
        XCTAssertEqual(sessions.count, 2, "超过 30 分钟窗口应封口并新建会话")
    }

    func test_answerWithinGap_reusesSessionAndExtendsDuration() async throws {
        let t0 = Date()
        try await repo.save(makeResult(quizType: "geometric", date: t0))
        try await repo.save(makeResult(quizType: "geometric",
                                       date: t0.addingTimeInterval(10 * 60)))

        let sessions = try fetchSessions(kind: TrainingSessionKind.cognitive)
        XCTAssertEqual(sessions.count, 1)
        let session = try XCTUnwrap(sessions.first)
        print("[W5-边界] 窗口内复用会话 durationMinutes=\(session.totalDurationMinutes)")
        XCTAssertEqual(session.totalDurationMinutes, 10, "时长应按首题→末题延伸到 10 分钟")
    }

    func test_differentQuizTypes_getSeparateSessions() async throws {
        let t0 = Date()
        try await repo.save(makeResult(quizType: "geometric", date: t0))
        try await repo.save(makeResult(quizType: "aimPoint3D", date: t0.addingTimeInterval(5)))

        let sessions = try fetchSessions(kind: TrainingSessionKind.cognitive)
        print("[W5-边界] 两种题型会话数=\(sessions.count) notes=\(sessions.map(\.note))")
        XCTAssertEqual(sessions.count, 2, "不同 quizType 不并入同一会话")
    }

    func test_retriedSave_keepsOriginalSessionId() async throws {
        let first = makeResult(quizType: "geometric", date: Date())
        try await repo.save(first)
        let originalSessionId = try XCTUnwrap(first.sessionId)

        // 模拟「保存失败后重试」：同一对象再走一次 save。
        try await repo.save(first)
        XCTAssertEqual(first.sessionId, originalSessionId, "重试不得改变已有归属")
        XCTAssertEqual(try fetchSessions(kind: TrainingSessionKind.cognitive).count, 1)
    }

    // MARK: - 标准 3：历史回填

    /// 直接插入 context（绕过 repository）以造出 `sessionId == nil` 的历史记录。
    private func insertLegacy(quizType: String, date: Date) -> AngleTestResult {
        let r = makeResult(quizType: quizType, date: date)
        context.insert(r)
        return r
    }

    func test_backfill_groupsLegacyResultsBySameQuizTypeAnd30MinGap() throws {
        let t0 = Date().addingTimeInterval(-10 * 24 * 3600)
        // geometric 组 1：3 条，彼此 1 分钟。
        for i in 0..<3 { _ = insertLegacy(quizType: "geometric", date: t0.addingTimeInterval(Double(i) * 60)) }
        // geometric 组 2：2 条，与组 1 间隔 2 小时。
        for i in 0..<2 {
            _ = insertLegacy(quizType: "geometric",
                             date: t0.addingTimeInterval(2 * 3600 + Double(i) * 60))
        }
        // aimPoint 组：1 条，与 geometric 组 1 同时刻但题型不同。
        _ = insertLegacy(quizType: "aimPoint", date: t0.addingTimeInterval(30))
        try context.save()

        let report = try CognitiveSessionBackfill.run(context: context)
        print("[W5-标准3] 回填统计 \(report.summary)")

        XCTAssertEqual(report.orphanResults, 6)
        XCTAssertEqual(report.createdSessions, 3, "geometric 两组 + aimPoint 一组 = 3 条会话")
        XCTAssertEqual(report.assignedResults, 6)

        let sessions = try fetchSessions(kind: TrainingSessionKind.cognitive)
        XCTAssertEqual(sessions.count, 3)
        for s in sessions {
            print("[W5-标准3] 回填会话 note=\(s.note) date=\(s.date) " +
                  "durationMinutes=\(s.totalDurationMinutes) drillEntries=\(s.drillEntries.count)")
            XCTAssertTrue(s.drillEntries.isEmpty)
        }

        let all = try context.fetch(FetchDescriptor<AngleTestResult>())
        XCTAssertTrue(all.allSatisfy { $0.sessionId != nil }, "回填后不应再有无归属成绩")

        // 分组正确性：同一组的 3 条应共享同一个 sessionId。
        let group1 = all.filter { $0.quizType == "geometric" && $0.date < t0.addingTimeInterval(3600) }
        XCTAssertEqual(Set(group1.compactMap { $0.sessionId }).count, 1)
    }

    func test_backfill_isIdempotent() throws {
        let t0 = Date().addingTimeInterval(-3600)
        for i in 0..<4 { _ = insertLegacy(quizType: "scene2D", date: t0.addingTimeInterval(Double(i) * 60)) }
        try context.save()

        let first = try CognitiveSessionBackfill.run(context: context)
        let sessionsAfterFirst = try fetchSessions(kind: TrainingSessionKind.cognitive).count
        let second = try CognitiveSessionBackfill.run(context: context)
        let sessionsAfterSecond = try fetchSessions(kind: TrainingSessionKind.cognitive).count

        print("[W5-标准3] 幂等：第一次 \(first.summary) 会话数=\(sessionsAfterFirst)")
        print("[W5-标准3] 幂等：第二次 \(second.summary) 会话数=\(sessionsAfterSecond)")

        XCTAssertEqual(first.createdSessions, 1)
        XCTAssertEqual(second, CognitiveSessionBackfill.Report(orphanResults: 0,
                                                              createdSessions: 0,
                                                              assignedResults: 0))
        XCTAssertEqual(sessionsAfterFirst, sessionsAfterSecond, "再跑一次不得重复建会话")
    }

    func test_backfill_doesNotTouchAlreadyAssignedResults() async throws {
        try await repo.save(makeResult(quizType: "geometric", date: Date()))
        let before = try fetchSessions(kind: TrainingSessionKind.cognitive)
        let report = try CognitiveSessionBackfill.run(context: context)
        let after = try fetchSessions(kind: TrainingSessionKind.cognitive)

        print("[W5-标准3] 对已归属数据回填：\(report.summary)")
        XCTAssertTrue(report.isNoOp)
        XCTAssertEqual(before.count, after.count)
    }

    func test_backfillSessionBoundary_matchesLiveRecorderBoundary() throws {
        // 回填与实时口径同源的反证：同一常量。
        XCTAssertEqual(CognitiveSessionRecorder.gap, AngleSessionInference.gap)
    }

    // MARK: - 标准 4：tool 活跃度

    func test_toolSession_recordsDurationWithNoDrillEntriesAndNoScores() throws {
        let start = Date()
        let session = try XCTUnwrap(
            ToolUsageTracker.record(entry: .freePlay, start: start,
                                    end: start.addingTimeInterval(125), context: context)
        )

        let tools = try fetchSessions(kind: TrainingSessionKind.tool)
        let entries = try context.fetch(FetchDescriptor<DrillEntry>())
        let sets = try context.fetch(FetchDescriptor<DrillSet>())

        print("""
        [W5-标准4] toolSessions=\(tools.count) id=\(session.id) kind=\(session.kind) \
        note=\(session.note) date=\(session.date) \
        totalDurationMinutes=\(session.totalDurationMinutes) \
        drillEntries=\(session.drillEntries.count) planId=\(session.planId ?? "nil")
        """)
        print("[W5-标准4] 全库 DrillEntry=\(entries.count) DrillSet=\(sets.count)")

        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(session.kind, TrainingSessionKind.tool)
        XCTAssertEqual(session.note, "自由击球")
        XCTAssertEqual(session.date, start, "会话日期 = 进页时刻")
        XCTAssertEqual(session.totalDurationMinutes, 2, "125 秒 → 2 分钟")
        // ⛔ 契约 §5.3 红线：tool 不得写任何 made/target 或进袋结果。
        XCTAssertTrue(session.drillEntries.isEmpty, "tool 会话不得产生 DrillEntry")
        XCTAssertTrue(entries.isEmpty, "tool 落库不得在库里留下任何 DrillEntry")
        XCTAssertTrue(sets.isEmpty, "tool 落库不得在库里留下任何 DrillSet（made/target 的唯一载体）")
        XCTAssertNil(session.planId)
    }

    func test_toolSession_shortStayIsNotRecorded() throws {
        let start = Date()
        let session = ToolUsageTracker.record(entry: .drillTryout, start: start,
                                              end: start.addingTimeInterval(3), context: context)
        let tools = try fetchSessions(kind: TrainingSessionKind.tool)
        print("[W5-标准4] 停留 3 秒：返回=\(session == nil ? "nil" : "session") toolSessions=\(tools.count)")
        XCTAssertNil(session, "停留 < 5 秒视为误触，不落库")
        XCTAssertTrue(tools.isEmpty)
    }

    func test_dailyClearanceUsesToolKindAndNeverCountsTowardGoalOrAccuracy() throws {
        let start = Date()
        let session = try XCTUnwrap(
            ToolUsageTracker.record(
                entry: .dailyClearance,
                start: start,
                end: start.addingTimeInterval(65),
                context: context
            )
        )

        XCTAssertEqual(session.kind, TrainingSessionKind.tool)
        XCTAssertEqual(session.note, "每日清台")
        XCTAssertEqual(session.totalDurationMinutes, 1)
        XCTAssertTrue(session.drillEntries.isEmpty)
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(session.kind))
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(session.kind))
    }

    func test_toolSession_atThresholdIsRecordedAsOneMinute() throws {
        let start = Date()
        let session = try XCTUnwrap(
            ToolUsageTracker.record(entry: .planThree, start: start,
                                    end: start.addingTimeInterval(5), context: context)
        )
        print("[W5-标准4] 停留 5 秒：durationMinutes=\(session.totalDurationMinutes)")
        XCTAssertEqual(session.totalDurationMinutes, 1, "下限 1 分钟")
    }

    func test_toolSession_isEnqueuedForUpload() throws {
        let start = Date()
        let session = try XCTUnwrap(
            ToolUsageTracker.record(entry: .freePosition, start: start,
                                    end: start.addingTimeInterval(600), context: context)
        )
        let pending = try context.fetch(FetchDescriptor<SyncPendingItem>())
        print("[W5-D-v29-4] pendingItems=\(pending.map { "\($0.entityType):\($0.entityId)" })")
        XCTAssertTrue(
            pending.contains { $0.entityType == "TrainingSession" && $0.entityId == session.id },
            "D-v29-4 裁定 tool 时长上传，会话须进同步队列"
        )
    }

    func test_allFiveToolEntriesHaveDistinctLabels() {
        let labels = ToolUsageEntry.allCases.map(\.displayNameZh)
        print("[W5-标准5] 五个工具入口=\(labels)")
        XCTAssertEqual(ToolUsageEntry.allCases.count, 5)
        XCTAssertEqual(Set(labels).count, 5)
        XCTAssertTrue(labels.contains("每日清台"))
    }

    func test_cognitiveSessionSave_alsoEnqueuesSession() async throws {
        try await repo.save(makeResult(quizType: "geometric", date: Date()))
        let session = try XCTUnwrap(try fetchSessions(kind: TrainingSessionKind.cognitive).first)
        let pending = try context.fetch(FetchDescriptor<SyncPendingItem>())
        print("[W5-同步] cognitive pendingItems=\(pending.map(\.entityType))")
        XCTAssertTrue(pending.contains { $0.entityType == "TrainingSession" && $0.entityId == session.id })
        XCTAssertEqual(pending.filter { $0.entityType == "TrainingSession" }.count, 1,
                       "同一分钟内连续答题不得重复入队")
    }

    func test_reusedSession_reEnqueuesOnlyWhenDurationChanges() async throws {
        let t0 = Date()
        try await repo.save(makeResult(quizType: "geometric", date: t0))
        // 同一分钟内的第二题：时长仍是 1 分钟 ⇒ 不重复入队。
        try await repo.save(makeResult(quizType: "geometric", date: t0.addingTimeInterval(5)))
        let afterSameMinute = try context.fetch(FetchDescriptor<SyncPendingItem>())
            .filter { $0.entityType == "TrainingSession" }.count
        // 跨过分钟边界：时长变为 3 分钟 ⇒ 须重新入队，否则服务端时长永远停在 1 分钟。
        try await repo.save(makeResult(quizType: "geometric", date: t0.addingTimeInterval(180)))
        let afterMinuteBump = try context.fetch(FetchDescriptor<SyncPendingItem>())
            .filter { $0.entityType == "TrainingSession" }.count

        let session = try XCTUnwrap(try fetchSessions(kind: TrainingSessionKind.cognitive).first)
        print("[W5-同步] 会话入队次数：同分钟内=\(afterSameMinute) 跨分钟后=\(afterMinuteBump) " +
              "最终时长=\(session.totalDurationMinutes) 分钟")

        XCTAssertEqual(afterSameMinute, 1)
        XCTAssertEqual(afterMinuteBump, 2, "时长变化须重新入队上传")
        XCTAssertEqual(session.totalDurationMinutes, 3)
        XCTAssertEqual(try fetchSessions(kind: TrainingSessionKind.cognitive).count, 1)
    }

    // MARK: - 同步 DTO（本批第 4/5 项）

    private var jsonEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func test_trainingSessionDTO_carriesKind() throws {
        let session = TrainingSession(kind: TrainingSessionKind.tool)
        session.totalDurationMinutes = 7
        let json = try jsonEncoder.encode(TrainingSessionDTO(from: session))
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        print("[W5-DTO] TrainingSessionDTO keys=\(dict.keys.sorted()) kind=\(dict["kind"] ?? "nil")")
        XCTAssertEqual(dict["kind"] as? String, TrainingSessionKind.tool)
    }

    func test_trainingSessionDTO_decodesWhenServerOmitsKind() throws {
        // 旧后端 mongoose `strict: true` 会丢弃未声明字段，回包里没有 kind。
        let payload = """
        {"clientId":"abc","date":"2026-08-06T12:00:00Z","ballType":"chinese8",
         "totalDurationMinutes":5,"note":"","drillEntries":[]}
        """
        let dto = try jsonDecoder.decode(TrainingSessionDTO.self, from: Data(payload.utf8))
        print("[W5-DTO] 缺 kind 回包解码成功，kind 回落=\(dto.kind)")
        XCTAssertEqual(dto.kind, TrainingSessionKind.drill)
    }

    func test_angleTestDTO_carriesQuizTypeErrorMMAndSessionId() throws {
        let sessionId = UUID()
        let result = AngleTestResult(actualAngle: 30, userAngle: 27, pocketType: "side",
                                     quizType: "aimPoint3D", errorMM: -4.5, sessionId: sessionId)
        let json = try jsonEncoder.encode(AngleTestDTO(from: result))
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        print("[W5-DTO] AngleTestDTO keys=\(dict.keys.sorted())")
        XCTAssertEqual(dict["quizType"] as? String, "aimPoint3D")
        XCTAssertEqual(dict["errorMM"] as? Double, -4.5)
        XCTAssertEqual(dict["sessionId"] as? String, sessionId.uuidString)
    }

    func test_angleTestDTO_decodesWhenServerOmitsNewFields() throws {
        let payload = """
        {"clientId":"abc","date":"2026-08-06T12:00:00Z","actualAngle":30,
         "userAngle":27,"pocketType":"side"}
        """
        let dto = try jsonDecoder.decode(AngleTestDTO.self, from: Data(payload.utf8))
        print("[W5-DTO] 缺新字段回包解码成功 quizType=\(dto.quizType) errorMM=\(dto.errorMM) " +
              "sessionId=\(dto.sessionId ?? "nil")")
        XCTAssertEqual(dto.quizType, "table2D")
        XCTAssertEqual(dto.errorMM, 0)
        XCTAssertNil(dto.sessionId)
    }

    // MARK: - 同步 DTO 成绩字段对齐（v36 W1 / 契约 §4.1）

    /// 编码路径必须原样带上 9 个成绩字段。丢 `unitLabel` 会让恢复的数据语义错误
    /// （「局/次」被当「球」），故这里刻意用非默认值断言。
    func test_trainingSessionDTO_carriesDrillSetAndEntryScoreFields() throws {
        let session = TrainingSession()
        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球",
                               orderIndex: 3, note: "手感偏薄", criteriaText: "10 中 8 达标")
        let drillSet = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7,
                                formationToken: "f2", formationName: "中袋球形",
                                unitLabel: "局", passMade: 8, passTotal: 10,
                                durationSeconds: 245)
        // iOS 17 SwiftData cannot safely traverse a relationship graph composed
        // entirely of unmanaged @Model instances. Mirror the production path.
        context.insert(session)
        context.insert(entry)
        context.insert(drillSet)
        entry.session = session
        drillSet.entry = entry

        let json = try jsonEncoder.encode(TrainingSessionDTO(from: session))
        let dict = try XCTUnwrap(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let entries = try XCTUnwrap(dict["drillEntries"] as? [[String: Any]])
        let entryDict = try XCTUnwrap(entries.first)
        let setDict = try XCTUnwrap((entryDict["sets"] as? [[String: Any]])?.first)
        print("[W1-DTO] entry keys=\(entryDict.keys.sorted()) set keys=\(setDict.keys.sorted())")

        for key in ["orderIndex", "note", "criteriaText"] {
            XCTAssertTrue(entryDict.keys.contains(key), "DrillEntryDTO 缺字段 \(key)")
        }
        for key in ["formationToken", "formationName", "unitLabel",
                    "passMade", "passTotal", "durationSeconds"] {
            XCTAssertTrue(setDict.keys.contains(key), "DrillSetDTO 缺字段 \(key)")
        }

        XCTAssertEqual(entryDict["orderIndex"] as? Int, 3)
        XCTAssertEqual(entryDict["note"] as? String, "手感偏薄")
        XCTAssertEqual(entryDict["criteriaText"] as? String, "10 中 8 达标")
        XCTAssertEqual(setDict["formationToken"] as? String, "f2")
        XCTAssertEqual(setDict["formationName"] as? String, "中袋球形")
        XCTAssertEqual(setDict["unitLabel"] as? String, "局", "unitLabel 丢失会让恢复数据语义错误")
        XCTAssertEqual(setDict["passMade"] as? Int, 8)
        XCTAssertEqual(setDict["passTotal"] as? Int, 10)
        XCTAssertEqual(setDict["durationSeconds"] as? Int, 245)
    }

    /// 旧后端 mongoose `strict: true` 会丢弃未登记字段，回包里 9 个新字段全缺。
    /// 解码必须成功并回落默认值，否则 `syncSession` 会误判上传失败 → 队列项无限重试。
    func test_trainingSessionDTO_decodesWhenServerOmitsScoreFields() throws {
        let payload = """
        {"clientId":"abc","date":"2026-08-06T12:00:00Z","ballType":"chinese8",
         "totalDurationMinutes":5,"note":"","kind":"drill",
         "drillEntries":[{"drillId":"drill_c001","drillNameZh":"直线球",
           "sets":[{"setNumber":1,"targetBalls":10,"madeBalls":7}]}]}
        """
        let dto = try jsonDecoder.decode(TrainingSessionDTO.self, from: Data(payload.utf8))
        let entry = try XCTUnwrap(dto.drillEntries.first)
        let set = try XCTUnwrap(entry.sets.first)
        print("[W1-DTO] 缺成绩字段回包解码成功 orderIndex=\(entry.orderIndex) " +
              "note=\"\(entry.note)\" criteriaText=\"\(entry.criteriaText)\" " +
              "unitLabel=\(set.unitLabel) passMade=\(set.passMade) passTotal=\(set.passTotal) " +
              "formationToken=\(set.formationToken ?? "nil") " +
              "durationSeconds=\(set.durationSeconds.map(String.init) ?? "nil")")

        XCTAssertEqual(entry.orderIndex, 0)
        XCTAssertEqual(entry.note, "")
        XCTAssertEqual(entry.criteriaText, "")
        XCTAssertNil(set.formationToken)
        XCTAssertNil(set.formationName)
        XCTAssertEqual(set.unitLabel, "球")
        XCTAssertEqual(set.passMade, 0)
        XCTAssertEqual(set.passTotal, 0)
        XCTAssertNil(set.durationSeconds)
        // 原有字段不受影响
        XCTAssertEqual(set.madeBalls, 7)
        XCTAssertEqual(entry.drillNameZh, "直线球")
    }
}
