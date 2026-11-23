import XCTest

/// v22 W3：力度控制专项计划列表/详情截图 → `build/v22-w3-screenshots/`
final class V22W3ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v22-w3-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW3_planForceListAndDetailScreenshots() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        // 列表应出现「力度控制专项」（L1→L2；Pro；可能需下滑）
        let forceCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '力度控制专项'")
        ).firstMatch
        XCTAssertTrue(forceCard.waitForExistence(timeout: 10), "计划列表应出现「力度控制专项」")
        for _ in 0..<10 {
            if forceCard.isHittable { break }
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(forceCard.isHittable, "「力度控制专项」应滚入可见区后再截图")
        savePNG("01-plan-list-force")

        forceCard.tap()
        sleep(3)

        // 详情：第 1 周 theme
        let week1Theme = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '轻推与三档'")
        ).firstMatch
        XCTAssertTrue(week1Theme.waitForExistence(timeout: 8), "详情应可见 W1 theme「轻推与三档」")
        savePNG("02-plan-force-detail-week1-theme")

        // 先把 hero 顶上去，避免大封面抢点击
        app.swipeUp()
        usleep(500_000)

        expandWeek1()
        sleep(1)
        savePNG("03-plan-force-week1-expanded")

        let drillHit = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS '轻推定位' OR label CONTAINS '三档力度' OR label CONTAINS 'drill_c044' OR label CONTAINS '专项训练' OR label CONTAINS '热身'"
            )
        ).firstMatch
        XCTAssertTrue(
            drillHit.waitForExistence(timeout: 6),
            "展开后应看到力度专项 drill/阶段名；debug=\(buttonLabelsDebug())"
        )
    }

    // MARK: - Helpers

    private func expandWeek1() {
        let weekRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '第 1 周'")
        ).firstMatch
        XCTAssertTrue(weekRow.waitForExistence(timeout: 6), "应有第 1 周手风琴按钮")

        for attempt in 1...5 {
            if weekRow.isHittable {
                weekRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                app.swipeUp()
                usleep(300_000)
                weekRow.tap()
            }
            sleep(1)

            let expanded = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '第 1 天' OR label CONTAINS '热身' OR label CONTAINS '专项训练'")
            ).firstMatch
            if expanded.exists { return }

            // 再点一次 theme 文本（W2 回退路径）
            let theme = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '轻推与三档'")
            ).firstMatch
            if theme.exists, theme.isHittable {
                theme.tap()
                sleep(1)
            }
            if expanded.exists { return }

            // 偶发点到已展开又收起：奇数次后再试
            if attempt % 2 == 0 {
                app.swipeDown()
                usleep(300_000)
            }
        }
    }

    private func buttonLabelsDebug() -> String {
        let buttons = app.buttons.allElementsBoundByIndex
        let labels = (0..<min(buttons.count, 20)).compactMap { buttons[$0].label }
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
