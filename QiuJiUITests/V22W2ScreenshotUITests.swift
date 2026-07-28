import XCTest

/// v22 W2：准度专项计划列表/详情截图 → `build/v22-w2-screenshots/`
final class V22W2ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v22-w2-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW2_planAccuracyListAndDetailScreenshots() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        // 列表应出现「准度专项」（L1→L2 分组内；可能需下滑才入屏）
        let accuracyCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '准度专项'")
        ).firstMatch
        XCTAssertTrue(accuracyCard.waitForExistence(timeout: 10), "计划列表应出现「准度专项」")
        for _ in 0..<8 {
            if accuracyCard.isHittable { break }
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(accuracyCard.isHittable, "「准度专项」应滚入可见区后再截图")
        savePNG("01-plan-list-accuracy")

        accuracyCard.tap()
        sleep(2)

        // 详情：第 1 周 theme
        let week1Theme = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '近台直线打底'")
        ).firstMatch
        XCTAssertTrue(week1Theme.waitForExistence(timeout: 8), "详情应可见 W1 theme「近台直线打底」")
        savePNG("02-plan-accuracy-detail-week1-theme")

        // 展开第 1 周，确认专项 drill 名
        let weekRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '近台直线' OR label BEGINSWITH '第 1 周'")
        ).firstMatch
        if weekRow.waitForExistence(timeout: 4), weekRow.isHittable {
            weekRow.tap()
        } else if week1Theme.isHittable {
            week1Theme.tap()
        }
        sleep(1)
        app.swipeUp()
        usleep(400_000)

        let drillHit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '近台底袋' OR label CONTAINS '半台直线'")
        ).firstMatch
        XCTAssertTrue(drillHit.waitForExistence(timeout: 6), "展开后应看到准度专项 drill 名（近台底袋/半台直线）")
        savePNG("03-plan-accuracy-week1-expanded")
    }

    // MARK: - Helpers

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
