import XCTest

/// Review draft only. Literal independent frozen-index oracle; no production store access.
final class LibraryCategoryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var output: URL?
    private var sequence = 0
    private struct Stop: Error { let reason: String }
    private let prefix = "drillCard_"
    private let positioning: Set<String> = Set([18,20,21,30,31,5,34,35,36,37,38,39,40,41,42,79,80,81,82,46,50,51,69,71].map { String(format: "drill_c%03d", $0) })
    private let straight: Set<String> = Set([12,9,22,1,72,39].map { String(format: "drill_c%03d", $0) })
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil, output != nil { try capture("terminal-before-termination") }
    }
    func testPositioningExactPrimaryAndSecondarySetThenAllResetWithSearch() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_LIBRARY_CATEGORY_AUTH") == "NEW_DEDICATED_DISK_GUEST", "Require dedicated new guest device")
        guard let expected = setting("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              setting("SIMULATOR_UDID")?.lowercased() == expected.lowercased(),
              let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else { throw Stop(reason: "Device/evidence guard failed") }
        let dir = URL(fileURLWithPath: path).appendingPathComponent("library-category-" + UUID().uuidString)
        try require(!FileManager.default.fileExists(atPath: dir.path), "Evidence leaf must be new")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true); output = dir
        let a = XCUIApplication(); app = a
        a.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        a.launch()
        try require(a.wait(for: .runningForeground, timeout: 15), "Foreground launch")
        try tab("我的")
        try wait("Actual guest header") { a.buttons["profile.login"].exists && a.buttons["profile.login"].label.contains("游客模式") }
        try require(!a.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch.exists, "No account")
        try tab("动作库")
        try wait("Loaded library") { a.buttons["drillCard_drill_c012"].exists }
        try require(!a.buttons["清除搜索"].exists && a.buttons["badgeFilterMenu"].label == "筛选球种与精讲", "Initial unfiltered normal library required")
        try capture("initial-all-baseline-top-only")
        try tapUnique(a.buttons.matching(identifier: "sidebar_走位"))
        try wait("Positioning filter loaded at top") {
            let ids = self.loadedIDs()
            return ids.contains("drill_c018") && !ids.isEmpty && ids.isSubset(of: self.positioning)
        }
        try collect(expected: positioning, stage: "positioning-all-24", maxMoves: 32)
        // Keep category selected, add a query with an independent, discriminating intersection.
        let field = a.textFields["librarySearchField"]
        try tapUnique(a.textFields.matching(identifier: "librarySearchField"))
        let intro = a.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.waitForExistence(timeout: 2) {
            try tapUnique(a.buttons.matching(identifier: "Continue"))
            try require(intro.waitForNonExistence(timeout: 8), "Keyboard intro must close")
        }
        try require(a.keyboards.firstMatch.waitForExistence(timeout: 8), "Real editing keyboard")
        field.typeText("直线\n")
        try wait("Query committed with keyboard closed") { field.value as? String == "直线" && !a.keyboards.firstMatch.exists }
        try wait("Positioning and query intersection") { self.loadedIDs() == ["drill_c039"] }
        try collect(expected: ["drill_c039"], stage: "positioning-plus-straight-one", maxMoves: 8)
        try tapUnique(a.buttons.matching(identifier: "sidebar_全部"))
        try wait("Reset category preserves query and restores non-positioning IDs") {
            field.value as? String == "直线" && self.loadedIDs().contains("drill_c012") && self.loadedIDs().isSubset(of: self.straight)
        }
        try collect(expected: straight, stage: "all-plus-straight-six", maxMoves: 14)
        try require(field.value as? String == "直线", "Category reset must preserve normal query")
        try capture("verified-category-reset-six-exact-ids")
    }
    private func loadedIDs() -> Set<String> {
        Set(app!.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex.map { String($0.identifier.dropFirst(prefix.count)) })
    }
    private func resultScroll() throws -> XCUIElement {
        let candidates = app!.scrollViews.allElementsBoundByIndex.filter {
            $0.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).count > 0
        }
        try require(candidates.count == 1, "Exactly one actual ScrollView containing result cards; not whole-page scroll")
        return candidates[0]
    }
    private func viewport(_ scroll: XCUIElement) throws -> CGRect {
        let bars = app!.tabBars
        try require(bars.count == 1 && !bars.firstMatch.frame.isEmpty, "Unique real TabBar")
        var r = scroll.frame.intersection(app!.windows.firstMatch.frame)
        r.size.height = min(r.maxY, bars.firstMatch.frame.minY) - r.minY
        try require(!r.isEmpty && r.height > 100, "Usable actual results viewport")
        return r
    }
    private func signature(_ scroll: XCUIElement) throws -> [String] {
        let bounds = try viewport(scroll)
        return scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && bounds.intersects($0.frame)
        }.map { "\($0.identifier):\(Int(($0.frame.minY * 2).rounded())):\(Int(($0.frame.maxY * 2).rounded()))" }.sorted()
    }
    private func settle(_ scroll: XCUIElement) throws -> [String] {
        var previous: [String] = []; var since = ProcessInfo.processInfo.systemUptime
        try wait("Actual result frames stabilize") {
            guard let now = try? self.signature(scroll), !now.isEmpty else { return false }
            if now != previous { previous = now; since = ProcessInfo.processInfo.systemUptime; return false }
            return ProcessInfo.processInfo.systemUptime - since >= 0.7
        }
        return previous
    }
    private func collect(expected: Set<String>, stage: String, maxMoves: Int) throws {
        var seen = Set<String>(); var last: [String] = []; var unchanged = 0
        for step in 0...maxMoves {
            let scroll = try resultScroll(); let stable = try settle(scroll); let bounds = try viewport(scroll)
            let cards = scroll.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex
            let loaded = cards.map { String($0.identifier.dropFirst(prefix.count)) }
            try require(Set(loaded).count == loaded.count, "Duplicate AX card identifiers in results")
            try require(Set(loaded).isSubset(of: expected), "Unexpected result ID: \(Set(loaded).subtracting(expected).sorted())")
            for card in cards where !card.frame.isEmpty && bounds.contains(card.frame) {
                seen.insert(String(card.identifier.dropFirst(prefix.count)))
            }
            try capture("\(stage)-step-\(step)")
            print("[QD-LibraryCategory] stage=\(stage) step=\(step) seen=\(seen.sorted()) frames=\(stable)")
            unchanged = stable == last ? unchanged + 1 : 0
            // Two real forward gestures with unchanged stable viewport, plus complete exact union.
            if unchanged >= 2 {
                try require(seen == expected, "Stable scroll endpoint missing IDs: \(expected.subtracting(seen).sorted()); not a passing partial lazy list")
                return
            }
            try require(step < maxMoves, "Finite scroll budget exhausted without endpoint")
            last = stable
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let x = bounds.midX-scroll.frame.minX
            let y = bounds.midY-scroll.frame.minY
            // One third viewport with overlap; no screen-coordinate constant, no swipe on sidebar.
            origin.withOffset(CGVector(dx: x, dy: y+bounds.height/6)).press(forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: y-bounds.height/6)))
        }
    }
    private func tab(_ label: String) throws {
        try wait("Unique TabBar") { self.app!.tabBars.count == 1 }
        try tapUnique(app!.tabBars.firstMatch.buttons.matching(NSPredicate(format: "label == %@", label)))
    }
    private func tapUnique(_ query: XCUIElementQuery) throws {
        try wait("Unique actionable control") { query.count == 1 && query.element.isEnabled && query.element.isHittable }
        let e = query.element
        try require(app!.windows.firstMatch.frame.contains(e.frame) && !e.frame.isEmpty, "Control frame within window")
        if !app!.tabBars.firstMatch.buttons.allElementsBoundByIndex.contains(where: { $0.identifier == e.identifier && $0.frame == e.frame }), app!.tabBars.count == 1 {
            try require(e.frame.maxY <= app!.tabBars.firstMatch.frame.minY, "Control not covered by TabBar")
        }
        e.tap()
    }
    private func wait(_ why: String, _ body: @escaping () -> Bool) throws {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)
        try require(XCTWaiter.wait(for: [e], timeout: 12) == .completed, why)
    }
    private func require(_ yes: Bool, _ why: String) throws { if !yes { throw Stop(reason: why) } }
    private func capture(_ stage: String) throws {
        guard let app, let output else { throw Stop(reason: "No initialized capture") }
        sequence += 1; let stem = "\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem+".png"), options: .withoutOverwriting)
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let ax = app.debugDescription
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem+".txt"), options: .withoutOverwriting)
        let text = XCTAttachment(string: ax); text.name = stem+"-AX"; text.lifetime = .keepAlways; add(text)
    }
}
