import XCTest

final class BankPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: 90), .completed, e.debugDescription)
    }
    private func selectMenu(_ id: String) {
        let item = node(id)
        for _ in 0..<6 where !item.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(item); item.tap()
    }
    private func probe() throws -> [String: Any] {
        let value = try XCTUnwrap(node("bank.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func phase(_ phase: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["phase"] as? String) == phase
        }, object: app)], timeout: 100), .completed)
    }
    private func assertSimpleMenu() {
        XCTAssertTrue(node("bank.trainingSettings").waitForExistence(timeout: 3))
        XCTAssertFalse(node("bank.requirement").exists)
        XCTAssertFalse(node("bank.playback").exists)
        XCTAssertFalse(node("bank.next").exists)
        XCTAssertFalse(node("bank.resultDetails").exists)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func waitForBaseline(_ visible: Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["referenceVisible"] as? Bool) == visible
        }, object: app)], timeout: 30), .completed)
    }
    private func open(animated: Bool, lastFree: Bool = false, rails: Int = 3, seed: UInt64 = 31) {
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", lastFree ? "-w7.forceDailyLimitNear" : "-forcePremium", "-bank.probe", "-bank.fixedSeed=\(seed)", "-showsTableSights.v1", "YES", "-tableStyle.v1", "charcoal", "-clothColor.v1", "green"])
        app.switchTab(.angle); app.buttons["angleHomeTab_进阶"].tap()
        let entry = app.buttons["翻袋练习"]
        for _ in 0..<5 where !entry.isHittable { app.swipeUp() }
        ready(entry); entry.tap(); ready(app.buttons["bank.start"])
        capture("bank-settings-top")
        let railChoice = node("bank.railCount.\(rails)")
        for _ in 0..<5 where !railChoice.isHittable { app.swipeUp() }
        ready(railChoice); railChoice.tap()
        XCTAssertFalse(node("bank.railCount.4").exists)
        capture("bank-settings-\(rails)-rails")
        let toggle = app.switches["bank.playsStroke"]
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        ready(toggle)
        let colorHints = app.switches["bank.railColors"]
        if colorHints.value as? String == "0" {
            for _ in 0..<3 where !colorHints.isHittable { app.swipeDown() }
            ready(colorHints)
            colorHints.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
            for _ in 0..<3 where !toggle.isHittable { app.swipeUp() }
        }
        if (toggle.value as? String == "1") != animated {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
        }
        capture("bank-settings")
        app.buttons["bank.start"].tap(); phase("aiming"); ready(app.buttons["bank.strike"])
        // Saved project view is an intentional preference; launchClean does not erase it.
        if (try? probe()["view"] as? String) == "3D" {
            app.buttons["bank.more"].tap(); ready(node("bank.cameraMode")); node("bank.cameraMode").tap()
            if node("bank.dismissMenu").exists { node("bank.dismissMenu").tap() }
        }
        XCTAssertEqual(try? probe()["view"] as? String, "2D")

    }
    func testReferenceDemonstrationInMeasurementSlot() throws {
        open(animated: false, rails: 2)
        try verifyPracticeDemonstration(in: app, page: "bank", phase: { phase($0) }, probe: probe)
    }

    func testRejectedDemonstrationRestoresPlayerAndAllowsNext() throws {
        // Stable three-rail case with a confirmed mid-route jaw collision.
        open(animated: false, rails: 3, seed: 150)
        let demo = app.buttons["bank.referenceReplay"]
        for _ in 0..<3 {
            app.buttons["bank.strike"].tap(); phase("result")
            if demo.exists { break }
            app.buttons["bank.retry"].tap(); phase("aiming")
        }
        let before = try probe()
        demo.tap()
        let alert = app.alerts["练习提示"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "碰到袋角")).firstMatch.exists)
        alert.buttons["知道了"].tap(); phase("result")
        XCTAssertEqual(try probe()["demoShowing"] as? Bool, false)
        XCTAssertEqual(try probe()["instrument"] as? [Double], before["playerInput"] as? [Double])
        XCTAssertEqual(try probe()["attempts"] as? Int, before["attempts"] as? Int)
        app.buttons["bank.strike"].tap(); phase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, before["question"] as? String)
    }

    func testFirstAttemptRetrySimpleResultAndNextQuestion() throws {
        open(animated: false)
        let original = try probe(), id = original["question"] as? String
        XCTAssertEqual(original["direction"] as? [Double], original["initialDirection"] as? [Double])
        waitForBaseline(false)
        let sequence = node("bank.railSequence")
        XCTAssertTrue(sequence.label.contains("目标球"), sequence.label)
        XCTAssertTrue(sequence.label.contains("第3库"), sequence.label)
        XCTAssertFalse(sequence.label.contains("可选"))
        XCTAssertTrue(app.frame.contains(sequence.frame))
        capture("bank-2D-initial-three-rails")
        app.buttons["bank.more"].tap(); assertSimpleMenu()
        capture("bank-simple-menu-aiming")
        node("bank.dismissMenu").tap()
        app.buttons["bank.strike"].tap(); phase("result")
        capture("bank-simple-result")
        XCTAssertFalse(node("scoreDetails.panel").exists)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["referenceVisible"] as? Bool, false)
        XCTAssertEqual(try probe()["objectActualVisible"] as? Bool, true)
        let successes = try probe()["successes"] as? Int
        capture("bank-2D-result")
        app.buttons["bank.more"].tap()
        XCTAssertFalse(node("bank.resultDetails").exists)
        ready(node("bank.dismissMenu")); node("bank.dismissMenu").tap()
        ready(app.buttons["bank.retry"])
        app.buttons["bank.retry"].tap(); phase("aiming")
        waitForBaseline(false)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        XCTAssertEqual(try probe()["objectActualVisible"] as? Bool, true)
        capture("bank-target-route-retry")
        app.buttons["bank.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["successes"] as? Int, successes)
        app.buttons["bank.strike"].tap(); phase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, id)
        waitForBaseline(false)
        XCTAssertEqual(try probe()["objectActualVisible"] as? Bool, false)
        capture("bank-next-question")
    }
    func testAimCloseupMenuHeldGestureAndViewSwitch() throws {
        open(animated: false)
        for view in ["2D", "3D"] {
            if view == "3D" {
                app.buttons["bank.more"].tap(); selectMenu("bank.cameraMode")
                if node("bank.dismissMenu").exists { node("bank.dismissMenu").tap() }
            }
            app.buttons["bank.more"].tap()
            let toggle = node("menu.aimCloseup"); ready(toggle)
            if toggle.value as? String != "已选" { toggle.tap() }
            XCTAssertEqual(toggle.value as? String, "已选")
            node("bank.dismissMenu").tap()
            let orientations: [UIDeviceOrientation] = UIDevice.current.userInterfaceIdiom == .pad
                ? [.portrait, .landscapeLeft] : [.landscapeLeft]
            for orientation in orientations {
                XCUIDevice.shared.orientation = orientation
                let ruler = node("bank.aimWheel"); ready(ruler)
                XCTAssertFalse(node("aimCloseup.hud").exists)
                let start = ruler.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
                let travel = ruler.frame.width > ruler.frame.height
                    ? CGVector(dx: -12, dy: 0) : CGVector(dx: 0, dy: -12)
                print("BANK_CLOSEUP_CAPTURE \(view)-\(orientation.rawValue)")
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(travel),
                    withVelocity: XCUIGestureVelocity(rawValue: 100), thenHoldForDuration: 12)
                XCTAssertTrue(node("aimCloseup.hud").waitForNonExistence(timeout: 3))
                capture("bank-closeup-released-" + view + "-" + String(orientation.rawValue))
            }
            app.buttons["bank.more"].tap(); ready(toggle); toggle.tap()
            XCTAssertEqual(toggle.value as? String, "未选")
            node("bank.dismissMenu").tap()
        }
        app.buttons["bank.strike"].tap(); phase("result")
        XCTAssertFalse(node("aimCloseup.hud").exists)
        app.buttons["bank.retry"].tap(); phase("aiming")
        XCTAssertFalse(node("aimCloseup.hud").exists)
    }

    func testRoutesShownDuringAnimatedStrokeIn2DAnd3D() throws {
        open(animated: true)
        for view in ["2D", "3D"] {
            if view == "3D" {
                app.buttons["bank.retry"].tap(); phase("aiming")
                app.buttons["bank.more"].tap(); selectMenu("bank.cameraMode")
                if node("bank.dismissMenu").exists { node("bank.dismissMenu").tap() }
            }
            XCTAssertEqual(try probe()["view"] as? String, view)
            ready(app.buttons["bank.strike"]); app.buttons["bank.strike"].tap(); phase("playing")
            let playing = try probe()
            XCTAssertEqual(playing["actualVisible"] as? Bool, true)
            XCTAssertEqual(playing["objectActualVisible"] as? Bool, true)
            XCTAssertEqual(playing["referenceVisible"] as? Bool, false)
            capture("bank-" + view + "-stroke-routes")
            phase("result")
            XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        }
    }

    func testViewSwitchMeasurementSettingsCancelAndSimpleMenu() throws {
        open(animated: true)
        let id = try probe()["question"] as? String
        waitForBaseline(false)
        app.buttons["bank.geometry"].tap(); ready(node("bank.geometry.2")); node("bank.geometry.2").tap()
        XCTAssertEqual((try probe()["geometry"] as? [String: Any])?["count"] as? Int, 2)
        waitForBaseline(false)
        capture("bank-target-measurement")
        app.buttons["bank.more"].tap(); selectMenu("bank.trainingSettings")
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, id)
        XCTAssertEqual((try probe()["geometry"] as? [String: Any])?["count"] as? Int, 2)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; ready(app.buttons["bank.strike"])
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.frame.width < self.app.frame.height
            }, object: app)], timeout: 10), .completed)
            capture("bank-iPad-portrait-2D")
        }
        XCUIDevice.shared.orientation = .landscapeLeft; ready(app.buttons["bank.strike"])
        capture("bank-landscape-2D")
        app.buttons["bank.more"].tap(); ready(node("bank.cameraMode")); node("bank.cameraMode").tap()
        if node("bank.dismissMenu").exists { node("bank.dismissMenu").tap() }
        XCTAssertEqual(try probe()["view"] as? String, "3D")
        XCTAssertEqual(try probe()["question"] as? String, id)
        app.buttons["bank.geometry"].tap(); ready(node("bank.geometry.0")); node("bank.geometry.0").tap()
        waitForBaseline(false)
        capture("bank-3D-aiming")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; ready(app.buttons["bank.strike"])
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.frame.width < self.app.frame.height
            }, object: app)], timeout: 10), .completed)
            capture("bank-iPad-portrait-3D")
        }
        ready(app.buttons["bank.strike"]); app.buttons["bank.strike"].tap(); phase("result")
        capture("bank-3D-result")
        XCUIDevice.shared.press(.home); app.activate(); phase("result")
        XCTAssertEqual(try probe()["question"] as? String, id)
        app.buttons["bank.more"].tap(); assertSimpleMenu()
        capture("bank-simple-menu-result")
        node("bank.dismissMenu").tap()
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
    }
    func testColorDraftCancelAndCommitKeepsMenuSimple() throws {
        open(animated: false)
        let original = try probe()["question"] as? String
        func settings() {
            app.buttons["bank.more"].tap(); selectMenu("bank.trainingSettings")
            ready(app.buttons["bank.start"])
        }
        func disableColors() {
            let toggle = app.switches["bank.railColors"]
            for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
            ready(toggle)
            if toggle.value as? String == "1" {
                toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
            }
        }
        settings(); disableColors(); app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, original)
        XCTAssertTrue(node("bank.railSequence").exists)
        settings(); disableColors(); app.buttons["bank.start"].tap(); phase("aiming")
        XCTAssertFalse(node("bank.railSequence").exists)
        app.buttons["bank.more"].tap(); assertSimpleMenu()
        capture("bank-colors-off-simple-menu")
    }
    func testLastFreeQuestionRetryAndSummary() throws {
        open(animated: false, lastFree: true)
        app.buttons["bank.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        XCTAssertEqual(try probe()["primary"] as? String, "查看总结")
        XCTAssertFalse(node("bank.summary").exists)
        app.buttons["bank.retry"].tap(); phase("aiming")
        app.buttons["bank.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        capture("bank-last-free-result")
        app.buttons["bank.strike"].tap(); phase("summary")
        XCTAssertTrue(node("bank.summary").exists); capture("bank-summary")
    }
}

final class BankSolverTrajectoryUITests: XCTestCase {
    func testStrikeAndReplayTrajectoriesIn2DAnd3D() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral"])
        defer { app.terminate() }
        func ready(_ item: XCUIElement) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: item)], timeout: 90), .completed)
        }
        func capture(_ name: String) {
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = name; image.lifetime = .keepAlways; add(image)
        }
        app.switchTab(.angle)
        ready(app.buttons["angleHomeTab_进阶"]); app.buttons["angleHomeTab_进阶"].tap()
        ready(app.buttons["翻袋解球"]); app.buttons["翻袋解球"].tap()
        let strike = app.buttons["bankshot.strike"]
        for mode in ["2D", "3D"] {
            ready(strike)
            app.buttons["bankshot.more"].tap()
            let camera = app.buttons["bankshot.cameraMode"]; ready(camera)
            if camera.value as? String != mode { camera.tap() }
            app.buttons["bankshot.dismissMenu"].tap()
            ready(strike); capture("bank-trajectory-\(mode)-ready")
            strike.tap()
            for i in 1...3 { Thread.sleep(forTimeInterval: 1); capture("bank-trajectory-\(mode)-strike-\(i)") }
            ready(app.buttons["solver.replay"])
            app.buttons["solver.replay"].tap()
            Thread.sleep(forTimeInterval: 2); capture("bank-trajectory-\(mode)-replay")
            ready(app.buttons["solver.undo"])
            app.buttons["solver.undo"].tap()
            ready(strike); capture("bank-trajectory-\(mode)-undo")
        }
    }
}
