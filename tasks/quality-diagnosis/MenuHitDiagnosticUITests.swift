import XCTest

final class MenuHitDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"])
    }
    override func tearDownWithError() throws { app?.terminate() }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 12) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout)); XCTAssertTrue(element.isHittable)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func tap(_ label: String) {
        let element = app.buttons[label].firstMatch
        ready(element); element.tap()
    }
    private func back() { let button = app.navigationBars.buttons.firstMatch; ready(button); button.tap() }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "menu-hit-\(runID)-\(stage)"
        let item = XCTAttachment(screenshot: shot)
        item.name = filename; item.lifetime = .keepAlways; add(item)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(filename + ".png"))
        let ax = app.debugDescription
        let tree = XCTAttachment(string: ax); tree.name = filename + "-AX"; tree.lifetime = .keepAlways; add(tree)
        try ax.write(to: dir.appendingPathComponent(filename + ".txt"), atomically: true, encoding: .utf8)
    }

    func testVisibleMoreMenuRespondsAtItsActualFrameCenter() throws {
        app.switchTab(.training)
        let more = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(more.waitForExistence(timeout: 12))
        let frame = more.frame
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        XCTAssertFalse(frame.isEmpty)
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite)
        XCTAssertTrue(window.frame.contains(frame), "More must be wholly inside actual window")
        let observation = "moreFrame=\(frame); windowFrame=\(window.frame); isHittable=\(more.isHittable)"
        let evidence = XCTAttachment(string: observation)
        evidence.name = "more-hit-observation-" + runID
        evidence.lifetime = .keepAlways; add(evidence)
        print(observation)
        try capture("more-before-center-touch")
        // A diagnostic probe of the observed element, never a guessed screen coordinate.
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let create = app.buttons["新建模版"].firstMatch
        XCTAssertTrue(create.waitForExistence(timeout: 8), "Actual frame-center touch did not open menu")
        XCTAssertTrue(create.isHittable)
        try capture("more-menu-after-center-touch")
        // Presence of the menu action is the target; this probe does not create a template.
    }

    func testTemplateEmptyShelfCreateSaveAndReopen() throws {
        try templateJourney(observedNavigationTouch: false)
    }

    func testTemplateShelfSaveAndReopenWithObservedNavigationTouch() throws {
        try templateJourney(observedNavigationTouch: true)
    }

    private func navigationTouch(_ element: XCUIElement, stage: String) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 12))
        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(frame))
        let observed = XCTAttachment(string: "frame=\(frame); isHittable=\(element.isHittable)")
        observed.name = stage + "-touch-observation"; observed.lifetime = .keepAlways; add(observed)
        try capture(stage + "-before-touch")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func templateJourney(observedNavigationTouch: Bool) throws {
        app.switchTab(.training)
        let shelf = app.buttons["我的模版"].firstMatch
        reveal(shelf); ready(shelf); shelf.tap()
        let empty = app.staticTexts["还没有模版"]
        reveal(empty); XCTAssertTrue(empty.exists)
        let create = app.buttons["新建模版"].firstMatch
        reveal(create); ready(create)
        try capture("template-empty-shelf")
        create.tap()
        XCTAssertTrue(app.navigationBars["新建模版"].waitForExistence(timeout: 8))
        let name = app.textFields["customPlanNameField"]
        ready(name); name.tap()
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.exists { tap("Continue") }
        let previous = try XCTUnwrap(name.value as? String)
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count + 2))
        let title = "诊断模版" + runID.prefix(8)
        name.typeText(title + "\n")
        XCTAssertEqual(name.value as? String, title)
        let add = app.buttons["添加训练项目"]
        reveal(add); ready(add); add.tap()
        tap("添加中袋直线出杆")
        tap("完成(1)")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.exists)
        try capture("template-fields-before-save")
        if observedNavigationTouch {
            try navigationTouch(app.buttons["保存"].firstMatch, stage: "save")
        } else { tap("保存") }
        tap("仅保存")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForNonExistence(timeout: 8))
        let templates = app.buttons["我的模版"].firstMatch
        reveal(templates); ready(templates); templates.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "trainingHome.template.edit.", title)).firstMatch
        reveal(card); ready(card); card.tap()
        XCTAssertTrue(app.navigationBars["编辑模版"].waitForExistence(timeout: 8))
        XCTAssertEqual(name.value as? String, title)
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.exists)
        try capture("template-saved-reopened")
        if observedNavigationTouch {
            try navigationTouch(app.navigationBars.buttons.firstMatch, stage: "return")
        } else { back() }
        ready(card)
    }

}
