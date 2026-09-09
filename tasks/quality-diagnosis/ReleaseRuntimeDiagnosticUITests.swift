import XCTest

/// Immutable Release package via independently audited xctestrun; no App arguments or business fixtures.
final class ReleaseRuntimeDiagnosticUITests: XCTestCase {
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

    func testInstalledReleaseOrdinaryNavigation() throws {
        try require(env("QD_RELEASE_AUTH") == "HASH_VERIFIED_RELEASE_PACKAGE", "Explicit immutable Release package required")
        try require(env("SIMULATOR_UDID") == "36379572-4169-495D-A5A5-D47869ED9FDE", "Dedicated Release device required")
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Failure.requirement("Evidence root") }
        output = URL(fileURLWithPath: root).appendingPathComponent("release-navigation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication(bundleIdentifier: "com.xinkuan.qiuji")
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 20), "No-argument Release launch")
        try until("Normal training root") { self.app.buttons["trainingHome.freeRecord"].exists }
        try require(app.tabBars.buttons.count == 5, "Five normal tabs")
        try capture("ordinary-training")
        try profile()
        try capture("ordinary-guest-profile")
        try tap(app.tabBars.buttons["记录"])
        try require(app.tabBars.buttons["记录"].isSelected, "Actual records tab")
        try capture("ordinary-records")
        try tap(app.tabBars.buttons["训练"])
        try until("Return normal training") { self.app.buttons["trainingHome.freeRecord"].exists }
        try profile()
        try openPage("偏好设置")
        try require(app.scrollViews["settings.content"].exists, "Actual settings content")
        try capture("ordinary-settings")
        try backToProfile(from: "偏好设置")
        try capture("returned-guest-profile")
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
