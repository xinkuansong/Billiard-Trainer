import XCTest

/// v21 W3 截图：准度分类列表新条目 / 详情 / 精讲分段 → `build/v21-w3-screenshots/`
final class V21W3ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v21-w3-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW3_accuracyListDetailTutorialScreenshots() {
        app.switchTab(.drillLibrary)
        sleep(2)

        let sidebar = app.descendants(matching: .any)["sidebar_准度"]
        if sidebar.waitForExistence(timeout: 5) {
            sidebar.tap()
        } else {
            let accuracy = app.buttons.matching(NSPredicate(format: "label CONTAINS '准度'")).firstMatch
            XCTAssertTrue(accuracy.waitForExistence(timeout: 5), "应能切到准度分类")
            accuracy.tap()
        }
        sleep(2)

        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "搜索框应存在")
        search.tap()
        search.typeText("带塞")
        sleep(2)

        let listHit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '小角度带塞' OR label CONTAINS '中大角度带塞' OR label CONTAINS '远台带塞'")
        ).firstMatch
        XCTAssertTrue(listHit.waitForExistence(timeout: 8), "搜索「带塞」应出现 c076/c077/c078")
        savePNG("01-accuracy-list-new-entries")

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c076' OR label CONTAINS '小角度带塞'"))
            .firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
        } else {
            listHit.tap()
        }
        sleep(2)
        savePNG("02-c076-detail")

        let tutorialTab = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '精讲' OR label CONTAINS '图文' OR label CONTAINS '讲解'")
        ).firstMatch
        if tutorialTab.waitForExistence(timeout: 4) {
            tutorialTab.tap()
            sleep(1)
        } else {
            let anyTutorial = app.staticTexts["精讲"].firstMatch
            if anyTutorial.waitForExistence(timeout: 2) {
                anyTutorial.tap()
                sleep(1)
            }
        }
        let segment = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'A2' OR label CONTAINS '反塞'")
        ).firstMatch
        if segment.waitForExistence(timeout: 3) {
            segment.tap()
            sleep(1)
        }
        savePNG("03-c076-tutorial-formations")
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
