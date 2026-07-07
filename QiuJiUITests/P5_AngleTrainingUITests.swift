import XCTest

/// 练习 Tab（原「角度」）首页与核心子页冒烟（学 / 练 / 打 / 解 分类侧栏 + 分组网格）。
final class P5_AngleTrainingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        sleep(2)
    }

    /// 分段 Tab 用 accessibilityIdentifier 精确定位（避免与底部 Tab 重名）。
    @discardableResult
    private func switchHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 3) else { return false }
        seg.tap()
        usleep(600_000)
        return true
    }

    // MARK: - Angle Home

    func testAngleHomeTitle() {
        let pageTitle = app.staticTexts["练习"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5),
                      "Practice page header '练习' should be visible")
    }

    func testFourSegmentTabs() {
        for name in ["学", "练", "打", "解"] {
            XCTAssertTrue(app.buttons["angleHomeTab_\(name)"].waitForExistence(timeout: 3),
                          "Segment tab '\(name)' should exist")
        }
    }

    func testSegmentCards() {
        // 学（默认分段）
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3), "瞄准原理 card should exist in 学")
        XCTAssertTrue(app.buttons["进球点对照表"].waitForExistence(timeout: 3), "进球点对照表 card should exist in 学")
        // 练
        XCTAssertTrue(switchHomeTab("练"), "Should switch to 练 segment")
        XCTAssertTrue(app.buttons["角度预测"].waitForExistence(timeout: 3), "角度预测 card should exist in 练")
        // 打
        XCTAssertTrue(switchHomeTab("打"), "Should switch to 打 segment")
        XCTAssertTrue(app.buttons["自由击球"].waitForExistence(timeout: 3), "自由击球 card should exist in 打")
        XCTAssertTrue(app.buttons["走位编排台"].waitForExistence(timeout: 3), "走位编排台 card should exist in 打")
        // 解
        XCTAssertTrue(switchHomeTab("解"), "Should switch to 解 segment")
        XCTAssertTrue(app.buttons["翻袋解球器"].waitForExistence(timeout: 3), "翻袋解球器 card should exist in 解")
        XCTAssertTrue(app.buttons["反射解球器"].waitForExistence(timeout: 3), "反射解球器 card should exist in 解")
    }

    // MARK: - Search

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSearchFiltersEntries() {
        let searchField = app.textFields["搜索练习"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        snap("search-idle")
        searchField.tap()
        searchField.typeText("翻袋")
        usleep(600_000)
        snap("search-filtered")
        XCTAssertTrue(app.buttons["翻袋解球器"].waitForExistence(timeout: 3),
                      "Matching card 翻袋解球器 should remain visible")
        XCTAssertFalse(app.buttons["瞄准原理"].exists,
                       "Non-matching card 瞄准原理 should be filtered out")

        // 清空按钮恢复全部
        let clearButton = app.buttons["xmark.circle.fill"].firstMatch
        if clearButton.exists { clearButton.tap() } else {
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        }
        usleep(600_000)
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3),
                      "Clearing search should restore all cards")
    }

    func testSearchEmptyState() {
        let searchField = app.textFields["搜索练习"]
        guard searchField.waitForExistence(timeout: 3) else { return }
        searchField.tap()
        searchField.typeText("zzz")
        usleep(600_000)
        snap("search-empty")
        XCTAssertTrue(app.staticTexts["没有找到相关练习"].waitForExistence(timeout: 3),
                      "Empty state should appear for no-match search")
        let browseAll = app.buttons["浏览全部练习"]
        XCTAssertTrue(browseAll.waitForExistence(timeout: 3), "Empty state action should exist")
        browseAll.tap()
        usleep(600_000)
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3),
                      "Tapping 浏览全部练习 should clear search and restore cards")
    }

    // MARK: - Contact Point Table（学）

    func testNavigateToContactPointTable() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["进球点对照表"].waitForExistence(timeout: 3), "Contact point table should open")
    }

    func testContactPointTableSlider() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "Slider should be visible")
    }

    func testContactPointTableContent() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["拖动查看瞄准点与接触点"].waitForExistence(timeout: 3), "Interactive hint should be visible")
        app.scrollDown(times: 2)
        XCTAssertTrue(app.staticTexts["原理说明"].waitForExistence(timeout: 3), "Principle section should be visible")
    }

    // MARK: - Geometric Quiz（练）

    func testNavigateToGeometricQuiz() {
        guard switchHomeTab("练") else { return }
        let quizCard = app.buttons["角度预测"]
        guard quizCard.waitForExistence(timeout: 3) else { return }
        quizCard.tap()
        sleep(2)
        // 几何角度训练页导航标题为「角度预测」（GeometricAngleQuizView）。
        XCTAssertTrue(app.navigationBars["角度预测"].waitForExistence(timeout: 5),
                      "Geometric quiz view should open")
    }

    // MARK: - Free Play（打，ADR-P18-01 直达编排台自由模式）

    func testNavigateToFreePlay() {
        guard switchHomeTab("打") else { return }
        let freePlayCard = app.buttons["自由击球"]
        guard freePlayCard.waitForExistence(timeout: 3) else { return }
        freePlayCard.tap()
        sleep(2)
        // 编排台默认名时标题显示页面名「走位编排台」（T-P18-37）。
        XCTAssertTrue(app.navigationBars["走位编排台"].waitForExistence(timeout: 5),
                      "Free play should open the composer in free aim mode")
    }
}
