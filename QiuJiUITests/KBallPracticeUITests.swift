import XCTest

final class KBallPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)], timeout: timeout), .completed, element.debugDescription)
    }
    private func probe() throws -> [String: Any] {
        let value = try XCTUnwrap(node("kBall.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func phase(_ value: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["phase"] as? String) == value
        }, object: app)], timeout: 100), .completed)
    }
    private func waitForBaseline(_ visible: Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["referenceVisible"] as? Bool) == visible
        }, object: app)], timeout: 90), .completed)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func open(animated: Bool, lastFree: Bool = false) {
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", lastFree ? "-w7.forceDailyLimitNear" : "-forcePremium", "-kBall.probe", "-kBall.fixedSeed", "-showsTableSights.v1", "YES", "-tableStyle.v1", "charcoal", "-clothColor.v1", "green"])
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons["K球练习"]
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        ready(entry); entry.tap()
        ready(app.buttons["kBall.start"])
        let toggle = app.switches["kBall.playsStroke"]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        ready(toggle)
        let colorHints = app.switches["kBall.railColors"]
        if colorHints.value as? String == "0" {
            for _ in 0..<3 where !colorHints.isHittable { app.swipeDown() }
            ready(colorHints)
            colorHints.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
            for _ in 0..<3 where !toggle.isHittable { app.swipeUp() }
        }
        if (toggle.value as? String == "1") != animated {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
        }
        XCTAssertFalse(app.staticTexts["只统计每题首答；重打不改成绩。母球落袋和第二球碰后的位置不影响本题结果。"].exists)
        capture("kBall-settings")
        app.buttons["kBall.start"].tap()
        let entryNotice = node("kBall.question")
        XCTAssertTrue(entryNotice.waitForExistence(timeout: 15))
        XCTAssertTrue(entryNotice.label.contains("要求：两库"), entryNotice.label)
        XCTAssertFalse(entryNotice.label.contains("末库可选"), entryNotice.label)
        capture("kBall-entry-required-rail")
        phase("aiming")
        ready(app.buttons["kBall.strike"])
    }
    func testRailColorHintsCanBeDisabled() throws {
        open(animated: false)
        XCTAssertTrue(node("kBall.railSequence").exists)
        XCTAssertEqual(node("kBall.requirement").label, "要求：两库")
        XCTAssertTrue(app.frame.contains(node("kBall.railSequence").frame))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; ready(app.buttons["kBall.strike"])
            capture("kBall-colors-iPad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft; ready(app.buttons["kBall.strike"])
        }
        XCTAssertTrue(node("kBall.railSequence").label.contains("第1库，蓝色"))
        XCTAssertTrue(node("kBall.railSequence").label.contains("第2库，金色，可选"))
        XCTAssertFalse(node("kBall.railSequence").label.contains("出库后"))
        capture("kBall-colors-on")
        app.buttons["kBall.more"].tap(); ready(app.buttons["kBall.trainingSettings"])
        app.buttons["kBall.trainingSettings"].tap(); ready(app.buttons["kBall.start"])
        let toggle = app.switches["kBall.railColors"]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        ready(toggle)
        toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
        app.buttons["kBall.start"].tap(); phase("aiming")
        XCTAssertFalse(node("kBall.railSequence").exists)
        capture("kBall-colors-off-unchanged-felt")
    }
    func testBaselineRetryAndSimplifiedMenu() throws {
        open(animated: false)
        waitForBaseline(true)
        XCTAssertTrue(node("kBall.referenceLegend").exists)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        XCTAssertTrue(node("kBall.requirement").label.contains("要求：两库"))
        XCTAssertTrue(node("kBall.successRate").label.contains("成功率"))
        XCTAssertFalse(node("kBall.successRate").label.contains("首答"))
        XCTAssertFalse(node("kBall.referenceParameters").exists)
        let question = try probe()["question"] as? String
        capture("kBall-2D-before-answer")
        app.buttons["kBall.more"].tap()
        XCTAssertFalse(app.buttons["kBall.reference"].exists)
        XCTAssertFalse(app.buttons["kBall.replay"].exists)
        capture("kBall-simplified-menu")
        app.buttons["kBall.trainingSettings"].tap(); ready(app.buttons["training.settingsCancel"])
        app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, question)
        app.buttons["kBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        let successes = try probe()["successes"] as? Int
        capture("kBall-2D-result")
        ready(app.buttons["kBall.retry"]); app.buttons["kBall.retry"].tap(); phase("aiming")
        waitForBaseline(false)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
        capture("kBall-2D-retry-actual-only")
        app.buttons["kBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["successes"] as? Int, successes)
        waitForBaseline(false)
        capture("kBall-after-retry")
        app.buttons["kBall.strike"].tap(); phase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        waitForBaseline(true)
        XCTAssertTrue(node("kBall.referenceLegend").exists)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        capture("kBall-next-question-baseline")
    }
    func testLastFreeQuestionKeepsResultAndRetryBeforeSummary() throws {
        open(animated: false, lastFree: true)
        app.buttons["kBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        XCTAssertEqual(try probe()["primary"] as? String, "查看总结")
        XCTAssertFalse(node("kBall.summary").exists)
        app.buttons["kBall.retry"].tap(); phase("aiming")
        app.buttons["kBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        capture("kBall-last-free-result")
        app.buttons["kBall.strike"].tap(); phase("summary")
        XCTAssertTrue(node("kBall.summary").exists)
        capture("kBall-summary")
    }
    func testSharedViewAndAnimatedStroke() throws {
        open(animated: true)
        XCUIDevice.shared.orientation = .landscapeLeft
        ready(app.buttons["kBall.strike"])
        let question = try probe()["question"] as? String
        app.buttons["kBall.more"].tap(); ready(node("kBall.cameraMode")); node("kBall.cameraMode").tap()
        if node("kBall.dismissMenu").exists { node("kBall.dismissMenu").tap() }
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["view"] as? String, "3D")
        waitForBaseline(true)
        XCTAssertTrue(node("kBall.referenceLegend").exists)
        capture("kBall-3D-before-answer")
        ready(app.buttons["kBall.strike"]); app.buttons["kBall.strike"].tap(); phase("result")
        capture("kBall-3D-result")
        XCUIDevice.shared.press(.home); app.activate(); phase("result")
        XCTAssertEqual(try probe()["question"] as? String, question)
        ready(app.buttons["kBall.retry"]); app.buttons["kBall.retry"].tap(); phase("aiming")
        capture("kBall-3D-retry")
        waitForBaseline(false)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
    }
}
