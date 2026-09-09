import XCTest

/// Draft only. Ordinary disk guest; no store, identity, premium, or onboarding launch overrides.
final class SettingsBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
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

    func testOrdinaryGuestSoundPersistsAcrossRestartAndAboutShowsInstalledVersion() throws {
        try require(env("QD_SETTINGS_AUTHORIZATION") == "NEW_DEDICATED_EMPTY_DISK_GUEST_DEVICE", "Dedicated empty disk and Keychain device must be externally verified")
        guard let expected = env("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env("SIMULATOR_UDID")?.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Explicit authorized device must match runner") }
        guard let version = env("QD_SETTINGS_EXPECTED_VERSION_DISPLAY"),
              version.hasPrefix("版本 "), version.contains("（"), version.hasSuffix("）"), !version.contains("—")
        else { throw Failure.requirement("Provide independently read installed App Info.plist version display") }
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Failure.requirement("Absolute evidence root required") }
        output = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("settings-boundary-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: output.path), "Evidence directory must be new")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        print("[QD-Settings] evidence=\(output.path); expectedVersion=\(version)")
        app = XCUIApplication()
        do {
            try launchOrdinary()
            // RootView's ordinary branch is MainTabView; OnboardingView is preview-only.
            // settings001 actual PNG/AX showed the empty training root on a new device.
            try until("New device must present actual normal training root") {
                self.app.buttons["trainingHome.freeRecord"].exists && self.app.tabBars.buttons["我的"].exists
            }
            try require(!app.buttons["onboarding.skip"].exists, "Ordinary snapshot004 route must not be a preview fixture")
            try capture("ordinary-first-launch-training-root")
            try profile()
            try openPage("偏好设置")
            let sound = app.switches.matching(identifier: "击球音效")
            try require(sound.count == 1, "Unique source-labelled sound switch required; unknown AX must fail with evidence")
            try reveal(sound.firstMatch, scroll: app.scrollViews["settings.content"])
            let original = try soundValue(sound.firstMatch)
            try capture("sound-default-" + original)
            try require(original == "1", "Fresh UserPreferences defaults sound to true; do not silently accept a contaminated device or wrong default")
            let changed = original == "1" ? "0" : "1"
            try tap(sound.firstMatch)
            try until("Actual sound switch changes") { (sound.firstMatch.value as? String) == changed }
            try capture("sound-changed-" + changed)
            try backToProfile(from: "偏好设置")
            try openPage("偏好设置")
            try require(try soundValue(app.switches["击球音效"]) == changed, "Sound change must survive navigation")
            try capture("sound-reentered-" + changed)
            try backToProfile(from: "偏好设置")
            app.terminate()
            try require(app.wait(for: .notRunning, timeout: 10), "Old process must reach notRunning")
            print("[QD-Settings] old process notRunning; monotonic=\(ProcessInfo.processInfo.systemUptime)")
            try launchOrdinary()
            try profile()
            try require(!app.buttons["onboarding.skip"].exists, "Restart must stay on the ordinary route without preview")
            try openPage("偏好设置")
            try require(try soundValue(app.switches["击球音效"]) == changed, "Changed sound value must survive real process restart")
            try capture("sound-restarted-" + changed)
            try backToProfile(from: "偏好设置")
            try openPage("关于与反馈")
            let scrolls = app.scrollViews
            try require(scrolls.count == 1, "About must expose one actual vertical scroll container; do not guess")
            let versionText = app.staticTexts.matching(identifier: version)
            try require(versionText.count == 1, "Displayed version must match installed App metadata")
            try reveal(versionText.firstMatch, scroll: scrolls.firstMatch)
            try capture("about-installed-version")
            let notice = app.staticTexts["用户协议与隐私政策尚未发布。发布前不会用空操作或测试网址冒充正式入口。"]
            try reveal(notice, scroll: scrolls.firstMatch)
            try require(!app.descendants(matching: .any)["about.terms"].exists && !app.descendants(matching: .any)["about.privacy"].exists, "Frozen unpublished legal configuration must not expose links")
            try capture("about-unpublished-legal")
            try backToProfile(from: "关于与反馈")
            try capture("verified-returned-guest")
        } catch {
            try capture("failure-before-termination")
            throw error
        }
    }

    private func launchOrdinary() throws {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment = [:]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "Ordinary launch must reach foreground")
    }
    private func profile() throws {
        try tap(app.tabBars.buttons["我的"])
        try until("Actual guest profile required") { self.app.buttons["profile.login"].exists }
        try require(app.tabBars.buttons["我的"].isSelected && app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Refuse an authenticated or wrong page")
    }
    private func openPage(_ title: String) throws {
        let rows = app.staticTexts.matching(identifier: title)
        try require(rows.count == 1, "Unique source-backed profile row required")
        try require(app.scrollViews.count == 1, "Profile must expose one real scroll container")
        try reveal(rows.firstMatch, scroll: app.scrollViews.firstMatch)
        try tap(rows.firstMatch)
        try until("Expected pushed page " + title) { self.app.navigationBars[title].exists }
    }
    private func backToProfile(from title: String) throws {
        let nav = app.navigationBars[title]
        try require(nav.exists, "Must leave the actual expected page")
        let back = nav.buttons.matching(identifier: "BackButton")
        try require(back.count == 1, "Require observed BackButton identity, no first-button guessing")
        try tap(back.firstMatch)
        try until("Pushed page dismisses and real tab returns") { !nav.exists && self.app.tabBars.buttons["我的"].exists }
        try profile()
    }
    private func soundValue(_ element: XCUIElement) throws -> String {
        try until("Sound switch exists") { element.exists }
        guard let value = element.value as? String, ["0", "1"].contains(value) else { throw Failure.requirement("Unknown switch value; require actual 0/1") }
        return value
    }
    private func fullyVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty, app.windows.firstMatch.frame.contains(element.frame) else { return false }
        if app.tabBars.firstMatch.exists && element.frame.maxY > app.tabBars.firstMatch.frame.minY { return false }
        if app.navigationBars.firstMatch.exists && element.frame.minY < app.navigationBars.firstMatch.frame.maxY { return false }
        return true
    }
    private func reveal(_ element: XCUIElement, scroll: XCUIElement) throws {
        try require(scroll.exists, "Actual scroll required")
        for _ in 0..<10 {
            if fullyVisible(element) && element.isHittable { return }
            try require(element.exists, "Missing AX target: retain evidence instead of blind scrolling")
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.windows.firstMatch.frame.minY
            let down = element.frame.minY < top
            // Short step within the observed scroll frame; direction follows actual target position.
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.68 : 0.32))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        try require(fullyVisible(element) && element.isHittable, "Target must fully clear navigation and TabBar")
    }
    private func tap(_ element: XCUIElement) throws {
        try until("Control exists, enabled and hittable") { element.exists && element.isEnabled && element.isHittable }
        try require(!element.frame.isEmpty && app.windows.firstMatch.frame.contains(element.frame), "Full control must lie inside actual window")
        element.tap()
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
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
