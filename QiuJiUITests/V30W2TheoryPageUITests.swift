import XCTest

/// v30 W2：物理定理批四篇（T01 / T02 / T09 / T04）上线可点 + 页内说明图 + Light/Dark 截图。
///
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/v30-w2-screenshots/`。
final class V30W2TheoryPageUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w2-screenshots"
    )

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV30W2_TheoryPagesLight() {
        openIndex()
        capturePage(pageID: "t01", title: "30° 法则", suffix: "Light",
                    figureIdentifiers: ["theoryT01.rollFigure"])
        capturePage(pageID: "t02", title: "90° 法则", suffix: "Light",
                    figureIdentifiers: ["theoryT02.stunFigure"])
        capturePage(pageID: "t09", title: "最少加塞原则", suffix: "Light",
                    figureIdentifiers: ["theoryT09.errorFigure", "theoryT09.levelFigure"])
        capturePage(pageID: "t04", title: "母球速度分级", suffix: "Light",
                    figureIdentifiers: ["theoryT04.spectrumFigure"])
        // 索引页：6 条已上线可点（完成标准 f）。
        savePNG("theory-index-published-Light")
    }

    func testV30W2_TheoryPagesDark() {
        openIndex()
        capturePage(pageID: "t01", title: "30° 法则", suffix: "Dark",
                    figureIdentifiers: ["theoryT01.rollFigure"])
        capturePage(pageID: "t02", title: "90° 法则", suffix: "Dark",
                    figureIdentifiers: ["theoryT02.stunFigure"])
        capturePage(pageID: "t09", title: "最少加塞原则", suffix: "Dark",
                    figureIdentifiers: ["theoryT09.errorFigure", "theoryT09.levelFigure"])
        capturePage(pageID: "t04", title: "母球速度分级", suffix: "Dark",
                    figureIdentifiers: ["theoryT04.spectrumFigure"])
        savePNG("theory-index-published-Dark")
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

    private func capturePage(pageID: String, title: String, suffix: String,
                             figureIdentifiers: [String]) {
        let row = app.descendants(matching: .any)["theoryEntry_\(pageID)"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 6), "\(pageID) 应是索引页上的可点条目")
        var scrolls = 0
        while !row.isHittable && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(row.isHittable, "\(pageID) 条目滚动后仍不可点")
        row.tap()

        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 6),
            "\(pageID) 详情页导航标题应为「\(title)」"
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

        for _ in 0..<6 { app.swipeUp() }
        sleep(1)
        savePNG("theory-\(pageID)-bottom-\(suffix)")

        XCTAssertTrue(app.staticTexts["常见误区"].exists, "\(pageID) 应有常见误区卡")
        XCTAssertTrue(app.staticTexts["相关页面"].exists, "\(pageID) 页尾应有「相关页面」")

        app.navigationBars[title].buttons.firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["球理"].waitForExistence(timeout: 6),
            "返回后应回到球理索引页"
        )
        app.swipeDown()
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
