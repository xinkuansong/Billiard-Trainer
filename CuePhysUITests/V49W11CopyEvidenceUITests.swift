import XCTest

/// v49 W11：走位基础详情和长教程 Light / Dark 取证。
final class V49W11CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW11_Light_C005() { captureTutorial("drill_c005", "一库走位", "一库走位先从下一杆倒推", "Light") }
    func testW11_Dark_C005() { captureTutorial("drill_c005", "一库走位", "一库走位先从下一杆倒推", "Dark") }
    func testW11_Light_C036() { captureTutorial("drill_c036", "低杆一库走位", "无塞低杆建立自然回撤线", "Light") }
    func testW11_Dark_C036() { captureTutorial("drill_c036", "低杆一库走位", "无塞低杆建立自然回撤线", "Dark") }
    func testW11_Light_C038Detail() { captureDetail("drill_c038", "两库走位", "先看目标区域", "Light") }
    func testW11_Dark_C038Detail() { captureDetail("drill_c038", "两库走位", "先看目标区域", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w11-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w11-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w11-\(id)-detail-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W11-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
