import XCTest

/// Normal UI boundary diagnostics. Run permission cases on separate fresh devices.
final class SystemBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"])
    }
    override func tearDownWithError() throws { app?.terminate() }

    private func ready(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        XCTAssertTrue(element.isHittable)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "system-\(runID)-\(stage)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(filename + ".png"))
    }
    private func guestProfile() throws {
        app.switchTab(.profile)
        let guest = app.buttons["profile.login"]
        XCTAssertTrue(guest.waitForExistence(timeout: 8))
        _ = try XCTUnwrap(guest.exists && guest.label.contains("游客模式") ? true : nil,
                          "Refuse profile mutation unless the actual UI identifies a guest")
        XCTAssertFalse(app.descendants(matching: .any)["profile.accountHeader"].exists)
    }
    private func profilePage(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        reveal(row); ready(row); row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8))
    }
    private func back() {
        let element = app.navigationBars.buttons.firstMatch
        ready(element); element.tap()
    }
    private func dismissKeyboardIntroIfPresent() {
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.exists {
            let proceed = app.buttons["Continue"]
            ready(proceed); proceed.tap()
        }
    }

    func testLibraryEmptySearchRecoversAndFavoriteSurvivesReentry() throws {
        try guestProfile()
        profilePage("我的收藏")
        XCTAssertTrue(app.staticTexts["还没有收藏"].waitForExistence(timeout: 10))
        let browse = app.buttons["浏览动作库"].firstMatch
        ready(browse); browse.tap()
        let search = app.textFields["librarySearchField"]
        ready(search); search.tap(); dismissKeyboardIntroIfPresent()
        search.typeText("QDNORESULT" + runID.prefix(8) + "\n")
        XCTAssertTrue(app.staticTexts["没有找到相关动作"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "drillCard_")).count, 0)
        try capture("library-no-results")
        let all = app.buttons["浏览全部动作"].firstMatch
        reveal(all); ready(all); all.tap()
        XCTAssertTrue(app.staticTexts["没有找到相关动作"].waitForNonExistence(timeout: 8))
        ready(search); search.tap(); search.typeText("中袋直线出杆\n")
        let card = app.buttons["drillCard_drill_c012"].firstMatch
        ready(card); card.tap()
        let favorite = app.buttons["收藏"].firstMatch
        ready(favorite); favorite.tap()
        XCTAssertTrue(app.buttons["取消收藏"].waitForExistence(timeout: 5))
        try capture("detail-favorited")
        back(); XCTAssertTrue(search.waitForExistence(timeout: 8))
        try guestProfile()
        profilePage("我的收藏")
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["还没有收藏"].exists)
        try capture("favorites-first-entry")
        back(); profilePage("我的收藏")
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.waitForExistence(timeout: 10))
        try capture("favorites-reentered")
    }

    func testGuestNicknameUsesNormalLocalEditorAndReopens() throws {
        try guestProfile()
        profilePage("个人信息")
        let nameButton = app.buttons["personalInfo.displayNameButton"]
        ready(nameButton); nameButton.tap()
        let field = app.textFields["personalInfo.displayNameField"]
        ready(field); dismissKeyboardIntroIfPresent()
        let oldValue = try XCTUnwrap(field.value as? String)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count + 2))
        let nickname = "诊断" + runID.prefix(8)
        field.typeText(nickname)
        XCTAssertEqual(field.value as? String, nickname)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let save = app.buttons["personalInfo.displayNameSave"]
        ready(save)
        try capture("guest-name-keyboard")
        save.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 8))
        XCTAssertTrue(nameButton.label.contains(nickname))
        back()
        try guestProfile()
        profilePage("个人信息")
        ready(nameButton); XCTAssertTrue(nameButton.label.contains(nickname))
        try capture("guest-name-reentered")
    }

    private func notificationPrompt(allow: Bool) throws {
        try guestProfile()
        profilePage("训练目标")
        let toggle = app.switches["trainingGoal.reminderEnabled"]
        reveal(toggle); ready(toggle)
        let status = app.staticTexts["trainingGoal.reminderAuthorization"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "首次开启时会请求系统通知权限", "Each permission case needs its own fresh undecided device")
        XCTAssertEqual(toggle.value as? String, "0")
        try capture("notification-before-request")
        toggle.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let springAlert = springboard.alerts.firstMatch
        let alert = springAlert.waitForExistence(timeout: 5) ? springAlert : app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "The real system prompt is required")
        let allowPredicate = NSPredicate(format: "(label CONTAINS '允许' AND NOT label CONTAINS '不允许') OR label == 'Allow'")
        let denyPredicate = NSPredicate(format: "label CONTAINS '不允许' OR label == \"Don't Allow\"")
        let allowButton = alert.buttons.matching(allowPredicate).firstMatch
        let denyButton = alert.buttons.matching(denyPredicate).firstMatch
        // Both permission choices distinguish this from an app error or stale settings screen.
        XCTAssertTrue(allowButton.exists); XCTAssertTrue(denyButton.exists)
        let tree = XCTAttachment(string: alert.debugDescription)
        tree.name = "system-\(runID)-notification-prompt-AX"; tree.lifetime = .keepAlways; add(tree)
        try capture("notification-real-prompt")
        let action = allow ? allowButton : denyButton
        ready(action); action.tap()
        if !allow {
            let failure = app.alerts["无法开启提醒"]
            XCTAssertTrue(failure.waitForExistence(timeout: 8))
            try capture("notification-denied-explanation")
            let acknowledge = failure.buttons["知道了"]
            ready(acknowledge); acknowledge.tap()
        }
        let expected = allow ? "系统通知权限已开启" : "系统通知权限未开启，请前往系统设置允许通知"
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: status)], timeout: 8), .completed)
        XCTAssertEqual(toggle.value as? String, allow ? "1" : "0")
        try capture("notification-final-status")
    }
    func testNotificationRealPromptAllowedWithEvidence() throws { try notificationPrompt(allow: true) }
    func testNotificationRealPromptDeniedWithEvidence() throws { try notificationPrompt(allow: false) }
}
