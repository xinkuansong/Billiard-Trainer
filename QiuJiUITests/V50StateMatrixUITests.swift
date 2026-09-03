import XCTest

/// v50 W6：四个锚点共享的状态、最大字号与 AX 契约。
/// 数据态使用显式内存库，避免把其他测试或人工操作留下的 SwiftData 当成 fixture。
final class V50StateMatrixUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchCompletionAndRelaunchPersistence() throws {
        app = launch(onboarding: false, extra: ["-v50.inMemoryStore"])
        XCTAssertTrue(app.staticTexts["看懂球路，再开始练"].waitForExistence(timeout: 8))
        try capture("onboarding-1-route")

        for expected in ["记录每杆，复盘趋势", "球迹"] {
            let next = app.buttons["继续"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), "引导中途页必须可继续")
            next.tap()
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5))
        }
        try capture("onboarding-3-summary")

        let start = app.buttons["开始使用"]
        XCTAssertTrue(start.isHittable, "最大字号下开始使用必须可点击")
        start.tap()
        assertMainTabsVisible()
        try capture("onboarding-completed")

        app.terminate()
        // 不再传 hasCompletedOnboarding，必须读取上一次点击写入的 UserDefaults。
        app = launch(onboarding: nil, extra: ["-v50.inMemoryStore"])
        assertMainTabsVisible()
        XCTAssertFalse(app.buttons["继续"].exists, "完成引导后重启不得再次进入引导")
        try capture("onboarding-relaunch-persisted")
    }

    func testGuestFreeAndForcedProBoundaries() throws {
        app = launch(onboarding: true, extra: ["-v50.inMemoryStore"])
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 6), "游客必须有登录入口")
        XCTAssertTrue(app.staticTexts["游客模式"].exists)
        XCTAssertTrue(app.staticTexts["升级 Pro"].waitForExistence(timeout: 5), "免费态必须明确升级入口")
        try capture("identity-guest-free")

        app.terminate()
        app = launch(
            onboarding: true,
            extra: ["-v50.inMemoryStore", "-forceNonPremium", "-deeplink.drillDetail=drill_c039", "-v49.forceLight"]
        )
        XCTAssertTrue(app.buttons["unlockProButton"].waitForExistence(timeout: 8), "免费用户的 Pro 动作必须门控")
        XCTAssertFalse(app.buttons["bottomTryoutButton"].isHittable, "免费态不得绕过试打门控")
        try capture("identity-free-pro-gate")

        app.terminate()
        app = launch(
            onboarding: true,
            extra: ["-v50.inMemoryStore", "-forcePremium", "-deeplink.drillDetail=drill_c039", "-v49.forceLight"]
        )
        XCTAssertTrue(app.buttons["bottomTryoutButton"].waitForExistence(timeout: 8), "forced Pro 必须解锁同一入口")
        XCTAssertFalse(app.buttons["unlockProButton"].exists, "Pro 态不得残留免费门控")
        try capture("identity-forced-pro")
    }

    func testFiveRootsAndLongContentAtCurrentContentSize() throws {
        app = launch(onboarding: true, extra: ["-v50.inMemoryStore", "-forcePremium"])

        app.switchTab(.training)
        let trainingState = app.staticTexts["今日训练待安排"]
        XCTAssertTrue(trainingState.waitForExistence(timeout: 8), "内存空库应呈现明确训练空态")
        // 空态同时有一个文字链接“自由记录”和固定 64pt 主 CTA；44pt 命中区
        // 契约必须绑定后者，不能让 firstMatch 随 AX 树顺序漂移。
        let primaryCTA = app.buttons["trainingHome.freeRecord"]
        XCTAssertTrue(primaryCTA.waitForExistence(timeout: 5), "训练首页空态主 CTA 必须有稳定 AX 标识")
        assertInWindow(primaryCTA)
        try capture("ax-root-training")

        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        assertInWindow(search, minimumHeight: nil)
        try capture("ax-root-library")

        app.switchTab(.angle)
        let learn = app.descendants(matching: .any)["angleHomeTab_理"]
        XCTAssertTrue(learn.waitForExistence(timeout: 8))
        assertInWindow(learn)
        try capture("ax-root-practice")

        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 8), "空库必须给出记录空态")
        try capture("ax-root-history-empty")

        app.switchTab(.profile)
        let profileLogin = app.buttons["profile.login"]
        XCTAssertTrue(profileLogin.waitForExistence(timeout: 8))
        assertInWindow(profileLogin)
        try capture("ax-root-profile")

        XCTAssertTrue(TheoryIndexNavigation.openPage(in: app, cardTitle: "球团管理"))
        XCTAssertTrue(app.descendants(matching: .any)["theoryPage_t07"].waitForExistence(timeout: 6))
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "长球理页必须可滚动")
        for _ in 0..<8 { scroll.swipeUp(velocity: .fast) }
        XCTAssertTrue(app.navigationBars["球团管理"].exists, "滚到底后仍应留在同一页")
        try capture("ax-long-theory-bottom")
    }

    func testProfileAndPlanKeyboardReachability() throws {
        app = launch(onboarding: true, extra: ["-v50.inMemoryStore", "-forcePremium"])
        app.switchTab(.profile)
        let personalInfo = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '个人信息'")
        ).firstMatch
        XCTAssertTrue(personalInfo.waitForExistence(timeout: 5))
        personalInfo.tap()
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 6))
        app.buttons["球迹用户"].tap()
        let name = app.textFields["输入昵称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertInWindow(name, minimumHeight: nil)
        XCTAssertTrue(app.buttons["完成"].isHittable, "昵称键盘态必须可完成")
        try capture("keyboard-profile-name")

        app.terminate()
        app = launch(onboarding: true, extra: ["-v50.inMemoryStore", "-forcePremium"])
        app.switchTab(.training)
        let menu = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 6))
        menu.tap()
        XCTAssertTrue(app.buttons["新建模版"].waitForExistence(timeout: 4))
        app.buttons["新建模版"].tap()
        let planName = app.textFields["customPlanNameField"]
        XCTAssertTrue(planName.waitForExistence(timeout: 6))
        planName.tap()
        planName.typeText("最大字号模版")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        assertInWindow(planName, minimumHeight: nil)
        XCTAssertTrue(app.navigationBars["新建模版"].exists)
        try capture("keyboard-custom-plan")
    }

    private func launch(onboarding: Bool?, extra: [String]) -> XCUIApplication {
        let candidate = XCUIApplication()
        candidate.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-resetDebugPremium"]
        if let onboarding {
            candidate.launchArguments += ["-hasCompletedOnboarding", onboarding ? "YES" : "NO"]
        }
        candidate.launchArguments += extra
        candidate.launch()
        return candidate
    }

    private func assertMainTabsVisible(file: StaticString = #filePath, line: UInt = #line) {
        let training = app.tabBars.buttons[XCUIApplication.Tab.training.rawValue].firstMatch
        let floating = app.buttons[XCUIApplication.Tab.training.rawValue].firstMatch
        XCTAssertTrue(
            training.waitForExistence(timeout: 8) || floating.waitForExistence(timeout: 3),
            "主界面五 Tab 必须出现",
            file: file,
            line: line
        )
    }

    private func assertInWindow(
        _ element: XCUIElement,
        minimumHeight: CGFloat? = 44,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "元素必须存在", file: file, line: line)
        XCTAssertTrue(element.isHittable, "元素必须可点击", file: file, line: line)
        let window = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(window.intersects(element.frame), "元素不得完全落在窗口外", file: file, line: line)
        if let minimumHeight {
            XCTAssertGreaterThanOrEqual(
                element.frame.height,
                minimumHeight,
                "主要按钮命中高度不得小于 \(minimumHeight)pt",
                file: file,
                line: line
            )
        }
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["V50_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V50_SHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name).png"),
            options: .atomic
        )
    }
}
