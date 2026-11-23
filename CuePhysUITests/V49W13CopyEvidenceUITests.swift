import XCTest

/// v49 W13：四球链与十二杆往返长页的 Light / Dark 取证。
final class V49W13CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW13_Light_C079() { captureTutorial("drill_c079", "四球走位", "前三杆都要借一库换边", "Light") }
    func testW13_Dark_C079() { captureTutorial("drill_c079", "四球走位", "前三杆都要借一库换边", "Dark") }
    func testW13_Light_C081Detail() { captureDetail("drill_c081", "四球同袋走位", "目标袋始终是左下角袋", "Light") }
    func testW13_Dark_C081Detail() { captureDetail("drill_c081", "四球同袋走位", "目标袋始终是左下角袋", "Dark") }
    func testW13_Light_C082() { captureTutorial("drill_c082", "横向蛇彩围 8", "这组不是沿着球排依次推进", "Light") }
    func testW13_Dark_C082() { captureTutorial("drill_c082", "横向蛇彩围 8", "这组不是沿着球排依次推进", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w13-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w13-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w13-\(id)-detail-\(suffix)")
    }

    private func launch(_ id: String, _ suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(id)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot(); let url = outDir.appendingPathComponent("\(name).png")
        do { try shot.pngRepresentation.write(to: url); print("[V49-W13-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
