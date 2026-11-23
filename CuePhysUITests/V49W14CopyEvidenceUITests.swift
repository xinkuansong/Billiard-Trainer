import XCTest

/// v49 W14：力度长页、往返标尺与综合路线的 Light / Dark 取证。
final class V49W14CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW14_Light_C047() { captureTutorial("drill_c047", "强力高杆", "纯高杆会让母球在碰撞后继续向前", "Light") }
    func testW14_Dark_C047() { captureTutorial("drill_c047", "强力高杆", "纯高杆会让母球在碰撞后继续向前", "Dark") }
    func testW14_Light_C049Detail() { captureDetail("drill_c049", "五档力度阶梯", "完整往返行程", "Light") }
    func testW14_Dark_C049Detail() { captureDetail("drill_c049", "五档力度阶梯", "完整往返行程", "Dark") }
    func testW14_Light_C051() { captureTutorial("drill_c051", "全力度走位综合", "这组不是单纯比较力量", "Light") }
    func testW14_Dark_C051() { captureTutorial("drill_c051", "全力度走位综合", "这组不是单纯比较力量", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w14-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w14-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w14-\(id)-detail-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W14-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
