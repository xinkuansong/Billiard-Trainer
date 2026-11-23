import XCTest

/// v21 W2 截图：杆法分类列表新条目 / 详情 / 精讲分段 → `build/v21-w2-screenshots/`
final class V21W2ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v21-w2-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW2_cueActionListDetailTutorialScreenshots() {
        app.switchTab(.drillLibrary)
        sleep(2)

        // 侧栏 → 杆法训练
        let sidebar = app.descendants(matching: .any)["sidebar_杆法"]
        if sidebar.waitForExistence(timeout: 5) {
            sidebar.tap()
        } else {
            let cue = app.buttons.matching(NSPredicate(format: "label CONTAINS '杆法'")).firstMatch
            XCTAssertTrue(cue.waitForExistence(timeout: 5), "应能切到杆法分类")
            cue.tap()
        }
        sleep(2)

        // 搜索露出新条目（Lazy 网格滚底不可靠）
        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "搜索框应存在")
        search.tap()
        search.typeText("挤偏")
        sleep(2)

        let listHit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '挤偏认知' OR label CONTAINS '挤偏放大'")
        ).firstMatch
        XCTAssertTrue(listHit.waitForExistence(timeout: 8), "搜索「挤偏」应出现 c073/c074")
        savePNG("01-cueAction-list-new-entries")

        // 进 c073 详情（免费钩子）
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c073' OR label CONTAINS '挤偏认知'"))
            .firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
        } else {
            listHit.tap()
        }
        sleep(2)
        savePNG("02-c073-detail")

        // 精讲 / formations 分段
        let tutorialTab = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '精讲' OR label CONTAINS '图文' OR label CONTAINS '讲解'")
        ).firstMatch
        if tutorialTab.waitForExistence(timeout: 4) {
            tutorialTab.tap()
            sleep(1)
        } else {
            // 详情页可能有「精讲」入口为其他控件
            let anyTutorial = app.staticTexts["精讲"].firstMatch
            if anyTutorial.waitForExistence(timeout: 2) {
                anyTutorial.tap()
                sleep(1)
            }
        }
        let segment = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'A2' OR label CONTAINS '右塞'")
        ).firstMatch
        if segment.waitForExistence(timeout: 3) {
            segment.tap()
            sleep(1)
        }
        savePNG("03-c073-tutorial-formations")
    }

    private func savePNG(_ name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        let data = shot.pngRepresentation
        try? data.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
