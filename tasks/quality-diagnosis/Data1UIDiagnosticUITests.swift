import XCTest

/// Uncompiled draft. Actual guest disk launch; never injects data into the App.
final class Data1UIDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    private func require(_ value: Bool, _ reason: String) throws {
        guard value else { XCTFail(reason); throw NSError(domain: "Data1UI", code: 1) }
    }
    private func checkDay() throws {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        try require(TimeZone.current.identifier == "Asia/Shanghai" && f.string(from: Date()) == "2026-09-06", "Fixed ledger day/timezone expired")
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        try require(env["QD_UI_ENVIRONMENT"] == "SEEDED_DEDICATED_GUEST_SIMULATOR", "Dedicated seed authorization required")
        let raw = try XCTUnwrap(env["QD_EXPECTED_MANIFEST_JSON"])
        let m = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        try require(m["fixture"] as? String == "DATA1-20260906-v1", "Wrong ledger")
        try require(m["bundleID"] as? String == "com.xinkuan.qiuji", "Wrong host manifest")
        let owner = try XCTUnwrap(m["owner"] as? String)
        try require(owner.hasPrefix("guest:") && owner == env["QD_EXPECTED_GUEST_OWNER"], "Wrong seed owner")
        let relative = try XCTUnwrap(m["storeRelativePath"] as? String)
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        try require(relative == env["QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH"] && !relative.hasPrefix("/") && !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }, "Wrong default relative path")
        for (key, expected) in ["sessionCount":7, "entryCount":6, "setCount":6, "answerCount":1, "pendingSyncCount":0] {
            try require((m[key] as? NSNumber)?.intValue == expected, "Invalid actual count: " + key)
        }
        try checkDay()
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v51.followSystemAppearance", "-forcePremium"]
        app.launch() // Premium only unlocks statistics; still real guest, no memory/deeplink/auth/data fixture.
        app.switchTab(.profile)
        try ready(app.buttons["profile.login"])
        try require(!app.descendants(matching: .any)["profile.accountHeader"].exists, "Guest prerequisite failed")
        try capture("guest-before")
    }
    override func tearDownWithError() throws {
        if app != nil { try? capture("teardown"); app.terminate() }
    }
    private func ready(_ e: XCUIElement) throws {
        let p = NSPredicate(format: "exists == true AND hittable == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: 12) == .completed, "Element not usable: " + e.description)
    }
    private func visible(_ e: XCUIElement) -> Bool {
        guard e.exists && e.isHittable else { return false }
        let r = e.frame
        return !r.isEmpty && r.minX.isFinite && r.minY.isFinite && app.windows.firstMatch.frame.contains(r)
    }
    private func scroll(_ up: Bool) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: up ? 0.77 : 0.32))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: up ? 0.32 : 0.77)))
    }
    private func reveal(_ e: XCUIElement) throws {
        for _ in 0..<16 { if visible(e) { return }; scroll(true) }
        try require(visible(e), "Bounded scrolling did not expose element: " + e.description)
    }
    private func capture(_ stage: String) throws {
        let stem = "data1-\(name)-\(stage)-\(runID)"
        let screenshot = XCUIScreen.main.screenshot()
        let imageAttachment = XCTAttachment(screenshot: screenshot)
        imageAttachment.name = stem; imageAttachment.lifetime = .keepAlways; add(imageAttachment)
        let tree = app.debugDescription
        let ax = XCTAttachment(string: tree); ax.name = stem + "-AX"; ax.lifetime = .keepAlways; add(ax)
        let env = ProcessInfo.processInfo.environment
        let dir = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let root = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(to: root.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        try Data(tree.utf8).write(to: root.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
    /// Bind an integer to its caption using visible frames; fail on ambiguity.
    /// Supports the real overview's value-above-caption layout, not arbitrary numbers.
    private func metric(_ caption: String, equals expected: Int) throws {
        let labels = app.staticTexts.matching(NSPredicate(format: "label == %@", caption)).allElementsBoundByIndex.filter(visible)
        try require(labels.count == 1, "Metric caption absent/ambiguous: " + caption)
        let label = labels[0]; let bounds = label.frame
        let candidates = app.staticTexts.allElementsBoundByIndex.filter { e in
            guard visible(e), Int(e.label) != nil else { return false }
            let r = e.frame; let gap = bounds.minY - r.maxY
            return gap >= -4 && gap <= 70 && min(r.maxX, bounds.maxX) > max(r.minX, bounds.minX)
        }
        try require(candidates.count == 1, "Value-caption frame association absent/ambiguous: " + caption)
        let evidence = XCTAttachment(string: "\(caption) \(bounds) -> \(candidates[0].label) \(candidates[0].frame)")
        evidence.name = "metric-frame-binding"; evidence.lifetime = .keepAlways; add(evidence)
        try require(candidates[0].label == String(expected), "Wrong bound value for " + caption)
    }
    private func historyRow(_ fragments: [String]) throws -> XCUIElement {
        let rows = app.buttons.allElementsBoundByIndex.filter { e in visible(e) && fragments.allSatisfy { e.label.contains($0) } }
        try require(rows.count == 1, "Specific history row absent/ambiguous: " + fragments.joined(separator: ","))
        return rows[0]
    }
    func testNormalGuestHomeTodayHistoryAndEntryCount() throws {
        app.switchTab(.training)
        let summary = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "本周训练 3 / 3 天，连续训练 2 天")).firstMatch
        try ready(summary); try capture("home-week")
        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]; try ready(search)
        search.tap(); search.typeText("半台直线球\n")
        let card = app.buttons["drillCard_drill_c001"]; try ready(card)
        try capture("practice-count-before")
        let badge = card.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "已练 6 次")).firstMatch
        try require(card.label.contains("已练 6 次") || visible(badge), "Count not bound to c001 card")
        app.switchTab(.history); try capture("history-today-before")
        // Two drill sessions plus a tool row; each must actually be visible.
        _ = try historyRow(["半台直线球", "30 分钟"])
        _ = try historyRow(["QD-DATA1-D", "99 分钟"])
        let a = try historyRow(["半台直线球", "20 分钟"]); a.tap()
        let note = app.staticTexts["QD-DATA1-A"].firstMatch; try reveal(note)
        try capture("history-A-note")
        // Both entries belong to this opened unique record, not other history rows.
        for _ in 0..<8 { if visible(app.staticTexts["8/10"].firstMatch) { break }; scroll(false) }
        try ready(app.staticTexts["8/10"].firstMatch)
        try ready(app.staticTexts["2/5"].firstMatch); try capture("history-A-two-entries")
        let back = app.navigationBars.buttons.firstMatch; try ready(back); back.tap()
        try ready(app.buttons["统计"].firstMatch)
        app.switchTab(.training); try ready(summary)
        try capture("home-returned"); try checkDay()
    }
    func testNormalGuestStatisticsRangeValuesAndProfileBoundary() throws {
        app.switchTab(.history)
        let stats = app.buttons["统计"].firstMatch; try ready(stats); stats.tap()
        let ranges = [("周", "本周训练天数", 3, 65, 4, "14/27 局/球"),
                      ("月", "本月训练天数", 4, 105, 5, "18/37 局/球"),
                      ("年", "本年训练天数", 5, 185, 6, "24/47 局/球")]
        for (range, dayCaption, days, minutes, sets, mixedSummary) in ranges {
            let chip = app.buttons[range].firstMatch
            for _ in 0..<16 { if visible(chip) { break }; scroll(false) }
            try ready(chip); chip.tap()
            try ready(app.staticTexts[dayCaption].firstMatch)
            try capture("statistics-\(range)-before-bind")
            try metric(dayCaption, equals: days)
            try metric("分钟 · 总时长", equals: minutes)
            try metric("训练组数", equals: sets)
            let mixed = app.staticTexts[mixedSummary].firstMatch; try reveal(mixed)
            try capture("statistics-\(range)-mixed-before-bind")
            let base = mixed.frame
            let peers = app.staticTexts.allElementsBoundByIndex.filter { e in
                visible(e) && abs(e.frame.midY - base.midY) < 12
            }
            try require(peers.contains { $0.label == "\(sets) 组" } && peers.contains { $0.label == "单位混合" }, "Mixed summary not associated with set count/warning row")
            // These are characterization values, never acceptance of mixed-unit division.
        }
        app.switchTab(.profile); try ready(app.buttons["profile.login"])
        try capture("guest-no-month-card")
        for id in ["profile.monthlyOverview.trainingDays", "profile.monthlyOverview.duration", "profile.monthlyOverview.longestStreak"] {
            try require(!app.descendants(matching: .any)[id].exists, "Guest unexpectedly exposes logged-in monthly metric")
        }
        try checkDay()
    }
}
