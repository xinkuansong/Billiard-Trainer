import XCTest

extension XCUIApplication {

    // MARK: - Tab Navigation

    enum Tab: String {
        case training = "训练"
        case drillLibrary = "动作库"
        case angle = "角度"
        case history = "记录"
        case profile = "我的"
    }

    func switchTab(_ tab: Tab) {
        // 冷启动可能 >3s 才出现 TabBar：先等待存在再点，规避偶发 "No matches for TabBar"。
        let button = tabBars.buttons[tab.rawValue]
        _ = button.waitForExistence(timeout: 20)
        button.tap()
    }

    // MARK: - Launch Helpers

    static func launchClean() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launchArguments += ["-AppleLocale", "zh_CN"]
        app.launch()
        // 偶发：安装/启动竞态导致 app 进程秒退。用进程状态判断（不走 AX 快照，
        // 避免主线程繁忙时误判），不在前台才重启动。
        for _ in 0..<2 {
            sleep(3)
            if app.state == .runningForeground { break }
            app.launch()
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
