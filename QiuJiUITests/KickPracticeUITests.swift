import XCTest

final class KickPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: 90), .completed, e.debugDescription)
    }
    private func probe() throws -> [String: Any] {
        let value = try XCTUnwrap(node("kick.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func phase(_ phase: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["phase"] as? String) == phase
        }, object: app)], timeout: 100), .completed)
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
    private func open(animated: Bool, lastFree: Bool = false) {
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", lastFree ? "-w7.forceDailyLimitNear" : "-forcePremium", "-kick.probe", "-kick.fixedSeed", "-showsTableSights.v1", "YES", "-tableStyle.v1", "charcoal", "-clothColor.v1", "green"])
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons["解球练习"]
        for _ in 0..<5 where !entry.isHittable { app.swipeUp() }
        ready(entry); entry.tap(); ready(app.buttons["kick.start"])
        let toggle = app.switches["kick.playsStroke"]
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        ready(toggle)
        let colorHints = app.switches["kick.railColors"]
        if colorHints.value as? String == "0" {
            for _ in 0..<3 where !colorHints.isHittable { app.swipeDown() }
            ready(colorHints)
            colorHints.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
            for _ in 0..<3 where !toggle.isHittable { app.swipeUp() }
        }
        if (toggle.value as? String == "1") != animated {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
        }
        capture("kick-settings")
        app.buttons["kick.start"].tap(); phase("aiming"); ready(app.buttons["kick.strike"])
        // Saved project view is an intentional preference; launchClean does not erase it.
        if (try? probe()["view"] as? String) == "3D" {
            app.buttons["kick.more"].tap(); ready(node("kick.cameraMode")); node("kick.cameraMode").tap()
            if node("kick.dismissMenu").exists { node("kick.dismissMenu").tap() }
        }
        XCTAssertEqual(try? probe()["view"] as? String, "2D")

    }
    func testOptionalLastRailOutlineAndOneRailException() throws {
        open(animated: false)
        func selectRails(_ count: Int) {
            app.buttons["kick.more"].tap(); ready(app.buttons["kick.trainingSettings"])
            app.buttons["kick.trainingSettings"].tap(); ready(app.buttons["kick.start"])
            let choice = node("kick.railCount.\(count)")
            for _ in 0..<5 where !choice.isHittable { app.swipeUp() }
            ready(choice); choice.tap()
            app.buttons["kick.start"].tap(); phase("aiming")
            ready(app.buttons["kick.strike"])
        }
        selectRails(4)
        let sequence = node("kick.railSequence")
        XCTAssertTrue(sequence.label.contains("第4库，珊瑚色，可选"), sequence.label)
        XCTAssertTrue(app.frame.contains(sequence.frame))
        capture("kick-four-rails-optional-last")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; ready(app.buttons["kick.strike"])
            capture("kick-four-rails-optional-last-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft; ready(app.buttons["kick.strike"])
        }
        app.buttons["kick.more"].tap(); ready(node("kick.cameraMode")); node("kick.cameraMode").tap()
        if node("kick.dismissMenu").exists { node("kick.dismissMenu").tap() }
        ready(app.buttons["kick.strike"])
        XCTAssertTrue(sequence.label.contains("可选")); capture("kick-optional-last-3D")
        selectRails(1)
        XCTAssertFalse(sequence.label.contains("可选"))
        capture("kick-one-rail-required")
    }
    func testInitialRailAimAndDirectHitNotice() throws {
        open(animated: false)
        let initial = try probe()
        XCTAssertEqual(initial["direction"] as? [Double], initial["initialDirection"] as? [Double])
        capture("kick-first-rail-initial-aim")
        let cue = try XCTUnwrap(initial["cue"] as? [Double])
        let target = try XCTUnwrap(initial["target"] as? [Double])
        let desired = atan2(target[1] - cue[1], target[0] - cue[0])
        let wheel = node("kick.aimWheel"); ready(wheel)
        func angle() throws -> Double {
            let d = try XCTUnwrap(probe()["direction"] as? [Double])
            return atan2(d[1], d[0])
        }
        func difference(_ a: Double, _ b: Double) -> Double { atan2(sin(a-b), cos(a-b)) }
        var gain = 0.15 * Double.pi / 180
        for _ in 0..<45 {
            let before = try angle(), delta = difference(desired, before)
            if abs(delta) < 0.005 { break }
            let travel = max(-100, min(100, delta / gain))
            let start = wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: -travel)))
            let moved = difference(try angle(), before)
            if abs(moved) > 0.0001 { gain = moved / travel }
        }
        XCTAssertLessThan(abs(difference(desired, try angle())), 0.015)
        app.buttons["kick.strike"].tap()
        let notice = node("kick.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        XCTAssertTrue(notice.label.contains("请先碰库，再碰目标球"))
        XCTAssertEqual(try probe()["phase"] as? String, "aiming")
        XCTAssertEqual(try probe()["attempts"] as? Int, 0)
        XCTAssertEqual(try probe()["quota"] as? Int, initial["quota"] as? Int)
        capture("kick-direct-hit-info")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: notice)], timeout: 6), .completed)
        capture("kick-direct-hit-info-expired")
        app.buttons["kick.more"].tap(); ready(node("kick.cameraMode")); node("kick.cameraMode").tap()
        if node("kick.dismissMenu").exists { node("kick.dismissMenu").tap() }
        ready(app.buttons["kick.strike"]); app.buttons["kick.strike"].tap()
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        XCTAssertEqual(try probe()["attempts"] as? Int, 0)
        capture("kick-3D-direct-hit-info")
    }
    func testColorHintDraftCancelCommitAndNoticeExpiry() throws {
        open(animated: false)
        let original = try probe()["question"] as? String
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: node("kick.question"))], timeout: 6), .completed)
        XCTAssertFalse(node("kick.requirement").exists)
        XCTAssertTrue(node("kick.railSequence").exists)
        func settings() {
            app.buttons["kick.more"].tap(); ready(app.buttons["kick.trainingSettings"])
            app.buttons["kick.trainingSettings"].tap(); ready(app.buttons["kick.start"])
        }
        func disableColors() {
            let toggle = app.switches["kick.railColors"]
            for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
            ready(toggle)
            if toggle.value as? String == "1" {
                toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -25, dy: 0)).tap()
            }
        }
        settings()
        for _ in 0..<3 where !node("kick.railCount.4").isHittable { app.swipeUp() }
        XCTAssertTrue(node("kick.railCount.0").exists)
        XCTAssertTrue(node("kick.railCount.4").exists)
        capture("kick-inline-rail-count")
        disableColors(); app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, original)
        XCTAssertTrue(node("kick.railSequence").exists)
        settings(); disableColors(); app.buttons["kick.start"].tap(); phase("aiming")
        XCTAssertFalse(node("kick.railSequence").exists)
        XCTAssertEqual(try probe()["railColors"] as? Bool, false)
        capture("kick-colors-off-unchanged-felt")
        app.buttons["kick.strike"].tap(); phase("result")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: node("kick.result"))], timeout: 6), .completed)
        capture("kick-result-notice-expired")
    }
    func testDirectionRetrySettingsAndNextQuestion() throws {
        open(animated: false)
        let id = try probe()["question"] as? String
        waitForBaseline(false)
        capture("kick-no-baseline-2D")
        let sequence = node("kick.railSequence")
        XCTAssertTrue(sequence.exists)
        XCTAssertTrue(app.frame.contains(sequence.frame))
        XCTAssertEqual(try probe()["railColors"] as? Bool, true)
        let direction = try probe()["direction"] as? [Double]
        let wheel = node("kick.aimWheel"); ready(wheel)
        wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.65)).press(forDuration: 0.1, thenDragTo: wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.35)))
        XCTAssertNotEqual(try probe()["direction"] as? [Double], direction)
        waitForBaseline(false)
        capture("kick-2D-aiming")
        app.buttons["kick.more"].tap(); ready(app.buttons["kick.trainingSettings"]); app.buttons["kick.trainingSettings"].tap()
        ready(app.buttons["training.settingsCancel"]); app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, id)
        app.buttons["kick.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        let success = try probe()["successes"] as? Int
        let result = node("kick.result")
        XCTAssertTrue(result.exists)
        XCTAssertTrue(result.label.contains(success == 1 ? " · 成功" : " · 失败"), result.label)
        capture("kick-2D-result")
        app.buttons["kick.retry"].tap(); phase("aiming")
        waitForBaseline(false)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
        capture("kick-previous-route-retry-2D")
        app.buttons["kick.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["successes"] as? Int, success)
        app.buttons["kick.strike"].tap(); phase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, id)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        waitForBaseline(false)
        capture("kick-next-question-no-baseline")
    }
    func testViewSwitchAnimationBackgroundAndMeasurement() throws {
        open(animated: true)
        let id = try probe()["question"] as? String
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; ready(app.buttons["kick.strike"]); capture("kick-iPad-portrait")
        }
        XCUIDevice.shared.orientation = .landscapeLeft; ready(app.buttons["kick.strike"])
        XCTAssertTrue(node("kick.railSequence").label.contains("第1库，蓝色"))
        capture("kick-landscape-2D")
        app.buttons["kick.more"].tap(); ready(node("kick.cameraMode")); node("kick.cameraMode").tap()
        if node("kick.dismissMenu").exists { node("kick.dismissMenu").tap() }
        XCTAssertEqual(try probe()["view"] as? String, "3D")
        XCTAssertEqual(try probe()["question"] as? String, id)
        waitForBaseline(false)
        capture("kick-3D-aiming")
        XCTAssertTrue(node("kick.railSequence").exists)
        XCTAssertFalse(node("kick.railSequence").frame.intersects(app.buttons["kick.strike"].frame))
        ready(app.buttons["kick.strike"]); app.buttons["kick.strike"].tap(); phase("result")
        capture("kick-3D-result")
        XCUIDevice.shared.press(.home); app.activate(); phase("result")
        XCTAssertEqual(try probe()["question"] as? String, id)
        XCTAssertFalse(app.buttons["kick.playback"].exists)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        app.buttons["kick.retry"].tap(); phase("aiming"); capture("kick-3D-retry")
        waitForBaseline(false)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
        app.buttons["kick.geometry"].tap(); ready(node("kick.geometry.2")); node("kick.geometry.2").tap()
        XCTAssertEqual((try probe()["geometry"] as? [String: Any])?["count"] as? Int, 2)
        capture("kick-3D-measurement")
    }
    func testDisplayMenuSpinPadAndCancellationKeepDraft() throws {
        open(animated: false)
        let id = try probe()["question"] as? String
        let initial = try probe()["direction"] as? [Double]
        ready(node("shotStage.spinEntry")); node("shotStage.spinEntry").tap()
        ready(node("spinPad.disc")); capture("kick-expanded-spin")
        // Dismissing the disc must swallow this touch, not drag the underlying aim.
        ready(node("关闭打点")); node("关闭打点").tap()
        XCTAssertEqual(try probe()["direction"] as? [Double], initial)
        app.buttons["kick.more"].tap(); ready(node("menu.tableGrid")); node("menu.tableGrid").tap()
        XCTAssertTrue(node("menu.tableGrid").exists)
        capture("kick-display-menu")
        if node("kick.dismissMenu").exists { node("kick.dismissMenu").tap() }
        XCTAssertEqual(try probe()["question"] as? String, id)
        XCTAssertEqual(try probe()["attempts"] as? Int, 0)
        ready(app.buttons["kick.strike"]); capture("kick-grid")
    }
    func testLastFreeQuestionResultRetryAndExplicitSummary() throws {
        open(animated: false, lastFree: true)
        app.buttons["kick.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        XCTAssertEqual(try probe()["primary"] as? String, "查看总结")
        XCTAssertFalse(node("kick.summary").exists)
        app.buttons["kick.retry"].tap(); phase("aiming")
        app.buttons["kick.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["quota"] as? Int, 15)
        capture("kick-last-free-result")
        app.buttons["kick.strike"].tap(); phase("summary")
        XCTAssertTrue(node("kick.summary").exists); capture("kick-summary")
    }
}
