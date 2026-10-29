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
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", lastFree ? "-w7.forceDailyLimitNear" : "-forcePremium", "-kBall.probe", "-kBall.fixedSeed"])
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons["K球练习"]
        for _ in 0..<4 where !entry.isHittable { app.swipeUp() }
        ready(entry); entry.tap()
        ready(app.buttons["kBall.start"])
        let toggle = app.switches["kBall.playsStroke"]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        ready(toggle)
        if (toggle.value as? String == "1") != animated {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
        }
        XCTAssertFalse(app.staticTexts["只统计每题首答；重打不改成绩。母球落袋和第二球碰后的位置不影响本题结果。"].exists)
        capture("kBall-settings")
        app.buttons["kBall.start"].tap()
        let entryNotice = node("kBall.question")
        XCTAssertTrue(entryNotice.waitForExistence(timeout: 15))
        XCTAssertTrue(entryNotice.label.contains("要求：两库"), entryNotice.label)
        capture("kBall-entry-required-rail")
        phase("aiming")
        ready(app.buttons["kBall.strike"])
    }
    func testNeutralBaselineRetryAndSimplifiedMenu() throws {
        open(animated: false)
        waitForBaseline(true)
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
        app.buttons["kBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["successes"] as? Int, successes)
        waitForBaseline(false)
        capture("kBall-after-retry")
        app.buttons["kBall.strike"].tap(); phase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        waitForBaseline(true)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
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
        capture("kBall-3D-before-answer")
        ready(app.buttons["kBall.strike"]); app.buttons["kBall.strike"].tap(); phase("result")
        capture("kBall-3D-result")
        XCUIDevice.shared.press(.home); app.activate(); phase("result")
        XCTAssertEqual(try probe()["question"] as? String, question)
        ready(app.buttons["kBall.retry"]); app.buttons["kBall.retry"].tap(); phase("aiming")
        capture("kBall-3D-retry")
    }
}
