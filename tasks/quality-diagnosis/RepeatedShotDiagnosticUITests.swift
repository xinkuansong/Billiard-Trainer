import XCTest

/// Ten real shot/replay/redo cycles in one explicit app launch. No performance SLA.
final class RepeatedShotDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private let runID = UUID().uuidString
    private var samples: [[String: Any]] = []
    private var eventIndex = 0
    private var evidenceStrategy = "strict-transient-busy-and-terminal-states"

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil {
            try report("terminal")
            try capture("terminal")
        }
    }

    func testTenActualShotReplayRedoCyclesInOneAppLaunch() throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_REPEATED_SHOT_AUTH"] ?? env["TEST_RUNNER_QD_REPEATED_SHOT_AUTH"], "DEDICATED_DIAGNOSTIC_SIMULATOR")
        _ = try directory()
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                                       "-hasCompletedOnboarding", "YES", "-resetDebugPremium",
                                       "-v50.inMemoryStore", "-v51.followSystemAppearance"]
        app = application
        application.launch() // Exactly one launch; no recovery launch or per-cycle navigation.
        XCTAssertEqual(application.state, .runningForeground)
        application.switchTab(.angle)
        let category = application.buttons["angleHomeTab_打"]
        ready(category); category.tap()
        let card = application.buttons["自由击球"].firstMatch
        ready(card)
        let window = application.windows.firstMatch
        let tabs = application.tabBars.firstMatch
        XCTAssertTrue(window.exists); XCTAssertTrue(tabs.exists)
        XCTAssertFalse(card.frame.isEmpty); XCTAssertTrue(window.frame.contains(card.frame))
        XCTAssertLessThan(card.frame.maxY, tabs.frame.minY)
        card.tap()
        XCTAssertTrue(application.navigationBars["自由击球"].waitForExistence(timeout: 30))
        let strike = application.buttons["击球"].firstMatch
        let busy = application.buttons["击球中"].firstMatch
        let replay = application.buttons["回放"].firstMatch
        let redo = application.buttons["重打"].firstMatch
        ready(strike)
        XCTAssertTrue(replay.exists); XCTAssertFalse(replay.isEnabled)
        XCTAssertTrue(redo.exists); XCTAssertFalse(redo.isEnabled)
        try capture("initial-default-board")
        try report("entered-default-board")

        for iteration in 1...10 {
            XCTAssertEqual(application.state, .runningForeground)
            ready(strike)
            XCTAssertFalse(busy.exists)
            XCTAssertFalse(replay.isEnabled); XCTAssertFalse(redo.isEnabled)
            samples.append(["iteration": iteration, "phase": "before-shot", "startUptime": now])
            try report("cycle-\(iteration)-before-shot")
            let start = now
            samples[iteration - 1]["shotTapUptime"] = start
            strike.tap()
            // Do not infer started from the final ready state. Missing this transient is
            // a failed observation, never an automatically successful short animation.
            let shotStatus = application.staticTexts.matching(NSPredicate(
                format: "identifier == %@ AND label == %@", "navStatus.subtitle", "击球中…"
            )).firstMatch
            waitState("actual ball animation started", timeout: 6) {
                busy.exists && !busy.isEnabled && replay.exists && !replay.isEnabled && shotStatus.exists
            }
            samples[iteration - 1]["shotBusyObservedUptime"] = now
            samples[iteration - 1]["phase"] = "shot-start-observed"
            try report("cycle-\(iteration)-shot-started")
            waitState("shot ended with replay and redo available", timeout: 45) {
                !busy.exists && replay.exists && replay.isEnabled && redo.exists && redo.isEnabled
            }
            let shotEnd = now
            samples[iteration - 1]["shotEndObservedUptime"] = shotEnd
            samples[iteration - 1]["shotThroughEndQuerySeconds"] = shotEnd - start
            samples[iteration - 1]["phase"] = "shot-ended"
            try report("cycle-\(iteration)-shot-ended")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-shot-ended") }

            ready(replay)
            let replayStart = now
            samples[iteration - 1]["replayTapUptime"] = replayStart
            replay.tap()
            let replayStatus = application.staticTexts.matching(NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@", "navStatus.subtitle", "回放上一杆"
            )).firstMatch
            waitState("actual replay busy and replay-specific status", timeout: 6) {
                busy.exists && !busy.isEnabled && !replay.isEnabled && replayStatus.exists
            }
            samples[iteration - 1]["replayBusyObservedUptime"] = now
            samples[iteration - 1]["phase"] = "replay-start-observed"
            try report("cycle-\(iteration)-replay-started")
            waitState("replay ended", timeout: 45) {
                !busy.exists && !replayStatus.exists && replay.exists && replay.isEnabled && redo.exists && redo.isEnabled
            }
            let replayEnd = now
            samples[iteration - 1]["replayEndObservedUptime"] = replayEnd
            samples[iteration - 1]["replayThroughEndQuerySeconds"] = replayEnd - replayStart
            samples[iteration - 1]["phase"] = "replay-ended"
            try report("cycle-\(iteration)-replay-ended")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-replay-ended") }

            ready(redo)
            let resetStart = now
            redo.tap()
            ready(strike)
            XCTAssertFalse(busy.exists); XCTAssertFalse(replay.isEnabled); XCTAssertFalse(redo.isEnabled)
            let end = now
            samples[iteration - 1]["redoEndObservedUptime"] = end
            samples[iteration - 1]["redoThroughReadyQuerySeconds"] = end - resetStart
            samples[iteration - 1]["wholeCycleIncludingEvidenceSeconds"] = end - start
            samples[iteration - 1]["phase"] = "completed"
            try report("cycle-\(iteration)-completed")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-redo-default-board") }
        }
        XCTAssertEqual(samples.count, 10)
        XCTAssertEqual(samples.filter { ($0["phase"] as? String) == "completed" }.count, 10)
        XCTAssertEqual(application.state, .runningForeground)
        try report("all-ten-completed")
    }

    /// Companion only: the orchestrator MUST review every shot/replay in xcresult video.
    /// A green method proves operations and terminal controls, never actual motion.
    func testTenShotReplayRedoCyclesForRequiredVideoReview() throws {
        evidenceStrategy = "operations-and-terminal-states-with-required-video-review"
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_REPEATED_SHOT_AUTH"] ?? env["TEST_RUNNER_QD_REPEATED_SHOT_AUTH"], "DEDICATED_DIAGNOSTIC_SIMULATOR")
        _ = try directory()
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                                       "-hasCompletedOnboarding", "YES", "-resetDebugPremium",
                                       "-v50.inMemoryStore", "-v51.followSystemAppearance"]
        app = application
        application.launch() // Exactly one launch; no recovery launch or per-cycle navigation.
        XCTAssertEqual(application.state, .runningForeground)
        application.switchTab(.angle)
        let category = application.buttons["angleHomeTab_打"]
        ready(category); category.tap()
        let card = application.buttons["自由击球"].firstMatch
        ready(card)
        let window = application.windows.firstMatch
        let tabs = application.tabBars.firstMatch
        XCTAssertTrue(window.exists); XCTAssertTrue(tabs.exists)
        XCTAssertFalse(card.frame.isEmpty); XCTAssertTrue(window.frame.contains(card.frame))
        XCTAssertLessThan(card.frame.maxY, tabs.frame.minY)
        card.tap()
        XCTAssertTrue(application.navigationBars["自由击球"].waitForExistence(timeout: 30))
        let strike = application.buttons["击球"].firstMatch
        let busy = application.buttons["击球中"].firstMatch
        let replay = application.buttons["回放"].firstMatch
        let redo = application.buttons["重打"].firstMatch
        ready(strike)
        XCTAssertTrue(replay.exists); XCTAssertFalse(replay.isEnabled)
        XCTAssertTrue(redo.exists); XCTAssertFalse(redo.isEnabled)
        try capture("initial-default-board")
        try report("entered-default-board")

        for iteration in 1...10 {
            XCTAssertEqual(application.state, .runningForeground)
            ready(strike)
            XCTAssertFalse(busy.exists)
            XCTAssertFalse(replay.isEnabled); XCTAssertFalse(redo.isEnabled)
            samples.append(["iteration": iteration, "phase": "before-shot", "startUptime": now, "shotVideoVerdict": "pending-required-review", "replayVideoVerdict": "pending-required-review"])
            try report("cycle-\(iteration)-before-shot")
            let start = now
            samples[iteration - 1]["shotTapUptime"] = start
            strike.tap()
            // Give the UI a bounded scheduling interval; this is NOT motion evidence.
            // The tap may itself return only after playback. External video is mandatory.
            Thread.sleep(forTimeInterval: 1)
            samples[iteration - 1]["shotTapReturnedObservationUptime"] = now
            samples[iteration - 1]["phase"] = "shot-operation-observed-motion-unverified"
            try report("cycle-\(iteration)-shot-operation-motion-unverified")
            waitState("shot ended with replay and redo available", timeout: 45) {
                !busy.exists && replay.exists && replay.isEnabled && redo.exists && redo.isEnabled
            }
            let shotEnd = now
            samples[iteration - 1]["shotTerminalStateObservedUptime"] = shotEnd
            samples[iteration - 1]["shotThroughEndQuerySeconds"] = shotEnd - start
            samples[iteration - 1]["phase"] = "shot-terminal-motion-unverified"
            try report("cycle-\(iteration)-shot-ended")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-shot-ended") }

            ready(replay)
            let replayStart = now
            samples[iteration - 1]["replayTapUptime"] = replayStart
            replay.tap()
            Thread.sleep(forTimeInterval: 1)
            samples[iteration - 1]["replayTapReturnedObservationUptime"] = now
            samples[iteration - 1]["phase"] = "replay-operation-observed-motion-unverified"
            try report("cycle-\(iteration)-replay-operation-motion-unverified")
            waitState("replay ended", timeout: 45) {
                !busy.exists && replay.exists && replay.isEnabled && redo.exists && redo.isEnabled
            }
            let replayEnd = now
            samples[iteration - 1]["replayTerminalStateObservedUptime"] = replayEnd
            samples[iteration - 1]["replayThroughEndQuerySeconds"] = replayEnd - replayStart
            samples[iteration - 1]["phase"] = "replay-terminal-motion-unverified"
            try report("cycle-\(iteration)-replay-ended")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-replay-ended") }

            ready(redo)
            let resetStart = now
            redo.tap()
            ready(strike)
            XCTAssertFalse(busy.exists); XCTAssertFalse(replay.isEnabled); XCTAssertFalse(redo.isEnabled)
            let end = now
            samples[iteration - 1]["redoEndObservedUptime"] = end
            samples[iteration - 1]["redoThroughReadyQuerySeconds"] = end - resetStart
            samples[iteration - 1]["wholeCycleIncludingEvidenceSeconds"] = end - start
            samples[iteration - 1]["phase"] = "operations-completed-video-pending"
            try report("cycle-\(iteration)-completed")
            if [1, 5, 10].contains(iteration) { try capture("cycle-\(iteration)-redo-default-board") }
        }
        XCTAssertEqual(samples.count, 10)
        XCTAssertEqual(samples.filter { ($0["phase"] as? String) == "operations-completed-video-pending" }.count, 10)
        XCTAssertEqual(application.state, .runningForeground)
        try report("ten-operation-cycles-completed-video-verdicts-required")
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private func ready(_ element: XCUIElement) {
        waitState("action ready: \(element)", timeout: 30) {
            element.exists && element.isEnabled && element.isHittable
        }
    }
    private func waitState(_ description: String, timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, description)
    }
    private func directory() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        XCTAssertFalse(path.isEmpty)
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func report(_ stage: String) throws {
        eventIndex += 1
        let value: [String: Any] = ["runID": runID, "stage": stage, "eventIndex": eventIndex,
            "evidenceStrategy": evidenceStrategy,
            "videoAcceptance": evidenceStrategy == "strict-transient-busy-and-terminal-states" ? "not-the-companion-strategy" : "PENDING: all 10 shots and all 10 replays require video motion evidence; green method is insufficient",
            "wallTimeISO8601": ISO8601DateFormatter().string(from: Date()), "systemUptime": now,
            "clock": "ProcessInfo.systemUptime", "explicitLaunchCount": 1,
            "pidContinuity": "requires external host PID timeline", "hardPerformanceThreshold": NSNull(), "samples": samples]
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        let stem = "repeated-shot-\(runID)-event-\(eventIndex)-\(stage)"
        try data.write(to: directory().appendingPathComponent(stem + ".json"), options: .withoutOverwriting)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = stem; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func capture(_ stage: String) throws {
        let application = try XCTUnwrap(app)
        let stem = "repeated-shot-\(runID)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: directory().appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let attachment = XCTAttachment(screenshot: shot); attachment.name = stem; attachment.lifetime = .keepAlways; add(attachment)
        let tree = application.debugDescription
        try Data(tree.utf8).write(to: directory().appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let ax = XCTAttachment(string: tree); ax.name = stem + "-AX"; ax.lifetime = .keepAlways; add(ax)
    }
}
