import XCTest

/// v25 W2：抽查配图命名修复后的精讲页。
///
/// 样例：免费 drill c001 / c023 / c024（均属 strip_still 修复集）。
/// 建议样例里的 c031 为 `isPremium=true`：锁态按 F-DD-04 **不露**「查看精讲」，
/// 无法验证精讲配图；本 class **不包含** c031 用例（改用同属修复集的免费 c024）。
/// 若需覆盖 Premium 锁态，应另立断言「无查看精讲 / 有解锁 Pro」的用例，而非 XCTSkip。
///
/// 截图落盘 `build/w2-screenshots/`（worktree 内绝对路径）。
/// 每个 drill 独立 test case，避免上一例 OOM 拖垮整组。
final class V25W2ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer-wt-v25-w2/build/w2-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW2_c001_tutorialImages() {
        captureTutorial(search: "半台", drillId: "drill_c001", label: "半台直线球")
    }

    func testW2_c023_tutorialImages() {
        captureTutorial(search: "五分点", drillId: "drill_c023", label: "五分点瞄准线练习")
    }

    func testW2_c024_tutorialImages() {
        captureTutorial(search: "分离角90", drillId: "drill_c024", label: "分离角90度规则")
    }

    private func captureTutorial(search: String, drillId: String, label: String) {
        app.switchTab(.drillLibrary)
        sleep(2)

        let allSidebar = app.descendants(matching: .any)["sidebar_全部"]
        if allSidebar.waitForExistence(timeout: 5) {
            allSidebar.tap()
            sleep(1)
        }

        let searchField = app.textFields["搜索动作"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "搜索框应存在")
        searchField.tap()
        if let value = searchField.value as? String, !value.isEmpty, value != "搜索动作" {
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 4)
            searchField.typeText(deletes)
        }
        searchField.typeText(search)
        sleep(2)

        let byId = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_\(drillId)'"))
            .firstMatch
        if byId.waitForExistence(timeout: 8) {
            byId.tap()
        } else {
            let byLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", label)
            ).firstMatch
            XCTAssertTrue(byLabel.waitForExistence(timeout: 6), "搜索「\(search)」应出现 \(label)")
            byLabel.tap()
        }
        sleep(3)
        savePNG("w2-\(drillId)-detail")

        // 滚到精讲入口（长详情页多滚几次）
        var opened = false
        for _ in 0..<6 {
            let tutorialBtn = app.buttons["查看精讲"]
            let tutorialText = app.staticTexts["查看精讲"]
            if tutorialBtn.exists {
                tutorialBtn.tap()
                opened = true
                break
            }
            if tutorialText.exists {
                tutorialText.tap()
                opened = true
                break
            }
            app.scrollDown(times: 1)
            usleep(600_000)
        }
        if !opened {
            XCTFail("\(drillId) 无「查看精讲」")
            return
        }

        // 等精讲节标题出现（比 waitForIdle 更稳，大图解码时 idle 可能超时）
        let principle = app.staticTexts["技术原理"]
        _ = principle.waitForExistence(timeout: 15)
        sleep(2)
        savePNG("w2-\(drillId)-tutorial-top")
        app.scrollDown(times: 1)
        sleep(1)
        savePNG("w2-\(drillId)-tutorial-scroll")
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let file = outDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: file)
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
