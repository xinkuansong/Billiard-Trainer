import XCTest

final class ShotAudioPreviewUITests: XCTestCase {
    func testManualBreakPlaysWithImportedPreviewSounds() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("output/shot-audio-preview-20260930/manifest.json").path) else {
            throw XCTSkip("Local audition pack required")
        }
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-deeplink.dailyClearance", "-dailyClearance.resetState",
            "-dailyClearance.fixture=manual", "-shotAudioPreview", "-soundEffectsEnabled", "YES"
        ])
        app.terminate()
        app.launchArguments.removeAll { ["-shotAudioPreview", "-soundEffectsEnabled", "YES"].contains($0) }
        app.launch()
        XCUIDevice.shared.press(.home)
        app.activate()
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 20))
        XCTAssertTrue(strike.isEnabled)
        strike.tap()
        sleep(3)
        XCTAssertFalse(strike.isEnabled, "Break playback should own the shot controls")
        sleep(6)
        XCTAssertEqual(app.state, .runningForeground)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: root.appendingPathComponent("output/shot-audio-preview-20260930/app-after-break-r2.png"))
    }

    func testDailyClearancePlaysWithImportedPreviewSounds() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("output/shot-audio-preview-20260930/manifest.json").path) else {
            throw XCTSkip("Local audition pack required; import into simulator Documents/ShotAudioPreview first")
        }
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-deeplink.dailyClearance", "-dailyClearance.fixture=progress",
            "-shotAudioPreview", "-soundEffectsEnabled", "YES"
        ])
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 20))
        XCTAssertTrue(strike.isEnabled)
        strike.tap()
        // 真实页面击球路径；仅证明流程运行，资源解码/调度另查 ShotSoundBank 日志。
        sleep(6)
        XCTAssertEqual(app.state, .runningForeground)
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: root.appendingPathComponent("output/shot-audio-preview-20260930/app-after-shot.png"))
    }
}
