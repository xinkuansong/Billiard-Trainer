import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import QiuJi

/// 问题集合 v29 W6：记录 / 统计页按 `kind` 读取改造。
///
/// 覆盖五条完成标准：
/// - 标准 2：含三种 kind 的数据集，统计页数字与手算一致（手算过程随断言打印）；
/// - 标准 3：加一条 `tool` 会话后统计数字**逐项不变**（前后对比输出）；
/// - 标准 4：历史页 cognitive 分组与改造前 `AngleTrainingSession` 投影语义一致；
/// - 标准 5：删除 drill / 球形（内容侧消失）后历史记录仍按快照正常显示；
/// - 顺带：日历 `tool` 淡色活跃标记、周目标只算 `drill` + `cognitive`。
@MainActor
final class V29W6HistoryStatisticsKindTests: XCTestCase {

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

    /// 三种 kind 混合的数据集。
    ///
    /// `drill`（真实球台成绩）：
    /// - accuracy / drill_c001「半台直线球」：2 组 8/10 + 6/10，单位「球」
    /// - accuracy / drill_c002「小角度进球」：1 组 4/5，单位「球」
    /// - positioning / drill_c050「走位一杆清」：1 组 3/10，单位「局」
    ///
    /// `cognitive`：1 条会话（3 题）——⛔ 无 `DrillEntry`，不该进任何 made/target 求和。
    /// `tool`：1 条会话 25 分钟——⛔ 不该进任何聚合，也不计周目标。
    private struct Fixture {
        let drillSession: TrainingSession
        let cognitiveSession: TrainingSession
        let toolSession: TrainingSession
    }

    /// 固定为「今天中午」而不是 `Date()`：夹具里有 -1h / -2h 的偏移，
    /// 若在午夜前后跑，`Date()` 会让同一批会话跨到两个自然日，天数断言随时钟漂移。
    nonisolated private static var fixtureBaseDate: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
    }

    @discardableResult
    private func makeFixture(baseDate: Date = V29W6HistoryStatisticsKindTests.fixtureBaseDate) -> Fixture {
        let drill = TrainingSession(kind: TrainingSessionKind.drill)
        drill.date = baseDate
        drill.totalDurationMinutes = 40

        let e1 = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球",
                            orderIndex: 0, criteriaText: "10 球进 8")
        e1.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8, unitLabel: "球"),
            DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 6, unitLabel: "球"),
        ]
        let e2 = DrillEntry(drillId: "drill_c002", drillNameZh: "小角度进球", orderIndex: 1)
        e2.sets = [DrillSet(setNumber: 1, targetBalls: 5, madeBalls: 4, unitLabel: "球")]
        let e3 = DrillEntry(drillId: "drill_c050", drillNameZh: "走位一杆清", orderIndex: 2)
        e3.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 3, unitLabel: "局")]
        drill.drillEntries = [e1, e2, e3]
        context.insert(drill)

        let cognitive = CognitiveSessionRecorder.makeSession(
            quizType: "geometric",
            start: baseDate.addingTimeInterval(-3600),
            end: baseDate.addingTimeInterval(-3300)
        )
        context.insert(cognitive)
        for i in 0..<3 {
            let r = AngleTestResult(actualAngle: 45, userAngle: 45 + Double(i) * 2,
                                    pocketType: "corner", quizType: "geometric")
            r.date = baseDate.addingTimeInterval(-3600 + Double(i) * 120)
            r.sessionId = cognitive.id
            context.insert(r)
        }

        let tool = TrainingSession(kind: TrainingSessionKind.tool)
        tool.date = baseDate.addingTimeInterval(-7200)
        tool.totalDurationMinutes = 25
        tool.note = "自由击球"
        context.insert(tool)

        try! context.save()
        return Fixture(drillSession: drill, cognitiveSession: cognitive, toolSession: tool)
    }

    private func makeStatisticsVM() -> StatisticsViewModel {
        let vm = StatisticsViewModel()
        // 分类映射照常由内容库提供；测试里显式注入，避免依赖 Bundle 内容。
        vm.categoryMapping = [
            "drill_c001": "accuracy",
            "drill_c002": "accuracy",
            "drill_c050": "positioning",
        ]
        vm.timeRange = .week
        return vm
    }

    /// 统计页所有对外数字的一次快照，用于「加 tool 前后逐项对比」。
    @MainActor
    private struct StatsSnapshot: Equatable, CustomStringConvertible {
        let trainingDays: Int
        let totalDurationMinutes: Int
        let totalSets: Int
        let categoryRates: [String: String]
        let daysByKind: String
        let minutesByKind: String

        init(_ vm: StatisticsViewModel) {
            trainingDays = vm.trainingDays
            totalDurationMinutes = vm.totalDurationMinutes
            totalSets = vm.totalSets
            categoryRates = Dictionary(uniqueKeysWithValues: vm.categorySuccessRates.map {
                ($0.id, String(format: "%.4f(%d/%d)", $0.rate, $0.made, $0.target))
            })
            let d = vm.daysByKind
            let m = vm.minutesByKind
            daysByKind = "drill=\(d.drill) cognitive=\(d.cognitive) tool=\(d.tool)"
            minutesByKind = "drill=\(m.drill) cognitive=\(m.cognitive) tool=\(m.tool)"
        }

        /// 会被 tool 影响的字段单独列出，用于说明「哪些数字允许变、哪些必须不变」。
        var aggregatesOnly: [String: String] {
            ["trainingDays": "\(trainingDays)",
             "totalDurationMinutes": "\(totalDurationMinutes)",
             "totalSets": "\(totalSets)",
             "categoryRates": "\(categoryRates.sorted { $0.key < $1.key })"]
        }

        var description: String {
            "days=\(trainingDays) minutes=\(totalDurationMinutes) sets=\(totalSets) " +
            "rates=\(categoryRates.sorted { $0.key < $1.key }) " +
            "daysByKind[\(daysByKind)] minutesByKind[\(minutesByKind)]"
        }
    }

    // MARK: - 标准 2：三种 kind 数据集下统计数字 == 手算

    func test_categoryRates_matchHandComputation_withAllThreeKinds() throws {
        makeFixture()
        let vm = makeStatisticsVM()
        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())

        print("""

        ===== [W6-标准2] 手算过程 =====
        数据集：drill 1 条（3 个 drill / 4 组）+ cognitive 1 条（3 题、无组）+ tool 1 条（25 分钟）

        分类 accuracy（drill_c001 + drill_c002，单位均为「球」）：
          Σmade   = 8 + 6 + 4 = 18
          Σtarget = 10 + 10 + 5 = 25
          rate    = 18 / 25 = 0.72 → 72%
          组数     = 2 + 1 = 3

        分类 positioning（drill_c050，单位「局」）：
          Σmade   = 3
          Σtarget = 10
          rate    = 3 / 10 = 0.30 → 30%
          组数     = 1

        ⛔ 全局单一准确率（D-v29-2 已删）：若还存在会是 (18+3)/(25+10) = 21/35 = 0.60，
           把「球」和「局」加在同一分母——正是该裁定要消掉的无意义数字。

        训练量口径（drill + cognitive，⛔ 排除 tool）：
          时长 = 40 + 5 = 45 分钟（cognitive 会话 300 秒 → 5 分钟）
          天数 = 1（三条会话都落在同一天）
          组数 = 4（只有 drill 有组；cognitive/tool 恒为 0）

        实测：
        \(StatsSnapshot(vm))
        ==============================

        """)

        let rates = vm.categorySuccessRates
        XCTAssertEqual(rates.count, 2, "只应有 accuracy / positioning 两个分组")

        let accuracy = try XCTUnwrap(rates.first { $0.id == "accuracy" })
        XCTAssertEqual(accuracy.made, 18)
        XCTAssertEqual(accuracy.target, 25)
        XCTAssertEqual(accuracy.rate, 0.72, accuracy: 0.0001)
        XCTAssertEqual(accuracy.totalSets, 3)
        XCTAssertEqual(accuracy.units, ["球"])
        XCTAssertEqual(accuracy.countSummary, "18/25 球")

        let positioning = try XCTUnwrap(rates.first { $0.id == "positioning" })
        XCTAssertEqual(positioning.made, 3)
        XCTAssertEqual(positioning.target, 10)
        XCTAssertEqual(positioning.rate, 0.30, accuracy: 0.0001)
        XCTAssertEqual(positioning.totalSets, 1)
        XCTAssertEqual(positioning.units, ["局"])

        // 训练量：drill 40 + cognitive 5 = 45；tool 的 25 分钟不在内。
        XCTAssertEqual(vm.totalDurationMinutes, 45)
        XCTAssertEqual(vm.trainingDays, 1)
        XCTAssertEqual(vm.totalSets, 4)

        let m = vm.minutesByKind
        XCTAssertEqual(m.drill, 40)
        XCTAssertEqual(m.cognitive, 5)
        XCTAssertEqual(m.tool, 25, "tool 时长单独可见，但不进 totalDurationMinutes")
        XCTAssertEqual(m.drill + m.cognitive, vm.totalDurationMinutes)
    }

    /// 分组内 Σmade/Σtarget ≠ 各组比率的平均——手算校验聚合口径没写成「平均的平均」。
    func test_categoryRate_isSumRatio_notAverageOfSetRatios() throws {
        makeFixture()
        let vm = makeStatisticsVM()
        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())

        let accuracy = try XCTUnwrap(vm.categorySuccessRates.first { $0.id == "accuracy" })
        // 各组比率平均 = (0.8 + 0.6 + 0.8) / 3 = 0.7333…，与 Σ 口径 0.72 不同。
        let averageOfSets = (0.8 + 0.6 + 0.8) / 3.0
        print("[W6-标准2] Σ口径=\(accuracy.rate) 各组平均=\(averageOfSets)")
        XCTAssertEqual(accuracy.rate, 0.72, accuracy: 0.0001)
        XCTAssertNotEqual(accuracy.rate, averageOfSets, accuracy: 0.0001)
    }

    // MARK: - 标准 3：加 tool 会话，统计数字不变

    func test_addingToolSession_leavesEveryAggregateUnchanged() throws {
        makeFixture()
        let vm = makeStatisticsVM()
        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let before = StatsSnapshot(vm)

        // 再加一条 tool 会话（不同的一天 + 更长时长，若被误算入必然改变天数与时长）。
        let extraTool = TrainingSession(kind: TrainingSessionKind.tool)
        extraTool.date = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        extraTool.totalDurationMinutes = 99
        extraTool.note = "打一走二想三"
        context.insert(extraTool)
        try context.save()

        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let after = StatsSnapshot(vm)

        print("""

        ===== [W6-标准3] tool 排除前后对比 =====
        新增：kind=tool date=-2d duration=99min note=打一走二想三
        before: \(before)
        after : \(after)
        必须不变的聚合项：
          before=\(before.aggregatesOnly.sorted { $0.key < $1.key })
          after =\(after.aggregatesOnly.sorted { $0.key < $1.key })
        允许变化的只有 tool 自身的独立展示：
          minutesByKind before=\(before.minutesByKind) after=\(after.minutesByKind)
        =======================================

        """)

        XCTAssertEqual(before.aggregatesOnly, after.aggregatesOnly,
                       "tool 会话不得改变任何准确率/训练量聚合（契约 §5.3）")
        XCTAssertEqual(after.trainingDays, 1, "tool 那天不算训练日")
        XCTAssertEqual(after.totalDurationMinutes, 45)
        XCTAssertEqual(vm.minutesByKind.tool, 25 + 99, "tool 时长仍如实单列")
        XCTAssertFalse(vm.filteredSessions.contains { $0.kind == TrainingSessionKind.tool })
        XCTAssertFalse(vm.filteredDrillSessions.contains { $0.kind != TrainingSessionKind.drill })
    }

    /// tool 会话即使被塞进 `DrillEntry`（异常数据），也不得进入准确率聚合——
    /// 排除依据是 `kind`，不是「恰好没有组」。
    func test_toolSessionWithStrayEntries_stillExcludedFromRates() throws {
        makeFixture()

        let dirtyTool = TrainingSession(kind: TrainingSessionKind.tool)
        dirtyTool.date = Date()
        dirtyTool.totalDurationMinutes = 30
        let stray = DrillEntry(drillId: "drill_c001", drillNameZh: "引擎试打")
        stray.sets = [DrillSet(setNumber: 1, targetBalls: 100, madeBalls: 100, unitLabel: "球")]
        dirtyTool.drillEntries = [stray]
        context.insert(dirtyTool)
        try context.save()

        let vm = makeStatisticsVM()
        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())

        let accuracy = try XCTUnwrap(vm.categorySuccessRates.first { $0.id == "accuracy" })
        print("[W6-标准3] 脏 tool（100/100）注入后 accuracy=\(accuracy.countSummary) rate=\(accuracy.rate)")
        XCTAssertEqual(accuracy.made, 18, "tool 的 100 球未被计入")
        XCTAssertEqual(accuracy.target, 25)
        XCTAssertEqual(vm.totalSets, 4)
    }

    // MARK: - 标准 4：历史页 cognitive 读真 session，语义与旧投影一致

    func test_historyCognitiveGrouping_matchesLegacyProjectionSemantics() async throws {
        // 构造两簇同 quizType 的历史答题：簇内间隔 2 分钟，两簇间隔 90 分钟（> 30 分钟）。
        let t0 = Calendar.current.date(byAdding: .hour, value: -6, to: Date())!
        var offsets: [Double] = [0, 120, 240]                      // 第一簇 3 题
        offsets += [5400, 5520]                                    // 第二簇 2 题（+90min、+92min）
        var orphans: [AngleTestResult] = []
        for off in offsets {
            let r = AngleTestResult(actualAngle: 40, userAngle: 42,
                                    pocketType: "corner", quizType: "scene2D")
            r.date = t0.addingTimeInterval(off)
            context.insert(r)
            orphans.append(r)
        }
        try context.save()

        // 改造前的呈现口径：内存投影。
        let legacy = HistoryViewModel.inferAngleSessions(orphans)

        // W5 回填（同口径）→ W6 历史页读真 session。
        let report = try CognitiveSessionBackfill.run(context: context)

        let vm = HistoryViewModel()
        await vm.loadSessions(context: context)
        let modern = vm.cognitiveSessions

        print("""

        ===== [W6-标准4] 新旧呈现对比 =====
        回填报告：\(report.summary)
        旧（AngleTrainingSession 内存投影）：\(legacy.count) 组
        \(legacy.sorted { $0.endDate > $1.endDate }.map { "  quizType=\($0.quizType) 题数=\($0.questionCount) 起=\($0.startDate) 止=\($0.endDate)" }.joined(separator: "\n"))
        新（kind="cognitive" 真 session）：\(modern.count) 组
        \(modern.map { "  name=\($0.displayNameZh) 题数=\($0.questionCount) 起=\($0.startDate) 止=\($0.endDate) 时长=\($0.durationMinutes)min" }.joined(separator: "\n"))
        未归属成绩数：\(vm.unassignedCognitiveResultCount)
        ===================================

        """)

        XCTAssertEqual(modern.count, legacy.count, "分组数量一致")
        let legacySorted = legacy.sorted { $0.endDate > $1.endDate }
        for (m, l) in zip(modern, legacySorted) {
            XCTAssertEqual(m.questionCount, l.questionCount, "每组题数一致")
            XCTAssertEqual(m.startDate, l.startDate, "起始时间一致")
            XCTAssertEqual(m.endDate, l.endDate, "结束时间一致")
            XCTAssertEqual(m.quizType, l.quizType)
        }
        XCTAssertEqual(modern.map(\.questionCount), [2, 3], "新的在前：2 题簇 → 3 题簇")
        XCTAssertEqual(vm.unassignedCognitiveResultCount, 0, "回填后无孤儿成绩")
        // 名称走 `note` 快照，而不是把 quizType 拿去回查文案表。
        XCTAssertEqual(Set(modern.map(\.displayNameZh)), ["2D 角度训练"])
    }

    /// 归属由 `sessionId` 决定，不再由时间间隔推断：把两条时间上紧邻的成绩
    /// 分给两个会话，历史页就该显示两行，而不是被 30 分钟窗口合并成一行。
    func test_historyCognitiveGrouping_followsSessionId_notTimeGap() throws {
        let t0 = Date().addingTimeInterval(-1800)
        let s1 = CognitiveSessionRecorder.makeSession(quizType: "geometric", start: t0, end: t0)
        let s2 = CognitiveSessionRecorder.makeSession(quizType: "geometric",
                                                      start: t0.addingTimeInterval(60),
                                                      end: t0.addingTimeInterval(60))
        context.insert(s1)
        context.insert(s2)

        var results: [AngleTestResult] = []
        for (idx, session) in [s1, s2].enumerated() {
            let r = AngleTestResult(actualAngle: 30, userAngle: 31,
                                    pocketType: "corner", quizType: "geometric")
            r.date = t0.addingTimeInterval(Double(idx) * 60)
            r.sessionId = session.id
            context.insert(r)
            results.append(r)
        }
        try context.save()

        let items = HistoryViewModel.assembleCognitiveSessions(
            sessions: try context.fetch(FetchDescriptor<TrainingSession>()),
            results: results
        )
        // 同 quizType、间隔 1 分钟：旧投影会合并成 1 组。
        let legacy = HistoryViewModel.inferAngleSessions(results)

        print("[W6-标准4] 同 quizType 间隔 60s：真 session 分组=\(items.count) 旧投影分组=\(legacy.count)")
        XCTAssertEqual(items.count, 2, "归属跟 sessionId，不跟时间窗口")
        XCTAssertEqual(legacy.count, 1, "对照：旧投影会把它们合并（说明两者确实是不同机制）")
        XCTAssertTrue(items.allSatisfy { $0.questionCount == 1 })
    }

    func test_historyCognitive_unassignedResultsAreCountedNotSilentlyDropped() async throws {
        let cognitive = CognitiveSessionRecorder.makeSession(quizType: "geometric",
                                                            start: Date(), end: Date())
        context.insert(cognitive)
        let assigned = AngleTestResult(actualAngle: 20, userAngle: 21,
                                       pocketType: "corner", quizType: "geometric")
        assigned.sessionId = cognitive.id
        context.insert(assigned)
        let orphan = AngleTestResult(actualAngle: 20, userAngle: 25,
                                     pocketType: "corner", quizType: "geometric")
        context.insert(orphan)
        try context.save()

        let vm = HistoryViewModel()
        await vm.loadSessions(context: context)

        print("[W6] cognitive 组=\(vm.cognitiveSessions.count) 未归属成绩=\(vm.unassignedCognitiveResultCount)")
        XCTAssertEqual(vm.cognitiveSessions.count, 1)
        XCTAssertEqual(vm.cognitiveSessions[0].questionCount, 1)
        XCTAssertEqual(vm.unassignedCognitiveResultCount, 1,
                       "孤儿成绩不静默消失，计数留痕供排查")
    }

    // MARK: - 标准 5：内容删除后历史仍按快照显示

    func test_historyDisplay_survivesDrillAndFormationDeletion() async throws {
        // 记录一条用「已下架」drill 与球形的训练：drillId 不在任何内容映射里。
        let session = TrainingSession(kind: TrainingSessionKind.drill)
        session.date = Date()
        session.totalDurationMinutes = 20
        let entry = DrillEntry(drillId: "drill_deleted_999",
                               drillNameZh: "已下架的老球形练习",
                               orderIndex: 0,
                               criteriaText: "10 球进 7")
        entry.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7,
                     formationToken: "drill_deleted_999__X9",
                     formationName: "被删掉的球形 X9",
                     unitLabel: "球"),
        ]
        session.drillEntries = [entry]
        context.insert(session)
        try context.save()

        let vm = HistoryViewModel()
        await vm.loadSessions(context: context)   // 内容映射里没有 drill_deleted_999
        vm.selectedDate = session.date

        let items = vm.selectedDateItems
        let title = vm.displayName(for: session)
        let stored = try context.fetch(FetchDescriptor<DrillSet>())

        print("""

        ===== [W6-标准5] 快照生效实证 =====
        drillId=\(entry.drillId)（内容库无此 drill：categoryForDrill 兜底 = \(vm.categoryForDrill(entry.drillId))）
        行标题（快照 drillNameZh）：\(title)
        达标说明（快照 criteriaText）：\(entry.criteriaText)
        球形名（快照 formationName）：\(stored.first?.formationName ?? "nil")
        球形 token：\(stored.first?.formationToken ?? "nil")
        单位（快照 unitLabel）：\(stored.first?.unitLabel ?? "nil")
        当日行数：\(items.count)
        ===================================

        """)

        XCTAssertEqual(items.count, 1, "drill 被删也照常出现在历史里")
        XCTAssertEqual(title, "已下架的老球形练习", "标题取快照，不回查内容表")
        XCTAssertFalse(title.contains("训练"), "不应退回分类名兜底")
        XCTAssertEqual(stored.first?.formationName, "被删掉的球形 X9")
        XCTAssertEqual(entry.criteriaText, "10 球进 7")
        // 唯一退化的是分类归属（无快照字段），名称与达标线不受影响。
        XCTAssertEqual(vm.categoryForDrill(entry.drillId), "combined")
    }

    func test_displayName_multipleEntries_usesSnapshotNames() {
        let session = TrainingSession(kind: TrainingSessionKind.drill)
        let a = DrillEntry(drillId: "x", drillNameZh: "半台直线球", orderIndex: 0)
        let b = DrillEntry(drillId: "y", drillNameZh: "小角度进球", orderIndex: 1)
        context.insert(session)
        context.insert(b)
        context.insert(a)
        // 乱序关联，应仍按 orderIndex 取首项。
        b.session = session
        a.session = session

        let vm = HistoryViewModel()
        XCTAssertEqual(vm.displayName(for: session), "半台直线球 等 2 项")
    }

    // MARK: - 日历标记：tool 淡色活跃

    func test_calendarMarker_toolOnlyDay_isToolActivity() async throws {
        let cal = Calendar.current
        let toolDay = cal.date(byAdding: .day, value: -3, to: Date())!
        let drillDay = cal.date(byAdding: .day, value: -1, to: Date())!

        let tool = TrainingSession(kind: TrainingSessionKind.tool)
        tool.date = toolDay
        tool.totalDurationMinutes = 12
        tool.note = "自由走位"
        context.insert(tool)

        let drill = TrainingSession(kind: TrainingSessionKind.drill)
        drill.date = drillDay
        drill.totalDurationMinutes = 30
        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
        entry.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 9, unitLabel: "球")]
        drill.drillEntries = [entry]
        context.insert(drill)
        try context.save()

        let vm = HistoryViewModel()
        await vm.loadSessions(context: context)

        let toolMarker = vm.marker(for: toolDay)
        let drillMarker = vm.marker(for: drillDay)
        print("[W6] toolDay marker=\(String(describing: toolMarker)) drillDay marker=\(String(describing: drillMarker))")

        XCTAssertEqual(toolMarker, .toolActivity("工具"))
        XCTAssertTrue(toolMarker?.isToolActivity == true, "tool 走淡色标记")
        XCTAssertNotNil(drillMarker)
        XCTAssertFalse(drillMarker?.isToolActivity == true, "训练标记不是淡色活跃标记")
        XCTAssertTrue(vm.hasSession(on: toolDay), "工具日在日历上可见")

        // tool 那天也该有一行，避免「日历有标记、点开却说无记录」。
        vm.selectedDate = toolDay
        XCTAssertEqual(vm.selectedDateItems.count, 1)
        if case .tool(let item) = vm.selectedDateItems[0] {
            XCTAssertEqual(item.displayNameZh, "自由走位", "工具名取 note 快照")
            XCTAssertEqual(item.durationMinutes, 12)
        } else {
            XCTFail("工具日应是 tool 行")
        }
    }

    func test_cognitiveOnlyDay_marker_isTrainingNotTool() async throws {
        let day = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let cognitive = CognitiveSessionRecorder.makeSession(quizType: "aimPoint",
                                                            start: day, end: day)
        context.insert(cognitive)
        let r = AngleTestResult(actualAngle: 10, userAngle: 11,
                                pocketType: "corner", quizType: "aimPoint")
        r.date = day
        r.sessionId = cognitive.id
        context.insert(r)
        try context.save()

        let vm = HistoryViewModel()
        await vm.loadSessions(context: context)

        // 改造前：cognitive 会话有 0 个 DrillEntry，`categoryForDate` 会把它算成
        // 「综合」；现在只看 drill，故落到认知练习的「角度」标记。
        XCTAssertEqual(vm.marker(for: day), .training("角度"))
        XCTAssertNil(vm.categoryForDate(day), "cognitive 不产生 drill 分类")
    }

    // MARK: - 标准 2 的图形取证：真实卡片视图 + 真实数据离屏渲染

    /// 统计页整体受 Pro 门控（`BTPremiumLock(.fullMask)` 把内容 blur 8pt），
    /// 从 App 截图看不清数字，故这里直接用**生产视图** `StatisticsCategoryRatesCard`
    /// 配上 `StatisticsViewModel` 算出的真值离屏渲染成 PNG，作为「数字与手算一致」的图证。
    func test_renderCategoryRatesCard_asEvidence() throws {
        makeFixture()
        let vm = makeStatisticsVM()
        vm.sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let items = vm.categorySuccessRates

        XCTAssertEqual(items.map(\.id), ["accuracy", "positioning"])
        XCTAssertEqual(items.map { String(format: "%.0f%%", $0.rate * 100) }, ["72%", "30%"])

        let card = StatisticsCategoryRatesCard(
            items: items,
            dateRangeLabel: vm.dateRangeLabel,
            hasScores: vm.hasDrillScores
        )
        .frame(width: 390)
        .background(Color.btBG)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "分类成功率卡应能渲染")
        try writeEvidence(image, name: "01-statistics-category-rates")

        // 空态一并取证：无球台成绩时不显示一排 0，也不出现「达标线 0」之类的伪值。
        let emptyCard = StatisticsCategoryRatesCard(
            items: [], dateRangeLabel: vm.dateRangeLabel, hasScores: false
        )
        .frame(width: 390)
        .background(Color.btBG)
        let emptyRenderer = ImageRenderer(content: emptyCard)
        emptyRenderer.scale = 2
        try writeEvidence(try XCTUnwrap(emptyRenderer.uiImage), name: "02-statistics-category-rates-empty")
    }

    private func writeEvidence(_ image: UIImage, name: String) throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/w6-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try XCTUnwrap(image.pngData()).write(to: url)
        print("[W6-evidence] \(url.path)")
    }

    // MARK: - 周目标只算 drill + cognitive

    func test_weeklyGoal_excludesToolSessions() throws {
        let cal = Calendar.current
        let weekStart = try XCTUnwrap(cal.dateInterval(of: .weekOfYear, for: Date())?.start)

        func session(_ kind: String, dayOffset: Int) -> TrainingSession {
            let s = TrainingSession(kind: kind)
            s.date = cal.date(byAdding: .hour, value: dayOffset * 24 + 1, to: weekStart)!
            return s
        }

        // 本周：drill 第 0 天、cognitive 第 1 天、tool 第 2 天。
        let all = [session(TrainingSessionKind.drill, dayOffset: 0),
                   session(TrainingSessionKind.cognitive, dayOffset: 1),
                   session(TrainingSessionKind.tool, dayOffset: 2)]

        let counted = TrainingGoalMetrics.daysTrained(all, since: weekStart, calendar: cal)
        print("""
        [W6] 周目标手算：本周 3 条会话（drill/cognitive/tool 各 1，分属 3 个不同日期）
             计入 = drill + cognitive = 2 天；tool 不计。实测 = \(counted) 天
        """)
        XCTAssertEqual(counted, 2)
        XCTAssertEqual(TrainingGoalMetrics.goalCounting(all).count, 2)
        XCTAssertFalse(TrainingSessionKind.countsTowardGoal(TrainingSessionKind.tool))
        XCTAssertFalse(TrainingSessionKind.countsTowardAccuracy(TrainingSessionKind.tool))
    }

}
