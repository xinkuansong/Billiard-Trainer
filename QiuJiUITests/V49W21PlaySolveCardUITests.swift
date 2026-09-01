import XCTest

/// v49 W21：「打」「解」区 9 张正式卡的任务文案、单行布局与真实路由取证。
final class V49W21PlaySolveCardUITests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots")

    private let playCards: [(title: String, subtitle: String)] = [
        ("分离角与走位", "调打点力度看走位"),
        ("自由走位", "逐杆摆打推演走位"),
        ("自由击球", "从开球打一整局"),
        ("拍照建球形", "拍球局导入沙盘"),
    ]

    private let solveCards: [(title: String, subtitle: String)] = [
        ("思路训练", "定落点看塞与力度"),
        ("打一走二想三", "定三颗倒推第一杆"),
        ("防守", "选目标球求防守线"),
        ("翻袋解球器", "选袋求一至三库线"),
        ("反射解球器", "摆球求一至三库线"),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW21_Light_PlayGridCopy() { captureGrid(tab: "打", cards: playCards, scheme: "Light", stem: "play") }
    func testW21_Dark_PlayGridCopy() { captureGrid(tab: "打", cards: playCards, scheme: "Dark", stem: "play") }
    func testW21_Light_SolveGridCopy() { captureGrid(tab: "解", cards: solveCards, scheme: "Light", stem: "solve") }
    func testW21_Dark_SolveGridCopy() { captureGrid(tab: "解", cards: solveCards, scheme: "Dark", stem: "solve") }

    func testW21_AllProductionCardsOpenPromisedPage() {
        for (tab, cards) in [("打", playCards), ("解", solveCards)] {
            for card in cards {
                let app = launch(tab: tab, scheme: "Light")
                let button = findCard(card.title, in: app)
                XCTAssertTrue(button.exists, "\(card.title) 卡不可达")
                button.tap()
                XCTAssertTrue(app.navigationBars[card.title].waitForExistence(timeout: 10), "\(card.title) 路由错误")
                app.terminate()
            }
        }
    }

    private func captureGrid(tab: String, cards: [(title: String, subtitle: String)], scheme: String, stem: String) {
        let app = launch(tab: tab, scheme: scheme)
        for card in cards {
            XCTAssertTrue(findCard(card.title, in: app).exists, "缺少卡片：\(card.title)")
            XCTAssertTrue(findText(card.subtitle, in: app).exists, "副标题缺失或被截断：\(card.title)")
        }
        scrollToTop(in: app)
        save(app, "w21-\(stem)-grid-top-\(scheme)")
        for _ in 0..<4 { app.swipeUp(); usleep(150_000) }
        save(app, "w21-\(stem)-grid-bottom-\(scheme)")
    }

    private func launch(tab: String, scheme: String) -> XCUIApplication {
        var args = ["-forcePremium"]
        if scheme == "Light" { args.append("-v49.forceLight") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle)
        let tabButton = app.buttons["angleHomeTab_\(tab)"]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 8))
        tabButton.tap()
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
        do { try app.screenshot().pngRepresentation.write(to: url); print("[V49-W21-SCREENSHOT] \(url.path)") }
        catch { XCTFail("写截图失败 \(stem): \(error)") }
    }
}
