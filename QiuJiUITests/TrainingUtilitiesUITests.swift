import XCTest

final class TrainingUtilitiesUITests: XCTestCase {
    func testManualNotesReminderAndHelp() throws { try exercise(appearance: "Light") }
    func testManualNotesReminderAndHelpDark() throws { try exercise(appearance: "Dark") }

    private func exercise(appearance: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(zh-Hans)", "-v50.inMemoryStore", "-appearanceMode", appearance.lowercased()]
        app.launch()
        let menu = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        capture("home")
        menu.tap()
        XCTAssertFalse(app.buttons["好友"].exists)
        capture("menu")
        app.buttons["补记训练"].tap()
        XCTAssertTrue(app.navigationBars["补记训练"].waitForExistence(timeout: 5))
        let minutes = app.textFields["manualTraining.minutes"]
        minutes.tap(); minutes.typeText("45")
        app.buttons["manualTraining.dismissKeyboard"].tap()
        let content = app.textViews["manualTraining.content"]
        if content.exists { content.tap(); content.typeText("直线球与定杆练习") }
        else { let field = app.textFields["manualTraining.content"]; field.tap(); field.typeText("直线球与定杆练习") }
        app.buttons["manualTraining.dismissKeyboard"].tap()
        let note = app.textViews["manualTraining.note"]
        if note.exists { note.tap(); note.typeText("出杆放慢，注意击球后的停顿。") }
        else { let field = app.textFields["manualTraining.note"]; field.tap(); field.typeText("出杆放慢，注意击球后的停顿。") }
        XCTAssertTrue(app.buttons["manualTraining.save"].isHittable)
        capture("manual-keyboard")
        let dismissKeyboard = app.buttons["manualTraining.dismissKeyboard"]
        XCTAssertTrue(dismissKeyboard.waitForExistence(timeout: 5))
        dismissKeyboard.tap()
        capture("manual")
        app.buttons["manualTraining.save"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        menu.tap(); app.buttons["训练心得"].tap()
        XCTAssertTrue(app.staticTexts["直线球与定杆练习"].waitForExistence(timeout: 8))
        capture("notes")
        app.staticTexts["直线球与定杆练习"].tap()
        XCTAssertTrue(app.buttons["trainingNotes.edit"].waitForExistence(timeout: 5))
        app.buttons["trainingNotes.edit"].tap()
        let editor = app.textViews["trainingNotes.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText("下次继续。")
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "下次继续。")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["trainingNotes.record"].tap()
        XCTAssertTrue(app.buttons["编辑补记"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["补记训练"].exists)
        XCTAssertFalse(app.staticTexts["0%"].exists)
        capture("manual-detail")
        app.buttons["编辑补记"].tap()
        XCTAssertTrue(app.navigationBars["编辑补记"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["manualTraining.minutes"].value as? String, "45")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["删除记录"].tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["直线球与定杆练习"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        menu.tap(); app.buttons["训练提醒"].tap()
        XCTAssertTrue(app.navigationBars["训练提醒"].waitForExistence(timeout: 5))
        let toggle = app.switches["trainingReminder.enabled"]
        if toggle.value as? String == "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        capture("reminder-toggle")
        XCTAssertTrue(app.buttons["周一"].waitForExistence(timeout: 5))
        app.buttons["周二"].tap()
        capture("reminder")
        app.navigationBars.buttons.firstMatch.tap()
        menu.tap(); app.buttons["使用帮助"].tap()
        XCTAssertTrue(app.navigationBars["使用帮助"].waitForExistence(timeout: 5))
        app.buttons["练完后忘记记录怎么办？"].tap()
        capture("help")
    }

    func testJournalPagesLight() throws { try journalPages(appearance: "light") }
    func testJournalPagesDark() throws { try journalPages(appearance: "dark") }

    private func journalPages(appearance: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(zh-Hans)", "-v50.inMemoryStore", "-appearanceMode", appearance, "-journal.fixture"]
        app.launch()
        let menu = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap(); app.buttons["训练心得"].tap()
        let pages = app.buttons.matching(identifier: "trainingNotes.day")
        XCTAssertTrue(pages.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(pages.count, 2)
        XCTAssertFalse(app.staticTexts["空编号训练"].exists)
        capture("journal-list")
        pages.firstMatch.tap()
        let edit = app.buttons["trainingNotes.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        capture("journal-detail")
        edit.tap()
        let note = app.textViews["trainingNotes.editor"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap(); note.typeText("未保存的修改")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.buttons["trainingNotes.save"].isHittable)
        capture("journal-keyboard")
        app.buttons["trainingNotes.dismissKeyboard"].tap()
        app.navigationBars.buttons["取消"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未保存的修改")).firstMatch.exists)
        edit.tap(); note.tap(); note.typeText("下次保持停顿。")
        app.buttons["trainingNotes.dismissKeyboard"].tap()
        let actionNote = app.textViews["trainingNotes.entry.0"]
        for _ in 0..<4 { if actionNote.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(actionNote.isHittable)
        actionNote.tap(); actionNote.typeText("注意送杆。")
        app.buttons["trainingNotes.dismissKeyboard"].tap()
        capture("journal-edit")
        app.buttons["trainingNotes.save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "注意送杆。")).firstMatch.exists)
        app.navigationBars.buttons.firstMatch.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("重心")
        XCTAssertEqual(pages.count, 1)
        pages.firstMatch.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2次训练"].exists)
        capture("journal-day-multiple")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "utilities-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
