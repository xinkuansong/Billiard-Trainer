import XCTest

/// v21 W4 截图：cueAction 列表（无 c019、有更新 R4）+ c018 详情 → `build/v21-w4-screenshots/`
final class V21W4ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v21-w4-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW4_cueActionListAndC018DetailScreenshots() {
        app.switchTab(.drillLibrary)
        sleep(2)

        let sidebar = app.descendants(matching: .any)["sidebar_杆法训练"]
        if sidebar.waitForExistence(timeout: 5) {
            sidebar.tap()
        } else {
            let cue = app.buttons.matching(NSPredicate(format: "label CONTAINS '杆法'")).firstMatch
            XCTAssertTrue(cue.waitForExistence(timeout: 5), "应能切到杆法分类")
            cue.tap()
        }
        sleep(2)
        savePNG("01-cueAction-list")

        // 确认无「右塞一库」（c019）
        let retired = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '右塞一库'")).firstMatch
        XCTAssertFalse(retired.waitForExistence(timeout: 2), "cueAction 列表不应再出现 c019「右塞一库」")

        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "搜索框应存在")
        search.tap()
        search.typeText("加塞一库")
        sleep(2)

        let listHit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '加塞一库变线'")
        ).firstMatch
        XCTAssertTrue(listHit.waitForExistence(timeout: 8), "搜索应出现更新后的 c018")
        savePNG("02-cueAction-search-c018")

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c018' OR label CONTAINS '加塞一库变线'"))
            .firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
        } else {
            listHit.tap()
        }
        sleep(2)
        savePNG("03-c018-detail")
    }

    func testW4_cueActionSearchC016Screenshot() {
        app.switchTab(.drillLibrary)
        sleep(2)

        let sidebar = app.descendants(matching: .any)["sidebar_杆法训练"]
        if sidebar.waitForExistence(timeout: 5) {
            sidebar.tap()
        } else {
            let cue = app.buttons.matching(NSPredicate(format: "label CONTAINS '杆法'")).firstMatch
            XCTAssertTrue(cue.waitForExistence(timeout: 5))
            cue.tap()
        }
        sleep(1)

        let search = app.textFields["搜索动作"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("斯登角度")
        sleep(2)

        let stun = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '斯登角度'")).firstMatch
        XCTAssertTrue(stun.waitForExistence(timeout: 8), "应能搜到 c016 斯登角度停球")
        savePNG("04-cueAction-search-c016")
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
