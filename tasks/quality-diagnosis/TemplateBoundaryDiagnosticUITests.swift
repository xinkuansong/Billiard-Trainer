import XCTest

/// Unregistered diagnostic draft. Normal UI on a new dedicated disk guest simulator.
final class TemplateBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private let token = UUID().uuidString
    private var sequence = 0
    private enum Failure: Error { case requirement(String) }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal-unclassified") }
    }

    func testInvalidDraftsLongNameAndOneDrillTemplateSurviveProcessRestart() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_TEMPLATE_BOUNDARY") == "NEW_DEDICATED_DISK_GUEST_SIMULATOR", "New dedicated disk guest authorization required")
        guard let expected = setting("QD_TEMPLATE_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              let actual = env["SIMULATOR_UDID"], expected.lowercased() == actual.lowercased()
        else { throw Failure.requirement("Authorized new UDID must equal runner SIMULATOR_UDID") }
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute output directory required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try launchGuest()
        try shelf(empty: true)

        // A fresh field avoids assuming the caret or guessing how to select existing text.
        try create()
        try saveDisabled("both-name-and-actions-empty")
        try addC037()
        try require(app.textFields["customPlanNameField"].value as? String == "我的模版"
                    || app.textFields["customPlanNameField"].value as? String == "", "Untouched empty field must remain placeholder/empty")
        try saveDisabled("one-action-but-name-empty")
        try backToShelf()
        try shelf(empty: true)

        let longName = String(repeating: "长名称模版边界", count: 8) + String(token.prefix(8))
        try create()
        try enterFreshName(longName)
        try saveDisabled("long-name-but-no-actions")
        try capture("long-name-visible-field-and-return-control-review-required")
        try backToShelf()
        try shelf(empty: true)

        try create()
        try enterFreshName(longName)
        try addC037()
        let save = app.navigationBars.buttons["保存"].firstMatch
        try until("Valid one-action draft enables save") { save.exists && save.isEnabled }
        // Prior actual toolbar AX can report false hittable. Touch only its measured navigation frame.
        try navigationTouch(save)
        try tap(app.buttons["仅保存"])
        try until("Builder must dismiss after save") { !self.app.navigationBars["新建模版"].exists && self.rootTabsVisible }
        try shelf(empty: false)
        let cards = templateCards()
        try until("Exactly one normal template was saved") { cards.count == 1 }
        let card = cards.firstMatch
        try reveal(card)
        try require(card.label.contains(longName), "Shelf accessibility identity must preserve full long name")
        let identifier = card.identifier
        let id = identifier.replacingOccurrences(of: "trainingHome.template.edit.", with: "")
        try require(UUID(uuidString: id) != nil, "Only actual UUID template card counts, not cover/button decorations")
        try capture("saved-one-template-long-name-review-required")
        try tap(card)
        try checkEditor(longName)
        try backToShelf()

        app.terminate()
        try require(app.wait(for: .notRunning, timeout: 10), "Old process must end before relaunch")
        print("[QD-TemplateBoundary] old process notRunning; ordinary disk store retained; templateID=\(id)")
        try launchGuest()
        try shelf(empty: false)
        try until("Same single template must survive relaunch") { self.templateCards().count == 1 }
        let reopened = app.buttons[identifier]
        try reveal(reopened)
        try require(reopened.label.contains(longName), "Same UUID and full name must survive process restart")
        try tap(reopened)
        try checkEditor(longName)
        try capture("reopened-same-uuid-full-name-one-action-review-required")
        try backToShelf()
        try capture("verified-exit-after-restart")
    }

    /// Companion only: real keyboard input and discard, not another save/restart verdict.
    func testNormalTemplateKeyboardInputAndDiscardKeepsShelfEmpty() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_TEMPLATE_BOUNDARY") == "NEW_DEDICATED_DISK_GUEST_SIMULATOR", "New dedicated disk guest authorization required")
        guard let expected = setting("QD_TEMPLATE_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              let actual = env["SIMULATOR_UDID"], expected.lowercased() == actual.lowercased()
        else { throw Failure.requirement("Authorized new UDID must equal runner SIMULATOR_UDID") }
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute output directory required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try launchGuest()
        try shelf(empty: true)

        try require(setting("QD_TEMPLATE_KEYBOARD_EVIDENCE") == "1", "Explicit expanded-keyboard evidence required")
        try create()
        try enterFreshName("键盘观察" + String(token.prefix(8)))
        try saveDisabled("named-draft-without-actions")
        try backToShelf()
        try shelf(empty: true)
        try capture("keyboard-companion-returned-empty-no-template-saved")
    }

    private func launchGuest() throws {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 15), "App foreground required")
        try selectRootTab("我的")
        try until("Guest profile required") { self.app.buttons["profile.login"].exists }
        try require(app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "No real account or authenticated fixture allowed")
        try selectRootTab("训练")
    }
    private var rootTabsVisible: Bool {
        if app.tabBars.firstMatch.exists { return true }
        // m3-keyboard001 actual AX: five nested Button pairs in top Other, no TabBar.
        let names = ["训练", "动作库", "练习", "记录", "我的"]
        let buttons = names.map { app.buttons.matching(NSPredicate(format: "label == %@", $0)).firstMatch }
        guard buttons.allSatisfy({ $0.exists && !$0.frame.isEmpty }) else { return false }
        let row = buttons[0].frame
        return buttons.allSatisfy { abs($0.frame.midY - row.midY) < 1 && $0.frame.maxY < app.windows.firstMatch.frame.midY }
    }
    private func selectRootTab(_ title: String) throws {
        try until("Actual system root tab row required") { self.rootTabsVisible }
        let standard = app.tabBars.buttons[title]
        let button = standard.exists ? standard : app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        try tap(button)
        try until("Root tab selection must take effect") { button.isSelected }
    }
    private func templateCards() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "trainingHome[.]template[.]edit[.][A-Fa-f0-9-]{36}"))
    }
    private func shelf(empty: Bool) throws {
        let segment = app.buttons["我的模版"]
        try reveal(segment); try tap(segment)
        if empty {
            try until("Empty template shelf must be visible") { self.app.staticTexts["还没有模版"].exists }
            try require(templateCards().count == 0, "No pre-existing template is permitted")
        } else { try until("Saved template shelf must be present") { self.templateCards().count == 1 } }
    }
    private func create() throws {
        let button = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "新建模版", "list.bullet.clipboard")).firstMatch
        try reveal(button); try tap(button)
        try until("New builder identity") { self.app.navigationBars["新建模版"].exists }
        try require(app.staticTexts["还没有添加训练项目"].exists, "Each diagnostic draft begins without actions")
    }
    private func enterFreshName(_ name: String) throws {
        let field = app.textFields["customPlanNameField"]
        try require(field.waitForExistence(timeout: 10), "Fresh name field required")
        try require(field.value as? String == "我的模版" || field.value as? String == "", "Refuse to overwrite unknown text/caret state")
        try tap(field)
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.waitForExistence(timeout: 2) {
            let controls = app.buttons.matching(identifier: "Continue")
            try require(controls.count == 1, "Keyboard introduction must expose exactly one Continue control")
            try tap(controls.firstMatch)
            try require(intro.waitForNonExistence(timeout: 8), "Keyboard introduction must dismiss before text input")
        }
        let env = ProcessInfo.processInfo.environment
        let keyboardEvidence = env["QD_TEMPLATE_KEYBOARD_EVIDENCE"] == "1"
            || env["TEST_RUNNER_QD_TEMPLATE_KEYBOARD_EVIDENCE"] == "1"
        if keyboardEvidence {
            field.typeText(name)
            try until("Full name must be entered while real keyboard is present") {
                field.value as? String == name && self.app.keyboards.firstMatch.exists
            }
            try require(field.isHittable, "Focused template field must remain reachable with keyboard")
            try capture("matrix-long-name-real-keyboard-expanded-review-required")
            field.typeText("\n")
        } else {
            field.typeText(name + "\n")
        }
        try until("Entered full long name must be exact") { field.value as? String == name }
        try until("Keyboard must normally dismiss") { !self.app.keyboards.firstMatch.exists }
    }
    private func addC037() throws {
        let add = app.buttons["添加训练项目"]
        try reveal(add); try tap(add)
        let search = app.searchFields.firstMatch
        try tap(search)
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.waitForExistence(timeout: 2) {
            let controls = app.buttons.matching(identifier: "Continue")
            try require(controls.count == 1, "Keyboard introduction must expose exactly one Continue control")
            try tap(controls.firstMatch)
            try require(intro.waitForNonExistence(timeout: 8), "Keyboard introduction must dismiss before text input")
        }
        search.typeText("走位基础")
        try tap(app.buttons["添加走位基础"])
        try until("Real c037 selection must be reflected") { self.app.buttons["取消选择走位基础"].exists }
        let close = app.buttons["关闭"]
        if close.exists {
            try tap(close)
        } else {
            // M2 iOS17 run001 AX and full screenshot show the system Search key.
            try require(app.keyboards.firstMatch.exists, "Actual search keyboard required")
            try tap(app.keyboards.buttons["Search"])
        }
        try until("Picker search keyboard closes") { !self.app.keyboards.firstMatch.exists }
        let done = app.buttons["完成(1)"]
        if !done.exists {
            // M2 run002: keyboard dismissed but searchable remains active, with Cancel.
            let picker = app.navigationBars["选择训练动作"]
            try require(search.exists && search.value as? String == "走位基础", "Observed active search must match selected drill")
            try tap(picker.buttons["取消"])
            // run003: clear search restores full lazy List; selected c037 row is offscreen.
            // Count remains one. Verify exact c037 on the builder after closing the picker.
            try until("One selection must survive leaving search") { done.exists && done.isEnabled }
        }
        try tap(done)
        try until("One c037 full dose must be loaded") { self.app.staticTexts["3 组  1 动作"].exists && self.app.staticTexts["走位基础"].exists }
    }
    private func saveDisabled(_ stage: String) throws {
        let save = app.navigationBars.buttons["保存"].firstMatch
        try until("Invalid draft must disable save menu") { save.exists && !save.isEnabled }
        try require(!app.buttons["仅保存"].exists, "No save action menu may already be open")
        try capture(stage)
    }
    private func checkEditor(_ name: String) throws {
        try until("Actual edit page required") { self.app.navigationBars["编辑模版"].exists }
        try until("Persisted full name and one action dose required") {
            self.app.textFields["customPlanNameField"].value as? String == name
                && self.app.staticTexts["3 组  1 动作"].exists
                && self.app.staticTexts["走位基础"].exists
        }
    }
    private func backToShelf() throws {
        let identified = app.navigationBars.buttons["BackButton"]
        let back = identified.exists ? identified : app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "返回")).firstMatch
        try navigationTouch(back)
        try until("Normal back must reach training shelf") { self.rootTabsVisible && !self.app.textFields["customPlanNameField"].exists }
    }
    private func navigationTouch(_ element: XCUIElement) throws {
        try until("Navigation control must exist and be enabled") { element.exists && element.isEnabled }
        try require(!element.frame.isEmpty && app.navigationBars.firstMatch.frame.contains(element.frame), "Measured navigation control frame required")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func reveal(_ element: XCUIElement) throws {
        for _ in 0..<12 {
            let window = app.windows.firstMatch.frame
            let navBottom = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : window.minY
            let tabs = app.tabBars.firstMatch
            // Actual iPad26 longread001 shows its system tab bar above content.
            // Use measured bar position; do not treat every tab bar as a bottom obstruction.
            let upperTabs = tabs.exists && tabs.frame.midY < window.midY
            let top = max(navBottom, upperTabs ? tabs.frame.maxY : window.minY)
            let bottom = tabs.exists && !upperTabs ? tabs.frame.minY : window.maxY
            if element.exists && element.isHittable && !element.frame.isEmpty && window.contains(element.frame)
                && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            let candidates = app.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > $0.frame.width && $0.frame.width > window.width * 0.8 }
            try require(candidates.count == 1, "Need actual unique vertical ScrollView")
            let scroll = candidates[0]
            let upper = max(top, scroll.frame.minY), lower = min(bottom, scroll.frame.maxY)
            try require(lower > upper, "Usable scroll viewport required")
            let distance = (lower - upper) / 8
            let direction: CGFloat = element.exists && element.frame.minY < upper ? -1 : 1
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let center = (lower + upper) / 2 - scroll.frame.minY
            let from = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center + direction * distance / 2))
            let to = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center - direction * distance / 2))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        throw Failure.requirement("Target not fully visible above real TabBar; preserve evidence")
    }
    private func tap(_ element: XCUIElement) throws {
        try until("Actionable actual control required") { element.exists && element.isEnabled && element.isHittable }
        element.tap()
    }
    private func until(_ message: String, _ body: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: 12) == .completed, message)
    }
    private func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.requirement(message) } }
    private func capture(_ stage: String) throws {
        sequence += 1
        let stem = "template-boundary-\(token)-\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot); attachment.name = stem; attachment.lifetime = .keepAlways; add(attachment)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
