import XCTest

/// Unregistered/unrun. New dedicated disk guest; only this run's c012 favorite is removed.
final class LibraryBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var output: URL!
    private let runID = UUID().uuidString
    private var captureIndex = 0
    private enum Failure: Error { case requirement(String) }
    private let query = "直线出杆"
    private let twoResults: Set<String> = ["drill_c009", "drill_c012"]

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal-unclassified") }
    }

    func testBallFilterResetAndFavoriteAddRemoveSurviveProcessRestarts() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_LIBRARY_BOUNDARY") == "NEW_DEDICATED_DISK_GUEST_SIMULATOR", "Require a newly created authorized guest simulator")
        guard let expected = setting("QD_LIBRARY_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              let actual = env["SIMULATOR_UDID"], actual.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Runner device must match the explicitly authorized new UDID") }
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute QD_SHOT_DIR required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        try launchDiskGuest()
        try favorites(expectedPresent: false, stage: "initial-empty-favorites")
        try librarySearch()
        try resultSet(twoResults)
        try capture("search-two-literal-content-ids")
        try tap(app!.buttons["badgeFilterMenu"])
        try tap(app!.buttons["ballTypeMenu_9球"])
        try resultSet(["drill_c009"])
        try require(app!.buttons["badgeFilterMenu"].label == "筛选，已选 1 项", "Ball filter must actually be active")
        try capture("nine-ball-keeps-universal-c009-excludes-c012")
        try tap(app!.buttons["badgeFilterMenu"])
        try tap(app!.buttons["清除筛选"])
        try resultSet(twoResults)
        try require(app!.buttons["badgeFilterMenu"].label == "筛选球种与精讲", "Menu filter reset must be reflected in state")
        try require(app!.textFields["librarySearchField"].value as? String == query, "Menu reset must preserve the search query")
        try capture("filter-reset-restores-exact-two-ids")

        try openC012()
        try tap(app!.buttons["收藏"])
        try exists(app!.buttons["取消收藏"])
        try capture("c012-favorited-normal-detail")
        try back()
        try favorites(expectedPresent: true, stage: "favorited-before-process-restart")
        try restart()
        try favorites(expectedPresent: true, stage: "favorite-survives-first-process-restart")
        try librarySearch()
        try resultSet(twoResults)
        try openC012()
        try exists(app!.buttons["取消收藏"])
        try tap(app!.buttons["取消收藏"])
        try exists(app!.buttons["收藏"])
        try require(!app!.buttons["取消收藏"].exists, "Unfavorite must change the actual detail control")
        try capture("only-this-run-c012-unfavorited")
        try back()
        try favorites(expectedPresent: false, stage: "empty-after-normal-unfavorite")
        try restart()
        try favorites(expectedPresent: false, stage: "unfavorite-survives-second-process-restart")
        try librarySearch()
        try resultSet(twoResults)
        try openC012()
        try exists(app!.buttons["收藏"])
        try require(!app!.buttons["取消收藏"].exists, "Deleted favorite must not return after process relaunch")
        try capture("verified-final-c012-not-favorited-source-still-present")
        print("[QD-LibraryBoundary] exact search set c009+c012 -> 9ball c009 -> reset c009+c012; c012 add persisted across restart; normal removal persisted across second restart; guest only")
    }

    private func launchDiskGuest() throws {
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application
        application.launch()
        try require(application.wait(for: .runningForeground, timeout: 15), "App must reach foreground")
        try tab("我的")
        try exists(application.buttons["profile.login"])
        try require(application.buttons["profile.login"].label.contains("游客模式"), "Refuse to change an authenticated user's favorites")
        try require(!application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch.exists, "No account fixture or real account allowed")
    }
    private func restart() throws {
        guard let app else { throw Failure.requirement("No process to restart") }
        app.terminate()
        try require(app.wait(for: .notRunning, timeout: 10), "Old app process must actually end")
        print("[QD-LibraryBoundary] old process confirmed notRunning; no reset/clear/in-memory argument; monotonic=\(ProcessInfo.processInfo.systemUptime)")
        try launchDiskGuest()
    }
    private func favorites(expectedPresent: Bool, stage: String) throws {
        try tab("我的")
        let link = app!.staticTexts["我的收藏"].firstMatch
        try revealProfileRow(link)
        try tap(link)
        try exists(app!.navigationBars["我的收藏"])
        let empty = app!.staticTexts["还没有收藏"]
        let title = app!.staticTexts.matching(NSPredicate(format: "label == %@", "中袋直线出杆"))
        if expectedPresent {
            try until("The newly favorited c012 must be visible once") { title.count == 1 && !empty.exists }
        } else {
            try exists(empty)
            try require(title.count == 0, "c012 must be absent from the loaded empty favorite view")
        }
        try capture(stage)
        // FavoriteDrillsView hides the TabBar; always return before switching tabs.
        try back()
    }
    private func librarySearch() throws {
        try tab("动作库")
        let field = app!.textFields["librarySearchField"]
        try exists(field)
        if app!.buttons["清除搜索"].exists { try tap(app!.buttons["清除搜索"]) }
        try tap(field)
        let intro = app!.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.exists { try tap(app!.buttons["Continue"]) }
        field.typeText(query + "\n")
        try require(field.value as? String == query, "Normal search text must actually be entered")
        try until("Keyboard must close before observing cards") { !self.app!.keyboards.firstMatch.exists }
    }
    private func resultSet(_ ids: Set<String>) throws {
        let cards = app!.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "drillCard_"))
        let expected = Set(ids.map { "drillCard_" + $0 })
        try until("Actual filtered card set must equal \(ids.sorted())") {
            let current = cards.allElementsBoundByIndex
            return current.count == expected.count && Set(current.map(\.identifier)) == expected
        }
        // This two-card query is deliberately bounded; do not count a partial lazy full library.
        let bar = app!.tabBars.firstMatch
        try exists(bar)
        for card in cards.allElementsBoundByIndex {
            try require(!card.frame.isEmpty && app!.windows.firstMatch.frame.contains(card.frame)
                        && card.frame.maxY < bar.frame.minY,
                        "Both literal result cards must be fully visible; otherwise retain AX observation limitation")
        }
        print("[QD-LibraryBoundary] visible exact result IDs=\(cards.allElementsBoundByIndex.map(\.identifier).sorted())")
    }
    private func openC012() throws {
        let card = app!.buttons["drillCard_drill_c012"]
        try tap(card)
        // Queue003 actual AX: untitled Hosting NavigationBar; title is body text.
        let title = app!.staticTexts.matching(NSPredicate(format: "label == %@", "中袋直线出杆"))
        try until("c012 detail must show its exact body title once") { title.count == 1 }
        try exists(app!.buttons["addToTrainingButton"])
        try exists(app!.buttons["bottomTryoutButton"])
        let viewport = app!.descendants(matching: .any).matching(identifier: "drillSceneTableViewport").firstMatch
        try exists(viewport)
        try require(viewport.label == "球桌回放" && !viewport.frame.isEmpty, "The actual detail scene viewport must be present")
        let backButton = app!.navigationBars.buttons["BackButton"]
        try until("Detail must retain an actionable normal return control") {
            backButton.exists && backButton.label == "返回" && backButton.isEnabled && backButton.isHittable
        }
    }
    private func revealProfileRow(_ row: XCUIElement) throws {
        let bar = app!.tabBars.firstMatch
        try exists(bar)
        for _ in 0..<6 {
            if row.exists, row.isHittable, !row.frame.isEmpty,
               app!.windows.firstMatch.frame.contains(row.frame), row.frame.maxY < bar.frame.minY { return }
            let candidates = app!.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > $0.frame.width }
            try require(candidates.count == 1, "Observe one profile vertical ScrollView before scrolling")
            let scroll = candidates[0]
            let top = max(scroll.frame.minY, app!.windows.firstMatch.frame.minY)
            let bottom = min(scroll.frame.maxY, bar.frame.minY)
            try require(bottom > top, "Profile viewport must be usable")
            let distance = (bottom - top) / 8
            let center = (top + bottom) / 2
            let sign: CGFloat = row.exists && row.frame.minY < top ? -1 : 1
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center + sign * distance / 2 - scroll.frame.minY))
            let to = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: center - sign * distance / 2 - scroll.frame.minY))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        throw Failure.requirement("Profile favorites row not fully exposed; no guessed screen tap")
    }
    private func tab(_ name: String) throws { try exists(app!.tabBars.firstMatch); try tap(app!.tabBars.firstMatch.buttons[name]) }
    private func back() throws { try tap(app!.navigationBars.buttons.firstMatch) }
    private func exists(_ element: XCUIElement) throws { try require(element.waitForExistence(timeout: 12), "Missing element: \(element)") }
    private func tap(_ element: XCUIElement) throws {
        try until("Element must be actionable: \(element)") { element.exists && element.isHittable && element.isEnabled }
        element.tap()
    }
    private func until(_ message: String, _ predicate: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: 12) == .completed, message)
    }
    private func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.requirement(message) } }
    private func capture(_ stage: String) throws {
        guard let app else { throw Failure.requirement("No app for capture") }
        captureIndex += 1
        let stem = "library-boundary-\(runID)-\(captureIndex)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
