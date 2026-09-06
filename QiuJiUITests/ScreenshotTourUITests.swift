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
    private var v47ForcedShotDirURL: URL?
    private var usesDeterministicInMemoryStore = false

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var v56MatrixShotDirURL: URL {
        let screenSize = XCUIScreen.main.screenshot().image.size
        let device = "\(Int(screenSize.width))x\(Int(screenSize.height))"
        let mode: String
        switch XCUIDevice.shared.appearance {
        case .light: mode = "light"
        case .dark: mode = "dark"
        case .unspecified: mode = "unknown"
        @unknown default: mode = "unknown"
        }
        return projectRootURL
            .appendingPathComponent("build/v56/w7/full", isDirectory: true)
            .appendingPathComponent(device, isDirectory: true)
            .appendingPathComponent(mode, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    /// 设计巡游跨设备比较必须从同一 SwiftData 空基线启动，不能继承各模拟器
    /// 之前遗留的训练计划、历史或收藏。其他历史测试默认仍使用持久化容器。
    private func launchPremium() -> XCUIApplication {
        var arguments = ["-forcePremium", "-v51.followSystemAppearance"]
        if usesDeterministicInMemoryStore {
            arguments.append("-v50.inMemoryStore")
        }
        return XCUIApplication.launchClean(extraArgs: arguments)
    }

    // MARK: - Helpers

    /// 截图目录：v50 矩阵优先读取 `V50_SHOT_DIR` / `/tmp/qiuji-v50/shot_dir`；
    /// 旧的单页样板仍兼容 `UI_POLISH_SHOT_DIR` / `/tmp/qiuji-uitest/shot_dir`。
    /// v47 起禁止测试默认覆盖 `docs/ui-polish/screenshots-latest/` 设计基线。
    private var shotDirURL: URL? {
        if let v47ForcedShotDirURL { return v47ForcedShotDirURL }
        if let env = ProcessInfo.processInfo.environment["V50_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let env = ProcessInfo.processInfo.environment["TEST_RUNNER_V50_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let fileDir = (try? String(contentsOfFile: "/tmp/qiuji-v50/shot_dir", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines), !fileDir.isEmpty {
            return URL(fileURLWithPath: fileDir, isDirectory: true)
        }
        if let env = ProcessInfo.processInfo.environment["UI_POLISH_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        if let env = ProcessInfo.processInfo.environment["TEST_RUNNER_UI_POLISH_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // File override avoids polluting docs/ui-polish when env isn't inherited by the runner.
        if let fileDir = (try? String(contentsOfFile: "/tmp/qiuji-uitest/shot_dir", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines), !fileDir.isEmpty {
            return URL(fileURLWithPath: fileDir, isDirectory: true)
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
            case .unspecified: mode = "unknown"
            @unknown default: mode = "unknown"
            }
        }
        return projectRootURL
            .appendingPathComponent("build/v50/manual", isDirectory: true)
            .appendingPathComponent(mode, isDirectory: true)
    }

    private func snap(_ name: String) {
        guard assertCriticalPageIdentity(before: name) else { return }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // 同步写命名 PNG（不依赖 xcresult 二次导出）。写盘失败必须让测试变红，
        // 禁止用 try? 把缺图伪装成巡游成功。
        if let dir = shotDirURL {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent("\(name).png")
                try screenshot.pngRepresentation.write(to: file, options: .atomic)
            } catch {
                XCTFail("截图写盘失败 \(name): \(error.localizedDescription)")
            }
        }
    }

    /// v56 W1：文件名完整不代表页面正确。关键页面必须先证明 AX 身份，
    /// 失败时不写 PNG，让 manifest 门禁同时暴露缺图，禁止把上一页冒充目标页。
    @discardableResult
    private func assertCriticalPageIdentity(before screenshotName: String) -> Bool {
        let navigationTitles: [String: String] = [
            "03-plan-list": "训练计划",
            "13-geometric-quiz": "角度预测",
            "14-scene-aiming-2d": "2D 角度训练",
            "15-scene-aiming-3d": "3D 角度训练",
            "16-aimpoint-training": "瞄准点训练",
            "17-aimpoint-scene-2d": "2D 瞄准点训练",
            "18-aimpoint-scene-3d": "3D 瞄准点训练",
            "19-shot-simulation": "分离角与走位",
            "20-position-play-composer": "自由走位",
            "21-free-play": "自由击球",
            "22-ball-extraction": "拍照建球形",
            "23-batch-drill-studio": "批量出片台",
            "24-silu-trainer": "思路训练",
            "25-plan-three": "打一走二想三",
            "26-snooker-tactics": "防守",
            "27-bank-shot": "翻袋解球器",
            "28-diamond-system": "反射解球器",
            "52-profile-personal-info": "个人信息",
            "53-profile-training-goal": "训练目标",
            "54-profile-settings": "偏好设置",
            "55-profile-about": "关于与反馈",
            "56-profile-favorites": "我的收藏",
            "71-phone-login": "手机号登录",
        ]
        let theoryTitles: [String: String] = [
            "12c-theory-t01": "30° 法则",
            "12d-theory-t02": "90° 法则",
            "12e-theory-t03": "切线法则",
            "12f-theory-t04": "母球速度分级",
            "12g-theory-t09": "最少加塞原则",
            "12h-theory-t05": "反向规划",
            "12i-theory-t06": "关键球原理",
            "12j-theory-t07": "球团管理",
            "12k-theory-t08": "风险报酬决策矩阵",
            "12l-theory-t10": "安全球三维度模型",
            "12m-theory-flow": "清台 5 步决策流程",
            "12n-theory-quickref": "清台速查手册",
        ]

        let isVisible: Bool
        switch screenshotName {
        case "00-launch", "01-training-home":
            // `00` 是启动过程证据；App 稳定后它与训练首页可能同帧，不计独立页面。
            isVisible = app.buttons["trainingHome.moreMenu"].waitForExistence(timeout: 5)
        case "04-plan-detail":
            isVisible = app.descendants(matching: .any)["planDetail.primaryCTA"]
                .waitForExistence(timeout: 5)
        case "05-drill-library":
            // 动作库是 Tab 根页，按 D-v47-1 不显示 navigation title；
            // 用内容卡 identifier 证明已进入真实根页。
            // iPadOS 26 的浮动 Tab 会把 cell 与内部 view 都映射成同名 Button。
            // `firstMatch` 避免唯一性查询因嵌套重复元素失败。
            let tab = app.buttons.matching(identifier: "动作库").firstMatch
            let card = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH 'drillCard_'"
            )).firstMatch
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
                && card.waitForExistence(timeout: 2)
        case "06-drill-detail-top":
            // 小屏首张卡片内含收藏按钮；只记录 tap 动作不足以证明已 push。
            // 以详情页固定底栏 CTA 作为页面身份，避免把动作库误收为详情证据。
            isVisible = app.buttons["bottomTryoutButton"].waitForExistence(timeout: 5)
        case "08-angle-home-all":
            isVisible = app.buttons["angleHomeTab_全部"].waitForExistence(timeout: 5)
        case "08a-angle-home-learn":
            let tab = app.buttons["angleHomeTab_学"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
        case "08a2-angle-home-theory":
            let tab = app.buttons["angleHomeTab_理"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
        case "08b-angle-home-train":
            let tab = app.buttons["angleHomeTab_练"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
        case "08c-angle-home-play":
            let tab = app.buttons["angleHomeTab_打"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
        case "08d-angle-home-solve":
            let tab = app.buttons["angleHomeTab_解"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
        case "50-profile-top":
            let tab = app.buttons.matching(identifier: "我的").firstMatch
            let accountHeader = app.descendants(matching: .any)["profile.accountHeader"]
            let loginHeader = app.descendants(matching: .any)["profile.login"]
            let profileRow = app.staticTexts["个人信息"]
            isVisible = tab.waitForExistence(timeout: 3) && tab.isSelected
                && (accountHeader.waitForExistence(timeout: 1)
                    || loginHeader.waitForExistence(timeout: 1)
                    || profileRow.waitForExistence(timeout: 1))
        case "40-history-calendar":
            // 记录同样是隐藏导航栏的 Tab 根页；选中态就是稳定页面身份。
            let tab = app.buttons.matching(identifier: "记录").firstMatch
            isVisible = tab.waitForExistence(timeout: 5) && tab.isSelected
        case "57-subscription-status":
            isVisible = app.navigationBars["订阅管理"].waitForExistence(timeout: 3)
                || app.navigationBars["Pro 权益"].waitForExistence(timeout: 2)
        case "70-login":
            isVisible = waitForLoginScreen(timeout: 5)
        case "72-onboarding":
            isVisible = app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 5)
        default:
            if let title = navigationTitles[screenshotName] ?? theoryTitles[screenshotName] {
                isVisible = app.navigationBars[title].waitForExistence(timeout: 5)
            } else {
                return true
            }
        }

        if !isVisible {
            XCTFail("截图 \(screenshotName) 页面身份断言失败；拒绝把当前画面写成目标页")
        }
        return isVisible
    }

    private func waitForLoginScreen(timeout: TimeInterval) -> Bool {
        app.staticTexts["看懂球路，练出结果"].waitForExistence(timeout: timeout)
            && app.buttons["通过 Apple 登录"].waitForExistence(timeout: 2)
    }

    private func assertCurrentLoginContract() {
        XCTAssertTrue(waitForLoginScreen(timeout: 5), "登录页身份锚点应可见")
        XCTAssertTrue(app.buttons["通过 Apple 登录"].exists, "当前生产登录应保留 Apple")
        XCTAssertTrue(app.buttons["暂不登录，匿名使用"].exists, "当前生产登录应保留匿名使用")
        XCTAssertTrue(
            app.staticTexts["微信与手机号登录暂未开放"].exists,
            "未开放方式应以静态说明诚实呈现"
        )
        XCTAssertFalse(app.buttons["微信登录"].exists, "不得把未开放的微信登录断言为生产按钮")
        XCTAssertFalse(app.buttons["手机号登录"].exists, "手机号表单只保留测试专用深链")

        let terms = app.links["用户协议"]
        let privacy = app.links["隐私政策"]
        if terms.exists || privacy.exists {
            XCTAssertTrue(terms.exists, "配置法律 URL 时应同时提供用户协议 Link")
            XCTAssertTrue(privacy.exists, "配置法律 URL 时应同时提供隐私政策 Link")
        } else {
            XCTAssertTrue(
                app.staticTexts["用户协议与隐私政策发布后将在此提供可访问链接"].exists,
                "未配置法律 URL 时必须展示合并 fallback，不能静默缺失"
            )
        }
    }

    /// 用 W0 冻结的 66 张基线文件名做完整性门禁。巡游里的防御式点击仍可继续
    /// 收集后续页面，但任何静默跳页最终都会因缺图而失败。
    private func assertV47BaselineScreenshotCompleteness() {
        guard let outputDir = shotDirURL else {
            XCTFail("v47 截图输出目录不可用")
            return
        }

        let manifestPath = ProcessInfo.processInfo.environment["V50_EXPECTED_SHOT_MANIFEST"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V50_EXPECTED_SHOT_MANIFEST"]
            ?? projectRootURL.appendingPathComponent(
                "docs/design/v47/baseline-screenshots.sha256"
            ).path
        do {
            let manifest = try String(contentsOfFile: manifestPath, encoding: .utf8)
            let expected = Set(manifest.split(separator: "\n").compactMap { line -> String? in
                guard !line.hasPrefix("#"), let path = line.split(separator: " ").last else { return nil }
                return URL(fileURLWithPath: String(path)).lastPathComponent
            })
            XCTAssertEqual(expected.count, 66, "v47 基线 manifest 必须正好登记 66 张 PNG")
            let nonProductionEvidence = Set(["00-launch.png", "71-phone-login.png"])
            XCTAssertTrue(
                nonProductionEvidence.isSubset(of: expected),
                "manifest 必须显式包含启动过程帧与测试专用手机号页"
            )
            XCTAssertEqual(
                expected.subtracting(nonProductionEvidence).count,
                64,
                "66 个文件应准确拆分为 64 个生产独立状态 + 1 个启动过程帧 + 1 个测试专用页"
            )

            let produced = Set(try FileManager.default.contentsOfDirectory(
                at: outputDir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension.lowercased() == "png" }.map(\.lastPathComponent))
            let missing = expected.subtracting(produced).sorted()
            XCTAssertTrue(missing.isEmpty, "v47 巡游缺图：\(missing.joined(separator: ", "))")
        } catch {
            XCTFail("v47 截图完整性门禁无法读取 manifest/输出目录：\(error.localizedDescription)")
        }
    }

    /// 完整巡游必须从空输出目录开始，避免上轮残留 PNG 掩盖本轮静默跳页。
    /// 只允许清理版本化 build 截图目录或专用系统临时目录，绝不递归删除 docs/Resources。
    @discardableResult
    private func resetV47ShotDirectory() -> Bool {
        guard let dir = shotDirURL else {
            XCTFail("v47 截图输出目录不可用")
            return false
        }
        let standardized = dir.standardizedFileURL.path
        let buildRoot = projectRootURL.appendingPathComponent("build", isDirectory: true)
            .standardizedFileURL.path + "/"
        let allowedBuildLeaf = standardized.hasPrefix(buildRoot)
            && (standardized.contains("/v47-")
                || standardized.contains("/v50/")
                || standardized.contains("/v51/")
                || standardized.contains("/v56/"))
        let allowedTemporaryLeaf = standardized.hasPrefix("/tmp/qiuji-v50/")
            || standardized.hasPrefix("/private/tmp/qiuji-v50/")
            || standardized.hasPrefix("/tmp/qiuji-uitest/")
        let allowed = allowedBuildLeaf || allowedTemporaryLeaf
        guard allowed else {
            XCTFail("拒绝清理非版本化专用输出目录：\(standardized)")
            return false
        }
        do {
            if FileManager.default.fileExists(atPath: standardized) {
                try FileManager.default.removeItem(at: dir)
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return true
        } catch {
            XCTFail("无法重置 v47 截图目录：\(error.localizedDescription)")
            return false
        }
    }

    /// v56 W7 的 66 页巡游按页面族拆成短 Runner，但所有分段必须落到同一设备/外观目录。
    /// Foundation 是唯一允许清目录的分段；其余分段只能追加，最后由 manifest 独立收账。
    @discardableResult
    private func useV56MatrixShotDirectory(reset: Bool) -> Bool {
        v47ForcedShotDirURL = v56MatrixShotDirURL
        if reset { return resetV47ShotDirectory() }
        do {
            try FileManager.default.createDirectory(
                at: v56MatrixShotDirURL,
                withIntermediateDirectories: true
            )
            return true
        } catch {
            XCTFail("无法准备 v56 矩阵目录：\(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    private func tapIfExists(_ label: String, timeout: TimeInterval = 4) -> Bool {
        // Prefer the card button; title text is often duplicated inside the card
        // and `staticTexts[label].tap()` then fatals on multiple matches.
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        let staticText = app.staticTexts[label].firstMatch
        if staticText.waitForExistence(timeout: 1) {
            staticText.tap()
            return true
        }
        return false
    }

    /// AngleHome 在 iPad 上会因网格高度/上一次分段状态让目标卡不在首个可见区；
    /// 长巡游还可能在 soft restart 后短暂拿到空 AX 快照。第一轮滚动仍找不到时，
    /// 用一次干净重启重建 AX 树并恢复指定分段。调用点仍须显式报错，最终再由
    /// 66 张 manifest 双重兜底。
    @discardableResult
    private func tapAngleCard(
        _ label: String,
        tab: String,
        maxScrolls: Int = 4
    ) -> Bool {
        for attempt in 0..<2 {
            if attempt > 0 {
                app.terminate()
                app = launchPremium()
                sleep(2)
                app.switchTab(.angle)
                sleep(1)
                guard switchAngleHomeTab(tab) else { return false }
            }

            if tapIfExists(label, timeout: 4) { return true }
            for _ in 0..<maxScrolls {
                let scroll = app.scrollViews.firstMatch
                if scroll.exists {
                    scroll.swipeUp(velocity: .fast)
                } else {
                    app.swipeUp(velocity: .fast)
                }
                usleep(450_000)
                if tapIfExists(label, timeout: 2) { return true }
            }
        }
        return false
    }

    /// 打开训练首页的更多菜单。生产代码提供稳定 identifier；中文/英文系统标签
    /// 仅保留为旧构建兜底，避免 developmentLanguage 变化造成静默漏页。
    @discardableResult
    private func openTrainingHomeMenu(timeout: TimeInterval = 4) -> Bool {
        let identified = app.buttons["trainingHome.moreMenu"]
        if identified.waitForExistence(timeout: timeout) {
            identified.tap()
            return true
        }
        let localizedFallback = app.buttons.matching(NSPredicate(
            format: "label CONTAINS 'ellipsis' OR label == 'More' OR label == '更多'"
        )).firstMatch
        if localizedFallback.waitForExistence(timeout: 1) {
            localizedFallback.tap()
            return true
        }
        return false
    }

    /// SwiftUI 在部分 iPadOS 26 构建中不会把 identifier 透传给复合 Button；
    /// 明确的产品级 accessibilityLabel 是稳定且可读的第二定位通道。
    private func resolvedButton(
        identifier: String,
        label: String,
        timeout: TimeInterval = 5
    ) -> XCUIElement? {
        let identified = app.buttons[identifier]
        if identified.waitForExistence(timeout: timeout) { return identified }
        let labelled = app.buttons[label]
        if labelled.waitForExistence(timeout: 2) { return labelled }
        return nil
    }

    /// iPadOS 26 长时间 UI 测试后，切入“我的”可能短暂返回空 AX 快照。
    /// 有界重新激活/选 Tab，并兼容 SwiftUI 复合按钮的合并标签。
    @discardableResult
    private func openProfileLogin() -> Bool {
        for attempt in 0..<3 {
            if attempt > 0 {
                app.activate()
                app.switchTab(.profile)
                sleep(1)
            }
            let candidates = [
                app.buttons["profile.login"],
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH '点击登录'")).firstMatch,
                app.buttons["登录 / 注册"],
            ]
            for candidate in candidates where candidate.waitForExistence(timeout: 2) {
                candidate.tap()
                if waitForLoginScreen(timeout: 5) {
                    return true
                }
            }
        }
        return false
    }

    /// 从“我的”根页打开一个推入式子页。长巡游运行到 Profile 时，SwiftUI 的
    /// AX 树偶尔会短暂缺行；每轮先回到列表顶部，再做有限次滚动查找，并以目标
    /// navigation title 确认确实进入了页面，禁止把根页误截成子页。
    @discardableResult
    private func openProfileDestination(
        _ title: String,
        maxScrolls: Int = 6
    ) -> Bool {
        let destination = app.navigationBars[title]
        for attempt in 0..<2 {
            if destination.waitForExistence(timeout: attempt == 0 ? 1 : 2) {
                return true
            }
            if attempt > 0 {
                app.activate()
                if destination.waitForExistence(timeout: 2) { return true }
            }

            app.switchTab(.profile)
            sleep(1)
            app.scrollUp(times: 5)
            sleep(1)

            for scrollIndex in 0...maxScrolls {
                if tapIfExists(title, timeout: scrollIndex == 0 ? 3 : 1),
                   destination.waitForExistence(timeout: 4) {
                    return true
                }
                guard scrollIndex < maxScrolls else { break }
                let scroll = app.scrollViews.firstMatch
                if scroll.exists {
                    scroll.swipeUp(velocity: .fast)
                } else {
                    app.swipeUp(velocity: .fast)
                }
                usleep(400_000)
            }
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

    /// 角度首页分段 Tab（学 / 理 / 练 / 打 / 解，ADR-P18-01 + v32 五分类）。
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

    /// 给 UI 设计师的整页快照：Pro 解锁后走完整巡游，再补巡游漏掉的常规页。
    /// 落盘目录：`UI_POLISH_SHOT_DIR` 或 `/tmp/qiuji-uitest/shot_dir`。
    func testDesignerPageDump() {
        // v50 必须由矩阵运行器注入按 runtime/device/appearance/state/suite 隔离的目录；
        // `shotDirURL` 的默认值只服务人工单跑，绝不再硬编码覆盖 Light 或其他设备证据。
        guard resetV47ShotDirectory() else { return }
        usesDeterministicInMemoryStore = true
        app.terminate()
        app = launchPremium()
        sleep(3)
        snap("00-launch")

        tourTraining()
        tourCustomPlanBuilder()
        tourDrillLibrary()
        tourDrillTutorial()
        tourAngle()
        tourRemainingLearnPages()
        tourAllTheoryPages()

        // 球理 push 会藏底栏，必须软重启再拍记录 / 我的。
        app.terminate()
        app = launchPremium()
        sleep(3)
        tourHistory()
        tourProfile()
        tourFavoritesAndSubscriptionStatus()
        tourLogin()
        tourOnboarding()
        assertV47BaselineScreenshotCompleteness()
    }

    /// v56 W1：允许把长巡游拆成多个隔离 Runner 补齐同一目录后，单独核对总账。
    /// 该用例不启动 App、不清目录，只验证本轮 66 文件与 64+1+1 口径。
    func testV56W7GManifestCompleteness() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        assertV47BaselineScreenshotCompleteness()
    }

    /// v56 W7：分段 1/6。只在这里清理本设备/外观目录，建立 00–08d 基础页面证据。
    func testV56W7AFoundation() {
        guard useV56MatrixShotDirectory(reset: true) else { return }
        usesDeterministicInMemoryStore = true
        app.terminate()
        app = launchPremium()
        sleep(3)
        snap("00-launch")
        tourTraining()
        tourCustomPlanBuilder()
        tourDrillLibrary()
        tourDrillTutorial()
        tourAngleLandingPages()
    }

    /// v56 W7：分段 2/6。学习入口与理论入口各自保持真实页面身份。
    func testV56W7BLearn() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v51.followSystemAppearance",
        ])
        sleep(3)
        tourAnglePages(v56LearnCorePages)
        tourRemainingLearnPages()
    }

    /// v56 W7：分段 3/6。练习工具页单独巡游，控制 Runner 生命周期。
    func testV56W7CPractice() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        tourAnglePages(v56PracticePages)
    }

    /// v56 W7：分段 4/6。打 / 解的固定暗场工具页。
    func testV56W7DPlayAndSolve() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        tourAnglePages(v56PlayAndSolvePages)
    }

    /// v56 W7：分段 5/6。12 个球理页面。
    func testV56W7ETheory() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        tourAllTheoryPages()
    }

    /// v56 W7：分段 6/6。记录、个人、订阅、登录、测试专用手机号页与引导。
    func testV56W7FChromeAndStates() {
        guard useV56MatrixShotDirectory(reset: false) else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        tourHistory()
        tourProfile()
        tourFavoritesAndSubscriptionStatus()
        tourModalFlows()
        tourLogin()
        tourOnboarding()
    }

    /// D-v47-1：五个 Tab 根页永久保持无大标题。子页正常导航标题不在本断言范围。
    func testV47TabRootsHaveNoNavigationTitle() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v51.followSystemAppearance"])
        let tabs: [XCUIApplication.Tab] = [.training, .drillLibrary, .angle, .history, .profile]
        for tab in tabs {
            app.switchTab(tab)
            XCTAssertFalse(
                app.navigationBars[tab.rawValue].waitForExistence(timeout: 1),
                "\(tab.rawValue) Tab 根页不得恢复 navigation title"
            )
            let pageIdentity: XCUIElement
            switch tab {
            case .training: pageIdentity = app.staticTexts["本周训练"].firstMatch
            case .drillLibrary: pageIdentity = app.textFields["搜索动作"].firstMatch
            case .angle: pageIdentity = app.textFields["搜索练习"].firstMatch
            case .history: pageIdentity = app.buttons["统计"].firstMatch
            case .profile: pageIdentity = app.staticTexts["我的收藏"].firstMatch
            }
            guard pageIdentity.waitForExistence(timeout: 8) else {
                XCTFail("\(tab.rawValue) Tab 必须实际显示目标页，不能用上一页截图代替")
                return
            }
            snap("tab-root-\(tab.rawValue)")
        }
    }

    /// W3 根页样板 R：固定首屏/底部证据，并守住“无大标题 + 唯一主 CTA + 可滚到底”。
    func testV47TrainingHomeSample() {
        let mode: String
        switch XCUIDevice.shared.appearance {
        case .light: mode = "light"
        case .dark: mode = "dark"
        case .unspecified: mode = "unknown"
        @unknown default: mode = "unknown"
        }
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/training-home/\(mode)",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        app.switchTab(.training)

        XCTAssertFalse(
            app.navigationBars[XCUIApplication.Tab.training.rawValue].waitForExistence(timeout: 1),
            "训练根页不得恢复 navigation title"
        )
        XCTAssertTrue(
            app.staticTexts["今日训练进行中"].waitForExistence(timeout: 5),
            "首屏应明确当前训练状态"
        )
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == '开始训练'")).count,
            1,
            "训练根页只能有一个主 CTA"
        )
        snap("01-training-home-top")

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 3), "训练根页应可滚动")
        for _ in 0..<5 { scrollSurface.swipeUp(velocity: .fast) }
        snap("02-training-home-bottom")

        XCTAssertTrue(
            app.tabBars.buttons[XCUIApplication.Tab.training.rawValue].exists
                || app.buttons[XCUIApplication.Tab.training.rawValue].exists,
            "滚动到底后 Tab Bar 仍应可达"
        )
    }

    /// W3 AX 证据：调用前须用 `simctl ui <device> content_size accessibility-large` 设置系统字号。
    /// 本测试只固定截图与关键可达性；是否实际缩放必须结合系统设置回读和截图目视裁定。
    func testV47TrainingHomeSampleAccessibilitySize() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/training-home/ax-large",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        app.switchTab(.training)

        XCTAssertTrue(app.staticTexts["今日训练进行中"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == '开始训练'")).count,
            1
        )
        snap("01-training-home-ax-large")
    }

    /// W3 15–30 秒交互证据：滚动、切换计划来源，再回到首要状态。
    func testV47TrainingHomeInteractionEvidence() {
        app.switchTab(.training)
        XCTAssertTrue(app.staticTexts["今日训练进行中"].waitForExistence(timeout: 5))

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 3))
        scrollSurface.swipeUp(velocity: .slow)
        scrollSurface.swipeDown(velocity: .slow)

        if app.buttons["我的模版"].waitForExistence(timeout: 3) {
            app.buttons["我的模版"].tap()
            XCTAssertTrue(app.buttons["官方计划"].waitForExistence(timeout: 3))
            app.buttons["官方计划"].tap()
        }

        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == '开始训练'")).count,
            1
        )
    }

    /// W3 紧凑尺寸证据：在 375pt 宽设备上验证状态、唯一 CTA 与底部安全区。
    func testV47TrainingHomeCompactSample() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/training-home/compact",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        app.switchTab(.training)

        let activeState = app.staticTexts["今日训练进行中"]
        let emptyState = app.staticTexts["今日训练待安排"]
        let hasRecognizableState = activeState.waitForExistence(timeout: 3)
            || emptyState.waitForExistence(timeout: 3)
        XCTAssertTrue(hasRecognizableState, "紧凑尺寸首屏应明确当前训练状态")
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(format: "label == '开始训练' OR label == '自由记录'")
            ).count,
            1
        )
        snap("01-training-home-compact-top")

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 3))
        for _ in 0..<5 { scrollSurface.swipeUp(velocity: .fast) }
        snap("02-training-home-compact-bottom")
    }

    /// W8 数据样板 D：固定统计首屏/底部，并验证周期上下文与核心指标可达。
    func testV47StatisticsSample() {
        let mode: String
        switch XCUIDevice.shared.appearance {
        case .light: mode = "light"
        case .dark: mode = "dark"
        case .unspecified: mode = "unknown"
        @unknown default: mode = "unknown"
        }
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/statistics/\(mode)",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        openV47Statistics()

        XCTAssertTrue(app.staticTexts["统计区间"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["训练概况"].exists)
        XCTAssertTrue(app.staticTexts["分钟 · 总时长"].exists)
        XCTAssertTrue(app.staticTexts["训练组数"].exists)
        snap("01-statistics-top")

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 3))
        for _ in 0..<5 { scrollSurface.swipeUp(velocity: .fast) }
        snap("02-statistics-bottom")
    }

    /// W8 AX 证据：调用前须设置并回读系统 accessibility-large 字号。
    func testV47StatisticsSampleAccessibilitySize() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/statistics/ax-large",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        openV47Statistics()
        XCTAssertTrue(app.staticTexts["训练概况"].waitForExistence(timeout: 5))
        snap("01-statistics-ax-large")
    }

    /// W8 Free 证据：统计内容保持在原导航位置，以明确的 Pro 门槛承接，不改变入口。
    func testV47StatisticsFreeGateSample() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/statistics/free",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean()
        openV47Statistics()
        XCTAssertTrue(app.staticTexts["统计功能为 Pro 专属"].waitForExistence(timeout: 5))
        snap("01-statistics-free-gate")
    }

    /// W8 紧凑尺寸证据：允许独立模拟器处于有数据或空态，但状态必须完整可辨。
    func testV47StatisticsCompactSample() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/statistics/compact",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        openV47Statistics()

        let overview = app.staticTexts["训练概况"]
        let empty = app.staticTexts["还没有训练数据"]
        XCTAssertTrue(
            overview.waitForExistence(timeout: 3) || empty.waitForExistence(timeout: 3),
            "紧凑尺寸统计页应明确呈现数据概况或空态"
        )
        snap("01-statistics-compact")
    }

    /// W8 15–30 秒交互证据：切换周/月/年并滚动查看趋势和分类。
    func testV47StatisticsInteractionEvidence() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        openV47Statistics()

        for range in ["月", "年", "周"] {
            let button = app.buttons[range]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "统计周期 \(range) 应可达")
            button.tap()
            usleep(500_000)
        }

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 3))
        scrollSurface.swipeUp(velocity: .slow)
        scrollSurface.swipeDown(velocity: .slow)
        XCTAssertTrue(app.staticTexts["训练概况"].exists)
    }

    private func openV47Statistics() {
        app.switchTab(.history)
        let statsTab = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '统计'")).firstMatch
        XCTAssertTrue(statsTab.waitForExistence(timeout: 5), "记录根页应提供统计分段")
        statsTab.tap()
    }

    /// W10a 品牌样板 B：三屏引导与登录必须共享同一球路/复盘语言，同时保持原入口。
    func testV47BrandSample() {
        let mode: String
        switch XCUIDevice.shared.appearance {
        case .light: mode = "light"
        case .dark: mode = "dark"
        case .unspecified: mode = "unknown"
        @unknown default: mode = "unknown"
        }
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/brand/\(mode)",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        launchV47Onboarding()
        XCTAssertTrue(app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["继续"].exists)
        XCTAssertTrue(app.buttons["跳过"].exists)
        snap("01-onboarding-route")

        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["记录每杆，复盘趋势"].waitForExistence(timeout: 3))
        snap("02-onboarding-review")

        app.buttons["继续"].tap()
        XCTAssertTrue(app.buttons["开始使用"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["登录已有账号"].exists)
        snap("03-onboarding-summary")

        app.buttons["登录已有账号"].tap()
        XCTAssertTrue(app.staticTexts["看懂球路，练出结果"].waitForExistence(timeout: 3))
        assertCurrentLoginContract()
        snap("04-login")
    }

    /// W10a AX 证据：调用前须设置并回读系统 accessibility-large 字号。
    func testV47BrandSampleAccessibilitySize() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/brand/ax-large",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        launchV47Onboarding()
        XCTAssertTrue(app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 5))
        snap("01-onboarding-ax-large")

        openV47LoginFromOnboarding()
        XCTAssertTrue(app.staticTexts["看懂球路，练出结果"].waitForExistence(timeout: 3))
        snap("02-login-ax-large")
    }

    /// W10a 375pt 紧凑尺寸：引导、登录入口与底部协议均必须完整可达。
    func testV47BrandCompactSample() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/brand/compact",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        launchV47Onboarding()
        XCTAssertTrue(app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["继续"].isHittable)
        XCTAssertTrue(app.buttons["跳过"].isHittable)
        snap("01-onboarding-compact")

        openV47LoginFromOnboarding()
        XCTAssertTrue(app.buttons["通过 Apple 登录"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["暂不登录，匿名使用"].exists)
        XCTAssertTrue(app.staticTexts["微信与手机号登录暂未开放"].exists)
        XCTAssertFalse(app.buttons["手机号登录"].exists)
        snap("02-login-compact")
    }

    /// v56 W2–W4 聚焦证据：同一设备/外观下记录弱绿筛选、侧栏、Guest 层级与 Pro 材质。
    func testV56ColorSemanticsFocused() {
        let mode: String
        switch XCUIDevice.shared.appearance {
        case .light: mode = "light"
        case .dark: mode = "dark"
        case .unspecified: mode = "unknown"
        @unknown default: mode = "unknown"
        }
        v47ForcedShotDirURL = projectRootURL
            .appendingPathComponent("build/v56/w7/focused/\(mode)", isDirectory: true)
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean()
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["登录 / 注册"].exists, "Guest 只能保留一个主登录行动")
        snap("01-profile-guest")

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        app.switchTab(.drillLibrary)
        XCTAssertTrue(app.buttons["levelFilter_全部"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["levelFilter_全部"].isSelected)
        snap("02-drill-filter-selected")

        app.switchTab(.angle)
        XCTAssertTrue(app.buttons["angleHomeTab_全部"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["angleHomeTab_全部"].isSelected)
        snap("03-angle-sidebar-selected")

        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 5))
        XCTAssertTrue(tapIfExists("订阅管理", timeout: 4))
        XCTAssertTrue(
            app.navigationBars["订阅管理"].waitForExistence(timeout: 5)
                && app.staticTexts["Pro 会员"].waitForExistence(timeout: 2),
            "强制 Pro 状态应进入订阅管理并展示会员材质"
        )
        snap("04-subscription-premium")
    }

    /// W10a 键盘态：品牌构图不能阻断手机号登录 Sheet、输入焦点和键盘。
    func testV47BrandPhoneKeyboardSample() {
        v47ForcedShotDirURL = URL(
            fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v47-samples/brand/keyboard",
            isDirectory: true
        )
        guard resetV47ShotDirectory() else { return }

        launchV47Onboarding()
        openV47LoginFromOnboarding()
        app.buttons["手机号登录"].tap()

        let phoneField = app.textFields["请输入手机号"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 3))
        phoneField.tap()
        phoneField.typeText("13800138000")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["发送验证码"].exists)
        snap("01-phone-login-keyboard")
    }

    /// W10a 15–30 秒交互证据：完整经过引导、登录与手机号输入，不改变跳过/登录路径。
    func testV47BrandInteractionEvidence() {
        launchV47Onboarding()
        XCTAssertTrue(app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 5))
        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["记录每杆，复盘趋势"].waitForExistence(timeout: 3))
        app.buttons["继续"].tap()
        XCTAssertTrue(app.buttons["登录已有账号"].waitForExistence(timeout: 3))
        app.buttons["登录已有账号"].tap()
        XCTAssertTrue(app.buttons["手机号登录"].waitForExistence(timeout: 3))
        app.buttons["手机号登录"].tap()

        let phoneField = app.textFields["请输入手机号"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 3))
        phoneField.tap()
        phoneField.typeText("13800138000")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    }

    private func launchV47Onboarding() {
        app.terminate()
        let fresh = XCUIApplication()
        fresh.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        fresh.launchArguments += ["-AppleLocale", "zh_CN"]
        fresh.launchArguments += ["-hasCompletedOnboarding", "NO"]
        fresh.launchArguments += ["-resetDebugPremium"]
        fresh.launch()
        app = fresh
    }

    private func openV47LoginFromOnboarding() {
        for _ in 0..<2 {
            let next = app.buttons["继续"]
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        let login = app.buttons["登录已有账号"]
        XCTAssertTrue(login.waitForExistence(timeout: 3))
        login.tap()
    }

    /// W0/W15a 同形性能对拍：训练与记录根页各静置 10 秒、连续滚动 15 秒。
    /// 指标绑定被测 App 进程，避免只量到 UI runner；模拟器数据只比较同机趋势。
    func testV47TrainingAndHistoryPerformanceBaseline() {
        let options = XCTMeasureOptions()
        options.iterationCount = 1

        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(application: app),
                XCTMemoryMetric(application: app),
                XCTOSSignpostMetric.scrollingAndDecelerationMetric,
            ],
            options: options
        ) {
            exerciseV47PerformancePage(tab: .training)
            exerciseV47PerformancePage(tab: .history)
        }
    }

    private func exerciseV47PerformancePage(tab: XCUIApplication.Tab) {
        app.switchTab(tab)
        Thread.sleep(forTimeInterval: 10)

        let scrollSurface = app.scrollViews.firstMatch
        XCTAssertTrue(scrollSurface.waitForExistence(timeout: 5), "\(tab.rawValue) 根页缺少可滚动表层")
        let deadline = Date().addingTimeInterval(15)
        var upward = true
        while Date() < deadline {
            if upward {
                scrollSurface.swipeUp(velocity: .fast)
            } else {
                scrollSurface.swipeDown(velocity: .fast)
            }
            upward.toggle()
        }
    }

    /// 接 remainder：球理页会藏底栏，先软重启再拍记录 / 我的 / 登录 / 引导。
    func testDesignerPageDumpChrome() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        tourHistory()
        tourProfile()
        tourFavoritesAndSubscriptionStatus()
        app.switchTab(.training)
        sleep(2)
        if tapIfExists("自由记录", timeout: 3) {
            sleep(2)
            snap("62-free-record-session")
        }
        tourLogin()
        tourOnboarding()
    }

    /// v56 W1：长巡游拆分后的“学 + 理”补拍段，控制单个 Runner 生命周期。
    func testV56LearningAndTheoryRemainder() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        tourRemainingLearnPages()
        tourAllTheoryPages()
    }

    /// 补拍自由记录会话 + 引导（避开 Paywall 不可点）。
    func testDesignerPageDumpTail() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)
        app.switchTab(.training)
        sleep(2)
        if tapIfExists("自由记录", timeout: 3) {
            sleep(2)
            snap("62-free-record-session")
        }
        tourOnboarding()
    }

    /// 接 `testDesignerPageDump`：从「解」区「防守」起补拍未完成页。
    func testDesignerPageDumpRemainder() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(3)

        let remainingSolve: [(String, String)] = [
            ("防守", "26-snooker-tactics"),
            ("翻袋解球器", "27-bank-shot"),
            ("反射解球器", "28-diamond-system"),
        ]
        for (label, name) in remainingSolve {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
            sleep(2)
            app.switchTab(.angle)
            sleep(1)
            switchAngleHomeTab("解")
            if tapIfExists(label, timeout: 4) {
                sleep(3)
                startAimingTrainingFromSheet()
                if label == "翻袋解球器" { ensureBankSolution() }
                snap(name)
            }
        }

        tourRemainingLearnPages()
        tourAllTheoryPages()
        tourHistory()
        tourProfile()
        tourFavoritesAndSubscriptionStatus()
        tourLogin()
        tourModalFlows()
        tourOnboarding()
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
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
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
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        tourHistory()
        tourProfile()
        tourModalFlows()
    }

    /// v50 W4：iPad 完整巡游曾因目标卡不在首屏而静默漏图。
    /// 用三个真实漏页锁定学/练/打三个分段的滚动导航。
    func testV50IPadAngleRouteNavigationRegression() {
        guard resetV47ShotDirectory() else { return }
        let pages: [(String, String, String)] = [
            ("学", "旋转与加塞", "09d-spin-and-english"),
            ("练", "3D 瞄准点训练", "18-aimpoint-scene-3d"),
            ("打", "分离角与走位", "19-shot-simulation"),
        ]
        for (tab, label, name) in pages {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
            sleep(2)
            app.switchTab(.angle)
            XCTAssertTrue(switchAngleHomeTab(tab), "无法切换到 \(tab) 分段")
            XCTAssertTrue(tapAngleCard(label, tab: tab), "iPad 滚动/AX 恢复后仍无法打开 \(label)")
            XCTAssertTrue(
                app.navigationBars[label].waitForExistence(timeout: 5),
                "点击后未进入 \(label)"
            )
            startAimingTrainingFromSheet()
            snap(name)
        }
    }

    /// v50 W4：双 iPad 并发长巡游曾在 T07 前同时遇到一次 AX 空快照。
    /// 聚焦锁定“切到理分段 → 找到球团管理 → push”整条公共导航链。
    func testV50IPadTheoryT07NavigationRegression() {
        guard resetV47ShotDirectory() else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        XCTAssertTrue(
            TheoryIndexNavigation.openPage(in: app, cardTitle: "球团管理"),
            "iPad 应能打开 T07 球团管理"
        )
        let navigationBar = app.navigationBars["球团管理"]
        XCTAssertTrue(
            navigationBar.buttons["返回"].waitForExistence(timeout: 3),
            "中文 App 的系统返回按钮应显示“返回”"
        )
        XCTAssertFalse(
            navigationBar.buttons["Back"].exists,
            "工程开发语言不得回退为英文"
        )
        snap("12j-theory-t07")
    }

    /// v50 W5：大屏 iPad 长巡游曾同时漏掉两个训练菜单页面，并在 AX 空快照时
    /// 漏掉“解 / 思路训练”。逐页干净启动，锁定稳定菜单标识和 AX 恢复链。
    func testV50LargeIPadMissingRouteRegression() {
        guard resetV47ShotDirectory() else { return }

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.training)
        XCTAssertTrue(openTrainingHomeMenu(), "训练首页应能通过稳定标识打开更多菜单")
        XCTAssertTrue(tapIfExists("训练计划", timeout: 3), "更多菜单应包含训练计划")
        XCTAssertTrue(app.navigationBars["训练计划"].waitForExistence(timeout: 5), "应进入训练计划列表")
        snap("03-plan-list")

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.training)
        XCTAssertTrue(openTrainingHomeMenu(), "训练首页应能再次打开更多菜单")
        XCTAssertTrue(tapIfExists("新建模版", timeout: 3), "更多菜单应包含新建模版")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForExistence(timeout: 5), "应进入新建模版")
        snap("04b-custom-plan-builder")

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.angle)
        // 第一次 AX 快照可能为空；tapAngleCard 会在必要时重启并恢复“解”分段。
        _ = switchAngleHomeTab("解")
        XCTAssertTrue(tapAngleCard("思路训练", tab: "解"), "AX 恢复后应能打开思路训练")
        XCTAssertTrue(app.navigationBars["思路训练"].waitForExistence(timeout: 5), "应进入思路训练")
        snap("24-silu-trainer")
    }

    /// v56 W1：大屏 iPad 上点击登录内部文字不会可靠触发外层 Button。
    /// 验证个人页 → Apple-only 登录 Sheet；手机号表单仅通过测试专用深链保留。
    func testV50IPadLoginNavigationRegression() {
        guard resetV47ShotDirectory() else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.profile)

        guard openProfileLogin() else {
            XCTFail("个人页应提供稳定的登录入口")
            return
        }
        assertCurrentLoginContract()
        snap("70-login")

        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v51.followSystemAppearance",
            "-v51.phoneLoginPreview",
        ])
        XCTAssertTrue(
            app.navigationBars["手机号登录"].waitForExistence(timeout: 5),
            "测试专用深链应保留手机号登录页"
        )
        snap("71-phone-login")
    }

    /// v50 W5：产品当前只支持竖屏。向 iPad 模拟器发出横屏请求后，App 内容区域
    /// 必须继续保持竖向几何；这是一条负向能力边界，不代表已支持横屏布局。
    func testV50IPadPortraitOnlyBoundary() {
        guard resetV47ShotDirectory() else { return }
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.training)
        let initialFrame = app.frame
        XCTAssertGreaterThan(initialFrame.height, initialFrame.width, "iPad 初始内容区域应为竖屏")

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(3)
        let afterRequestFrame = app.frame
        XCTAssertGreaterThan(
            afterRequestFrame.height,
            afterRequestFrame.width,
            "仅竖屏 App 不应接受横屏请求并变成横向内容区域"
        )
        snap("00-portrait-only-after-landscape-request")
        XCUIDevice.shared.orientation = .portrait
    }

    /// 轻量巡游：学练四页（瞄准原理 / 浅谈球感 / 进球点对照表 / 几何角度训练=角度预测），
    /// 用于视觉打磨的快速回归，避免完整巡游的会话态/Paywall 流程拖慢并触发模拟器不稳定。
    /// T-P18-46 真台化后每页加拍一帧下滑截图，覆盖页中下部的插图卡。
    /// 学区六文档页 + 角度预测巡游（v14 B3：原理/球感接壳 + 六页取证帧）。
    /// 依赖 `/tmp/qiuji-uitest/shot_dir` 或 `UI_POLISH_SHOT_DIR`，避免写入 docs/ui-polish 基线。
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
            ("学", "加塞吃库图谱", "a17-cushion-english-atlas"),
            ("学", "浅谈球感", "a11-ball-feel"),
            ("学", "瞄准点对照表", "a10-contact-point"),
            ("练", "角度预测", "a12-geometric-quiz"),
        ]
        for (tab, label, name) in pages {
            switchAngleHomeTab(tab)
            var opened = tapIfExists(label, timeout: 4)
            if !opened {
                app.swipeUp()
                usleep(500_000)
                opened = tapIfExists(label, timeout: 3)
            }
            if !opened {
                app.swipeDown()
                usleep(400_000)
                opened = tapIfExists(label, timeout: 3)
            }
            guard opened else { continue }
            sleep(3)
            snap(name)
            // v14 B3：六学页顶区别名帧（明/暗各跑一轮即可归档）。
            if name == "a09-aiming-principle" { snap("v14-b3-principle-top") }
            if name == "a13-aiming-methods" { snap("v14-b3-methods-top") }
            if name == "a16-aiming-correction" { snap("v14-b3-correction-top") }
            if name == "a14-spin-and-english" { snap("v14-b3-spin-top") }
            if name == "a11-ball-feel" { snap("v14-b3-ballfeel-top") }
            if name == "a10-contact-point" { snap("v14-b3-contact-top") }
            // 分离角图谱 / 加塞吃库图谱为场景交互页（非长文滚动）：额外等轨迹算完再拍默认态。
            if name == "a15-separation-angle-atlas" {
                sleep(2)
                snap("\(name)-default")
                snap("v14-b3-atlas-top")
                popBack()
                sleep(1)
                continue
            }
            if name == "a17-cushion-english-atlas" {
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
            // v14 B3：原理公式次级卡；球感全宽出血节。
            if name == "a09-aiming-principle" {
                app.swipeUp()
                sleep(1)
                snap("v14-b3-principle-formula")
                snap("\(name)-scrolled3")
            }
            if name == "a11-ball-feel" {
                app.swipeUp()
                sleep(1)
                snap("v14-b3-ballfeel-perspective")
                snap("\(name)-scrolled3")
            }
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

    /// v20 W2：加塞吃库图谱交互取证——默认态 / 高力度 / 拖球 / 球库点上+拖上 / 左缘横向图例。
    func testCushionEnglishAtlasInteractions() {
        // SceneKit 叠层下合成拖力度柱不可靠 → 启用页内 UI 测钩子（`-w2.uiHooks`）。
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-w2.uiHooks"])
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("学")
        sleep(1)
        guard tapIfExists("加塞吃库图谱", timeout: 4) else {
            XCTFail("加塞吃库图谱卡不可达")
            return
        }
        sleep(4) // 等 8 路并行 simulateFree
        snap("w2-atlas-default")

        let legend = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'cushionEnglishAtlas.spinLegend'"))
            .firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 3), "左缘 8 档左右塞色序图例不可达")

        let simMs = app.staticTexts["w2.parallelSimMs"]
        if simMs.waitForExistence(timeout: 3) {
            print("[W2-PERF] 8×simulateFree parallel \(simMs.label) ms (default scene, velocity 1.5)")
        }

        let bump = app.buttons["高力度"]
        XCTAssertTrue(bump.waitForExistence(timeout: 3), "w2.uiHooks「高力度」钩子不可达")
        bump.tap()
        sleep(5)
        snap("w2-atlas-high-power")
        XCTAssertTrue(app.staticTexts["5.5"].waitForExistence(timeout: 4),
                      "拉高力度后应出现读数 5.5（顶栏或仪表柱）")
        if simMs.exists {
            print("[W2-PERF] 8×simulateFree parallel \(simMs.label) ms (after bump, velocity 5.5)")
        }

        let table = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'cushionEnglishAtlas.root'")).firstMatch
        if table.waitForExistence(timeout: 2) {
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.48))
            let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.42))
            start.press(forDuration: 0.2, thenDragTo: end)
            sleep(3)
            snap("w2-atlas-drag-cut")
        }

        let tapBall = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__1'")).firstMatch
        XCTAssertTrue(tapBall.waitForExistence(timeout: 3), "球库 _1 槽位不可达")
        tapBall.tap()
        sleep(3)
        snap("w2-atlas-palette-tap")

        let dragBall = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__2'")).firstMatch
        if dragBall.waitForExistence(timeout: 2), table.exists {
            let start = dragBall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dest = table.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.40))
            start.press(forDuration: 0.25, thenDragTo: dest)
            sleep(3)
            snap("w2-atlas-palette-drag")
        } else {
            XCTFail("球库拖放路径不可达（paletteBall__2 或台面）")
        }

        XCTAssertEqual(app.state, .runningForeground, "交互后 App 应仍在前台")
    }

    /// v11 Y3 / v15 W1：分离角图谱交互取证——默认态 / 高力度 / 拖球 / 球库点上+拖上 / 左缘图例。
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

        // A2：左缘 8 只读迷你打点盘常驻（替代底部弹出盘）。
        let legend = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'separationAngleAtlas.spinLegend'"))
            .firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 3), "左缘 8 档色序图例不可达")

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

        // A3：球库点击上桌（paletteBall__1）。
        let tapBall = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__1'")).firstMatch
        XCTAssertTrue(tapBall.waitForExistence(timeout: 3), "球库 _1 槽位不可达")
        tapBall.tap()
        sleep(3)
        snap("y3-atlas-palette-tap")

        // A3：球库拖放到台（paletteBall__2 → 台面中部）。
        let dragBall = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__2'")).firstMatch
        if dragBall.waitForExistence(timeout: 2), table.exists {
            let start = dragBall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dest = table.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.40))
            start.press(forDuration: 0.25, thenDragTo: dest)
            sleep(3)
            snap("y3-atlas-palette-drag")
        } else {
            XCTFail("球库拖放路径不可达（paletteBall__2 或台面）")
        }

        XCTAssertEqual(app.state, .runningForeground, "交互后 App 应仍在前台")
    }

    /// v11 Y1 返工 r1（FL-026）+ v13 B1/B2：瞄准方法页交互取证——
    /// 管道节三态、接触点终帧+误差徽章、平行线 Q、符号图例、厚薄跟 θ。
    /// v14 B2：四交互学页顶区 + 控件条取证（依赖 `/tmp/qiuji-uitest/shot_dir` 或
    /// `UI_POLISH_SHOT_DIR`，避免写入 docs/ui-polish 基线）。
    func testV14B2InteractiveLearnShellShots() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)
        switchAngleHomeTab("学")
        sleep(1)

        let pages: [(label: String, snap: String, sliderId: String)] = [
            ("瞄准方法", "v14-b2-methods", "aimingMethods.thetaSlider"),
            ("瞄准修正", "v14-b2-correction", "aimingCorrection.velocitySlider"),
            ("旋转与加塞", "v14-b2-spin", "spinAndEnglish.thetaSlider"),
            ("瞄准点对照表", "v14-b2-contact", "contactPointTable.thetaSlider"),
        ]
        for page in pages {
            switchAngleHomeTab("学")
            var opened = tapIfExists(page.label, timeout: 4)
            if !opened {
                app.swipeUp()
                usleep(500_000)
                opened = tapIfExists(page.label, timeout: 3)
            }
            if !opened {
                app.swipeDown()
                usleep(400_000)
                opened = tapIfExists(page.label, timeout: 3)
            }
            guard opened else {
                XCTFail("\(page.label) 卡不可达")
                continue
            }
            sleep(2)
            XCTAssertTrue(app.navigationBars[page.label].waitForExistence(timeout: 6),
                          "应进入 \(page.label)")
            snap("\(page.snap)-top")
            let slider = app.sliders[page.sliderId]
            var guardCount = 0
            while (!slider.exists || !slider.isHittable || slider.frame.minY > 700),
                  guardCount < 6 {
                dragScrollUp(0.22)
                guardCount += 1
            }
            XCTAssertTrue(slider.waitForExistence(timeout: 4), "\(page.label) 主控件不可达")
            snap("\(page.snap)-controls")
            popBack()
            sleep(1)
        }
    }

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

        // v13 B2 A6：开篇符号图例入镜（进页即可见，先拍再调 θ）。
        let legend = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'aimingMethods.symbolLegend'"))
            .firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 4), "符号图例不可达")
        snap("v13-b2-symbol-legend")

        // v13 B1：先在页顶把 θ 调到 45°（φ 跟随，后续管道默认仍相切），再取厚薄非 30° 帧。
        let thetaSlider = app.sliders["aimingMethods.thetaSlider"]
        XCTAssertTrue(thetaSlider.waitForExistence(timeout: 4) && thetaSlider.isHittable,
                      "θ 滑杆不可达")
        // θ ∈ [5,75] → 45° 归一化位置 ≈ (45−5)/(75−5) = 0.571
        thetaSlider.adjust(toNormalizedSliderPosition: 0.571)
        sleep(1)

        // 管道节：B2 开篇图例加高后，需多滚直到 φ 滑杆可见且离开 Home 指示条
        // （上一轮教训：滑杆贴屏幕底缘时 adjust 合成拖拽会误触系统手势）。
        let phiSlider = app.sliders["aimingMethods.pipe.trialSlider"]
        var pipeGuard = 0
        while (!phiSlider.exists || !phiSlider.isHittable || phiSlider.frame.minY > 720
                || phiSlider.frame.maxY > 820), pipeGuard < 10 {
            dragScrollUp(0.28)
            pipeGuard += 1
        }
        // 滑杆太靠顶则略回滚，保证管道图+徽章同帧。
        if phiSlider.exists, phiSlider.frame.minY < 280 {
            dragScrollUp(-0.12)
        }
        if phiSlider.waitForExistence(timeout: 4), phiSlider.isHittable {
            snap("y1r1-pipe-tangent") // φ 已跟 θ=45 → ✓相切徽章
            // v13 B2 D-v13-3：节内 θ 读数与管道卡同帧。
            snap("v13-b2-pipe-theta-readout")
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

        // 接触点节：D-v13-2 默认终帧 + 误差角徽章常显；再重播取 B1 起/终帧。
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
            // B2：进入即碰合终帧 + 误差徽章（无需先点播放）。
            snap("v13-b2-contact-final-mislead-badge")
            play.tap() // 重播：瞬回起点再动画到终帧
            usleep(250_000) // 靠近起点，保留 B1 帧名
            snap("y1r1-contact-start")
            sleep(2) // 动画 1.2s
            snap("y1r1-contact-merged")
        } else {
            XCTFail("碰合播放键不可达")
        }

        // 平行线主图：滚到节标题，拍 Q 标注 + 节内 θ 读数。
        var parallelGuard = 0
        let parallelTitle = app.staticTexts["平行线瞄准法"]
        while (!parallelTitle.exists || parallelTitle.frame.minY > 520), parallelGuard < 10 {
            dragScrollUp(0.32)
            parallelGuard += 1
        }
        if parallelTitle.exists, parallelTitle.frame.minY < 60 {
            dragScrollUp(-0.10)
        }
        snap("v13-b2-parallel-q-label")

        // 滚到厚薄节标题可见，拍非 30° 重合示意（identifier 可能被子元素共享，故用标题定位）。
        var overlapGuard = 0
        let overlapTitle = app.staticTexts["补充：重合比例法（厚薄法）"]
        while (!overlapTitle.exists || overlapTitle.frame.minY > 620), overlapGuard < 12 {
            dragScrollUp(0.35)
            overlapGuard += 1
        }
        if overlapTitle.exists, overlapTitle.frame.minY < 80 {
            dragScrollUp(-0.12)
        }
        snap("v13-b1-overlap-theta45")
        // 再上滚：厚薄表行高亮入镜。
        dragScrollUp(0.28)
        sleep(1)
        snap("v13-b1-overlap-table-and-cta")
        // 相关页 CTA（含旋转与加塞）入镜——需滚过前两条才见后两条。
        dragScrollUp(0.40)
        sleep(1)
        snap("v13-b1-crossrefs-cta")
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
        let sidebar = app.buttons["sidebar_杆法"]
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
        // DR-063：BankShot 为 topDown2DRotated，袋口 chip 用 portrait 屏幕短名
        for pocket in ["左上角", "右下角", "右上角", "左侧中", "右侧中", "左下角"] {
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

        // 「我的模版」分段（现网用字；旧「自定义模版」不再上屏）
        if tapIfExists("我的模版", timeout: 2) || tapIfExists("自定义模版", timeout: 1) || tapIfExists("自定义", timeout: 1) {
            sleep(1)
            snap("02-training-custom-tab")
            _ = tapIfExists("官方计划", timeout: 2)
            sleep(1)
        } else {
            XCTFail("完整巡游无法打开训练 / 我的模版")
        }

        // 顶部菜单进入训练计划列表
        if openTrainingHomeMenu() {
            sleep(1)
            if app.buttons["训练计划"].waitForExistence(timeout: 2) {
                app.buttons["训练计划"].tap()
                sleep(2)
                snap("03-plan-list")
                popBack()
            } else {
                XCTFail("训练首页更多菜单缺少训练计划")
                app.tap() // 关闭菜单
            }
        } else {
            XCTFail("训练首页无法打开更多菜单")
        }

        // 直接从首页计划卡片进入计划详情
        let planCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '新手入门' OR label CONTAINS '基础杆法' OR label CONTAINS '第 1 期'")).firstMatch
        if planCard.waitForExistence(timeout: 3) {
            planCard.tap()
            sleep(2)
            snap("04-plan-detail")
            popBack()
        } else {
            XCTFail("完整巡游无法打开训练计划详情")
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
        var attemptedDetail = false
        if drillCard.waitForExistence(timeout: 4) {
            drillCard.tap()
            attemptedDetail = true
        } else {
            let cell = app.cells.firstMatch
            if cell.waitForExistence(timeout: 4) {
                cell.tap()
                attemptedDetail = true
            }
        }
        guard attemptedDetail else {
            XCTFail("完整巡游无法打开动作详情")
            return
        }

        let detailCTA = app.buttons["bottomTryoutButton"]
        if !detailCTA.waitForExistence(timeout: 3), drillCard.exists {
            // 避开卡片右上角的收藏按钮，在内容区重试一次。
            drillCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        }
        guard detailCTA.waitForExistence(timeout: 5) else {
            XCTFail("完整巡游点击动作卡后未进入动作详情")
            return
        }
        snap("06-drill-detail-top")
        app.scrollDown(times: 2)
        sleep(1)
        snap("07-drill-detail-bottom")
        popBack()
        sleep(1)
    }

    // MARK: 角度 Tab（学/练/打/解 全入口卡各截一帧默认态）

    private var v56LearnCorePages: [(String, String, String)] {
        [
            ("学", "瞄准原理", "09-aiming-principle"),
            ("学", "角度与瞄准", "10-angle-dynamic"),
            ("学", "浅谈球感", "11-ball-feel"),
            ("学", "瞄准点对照表", "12-contact-point-table"),
        ]
    }

    private var v56PracticePages: [(String, String, String)] {
        [
            ("练", "角度预测", "13-geometric-quiz"),
            ("练", "2D 角度训练", "14-scene-aiming-2d"),
            ("练", "3D 角度训练", "15-scene-aiming-3d"),
            ("练", "瞄准点训练", "16-aimpoint-training"),
            ("练", "2D 瞄准点训练", "17-aimpoint-scene-2d"),
            ("练", "3D 瞄准点训练", "18-aimpoint-scene-3d"),
        ]
    }

    private var v56PlayAndSolvePages: [(String, String, String)] {
        [
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
    }

    private func tourAngleLandingPages() {
        app.switchTab(.angle)
        sleep(2)
        snap("08-angle-home-all")
        switchAngleHomeTab("学"); snap("08a-angle-home-learn")
        switchAngleHomeTab("理"); snap("08a2-angle-home-theory")
        switchAngleHomeTab("练"); snap("08b-angle-home-train")
        switchAngleHomeTab("打"); snap("08c-angle-home-play")
        switchAngleHomeTab("解"); snap("08d-angle-home-solve")
    }

    private func tourAnglePages(_ pages: [(String, String, String)]) {
        app.switchTab(.angle)
        sleep(2)
        for (tab, label, name) in pages {
            _ = switchAngleHomeTab(tab)
            if tapAngleCard(label, tab: tab) {
                sleep(3)
                XCTAssertFalse(
                    app.staticTexts["解锁球迹 Pro"].exists,
                    "Pro 巡游进入 \(label) 时不得把 Paywall 当作目标页"
                )
                // 只有瞄准训练会先展示设置 sheet。页面已稳定后先做无等待探测，
                // 避免其余二十余个工具页各自空等 4 秒。
                if app.buttons["开始训练"].exists {
                    startAimingTrainingFromSheet()
                }
                if label == "翻袋解球器" { ensureBankSolution() }
                snap(name)
                popBack()
                sleep(1)
            } else {
                XCTFail("完整巡游无法打开 \(tab) / \(label)")
            }
        }
    }

    private func tourAngle() {
        tourAngleLandingPages()
        tourAnglePages(v56LearnCorePages + v56PracticePages + v56PlayAndSolvePages)
    }

    // MARK: 记录 Tab

    private func tourHistory() {
        app.switchTab(.history)
        sleep(2)
        snap("40-history-calendar")

        let statsAny = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '统计'")).firstMatch
        for attempt in 0..<2 {
            if statsAny.waitForExistence(timeout: 5), statsAny.isHittable {
                statsAny.tap()
                sleep(2)
                snap("41-history-statistics")
                return
            }
            if attempt == 0 {
                app.activate()
                app.switchTab(.history)
                sleep(1)
            }
        }
        XCTFail("完整巡游无法在有界恢复后打开记录 / 统计")
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
            guard openProfileDestination(label) else {
                XCTFail("完整巡游无法在有界恢复后打开我的 / \(label)")
                continue
            }
            sleep(1)
            snap(name)
            popBack()
            sleep(1)
        }
    }

    // MARK: 设计师整页补拍（巡游未覆盖的常规页）

    private func tourCustomPlanBuilder() {
        app.switchTab(.training)
        sleep(1)
        if openTrainingHomeMenu() {
            sleep(1)
            if tapIfExists("新建模版", timeout: 2) {
                sleep(2)
                snap("04b-custom-plan-builder")
                popBack()
                sleep(1)
                return
            }
            XCTFail("训练首页更多菜单缺少新建模版")
            app.tap()
        } else {
            XCTFail("训练首页无法打开更多菜单以进入新建模版")
        }
    }

    private func tourDrillTutorial() {
        app.switchTab(.drillLibrary)
        sleep(2)
        let drillCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
        guard drillCard.waitForExistence(timeout: 4) else {
            XCTFail("完整巡游无法为精讲打开动作详情")
            return
        }
        drillCard.tap()
        let detailCTA = app.buttons["bottomTryoutButton"]
        if !detailCTA.waitForExistence(timeout: 3), drillCard.exists {
            drillCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        }
        guard detailCTA.waitForExistence(timeout: 5) else {
            XCTFail("完整巡游无法为精讲进入动作详情")
            return
        }
        var openedTutorial = tapIfExists("查看精讲", timeout: 2)
        for _ in 0..<4 where !openedTutorial {
            let scroll = app.scrollViews.firstMatch
            if scroll.exists {
                scroll.swipeUp(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
            usleep(400_000)
            openedTutorial = tapIfExists("查看精讲", timeout: 1)
        }
        guard openedTutorial else {
            XCTFail("完整巡游动作详情缺少查看精讲入口")
            popBack()
            return
        }
        sleep(2)
        snap("07b-drill-tutorial")
        popBack()
        sleep(1)
        popBack()
        sleep(1)
    }

    private func tourRemainingLearnPages() {
        let pages: [(String, String)] = [
            ("瞄准方法", "09b-aiming-methods"),
            ("瞄准修正", "09c-aiming-correction"),
            ("旋转与加塞", "09d-spin-and-english"),
            ("分离角图谱", "09e-separation-angle-atlas"),
            ("加塞吃库图谱", "09f-cushion-english-atlas"),
        ]
        for (label, name) in pages {
            _ = switchAngleHomeTab("学")
            let opened = tapAngleCard(label, tab: "学")
            if opened {
                sleep(3)
                snap(name)
                popBack()
                sleep(1)
            } else {
                XCTFail("完整巡游无法打开学 / \(label)")
            }
        }
    }

    private func tourAllTheoryPages() {
        let pages: [(String, String)] = [
            ("30° 法则", "12c-theory-t01"),
            ("90° 法则", "12d-theory-t02"),
            ("切线法则", "12e-theory-t03"),
            ("母球速度分级", "12f-theory-t04"),
            ("最少加塞原则", "12g-theory-t09"),
            ("反向规划", "12h-theory-t05"),
            ("关键球原理", "12i-theory-t06"),
            ("球团管理", "12j-theory-t07"),
            ("风险报酬决策矩阵", "12k-theory-t08"),
            ("安全球三维度模型", "12l-theory-t10"),
            ("清台 5 步决策流程", "12m-theory-flow"),
            ("清台速查手册", "12n-theory-quickref"),
        ]
        for (title, name) in pages {
            guard TheoryIndexNavigation.openPage(in: app, cardTitle: title) else {
                XCTFail("完整巡游无法打开球理 / \(title)")
                continue
            }
            sleep(2)
            snap(name)
            popBack()
            sleep(1)
        }
    }

    private func tourFavoritesAndSubscriptionStatus() {
        let pages = [
            ("我的收藏", "56-profile-favorites"),
            ("订阅管理", "57-subscription-status"),
        ]
        for (label, name) in pages {
            guard openProfileDestination(label) else {
                XCTFail("完整巡游无法在有界恢复后打开我的 / \(label)")
                continue
            }
            sleep(1)
            snap(name)
            popBack()
            sleep(1)
        }
    }

    private func tourLogin() {
        // 会话态页面会隐藏 Tab bar；登录证据必须从独立根会话进入，不能依赖前页 AX 树。
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v51.followSystemAppearance",
        ])
        sleep(2)
        app.switchTab(.profile)
        sleep(1)
        guard openProfileLogin() else {
            XCTFail("个人页无法找到稳定的登录入口")
            return
        }
        assertCurrentLoginContract()
        snap("70-login")

        // Phone sign-in is unavailable from the production sheet. Keep its retained
        // form in the 66-file responsive matrix through a UI-test-only deep link.
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v51.followSystemAppearance",
            "-v51.phoneLoginPreview",
        ])
        guard app.navigationBars["手机号登录"].waitForExistence(timeout: 5) else {
            XCTFail("手机号登录页未能通过测试专用深链打开")
            return
        }
        snap("71-phone-login")
    }

    private func tourOnboarding() {
        app.terminate()
        let fresh = XCUIApplication()
        fresh.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        fresh.launchArguments += ["-AppleLocale", "zh_CN"]
        fresh.launchArguments += ["-hasCompletedOnboarding", "NO"]
        fresh.launchArguments += ["-resetDebugPremium"]
        fresh.launchArguments += ["-v51.followSystemAppearance"]
        fresh.launch()
        app = fresh
        sleep(3)
        snap("72-onboarding")
    }

    // MARK: 弹窗 / 会话态流程（放最后）

    private func tourModalFlows() {
        let matrixDirectory = v47ForcedShotDirURL
        let supplementalDirectory = v56MatrixShotDirURL
            .appendingPathComponent("_supplemental", isDirectory: true)

        // 订阅 Paywall
        app.switchTab(.profile)
        sleep(1)
        app.scrollUp(times: 4)
        sleep(1)
        if tapIfExists("解锁球迹 Pro", timeout: 2) || tapIfExists("升级 Pro", timeout: 2) || tapIfExists("订阅管理", timeout: 2) {
            sleep(3)
            v47ForcedShotDirURL = supplementalDirectory
            snap("60-subscription-paywall")
            // 等待产品加载超时（8s）后捕获错误/重试兜底态（U-04）
            sleep(8)
            snap("61-subscription-paywall-timeout")
            v47ForcedShotDirURL = matrixDirectory
            app.swipeDown()
            sleep(1)
        }

        // 自由记录 → 进入训练会话（含 drill picker sheet）
        // Paywall 的系统 sheet 在部分 Runtime 下下拉后会短暂保留不可交互的 AX 树；
        // 从干净根会话继续，避免把系统转场时序误判成产品页缺失。
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        sleep(2)
        app.switchTab(.training)
        sleep(2)
        if tapIfExists("自由记录", timeout: 3) {
            sleep(2)
            v47ForcedShotDirURL = supplementalDirectory
            snap("62-free-record-session")
            v47ForcedShotDirURL = matrixDirectory
        }
    }
}
