import XCTest

/// 问题集合 v5 批次 V5 验收截图：
/// - Q7.2 2D 瞄准点训练布局（球桌/球库/瞄准条/提交按钮走 ShotStageProxy 贴边）；
/// - Q7.4 验证击球出杆动画（提交后倒计时→运杆，抓取多帧证明球杆可见）；
/// - Q5/Q9 3D 瞄准点训练进场机位=最高 + 滑屏控制相机（横滑 yaw / 竖滑 zoom）。
final class S5_AimPointSceneV5UITests: XCTestCase {

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

    /// Q7.2 布局 + Q7.4 出杆动画（2D 瞄准点训练）。
    func testAimPointScene2D_LayoutAndCueStroke() throws {
        guard openCard(homeTab: "练", title: "2D 瞄准点训练") else {
            XCTFail("未能进入 2D 瞄准点训练"); return
        }
        sleep(2)
        snap("v5-q72-2d-aiming-layout")   // 球桌/球库/瞄准条(左)/提交(右下贴边)

        // Q9 2D：拖动 = G13 相对瞄准（在球桌上横向拖一段）。
        let scene = app.windows.firstMatch
        let c = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        c.press(forDuration: 0.05,
                thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45)))
        sleep(1)
        snap("v5-q9-2d-relative-drag-aim")

        // 提交 → 结果态（1.5s 倒计时）→ 运杆出杆。多帧抓取出杆动画（Q7.4）。
        let submit = app.buttons["提交"]
        if submit.waitForExistence(timeout: 4) {
            submit.tap()
            usleep(500_000)
            snap("v5-q73-2d-result-countdown")   // 结果态（正确红线/红点 + 「1.5 秒后自动击球验证」）
            // 倒计时 1.5s 后进入 striking；此后运杆 ~0.6s + 出杆 + 跟杆，连续抓帧。
            for i in 0..<6 {
                usleep(400_000)
                snap("v5-q74-2d-strike-\(i)")
            }
        }
    }

    /// Q5/Q9 3D：进场机位=最高 + 滑屏控制相机。
    func testAimPointScene3D_CameraDefaultsHighestAndSwipe() throws {
        guard openCard(homeTab: "练", title: "3D 瞄准点训练") else {
            XCTFail("未能进入 3D 瞄准点训练"); return
        }
        sleep(2)
        snap("v5-q5q9-3d-entry-highest")   // 每题进场默认最高机位

        let scene = app.windows.firstMatch
        // 竖滑（上滑）压低机位（Q9 竖滑 zoom 梯：进场在最高 zoom=1，上滑降 zoom）。
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.05,
                   thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        sleep(1)
        snap("v5-q9-3d-after-vertical-swipe")

        // 横滑（yaw 旋转，Q9 横滑）。
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.45))
            .press(forDuration: 0.05,
                   thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45)))
        sleep(1)
        snap("v5-q9-3d-after-horizontal-swipe")
    }
}
