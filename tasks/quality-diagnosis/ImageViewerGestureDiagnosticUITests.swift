import XCTest

/// Normal c001 gallery continuation, based on archived actual observation003.
/// Complete PNG review remains required for visual zoom and image replacement.
final class ImageViewerGestureDiagnosticUITests: XCTestCase {
    private let expectedDeviceUDID = "249B8998-B4A5-4F3C-ACED-173D0C290355"
    private var app: XCUIApplication?
    private var output: URL?
    private var sequence = 0
    // Conservative exclusion band reviewed for the 402x874 portrait iPhone 17 Pro.
    // This is NOT a measured safeAreaInsets value.
    private let bottomExclusionBand: CGFloat = 44
    private enum Page { case library, detail, tutorial }
    private struct Stop: Error { let reason: String }

    private func setting(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        try require(UUID(uuidString: expectedDeviceUDID) != nil, "Replace reviewed device placeholder before registration; never run on an arbitrary device")
        try require(setting("QD_IMAGE_VIEWER_AUTH") == "NEW_EMPTY_IMAGE_VIEWER_DEVICE", "Dedicated new guest device authorization required")
        try require(setting("QD_IMAGE_VIEWER_DEVICE_UDID")?.uppercased() == expectedDeviceUDID.uppercased() &&
                    ProcessInfo.processInfo.environment["SIMULATOR_UDID"]?.uppercased() == expectedDeviceUDID.uppercased(),
                    "Dedicated image viewer device mismatch")
        guard let root = setting("QD_SHOT_DIR"), root.hasPrefix("/"), root != "/" else {
            throw Stop(reason: "Absolute new evidence root required")
        }
        let leaf = URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent("image-viewer-gesture-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: leaf.path), "Refuse existing observation leaf")
        try FileManager.default.createDirectory(at: leaf, withIntermediateDirectories: true)
        output = leaf
    }

    func testNormalUnzoomedGallerySwipeAndCloseContrast() throws {
        let application = XCUIApplication()
        app = application
        do {
            try require(application.state == .notRunning, "New observation App must not already be running")
            application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                                           "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore",
                                           "-v51.followSystemAppearance"]
            application.launch()
            try require(application.wait(for: .runningForeground, timeout: 20), "Normal single launch did not foreground")
            try selectTab("我的", in: application)
            let login = application.buttons["profile.login"]
            try require(login.waitForExistence(timeout: 12) && login.label.contains("游客模式") &&
                        !application.buttons["profile.accountHeader"].exists, "Actual guest presentation required")
            try capture("guest-before-normal-entry", in: application)

            try selectTab("动作库", in: application)
            let search = application.textFields["librarySearchField"]
            try tap(search)
            search.typeText("半台直线球\n")
            try require(search.value as? String == "半台直线球", "Exact c001 search required")
            let card = application.descendants(matching: .any).matching(identifier: "drillCard_drill_c001").firstMatch
            try reveal(card, page: .library, in: application)
            try tap(card)
            try require(application.staticTexts["半台直线球"].firstMatch.waitForExistence(timeout: 12), "Normal c001 detail title missing")
            let tutorial = application.buttons["查看精讲"].firstMatch
            try reveal(tutorial, page: .detail, in: application)
            try tap(tutorial)
            try require(application.navigationBars.staticTexts["精讲"].firstMatch.waitForExistence(timeout: 12), "Normal tutorial navigation missing")
            let poster = application.buttons["tutorialSection_开局与击球顺序"]
            try capture("tutorial-entry-before-initial-reveal", in: application)
            try reveal(poster, page: .tutorial, in: application)
            try require(poster.identifier == "tutorialSection_开局与击球顺序" && poster.label == "进入全屏幕", "Must tap actual initial poster, not section card")
            try capture("tutorial-before-poster-tap", in: application)
            let originalPosterFrame = poster.frame
            try tap(poster) // Exactly one normal poster tap.
            try require(application.wait(for: .runningForeground, timeout: 10), "App left foreground after poster tap")
            try capture("after-poster-tap-observation", in: application)
            let pageOne = application.staticTexts["1 / 6"]
            try require(pageOne.waitForExistence(timeout: 12), "Actual first of six images required")
            let collections = application.collectionViews
            try require(collections.count == 1, "Actual observed gallery CollectionView required")
            let gallery = collections.firstMatch
            let cell = gallery.cells.firstMatch
            try require(cell.images.count == 1, "Actual first visible cell single media image required")
            let media = cell.images.firstMatch
            let initialFrame = media.frame
            try require(abs(initialFrame.minX) < 1 && abs(initialFrame.minY-68.3) < 2 && abs(initialFrame.width-402) < 1 && abs(initialFrame.height-715) < 2, "Media must match observed initial gallery viewport")
            // Independent contrast: no zoom; one normal XCTest CollectionView swipe.
            gallery.swipeLeft()
            let pageTwo = application.staticTexts["2 / 6"]
            let didAdvance = pageTwo.waitForExistence(timeout: 12) && pageTwo.isHittable
            if didAdvance {
                let secondCaption = gallery.staticTexts["第1杆：约 4°"]
                try require(secondCaption.waitForExistence(timeout: 12) && secondCaption.isHittable && application.windows.firstMatch.frame.contains(secondCaption.frame), "Actual visible second image caption required")
            }
            try capture("one-normal-swipe-actual-terminal", in: application)
            let close = application.buttons["xmark.circle.fill"]
            try require(close.exists && close.label == "关闭", "Observed explicit close button required")
            try tap(close)
            try require(close.waitForNonExistence(timeout: 12) && !pageTwo.exists, "Gallery must close")
            try require(poster.exists && poster.isHittable && application.navigationBars.staticTexts["精讲"].firstMatch.exists, "Return to original tutorial poster required")
            try require(abs(poster.frame.midX-originalPosterFrame.midX) <= 2 && abs(poster.frame.midY-originalPosterFrame.midY) <= 2, "Return must retain original poster scroll position without extra scrolling")
            try capture("closed-original-tutorial-position", in: application)
            try require(didAdvance, "One ordinary unzoomed swipe did not show second image; close result preserved separately")
        } catch {
            do { try capture("failure-before-termination", in: application) }
            catch let evidenceError { XCTFail("Failure evidence could not be saved: \(evidenceError)"); throw evidenceError }
            throw error
        }
    }

    override func tearDownWithError() throws {
        guard let app else { return }
        defer { app.terminate() }
        if output != nil { try capture("terminal-before-termination", in: app) }
        // No guessed dismissal action. Termination ends only this observation process.
    }
    private func selectTab(_ title: String, in app: XCUIApplication) throws {
        let tab = app.tabBars.buttons[title]
        try tap(tab)
        let condition = NSPredicate(format: "selected == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: condition, object: tab)], timeout: 10) == .completed,
                    "Actual selected tab required: \(title)")
    }
    private func tap(_ element: XCUIElement) throws {
        let condition = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: condition, object: element)], timeout: 15) == .completed,
                    "Action element not ready: \(element)")
        element.tap()
    }
    private func bounds(page: Page, in app: XCUIApplication) throws -> (CGRect, XCUIElement) {
        let window = app.windows.firstMatch.frame
        try require(window.width == 402 && window.height == 874, "Reviewed 402x874 portrait iPhone 17 Pro window required")
        let nav = app.navigationBars.firstMatch
        var top = window.minY
        var bottom = window.maxY - bottomExclusionBand
        switch page {
        case .library:
            let tabs = app.tabBars.firstMatch
            try require(tabs.exists && !tabs.frame.isEmpty && tabs.isHittable && window.intersects(tabs.frame),
                        "Library contract requires actual visible bottom TabBar")
            bottom = min(bottom, tabs.frame.minY)
            if nav.exists && !nav.frame.isEmpty { top = max(top, nav.frame.maxY) }
        case .detail, .tutorial:
            // DrillDetailView hides the TabBar; tutorial remains on that navigation stack.
            try require(nav.exists && !nav.frame.isEmpty && window.intersects(nav.frame),
                        "Detail/tutorial actual navigation bar required")
            top = max(top, nav.frame.maxY)
            let tabs = app.tabBars.firstMatch
            try require(!(tabs.exists && tabs.isHittable), "Unexpected visible TabBar on hidden-tab detail/tutorial route")
        }
        let safe = CGRect(x: window.minX, y: top, width: window.width, height: bottom - top)
        try require(safe.height > 150, "No safe navigation content viewport")
        let scrolls = app.scrollViews
        let candidates = (0..<min(scrolls.count, 8)).map { scrolls.element(boundBy: $0) }
            .filter { $0.exists && $0.isHittable && !$0.frame.isEmpty && $0.frame.intersects(safe) }
            .filter { page != .library || $0.descendants(matching: .any).matching(identifier: "drillCard_drill_c001").count == 1 }
        try require(candidates.count == 1, "Need one actual active ScrollView; do not guess container")
        let scroll = candidates[0]
        let area = scroll.frame.intersection(safe)
        try require(!area.isNull && area.height > 150 && area.width > 100, "Invalid actual scroll/window/conservative-boundary intersection")
        return (area, scroll)
    }
    private func reveal(_ element: XCUIElement, page: Page, in app: XCUIApplication) throws {
        for _ in 0..<6 {
            let (area, _) = try bounds(page: page, in: app)
            if element.exists && !element.frame.isEmpty {
                try require(element.frame.height <= area.height && element.frame.width <= area.width,
                            "Target exceeds conservative viewport; full exposure impossible, stop rather than oscillate")
            }
            if element.exists && !element.frame.isEmpty && area.contains(element.frame) && element.isHittable { return }
            let visible = area.insetBy(dx: 12, dy: 12)
            try require(visible.height > 120 && visible.width > 100, "Invalid drag viewport")
            // AX-observed tall posters require a bounded alignment, not fixed large swipes
            // that can jump across the narrow fully-visible position range.
            if element.exists && !element.frame.isEmpty {
                let delta = max(-visible.height * 0.42, min(visible.height * 0.42, element.frame.midY - area.midY))
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let center = origin.withOffset(CGVector(dx: visible.midX, dy: visible.midY))
                center.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: visible.midX, dy: visible.midY - delta)), withVelocity: 150, thenHoldForDuration: 0.3)
                continue
            }
            let moveDown = element.exists && !element.frame.isEmpty && element.frame.minY < area.minY
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let upper = origin.withOffset(CGVector(dx: visible.midX, dy: visible.minY + visible.height * 0.28))
            let lower = origin.withOffset(CGVector(dx: visible.midX, dy: visible.minY + visible.height * 0.72))
            if moveDown { upper.press(forDuration: 0.05, thenDragTo: lower) }
            else { lower.press(forDuration: 0.05, thenDragTo: upper) }
        }
        let (area, _) = try bounds(page: page, in: app)
        try require(element.exists && !element.frame.isEmpty && area.contains(element.frame) && element.isHittable,
                    "Bounded full exposure failed; capture before any poster tap")
    }
    private func capture(_ stage: String, in app: XCUIApplication) throws {
        let folder = try XCTUnwrap(output)
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let path = folder.appendingPathComponent(stem + ".png")
        try png.write(to: path, options: .withoutOverwriting)
        try require(try Data(contentsOf: path) == png, "PNG readback failed")
        let image = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        image.name = stem; image.lifetime = .keepAlways; add(image)
        let ax = app.debugDescription
        try Data(ax.utf8).write(to: folder.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
    }
    private func require(_ condition: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(message, file: file, line: line); throw Stop(reason: message) }
    }
}
