import XCTest

/// v49 W18：「学」区 9 张卡的文案、单行布局与真实路由取证。
final class V49W18PracticeCardUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    private let cards: [(title: String, subtitle: String, navTitle: String)] = [
        ("瞄准原理", "从切球角找瞄准点", "瞄准原理"),
        ("瞄准方法", "三种方法找瞄准点", "瞄准方法"),
        ("瞄准修正", "补偿投掷与加塞", "瞄准修正"),
        ("旋转与加塞", "预判旋转后路线", "旋转与加塞"),
        ("角度与瞄准", "拖球看瞄准点变化", "角度与瞄准"),
        ("分离角图谱", "看高低杆碰后方向", "分离角图谱"),
        ("加塞吃库图谱", "换塞侧看出库方向", "加塞吃库图谱"),
        ("浅谈球感", "用误差练出直觉", "浅谈球感"),
        ("瞄准点对照表", "按切球角查瞄准点", "瞄准点对照表"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW18_Light_LearnGridCopy() { captureGrid("Light") }
    func testW18_Dark_LearnGridCopy() { captureGrid("Dark") }

    func testW18_AllCardsOpenPromisedPage() {
        let app = launch("Light")
        for card in cards {
            let button = findCard(card.title, in: app)
            XCTAssertTrue(button.exists, "\(card.title) 卡不可达")
            button.tap()
            XCTAssertTrue(app.navigationBars[card.navTitle].waitForExistence(timeout: 8), "\(card.title) 路由错误")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["angleHomeTab_学"].waitForExistence(timeout: 8))
        }
    }

    private func captureGrid(_ scheme: String) {
        let app = launch(scheme)
        for card in cards {
            XCTAssertTrue(findCard(card.title, in: app).exists, "缺少卡片：\(card.title)")
            XCTAssertTrue(findText(card.subtitle, in: app).exists, "副标题缺失或被截断：\(card.title)")
        }
        scrollToTop(in: app)
        save(app, "w18-learn-grid-top-\(scheme)")
        for _ in 0..<4 { app.swipeUp(); usleep(150_000) }
        save(app, "w18-learn-grid-bottom-\(scheme)")
    }

    private func launch(_ scheme: String) -> XCUIApplication {
        var args = ["-forcePremium"]
        if scheme == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle)
        XCTAssertTrue(app.buttons["angleHomeTab_学"].waitForExistence(timeout: 8))
        app.buttons["angleHomeTab_学"].tap()
        return app
    }

    private func findCard(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 2) { return card }
        for _ in 0..<6 where !card.exists { app.swipeUp(); usleep(160_000) }
        return card
    }

    private func findText(_ value: String, in app: XCUIApplication) -> XCUIElement {
        let text = app.staticTexts[value]
        if text.waitForExistence(timeout: 2) { return text }
        for _ in 0..<6 where !text.exists { app.swipeUp(); usleep(160_000) }
        return text
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<10 { app.swipeDown(); usleep(100_000) }
    }

    private func save(_ app: XCUIApplication, _ stem: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown-device"
        let url = outDir.appendingPathComponent("\(stem)-\(device).png")
        do { try app.screenshot().pngRepresentation.write(to: url); print("[V49-W18-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(stem): \(error)") }
    }
}
