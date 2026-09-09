import XCTest

/// Fixed c042 content verified against snapshot-004, reached through the normal library UI.
final class DetailJourneyDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    private let drillTitle = "初级蛇彩"
    private var output: URL!
    private func setting(_ key: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        return env[key] ?? env["TEST_RUNNER_" + key]
    }
    private func require(_ value: Bool, _ reason: String) throws {
        guard value else { XCTFail(reason); throw NSError(domain: "QDDetail", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]) }
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        let expected = try XCTUnwrap(setting("QD_DETAIL_DEVICE_UDID"))
        try require(!expected.isEmpty && setting("SIMULATOR_UDID") == expected, "Wrong dedicated simulator")
        let path = try XCTUnwrap(setting("QD_SHOT_DIR"))
        try require(path.hasPrefix("/"), "Absolute evidence directory required")
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let probe = output.appendingPathComponent("write-probe-" + runID)
        try Data("probe".utf8).write(to: probe, options: .withoutOverwriting)
        try FileManager.default.removeItem(at: probe)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forceNonPremium"]
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 20), "Single launch failed")
        app.switchTab(.profile)
        try ready(app.buttons["profile.login"])
        try require(!app.descendants(matching: .any)["profile.accountHeader"].exists, "Expected dedicated guest")
        try capture("guest-free-before")
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil && output != nil { try capture("teardown") }
    }
    private func visible(_ e: XCUIElement) -> Bool {
        guard e.exists else { return false }
        let r = e.frame, w = app.windows.firstMatch.frame
        guard !r.isEmpty, r.minX.isFinite, r.minY.isFinite, w.contains(r) else { return false }
        if e.identifier.hasPrefix("tutorialSection_") {
            let scrolls = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && !$0.frame.isEmpty }
            if scrolls.count != 1 || !scrolls[0].frame.contains(r) { return false }
        }
        let tab = app.tabBars.firstMatch
        if tab.exists && tab.isHittable && r.maxY > tab.frame.minY { return false }
        let nav = app.navigationBars.firstMatch
        if nav.exists && nav.isHittable && !nav.frame.contains(r) && r.minY < nav.frame.maxY { return false }
        return true
    }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 20) throws {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: timeout) == .completed && visible(e), "Expected unoccluded actionable element: \(e)")
    }
    private func scrollingBounds() throws -> CGRect {
        let views = app.scrollViews.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && !$0.frame.isEmpty }
        try require(views.count == 1, "Expected unique active scroll container")
        var r = views[0].frame.intersection(app.windows.firstMatch.frame)
        let nav = app.navigationBars.firstMatch, tab = app.tabBars.firstMatch
        if nav.exists && nav.isHittable { let y = max(r.minY, nav.frame.maxY); r = CGRect(x:r.minX, y:y, width:r.width, height:max(0,r.maxY-y)) }
        if tab.exists && tab.isHittable { r.size.height = max(0,min(r.maxY,tab.frame.minY)-r.minY) }
        try require(r.width > 0 && r.height > 100, "Invalid active scrolling bounds")
        return r
    }
    private func recordScroll(_ e: XCUIElement, phase: String, step: Int, bounds: CGRect) throws {
        let row: [String: Any] = ["phase":phase, "step":step, "uptime":ProcessInfo.processInfo.systemUptime,
            "target":e.exists ? e.identifier : "not-yet-materialized", "exists":e.exists, "frame":e.exists ? NSCoder.string(for:e.frame) : "absent",
            "bounds":NSCoder.string(for:bounds)]
        var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]); data.append(10)
        let url = output.appendingPathComponent("scroll-" + runID + ".jsonl")
        if !FileManager.default.fileExists(atPath:url.path) { try data.write(to:url, options:.withoutOverwriting) }
        else { let h = try FileHandle(forWritingTo:url); try h.seekToEnd(); try h.write(contentsOf:data); try h.close() }
    }
    private func settle(_ e: XCUIElement) throws {
        var previous: CGRect?
        var stable = 0
        let p = NSPredicate { _, _ in
            guard e.exists else { return true }
            let frame = e.frame
            if let old = previous, abs(old.minY-frame.minY)<0.5 && abs(old.height-frame.height)<0.5 { stable += 1 } else { stable = 0 }
            previous = frame
            return stable >= 2
        }
        try require(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:p, object:nil)], timeout:6) == .completed, "Scroll target did not settle")
    }
    private func reveal(_ e: XCUIElement) throws {
        // Search budget is unchanged; a near, measurable image has a separate bounded alignment phase.
        for step in 0..<16 {
            if visible(e) { return }
            let r = try scrollingBounds()
            try recordScroll(e, phase:"search-before", step:step, bounds:r)
            if e.exists && e.frame.intersects(r) { break }
            let up = !e.exists || e.frame.minY >= r.minY
            let origin = app.coordinate(withNormalizedOffset:.zero)
            let start = origin.withOffset(CGVector(dx:r.midX,dy:r.minY+r.height*(up ? 0.75 : 0.25)))
            let end = origin.withOffset(CGVector(dx:r.midX,dy:r.minY+r.height*(up ? 0.25 : 0.75)))
            start.press(forDuration:0.05,thenDragTo:end)
        }
        var previousOverflow: CGFloat?
        var noProgress = 0
        for step in 0..<4 {
            try settle(e)
            let r = try scrollingBounds()
            try recordScroll(e,phase:"align-before",step:step,bounds:r)
            if visible(e) { return }
            try require(e.exists && e.frame.height <= r.height && e.frame.width <= r.width, "Target missing or larger than active viewport")
            let f = e.frame
            let overflow = max(0,r.minY-f.minY)+max(0,f.maxY-r.maxY)
            if let old = previousOverflow, overflow >= old-1 { noProgress += 1 } else { noProgress = 0 }
            try require(noProgress < 2,"Alignment made no progress twice")
            previousOverflow = overflow
            let dy = max(-r.height*0.5,min(r.height*0.5,(r.midY-f.midY)*0.6))
            let origin = app.coordinate(withNormalizedOffset:.zero)
            let startY = dy > 0 ? r.minY+r.height*0.25 : r.minY+r.height*0.75
            let start = origin.withOffset(CGVector(dx:r.midX,dy:startY))
            let end = origin.withOffset(CGVector(dx:r.midX,dy:startY+dy))
            start.press(forDuration:0.05,thenDragTo:end,withVelocity:XCUIGestureVelocity.slow,thenHoldForDuration:0.3)
        }
        try settle(e)
        try recordScroll(e,phase:"align-final",step:4,bounds:scrollingBounds())
        try require(visible(e), "Bounded search and alignment failed")
    }
    private func text(_ fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
    private func readCaption(_ fragment: String, revealFirst: Bool = true) throws {
        if revealFirst { try reveal(text(fragment)) }
        let hits = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).allElementsBoundByIndex.filter(visible)
        try require(hits.count == 1, "Caption must have one visible node: " + fragment)
    }
    private func capture(_ stage: String) throws {
        let dir = try XCTUnwrap(output)
        let stem = "detail-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(runID)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let hierarchy = XCTAttachment(string: ax); hierarchy.name = stem + "-AX"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        try Data(ax.utf8).write(to: dir.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
    private func openC042() throws {
        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]; try ready(search); search.tap()
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.waitForExistence(timeout: 2) {
            let controls = app.buttons.matching(NSPredicate(format: "label == %@", "Continue"))
            try require(controls.count == 1 && controls.firstMatch.isHittable, "Observed keyboard introduction requires unique Continue")
            controls.firstMatch.tap()
            try require(intro.waitForNonExistence(timeout: 8), "Keyboard introduction did not dismiss")
        }
        search.typeText(drillTitle + "\n")
        try require(search.value as? String == drillTitle, "Exact c042 search required")
        let card = app.descendants(matching: .any).matching(identifier: "drillCard_drill_c042").firstMatch
        try ready(card); card.tap()
        try require(app.staticTexts[drillTitle].waitForExistence(timeout: 20) && app.buttons["bottomTryoutButton"].exists, "Exact c042 body title and detail-only tryout action required")
        try ready(app.buttons["bottomTryoutButton"])
        try capture("detail")
    }
    private func backToDetail() throws {
        let back = app.navigationBars.buttons.firstMatch; try ready(back); back.tap()
        try require(app.staticTexts[drillTitle].waitForExistence(timeout: 20) && app.buttons["bottomTryoutButton"].exists, "Exact c042 body title and detail-only tryout action required")
        try ready(app.buttons["bottomTryoutButton"])
    }
    private func backToLibrary() throws {
        let back = app.navigationBars.buttons.firstMatch; try ready(back); back.tap()
        try ready(app.textFields["librarySearchField"])
        try require(app.textFields["librarySearchField"].value as? String == drillTitle, "Search text changed")
        try ready(app.descendants(matching: .any).matching(identifier: "drillCard_drill_c042").firstMatch)
        try capture("library-returned")
    }

    func testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition() throws {
        do {
        try openC042()
        let tutorial = app.buttons["查看精讲"].firstMatch; try reveal(tutorial); try ready(tutorial); tutorial.tap()
        let picker = app.segmentedControls["tutorialFormationPicker"]; try ready(picker)
        let first = picker.buttons["球形1：首杆八起点阶梯"]
        let second = picker.buttons["球形2：五球连续蛇彩"]
        try require(first.isSelected, "Required state assertion failed")
        let firstPoster = app.buttons["tutorialSection_第八杆：1号球 · 左侧中袋"]
        try reveal(firstPoster); try ready(firstPoster)
        try readCaption("第8杆：约 18°")
        try require(!(app.buttons["tutorialSection_第五杆：5号球 · 左下角袋"].isHittable), "Forbidden state assertion failed")
        try capture("tutorial-f1-eighth-shot")
        try ready(second); second.tap(); try require(second.isSelected, "Required state assertion failed")
        let secondInitial = app.buttons["tutorialSection_开局与击球顺序"]
        try reveal(secondInitial); try ready(secondInitial)
        try readCaption("开局：五球连打，先左中袋再右中袋，角袋收尾")
        try capture("tutorial-f2-opening")
        let secondPoster = app.buttons["tutorialSection_第五杆：5号球 · 左下角袋"]
        try reveal(secondPoster); try ready(secondPoster)
        try readCaption("第5杆：约 3°")
        try require(!(firstPoster.isHittable), "Forbidden state assertion failed")
        try capture("tutorial-f2-fifth-shot")
        try ready(first); first.tap(); try require(first.isSelected, "Required state assertion failed")
        // Do not reveal: this assertion tests retained per-formation scroll position.
        try readCaption("第8杆：约 18°", revealFirst: false)
        try require(!(secondPoster.isHittable), "Forbidden state assertion failed")
        try capture("tutorial-f1-position-restored")
        try backToDetail()
        try backToLibrary()
            } catch {
            try capture("failure-before-termination")
            throw error
        }
    }

    func testC042BothTryoutBoardsStrikeUndoAndRearrange() throws {
        do {
        try openC042()
        for (index, count, balls) in [(0, 8, 3), (1, 5, 5)] {
            let tryout = app.buttons["bottomTryoutButton"]; try ready(tryout); tryout.tap()
            try require(app.navigationBars["选择球形"].waitForExistence(timeout: 15), "Required state assertion failed")
            let row = app.buttons["tryoutFormation_\(index)"]; try ready(row)
            // Check the selected row's identity and source-derived dose, not another row's text.
            try require(row.label.contains("球形\(index + 1)"), "Required state assertion failed")
            try require(row.label.contains("\(count) 杆"), "Required state assertion failed")
            try require(row.label.contains("\(balls) 球"), "Required state assertion failed")
            try capture("formation-\(index + 1)-choice")
            row.tap()
            try ready(app.buttons["tryoutMode_序列"], timeout: 30)
            let brief = app.descendants(matching: .any).matching(identifier: "tryout.briefCard").firstMatch
            try require(brief.waitForExistence(timeout: 12), "Required state assertion failed")
            try require(text("本局共 \(count) 杆").waitForExistence(timeout: 12), "Required state assertion failed")
            try require(!(text("本局共 \(count == 8 ? 5 : 8) 杆").exists), "Forbidden state assertion failed")
            try capture("formation-\(index + 1)-initial")
            let free = app.buttons["tryoutMode_自由"]; try ready(free); free.tap()
            let strike = app.buttons["击球"].firstMatch
            let undo = app.buttons["重打"].firstMatch
            let replay = app.buttons["回放"].firstMatch
            try ready(strike, timeout: 30)
            try require(!(undo.isEnabled), "Forbidden state assertion failed")
            try capture("formation-\(index + 1)-free-before-shot")
            strike.tap()
            try ready(undo, timeout: 60)
            try ready(replay, timeout: 15)
            try capture("formation-\(index + 1)-after-shot")
            undo.tap()
            try ready(strike, timeout: 30)
            try require(!(undo.isEnabled), "Forbidden state assertion failed")
            try capture("formation-\(index + 1)-undo")
            let rearrange = app.buttons["tryout.rearrange"]; try ready(rearrange); rearrange.tap()
            try ready(strike, timeout: 30)
            try require(!(replay.isEnabled), "Forbidden state assertion failed")
            try capture("formation-\(index + 1)-rearranged")
            try backToDetail()
        }
        try backToLibrary()
            } catch {
            try capture("failure-before-termination")
            throw error
        }
    }
}
