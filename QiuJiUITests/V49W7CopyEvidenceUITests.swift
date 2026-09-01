import XCTest

/// v49 W7：代表性的长/短精讲与详情页 Light / Dark 取证。
final class V49W7CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW7_Light_C003() { captureTutorial("drill_c003", "高杆跟进", "击打母球中心上方", "Light") }
    func testW7_Dark_C003() { captureTutorial("drill_c003", "高杆跟进", "击打母球中心上方", "Dark") }
    func testW7_Light_C016() { captureTutorial("drill_c016", "斯登母球控制", "两球距离固定", "Light") }
    func testW7_Dark_C016() { captureTutorial("drill_c016", "斯登母球控制", "两球距离固定", "Dark") }
    func testW7_Light_C017Detail() { captureDetail("drill_c017", "低杆远台缩回", "保持低杆打点", "Light") }
    func testW7_Dark_C017Detail() { captureDetail("drill_c017", "低杆远台缩回", "保持低杆打点", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w7-\(id)-tutorial-\(suffix)")
        for _ in 0..<3 { app.swipeUp(); usleep(200_000) }
        save(app, "w7-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w7-\(id)-detail-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W7-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
