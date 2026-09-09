import XCTest

/// Diagnostic draft. Normal UI only; never seeds elapsed time or changes the clock.
final class TimerJourneyDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    private struct Reading {
        let start: TimeInterval
        let end: TimeInterval
        let seconds: Int
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: [
            "-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"
        ])
    }
    override func tearDownWithError() throws { app?.terminate() }

    func testNormalTimerPauseResumeMinimizeBackgroundAndRestExtension() throws {
        app.switchTab(.profile)
        ready(app.buttons["profile.login"])
        app.switchTab(.training)
        tap("trainingHome.freeTraining")
        tap("添加中袋直线出杆")
        tap("完成(1)")
        let timer = app.descendants(matching: .any)["activeTraining.timer"].firstMatch
        ready(timer)
        let toggle = app.buttons["activeTraining.timerToggle"]
        ready(toggle)
        // New normal sessions are prepared with timing stopped, not a seeded run.
        XCTAssertEqual(toggle.label, "继续计时")
        XCTAssertEqual(try trainingReading().seconds, 0)
        tap("activeTraining.timerToggle")
        waitLabel(toggle, "暂停计时")
        let started = try trainingReading()
        try holdForMeasurement(seconds: 3)
        let advanced = try trainingReading()
        assertRunningDelta(started, advanced)
        XCTAssertGreaterThan(advanced.seconds, started.seconds)
        try capture("running")

        tap("activeTraining.timerToggle")
        waitLabel(toggle, "继续计时")
        let paused = try trainingReading()
        try holdForMeasurement(seconds: 3)
        let held = try trainingReading()
        XCTAssertEqual(held.seconds, paused.seconds, "Paused elapsed time must remain exactly unchanged")
        try capture("paused-unchanged")
        tap("activeTraining.timerToggle")
        waitLabel(toggle, "暂停计时")
        let resumed = try trainingReading()
        XCTAssertGreaterThanOrEqual(resumed.seconds, paused.seconds)
        try holdForMeasurement(seconds: 3)
        let continuing = try trainingReading()
        assertRunningDelta(resumed, continuing)
        XCTAssertGreaterThan(continuing.seconds, resumed.seconds)

        let beforeMinimize = try trainingReading()
        tap("最小化训练")
        ready(app.buttons["minimizedTraining.resume"])
        XCTAssertFalse(timer.exists)
        try capture("session-minimized")
        tap("minimizedTraining.resume")
        ready(timer)
        waitLabel(toggle, "暂停计时")
        let restored = try trainingReading()
        assertRunningDelta(beforeMinimize, restored)
        try capture("session-restored")

        let beforeBackground = try trainingReading()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 8))
        try holdForMeasurement(seconds: 4)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        ready(timer)
        waitLabel(toggle, "暂停计时")
        let afterBackground = try trainingReading()
        assertRunningDelta(beforeBackground, afterBackground)
        XCTAssertGreaterThan(afterBackground.seconds, beforeBackground.seconds)
        try capture("foreground-time-restored")

        // Measure the rest clock independently. No assertion that rest counts
        // toward cumulative training: Q-v48-1 is still an unconfirmed proposal.
        tap("activeTraining.rest")
        ready(app.buttons["+30S"])
        let restBefore = try restReading()
        XCTAssertGreaterThan(restBefore.seconds, 0)
        tap("+30S")
        let restAdded = try restReading()
        assertRestDelta(restBefore, restAdded, extensionSeconds: 30)
        XCTAssertGreaterThan(restAdded.seconds, restBefore.seconds)
        try capture("rest-extended")
        tap("最小化组间休息")
        ready(app.buttons["activeTraining.restPill"])
        XCTAssertFalse(app.buttons["minimizedTraining.resume"].exists)
        XCTAssertTrue(timer.exists)
        let restMinimized = try restReading()
        try holdForMeasurement(seconds: 3)
        let restTicked = try restReading()
        assertRestDelta(restMinimized, restTicked, extensionSeconds: 0)
        XCTAssertLessThan(restTicked.seconds, restMinimized.seconds)
        try capture("rest-minimized-ticking")
        tap("activeTraining.restPill")
        ready(app.buttons["完成休息"])
        tap("完成休息")
        XCTAssertTrue(app.buttons["完成休息"].waitForNonExistence(timeout: 8))
        waitLabel(app.buttons["activeTraining.rest"], "休息设置")
        XCTAssertFalse(app.buttons["activeTraining.restPill"].exists)
        try capture("rest-finished")

        tap("activeTraining.more")
        tap("结束训练")
        let end = app.alerts.buttons["结束"]
        ready(end); end.tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["minimizedTraining.resume"].exists)
        try capture("training-ended-note-phase")
        // Stop at the explicit ended/note phase. Saving zero scored groups would
        // conflate this timer diagnosis with the already recorded QD012 issue.
    }

    func testNormalRestExpiresInBackgroundAndCanRestart() throws {
        app.switchTab(.profile)
        ready(app.buttons["profile.login"])
        app.switchTab(.training)
        tap("trainingHome.freeTraining")
        tap("添加中袋直线出杆")
        tap("完成(1)")
        ready(app.buttons["activeTraining.rest"])
        tap("activeTraining.timerToggle")
        waitLabel(app.buttons["activeTraining.timerToggle"], "暂停计时")
        tap("activeTraining.rest")
        ready(app.buttons["+30S"])
        let initial = try restReading()
        XCTAssertGreaterThan(initial.seconds, 0)
        XCTAssertLessThanOrEqual(initial.seconds, 60, "Unexpected normal rest duration; do not silently extend the run")
        try capture("natural-zero-before-background")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 8))
        let backgroundStart = ProcessInfo.processInfo.systemUptime
        // Wait the observed remaining duration plus two seconds of quantization
        // margin, without changing the app clock or pressing Finish rest.
        try holdForMeasurement(seconds: TimeInterval(initial.seconds) + 2)
        let backgroundEnd = ProcessInfo.processInfo.systemUptime
        print("[QD-Timer] natural-zero backgroundStart=\(backgroundStart) backgroundEnd=\(backgroundEnd) initialSeconds=\(initial.seconds)")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        waitLabel(app.buttons["activeTraining.rest"], "休息设置")
        XCTAssertFalse(app.buttons["完成休息"].exists)
        XCTAssertFalse(app.buttons["activeTraining.restPill"].exists)
        waitLabel(app.buttons["activeTraining.timerToggle"], "暂停计时")
        try capture("natural-zero-foreground-cleared")
        tap("activeTraining.rest")
        ready(app.buttons["+30S"])
        let restarted = try restReading()
        XCTAssertGreaterThan(restarted.seconds, 0)
        try holdForMeasurement(seconds: 3)
        let ticked = try restReading()
        assertRestDelta(restarted, ticked, extensionSeconds: 0)
        XCTAssertGreaterThan(ticked.seconds, 0)
        XCTAssertLessThan(ticked.seconds, restarted.seconds)
        try capture("natural-zero-next-rest-ticking")
        tap("完成休息")
        waitLabel(app.buttons["activeTraining.rest"], "休息设置")
    }

    private func trainingReading() throws -> Reading {
        let start = ProcessInfo.processInfo.systemUptime
        let label = app.descendants(matching: .any)["activeTraining.timer"].firstMatch.label
        let end = ProcessInfo.processInfo.systemUptime
        let value = label.replacingOccurrences(of: "训练时间 ", with: "")
        let parts = value.split(separator: ":").compactMap { Int($0) }
        XCTAssertTrue(parts.count == 2 || parts.count == 3, "Unrecognized timer label: " + label)
        guard parts.count == 2 || parts.count == 3 else { throw ProbeError.invalidClock }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        print("[QD-Timer] training start=\(start) end=\(end) seconds=\(seconds) label=\(label)")
        return Reading(start: start, end: end, seconds: seconds)
    }
    private func restReading() throws -> Reading {
        let start = ProcessInfo.processInfo.systemUptime
        let label = app.buttons["activeTraining.rest"].label
        let end = ProcessInfo.processInfo.systemUptime
        // Header remains in AX while the rest card is expanded; its production
        // label is either 跳过休息 N秒 or 展开组间休息 N秒.
        let seconds = try XCTUnwrap(label.split(separator: " ").last.flatMap {
            Int($0.replacingOccurrences(of: "秒", with: ""))
        }, "Unrecognized rest label: " + label)
        print("[QD-Timer] rest start=\(start) end=\(end) seconds=\(seconds) label=\(label)")
        return Reading(start: start, end: end, seconds: seconds)
    }
    private func assertRunningDelta(_ a: Reading, _ b: Reading) {
        let delta = b.seconds - a.seconds
        // AX reads are bracketed; permit one integer-quantization second plus
        // one scheduled display tick, not an arbitrary duration/percentage band.
        XCTAssertGreaterThanOrEqual(delta, max(0, Int(floor(b.start - a.end)) - 2))
        XCTAssertLessThanOrEqual(delta, Int(ceil(b.end - a.start)) + 2)
    }
    private func assertRestDelta(_ a: Reading, _ b: Reading, extensionSeconds: Int) {
        let delta = b.seconds - a.seconds
        XCTAssertGreaterThanOrEqual(delta, extensionSeconds - Int(ceil(b.end - a.start)) - 2)
        XCTAssertLessThanOrEqual(delta, extensionSeconds - Int(floor(b.start - a.end)) + 2)
    }
    private func holdForMeasurement(seconds: TimeInterval) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        while ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: max(0, min(0.1, deadline - ProcessInfo.processInfo.systemUptime)))
        }
    }
    private func ready(_ element: XCUIElement) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 12), .completed)
    }
    private func tap(_ identifier: String) {
        let element = app.buttons[identifier].firstMatch
        ready(element); element.tap()
    }
    private func waitLabel(_ element: XCUIElement, _ label: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)], timeout: 8), .completed)
    }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let directory = URL(fileURLWithPath: try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = "timer-\(runID)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot)
        image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let tree = XCTAttachment(string: ax)
        tree.name = stem + "-AX"; tree.lifetime = .keepAlways; add(tree)
        try Data(ax.utf8).write(to: directory.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
    private enum ProbeError: Error { case invalidClock }
}
