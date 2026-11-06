import XCTest

/// v49 W18：「学」区 9 张卡的文案、单行布局与真实路由取证。
final class V49W18PracticeCardUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    private let cards: [(title: String, subtitle: String, navTitle: String)] = [
        ("瞄准原理", "理解切角、厚薄与瞄准点的关系", "瞄准原理"),
        ("瞄准方法", "对比同一球形的三种瞄准方法", "瞄准方法"),
        ("瞄准修正", "观察力度与旋转造成的瞄准偏差", "瞄准修正"),
        ("旋转与加塞", "认识打点、旋转与母球走向", "旋转与加塞"),
        ("角度与瞄准", "拖动球形观察切角与瞄准方向", "角度与瞄准"),
        ("分离角图谱", "对比不同高低杆的母球路线", "分离角图谱"),
        ("加塞吃库图谱", "对比不同左右塞的母球吃库路线", "加塞吃库图谱"),
        ("浅谈凭感觉瞄准", "用参照和练习建立瞄准感觉", "浅谈凭感觉瞄准"),
        ("瞄准点对照表", "按切角查瞄准点与接触点", "瞄准点对照表"),
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
            XCTAssertTrue(app.buttons["angleHomeTab_基础"].waitForExistence(timeout: 8))
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
        save(app, "w18-learn-grid-top-\(scheme)")
        for _ in 0..<4 { app.swipeUp(); usleep(150_000) }
        save(app, "w18-learn-grid-bottom-\(scheme)")
    }

    private func launch(_ scheme: String) -> XCUIApplication {
        var args = ["-forcePremium"]
        if scheme == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle)
        XCTAssertTrue(app.buttons["angleHomeTab_基础"].waitForExistence(timeout: 8))
        app.buttons["angleHomeTab_基础"].tap()
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
        do { try app.screenshot().pngRepresentation.write(to: url); print("[V49-W18-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(stem): \(error)") }
    }
}
