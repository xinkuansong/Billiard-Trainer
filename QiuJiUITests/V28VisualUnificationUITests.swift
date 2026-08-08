import XCTest

/// v28 W4：三 Tab 表层语法 + 练习混合封面 Light/Dark 截图总验收。
///
/// 外观切换：事先 `xcrun simctl ui <udid> appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/v28-screenshots/`。
final class V28VisualUnificationUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v28-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV28_LightScreenshots() {
        captureSeries(suffix: "Light")
    }

    func testV28_DarkScreenshots() {
        captureSeries(suffix: "Dark")
    }

    func testPracticePremiumEntryShowsSubscription() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium"])
        app.switchTab(.angle)
        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 8))
        learn.tap()

        let premiumEntry = app.buttons["分离角图谱"]
        XCTAssertTrue(premiumEntry.waitForExistence(timeout: 5))
        premiumEntry.tap()

        let paywallTitle = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS '解锁球迹'"))
            .firstMatch
        XCTAssertTrue(paywallTitle.waitForExistence(timeout: 8), "非 Pro 用户点击高级练习入口应展示订阅页")
        XCTAssertFalse(
            app.navigationBars["分离角图谱"].exists,
            "门控入口不应先进入内容页"
        )
    }

    private func captureSeries(suffix: String) {
        // 1) Training home — plan cards under shared shell
        app.switchTab(.training)
        sleep(2)
        let official = app.buttons["官方计划"]
        if official.waitForExistence(timeout: 4) {
            official.tap()
            sleep(1)
        }
        savePNG("training-home-\(suffix)")

        // Plan list via overflow menu when available
        let more = app.buttons.matching(NSPredicate(format: "label CONTAINS '更多' OR identifier CONTAINS 'ellipsis'")).firstMatch
        if more.waitForExistence(timeout: 2) {
            more.tap()
            sleep(1)
            let plans = app.buttons["训练计划"].firstMatch
            if plans.waitForExistence(timeout: 2) {
                plans.tap()
                sleep(2)
                savePNG("training-plan-list-\(suffix)")
                app.tapBackButton()
                sleep(1)
            }
        } else {
            savePNG("training-plan-list-skipped-\(suffix)")
        }

        // 2) Drill library — single chip row + filter menu
        app.switchTab(.drillLibrary)
        sleep(2)
        XCTAssertTrue(
            app.descendants(matching: .any)["levelFilter_全部"].waitForExistence(timeout: 5),
            "动作库应保留一行等级 quick chips"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["ballType_中式台球"].waitForExistence(timeout: 1),
            "球种 chips 行应已移除"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["badgeFilterMenu"].waitForExistence(timeout: 3),
            "筛选菜单应存在"
        )
        savePNG("drill-library-home-\(suffix)")

        // Open a detail before the filter Menu so hit-testing is not blocked by a popover.
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'"))
            .firstMatch
        if card.waitForExistence(timeout: 6) {
            card.tap()
            sleep(2)
            savePNG("drill-detail-\(suffix)")
            app.tapBackButton()
            sleep(1)
        } else {
            savePNG("drill-detail-skipped-\(suffix)")
        }

        let menu = app.descendants(matching: .any)["badgeFilterMenu"]
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
            sleep(1)
            savePNG("drill-library-filter-menu-\(suffix)")
            // Dismiss popover by tapping page title area (not tab bar).
            app.staticTexts["动作库"].firstMatch.tap()
            sleep(1)
        }

        // 3) Practice — five zones (学/理/练/打/解, v32)
        app.switchTab(.angle)
        sleep(3)
        let practiceSidebar = app.descendants(matching: .any)["angleHomeTab_全部"]
        XCTAssertTrue(
            practiceSidebar.waitForExistence(timeout: 8),
            "练习首页侧栏「全部」应出现（确认已离开动作库）"
        )
        savePNG("practice-all-\(suffix)")

        for zone in ["学", "理", "练", "打", "解"] {
            let tab = app.descendants(matching: .any)["angleHomeTab_\(zone)"]
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                sleep(2)
                savePNG("practice-\(zone)-\(suffix)")
            }
        }

        // Landing samples (system push — no fake mat requirement)
        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        if learn.waitForExistence(timeout: 2) { learn.tap(); sleep(1) }
        let aiming = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "瞄准原理"))
            .firstMatch
        if aiming.waitForExistence(timeout: 4) {
            aiming.tap()
            sleep(2)
            savePNG("practice-landing-aimingPrinciple-\(suffix)")
            app.tapBackButton()
            sleep(1)
        }

        let train = app.descendants(matching: .any)["angleHomeTab_练"]
        if train.waitForExistence(timeout: 2) {
            train.tap()
            sleep(1)
            let quiz = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "角度预测"))
                .firstMatch
            if quiz.waitForExistence(timeout: 4) {
                quiz.tap()
                sleep(2)
                savePNG("practice-landing-geometricQuiz-\(suffix)")
                app.tapBackButton()
                sleep(1)
            }
        }
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = outDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}
