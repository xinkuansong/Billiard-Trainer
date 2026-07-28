import XCTest

/// v21 W5：计划加塞周次截图 + 学区 CTA→drill_c073 导航断言。
final class V21W5WiringUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v21-w5-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    // MARK: - Plan detail

    func testW5_planCueballEnglishWeekScreenshot() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        let cueball = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '基础杆法'")
        ).firstMatch
        XCTAssertTrue(cueball.waitForExistence(timeout: 8), "应看到「基础杆法专项」计划卡")
        cueball.tap()
        sleep(2)

        // 滚到第 6 周主题（加塞与挤偏）
        for _ in 0..<6 {
            app.swipeUp()
            usleep(350_000)
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS '加塞'")).firstMatch.exists {
                break
            }
        }

        let englishWeek = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '加塞'")
        ).firstMatch
        XCTAssertTrue(englishWeek.waitForExistence(timeout: 5), "计划详情应出现加塞周次主题")
        savePNG("01-plan-cueball-english-week")

        // 展开该周，确认 drill 名可见
        if englishWeek.isHittable {
            englishWeek.tap()
        } else {
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '加塞与挤偏'")).firstMatch.tap()
        }
        sleep(1)
        app.swipeUp()
        usleep(400_000)
        let drillHit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '挤偏认知' OR label CONTAINS '斯登' OR label CONTAINS '加塞'")
        ).firstMatch
        XCTAssertTrue(drillHit.waitForExistence(timeout: 5), "展开后应看到加塞相关 drill 名")
        savePNG("02-plan-cueball-week6-expanded")
    }

    // MARK: - Learn CTAs → drill

    func testW5_aimingCorrectionCTAOpensSquirtDrill() {
        openLearnPage(cardTitle: "瞄准修正", navTitle: "瞄准修正")
        savePNG("03-aiming-correction-page")

        dragScrollUp(times: 8)
        let cta = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'aimingCorrection.squirtDrillCTA'"))
            .firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 8), "瞄准修正页挤偏 drill CTA 应可达")
        savePNG("04-aiming-correction-cta")
        cta.tap()
        sleep(2)

        assertArrivedAtSquirtDrill()
        savePNG("05-aiming-correction-drill-arrived")
    }

    func testW5_spinAndEnglishCTAOpensSquirtDrill() {
        openLearnPage(cardTitle: "旋转与加塞", navTitle: "旋转与加塞")
        savePNG("06-spin-and-english-page")

        dragScrollUp(times: 8)
        let cta = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'spinAndEnglish.squirtDrillCTA'"))
            .firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 8), "旋转与加塞页挤偏 drill CTA 应可达")
        savePNG("07-spin-and-english-cta")
        cta.tap()
        sleep(2)

        assertArrivedAtSquirtDrill()
        savePNG("08-spin-and-english-drill-arrived")
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
        // 首页海报卡直达
        let card = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '训练计划'")).firstMatch
        if card.waitForExistence(timeout: 3) {
            card.tap()
        }
    }

    private func openLearnPage(cardTitle: String, navTitle: String) {
        app.switchTab(.angle)
        sleep(2)
        let seg = app.buttons["angleHomeTab_学"]
        if seg.waitForExistence(timeout: 5) { seg.tap() }
        usleep(700_000)

        let card = app.staticTexts[cardTitle]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "\(cardTitle) 卡不可达")
        if card.isHittable {
            card.tap()
        } else {
            app.swipeUp()
            usleep(400_000)
            app.staticTexts[cardTitle].tap()
        }
        sleep(2)
        XCTAssertTrue(app.navigationBars[navTitle].waitForExistence(timeout: 8),
                      "应进入\(navTitle)页")
    }

    private func assertArrivedAtSquirtDrill() {
        let title = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "挤偏认知")
        ).firstMatch
        let nav = app.navigationBars.matching(
            NSPredicate(format: "identifier CONTAINS %@ OR label CONTAINS %@", "挤偏", "挤偏")
        ).firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 8) || nav.waitForExistence(timeout: 2),
            "CTA 应到达挤偏认知 drill 详情（标题或导航栏）"
        )
    }

    private func dragScrollUp(times: Int = 1) {
        guard app.state == .runningForeground else { return }
        let host: XCUIElement = app.scrollViews.firstMatch.exists
            ? app.scrollViews.firstMatch
            : app.windows.firstMatch
        for _ in 0..<times {
            guard app.state == .runningForeground else { return }
            let start = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.78))
            let end = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.28))
            start.press(forDuration: 0.05, thenDragTo: end)
            usleep(450_000)
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
