import XCTest

/// 问题集合 v29 W6 的**真机 UI 取证**：在已播种「三种 kind + 已下架 drill」的库上
/// 打开记录页，证明
/// - 三种 kind 各自成行（drill / cognitive / tool），tool 行明示「工具使用」且不可点；
/// - 日历上只有 tool 的那天显示淡色活跃标记；
/// - 引用**已删除** drill 与球形的历史记录仍按快照正常显示（标准 5）。
///
/// 数据来源：`V29W6StoreSeedRunnerTests` 生成的 store 由 shell 拷进 App 容器。
/// 本用例只读不写，不依赖内容库里是否真的存在 `drill_deleted_999`（正是要它不存在）。
final class V29W6HistoryKindUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = repoRoot
            .appendingPathComponent("build", isDirectory: true)
            .appendingPathComponent("w6-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    /// 点日历格。日格是 `Button { VStack { Text(日) ; Text(标记) } }`，其 AX 标签会
    /// 把日期与标记拼在一起，按 identifier / 精确 label 都取不到，故按日期数字文案的
    /// 中心点坐标点击——坐标点击不要求元素 hittable，穿透到底层按钮。
    private func tapCalendarDay(_ day: Int) {
        let text = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "\(day)")
        ).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 8), "日历上应有 \(day) 号")
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func test_historyPage_showsThreeKindsAndSnapshotNames() throws {
        app.switchTab(.history)
        sleep(3)
        snap("10-history-today")

        // 今天：drill（快照名「半台直线球 等 3 项」）+ cognitive「角度预测」+ tool「自由击球」
        XCTAssertTrue(app.staticTexts["半台直线球 等 3 项"].waitForExistence(timeout: 10),
                      "drill 行标题应取 drillNameZh 快照")
        XCTAssertTrue(app.staticTexts["角度预测"].exists, "cognitive 行应取 note 快照名")
        XCTAssertTrue(app.staticTexts["自由击球"].exists, "tool 行应取 note 快照名")
        XCTAssertTrue(app.staticTexts["工具使用"].exists, "tool 行须明示不是训练成绩")
    }

    /// 标准 5：昨天那条记录引用的 drill 已从内容库下架，历史仍按快照显示。
    func test_historyPage_deletedDrillStillRendersFromSnapshot() throws {
        app.switchTab(.history)
        sleep(3)

        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        tapCalendarDay(cal.component(.day, from: yesterday))
        sleep(2)
        snap("11-history-yesterday-deleted-drill")

        XCTAssertTrue(app.staticTexts["已下架的老球形练习"].waitForExistence(timeout: 8),
                      "内容库里已无该 drill，但历史仍按 drillNameZh 快照显示")
    }

    /// 只有工具使用的那天：日历淡色标记 + 当天列表有 tool 行（不出现「当天无训练记录」）。
    func test_historyPage_toolOnlyDay_showsActivityMarkerAndRow() throws {
        app.switchTab(.history)
        sleep(3)

        let cal = Calendar.current
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        tapCalendarDay(cal.component(.day, from: twoDaysAgo))
        sleep(2)
        snap("12-history-tool-only-day")

        XCTAssertTrue(app.staticTexts["打一走二想三"].waitForExistence(timeout: 8),
                      "只有工具使用的那天也该有一行，避免日历有标记点开却说无记录")
        XCTAssertFalse(app.staticTexts["当天无训练记录"].exists)
    }

    /// 统计页：分类成功率卡在 Pro 门控下会被 blur，这里只取「布局与认知练习区分开展示」的证。
    func test_statisticsTab_layout() throws {
        app.switchTab(.history)
        sleep(2)
        let statsTab = app.buttons["统计"].firstMatch
        if statsTab.waitForExistence(timeout: 6) {
            statsTab.tap()
        }
        sleep(3)
        snap("20-statistics-free-tier")
        XCTAssertTrue(app.staticTexts["角度训练"].waitForExistence(timeout: 10),
                      "cognitive 成绩在「角度训练」区单独展示（与 drill 分开）")
    }
}
