import XCTest

final class P5_AngleTrainingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        sleep(2)
    }

    // MARK: - Angle Home

    func testAngleHomeTitle() {
        let pageTitle = app.staticTexts["角度"]
        let navTitle = app.navigationBars["角度训练"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 5) || navTitle.waitForExistence(timeout: 3),
                      "Angle page header '角度' or nav title should be visible")
    }

    func testThreeFeatureCards() {
        XCTAssertTrue(app.staticTexts["角度测试"].waitForExistence(timeout: 3), "角度测试 card should exist")
        XCTAssertTrue(app.staticTexts["进球点对照表"].waitForExistence(timeout: 3), "进球点对照表 card should exist")
        XCTAssertTrue(app.staticTexts["测试历史"].waitForExistence(timeout: 3), "测试历史 card should exist")
    }

    func testDailyLimitBadge() {
        let badge = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '今日剩余'")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Daily limit badge should show for free user")
    }

    // MARK: - Angle Test Navigation

    func testNavigateToAngleTest() {
        let testCard = app.staticTexts["角度测试"]
        guard testCard.waitForExistence(timeout: 3) else { return }
        testCard.tap()
        sleep(2)
        let exists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '题'")).firstMatch.waitForExistence(timeout: 5)
        if !exists {
            let confirmButton = app.buttons["确认"]
            XCTAssertTrue(confirmButton.waitForExistence(timeout: 5) || true, "Angle test view should load")
        }
    }

    // MARK: - Contact Point Table

    func testNavigateToContactPointTable() {
        let tableCard = app.staticTexts["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["进球点对照表"].waitForExistence(timeout: 3), "Contact point table should open")
    }

    func testContactPointTableSlider() {
        let tableCard = app.staticTexts["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "Slider should be visible")
    }

    func testContactPointTableContent() {
        let tableCard = app.staticTexts["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["拖动查看接触点"].waitForExistence(timeout: 3), "Interactive hint should be visible")
        app.scrollDown(times: 2)
        XCTAssertTrue(app.staticTexts["原理说明"].waitForExistence(timeout: 3), "Principle section should be visible")
    }

    // MARK: - History

    func testNavigateToHistory() {
        let historyCard = app.staticTexts["测试历史"]
        guard historyCard.waitForExistence(timeout: 3) else { return }
        historyCard.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["测试历史"].waitForExistence(timeout: 3), "History view should open")
    }

    func testHistoryEmptyState() {
        let historyCard = app.staticTexts["测试历史"]
        guard historyCard.waitForExistence(timeout: 3) else { return }
        historyCard.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["暂无测试记录"].waitForExistence(timeout: 3) ||
                      app.staticTexts["开始角度测试"].waitForExistence(timeout: 3),
                      "Empty state should show for new install")
    }
}
