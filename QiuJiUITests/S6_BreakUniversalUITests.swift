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
