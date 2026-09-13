import XCTest
final class RenderQualityV62UITests: XCTestCase {
    func testRoomStyleSettings() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings"])
        func openRoom() {
            let entry = app.buttons["settings.roomStyle"]
            XCTAssertTrue(entry.waitForExistence(timeout: 15))
            for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
            entry.tap()
        }
        openRoom()
        let walnut = app.buttons["settings.roomStyle.walnut"]
        XCTAssertTrue(walnut.waitForExistence(timeout: 15))
        if !walnut.isHittable { app.swipeUp() }
        walnut.tap(); XCTAssertEqual(walnut.value as? String, "已选择")
        app.terminate(); app.launch(); openRoom()
        XCTAssertTrue(walnut.waitForExistence(timeout: 15))
        XCTAssertEqual(walnut.value as? String, "已选择")
        let eastern = app.buttons["settings.roomStyle.eastern"]
        XCTAssertTrue(eastern.exists)
        if !eastern.isHittable { app.swipeUp() }
        eastern.tap(); XCTAssertEqual(eastern.value as? String, "已选择")
        app.terminate(); app.launch(); openRoom()
        XCTAssertTrue(eastern.waitForExistence(timeout: 15))
        XCTAssertEqual(eastern.value as? String, "已选择")
        let tournament = app.buttons["settings.roomStyle.tournament"]
        if !tournament.isHittable { app.swipeUp() }
        tournament.tap(); XCTAssertEqual(tournament.value as? String, "已选择")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "room-style-settings"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<6 where !app.buttons["浅色"].isHittable { app.swipeDown() }
        app.buttons["浅色"].tap()
        app.terminate(); app.launch(); openRoom()
        XCTAssertTrue(app.buttons["settings.roomStyle.tournament"].waitForExistence(timeout: 15))
        let light = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        light.name = "room-style-settings-light"; light.lifetime = .keepAlways; add(light)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<6 where !app.buttons["跟随系统"].isHittable { app.swipeDown() }
        app.buttons["跟随系统"].tap()
    }

    func testFrameRateSettings() throws {
        continueAfterFailure = false
        let args = ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings"]
        let app = XCUIApplication.launchClean(extraArgs: args)
        XCTAssertTrue(app.buttons["60 帧"].waitForExistence(timeout: 15))
        for rate in ["30 帧", "120 帧", "60 帧"] {
            app.buttons[rate].tap()
            XCTAssertTrue(app.buttons[rate].isSelected)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "frame-rate-settings"; shot.lifetime = .keepAlways; add(shot)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["60 帧"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["60 帧"].isSelected)
    }

    func testReferenceShotSimulationPlayback() throws {
        try captureReferencePlayback(title: "分离角与走位", identifier: "shotSimulation")
    }
    func testReferenceFreePlayPlayback() throws {
        try captureReferencePlayback(title: "自由击球", identifier: "freeplay")
    }
    private func captureReferencePlayback(title: String, identifier: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-v62.s267Lighting"])
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        let mode = app.buttons["\(identifier).cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        try capture("topdown")
        mode.tap()
        let entered3D = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "3D"), object: mode)
        XCTAssertEqual(XCTWaiter.wait(for: [entered3D], timeout: 3), .completed, "Camera must enter 3D after one tap")
        func capture(_ name: String) throws {
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            if let path = ProcessInfo.processInfo.environment["V62_SHOT_DIR"], path != "device" {
                let root = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
            }
        }
        let ready = NSPredicate(format: "enabled == true")
        let strike = app.buttons["击球"]
        expectation(for: ready, evaluatedWith: strike); waitForExpectations(timeout: 20)
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        let hasFPS = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "FPS"), object: table)
        XCTAssertEqual(XCTWaiter.wait(for: [hasFPS], timeout: 5), .completed)
        try capture("before-shot")
        strike.tap()
        let replay = app.buttons["回放"]
        expectation(for: ready, evaluatedWith: replay); waitForExpectations(timeout: 30)
        try capture("after-shot")
        replay.tap()
        expectation(for: ready, evaluatedWith: replay); waitForExpectations(timeout: 30)
        app.buttons["重打"].tap()
        XCTAssertTrue(app.buttons["\(identifier).focus"].isHittable)
        try capture("reset-shot")
    }

    func testOriginalAngleTrainingPage() throws { try capture(mobile:false) }
    func testCandidateAngleTrainingPage() throws { try capture(mobile:true) }
    func testReferenceAngleTrainingPage() throws { try capture(mobile:true,reference:true) }
    private func capture(mobile: Bool, reference: Bool = false) throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-v53.authenticatedProfileFixture","-forcePremium","-v62.fixture"] + (mobile ? [] : ["-v62.legacyRendering"]) + (reference ? ["-v62.s267Lighting"] : []))
        app.switchTab(.angle)
        let search=app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout:15));search.tap();search.typeText("3D 角度训练")
        let card=app.buttons["3D 角度训练"]
        XCTAssertTrue(card.waitForExistence(timeout:10));card.tap()
        let start=app.buttons["开始训练"]
        XCTAssertTrue(start.waitForExistence(timeout:20));start.tap()
        let table=app.descendants(matching:.any)["table.scene"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout:15))
        Thread.sleep(forTimeInterval:2)
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=mobile ? "v62-candidate" : "v62-baseline";a.lifetime = .keepAlways;add(a)
        let root: URL
        if let path = ProcessInfo.processInfo.environment["V62_SHOT_DIR"] {
            root = path == "device" ? FileManager.default.temporaryDirectory.appendingPathComponent("render-quality-v62") : URL(fileURLWithPath: path)
        } else {
            #if targetEnvironment(simulator)
            root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/render-quality-v62")
            #else
            root = FileManager.default.temporaryDirectory.appendingPathComponent("render-quality-v62")
            #endif
        }
        let dir = root.appendingPathComponent("candidate/ui")
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to:dir.appendingPathComponent(mobile ? "mobile.png" : "baseline.png"))
        let assist=app.buttons["辅助"]
        XCTAssertTrue(assist.exists);assist.tap()
        Thread.sleep(forTimeInterval:1)
        let assistShot = XCUIScreen.main.screenshot()
        let assistAttachment = XCTAttachment(screenshot: assistShot)
        assistAttachment.name = mobile ? "v62-candidate-assist" : "v62-baseline-assist"
        assistAttachment.lifetime = .keepAlways
        add(assistAttachment)
        try assistShot.pngRepresentation.write(to:dir.appendingPathComponent(mobile ? "mobile-assist.png" : "baseline-assist.png"))
        table.swipeLeft(); table.pinch(withScale:1.2,velocity:1)
        XCTAssertEqual(app.state,.runningForeground)
        XCTAssertTrue(table.exists)
        Thread.sleep(forTimeInterval: 1)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: dir.appendingPathComponent(mobile ? "mobile-gesture.png" : "baseline-gesture.png"))
        app.buttons["答题"].tap()
        XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 5))
        app.buttons["3"].tap(); app.buttons["0"].tap(); app.buttons["提交"].tap()
        XCTAssertTrue(app.buttons["下一题"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: dir.appendingPathComponent(mobile ? "mobile-answer.png" : "baseline-answer.png"))
        app.buttons["下一题"].tap()
        XCTAssertTrue(app.buttons["答题"].waitForExistence(timeout: 5))
        XCTAssertTrue(table.exists)
    }
}
