import XCTest

/// Standard FreePlay consumes Daily's chrome while keeping manual break delivery and game rules.
final class S1_FreePlayLayoutUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        var args = ["-forcePremium", "-v51.followSystemAppearance", "-dailyLayout.probe", "-3dDrag.probe"]
        if UIDevice.current.userInterfaceIdiom != .pad { args.append("-deeplink.freePlay") }
        app = XCUIApplication.launchClean(extraArgs: args)
    }

    private func snap(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let root = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
        }
    }

    private func ready(_ element: XCUIElement, timeout: TimeInterval = 30) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)], timeout: timeout), .completed)
    }

    private func open() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.switchTab(.angle)
            let tab = app.buttons["angleHomeTab_打"]
            XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
            let card = app.buttons["自由击球"]
            XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        }
        XCTAssertTrue(app.buttons["freeplay.moreMenu"].waitForExistence(timeout: 15))
        if UIDevice.current.userInterfaceIdiom == .pad { XCUIDevice.shared.orientation = .landscapeLeft }
        sleep(2)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
    }

    private func menu() {
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout: 3))
    }

    private func toggleView(_ value: String) {
        menu()
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, value)
        // View mode stays in the menu; dismiss through its explicit outside layer.
        if app.buttons["关闭菜单"].exists { app.buttons["关闭菜单"].tap() }
        sleep(1)
    }

    private func chooseFreeAim() {
        menu(); app.buttons["dailyClearance.aimModeMenu"].tap()
        let free = app.buttons["dailyClearance.aim.free"]
        XCTAssertTrue(free.waitForExistence(timeout: 3)); free.tap()
    }

    func testFreePlayLayoutAndTableSizeLock() throws {
        open()
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        let initial = stage.frame
        XCTAssertFalse(app.descendants(matching: .any)["paletteBall_cueBall"].exists)
        for n in 1...15 { XCTAssertTrue(app.buttons["paletteBall__\(n)"].exists) }
        try snap("01-standard-2d")
        chooseFreeAim()
        XCTAssertEqual(stage.frame.width, initial.width, accuracy: 1)
        XCTAssertEqual(stage.frame.height, initial.height, accuracy: 1)
        let wheel = app.otherElements["shotStage.aimWheel"]
        XCTAssertTrue(wheel.isEnabled)
        XCTAssertEqual(wheel.label, "瞄准微调")
        menu(); try snap("02-standard-settings")
        XCTAssertTrue(app.buttons["freeplay.clearTable"].exists)
        XCTAssertFalse(app.buttons["dailyClearance.changeGame"].exists)
        app.buttons["menu.tableGrid"].tap()
        toggleView("3D")
        for name in ["firstPerson", "thirdPerson", "wholeTable"] {
            let button = app.buttons[name == "wholeTable" ? "dailyClearance.observeTable" : "shotCamera." + name]
            XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap(); sleep(1)
            try snap("03-camera-" + name)
        }
        let temporary = app.buttons["shotCamera.temporaryTopDown"]
        temporary.tap(); sleep(1); try snap("04-temporary-2d")
        temporary.tap(); sleep(1); try snap("05-temporary-return")
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(app.buttons["回中"].waitForExistence(timeout: 3))
        app.buttons["低杆增加 1%"].tap(); app.buttons["回中"].tap()
        try snap("06-spin")
        toggleView("2D")
        XCTAssertFalse(app.buttons["回中"].exists)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
            try snap("07-ipad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            try snap("08-ipad-landscape-return")
        }
        XCTAssertEqual(stage.frame.width, initial.width, accuracy: 1)
        XCTAssertEqual(stage.frame.height, initial.height, accuracy: 1)
    }

    func testPerspectiveBreakAndContinue() throws {
        open(); toggleView("3D")
        for count in [15, 9] {
            app.buttons["break.entry"].tap()
            let game = app.buttons["break.game.\(count)"]
            XCTAssertTrue(game.waitForExistence(timeout: 5)); game.tap()
            let strike = app.buttons["break.strike"]
            ready(strike); try snap("rack-\(count)-3d")
            app.buttons["dailyClearance.observeTable"].tap()
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let point = table.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3))
            point.press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: .init(dx: 0.6, dy: 0.3)))
            app.buttons["shotCamera.thirdPerson"].tap()
            toggleView("2D"); try snap("rack-\(count)-2d")
            app.buttons["break.rerack"].tap(); ready(strike)
            strike.tap()
            let confirm = app.buttons["break.confirm"]
            ready(confirm, timeout: 75); try snap("settled-\(count)-2d")
            toggleView("3D"); XCTAssertTrue(confirm.isHittable)
            confirm.tap()
            XCTAssertTrue(app.descendants(matching: .any)["freeplay.gameStatus"].waitForExistence(timeout: 5))
            try snap("delivered-\(count)-3d")
        }
        chooseFreeAim()
        let strike = app.buttons["dailyClearance.strike"]
        ready(strike); strike.tap()
        ready(app.buttons["dailyClearance.undo"], timeout: 60)
        try snap("continued-shot")
        app.buttons["dailyClearance.playback"].tap()
        ready(app.buttons["dailyClearance.undo"], timeout: 60)
        app.buttons["dailyClearance.undo"].tap()
        app.buttons["break.entry"].tap(); app.buttons["break.game.4"].tap()
        ready(app.buttons["break.strike"]); menu(); app.buttons["freeplay.cancelBreak"].tap()
        ready(strike); try snap("cancelled-break")
    }

    func testPerspectiveScratchReturnsCueAutomatically() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.freePlay", "-v63.freePlayScratch", "-dailyLayout.probe"])
        open(); toggleView("3D")
        let strike = app.buttons["dailyClearance.strike"]
        ready(strike); strike.tap()
        ready(app.buttons["dailyClearance.playback"], timeout: 45)
        ready(strike)
        XCTAssertFalse(app.descendants(matching: .any)["paletteBall_cueBall"].exists)
        let status = app.descendants(matching: .any)["freeplay.landscape"].firstMatch
        XCTAssertTrue(status.exists)
        XCTAssertTrue((status.value as? String ?? "").contains("犯规"))
        try snap("scratch-returned-3d")
        app.buttons["dailyClearance.playback"].tap()
        ready(strike, timeout: 45)
        try snap("scratch-replay-return")
    }
}
