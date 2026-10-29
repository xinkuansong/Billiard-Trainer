import XCTest

extension XCUIApplication {

    /// Window tests restore the real iPad window, including across app relaunches.
    /// A floating window keeps its aspect ratio when the device rotates.
    func maximizeTrainingTestWindow() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        // UIScreen.main.bounds may follow the app's floating scene on iPadOS 26.
        // SpringBoard exposes the actual current display frame.
        let display = XCUIApplication(bundleIdentifier: "com.apple.springboard").frame
        let window = windows.firstMatch
        func isFullscreen() -> Bool {
            let frame = window.frame
            return abs(frame.minX - display.minX) < 1 && abs(frame.minY - display.minY) < 1
                && abs(frame.width - display.width) < 1 && abs(frame.height - display.height) < 1
        }
        print("TRAINING_WINDOW display=\(display) window=\(window.frame)")
        guard window.waitForExistence(timeout: 5), !isFullscreen() else { return }
        window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in isFullscreen() }, object: window)
        if XCTWaiter.wait(for: [expanded], timeout: 2) != .completed {
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            isFullscreen()
        }, object: window)], timeout: 8), .completed, "Restore full display bounds before a new independent trial")
    }

    /// Historical test names describe the projection, not separate home cards.
    static func trainingCardTitle(_ title: String) -> String {
        let names = ["角度", "瞄准点", "准度", "分离角", "两球走位", "三球走位", "多球走位"]
        for name in names {
            if ["2D" + name, "3D" + name, "2D " + name + "训练", "3D " + name + "训练"].contains(title) { return ["角度", "瞄准点", "准度", "分离角"].contains(name) ? name + "练习" : name }
        }
        return title
    }

    /// Select the requested view through the real menu after starting a merged project.
    /// Do not call this when asserting that a previously chosen view survived restore.
    func selectTrainingView(_ title: String) {
        guard Self.trainingCardTitle(title) != title else { return }
        maximizeTrainingTestWindow()
        let name = Self.trainingCardTitle(title)
        let prefixes = ["角度练习": "angleTraining", "瞄准点练习": "aimPointTraining", "准度练习": "accuracy",
                        "分离角练习": "separation", "两球走位": "twoBall", "三球走位": "threeBall", "多球走位": "multiBall"]
        guard let prefix = prefixes[name] else { XCTFail("Unknown training project: " + title); return }
        XCTAssertTrue(buttons[prefix + ".start"].waitForNonExistence(timeout: 180))
        let moreID = prefix == "multiBall" ? "freeplay.moreMenu" : prefix + (["angleTraining", "aimPointTraining"].contains(prefix) ? ".settings" : ".more")
        let more = buttons[moreID]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: more)], timeout: 60), .completed)
        more.tap()
        let mode = descendants(matching: .any).matching(identifier: (prefix == "multiBall" ? "freeplay" : prefix) + ".cameraMode").firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        let expected = title.hasPrefix("3D") ? "3D" : "2D"
        if mode.value as? String != expected { mode.tap() }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "value == %@", expected), object: mode)], timeout: 10), .completed)
        let close = descendants(matching: .any).matching(identifier: prefix == "multiBall" ? "dailyClearance.menuClose" : prefix + ".dismissMenu").firstMatch
        if prefix == "multiBall", !close.exists {
            let backdrop = buttons["关闭菜单"].firstMatch
            XCTAssertTrue(backdrop.waitForExistence(timeout: 5))
            backdrop.coordinate(withNormalizedOffset: .init(dx: 0.03, dy: 0.7)).tap()
        } else {
            XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        }
        XCTAssertTrue(mode.waitForNonExistence(timeout: 5))
    }

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
        // Account tests bypass both legacy onboarding and the new first-run flow.
        // Dedicated onboarding tests own a separate progress domain and must keep it intact.
        if !extraArgs.contains(where: { $0.hasPrefix("-firstRun.fixture=") }) {
            app.launchArguments += ["-firstRun.profileFlow.v1", "completed"]
        }
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
