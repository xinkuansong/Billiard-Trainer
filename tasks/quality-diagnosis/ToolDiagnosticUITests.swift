import XCTest

/// Diagnostic-only draft for snapshot-002; no production/legacy test changes.
final class ToolDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws { app?.terminate() }

    private func ready(_ element: XCUIElement, timeout: TimeInterval = 12) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout), .completed,
                       "Expected actionable element: \(element)")
    }
    private func tap(_ label: String) {
        let element = app.buttons[label].firstMatch
        ready(element); element.tap()
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "tool-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(UUID().uuidString)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(filename + ".png"))
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func enter(_ section: String, _ title: String, settingsFirst: Bool = false) {
        app.switchTab(.angle)
        tap("angleHomeTab_\(section)")
        let card = app.buttons[title].firstMatch
        reveal(card); ready(card); card.tap()
        if settingsFirst {
            XCTAssertTrue(app.navigationBars["训练设置"].waitForExistence(timeout: 20))
            tap("开始训练")
        }
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 20))
    }
    private func returnHome(_ section: String, _ title: String) {
        let back = app.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        ready(app.buttons["angleHomeTab_\(section)"])
        let card = app.buttons[title].firstMatch
        reveal(card); ready(card)
    }
    private func answer(_ number: String) {
        tap("答题")
        for digit in number { tap(String(digit)) }
        tap("提交")
        let next = app.buttons["下一题"].firstMatch
        reveal(next); ready(next)
    }

    func testAnglePredictionAnswersAppearInHistory() throws {
        // A fresh in-memory container prevents pre-existing records satisfying assertions.
        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 8))
        enter("练", "角度预测")
        for (index, value) in ["17", "28", "39"].enumerated() {
            answer(value)
            if index < 2 { tap("下一题") }
        }
        try capture("three-answers")
        returnHome("练", "角度预测")
        app.switchTab(.history)
        let record = app.staticTexts["角度预测"].firstMatch
        reveal(record); ready(record); record.tap()
        XCTAssertTrue(app.navigationBars["角度预测"].waitForExistence(timeout: 8))
        let questions = app.staticTexts["题目明细"]
        reveal(questions)
        XCTAssertTrue(app.staticTexts["3 题"].exists)
        for value in ["17°", "28°", "39°"] {
            let answerValue = app.staticTexts[value].firstMatch
            reveal(answerValue); XCTAssertTrue(answerValue.exists)
        }
        XCTAssertTrue(app.staticTexts["#3"].exists)
        XCTAssertFalse(app.staticTexts["#4"].exists)
        try capture("history-three-answers")
        let back = app.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        ready(app.staticTexts["角度预测"].firstMatch)
    }

    private func sceneAngle(_ title: String) throws {
        enter("练", title, settingsFirst: true)
        answer("45")
        try capture("result")
        tap("下一题"); ready(app.buttons["答题"])
        returnHome("练", title)
    }
    func testAngle2DAnswerAndNext() throws { try sceneAngle("2D 角度训练") }
    func testAngle3DAnswerAndNext() throws { try sceneAngle("3D 角度训练") }

    func testAimPointSubmitAndNext() throws {
        enter("练", "瞄准点训练")
        tap("提交瞄准点")
        let next = app.buttons["下一题"].firstMatch
        reveal(next); ready(next)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "正确偏移")).firstMatch.exists)
        try capture("result")
        next.tap(); ready(app.buttons["提交瞄准点"])
        returnHome("练", "瞄准点训练")
    }
    private func sceneAimPoint(_ title: String) throws {
        enter("练", title)
        tap("提交")
        // Results auto-transition through physical verification; do not rely on a 1.5s transient label.
        let submit = app.buttons["提交"].firstMatch
        XCTAssertTrue(submit.waitForNonExistence(timeout: 5))
        ready(submit, timeout: 35)
        try capture("after-verification-next-question")
        returnHome("练", title)
    }
    func testAimPoint2DSubmitAndAdvance() throws { try sceneAimPoint("2D 瞄准点训练") }
    func testAimPoint3DSubmitAndAdvance() throws { try sceneAimPoint("3D 瞄准点训练") }

    private func strikeAndReplay(_ title: String) throws {
        enter("打", title)
        // Default layout has cue + target balls, without seeded fixtures or asset recording.
        let replay = app.buttons["回放"].firstMatch
        XCTAssertTrue(replay.waitForExistence(timeout: 10)); XCTAssertFalse(replay.isEnabled)
        tap("击球")
        ready(replay, timeout: 45)
        try capture("shot-settled")
        replay.tap()
        ready(replay, timeout: 45)
        // Replay preserves the post-shot board; a potted target cannot be struck again.
        // Restore the actual pre-shot board through the existing normal redo control.
        tap("重打")
        ready(app.buttons["击球"].firstMatch, timeout: 45)
        XCTAssertFalse(replay.isEnabled)
        try capture("replay-settled")
        returnHome("打", title)
    }
    func testShotSimulationStrikeAndReplay() throws { try strikeAndReplay("分离角与走位") }
    func testFreePlayStrikeAndReplay() throws { try strikeAndReplay("自由击球") }

    private func solverMode(_ title: String) throws {
        enter("解", title)
        let mode = app.buttons["solver.mode"]
        ready(mode, timeout: 30)
        XCTAssertTrue(mode.label.contains("求解"))
        mode.tap(); XCTAssertTrue(mode.label.contains("自由"))
        ready(app.buttons["击球"].firstMatch, timeout: 20)
        tap("击球")
        ready(app.buttons["上一杆"].firstMatch, timeout: 45)
        try capture("free-shot-settled")
        tap("上一杆")
        ready(mode); mode.tap()
        XCTAssertTrue(mode.label.contains("求解"))
        XCTAssertTrue(app.buttons["下一解"].waitForExistence(timeout: 30))
        try capture("returned-to-solve")
        returnHome("解", title)
    }
    func testBankSolverModeStrikeUndoReturn() throws { try solverMode("翻袋解球器") }
    func testReflectionSolverModeStrikeUndoReturn() throws { try solverMode("反射解球器") }
}
