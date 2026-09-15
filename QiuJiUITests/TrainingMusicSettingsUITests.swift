import XCTest

final class TrainingMusicSettingsUITests: XCTestCase {
    func testSoundTogglesAreIndependentAndPersist() {
        let app = XCUIApplication.launchClean(extraArgs: [
            "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings"
        ])
        let music = app.switches["settings.backgroundMusic"]
        let effects = app.switches["settings.shotSoundEffects"]
        XCTAssertTrue(music.waitForExistence(timeout: 10))
        XCTAssertTrue(effects.exists)
        // Start from known values through the real controls, not launch overrides.
        if music.value as? String != "1" { music.tap() }
        if effects.value as? String != "0" { effects.tap() }
        app.buttons["深色"].tap()
        capture("settings-music-on-effects-off-dark")
        music.tap()
        XCTAssertEqual(music.value as? String, "0")
        XCTAssertEqual(effects.value as? String, "0")
        effects.tap()
        XCTAssertEqual(music.value as? String, "0")
        XCTAssertEqual(effects.value as? String, "1")
        app.terminate()
        app.launch()
        XCTAssertTrue(music.waitForExistence(timeout: 10))
        XCTAssertEqual(music.value as? String, "0")
        XCTAssertEqual(effects.value as? String, "1")
        music.tap()
        effects.tap()
        // Debug deep links intentionally pin a color scheme; relaunch with the
        // light fixture so the screenshot verifies actual light rendering.
        app.terminate()
        app.launchArguments.append("-v54.forceLight")
        app.launch()
        XCTAssertTrue(music.waitForExistence(timeout: 10))
        XCTAssertEqual(app.scrollViews["settings.content"].value as? String, "light")
        capture("settings-music-on-effects-off-light")
        app.buttons["跟随系统"].tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
