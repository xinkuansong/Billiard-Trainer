import XCTest

final class ProfileNavigationDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    override func setUpWithError() throws {
        continueAfterFailure = false
        // No followSystemAppearance override: this suite tests actual preference changes.
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws { app?.terminate() }
    private func ready(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10)); XCTAssertTrue(element.isHittable)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func guestProfile() throws {
        app.switchTab(.profile)
        let guest = app.buttons["profile.login"]
        XCTAssertTrue(guest.waitForExistence(timeout: 8))
        _ = try XCTUnwrap(guest.exists && guest.label.contains("游客模式") ? true : nil)
        XCTAssertFalse(app.descendants(matching: .any)["profile.accountHeader"].exists)
    }
    private func openProfilePage(_ title: String) {
        let item = app.staticTexts[title].firstMatch
        reveal(item); ready(item); item.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8))
    }
    private func capture(_ stage: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let filename = "profile-nav-\(runID)-\(stage)"
        let item = XCTAttachment(screenshot: screenshot)
        item.name = filename; item.lifetime = .keepAlways; add(item)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: dir.appendingPathComponent(filename + ".png"))
    }
    private func back() { let button = app.navigationBars.buttons.firstMatch; ready(button); button.tap() }
    private func assertValue(_ element: XCUIElement, _ value: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)], timeout: 8), .completed)
    }

    func testGuestAppearanceAndSoundPreferencesRestoreOriginalValues() throws {
        try guestProfile(); openProfilePage("偏好设置")
        let modes = ["跟随系统", "浅色", "深色"]
        let selectedModes = modes.filter { app.buttons[$0].isSelected }
        XCTAssertEqual(selectedModes.count, 1)
        let original = try XCTUnwrap(selectedModes.first, "Read the selected preference, not the current effective color")
        let content = app.scrollViews["settings.content"]
        ready(content)
        let sound = app.switches["击球音效"]
        reveal(sound); ready(sound)
        let oldSound = try XCTUnwrap(sound.value as? String)
        XCTAssertTrue(["0", "1"].contains(oldSound))
        try capture("settings-before")
        sound.tap(); assertValue(sound, oldSound == "1" ? "0" : "1")
        try capture("sound-toggled")
        sound.tap(); assertValue(sound, oldSound)
        for (mode, effective) in [("深色", "dark"), ("浅色", "light")] {
            let button = app.buttons[mode]
            for _ in 0..<6 {
                if button.exists && button.isHittable { break }
                app.swipeDown()
            }
            ready(button); button.tap()
            XCTAssertTrue(button.isSelected)
            assertValue(content, effective)
            try capture("settings-\(effective)")
        }
        let restore = app.buttons[original]
        ready(restore); restore.tap()
        XCTAssertTrue(restore.isSelected)
        reveal(sound); assertValue(sound, oldSound)
        try capture("settings-restored")
        back(); XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8))
    }

    func testAboutShowsFrozenUnpublishedLegalConfigurationWithoutExternalActions() throws {
        try guestProfile(); openProfilePage("关于与反馈")
        let missing = app.staticTexts["用户协议与隐私政策尚未发布。发布前不会用空操作或测试网址冒充正式入口。"]
        reveal(missing); XCTAssertTrue(missing.exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.terms"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["about.privacy"].exists)
        try capture("about-legal-unpublished")
        back(); XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8))
    }

    func testPhotoExtractionNormalEntryShowsUnselectedStateAndReturns() throws {
        try guestProfile()
        app.switchTab(.angle)
        let play = app.buttons["angleHomeTab_打"]
        ready(play); play.tap()
        let card = app.buttons["拍照建球形"]
        reveal(card); ready(card); card.tap()
        XCTAssertTrue(app.navigationBars["拍照建球形"].waitForExistence(timeout: 12))
        let picker = app.buttons["选择照片"]
        ready(picker); XCTAssertTrue(picker.isEnabled)
        XCTAssertTrue(app.staticTexts["拍摄或选择一张球桌照片"].exists)
        XCTAssertFalse(app.buttons["下一步"].exists)
        try capture("photo-extraction-no-photo-selected")
        // Do not open a picker that might expose existing private photos.
        back(); ready(play); ready(card)
        try capture("photo-extraction-returned")
    }
}
