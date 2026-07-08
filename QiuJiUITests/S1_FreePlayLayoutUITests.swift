import XCTest

/// 问题集合 v3 §S1 自由击球基准页布局验收：
/// - 截图核验 G3–G11（贴边 / 对齐 / 不遮挡 / 三圆圈开球按钮）；
/// - G10 断言：进袋/自由切换、进入开球模式时 `freeplay.stage` frame 零变化（球桌尺寸锁定）。
final class S1_FreePlayLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openFreePlay() -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab("打") else { return false }
        let card = app.buttons["自由击球"]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        return app.otherElements["freeplay.stage"].waitForExistence(timeout: 5)
    }

    func testFreePlayLayoutAndTableSizeLock() throws {
        guard openFreePlay() else {
            XCTFail("未能进入自由击球页")
            return
        }
        sleep(3)
        let stage = app.otherElements["freeplay.stage"]
        let framePocket = stage.frame
        snap("s1-01-freeplay-pocket")

        // 进袋 ⇄ 自由 切换：G10 球桌尺寸不变。
        let toggle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '瞄准模式'")).firstMatch
        if toggle.waitForExistence(timeout: 2) {
            toggle.tap(); sleep(2)
            snap("s1-02-freeplay-free")
            let frameFree = stage.frame
            XCTAssertEqual(frameFree.width, framePocket.width, accuracy: 0.5, "切换瞄准模式球桌宽不变（G10）")
            XCTAssertEqual(frameFree.height, framePocket.height, accuracy: 0.5, "切换瞄准模式球桌高不变（G10）")
        }

        // 进入开球模式：底栏换成开球条，G10 stage frame 仍不变。
        let breakBtn = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        if breakBtn.waitForExistence(timeout: 5) {
            breakBtn.tap(); sleep(1)
            // 玩法选择 sheet：选中式八球。
            _ = app.staticTexts["中式八球"].waitForExistence(timeout: 3)
            if app.staticTexts["中式八球"].exists { app.staticTexts["中式八球"].tap() }
            else if app.buttons["中式八球"].exists { app.buttons["中式八球"].tap() }
            sleep(2)
            snap("s1-03-freeplay-break")
            let frameBreak = stage.frame
            XCTAssertEqual(frameBreak.width, framePocket.width, accuracy: 0.5, "开球模式球桌宽不变（G10）")
            XCTAssertEqual(frameBreak.height, framePocket.height, accuracy: 0.5, "开球模式球桌高不变（G10）")
        }
    }
}
