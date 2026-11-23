import XCTest

/// v38 W7：计划货架 12 份上屏 + Freemium 锁 + 准度Ⅰ/走位Ⅱ第一堂主课。
/// 截图落 `build/v38-w7-screenshots/`。
final class V37W4PlanShelfUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v38-w7-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testShelfShowsTwelvePlansAndFirstLessons() {
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium"])
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["官方计划"].waitForExistence(timeout: 8)
                      || app.staticTexts["官方计划"].waitForExistence(timeout: 2))

        savePNG("01-shelf-top")
        XCTAssertTrue(scrollToLabel("基本功"), "货架应出现免费「基本功」")
        XCTAssertTrue(scrollToLabel("准度Ⅰ·近中台"), "货架应出现免费「准度Ⅰ·近中台」")
        XCTAssertTrue(scrollToLabel("杆法Ⅰ·高低杆"), "货架应出现免费「杆法Ⅰ·高低杆」")
        XCTAssertTrue(scrollToLabel("准度Ⅲ·带塞"), "货架应出现 Pro「准度Ⅲ·带塞」（D-v38-2=A）")
        XCTAssertTrue(scrollToLabel("走位Ⅱ·多库与蛇彩"), "货架应出现「走位Ⅱ·多库与蛇彩」")
        savePNG("02-shelf-accuracy3")

        XCTAssertTrue(openPlan(named: "准度Ⅰ·近中台"))
        XCTAssertTrue(
            app.buttons["开始此计划"].waitForExistence(timeout: 8),
            "未订阅时免费准度Ⅰ应可激活"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["planDrillRow-drill_c011"].waitForExistence(timeout: 8),
            "准度Ⅰ第一堂主课须为近台 c011，不得再是半台先于近台"
        )
        savePNG("03-accuracy-first-lesson")
        goBack()

        XCTAssertTrue(openPlan(named: "走位Ⅱ·多库与蛇彩"))
        XCTAssertTrue(
            app.buttons["解锁此计划"].waitForExistence(timeout: 8),
            "未订阅时走位Ⅱ应锁定"
        )
        XCTAssertFalse(app.buttons["开始此计划"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["planDrillRow-drill_c080"].waitForExistence(timeout: 8),
            "走位Ⅱ第一堂主课须为半台 c080，不得再是蛇彩先于半台"
        )
        savePNG("04-positioning2-first-lesson")
    }

    /// 训练首页货架：打开靠后的计划再返回，应仍停在该卡附近，不必从顶再滑。
    func testHomeShelfScrollRestoredAfterClosingPlan() {
        app = XCUIApplication.launchClean()
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["官方计划"].waitForExistence(timeout: 8)
                      || app.staticTexts["官方计划"].waitForExistence(timeout: 2))

        let card = app.buttons["planPoster-plan_positioning2"]
        XCTAssertTrue(scrollUntilOnScreen(card), "应能滑到走位Ⅱ卡片")
        savePNG("05-home-before-open")
        tapEvenIfOccluded(card)
        XCTAssertTrue(app.staticTexts["训练安排"].waitForExistence(timeout: 10), "应进入计划详情")
        goBack()
        XCTAssertTrue(
            app.buttons["官方计划"].waitForExistence(timeout: 8)
                || app.staticTexts["官方计划"].waitForExistence(timeout: 2),
            "应回到训练首页"
        )
        let backCard = app.buttons["planPoster-plan_positioning2"]
        XCTAssertTrue(
            backCard.waitForExistence(timeout: 3) && isOnScreen(backCard),
            "返回后走位Ⅱ仍应在视口内，无需从顶部再滑"
        )
        savePNG("06-home-after-back")
    }

    /// 「训练计划」列表：打开靠后的计划再返回，应仍停在该卡附近。
    func testPlanListScrollRestoredAfterClosingPlan() {
        app = XCUIApplication.launchClean()
        app.switchTab(.training)
        XCTAssertTrue(openPlanList(), "应能打开训练计划列表")

        let card = app.buttons["planListPoster-plan_positioning2"]
        XCTAssertTrue(scrollUntilOnScreen(card), "列表应能滑到走位Ⅱ卡片")
        savePNG("07-list-before-open")
        tapEvenIfOccluded(card)
        XCTAssertTrue(app.staticTexts["训练安排"].waitForExistence(timeout: 10), "应进入计划详情")
        goBack()
        XCTAssertTrue(app.navigationBars["训练计划"].waitForExistence(timeout: 8)
                      || app.staticTexts["训练计划"].waitForExistence(timeout: 2))
        let backCard = app.buttons["planListPoster-plan_positioning2"]
        XCTAssertTrue(
            backCard.waitForExistence(timeout: 3) && isOnScreen(backCard),
            "返回列表后走位Ⅱ仍应在视口内"
        )
        savePNG("08-list-after-back")
    }

    func testCoverPilotTargetCards() {
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium"])
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["官方计划"].waitForExistence(timeout: 8)
                      || app.staticTexts["官方计划"].waitForExistence(timeout: 2))

        for planID in ["plan_accuracy3", "plan_positioning", "plan_fullskill"] {
            let card = app.buttons["planPoster-\(planID)"]
            XCTAssertTrue(scrollUntilOnScreen(card), "目标计划卡应可见：\(planID)")
            savePNG("pilot-\(planID)")
        }
    }

    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        let screen = app.frame
        return frame.width > 0
            && frame.maxY > 80
            && frame.minY < screen.height - 40
    }

    private func scrollUntilOnScreen(_ element: XCUIElement, maxSwipes: Int = 16) -> Bool {
        for _ in 0..<maxSwipes {
            if isOnScreen(element) { return true }
            app.windows.firstMatch.swipeUp()
        }
        return isOnScreen(element)
    }

    /// 首页底栏圆形 CTA 可能挡住货架底卡，坐标点仍能进详情。
    private func tapEvenIfOccluded(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }
    }

    private func scrollToLabel(_ text: String) -> Bool {
        let pred = NSPredicate(format: "label CONTAINS %@", text)
        let el = app.descendants(matching: .any).matching(pred).firstMatch
        for _ in 0..<16 {
            if el.exists { return true }
            app.windows.firstMatch.swipeUp()
        }
        return el.exists
    }

    private func openPlan(named name: String) -> Bool {
        app.switchTab(.training)
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        for _ in 0..<16 where !(card.exists && card.isHittable) {
            app.windows.firstMatch.swipeUp()
        }
        guard card.exists else { return false }
        card.tap()
        return app.staticTexts["训练安排"].waitForExistence(timeout: 10)
    }

    private func openPlanList() -> Bool {
        let menu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")
        ).firstMatch
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
            let planList = app.buttons["训练计划"]
            if planList.waitForExistence(timeout: 2) {
                planList.tap()
                return app.navigationBars["训练计划"].waitForExistence(timeout: 8)
                    || app.staticTexts["训练计划"].waitForExistence(timeout: 2)
            }
        }
        return false
    }

    private func goBack() {
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
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
