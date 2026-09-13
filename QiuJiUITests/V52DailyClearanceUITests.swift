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

    func testPerspectiveRoundTripsPreserveDailyProgress() {
        let app = launch(["-dailyClearance.fixture=progress"])
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.exists)
        for _ in 0..<3 {
            camera.tap()
            XCTAssertEqual(camera.value as? String, "3D")
            XCTAssertTrue(hud.label.contains("2 杆"))
            XCTAssertTrue(hud.label.contains("1 次犯规"))
            app.buttons["freeplay.observation"].tap()
            app.buttons["freeplay.observe.table"].tap()
            snap(app, "v63-daily-3d-progress")
            camera.tap()
            XCTAssertEqual(camera.value as? String, "2D")
            XCTAssertTrue(hud.label.contains("2 杆"))
            XCTAssertTrue(hud.label.contains("1 次犯规"))
        }
        snap(app, "v63-daily-returned-progress")
    }

    func testRealAutomaticBreakFirstShotAndRelaunchIn3D() {
        let app = launch([], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 90), "The real automatic break must deliver")
        XCTAssertTrue(hud.label.contains("0 杆"))
        snap(app, "v63-daily-real-break-3d")
        app.buttons["瞄准模式：进袋，点击切换"].tap()
        let strike = app.buttons["击球"]
        let enabled = NSPredicate(format: "enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: enabled, evaluatedWith: strike)], timeout: 20), .completed)
        strike.tap()
        let oneShot = NSPredicate(format: "label CONTAINS %@", "1 杆")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: oneShot, evaluatedWith: hud)], timeout: 60), .completed)
        snap(app, "v63-daily-first-shot-3d")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-dailyClearance.resetState" }
        app.launch()
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("1 杆"))
        XCTAssertFalse(app.descendants(matching: .any)["dailyClearance.autoBreaking"].exists)
        snap(app, "v63-daily-restored-first-shot")
    }

    func testRealManualBreakDeliversAndRestoresIn3D() {
        let app = launch(["-dailyClearance.fixture=manual"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        let strike = app.buttons["break.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        XCTAssertTrue(strike.isEnabled)
        snap(app, "v63-daily-manual-ready-3d")
        XCTAssertFalse(app.buttons["取消"].exists, "An abandoned daily attempt cannot restore the previous board")
        app.buttons["break.rerack"].tap()
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=manual"
        }
        app.launch()
        XCTAssertTrue(strike.waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["取消"].exists)
        if camera.value as? String != "3D" { camera.tap() }
        // This second rerack must deliver without a restart masking stale controller state.
        app.buttons["break.rerack"].tap()
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        strike.tap()
        let confirm = app.buttons["break.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 90))
        XCTAssertFalse(app.buttons["取消"].exists)
        snap(app, "v63-daily-manual-settled-3d")
        confirm.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("0 杆"))
        XCTAssertFalse(confirm.exists)
        XCTAssertTrue(app.buttons["击球"].exists)
        snap(app, "v63-daily-manual-delivered-3d")
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=manual"
        }
        app.launch()
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("0 杆"))
        XCTAssertFalse(app.buttons["break.strike"].exists)
    }

    func testCompletedAndFailedResultsRemainUsableIn3D() {
        for state in ["completed", "failed"] {
            let app = launch(["-dailyClearance.fixture=" + state])
            let camera = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(camera.waitForExistence(timeout: 12))
            camera.tap()
            XCTAssertEqual(camera.value as? String, "3D")
            let action = app.buttons[state == "completed" ? "dailyClearance.replay" : "dailyClearance.rerack"]
            XCTAssertTrue(action.isHittable)
            XCTAssertGreaterThanOrEqual(action.frame.minY, 0)
            XCTAssertFalse(app.buttons["击球"].exists, "A finished daily attempt must not expose another shot")
            XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY)
            snap(app, "v63-daily-3d-" + state)
            camera.tap()
            XCTAssertTrue(action.isHittable)
            XCTAssertFalse(app.buttons["击球"].exists)
            camera.tap()
            XCTAssertTrue(action.isHittable)
            app.terminate()
        }
    }

    func testFinalNineBallPhysicallyCompletesAndReplays() {
        let app = launch(["-dailyClearance.fixture=lastBall"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        let strike = app.buttons["击球"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                      evaluatedWith: strike)], timeout: 30), .completed)
        snap(app, "v63-daily-last-ball-ready")
        strike.tap()
        let replay = app.buttons["dailyClearance.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 60), "The simulated final ball must reach completion")
        XCTAssertFalse(strike.exists)
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].label.contains("1 杆"))
        snap(app, "v63-daily-last-ball-completed")
        replay.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "0 杆"),
                                                      evaluatedWith: hud)], timeout: 90), .completed)
        XCTAssertFalse(replay.exists)
        XCTAssertEqual(camera.value as? String, "3D")
        snap(app, "v63-daily-new-rack-after-completion")
    }

    func testPhysicalScratchRestoresCueAndAllowsNextShot() {
        let app = launch(["-dailyClearance.fixture=scratch"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        let strike = app.buttons["击球"]
        func waitForStrike() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                          evaluatedWith: strike)], timeout: 30), .completed)
        }
        waitForStrike()
        snap(app, "v63-daily-scratch-ready")
        strike.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "1 次犯规"),
                                                      evaluatedWith: hud)], timeout: 60), .completed)
        waitForStrike()
        app.buttons["freeplay.observation"].tap()
        XCTAssertTrue(app.buttons["freeplay.observe.cue"].isEnabled, "The physically pocketed cue must be restored")
        app.buttons["freeplay.observe.table"].tap()
        snap(app, "v63-daily-scratch-cue-restored")
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "2 杆"),
                                                      evaluatedWith: hud)], timeout: 60), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=scratch" }
        app.launch()
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("2 杆"))
        snap(app, "v63-daily-scratch-resumed")
    }
}
