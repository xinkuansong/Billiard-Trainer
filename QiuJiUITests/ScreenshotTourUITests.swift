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

    /// 角度首页分段 Tab（学习 / 训练 / 工具，ADR-P11-08）。
    /// 用 accessibilityIdentifier 精确定位，避免「训练」与底部 Tab 重名误点。
    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        if seg.waitForExistence(timeout: 3) {
            seg.tap()
            usleep(600_000)
            return true
        }
        return false
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

        let pages: [(String, String, String)] = [
            ("学习", "瞄准原理", "a09-aiming-principle"),
            ("学习", "浅谈球感", "a11-ball-feel"),
            ("训练", "几何角度训练", "a12-geometric-quiz"),
        ]
        for (tab, label, name) in pages {
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 4) {
                sleep(2)
                snap(name)
                popBack()
                sleep(1)
            }
        }
    }

    /// 反射 / 翻袋解球器「真实反射模式」专项截图：理想态 → 切真实（叠加蓝色虚线对照 + 缩小因子滑块）→ 拉到最小因子。
    func testReflectionRealMode() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        openSolver(entry: "反射解球器")
        captureSolverRealMode(prefix: "r01-reflection")
        popBack(); sleep(1)

        openSolver(entry: "翻袋解球器")
        // 翻袋页默认袋口（左上）可能无解：逐个袋口找到有解的那个。
        ensureBankSolution()
        captureSolverRealMode(prefix: "r02-bankshot")
        popBack(); sleep(1)
    }

    /// 仅翻袋页：单独成测，规避与反射页连跑时的模拟器不稳定。
    func testBankShotRealMode() {
        sleep(3)
        openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球")
        ensureBankSolution()
        captureSolverRealMode(prefix: "r02-bankshot")
    }

    /// 仅动作库：网格缩略图 + 详情页，单独成测，用于验证 USDZ 2D 顶视渲染
    /// （网格离线烘焙 PNG `BTBakedDrillTable` + 详情页 live `DrillSceneView`）。
    func testDrillLibraryOnly() {
        sleep(3)
        tourDrillLibrary()
    }

    /// 仅走位编排台：布局回归截图（顶部信息行 + 全宽居中球桌 + 右下操作列 + 击球后状态）。
    func testPositionPlayComposerOnly() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("工具")
        _ = tapIfExists("走位编排台", timeout: 4)
        sleep(4)
        snap("pp01-composer-layout")
        if tapIfExists("击球", timeout: 4) {
            sleep(8)
            snap("pp02-after-strike")
            // 重打：应回到 pp01 的桌面与选择（目标球/袋口/角度全部恢复）。
            if tapIfExists("重打", timeout: 3) {
                sleep(3)
                snap("pp03-after-replay")
            }
        }
    }

    /// 统一设计语言回归（ADR-P11-07/08）：角度首页海报卡三分段 + 各 2D 球桌页
    /// 统一取景 / 顶部胶囊 / BTSceneFAB + 2D 瞄准训练 + 走位编排台全宽球桌。
    func testUnifiedDesignPages() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        snap("u01-angle-home-learn")
        switchAngleHomeTab("训练")
        snap("u02-angle-home-train")
        switchAngleHomeTab("工具")
        snap("u02b-angle-home-tools")

        switchAngleHomeTab("训练")
        if tapIfExists("几何角度训练", timeout: 3) {
            sleep(2)
            snap("u03-geometric-quiz-dark")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "2D 瞄准训练", navTitle: "2D 瞄准训练", homeTab: "训练") {
            sleep(3)
            snap("u03b-scene2d-aiming")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "分离角与走位", navTitle: "分离角与走位", homeTab: "工具") {
            sleep(3)
            snap("u04-shot-simulation")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "工具") {
            sleep(2)
            snap("u05-reflection")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球", homeTab: "工具") {
            sleep(2)
            snap("u06-bankshot")
            popBack(); sleep(1)
        }
    }

    /// 弹层 / 展开态核验（ADR-P11-08/09）：分离角打点盘 sheet、编排台打点盘 sheet、
    /// 反射「真实」模式滑块、角度预测左对齐指标条。
    func testScenePopups() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        if openSolverVerified(entry: "分离角与走位", navTitle: "分离角与走位", homeTab: "工具") {
            sleep(3)
            snap("p00-shotsim-bottombar")
            if tapIfExists("打点", timeout: 3) {
                sleep(2)
                snap("p01-shotsim-spinpad")
                _ = tapIfExists("关闭打点", timeout: 2)
                sleep(1)
            }
            popBack(); sleep(1)
        }

        switchAngleHomeTab("工具")
        if tapIfExists("走位编排台", timeout: 4) {
            sleep(4)
            if tapIfExists("打点", timeout: 3) {
                sleep(2)
                snap("p02-composer-spinpad")
                _ = tapIfExists("关闭打点", timeout: 2)
                sleep(1)
            }
            popBack(); sleep(1)
        }

        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "工具") {
            sleep(2)
            if app.buttons["真实"].waitForExistence(timeout: 3) {
                app.buttons["真实"].tap()
                sleep(2)
                snap("p03-reflection-real")
                _ = tapIfExists("理想", timeout: 2)
                sleep(1)
            }
            popBack(); sleep(1)
        }

        switchAngleHomeTab("训练")
        if tapIfExists("几何角度训练", timeout: 3) {
            sleep(2)
            snap("p04-quiz-capsule")
            popBack(); sleep(1)
        }
    }

    /// 收起贴底 sheet：从 sheet 顶部拖动指示条（grabber）向下拖出屏幕。
    /// 起手点不能落在 sheet 内容（如打点盘会吞掉拖动手势），也不能用
    /// `app.swipeDown()`（从屏幕中心起手落在场景区）。grabber 约在屏高 78% 处。
    private func dismissBottomSheet() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.785))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.1))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(1)
    }

    /// 进入指定解球页并**校验确实到达**（用导航标题判定），错页则返回重试。
    @discardableResult
    private func openSolverVerified(entry: String, navTitle: String,
                                    homeTab: String = "工具") -> Bool {
        for _ in 0..<3 {
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab(homeTab)
            // 首页卡片是合并 AX 标签的按钮：先按 identifier 找按钮，再退回 staticText。
            // 不查 isHittable：AX 快照偶发失败（kAXError -25218）会直接抛错中断测试。
            let card = app.buttons[entry]
            if card.waitForExistence(timeout: 4) {
                card.tap()
            } else if app.staticTexts[entry].waitForExistence(timeout: 2) {
                app.staticTexts[entry].tap()
            }
            sleep(2)
            if app.navigationBars[navTitle].waitForExistence(timeout: 3) { return true }
            popBack()   // 误入他页 → 返回重试
            sleep(1)
        }
        return false
    }

    private func openSolver(entry: String) {
        openSolverVerified(entry: entry, navTitle: entry == "翻袋解球器" ? "翻袋解球" : "反射解球器")
    }

    private var hasNoSolution: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS '暂无翻袋解'")).firstMatch.exists
    }

    private func ensureBankSolution() {
        guard hasNoSolution else { return }
        for pocket in ["右上", "左下", "右下", "上中", "下中", "左上"] {
            if tapIfExists(pocket, timeout: 2) {
                sleep(1)
                if !hasNoSolution { return }
            }
        }
    }

    private func captureSolverRealMode(prefix: String) {
        // 归一到「理想」模式（共享设置可能残留真实态）。
        if app.buttons["理想"].waitForExistence(timeout: 3) {
            app.buttons["理想"].tap()
            sleep(2)
        }
        snap("\(prefix)-ideal")

        // 切到「真实」模式（分段控件）。
        if app.buttons["真实"].waitForExistence(timeout: 3) {
            app.buttons["真实"].tap()
            sleep(2)
            // 先把因子拉回接近 1，再截「默认真实」与「最小因子」两态。
            let slider = app.sliders.firstMatch
            if slider.waitForExistence(timeout: 2) {
                slider.adjust(toNormalizedSliderPosition: 0.75)   // ≈0.95
                sleep(2)
                snap("\(prefix)-real-095")
                slider.adjust(toNormalizedSliderPosition: 0.0)    // 0.80
                sleep(2)
                snap("\(prefix)-real-min-factor")
            } else {
                snap("\(prefix)-real-default")
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

        let subPages: [(String, String, String)] = [
            ("学习", "瞄准原理", "09-angle-aiming-principle"),
            ("学习", "角度与打点", "10-angle-dynamic"),
            ("学习", "浅谈球感", "11-angle-ball-feel"),
            ("学习", "进球点对照表", "15-angle-contact-point-table"),
            ("训练", "几何角度训练", "12-angle-geometric-quiz"),
            ("训练", "2D 瞄准训练", "13-angle-scene2d-aiming"),
            ("训练", "3D 瞄准训练", "14-angle-scene3d-aiming"),
        ]
        for (tab, label, name) in subPages {
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 3) {
                sleep(2)
                snap(name)
                popBack()
                sleep(1)
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
