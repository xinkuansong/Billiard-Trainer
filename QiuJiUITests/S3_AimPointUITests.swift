import XCTest

/// 问题集合 v3 §S3 瞄准点概念修正（G1）验收截图：
/// - 瞄准点训练页（P8.1–P8.6：水平线 / 无假想球红点 / 红色小瞄准点 / 占比放大 / 统计单行）；
/// - 2D 瞄准点训练页（P9.1：G1 垂线随瞄准线旋转 + 提交后正确瞄准点红点）；
/// - 瞄准原理页（G1 名词与配图口径）。
final class S3_AimPointUITests: XCTestCase {

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

    private func openCard(homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(2)
        return true
    }

    /// P8：瞄准点训练页——出题态 + 提交后结果态。
    func testAimPointTrainingLayout() throws {
        guard openCard(homeTab: "练", title: "瞄准点训练") else {
            XCTFail("未能进入瞄准点训练"); return
        }
        sleep(1)
        snap("s3-01-aimpoint-training-aiming")

        let submit = app.buttons["提交瞄准点"]
        if submit.waitForExistence(timeout: 4) {
            submit.tap()
            sleep(1)
            snap("s3-02-aimpoint-training-result")
        }
    }

    /// P9.1：2D 瞄准点训练——瞄准态（G1 垂线）+ 提交后（红线 + 正确瞄准点红点）。
    func testAimPointScene2DLayout() throws {
        guard openCard(homeTab: "练", title: "2D 瞄准点训练") else {
            XCTFail("未能进入 2D 瞄准点训练"); return
        }
        sleep(2)
        snap("s3-03-aimpoint-2d-aiming")

        let submit = app.buttons["提交"]
        if submit.waitForExistence(timeout: 4) {
            submit.tap()
            sleep(1)
            snap("s3-04-aimpoint-2d-result")
        }
    }

    /// G1 文档：瞄准原理页名词系统配图（垂线 + 垂足红点）。
    func testAimingPrincipleG1Figure() throws {
        guard openCard(homeTab: "学", title: "瞄准原理") else {
            XCTFail("未能进入瞄准原理"); return
        }
        sleep(2)
        snap("s3-05-aiming-principle-terms")
    }
}
