import XCTest

/// W2-10 改后截图采集（本批验收用）。
final class W210ScreenshotUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-w2-10/docs/ui-polish/screenshots-w2-10",
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
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        return false
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let id = "angleHomeTab_\(name)"
        let tab = app.buttons[id]
        if tab.waitForExistence(timeout: 4) {
            tab.tap()
            return true
        }
        return false
    }

    func testW210AfterScreenshots() throws {
        XCTAssertTrue(tapLabel("练习"), "应能进入练习 Tab")
        sleep(1)
        snap("after-angle-home")

        // SceneAiming 2D
        switchAngleHomeTab("练")
        sleep(1)
        if tapLabel("2D 角度训练", timeout: 4) {
            sleep(1)
            if app.buttons["开始训练"].waitForExistence(timeout: 4) {
                app.buttons["开始训练"].tap()
                sleep(2)
            }
            snap("after-scene-aiming-2d")
            if app.navigationBars.buttons.element(boundBy: 0).exists {
                app.navigationBars.buttons.element(boundBy: 0).tap()
                sleep(1)
            }
        }

        // 历史 / 统计
        XCTAssertTrue(tapLabel("记录"), "应能进入记录 Tab")
        sleep(1)
        snap("after-history-calendar")
        if tapLabel("统计", timeout: 3) {
            sleep(2)
            snap("after-statistics")
        }

        // 拍照建球形（批量台 simulator-only；用生产建球形页作 chrome 代表）
        _ = tapLabel("练习")
        sleep(1)
        switchAngleHomeTab("打")
        sleep(1)
        if tapLabel("拍照建球形", timeout: 4) {
            sleep(2)
            snap("after-ball-extraction")
        }
    }
}
