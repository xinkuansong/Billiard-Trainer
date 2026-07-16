import XCTest

/// v7 W3/C20：练习首页封面色迁移后 Light/Dark 截图取证。
/// 截图写入 `build/w3-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
///
/// 外观切换：不要在用例内反复设 `XCUIDevice.appearance`（易打崩 Runner / 不生效）。
/// 请事先 `xcrun simctl ui <udid> appearance light|dark`，再分别跑 light / dark 用例。
final class W3_HomeCoverUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w3-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 全新模拟器首启可能落在 Onboarding：先跳过再等 TabBar。
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func openPracticeHome(_ app: XCUIApplication) {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        let all = app.buttons["angleHomeTab_全部"]
        if all.waitForExistence(timeout: 4) {
            all.tap()
            usleep(600_000)
        }
    }

    private func snapHomeSeries(_ app: XCUIApplication, suffix: String) {
        openPracticeHome(app)
        snap(app, "w3-c20-01-home-all-\(suffix)")
        let learn = app.buttons["angleHomeTab_学"]
        if learn.waitForExistence(timeout: 3) {
            learn.tap(); usleep(600_000)
            snap(app, "w3-c20-02-home-learn-\(suffix)")
        }
        let train = app.buttons["angleHomeTab_练"]
        if train.waitForExistence(timeout: 3) {
            train.tap(); usleep(600_000)
            snap(app, "w3-c20-03-home-train-\(suffix)")
        }
    }

    func testW3HomeCoverLightScreenshots() throws {
        let app = XCUIApplication.launchClean()
        snapHomeSeries(app, suffix: "light")
    }

    func testW3HomeCoverDarkScreenshots() throws {
        let app = XCUIApplication.launchClean()
        snapHomeSeries(app, suffix: "dark")
    }
}
