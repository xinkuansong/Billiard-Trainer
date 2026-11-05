import XCTest

/// 问题集合 v5 · V6（G18 开球通用规范）截图核验：
/// 逐宿主进入开球模式，核验「左侧瞄准刻度轮 + 右侧力度柱贴边（默认 6 m/s）+ 底部条按钮」，
/// 并核验 FreePlay 停稳后「重开 / 完成」位置互换（完成在最右主位）。
///
/// 有真实开球流程的宿主：自由击球（FreePlay）/ 思路训练（Silu）/ 打一走二想三（PlanThree）。
/// 走位编排台（Composer）按既有设计（条 19.2）本页无开球入口（禁用态），故不在此截图。
final class S6_BreakUniversalUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    // MARK: - Helpers

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapIfExists(_ label: String, timeout: TimeInterval = 4) -> Bool {
        let t = app.staticTexts[label]
        if t.waitForExistence(timeout: timeout) { t.tap(); return true }
        let b = app.buttons[label]
        if b.waitForExistence(timeout: 1) { b.tap(); return true }
        return false
    }

    private func popBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 2), back.isHittable { back.tap(); usleep(700_000) }
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        if seg.waitForExistence(timeout: 3) { seg.tap(); usleep(600_000); return true }
        return false
    }

    private func breakEntry() -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
    }

    // MARK: - Test

    func testV6BreakUniversal() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        // ── 自由击球（手动交付：racked → strike → settled，核验按钮互换） ──
        switchAngleHomeTab("打")
        if tapIfExists("自由击球", timeout: 5) {
            sleep(3)
            let entry = breakEntry()
            if entry.waitForExistence(timeout: 4), entry.isHittable {
                entry.tap(); sleep(1)
                if tapIfExists("中式八球", timeout: 3) {
                    sleep(3)
                    // racked：左瞄准轮 + 右力度柱（默认 6.0）+ 取消/重开/开球。
                    snap("v6-freeplay-break-racked")
                    let strike = app.descendants(matching: .any)
                        .matching(NSPredicate(format: "identifier == 'break.strike'")).firstMatch
                    if strike.waitForExistence(timeout: 3), strike.isHittable {
                        strike.tap()
                        sleep(10)   // 求解 + 运杆 + 散局 + 停稳
                        // settled：取消/重开/完成——完成在最右主位（重开与完成互换）。
                        snap("v6-freeplay-break-settled")
                    }
                }
            }
            popBack(); sleep(1)
        }

        // ── 思路训练（Q14，自动交付：只截 racked） ──
        captureSolverBreak(entry: "思路训练", name: "v6-silu-break-racked")

        // ── 打一走二想三（Q15.4，自动交付：只截 racked） ──
        captureSolverBreak(entry: "打一走二想三", name: "v6-planthree-break-racked")
    }

    private func captureSolverBreak(entry: String, name: String) {
        for _ in 0..<3 {
            app.switchTab(.angle); sleep(1)
            switchAngleHomeTab("解")
            let card = app.buttons[entry]
            if card.waitForExistence(timeout: 4) { card.tap(); break }
        }
        sleep(3)
        let be = breakEntry()
        if be.waitForExistence(timeout: 4), be.isHittable {
            be.tap(); sleep(1)
            let nine = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'break.game.15'")).firstMatch
            if nine.waitForExistence(timeout: 2), nine.isHittable {
                nine.tap()
            } else {
                _ = tapIfExists("中式八球", timeout: 3)
            }
            sleep(3)
            snap(name)   // 左瞄准轮 + 右力度柱 + 取消/重开/开球
            _ = tapIfExists("取消", timeout: 3)
            sleep(1)
        }
        popBack(); sleep(1)
    }
}

/// Real controls: settings do not replace the board; break owns the direction lane
/// until natural settle/cancellation, then restores the page's planning controls.
final class UnifiedBreakFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var planning = false
    private var silu = false
    private var moreID: String { silu ? "silu.more" : (planning ? "planthree.more" : "freeplay.moreMenu") }
    private var breakStrike: XCUIElement { node(silu ? "silu.strike" : (planning ? "planthree.strike" : "break.strike")) }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private func node(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 40) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)], timeout: timeout), .completed)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "unified-break-" + name; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "unified-break-" + name + "-tree"; tree.lifetime = .keepAlways; add(tree)
    }
    private func reveal(_ id: String) -> XCUIElement {
        let item = app.buttons[id], scroll = app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<8 {
            if item.isHittable && scroll.frame.contains(item.frame) { break }
            if item.exists && item.frame.minY < scroll.frame.minY { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(item.isHittable, id)
        return item
    }
    private func closeMenu() {
        let close = app.buttons["dailyClearance.menuClose"]
        if close.exists { close.tap() }
        else {
            let backdrop = silu ? app.buttons["silu.dismissMenu"] : (planning ? app.buttons["planthree.dismissMenu"] : app.buttons["关闭菜单"].firstMatch)
            backdrop.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.8)).tap()
        }
    }
    private func assertQuiet() {
        for text in ["运杆…", "开球中…", "开球计算中…", "已停稳", "开球中"] {
            XCTAssertFalse(app.staticTexts[text].exists, text)
        }
    }
    private func launch(planning: Bool, mode: String, silu: Bool = false) {
        self.planning = planning
        self.silu = silu
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral",
            "-dailyLayout.probe", "-3dDrag.probe",
            silu ? "-deeplink.silu" : (planning ? "-deeplink.planThree" : "-dailyInteraction.sharedPage=composer")])
        ready(app.buttons[moreID])
        app.buttons[moreID].tap()
        let camera = app.buttons[silu ? "silu.cameraMode" : (planning ? "planthree.cameraMode" : "freeplay.cameraMode")]
        ready(camera)
        if camera.value as? String != mode { camera.tap() }
        closeMenu()
        capture((silu ? "silu-" : (planning ? "planthree-" : "composer-")) + mode + "-launch")
        ready(node("break.entry"))
    }
    private func exercise(planning: Bool, mode: String, silu: Bool = false) {
        launch(planning: planning, mode: mode, silu: silu)
        let prefix = (silu ? "silu-" : (planning ? "planthree-" : "composer-")) + mode
        let entry = node("break.entry")
        if planning || silu {
            XCTAssertTrue(app.buttons["solver.nextSolution"].exists)
            XCTAssertGreaterThanOrEqual(app.buttons["solver.nextSolution"].frame.minY, entry.frame.maxY)
        }
        if silu {
            let tool = app.buttons["silu.tool"], clear = app.buttons["silu.clearConstraint"], solution = app.buttons["solver.nextSolution"]
            XCTAssertGreaterThanOrEqual(tool.frame.minY, entry.frame.maxY)
            XCTAssertGreaterThanOrEqual(clear.frame.minY, tool.frame.maxY)
            XCTAssertGreaterThanOrEqual(solution.frame.minY, clear.frame.maxY)
        }
        capture(prefix + "-idle")
        entry.tap()
        ready(breakStrike)
        XCTAssertFalse(app.buttons["break.game.4"].exists, "The left entry must rack directly without the old picker")
        app.buttons[moreID].tap()
        let settings = reveal("break.settings")
        XCTAssertTrue(settings.label.contains("开球玩法"))
        settings.tap()
        ready(app.buttons["break.game.4"])
        app.buttons["break.game.4"].tap()
        XCTAssertEqual(app.buttons["break.game.4"].value as? String, "已选")
        XCTAssertEqual(node("break.rerack").value as? String, "4 球")
        capture(prefix + "-settings-immediate-4")
        // Change an already prepared rack without touching the rerack/strike controls.
        for count in [9, 15, 6, 5, 4] {
            app.buttons["break.game.\(count)"].tap()
            XCTAssertEqual(app.buttons["break.game.\(count)"].value as? String, "已选")
            XCTAssertEqual(node("break.rerack").value as? String, count == 15 ? "中式八球" : "\(count) 球")
        }
        capture(prefix + "-settings-switched-4")
        closeMenu()
        ready(breakStrike)
        XCTAssertFalse(app.buttons["solver.nextSolution"].exists)
        XCTAssertTrue(app.staticTexts["方向"].exists)
        assertQuiet(); capture(prefix + "-racked")
        app.buttons[moreID].tap()
        XCTAssertFalse(app.buttons["silu.cancelBreak"].exists)
        XCTAssertFalse(app.buttons["planthree.cancelBreak"].exists)
        XCTAssertFalse(app.buttons["freeplay.cancelBreak"].exists)
        capture(prefix + "-settings-no-cancel")
        closeMenu()
        ready(node("break.rerack")); node("break.rerack").tap()
        ready(breakStrike); breakStrike.tap()
        assertQuiet(); capture(prefix + "-moving")
        // Natural stop must return to normal controls without another tap.
        ready(entry, timeout: 100)
        XCTAssertFalse(node("break.confirm").exists)
        if planning || silu {
            XCTAssertTrue(app.buttons["solver.nextSolution"].exists)
            XCTAssertFalse(app.staticTexts["方向"].exists)
        }
        if silu {
            XCTAssertTrue(app.buttons["silu.tool"].exists)
            XCTAssertEqual(entry.value as? String, "4 球")
            app.buttons["silu.tool"].tap()
            ready(app.buttons["silu.tool.restPoint"])
            app.buttons["silu.tool.restPoint"].tap()
            XCTAssertTrue((node("silu.layoutState").value as? String)?.contains("tool=restPoint") == true)
            app.buttons["silu.tool"].tap()
            app.buttons["silu.tool.place"].tap()
        }
        assertQuiet(); capture(prefix + "-complete")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
            let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 10), .completed)
            ready(entry); capture(prefix + "-portrait")
            entry.tap(); ready(breakStrike)
            XCTAssertFalse(app.buttons["solver.nextSolution"].exists)
            capture(prefix + "-portrait-racked")
        }
    }
    func testSilu2D() { exercise(planning: false, mode: "2D", silu: true) }
    func testSilu3D() { exercise(planning: false, mode: "3D", silu: true) }
    func testPlanThree2D() { exercise(planning: true, mode: "2D") }
    func testPlanThree3D() { exercise(planning: true, mode: "3D") }
    func testComposer2D() { exercise(planning: false, mode: "2D") }
    func testComposer3D() { exercise(planning: false, mode: "3D") }
    func testDailyGameplayName() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-v53.authenticatedProfileFixture", "-dailyClearance.resetState", "-dailyClearance.fixture=selection", "-deeplink.dailyClearance"])
        ready(app.buttons["freeplay.moreMenu"]); app.buttons["freeplay.moreMenu"].tap()
        let item = reveal("dailyClearance.changeGame")
        XCTAssertEqual(item.label, "开球玩法")
        capture("daily-settings")
        item.tap()
        XCTAssertTrue(app.staticTexts["开球玩法"].exists)
        XCTAssertFalse(app.staticTexts["临时换玩法"].exists)
        capture("daily-games")
    }
}
