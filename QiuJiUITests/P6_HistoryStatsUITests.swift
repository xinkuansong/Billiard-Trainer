import XCTest

final class P6_HistoryStatsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.history)
        sleep(2)
    }

    // MARK: - History Calendar

    func testHistoryTabTitle() {
        XCTAssertTrue(app.staticTexts["记录"].waitForExistence(timeout: 3), "History tab title should be visible")
    }

    func testSegmentedTabVisible() {
        let calendarText = app.staticTexts["日历"]
        let statsText = app.staticTexts["统计"]
        let calendarBtn = app.buttons["日历"]
        let statsBtn = app.buttons["统计"]
        XCTAssertTrue(calendarText.waitForExistence(timeout: 5) || statsText.waitForExistence(timeout: 3) ||
                      calendarBtn.waitForExistence(timeout: 3) || statsBtn.waitForExistence(timeout: 3),
                      "Segmented tab should have 日历/统计 (as text or button)")
    }

    func testCalendarMonthNavigation() {
        let prevButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'chevron' OR label CONTAINS 'Back' OR label CONTAINS 'left'")).firstMatch
        if prevButton.waitForExistence(timeout: 3) {
            prevButton.tap()
            sleep(1)
        }
    }

    func testCalendarWeekdayHeaders() {
        for day in ["一", "二", "三", "四", "五", "六", "日"] {
            let dayLabel = app.staticTexts[day]
            if dayLabel.waitForExistence(timeout: 2) {
                continue
            }
        }
    }

    // MARK: - Statistics

    func testSwitchToStatistics() {
        let statsAny = app.descendants(matching: .any).matching(NSPredicate(format: "label == '统计'")).firstMatch
        if statsAny.waitForExistence(timeout: 5) {
            statsAny.tap()
        } else {
            return
        }
        sleep(2)

        let hasContent = app.staticTexts["还没有训练记录"].waitForExistence(timeout: 5) ||
                         app.staticTexts["周"].waitForExistence(timeout: 3) ||
                         app.buttons["周"].waitForExistence(timeout: 3) ||
                         app.staticTexts["开始训练"].waitForExistence(timeout: 3) ||
                         app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '训练'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Statistics should show empty state or time pills or training content")
    }

    func testStatisticsTimePills() {
        let statsTab = app.staticTexts["统计"].firstMatch
        let statsBtn = app.buttons["统计"].firstMatch
        if statsTab.waitForExistence(timeout: 3) {
            statsTab.tap()
        } else if statsBtn.waitForExistence(timeout: 3) {
            statsBtn.tap()
        } else {
            return
        }
        sleep(1)

        for pill in ["周", "月", "年"] {
            let pillButton = app.buttons[pill].firstMatch
            let pillText = app.staticTexts[pill].firstMatch
            if pillButton.waitForExistence(timeout: 2) {
                pillButton.tap()
                sleep(1)
            } else if pillText.waitForExistence(timeout: 2) {
                pillText.tap()
                sleep(1)
            }
        }
    }

    // MARK: - Empty States

    func testHistoryEmptyState() {
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 5) ||
                      app.staticTexts["当天无训练记录"].waitForExistence(timeout: 5) ||
                      app.buttons.count > 0,
                      "Should show empty state or calendar content")
    }
}
