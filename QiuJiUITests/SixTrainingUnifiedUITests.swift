import XCTest

final class SixTrainingUnifiedUITests: XCTestCase {
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
            XCTAssertEqual(app.staticTexts["dailyClearance.spinTransparencyPercent"].label, "0%")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "spinPad.disc").firstMatch.exists)
            for name in ["高杆增加 1%", "低杆增加 1%", "左塞增加 1%", "右塞增加 1%", "回中"] {
                let button = app.buttons[name]
                XCTAssertTrue(button.exists, name); XCTAssertFalse(button.isEnabled, name)
            }
            capture(title + "-locked-standard-pad")
            // Dismiss the menu and pad using their standard outside interception.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            ready(strike); strike.tap()
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
