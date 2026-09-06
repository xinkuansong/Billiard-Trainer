import XCTest

/// Diagnostic draft against snapshot-002. Not compiled or executed.
/// Normal UI only; no solver seeds, recording, export, or production asset writes.
final class AdvancedToolDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws { app?.terminate() }

    private func ready(_ element: XCUIElement, timeout: TimeInterval = 20) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout), .completed)
    }
    private func state(_ element: XCUIElement, enabled: Bool, timeout: TimeInterval = 15) {
        let predicate = NSPredicate(format: "exists == true AND enabled == %@", NSNumber(value: enabled))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout), .completed)
    }
    private func tap(_ title: String) {
        let button = app.buttons[title].firstMatch
        ready(button); button.tap()
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func enter(_ section: String, _ title: String) {
        app.switchTab(.angle)
        tap("angleHomeTab_\(section)")
        let card = app.buttons[title].firstMatch
        reveal(card); card.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 20))
    }
    private func returnHome(_ section: String, _ title: String) {
        let back = app.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        ready(app.buttons["angleHomeTab_\(section)"])
        reveal(app.buttons[title].firstMatch)
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "advanced-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(UUID().uuidString)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(filename + ".png"))
    }

    func testSnookerDefaultSolveRespondsAndUndoOrNoSolutionReturns() throws {
        enter("解", "防守")
        let status = app.staticTexts["navStatus.subtitle"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        let strike = app.buttons["击球"].firstMatch
        let next = app.buttons["下一解"].firstMatch
        let undo = app.buttons["上一杆"].firstMatch
        state(strike, enabled: false)
        state(undo, enabled: false)
        let initial = status.label
        tap("求解")
        // No need to catch transient busy text: require a changed, terminal status.
        let terminal = NSPredicate(format: "exists == true AND label != %@ AND label != %@", initial, "求解中…")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: terminal, object: status)], timeout: 60), .completed)
        ready(app.buttons["求解"].firstMatch)
        if status.label.hasPrefix("未找到可行防守解") {
            // Explicitly only tests feedback consistency; does not prove infeasibility.
            state(strike, enabled: false); state(next, enabled: false)
            try capture("no-solution-feedback")
        } else {
            ready(strike)
            try capture("solution")
            if next.isEnabled {
                XCTAssertTrue(status.label.hasPrefix("解 1/"))
                next.tap()
                let second = NSPredicate(format: "label BEGINSWITH %@", "解 2/")
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: second, object: status)], timeout: 10), .completed)
                try capture("second-solution")
            } else {
                // A single solution is legal. Report this stage as next-solution unexercised.
                try capture("single-solution-next-unexercised")
            }
            strike.tap()
            ready(undo, timeout: 60)
            try capture("shot-settled")
            undo.tap()
            let restored = NSPredicate(format: "label BEGINSWITH %@", "已退回上一杆击打前")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: restored, object: status)], timeout: 15), .completed)
            state(undo, enabled: false)
            state(app.buttons["回放"].firstMatch, enabled: false)
            ready(strike)
            try capture("undo-restored")
        }
        returnHome("解", "防守")
    }

    func testComposerDefaultStrikeRedoRestoresActionStateAndReturns() throws {
        enter("打", "自由走位")
        // Default unrecorded board; do not enter more-menu, recording, or export.
        let redo = app.buttons["重打"].firstMatch
        let replay = app.buttons["回放"].firstMatch
        state(redo, enabled: false); state(replay, enabled: false)
        ready(app.buttons["击球"].firstMatch, timeout: 30)
        try capture("default-ready")
        tap("击球")
        ready(redo, timeout: 60); ready(replay)
        try capture("shot-settled")
        redo.tap()
        state(redo, enabled: false); state(replay, enabled: false)
        ready(app.buttons["击球"].firstMatch, timeout: 30)
        try capture("redo-restored")
        returnHome("打", "自由走位")
    }
}
