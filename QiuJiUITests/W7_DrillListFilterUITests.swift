import XCTest

/// W7 E18–E20：动作库列表四态截图 + 角标菜单 + 角度首页无回归。
final class W7_DrillListFilterUITests: XCTestCase {

    var app: XCUIApplication!

    private var shotDir: URL {
        if let env = ProcessInfo.processInfo.environment["UI_POLISH_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let fileDir = (try? String(contentsOfFile: "/tmp/qiuji-uitest/shot_dir", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines), !fileDir.isEmpty {
            return URL(fileURLWithPath: fileDir, isDirectory: true)
        }
        return URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-wt-v25-w7/build/w7-screenshots",
                   isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW7_FourFilterStates() {
        app.switchTab(.drillLibrary)
        sleep(3)

        // R1: default fundamentals group — cover labels must differ across cards.
        snap("w7r2-s1-default")

        let levelBeginner = app.descendants(matching: .any)["levelFilter_入门"]
        XCTAssertTrue(levelBeginner.waitForExistence(timeout: 5), "E18 level chip 入门 should exist")
        levelBeginner.tap()
        sleep(1)
        snap("w7r2-s2-level-beginner")

        // Combined: 中式台球 × 准度训练 × 入门 × 新版精讲 (via filter Menu)
        let chinese = app.descendants(matching: .any)["ballType_中式台球"]
        if chinese.waitForExistence(timeout: 3) { chinese.tap() }
        sleep(1)

        let accuracy = app.descendants(matching: .any)["sidebar_准度训练"]
        if accuracy.waitForExistence(timeout: 3) { accuracy.tap() }
        sleep(1)

        let menu = app.descendants(matching: .any)["badgeFilterMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3), "R2 badge filter menu should exist")
        menu.tap()
        sleep(1)
        snap("w7r2-s5-badge-menu")

        let modern = app.buttons["新版精讲"].firstMatch
        if modern.waitForExistence(timeout: 3) {
            modern.tap()
        } else {
            app.menuItems["新版精讲"].tap()
        }
        sleep(1)
        snap("w7r2-s3-combined-filters")

        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("zzzzz_w7_empty")
        sleep(1)
        XCTAssertTrue(
            app.staticTexts["没有符合筛选的动作"].waitForExistence(timeout: 3)
                || app.staticTexts["没有找到相关动作"].waitForExistence(timeout: 2),
            "Empty state should appear under combined filters + nonsense search"
        )
        app.staticTexts["动作库"].firstMatch.tap()
        sleep(1)
        snap("w7r2-s4-empty")
    }

    func testW7_AngleHomeNoRegression() {
        app.switchTab(.angle)
        sleep(3)
        XCTAssertTrue(
            app.textFields["搜索练习"].waitForExistence(timeout: 5)
                || app.staticTexts["练习"].waitForExistence(timeout: 3),
            "Angle/Practice home should load"
        )
        snap("w7r2-s6-angle-home")
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let file = shotDir.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: file)
    }
}
