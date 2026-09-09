import XCTest

/// Draft: exactly one previously observed rectangular scenario, normal entry, no board/result seed.
final class SiluShotDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var output: URL!
    private var sequence = 0
    private var status: XCUIElement { app.staticTexts["navStatus.subtitle"] }
    private struct Stop: Error { let reason: String }
    private func env(_ key: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return e[key] ?? e["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("terminal-before-termination") }
    }
    func testObservedRectangleNextSolutionStrikeAndUndoRestoresBoardAndSolutionIndex() throws {
        try require(env("QD_SILU_SHOT_AUTH") == "EXISTING_004_RECTANGLE_DEVICE_NORMAL_UI", "Authorized existing observed scenario device required")
        let expected = "401DEA72-01DD-46C2-B774-86B7D58BC06C"
        try require(env("QD_SOLVER_DEVICE_UDID") == expected && env("SIMULATOR_UDID")?.uppercased() == expected, "Use only original observed rectangle device, no cross-device coordinates")
        guard let root = env("QD_SHOT_DIR"), root.hasPrefix("/") else { throw Stop(reason: "Absolute new evidence root required") }
        output = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent("silu-shot-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: output.path), "New evidence directory required")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"]
        do {
            app.launch()
            try require(app.wait(for: .runningForeground, timeout: 15), "Actual live process required")
            try require(app.windows.firstMatch.frame.size == CGSize(width: 402, height: 874), "Observed 402x874 viewport required")
            try tab("我的")
            try until("Actual guest required") { self.app.buttons["profile.login"].exists }
            try require(app.buttons["profile.login"].label.contains("游客模式") && !app.buttons["profile.accountHeader"].exists, "No authenticated profile allowed")
            try tab("练习")
            try button("angleHomeTab_解")
            let entry = app.buttons["思路训练"]
            try reveal(entry); try tap(entry)
            try until("Actual Silu page and subtitle required") { self.app.navigationBars["思路训练"].exists && self.status.exists }
            let yellow = try ball("_1")
            try require(abs(yellow.frame.midX - 176.3) <= 2 && abs(yellow.frame.midY - 394.6) <= 2, "Default yellow ball must match the actually observed scenario")
            point(yellow.frame.midX, yellow.frame.midY).tap()
            point(71.6, 201).tap() // Reviewed left-upper pocket on original device.
            try capture("actual-yellow-and-reviewed-pocket-selected")
            try button("落区")
            point(105, 310).press(forDuration: 0.1, thenDragTo: point(295, 640), withVelocity: 250, thenHoldForDuration: 0.2)
            try until("Actual rectangle ready") { self.status.label == "已就绪，点「求解」反解走位" }
            try capture("same-observed-rectangle-ready")
            try button("求解")
            try until("Same positive rectangle must yield multiple solutions", timeout: 120) {
                self.status.label.hasPrefix("解 1/") && self.app.buttons["下一解"].isEnabled && self.app.buttons["击球"].isEnabled
            }
            let total = try solutionTotal(status.label, index: 1)
            try require(total >= 2 && !status.label.contains("最接近解") && !status.label.contains("翻袋备选"), "Expected actual satisfying multiple-solution branch, no weaker substitute")
            try capture("first-solution")
            try button("下一解")
            try until("One Next must select second solution") { self.status.label.hasPrefix("解 2/\(total) · ") }
            try require(!status.label.contains("最接近解") && !status.label.contains("翻袋备选"), "Second solution branch must remain reported satisfying")
            let secondSummary = status.label
            let beforeCue = try ball("cueBall").frame
            let beforeTarget = try ball("_1").frame
            try require(!app.buttons["上一杆"].isEnabled && !app.buttons["回放"].isEnabled, "No prior shot context may exist")
            try capture("second-solution-before-real-shot")
            print("[QD-SiluShot] strikeStart uptime=\(ProcessInfo.processInfo.systemUptime) second=\(secondSummary)")
            try button("击球")
            try until("Actual shot must settle with explicit Silu terminal", timeout: 90) {
                let s = self.status.label
                return (s == "已击打 · 母球停在终点，可继续画约束再求解" || s == "母球进袋（scratch）· 重新摆母球或「恢复默认」") && self.app.buttons["上一杆"].isEnabled
            }
            try require(!app.buttons["击球"].isEnabled && !app.buttons["下一解"].isEnabled, "Shot completion must invalidate old solution for changed board")
            print("[QD-SiluShot] settled uptime=\(ProcessInfo.processInfo.systemUptime) status=\(status.label)")
            try capture("actual-shot-settled-branch-review-required")
            try button("上一杆")
            try until("Actual complete undo status required") { self.status.label == "已退回上一杆击打前 · 球形/约束/解已还原" }
            try require(app.buttons["击球"].isEnabled && app.buttons["下一解"].isEnabled && app.buttons["求解"].isEnabled && !app.buttons["上一杆"].isEnabled && !app.buttons["回放"].isEnabled, "Undo must restore actionable constraint/solution and consume undo context")
            try sameFrame(try ball("cueBall").frame, beforeCue, key: "cueBall")
            try sameFrame(try ball("_1").frame, beforeTarget, key: "_1")
            try capture("undo-restored-original-ball-ids-and-positions")
            // Undo replaces subtitle with explanatory text. One Next independently exposes restored index.
            try button("下一解")
            let nextIndex = total > 2 ? 3 : 1
            try until("Undo must preserve second solution index") { self.status.label.hasPrefix("解 \(nextIndex)/\(total) · ") }
            try capture("verified-restored-index-next-without-resolve")
            let back = app.navigationBars["思路训练"].buttons.matching(identifier: "BackButton")
            try require(back.count == 1, "Exact page-scoped back control required")
            try tap(back.firstMatch)
            try until("Return to actual solving home") { self.app.buttons["angleHomeTab_解"].exists && !self.app.navigationBars["思路训练"].exists }
            try capture("returned-to-normal-home")
        } catch { try capture("failure-before-termination"); throw error }
    }
    private func solutionTotal(_ s: String, index: Int) throws -> Int {
        let prefix = "解 \(index)/"
        try require(s.hasPrefix(prefix), "Expected actual solution index")
        let digits = s.dropFirst(prefix.count).prefix(while: { $0.isNumber })
        guard let n = Int(digits), n >= index else { throw Stop(reason: "Readable solution count required") }
        return n
    }
    private func sameFrame(_ a: CGRect, _ b: CGRect, key: String) throws {
        try require(abs(a.midX-b.midX) <= 2 && abs(a.midY-b.midY) <= 2 && abs(a.width-b.width) <= 2 && abs(a.height-b.height) <= 2, "Restored actual ball frame differs: " + key)
    }
    private func ball(_ key: String) throws -> XCUIElement {
        let q = app.descendants(matching: .any).matching(identifier: key)
        try require(q.count > 0, "Observed semantic ball key missing: " + key)
        let root = q.firstMatch
        try require(root.frame.width > 0 && root.frame.width < 30 && root.frame.height > 0 && root.frame.height < 30, "Require ball-sized outer semantic frame, not hidden mesh descendant")
        return root
    }
    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate { app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)) }
    private func tab(_ title: String) throws {
        try until("Unique real TabBar required") { self.app.tabBars.count == 1 }
        let q = app.tabBars.firstMatch.buttons.matching(identifier: title)
        try require(q.count == 1, "Unique actual Tab required")
        try tap(q.firstMatch)
        try until("Actual Tab selection") { q.firstMatch.isSelected }
    }
    private func button(_ id: String) throws {
        let q = app.buttons.matching(identifier: id)
        try require(q.count == 1, "Unique actual button required: " + id)
        try tap(q.firstMatch)
    }
    private func tap(_ e: XCUIElement) throws {
        try until("Enabled/hittable actual control required") { e.exists && e.isEnabled && e.isHittable }
        try require(!e.frame.isEmpty && app.windows.firstMatch.frame.contains(e.frame), "Full control must lie inside window")
        e.tap()
    }
    private func reveal(_ e: XCUIElement) throws {
        for _ in 0..<10 {
            let bottom = app.tabBars.firstMatch.frame.minY
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.windows.firstMatch.frame.minY
            if e.exists && e.isHittable && !e.frame.isEmpty && app.windows.firstMatch.frame.contains(e.frame) && e.frame.maxY < bottom && e.frame.minY >= top { return }
            try require(app.scrollViews.count == 1, "Unique real home scroll required")
            let s = app.scrollViews.firstMatch
            s.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: s.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: e.exists && e.frame.minY < top ? 0.68 : 0.32)))
        }
        throw Stop(reason: "Entry did not fully clear TabBar")
    }
    private func until(_ reason: String, timeout: TimeInterval = 15, _ body: @escaping () -> Bool) throws {
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)], timeout: timeout) == .completed, reason)
    }
    private func require(_ v: Bool, _ reason: String) throws { if !v { throw Stop(reason: reason) } }
    private func capture(_ stage: String) throws {
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
