import XCTest

/// v49 W20：「练」区 6 张卡的操作反馈文案、单行布局与真实路由取证。
final class V49W20TrainCardUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    private let cards: [(title: String, subtitle: String, navTitle: String)] = [
        ("角度预测", "看简图估切角，对照答案与误差", "角度预测"),
        ("2D 角度训练", "俯视瞄准看误差", "2D 角度训练"),
        ("3D 角度训练", "站位瞄准看误差", "3D 角度训练"),
        ("瞄准点训练", "根据切角摆准假想球位置", "瞄准点训练"),
        ("2D 瞄准点训练", "俯视调线击球验证", "2D 瞄准点训练"),
        ("3D 瞄准点训练", "站位调线击球验证", "3D 瞄准点训练"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW20_Light_TrainGridCopy() { captureGrid("Light") }
    func testW20_Dark_TrainGridCopy() { captureGrid("Dark") }

    func testW20_AllCardsOpenPromisedPage() {
        for card in cards {
            let app = launch("Light")
            let button = findCard(card.title, in: app)
            XCTAssertTrue(button.exists, "\(card.title) 卡不可达")
            button.tap()
            XCTAssertTrue(app.navigationBars[card.navTitle].waitForExistence(timeout: 8), "\(card.title) 路由错误")
            app.terminate()
        }
    }

    private func captureGrid(_ scheme: String) {
        let app = launch(scheme)
        for card in cards {
            let button = findCard(card.title, in: app)
            XCTAssertTrue(button.exists, "缺少卡片：\(card.title)")
            XCTAssertTrue(button.label.contains(card.subtitle), "卡片缺少已批准的副标题：\(card.title)")
        }
        scrollToTop(in: app)
        save(app, "w20-train-grid-top-\(scheme)")
        for _ in 0..<4 { app.swipeUp(); usleep(150_000) }
        save(app, "w20-train-grid-bottom-\(scheme)")
    }

    private func launch(_ scheme: String) -> XCUIApplication {
        var args = ["-forcePremium"]
        if scheme == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle)
        XCTAssertTrue(app.buttons["angleHomeTab_准度"].waitForExistence(timeout: 8))
        app.buttons["angleHomeTab_准度"].tap()
        return app
    }

    private func findCard(_ title: String, in app: XCUIApplication) -> XCUIElement {
        PracticeHomeNavigation.select(PracticeHomeNavigation.section(for: title), in: app)
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 2) { return card }
        for _ in 0..<6 where !card.exists { app.swipeUp(); usleep(160_000) }
        return card
    }


    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<10 { app.swipeDown(); usleep(100_000) }
    }

    private func save(_ app: XCUIApplication, _ stem: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown-device"
        let url = outDir.appendingPathComponent("\(stem)-\(device).png")
        do { try app.screenshot().pngRepresentation.write(to: url); print("[V49-W20-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(stem): \(error)") }
    }
}
