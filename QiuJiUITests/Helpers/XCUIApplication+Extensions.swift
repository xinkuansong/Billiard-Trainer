import XCTest

extension XCUIApplication {

    // MARK: - Tab Navigation

    enum Tab: String {
        case training = "训练"
        case drillLibrary = "动作库"
        case angle = "练习"
        case history = "记录"
        case profile = "我的"
    }

    func switchTab(_ tab: Tab) {
        // 冷启动可能 >3s 才出现 TabBar：先等待存在再点，规避偶发 "No matches for TabBar"。
        if tabBars.firstMatch.waitForExistence(timeout: 5) {
            let tabBarButton = tabBars.buttons[tab.rawValue]
            if tabBarButton.waitForExistence(timeout: 15) {
                tabBarButton.tap()
                return
            }
        }

        // iOS 26 floating tab bar may expose its item as a Cell-backed button outside TabBar descendants.
        let floatingTabButton = buttons[tab.rawValue].firstMatch
        XCTAssertTrue(
            floatingTabButton.waitForExistence(timeout: 5),
            "Tab '\(tab.rawValue)' should exist"
        )
        floatingTabButton.tap()
    }

    // MARK: - Launch Helpers

    static func launchClean(extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launchArguments += ["-AppleLocale", "zh_CN"]
        // 跳过 Onboarding，避免新鲜模拟器上 TabBar 尚未出现导致 switchTab 失败。
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        // 清掉手动「模拟器解锁 Pro」的 UserDefaults，避免污染免费档用例。
        app.launchArguments += ["-resetDebugPremium"]
        app.launchArguments += extraArgs
        app.launch()
        // 偶发：安装/启动竞态导致 app 进程秒退。用进程状态判断（不走 AX 快照，
        // 避免主线程繁忙时误判），不在前台才重启动。
        for _ in 0..<2 {
            sleep(3)
            if app.state == .runningForeground { break }
            app.launch()
        }
        // 兜底：若仍停在 Onboarding，点「跳过」。
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 2) {
            skip.tap()
            sleep(1)
        }
        return app
    }

    // MARK: - Wait Helpers

    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: - Scroll Helpers

    func scrollDown(in element: XCUIElement? = nil, times: Int = 1) {
        let target = element ?? swipeTargetElement
        for _ in 0..<times {
            target.swipeUp()
        }
    }

    func scrollUp(in element: XCUIElement? = nil, times: Int = 1) {
        let target = element ?? swipeTargetElement
        for _ in 0..<times {
            target.swipeDown()
        }
    }

    private var swipeTargetElement: XCUIElement {
        windows.firstMatch
    }

    // MARK: - Navigation

    func tapBackButton() {
        navigationBars.buttons.element(boundBy: 0).tap()
    }

    // MARK: - Assertions

    func assertTabBarVisible() {
        XCTAssertTrue(tabBars.element.exists, "Tab bar should be visible")
    }

    func assertElementExists(_ identifier: String, type: XCUIElement.ElementType = .any, message: String? = nil) {
        let element: XCUIElement
        switch type {
        case .staticText:
            element = staticTexts[identifier]
        case .button:
            element = buttons[identifier]
        default:
            element = descendants(matching: .any)[identifier]
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3), message ?? "Element '\(identifier)' should exist")
    }
}
