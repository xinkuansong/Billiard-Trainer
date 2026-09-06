import XCTest

/// Unexecuted snapshot-002 diagnostic draft. Normal navigation, no seeded boards.
final class SolverBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var status: XCUIElement { app.staticTexts["navStatus.subtitle"].firstMatch }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
    }
    override func tearDownWithError() throws { app?.terminate() }
    private func wait(_ predicate: NSPredicate, on element: XCUIElement, timeout: TimeInterval = 20) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout), .completed)
    }
    private func ready(_ element: XCUIElement) {
        wait(NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), on: element)
    }
    private func enabled(_ element: XCUIElement, _ value: Bool) {
        wait(NSPredicate(format: "exists == true AND enabled == %@", NSNumber(value: value)), on: element)
    }
    private func tap(_ title: String) {
        let element = app.buttons[title].firstMatch
        ready(element); element.tap()
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func enter(_ title: String) {
        app.switchTab(.angle)
        tap("angleHomeTab_解")
        let card = app.buttons[title].firstMatch
        reveal(card); card.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 20))
        XCTAssertTrue(status.waitForExistence(timeout: 20))
    }
    private func returnHome(_ title: String) {
        let back = app.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        ready(app.buttons["angleHomeTab_解"])
        reveal(app.buttons[title].firstMatch)
    }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let id = "solver-boundary-\(name.replacingOccurrences(of: "/", with: "_"))-\(stage)-\(UUID().uuidString)"
        let image = XCTAttachment(screenshot: shot)
        image.name = id; image.lifetime = .keepAlways; add(image)
        let ax = XCTAttachment(string: app.debugDescription)
        ax.name = id + "-AX"; ax.lifetime = .keepAlways; add(ax)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(id + ".png"))
        try app.debugDescription.write(to: dir.appendingPathComponent(id + "-AX.txt"), atomically: true, encoding: .utf8)
    }

    func testSiluMissingConstraintRemainsDisabledAfterSelectingToolAndReturns() throws {
        enter("思路训练")
        enabled(app.buttons["求解"].firstMatch, false)
        enabled(app.buttons["下一解"].firstMatch, false)
        try capture("default-no-constraint")
        tap("落点")
        wait(NSPredicate(format: "label == %@", "点按球桌标出母球期望停的落点（琥珀十字为目标，环为命中容差）"), on: status)
        enabled(app.buttons["求解"].firstMatch, false)
        try capture("rest-point-tool-selected-no-board-input")
        tap("摆球")
        wait(NSPredicate(format: "label BEGINSWITH %@", "拖动摆球"), on: status)
        enabled(app.buttons["求解"].firstMatch, false)
        try capture("placement-mode-restored")
        returnHome("思路训练")
    }

    func testPlanThreeUnfilledRoleRequestsPocketThenBallAndReturns() throws {
        enter("打一走二想三")
        enabled(app.buttons["求解"].firstMatch, false)
        enabled(app.buttons["下一解"].firstMatch, false)
        try capture("default-unfilled-roles")
        // SwiftUI combines Text+Image. Match the role text contained by exactly one button.
        func role(_ title: String) {
            let matches = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title))
            XCTAssertEqual(matches.count, 1, "Role AX must be unambiguous; do not use guessed scene coordinates")
            let chip = matches.firstMatch
            ready(chip); chip.tap()
        }
        role("①袋")
        wait(NSPredicate(format: "label == %@", "点袋口，设为①一号球目标袋"), on: status)
        enabled(app.buttons["求解"].firstMatch, false)
        try capture("waiting-pocket-one")
        role("②球")
        wait(NSPredicate(format: "label == %@", "点桌上的球，设为②二号球"), on: status)
        enabled(app.buttons["求解"].firstMatch, false)
        try capture("waiting-ball-two")
        tap("清空计划")
        wait(NSPredicate(format: "label == %@", "点桌上的球，设为①一号球"), on: status)
        enabled(app.buttons["求解"].firstMatch, false)
        try capture("cleared-role-selection")
        returnHome("打一走二想三")
    }

    private func terminal(_ title: String, cushions: Int?) throws {
        let noSolution: String
        if cushions != nil {
            noSolution = title == "翻袋解球器" ? "该库数下无解，换库数 / 袋口或移动球位" : "该库数下无解，换库数或移动球位"
        } else {
            noSolution = title == "翻袋解球器" ? "该袋暂无翻袋解，换袋口或移动球位再试" : "该位置暂无解，移动球位再试"
        }
        let prefix = cushions.map { "\($0) 库" }
        let predicate = NSPredicate { [weak self] _, _ in
            guard let self, self.status.exists else { return false }
            let text = self.status.label
            return text == noSolution || (prefix.map { text.hasPrefix($0) } ??
                ["1 库", "2 库", "3 库"].contains { text.hasPrefix($0) })
        }
        wait(predicate, on: status, timeout: 60)
        let next = app.buttons["solver.nextSolution"].firstMatch
        if status.label == noSolution {
            enabled(next, false)
            enabled(app.buttons["击打"].firstMatch, false)
            try capture("\(cushions.map(String.init) ?? "auto")-no-solution-next-unexercised")
        } else {
            ready(app.buttons["击打"].firstMatch)
            let multi = status.label.contains("解 ")
            enabled(next, multi)
            try capture("\(cushions.map(String.init) ?? "auto")-solution")
            if multi {
                let suffix = try XCTUnwrap(status.label.components(separatedBy: "解 ").last)
                let indices = suffix.split(separator: "/").compactMap { Int($0) }
                XCTAssertEqual(indices.count, 2)
                guard indices.count == 2 else { return }
                XCTAssertGreaterThan(indices[1], 1)
                XCTAssertTrue((1...indices[1]).contains(indices[0]))
                if cushions != nil { XCTAssertEqual(indices[0], 1) }
                let expectedNext = indices[0] % indices[1] + 1
                next.tap()
                wait(NSPredicate(format: "label CONTAINS %@", "解 \(expectedNext)/\(indices[1])"), on: status)
                if let prefix { XCTAssertTrue(status.label.hasPrefix(prefix)) }
                ready(app.buttons["击打"].firstMatch)
                try capture("\(cushions.map(String.init) ?? "auto")-actual-next-solution")
            } else {
                try capture("\(cushions.map(String.init) ?? "auto")-single-solution-next-unexercised")
            }
        }
    }
    private func solveFilters(_ title: String) throws {
        enter(title)
        XCTAssertTrue(app.buttons["solver.mode"].label.contains("求解"))
        try terminal(title, cushions: nil)
        for count in 1...3 {
            tap("\(count)库")
            try terminal(title, cushions: count)
        }
        tap("自动")
        try terminal(title, cushions: nil)
        returnHome(title)
    }
    func testBankDefaultSolutionsAndOneTwoThreeCushionTerminalStates() throws {
        try solveFilters("翻袋解球器")
    }
    func testReflectionDefaultSolutionsAndOneTwoThreeCushionTerminalStates() throws {
        try solveFilters("反射解球器")
    }
}
