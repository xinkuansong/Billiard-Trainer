import XCTest

/// v49 W15：翻袋、K 球与贴库球的 Light / Dark 页面取证。
final class V49W15CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW15_Light_C054() { captureTutorial("drill_c054", "翻袋入底袋", "镜像方向可以帮你找到", "Light") }
    func testW15_Light_C055() { captureTutorial("drill_c055", "翻袋入中袋", "中袋翻袋的进球容错比底袋更大", "Light") }
    func testW15_Dark_C055Detail() { captureDetail("drill_c055", "翻袋入中袋", "中袋比底袋容错更大", "Dark") }
    func testW15_Dark_C056() { captureTutorial("drill_c056", "K球不吃库", "母球在打进 1 号后继续碰到 2 号", "Dark") }
    func testW15_Light_C057() { captureTutorial("drill_c057", "K球吃库", "母球随后按图示路线碰库", "Light") }
    func testW15_Dark_C057() { captureTutorial("drill_c057", "K球吃库", "母球随后按图示路线碰库", "Dark") }
    func testW15_Light_C058Detail() { captureDetail("drill_c058", "贴库球处理", "完全贴库时用高杆轻推", "Light") }
    func testW15_Dark_C058Detail() { captureDetail("drill_c058", "贴库球处理", "完全贴库时用高杆轻推", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w15-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w15-\(id)-tutorial-later-\(suffix)")
    }

    private func captureDetail(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let target = text(app, focus)
        for _ in 0..<6 where !target.exists { app.swipeUp(); usleep(200_000) }
        XCTAssertTrue(target.exists)
        save(app, "w15-\(id)-detail-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W15-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
