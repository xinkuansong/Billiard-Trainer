import XCTest

/// v30 W3：战术定理批四篇（T05 / T06 / T07 / T10）上线可点 + 页内说明图 + Light/Dark 截图。
///
/// 配图取证（**v30 W4 按 X-v30-9 重写**）：走 `captureTheoryFigure` ——
/// 先把图完整滚进可视区并断言 `frame` 落在可视区内，再**直接截该元素**落盘
/// （另存 `-context` 全屏）。原「滚到 isHittable + 只断言字节 ≠ 页顶」的口径已作废：
/// 它对「滚过头」无效，是 W3 四张 figure 拍成正文的根因。
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`。
/// 截图落盘 `build/v30-w3-screenshots/`。
final class V30W3TheoryPageUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w3-screenshots"
    )

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV30W3_TheoryPagesLight() {
        openIndex()
        capturePage(pageID: "t05", title: "反向规划", suffix: "Light",
                    figureIdentifiers: ["theoryT05.chainFigure"])
        capturePage(pageID: "t06", title: "关键球原理", suffix: "Light",
                    figureIdentifiers: ["theoryT06.layerFigure"])
        capturePage(pageID: "t07", title: "球团管理", suffix: "Light",
                    figureIdentifiers: ["theoryT07.phaseFigure"])
        capturePage(pageID: "t10", title: "安全球三维度模型", suffix: "Light",
                    figureIdentifiers: ["theoryT10.dimensionFigure", "theoryT10.ladderFigure"])
        savePNG(app.screenshot(), name: "theory-index-published-Light")
    }

    func testV30W3_TheoryPagesDark() {
        openIndex()
        capturePage(pageID: "t05", title: "反向规划", suffix: "Dark",
                    figureIdentifiers: ["theoryT05.chainFigure"])
        capturePage(pageID: "t06", title: "关键球原理", suffix: "Dark",
                    figureIdentifiers: ["theoryT06.layerFigure"])
        capturePage(pageID: "t07", title: "球团管理", suffix: "Dark",
                    figureIdentifiers: ["theoryT07.phaseFigure"])
        capturePage(pageID: "t10", title: "安全球三维度模型", suffix: "Dark",
                    figureIdentifiers: ["theoryT10.dimensionFigure", "theoryT10.ladderFigure"])
        savePNG(app.screenshot(), name: "theory-index-published-Dark")
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
        let topName = "theory-\(pageID)-top-\(suffix)"
        let topData = savePNG(app.screenshot(), name: topName)

        for identifier in figureIdentifiers {
            // X-v30-9 修复：改为「滚到图完整可见 → 断言 frame 落在可视区内 → 截该元素」。
            // 原口径（滚到 isHittable + 只断言字节 ≠ 页顶）对「滚过头」无效，
            // 导致 W3 四张 figure 实际拍到的是图下方的正文。
            let fileStem = "theory-\(pageID)-figure-\(identifier.replacingOccurrences(of: ".", with: "-"))-\(suffix)"
            let figureData = captureTheoryFigure(
                identifier,
                app: app,
                navigationTitle: title,
                fileStem: fileStem,
                outDir: outDir
            )
            XCTAssertNotEqual(
                figureData, topData,
                "\(pageID) 配图截图 \(fileStem) 不得与页顶截图内容相同"
            )
        }

        for _ in 0..<6 { app.swipeUp() }
        sleep(1)
        savePNG(app.screenshot(), name: "theory-\(pageID)-bottom-\(suffix)")

        XCTAssertTrue(app.staticTexts["常见误区"].exists, "\(pageID) 应有常见误区卡")
        XCTAssertTrue(app.staticTexts["相关页面"].exists, "\(pageID) 页尾应有「相关页面」")

        app.navigationBars[title].buttons.firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["球理"].waitForExistence(timeout: 6),
            "返回后应回到球理索引页"
        )
        app.swipeDown()
    }

    @discardableResult
    private func savePNG(_ shot: XCUIScreenshot, name: String) -> Data {
        let data = shot.pngRepresentation
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? data.write(to: outDir.appendingPathComponent("\(name).png"))
        return data
    }
}
