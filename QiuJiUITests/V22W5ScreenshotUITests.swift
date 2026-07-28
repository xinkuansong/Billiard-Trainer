import XCTest

/// v22 W5：加塞专项计划列表/详情截图 → `build/v22-w5-screenshots/`
final class V22W5ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v22-w5-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW5_planEnglishListAndDetailScreenshots() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        // 列表应出现「加塞专项」（L2；Pro）。勿误点「高级专项：加塞与多库」
        let englishCard = app.staticTexts.matching(
            NSPredicate(format: "label == '加塞专项'")
        ).firstMatch
        var listed = false
        for _ in 0..<22 {
            if englishCard.exists, englishCard.isHittable {
                listed = true
                break
            }
            swipeWindowUp()
            usleep(350_000)
        }
        XCTAssertTrue(listed, "计划列表应滚到「加塞专项」；debug=\(staticTextLabelsDebug())")
        savePNG("01-plan-list-english")

        englishCard.tap()

        // 详情：Pro 锁可见「解锁此计划」或训练安排/周主题；勿死等 app idle
        let unlockCTA = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '解锁此计划'")
        ).firstMatch
        let arrange = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '训练安排'")
        ).firstMatch
        let week1 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '第 1 周' AND label CONTAINS '挤偏'")
        ).firstMatch
        let detailHero = app.staticTexts.matching(
            NSPredicate(format: "label == '加塞专项'")
        ).firstMatch

        var detailReady = false
        for _ in 0..<20 {
            if unlockCTA.exists || arrange.exists || week1.exists || detailHero.exists {
                detailReady = true
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            detailReady,
            "应进入加塞专项详情；debug=\(buttonLabelsDebug()) | \(staticTextLabelsDebug())"
        )
        savePNG("02-plan-english-detail-hero")

        // 滚到训练安排 / W1 theme（用窗口坐标拖，避开 app.swipeUp 的长 idle）
        for _ in 0..<8 {
            if week1.exists { break }
            swipeWindowUp()
            usleep(300_000)
        }
        XCTAssertTrue(
            week1.waitForExistence(timeout: 6),
            "详情应可见 W1 手风琴（theme 含「挤偏」）；debug=\(buttonLabelsDebug())"
        )
        savePNG("03-plan-english-detail-week1-theme")

        week1.tap()
        usleep(800_000)

        let day1 = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '第 1 天'")
        ).firstMatch
        if !day1.waitForExistence(timeout: 3) {
            let themeText = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '挤偏认知'")
            ).firstMatch
            if themeText.exists { themeText.tap() }
            else { week1.tap() }
            usleep(800_000)
        }
        XCTAssertTrue(
            day1.waitForExistence(timeout: 5),
            "展开后应见「第 1 天」；debug=\(buttonLabelsDebug()) | \(staticTextLabelsDebug())"
        )

        swipeWindowUp()
        usleep(400_000)
        savePNG("04-plan-english-week1-expanded")

        let drillHit = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS '挤偏' OR label CONTAINS '塞量' OR label CONTAINS '带塞' OR label CONTAINS '直线出杆' OR label CONTAINS '专项训练' OR label CONTAINS '热身'"
            )
        ).firstMatch
        XCTAssertTrue(
            drillHit.waitForExistence(timeout: 6),
            "展开后应看到加塞专项 drill/阶段名；debug=\(staticTextLabelsDebug())"
        )
    }

    // MARK: - Helpers

    private func swipeWindowUp() {
        let win = app.windows.firstMatch
        guard win.exists else {
            app.swipeUp()
            return
        }
        let start = win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func buttonLabelsDebug() -> String {
        let buttons = app.buttons.allElementsBoundByIndex
        let labels = (0..<min(buttons.count, 20)).compactMap { buttons[$0].label }
        return labels.joined(separator: " | ")
    }

    private func staticTextLabelsDebug() -> String {
        let texts = app.staticTexts.allElementsBoundByIndex
        let labels = (0..<min(texts.count, 40)).compactMap { texts[$0].label }
        return labels.joined(separator: " | ")
    }

    private func openPlanList() {
        let menu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More' OR label CONTAINS '更多'")
        ).firstMatch
        if menu.waitForExistence(timeout: 4) {
            menu.tap()
            usleep(500_000)
        }
        let planList = app.buttons["训练计划"]
        if planList.waitForExistence(timeout: 3) {
            planList.tap()
            return
        }
        let card = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '训练计划'")).firstMatch
        if card.waitForExistence(timeout: 3) {
            card.tap()
        }
    }

    private func savePNG(_ name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
