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

    /// 瞄准训练入口流程（T-P18-48）：进页先弹训练设置 sheet，点「开始训练」
    /// 后才出题。返回是否成功关掉了设置 sheet。
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

    /// 通过导航返回键弹出当前推入页面（不处理 sheet）。
    private func popBack() {
        let backBtn = app.navigationBars.buttons.element(boundBy: 0)
        if backBtn.waitForExistence(timeout: 2), backBtn.isHittable {
            backBtn.tap()
            usleep(700_000)
        }
    }

    /// 角度首页分段 Tab（学 / 练 / 打 / 解，ADR-P18-01 四分段 IA）。
    /// 用 accessibilityIdentifier 精确定位，避免与底部 Tab 重名误点。
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

    /// 轻量巡游：学练四页（瞄准原理 / 浅谈球感 / 进球点对照表 / 几何角度训练=角度预测），
    /// 用于视觉打磨的快速回归，避免完整巡游的会话态/Paywall 流程拖慢并触发模拟器不稳定。
    /// T-P18-46 真台化后每页加拍一帧下滑截图，覆盖页中下部的插图卡。
    func testAngleLearningPages() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        let pages: [(String, String, String)] = [
            ("学", "瞄准原理", "a09-aiming-principle"),
            ("学", "浅谈球感", "a11-ball-feel"),
            ("学", "进球点对照表", "a10-contact-point"),
            ("练", "角度预测", "a12-geometric-quiz"),
        ]
        for (tab, label, name) in pages {
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 4) {
                sleep(3)
                snap(name)
                // 角度预测：开参考线拍一帧（核 90° 参考线 + 标签不裁切）。
                if tapIfExists("显示参考", timeout: 2) {
                    sleep(1)
                    snap("\(name)-reference")
                }
                app.swipeUp()
                sleep(1)
                snap("\(name)-scrolled")
                popBack()
                sleep(1)
            }
        }
    }

    /// 学→练导流链路（T-P18-51）：原理页末 CTA→角度预测、球感 CTA→2D 角度训练、
    /// 角度预测答题后「去真台练」、拍照建球形步骤指示 + 送入菜单、角度与打点首拖提示。
    func testLearnPracticeFlow() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        // ① 瞄准原理页末 CTA「去练一练」→ 角度预测。
        switchAngleHomeTab("学")
        if tapIfExists("瞄准原理", timeout: 4) {
            sleep(2)
            app.swipeUp(); app.swipeUp(); app.swipeUp(); app.swipeUp()
            sleep(1)
            snap("lp01-principle-cta")
            let cta = app.buttons["去练一练"]
            XCTAssertTrue(cta.waitForExistence(timeout: 3), "瞄准原理页末应有去练一练 CTA")
            cta.tap()
            sleep(2)
            XCTAssertTrue(app.navigationBars["角度预测"].waitForExistence(timeout: 5),
                          "CTA 应导航到角度预测")
            snap("lp02-cta-to-quiz")
            // ② 答一题 → 结果卡应有「去真台练」入口。
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 3) {
                field.tap()
                field.typeText("45")
                if tapIfExists("确认", timeout: 3) {
                    sleep(1)
                    app.swipeUp()
                    sleep(1)
                    snap("lp03-quiz-result-links")
                    XCTAssertTrue(app.buttons["去真台练"].waitForExistence(timeout: 3),
                                  "答题结果卡应有去真台练入口")
                }
            }
            popBack(); sleep(1)
            popBack(); sleep(1)
        }

        // ③ 浅谈球感页末 CTA「用真台验证」→ 2D 角度训练（进页先弹训练设置 sheet）。
        switchAngleHomeTab("学")
        if tapIfExists("浅谈球感", timeout: 4) {
            sleep(2)
            app.swipeUp(); app.swipeUp(); app.swipeUp(); app.swipeUp()
            sleep(1)
            let cta = app.buttons["用真台验证"]
            XCTAssertTrue(cta.waitForExistence(timeout: 3), "球感页末应有用真台验证 CTA")
            cta.tap()
            sleep(2)
            XCTAssertTrue(app.navigationBars["2D 角度训练"].waitForExistence(timeout: 5),
                          "CTA 应导航到 2D 角度训练")
            snap("lp04-ballfeel-to-2d")
            // 关掉设置 sheet 再返回（兜底默认开题后 popBack）。
            startAimingTrainingFromSheet()
            sleep(2)
            popBack(); sleep(1)
            popBack(); sleep(1)
        }

        // ④ 角度与打点：首拖提示（首次进页常驻，拖动后消失）。
        switchAngleHomeTab("学")
        if tapIfExists("角度与打点", timeout: 4) {
            sleep(3)
            snap("lp05-angledynamic-first-drag-hint")
            popBack(); sleep(1)
        }

        // ⑤ 拍照建球形：步骤指示（第 1 步 / 共 4 步）。
        switchAngleHomeTab("打")
        if tapIfExists("拍照建球形", timeout: 4) {
            sleep(2)
            XCTAssertTrue(app.staticTexts["第 1 步 / 共 4 步 · 选择照片"].waitForExistence(timeout: 3),
                          "拍照建球形应显示步骤指示")
            snap("lp06-extraction-step-indicator")
            popBack(); sleep(1)
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
        openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球器")
        ensureBankSolution()
        captureSolverRealMode(prefix: "r02-bankshot")
    }

    /// 仅动作库：网格缩略图 + 详情页，单独成测，用于验证 USDZ 2D 顶视渲染
    /// 临时验收：drill_c042 序列出片接入效果（详情页视频 + 图文精讲，ADR-P11-14 demo）。
    func testDrillC042TutorialDemo() {
        sleep(3)
        app.switchTab(.drillLibrary)
        sleep(2)

        let search = app.textFields["搜索动作"]
        if search.waitForExistence(timeout: 4) {
            search.tap()
            search.typeText("蛇彩")
            sleep(2)
        }
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c042'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "未找到 drill_c042 卡片")
        card.tap()
        sleep(3)
        snap("c042-01-detail-top")

        app.scrollDown(times: 2)
        sleep(1)
        snap("c042-02-detail-video")

        if tapIfExists("查看精讲") {
            sleep(2)
            snap("c042-03-tutorial-top")
            for i in 4...8 {
                app.scrollDown(times: 1)
                usleep(800_000)
                snap("c042-0\(i)-tutorial-scroll")
            }
        }
    }

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
        switchAngleHomeTab("打")
        _ = tapIfExists("走位编排台", timeout: 4)
        sleep(4)
        snap("pp01-composer-layout")
        if tapIfExists("击球", timeout: 4) {
            sleep(8)
            snap("pp02-after-strike")
            // 上一杆（条 15.6 文字按钮）：应回到 pp01 的桌面与选择（目标球/袋口/角度全部恢复）。
            if tapIfExists("上一杆", timeout: 3) {
                sleep(3)
                snap("pp03-after-undo")
            }
        }
        // 4x8 台面网格（条 16）：设置菜单开启后截图，再关闭还原。
        let more = app.navigationBars.buttons["更多"].exists
            ? app.navigationBars.buttons["更多"]
            : app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if more.waitForExistence(timeout: 3) {
            more.tap()
            if tapIfExists("台面网格 4×8", timeout: 3) {
                sleep(1)
                snap("pp04-table-grid-on")
                more.tap()
                _ = tapIfExists("台面网格 4×8", timeout: 3)
            }
        }
    }

    /// 统一设计语言回归（ADR-P11-07/08 / ADR-P18-01）：角度首页海报卡四分段（学/练/打/解）
    /// + 各 2D 球桌页统一取景 / 顶部胶囊 / BTSceneFAB + 瞄准训练（合并卡，默认 2D）+ 走位编排台全宽球桌。
    func testUnifiedDesignPages() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        snap("u01-angle-home-learn")
        switchAngleHomeTab("练")
        snap("u02-angle-home-train")
        switchAngleHomeTab("打")
        snap("u02b-angle-home-play")
        switchAngleHomeTab("解")
        snap("u02c-angle-home-solve")

        switchAngleHomeTab("练")
        if tapIfExists("角度预测", timeout: 3) {
            sleep(2)
            snap("u03-geometric-quiz-dark")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "2D 角度训练", navTitle: "2D 角度训练", homeTab: "练") {
            snap("u03b-scene-aiming-settings")
            startAimingTrainingFromSheet()
            sleep(2)
            snap("u03b-scene-aiming-2d")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "分离角与走位", navTitle: "分离角与走位", homeTab: "打") {
            sleep(3)
            snap("u04-shot-simulation")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "解") {
            sleep(2)
            snap("u05-reflection")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球器", homeTab: "解") {
            sleep(2)
            snap("u06-bankshot")
            popBack(); sleep(1)
        }
    }

    /// P18 B2 专项截图：统一 `ShotControlBar` 换装（A 类可编辑 / B 类只读）+ 分离角手动瞄准
    /// + 自由击球入口 + B 类三页「试打」跳自由击球（带球局快照）。
    func testB2ShotControls() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        // 分离角：自动态底栏 → 切「手动」（chip + 角度齿轮 + 虚线对照）。
        if openSolverVerified(entry: "分离角与走位", navTitle: "分离角与走位", homeTab: "打") {
            sleep(3)
            snap("b2-01-shotsim-auto")
            if tapIfExists("手动", timeout: 3) {
                sleep(3)
                snap("b2-02-shotsim-manual")
                _ = tapIfExists("自动", timeout: 2)
                sleep(1)
            }
            popBack(); sleep(1)
        }

        // 自由击球入口卡 → 编排台自由模式（角度齿轮 + 首碰读数胶囊）。
        switchAngleHomeTab("打")
        if tapIfExists("自由击球", timeout: 4) {
            sleep(4)
            snap("b2-03-freeplay-composer")
            popBack(); sleep(1)
        }

        // 内置开球（T-P18-47，替代球形生成器页）：编排台球库行「开球」入口 →
        // 玩法选择 sheet → 摆架 → 真实物理开球散局落座。
        switchAngleHomeTab("打")
        if tapIfExists("走位编排台", timeout: 4) {
            sleep(4)
            let entry = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
            if entry.waitForExistence(timeout: 3) {
                entry.tap()
                sleep(2)
                snap("b2-04a-break-picker")
                if tapIfExists("9 球", timeout: 3) {
                    sleep(3)
                    snap("b2-04b-break-racked")
                    let strike = app.descendants(matching: .any)
                        .matching(NSPredicate(format: "identifier == 'break.strike'")).firstMatch
                    if strike.waitForExistence(timeout: 3) {
                        strike.tap()
                        sleep(9)   // 求解 + 运杆 + 散局动画 + 落座
                        snap("b2-04c-break-settled")
                    }
                }
            }
            popBack(); sleep(1)
        }

        // B 类三页：只读控制条 + 「试打」→ 编排台自由模式带球局快照。
        let solvers: [(String, String, String)] = [
            ("思路训练", "思路训练", "b2-05-silu"),
            ("打一走二想三", "打一走二想三", "b2-06-planthree"),
            ("做斯诺克", "做斯诺克", "b2-07-snooker"),
        ]
        for (entry, nav, name) in solvers {
            if openSolverVerified(entry: entry, navTitle: nav, homeTab: "解") {
                sleep(3)
                snap(name)
                // 内置开球入口（T-P18-47）：思路/三杆也有球库行「开球」块 → 摆架 → 取消恢复。
                let breakEntry = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
                if breakEntry.waitForExistence(timeout: 2), breakEntry.isHittable {
                    breakEntry.tap()
                    sleep(1)
                    let nine = app.descendants(matching: .any)
                        .matching(NSPredicate(format: "identifier == 'break.game.9'")).firstMatch
                    if nine.waitForExistence(timeout: 3) {
                        nine.tap()
                        sleep(3)
                        snap("\(name)-break-racked")
                        _ = tapIfExists("取消", timeout: 3)   // 取消恢复进场前桌面
                        sleep(2)
                    }
                }
                if tapIfExists("试打", timeout: 3) {
                    sleep(4)
                    snap("\(name)-tryplay")
                    popBack(); sleep(1)   // 编排台 → B 类页
                }
                popBack(); sleep(1)       // B 类页 → 首页
            }
        }
    }

    /// P18 B3 风格收口专项截图：带 spin drill 详情回放（打点指示器换 BTSpinMiniIcon 单一真源）
    /// + 几何角度训练（场景页胶囊按钮对齐）+ BTIcon 迁移页（训练首页/历史/我的）。
    func testB3StyleGate() {
        sleep(3)

        // 1) 杆法类带 spin drill：详情打点/力度指示器 + 回放中帧。
        app.switchTab(.drillLibrary)
        sleep(3)
        let sidebar = app.buttons["sidebar_杆法训练"]
        if sidebar.waitForExistence(timeout: 4) { sidebar.tap() }
        sleep(1)
        let spinDrills: [(String, String)] = [
            ("drill_c003", "b3-00-drill-c003"),
            ("drill_c004", "b3-01-drill-c004"), ("drill_c017", "b3-02-drill-c017"),
        ]
        for (id, name) in spinDrills {
            let card = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'drillCard_\(id)'")).firstMatch
            guard card.waitForExistence(timeout: 4) else { continue }
            var scrolls = 0
            while !card.isHittable, scrolls < 4 {
                app.scrollDown(times: 1); sleep(1); scrolls += 1
            }
            guard card.isHittable else { continue }
            card.tap()
            sleep(4)
            snap("\(name)-detail")
            let play = app.buttons["drillPlayButton"]
            if play.waitForExistence(timeout: 3) {
                play.tap()
                sleep(3)
                snap("\(name)-playing")
                sleep(6)
            }
            popBack(); sleep(1)
        }

        // 2) 几何角度训练：输入卡（确认胶囊）→ 作答 → 结果卡（下一题胶囊）。
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("练")
        if tapIfExists("角度预测", timeout: 4) {
            sleep(2)
            snap("b3-04-geoquiz-input")
            if app.keys["4"].waitForExistence(timeout: 3) {
                app.keys["4"].tap()
                app.keys["5"].tap()
            }
            _ = tapIfExists("确认", timeout: 3)
            sleep(1)
            snap("b3-05-geoquiz-result")
            popBack(); sleep(1)
        }

        // 3) BTIcon 迁移第一批页面：训练首页 / 历史 / 我的（图标渲染回归）。
        app.switchTab(.training); sleep(2); snap("b3-06-training-home")
        app.switchTab(.history); sleep(2); snap("b3-07-history")
        app.switchTab(.profile); sleep(2); snap("b3-08-profile")
    }

    /// P18 B3+ 验收门截图：合并瞄准训练卡（2D/3D 切换、3D 黑带排查）、角度与打点文字朝向、
    /// 翻袋/反射顶部两行收口、编排台默认标题、拍照建球形绿标题、
    /// 思路训练器齿轮/省略号分工、入口副标题。
    func testB3PlusGate() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        // 入口副标题（练/打/解三分段首页）。
        switchAngleHomeTab("练"); snap("b3p-01-home-train")
        switchAngleHomeTab("打"); snap("b3p-02-home-play")
        switchAngleHomeTab("解"); snap("b3p-03-home-solve")

        // 2D / 3D 拆两卡（T-P18-48）：各自入口先弹设置再开始，成绩分记。
        if openSolverVerified(entry: "2D 角度训练", navTitle: "2D 角度训练", homeTab: "练") {
            startAimingTrainingFromSheet()
            sleep(2)
            snap("b3p-04-aiming-2d")
            // 辅助档：§1.2 统一线语言（瞄准线/进球线/90° 短虚线/接触点），无数值角弧。
            if tapIfExists("辅助", timeout: 3) {
                sleep(2)
                snap("b3p-04b-aiming-2d-assist")
            }
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "3D 角度训练", navTitle: "3D 角度训练", homeTab: "练") {
            startAimingTrainingFromSheet()
            sleep(3)
            snap("b3p-05-aiming-3d")
            popBack(); sleep(1)
        }

        // 角度与打点：瞄准线/进球线文字朝向复现（T-P18-35）。
        switchAngleHomeTab("学")
        if tapIfExists("角度与打点", timeout: 4) {
            sleep(3)
            snap("b3p-06-angle-dynamic")
            popBack(); sleep(1)
        }

        // 翻袋/反射：顶部 ≤2 行 + 浮层解 pill + 内联发力（T-P18-32）。
        if openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球器", homeTab: "解") {
            sleep(2)
            snap("b3p-07-bankshot-ideal")
            if tapIfExists("真实", timeout: 3) {
                sleep(4)
                snap("b3p-08-bankshot-real")
            }
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "解") {
            sleep(2)
            snap("b3p-09-reflection-ideal")
            popBack(); sleep(1)
        }

        // 思路训练：右上角单一省略号菜单（求解范围 + 显示 + 桌面操作，条 21.6）。
        if openSolverVerified(entry: "思路训练", navTitle: "思路训练", homeTab: "解") {
            sleep(2)
            snap("b3p-10-silu-toolbar")
            popBack(); sleep(1)
        }

        // 自由走位：默认标题不显「未命名走位」（T-P18-37）。
        switchAngleHomeTab("打")
        if tapIfExists("自由走位", timeout: 4) {
            sleep(3)
            snap("b3p-12-composer-title")
            popBack(); sleep(1)
        }

        // 拍照建球形：principal 品牌绿标题（T-P18-31）。
        switchAngleHomeTab("打")
        if tapIfExists("拍照建球形", timeout: 4) {
            sleep(2)
            snap("b3p-13-ballextract-title")
            popBack(); sleep(1)
        }
    }

    /// 弹层 / 展开态核验（ADR-P11-08/09）：分离角打点盘 sheet、编排台打点盘 sheet、
    /// 反射「真实」模式滑块、角度预测左对齐指标条。
    func testScenePopups() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        if openSolverVerified(entry: "分离角与走位", navTitle: "分离角与走位", homeTab: "打") {
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

        switchAngleHomeTab("打")
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

        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "解") {
            sleep(2)
            if app.buttons["真实"].waitForExistence(timeout: 3) {
                app.buttons["真实"].tap()
                sleep(2)
                snap("p03-reflection-real")
                _ = tapIfExists("理想", timeout: 2)
                sleep(1)
            }
            // 原理 sheet 暗材质核验（T-P18-49，§1.6 Z7 浮出层）。
            if tapIfExists("原理", timeout: 3) {
                sleep(2)
                snap("p03b-reflection-info-dark")
                _ = tapIfExists("完成", timeout: 2)
                sleep(1)
            }
            popBack(); sleep(1)
        }

        switchAngleHomeTab("练")
        if tapIfExists("角度预测", timeout: 3) {
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
                                    homeTab: String = "解") -> Bool {
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
        openSolverVerified(entry: entry, navTitle: entry == "翻袋解球器" ? "翻袋解球器" : "反射解球器")
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

    // MARK: 角度 Tab（含 学/练 分段子页；打/解 沙盘与解球页由专项测试覆盖）

    private func tourAngle() {
        app.switchTab(.angle)
        sleep(2)
        snap("08-angle-home")

        let subPages: [(String, String, String)] = [
            ("学", "瞄准原理", "09-angle-aiming-principle"),
            ("学", "角度与打点", "10-angle-dynamic"),
            ("学", "浅谈球感", "11-angle-ball-feel"),
            ("学", "进球点对照表", "15-angle-contact-point-table"),
            ("练", "角度预测", "12-angle-geometric-quiz"),
            ("练", "2D 角度训练", "13-angle-scene-aiming"),
        ]
        for (tab, label, name) in subPages {
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 3) {
                sleep(2)
                // 瞄准训练入口先弹设置 sheet（T-P18-48）：关掉再截训练态。
                startAimingTrainingFromSheet()
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
