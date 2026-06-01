import XCTest

/// 全页面截图巡游。
/// 依次进入 5 个 Tab 及主要子页面，逐页捕获 `XCUIScreen.main.screenshot()` 为 keepAlways 附件。
/// 设计原则：
/// - 非破坏性的「推入式」子页面（NavigationLink push）先遍历，遍历后用导航返回键回到根。
/// - 会弹出 sheet / 进入会话态的流程（自由记录、订阅 Paywall）放在最后，避免污染后续页面。
/// - 全程防御式点击（存在才点），缺失则跳过，不阻塞整体巡游。
/// 截图通过 `-resultBundlePath` 落入 .xcresult，再用 xcresulttool 导出 PNG。
final class ScreenshotTourUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    // MARK: - Helpers

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func tapIfExists(_ label: String, timeout: TimeInterval = 4) -> Bool {
        let staticText = app.staticTexts[label]
        if staticText.waitForExistence(timeout: timeout) {
            staticText.tap()
            return true
        }
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 1) {
            button.tap()
            return true
        }
        return false
    }

    /// 通过导航返回键弹出当前推入页面（不处理 sheet）。
    private func popBack() {
        let backBtn = app.navigationBars.buttons.element(boundBy: 0)
        if backBtn.waitForExistence(timeout: 2), backBtn.isHittable {
            backBtn.tap()
            usleep(700_000)
        }
    }

    // MARK: - The Tour

    func testFullScreenshotTour() {
        sleep(3)
        snap("00-launch")

        tourTraining()
        tourDrillLibrary()
        tourAngle()
        tourHistory()
        tourProfile()

        // 破坏性 / sheet 流程放最后
        tourModalFlows()
    }

    /// 轻量巡游：仅角度模块的三个学习/训练页（瞄准原理 / 浅谈球感 / 几何角度训练），
    /// 用于视觉打磨的快速回归，避免完整巡游的会话态/Paywall 流程拖慢并触发模拟器不稳定。
    func testAngleLearningPages() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        let pages: [(String, String)] = [
            ("瞄准原理", "a09-aiming-principle"),
            ("浅谈球感", "a11-ball-feel"),
            ("几何角度训练", "a12-geometric-quiz"),
        ]
        for (label, name) in pages {
            if tapIfExists(label, timeout: 4) {
                sleep(2)
                snap(name)
                popBack()
                sleep(1)
            }
        }
    }

    // MARK: 训练 Tab（非破坏性部分）

    private func tourTraining() {
        app.switchTab(.training)
        sleep(2)
        snap("01-training-home")

        // 自定义模版分段
        if tapIfExists("自定义模版", timeout: 2) || tapIfExists("自定义", timeout: 1) {
            sleep(1)
            snap("02-training-custom-tab")
            _ = tapIfExists("官方计划", timeout: 2)
            sleep(1)
        }

        // 顶部菜单进入训练计划列表
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")).firstMatch
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
            sleep(1)
            if app.buttons["训练计划"].waitForExistence(timeout: 2) {
                app.buttons["训练计划"].tap()
                sleep(2)
                snap("03-plan-list")
                popBack()
            } else {
                app.tap() // 关闭菜单
            }
        }

        // 直接从首页计划卡片进入计划详情
        let planCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '新手入门' OR label CONTAINS '基础杆法' OR label CONTAINS '第 1 期'")).firstMatch
        if planCard.waitForExistence(timeout: 3) {
            planCard.tap()
            sleep(2)
            snap("04-plan-detail")
            popBack()
        }
        app.switchTab(.training)
        sleep(1)
    }

    // MARK: 动作库 Tab

    private func tourDrillLibrary() {
        app.switchTab(.drillLibrary)
        sleep(3)
        snap("05-drill-library")

        let drillCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
        if drillCard.waitForExistence(timeout: 4) {
            drillCard.tap()
        } else {
            let cell = app.cells.firstMatch
            if cell.waitForExistence(timeout: 4) { cell.tap() }
        }
        sleep(3)
        snap("06-drill-detail-top")
        app.scrollDown(times: 2)
        sleep(1)
        snap("07-drill-detail-bottom")
        popBack()
        sleep(1)
    }

    // MARK: 角度 Tab（含全部学习/训练/工具子页）

    private func tourAngle() {
        app.switchTab(.angle)
        sleep(2)
        snap("08-angle-home")

        let subPages: [(String, String)] = [
            ("瞄准原理", "09-angle-aiming-principle"),
            ("角度与打点", "10-angle-dynamic"),
            ("浅谈球感", "11-angle-ball-feel"),
            ("几何角度训练", "12-angle-geometric-quiz"),
            ("2D 瞄准训练", "13-angle-scene2d-aiming"),
            ("3D 瞄准训练", "14-angle-scene3d-aiming"),
            ("进球点对照表", "15-angle-contact-point-table"),
        ]
        for (label, name) in subPages {
            if tapIfExists(label, timeout: 3) {
                sleep(2)
                snap(name)
                popBack()
                sleep(1)
            } else {
                // 子页可能在滚动区域下方，向下滚动后再试
                app.scrollDown(times: 1)
                sleep(1)
                if tapIfExists(label, timeout: 2) {
                    sleep(2)
                    snap(name)
                    popBack()
                    sleep(1)
                }
            }
        }
    }

    // MARK: 记录 Tab

    private func tourHistory() {
        app.switchTab(.history)
        sleep(2)
        snap("16-history-calendar")

        let statsAny = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '统计'")).firstMatch
        if statsAny.waitForExistence(timeout: 3) {
            statsAny.tap()
            sleep(2)
            snap("17-history-statistics")
        }
    }

    // MARK: 我的 Tab（含推入式子页）

    private func tourProfile() {
        app.switchTab(.profile)
        sleep(3)
        snap("18-profile-top")
        app.scrollDown(times: 3)
        sleep(1)
        snap("19-profile-scrolled")
        app.scrollUp(times: 4)
        sleep(1)

        let subPages: [(String, String)] = [
            ("个人信息", "20-profile-personal-info"),
            ("训练目标", "21-profile-training-goal"),
            ("偏好设置", "22-profile-settings"),
            ("关于与反馈", "23-profile-about"),
        ]
        for (label, name) in subPages {
            app.switchTab(.profile)
            sleep(1)
            if !tapIfExists(label, timeout: 2) {
                app.scrollDown(times: 2)
                sleep(1)
                _ = tapIfExists(label, timeout: 2)
            }
            sleep(2)
            // 仅当进入了导航页（出现返回键）才截图，避免误截
            if app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 2) {
                snap(name)
                popBack()
                sleep(1)
            }
        }
    }

    // MARK: 弹窗 / 会话态流程（放最后）

    private func tourModalFlows() {
        // 订阅 Paywall
        app.switchTab(.profile)
        sleep(1)
        app.scrollUp(times: 4)
        sleep(1)
        if tapIfExists("解锁球迹 Pro", timeout: 2) || tapIfExists("升级 Pro", timeout: 2) || tapIfExists("订阅管理", timeout: 2) {
            sleep(3)
            snap("24-subscription-paywall")
            // 等待产品加载超时（8s）后捕获错误/重试兜底态（U-04）
            sleep(8)
            snap("25-subscription-paywall-timeout")
            app.swipeDown()
            sleep(1)
        }

        // 自由记录 → 进入训练会话（含 drill picker sheet）
        app.switchTab(.training)
        sleep(2)
        if tapIfExists("自由记录", timeout: 3) {
            sleep(2)
            snap("25-free-record-session")
        }
    }
}
