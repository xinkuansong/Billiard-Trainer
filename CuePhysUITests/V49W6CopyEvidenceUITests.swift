import XCTest

/// v49 W6：c073 / c074 / c075 详情与精讲的 Light / Dark 页面取证。
final class V49W6CopyEvidenceUITests: XCTestCase {

    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW6_Light_C073() { captureTutorial("drill_c073", "挤偏认知·直球近台", "杆头离开母球中心后", "Light") }
    func testW6_Dark_C073() { captureTutorial("drill_c073", "挤偏认知·直球近台", "杆头离开母球中心后", "Dark") }
    func testW6_Light_C074() { captureC074("Light") }
    func testW6_Dark_C074() { captureC074("Dark") }
    func testW6_Light_C075() { captureTutorial("drill_c075", "塞量阶梯", "第一组固定球形", "Light") }
    func testW6_Dark_C075() { captureTutorial("drill_c075", "塞量阶梯", "第一组固定球形", "Dark") }
    func testW6_Light_C073Detail() { captureDetail("drill_c073", "挤偏认知·直球近台", "先用母球直入角袋", "Light") }
    func testW6_Dark_C075Detail() { captureDetail("drill_c075", "塞量阶梯", "观察碰库后的路线", "Dark") }

    private func captureC074(_ suffix: String) {
        let app = openTutorial("drill_c074", "挤偏放大·直球长台", suffix)
        XCTAssertTrue(text(app, contains: "母球起始路线只偏一点").waitForExistence(timeout: 8))
        savePNG(app, "w6-drill_c074-tutorial-f1-\(suffix)")
        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8))
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(text(app, contains: "远台加塞五分点").waitForExistence(timeout: 8))
        savePNG(app, "w6-drill_c074-tutorial-f2-\(suffix)")
    }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = openTutorial(id, title, suffix)
        XCTAssertTrue(text(app, contains: focus).waitForExistence(timeout: 8))
        savePNG(app, "w6-\(id)-tutorial-\(suffix)")
        for _ in 0..<7 { app.swipeUp(); usleep(250_000) }
        savePNG(app, "w6-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        var args = ["-deeplink.drillDetail=\(id)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, contains: focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(target.exists)
        savePNG(app, "w6-\(id)-detail-\(suffix)")
    }

    private func openTutorial(_ id: String, _ title: String, _ suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(id)", "-forcePremium"]
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
            print("[V49-W6-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
