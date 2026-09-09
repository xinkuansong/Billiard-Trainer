import XCTest

/// Finite normal unrecorded two-shot diagnostic; no asset writes.
final class ComposerContinuationDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private var sequence = 0
    private struct Stop: Error { let reason: String }
    private func env(_ key: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return e[key] ?? e["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        try require(env("QD_COMPOSER_AUTH") == "NEW_EMPTY_COMPOSER_DEVICE", "Dedicated empty device authorization required")
        let expected = "89625133-53C9-4CAF-B587-6628568CDAC9"
        try require(env("QD_COMPOSER_DEVICE_UDID") == expected && env("SIMULATOR_UDID")?.uppercased() == expected, "Dedicated composer device only")
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Stop(reason: "Absolute new evidence root required") }
        output = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("composer-continuation-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: output.path), "Fresh evidence leaf required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "Actual foreground required")
        tap(app.tabBars.buttons["我的"])
        try require(app.buttons["profile.login"].waitForExistence(timeout: 10) && app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "Actual guest only")
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("terminal-before-termination") }
    }
    private func require(_ v: Bool, _ why: String) throws { if !v { throw Stop(reason: why) } }
    private func tap(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)], timeout: 15), .completed)
        element.tap()
    }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 30) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: e)], timeout: timeout), .completed)
    }
    private func board(_ stage: String) throws -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        for key in ["cueBall", "_1", "_2"] {
            let e = app.descendants(matching: .any).matching(identifier: key).firstMatch
            if e.exists {
                let r = e.frame
                print("[QD-Composer] \(stage) \(key) root=\(r) hittable=\(e.isHittable)")
                if r.width > 0 && r.height > 0 && r.width < 30 && r.height < 30 && app.windows.firstMatch.frame.contains(r) { result[key] = r }
            }
        }
        try capture(stage)
        return result
    }
    func testNormalTwoShotsThenSingleUndoRestoresSecondShotInput() throws {
        let tab = app.tabBars.buttons["练习"]
        tap(tab)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab)], timeout: 8), .completed)
        tap(app.buttons["angleHomeTab_打"])
        let card = app.buttons["自由走位"].firstMatch
        for _ in 0..<4 {
            if card.exists && card.isHittable && card.frame.maxY < app.tabBars.firstMatch.frame.minY { break }
            app.swipeUp()
        }
        XCTAssertLessThan(card.frame.maxY, app.tabBars.firstMatch.frame.minY)
        tap(card)
        XCTAssertTrue(app.navigationBars["自由走位"].waitForExistence(timeout: 15))
        let strike = app.buttons["击球"].firstMatch
        let redo = app.buttons["重打"].firstMatch
        let replay = app.buttons["回放"].firstMatch
        ready(strike)
        XCTAssertFalse(redo.isEnabled); XCTAssertFalse(replay.isEnabled)
        let initial = try board("default-before-first")
        XCTAssertEqual(Set(initial.keys), Set(["cueBall", "_1", "_2"]))
        tap(strike)
        ready(redo, timeout: 60); ready(replay)
        let first = try board("first-settled-before-second")
        // This is the actual second input, never a seeded or predicted final board.
        XCTAssertNotNil(first["cueBall"])
        ready(strike, timeout: 30)
        tap(strike)
        ready(redo, timeout: 60); ready(replay)
        _ = try board("second-settled")
        tap(redo)
        XCTAssertFalse(redo.isEnabled); XCTAssertFalse(replay.isEnabled)
        ready(strike, timeout: 30)
        let restored = try board("undo-restored-second-input")
        XCTAssertEqual(Set(restored.keys), Set(first.keys))
        for key in first.keys {
            let before = try XCTUnwrap(first[key]), after = try XCTUnwrap(restored[key])
            XCTAssertEqual(after.midX, before.midX, accuracy: 2, key + " x restoration")
            XCTAssertEqual(after.midY, before.midY, accuracy: 2, key + " y restoration")
        }
        // Root AX presence is only an observation: main reviewer must examine all four
        // complete images for actual visible balls and advancement; hidden meshes persist.
        let back = app.navigationBars.buttons.firstMatch
        tap(back)
        XCTAssertTrue(app.buttons["angleHomeTab_打"].waitForExistence(timeout: 15))
        try capture("normal-return")
    }
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
