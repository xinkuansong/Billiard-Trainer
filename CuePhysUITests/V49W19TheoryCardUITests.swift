import XCTest

/// v49 W19：「理」区 12 张卡的短提示、完整路由与大小屏取证。
final class V49W19TheoryCardUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    private let cards: [(title: String, subtitle: String)] = [
        ("30° 法则", "理解自然滚动的碰后方向与条件"),
        ("90° 法则", "理解斯登击球的直角分离条件"),
        ("切线法则", "用切线建立母球碰后路线参照"),
        ("母球速度分级", "建立力度参照，按球形校准"),
        ("最少加塞原则", "按路线需要选择合适塞量"),
        ("反向规划", "从收尾球倒推球序与落位"),
        ("关键球原理", "识别关键球，安排收尾衔接"),
        ("球团管理", "判断球团处理时机与后续衔接"),
        ("风险报酬决策矩阵", "权衡成功收益与失败代价"),
        ("安全球三维度模型", "从距离、库位与障碍分析防守"),
        ("清台 5 步决策流程", "串起观察、规划、执行与复盘"),
        ("清台速查手册", "快速查阅控球与清台判断要点"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW19_Light_TheoryGridCopy() { captureGrid("Light") }
    func testW19_Dark_TheoryGridCopy() { captureGrid("Dark") }

    func testW19_AllTheoryCardsOpenMatchingPage() {
        let app = launch("Light")
        for card in cards {
            let button = find(card.title, type: .button, in: app)
            XCTAssertTrue(button.exists, "\(card.title) 卡不可达")
            button.tap()
            XCTAssertTrue(app.navigationBars[card.title].waitForExistence(timeout: 8), "\(card.title) 路由错误")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["angleHomeTab_控球"].waitForExistence(timeout: 8))
        }
    }

    private func captureGrid(_ scheme: String) {
        let app = launch(scheme)
        for card in cards {
            let button = find(card.title, type: .button, in: app)
            XCTAssertTrue(button.exists, "缺少卡片：\(card.title)")
            XCTAssertTrue(button.label.contains(card.subtitle), "卡片短提示缺失：\(card.title)")
        }
        scrollToTop(in: app)
        save(app, "w19-theory-grid-top-\(scheme)")
        for _ in 0..<3 { app.swipeUp(); usleep(150_000) }
        save(app, "w19-theory-grid-middle-\(scheme)")
        for _ in 0..<4 { app.swipeUp(); usleep(150_000) }
        save(app, "w19-theory-grid-bottom-\(scheme)")
    }

    private func launch(_ scheme: String) -> XCUIApplication {
        var args = ["-forcePremium"]
        if scheme == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle)
        XCTAssertTrue(app.buttons["angleHomeTab_控球"].waitForExistence(timeout: 8))
        app.buttons["angleHomeTab_控球"].tap()
        return app
    }

    private func find(_ value: String, type: XCUIElement.ElementType, in app: XCUIApplication) -> XCUIElement {
        if type == .button { PracticeHomeNavigation.select(PracticeHomeNavigation.section(for: value), in: app) }
        let element = app.descendants(matching: type)[value]
        if element.waitForExistence(timeout: 2) { return element }
        for _ in 0..<8 where !element.exists { app.swipeUp(); usleep(150_000) }
        return element
    }

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<12 { app.swipeDown(); usleep(80_000) }
    }

    private func save(_ app: XCUIApplication, _ stem: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown-device"
        let url = outDir.appendingPathComponent("\(stem)-\(device).png")
        do { try app.screenshot().pngRepresentation.write(to: url); print("[V49-W19-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(stem): \(error)") }
    }
}
