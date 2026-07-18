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

    /// 截图目录：优先 `UI_POLISH_SHOT_DIR`；否则按外观写入
    /// `docs/ui-polish/screenshots-latest/{light|dark}/`。
    private var shotDirURL: URL? {
        if let env = ProcessInfo.processInfo.environment["UI_POLISH_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        let fileMode = (try? String(contentsOfFile: "/tmp/qiuji-uitest/appearance", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let mode: String
        if fileMode == "light" || fileMode == "dark" {
            mode = fileMode!
        } else {
            switch XCUIDevice.shared.appearance {
            case .light: mode = "light"
            case .dark:  mode = "dark"
            @unknown default: mode = "unknown"
            }
        }
        let base = "/Users/song/projects/13.billiard_trainer/docs/ui-polish/screenshots-latest"
        return URL(fileURLWithPath: "\(base)/\(mode)", isDirectory: true)
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // 同步写命名 PNG，便于直接落入 docs/ui-polish（不依赖 xcresult 二次导出）。
        if let dir = shotDirURL {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: file)
        }
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
        // 外观不在测试内切换（反复设 XCUIDevice.appearance 易把 Runner 打崩）。
        // 请事先：`xcrun simctl ui booted appearance light|dark`，并用
        // `echo light|dark > /tmp/qiuji-uitest/appearance` 告知 snap 落盘子目录。
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

    /// 分段补拍：每页软重启。外观靠事先 `simctl ui appearance` + `/tmp/qiuji-uitest/appearance`。
    func testScreenshotTourPlaySolveRemainder() {
        sleep(2)

        let pages: [(String, String, String)] = [
            ("练", "3D 瞄准点训练", "18-aimpoint-scene-3d"),
            ("打", "分离角与走位", "19-shot-simulation"),
            ("打", "自由走位", "20-position-play-composer"),
            ("打", "自由击球", "21-free-play"),
            ("打", "拍照建球形", "22-ball-extraction"),
            ("打", "批量出片台", "23-batch-drill-studio"),
            ("解", "思路训练", "24-silu-trainer"),
            ("解", "打一走二想三", "25-plan-three"),
            ("解", "防守", "26-snooker-tactics"),
            ("解", "翻袋解球器", "27-bank-shot"),
            ("解", "反射解球器", "28-diamond-system"),
        ]
        for (tab, label, name) in pages {
            app.terminate()
            app = XCUIApplication.launchClean()
            sleep(2)
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 4) {
                sleep(3)
                startAimingTrainingFromSheet()
                if label == "翻袋解球器" { ensureBankSolution() }
                snap(name)
            }
        }

        app.terminate()
        app = XCUIApplication.launchClean()
        sleep(2)
        tourHistory()
        tourProfile()
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
            ("学", "瞄准方法", "a13-aiming-methods"),
            ("学", "瞄准修正", "a16-aiming-correction"),
            ("学", "旋转与加塞", "a14-spin-and-english"),
            ("学", "分离角图谱", "a15-separation-angle-atlas"),
            ("学", "浅谈球感", "a11-ball-feel"),
            ("学", "瞄准点对照表", "a10-contact-point"),
            ("练", "角度预测", "a12-geometric-quiz"),
        ]
        for (tab, label, name) in pages {
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 4) {
                sleep(3)
                snap(name)
                // 分离角图谱为场景交互页（非长文滚动）：额外等轨迹算完再拍默认态。
                if name == "a15-separation-angle-atlas" {
                    sleep(2)
                    snap("\(name)-default")
                    popBack()
                    sleep(1)
                    continue
                }
                // 角度预测：开参考线拍一帧（核 90° 参考线 + 标签不裁切）。
                if tapIfExists("显示参考", timeout: 2) {
                    sleep(1)
                    snap("\(name)-reference")
                }
                app.swipeUp()
                sleep(1)
                snap("\(name)-scrolled")
                // 页底第三帧：核验页尾插图卡（P2.1 全宽 2D 图 / 对照表估角图等）。
                app.swipeUp()
                sleep(1)
                snap("\(name)-scrolled2")
                // 瞄准方法页（v11 Y1 r1）交互化后更长：补两帧盖平行线主图/
                // Mosconi 变体/重合比例补充节/相关页面。
                if name == "a13-aiming-methods" {
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled3")
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled4")
                }
                // 瞄准修正（v12 Z3）：六节长页，补帧盖④加塞 / ⑤求解对比+速查 / ⑥实战启示。
                if name == "a16-aiming-correction" {
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled3")
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled4")
                }
                // 旋转与加塞（v12 Z4）：页更长——补帧盖打点节 / 吃库反弹 / 瞄准修正 CTA / 相关页面。
                if name == "a14-spin-and-english" {
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled3")
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled4")
                    app.swipeUp()
                    sleep(1)
                    snap("\(name)-scrolled5")
                }
                popBack()
                sleep(1)
            }
        }
    }

    /// v11 Y3：分离角图谱交互取证——默认态 / 拉高力度 / 拖球改切角。
    func testSeparationAngleAtlasInteractions() {
        // SceneKit 叠层下合成拖力度柱不可靠 → 启用页内 UI 测钩子（`-y3.uiHooks`）。
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-y3.uiHooks"])
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("学")
        sleep(1)
        guard tapIfExists("分离角图谱", timeout: 4) else {
            XCTFail("分离角图谱卡不可达")
            return
        }
        sleep(4) // 等 8 路并行 simulateFree
        snap("y3-atlas-default")

        // 性能取证：抽取最近一次 8×simulateFree 并行实测耗时（钩子读数）。
        let simMs = app.staticTexts["y3.parallelSimMs"]
        if simMs.waitForExistence(timeout: 3) {
            print("[Y3-PERF] 8×simulateFree parallel \(simMs.label) ms (default scene, velocity 1.5)")
        }

        // 拉高力度（钩子设 5.5）→ 轨迹应随力度更新；顶栏读数离开 1.5。
        // 用 label「高力度」定位（根视图 AX id 勿盖住子控件 identifier）。
        let bump = app.buttons["高力度"]
        XCTAssertTrue(bump.waitForExistence(timeout: 3), "y3.uiHooks「高力度」钩子不可达")
        bump.tap()
        sleep(5)
        snap("y3-atlas-high-power")
        XCTAssertTrue(app.staticTexts["5.5"].waitForExistence(timeout: 4),
                      "拉高力度后应出现读数 5.5（顶栏或仪表柱）")
        if simMs.exists {
            print("[Y3-PERF] 8×simulateFree parallel \(simMs.label) ms (after bump, velocity 5.5)")
        }

        // 拖台面中部附近的球（改切角）→ 轨迹重算。
        let table = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'separationAngleAtlas.root'")).firstMatch
        if table.waitForExistence(timeout: 2) {
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.48))
            let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.42))
            start.press(forDuration: 0.2, thenDragTo: end)
            sleep(3)
            snap("y3-atlas-drag-cut")
        }

        // 打开只读 8 点打点盘。
        let spinMini = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '打点'")).firstMatch
        if spinMini.waitForExistence(timeout: 2), spinMini.isHittable {
            spinMini.tap()
            sleep(1)
            snap("y3-atlas-spin-pad")
        }

        XCTAssertEqual(app.state, .runningForeground, "交互后 App 应仍在前台")
    }

    /// v11 Y1 返工 r1（FL-026）：瞄准方法页交互取证——管道节三态
    /// （默认 φ=θ=30° 相切 / 拖到 5° 太厚 / 拖到 75° 太薄）+ 接触点碰合动画起终帧。
    func testAimingMethodsInteractions() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("学")
        sleep(1)
        guard tapIfExists("瞄准方法", timeout: 4) else {
            XCTFail("瞄准方法卡不可达")
            return
        }
        sleep(3)

        // 管道节：页面顶端已可见插图+徽章，小步上滚让底部滑杆离开 Home 指示条
        // 区域（上一轮教训：滑杆贴屏幕底缘时 adjust 合成拖拽会误触系统手势）。
        let phiSlider = app.sliders["aimingMethods.pipe.trialSlider"]
        dragScrollUp(0.22)
        if phiSlider.waitForExistence(timeout: 4), phiSlider.isHittable {
            snap("y1r1-pipe-tangent") // 默认 φ=θ=30 → ✓相切徽章
            phiSlider.adjust(toNormalizedSliderPosition: 0.0) // φ=5 < θ → 太厚
            sleep(1)
            snap("y1r1-pipe-thick")
            phiSlider.adjust(toNormalizedSliderPosition: 1.0) // φ=75 > θ → 太薄
            sleep(1)
            snap("y1r1-pipe-thin")
            XCTAssertEqual(app.state, .runningForeground, "adjust 后 App 应仍在前台")
        } else {
            XCTFail("试瞄滑杆不可达或不可点击")
        }

        // 接触点节：滚到播放键可点击，且其上方插图不被裁切，拍起点/碰合两帧。
        let play = app.buttons["aimingMethods.contact.play"]
        var guardCount = 0
        while (!play.exists || !play.isHittable || play.frame.minY > 800), guardCount < 8 {
            dragScrollUp(0.30)
            guardCount += 1
        }
        if play.exists, play.frame.minY < 430 { // 插图顶被裁：回滚一点
            dragScrollUp(-0.15)
        }
        if play.waitForExistence(timeout: 3), play.isHittable {
            snap("y1r1-contact-start")
            play.tap()
            sleep(2) // 动画 1.2s
            snap("y1r1-contact-merged")
        } else {
            XCTFail("碰合播放键不可达")
        }
    }

    /// 受控小步滚动（正值向上滚 dy·屏高，负值向下），避开系统边缘手势。
    private func dragScrollUp(_ dyNormalized: CGFloat) {
        let scroll = app.scrollViews.firstMatch
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.60))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.60 - dyNormalized))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: 300, thenHoldForDuration: 0.4)
        usleep(500_000)
    }

    /// 问题集合 v5 V4 学习/训练页轻修取证：Q1 卡片字号、Q2 改名、Q3 对照表标签
    /// 0°/90° 最坏帧、Q4 角度预测 90° 最坏帧、Q6 瞄准点训练线宽/红点。
    func testV4Evidence() {
        sleep(3)

        // Q1：训练计划卡标题字号（planPosterCard）。
        app.switchTab(.training)
        sleep(2)
        snap("v4-q1-training-home")

        // Q1/Q2：练习页学分类卡（角度与瞄准 改名 + AngleGridCard 标题字号）。
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("学")
        sleep(1)
        snap("v4-q1q2-angle-learn-cards")

        // Q3：瞄准点对照表——拖角度滑条到 0° 与 90° 最坏帧，核验两标签不遮挡球。
        if tapIfExists("瞄准点对照表", timeout: 4) {
            sleep(2)
            let angleSlider = app.sliders.element(boundBy: 0)
            if angleSlider.waitForExistence(timeout: 3) {
                angleSlider.adjust(toNormalizedSliderPosition: 0.0)
                sleep(1)
                snap("v4-q3-contact-table-0deg")
                angleSlider.adjust(toNormalizedSliderPosition: 1.0)
                sleep(1)
                snap("v4-q3-contact-table-90deg")
                angleSlider.adjust(toNormalizedSliderPosition: 0.5)
                sleep(1)
                snap("v4-q3-contact-table-45deg")
            }
            popBack(); sleep(1)
        }

        // Q6：瞄准点训练——默认帧 + 提交后（正确红线/红点）帧。
        switchAngleHomeTab("练")
        sleep(1)
        if tapIfExists("瞄准点训练", timeout: 4) {
            sleep(2)
            snap("v4-q6-aimpoint-training-default")
            if tapIfExists("提交瞄准点", timeout: 3) {
                sleep(1)
                snap("v4-q6-aimpoint-training-result")
            }
            popBack(); sleep(1)
        }

        // Q4：角度预测 90° 最坏帧（确定性 forcedAngle 注入后重启）。
        app.terminate()
        app.launchArguments += ["-geometricQuiz.forcedAngle", "90"]
        app.launch()
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("练")
        sleep(1)
        if tapIfExists("角度预测", timeout: 4) {
            sleep(2)
            snap("v4-q4-angle-prediction-90deg")
            if tapIfExists("显示参考", timeout: 2) {
                sleep(1)
                snap("v4-q4-angle-prediction-90deg-reference")
            }
            popBack(); sleep(1)
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

        // ④ 角度与瞄准：首拖提示（首次进页常驻，拖动后消失）。
        switchAngleHomeTab("学")
        if tapIfExists("角度与瞄准", timeout: 4) {
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

    /// 反射 / 翻袋解球器专项截图（W4/W5 版面）：默认解 → 下一解（贴边动作列）→
    /// 球库拖入障碍球（真实碰撞体重求解）→ 右缘力度柱拉高（力度 = 求解输入）→ 击打演示。
    func testReflectionRealMode() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        openSolver(entry: "反射解球器")
        captureSolverStates(prefix: "r01-reflection")
        popBack(); sleep(1)

        openSolver(entry: "翻袋解球器")
        // 翻袋页默认袋口（左上）可能无解：逐个袋口找到有解的那个。
        ensureBankSolution()
        captureSolverStates(prefix: "r02-bankshot")
        popBack(); sleep(1)
    }

    /// 仅翻袋页：单独成测，规避与反射页连跑时的模拟器不稳定。
    func testBankShotRealMode() {
        sleep(3)
        openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球器")
        ensureBankSolution()
        captureSolverStates(prefix: "r02-bankshot")
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
            ("防守", "防守", "b2-07-snooker"),
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

        // 角度与瞄准：瞄准线/进球线文字朝向复现（T-P18-35）。
        switchAngleHomeTab("学")
        if tapIfExists("角度与瞄准", timeout: 4) {
            sleep(3)
            snap("b3p-06-angle-dynamic")
            popBack(); sleep(1)
        }

        // 翻袋/反射：顶部 1 行库数 chip + 浮层解 pill + 右缘力度柱（W4 版面）。
        if openSolverVerified(entry: "翻袋解球器", navTitle: "翻袋解球器", homeTab: "解") {
            sleep(3)
            snap("b3p-07-bankshot")
            popBack(); sleep(1)
        }
        if openSolverVerified(entry: "反射解球器", navTitle: "反射解球器", homeTab: "解") {
            sleep(3)
            snap("b3p-09-reflection")
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
    /// 反射原理 sheet 暗材质、角度预测左对齐指标条。
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

    /// W4/W5 版面截图：默认解 → 下一解 → 球库拖入障碍球（真实碰撞体，重求解）→
    /// 力度柱拉高（力度 = 求解输入，改力度会重新求解）→ 击打演示（出杆 + 回放 + 自动复位）。
    private func captureSolverStates(prefix: String) {
        sleep(4)   // 等首次引擎求解完成。
        snap("\(prefix)-default")

        // V9 条 17.9（G19）：三点菜单可开 + 台面网格 Toggle 生效。
        let more = app.navigationBars.buttons["更多"].exists
            ? app.navigationBars.buttons["更多"]
            : app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if more.waitForExistence(timeout: 3) {
            more.tap()
            sleep(1)
            snap("\(prefix)-more-menu")
            if tapIfExists("台面网格 4×8", timeout: 3) {
                sleep(1)
                snap("\(prefix)-grid-on")   // 网格 Toggle 生效（4×8 台面网格上屏）。
                more.tap()
                sleep(1)
                _ = tapIfExists("台面网格 4×8", timeout: 2)   // 关掉恢复初态。
            } else {
                app.tap()   // 关闭菜单
            }
            sleep(1)
        }

        // 贴边动作列「下一解」：多解时切换（禁用态 = 单解，跳过）。
        let next = app.buttons["下一解"]
        if next.waitForExistence(timeout: 2), next.isEnabled {
            next.tap()
            sleep(1)
            snap("\(prefix)-next-solution")
        }

        // 球库拖 1 号球上桌 = 障碍球（拖到球桌中带偏左，避开右缘力度柱）。
        let palette = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__1'")).firstMatch
        if palette.waitForExistence(timeout: 2) {
            let start = palette.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.5))
            start.press(forDuration: 0.15, thenDragTo: target)
            sleep(4)
            snap("\(prefix)-obstacle")
        }

        // 右缘力度柱从低拖高（相对增量拖动）→ 重求解。
        let power = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'solver.power'")).firstMatch
        if power.waitForExistence(timeout: 2) {
            let from = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            let to = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            from.press(forDuration: 0.1, thenDragTo: to)
            sleep(4)
            snap("\(prefix)-high-power")
        }

        // V9 条 17.3/17.5：求解态动作列 = 击打/上一杆/回放（删演示中「停止」，演示不可中断）。
        // 击打演示：出杆 → TrajectoryPlayback 回放 → 感知静止后自动复位（解线重绘、动作列回位）。
        let strike = app.buttons["击打"]
        if strike.waitForExistence(timeout: 2), strike.isEnabled {
            strike.tap()
            sleep(2)   // 回杆/出杆中或回放初段。
            snap("\(prefix)-strike-playing")
            // 等自动复位：击打钮重新出现（演示期标题为「击球中」→ 复位后回「击打」）。
            for _ in 0..<14 {
                if app.buttons["击打"].exists { break }
                sleep(1)
            }
            sleep(1)
            snap("\(prefix)-strike-reset")
            // V9 条 17.5：演示复位后「上一杆」应可用（G17 全量恢复）。
            if app.buttons["上一杆"].waitForExistence(timeout: 2), app.buttons["上一杆"].isEnabled {
                app.buttons["上一杆"].tap()
                sleep(2)
                snap("\(prefix)-solve-undo")
            }
        }

        // W6 自由模式：切自由（瞄准线 + 首碰胶囊 + 刻度轮 + 恢复球形）→ 击球（simulateFree
        // 真物理，球停在哪是哪）→ 恢复球形（回最近求解快照）→ 切回求解（缓存命中直显）。
        let modeToggle = app.buttons["solver.mode"]
        if modeToggle.waitForExistence(timeout: 2) {
            modeToggle.tap()
            sleep(2)
            snap("\(prefix)-free-default")

            let freeStrike = app.buttons["击球"]
            if freeStrike.waitForExistence(timeout: 2), freeStrike.isEnabled {
                freeStrike.tap()
                // 等击球完成（击球中 → 回「击球」且可用）。
                for _ in 0..<16 {
                    let b = app.buttons["击球"]
                    if b.exists, b.isEnabled { break }
                    sleep(1)
                }
                sleep(1)
                snap("\(prefix)-free-after-shot")
            }

            let restore = app.buttons["solver.restore"]
            if restore.waitForExistence(timeout: 2), restore.isEnabled {
                restore.tap()
                sleep(1)
                snap("\(prefix)-free-restored")
            }

            modeToggle.tap()
            sleep(2)   // 缓存命中应直显（无求解等待）。
            snap("\(prefix)-back-to-solve")
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

    // MARK: 角度 Tab（学/练/打/解 全入口卡各截一帧默认态）

    private func tourAngle() {
        app.switchTab(.angle)
        sleep(2)
        snap("08-angle-home-all")
        switchAngleHomeTab("学"); snap("08a-angle-home-learn")
        switchAngleHomeTab("练"); snap("08b-angle-home-train")
        switchAngleHomeTab("打"); snap("08c-angle-home-play")
        switchAngleHomeTab("解"); snap("08d-angle-home-solve")

        // 全入口卡默认态（场景页只截进场帧，不做击打/求解交互）。
        let subPages: [(String, String, String)] = [
            // 学
            ("学", "瞄准原理", "09-aiming-principle"),
            ("学", "角度与瞄准", "10-angle-dynamic"),
            ("学", "浅谈球感", "11-ball-feel"),
            ("学", "瞄准点对照表", "12-contact-point-table"),
            // 练
            ("练", "角度预测", "13-geometric-quiz"),
            ("练", "2D 角度训练", "14-scene-aiming-2d"),
            ("练", "3D 角度训练", "15-scene-aiming-3d"),
            ("练", "瞄准点训练", "16-aimpoint-training"),
            ("练", "2D 瞄准点训练", "17-aimpoint-scene-2d"),
            ("练", "3D 瞄准点训练", "18-aimpoint-scene-3d"),
            // 打
            ("打", "分离角与走位", "19-shot-simulation"),
            ("打", "自由走位", "20-position-play-composer"),
            ("打", "自由击球", "21-free-play"),
            ("打", "拍照建球形", "22-ball-extraction"),
            ("打", "批量出片台", "23-batch-drill-studio"),
            // 解
            ("解", "思路训练", "24-silu-trainer"),
            ("解", "打一走二想三", "25-plan-three"),
            ("解", "防守", "26-snooker-tactics"),
            ("解", "翻袋解球器", "27-bank-shot"),
            ("解", "反射解球器", "28-diamond-system"),
        ]
        for (idx, (tab, label, name)) in subPages.enumerated() {
            // SceneKit 页连开易把模拟器进程打崩：每个场景入口前软重启。
            if idx >= 4 { // 学的知识页较轻；从练/打/解起每页重启
                app.terminate()
                app = XCUIApplication.launchClean()
                sleep(2)
            }
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab(tab)
            if tapIfExists(label, timeout: 3) {
                sleep(3)
                // 瞄准训练入口先弹设置 sheet（T-P18-48）：关掉再截训练态。
                startAimingTrainingFromSheet()
                // 翻袋默认袋口可能无解，尽力找一个有解袋口再截（失败也截当前态）。
                if label == "翻袋解球器" {
                    ensureBankSolution()
                }
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
        snap("40-history-calendar")

        let statsAny = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '统计'")).firstMatch
        if statsAny.waitForExistence(timeout: 3) {
            statsAny.tap()
            sleep(2)
            snap("41-history-statistics")
        }
    }

    // MARK: 我的 Tab（含推入式子页）

    private func tourProfile() {
        app.switchTab(.profile)
        sleep(3)
        snap("50-profile-top")
        app.scrollDown(times: 3)
        sleep(1)
        snap("51-profile-scrolled")
        app.scrollUp(times: 4)
        sleep(1)

        let subPages: [(String, String)] = [
            ("个人信息", "52-profile-personal-info"),
            ("训练目标", "53-profile-training-goal"),
            ("偏好设置", "54-profile-settings"),
            ("关于与反馈", "55-profile-about"),
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
            snap("60-subscription-paywall")
            // 等待产品加载超时（8s）后捕获错误/重试兜底态（U-04）
            sleep(8)
            snap("61-subscription-paywall-timeout")
            app.swipeDown()
            sleep(1)
        }

        // 自由记录 → 进入训练会话（含 drill picker sheet）
        app.switchTab(.training)
        sleep(2)
        if tapIfExists("自由记录", timeout: 3) {
            sleep(2)
            snap("62-free-record-session")
        }
    }
}
