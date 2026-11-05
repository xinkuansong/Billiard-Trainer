import XCTest

/// v49 W16：长 K 球页、防守页与规则流程页的 Light / Dark 取证。
final class V49W16CopyEvidenceUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW16_Light_C060() { captureTutorial("drill_c060", "防守", "防守不是把球打得越远越好", "Light") }
    func testW16_Dark_C085() { captureTutorial("drill_c085", "K球综合挑战", "前九杆依次 K 1–9 号", "Dark") }
    func testW16_Light_C085() { captureTutorial("drill_c085", "K球综合挑战", "前九杆依次 K 1–9 号", "Light") }
    func testW16_Dark_C064() { captureTutorial("drill_c064", "三球连打", "先从 3 号倒推", "Dark") }
    func testW16_Light_C065() { captureTutorial("drill_c065", "Ghost Game 单人练习", "把对手设定为不会失误", "Light") }
    func testW16_Dark_C070() { captureTutorial("drill_c070", "中八全台清台挑战", "自定义顺序", "Dark") }

    private func captureTutorial(_ id: String, _ title: String, _ focus: String, _ suffix: String) {
        let app = launch(id, suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        let button = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !button.exists { app.swipeUp(); usleep(250_000) }
        XCTAssertTrue(button.exists); button.tap()
        XCTAssertTrue(text(app, focus).waitForExistence(timeout: 12))
        save(app, "w16-\(id)-tutorial-\(suffix)")
        for _ in 0..<4 { app.swipeUp(); usleep(200_000) }
        save(app, "w16-\(id)-tutorial-later-\(suffix)")
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
        do { try shot.pngRepresentation.write(to: url); print("[V49-W16-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(name): \(error)") }
    }
}
