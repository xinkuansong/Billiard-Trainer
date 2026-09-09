import XCTest

/// Unregistered diagnostic draft: ordinary M2 disk launch and a real first notification refusal.
final class M2StartupPermissionDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var sequence = 0
    private enum Failure: Error { case requirement(String) }
    private func env(_ key: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return e[key] ?? e["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("terminal-unclassified") }
    }

    func testOrdinaryM2EmptyGuestStartupAndFirstNotificationDenialSurvivePageReentry() throws {
        try require(env("QD_M2_STARTUP_AUTHORIZATION") == "NEW_SE3_IOS17_LARGE_LIGHT_EMPTY_DISK_UNDECIDED", "External new SE3/iOS17 large/light empty disk and undecided permission evidence required")
        guard let expected = env("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env("SIMULATOR_UDID")?.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Runner must match authorized new device UUID") }
        try require(ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 17, "This representative case requires iOS 17")
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Failure.requirement("Absolute evidence root required") }
        output = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("m2-startup-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: output.path), "New evidence directory required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        print("[QD-M2Startup] evidence=\(output.path)")
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment = [:]
        do {
            app.launch()
            try require(app.wait(for: .runningForeground, timeout: 15), "Normal foreground process required")
            let training = try tabElement("训练")
            try require(training.isSelected, "Ordinary RootView must show initial training Tab")
            let free = app.buttons.matching(identifier: "trainingHome.freeRecord")
            try require(free.count == 1, "Actual empty-home free-record CTA required")
            try reveal(free.firstMatch)
            try require(app.staticTexts["选择一个计划开始训练"].exists, "Actual empty-home explanation required")
            try require(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "trainingHome.scheduleItem.")).count == 0, "New home must not have queued source cards")
            try capture("ordinary-empty-training-home")
            try guestProfile()
            try capture("ordinary-guest-profile")
            try openGoal()
            let toggle = app.switches["trainingGoal.reminderEnabled"]
            try reveal(toggle)
            try state("首次开启时会请求系统通知权限")
            try capture("first-request-before")
            try tap(toggle)
            try until("Real system notification choices required") { self.permissionAlerts(self.springboard).count == 1 || self.permissionAlerts(self.app).count == 1 }
            // The same OS alert can be exposed by both applications. Prefer its SpringBoard host.
            let systemAlerts = permissionAlerts(springboard)
            let appAlerts = permissionAlerts(app)
            try require(systemAlerts.count <= 1 && appAlerts.count <= 1 && (!systemAlerts.isEmpty || !appAlerts.isEmpty), "Missing or ambiguous permission alerts must stop")
            let alert = systemAlerts.count == 1 ? systemAlerts[0] : appAlerts[0]
            try require(alert.label.contains("通知") || alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "通知")).count > 0 || alert.label.contains("Notifications"), "Must be notification permission, not another two-choice prompt")
            try capture("actual-system-notification-prompt")
            let deny = alert.buttons.matching(denyPredicate)
            try require(deny.count == 1 && alert.buttons.matching(allowPredicate).count == 1, "Both unique actual OS choices required")
            try tap(deny.firstMatch)
            let failure = app.alerts["无法开启提醒"]
            try until("App must explain denied permission") { failure.exists }
            try capture("denied-app-explanation")
            let acknowledge = failure.buttons.matching(identifier: "知道了")
            try require(acknowledge.count == 1, "Unique acknowledgement required")
            try tap(acknowledge.firstMatch)
            try until("App explanation dismissed") { !failure.exists }
            let denied = "系统通知权限未开启，请前往系统设置允许通知"
            try state(denied)
            try capture("denied-off-before-return")
            let navs = app.navigationBars.matching(identifier: "训练目标")
            try require(navs.count == 1, "One actual goal navigation bar required")
            // iOS17 M2 archived template AX exposes exact label 返回, not BackButton.
            // Scope to this page; if this page differs, fail and retain its actual AX.
            let back = navs.firstMatch.buttons.matching(NSPredicate(format: "label == %@", "返回"))
            try require(back.count == 1, "Require exact page-scoped iOS17 back label; no first-button fallback")
            try tap(back.firstMatch)
            try until("Goal must close and profile Tab return") { !self.app.navigationBars["训练目标"].exists && self.app.tabBars.buttons["我的"].exists }
            try guestProfile()
            try openGoal()
            try reveal(app.switches["trainingGoal.reminderEnabled"])
            try state(denied)
            try require(permissionAlerts(springboard).isEmpty && permissionAlerts(app).isEmpty, "Reentry must not request permission again")
            try capture("verified-reentered-denied-off")
        } catch {
            try capture("failure-before-termination")
            throw error
        }
    }
    private var allowPredicate: NSPredicate { NSPredicate(format: "label == %@ OR label == %@", "允许", "Allow") }
    private var denyPredicate: NSPredicate { NSPredicate(format: "label == %@ OR label == %@", "不允许", "Don't Allow") }
    private func permissionAlerts(_ host: XCUIApplication) -> [XCUIElement] {
        host.alerts.allElementsBoundByIndex.filter { $0.buttons.matching(allowPredicate).count == 1 && $0.buttons.matching(denyPredicate).count == 1 }
    }
    private func state(_ expected: String) throws {
        try until("Exact authorization and idle off switch required") {
            let toggle = self.app.switches["trainingGoal.reminderEnabled"]
            return toggle.exists && toggle.isEnabled && (toggle.value as? String) == "0" && self.app.staticTexts["trainingGoal.reminderAuthorization"].label == expected
        }
        try require(!app.descendants(matching: .any)["trainingGoal.reminderTime"].exists, "Off reminder must not show time picker")
    }
    private func tabElement(_ label: String) throws -> XCUIElement {
        try until("Actual TabBar required") { self.app.tabBars.count == 1 }
        let tabs = app.tabBars.firstMatch.buttons.matching(NSPredicate(format: "label == %@", label))
        try require(tabs.count == 1, "Unique named Tab required")
        return tabs.firstMatch
    }
    private func guestProfile() throws {
        let tab = try tabElement("我的")
        try tap(tab)
        try until("Guest profile must load") { self.app.buttons["profile.login"].exists }
        try require(tab.isSelected && app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Only actual guest may change reminder")
    }
    private func openGoal() throws {
        let rows = app.staticTexts.matching(identifier: "训练目标")
        try require(rows.count == 1, "Unique normal profile goal row required")
        try reveal(rows.firstMatch)
        try tap(rows.firstMatch)
        try until("Actual goal page required") { self.app.navigationBars.matching(identifier: "训练目标").count == 1 }
    }
    private func fullyVisible(_ e: XCUIElement) -> Bool {
        guard e.exists, !e.frame.isEmpty, app.windows.firstMatch.frame.contains(e.frame) else { return false }
        if app.navigationBars.firstMatch.exists && e.frame.minY < app.navigationBars.firstMatch.frame.maxY { return false }
        if app.tabBars.firstMatch.exists && e.frame.maxY > app.tabBars.firstMatch.frame.minY { return false }
        return true
    }
    private func reveal(_ e: XCUIElement) throws {
        for _ in 0..<10 {
            if fullyVisible(e) && e.isHittable { return }
            try require(e.exists && app.scrollViews.count == 1, "Missing target or ambiguous scroll: retain AX instead of guessing")
            let scroll = app.scrollViews.firstMatch
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.windows.firstMatch.frame.minY
            let downward = e.frame.minY < top
            // Relative short swipe in the actual unique scroll; not a guessed target coordinate.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: downward ? 0.68 : 0.32)))
        }
        try require(fullyVisible(e) && e.isHittable, "Target must fully clear nav and TabBar")
    }
    private func tap(_ e: XCUIElement) throws {
        try until("Actual enabled and hittable control required") { e.exists && e.isEnabled && e.isHittable }
        try require(!e.frame.isEmpty && app.windows.firstMatch.frame.contains(e.frame), "Full control must be inside actual window")
        e.tap()
    }
    private func until(_ message: String, _ body: @escaping () -> Bool) throws {
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)], timeout: 12) == .completed, message)
    }
    private func require(_ value: Bool, _ message: String) throws { if !value { throw Failure.requirement(message) } }
    private func capture(_ stage: String) throws {
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription + "\nSYSTEM ALERTS\n" + springboard.alerts.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
