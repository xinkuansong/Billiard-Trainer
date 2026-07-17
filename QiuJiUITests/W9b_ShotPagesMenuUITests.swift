import XCTest

/// v7 W9b（C29–C33）：三点菜单模板截图 + Composer 开球全流程。
/// 截图写入 `build/w9b-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
final class W9b_ShotPagesMenuUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w9b-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    private func switchAngleHomeTab(_ app: XCUIApplication, _ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openCard(_ app: XCUIApplication, homeTab: String, title: String) -> Bool {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(app, homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }
    }

    /// 右上「更多」三点（`accessibilityLabel` = 更多）。
    private func moreButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == '更多' OR identifier == 'composer.more'")).firstMatch
    }

    private func openMoreMenuAndSnap(_ app: XCUIApplication, _ name: String) {
        let more = moreButton(app)
        guard more.waitForExistence(timeout: 3) else {
            XCTFail("\(name): 缺少三点菜单入口")
            return
        }
        more.tap()
        sleep(1)
        snap(app, name)
        // 点空白关菜单，避免挡后续导航。
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        usleep(400_000)
    }

    // MARK: - C29/C31 九点沙盘 + 有入口测验页菜单截图

    func testW9bMoreMenusNineSandboxesAndQuiz() throws {
        let app = XCUIApplication.launchClean()

        let sandboxes: [(tab: String, title: String, shot: String)] = [
            ("打", "分离角与走位", "w9b-menu-01-shotsim"),
            ("打", "自由走位", "w9b-menu-02-composer"),
            ("打", "自由击球", "w9b-menu-03-freeplay"),
            ("解", "思路训练", "w9b-menu-04-silu"),
            ("解", "打一走二想三", "w9b-menu-05-planthree"),
            ("解", "防守", "w9b-menu-06-snooker"),
            ("解", "翻袋解球器", "w9b-menu-07-bank"),
            ("解", "反射解球器", "w9b-menu-08-diamond"),
        ]
        for item in sandboxes {
            XCTAssertTrue(openCard(app, homeTab: item.tab, title: item.title), item.title)
            openMoreMenuAndSnap(app, item.shot)
            goBack(app)
        }

        // 测验页：AngleDynamic / AimPointScene(2D) 有三点；Geometric 仅重置（截 trailing）
        XCTAssertTrue(openCard(app, homeTab: "学", title: "角度与瞄准"), "AngleDynamic")
        openMoreMenuAndSnap(app, "w9b-menu-09-angledynamic")
        goBack(app)

        XCTAssertTrue(openCard(app, homeTab: "练", title: "2D 瞄准点训练"), "AimPointScene2D")
        // 进页可能有设置 sheet——先关掉。
        if app.buttons["开始训练"].waitForExistence(timeout: 2) {
            app.buttons["开始训练"].tap(); sleep(2)
        } else if app.buttons["重新开始"].waitForExistence(timeout: 1) {
            app.swipeDown(); sleep(1)
        }
        openMoreMenuAndSnap(app, "w9b-menu-10-aimpoint-scene")
        goBack(app)

        XCTAssertTrue(openCard(app, homeTab: "练", title: "角度预测"), "Geometric")
        snap(app, "w9b-menu-11-geometric-reset-trailing")
        let reset = app.buttons["重置统计"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3), "Geometric 应保留重置统计 trailing")
        XCTAssertFalse(moreButton(app).exists, "Geometric 无可配项，不应有三点")
        // C30：主 CTA「下一题」在结果态；答题入口弹 NumericKeypadHUD（ZStack 底浮层）。
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 3), answer.isHittable {
            answer.tap(); sleep(1)
            snap(app, "w9b-c30-geometric-keypad")
        }
        goBack(app)

        XCTAssertTrue(openCard(app, homeTab: "练", title: "瞄准点训练"), "AimPointTraining")
        snap(app, "w9b-menu-12-aimpoint-training-no-more")
        XCTAssertFalse(moreButton(app).waitForExistence(timeout: 1),
                       "AimPointTraining 无 SCN 网格，不并三点（留档）")
        XCTAssertTrue(app.buttons["提交瞄准点"].waitForExistence(timeout: 4),
                      "AimPointTraining 主 CTA 应为 BTTextActionButton「提交瞄准点」")
        snap(app, "w9b-c30-aimpoint-training-cta")
        goBack(app)
    }

    // MARK: - C32 Composer 开球全流程

    func testW9bComposerBreakFullFlow() throws {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由走位"), "Composer")

        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 4), "Composer 开球入口应可点（D12）")
        XCTAssertTrue(entry.isHittable, "Composer 开球入口应可点击")
        snap(app, "w9b-break-01-composer-entry")

        entry.tap()
        sleep(2)
        snap(app, "w9b-break-02-picker")

        let nine = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.game.9'")).firstMatch
        XCTAssertTrue(nine.waitForExistence(timeout: 4), "玩法选择应出现 9 球")
        nine.tap()
        sleep(3)
        snap(app, "w9b-break-03-racked")

        let strike = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.strike'")).firstMatch
        XCTAssertTrue(strike.waitForExistence(timeout: 4), "开球主按钮应出现")
        strike.tap()
        sleep(10)   // 求解 + 运杆 + 散局停稳

        // K6 / D-v8-3a：Composer 开球统一手动交付——停稳进 settled 三态
        // （完成 / 重开 / 取消），不再自动落座。
        let confirm = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.confirm'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15),
                      "停稳后应出现「完成」主钮（手动交付，D-v8-3a）")
        let rerack = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.rerack'")).firstMatch
        XCTAssertTrue(rerack.exists, "settled 应保留「重开」")
        XCTAssertTrue(app.buttons["取消"].exists || app.staticTexts["取消"].exists
                      || app.descendants(matching: .any)["取消"].exists,
                      "settled 应保留「取消」")
        snap(app, "w9b-break-04-settled")

        // 点「完成」交付击打阶段 → 开球模式退出（入口重新可点）。
        confirm.tap()
        sleep(2)
        let entryAgain = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        XCTAssertTrue(entryAgain.waitForExistence(timeout: 6),
                      "点「完成」落座后应回到编排态（开球入口复现）")
        snap(app, "w9b-break-05-delivered")
    }
}
