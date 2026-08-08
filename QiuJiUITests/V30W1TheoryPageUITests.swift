import XCTest

/// v30 W1：试点两篇球理详情页（切线法则 / 风险报酬决策矩阵）的上线可点 + 渲染验收。
///
/// 返工 r1 追加：
/// - 断言四张页内说明图确实在页面上（T03 两张真台图 / T08 两张抽象图示）；
/// - 额外抓一张现有学页「瞄准原理」截图落同一目录，供风格并排对比（完成标准 k）。
///
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/v30-w1-rework-screenshots/`。
final class V30W1TheoryPageUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w1-rework-screenshots"
    )

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV30W1_TheoryPagesLight() {
        openIndex()
        capturePage(pageID: "t03", title: "切线法则", suffix: "Light",
                    figureIdentifiers: ["theoryT03.tangentFigure", "theoryT03.pathsFigure"])
        capturePage(pageID: "t08", title: "风险报酬决策矩阵", suffix: "Light",
                    figureIdentifiers: ["theoryT08.zoneFigure", "theoryT08.flowFigure"])
    }

    func testV30W1_TheoryPagesDark() {
        openIndex()
        capturePage(pageID: "t03", title: "切线法则", suffix: "Dark",
                    figureIdentifiers: ["theoryT03.tangentFigure", "theoryT03.pathsFigure"])
        capturePage(pageID: "t08", title: "风险报酬决策矩阵", suffix: "Dark",
                    figureIdentifiers: ["theoryT08.zoneFigure", "theoryT08.flowFigure"])
    }

    /// 风格对比基准：现有文档学页「瞄准原理」首屏 + 一屏滚动。
    func testV30W1_ReferenceLearnPageLight() {
        app.switchTab(.angle)
        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10), "练习 Tab「学」侧栏应出现")
        learn.tap()

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "瞄准原理"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 6), "「学」分组应有瞄准原理入口卡")
        card.tap()

        XCTAssertTrue(app.navigationBars["瞄准原理"].waitForExistence(timeout: 6))
        sleep(2)
        savePNG("reference-aimingPrinciple-top-Light")
        app.swipeUp()
        sleep(1)
        savePNG("reference-aimingPrinciple-mid-Light")
    }

    // MARK: - Steps

    private func openIndex() {
        XCTAssertTrue(TheoryIndexNavigation.openTheorySection(in: app))
    }

    /// 从理区网格进一篇详情页，取证后返回理区（v32.2：不再经索引页）。
    private func capturePage(pageID: String, title: String, suffix: String,
                             figureIdentifiers: [String]) {
        XCTAssertTrue(
            TheoryIndexNavigation.openPage(in: app, cardTitle: title, navigationTitle: title)
        )
        sleep(3)
        savePNG("theory-\(pageID)-top-\(suffix)")

        for identifier in figureIdentifiers {
            let figure = app.descendants(matching: .any)[identifier].firstMatch
            var tries = 0
            while !figure.exists && tries < 6 {
                app.swipeUp()
                tries += 1
                sleep(1)
            }
            XCTAssertTrue(figure.exists, "\(pageID) 详情页应有说明图 \(identifier)")
            savePNG("theory-\(pageID)-figure-\(identifier.replacingOccurrences(of: ".", with: "-"))-\(suffix)")
        }

        app.swipeUp()
        sleep(1)
        savePNG("theory-\(pageID)-mid-\(suffix)")

        app.swipeUp()
        sleep(1)
        savePNG("theory-\(pageID)-mid2-\(suffix)")

        for _ in 0..<6 { app.swipeUp() }
        sleep(1)
        savePNG("theory-\(pageID)-bottom-\(suffix)")

        XCTAssertTrue(
            app.staticTexts["常见误区"].exists,
            "\(pageID) 详情页应有常见误区卡"
        )
        XCTAssertTrue(
            app.staticTexts["相关页面"].exists,
            "\(pageID) 详情页页尾应有「相关页面」（对齐现有学页结构）"
        )

        app.navigationBars[title].buttons.firstMatch.tap()
        XCTAssertTrue(
            TheoryIndexNavigation.openTheorySection(in: app),
            "返回后应能再次打开理区"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", title))
                .firstMatch.waitForExistence(timeout: 6),
            "返回理区后应仍能看到「\(title)」卡"
        )
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
