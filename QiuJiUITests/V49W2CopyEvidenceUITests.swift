import XCTest

/// v49 W2：短课 c022 与长课 c023 的 Light / Dark 真机界面取证。
final class V49W2CopyEvidenceUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW2_Light_01_C022Detail() { captureDetail(drillId: "drill_c022", title: "直线推白球", focus: "只推母球，不进袋", suffix: "Light") }
    func testW2_Light_02_C022Tutorial() { captureTutorial(drillId: "drill_c022", title: "直线推白球", principle: "这项练习只看出杆线", suffix: "Light", bottomSwipes: 6) }
    func testW2_Light_03_C023Detail() { captureDetail(drillId: "drill_c023", title: "五分点", focus: "把袋口、8 号和母球摆成一条直线", suffix: "Light") }
    func testW2_Light_04_C023Tutorial() { captureTutorial(drillId: "drill_c023", title: "五分点", principle: "这条五分点线先看进球，再看停位", suffix: "Light", bottomSwipes: 5) }

    func testW2_Dark_01_C022Detail() { captureDetail(drillId: "drill_c022", title: "直线推白球", focus: "只推母球，不进袋", suffix: "Dark") }
    func testW2_Dark_02_C022Tutorial() { captureTutorial(drillId: "drill_c022", title: "直线推白球", principle: "这项练习只看出杆线", suffix: "Dark", bottomSwipes: 6) }
    func testW2_Dark_03_C023Detail() { captureDetail(drillId: "drill_c023", title: "五分点", focus: "把袋口、8 号和母球摆成一条直线", suffix: "Dark") }
    func testW2_Dark_04_C023Tutorial() { captureTutorial(drillId: "drill_c023", title: "五分点", principle: "这条五分点线先看进球，再看停位", suffix: "Dark", bottomSwipes: 5) }

    private func captureDetail(drillId: String, title: String, focus: String, suffix: String) {
        let app = launch(drillId: drillId, suffix: suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        XCTAssertTrue(scrollToTextContaining(app, focus), "\(drillId) 详情应显示本批描述")
        savePNG(app, "w2-\(drillId)-detail-\(suffix)")
    }

    private func captureTutorial(
        drillId: String,
        title: String,
        principle: String,
        suffix: String,
        bottomSwipes: Int
    ) {
        let app = launch(drillId: drillId, suffix: suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))

        let tutorial = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !tutorial.exists {
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(tutorial.exists, "\(drillId) 应有精讲入口")
        tutorial.tap()

        XCTAssertTrue(app.staticTexts["技术原理"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", principle)
            ).firstMatch.waitForExistence(timeout: 8),
            "\(drillId) 精讲应显示本轮技术原理"
        )
        savePNG(app, "w2-\(drillId)-tutorial-top-\(suffix)")

        for _ in 0..<bottomSwipes {
            app.swipeUp()
            usleep(250_000)
        }
        savePNG(app, "w2-\(drillId)-tutorial-later-\(suffix)")
    }

    private func scrollToTextContaining(_ app: XCUIApplication, _ text: String) -> Bool {
        let element = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", text)
        ).firstMatch
        if element.waitForExistence(timeout: 4) { return true }
        for _ in 0..<8 {
            app.swipeUp()
            usleep(300_000)
            if element.exists { return true }
        }
        return element.exists
    }

    private func launch(drillId: String, suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(drillId)"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func savePNG(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            print("[V49-W2-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
