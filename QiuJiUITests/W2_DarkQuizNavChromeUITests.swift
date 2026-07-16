import XCTest

/// v7 W2/C7：五个暗色测验页导航栏 dark chrome + 品牌绿 principal 截图取证。
/// 截图写入 `build/w2-screenshots/`（禁止覆盖 `docs/ui-polish/` 基线）。
final class W2_DarkQuizNavChromeUITests: XCTestCase {

    var app: XCUIApplication!

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w2-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openCard(homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 4) {
            card.tap()
        } else if app.staticTexts[title].waitForExistence(timeout: 2) {
            app.staticTexts[title].tap()
        } else {
            return false
        }
        sleep(2)
        return true
    }

    @discardableResult
    private func dismissAimingSettingsIfNeeded() -> Bool {
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            sleep(1)
            return true
        }
        return false
    }

    private func backToHome() {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 2) { back.tap(); sleep(1) }
    }

    func testDarkQuizNavChromeScreenshots() throws {
        // 1) 2D 角度训练（SceneAiming）
        guard openCard(homeTab: "练", title: "2D 角度训练") else {
            XCTFail("未能进入 2D 角度训练"); return
        }
        _ = dismissAimingSettingsIfNeeded()
        sleep(1)
        snap("w2-c7-01-scene-aiming-2d-nav")
        backToHome()

        // 2) 角度预测（Geometric）
        guard openCard(homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测"); return
        }
        snap("w2-c7-02-geometric-quiz-nav")
        backToHome()

        // 3) 角度与瞄准（AngleDynamic）— 学分段
        guard openCard(homeTab: "学", title: "角度与瞄准") else {
            XCTFail("未能进入角度与瞄准"); return
        }
        snap("w2-c7-03-angle-dynamic-nav")
        backToHome()

        // 4) 瞄准点训练
        guard openCard(homeTab: "练", title: "瞄准点训练") else {
            XCTFail("未能进入瞄准点训练"); return
        }
        snap("w2-c7-04-aimpoint-training-nav")
        backToHome()

        // 5) 2D 瞄准点训练（AimPointScene）
        guard openCard(homeTab: "练", title: "2D 瞄准点训练") else {
            XCTFail("未能进入 2D 瞄准点训练"); return
        }
        snap("w2-c7-05-aimpoint-scene-2d-nav")
    }
}
