import XCTest

final class SnakePracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch(direct: Bool = true) {
        var args = ["-forcePremium", "-v51.followSystemAppearance", "-3dDrag.probe", "-snakePractice.resetHistory",
                    "-showTableGrid", "NO", "-snakePractice.count", "5", "-snakePractice.mode", "沿线清台", "-snakePractice.view3D", "NO"]
        if direct { args.append("-deeplink.snakePractice") }
        app = .launchClean(extraArgs: args)
        if !direct {
            app.switchTab(.angle)
            app.buttons["angleHomeTab_练"].tap()
            let card = app.buttons["蛇彩练习"]
            for _ in 0..<4 {
                if card.exists && card.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            do { try snap("00-train-entry-last") } catch { XCTFail("Entry screenshot: \(error)") }
            card.tap()
        }
        XCTAssertTrue(app.buttons["snake.start"].waitForExistence(timeout: 10))
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)], timeout: timeout), .completed)
    }
    private func snap(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
        }
    }
    private var state: XCUIElement { app.descendants(matching: .any)["snake.landscape"] }
    private var table: XCUIElement { app.descendants(matching: .any)["table.scene"] }
    private func balls() throws -> [[String: Any]] {
        let text = try XCTUnwrap(table.value as? String)
        let data = try XCTUnwrap(text.data(using: .utf8))
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(value["balls"] as? [[String: Any]])
    }
    private func ball(_ key: String) throws -> [String: Any] {
        try XCTUnwrap(try balls().first { $0["key"] as? String == key })
    }
    private func start() {
        app.buttons["snake.start"].tap()
        XCTAssertTrue(state.waitForExistence(timeout: 30))
        if UIDevice.current.userInterfaceIdiom != .pad { XCUIDevice.shared.orientation = .landscapeLeft }
        ready(app.buttons["dailyClearance.strike"])
    }
    private func menu() {
        ready(app.buttons["freeplay.moreMenu"])
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(app.buttons["snake.settings"].waitForExistence(timeout: 5))
    }
    private func restart() {
        ready(app.buttons["snake.restart"])
        app.buttons["snake.restart"].tap()
        XCTAssertTrue(app.buttons["snake.restart.confirm"].waitForExistence(timeout: 5))
        app.buttons["snake.restart.confirm"].tap()
    }
    private func chooseCount(_ count: Int) {
        app.buttons["snake.count"].tap()
        let option = app.buttons["snake.count.\(count)"]
        for _ in 0..<3 {
            if option.exists && option.isHittable { break }
            let menu = app.collectionViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", "snake.count.")).firstMatch
            if menu.exists { menu.swipeUp() }
        }
        XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
        option.tap()
    }
    private func checkPalette(_ count: Int) {
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).count, count)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        XCTAssertFalse(app.buttons["paletteBall__\(count+1)"].exists)
        XCTAssertFalse(app.buttons["break.entry"].exists)
    }

    func testProEntryGatesFreeAndAllowsPremium() throws {
        app = .launchClean(extraArgs: ["-forceNonPremium", "-v54.forceLight"])
        app.switchTab(.angle)
        app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons["蛇彩练习"]
        for _ in 0..<4 {
            if card.exists && card.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        try snap("pro-01-locked-entry")
        card.tap()
        XCTAssertTrue(app.buttons["subscription.close"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["snake.start"].exists)
        try snap("pro-02-subscription")
        app.buttons["subscription.close"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["snake.start"].exists)
        app.terminate()

        launch(direct: false)
        XCTAssertFalse(app.buttons["subscription.close"].exists)
        try snap("pro-03-member-settings")
    }

    func testCountsRandomSettingsAndStandardViews() throws {
        launch()
        XCTAssertFalse(app.descendants(matching: .any)["snake.preview"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["snake.arrangement"].exists)
        try snap("01-settings-five")
        start(); checkPalette(5)
        try snap("02-five-2d")
        for count in [3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15] {
            menu(); app.buttons["snake.settings"].tap()
            chooseCount(count)
            if count == 15 {
                app.segmentedControls["snake.mode"].buttons["按号"].tap()
                XCTAssertFalse(app.descendants(matching: .any)["snake.preview"].exists)
                XCTAssertFalse(app.descendants(matching: .any)["snake.arrangement"].exists)
                try snap("05-settings-fifteen")
            }
            start(); checkPalette(count)
            try snap("table-\(count)-2d")
        }
        let before = try balls().map { $0["key"] as! String }.sorted()
        menu(); app.buttons["freeplay.cameraMode"].tap()
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
        app.buttons["关闭菜单"].tap()
        ready(app.buttons["dailyClearance.strike"])
        XCTAssertEqual(try balls().map { $0["key"] as! String }.sorted(), before)
        checkPalette(15)
        try snap("07-fifteen-3d")
        menu(); try snap("08-standard-menu")
        XCTAssertFalse(app.buttons["snake.help"].exists)
        XCTAssertFalse(app.buttons["snake.next"].exists)
        app.buttons["关闭菜单"].tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            menu(); app.buttons["freeplay.cameraMode"].tap(); app.buttons["关闭菜单"].tap()
            XCUIDevice.shared.orientation = .portrait
            ready(app.buttons["dailyClearance.strike"])
            checkPalette(15); try snap("10-ipad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft
            ready(app.buttons["dailyClearance.strike"])
            checkPalette(15); try snap("11-ipad-landscape")
        }
    }

    func testRealEntryPlacementStrokeReplayUndoAndRestart() throws {
        launch(direct: false)
        start(); checkPalette(5)
        let cue = try ball("cueBall")
        XCTAssertEqual(cue["draggable"] as? Bool, true)
        for target in try balls() where target["key"] as? String != "cueBall" {
            XCTAssertEqual(target["draggable"] as? Bool, false)
        }
        let point = try XCTUnwrap(cue["screen"] as? [Double])
        let from = table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1]))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: 90, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.1)
        ready(app.buttons["dailyClearance.strike"])
        let placed = try XCTUnwrap(try ball("cueBall")["world"] as? [Double])
        let old = try XCTUnwrap(cue["world"] as? [Double])
        XCTAssertGreaterThan(abs(placed[0]-old[0])+abs(placed[2]-old[2]), 0.01)
        let beforeShot = try balls()
        app.buttons["paletteBall__3"].tap()
        XCTAssertTrue((state.value as? String ?? "").contains("目标_1"))
        app.buttons["dailyClearance.strike"].tap()
        let choice = app.buttons["snake.failure.retry"]
        XCTAssertTrue(choice.waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["snake.failure.retry"].exists)
        XCTAssertTrue(app.buttons["snake.failure.restart"].exists)
        try snap("12-failure-choice")
        app.buttons["snake.failure.retry"].tap()
        ready(app.buttons["dailyClearance.strike"])
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆true"))
        for expected in beforeShot {
            let key = try XCTUnwrap(expected["key"] as? String)
            let a = try XCTUnwrap(expected["world"] as? [Double])
            let b = try XCTUnwrap(try ball(key)["world"] as? [Double])
            XCTAssertEqual(a[0],b[0],accuracy:0.0001); XCTAssertEqual(a[2],b[2],accuracy:0.0001)
        }
        try snap("13-undo")
        menu(); app.buttons["snake.settings"].tap()
        chooseCount(10)
        app.buttons["snake.settingsCancel"].tap()
        checkPalette(5)
        restart()
        ready(app.buttons["dailyClearance.strike"])
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆true"))
        checkPalette(5)
    }
    private var recordRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "snake.record."))
    }
    private func revealRecords() {
        for _ in 0..<4 {
            if recordRows.firstMatch.exists && recordRows.firstMatch.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(recordRows.firstMatch.isHittable)
    }
    private func relaunchWithoutConfigurationOverrides() {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        var args = app.launchArguments
        for key in ["-snakePractice.count", "-snakePractice.mode"] {
            if let index = args.firstIndex(of: key) { args.removeSubrange(index...index+1) }
        }
        args.removeAll { $0 == "-snakePractice.resetHistory" }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.buttons["snake.start"].waitForExistence(timeout: 20))
    }
    func testChoiceMemoryAndUnplayedRestartExitDoNotCreateHistory() throws {
        launch()
        chooseCount(9)
        app.segmentedControls["snake.mode"].buttons["按号"].tap()
        relaunchWithoutConfigurationOverrides()
        XCTAssertTrue(app.buttons["snake.count"].label.contains("9") || (app.buttons["snake.count"].value as? String ?? "").contains("9"))
        XCTAssertTrue(app.segmentedControls["snake.mode"].buttons["按号"].isSelected)
        try snap("20-remembered-settings")
        start(); checkPalette(9)
        restart()
        ready(app.buttons["dailyClearance.strike"])
        menu(); app.buttons["snake.settings"].tap()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].exists)
        XCTAssertEqual(recordRows.count, 0)
        try snap("21-unplayed-restart-no-record")
        app.buttons["snake.settingsCancel"].tap()
        app.buttons["dailyClearance.back"].tap()
        relaunchWithoutConfigurationOverrides()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].exists)
        XCTAssertEqual(recordRows.count, 0)
        try snap("22-unplayed-exit-no-record")
        start()
        relaunchWithoutConfigurationOverrides()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].exists)
        XCTAssertEqual(recordRows.count, 0)
    }

    func testFailureRestartChoiceRecordsAndRetryRestoresWithoutRecording() throws {
        launch(); start()
        let power = app.descendants(matching: .any)["shotStage.powerBar"]
        let from = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        from.press(forDuration: 0.05, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)), withVelocity: .fast, thenHoldForDuration: 0.05)
        ready(app.buttons["dailyClearance.strike"])
        app.buttons["dailyClearance.strike"].tap()
        XCTAssertTrue(app.buttons["snake.failure.retry"].waitForExistence(timeout: 60))
        try snap("30-miss-choice")
        app.buttons["snake.failure.retry"].tap()
        ready(app.buttons["dailyClearance.strike"])
        menu(); app.buttons["snake.settings"].tap()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].exists)
        app.buttons["snake.settingsCancel"].tap()
        app.buttons["dailyClearance.strike"].tap()
        XCTAssertTrue(app.buttons["snake.failure.retry"].waitForExistence(timeout: 60))
        app.buttons["snake.failure.restart"].tap()
        ready(app.buttons["dailyClearance.strike"])
        menu(); app.buttons["snake.settings"].tap()
        revealRecords()
        XCTAssertEqual(recordRows.count, 1)
        XCTAssertTrue(recordRows.firstMatch.label.contains("失败"))
        XCTAssertTrue(recordRows.firstMatch.label.contains("0/5"))
        try snap("31-failure-record")
    }

    func testLegalStrokeReplayDoesNotChangeProgressOrRecord() throws {
        launch(); chooseCount(3); start()
        // Refresh the native probe after the forced landscape layout has settled.
        menu(); app.buttons["关闭菜单"].tap()
        let value = try XCTUnwrap(table.value as? String).data(using: .utf8)!
        let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: value) as? [String: Any])
        let pockets = try XCTUnwrap(probe["pockets"] as? [[String: Any]])
        let pocket = try XCTUnwrap(pockets.first { $0["index"] as? Int == 4 }?["screen"] as? [Double])
        // Aim a cut from below ball 2 toward the leftmost ball and upper middle
        // pocket; the earlier shallow/straight inputs actually scratched.
        let cue = try XCTUnwrap(try ball("cueBall")["screen"] as? [Double])
        let second = try XCTUnwrap(try ball("_2")["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: cue[0], dy: cue[1])).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(.init(dx: second[0] + 60, dy: cue[1])), withVelocity: .slow, thenHoldForDuration: 0.1)
        let placed = try XCTUnwrap(try ball("cueBall")["world"] as? [Double])
        // Shared ball dragging reserves 52 pt for finger clearance, plus one
        // recognizer sample before tracking. Verify the actual result, not the finger endpoint.
        XCTAssertGreaterThan(placed[0], -0.05, "Cue must cross the drag dead zone")
        XCTAssertLessThan(placed[0], 0.1)
        XCTAssertEqual(placed[2], 0.3175, accuracy: 0.01)
        origin.withOffset(.init(dx: pocket[0], dy: pocket[1])).tap()
        ready(app.buttons["dailyClearance.strike"])
        print("SNAKE_FIXTURE_STATE", state.value ?? "nil")
        print("SNAKE_FIXTURE_BALLS", try balls())
        try snap("38-legal-fixture-aim")
        app.buttons["dailyClearance.strike"].tap()
        ready(app.buttons["dailyClearance.playback"], timeout: 60)
        try snap("39-legal-fixture-outcome")
        XCTAssertFalse(app.buttons["snake.failure.retry"].exists, app.buttons["snake.failure.retry"].debugDescription)
        XCTAssertTrue((state.value as? String ?? "").contains("目标_2"))
        let settled = state.value as? String
        app.buttons["dailyClearance.playback"].tap()
        ready(app.buttons["dailyClearance.undo"], timeout: 60)
        XCTAssertEqual(state.value as? String, settled)
        try snap("40-legal-stroke-replayed")
        restart()
        ready(app.buttons["dailyClearance.strike"])
        menu(); app.buttons["snake.settings"].tap()
        revealRecords()
        XCTAssertTrue(recordRows.firstMatch.label.contains("1/3"))
        try snap("41-partial-score-record")
    }

    func testSettingsRestartGridAndTemporaryDrag() throws {
        launch()
        let modes = app.segmentedControls["snake.mode"]
        XCTAssertTrue(app.staticTexts["击球顺序"].exists)
        modes.buttons["从右到左"].tap()
        try snap("50-settings-three-orders")
        relaunchWithoutConfigurationOverrides()
        XCTAssertTrue(app.segmentedControls["snake.mode"].buttons["从右到左"].isSelected)
        start()
        XCTAssertTrue(app.staticTexts["母球自由球上手"].exists)
        let one = try XCTUnwrap(try ball("_1")["world"] as? [Double])
        let five = try XCTUnwrap(try ball("_5")["world"] as? [Double])
        XCTAssertGreaterThan(one[0], five[0])
        try snap("51-start-ball-in-hand")
        app.buttons["snake.restart"].tap()
        try snap("52-restart-confirmation")
        app.buttons["snake.restart.cancel"].tap()
        menu()
        XCTAssertFalse(app.buttons["snake.help"].exists)
        XCTAssertFalse(app.buttons["snake.next"].exists)
        app.scrollViews["dailyClearance.menuScroll"].swipeUp()
        try snap("53-practice-menu")
        app.scrollViews["dailyClearance.menuScroll"].swipeDown()
        // Repeated toggles must update the actual rendered table, including after idle.
        for index in 0..<4 {
            app.buttons["menu.tableGrid"].tap()
            try snap("54-grid-\(index)")
        }
        app.buttons["freeplay.cameraMode"].tap()
        app.buttons["关闭菜单"].tap()
        ready(app.buttons["shotCamera.temporaryTopDown"])
        app.buttons["shotCamera.temporaryTopDown"].tap()
        let cue = try XCTUnwrap(try ball("cueBall")["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(.init(dx: cue[0], dy: cue[1]))
        // Drag toward the center so all device sizes have enough legal table room.
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -110, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let after = try XCTUnwrap(try ball("cueBall")["screen"] as? [Double])
        let travel = cue[0] - after[0]
        XCTAssertGreaterThan(travel, 15)
        XCTAssertLessThan(travel, 65, "Temporary 2D must reserve at least 45pt of finger clearance")
        try snap("55-temporary-drag-clearance")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        for index in 0..<3 {
            menu(); app.buttons["menu.tableGrid"].tap()
            try snap("57-grid-3d-\(index)")
            app.buttons["关闭菜单"].tap()
        }
        ready(app.buttons["snake.restart"])
        app.buttons["snake.restart"].tap()
        try snap("56-3d-restart-confirmation")
        app.buttons["snake.restart.confirm"].tap()
        menu(); app.buttons["snake.settings"].tap()
        XCTAssertTrue(app.staticTexts["暂无训练记录"].exists)
    }

    func testSharedDailyConfirmationsAndFreePlayDrag() throws {
        app = .launchClean(extraArgs: ["-forcePremium", "-v51.followSystemAppearance", "-deeplink.dailyClearance",
            "-dailyClearance.resetState", "-dailyClearance.resetHomeState", "-dailyClearance.fixture=progress"])
        let daily = app.descendants(matching: .any)["dailyClearance.landscape"]
        XCTAssertTrue(daily.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        for dimension in ["2D", "3D"] {
            app.buttons["freeplay.moreMenu"].tap()
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension { mode.tap() }
            app.buttons["关闭菜单"].tap()
            ready(app.buttons["break.entry"])
            app.buttons["break.entry"].tap()
            XCTAssertTrue(app.buttons["dailyClearance.confirmBreak"].waitForExistence(timeout: 5))
            try snap("60-daily-\(dimension)-restart")
            app.buttons["dailyClearance.confirmBreak"].tap()
            app.buttons["freeplay.moreMenu"].tap()
            app.buttons["dailyClearance.changeGame"].tap()
            app.buttons["dailyClearance.game.fourBall"].tap()
            XCTAssertTrue(app.buttons["dailyClearance.gameChangeCancel"].waitForExistence(timeout: 5))
            try snap("61-daily-\(dimension)-change-game")
            app.buttons["dailyClearance.gameChangeCancel"].tap()
        }
        app.terminate()
        app = .launchClean(extraArgs: ["-forcePremium", "-v51.followSystemAppearance", "-deeplink.freePlay", "-3dDrag.probe"])
        XCTAssertTrue(table.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        if mode.value as? String != "3D" { mode.tap() }
        app.buttons["关闭菜单"].tap()
        ready(app.buttons["shotCamera.temporaryTopDown"])
        app.buttons["shotCamera.temporaryTopDown"].tap()
        let cue = try XCTUnwrap(try ball("cueBall")["screen"] as? [Double])
        let from = table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: cue[0], dy: cue[1]))
        let dx: Double = cue[0] > table.frame.width / 2 ? -110 : 110
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: dx, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let after = try XCTUnwrap(try ball("cueBall")["screen"] as? [Double])
        let travel = abs(after[0] - cue[0])
        XCTAssertGreaterThan(travel, 15)
        XCTAssertLessThan(travel, 65)
        try snap("62-freeplay-temporary-drag")
        app.terminate()
        app = .launchClean(extraArgs: ["-forcePremium", "-v51.followSystemAppearance", "-dailyInteraction.sharedPage=composer"])
        XCTAssertTrue(table.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["freeplay.moreMenu"].tap()
        let reset = app.buttons["composer.reset"]
        if !reset.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        reset.tap()
        XCTAssertTrue(app.buttons["composer.reset.cancel"].waitForExistence(timeout: 5))
        try snap("63-composer-reset")
        app.buttons["composer.reset.cancel"].tap()

    }

}

/// Real gestures, world-position assertions and permission parity across camera modes.
final class LegalBallMovementUITests: XCTestCase {
    private var app: XCUIApplication!
    private var prefix = "freeplay"
    private var route = ""
    private var evidenceRun = ""
    private struct Probe: Decodable {
        struct Ball: Decodable {
            let key: String
            let screen: [Double]
            let world: [Double]
            let draggable: Bool
        }
        let balls: [Ball]
        let camera: [Double]
        let diagramSurface: String
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private var table: XCUIElement { app.descendants(matching: .any)["table.scene"].firstMatch }
    private func ready(_ e: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: 45), .completed)
    }
    private func probe() throws -> Probe {
        try JSONDecoder().decode(Probe.self, from: Data(try XCTUnwrap(table.value as? String).utf8))
    }
    private func capture(_ label: String) throws {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = route + "-" + label; a.lifetime = .keepAlways; add(a)
        let p = XCTAttachment(string: try XCTUnwrap(table.value as? String))
        p.name = route + "-" + label + "-world"; p.lifetime = .keepAlways; add(p)
    }
    private func launch(_ page: String, extra: [String] = []) throws {
        route = page + evidenceRun
        XCUIDevice.shared.orientation = .landscapeLeft
        prefix = ["bank": "bankshot", "diamond": "reflection", "separation": "separationAngleAtlas", "cushion": "cushionEnglishAtlas"][page] ?? page
        var args = ["-forcePremium", "-v50.inMemoryStore", "-3dDrag.probe", "-v54.forceDark", "-drillTryout.hasSeenGestureHint", "YES"]
        switch page {
        case "freeplay": args += ["-deeplink.freePlay"]
        case "daily": prefix = "freeplay"; args += ["-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.resetHomeState"]
        case "snake": prefix = "freeplay"; args += ["-deeplink.snakePractice", "-snakePractice.count", "3"]
        case "silu": args += ["-deeplink.silu"]
        case "planthree": args += ["-deeplink.planThree", "-planThree.twoBall"]
        case "snooker": args += ["-deeplink.snooker", "-snooker.full"]
        case "tryout": prefix = "freeplay"; args += ["-deeplink.tryout=drill_c042"]
        case "formation": prefix = "freeplay"; args += ["-deeplink.customFormation", "-customFormation.owner=drag-audit-\(UUID())"]
        default:
            if ["composer", "shot"].contains(page) { prefix = "freeplay" }
            args += ["-dailyInteraction.sharedPage=" + page]
        }
        app = .launchClean(extraArgs: args + extra)
        if page == "formation" {
            ready(app.buttons["formation.new"]); app.buttons["formation.new"].tap()
            ready(app.buttons["paletteBall__1"]); app.buttons["paletteBall__1"].tap()
            ready(app.buttons["formation.edit.save"]); app.buttons["formation.edit.save"].tap()
            let save = app.alerts["保存模板"].buttons.matching(identifier: "formation.save.confirm").firstMatch
            ready(save); save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["formation.start"]); app.buttons["formation.start"].tap()
        }
        if page == "snake" { ready(app.buttons["snake.start"]); app.buttons["snake.start"].tap() }
        XCTAssertTrue(table.waitForExistence(timeout: 45))
        XCUIDevice.shared.orientation = .landscapeLeft
        if page == "tryout" {
            openMenu(); ready(app.buttons["tryout.mode"]); app.buttons["tryout.mode"].tap(); closeMenu()
        }
    }
    private func openMenu() {
        let more = app.buttons[prefix + (prefix == "freeplay" ? ".moreMenu" : ".more")]
        ready(more)
        // The floating button's AX activation point can be invalid after rotation;
        // use its actual visible centre, as for the existing menu backdrop tests.
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func closeMenu() {
        let dismiss = app.buttons[prefix == "freeplay" ? "关闭菜单" : prefix + ".dismissMenu"]
        if !dismiss.exists { return } // Some menu actions close their own panel.
        ready(dismiss); dismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    }
    private func mode(_ value: String) {
        openMenu()
        let button = app.buttons[prefix + ".cameraMode"]; ready(button)
        if button.value as? String != value { button.tap() }
        // Solver pages apply stored view changes when the pending solve finishes.
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: button)], timeout: 15), .completed)
        closeMenu()
        if value == "3D" { ready(app.buttons["dailyClearance.observeTable"]); app.buttons["dailyClearance.observeTable"].tap() }
    }
    private func permissions(_ p: Probe) -> Set<String> { Set(p.balls.filter(\.draggable).map(\.key)) }
    private func assertRetained(_ before: Probe, _ after: Probe) throws {
        for ball in before.balls {
            let b = try XCTUnwrap(after.balls.first { $0.key == ball.key })
            for i in 0..<3 { XCTAssertEqual(ball.world[i], b.world[i], accuracy: 0.0001, "Camera switch changed " + ball.key) }
        }
    }
    private func waitForCameraToSettle() {
        var previous: [Double] = []
        var stableSince = Date()
        let condition = NSPredicate { [weak self] _, _ in
            guard let p = try? self?.probe() else { return false }
            let current = p.camera + p.balls.flatMap { Array($0.screen.prefix(2)) }
            if previous.count != current.count || zip(previous, current).contains(where: { abs($0 - $1) > 0.0001 }) {
                previous = current; stableSince = Date(); return false
            }
            return Date().timeIntervalSince(stableSince) >= 0.4
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: condition, object: nil)], timeout: 15), .completed,
                       "Read drag coordinates only after the actual camera and ball projections settle")
    }
    private func drag(_ key: String, label: String, offset: Double = 0, distance: Double = 120, moves: Bool = true, vertical: Bool = false) throws {
        if label.hasPrefix("3D-") { waitForCameraToSettle() }
        let before = try probe()
        let ball = try XCTUnwrap(before.balls.first { $0.key == key })
        let x = ball.screen[0], y = ball.screen[1]
        XCTAssertTrue(CGRect(origin: .zero, size: table.frame.size).contains(CGPoint(x: x, y: y)))
        let dx = vertical ? 0 : (x > table.frame.width / 2 ? -distance : distance)
        let dy = vertical ? (y > table.frame.height / 2 ? -distance : distance) : 0
        let start = table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y + offset))
        try capture(label + "-before")
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .slow, thenHoldForDuration: 0.3)
        let after = try probe()
        try capture(label + "-after")
        let moved = try XCTUnwrap(after.balls.first { $0.key == key })
        let travel = hypot(moved.world[0] - ball.world[0], moved.world[2] - ball.world[2])
        if moves { XCTAssertGreaterThan(travel, 0.002, label + ": legal ball did not move") }
        else { XCTAssertLessThan(travel, 0.0001, label + ": finger-clearance gate or permission violated") }
        XCTAssertEqual(ball.world[1], moved.world[1], accuracy: 0.0001)
        if moves && vertical && label.hasPrefix("temporary-") {
            let displayedTravel = hypot(moved.screen[0] - ball.screen[0], moved.screen[1] - ball.screen[1])
            XCTAssertEqual(displayedTravel, distance - 52, accuracy: 2,
                           "Temporary 2D must reserve exactly 52pt, even when drag events are coalesced")
        }
        for other in before.balls where other.key != key {
            let b = try XCTUnwrap(after.balls.first { $0.key == other.key })
            for i in 0..<3 { XCTAssertEqual(other.world[i], b.world[i], accuracy: 0.0001, label + ": moved another ball " + other.key) }
        }
    }
    private func check(_ page: String, extra: [String] = [], cueOnly: Bool = false, restricted: Bool = false, nearHit: Bool = false, kitchen: Bool = false, prepare: (() -> Void)? = nil) throws {
        try launch(page, extra: extra)
        prepare?()
        mode("2D")
        let baseline = try probe(), allowed = permissions(baseline)
        if restricted { XCTAssertTrue(allowed.isEmpty) }
        else if cueOnly { XCTAssertEqual(allowed, ["cueBall"]) }
        else { XCTAssertTrue(allowed.contains("cueBall")); XCTAssertGreaterThan(allowed.count, 1) }
        let keys = restricted ? ["cueBall"] : ["cueBall"] + (cueOnly ? [] : Array(allowed.filter { $0 != "cueBall" }.sorted().prefix(1)))
        for dimension in ["2D", "3D", "temporary"] {
            let prior = try probe()
            if dimension == "3D" { mode("3D") }
            if dimension == "temporary" { ready(app.buttons["shotCamera.temporaryTopDown"]); app.buttons["shotCamera.temporaryTopDown"].tap() }
            let current = try probe()
            try assertRetained(prior, current)
            XCTAssertEqual(permissions(current), allowed, dimension + " changed movement permissions")
            if dimension == "temporary" { XCTAssertEqual(current.diagramSurface, "temporaryTopDown") }
            for key in keys {
                if dimension != "3D" && !restricted { try drag(key, label: dimension + "-short-" + key, distance: 30, moves: false) }
                // This drill starts with collinear targets. Move its first target
                // sideways on the table before the perspective pass, so its centre
                // is not covered by the nearer ball (which correctly wins the hit).
                let separateTryoutTarget = page == "tryout" && key != "cueBall" && dimension == "2D"
                try drag(key, label: dimension + "-" + key, moves: !restricted,
                         vertical: (kitchen && dimension != "3D") || separateTryoutTarget)
                if kitchen {
                    let cue = try XCTUnwrap(probe().balls.first { $0.key == "cueBall" })
                    XCTAssertGreaterThanOrEqual(cue.world[0], 2.54 / 4 - 0.0001, "Cue escaped the legal kitchen")
                }
            }
            if nearHit && dimension != "3D" { try drag("cueBall", label: dimension + "-near-hit", offset: 30) }
        }
        let held = try probe()
        app.buttons["shotCamera.temporaryTopDown"].tap()
        try assertRetained(held, probe())
        mode("2D")
        try assertRetained(held, probe())
        try capture("returned-2D")
    }
    func testAngleDiagram() throws { try check("angleDynamic") }
    func testSeparationDiagram() throws { try check("separation") }
    func testCushionDiagram() throws { try check("cushion") }
    func testBank() throws { try check("bank") }
    func testDiamond() throws { try check("diamond") }
    func testSilu() throws { try check("silu") }
    func testPlanThree() throws { try check("planthree") }
    func testDefense() throws { try check("snooker") }
    func testFreePlay() throws { try check("freeplay", cueOnly: true) }
    func testComposer() throws { try check("composer") }
    func testSimulation() throws { try check("shot") }
    func testTryoutFree() throws { try check("tryout") }
    func testSnakeOpening() throws { try check("snake", cueOnly: true) }
    func testDailyBallInHand() throws { try check("daily", extra: ["-dailyClearance.fixture=ballInHand"], cueOnly: true) }
    func testDailyBehindHeadString() throws { try check("daily", extra: ["-dailyClearance.fixture=behindHeadString"], cueOnly: true, kitchen: true) }
    func testDailyBehindHeadStringRepeated() throws {
        // A tablet-only zero-movement observation needs repeated complete flows,
        // with the original gesture and clearance assertions retained.
        for iteration in 1...3 {
            evidenceRun = "-repeat\(iteration)"
            try check("daily", extra: ["-dailyClearance.fixture=behindHeadString"], cueOnly: true, kitchen: true)
            app.terminate()
        }
    }
    func testDailyLocked() throws { try check("daily", extra: ["-dailyClearance.fixture=selection"], restricted: true) }
    func testTemporaryNearHitMatchesOrdinary() throws { try check("freeplay", cueOnly: true, nearHit: true) }
    func testFormationPractice() throws { try check("formation") }
    func testFormationArrange() throws {
        try check("formation", prepare: {
            self.openMenu()
            let arrange = self.app.buttons["formation.arrange"]
            for _ in 0..<5 {
                if arrange.exists && arrange.isHittable { break }
                self.app.scrollViews["dailyClearance.menuScroll"].swipeUp()
            }
            self.ready(arrange); arrange.tap(); self.closeMenu()
        })
    }
    private func checkBreak(_ page: String) throws {
        try check(page, cueOnly: true, kitchen: true, prepare: {
            let entry = self.app.buttons["break.entry"]
            if !entry.exists { self.openMenu() }
            self.ready(entry); entry.tap()
            self.ready(self.app.buttons["break.game.9"]); self.app.buttons["break.game.9"].tap()
            self.ready(self.app.buttons[self.prefix == "freeplay" ? "break.strike" : self.prefix + ".strike"])
        })
    }
    func testFreePlayBreak() throws { try checkBreak("freeplay") }
    func testComposerBreak() throws { try checkBreak("composer") }
    func testSiluBreak() throws { try checkBreak("silu") }
    func testPlanThreeBreak() throws { try checkBreak("planthree") }
    func testDailyBreak() throws { try check("daily", extra: ["-dailyClearance.fixture=manual"], cueOnly: true, kitchen: true) }
}
