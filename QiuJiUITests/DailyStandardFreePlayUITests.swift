import XCTest

/// Renderer placement must follow the visible stage across the real detail navigation route.
/// The baseline failure is retained in fixes-20261009/before-p1; no production delay is used.
final class DailyStandardFreePlayUITests: XCTestCase {
    private var app: XCUIApplication!
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func assertRendererMatchesStage(file: StaticString = #filePath, line: UInt = #line) {
        let stage = element("freeplay.stage").frame
        let renderer = element("table.scene").frame
        XCTAssertGreaterThan(stage.width, 100, file: file, line: line)
        XCTAssertTrue(renderer.contains(CGPoint(x: stage.midX, y: stage.midY)), "renderer=\(renderer), stage=\(stage)", file: file, line: line)
        XCTAssertEqual(renderer.minX, stage.minX, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.minY, stage.minY, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.width, stage.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.height, stage.height, accuracy: 2, file: file, line: line)
    }
    func testTryoutRendererFollowsStageAfterDetailRotation() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.drillDetail=drill_c001", "-v54.forceLight", "-dailyLayout.probe"])
        let mode = app.buttons["drillScene.cameraMode"], play = app.buttons["drillPlayButton"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        mode.tap(); app.buttons["drillScene.overview"].tap(); mode.tap()
        play.tap(); play.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '继续' OR label == '回放'"), object: play)], timeout: 40), .completed)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width }, object: nil)], timeout: 10), .completed)
        app.buttons["bottomTryoutButton"].tap()
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 15))
        try capture("tryout-renderer-entry")
        assertRendererMatchesStage()
        // A second independent snapshot exposes stale placement; this is observation,
        // not a readiness delay or an attempt to make the first assertion pass.
        try capture("tryout-renderer-second")
        assertRendererMatchesStage()
        if ProcessInfo.processInfo.environment["FREEPLAY_DIAGNOSTIC_BASELINE"] == "1" { return }
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        try capture("tryout-renderer-landscape"); assertRendererMatchesStage()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width }, object: nil)], timeout: 10), .completed)
        try capture("tryout-renderer-return"); assertRendererMatchesStage()
    }
    private func openPlayPage(_ title: String) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-dailyLayout.probe"])
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.buttons["freeplay.moreMenu"].waitForExistence(timeout: 15))
    }
    func testSimulationReadoutAndRenderer() throws {
        continueAfterFailure = false
        openPlayPage("分离角与走位")
        let metric = element("shotSimulation.readout")
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        XCTAssertTrue(metric.label.contains("切角"))
        XCTAssertFalse(metric.label.contains("球形"))
        try capture("p01-readout-portrait")
        assertRendererMatchesStage()
        print("P01 renderer.isHittable=\(element("table.scene").isHittable), frame=\(element("table.scene").frame)")
        let state = element("shotSimulation.landscape")
        let target = app.buttons["paletteBall__2"]
        XCTAssertTrue(target.exists)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.35, thenDragTo: element("table.scene").coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "_2"), object: state)], timeout: 10), .completed)
        try capture("p01-ball-placed-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        try capture("p01-readout-landscape"); assertRendererMatchesStage()
    }
    func testManualBreakSettledActionsAreCentralAndUsable() throws {
        continueAfterFailure = false
        openPlayPage("自由击球")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        app.buttons["break.entry"].tap()
        XCTAssertTrue(app.buttons["break.game.9"].waitForExistence(timeout: 5))
        app.buttons["break.game.9"].tap()
        func ready(_ button: XCUIElement, timeout: TimeInterval = 75) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: button)], timeout: timeout), .completed)
        }
        let strike = app.buttons["break.strike"], confirm = app.buttons["break.confirm"], rerack = app.buttons["break.rerack"]
        ready(strike); strike.tap(); ready(confirm)
        XCTAssertEqual(app.buttons.matching(identifier: "break.confirm").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "break.rerack").count, 1)
        let stage = element("freeplay.stage").frame
        for button in [confirm, rerack] {
            XCTAssertTrue(stage.contains(CGPoint(x: button.frame.midX, y: button.frame.midY)))
            XCTAssertEqual(button.frame.midX, stage.midX, accuracy: stage.width * 0.15)
            XCTAssertEqual(button.frame.midY, stage.midY, accuracy: 2)
        }
        let actions = confirm.frame.union(rerack.frame)
        XCTAssertEqual(actions.midX, stage.midX, accuracy: stage.width * 0.08)
        XCTAssertEqual(actions.midY, stage.midY, accuracy: stage.height * 0.15)
        try capture("p02-settled-central-actions")
        // The old side controls disallowed actions while temporarily observing from above.
        // Moving them to the table center must preserve the same gate and recovery path.
        app.buttons["freeplay.moreMenu"].tap()
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
        app.buttons["关闭菜单"].tap()
        let temporary = app.buttons["shotCamera.temporaryTopDown"]
        ready(temporary); temporary.tap()
        XCTAssertFalse(confirm.isEnabled); XCTAssertFalse(rerack.isEnabled)
        try capture("p02-settled-temporary-disabled")
        temporary.tap(); ready(confirm); ready(rerack)
        try capture("p02-settled-temporary-return")
        rerack.tap(); ready(strike)
        XCTAssertFalse(confirm.exists)
        try capture("p02-reracked")
        strike.tap(); ready(confirm); confirm.tap()
        XCTAssertTrue(element("freeplay.gameStatus").waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
        try capture("p02-confirmed")
    }

}
