import XCTest

/// v49 W5：c076 / c077 / c078 详情与精讲的 Light / Dark 页面取证。
final class V49W5CopyEvidenceUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW5_Light_C076() { captureC076(suffix: "Light") }
    func testW5_Dark_C076() { captureC076(suffix: "Dark") }
    func testW5_Light_C076Detail() { captureDetail("drill_c076", "小角度带塞", "先练左侧中袋，再换左下角袋", "Light") }
    func testW5_Dark_C076Detail() { captureDetail("drill_c076", "小角度带塞", "先练左侧中袋，再换左下角袋", "Dark") }
    func testW5_Light_C077() { captureSingle("drill_c077", "中大角度带塞", "这五个摆位只练右塞", "Light") }
    func testW5_Dark_C077() { captureSingle("drill_c077", "中大角度带塞", "这五个摆位只练右塞", "Dark") }
    func testW5_Light_C077Detail() { captureDetail("drill_c077", "中大角度带塞", "半颗皮头右塞不变", "Light") }
    func testW5_Dark_C077Detail() { captureDetail("drill_c077", "中大角度带塞", "半颗皮头右塞不变", "Dark") }
    func testW5_Light_C078() { captureSingle("drill_c078", "远台带塞准度", "远台会放大很小的瞄准偏差", "Light") }
    func testW5_Dark_C078() { captureSingle("drill_c078", "远台带塞准度", "远台会放大很小的瞄准偏差", "Dark") }

    private func captureC076(suffix: String) {
        let app = openTutorial(drillId: "drill_c076", title: "小角度带塞", suffix: suffix)
        XCTAssertTrue(text(app, contains: "这一形把小角度和左右塞放在一起练").waitForExistence(timeout: 8))
        savePNG(app, "w5-drill_c076-tutorial-f1-\(suffix)")

        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(text(app, contains: "换成左下角袋后").waitForExistence(timeout: 8))
        savePNG(app, "w5-drill_c076-tutorial-f2-\(suffix)")
    }

    private func captureDetail(_ drillId: String, _ title: String, _ focus: String, _ suffix: String) {
        var args = ["-deeplink.drillDetail=\(drillId)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let focusText = text(app, contains: focus)
        if !focusText.waitForExistence(timeout: 4) {
            for _ in 0..<6 where !focusText.exists { app.swipeUp(); usleep(250_000) }
        }
        XCTAssertTrue(focusText.exists)
        savePNG(app, "w5-\(drillId)-detail-\(suffix)")
    }

    private func captureSingle(_ drillId: String, _ title: String, _ principle: String, _ suffix: String) {
        let app = openTutorial(drillId: drillId, title: title, suffix: suffix)
        XCTAssertTrue(text(app, contains: principle).waitForExistence(timeout: 8))
        savePNG(app, "w5-\(drillId)-tutorial-\(suffix)")
        for _ in 0..<7 { app.swipeUp(); usleep(250_000) }
        savePNG(app, "w5-\(drillId)-tutorial-later-\(suffix)")
    }

    private func openTutorial(drillId: String, title: String, suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(drillId)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let tutorial = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !tutorial.exists { app.swipeUp(); usleep(300_000) }
        XCTAssertTrue(tutorial.exists)
        tutorial.tap()
        XCTAssertTrue(app.staticTexts["技术原理"].waitForExistence(timeout: 15))
        return app
    }

    private func text(_ app: XCUIApplication, contains value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
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
            print("[V49-W5-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
