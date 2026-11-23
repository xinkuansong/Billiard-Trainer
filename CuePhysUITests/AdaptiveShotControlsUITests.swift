import XCTest

final class AdaptiveShotControlsUITests: XCTestCase {
    func testRulerAudioEnabledAndMutedInBothDimensions() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("build/control-audio-20261001/ui")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for enabled in [true, false] {
            let arguments = ["-deeplink.dailyClearance", "-dailyClearance.resetState",
                "-dailyClearance.fixture=progress", "-soundEffectsEnabled", enabled ? "YES" : "NO"]
                + (enabled ? ["-shotAudioPreview"] : [])
            let app = XCUIApplication.launchClean(extraArgs: arguments)
            for dimension in ["2d", "3d"] {
                let strike = app.buttons["dailyClearance.strike"]
                XCTAssertTrue(strike.waitForExistence(timeout: 20))
                if dimension == "3d" { app.buttons["freeplay.cameraMode"].tap() }
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
                let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
                let before = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                for control in [power, wheel] {
                    control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                        .press(forDuration: 0.1,
                               thenDragTo: control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                               withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.3)
                }
                XCTAssertGreaterThan(try XCTUnwrap(Double(try XCTUnwrap(power.value as? String))), before)
                // Aim edits recompute the prediction asynchronously before enabling strike.
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                XCTAssertTrue((status.value as? String)?.contains("自由模式") == true)
                try XCUIScreen.main.screenshot().pngRepresentation.write(to:
                    directory.appendingPathComponent("\(enabled ? "enabled" : "muted")-\(dimension).png"))
            }
            app.terminate()
        }
        // Playback and mute evidence is collected from the simulator audio-engine log.
        // This UI assertion only verifies that actual gestures and shot controls still work.
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
    }

    func testSamePowerTravelIsFinerWhenSlowInBothDimensions() throws {
        for dimension in ["2d", "3d"] {
            var changes: [Double] = []
            for speed in [20.0, 300.0] {
                let app = XCUIApplication.launchClean(extraArgs: [
                    "-deeplink.dailyClearance", "-dailyClearance.resetState",
                    "-dailyClearance.fixture=progress"
                ])
                let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
                XCTAssertTrue(power.waitForExistence(timeout: 15))
                if dimension == "3d" { app.buttons["freeplay.cameraMode"].tap() }
                let strike = app.buttons["dailyClearance.strike"]
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                let beforeStatus = status.value as? String
                let initial = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                    .press(forDuration: 0.1,
                           thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                           withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: 0.1)
                let final = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                changes.append(final - initial)
                XCTAssertGreaterThan(final, initial)
                XCTAssertEqual(status.value as? String, beforeStatus, "Adjustment never fires a shot")
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    .press(forDuration: 0.1,
                           thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                           withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: 0.1)
                XCTAssertEqual(wheel.value as? String, speed < 30 ? "精细刻度" : "常规刻度")
                XCTAssertEqual(try XCTUnwrap(Double(try XCTUnwrap(power.value as? String))), final)
                let afterAim = try XCTUnwrap(status.value as? String)
                XCTAssertEqual(Array(afterAim.components(separatedBy: "，").prefix(4)),
                               Array((beforeStatus ?? "").components(separatedBy: "，").prefix(4)),
                               "Aiming can change aim mode, but cannot advance the game")
                XCTAssertTrue(afterAim.contains("自由模式"))
                let shot = XCUIScreen.main.screenshot()
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = "adaptive-\(dimension)-\(Int(speed))-power-\(final)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let directory = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/adaptive-controls-r2-20260928/after")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try shot.pngRepresentation.write(to: directory.appendingPathComponent("\(dimension)-\(Int(speed))-\(Int(app.frame.width)).png"))
                app.terminate()
            }
            XCTAssertLessThan(changes[0], changes[1] * 0.5, "\(dimension): slow=\(changes[0]), fast=\(changes[1])")
        }
    }
}

final class NextShotDefaultsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws { app?.terminate() }

    private func launch(_ arguments: [String]) {
        app = .launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
                                      "-freeLayout.ephemeral", "-3dDrag.probe",
                                      "-v54.forceDark"] + arguments)
    }

    private func ready(_ element: XCUIElement, timeout: TimeInterval = 25) {
        let predicate = NSPredicate(format: "exists == true AND enabled == true AND hittable == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                     timeout: timeout), .completed, element.debugDescription)
    }

    private var table: XCUIElement { app.descendants(matching: .any)["table.scene"].firstMatch }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func closeSpinPad(_ disc: XCUIElement) {
        // The centre of the dismissal layer is covered by the interactive disc.
        // Tap the visible backdrop so closing it cannot edit the selected tip.
        let backdrop = app.buttons["关闭打点"].firstMatch
        backdrop.coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.05)).tap()
        XCTAssertTrue(disc.waitForNonExistence(timeout: 5))
    }

    private func cuePosition() throws -> [Double] {
        let data = Data(try XCTUnwrap(table.value as? String).utf8)
        let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        return try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" }?["world"] as? [Double])
    }

    private func checkShot(_ page: String, retry: Bool = false) throws {
        XCTAssertTrue(table.waitForExistence(timeout: 40))
        XCUIDevice.shared.orientation = .landscapeLeft
        let sharedStrike = app.buttons["dailyClearance.strike"].firstMatch
        let strike = page == "02-freeplay" ? app.buttons["击球"].firstMatch : sharedStrike
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        let spin = app.buttons["shotStage.spinEntry"].firstMatch
        let disc = app.descendants(matching: .any)["spinPad.disc"].firstMatch
        ready(strike)
        ready(power)
        let defaultPower = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
        XCTAssertEqual(defaultPower, 2.0, accuracy: 0.001)
        power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.70)).press(forDuration: 0.1,
            thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.57)),
            withVelocity: XCUIGestureVelocity(rawValue: 70), thenHoldForDuration: 0.1)
        let struckPower = try XCTUnwrap(power.value as? String)
        XCTAssertNotEqual(struckPower, "2.00")
        ready(spin); spin.tap()
        let high = app.buttons["高杆增加 1%"].firstMatch
        ready(high)
        for _ in 0..<4 { high.tap() }
        let struckTip = try XCTUnwrap(disc.value as? String)
        XCTAssertNotEqual(struckTip, "中心球")
        screenshot(page + "-before")
        closeSpinPad(disc)
        ready(strike)
        let cueBefore = try cuePosition()
        screenshot(page + "-ready")
        strike.tap()
        let settled = NSPredicate { _, _ in
            power.exists && (power.value as? String) == "2.00"
                && ((try? self.cuePosition()).map { $0 != cueBefore } ?? false)
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 55)
        screenshot(page + "-settled")
        XCTAssertEqual(result, .completed, "The cue must move and the next shot must return to the default speed")
        ready(spin); spin.tap()
        XCTAssertTrue(disc.waitForExistence(timeout: 5))
        screenshot(page + "-centered")
        XCTAssertEqual(disc.value as? String, "中心球")
        closeSpinPad(disc)

        if retry {
            let replay = app.buttons["dailyClearance.playback"].firstMatch
            ready(replay); replay.tap(); ready(replay, timeout: 55)
            XCTAssertEqual(power.value as? String, "2.00")
            let undo = app.buttons["dailyClearance.undo"].firstMatch
            ready(undo); undo.tap()
            ready(strike)
            ready(spin)
            spin.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.4)).tap()
            XCTAssertTrue(disc.waitForExistence(timeout: 5))
            XCTAssertEqual(power.value as? String, struckPower)
            XCTAssertEqual(disc.value as? String, struckTip)
            screenshot(page + "-retry")
        }
    }

    func testDailyClearance() throws {
        launch(["-deeplink.dailyClearance", "-dailyClearance.resetState",
                "-dailyClearance.preferredGame.v1", "nineBall",
                "-dailyClearance.fixture=scoringPair"])
        XCTAssertTrue(table.waitForExistence(timeout: 25))
        XCUIDevice.shared.orientation = .landscapeLeft
        let more = app.buttons["freeplay.moreMenu"].firstMatch
        ready(more); more.tap()
        let mode = app.buttons["freeplay.cameraMode"].firstMatch
        ready(mode)
        if mode.value as? String == "3D" { mode.tap() }
        app.buttons["关闭菜单"].firstMatch.tap()
        let raw = Data(try XCTUnwrap(table.value as? String).utf8)
        let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let pockets = try XCTUnwrap(probe["pockets"] as? [[String: Any]])
        let point = try XCTUnwrap(pockets.first { $0["index"] as? Int == 4 }?["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero)
            .withOffset(.init(dx: point[0], dy: point[1])).tap()
        try checkShot("01-daily")
    }

    func testFreePlay() throws {
        launch(["-deeplink.freePlay"])
        try checkShot("02-freeplay")
    }

    func testSnakePractice() throws {
        launch(["-deeplink.snakePractice", "-snakePractice.count", "3",
                "-snakePractice.mode", "沿线清台", "-snakePractice.view3D", "NO"])
        let start = app.buttons["snake.start"]
        ready(start); start.tap()
        XCTAssertTrue(table.waitForExistence(timeout: 30))
        XCUIDevice.shared.orientation = .landscapeLeft
        let more = app.buttons["freeplay.moreMenu"]
        ready(more); more.tap(); app.buttons["关闭菜单"].tap()
        let raw = Data(try XCTUnwrap(table.value as? String).utf8)
        let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        let pockets = try XCTUnwrap(probe["pockets"] as? [[String: Any]])
        let cue = try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" }?["screen"] as? [Double])
        let second = try XCTUnwrap(balls.first { $0["key"] as? String == "_2" }?["screen"] as? [Double])
        let pocket = try XCTUnwrap(pockets.first { $0["index"] as? Int == 4 }?["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: cue[0], dy: cue[1])).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(.init(dx: second[0] + 60, dy: cue[1])),
            withVelocity: .slow, thenHoldForDuration: 0.1)
        origin.withOffset(.init(dx: pocket[0], dy: pocket[1])).tap()
        try checkShot("03-snake")
    }

    func testMultiBall() throws {
        launch(["-pro.route=multiBall", "-multiBall.fixedSeed"])
        let picker = app.segmentedControls["multiBall.positionMode"]
        if !picker.isHittable { app.collectionViews.firstMatch.swipeUp() }
        let free = picker.buttons["自主走位"]
        ready(free); free.tap()
        let start = app.buttons["multiBall.start"]
        ready(start); start.tap()
        try checkShot("04-multiball")
    }

    func testCustomFormation() throws {
        launch(["-deeplink.customFormation", "-customFormation.owner=reset-evidence"])
        let builtIn = app.buttons["formation.builtin.B4443000-0000-4000-8000-000000000001"]
        ready(builtIn); builtIn.tap()
        let start = app.buttons["formation.start"]
        ready(start); start.tap()
        try checkShot("05-formation", retry: true)
    }

    func testSeparationAndPosition() throws {
        launch([])
        app.switchTab(.angle)
        app.buttons["angleHomeTab_走位"].tap()
        let entry = app.buttons["分离角与走位"]
        for _ in 0..<5 {
            if entry.isHittable { break }
            app.swipeUp()
        }
        ready(entry); entry.tap()
        try checkShot("06-composer", retry: true)
    }
}


final class BoardMemoryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testComposerExitAndRelaunch() throws {
        try exercise(title: "分离角与走位", back: "dailyClearance.back", palette: "paletteBall__5")
    }
    func testSiluExitAndRelaunch() throws {
        try exercise(title: "走位求解", back: "silu.back", palette: "paletteBall__5")
    }
    func testPlanThreeExitAndRelaunch() throws {
        try exercise(title: "打一走二想三", back: "planthree.back", palette: "paletteBall__5")
    }
    func testBankExitAndRelaunch() throws {
        try exercise(title: "翻袋", back: "bankshot.back", palette: "paletteBall__5")
    }
    func testDiamondExitAndRelaunch() throws {
        try exercise(title: "颗星解球", back: "reflection.back", palette: "paletteBall__5")
    }
    func testAngleExitAndRelaunch() throws {
        try exercise(title: "角度与瞄准", back: "angleDynamic.back", palette: "paletteBall__5")
    }
    func testToleranceExitAndRelaunch() throws {
        try exercise(title: "进球容错角", back: "pocketTolerance.back", palette: "paletteBall__5")
    }
    func testSevenPageIsolation() throws {
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-freeLayout.ephemeral", "-3dDrag.probe"])
        app.terminate(); app.launchEnvironment["BOARD_MEMORY_TEST_DOMAIN"] = UUID().uuidString; app.launch()
        defer { app.terminate() }
        let pages = [("分离角与走位", "dailyClearance", "_7"), ("走位求解", "silu", "_6"),
                     ("打一走二想三", "planthree", "_9"), ("翻袋", "bankshot", "_5"),
                     ("颗星解球", "reflection", "_12"), ("角度与瞄准", "angleDynamic", "_4"),
                     ("进球容错角", "pocketTolerance", "_15")]
        func open(_ title: String, _ prefix: String) {
            let search = app.textFields["librarySearchField"]
            if !search.exists { app.switchTab(.angle) }
            XCTAssertTrue(search.waitForExistence(timeout: 20)); search.tap()
            let old = search.value as? String ?? ""
            if !old.isEmpty && old != search.placeholderValue { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
            search.typeText(XCUIApplication.trainingCardTitle(title))
            app.buttons[XCUIApplication.trainingCardTitle(title)].tap()
            XCTAssertTrue(app.buttons[prefix + ".back"].waitForExistence(timeout: 30))
        }
        func board() throws -> [String: [Double]] {
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
            return try Dictionary(uniqueKeysWithValues: XCTUnwrap(object["balls"] as? [[String: Any]]).map {
                (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
            })
        }
        var expected: [String: [String: [Double]]] = [:]
        for (title, prefix, key) in pages {
            open(title, prefix)
            let button = app.buttons["paletteBall_" + key]
            XCTAssertTrue(button.waitForExistence(timeout: 30))
            var previous = CGRect.zero, since = Date()
            let ready = NSPredicate { _, _ in
                let frame = button.frame
                if frame != previous { previous = frame; since = Date() }
                return button.isEnabled && button.isHittable && Date().timeIntervalSince(since) > 1.5
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 60), .completed)
            button.tap()
            let added = NSPredicate { _, _ in (try? board()[key]) != nil }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: added, object: nil)], timeout: 20), .completed)
            expected[prefix] = try board()
            app.buttons[prefix + ".back"].tap()
            XCTAssertTrue(app.textFields["librarySearchField"].waitForExistence(timeout: 20))
        }
        app.terminate(); app.launch()
        for (title, prefix, _) in pages.reversed() {
            open(title, prefix)
            let actual = try board(), saved = try XCTUnwrap(expected[prefix])
            XCTAssertEqual(Set(actual.keys), Set(saved.keys), title)
            for (key, p) in saved {
                let q = try XCTUnwrap(actual[key])
                for axis in p.indices { XCTAssertEqual(p[axis], q[axis], accuracy: 0.00001, title) }
            }
            app.buttons[prefix + ".back"].tap()
            XCTAssertTrue(app.textFields["librarySearchField"].waitForExistence(timeout: 20))
        }
    }
    private func exercise(title: String, back: String, palette: String) throws {
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-freeLayout.ephemeral", "-3dDrag.probe"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.terminate()
        app.launchEnvironment["BOARD_MEMORY_TEST_DOMAIN"] = UUID().uuidString
        app.launch()
        func open() {
            let search = app.textFields["librarySearchField"]
            if !search.exists { app.switchTab(.angle) }
            XCTAssertTrue(search.waitForExistence(timeout: 20))
            search.tap()
            let old = search.value as? String ?? ""
            if !old.isEmpty && old != search.placeholderValue {
                search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            }
            search.typeText(XCUIApplication.trainingCardTitle(title))
            let card = app.buttons[XCUIApplication.trainingCardTitle(title)]
            XCTAssertTrue(card.waitForExistence(timeout: 15)); card.tap()
            let ball = app.buttons[palette]
            XCTAssertTrue(ball.waitForExistence(timeout: 30))
            var previous = CGRect.zero, since = Date()
            let stable = NSPredicate { _, _ in
                let frame = ball.frame
                if frame != previous { previous = frame; since = Date() }
                return ball.isHittable && ball.isEnabled && Date().timeIntervalSince(since) > 1.5
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: stable, object: nil)], timeout: 30), .completed)
        }
        func board() throws -> [String: [Double]] {
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let value = try XCTUnwrap(table.value as? String)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
            let balls = try XCTUnwrap(object["balls"] as? [[String: Any]])
            return try Dictionary(uniqueKeysWithValues: balls.map {
                (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
            })
        }
        func compare(_ expected: [String: [Double]]) throws {
            let actual = try board()
            XCTAssertEqual(Set(actual.keys), Set(expected.keys))
            for (key, position) in expected {
                let restored = try XCTUnwrap(actual[key])
                for axis in position.indices { XCTAssertEqual(restored[axis], position[axis], accuracy: 0.00001) }
            }
        }
        func snapshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = title + "-" + name; attachment.lifetime = .keepAlways; add(attachment)
        }
        open()
        let original = try board()
        app.buttons[palette].tap()
        let changed = NSPredicate { _, _ in (try? board().count) != original.count }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: nil)], timeout: 15), .completed)
        let expected = try board()
        let prefix = String(back.dropLast(".back".count))
        let moreID = prefix == "dailyClearance" ? "freeplay.moreMenu" : prefix + ".more"
        let cameraID = prefix == "dailyClearance" ? "freeplay.cameraMode" : prefix + ".cameraMode"
        XCUIDevice.shared.orientation = .landscapeLeft
        try compare(expected)
        app.buttons[moreID].tap()
        let mode = app.buttons[cameraID]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let enabled = NSPredicate { _, _ in mode.isEnabled }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: nil)], timeout: 30), .completed)
        mode.tap()
        app.buttons["关闭菜单"].tap()
        try compare(expected)
        snapshot("view-switched")
        XCUIDevice.shared.orientation = .portrait
        snapshot("saved")
        app.buttons[back].tap()
        XCTAssertTrue(app.textFields["librarySearchField"].waitForExistence(timeout: 15))
        open(); try compare(expected); snapshot("reentered")
        app.terminate(); app.launch()
        open(); try compare(expected); snapshot("relaunched")
    }
}
