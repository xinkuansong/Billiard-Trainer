import XCTest

final class V52DailyClearanceUITests: XCTestCase {
    private var outDir: URL {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["V52_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V52_SHOT_DIR"]
            ?? "/Users/song/projects/13.billiard_trainer/build/v52-screenshots/after"
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private func launch(_ extra: [String], game: String = "chineseEightBall") -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: [
            "-deeplink.dailyClearance",
            "-dailyClearance.resetState",
            "-dailyClearance.preferredGame.v1", game
        ] + extra)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("截图写入失败：\(url.path)，\(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAutomaticBreakDeliversStraightIntoSinglePlayerHUD() {
        let app = launch(["-dailyClearance.fixtureSettled"])
        XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["玩家 A"].exists)
        XCTAssertFalse(app.staticTexts["玩家 B"].exists)
        snap(app, "v52-daily-playing")
    }

    func testNineBallDefaultAutomaticallyBreaksAndBecomesShootable() {
        let app = launch(["-dailyClearance.fixtureSettled"], game: "nineBall")
        XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 12))
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 8))
        XCTAssertTrue(hud.label.contains("9 球"), "9 球默认值应贯穿自动开球后的单人 HUD")
        XCTAssertTrue(app.descendants(matching: .any)["freeplay.stage"].exists)
        snap(app, "v52-daily-nine-ball-playing")
    }

    func testRerackCancelAndConfirmKeepStageFrameStable() {
        let app = launch(["-dailyClearance.fixture=progress"])
        let stage = app.descendants(matching: .any)["freeplay.stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 12))
        let playingFrame = stage.frame

        let rerack = app.descendants(matching: .any)["break.entry"]
        XCTAssertTrue(rerack.waitForExistence(timeout: 5))
        rerack.tap()
        XCTAssertTrue(app.buttons["放弃并重新开球"].waitForExistence(timeout: 4))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 4))

        rerack.tap()
        XCTAssertTrue(app.buttons["放弃并重新开球"].waitForExistence(timeout: 4))
        app.buttons["放弃并重新开球"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.breakStatus"].waitForExistence(timeout: 6))
        XCTAssertEqual(stage.frame.width, playingFrame.width, accuracy: 0.5)
        XCTAssertEqual(stage.frame.height, playingFrame.height, accuracy: 0.5)
        snap(app, "v52-daily-manual-rack")
    }

    func testTemporaryGameChangeRequiresAbandonConfirmation() {
        let app = launch(["-dailyClearance.fixture=progress"])
        let menu = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 12))
        menu.tap()
        XCTAssertTrue(app.buttons["临时换玩法"].waitForExistence(timeout: 4))
        app.buttons["临时换玩法"].tap()
        let nineBall = app.descendants(matching: .any)["dailyClearance.game.nineBall"]
        XCTAssertTrue(nineBall.waitForExistence(timeout: 4))
        nineBall.tap()
        XCTAssertTrue(app.buttons["放弃并切换"].waitForExistence(timeout: 4))
        app.buttons["放弃并切换"].tap()
        let breakStatus = app.descendants(matching: .any)["dailyClearance.breakStatus"]
        XCTAssertTrue(breakStatus.waitForExistence(timeout: 6))
        XCTAssertTrue(breakStatus.label.contains("9 球"))
    }

    func testCompletedReplayPreservesCompletionAndStartsAnotherBoard() {
        let app = launch(["-dailyClearance.fixture=completed", "-dailyClearance.fixtureSettled"])
        let replay = app.buttons["dailyClearance.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 12))
        snap(app, "v52-daily-completed")
        replay.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 8))
        XCTAssertFalse(replay.exists)
    }
}
