import XCTest

/// Normal disk launch; synthetic data comes only from the prior hosted SwiftData seed.
/// Manifest is passed as JSON to the runner, never injected into the App as a fixture.
final class ThousandHistoryUIDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var expectedDay = ""
    private let runID = UUID().uuidString
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard env["QD_UI_ENVIRONMENT"] == "SEEDED_DEDICATED_GUEST_SIMULATOR" else {
            throw XCTSkip("Dedicated seeded guest simulator is required")
        }
        let raw = try XCTUnwrap(env["QD_EXPECTED_MANIFEST_JSON"])
        let manifest = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        for (key, expected) in ["sessionCount":1000, "entryCount":1000, "setCount":1000,
                                "trainingDays":1, "durationMinutes":2000, "made":8000, "target":10000] {
            XCTAssertEqual((manifest[key] as? NSNumber)?.intValue, expected, "Unexpected manifest \(key)")
        }
        let owner = try XCTUnwrap(manifest["owner"] as? String)
        XCTAssertTrue(owner.hasPrefix("guest:"))
        XCTAssertEqual(owner, try XCTUnwrap(env["QD_EXPECTED_GUEST_OWNER"]))
        XCTAssertEqual(manifest["storePath"] as? String, try XCTUnwrap(env["QD_EXPECTED_DEFAULT_STORE_PATH"]))
        expectedDay = try XCTUnwrap(manifest["localDay"] as? String)
        assertSameDay()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-hasCompletedOnboarding", "YES", "-forcePremium"]
        // No in-memory/deep-link/data fixture arguments. Normal root + normal record tab.
        app.launch()
    }
    override func tearDownWithError() throws {
        if app != nil { capture("teardown"); app.terminate() }
    }
    private func assertSameDay() {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar.current; f.timeZone = TimeZone.current; f.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(f.string(from: Date()), expectedDay, "Fixture day changed; do not classify as product failure")
    }
    private func ready(_ e: XCUIElement) {
        let p = NSPredicate(format: "exists == true AND hittable == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: 30), .completed)
    }
    private func swipeUp() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.78))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.3)))
    }
    private func reveal(_ e: XCUIElement, limit: Int = 18) {
        for _ in 0..<limit { if e.exists && e.isHittable { return }; swipeUp() }
        ready(e)
    }
    private func capture(_ stage: String) {
        let stem = "thousand-\(name)-\(stage)-\(runID)"
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = stem; shot.lifetime = .keepAlways; add(shot)
        let ax = XCTAttachment(string: app.debugDescription)
        ax.name = stem + "-AX"; ax.lifetime = .keepAlways; add(ax)
    }
    private func sampleVisibleRow(_ stage: String) throws -> Int {
        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "2 分钟"))
        var candidate: XCUIElement?
        for _ in 0..<18 {
            candidate = rows.allElementsBoundByIndex.first(where: { $0.isHittable })
            if candidate != nil { break }; swipeUp()
        }
        let row = try XCTUnwrap(candidate); ready(row); row.tap()
        let score = app.staticTexts["8/10"].firstMatch; reveal(score); ready(score)
        let note = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "QD-1000-")).firstMatch
        reveal(note); ready(note)
        let index = try XCTUnwrap(Int(note.label.replacingOccurrences(of: "QD-1000-", with: "")))
        XCTAssertTrue((0..<1000).contains(index))
        capture(stage)
        let close = app.navigationBars.buttons.firstMatch; ready(close); close.tap()
        ready(app.buttons["统计"].firstMatch)
        return index
    }
    func testNormalHistorySamplesAfterScrollingAndStatisticsTotals() throws {
        app.switchTab(.history)
        let first = try sampleVisibleRow("first-detail")
        // The first hittable row is a sample, not proof of the absolute list endpoint.
        for _ in 0..<6 { swipeUp() }
        capture("history-scrolled")
        let later = try sampleVisibleRow("scrolled-detail")
        XCTAssertLessThan(later, first, "Scroll must reach a different older real fixture")
        let statistics = app.buttons["统计"].firstMatch; ready(statistics); statistics.tap()
        for text in ["训练概况", "2000", "分钟 · 总时长", "1000", "训练组数", "1", "天"] {
            let e = app.staticTexts[text].firstMatch; reveal(e); ready(e)
        }
        capture("statistics-overview")
        let rate = app.staticTexts["80%"].firstMatch; reveal(rate); ready(rate)
        ready(app.staticTexts["8000/10000 球"].firstMatch)
        ready(app.staticTexts["1000 组"].firstMatch)
        capture("statistics-rate")
        let history = app.buttons["历史"].firstMatch; ready(history); history.tap()
        let returnedRows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "2 分钟"))
        XCTAssertTrue(returnedRows.allElementsBoundByIndex.contains(where: { $0.isHittable }))
        capture("history-returned"); assertSameDay()
    }
}
