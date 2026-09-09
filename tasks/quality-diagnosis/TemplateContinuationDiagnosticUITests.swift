import XCTest

/// Unrun diagnostic draft. Normal UI; isolated guest in-memory store.
final class TemplateContinuationDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let token = String(UUID().uuidString.prefix(8))
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"])
    }
    override func tearDownWithError() throws { if app != nil { try capture("terminal"); app.terminate() } }

    func testTemplateEditedDoseSavedThenDeletedKeepsHistoricalSourceAndScores() throws {
        let initialName = "模版初稿" + token
        let finalName = "模版定稿" + token
        app.switchTab(.profile); ready(app.buttons["profile.login"])
        app.switchTab(.history); ready(app.staticTexts["还没有训练记录"])
        app.switchTab(.training)
        reveal(app.buttons["我的模版"]); tap("我的模版")
        let create = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "新建模版", "list.bullet.clipboard")).firstMatch
        revealAboveTabBar(create); ready(create); create.tap()
        try setName(initialName)
        tap("添加训练项目")
        let search = app.searchFields.firstMatch
        ready(search); search.tap(); search.typeText("走位基础")
        tap("添加走位基础")
        XCTAssertTrue(app.buttons["取消选择走位基础"].exists)
        try capture("selected-drill-search-active")
        // iOS 26 search presentation hides the picker toolbar until search closes.
        tap("关闭")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 8))
        tap("完成(1)")
        try observedNavigationTouch(app.buttons["保存"].firstMatch, stage: "initial-save-menu")
        tap("仅保存")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForNonExistence(timeout: 8))
        reveal(app.buttons["我的模版"]); tap("我的模版")
        let initial = card(named: initialName)
        revealAboveTabBar(initial); ready(initial)
        let templateID = initial.identifier.replacingOccurrences(of: "trainingHome.template.edit.", with: "")
        XCTAssertNotNil(UUID(uuidString: templateID))
        initial.tap()
        XCTAssertTrue(app.navigationBars["编辑模版"].waitForExistence(timeout: 8))
        try setName(finalName)
        // The builder has one drill and one SF-symbol row settings action.
        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ellipsis' OR identifier CONTAINS[c] 'ellipsis'")).firstMatch
        reveal(settings); ready(settings); settings.tap()
        XCTAssertTrue(app.navigationBars["走位基础"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["遍数"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["×1"].exists)
        let increment = app.steppers.buttons["Increment"]
        ready(increment); increment.tap()
        XCTAssertTrue(app.staticTexts["×2"].waitForExistence(timeout: 5))
        // Frozen c037 content: 3 rounds × 15 per pass; 2 passes = 6 × 15 = 90.
        XCTAssertTrue(app.staticTexts["90"].exists)
        try capture("edited-two-passes")
        tap("完成")
        try observedNavigationTouch(app.buttons["保存"].firstMatch, stage: "edited-save-menu")
        tap("保存并加入今日安排")
        XCTAssertTrue(app.navigationBars["编辑模版"].waitForNonExistence(timeout: 8))
        let disclosureID = "trainingHome.scheduleItem." + templateID
        let disclosure = app.buttons[disclosureID]
        revealAboveTabBar(disclosure, up: false); ready(disclosure)
        XCTAssertTrue(disclosure.label.contains(finalName))
        XCTAssertEqual(disclosure.value as? String, "已折叠")
        disclosure.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "已展开"), object: disclosure
        )], timeout: 8), .completed)
        let start = app.descendants(matching: .any)[disclosureID + ".start"].firstMatch.buttons["开始这节课"]
        revealAboveTabBar(start); ready(start)
        XCTAssertEqual(start.label, "开始这节课")
        start.tap()
        ready(app.descendants(matching: .any)["activeTraining.timer"].firstMatch)
        let single = app.buttons["切换到单项视图"]
        if single.exists { ready(single); single.tap() }
        ready(app.buttons["切换到总览视图"])
        for group in 1...6 {
            let made = app.textFields["第\(group)组进球"]
            let total = app.textFields["第\(group)组总球"]
            reveal(made); ready(made)
            XCTAssertEqual(total.value as? String, "15")
            made.tap(); tap("setNumberKeyboard.5")
            XCTAssertEqual(made.value as? String, "5")
            tap("setNumberKeyboard.完成")
            let rest = app.buttons["完成休息"]
            if rest.waitForExistence(timeout: 3) { ready(rest); rest.tap() }
        }
        XCTAssertEqual(app.buttons.matching(identifier: "已完成").count, 6)
        XCTAssertFalse(app.textFields["第7组进球"].exists)
        try capture("six-groups-recorded")
        let more = app.buttons["activeTraining.more"]
        reveal(more, up: false); ready(more); more.tap(); tap("结束训练")
        let end = app.alerts.buttons["结束"]; ready(end); end.tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 8))
        // TrainingNoteView focuses its editor on appear and hides bottom actions.
        ready(app.buttons["trainingNote.dismissKeyboard"])
        tap("trainingNote.dismissKeyboard")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 8))
        tap("跳过")
        reveal(app.buttons["保存训练"]); tap("保存训练")
        // Source handleSave persists, shows the success toast, then dismisses.
        // A label changing to 完成 alone does not prove dismissal or saved history.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["保存训练"].waitForNonExistence(timeout: 12))
        XCTAssertTrue(app.buttons["完成"].waitForNonExistence(timeout: 12))
        app.switchTab(.history)
        try openAndCheckHistory(name: finalName, deleted: false)
        try capture("history-before-template-delete")
        try observedNavigationTouch(app.navigationBars.buttons.firstMatch, stage: "history-back")
        app.switchTab(.training)
        reveal(app.buttons["我的模版"]); tap("我的模版")
        let finalCard = app.buttons["trainingHome.template.edit." + templateID]
        revealAboveTabBar(finalCard); ready(finalCard)
        XCTAssertTrue(finalCard.label.contains(finalName))
        let management = app.buttons["trainingHome.template.menu." + templateID]
        revealAboveTabBar(management); ready(management); management.tap()
        tap("删除")
        let confirmation = app.buttons["删除"].firstMatch
        ready(confirmation)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "确定要删除「" + finalName + "」")).firstMatch.exists)
        confirmation.tap()
        XCTAssertTrue(finalCard.waitForNonExistence(timeout: 8))
        try capture("template-removed")
        app.switchTab(.history)
        try openAndCheckHistory(name: finalName, deleted: true)
        try capture("history-after-template-delete")
    }

    private func openAndCheckHistory(name: String, deleted: Bool) throws {
        let row = app.staticTexts["走位基础"].firstMatch
        revealAboveTabBar(row); ready(row); row.tap()
        let source = app.buttons["trainingDetail.sourceBreadcrumb"]
        reveal(source, up: false)
        XCTAssertTrue(source.exists)
        XCTAssertTrue(source.label.contains(name))
        XCTAssertTrue(source.label.contains(deleted ? "来源已删除" : "可查看来源"))
        XCTAssertEqual(source.isEnabled, !deleted)
        for n in 1...6 {
            let group = app.staticTexts["第\(n)组"]
            reveal(group); XCTAssertTrue(group.exists)
        }
        XCTAssertFalse(app.staticTexts["第7组"].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: "5/15").count, 6)
        XCTAssertTrue(app.staticTexts["30/90"].exists)
    }
    private func card(named title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@ AND label CONTAINS %@", "trainingHome[.]template[.]edit[.][A-Fa-f0-9-]{36}", title)).firstMatch
    }
    private func setName(_ text: String) throws {
        let field = app.textFields["customPlanNameField"]
        ready(field); field.tap()
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.exists { tap("Continue") }
        let old = try XCTUnwrap(field.value as? String)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count + 2))
        field.typeText(text + "\n")
        XCTAssertEqual(field.value as? String, text)
    }
    private func observedNavigationTouch(_ element: XCUIElement, stage: String) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 12))
        XCTAssertFalse(element.frame.isEmpty)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(element.frame))
        try capture(stage)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func ready(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 12)); XCTAssertTrue(element.isHittable)
    }
    private func reveal(_ element: XCUIElement, up: Bool = true) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if up { app.swipeUp() } else { app.swipeDown() }
        }
        ready(element)
    }
    private func revealAboveTabBar(_ element: XCUIElement, up: Bool = true) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 12))
        for _ in 0..<12 {
            if element.exists && element.isHittable && !element.frame.isEmpty
                && app.windows.firstMatch.frame.contains(element.frame)
                && element.frame.maxY <= tabBar.frame.minY { return }
            if element.exists && element.frame.maxY > tabBar.frame.minY {
                app.swipeUp()
            } else if up { app.swipeUp() } else { app.swipeDown() }
        }
        ready(element)
        XCTAssertFalse(element.frame.isEmpty)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(element.frame))
        XCTAssertLessThanOrEqual(element.frame.maxY, tabBar.frame.minY,
                                "The whole target must be above the actual TabBar before tapping")
    }
    private func tap(_ label: String) { let e = app.buttons[label].firstMatch; ready(e); e.tap() }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let dir = URL(fileURLWithPath: try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"]))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = "template-continuation-" + token + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let tree = XCTAttachment(string: ax); tree.name = stem + "-AX"; tree.lifetime = .keepAlways; add(tree)
        try Data(ax.utf8).write(to: dir.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
