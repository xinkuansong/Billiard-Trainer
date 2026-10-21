import XCTest

final class SixTrainingUnifiedUITests: XCTestCase {
    func testAccuracyStandardRetryAndRecordedPlayback() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
            app.buttons["accuracy.start"].tap()
            let strike = app.buttons["accuracy.strike"], retry = app.buttons["accuracy.retry"]
            let playback = app.buttons["accuracy.playback"]
            ready(strike)
            XCTAssertTrue(retry.exists); XCTAssertEqual(retry.label, "重打"); XCTAssertFalse(retry.isEnabled)
            XCTAssertTrue(playback.exists); XCTAssertEqual(playback.label, "回放"); XCTAssertFalse(playback.isEnabled)
            capture(title + "-standard-retry-replay-initial")
            strike.tap(); ready(playback, timeout: 60); ready(retry)
            let info = app.descendants(matching: .any).matching(identifier: "accuracy.questionInfo").firstMatch
            let metrics = info.label
            capture(title + "-standard-retry-replay-ready")
            playback.tap()
            XCTAssertEqual(strike.label, "停止回放")
            XCTAssertFalse(retry.isEnabled)
            capture(title + "-recorded-playback")
            ready(playback, timeout: 60) // Natural completion restores the result phase.
            XCTAssertEqual(info.label, metrics)
            retry.tap(); ready(strike)
            XCTAssertEqual(strike.label, "击球")
            XCTAssertEqual(info.label, metrics)
            ready(playback); playback.tap(); ready(strike); strike.tap()
            ready(playback)
            XCTAssertEqual(strike.label, "击球")
            XCTAssertEqual(info.label, metrics)
            capture(title + "-replay-stopped-retry-preserved")
            strike.tap(); ready(retry, timeout: 60)
            XCTAssertEqual(info.label, metrics)
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            ready(app.buttons["training.restart"])
            capture(title + "-replay-first-attempt-summary")
        }
    }

    func testStandardAngle2D() throws { try standardContract("2D角度") }
    func testStandardAngle3D() throws { try standardContract("3D角度") }
    func testStandardAimPoint2D() throws { try standardContract("2D瞄准点") }
    func testStandardAimPoint3D() throws { try standardContract("3D瞄准点") }
    func testStandardAccuracy2D() throws { try standardContract("2D准度") }
    func testStandardAccuracy3D() throws { try standardContract("3D准度") }

    private func standardContract(_ title: String) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-3dDrag.probe", "-dailyLayout.probe", "-freeLayout.ephemeral",
            "-v51.followSystemAppearance", "-appearanceMode", "system"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let accuracy = title.contains("准度"), aimPoint = title.contains("瞄准点")
        let prefix = accuracy ? "accuracy" : aimPoint ? "aimPointTraining" : "angleTraining"
        let primaryID = accuracy ? "accuracy.strike" : aimPoint ? "aimPointTraining.submit" : "答题"
        func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func probe() throws -> [String: Any] {
            let data = try XCTUnwrap((node(accuracy ? "table.scene" : prefix + ".scene").value as? String)?.data(using: .utf8))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func balls() throws -> [String: [Double]] {
            let list = try XCTUnwrap(try probe()["balls"] as? [[String: Any]])
            return try Dictionary(uniqueKeysWithValues: list.map {
                (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
            })
        }
        func menu() {
            let button = app.buttons[prefix + (accuracy ? ".more" : ".settings")]
            ready(button); button.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["menu.tableGrid"])
        }
        func cancelLayout() {
            let cancel = app.buttons["freeLayout.cancel"]
            ready(cancel); cancel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(node("freeLayout.editor").waitForNonExistence(timeout: 5))
        }
        func chooseMenu(_ id: String) {
            let button = app.buttons[id]
            for _ in 0..<5 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(button); button.tap()
        }
        func assertVisible(_ element: XCUIElement) {
            ready(element)
            XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(element.frame), element.debugDescription)
        }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons[title]
        for _ in 0..<4 where !card.isHittable { app.swipeUp() }
        ready(card); card.tap()
        ready(app.buttons[prefix + ".start"]); app.buttons[prefix + ".start"].tap()
        let primary = app.buttons[primaryID]
        // The isolated store starts with the actual automatic layout. Saving the
        // default as a template would instead freeze positions for window tests.
        assertVisible(primary)
        let originalBalls = try balls()
        XCTAssertEqual(originalBalls.count, 2)
        capture(title + "-standard-initial")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait]) { issue in
            let detail = XCTAttachment(string: "Issue element: \(issue.element?.debugDescription ?? "nil")\n\(app.debugDescription)")
            detail.name = title + "-accessibility-issue"; detail.lifetime = .keepAlways; self.add(detail)
            return false
        }

        // The system really backgrounds/foregrounds the app; no simulated phase flag.
        XCUIDevice.shared.press(.home); app.activate(); assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)
        if accuracy {
            XCTAssertEqual(try probe()["accuracyAimVisible"] as? Bool, true)
            XCTAssertEqual(try probe()["cueVisible"] as? Bool, true)
        }
        capture(title + "-background-return")

        if title.hasPrefix("3D") {
            let top = app.buttons["shotCamera.temporaryTopDown"]
            ready(top); top.tap()
            expectation(for: NSPredicate { _, _ in (try? probe()["standardTemporaryTable"] as? Bool) == true }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            capture(title + "-temporary-top-down")
            if accuracy { XCTAssertFalse(primary.isEnabled) }
            top.tap(); assertVisible(primary)
            XCTAssertEqual(try balls(), originalBalls)
            top.tap()
            expectation(for: NSPredicate { _, _ in (try? probe()["standardTemporaryTable"] as? Bool) == true }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            XCUIDevice.shared.press(.home); app.activate(); assertVisible(primary)
            XCTAssertEqual(try probe()["standardTemporaryTable"] as? Bool, false)
            XCTAssertEqual(try balls(), originalBalls)
            capture(title + "-temporary-background-return")
        }

        // Menu interception: tapping the primary's physical location closes only the menu.
        let primaryCenter = primary.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        menu(); ready(app.buttons["menu.tableGrid"])
        let grid = app.buttons["menu.tableGrid"], gridValue = app.buttons["menu.tableGrid"].value as? String
        grid.tap(); ready(grid)
        XCTAssertNotEqual(grid.value as? String, gridValue)
        grid.tap(); XCTAssertEqual(grid.value as? String, gridValue)
        capture(title + "-menu")
        let panel = node("dailyClearance.menuPanel")
        let center = CGPoint(x: primary.frame.midX, y: primary.frame.midY)
        if panel.frame.contains(center) {
            // At accessibility text sizes the menu covers the underlying action.
            // Tapping there would legitimately select a menu row, so use its outside mask.
            app.coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        } else { primaryCenter.tap() }
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)
        XCTAssertFalse(app.buttons["training.restart"].exists)

        // Move and resize a real control, cancel, and confirm the original geometry/state.
        menu(); chooseMenu("controlLayout.open")
        let key = accuracy ? "shot.aim" : aimPoint ? "aimPoint.hint" : "angle.assist"
        let edit = app.buttons["freeLayout.select." + key]
        ready(edit); let original = edit.frame
        edit.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        ready(app.buttons["freeLayout.larger"]); app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(edit.frame.width, original.width)
        app.buttons["freeLayout.collapse"].tap()
        let start = edit.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 24, dy: -12)))
        XCTAssertGreaterThan(edit.frame.midX, original.midX + 10)
        XCTAssertEqual(try balls(), originalBalls)
        capture(title + "-layout-moved")
        cancelLayout()
        assertVisible(primary)
        menu(); chooseMenu("controlLayout.open"); ready(edit)
        XCTAssertEqual(edit.frame.width, original.width, accuracy: 1)
        XCTAssertEqual(edit.frame.midX, original.midX, accuracy: 1)
        cancelLayout(); assertVisible(primary)
        XCTAssertEqual(try balls(), originalBalls)

        // iPad rotations must keep the question and the actual action inside the window.
        if min(app.frame.width, app.frame.height) >= 600 {
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                expectation(for: NSPredicate { _, _ in
                    let f = app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height > f.width : f.width > f.height
                }, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
                capture(title + "-rotation-" + String(orientation.rawValue))
            }
            let window = app.windows.firstMatch, full = app.windows.firstMatch.frame
            let renderer = try probe()["rendererID"] as? String
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width - 7, dy: full.height - 7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width * 0.7, dy: full.height * 0.78)))
            expectation(for: NSPredicate { _, _ in window.frame.width < full.width - 80 }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
            let viewport = try XCTUnwrap(try probe()["displayedViewport"] as? [Double])
            XCTAssertLessThanOrEqual(viewport[2], window.frame.width + 1)
            capture(title + "-system-window-small")
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - full.width) > 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            expectation(for: NSPredicate { _, _ in abs(window.frame.width - full.width) < 1 }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
            XCTAssertEqual(try probe()["rendererID"] as? String, renderer)
            capture(title + "-system-window-restored")
        }

        menu(); chooseMenu(prefix + ".trainingSettings")
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
        assertVisible(primary); XCTAssertEqual(try balls(), originalBalls)
        menu(); chooseMenu(prefix + ".finish")
        ready(app.buttons["training.restart"])
        XCTAssertTrue(app.staticTexts["题数"].exists)
        app.buttons["training.restart"].tap()
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
        ready(app.buttons["training.complete"])
        capture(title + "-cancel-restart-summary")
        app.buttons["training.complete"].tap(); ready(app.buttons["angleHomeTab_练"])
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testSixPagesVisualBaseline() {
        continueAfterFailure = false
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点", "2D准度", "3D准度"] {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
            app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
            let card = app.buttons[title]
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 8)); card.tap()
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            XCTAssertTrue(app.buttons[prefix + ".start"].waitForExistence(timeout: 10))
            capture(title + "-settings")
            app.buttons[prefix + ".start"].tap()
            let action = app.buttons[title.contains("准度") ? "accuracy.strike" : title.contains("瞄准点") ? "aimPointTraining.submit" : "答题"]
            XCTAssertTrue(action.waitForExistence(timeout: 40))
            expectation(for: NSPredicate { _, _ in action.isHittable && action.isEnabled }, evaluatedWith: app)
            waitForExpectations(timeout: 15)
            capture(title + "-table")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }
    private func fillTemplateName(_ field: XCUIElement, app: XCUIApplication, value: String) {
        ready(field); field.tap()
        // A fresh iOS 17 keyboard can cover the field with its QuickPath introduction.
        let keyboardIntro = app.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "继续"])).firstMatch
        if keyboardIntro.exists && keyboardIntro.isHittable { keyboardIntro.tap(); field.tap() }
        if let current = field.value as? String, current != "模板名称", !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 40) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)],
            timeout: timeout), .completed, element.debugDescription)
    }
    private func open(_ title: String, free: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: [free ? "-w7.forceDailyLimitNear" : "-forcePremium", "-v50.inMemoryStore"])
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons[title]
        if !card.isHittable { app.swipeUp() }
        ready(card); card.tap()
        return app
    }
    func testFreeModesPaywallCancelAndCompletion() {
        continueAfterFailure = false
        for title in ["2D角度", "2D瞄准点", "2D准度"] {
            let app = open(title, free: true)
            let prefix = title.contains("准度") ? "accuracy" : title.contains("瞄准点") ? "aimPointTraining" : "angleTraining"
            let free = app.segmentedControls["training.length"].buttons["自由练习"]
            ready(free); free.tap()
            ready(app.buttons["subscription.close"]); capture(title + "-free-mode-paywall")
            app.buttons["subscription.close"].tap()
            XCTAssertTrue(app.segmentedControls["training.length"].buttons["20题"].isSelected)
            app.buttons[prefix + ".start"].tap()
            if title.contains("准度") {
                let strike = app.buttons["accuracy.strike"]; ready(strike); strike.tap()
            } else if title.contains("瞄准点") {
                ready(app.buttons["aimPointTraining.submit"]); app.buttons["aimPointTraining.submit"].tap()
            } else {
                ready(app.buttons["答题"]); app.buttons["答题"].tap()
                ready(app.buttons["0"].firstMatch); app.buttons["0"].firstMatch.tap(); app.buttons["提交"].tap()
            }
            ready(app.buttons["training.restart"], timeout: 60)
            XCTAssertTrue(app.staticTexts["题数"].exists)
            capture(title + "-quota-finish")
            app.buttons["training.restart"].tap()
            ready(app.buttons["subscription.close"]); app.buttons["subscription.close"].tap()
            ready(app.buttons["training.complete"]); app.buttons["training.complete"].tap()
            ready(app.buttons["angleHomeTab_练"])
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }
    func testAccuracyRetryAndLockedStandardPadInBothModes() {
        continueAfterFailure = false
        for title in ["2D准度", "3D准度"] {
            let app = open(title)
            app.buttons["accuracy.start"].tap()
            let strike = app.buttons["accuracy.strike"]
            ready(strike)
            let question = app.staticTexts["accuracy.question"].label
            app.buttons["accuracy.more"].tap()
            ready(app.buttons["accuracy.transparency"]); app.buttons["accuracy.transparency"].tap()
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            ready(slider); slider.adjust(toNormalizedSliderPosition: 0)
            // XCTest's normalized drag can stop 1% above the physical endpoint on iPad.
            // Exact zero persistence is separately covered by SixTrainingUnifiedTests.
            let percent = Int(app.staticTexts["dailyClearance.spinTransparencyPercent"].label.replacingOccurrences(of: "%", with: ""))
            XCTAssertNotNil(percent); XCTAssertTrue((0...1).contains(percent ?? -1))
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "spinPad.disc").firstMatch.exists)
            for name in ["高杆增加 1%", "低杆增加 1%", "左塞增加 1%", "右塞增加 1%", "回中"] {
                let button = app.buttons[name]
                XCTAssertTrue(button.exists, name); XCTAssertFalse(button.isEnabled, name)
            }
            capture(title + "-locked-standard-pad")
            // Dismiss the menu and pad using their standard outside interception.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            ready(strike)
            // Persist a moved real primary button, then fire from its new hit region.
            app.buttons["accuracy.more"].tap()
            let layout = app.buttons["controlLayout.open"]
            for _ in 0..<5 where !layout.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(layout); layout.tap()
            let control = app.buttons["freeLayout.select.shot.strike"]
            ready(control)
            control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            app.buttons["freeLayout.larger"].tap()
            app.buttons["freeLayout.collapse"].tap()
            let from = control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -30, dy: -10)))
            let saved = control.frame
            app.buttons["freeLayout.collapse"].tap()
            ready(app.buttons["freeLayout.save"]); app.buttons["freeLayout.save"].tap()
            let name = app.alerts.textFields.firstMatch
            fillTemplateName(name, app: app, value: "Accuracy hit region")
            app.alerts.buttons["保存"].tap()
            ready(strike)
            XCTAssertEqual(strike.frame.midX, saved.midX, accuracy: 1)
            XCTAssertEqual(strike.frame.width, saved.width, accuracy: 1)
            capture(title + "-saved-primary-layout")
            strike.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["accuracy.retry"], timeout: 60)
            let info = app.descendants(matching: .any).matching(identifier: "accuracy.questionInfo").firstMatch
            let firstMetrics = info.label
            XCTAssertTrue(firstMetrics.contains("1/20"))
            XCTAssertTrue(firstMetrics.contains("进球率"))
            XCTAssertTrue(firstMetrics.contains("%"))
            app.buttons["accuracy.retry"].tap()
            ready(strike)
            XCTAssertEqual(app.staticTexts["accuracy.question"].label, question)
            XCTAssertEqual(info.label, firstMetrics)
            capture(title + "-retry-aiming")
            strike.tap(); ready(app.buttons["accuracy.retry"], timeout: 60)
            XCTAssertEqual(info.label, firstMetrics)
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            ready(app.buttons["training.restart"])
            XCTAssertTrue(app.staticTexts["题数"].exists)
            XCTAssertTrue(app.staticTexts["进球数量"].exists)
            capture(title + "-first-attempt-summary")
            app.buttons["training.restart"].tap()
            ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap()
            ready(app.buttons["training.restart"])
            XCTAssertTrue(app.staticTexts["进球数量"].exists)
            capture(title + "-scored-summary-cancel-restart")
            app.buttons["training.restart"].tap()
            ready(app.buttons["accuracy.start"]); app.buttons["accuracy.start"].tap()
            ready(strike)
            XCTAssertTrue(info.label.contains("1/20"))
            app.buttons["accuracy.more"].tap(); app.buttons["accuracy.finish"].tap()
            app.buttons["training.complete"].tap()
            ready(app.buttons["angleHomeTab_练"])
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testThree3DRoutesRequirePro() {
        continueAfterFailure = false
        for title in ["3D角度", "3D瞄准点", "3D准度"] {
            let app = open(title, free: true)
            ready(app.buttons["subscription.close"])
            app.buttons["subscription.close"].tap()
            ready(app.buttons["angleHomeTab_练"])
            app.terminate()
        }
    }
    func testUpgradeReturnsToCompletedRoundAndAllowsRestart() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimitNear", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        app.buttons["2D瞄准点"].tap()
        ready(app.buttons["aimPointTraining.start"]); app.buttons["aimPointTraining.start"].tap()
        ready(app.buttons["aimPointTraining.submit"]); app.buttons["aimPointTraining.submit"].tap()
        ready(app.buttons["training.restart"]); app.buttons["training.restart"].tap()
        ready(app.buttons["subscription.close"])
        let unlock = app.buttons["simulatorUnlockProButton"]
        let scroll = app.scrollViews["subscription.scroll"]
        for _ in 0..<18 where !unlock.isHittable {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.60))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.10)))
        }
        ready(unlock); unlock.tap()
        ready(app.buttons["training.restart"]); app.buttons["training.restart"].tap()
        ready(app.buttons["aimPointTraining.start"]); app.buttons["aimPointTraining.start"].tap()
        ready(app.buttons["aimPointTraining.submit"])
        capture("upgrade-restarted-round")
        app.buttons["aimPointTraining.settings"].tap(); app.buttons["aimPointTraining.finish"].tap()
        ready(app.buttons["training.complete"]); app.buttons["training.complete"].tap()
        ready(app.buttons["angleHomeTab_练"])
    }

}
