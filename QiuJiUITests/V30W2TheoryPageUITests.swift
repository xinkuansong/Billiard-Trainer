import XCTest

/// v30 W2：物理定理批四篇（T01 / T02 / T09 / T04）上线可点 + 页内说明图 + Light/Dark 截图。
///
/// 返工 r1（主控验收 R2）：配图截图必须滚到对应 `accessibilityIdentifier` 后
/// 用 **元素级** `XCUIElement.screenshot()` 落盘，禁止只拍全屏再改名
/// （曾导致 figure 文件与 top 文件 md5 相同、T09 levelFigure 无独立画面证据）。
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
        savePNG(app.screenshot(), name: "theory-index-published-Light")
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
        // 真台图首渲要解析 USDZ。
        sleep(3)
        savePNG(app.screenshot(), name: "theory-\(pageID)-top-\(suffix)")

        for identifier in figureIdentifiers {
            let figure = app.descendants(matching: .any)[identifier].firstMatch
            XCTAssertTrue(
                figure.waitForExistence(timeout: 6),
                "\(pageID) 详情页应有说明图 \(identifier)"
            )
            // 滚到该图可见且可点，再拍**元素级**截图（不是全屏改名）。
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
            // 再等一帧，避免滚完瞬间截到半屏。
            sleep(1)
            let fileStem = "theory-\(pageID)-figure-\(identifier.replacingOccurrences(of: ".", with: "-"))-\(suffix)"
            savePNG(figure.screenshot(), name: fileStem)
            // 同屏全页佐证（内容应含该图，且因滚动位置不同而与 top 区分）。
            savePNG(app.screenshot(), name: "\(fileStem)-screen")
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

    private func savePNG(_ shot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
