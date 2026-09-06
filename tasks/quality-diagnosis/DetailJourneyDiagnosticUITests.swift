import XCTest

/// Fixed c042 fixture from snapshot-002, reached through the normal library UI.
final class DetailJourneyDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    private let drillTitle = "初级蛇彩"
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("teardown") }
    }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 20) {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: timeout), .completed,
                       "Expected actionable element: \(e)")
    }
    private func reveal(_ e: XCUIElement) {
        for _ in 0..<28 {
            if e.exists && e.isHittable { return }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.78))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.33)))
        }
        ready(e)
    }
    private func text(_ fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let dir = URL(fileURLWithPath: try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"]), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = "detail-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(runID)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let ax = app.debugDescription
        let hierarchy = XCTAttachment(string: ax); hierarchy.name = stem + "-AX"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"))
        try ax.write(to: dir.appendingPathComponent(stem + ".txt"), atomically: true, encoding: .utf8)
    }
    private func openC042() throws {
        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]; ready(search); search.tap(); search.typeText(drillTitle + "\n")
        let card = app.descendants(matching: .any).matching(identifier: "drillCard_drill_c042").firstMatch
        ready(card); card.tap()
        XCTAssertTrue(app.navigationBars[drillTitle].waitForExistence(timeout: 20))
        ready(app.buttons["bottomTryoutButton"])
        try capture("detail")
    }
    private func backToDetail() {
        let back = app.navigationBars.buttons.firstMatch; ready(back); back.tap()
        XCTAssertTrue(app.navigationBars[drillTitle].waitForExistence(timeout: 20))
        ready(app.buttons["bottomTryoutButton"])
    }
    private func backToLibrary() throws {
        let back = app.navigationBars.buttons.firstMatch; ready(back); back.tap()
        ready(app.textFields["librarySearchField"])
        XCTAssertEqual(app.textFields["librarySearchField"].value as? String, drillTitle)
        ready(app.descendants(matching: .any).matching(identifier: "drillCard_drill_c042").firstMatch)
        try capture("library-returned")
    }

    func testC042TutorialTwoFormationsKeepDistinctPostersAndReadingPosition() throws {
        try openC042()
        let tutorial = app.buttons["查看精讲"].firstMatch; reveal(tutorial); ready(tutorial); tutorial.tap()
        let picker = app.segmentedControls["tutorialFormationPicker"]; ready(picker)
        let first = picker.buttons["球形1：首杆八起点阶梯"]
        let second = picker.buttons["球形2：五球连续蛇彩"]
        XCTAssertTrue(first.isSelected)
        let firstPoster = app.buttons["tutorialPoster_drill_c042_manual01_s08"]
        reveal(firstPoster); ready(firstPoster)
        let firstCaption = text("第8杆：约 18°"); reveal(firstCaption); ready(firstCaption)
        XCTAssertFalse(app.buttons["tutorialPoster_drill_c042_manual02_s05"].isHittable)
        try capture("tutorial-f1-eighth-shot")
        ready(second); second.tap(); XCTAssertTrue(second.isSelected)
        let secondInitial = app.buttons["tutorialPoster_drill_c042_manual02_initial"]
        reveal(secondInitial); ready(secondInitial)
        XCTAssertTrue(text("开局：五球连打，先左中袋再右中袋，角袋收尾").exists)
        try capture("tutorial-f2-opening")
        let secondPoster = app.buttons["tutorialPoster_drill_c042_manual02_s05"]
        reveal(secondPoster); ready(secondPoster)
        let secondCaption = text("第5杆：约 3°"); reveal(secondCaption); ready(secondCaption)
        XCTAssertFalse(firstPoster.isHittable)
        try capture("tutorial-f2-fifth-shot")
        ready(first); first.tap(); XCTAssertTrue(first.isSelected)
        // Do not reveal: this assertion tests retained per-formation scroll position.
        ready(firstCaption)
        XCTAssertFalse(secondPoster.isHittable)
        try capture("tutorial-f1-position-restored")
        backToDetail()
        try backToLibrary()
    }

    func testC042BothTryoutBoardsStrikeUndoAndRearrange() throws {
        try openC042()
        for (index, count, balls) in [(0, 8, 3), (1, 5, 5)] {
            let tryout = app.buttons["bottomTryoutButton"]; ready(tryout); tryout.tap()
            XCTAssertTrue(app.navigationBars["选择球形"].waitForExistence(timeout: 15))
            let row = app.buttons["tryoutFormation_\(index)"]; ready(row)
            // Check the selected row's identity and source-derived dose, not another row's text.
            XCTAssertTrue(row.label.contains("球形\(index + 1)"))
            XCTAssertTrue(row.label.contains("\(count) 杆"))
            XCTAssertTrue(row.label.contains("\(balls) 球"))
            try capture("formation-\(index + 1)-choice")
            row.tap()
            ready(app.buttons["tryoutMode_序列"], timeout: 30)
            let brief = app.descendants(matching: .any).matching(identifier: "tryout.briefCard").firstMatch
            XCTAssertTrue(brief.waitForExistence(timeout: 12))
            XCTAssertTrue(text("本局共 \(count) 杆").waitForExistence(timeout: 12))
            XCTAssertFalse(text("本局共 \(count == 8 ? 5 : 8) 杆").exists)
            try capture("formation-\(index + 1)-initial")
            let free = app.buttons["tryoutMode_自由"]; ready(free); free.tap()
            let strike = app.buttons["击球"].firstMatch
            let undo = app.buttons["重打"].firstMatch
            let replay = app.buttons["回放"].firstMatch
            ready(strike, timeout: 30)
            XCTAssertFalse(undo.isEnabled)
            strike.tap()
            ready(undo, timeout: 60)
            ready(replay, timeout: 15)
            try capture("formation-\(index + 1)-after-shot")
            undo.tap()
            ready(strike, timeout: 30)
            XCTAssertFalse(undo.isEnabled)
            try capture("formation-\(index + 1)-undo")
            let rearrange = app.buttons["tryout.rearrange"]; ready(rearrange); rearrange.tap()
            ready(strike, timeout: 30)
            XCTAssertFalse(replay.isEnabled)
            try capture("formation-\(index + 1)-rearranged")
            backToDetail()
        }
        try backToLibrary()
    }
}
