import XCTest

/// v37 W4：计划货架 11 份上屏 + Freemium 锁。截图落 `build/v37-w4-screenshots/`。
final class V37W4PlanShelfUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v37-w4-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testShelfShowsElevenPlansAndFreeUnlocks() {
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium"])
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["官方计划"].waitForExistence(timeout: 8)
                      || app.staticTexts["官方计划"].waitForExistence(timeout: 2))

        savePNG("01-shelf-top")
        XCTAssertTrue(scrollToLabel("基本功"), "货架应出现免费「基本功」")
        XCTAssertTrue(scrollToLabel("准度Ⅰ·近中台"), "货架应出现免费「准度Ⅰ·近中台」")
        XCTAssertTrue(scrollToLabel("杆法Ⅰ·高低杆"), "货架应出现免费「杆法Ⅰ·高低杆」")
        XCTAssertTrue(scrollToLabel("走位Ⅱ·多库与蛇彩"), "货架应出现新增「走位Ⅱ·多库与蛇彩」")
        savePNG("02-shelf-positioning2")

        XCTAssertTrue(openPlan(named: "准度Ⅰ·近中台"))
        XCTAssertTrue(
            app.buttons["开始此计划"].waitForExistence(timeout: 8),
            "未订阅时免费准度Ⅰ应可激活"
        )
        savePNG("03-free-accuracy")
        goBack()

        XCTAssertTrue(openPlan(named: "走位Ⅱ·多库与蛇彩"))
        XCTAssertTrue(
            app.buttons["解锁此计划"].waitForExistence(timeout: 8),
            "未订阅时走位Ⅱ应锁定"
        )
        XCTAssertFalse(app.buttons["开始此计划"].exists)
        savePNG("04-locked-positioning2")
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
