import XCTest

/// Snapshot004 diagnostic. Normal navigation, no seeded boards; only reviewed selectors run.
final class SolverBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private var status: XCUIElement { app.staticTexts["navStatus.subtitle"].firstMatch }
    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let expected = try XCTUnwrap(env["QD_SOLVER_DEVICE_UDID"] ?? env["TEST_RUNNER_QD_SOLVER_DEVICE_UDID"])
        XCTAssertEqual(env["SIMULATOR_UDID"], expected)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal") }
    }
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

    // Screen points below were measured from entrance001 PNG/AX on this exact
    // 402x874 device. No world coordinate or feasibility assertion is implied.
    private func observedPoint(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        XCTAssertEqual(app.windows.firstMatch.frame.size, CGSize(width: 402, height: 874))
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    private func observeCompletedSolve(_ action: String, stage: String) throws {
        let old = status.label
        tap("求解")
        let predicate = NSPredicate { [weak self] _, _ in
            guard let self, self.status.exists else { return false }
            let value = self.status.label
            let empty = value.hasPrefix("未找到解") || value.hasPrefix("直击角度过大，且暂无翻袋备选")
            let button = self.app.buttons[action].firstMatch
            return value != old && value != "求解中…" && (empty || (button.exists && button.isEnabled))
        }
        wait(predicate, on: status, timeout: 120)
        let value = status.label
        let classification = value.contains("翻袋备选") ? "bank-fallback" :
            value.contains("最接近解") ? "closest-not-satisfied" :
            (value.hasPrefix("未找到解") || value.hasPrefix("直击角度过大")) ? "empty" : "reported-satisfying-needs-independent-geometry"
        print("[QD-Constraint] stage=\(stage) branch=\(classification) status=\(value)")
        try capture(stage + "-" + classification)
    }
    func testSiluActualRectangleConstraintSolve() throws {
        enter("思路训练")
        // Explicitly reselect the observed yellow ball and upper-left pocket.
        observedPoint(176.3, 394.6).tap()
        observedPoint(71.6, 201).tap()
        try capture("silu-selected-ball-pocket")
        tap("落区")
        observedPoint(105, 310).press(forDuration: 0.1, thenDragTo: observedPoint(295, 640), withVelocity: 250, thenHoldForDuration: 0.2)
        wait(NSPredicate(format: "label == %@", "已就绪，点「求解」反解走位"), on: status)
        try capture("silu-actual-rectangle-ready")
        try observeCompletedSolve("击球", stage: "silu-rectangle-result")
        tap("清除约束")
        enabled(app.buttons["求解"].firstMatch, false)
        enabled(app.buttons["击球"].firstMatch, false)
        try capture("silu-clear-constraint")
        returnHome("思路训练")
    }
    func testPlanThreeActualFiveRolesDefaultSectorSolve() throws {
        enter("打一走二想三")
        func assign(_ role: String, _ x: CGFloat, _ y: CGFloat) throws {
            let chips = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", role))
            XCTAssertEqual(chips.count, 1)
            ready(chips.firstMatch); chips.firstMatch.tap()
            observedPoint(x, y).tap()
            try capture("plan-three-assigned-" + role)
        }
        try assign("①球", 160, 421.9)
        try assign("①袋", 80, 431)
        try assign("②球", 242, 339.9)
        try assign("②袋", 322, 198)
        try assign("③球", 160, 267)
        wait(NSPredicate(format: "label BEGINSWITH %@", "扇形为默认落区"), on: status)
        try capture("plan-three-five-roles-sector-ready")
        try observeCompletedSolve("打一", stage: "plan-three-default-sector-result")
        returnHome("打一走二想三")
    }

    func testSiluActualRestPointCandidateSolve() throws {
        enter("思路训练")
        observedPoint(176.3, 394.6).tap()
        observedPoint(71.6, 201).tap()
        tap("落点")
        observedPoint(110, 660).tap()
        wait(NSPredicate(format: "label == %@", "已就绪，点「求解」反解走位"), on: status)
        try capture("silu-left-bottom-point-ready")
        try observeCompletedSolve("击球", stage: "silu-left-bottom-point-result")
        returnHome("思路训练")
    }
    func testPlanThreeFiveRolesCustomRectangleStrikeAndUndo() throws {
        enter("打一走二想三")
        func assign(_ role: String, _ x: CGFloat, _ y: CGFloat) {
            let chips = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", role))
            XCTAssertEqual(chips.count, 1)
            ready(chips.firstMatch); chips.firstMatch.tap()
            observedPoint(x, y).tap()
        }
        assign("①球", 160, 421.9)
        assign("①袋", 80, 431)
        assign("②球", 242, 339.9)
        assign("②袋", 322, 198)
        assign("③球", 160, 267)
        wait(NSPredicate(format: "label BEGINSWITH %@", "扇形为默认落区"), on: status)
        tap("落区")
        // Actual plan-three felt bounds were reviewed in entrance001.
        observedPoint(105, 310).press(forDuration: 0.1, thenDragTo: observedPoint(295, 630), withVelocity: 250, thenHoldForDuration: 0.2)
        wait(NSPredicate(format: "label == %@", "约束就绪，点「求解」反解打一杆法"), on: status)
        try capture("plan-three-custom-rectangle-ready")
        try observeCompletedSolve("打一", stage: "plan-three-custom-rectangle-result")
        ready(app.buttons["打一"].firstMatch)
        print("[QD-Constraint] strikeStart uptime=\(ProcessInfo.processInfo.systemUptime) status=\(status.label)")
        tap("打一")
        let ended = NSPredicate { [weak self] _, _ in
            guard let self, self.status.exists else { return false }
            let value = self.status.label
            return value.hasPrefix("①进袋") || value.hasPrefix("①未进袋") || value.hasPrefix("母球进袋") || value.hasPrefix("清台完成")
        }
        wait(ended, on: status, timeout: 90)
        print("[QD-Constraint] strikeEnd uptime=\(ProcessInfo.processInfo.systemUptime) status=\(status.label)")
        try capture("plan-three-actual-strike-ended")
        tap("上一杆")
        wait(NSPredicate(format: "label == %@", "已退回上一杆击打前 · 球形/①②③/约束/解已还原"), on: status)
        ready(app.buttons["打一"].firstMatch)
        enabled(app.buttons["上一杆"].firstMatch, false)
        enabled(app.buttons["回放"].firstMatch, false)
        try capture("plan-three-actual-undo-restored")
        returnHome("打一走二想三")
    }

    func testCaptureCurrentConstraintToolEntrances() throws {
        enter("思路训练")
        try capture("004-silu-initial-full-board")
        returnHome("思路训练")
        enter("打一走二想三")
        try capture("004-plan-three-initial-full-board")
        returnHome("打一走二想三")
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
