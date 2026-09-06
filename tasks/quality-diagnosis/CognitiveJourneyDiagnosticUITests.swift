import XCTest

/// Diagnostic-only draft for snapshot-002; no production/legacy test changes.
final class CognitiveJourneyDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"])
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
        let filename = "cognitive-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(UUID().uuidString)"
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

    private func assertEmptyHistory() {
        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 10))
    }
    private func history(_ title: String, expectedAnswer: String) throws {
        returnHome("练", title)
        app.switchTab(.history)
        let record = app.staticTexts[title].firstMatch
        reveal(record); ready(record); record.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
        let detail = app.staticTexts["题目明细"]
        reveal(detail)
        XCTAssertTrue(app.staticTexts["1 题"].exists)
        XCTAssertTrue(app.staticTexts["#1"].exists)
        XCTAssertFalse(app.staticTexts["#2"].exists)
        XCTAssertTrue(app.staticTexts["你答"].exists)
        let value = app.staticTexts[expectedAnswer].firstMatch
        reveal(value); XCTAssertTrue(value.exists)
        try capture("history-one-answer")
    }
    private func angleJourney(_ title: String, value: String) throws {
        assertEmptyHistory()
        enter("练", title, settingsFirst: true)
        answer(value)
        try capture("answer-submitted")
        try history(title, expectedAnswer: value + "°")
    }
    func testAngle2DAnswerSaveAndHistory() throws {
        try angleJourney("2D 角度训练", value: "27")
    }
    func testAngle3DAnswerSaveAndHistory() throws {
        try angleJourney("3D 角度训练", value: "38")
    }
    func testAimPointDefaultAnswerSaveAndHistory() throws {
        assertEmptyHistory()
        enter("练", "瞄准点训练")
        let offset = app.staticTexts["当前偏移 0.0 mm"]
        reveal(offset); XCTAssertTrue(offset.exists)
        tap("提交瞄准点")
        ready(app.buttons["下一题"].firstMatch)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "你的偏移 0.0 mm")).firstMatch.exists)
        try capture("aim-default-zero-submitted")
        // Snapshot history currently mislabels millimetre values as degrees.
        // This assertion is a representation readback only, not acceptance of that unit.
        try history("瞄准点训练", expectedAnswer: "0°")
    }
    private func sceneAimJourney(_ title: String) throws {
        assertEmptyHistory()
        enter("练", title)
        // The normal initial aim passes through target centre: signed offset is zero.
        // Do not drag, seed geometry, or claim that this answer is correct.
        try capture("scene-default-before-submit")
        tap("提交")
        let submit = app.buttons["提交"].firstMatch
        XCTAssertTrue(submit.waitForNonExistence(timeout: 5))
        ready(submit, timeout: 35)
        try capture("scene-verification-completed")
        // No second submit: returning after auto-next must leave exactly one result.
        try history(title, expectedAnswer: "0°")
    }
    func testAimPoint2DDefaultAnswerSaveAndHistory() throws {
        try sceneAimJourney("2D 瞄准点训练")
    }
    func testAimPoint3DDefaultAnswerSaveAndHistory() throws {
        try sceneAimJourney("3D 瞄准点训练")
    }
}
