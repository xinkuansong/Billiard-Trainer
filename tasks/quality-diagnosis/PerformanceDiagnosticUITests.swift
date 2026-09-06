import XCTest

/// Diagnostic observation only: no product performance threshold or asset generation.
final class PerformanceDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func configuredApp() -> XCUIApplication {
        let candidate = XCUIApplication()
        candidate.launchArguments = [
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-resetDebugPremium",
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance"
        ]
        return candidate
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 30) {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout), .completed)
    }
    private func artifactDirectory() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "performance-\(runID)-\(stage)"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename; attachment.lifetime = .keepAlways; add(attachment)
        try shot.pngRepresentation.write(to: artifactDirectory().appendingPathComponent(filename + ".png"))
    }
    private func writeReport(_ stage: String, samples: [[String: Any]]) throws {
        let report: [String: Any] = [
            "runID": runID,
            "scenario": stage,
            "clock": "ProcessInfo.systemUptime",
            "store": "fresh in-memory container per explicit launch",
            "samples": samples,
            "hardPerformanceThreshold": NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "performance-\(runID)-\(stage)"; attachment.lifetime = .keepAlways; add(attachment)
        try data.write(to: artifactDirectory().appendingPathComponent("performance-\(runID)-\(stage).json"))
    }

    func testFiveProcessColdLaunchObservations() throws {
        app = configuredApp()
        var samples: [[String: Any]] = []
        for iteration in 1...5 {
            app.terminate()
            XCTAssertEqual(app.state, .notRunning)
            let start = ProcessInfo.processInfo.systemUptime
            app.launch()
            let launchReturned = ProcessInfo.processInfo.systemUptime
            XCTAssertEqual(app.state, .runningForeground)
            let primary = app.buttons["trainingHome.freeTraining"]
            ready(primary)
            let readyAt = ProcessInfo.processInfo.systemUptime
            samples.append([
                "iteration": iteration,
                "launchCallSeconds": launchReturned - start,
                "launchThroughCTAQuerySeconds": readyAt - start,
                "foregroundAtObservation": app.state == .runningForeground
            ])
            // Persist each sample before the next launch so later failure preserves prior observations.
            try writeReport("five-process-launches", samples: samples)
            try capture("launch-\(iteration)-ready")
        }
        XCTAssertEqual(samples.count, 5)
    }

    func testTenToolEntryExitCyclesInOneExplicitAppLaunch() throws {
        app = configuredApp()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
        app.switchTab(.angle)
        let playSection = app.buttons["angleHomeTab_打"]
        ready(playSection); playSection.tap()
        var samples: [[String: Any]] = []
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        // One ten-cycle block. App-targeted aggregate memory/CPU metrics are retained in xcresult.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            do {
                for iteration in 1...10 {
                    XCTAssertEqual(app.state, .runningForeground)
                    let card = app.buttons["自由击球"].firstMatch
                    ready(card)
                    let entryStart = ProcessInfo.processInfo.systemUptime
                    card.tap()
                    XCTAssertTrue(app.navigationBars["自由击球"].waitForExistence(timeout: 30))
                    let initialized = app.staticTexts.matching(NSPredicate(
                        format: "identifier == %@ AND label CONTAINS %@", "navStatus.subtitle", "已就绪"
                    )).firstMatch
                    XCTAssertTrue(initialized.waitForExistence(timeout: 30))
                    let enteredAt = ProcessInfo.processInfo.systemUptime
                    // Real interaction proves this is not a stale or inert scene screenshot.
                    let spin = app.buttons["shotStage.spinEntry"].firstMatch
                    ready(spin); spin.tap()
                    let close = app.buttons["关闭打点"].firstMatch
                    ready(close)
                    try capture("cycle-\(iteration)-spin-open")
                    close.tap()
                    XCTAssertTrue(close.waitForNonExistence(timeout: 5))
                    let back = app.navigationBars.buttons.firstMatch
                    ready(back)
                    let returnStart = ProcessInfo.processInfo.systemUptime
                    back.tap()
                    ready(playSection); ready(card)
                    let returnedAt = ProcessInfo.processInfo.systemUptime
                    samples.append([
                        "iteration": iteration,
                        "entryThroughReadyQuerySeconds": enteredAt - entryStart,
                        "returnThroughCardQuerySeconds": returnedAt - returnStart,
                        "foregroundAtObservation": app.state == .runningForeground
                    ])
                    try writeReport("ten-tool-cycles", samples: samples)
                    try capture("cycle-\(iteration)-returned")
                }
            } catch {
                XCTFail("Diagnostic artifact or scenario failed: \(error)")
            }
        }
        XCTAssertEqual(samples.count, 10, "Every cycle must reach and return from the actual tool")
    }
}
