import XCTest
import SwiftData
@testable import QiuJi

/// 问题集合 v29 W6 取证用**播种 runner**：把「三种 kind + 已下架 drill」的数据集
/// 写成一个真实 SwiftData store 文件，供 shell 拷进模拟器 App 容器后启动截图。
///
/// 为什么不用 UI 一路点出来：cognitive 要答题、tool 要停留、还得有一条引用**已删除**
/// drill 的历史记录——最后一项无法从 UI 造出（当前内容库里的 drill 都存在）。
/// 播种走的是与 App 完全同一套 `ModelContainerFactory.currentSchema` 与迁移计划，
/// 因此 App 启动后读到的就是生产路径读出的数据。
///
/// ⛔ 不随常规测试跑（写盘且只服务取证）：未开门即 `XCTSkip`。
/// 开门：`touch build/.w6-seed-store`，再
/// `xcodebuild ... -only-testing:QiuJiTests/V29W6StoreSeedRunnerTests test`。
@MainActor
final class V29W6StoreSeedRunnerTests: XCTestCase {

    private static let flagRelativePath = "build/.w6-seed-store"
    private static let outputRelativePath = "build/w6-seed"

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func skipUnlessEnabled() throws {
        let flag = repositoryRoot.appendingPathComponent(Self.flagRelativePath)
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: flag.path),
            "W6 取证播种 runner，不随常规测试跑。开门：touch \(Self.flagRelativePath)"
        )
    }

    /// 造一个可截图的数据集，写到 `build/w6-seed/default.store`。
    ///
    /// 内容与 `V29W6HistoryStatisticsKindTests` 的夹具同构（同一手算口径），
    /// 另加一条引用「已下架 drill + 已删球形」的历史记录用于快照实证。
    func test_seedThreeKindStore() throws {
        try skipUnlessEnabled()

        let outDir = repositoryRoot.appendingPathComponent(Self.outputRelativePath, isDirectory: true)
        try? FileManager.default.removeItem(at: outDir)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let storeURL = outDir.appendingPathComponent("default.store")

        let container = try ModelContainerFactory.makeContainer(at: storeURL)
        let context = container.mainContext

        let cal = Calendar.current
        let noonToday = cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)

        // ── kind="drill"：accuracy 18/25 球、positioning 3/10 局（与单测手算同值）
        let drill = TrainingSession(kind: TrainingSessionKind.drill)
        drill.date = noonToday
        drill.totalDurationMinutes = 40
        drill.note = "手感不错"
        let e1 = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球",
                            orderIndex: 0, note: "后手放松", criteriaText: "10 球进 8")
        e1.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8, unitLabel: "球", durationSeconds: 300),
            DrillSet(setNumber: 2, targetBalls: 10, madeBalls: 6, unitLabel: "球", durationSeconds: 280),
        ]
        let e2 = DrillEntry(drillId: "drill_c002", drillNameZh: "小角度进球", orderIndex: 1)
        e2.sets = [DrillSet(setNumber: 1, targetBalls: 5, madeBalls: 4, unitLabel: "球")]
        let e3 = DrillEntry(drillId: "drill_c050", drillNameZh: "走位一杆清", orderIndex: 2)
        e3.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 3, unitLabel: "局")]
        drill.drillEntries = [e1, e2, e3]
        context.insert(drill)

        // ── kind="drill" 且引用已下架 drill / 已删球形（快照实证，标准 5）
        let legacy = TrainingSession(kind: TrainingSessionKind.drill)
        legacy.date = cal.date(byAdding: .day, value: -1, to: noonToday)!
        legacy.totalDurationMinutes = 25
        let le = DrillEntry(drillId: "drill_deleted_999",
                            drillNameZh: "已下架的老球形练习",
                            orderIndex: 0, criteriaText: "10 球进 7")
        le.sets = [
            DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 7,
                     formationToken: "drill_deleted_999__X9",
                     formationName: "被删掉的球形 X9", unitLabel: "球"),
        ]
        legacy.drillEntries = [le]
        context.insert(legacy)

        // ── kind="cognitive"：1 条会话 + 3 题
        let cognitive = CognitiveSessionRecorder.makeSession(
            quizType: "geometric",
            start: noonToday.addingTimeInterval(-3600),
            end: noonToday.addingTimeInterval(-3300)
        )
        context.insert(cognitive)
        for i in 0..<3 {
            let r = AngleTestResult(actualAngle: 45, userAngle: 45 + Double(i) * 2,
                                    pocketType: "corner", quizType: "geometric")
            r.date = noonToday.addingTimeInterval(-3600 + Double(i) * 120)
            r.sessionId = cognitive.id
            context.insert(r)
        }

        // ── kind="tool"：当天 25 分钟 + 两天前 99 分钟（后者独占一天，用于看淡色标记）
        let tool1 = TrainingSession(kind: TrainingSessionKind.tool)
        tool1.date = noonToday.addingTimeInterval(-7200)
        tool1.totalDurationMinutes = 25
        tool1.note = "自由击球"
        context.insert(tool1)

        let tool2 = TrainingSession(kind: TrainingSessionKind.tool)
        tool2.date = cal.date(byAdding: .day, value: -2, to: noonToday)!
        tool2.totalDurationMinutes = 99
        tool2.note = "打一走二想三"
        context.insert(tool2)

        try context.save()

        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let byKind = Dictionary(grouping: sessions, by: \.kind).mapValues(\.count)
        print("""
        [W6-seed] store=\(storeURL.path)
        [W6-seed] sessions=\(sessions.count) byKind=\(byKind.sorted { $0.key < $1.key })
        [W6-seed] angleResults=\(try context.fetch(FetchDescriptor<AngleTestResult>()).count)
        [W6-seed] drillSets=\(try context.fetch(FetchDescriptor<DrillSet>()).count)
        """)

        XCTAssertEqual(byKind[TrainingSessionKind.drill], 2)
        XCTAssertEqual(byKind[TrainingSessionKind.cognitive], 1)
        XCTAssertEqual(byKind[TrainingSessionKind.tool], 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }
}
