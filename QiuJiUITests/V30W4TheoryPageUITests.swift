import XCTest

/// v30 W4：流程与速查两篇（清台 5 步决策流程 / 清台速查手册）上线可点 + 页内说明图 +
/// Light/Dark 截图 + 索引页 12 条全部可进入 + 速查表逐条深链可达。
///
/// 配图取证走 `captureTheoryFigure`（X-v30-9 修复口径：滚到图完整可见 → 断言 frame
/// 落在可视区内 → 直接截该元素）。外观切换：事先
/// `xcrun simctl ui booted appearance light|dark`。截图落盘 `build/v30-w4-screenshots/`。
final class V30W4TheoryPageUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w4-screenshots"
    )

    /// 索引页 12 条：id → 页名（与 `TheoryCatalog.entries` 逐字一致）。
    private let pageTitles: [(id: String, title: String)] = [
        ("t01", "30° 法则"),
        ("t02", "90° 法则"),
        ("t03", "切线法则"),
        ("t04", "母球速度分级"),
        ("t09", "最少加塞原则"),
        ("t05", "反向规划"),
        ("t06", "关键球原理"),
        ("t07", "球团管理"),
        ("t08", "风险报酬决策矩阵"),
        ("t10", "安全球三维度模型"),
        ("flow", "清台 5 步决策流程"),
        ("quickRef", "清台速查手册"),
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    // MARK: - 两篇页面 + 配图（Light / Dark）

    func testV30W4_TheoryPagesLight() {
        openIndex()
        capturePage(pageID: "flow", title: "清台 5 步决策流程", suffix: "Light",
                    figureIdentifiers: ["theoryFlow.stepsFigure", "theoryFlow.timeFigure"])
        capturePage(pageID: "quickRef", title: "清台速查手册", suffix: "Light",
                    figureIdentifiers: ["theoryQuickRef.routeFigure"])
        saveTheoryPNG(app.screenshot(), name: "theory-index-12published-Light", outDir: outDir)
    }

    func testV30W4_TheoryPagesDark() {
        openIndex()
        capturePage(pageID: "flow", title: "清台 5 步决策流程", suffix: "Dark",
                    figureIdentifiers: ["theoryFlow.stepsFigure", "theoryFlow.timeFigure"])
        capturePage(pageID: "quickRef", title: "清台速查手册", suffix: "Dark",
                    figureIdentifiers: ["theoryQuickRef.routeFigure"])
        saveTheoryPNG(app.screenshot(), name: "theory-index-12published-Dark", outDir: outDir)
    }

    // MARK: - 索引页 12 条全部可进入（完成标准 e）

    func testV30W4_AllTwelveIndexEntriesOpen() {
        openIndex()
        saveTheoryPNG(app.screenshot(), name: "theory-index-entries-top", outDir: outDir)

        for page in pageTitles {
            let row = app.descendants(matching: .any)["theoryEntry_\(page.id)"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 6), "\(page.id) 应是索引页上的可点条目")
            scrollToHittable(row)
            row.tap()
            XCTAssertTrue(
                app.navigationBars[page.title].waitForExistence(timeout: 8),
                "\(page.id) 应进入「\(page.title)」详情页"
            )
            app.navigationBars[page.title].buttons.firstMatch.tap()
            XCTAssertTrue(
                app.navigationBars["球理"].waitForExistence(timeout: 6),
                "从 \(page.id) 返回后应回到球理索引页"
            )
        }
        saveTheoryPNG(app.screenshot(), name: "theory-index-entries-after-all", outDir: outDir)
    }

    // MARK: - 速查表逐条深链可达（完成标准 f）

    func testV30W4_QuickRefDeepLinksAllReachable() {
        openIndex()
        openPage(id: "quickRef", title: "清台速查手册")

        // 速查表上的 11 条深链（除本页外的 11 篇），逐条点开 → 校验页名 → 返回。
        let linked = pageTitles.filter { $0.id != "quickRef" }
        for target in linked {
            let link = app.descendants(matching: .any)["quickRefLink_\(target.id)"].firstMatch
            XCTAssertTrue(
                link.waitForExistence(timeout: 8),
                "速查表应有指向「\(target.title)」的深链条目"
            )
            scrollToHittable(link)
            link.tap()
            XCTAssertTrue(
                app.navigationBars[target.title].waitForExistence(timeout: 8),
                "速查表深链 \(target.id) 应进入「\(target.title)」"
            )
            saveTheoryPNG(
                app.screenshot(),
                name: "quickref-deeplink-\(target.id)",
                outDir: outDir
            )
            app.navigationBars[target.title].buttons.firstMatch.tap()
            XCTAssertTrue(
                app.navigationBars["清台速查手册"].waitForExistence(timeout: 8),
                "从 \(target.id) 返回后应回到速查手册"
            )
        }
    }

    // MARK: - Steps

    private func openIndex() {
        app.switchTab(.angle)

        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10), "练习 Tab「学」侧栏应出现")
        learn.tap()

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "球理"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 6), "「学」分组应有球理入口卡")
        card.tap()

        XCTAssertTrue(
            app.navigationBars["球理"].waitForExistence(timeout: 6),
            "入口卡应 push 到球理索引页"
        )
    }

    private func openPage(id: String, title: String) {
        let row = app.descendants(matching: .any)["theoryEntry_\(id)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 6), "\(id) 应是索引页上的可点条目")
        scrollToHittable(row)
        row.tap()
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 8),
            "\(id) 详情页导航标题应为「\(title)」"
        )
    }

    private func scrollToHittable(_ element: XCUIElement, maxSwipes: Int = 8) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
            usleep(400_000)
        }
    }

    private func capturePage(pageID: String, title: String, suffix: String,
                             figureIdentifiers: [String]) {
        openPage(id: pageID, title: title)
        sleep(2)

        let topData = saveTheoryPNG(
            app.screenshot(), name: "theory-\(pageID)-top-\(suffix)", outDir: outDir
        )

        for identifier in figureIdentifiers {
            let stem = identifier.replacingOccurrences(of: ".", with: "-")
            let figureData = captureTheoryFigure(
                identifier,
                app: app,
                navigationTitle: title,
                fileStem: "theory-\(pageID)-figure-\(stem)-\(suffix)",
                outDir: outDir
            )
            XCTAssertNotEqual(figureData, topData, "\(identifier) 配图截图不应与页顶截图相同")
        }

        for _ in 0..<8 { app.swipeUp() }
        sleep(1)
        saveTheoryPNG(app.screenshot(), name: "theory-\(pageID)-bottom-\(suffix)", outDir: outDir)

        XCTAssertTrue(app.staticTexts["常见误区"].exists, "\(pageID) 应有常见误区卡")
        XCTAssertTrue(app.staticTexts["相关页面"].exists, "\(pageID) 页尾应有「相关页面」")

        app.navigationBars[title].buttons.firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["球理"].waitForExistence(timeout: 6),
            "返回后应回到球理索引页"
        )
        app.swipeDown()
    }
}
