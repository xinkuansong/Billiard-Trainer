import XCTest
import SwiftData
@testable import QiuJi

/// 问题集合 v29 W2b：历史详情「编辑数据」。
///
/// 覆盖完成标准：
/// - 标准 3（落库实证）：编辑后 made/target/duration/formation 确实写入并可从 store 重新读出，
///   且 `criteriaText` / `drillNameZh` / `unitLabel` / `passMade` / `passTotal` 等快照未被重建；
/// - 标准 5（校验）：made > target、target ≤ 0、非数字输入一律被拒且模型不被写脏。
@MainActor
final class V29W2bTrainingDataEditTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        SyncQueueManager.shared.configure(context: context)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Fixture

    private static let options = [
        DrillFormationOption(token: "manual01", name: "厚球分离角控制 · 球形1"),
        DrillFormationOption(token: "manual02", name: "厚球分离角控制 · 球形2"),
    ]

    /// 一条「已经存在的历史记录」：两组，带 W4 之后的全部字段。
    @discardableResult
    private func makeSession() throws -> TrainingSession {
        let session = TrainingSession()
        session.totalDurationMinutes = 20
        let entry = DrillEntry(
            drillId: "drill_c026",
            drillNameZh: "厚球分离角控制",
            orderIndex: 0,
            note: "手感一般",
            criteriaText: "10 次中 7 次分离角误差 < 5°"
        )
        let s1 = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 6,
                          formationToken: "manual01", formationName: "厚球分离角控制 · 球形1",
                          unitLabel: "次", passMade: 0, passTotal: 0, durationSeconds: 90)
        let s2 = DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 8,
                          formationToken: "manual01", formationName: "厚球分离角控制 · 球形1",
                          unitLabel: "次", passMade: 0, passTotal: 0, durationSeconds: 120)
        entry.sets = [s1, s2]
        session.drillEntries = [entry]
        context.insert(session)
        try context.save()
        return session
    }

    private func makeDraft(_ session: TrainingSession) -> TrainingDataDraft {
        TrainingDataDraft(session: session, formationProvider: { _ in Self.options })
    }

    private func refetch(_ id: UUID) throws -> TrainingSession {
        let all = try context.fetch(FetchDescriptor<TrainingSession>())
        return try XCTUnwrap(all.first(where: { $0.id == id }))
    }

    // MARK: - 草稿构造：只暴露成绩面

    func test_draft_mirrorsPersistedSets() throws {
        let session = try makeSession()
        let draft = makeDraft(session)

        XCTAssertEqual(draft.entries.count, 1)
        let entry = try XCTUnwrap(draft.entries.first)
        XCTAssertEqual(entry.drillNameZh, "厚球分离角控制")
        XCTAssertEqual(entry.criteriaText, "10 次中 7 次分离角误差 < 5°")
        XCTAssertEqual(entry.sets.map(\.madeText), ["6", "8"])
        XCTAssertEqual(entry.sets.map(\.targetText), ["10", "10"])
        XCTAssertEqual(entry.sets.map(\.durationText), ["90", "120"])
        XCTAssertEqual(entry.sets.map(\.formationToken), ["manual01", "manual01"])
        XCTAssertTrue(draft.isValid)
    }

    func test_draft_emptyDurationForRecordsWithoutTiming() throws {
        let session = try makeSession()
        // SwiftData 关系数组不保证顺序，按 setNumber 定位（草稿侧已按 setNumber 排序）。
        try XCTUnwrap(session.drillEntries[0].sets.first(where: { $0.setNumber == 1 }))
            .durationSeconds = nil
        try context.save()

        let draft = makeDraft(session)
        XCTAssertEqual(draft.entries[0].sets[0].durationText, "")
    }

    // MARK: - 标准 3：编辑后确实落库，快照不被重建

    func test_apply_persistsScoreEdits_andKeepsSnapshotFields() throws {
        let session = try makeSession()
        let sessionId = session.id
        var draft = makeDraft(session)

        draft.entries[0].sets[0].madeText = "9"
        draft.entries[0].sets[0].targetText = "12"
        draft.entries[0].sets[0].durationText = "150"
        draft.entries[0].sets[0].formationToken = Self.options[1].token
        draft.entries[0].sets[0].formationName = Self.options[1].name
        draft.entries[0].sets[1].durationText = ""   // 清空用时

        try draft.apply(to: session)
        try context.save()

        let reloaded = try refetch(sessionId)
        let entry = try XCTUnwrap(reloaded.drillEntries.first)
        let sets = entry.sets.sorted { $0.setNumber < $1.setNumber }

        // 成绩面写入
        XCTAssertEqual(sets[0].madeBalls, 9)
        XCTAssertEqual(sets[0].targetBalls, 12)
        XCTAssertEqual(sets[0].durationSeconds, 150)
        XCTAssertEqual(sets[0].formationToken, "manual02")
        XCTAssertEqual(sets[0].formationName, "厚球分离角控制 · 球形2")
        XCTAssertNil(sets[1].durationSeconds, "清空用时应写回 nil（未记录）")
        XCTAssertEqual(sets[1].madeBalls, 8, "未编辑的组保持原值")

        // 快照面原样冻结（契约 §6.5）
        XCTAssertEqual(entry.drillNameZh, "厚球分离角控制")
        XCTAssertEqual(entry.criteriaText, "10 次中 7 次分离角误差 < 5°")
        XCTAssertEqual(entry.note, "手感一般")
        XCTAssertEqual(sets.map(\.unitLabel), ["次", "次"])
        XCTAssertEqual(sets.map(\.passMade), [0, 0])
        XCTAssertEqual(sets.map(\.passTotal), [0, 0])
        // session 级字段不开放编辑
        XCTAssertEqual(reloaded.totalDurationMinutes, 20)
        XCTAssertEqual(reloaded.ballType, "chinese8")
        XCTAssertEqual(reloaded.kind, "drill")
        XCTAssertNil(reloaded.planId)
    }

    func test_apply_derivedSuccessRateFollowsEdit() throws {
        let session = try makeSession()
        XCTAssertEqual(session.drillEntries[0].successRate, 14.0 / 20.0, accuracy: 1e-9)

        var draft = makeDraft(session)
        draft.entries[0].sets[0].madeText = "10"
        try draft.apply(to: session)
        try context.save()

        XCTAssertEqual(try refetch(session.id).drillEntries[0].successRate,
                       18.0 / 20.0, accuracy: 1e-9)
    }

    func test_apply_enqueuesNothingItself_callerOwnsSync() throws {
        // apply 只写模型；同步入队由调用方（详情页）负责，避免测试对全局队列产生副作用。
        let session = try makeSession()
        var draft = makeDraft(session)
        draft.entries[0].sets[0].madeText = "7"
        let before = try context.fetch(FetchDescriptor<SyncPendingItem>()).count
        try draft.apply(to: session)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SyncPendingItem>()).count, before)
    }

    // MARK: - 标准 5：校验

    func test_validation_rejectsMadeGreaterThanTarget() throws {
        let session = try makeSession()
        var draft = makeDraft(session)
        draft.entries[0].sets[0].madeText = "99"

        let setId = draft.entries[0].sets[0].id
        XCTAssertFalse(draft.isValid)
        XCTAssertEqual(draft.validationErrors[setId], "进球数不能大于总数（10）")
        XCTAssertThrowsError(try draft.apply(to: session))

        // 被拒时模型不得被写脏
        XCTAssertEqual(try refetch(session.id).drillEntries[0].sets
            .first(where: { $0.setNumber == 1 })?.madeBalls, 6)
    }

    func test_validation_rejectsNonPositiveOrNonNumericTarget() throws {
        let session = try makeSession()
        for bad in ["0", "-3", "", "abc"] {
            var draft = makeDraft(session)
            draft.entries[0].sets[0].targetText = bad
            XCTAssertFalse(draft.isValid, "target=\(bad) 应被拒")
            XCTAssertEqual(draft.validationErrors[draft.entries[0].sets[0].id],
                           "总数需为大于 0 的整数")
        }
    }

    func test_validation_rejectsNonNumericMadeAndDuration() throws {
        let session = try makeSession()

        var badMade = makeDraft(session)
        badMade.entries[0].sets[0].madeText = "三"
        XCTAssertEqual(badMade.validationErrors[badMade.entries[0].sets[0].id],
                       "进球数需为 0 或正整数")

        var badDuration = makeDraft(session)
        badDuration.entries[0].sets[0].durationText = "-5"
        XCTAssertEqual(badDuration.validationErrors[badDuration.entries[0].sets[0].id],
                       "用时需为 0 或正整数秒，留空表示未记录")
    }

    func test_validation_emptyMadeMeansZero() throws {
        let session = try makeSession()
        var draft = makeDraft(session)
        draft.entries[0].sets[0].madeText = ""
        XCTAssertTrue(draft.isValid)
        try draft.apply(to: session)
        try context.save()
        XCTAssertEqual(try refetch(session.id).drillEntries[0].sets
            .first(where: { $0.setNumber == 1 })?.madeBalls, 0)
    }

    // MARK: - 球形选项来源

    func test_formationOptions_emptyForSingleFormationDrill() {
        // 单球形（或无序列）不出球形列——与录入侧同规则。
        XCTAssertTrue(TrainingDataDraft.formationOptions(for: "drill_does_not_exist").isEmpty)
    }
}
