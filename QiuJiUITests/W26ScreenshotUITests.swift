import XCTest

/// W2-6 改后截图采集（训练首页 / 会话 / 记分 / 休息覆层）。
final class W26ScreenshotUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-w2-6/docs/ui-polish/screenshots-w2-6/after",
            isDirectory: true)
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapIfExists(_ label: String, timeout: TimeInterval = 4) -> Bool {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        let text = app.staticTexts[label]
        if text.waitForExistence(timeout: 1), text.isHittable {
            text.tap()
            return true
        }
        return false
    }

    func testW26AfterScreenshots() throws {
        app.switchTab(.training)
        sleep(2)
        snap("01-training-home")

        if tapIfExists("我的计划", timeout: 3) {
            sleep(1)
            snap("02-training-my-plans")
        }

        // Free-record entry (no activated plan required)
        XCTAssertTrue(tapIfExists("自由记录", timeout: 6), "应能进入自由记录")
        sleep(2)
        snap("03-active-session-empty")

        // Add a drill so score card / rest chrome can appear
        XCTAssertTrue(tapIfExists("选择训练项目", timeout: 4), "应打开 DrillPicker")
        sleep(2)
        snap("03b-drill-picker")

        // Prefer named drill; fall back to first cell center tap
        let named = app.staticTexts["握杆稳定性练习"]
        if named.waitForExistence(timeout: 5) {
            named.tap()
        } else {
            let cell = app.cells.firstMatch
            XCTAssertTrue(cell.waitForExistence(timeout: 5), "picker 应有列表行")
            cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        sleep(1)
        snap("03c-drill-picker-added")

        // Prefer 完成(N); plain 完成 also dismisses
        let doneCounted = app.buttons["完成(1)"]
        if doneCounted.waitForExistence(timeout: 2) {
            doneCounted.tap()
        } else {
            let done = app.navigationBars.buttons.matching(NSPredicate(format: "label BEGINSWITH '完成'")).firstMatch
            XCTAssertTrue(done.waitForExistence(timeout: 3), "应出现完成按钮")
            done.tap()
        }
        sleep(2)
        snap("04-score-card")

        let complete = app.buttons["标记完成"].firstMatch
        if complete.waitForExistence(timeout: 5) {
            complete.tap()
            sleep(1)
            if app.buttons["完成休息"].waitForExistence(timeout: 4)
                || app.staticTexts["组间休息"].waitForExistence(timeout: 2) {
                snap("05-rest-overlay")
            }
        } else if tapIfExists("休息设置", timeout: 2) {
            sleep(1)
            snap("05-rest-overlay")
        }

        // Dismiss rest overlay so bottom chrome (minimize) is hittable
        if app.buttons["完成休息"].waitForExistence(timeout: 2) {
            app.buttons["完成休息"].tap()
            sleep(1)
        }

        let minimize = app.buttons["最小化训练"]
        if minimize.waitForExistence(timeout: 4) {
            minimize.tap()
            sleep(1)
            snap("06-continue-bar-home")
        }
    }
}
