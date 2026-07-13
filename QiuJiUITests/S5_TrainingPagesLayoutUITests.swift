import XCTest

/// 问题集合 v3 §S5 训练页布局与渲染验收截图：
/// - P4.1–P4.3 角度与打点：球桌在球库上方不遮挡、球库对齐球桌左右、黑 8 进球线黑色；
/// - P6.1–P6.4 + P7.1 2D/3D 角度训练：布局同 P4、辅助/答题在球桌右侧、假想球心红点；
/// - P5.1 角度预测：紧凑键盘不遮挡「换题 / 显示参考」；
/// - G2 台面网格提亮为灰白（0.55 alpha）。
final class S5_TrainingPagesLayoutUITests: XCTestCase {

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
        if card.waitForExistence(timeout: 4) {
            card.tap()
        } else if app.staticTexts[title].waitForExistence(timeout: 2) {
            app.staticTexts[title].tap()
        } else {
            return false
        }
        sleep(2)
        return true
    }

    /// 2D/3D 角度训练进页先弹训练设置 sheet，点「开始训练」后才出题。
    @discardableResult
    private func startAimingTrainingFromSheet() -> Bool {
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 4) {
            start.tap()
            sleep(2)
            return true
        }
        return false
    }

    /// P4.1–P4.3：角度与瞄准——默认布局（球桌上、球库下、宽度对齐）+ 黑 8 上桌进球线黑色。
    func testAngleDynamicLayout() throws {
        guard openCard(homeTab: "学", title: "角度与瞄准") else {
            XCTFail("未能进入角度与瞄准"); return
        }
        sleep(2)
        snap("s5-01-angledynamic-default")

        // P4.2/P4.3：点球库黑 8 上桌 → 进球线应为黑色虚线。
        let ball8 = app.otherElements["paletteBall_8"].firstMatch
        let ball8Alt = app.buttons["paletteBall_8"].firstMatch
        if ball8.waitForExistence(timeout: 3) {
            ball8.tap()
        } else if ball8Alt.waitForExistence(timeout: 2) {
            ball8Alt.tap()
        }
        sleep(2)
        snap("s5-02-angledynamic-black8-potline")
    }

    /// P6.1/P6.2/P6.3：2D 角度训练——布局 + 辅助/答题在球桌右侧 + 假想球心红点 + 键盘悬浮。
    func testSceneAiming2DLayout() throws {
        guard openCard(homeTab: "练", title: "2D 角度训练") else {
            XCTFail("未能进入 2D 角度训练"); return
        }
        startAimingTrainingFromSheet()
        sleep(2)
        snap("s5-03-aiming2d-layout")

        // 辅助档：假想球 + 球心红点（P6.3）。
        let assist = app.buttons["辅助"]
        if assist.waitForExistence(timeout: 4) {
            assist.tap()
            sleep(1)
            snap("s5-04-aiming2d-assist-ghost-dot")
        }

        // 答题：键盘悬浮不改变球桌高度（G10）。
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 4) {
            answer.tap()
            sleep(1)
            snap("s5-05-aiming2d-keypad-overlay")
        }
    }

    /// P7.1：3D 角度训练——底部不留空条、按钮悬浮右下。
    func testSceneAiming3DLayout() throws {
        guard openCard(homeTab: "练", title: "3D 角度训练") else {
            XCTFail("未能进入 3D 角度训练"); return
        }
        startAimingTrainingFromSheet()
        sleep(3)
        snap("s5-06-aiming3d-layout")
    }

    /// P5.1：角度预测——紧凑键盘弹出时「换题 / 显示参考」仍完整可见可点。
    func testGeometricQuizCompactKeypad() throws {
        guard openCard(homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测"); return
        }
        sleep(1)
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 4) {
            answer.tap()
            sleep(1)
        }
        snap("s5-07-geoquiz-compact-keypad")

        let changeQuestion = app.buttons["换题"]
        XCTAssertTrue(changeQuestion.waitForExistence(timeout: 3), "键盘弹出时应能看到换题按钮")
        XCTAssertTrue(changeQuestion.isHittable, "键盘不应遮挡换题按钮")
        let showReference = app.buttons["显示参考"]
        if showReference.exists {
            XCTAssertTrue(showReference.isHittable, "键盘不应遮挡显示参考按钮")
        }
    }

    /// G2：台面网格提亮——齿轮菜单开启「台面网格 4×8」后截图核验灰白网格。
    func testTableGridBrightness() throws {
        guard openCard(homeTab: "学", title: "角度与瞄准") else {
            XCTFail("未能进入角度与瞄准"); return
        }
        sleep(2)

        // 齿轮菜单是导航栏最后一个按钮（第一个是返回）。
        let navButtons = app.navigationBars.firstMatch.buttons
        func gridMenuItem() -> XCUIElement? {
            navButtons.element(boundBy: navButtons.count - 1).tap()
            usleep(800_000)
            let item = app.buttons["台面网格 4×8"]
            return item.waitForExistence(timeout: 3) ? item : nil
        }
        /// 目标状态未达成才 tap（菜单 Toggle 用 isSelected 暴露勾选态）。
        func setGrid(on: Bool) {
            guard let item = gridMenuItem() else { XCTFail("未找到台面网格开关"); return }
            if item.isSelected != on {
                item.tap()
            } else {
                // 已是目标状态：点空白处收起菜单。
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
            }
            sleep(1)
        }

        setGrid(on: true)
        sleep(1)
        snap("s5-08-table-grid-brightened")
        setGrid(on: false)   // 复原偏好，避免污染其他用例。
    }
}
