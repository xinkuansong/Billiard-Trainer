import XCTest

final class TrainingMultiSelectionUITests: XCTestCase {
    func testAccuracyBothModesRestoreSavedResultAfterProcessRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        func open(_ title: String) {
            app.switchTab(.angle)
            app.buttons["angleHomeTab_练"].tap()
            let card = app.buttons[title]
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        }
        for title in ["2D准度", "3D准度"] {
            open(title)
            let start = app.buttons["accuracy.start"]
            if !start.waitForExistence(timeout: 3) {
                // End a previous test draft through the same confirmed restart flow.
                app.buttons["accuracy.more"].tap()
                app.buttons["accuracy.trainingSettings"].tap()
            }
            XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
            let strike = app.buttons["accuracy.strike"]
            XCTAssertTrue(strike.waitForExistence(timeout: 20))
            expectation(for: NSPredicate { _, _ in strike.isHittable && strike.isEnabled }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            let question = app.staticTexts["accuracy.question"].label
            strike.tap()
            let result = app.staticTexts["accuracy.result"]
            XCTAssertTrue(result.waitForExistence(timeout: 40))
            let savedResult = result.label
            app.terminate()
            app.launch()
            open(title)
            XCTAssertTrue(result.waitForExistence(timeout: 15))
            XCTAssertEqual(result.label, savedResult)
            XCTAssertEqual(app.staticTexts["accuracy.question"].label, question)
            strike.tap()
            XCTAssertTrue(app.staticTexts["accuracy.question"].label.contains("第2题"))
            app.buttons["accuracy.more"].tap()
            app.buttons["accuracy.finish"].tap()
            // ProAccessGate owns the root AX identifier; assert the visible summary.
            XCTAssertTrue(app.navigationBars[title + "总结"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[title + " · 模拟练习"].exists)
            let summary = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            summary.name = title + "-persisted-summary"; summary.lifetime = .keepAlways; add(summary)
            app.terminate(); app.launch()
        }
    }

    func testSixSceneSettingsKeepMultiSelectionPopoverOpen() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        for title in ["2D角度", "3D角度", "2D瞄准点", "3D瞄准点", "2D准度", "3D准度"] {
            app.switchTab(.angle)
            let category = app.buttons["angleHomeTab_练"]
            XCTAssertTrue(category.waitForExistence(timeout: 5)); category.tap()
            let card = app.buttons[title]
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
            let random = app.buttons["training.range.mixed"]
            XCTAssertTrue(random.waitForExistence(timeout: 5))
            XCTAssertTrue(random.label.contains("随机"))
            XCTAssertTrue(random.label.contains("85"))
            random.tap()
            let small = app.buttons["training.range.small"], thin = app.buttons["training.range.thin"]
            small.tap(); thin.tap()
            XCTAssertEqual(small.value as? String, "已选")
            XCTAssertEqual(thin.value as? String, "已选")
            XCTAssertEqual(random.value as? String, "未选")
            let cue = app.buttons["training.cueDistance"]
            if !cue.isHittable { app.swipeUp() }
            cue.tap()
            let short = app.buttons["training.cueDistance.short"]
            let long = app.buttons["training.cueDistance.long"]
            XCTAssertTrue(short.waitForExistence(timeout: 3)); short.tap(); long.tap()
            XCTAssertEqual(short.value as? String, "已选")
            XCTAssertEqual(long.value as? String, "已选")
            XCTAssertTrue(short.isHittable, "Selecting an option must leave the popup open")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "\(title)-multi-distance"; attachment.lifetime = .keepAlways; add(attachment)
            // A physical tap over Start must only dismiss the popup, never start a round.
            let startID = title.contains("准度") ? "accuracy.start" : (title.contains("瞄准点") ? "aimPointTraining.start" : "angleTraining.start")
            app.buttons[startID].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(short.waitForNonExistence(timeout: 3))
            XCTAssertTrue(app.buttons["training.settingsCancel"].exists)
            XCTAssertTrue(random.exists, "Outside dismissal must not activate Start underneath")
            cue.tap()
            XCTAssertTrue(short.waitForExistence(timeout: 3))
            XCTAssertEqual(short.value as? String, "已选"); XCTAssertEqual(long.value as? String, "已选")
            short.tap(); long.tap()
            XCTAssertEqual(long.value as? String, "已选", "The last concrete selection cannot be removed")
            let mixed = app.buttons["training.cueDistance.mixed"]
            mixed.tap()
            XCTAssertEqual(short.value as? String, "未选"); XCTAssertEqual(long.value as? String, "未选")
            mixed.tap()
            XCTAssertEqual(mixed.value as? String, "已选", "Random is also protected as the last selection")
            app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let rail = app.buttons["training.railDistance"]
            if !rail.isHittable { app.swipeUp() }
            rail.tap()
            let near = app.buttons["training.railDistance.near"], frozen = app.buttons["training.railDistance.frozen"]
            XCTAssertTrue(near.waitForExistence(timeout: 3)); near.tap(); frozen.tap()
            XCTAssertEqual(near.value as? String, "已选"); XCTAssertEqual(frozen.value as? String, "已选")
            app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["training.settingsCancel"].tap()
        }
        app.terminate()
    }
    func testAccuracyBothModesFreezeTipAndPreserveResultAcrossReturn() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        for title in ["2D准度", "3D准度"] {
            app.switchTab(.angle)
            app.buttons["angleHomeTab_练"].tap()
            let card = app.buttons[title]
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
            let start = app.buttons["accuracy.start"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            if !start.isHittable { app.swipeUp() }
            start.tap()
            let strike = app.buttons["accuracy.strike"]
            XCTAssertTrue(strike.waitForExistence(timeout: 20), app.debugDescription)
            let ready = NSPredicate { _, _ in strike.isHittable && strike.isEnabled }
            expectation(for: ready, evaluatedWith: app); waitForExpectations(timeout: 10)
            XCTAssertTrue(app.staticTexts["accuracy.question"].label.contains("中杆"))
            app.buttons["shotStage.spinEntry"].tap()
            let disc = app.otherElements["打点盘"]
            XCTAssertTrue(disc.waitForExistence(timeout: 5))
            let tipValue = disc.value as? String
            disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: disc.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.2)))
            XCTAssertEqual(disc.value as? String, tipValue, "The assigned tip cannot be edited")
            app.buttons["关闭打点"].coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.03)).tap()
            XCTAssertTrue(app.otherElements["accuracy.spinPad"].waitForNonExistence(timeout: 5))
            let aiming = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            aiming.name = title + "-aiming"; aiming.lifetime = .keepAlways; add(aiming)
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCUIDevice.shared.orientation = .landscapeLeft
                expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height && strike.isHittable }, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                XCTAssertTrue(app.staticTexts["accuracy.question"].label.contains("第1题"))
                let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                landscape.name = title + "-landscape"; landscape.lifetime = .keepAlways; add(landscape)
                XCUIDevice.shared.orientation = .portrait
                expectation(for: NSPredicate { _, _ in app.frame.height > app.frame.width && strike.isHittable }, evaluatedWith: app)
                waitForExpectations(timeout: 10)
            }
            app.buttons["accuracy.more"].tap()
            XCTAssertFalse(app.buttons["menu.aimCloseup"].exists)
            XCTAssertFalse(app.buttons["透明度"].exists)
            app.buttons["accuracy.dismissMenu"].tap()
            strike.tap()
            let result = app.staticTexts["accuracy.result"]
            XCTAssertTrue(result.waitForExistence(timeout: 40), app.debugDescription)
            let outcome = result.label
            let completed = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            completed.name = title + "-result"; completed.lifetime = .keepAlways; add(completed)
            app.buttons["accuracy.replay"].tap()
            XCTAssertTrue(result.waitForNonExistence(timeout: 5))
            XCTAssertTrue(result.waitForExistence(timeout: 40))
            XCTAssertEqual(result.label, outcome)
            app.buttons["accuracy.back"].tap()
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
            XCTAssertTrue(result.waitForExistence(timeout: 15))
            XCTAssertEqual(result.label, outcome)
            app.buttons["accuracy.strike"].tap()
            XCTAssertTrue(app.staticTexts["accuracy.question"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["accuracy.question"].label.contains("第2题"))
            app.buttons["accuracy.back"].tap()
        }
    }

    func testAccuracyFreeAllowanceAnd3DProGate() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium", "-w7.forceDailyLimit", "-v50.inMemoryStore"])
        defer { app.terminate() }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let pro = app.buttons["3D准度"]
        if !pro.isHittable { app.swipeUp() }
        XCTAssertTrue(pro.waitForExistence(timeout: 5)); pro.tap()
        XCTAssertTrue(app.buttons["subscription.close"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["accuracy.start"].exists)
        app.buttons["subscription.close"].tap()
        let free = app.buttons["2D准度"]
        if !free.isHittable { app.swipeUp() }
        free.tap()
        XCTAssertTrue(app.buttons["accuracy.start"].waitForExistence(timeout: 5))
        app.buttons["accuracy.start"].tap()
        let strike = app.buttons["accuracy.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 20))
        XCTAssertEqual(strike.label, "解锁Pro")
        strike.tap()
        XCTAssertTrue(app.buttons["subscription.close"].waitForExistence(timeout: 10))
    }

}
