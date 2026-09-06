import XCTest

/// Independent diagnostic assertions; original legacy tests are unchanged.
final class QualityDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch(_ extra: [String] = []) {
        let env = ProcessInfo.processInfo.environment
        let follow = env["TEST_RUNNER_QD_FOLLOW_APPEARANCE"] == "1" || env["QD_FOLLOW_APPEARANCE"] == "1"
        app = XCUIApplication.launchClean(extraArgs: extra + (follow ? ["-v51.followSystemAppearance"] : []))
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        try shot.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
    private func reveal(_ element: XCUIElement, attempts: Int = 5) {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }

    func testGuestAndForcedPremiumGate() throws {
        launch(["-v50.inMemoryStore", "-forceNonPremium"])
        app.switchTab(.profile)
        let login = app.buttons["profile.login"]
        XCTAssertTrue(login.waitForExistence(timeout: 8))
        XCTAssertTrue(login.label.contains("游客模式"))
        XCTAssertTrue(login.label.contains("登录"))
        try capture("guest-profile")
        app.terminate()
        launch(["-v50.inMemoryStore", "-forceNonPremium", "-deeplink.drillDetail=drill_c039"])
        XCTAssertTrue(app.buttons["unlockProButton"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["bottomTryoutButton"].isHittable)
        try capture("free-gate")
        app.terminate()
        launch(["-v50.inMemoryStore", "-forcePremium", "-deeplink.drillDetail=drill_c039"])
        XCTAssertTrue(app.buttons["bottomTryoutButton"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["unlockProButton"].exists)
        try capture("forced-pro-gate")
    }

    func testFiveRootsReachable() throws {
        launch(["-v50.inMemoryStore", "-forceNonPremium"])
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["trainingHome.freeTraining"].waitForExistence(timeout: 8))
        try capture("root-training")
        app.switchTab(.drillLibrary)
        XCTAssertTrue(app.textFields["librarySearchField"].waitForExistence(timeout: 8))
        try capture("root-library")
        app.switchTab(.angle)
        XCTAssertTrue(app.descendants(matching: .any)["angleHomeTab_理"].waitForExistence(timeout: 8))
        try capture("root-practice")
        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 8))
        try capture("root-history")
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8))
        try capture("root-profile")
    }

    func testLibraryDetailTryoutAndReturn() throws {
        launch(["-v50.inMemoryStore", "-forceNonPremium"])
        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap(); search.typeText("中袋直线出杆\n")
        let card = app.descendants(matching: .any)["drillCard_drill_c012"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8)); card.tap()
        let tryout = app.buttons["bottomTryoutButton"]
        XCTAssertTrue(tryout.waitForExistence(timeout: 8))
        try capture("library-detail")
        sleep(3)
        try capture("library-detail-after-3s")
        tryout.tap()
        let formation = app.buttons["tryoutFormation_0"]
        if formation.waitForExistence(timeout: 3) { formation.tap() }
        XCTAssertTrue(app.buttons["tryout.rearrange"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["break.entry"].exists)
        try capture("library-tryout")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.isHittable); back.tap()
        XCTAssertTrue(tryout.waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        try capture("library-return")
    }

    func testNormalFreeTrainingPersistsAfterProcessRestart() throws {
        _ = try createNormalTrainingAndReopen()
    }

    private func createNormalTrainingAndReopen(capturePrefix: String = "") throws -> String {
        // No in-memory store, no seeded training state and no deep link.
        launch(["-forceNonPremium"])
        app.switchTab(.training)
        let free = app.buttons["trainingHome.freeTraining"]
        XCTAssertTrue(free.waitForExistence(timeout: 8)); free.tap()
        let add = app.buttons["添加中袋直线出杆"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8)); add.tap()
        app.buttons["完成(1)"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.waitForExistence(timeout: 8))
        let singleView = app.buttons["切换到单项视图"]
        if singleView.exists {
            XCTAssertTrue(singleView.isHittable); singleView.tap()
        }
        XCTAssertTrue(app.buttons["切换到总览视图"].waitForExistence(timeout: 5))
        try capture(capturePrefix + "training-single-view")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "training-single-view-AX"; tree.lifetime = .keepAlways; self.add(tree)
        let firstMade = ProcessInfo.processInfo.environment["QD_FIRST_MADE"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_QD_FIRST_MADE"]
        if let firstMade {
            let made = app.textFields["-"].firstMatch
            XCTAssertTrue(made.isHittable); made.tap(); made.typeText(firstMade)
        }
        // Save a partial training session (one of the prescribed groups).
        let mark = app.buttons["标记完成"].firstMatch
        reveal(mark)
        XCTAssertTrue(mark.isHittable); mark.tap()
        let finishRest = app.buttons["完成休息"]
        if finishRest.waitForExistence(timeout: 3) {
            XCTAssertTrue(finishRest.isHittable); finishRest.tap()
        }
        let marker = "QD-" + UUID().uuidString.prefix(8)
        // iOS 17 exposes the vertical SwiftUI TextField as TextView; iOS 26 as TextField.
        // Keep the same user input/value/persistence assertions for both real AX forms.
        let noteField = app.textFields["记录本项心得..."]
        let note = noteField.exists ? noteField : app.textViews["记录本项心得..."]
        // Notes appear above the set grid; bounded scroll upwards first.
        for _ in 0..<5 {
            if note.exists && note.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(note.isHittable)
        note.tap()
        let keyboardIntro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if keyboardIntro.exists {
            let proceed = app.buttons["Continue"]
            XCTAssertTrue(proceed.isHittable); proceed.tap()
        }
        note.typeText(marker)
        let enteredNote = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", marker)).firstMatch
        XCTAssertTrue(enteredNote.waitForExistence(timeout: 5), "Entered note must match this run's unique marker")
        try capture(capturePrefix + "training-recorded")
        let end = app.buttons["activeTraining.end"]
        if end.exists && end.isHittable { end.tap() }
        else { app.buttons["activeTraining.more"].tap(); app.buttons["结束训练"].tap() }
        XCTAssertTrue(app.alerts.buttons["结束"].waitForExistence(timeout: 5)); app.alerts.buttons["结束"].tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 8)); app.buttons["跳过"].tap()
        let save = app.buttons["保存训练"]
        XCTAssertTrue(save.waitForExistence(timeout: 8)); reveal(save); save.tap()
        XCTAssertTrue(free.waitForExistence(timeout: 8))
        XCTAssertTrue(save.waitForNonExistence(timeout: 8))
        XCTAssertTrue(free.isHittable)
        app.terminate()
        launch(["-forceNonPremium"])
        app.switchTab(.history)
        let row = app.staticTexts["中袋直线出杆"].firstMatch
        reveal(row)
        XCTAssertTrue(row.isHittable); row.tap()
        let savedNote = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        reveal(savedNote)
        XCTAssertTrue(savedNote.exists, "Saved item note must survive actual process restart")
        try capture(capturePrefix + "training-reopened-disk")
        return marker
    }

    private func assertOwnHistorySample(_ marker: String) throws {
        XCTAssertNotEqual(marker, "QD-3A760F98", "The preserved QD-012 evidence is never this test's target")
        let note = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", marker)
        ).firstMatch
        reveal(note)
        // A throwing identity check protects later edit/delete even if failure policy changes.
        _ = try XCTUnwrap(note.exists ? marker : nil, "Refuse mutation without this run's exact unique note")
        XCTAssertTrue(app.buttons["编辑数据"].exists)
    }

    private func openHistoryEditor(_ marker: String) throws {
        try assertOwnHistorySample(marker)
        let edit = app.buttons["编辑数据"]
        reveal(edit); XCTAssertTrue(edit.isHittable); edit.tap()
        XCTAssertTrue(app.navigationBars["编辑数据"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["editSetMade_1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dataEditorSave"].exists)
        XCTAssertTrue(app.buttons["dataEditorCancel"].exists)
    }

    private func replaceHistoryNumber(_ identifier: String, with text: String) throws {
        XCTAssertTrue(app.navigationBars["编辑数据"].exists)
        let field = app.textFields[identifier]
        reveal(field); XCTAssertTrue(field.isHittable)
        let previous = try XCTUnwrap(field.value as? String)
        // Use the actual field's right edge, rather than screen coordinates or a selection menu.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let previousDigits = previous.filter(\.isNumber)
        if !previousDigits.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previousDigits.count + 2))
        }
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text, "The actual field must contain exactly the requested value")
    }

    private func finishHistoryEditor(_ identifier: String) {
        XCTAssertTrue(app.navigationBars["编辑数据"].exists)
        let action = app.buttons[identifier]
        XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isHittable); action.tap()
    }

    private func reopenOwnHistorySample(_ marker: String) throws {
        app.terminate()
        launch(["-forceNonPremium"])
        app.switchTab(.history)
        let latest = app.staticTexts["中袋直线出杆"].firstMatch
        reveal(latest); XCTAssertTrue(latest.isHittable); latest.tap()
        // Recency is only a candidate selector. Exact identity is required before mutation.
        try assertOwnHistorySample(marker)
    }

    private func openOwnDeleteConfirmation(_ marker: String) throws {
        try assertOwnHistorySample(marker)
        let more = app.buttons["更多操作"].firstMatch
        reveal(more); XCTAssertTrue(more.isHittable); more.tap()
        let remove = app.buttons["删除"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); XCTAssertTrue(remove.isHittable); remove.tap()
        XCTAssertTrue(app.staticTexts["删除这条训练记录？"].waitForExistence(timeout: 5))
        try capture("delete-confirmation-" + UUID().uuidString)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "delete-confirmation-AX"; tree.lifetime = .keepAlways; add(tree)
        XCTAssertTrue(app.buttons["取消"].exists || app.otherElements["PopoverDismissRegion"].exists)
        XCTAssertTrue(app.buttons["删除"].waitForExistence(timeout: 5))
    }

    func testHistoryEditCancelSaveRejectAndDeleteOwnSample() throws {
        let capturePrefix = "history-" + UUID().uuidString + "-"
        // Real normal creation; never mutate one of the earlier diagnosis samples.
        let marker = try createNormalTrainingAndReopen(capturePrefix: capturePrefix)
        try assertOwnHistorySample(marker)
        try openHistoryEditor(marker)
        let fieldIDs = ["editSetMade_1", "editSetTarget_1", "editSetDuration_1"]
        var original: [String: String] = [:]
        for fieldID in fieldIDs {
            let field = app.textFields[fieldID]
            XCTAssertTrue(field.exists)
            original[fieldID] = try XCTUnwrap(field.value as? String)
        }
        try replaceHistoryNumber("editSetTarget_1", with: "9")
        try replaceHistoryNumber("editSetMade_1", with: "7")
        try replaceHistoryNumber("editSetDuration_1", with: "150")
        try capture(capturePrefix + "unsaved-values")
        finishHistoryEditor("dataEditorCancel")
        XCTAssertTrue(app.buttons["dataEditorCancel"].waitForNonExistence(timeout: 8))
        try openHistoryEditor(marker)
        for fieldID in fieldIDs {
            XCTAssertEqual(app.textFields[fieldID].value as? String, original[fieldID], "Cancel must retain the original stored value")
        }
        try replaceHistoryNumber("editSetTarget_1", with: "9")
        try replaceHistoryNumber("editSetMade_1", with: "7")
        try replaceHistoryNumber("editSetDuration_1", with: "150")
        finishHistoryEditor("dataEditorSave")
        XCTAssertTrue(app.buttons["dataEditorSave"].waitForNonExistence(timeout: 8))
        try assertOwnHistorySample(marker)
        let score = app.staticTexts["7/9"].firstMatch
        reveal(score); XCTAssertTrue(score.exists)
        try capture(capturePrefix + "saved-detail")

        try reopenOwnHistorySample(marker)
        try openHistoryEditor(marker)
        XCTAssertEqual(app.textFields["editSetMade_1"].value as? String, "7")
        XCTAssertEqual(app.textFields["editSetTarget_1"].value as? String, "9")
        XCTAssertEqual(app.textFields["editSetDuration_1"].value as? String, "150")
        try replaceHistoryNumber("editSetMade_1", with: "99")
        let error = app.staticTexts["editSetError_1"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("进球数不能大于总数"))
        finishHistoryEditor("dataEditorSave")
        XCTAssertTrue(app.alerts["无法保存"].waitForExistence(timeout: 5))
        try capture(capturePrefix + "invalid-save-rejected")
        let acknowledge = app.alerts.buttons["确定"]
        XCTAssertTrue(acknowledge.isHittable); acknowledge.tap()
        XCTAssertTrue(app.navigationBars["编辑数据"].exists)
        XCTAssertEqual(app.textFields["editSetMade_1"].value as? String, "99")
        finishHistoryEditor("dataEditorCancel")
        XCTAssertTrue(app.buttons["dataEditorCancel"].waitForNonExistence(timeout: 8))
        try openHistoryEditor(marker)
        XCTAssertEqual(app.textFields["editSetMade_1"].value as? String, "7")
        XCTAssertEqual(app.textFields["editSetTarget_1"].value as? String, "9")
        finishHistoryEditor("dataEditorCancel")
        XCTAssertTrue(app.buttons["dataEditorCancel"].waitForNonExistence(timeout: 8))

        try openOwnDeleteConfirmation(marker)
        let cancel = app.buttons["取消"].firstMatch
        if cancel.exists {
            XCTAssertTrue(cancel.isHittable); cancel.tap()
        } else {
            let dismissRegion = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(dismissRegion.isHittable); dismissRegion.tap()
        }
        XCTAssertTrue(app.staticTexts["删除这条训练记录？"].waitForNonExistence(timeout: 5))
        try assertOwnHistorySample(marker)
        try capture(capturePrefix + "delete-cancelled")
        try openOwnDeleteConfirmation(marker)
        let confirm = app.buttons["删除"].firstMatch
        XCTAssertTrue(confirm.isHittable); confirm.tap()
        XCTAssertTrue(app.buttons["编辑数据"].waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["删除这条训练记录？"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.alerts["操作失败"].exists)
        XCTAssertFalse(app.staticTexts[marker].exists)
        try capture(capturePrefix + "delete-confirmed-history")
        app.terminate()
        launch(["-forceNonPremium"])
        app.switchTab(.history)
        let remaining = app.staticTexts["中袋直线出杆"].firstMatch
        if remaining.waitForExistence(timeout: 5) {
            reveal(remaining); XCTAssertTrue(remaining.isHittable); remaining.tap()
            XCTAssertTrue(app.buttons["编辑数据"].waitForExistence(timeout: 8))
            let oldNote = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", marker)).firstMatch
            reveal(oldNote)
            XCTAssertFalse(oldNote.exists, "The just-deleted newest sample must not reopen after restart")
        } else {
            XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 5))
        }
        try capture(capturePrefix + "after-delete-restart")
    }
}
