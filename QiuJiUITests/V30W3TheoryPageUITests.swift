import XCTest

/// v30 W3：战术定理批四篇（T05 / T06 / T07 / T10）上线可点 + 页内说明图 + Light/Dark 截图。
///
/// 配图取证：滚到 `accessibilityIdentifier` 后再微滚，存**全屏**（抽象图元素截图易裁切）；
/// 与页顶 md5 不得相同。外观切换：事先 `xcrun simctl ui booted appearance light|dark`。
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
            let figure = app.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(
                figure.waitForExistence(timeout: 6),
                "\(pageID) 详情页应有说明图 \(identifier)"
            )
            var tries = 0
            while !figure.isHittable && tries < 10 {
                app.swipeUp()
                tries += 1
                sleep(1)
            }
            XCTAssertTrue(
                figure.isHittable,
                "\(pageID) 说明图 \(identifier) 滚动后仍不可见/不可点"
            )
            // 刚滚到 isHittable 时图常贴在屏底，再微滚一次把整图抬进视口中央。
            app.swipeUp()
            sleep(1)
            XCTAssertTrue(figure.isHittable || figure.exists,
                          "微滚后 \(identifier) 应仍在页上")

            // 抽象图示元素级 screenshot 易裁切；本批一律存滚到该图后的全屏证据。
            let fileStem = "theory-\(pageID)-figure-\(identifier.replacingOccurrences(of: ".", with: "-"))-\(suffix)"
            var screen = app.screenshot()
            var figureData = screen.pngRepresentation
            if figureData == topData {
                app.swipeUp()
                sleep(1)
                XCTAssertTrue(figure.isHittable || figure.exists,
                              "再微滚后 \(identifier) 应仍在页上")
                screen = app.screenshot()
                figureData = screen.pngRepresentation
            }
            figureData = savePNG(screen, name: fileStem)

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
