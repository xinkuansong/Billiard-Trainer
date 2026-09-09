import XCTest

/// Normal disk journey; no data fixture, deep link, login or purchase.
/// QD012 result-group semantics remain a known failure outside this method's oracle.
final class CurrentTrainingJourneyUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    func testNormalFirstGroupInputAndNumberedNoteSurviveProcessRestart() throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_CURRENT_JOURNEY_AUTH"] ?? env["TEST_RUNNER_QD_CURRENT_JOURNEY_AUTH"],
                       "DEDICATED_EMPTY_GUEST_SIMULATOR", "External device/empty-store preflight is required")
        launch()
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8), "Guest entry must be present")
        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 8), "Refuse to mix with existing history")
        capture("current-training-empty-history")
        app.switchTab(.training)
        let free = app.buttons["trainingHome.freeTraining"]
        XCTAssertTrue(free.waitForExistence(timeout: 8)); XCTAssertTrue(free.isHittable); free.tap()
        let add = app.buttons["添加中袋直线出杆"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8)); XCTAssertTrue(add.isHittable); add.tap()
        let selected = app.buttons["完成(1)"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5)); selected.tap()
        let single = app.buttons["切换到单项视图"]
        if single.waitForExistence(timeout: 3) { XCTAssertTrue(single.isHittable); single.tap() }
        XCTAssertTrue(app.buttons["切换到总览视图"].waitForExistence(timeout: 5))
        capture("current-training-before-score")

        let made = app.textFields["第1组进球"]
        let target = app.textFields["第1组总球"]
        reveal(made)
        XCTAssertTrue(made.isHittable)
        XCTAssertEqual(target.value as? String, "15", "Verify actual selected drill dose before entering 5/15")
        made.tap()
        let five = app.buttons["setNumberKeyboard.5"]
        XCTAssertTrue(five.waitForExistence(timeout: 5)); XCTAssertTrue(five.isHittable); five.tap()
        XCTAssertEqual(made.value as? String, "5", "Verify the actual field, not just a keyboard tap")
        capture("current-training-score-keyboard")
        let done = app.buttons["setNumberKeyboard.完成"]
        XCTAssertTrue(done.isHittable); done.tap()
        // Current keypad dismissal explicitly completes this group. Never tap 'mark complete'
        // again: that would change another group or toggle completion back off.
        let finishRest = app.buttons["完成休息"]
        if finishRest.waitForExistence(timeout: 3) { XCTAssertTrue(finishRest.isHittable); finishRest.tap() }
        XCTAssertTrue(app.buttons["已完成"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(done.exists)
        capture("current-training-first-group-completed")

        let more = app.buttons["activeTraining.more"]
        reveal(more, upward: false)
        XCTAssertTrue(more.isHittable); more.tap()
        let end = app.buttons["结束训练"].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5)); end.tap()
        XCTAssertTrue(app.alerts["结束训练？"].waitForExistence(timeout: 5))
        capture("current-training-end-confirmation")
        app.alerts.buttons["结束"].tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 8))
        let note = app.textViews["trainingNote.editor"]
        XCTAssertTrue(note.waitForExistence(timeout: 5)); XCTAssertTrue(note.isHittable); note.tap()
        XCTAssertEqual(note.value as? String, "1. ", "Current editor seeds the first numbered line")
        let marker = "QD-CURRENT-" + UUID().uuidString
        note.typeText(marker)
        note.typeText("\n")
        note.typeText("restart-check")
        let expectedNote = "1. " + marker + "\n2. restart-check"
        XCTAssertEqual(note.value as? String, expectedNote)
        capture("current-training-numbered-note-input")
        let dismiss = app.buttons["trainingNote.dismissKeyboard"]
        XCTAssertTrue(dismiss.isHittable); dismiss.tap()
        let finishNote = app.buttons["完成"].firstMatch
        XCTAssertTrue(finishNote.waitForExistence(timeout: 5)); XCTAssertTrue(finishNote.isHittable); finishNote.tap()
        let save = app.buttons["保存训练"]
        XCTAssertTrue(save.waitForExistence(timeout: 8)); reveal(save)
        capture("current-training-before-save")
        XCTAssertTrue(save.isHittable); save.tap()
        XCTAssertTrue(free.waitForExistence(timeout: 8)); XCTAssertTrue(free.isHittable)
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        app.terminate()
        launch()
        app.switchTab(.history)
        let row = app.staticTexts["中袋直线出杆"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8)); reveal(row)
        XCTAssertTrue(row.isHittable); row.tap()
        let savedNote = app.staticTexts[expectedNote]
        reveal(savedNote)
        XCTAssertTrue(savedNote.exists, "This run's complete numbered session note must survive a real process restart")
        capture("current-training-reopened-note")
        let identity = XCTAttachment(string: "marker=\(marker)\nexpectedNote=\(expectedNote)\nScope: input, normal save, process restart, note readback. QD012 result-group semantics not accepted by this test.")
        identity.name = "current-training-identity-and-scope"; identity.lifetime = .keepAlways; self.add(identity)
    }

    func testPreviouslySavedNumberedNoteSurvivesRestart() throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_CURRENT_JOURNEY_AUTH"], "DEDICATED_EXISTING_DIAGNOSTIC_RECORD")
        let expectedNote = try XCTUnwrap(env["QD_EXPECTED_SAVED_NOTE"])
        XCTAssertTrue(expectedNote.hasPrefix("1. QD-CURRENT-"))
        XCTAssertTrue(expectedNote.hasSuffix("\n2. restart-check"))
        launch()
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8))
        app.switchTab(.history)
        capture("previously-saved-history")
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "中袋直线出杆"))
        XCTAssertEqual(rows.count, 1, "Exactly the original diagnostic record must remain")
        let row = rows.firstMatch; reveal(row)
        XCTAssertTrue(row.isHittable); row.tap()
        let note = app.staticTexts[expectedNote]; reveal(note)
        XCTAssertTrue(note.exists); XCTAssertTrue(note.isHittable)
        capture("previously-saved-numbered-note")
    }

    private func launch() {
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium", "-v51.followSystemAppearance"])
    }

    private func reveal(_ element: XCUIElement, upward: Bool = true) {
        for _ in 0..<4 {
            if element.exists && element.isHittable { return }
            if upward { app.swipeUp() } else { app.swipeDown() }
        }
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-AX"; tree.lifetime = .keepAlways; add(tree)
    }
}
