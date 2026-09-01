import XCTest

/// v49 W9：分离角长教程和详情页 Light / Dark 取证。
final class V49W9CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW9_Light_C024() { captureTutorial("drill_c024", "分离角90度规则", "碰撞瞬间接近无前后旋", "Light") }
    func testW9_Dark_C024() { captureTutorial("drill_c024", "分离角90度规则", "碰撞瞬间接近无前后旋", "Dark") }
    func testW9_Light_C026() { captureTutorial("drill_c026", "厚球分离角控制", "越接近正碰", "Light") }
    func testW9_Dark_C026() { captureTutorial("drill_c026", "厚球分离角控制", "越接近正碰", "Dark") }
    func testW9_Light_C028Detail() { captureDetail("drill_c028", "低杆扩大分离角", "先用中杆建立路线基准", "Light") }
    func testW9_Dark_C028Detail() { captureDetail("drill_c028", "低杆扩大分离角", "先用中杆建立路线基准", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w9-\(id)-tutorial-\(suffix)")
        for _ in 0..<3 { app.swipeUp(); usleep(200_000) }
        save(app, "w9-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w9-\(id)-detail-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W9-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
