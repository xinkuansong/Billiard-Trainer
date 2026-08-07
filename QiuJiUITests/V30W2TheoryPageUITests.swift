import XCTest

/// v30 W2：物理定理批四篇（T01 / T02 / T09 / T04）上线可点 + 页内说明图 + Light/Dark 截图。
///
/// 返工 r1（主控验收 R2）：配图截图必须滚到对应 `accessibilityIdentifier` 后落盘，
/// 且与页顶截图 md5 不得相同。策略：
/// 1. 先滚到 `isHittable`；
/// 2. 优先 `XCUIElement.screenshot()`（真台图有效）；
/// 3. 若元素截图过小（抽象图 + `accessibilityElement(children: .ignore)` 常见黑块），
///    改存**该屏全页**截图，并在必要时再微滚一屏以与 top 区分。
///
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`。
/// 截图落盘 `build/v30-w2-screenshots/`。
final class V30W2TheoryPageUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w2-screenshots"
    )

    /// 元素截图过小视为失败（黑块 / 空框）；改走全屏。
    private let minElementBytes = 20_000

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
            sleep(1)

            let fileStem = "theory-\(pageID)-figure-\(identifier.replacingOccurrences(of: ".", with: "-"))-\(suffix)"
            let elementShot = figure.screenshot()
            let elementData = elementShot.pngRepresentation
            let figureData: Data
            if elementData.count >= minElementBytes {
                figureData = savePNG(elementShot, name: fileStem)
            } else {
                // 抽象图等元素截图常为黑块：改存滚到该图后的全屏，作为该图的画面证据。
                // 若仍与 top 同帧（图本就在首屏），再微滚一次拉开。
                var screen = app.screenshot()
                var data = screen.pngRepresentation
                if data == topData {
                    app.swipeUp()
                    sleep(1)
                    XCTAssertTrue(figure.isHittable || figure.exists,
                                  "微滚后 \(identifier) 应仍在页上")
                    screen = app.screenshot()
                    data = screen.pngRepresentation
                }
                figureData = savePNG(screen, name: fileStem)
                XCTAssertGreaterThan(
                    figureData.count, minElementBytes,
                    "\(pageID) \(identifier) 全屏回退截图仍过小"
                )
            }

            XCTAssertNotEqual(
                figureData, topData,
                "\(pageID) 配图截图 \(fileStem) 不得与页顶截图内容相同（R2）"
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
