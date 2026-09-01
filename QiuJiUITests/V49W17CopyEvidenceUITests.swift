import XCTest

/// v49 W17：中级 / 高级蛇彩长教程的 Light / Dark 取证。
final class V49W17CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW17_Light_C069() { captureTutorial("drill_c069", "中级蛇彩", "8 杆彼此独立", "Light") }
    func testW17_Dark_C069() { captureTutorial("drill_c069", "中级蛇彩", "8 杆彼此独立", "Dark") }
    func testW17_Light_C071() { captureTutorial("drill_c071", "高级蛇彩", "低杆离库", "Light") }
    func testW17_Dark_C071() { captureTutorial("drill_c071", "高级蛇彩", "低杆离库", "Dark") }
    func testW17_Light_C071_LongPage() { captureTutorial("drill_c071", "高级蛇彩", "第 12 杆再回右侧中袋", "Light", formation: "十五球满台蛇彩") }
    func testW17_Dark_C071_LongPage() { captureTutorial("drill_c071", "高级蛇彩", "第 12 杆再回右侧中袋", "Dark", formation: "十五球满台蛇彩") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String, formation: String? = nil) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        if let formation {
            let picker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", formation)).firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 12)); picker.tap()
        }
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w17-\(id)-tutorial-\(suffix)-\(sanitized(focus))")
        for _ in 0..<6 { app.swipeUp(); usleep(200_000) }
        save(app, "w17-\(id)-tutorial-later-\(suffix)-\(sanitized(focus))")
    }

    private func launch(_ id: String, _ suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(id)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func text(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    private func sanitized(_ value: String) -> String {
        value.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "/", with: "-")
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot(); let url = outDir.appendingPathComponent("\(name).png")
        do { try shot.pngRepresentation.write(to: url); print("[V49-W17-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
