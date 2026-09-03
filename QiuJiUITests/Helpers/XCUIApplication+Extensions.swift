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
        // iOS 26 may expose a floating/top tab item as PopUpButton instead of Button.
        // Long screenshot tours can also receive one transiently empty AX snapshot after
        // a soft restart, so activate and retry a bounded number of times before failing.
        for attempt in 0..<3 {
            if attempt > 0 {
                activate()
                sleep(1)
            }

            // Query by semantic identity before asking for a TabBar container. iPadOS 26
            // often exposes the top floating tabs as scope PopUpButtons with no TabBar
            // ancestor, and waiting for that absent container on every soft restart can
            // push the 66-page tour into the XCTest host timeout.
            let candidates = descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier == %@ OR label == %@",
                    tab.rawValue,
                    tab.rawValue
                )
            )
            if candidates.firstMatch.waitForExistence(timeout: attempt == 0 ? 5 : 2) {
                for index in 0..<min(candidates.count, 8) {
                    let candidate = candidates.element(boundBy: index)
                    if candidate.exists, candidate.isHittable {
                        candidate.tap()
                        return
                    }
                }
            }
        }

        XCTFail("Tab '\(tab.rawValue)' should exist and be hittable after bounded recovery")
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
        // `-hasCompletedOnboarding YES` 已把普通测试固定在主界面。不要在启动期
        // 额外查询“跳过”按钮：iPad AX 服务繁忙时，名义 2 秒的不存在查询可能
        // 膨胀到数分钟并让整条长巡游在第一张截图前超时。Onboarding 专项测试
        // 使用独立 XCUIApplication 和显式 NO 参数，不经过此 helper。
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
