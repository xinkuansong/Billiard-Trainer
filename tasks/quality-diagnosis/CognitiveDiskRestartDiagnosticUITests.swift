import XCTest

/// Normal disk store on a newly created, explicitly authorized guest simulator.
final class CognitiveDiskRestartDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    func testNormalAngleAnswerHistorySurvivesProcessTerminationAndRelaunch() throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_DISK_RESTART_BOUNDARY"] ?? env["TEST_RUNNER_QD_DISK_RESTART_BOUNDARY"],
                       "NEW_DEDICATED_GUEST_SIMULATOR")
        launch()
        app.switchTab(.profile)
        ready(app.buttons["profile.login"])
        app.switchTab(.history)
        ready(app.staticTexts["还没有训练记录"])
        try capture("empty-disk-history")
        app.switchTab(.angle)
        tap("angleHomeTab_练")
        let card = app.buttons["2D 角度训练"].firstMatch
        reveal(card); card.tap()
        ready(app.navigationBars["训练设置"])
        tap("开始训练")
        ready(app.navigationBars["2D 角度训练"])
        tap("答题"); tap("2"); tap("7"); tap("提交")
        reveal(app.buttons["下一题"].firstMatch)
        try capture("normal-answer-submitted")
        let back = app.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        ready(app.buttons["angleHomeTab_练"])
        let before = try readOnlyHistory(stage: "disk-history-before-termination")
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 8), "The original app process must end")
        print("[QD-CognitiveDisk] original app confirmed notRunning; no data removal or fixtures")
        launch()
        app.switchTab(.profile)
        ready(app.buttons["profile.login"])
        let after = try readOnlyHistory(stage: "disk-history-after-relaunch")
        XCTAssertEqual(after, before, "Question values and errors must survive a real process restart")
        print("[QD-CognitiveDisk] retained angle labels before=\(before) after=\(after)")
    }

    private func launch() {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v51.followSystemAppearance"])
        XCTAssertFalse(app.launchArguments.contains("-v50.inMemoryStore"))
    }
    private func readOnlyHistory(stage: String) throws -> [String] {
        app.switchTab(.history)
        let row = app.staticTexts["2D 角度训练"].firstMatch
        reveal(row)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "2D 角度训练")).count, 1, "Exactly one visible cognitive session")
        row.tap()
        ready(app.navigationBars["2D 角度训练"])
        reveal(app.staticTexts["题目明细"])
        XCTAssertTrue(app.staticTexts["1 题"].exists)
        XCTAssertTrue(app.staticTexts["#1"].exists)
        XCTAssertFalse(app.staticTexts["#2"].exists)
        XCTAssertTrue(app.staticTexts["实际"].exists)
        XCTAssertTrue(app.staticTexts["你答"].exists)
        XCTAssertTrue(app.staticTexts["27°"].exists)
        let values = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("°") }.sorted()
        XCTAssertGreaterThanOrEqual(values.count, 3, "Retain actual answer and error labels, not only the page title")
        try capture(stage)
        return values
    }
    private func ready(_ element: XCUIElement) {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: element)], timeout: 15), .completed)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { ready(element); return }
            app.swipeUp()
        }
        ready(element)
    }
    private func tap(_ identifier: String) {
        let e = app.buttons[identifier].firstMatch
        ready(e); e.tap()
    }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let dir = URL(fileURLWithPath: try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"]))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = "cognitive-disk-\(runID)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot); a.name = stem; a.lifetime = .keepAlways; add(a)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let t = XCTAttachment(string: ax); t.name = stem + "-AX"; t.lifetime = .keepAlways; add(t)
        try Data(ax.utf8).write(to: dir.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
