import XCTest

/// Normal disk UI; parent owns probe/seed/SQL, video and App PID/RSS sampling.
/// One launch, no deep links, no model injection. Premium override opens statistics only.
final class ThousandPerformanceDiagnosticUITests: XCTestCase {
    private struct Stop: Error { let message: String }
    private var app: XCUIApplication!
    private var output: URL!
    private var expectedDay = ""
    private var events: [[String: Any]] = []
    private var began = 0.0

    func testObserveThousandRecordScrollStatisticsAndReturn() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_UI_ENVIRONMENT") == "SEEDED_DEDICATED_GUEST_SIMULATOR", "Dedicated seeded guest authorization required")
        guard let expected = setting("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env["SIMULATOR_UDID"]?.lowercased() == expected.lowercased() else {
            throw Stop(message: "Explicit device UUID mismatch")
        }
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else {
            throw Stop(message: "Absolute fresh output leaf required")
        }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse populated output leaf")
        let raw = try XCTUnwrap(setting("QD_EXPECTED_MANIFEST_JSON"))
        let manifest = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        for (key, expectedValue) in ["sessionCount": 1000, "entryCount": 1000, "setCount": 1000,
                                      "trainingDays": 1, "durationMinutes": 2000, "made": 8000,
                                      "target": 10000, "pendingSyncCount": 0] {
            try require((manifest[key] as? NSNumber)?.intValue == expectedValue, "Manifest \(key) mismatch")
        }
        let owner = try XCTUnwrap(manifest["owner"] as? String)
        try require(owner.hasPrefix("guest:") && owner == setting("QD_EXPECTED_GUEST_OWNER"), "Manifest guest owner mismatch")
        try require(manifest["bundleID"] as? String == "com.xinkuan.qiuji", "Seed bundle mismatch")
        let storePath = try XCTUnwrap(manifest["storePath"] as? String)
        try require(storePath.hasPrefix("/") && storePath == setting("QD_EXPECTED_DEFAULT_STORE_PATH"), "Reviewed disk store path mismatch")
        expectedDay = try XCTUnwrap(manifest["localDay"] as? String)
        try sameDay()
        try Data(raw.utf8).write(to: output.appendingPathComponent("input-manifest.json"), options: .withoutOverwriting)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-hasCompletedOnboarding", "YES", "-forcePremium"]
        // Deliberately no v50.inMemoryStore, authenticatedProfileFixture or force route.
        began = ProcessInfo.processInfo.systemUptime
        do {
            try require(app.state == .notRunning, "Seed host must be terminated by parent before this one launch")
            app.launch()
            try require(app.wait(for: .runningForeground, timeout: 30), "App did not reach foreground")
            let recordTab = app.tabBars.buttons["记录"]
            try ready(recordTab)
            try mark("launch-to-record-tab-ready", start: began)

            try timed("record-tap-to-history-ready") {
                recordTab.tap()
                try self.ready(self.app.buttons["统计"].firstMatch)
                try self.visible(self.app.staticTexts[self.monthTitle()].firstMatch)
            }
            try capture("01-history-ready")

            let historyScroll = try activeScroll()
            let monthBefore = app.staticTexts[monthTitle()].firstMatch.frame
            try timed("one-short-history-drag-to-real-row-ready") {
                try self.dragUp(in: historyScroll)
                let row = try self.visibleHistoryRow()
                self.events.append(["observation": "actual-row-after-single-drag", "label": row.label,
                                    "frame": String(describing: row.frame), "monthBefore": String(describing: monthBefore)])
            }
            try capture("02-history-after-one-drag")

            let statistics = app.buttons["统计"].firstMatch
            try ready(statistics)
            try timed("statistics-tap-to-overview-ready") {
                statistics.tap()
                for text in ["训练概况", "2000", "分钟 · 总时长", "1000", "训练组数"] {
                    try self.visible(self.app.staticTexts[text].firstMatch)
                }
            }
            try capture("03-statistics-overview-1000-2000")

            // Lower category summary is a separate finite reveal, not a cold-load metric.
            let total = app.staticTexts["8000/10000 球"].firstMatch
            let groups = app.staticTexts["1,000 组"].firstMatch
            for attempt in 0..<6 {
                if fullyVisible(total) && fullyVisible(groups) { break }
                let scroll = try activeScroll()
                try timed("statistics-summary-drag-\(attempt + 1)") {
                    try self.dragUp(in: scroll)
                    try self.require(self.app.state == .runningForeground, "App left foreground after drag")
                }
            }
            let summaryStart = ProcessInfo.processInfo.systemUptime
            try visible(total); try visible(groups)
            try require(abs(total.frame.midY - groups.frame.midY) < 12, "Counts must occupy same category summary row")
            try mark("post-reveal-summary-AX-ready", start: summaryStart)
            try capture("04-statistics-category-8000-10000")

            let history = app.buttons["历史"].firstMatch
            try ready(history)
            try timed("history-return-tap-to-real-row-ready") {
                history.tap()
                _ = try self.visibleHistoryRow()
            }
            try capture("05-history-returned")
            try sameDay()
            try flush()
        } catch {
            events.append(["terminal": "failed", "uptime": ProcessInfo.processInfo.systemUptime,
                           "elapsedSinceLaunchStart": ProcessInfo.processInfo.systemUptime - began,
                           "error": String(describing: error)])
            // PNG is persisted before requesting the potentially slow AX tree.
            do { try flush(); try capture("failure") }
            catch let evidenceError { XCTFail("Evidence failure: \(evidenceError)"); throw evidenceError }
            throw error
        }
    }

    override func tearDownWithError() throws {
        if let app, app.state != .notRunning {
            app.terminate()
            try require(app.wait(for: .notRunning, timeout: 15), "App failed to terminate after evidence")
        }
    }

    private func timed(_ name: String, action: () throws -> Void) throws {
        events.append(["operation": name, "state": "prepared", "uptime": ProcessInfo.processInfo.systemUptime])
        try flush() // Persist pending operation before it can stall; exclude this write from the interval.
        let start = ProcessInfo.processInfo.systemUptime
        try action()
        try mark(name, start: start)
    }
    private func mark(_ name: String, start: Double) throws {
        let end = ProcessInfo.processInfo.systemUptime
        events.append(["operation": name, "state": "completed", "startUptime": start, "endUptime": end,
                       "automationIntervalSeconds": end - start,
                       "endpoint": name.hasPrefix("statistics-summary-drag-") ? "drag returned and App foreground; not summary AX-ready" : "named AX-ready condition"])
        try flush()
    }
    private func flush() throws {
        let value: [String: Any] = ["clock": "ProcessInfo.systemUptime", "events": events,
            "scope": "Single synthetic disk run; includes XCTest/AX/idle/action; excludes pre-action ledger write and post-ready PNG/AX capture. No SLA, FPS, cold-statistics or pure App latency claim.",
            "premium": "forcePremium only opens statistics; no purchase validation"]
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("operation-observations.json"), options: .atomic)
    }
    private func ready(_ element: XCUIElement) throws {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: element)], timeout: 30) == .completed,
                    "Action node not ready: \(element)")
    }
    private func viewport() -> CGRect {
        let window = app.windows.firstMatch.frame
        let tabs = app.tabBars.firstMatch
        guard tabs.exists, !tabs.frame.isEmpty else { return .null }
        let segment = app.buttons["统计"].firstMatch
        guard segment.exists, !segment.frame.isEmpty else { return .null }
        let top = max(window.minY, segment.frame.maxY)
        return CGRect(x: window.minX, y: top, width: window.width, height: max(0, tabs.frame.minY - top))
    }
    private func fullyVisible(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame, area = viewport()
        return !frame.isEmpty && !area.isEmpty && !area.isNull && area.contains(frame)
    }
    private func visible(_ element: XCUIElement) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.fullyVisible(element) }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: 30) == .completed, "Text not wholly visible: \(element)")
    }
    private func activeScroll() throws -> XCUIElement {
        let query = app.scrollViews
        let candidates = (0..<min(query.count, 8)).map { query.element(boundBy: $0) }.filter { $0.exists && $0.isHittable }
        try require(candidates.count == 1, "Expected one active history/statistics ScrollView; capture unknown AX instead of guessing")
        let scroll = candidates[0]
        try require(!scroll.frame.isEmpty && app.windows.firstMatch.frame.intersects(scroll.frame), "Invalid scroll geometry")
        return scroll
    }
    private func dragUp(in scroll: XCUIElement) throws {
        let rect = scroll.frame.intersection(viewport()).insetBy(dx: 12, dy: 12)
        try require(!rect.isNull && rect.height > 150 && rect.width > 100, "No safe active scroll viewport")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: rect.midX, dy: rect.minY + rect.height * 0.78))
        let end = origin.withOffset(CGVector(dx: rect.midX, dy: rect.minY + rect.height * 0.32))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func visibleHistoryRow() throws -> XCUIElement {
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "2 分钟"))
        // This single short drag should only reach the early rows. Never enumerate all 1,000 AX rows.
        for index in 0..<min(rows.count, 32) {
            let row = rows.element(boundBy: index)
            if fullyVisible(row) && row.isHittable && row.isEnabled { return row }
        }
        throw Stop(message: "No actual visible fixture row among first 32 after single drag; no extra scrolling")
    }
    private func sameDay() throws {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current; formatter.timeZone = TimeZone.current; formatter.dateFormat = "yyyy-MM-dd"
        try require(formatter.string(from: Date()) == expectedDay, "Fixture local day changed; prerequisite failure")
    }
    private func monthTitle() -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: Date())
    }
    private func capture(_ stage: String) throws {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = output.appendingPathComponent(stage + ".png")
        try png.write(to: url, options: .withoutOverwriting)
        try require(try Data(contentsOf: url) == png, "PNG readback mismatch")
        let shot = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        shot.name = stage; shot.lifetime = .keepAlways; add(shot)
        let ax = app.debugDescription
        try Data(ax.utf8).write(to: output.appendingPathComponent(stage + "-AX.txt"), options: .withoutOverwriting)
        let text = XCTAttachment(string: ax); text.name = stage + "-AX"; text.lifetime = .keepAlways; add(text)
    }
    private func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(message, file: file, line: line); throw Stop(message: message) }
    }
}
