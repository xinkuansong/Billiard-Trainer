import XCTest

/// Draft only. Normal guest roots; no deep links, seeded sessions or paid unlock.
final class RootReachabilityDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch() {
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"])
    }
    private func capture(_ stage: String) throws {
        let name = "root-reachability-\(stage)-\(UUID().uuidString)"
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["TEST_RUNNER_QD_SHOT_DIR"] ?? env["QD_SHOT_DIR"])
        try shot.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
    private func reveal(_ element: XCUIElement, stage: String) throws {
        for attempt in 0..<6 {
            if element.exists && element.isHittable && app.frame.contains(element.frame) { return }
            try capture("\(stage)-before-scroll-\(attempt)")
            app.swipeUp()
        }
        XCTAssertTrue(element.exists, "Missing \(stage)")
        XCTAssertTrue(element.isHittable, "Unreachable \(stage) after bounded scrolling")
        XCTAssertTrue(app.frame.contains(element.frame), "Outside viewport: \(stage)")
    }
    private func waitSelected(_ chip: XCUIElement) {
        let selected = NSPredicate(format: "selected == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: selected, object: chip)], timeout: 5), .completed)
    }

    func testTrainingLevelFilterReachableAndChangesCards() throws {
        launch(); app.switchTab(.training)
        let free = app.buttons["trainingHome.freeTraining"]
        XCTAssertTrue(free.waitForExistence(timeout: 8))
        try capture("training-initial")
        // Use the actual shared chip identifiers and selection trait from BTFilterChip.
        let beginner = app.buttons["filterChip_入门"]
        try reveal(beginner, stage: "beginner")
        beginner.tap(); waitSelected(beginner)
        let beginnerCard = app.buttons["planPoster-plan_beginner"]
        try reveal(beginnerCard, stage: "beginner-card")
        XCTAssertTrue(beginnerCard.label.contains("基本功"))
        try capture("beginner-selected")
        // Bring the filter back if revealing the card scrolled it above the viewport.
        let intermediate = app.buttons["filterChip_中级"]
        for _ in 0..<5 {
            if intermediate.exists && intermediate.isHittable && app.frame.contains(intermediate.frame) { break }
            app.swipeDown()
        }
        // A horizontal filter row can clip its later chips on AX5; scroll that real container.
        if !intermediate.isHittable || !app.frame.contains(intermediate.frame) {
            let containers = app.scrollViews.containing(.button, identifier: "filterChip_入门").allElementsBoundByIndex
            let row = try XCTUnwrap(containers.min { $0.frame.height < $1.frame.height })
            for _ in 0..<3 {
                if intermediate.isHittable && app.frame.contains(intermediate.frame) { break }
                row.swipeLeft()
            }
        }
        try reveal(intermediate, stage: "intermediate")
        intermediate.tap(); waitSelected(intermediate)
        XCTAssertFalse(beginner.isSelected)
        let intermediateCard = app.buttons["planPoster-plan_intermediate"]
        try reveal(intermediateCard, stage: "intermediate-card")
        XCTAssertTrue(intermediateCard.label.contains("准度Ⅱ·远台切角"))
        XCTAssertFalse(beginnerCard.exists, "L0→L1 card must leave the L2 result set")
        XCTAssertFalse(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.exists,
                       "Filter interaction must not accidentally start floating Free Training")
        try capture("intermediate-selected")
    }

    func testHistoryEmptyCTAReachableAndRoutesToTraining() throws {
        launch(); app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["还没有训练记录"].waitForExistence(timeout: 8))
        try capture("history-initial")
        let cta = app.buttons["去开始第一次练球吧"]
        try reveal(cta, stage: "history-empty-cta")
        XCTAssertTrue(app.staticTexts["还没有训练记录"].isHittable)
        try capture("history-cta-visible")
        cta.tap()
        XCTAssertTrue(app.buttons["trainingHome.freeTraining"].waitForExistence(timeout: 8))
        XCTAssertFalse(cta.isHittable)
        try capture("history-cta-training-destination")
    }
}
