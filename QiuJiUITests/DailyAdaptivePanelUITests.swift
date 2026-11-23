import XCTest

/// Current-run evidence only. The caller must inject a fresh output leaf and set
/// the simulator's real content size before selecting the maximum-type test.
final class DailyAdaptivePanelUITests: XCTestCase {
    private var output: URL!
    private var captures = [[String: String]]()
    private var launchCount = 0
    private var nativeMenuIndex = 0
    private var nativeMenuClip: CGRect?
    private let diagnosticIDs = ["dailyLayout.entryProbe",
        "v63.cameraDiagnostics", "table.scene", "dailyClearance.landscape", "freeplay.stage",
        "dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu",
        "paletteBall_cueBall", "paletteBall__1", "paletteBall__15", "dailyLayout.headerProbe",
        "dailyLayout.controlsProbe", "dailyLayout.spinGeometry", "shotStage.aimWheel", "shotStage.powerBar", "shotStage.instrument",
        "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback",
        "shotStage.powerShell", "shotCamera.firstPerson", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.observeTable", "spinPad.card", "spinPad.disc",
        "dailyClearance.spinTransparencyTitle", "dailyClearance.spinTransparencyPercent",
        "dailyClearance.spinTransparencyOpaqueLabel", "dailyClearance.spinTransparencyTransparentLabel",
        "dailyClearance.spinTransparencyPanel", "dailyClearance.spinTransparencyScroll",
        "dailyClearance.spinTransparencyDone", "dailyClearance.spinTransparencySlider", "menu.aimCloseup"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let path = env["DAILY_ADAPTIVITY_DIR"] ?? env["TEST_RUNNER_DAILY_ADAPTIVITY_DIR"]
        output = URL(fileURLWithPath: try XCTUnwrap(path,
            "Inject DAILY_ADAPTIVITY_DIR; lifecycle evidence has no legacy output fallback"))
            .appendingPathComponent(name.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    }

    /// Refresh the core template from current production UI, not historical Figma screenshots.
    func testC56CoreTemplateCurrentStates() throws {
        let app = try launch(); defer { app.terminate() }
        let window = app.windows.firstMatch.frame
        func dismiss() {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: window.midX, dy: window.midY)).tap()
        }
        func openMore() {
            app.buttons["freeplay.moreMenu"].tap()
            XCTAssertTrue(element(app, "dailyClearance.menuPanel").waitForExistence(timeout: 3))
        }
        for dimension in ["2D", "3D"] {
            if dimension == "3D" {
                openMore(); app.buttons["freeplay.cameraMode"].tap()
                waitValue(app.buttons["freeplay.cameraMode"], "3D"); dismiss()
            }
            try capture(app, "template-" + dimension + "-base")
            openMore()
            try capture(app, "template-" + dimension + "-more-top")
            let menuScroll = app.scrollViews["dailyClearance.menuScroll"]
            menuScroll.swipeUp()
            try capture(app, "template-" + dimension + "-more-bottom")
            XCTAssertTrue(customItem(app, "dailyClearance.changeGame").isHittable)
            customItem(app, "dailyClearance.aimModeMenu").tap()
            try capture(app, "template-" + dimension + "-aim")
            contain(app, app.buttons["dailyClearance.menuBack"])
            contain(app, app.buttons["dailyClearance.menuClose"])
            XCTAssertTrue(app.buttons["dailyClearance.menuBack"].isHittable)
            XCTAssertTrue(app.buttons["dailyClearance.menuClose"].isHittable)
            app.buttons["dailyClearance.menuClose"].tap()
            openMore(); menuScroll.swipeUp()
            customItem(app, "dailyClearance.trajectoryMenu").tap()
            try capture(app, "template-" + dimension + "-trajectory")
            XCTAssertEqual(app.buttons["dailyClearance.trajectory.3"].exists, dimension == "3D")
            app.buttons["dailyClearance.menuClose"].tap()
            openMore(); customItem(app, "dailyClearance.spinTransparencyMenu").tap()
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            XCTAssertTrue(slider.waitForExistence(timeout: 3))
            for (value, name) in [(Float(0), "0"), (Float(0.5), "50"), (Float(1), "100")] {
                slider.adjust(toNormalizedSliderPosition: CGFloat(value))
                try capture(app, "template-" + dimension + "-transparency-" + name)
            }
            slider.adjust(toNormalizedSliderPosition: 0.5)
            app.buttons["dailyClearance.spinTransparencyDone"].tap()
            XCTAssertTrue(element(app, "spinPad.card").exists)
            try capture(app, "template-" + dimension + "-spin")
            app.buttons["shotStage.spinEntry"].tap()
            if dimension == "3D" {
                XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
                for (id, name) in [("shotCamera.thirdPerson", "third"), ("shotCamera.firstPerson", "first"),
                    ("shotCamera.temporaryTopDown", "peek")] {
                    let button = app.buttons[id]; button.tap(); waitValue(button, "已选中")
                    try capture(app, "template-3D-" + name)
                }
                app.buttons["shotCamera.temporaryTopDown"].tap()
            }
        }
    }

    func testC56UnifiedStatusAndLiveFPS() throws {
        let app = try launch()
        let window = app.windows.firstMatch.frame
        let status = element(app, "dailyClearance.deviceStatus")
        let cluster = element(app, "dailyClearance.statusCluster")
        let fps = element(app, "dailyClearance.renderFPS")
        XCTAssertTrue(fps.waitForExistence(timeout: 5))
        waitValue(fps, "FPS · 静止")
        if min(window.width, window.height) < 600 {
            XCTAssertTrue(status.waitForExistence(timeout: 5), "Phone fullscreen should show actual clock and battery")
            contain(app, status)
            let more = app.buttons["freeplay.moreMenu"].frame
            XCTAssertLessThan(status.frame.midY, more.midY)
            XCTAssertEqual(cluster.frame.midY, more.midY, accuracy: 0.75)
            XCTAssertEqual(more.minX - (status.frame.midX + 16), 5, accuracy: 0.75)
            for index in 1...15 {
                XCTAssertFalse(status.frame.intersects(app.buttons["paletteBall__\(index)"].frame))
            }
            XCTAssertTrue(status.label.contains("时间")); XCTAssertTrue(status.label.contains("电量"))
        } else {
            XCTAssertFalse(status.exists, "iPad retains its visible system status bar")
        }
        try capture(app, "c56-status-2d", extraIDs: ["dailyClearance.deviceStatus", "dailyClearance.renderFPS", "dailyClearance.statusCluster"])
        let stage = element(app, "freeplay.stage").frame
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 3)); mode.tap(); waitValue(mode, "3D")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.midX, dy: window.midY)).tap()
        try capture(app, "c56-third-person", extraIDs: ["dailyClearance.deviceStatus", "dailyClearance.renderFPS", "dailyClearance.statusCluster"])
        let first = app.buttons["shotCamera.firstPerson"]
        contain(app, first, hit: true); first.tap(); waitValue(first, "已选中")
        try capture(app, "c56-first-person", extraIDs: ["dailyClearance.deviceStatus", "dailyClearance.renderFPS", "dailyClearance.statusCluster"])
        XCTAssertEqual(stage, element(app, "freeplay.stage").frame)
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        peek.tap(); waitValue(peek, "已选中")
        if min(window.width, window.height) < 600 { XCTAssertTrue(status.exists) }
        try capture(app, "c56-peek", extraIDs: ["dailyClearance.deviceStatus", "dailyClearance.renderFPS", "dailyClearance.statusCluster"])
        peek.tap(); waitValue(first, "已选中")
        XCTAssertFalse(element(app, "table.renderFPS").exists, "Legacy FPS label must not duplicate the header")
        app.buttons["dailyClearance.strike"].tap()
        let measured = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "[1-9][0-9]* FPS"), object: fps)
        XCTAssertEqual(XCTWaiter.wait(for: [measured], timeout: 10), .completed)
        try capture(app, "c56-moving-fps", extraIDs: ["dailyClearance.renderFPS"])
        let idle = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "FPS · 静止"), object: fps)
        XCTAssertEqual(XCTWaiter.wait(for: [idle], timeout: 30), .completed)
        try capture(app, "c56-idle-fps", extraIDs: ["dailyClearance.renderFPS"])
    }

    func testC54ActionStatesAndThreeCameraRoundTrip() throws {
        let app = try launch()
        let original = try state(app)
        let stage = element(app, "freeplay.stage").frame
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 3))
        mode.tap(); waitValue(mode, "3D")
        let window = app.windows.firstMatch.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.midX, dy: window.midY)).tap()
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        let ids = ["shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        let buttons = ids.map { app.buttons[$0] }
        for button in buttons { contain(app, button, hit: true); XCTAssertTrue(button.isEnabled) }
        let shell = element(app, "shotStage.powerShell").frame
        try capture(app, "c54-alignment-measured")
        let stack = buttons.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        // P01 centers the four-slot lane, whose first slot has no control.
        let slotPitch = abs(buttons[0].frame.midY - buttons[1].frame.midY)
        XCTAssertEqual(stack.midY - slotPitch / 2, shell.midY, accuracy: 0.75)
        for button in buttons { XCTAssertEqual(button.frame.midX, buttons[0].frame.midX, accuracy: 0.5) }
        try capture(app, "c54-third-person")
        buttons[1].tap()
        let diagnostics = element(app, "v63.cameraDiagnostics")
        let firstPerson = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "twoViewMode=firstPerson"), object: diagnostics)
        XCTAssertEqual(XCTWaiter.wait(for: [firstPerson], timeout: 5), .completed)
        waitValue(buttons[1], "已选中")
        try capture(app, "c54-first-person")
        buttons[2].tap()
        waitValue(buttons[2], "已选中")
        for button in buttons.prefix(2) { XCTAssertFalse(button.isEnabled) }
        XCTAssertFalse(app.buttons["dailyClearance.undo"].exists)
        XCTAssertFalse(app.buttons["dailyClearance.playback"].isEnabled)
        try capture(app, "c54-peek-disabled")
        buttons[2].tap()
        waitValue(buttons[1], "已选中")
        buttons[0].tap(); waitValue(buttons[0], "已选中")
        unchanged(original, try state(app))
        XCTAssertEqual(element(app, "freeplay.stage").frame, stage)
        try capture(app, "c54-restored")
        let replay = app.buttons["dailyClearance.playback"]
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertFalse(undo.exists); XCTAssertFalse(replay.isEnabled)
        app.buttons["dailyClearance.strike"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
        XCTAssertFalse(undo.exists)
        try capture(app, "c54-history-enabled")
        replay.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)], timeout: 25), .completed)
        XCTAssertFalse(undo.exists)
        try capture(app, "c54-history-replayed")
    }

    func testC51PaletteAndMenuRoundTrip() throws {
        let app = try launch()
        let stableIDs = ["freeplay.stage", "dailyClearance.back", "freeplay.moreMenu",
            "shotStage.aimWheel", "shotStage.powerBar", "dailyClearance.strike"]
        let before = stableIDs.map { element(app, $0).frame }
        func rendererID() throws -> String {
            let raw = try XCTUnwrap(element(app, "table.scene").value as? String)
            let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            return try XCTUnwrap(data["rendererID"] as? String)
        }
        let renderer = try rendererID()
        let initialState = try state(app)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        XCTAssertFalse(app.buttons["freeplay.cameraMode"].exists)
        let balls = (1...15).map { app.buttons["paletteBall__\($0)"] }
        for ball in balls { contain(app, ball) }
        if app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height {
            XCTAssertTrue(element(app, "dailyClearance.singleRowPalette").exists)
            for ball in balls { XCTAssertEqual(ball.frame.midY, balls[0].frame.midY, accuracy: 0.5) }
        }
        for (index, ball) in balls.enumerated() {
            for other in balls.dropFirst(index + 1) {
                XCTAssertFalse(ball.frame.insetBy(dx: 0.5, dy: 0.5).intersects(other.frame))
            }
        }
        try capture(app, "c51-2D", extraIDs: (1...15).map { "paletteBall__\($0)" })
        for dimension in ["3D", "2D"] {
            app.buttons["freeplay.moreMenu"].tap()
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 3))
            let scroll = app.scrollViews["dailyClearance.menuScroll"]
            for _ in 0..<3 where !mode.isHittable { scroll.swipeUp() }
            XCTAssertTrue(mode.isHittable)
            XCTAssertGreaterThanOrEqual(mode.frame.height, 44)
            mode.tap()
            waitValue(mode, dimension)
            try capture(app, "c51-menu-" + dimension)
            // Existing modal backdrop provides the explicit outside-dismiss path.
            let window = app.windows.firstMatch.frame
            let panel = element(app, "dailyClearance.menuPanel").frame
            let dismissPoint = CGPoint(x: window.midX, y: window.midY)
            XCTAssertFalse(panel.contains(dismissPoint))
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: dismissPoint.x, dy: dismissPoint.y)).tap()
            XCTAssertFalse(mode.exists)
            XCTAssertEqual(try rendererID(), renderer)
            unchanged(initialState, try state(app))
            try capture(app, "c51-" + dimension + "-returned")
            for (index, id) in stableIDs.enumerated() where id != "freeplay.stage" {
                XCTAssertEqual(element(app, id).frame, before[index], id)
            }
        }
        XCTAssertEqual(element(app, "freeplay.stage").frame, before[0])
        app.buttons["paletteBall__3"].tap()
        try capture(app, "c51-pocketed-feedback")
        XCTAssertTrue(app.buttons["paletteBall__1"].isEnabled)
        app.buttons["paletteBall__1"].tap()
        try capture(app, "c51-selected")
    }

    func testC51FiveRulesets() throws {
        for (game, count) in [("chineseEightBall", 15), ("nineBall", 9), ("sixBall", 6), ("fiveBall", 5), ("fourBall", 4)] {
            let app = try launch(fixture: "manual", game: game)
            let balls = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).allElementsBoundByIndex
            XCTAssertEqual(balls.count, count)
            XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
            for ball in balls {
                contain(app, ball)
                XCTAssertLessThanOrEqual(ball.frame.width, 38.5)
                XCTAssertEqual(ball.frame.midY, balls[0].frame.midY, accuracy: 0.5)
                XCTAssertFalse(ball.isEnabled, "Racked balls remain unselectable")
            }
            try capture(app, "c51-rack-" + game)
            app.terminate()
        }
    }

    func testC51NarrowPortraitPalette() throws {
        let app = try launch(extra: ["-dailyLayout.viewport=420x800"])
        XCTAssertTrue(element(app, "dailyClearance.twoRowPalette").exists)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        let top = app.buttons["paletteBall__1"].frame
        let bottom = app.buttons["paletteBall__9"].frame
        XCTAssertEqual(top.minX, bottom.minX, accuracy: 0.5)
        XCTAssertLessThan(top.maxY, bottom.minY)
        for number in 1...15 { contain(app, app.buttons["paletteBall__\(number)"]) }
        XCTAssertEqual(top.width, 38, accuracy: 0.5)
        try capture(app, "c51-narrow-2D", extraIDs: (1...15).map { "paletteBall__\($0)" })
        app.buttons["paletteBall__1"].tap()
        app.buttons["paletteBall__9"].tap()
        try capture(app, "c51-narrow-targets")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func frame(_ rect: CGRect) -> [String: Double] {
        ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
    }

    private func capture(_ app: XCUIApplication, _ state: String, extraIDs: [String] = [],
                         includeBaseDiagnostics: Bool = true) throws {
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: output.appendingPathComponent(state + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = state; attachment.lifetime = .keepAlways; add(attachment)
        try app.debugDescription.write(to: output.appendingPathComponent(state + "-ax.txt"),
                                      atomically: true, encoding: .utf8)
        let ids = (includeBaseDiagnostics ? diagnosticIDs : ["dailyLayout.controlsProbe"]) + extraIDs
        // Read each element's attributes from one real snapshot. Repeated AX
        // attribute requests produced gigabytes of redundant XCTest trace data.
        let snapshots = try app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ids))
            .allElementsBoundByIndex.map { try $0.snapshot() }
        let byID = Dictionary(snapshots.map { ($0.identifier, $0) },
                              uniquingKeysWith: { first, _ in first })
        let window = app.windows.firstMatch
        let windowExists = window.exists
        let windowFrame = windowExists ? window.frame : app.frame
        var diagnostics = [[String: Any]]()
        for id in ids {
            var row: [String: Any] = ["identifier": id, "exists": byID[id] != nil]
            if let node = byID[id] {
                row["frame"] = frame(node.frame)
                row["label"] = node.label
                row["elementType"] = node.elementType.rawValue
                row["selected"] = node.isSelected
                // Hittability is asserted at the actual interaction sites. Probing
                // every decorative element on every capture floods iOS 17 AX logs.
                row["hittabilityNotQueried"] = "Verified by action-specific assertions"
                row["value"] = node.value.map { String(describing: $0) } ?? ""
            }
            diagnostics.append(row)
        }
        let record: [String: Any] = ["state": state, "timestamp": Date().timeIntervalSince1970,
            "appState": app.state.rawValue, "launchArguments": app.launchArguments,
            "windowExists": windowExists, "windowFrame": frame(windowFrame),
            "diagnostics": diagnostics]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(state + ".json"))
        captures.append(["state": state, "screenshot": state + ".png", "measurements": state + ".json",
                         "rawAX": state + "-ax.txt"])
        try JSONSerialization.data(withJSONObject: captures, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("manifest.json"))
    }

    // Test process must receive a new evidence leaf and real content-size readback.
    private func launch(fixture: String = "selection", game: String = "chineseEightBall", extra: [String] = []) throws -> XCUIApplication {
        launchCount += 1
        nativeMenuClip = nil
        let requestedOrientation = ProcessInfo.processInfo.environment["DAILY_LAYOUT_ORIENTATION"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_DAILY_LAYOUT_ORIENTATION"]
        XCUIDevice.shared.orientation = requestedOrientation == "portrait" ? .portrait : .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-resetDebugPremium", "-forcePremium",
            "-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics",
            "-dailyClearance.resetState", "-dailyClearance.resetHomeState",
            "-dailyClearance.preferredGame.v1", game, "-deeplink.dailyClearance",
            "-dailyClearance.fixture=\(fixture)"] + extra
        // Fixtures already install board/phase; fixtureSettled would auto-deliver every later rerack.
        app.launch()
        let reached = element(app, "freeplay.stage").waitForExistence(timeout: 15)
        try capture(app, "entry-\(launchCount)-\(fixture)-" + (reached ? "ready" : "failed"))
        XCTAssertTrue(reached, "Keep the established entry deadline")
        XCTAssertTrue(element(app, "dailyLayout.entryProbe").exists)
        // Caller supplies real simulator readback; do not claim that launch args set type.
        let env = ProcessInfo.processInfo.environment
        let size = try XCTUnwrap(env["DAILY_LAYOUT_CONTENT_SIZE"] ?? env["TEST_RUNNER_DAILY_LAYOUT_CONTENT_SIZE"])
        try size.write(to: output.appendingPathComponent("content-size-readback.txt"), atomically: true, encoding: .utf8)
        return app
    }

    private func waitValue(_ node: XCUIElement, _ value: String) {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: node)
        let result = XCTWaiter.wait(for: [e], timeout: 3)
        if result != .completed {
            try? capture(XCUIApplication(), "value-failed-" + value)
        }
        XCTAssertEqual(result, .completed, "Expected \(value), actual \(String(describing: node.value))")
    }

    private func contain(_ app: XCUIApplication, _ node: XCUIElement, hit: Bool = false) {
        XCTAssertTrue(node.exists)
        XCTAssertGreaterThan(node.frame.width, 0)
        XCTAssertGreaterThan(node.frame.height, 0)
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -0.5, dy: -0.5).contains(node.frame))
        if hit {
            XCTAssertGreaterThanOrEqual(node.frame.width, 43.5)
            XCTAssertGreaterThanOrEqual(node.frame.height, 43.5)
            XCTAssertTrue(node.isHittable)
        }
    }

    private func mode(_ app: XCUIApplication, _ dimension: String) {
        let node = app.buttons["freeplay.cameraMode"]
        let opened = !node.exists
        if opened {
            app.buttons["freeplay.moreMenu"].tap()
            XCTAssertTrue(node.waitForExistence(timeout: 3))
        }
        if node.value as? String != dimension { node.tap() }
        waitValue(node, dimension)
        if opened { app.buttons["关闭菜单"].tap() }
    }

    private func state(_ app: XCUIApplication) throws -> [String: Double] {
        let diagnostics = element(app, "v63.cameraDiagnostics")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (diagnostics.value as? String)?.split(separator: " ").contains("twoViewComputing=false") == true
        }, object: diagnostics)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed,
                       "Read stable state after asynchronous spin solving; no sleep fallback")
        let probe = element(app, "dailyLayout.controlsProbe")
        let raw = try XCTUnwrap(probe.value as? String)
        var result = [String: Double]()
        for field in raw.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1)
            if parts.count == 2, let value = Double(parts[1]), value.isFinite { result[String(parts[0])] = value }
        }
        for key in ["aimX", "aimZ", "spinX", "spinY", "dailyShotCount", "velocity"] {
            _ = try XCTUnwrap(result[key], "W4 probe must expose actual \(key)")
        }
        result["power"] = try XCTUnwrap(result["velocity"])
        // Visible power AX is a cross-check only. Hidden panel controls are never queried.
        if !element(app, "dailyClearance.spinTransparencyPanel").exists {
            let actual = try XCTUnwrap(Double(try XCTUnwrap(element(app, "shotStage.powerBar").value as? String)))
            XCTAssertEqual(actual, result["power"]!, accuracy: 0.011, "AX readout rounds to two decimals")
        }
        return result
    }

    private func unchanged(_ before: [String: Double], _ after: [String: Double]) {
        for key in ["aimX", "aimZ", "spinX", "spinY", "dailyShotCount", "power"] {
            XCTAssertEqual(after[key]!, before[key]!, accuracy: key == "power" ? 0.001 : 0.000001, key)
        }
    }

    private func tap(_ app: XCUIApplication, at point: CGPoint) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    private func openTransparency(_ app: XCUIApplication) {
        app.buttons["freeplay.moreMenu"].tap()
        let item = app.buttons["dailyClearance.spinTransparencyMenu"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertTrue(item.isHittable)
        item.tap()
        XCTAssertTrue(app.sliders["dailyClearance.spinTransparencySlider"].waitForExistence(timeout: 5))
    }

    func testDailyPanelTextAndSliderRemainReadableAtConfiguredType() throws {
        let app = try launch(); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            mode(app, dimension)
            openTransparency(app)
            try capture(app, "text-\(dimension)-open")
            let done = app.buttons["dailyClearance.spinTransparencyDone"]
            contain(app, done, hit: true)
            let panel = element(app, "dailyClearance.spinTransparencyPanel")
            contain(app, panel)
            XCTAssertFalse(panel.frame.intersects(element(app, "dailyClearance.strike").frame),
                "Scrolling settings must leave the strike button visually separate")
            let card = element(app, "spinPad.card")
            let more = element(app, "freeplay.moreMenu").frame
            XCTAssertEqual(panel.frame.maxX, more.maxX, accuracy: 0.5)
            XCTAssertEqual(panel.frame.minY, more.maxY + 2, accuracy: 0.5)
            if panel.frame.intersects(card.frame) {
                // A large-type panel may cover decoration, but never all access
                // to the close control. Input shielding is checked separately.
                XCTAssertTrue(done.isHittable)
            }
            for suffix in ["Title", "Percent", "OpaqueLabel", "TransparentLabel"] {
                let node = element(app, "dailyClearance.spinTransparency" + suffix)
                XCTAssertTrue(node.exists)
                let scroll = element(app, "dailyClearance.spinTransparencyScroll")
                if scroll.exists {
                    _ = try revealScrollItem(app, id: "dailyClearance.spinTransparency" + suffix,
                        scroll: scroll, clip: scroll.frame.intersection(panel.frame).intersection(app.windows.firstMatch.frame),
                        state: "text-\(dimension)-\(suffix)-reveal")
                }
                contain(app, node)
                XCTAssertTrue(node.isHittable)
                // Width and original PNG are evidence; complete AX labels do not prove glyphs.
                XCTAssertGreaterThan(node.frame.width, 0, "Width is evidence only; screenshot review must reject vertical glyph strips")
                try capture(app, "text-\(dimension)-\(suffix)")
            }
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            let scroll = element(app, "dailyClearance.spinTransparencyScroll")
            if scroll.exists {
                _ = try revealScrollItem(app, id: "dailyClearance.spinTransparencySlider",
                    scroll: scroll, clip: scroll.frame.intersection(panel.frame).intersection(app.windows.firstMatch.frame),
                    state: "text-\(dimension)-slider-reveal")
            }
            contain(app, slider)
            XCTAssertTrue(slider.isHittable)
            for (position, expected) in [(CGFloat(0), "0%"), (CGFloat(1), "100%")] {
                // UISlider retains the grab offset within its enlarged touch thumb.
                // Drag beyond the track in slider-local coordinates, then read back
                // the exact endpoint; a second grab may be needed after a track tap.
                for _ in 0..<3 {
                    if slider.value as? String == expected { break }
                    let current = CGFloat(slider.normalizedSliderPosition)
                    let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.15 + current * 0.7, dy: 0.5))
                    let end = slider.coordinate(withNormalizedOffset: CGVector(dx: position == 0 ? -0.3 : 1.3, dy: 0.5))
                    start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
                }
                waitValue(slider, expected)
                XCTAssertFalse(panel.frame.intersects(element(app, "dailyClearance.strike").frame))
                try capture(app, "text-\(dimension)-endpoint-\(expected)")
            }
            done.tap()
            XCTAssertFalse(slider.exists)
            XCTAssertTrue(element(app, "spinPad.disc").exists)
            try capture(app, "text-\(dimension)-settings-closed-preview-remains")
            openTransparency(app)
            waitValue(slider, "100%")
            try capture(app, "text-\(dimension)-reopened-persisted")
            done.tap()
            app.buttons["shotStage.spinEntry"].tap()
            XCTAssertFalse(element(app, "spinPad.disc").exists)
            try capture(app, "text-\(dimension)-closed")
        }
    }

    func testDailySpinKeysResetAndOverlayPreventUnderlyingInput() throws {
        let app = try launch(); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            // The C56 mode control now lives in the shared menu.
            p01More(app)
            let modeControl = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(modeControl.waitForExistence(timeout: 3))
            if modeControl.value as? String != dimension { modeControl.tap() }
            waitValue(modeControl, dimension)
            let stageCenter = element(app, "freeplay.stage").frame
            tap(app, at: CGPoint(x: stageCenter.midX, y: stageCenter.midY))
            XCTAssertFalse(element(app, "dailyClearance.menuPanel").exists)
            let powerPoint = CGPoint(x: element(app, "shotStage.powerBar").frame.midX,
                                     y: element(app, "shotStage.powerBar").frame.midY)
            app.buttons["shotStage.spinEntry"].tap()
            let disc = element(app, "spinPad.disc")
            contain(app, element(app, "spinPad.card")); contain(app, disc)
            try assertSpinCardInsideInnerRails(app)
            let reset = app.buttons["回中"]
            for (label, key, sign) in [("高杆增加 1%", "spinY", 1.0), ("低杆增加 1%", "spinY", -1.0),
                                       ("左塞增加 1%", "spinX", 1.0), ("右塞增加 1%", "spinX", -1.0)] {
                contain(app, reset, hit: true); reset.tap()
                let before = try state(app)
                let keyNode = app.buttons[label]
                contain(app, keyNode, hit: true); keyNode.tap()
                let after = try state(app)
                XCTAssertGreaterThan(sign * (after[key]! - before[key]!), 0)
                XCTAssertEqual(after["dailyShotCount"], before["dailyShotCount"])
                reset.tap()
                let restored = try state(app)
                XCTAssertEqual(restored["spinX"]!, before["spinX"]!, accuracy: 0.000001)
                XCTAssertEqual(restored["spinY"]!, before["spinY"]!, accuracy: 0.000001)
                try capture(app, "spin-\(dimension)-\(key)-\(sign)")
            }
            // Existing spin overlay only covers central stage. Record outside-card power
            // behavior separately; no guessed policy that all visible navigation is disabled.
            let beforeOutside = try state(app)
            tap(app, at: powerPoint)
            try capture(app, "spin-\(dimension)-outside-power-diagnostic")
            let afterOutside = try state(app)
            try JSONSerialization.data(withJSONObject: ["before": beforeOutside, "after": afterOutside])
                .write(to: output.appendingPathComponent("spin-\(dimension)-outside-state.json"))
            if disc.exists { app.buttons["shotStage.spinEntry"].tap() }
            p01More(app)
            customItem(app, "dailyClearance.spinTransparencyMenu").tap()
            XCTAssertTrue(app.sliders["dailyClearance.spinTransparencySlider"].waitForExistence(timeout: 5))
            let panel = element(app, "dailyClearance.spinTransparencyPanel")
            try assertSpinCardInsideInnerRails(app)
            let before = try state(app)
            // Non-action card padding: verify events cannot reach the visible scene below.
            let coveredPoint = CGPoint(x: panel.frame.minX + 2, y: panel.frame.midY)
            try capture(app, "spin-\(dimension)-covered-before")
            tap(app, at: coveredPoint)
            try capture(app, "spin-\(dimension)-covered-after-tap")
            XCTAssertTrue(panel.exists, "Non-action card padding tap must not dismiss")
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: coveredPoint.x, dy: coveredPoint.y))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 12)))
            unchanged(before, try state(app))
            XCTAssertTrue(panel.exists)
            try capture(app, "spin-\(dimension)-covered-no-through")
            app.buttons["dailyClearance.spinTransparencyDone"].tap()
            // Outside-card close is allowed; its closing event must not alter shot state.
            let beforeClose = try state(app)
            let stage = element(app, "freeplay.stage").frame
            let closePoint = CGPoint(x: stage.minX + 8, y: stage.minY + 8)
            XCTAssertFalse(element(app, "spinPad.card").frame.contains(closePoint))
            tap(app, at: closePoint)
            XCTAssertFalse(disc.exists)
            unchanged(beforeClose, try state(app))
            try capture(app, "spin-\(dimension)-outside-close")
        }
    }

    private func assertSpinCardInsideInnerRails(_ app: XCUIApplication) throws {
        let raw = try XCTUnwrap(element(app, "dailyLayout.spinGeometry").value as? String)
        let values = Dictionary(uniqueKeysWithValues: raw.split(separator: " ").compactMap { token -> (String, Double)? in
            let pair = token.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, let value = Double(pair[1]) else { return nil }
            return (String(pair[0]), value)
        })
        let inner = CGRect(x: try XCTUnwrap(values["innerX"]), y: try XCTUnwrap(values["innerY"]),
                           width: try XCTUnwrap(values["innerWidth"]), height: try XCTUnwrap(values["innerHeight"]))
        let card = element(app, "spinPad.card").frame
        let disc = element(app, "spinPad.disc").frame
        XCTAssertTrue(clipContainsWithRoundoff(inner, frame: card), "The whole spin card must remain inside the inner rails: \(card), inner \(inner)")
        XCTAssertEqual(card.height, card.width, accuracy: 0.5)
        XCTAssertEqual(disc.width, card.width - 104, accuracy: 0.5)
        XCTAssertEqual(disc.width, disc.height, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(disc.width, 44)
        XCTAssertEqual(card.midX, inner.midX, accuracy: 0.5)
        XCTAssertEqual(card.midY, inner.midY, accuracy: 0.5)
        for label in ["高杆增加 1%", "低杆增加 1%", "左塞增加 1%", "右塞增加 1%"] {
            let key = app.buttons[label].frame
            XCTAssertGreaterThanOrEqual(key.width, 44)
            XCTAssertGreaterThanOrEqual(key.height, 44)
        }
    }

    func testDailyPanelDismissesBeforeCameraCentersActivate() throws {
        let app = try launch(); defer { app.terminate() }
        mode(app, "3D")
        let before = try state(app)
        let panel = element(app, "dailyClearance.spinTransparencyPanel")
        func cameraField(_ key: String) -> String? {
            guard let raw = element(app, "v63.cameraDiagnostics").value as? String else { return nil }
            return raw.split(separator: " ").first { $0.hasPrefix(key + "=") }
                .map { String($0.dropFirst(key.count + 1)) }
        }
        func waitCamera(_ key: String, _ expected: String) throws {
            let e = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                cameraField(key) == expected && cameraField("twoViewMoving") == "false"
            }, object: nil)
            let outcome = XCTWaiter.wait(for: [e], timeout: 8)
            let raw = try XCTUnwrap(element(app, "v63.cameraDiagnostics").value as? String)
            try raw.write(to: output.appendingPathComponent("camera-wait-" + key + "-" + expected + ".txt"),
                          atomically: true, encoding: .utf8)
            try capture(app, "camera-wait-" + key + "-" + expected)
            XCTAssertEqual(outcome, .completed)
        }
        func dismissThenActivate(_ id: String, _ tag: String) throws {
            let control = app.buttons[id]
            contain(app, control, hit: true)
            let originalFrame = control.frame
            openTransparency(app)
            XCTAssertTrue(panel.exists)
            let center = CGPoint(x: originalFrame.midX, y: originalFrame.midY)
            let player = try XCTUnwrap(cameraField("twoViewMode"))
            let temporary = try XCTUnwrap(cameraField("twoViewTemporary2D"))
            try capture(app, "camera-" + tag + "-settings-open")
            // The established full-page dismissal layer owns this first tap.
            // Requiring a camera action here would contradict no-through behavior.
            if panel.frame.contains(center) {
                app.buttons["dailyClearance.spinTransparencyDone"].tap()
            } else {
                tap(app, at: center)
            }
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: panel)
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
            unchanged(before, try state(app))
            XCTAssertEqual(cameraField("twoViewMode"), player)
            XCTAssertEqual(cameraField("twoViewTemporary2D"), temporary)
            try capture(app, "camera-" + tag + "-dismissed-no-through")
            XCTAssertEqual(control.frame, originalFrame)
            tap(app, at: center)
        }
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        try dismissThenActivate("shotCamera.firstPerson", "first-person")
        try waitCamera("twoViewMode", "firstPerson")
        unchanged(before, try state(app))
        try dismissThenActivate("shotCamera.temporaryTopDown", "topdown")
        try waitCamera("twoViewTemporary2D", "true")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        try waitCamera("twoViewTemporary2D", "false")
        unchanged(before, try state(app))
        try dismissThenActivate("shotCamera.thirdPerson", "player")
        try waitCamera("twoViewMode", "thirdPerson")
        unchanged(before, try state(app))
        XCTAssertFalse(element(app, "spinPad.disc").exists)
        try capture(app, "camera-player-after")
    }

    private func aimCloseup(_ app: XCUIApplication) throws -> Bool {
        let raw = try XCTUnwrap(element(app, "dailyLayout.controlsProbe").value as? String)
        let field = try XCTUnwrap(raw.split(separator: " ").first { $0.hasPrefix("showAimCloseup=") })
        let value = String(field.dropFirst("showAimCloseup=".count))
        XCTAssertTrue(value == "true" || value == "false")
        return value == "true"
    }

    // A native menu virtualizes its rows at large Dynamic Type. Discover the
    // visible first row and collection before waiting for a currently absent tail.
    private func revealMenuItem(_ app: XCUIApplication, id: String, state: String) throws -> XCUIElement {
        let first = app.buttons["dailyClearance.spinTransparencyMenu"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let collections = app.collectionViews.allElementsBoundByIndex
        nativeMenuIndex = try XCTUnwrap(collections.indices.first {
            collections[$0].buttons["dailyClearance.spinTransparencyMenu"].exists
        }, "The opened native menu must expose its observed CollectionView")
        let collection = app.collectionViews.element(boundBy: nativeMenuIndex)
        let nativeFrame = collection.frame
        var clippingFrames: [CGRect] = []
        for other in app.otherElements.allElementsBoundByIndex {
            let rect = other.frame
            guard abs(rect.minX - nativeFrame.minX) < 1 else { continue }
            guard abs(rect.width - nativeFrame.width) < 1 else { continue }
            guard abs(rect.minY - nativeFrame.minY) < 1 else { continue }
            if rect.height > 80 && rect.height <= nativeFrame.height { clippingFrames.append(rect) }
        }
        // The actual ancestor clip is shorter than CollectionView.frame on iOS 26.
        let clip = (clippingFrames.min { $0.height < $1.height } ?? nativeFrame)
            .intersection(app.windows.firstMatch.frame)
        nativeMenuClip = clip
        return try revealScrollItem(app, id: id, scroll: collection, clip: clip, state: state)
    }

    /// Roundoff only: eight ULPs at the clip's coordinate magnitude, not a display-pixel allowance.
    private func clipContainsWithRoundoff(_ clip: CGRect, frame: CGRect) -> Bool {
        let magnitude = max(1, abs(clip.minX), abs(clip.maxX), abs(clip.minY), abs(clip.maxY))
        let tolerance = magnitude.ulp * 8
        return clip.insetBy(dx: -tolerance, dy: -tolerance).contains(frame)
    }

    private func revealScrollItem(_ app: XCUIApplication, id: String, scroll: XCUIElement,
                                  clip: CGRect, state: String) throws -> XCUIElement {
        let item = element(app, id)
        try capture(app, state + "-initial-raw")
        let safe = clip.insetBy(dx: 12, dy: 12)
        XCTAssertGreaterThan(safe.height, 80)
        for index in 0..<15 {
            // Do not query hittability of an offscreen row: XCTest can throw.
            if item.exists && clipContainsWithRoundoff(clip, frame: item.frame) && item.isHittable { break }
            XCTAssertTrue(scroll.exists)
            var delta = safe.height * 0.35
            if item.exists {
                if item.frame.minY < safe.minY { delta = -min(delta, safe.minY - item.frame.minY + 4) }
                else if item.frame.maxY > safe.maxY { delta = min(delta, item.frame.maxY - safe.maxY + 4) }
            }
            // Begin on visible reading content, not an embedded Slider. A drag
            // originating on its thumb can be consumed without scrolling at all.
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            let panelScroll = scroll.identifier == "dailyClearance.spinTransparencyScroll"
            let sliderFrame = panelScroll && slider.exists ? slider.frame : .null
            let candidates: [CGFloat]
            if panelScroll {
                candidates = delta > 0
                    ? [safe.maxY, safe.minY + safe.height * 0.75, safe.midY]
                    : [safe.minY, safe.minY + safe.height * 0.25, safe.midY]
            } else {
                // Native lists may extend beneath system bars. Keep the qualified
                // interior gesture instead of beginning beside the home indicator.
                candidates = [delta > 0 ? safe.minY + safe.height * 0.75
                    : safe.minY + safe.height * 0.25, safe.midY]
            }
            let fromY = try XCTUnwrap(candidates.first { y in
                !sliderFrame.insetBy(dx: -4, dy: -4).contains(CGPoint(x: safe.midX, y: y))
                    && safe.minY <= y - delta && y - delta <= safe.maxY
            }, "No visible non-slider scroll origin; preserve failure evidence")
            let previousSliderValue = panelScroll && slider.exists ? slider.value as? String : nil
            let gestureRecord: [String: Any] = ["clip": frame(clip),
                "from": ["x": safe.midX, "y": fromY], "to": ["x": safe.midX, "y": fromY - delta],
                "sliderFrame": sliderFrame.isNull ? [:] : frame(sliderFrame),
                "sliderValue": previousSliderValue ?? "not-panel-slider"]
            try JSONSerialization.data(withJSONObject: gestureRecord, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent(state + "-scroll-\(index)-gesture.json"))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: safe.midX, dy: fromY)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: safe.midX, dy: fromY - delta)),
                withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
            if let previousSliderValue {
                XCTAssertEqual(slider.value as? String, previousSliderValue,
                    "Reading scroll must not accidentally adjust transparency")
            }
            try capture(app, state + "-scroll-\(index)", extraIDs: [id], includeBaseDiagnostics: false)
        }
        XCTAssertTrue(item.exists, "Last row must actually enter the accessibility tree")
        XCTAssertTrue(clipContainsWithRoundoff(clip, frame: item.frame), "The full final row must enter the observed viewport")
        XCTAssertTrue(item.isHittable)
        return item
    }

    private func revealLastMenuItem(_ app: XCUIApplication, dimension: String) throws -> XCUIElement {
        try revealMenuItem(app, id: "menu.aimCloseup", state: "menu-\(dimension)")
    }

    private func dismissMenu(_ app: XCUIApplication, dimension: String) throws {
        let collection = app.collectionViews.element(boundBy: nativeMenuIndex)
        XCTAssertTrue(collection.exists)
        let window = app.windows.firstMatch.frame
        let occupied = ["dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu",
            "shotStage.aimWheel", "shotStage.instrument", "dailyClearance.strike", "dailyClearance.undo",
            "dailyClearance.playback", "break.entry"].map { element(app, $0) }.filter { $0.exists }.map { $0.frame }
        // Pick an observed stage blank, outside collection and every visible interactive node.
        let stage = element(app, "freeplay.stage").frame.intersection(window)
        let candidates = [CGPoint(x: stage.midX, y: stage.minY + 12),
                          CGPoint(x: stage.minX + 12, y: stage.midY),
                          CGPoint(x: stage.midX, y: stage.maxY - 12)]
        let point = try XCTUnwrap(candidates.first { point in
            window.contains(point) && !collection.frame.contains(point) &&
            !occupied.contains { $0.insetBy(dx: -4, dy: -4).contains(point) }
        }, "No observed empty dismiss point; do not tap More through popover")
        let before = try state(app)
        try JSONSerialization.data(withJSONObject: ["x": point.x, "y": point.y])
            .write(to: output.appendingPathComponent("menu-\(dimension)-dismiss-point.json"))
        tap(app, at: point)
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: collection)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 3), .completed)
        unchanged(before, try state(app))
        XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
        try capture(app, "menu-\(dimension)-dismissed")
    }

    func testDailyNativeMoreLastDisplayItemIsReachable() throws {
        let app = try launch(); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            mode(app, dimension)
            let before = try state(app)
            let original = try aimCloseup(app)
            app.buttons["freeplay.moreMenu"].tap()
            let item = try revealLastMenuItem(app, dimension: dimension)
            item.tap()
            waitNativeMenuClosed(app)
            XCTAssertEqual(try aimCloseup(app), !original, "Real UI action must change preferences")
            app.buttons["freeplay.moreMenu"].tap()
            let restoredItem = try revealLastMenuItem(app, dimension: dimension + "-changed")
            try capture(app, "menu-\(dimension)-toggled-checkmark")
            restoredItem.tap()
            waitNativeMenuClosed(app)
            XCTAssertEqual(try aimCloseup(app), original)
            app.buttons["freeplay.moreMenu"].tap()
            _ = try revealLastMenuItem(app, dimension: dimension + "-restore")
            try capture(app, "menu-\(dimension)-restored-checkmark")
            try dismissMenu(app, dimension: dimension)
            unchanged(before, try state(app))
        }
    }
    private func waitNativeMenuClosed(_ app: XCUIApplication) {
        let menu = app.collectionViews.element(boundBy: nativeMenuIndex)
        let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: menu)
        XCTAssertEqual(XCTWaiter.wait(for: [e], timeout: 3), .completed)
    }

    private func modelField(_ app: XCUIApplication, _ key: String) throws -> String {
        let raw = try XCTUnwrap(element(app, "dailyLayout.controlsProbe").value as? String)
        let field = try XCTUnwrap(raw.split(separator: " ").first { $0.hasPrefix(key + "=") }, "Missing model field \(key)")
        return String(field.dropFirst(key.count + 1))
    }

    private func waitModel(_ app: XCUIApplication, _ key: String, _ value: String, state: String) throws {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let raw = self.element(app, "dailyLayout.controlsProbe").value as? String else { return false }
            return raw.split(separator: " ").contains(Substring(key + "=" + value))
        }, object: nil)
        let reached = XCTWaiter.wait(for: [e], timeout: 5)
        try capture(app, state)
        XCTAssertEqual(reached, .completed)
    }

    private func decision(_ app: XCUIApplication, _ id: String, state: String) throws -> XCUIElement {
        let node = element(app, id)
        XCTAssertTrue(node.waitForExistence(timeout: 5)); contain(app, node, hit: true)
        try capture(app, state, extraIDs: [id])
        // Text width/raw AX/PNG are evidence; glyph completeness requires original-image review.
        return node
    }

    func testDailyResultLastActionsRemainReadableAndReachable() throws {
        for appearance in ["Light", "Dark"] {
            for dimension in ["2D", "3D"] {
                for fixture in ["completed", "failed"] {
                    let app = try launch(fixture: fixture, extra: ["-v54.force\(appearance)"]); defer { app.terminate() }
                    mode(app, dimension)
                    let prefix = "result-\(appearance)-\(dimension)-\(fixture)"
                    let id = fixture == "completed" ? "dailyClearance.replay" : "dailyClearance.rerack"
                    let last = try decision(app, id, state: prefix + "-last-readable")
                    XCTAssertEqual(try modelField(app, "game"), "chineseEightBall")
                    if fixture == "failed" { XCTAssertEqual(try modelField(app, "phase"), "failed") }
                    last.tap()
                    if fixture == "failed" {
                        let restart = try decision(app, "dailyClearance.rerackAfterBreak", state: prefix + "-confirm")
                        restart.tap()
                    }
                    // Both actual actions use resetAndBeginManualRack, without a synthetic strike.
                    try waitModel(app, "phase", "manualRacked", state: prefix + "-new-rack")
                    XCTAssertEqual(try modelField(app, "dailyShotCount"), "0")
                    XCTAssertFalse(element(app, id).exists)
                    app.terminate()
                }
            }
        }
    }

    func testDailyRerackCancelRestartAndLastBreakChoiceRespectState() throws {
        for dimension in ["2D", "3D"] {
            let app = try launch(); defer { app.terminate() }
            mode(app, dimension)
            let before = try state(app)
            app.buttons["break.entry"].tap()
            let cancel = try decision(app, "dailyClearance.confirmBreak", state: "confirm-\(dimension)-cancel-ready")
            _ = try decision(app, "dailyClearance.rerackAfterBreak", state: "confirm-\(dimension)-restart-ready")
            cancel.tap()
            XCTAssertFalse(element(app, "dailyClearance.confirmBreak").exists)
            unchanged(before, try state(app))
            XCTAssertEqual(try modelField(app, "phase"), "playing")
            app.buttons["break.entry"].tap()
            let restart = try decision(app, "dailyClearance.rerackAfterBreak", state: "confirm-\(dimension)-second-ready")
            restart.tap()
            try waitModel(app, "phase", "manualRacked", state: "confirm-\(dimension)-restarted")
            XCTAssertEqual(try modelField(app, "dailyShotCount"), "0")
            app.terminate()
            // A pending rule decision intentionally disables the settings menu.
            // The fixture enters 2D; exercise that real reachable state once, then switch after resolving.
            guard dimension == "2D" else { continue }
            let weak = try launch(fixture: "weakBreak"); defer { weak.terminate() }
            XCTAssertFalse(weak.buttons["freeplay.moreMenu"].isEnabled)
            XCTAssertEqual(try modelField(weak, "breakChoiceCount"), "3")
            let notice = element(weak, "dailyClearance.notice")
            XCTAssertTrue(notice.exists)
            element(weak, "dailyClearance.ruleChoice.rerack").tap()
            for raw in ["rerackByIncoming", "rerackByBreaker"] {
                _ = customItem(weak, "dailyClearance.ruleChoice." + raw)
                _ = try decision(weak, "dailyClearance.ruleChoice." + raw, state: "choice-\(dimension)-" + raw)
            }
            customItem(weak, "dailyClearance.ruleChoice.back").tap()
            XCTAssertEqual(try modelField(weak, "breakChoiceCount"), "3")
            let count = try modelField(weak, "dailyShotCount")
            element(weak, "dailyClearance.ruleChoice.acceptBallInHand").tap()
            try waitModel(weak, "breakChoiceCount", "0", state: "choice-\(dimension)-resolved")
            XCTAssertEqual(try modelField(weak, "phase"), "playing")
            XCTAssertEqual(try modelField(weak, "cuePlacement"), "anywhere")
            XCTAssertEqual(try modelField(weak, "dailyShotCount"), count)
            XCTAssertFalse(element(weak, "dailyClearance.ruleChoice.acceptBallInHand").exists)
            mode(weak, "3D")
            XCTAssertEqual(try modelField(weak, "cuePlacement"), "anywhere")
            weak.terminate()
        }
    }

    func testDailyGamePickerLastRowAndProgressAbandonConfirmationRemainReachable() throws {
        for dimension in ["2D", "3D"] {
            let app = try launch(fixture: "progress"); defer { app.terminate() }
            mode(app, dimension)
            let originalGame = try modelField(app, "game")
            let originalCount = try modelField(app, "dailyShotCount")
            XCTAssertEqual(originalGame, "chineseEightBall"); XCTAssertEqual(originalCount, "2")
            // Source DailyClearanceGame.allCases declaration ends with fourBall.
            func chooseLast(_ suffix: String) throws {
                app.buttons["freeplay.moreMenu"].tap()
                let change = try revealMenuItem(app, id: "dailyClearance.changeGame",
                                                state: "game-\(dimension)-\(suffix)-menu")
                change.tap()
                XCTAssertTrue(element(app, "dailyClearance.game.chineseEightBall").waitForExistence(timeout: 5))
                nativeMenuClip = nil
                let collection = app.collectionViews.firstMatch
                let table = app.tables.firstMatch
                let listAppeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    collection.exists || table.exists
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [listAppeared], timeout: 5), .completed)
                let scroll = collection.exists ? collection : table
                let last = try revealScrollItem(app, id: "dailyClearance.game.fourBall", scroll: scroll,
                    clip: scroll.frame.intersection(app.windows.firstMatch.frame),
                    state: "game-\(dimension)-\(suffix)-list")
                contain(app, last, hit: true)
                try capture(app, "game-\(dimension)-\(suffix)-last-row")
                last.tap()
                XCTAssertTrue(app.buttons["放弃并切换"].waitForExistence(timeout: 5))
                try capture(app, "game-\(dimension)-\(suffix)-abandon-confirm")
            }
            try chooseLast("cancel")
            let cancel = app.buttons["取消"]
            if cancel.exists {
                contain(app, cancel, hit: true)
                cancel.tap()
            } else {
                // A native popover omits its cancel row and exposes an outside
                // dismissal region. Validate that observed system presentation.
                XCTAssertTrue(element(app, "PopoverDismissRegion").exists)
                let popover = app.popovers.firstMatch
                XCTAssertTrue(popover.exists)
                let stage = element(app, "freeplay.stage").frame
                let window = app.windows.firstMatch.frame
                let occupied = ["dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu",
                    "shotStage.aimWheel", "shotStage.instrument", "dailyClearance.strike", "break.entry"]
                    .map { element(app, $0) }.filter { $0.exists }.map { $0.frame }
                let candidates = [CGPoint(x: stage.minX + 12, y: stage.midY),
                    CGPoint(x: stage.midX, y: stage.maxY - 12)]
                let point = try XCTUnwrap(candidates.first { point in
                    window.contains(point) && !popover.frame.contains(point)
                        && !occupied.contains { $0.contains(point) }
                }, "No observed safe outside dismissal point")
                try JSONSerialization.data(withJSONObject: ["x": point.x, "y": point.y])
                    .write(to: output.appendingPathComponent("game-\(dimension)-cancel-outside-point.json"))
                tap(app, at: point)
            }
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["放弃并切换"])
            XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
            XCTAssertEqual(try modelField(app, "game"), originalGame)
            XCTAssertEqual(try modelField(app, "dailyShotCount"), originalCount)
            try chooseLast("accept")
            contain(app, app.buttons["放弃并切换"], hit: true); app.buttons["放弃并切换"].tap()
            try waitModel(app, "game", "fourBall", state: "game-\(dimension)-changed")
            try waitModel(app, "phase", "manualRacked", state: "game-\(dimension)-new-rack")
            XCTAssertEqual(try modelField(app, "dailyShotCount"), "0")
            app.terminate()
        }
    }

    private func customItem(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let item = element(app, id)
        let scroll = element(app, "dailyClearance.menuScroll")
        contain(app, element(app, "dailyClearance.menuPanel"))
        for _ in 0..<24 {
            if item.exists && scroll.frame.insetBy(dx: -1, dy: -1).contains(item.frame) && item.isHittable { return item }
            let down = item.exists && item.frame.minY < scroll.frame.minY
            let gap = down ? scroll.frame.minY - item.frame.minY + 6 : item.frame.maxY - scroll.frame.maxY + 6
            let distance = min(scroll.frame.height * 0.4, max(12, gap))
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.3 : 0.7))
            let end = start.withOffset(CGVector(dx: 0, dy: down ? distance : -distance))
            start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        try? capture(app, "custom-menu-unreachable-" + id, extraIDs: ["dailyClearance.menuPanel", "dailyClearance.menuScroll", id])
        XCTFail("Custom menu item not reachable: \(id), item=\(item.frame), scroll=\(scroll.frame), hittable=\(item.isHittable)")
        return item
    }

    func testV4CustomMenusApplyOptionsAndReturnWithoutChangingRack() throws {
        let app = try launch(); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            mode(app, dimension)
            let before = try state(app)
            func open(_ id: String) {
                if app.buttons["dailyClearance.menuBack"].exists { app.buttons["dailyClearance.menuBack"].tap() }
                if !element(app, "dailyClearance.menuPanel").exists { app.buttons["freeplay.moreMenu"].tap() }
                customItem(app, id).tap()
            }
            open("dailyClearance.aimModeMenu")
            XCTAssertTrue(app.buttons["dailyClearance.menuBack"].isHittable)
            app.buttons["dailyClearance.menuBack"].tap()
            customItem(app, "dailyClearance.aimModeMenu").tap()
            customItem(app, "dailyClearance.aim.free").tap()
            open("dailyClearance.aimModeMenu")
            XCTAssertEqual(customItem(app, "dailyClearance.aim.free").value as? String, "已选")
            customItem(app, "dailyClearance.aim.pocket").tap()
            for value in (dimension == "3D" ? [3, 2, 1, 0] : [2, 1, 0]) {
                open("dailyClearance.trajectoryMenu")
                customItem(app, "dailyClearance.trajectory.\(value)").tap()
                open("dailyClearance.trajectoryMenu")
                XCTAssertEqual(customItem(app, "dailyClearance.trajectory.\(value)").value as? String, "已选")
                try capture(app, "v4-menu-\(dimension)-trajectory-\(value)")
                app.buttons["dailyClearance.menuClose"].tap()
            }
            app.buttons["freeplay.moreMenu"].tap()
            let original = try aimCloseup(app)
            customItem(app, "menu.aimCloseup").tap()
            XCTAssertEqual(try aimCloseup(app), !original)
            customItem(app, "menu.aimCloseup").tap()
            XCTAssertEqual(try aimCloseup(app), original)
            let grid = customItem(app, "menu.tableGrid")
            let originalGrid = grid.value as? String
            grid.tap()
            XCTAssertNotEqual(customItem(app, "menu.tableGrid").value as? String, originalGrid)
            customItem(app, "menu.tableGrid").tap()
            XCTAssertEqual(customItem(app, "menu.tableGrid").value as? String, originalGrid)
            try capture(app, "v4-menu-\(dimension)-last-options")
            let stage = element(app, "freeplay.stage").frame
            tap(app, at: CGPoint(x: stage.minX + 4, y: stage.midY))
            XCTAssertFalse(element(app, "dailyClearance.menuPanel").exists)
            XCTAssertEqual(try state(app)["dailyShotCount"], before["dailyShotCount"])
        }
    }

    func testV4GameChangeAndRerackConfirmationsPreserveCancelAndApply() throws {
        let app = try launch(fixture: "progress"); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            mode(app, dimension)
            app.buttons["break.entry"].tap()
            let card = element(app, "dailyClearance.confirmation")
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            try capture(app, "v4-confirm-\(dimension)-rerack", extraIDs: ["dailyClearance.confirmation"])
            contain(app, card)
            let before = try state(app)
            app.buttons["dailyClearance.confirmBreak"].tap()
            unchanged(before, try state(app))
            func choose() {
                app.buttons["freeplay.moreMenu"].tap()
                customItem(app, "dailyClearance.changeGame").tap()
                customItem(app, "dailyClearance.game.fourBall").tap()
            }
            choose()
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            try capture(app, "v4-confirm-\(dimension)-game", extraIDs: ["dailyClearance.confirmation"])
            contain(app, card)
            let title = element(app, "dailyClearance.confirmationTitle")
            let titleScroll = element(app, "dailyClearance.confirmationTitleScroll")
            XCTAssertTrue(titleScroll.frame.insetBy(dx: -1, dy: -1).contains(title.frame),
                          "Calibration devices must show the complete decision title, not just tappable actions")
            app.buttons["dailyClearance.gameChangeCancel"].tap()
            unchanged(before, try state(app))
        }
        app.buttons["freeplay.moreMenu"].tap()
        customItem(app, "dailyClearance.changeGame").tap()
        customItem(app, "dailyClearance.game.fourBall").tap()
        app.buttons["dailyClearance.gameChangeConfirm"].tap()
        try waitModel(app, "game", "fourBall", state: "v4-confirm-game-applied")
        XCTAssertEqual(try modelField(app, "phase"), "manualRacked")
        XCTAssertEqual(try modelField(app, "dailyShotCount"), "0")
    }

    /// Seven approved semantic states, rendered in both dimensions on each calibration container.
    func testV4FinalStaticStateTour() throws {
        for fixture in ["selectionOpen", "selection", "ballInHand", "selectionStripe", "weakBreak", "completed", "failed"] {
            let app = try launch(fixture: fixture)
            for dimension in ["2D", "3D"] {
                mode(app, dimension)
                if fixture == "selection" { app.buttons["paletteBall__8"].tap() }
                try capture(app, "final-state-\(fixture)-\(dimension)", extraIDs: [
                    "dailyClearance.notice", "dailyClearance.ruleChoice.rerack", "dailyClearance.ruleChoice.acceptBallInHand",
                    "dailyClearance.replay", "dailyClearance.rerack"])
                contain(app, element(app, "freeplay.cameraMode"), hit: true)
                contain(app, element(app, "dailyClearance.back"), hit: true)
                for id in ["dailyClearance.notice", "dailyClearance.ruleChoice.rerack",
                           "dailyClearance.ruleChoice.acceptBallInHand", "dailyClearance.replay", "dailyClearance.rerack"] {
                    let node = element(app, id)
                    if node.exists { contain(app, node) }
                }
            }
            app.terminate()
        }
    }

    func testV4BackgroundRestoresParametersAndRenderer() throws {
        let app = try launch(); defer { app.terminate() }
        for dimension in ["2D", "3D"] {
            mode(app, dimension)
            func renderer() throws -> String {
                let raw = try XCTUnwrap(element(app, "table.scene").value as? String)
                let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                return try XCTUnwrap(data["rendererID"] as? String)
            }
            let before = try state(app)
            let identity = try renderer()
            try capture(app, "background-\(dimension)-before")
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
            XCTAssertTrue(element(app, "freeplay.stage").waitForExistence(timeout: 8))
            unchanged(before, try state(app))
            XCTAssertEqual(try renderer(), identity)
            // mode() closes the menu. Reopen it to read the current selection;
            // do not call mode() here, which could change the value under test.
            app.buttons["freeplay.moreMenu"].tap()
            XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout: 3))
            XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, dimension)
            app.buttons["关闭菜单"].tap()
            try capture(app, "background-\(dimension)-returned")
        }
    }

    func testV4RealPadWindowResizePreservesIntent() throws {
        let app = try launch(fixture: "manual"); defer { app.terminate() }
        mode(app, "2D")
        try XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription
            .write(to: output.appendingPathComponent("system-window-controls.txt"), atomically: true, encoding: .utf8)
        let window = app.windows.firstMatch
        let original = window.frame
        let originalWidth = try XCTUnwrap(Double(try modelField(app, "pageWidth")))
        let originalHeight = try XCTUnwrap(Double(try modelField(app, "pageHeight")))
        app.buttons["shotStage.spinEntry"].tap()
        app.buttons["chevron.up"].tap()
        let before = try state(app)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.99))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.72))
        try capture(app, "system-resize-before")
        start.press(forDuration: 1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(window.frame.width - original.width) > 30 || abs(window.frame.height - original.height) > 30
        }, object: nil)
        let result = XCTWaiter.wait(for: [changed], timeout: 8)
        try capture(app, "system-resize-after")
        XCTAssertEqual(result, .completed, "Only actual OS window changes qualify; never substitute a fixed DEBUG viewport")
        let contentChanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let width = Double((try? self.modelField(app, "pageWidth")) ?? "") ?? originalWidth
            let height = Double((try? self.modelField(app, "pageHeight")) ?? "") ?? originalHeight
            return abs(width - originalWidth) > 30 || abs(height - originalHeight) > 30
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [contentChanged], timeout: 8), .completed,
                       "The app layout must resize too; compositor scaling alone does not qualify")
        try capture(app, "system-resize-settled")
        let systemControl = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .buttons["window-controls:com.xinkuan.qiuji"]
        if systemControl.exists {
            XCTAssertFalse(systemControl.frame.intersects(app.buttons["dailyClearance.back"].frame),
                           "System window controls must not cover the app back control")
        }
        unchanged(before, try state(app))
        XCTAssertEqual(element(app, "spinPad.disc").value as? String, "高1%")
        contain(app, element(app, "spinPad.card"))
    }

}

extension DailyAdaptivePanelUITests {
    /// Current home route is the composer-backed separation page. Its completed
    /// shots survive backgrounding; the old shotSimulation cancellation test
    /// below covers a different owner and must not stand in for this contract.
    func testActivityMaintenanceAcrossShotAndPageLifecycle() throws {
        let app = try launchP01(requiresLandscape: false); defer { app.terminate() }
        let strike = app.buttons["dailyClearance.strike"]
        func waitEnabled(_ button: XCUIElement, _ enabled: Bool) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "enabled == %@", NSNumber(value: enabled)),
                object: button)], timeout: 45), .completed)
        }
        p01More(app); app.buttons["freeplay.cameraMode"].tap(); p01CloseMenu(app)
        let original = try p01Balls(app)
        for shot in 0..<2 {
            waitEnabled(strike, true)
            strike.tap()
            waitEnabled(strike, false)
            waitEnabled(strike, true)
            let after = try p01Balls(app)
            XCTAssertNotEqual(after, original, "A real shot must move at least one ball")
            try capture(app, "activity-shot-\(shot)-settled")
            XCUIDevice.shared.press(.home); app.activate()
            waitEnabled(strike, true)
            assertP01BallsEqual(try p01Balls(app), after)
            if shot == 0 {
                app.buttons["dailyClearance.undo"].tap()
                waitEnabled(strike, true)
                assertP01BallsEqual(try p01Balls(app), original)
            }
        }
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
        app.buttons["分离角与走位"].tap()
        XCTAssertTrue(element(app, "composer.landscape").waitForExistence(timeout: 15))
        waitEnabled(strike, true)
        XCTAssertTrue(element(app, "table.scene").exists)
        try capture(app, "activity-reentered")
    }

    private func launchP01(requiresLandscape: Bool = true, extraArgs: [String] = [], normalizeView: Bool = true) throws -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics"] + extraArgs)
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_走位"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons["分离角与走位"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        if UIDevice.current.userInterfaceIdiom == .phone { XCUIDevice.shared.orientation = .landscapeLeft }
        card.tap()
        XCTAssertTrue(element(app, "composer.landscape").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "composer.landscape").label.contains("分离角与走位"))
        if requiresLandscape {
            let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        }
        _ = try state(app)
        if normalizeView {
            p01More(app)
            if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
            p01CloseMenu(app)
            _ = try state(app)
        }
        return app
    }

    private func p01Scene(_ app: XCUIApplication) throws -> [String: Any] {
        let raw = try XCTUnwrap(element(app, "table.scene").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }

    private func p01Balls(_ app: XCUIApplication) throws -> [String: [Double]] {
        let list = try XCTUnwrap(try p01Scene(app)["balls"] as? [[String: Any]])
        return try Dictionary(uniqueKeysWithValues: list.map {
            (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
        })
    }

    private func p01CloseMenu(_ app: XCUIApplication) {
        let close = app.buttons["dailyClearance.menuClose"]
        if close.exists { close.tap() }
        else if element(app, "dailyClearance.menuPanel").exists {
            app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.2, dy: 0.5)).tap()
        }
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].waitForNonExistence(timeout: 3))
    }

    private func p01More(_ app: XCUIApplication) {
        p01CloseMenu(app)
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(element(app, "dailyClearance.menuPanel").waitForExistence(timeout: 3))
    }

    private func p01ScrollMenu(_ app: XCUIApplication) {
        let rect = app.scrollViews["dailyClearance.menuScroll"].frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: rect.midX, dy: rect.maxY - 18)).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(.init(dx: rect.midX, dy: rect.minY + 18)))
    }

    private func p01MenuItem(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let item = app.buttons[id]
        for _ in 0..<3 {
            if item.exists && item.isHittable { return item }
            p01ScrollMenu(app)
        }
        XCTAssertTrue(item.isHittable, id)
        return item
    }

    private func assertP01BallsEqual(_ actual: [String: [Double]], _ expected: [String: [Double]], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(actual.keys), Set(expected.keys), file: file, line: line)
        for (key, coordinates) in expected {
            guard let observed = actual[key] else { continue }
            XCTAssertEqual(observed.count, coordinates.count, file: file, line: line)
            for (a, b) in zip(observed, coordinates) {
                XCTAssertEqual(a, b, accuracy: 0.000001, "World metres; 0.001 mm tolerance for Float snapshot round trips", file: file, line: line)
            }
        }
    }

    private func p01SetTransparencyEndpoint(_ slider: XCUIElement, to target: CGFloat) {
        precondition(target == 0 || target == 1)
        let expected = "\(Int(target * 100))%"
        for _ in 0..<3 {
            if slider.value as? String == expected { break }
            slider.adjust(toNormalizedSliderPosition: target)
            if slider.value as? String == expected { break }
            let current = CGFloat(slider.normalizedSliderPosition)
            let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1 + current * 0.8, dy: 0.5))
            let end = slider.coordinate(withNormalizedOffset: CGVector(dx: target == 0 ? -0.3 : 1.3, dy: 0.5))
            start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        waitValue(slider, expected)
    }


    /// Actual renderer bounds, not the SwiftUI container. Also verifies that
    /// temporary observation never mutates the board or the formal preference.
    func testP01TemporaryTableProjection() throws {
        let app = try launchP01(requiresLandscape: false); defer { app.terminate() }
        let original = try p01Balls(app)
        p01More(app)
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
        p01CloseMenu(app)
        _ = try state(app)
        let normal = try XCTUnwrap(try p01Scene(app)["displayedTable"] as? [Double])
        try capture(app, "p01-projection-formal2D")
        p01More(app); app.buttons["freeplay.cameraMode"].tap(); waitValue(app.buttons["freeplay.cameraMode"], "3D")
        p01CloseMenu(app)
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        peek.tap(); waitValue(peek, "已选中")
        try capture(app, "p01-projection-temporary2D")
        let temporary = try XCTUnwrap(try p01Scene(app)["displayedTable"] as? [Double])
        XCTAssertFalse(app.buttons["dailyClearance.strike"].isEnabled)
        assertP01BallsEqual(try p01Balls(app), original)
        peek.tap()
        p01More(app); waitValue(app.buttons["freeplay.cameraMode"], "3D"); p01CloseMenu(app)
        try capture(app, "p01-projection-restored3D")
        try JSONSerialization.data(withJSONObject: ["formal": normal, "temporary": temporary], options: [.prettyPrinted])
            .write(to: output.appendingPathComponent("projection-bounds.json"))
        // Same outer table under the shared centered projection; orientation may rotate.
        XCTAssertEqual(temporary.count, normal.count)
        for (actual, expected) in zip(temporary, normal) { XCTAssertEqual(actual, expected, accuracy: 1) }
    }

    func testP01UnavailableAndFreeShotRecovery() throws {
        let app = try launchP01(); defer { app.terminate() }
        let strike = app.buttons["dailyClearance.strike"]
        let target = try XCTUnwrap((try p01Scene(app)["balls"] as? [[String: Any]])?.first { $0["key"] as? String == "_8" })
        let point = try XCTUnwrap(target["screen"] as? [Double])
        element(app, "table.scene").coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1]))
            .press(forDuration: 0.1, thenDragTo: app.buttons["paletteBall__8"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)))
        XCTAssertEqual(Set(try p01Balls(app).keys), Set(["cueBall"]))
        try capture(app, "p01-unavailable-no-target")
        XCTAssertFalse(strike.isEnabled)
        XCTAssertTrue(element(app, "shotSimulation.readout").label.contains("切角 —"))
        XCTAssertTrue(app.staticTexts["点选一颗目标球"].waitForExistence(timeout: 5))
        p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
        app.buttons["dailyClearance.aim.free"].tap(); p01CloseMenu(app)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)], timeout: 20), .completed)
        XCTAssertFalse(element(app, "shotSimulation.unavailable").exists, "A legal empty free shot is allowed")
        try capture(app, "p01-free-empty-shot-ready")
        p01More(app); p01MenuItem(app, "shotSimulation.reset").tap()
        XCTAssertEqual(Set(try p01Balls(app).keys), Set(["cueBall", "_8"]))
        XCTAssertFalse(element(app, "shotSimulation.unavailable").exists)
    }

    func testP01PaletteFinalPositionAndOutsideRelease() throws {
        let app = try launchP01(requiresLandscape: false); defer { app.terminate() }
        let table = element(app, "table.scene")
        let slot = app.buttons["paletteBall__1"]
        try capture(app, "p01-fast-release-before", extraIDs: ["table.scene", "paletteBall__1"])
        let end = table.coordinate(withNormalizedOffset: .init(dx: 0.3, dy: 0.55))
        slot.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
        let scene = try p01Scene(app)
        try JSONSerialization.data(withJSONObject: scene, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("fast-release-scene.json"))
        try capture(app, "p01-fast-release-result")
        let placement = try XCTUnwrap(scene["palettePlacement"] as? [String: Any])
        let legal = try XCTUnwrap(placement["world"] as? [Double])
        let actual = try XCTUnwrap(try p01Balls(app)["_1"])
        for (a, b) in zip(actual, legal) { XCTAssertEqual(a, b, accuracy: 0.000001) }
        let finger = try XCTUnwrap(placement["finger"] as? [Double])
        XCTAssertEqual(finger[0], table.frame.width * 0.3, accuracy: 1)
        XCTAssertEqual(finger[1], table.frame.height * 0.55, accuracy: 1)
        try capture(app, "p01-fast-final-release")
        p01More(app); p01MenuItem(app, "shotSimulation.reset").tap()
        let before = try p01Balls(app)
        // Cross the viewport then release outside its left edge. A stale valid
        // sample must not add the ball after the touch has left the table.
        slot.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 3, dy: app.windows.firstMatch.frame.height - 20)),
            withVelocity: .fast, thenHoldForDuration: 0)
        assertP01BallsEqual(try p01Balls(app), before)
        try capture(app, "p01-outside-release-cancelled")
    }

    func testP01BackgroundReplayAndExit() throws {
        let app = try launchP01(requiresLandscape: UIDevice.current.userInterfaceIdiom == .phone)
        defer { app.terminate() }
        func ready(_ id: String) -> XCUIElement {
            let button = app.buttons[id]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)], timeout: 40), .completed)
            return button
        }
        let original = try p01Balls(app)
        p01More(app); app.buttons["freeplay.cameraMode"].tap(); p01CloseMenu(app)
        p01More(app); p01MenuItem(app, "controlLayout.open").tap()
        XCTAssertTrue(app.buttons["freeLayout.cancel"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home); app.activate()
        app.buttons["freeLayout.cancel"].tap()
        assertP01BallsEqual(try p01Balls(app), original)
        ready("dailyClearance.strike").tap()
        XCTAssertFalse(app.buttons["freeplay.moreMenu"].isEnabled)
        XCUIDevice.shared.press(.home); app.activate()
        _ = ready("dailyClearance.strike")
        assertP01BallsEqual(try p01Balls(app), original)
        XCTAssertFalse(app.buttons["dailyClearance.playback"].isEnabled, "An interrupted first shot has no completed replay")
        try capture(app, "p01-shot-background-return")
        ready("dailyClearance.strike").tap()
        _ = ready("dailyClearance.playback")
        let after = try p01Balls(app)
        ready("dailyClearance.playback").tap()
        XCUIDevice.shared.press(.home); app.activate()
        _ = ready("dailyClearance.playback")
        assertP01BallsEqual(try p01Balls(app), after)
        try capture(app, "p01-replay-background-return")
        ready("dailyClearance.undo").tap()
        assertP01BallsEqual(try p01Balls(app), original)
        ready("dailyClearance.strike").tap()
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
        app.buttons["分离角与走位"].tap()
        XCTAssertTrue(element(app, "composer.landscape").waitForExistence(timeout: 15))
        _ = ready("dailyClearance.strike")
        assertP01BallsEqual(try p01Balls(app), original)
        XCTAssertFalse(app.buttons["dailyClearance.playback"].isEnabled)
        try capture(app, "p01-exit-during-shot-reentry")
    }

    func testP01AutomaticFallbackFeedback() throws {
        let app = try launchP01(); defer { app.terminate() }
        let root = element(app, "shotSimulation.landscape")
        p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
        app.buttons["dailyClearance.aim.pocket"].tap(); p01CloseMenu(app)
        let pockets = try XCTUnwrap(try p01Scene(app)["pockets"] as? [[String: Any]])
        for pocket in pockets {
            let point = try XCTUnwrap(pocket["screen"] as? [Double])
            element(app, "table.scene").coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
            if (root.value as? String ?? "").contains("自由模式") { break }
        }
        XCTAssertTrue((root.value as? String ?? "").contains("自由模式"))
        try capture(app, "p01-automatic-fallback")
        XCTAssertTrue(app.staticTexts["该袋口无法直进，已切到自由模式"].exists)
    }

    func testP01DisplayMemoryAndCloseupDismissal() throws {
        let daily = try launch()
        p01More(daily)
        let dailyGrid = daily.buttons["menu.tableGrid"].value as? String
        p01CloseMenu(daily); daily.terminate()
        let app = try launchP01()
        p01More(app)
        let grid = app.buttons["menu.tableGrid"]
        if grid.value as? String == dailyGrid { grid.tap() }
        let localGrid = grid.value as? String
        let closeup = app.buttons["menu.aimCloseup"]
        if closeup.value as? String != "已选" { closeup.tap() }
        p01CloseMenu(app)
        try capture(app, "p01-grid-local")
        let wheel = element(app, "shotStage.aimWheel")
        wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)))
        p01More(app)
        XCTAssertTrue(element(app, "aimCloseup.hud").waitForNonExistence(timeout: 3))
        p01MenuItem(app, "dailyClearance.spinTransparencyMenu").tap()
        XCTAssertTrue(element(app, "spinPad.card").exists)
        XCTAssertFalse(element(app, "aimCloseup.hud").exists)
        app.buttons["dailyClearance.spinTransparencyDone"].tap()
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertFalse(element(app, "aimCloseup.hud").exists)
        app.buttons["shotStage.spinEntry"].tap()
        p01More(app); app.buttons["freeplay.cameraMode"].tap(); p01CloseMenu(app)
        app.terminate()
        let warm = try launchP01(normalizeView: false)
        p01More(warm)
        waitValue(warm.buttons["freeplay.cameraMode"], "3D")
        XCTAssertEqual(warm.buttons["menu.tableGrid"].value as? String, localGrid)
        try capture(warm, "p01-reentered-preferences")
        p01CloseMenu(warm); warm.terminate()
        let dailyAgain = try launch(); defer { dailyAgain.terminate() }
        p01More(dailyAgain)
        XCTAssertEqual(dailyAgain.buttons["menu.tableGrid"].value as? String, dailyGrid)
        try capture(dailyAgain, "daily-grid-unaffected-by-p01")
    }

    func testP01ActualPadWindowResize() throws {
        let app = try launchP01(requiresLandscape: false); defer { app.terminate() }
        try verifyActualPadWindowResize(app, prefix: "p01")
    }

    func testDailySharedCapacityPanelActualWindowResize() throws {
        let app = try launch(extra: ["-v51.followSystemAppearance", "-3dDrag.probe"]); defer { app.terminate() }
        p01More(app)
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
        p01CloseMenu(app)
        try verifyActualPadWindowResize(app, prefix: "daily")
    }

    private func verifyActualPadWindowResize(_ app: XCUIApplication, prefix: String) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        _ = try state(app)
        func maximizeWindow() {
            let window = app.windows.firstMatch
            let before = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - before.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        func waitForStableGeometry() {
            var last: [CGRect] = []
            var consecutive = 0
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let current = [app.windows.firstMatch.frame, app.buttons["dailyClearance.strike"].frame,
                               self.element(app, "table.scene").frame]
                consecutive = current == last ? consecutive + 1 : 0
                last = current
                return consecutive >= 2
            }, object: nil)], timeout: 10), .completed, "Window, safe-area and renderer layout must settle")
        }
        if app.windows.firstMatch.frame.minX > 1 || app.windows.firstMatch.frame.minY > 40 {
            maximizeWindow()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.windows.firstMatch.frame.minX < 1
            }, object: nil)], timeout: 8), .completed)
        }
        waitForStableGeometry()
        let original = app.windows.firstMatch.frame
        defer {
            if app.windows.firstMatch.exists && abs(app.windows.firstMatch.frame.width - original.width) > 1 { maximizeWindow() }
        }
        let board = try p01Balls(app)
        let renderer = try p01Scene(app)["rendererID"] as? String
        let originalStrike = app.buttons["dailyClearance.strike"].frame
        let originalStage = element(app, "table.scene").frame
        try capture(app, prefix + "-window-full")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: original.width - 7, dy: original.height - 7)).press(forDuration: 0.5,
            thenDragTo: origin.withOffset(.init(dx: original.width * 0.7, dy: original.height * 0.78)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.windows.firstMatch.frame.width < original.width - 80
        }, object: nil)], timeout: 8), .completed, "Real system window must resize")
        _ = try state(app)
        assertP01BallsEqual(try p01Balls(app), board)
        try capture(app, prefix + "-window-small", extraIDs: ["dailyLayout.limited", "dailyLayout.limitedBack"])
        if element(app, "dailyLayout.limited").exists {
            XCTAssertTrue(app.buttons["dailyLayout.limitedBack"].isHittable)
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertFalse(strike.exists && strike.isEnabled && strike.isHittable, "Capacity-limited controls must not be actionable")
        } else {
            // A saved personal layout may extend beyond a small window by design.
            // Navigation stays reachable and resizing back must restore its positions.
            for id in ["dailyClearance.back", "freeplay.moreMenu"] { contain(app, element(app, id)); XCTAssertTrue(element(app, id).isHittable) }
        }
        maximizeWindow()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(app.windows.firstMatch.frame.width - original.width) < 1
        }, object: nil)], timeout: 8), .completed)
        _ = try state(app)
        waitForStableGeometry()
        try capture(app, prefix + "-window-restored")
        XCTAssertFalse(element(app, "dailyLayout.limited").exists)
        XCTAssertTrue(app.buttons["dailyClearance.strike"].isHittable)
        XCTAssertEqual(app.buttons["dailyClearance.strike"].frame.minX, originalStrike.minX, accuracy: 1)
        if prefix == "daily" {
            // Full-screen entry and a maximized floating window have different
            // system chrome/insets. Default controls track the actual stage;
            // equal window bounds do not imply equal content bounds.
            XCTAssertEqual(app.buttons["dailyClearance.strike"].frame.midY - element(app, "table.scene").frame.midY,
                           originalStrike.midY - originalStage.midY, accuracy: 1)
            for id in ["dailyClearance.back", "freeplay.moreMenu", "shotStage.aimWheel", "shotStage.powerBar", "dailyClearance.strike"] { contain(app, element(app, id)); XCTAssertTrue(element(app, id).isHittable) }
        } else {
            XCTAssertEqual(app.buttons["dailyClearance.strike"].frame.minY, originalStrike.minY, accuracy: 1)
        }
        XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
        assertP01BallsEqual(try p01Balls(app), board)
    }

    func testP01C56TemplateMenusAndCameras() throws {
        let app = try launchP01(); defer { app.terminate() }
        let root = element(app, "shotSimulation.landscape")
        let originalBalls = try p01Balls(app)
        XCTAssertEqual(Set(originalBalls.keys), Set(["cueBall", "_8"]))
        let originalState = try state(app)
        let renderer = try XCTUnwrap(try p01Scene(app)["rendererID"] as? String)
        XCTAssertFalse(app.buttons["break.entry"].exists)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        for key in (1...15).map({ "_\($0)" }) {
            XCTAssertTrue(app.buttons["paletteBall_" + key].exists)
            XCTAssertTrue(app.buttons["paletteBall_" + key].isHittable)
        }
        let stage = element(app, "freeplay.stage").frame
        let aim = element(app, "shotStage.aimWheel").frame
        let power = element(app, "shotStage.powerBar").frame
        XCTAssertEqual(aim.minY, power.minY, accuracy: 1)
        XCTAssertEqual(aim.maxY, power.maxY, accuracy: 1)
        try capture(app, "p01-2D-base", extraIDs: ["shotSimulation.landscape", "shotSimulation.readout"])
        for dimension in ["2D", "3D"] {
            if dimension == "3D" {
                p01More(app); app.buttons["freeplay.cameraMode"].tap()
                waitValue(app.buttons["freeplay.cameraMode"], "3D")
                p01CloseMenu(app)
                _ = try state(app)
            }
            try capture(app, "p01-" + dimension + "-base-ready", extraIDs: ["shotSimulation.landscape", "shotSimulation.readout"])
            assertP01BallsEqual(try p01Balls(app), originalBalls)
            XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
            XCTAssertEqual(element(app, "freeplay.stage").frame, stage)
            p01More(app)
            try capture(app, "p01-" + dimension + "-more-top")
            p01ScrollMenu(app)
            XCTAssertTrue(p01MenuItem(app, "shotSimulation.reset").isHittable)
            XCTAssertFalse(app.buttons["dailyClearance.changeGame"].exists)
            try capture(app, "p01-" + dimension + "-more-bottom")
            p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
            try capture(app, "p01-" + dimension + "-aim")
            app.buttons["dailyClearance.aim.free"].tap()
            XCTAssertTrue((root.value as? String)?.contains("自由模式") == true)
            p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
            app.buttons["dailyClearance.aim.pocket"].tap()
            p01More(app); p01MenuItem(app, "dailyClearance.trajectoryMenu").tap()
            XCTAssertEqual(app.buttons["dailyClearance.trajectory.3"].exists, dimension == "3D")
            try capture(app, "p01-" + dimension + "-trajectory")
            app.buttons["dailyClearance.menuClose"].tap()
            p01More(app); p01MenuItem(app, "dailyClearance.spinTransparencyMenu").tap()
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            XCTAssertTrue(slider.waitForExistence(timeout: 3))
            if dimension == "2D" {
                // launchClean preserves AppStorage; capture the actual persisted initial value.
                let initial = try XCTUnwrap(slider.value as? String)
                XCTAssertEqual(element(app, "dailyClearance.spinTransparencyPercent").label, initial)
                try capture(app, "p01-2D-transparency-initial-" + initial)
            }
            let transparencyScroll = element(app, "dailyClearance.spinTransparencyScroll")
            if transparencyScroll.exists {
                let panel = element(app, "dailyClearance.spinTransparencyPanel")
                _ = try revealScrollItem(app, id: "dailyClearance.spinTransparencySlider",
                    scroll: transparencyScroll, clip: transparencyScroll.frame.intersection(panel.frame).intersection(app.windows.firstMatch.frame),
                    state: "p01-" + dimension + "-transparency-slider-reveal")
            }
            contain(app, slider)
            XCTAssertTrue(slider.isHittable)
            for value in [CGFloat(0), 1] {
                p01SetTransparencyEndpoint(slider, to: value)
                try capture(app, "p01-" + dimension + "-transparency-\(Int(value * 100))")
            }
            slider.adjust(toNormalizedSliderPosition: 0.5)
            let observed = slider.normalizedSliderPosition
            XCTAssertTrue((0.25...0.75).contains(observed), "A real drag must leave the endpoint; XCUI target is approximate")
            try capture(app, "p01-" + dimension + "-transparency-drag-" + (slider.value as? String ?? "unknown"))
            app.buttons["dailyClearance.spinTransparencyDone"].tap()
            XCTAssertTrue(element(app, "spinPad.card").exists)
            try capture(app, "p01-" + dimension + "-spin")
            app.buttons["shotStage.spinEntry"].tap()
            unchanged(originalState, try state(app))
        }
        let third = app.buttons["shotCamera.thirdPerson"]
        let first = app.buttons["shotCamera.firstPerson"]
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        let shell = element(app, "shotStage.powerShell").frame
        let step = third.frame.midY - peek.frame.midY
        XCTAssertGreaterThan(step, 0)
        XCTAssertEqual(first.frame.midY - third.frame.midY, step, accuracy: 1)
        XCTAssertEqual(first.frame.midY, shell.midY + 1.5 * step, accuracy: 1)
        for button in [third, first, peek] {
            button.tap(); waitValue(button, "已选中")
            try capture(app, "p01-3D-" + button.identifier)
        }
        peek.tap(); waitValue(first, "已选中")
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
        // Palette in 3D is a status/reference surface, while existing table drag remains supported.
        app.buttons["paletteBall__1"].tap()
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        p01More(app); app.buttons["freeplay.cameraMode"].tap()
        waitValue(app.buttons["freeplay.cameraMode"], "2D"); p01CloseMenu(app)
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        try capture(app, "p01-2D-restored")
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
        try capture(app, "p01-normal-exit")
    }


    func testP01C56TemporaryAndPreferredAimAfterShots() throws {
        let app = try launchP01(); defer { app.terminate() }
        let root = element(app, "shotSimulation.landscape")
        func waitMode(_ mode: String) {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (root.value as? String)?.contains(mode + "模式") == true
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
        }
        func shootAndSettle() {
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)], timeout: 20), .completed)
            strike.tap()
            let undo = app.buttons["dailyClearance.undo"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)], timeout: 40), .completed)
        }
        p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
        app.buttons["dailyClearance.aim.pocket"].tap(); waitMode("进袋"); p01CloseMenu(app)
        let wheel = element(app, "shotStage.aimWheel")
        wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        waitMode("自由")
        try capture(app, "p01-temporary-free")
        shootAndSettle(); waitMode("进袋")
        try capture(app, "p01-next-shot-pocket")
        p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
        app.buttons["dailyClearance.aim.free"].tap(); waitMode("自由"); p01CloseMenu(app)
        shootAndSettle(); waitMode("自由")
        try capture(app, "p01-preferred-free-persists")
    }

    func testP01C56TabletRotationPreservesScene() throws {
        let app = try launchP01(requiresLandscape: false); defer { app.terminate() }
        let original = try p01Balls(app)
        let renderer = try XCTUnwrap(try p01Scene(app)["rendererID"] as? String)
        for dimension in ["2D", "3D"] {
            if dimension == "3D" {
                p01More(app); app.buttons["freeplay.cameraMode"].tap()
                waitValue(app.buttons["freeplay.cameraMode"], "3D")
                p01CloseMenu(app)
            }
            for (orientation, name) in [(UIDeviceOrientation.portrait, "portrait"), (.landscapeLeft, "landscape"), (.portrait, "portrait-restored")] {
                XCUIDevice.shared.orientation = orientation
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let frame = app.windows.firstMatch.frame
                    return orientation == .landscapeLeft ? frame.width > frame.height : frame.height > frame.width
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
                _ = try state(app)
                assertP01BallsEqual(try p01Balls(app), original)
                XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
                for id in ["dailyClearance.back", "freeplay.moreMenu", "shotStage.aimWheel", "shotStage.powerBar", "dailyClearance.strike"] {
                    contain(app, element(app, id))
                    XCTAssertTrue(element(app, id).isHittable, id)
                }
                XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
                for key in (1...15).map({ "_\($0)" }) {
                    XCTAssertTrue(app.buttons["paletteBall_" + key].exists)
                    XCTAssertTrue(app.buttons["paletteBall_" + key].isHittable)
                }
                try capture(app, "p01-tablet-" + dimension + "-" + name, extraIDs: ["shotSimulation.landscape", "shotSimulation.readout"])
            }
        }
    }

    func testP01FifteenSlotsMatchesDailyTableLayout() throws {
        let ids = ["freeplay.stage", "shotStage.aimWheel", "shotStage.powerBar",
                   "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback", "freeplay.moreMenu",
                   "paletteBall__1", "paletteBall__15", "dailyClearance.statusCluster"]
        let daily = try launch()
        let expected = Dictionary(uniqueKeysWithValues: ids.map { ($0, element(daily, $0).frame) })
        let window = daily.windows.firstMatch.frame
        try capture(daily, "daily-15-slots-reference")
        daily.terminate()
        let app = try launchP01(); defer { app.terminate() }
        XCTAssertEqual(app.windows.firstMatch.frame, window)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        for n in 1...15 { XCTAssertTrue(app.buttons["paletteBall__\(n)"].isHittable) }
        for id in ids { XCTAssertEqual(element(app, id).frame, expected[id], id) }
        try capture(app, "p01-15-slots-template-layout", extraIDs: ["shotSimulation.readout"])
        // A cue has no palette slot: dragging towards the palette must keep it on the table.
        let table = element(app, "table.scene")
        let balls = try XCTUnwrap(try p01Scene(app)["balls"] as? [[String: Any]])
        let cue = try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" })
        let point = try XCTUnwrap(cue["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1]))
            .press(forDuration: 0.1, thenDragTo: app.buttons["paletteBall__8"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertTrue(try p01Balls(app).keys.contains("cueBall"))
    }

    private func assertTemplateStatusVisible(_ app: XCUIApplication) {
        for id in ["dailyClearance.statusCluster", "dailyClearance.deviceStatus", "dailyClearance.renderFPS"] {
            let status = element(app, id)
            XCTAssertTrue(status.waitForExistence(timeout: 3), id)
            contain(app, status)
        }
    }

    /// Run with real simulator Light and Dark appearance; both consumers must
    /// render the shared material and retain the status cluster in both modes.
    func testP01AndDailySharedPanelsAppearance() throws {
        for page in ["daily", "p01"] {
            let args = ["-v51.followSystemAppearance"]
            let app = try page == "daily" ? launch(extra: args) : launchP01(extraArgs: args)
            for dimension in ["2D", "3D"] {
                if dimension == "3D" {
                    p01More(app); app.buttons["freeplay.cameraMode"].tap()
                    waitValue(app.buttons["freeplay.cameraMode"], "3D")
                    p01CloseMenu(app)
                }
                assertTemplateStatusVisible(app)
                try capture(app, page + "-" + dimension + "-status", extraIDs: ["dailyClearance.statusCluster", "dailyClearance.deviceStatus", "dailyClearance.renderFPS"])
                p01More(app)
                assertTemplateStatusVisible(app)
                try capture(app, page + "-" + dimension + "-more")
                p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
                try capture(app, page + "-" + dimension + "-aim")
                app.buttons["dailyClearance.menuClose"].tap()
                p01More(app); p01MenuItem(app, "dailyClearance.spinTransparencyMenu").tap()
                XCTAssertTrue(app.sliders["dailyClearance.spinTransparencySlider"].waitForExistence(timeout: 3))
                try capture(app, page + "-" + dimension + "-transparency")
                app.buttons["dailyClearance.spinTransparencyDone"].tap()
                // Transparency closes independently of the aiming disc.
                p01CloseMenu(app)
            }
            app.terminate()
        }
    }

    func testP01FifteenSlotsAndAutomaticScratchReturn() throws {
        let app = try launchP01(extraArgs: ["-v63.freePlayScratch"]); defer { app.terminate() }
        let before = try p01Balls(app)
        XCTAssertEqual(Set(before.keys), Set(["cueBall", "_1", "_8"]))
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        for n in 1...15 { XCTAssertTrue(app.buttons["paletteBall__\(n)"].isHittable) }
        let strike = app.buttons["dailyClearance.strike"]
        let replay = app.buttons["dailyClearance.playback"]
        func waitEnabled(_ button: XCUIElement) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "enabled == true"), object: button)], timeout: 30), .completed)
        }
        for dimension in ["2D", "3D"] {
            if dimension == "3D" {
                p01More(app); app.buttons["freeplay.cameraMode"].tap()
                waitValue(app.buttons["freeplay.cameraMode"], "3D")
                p01CloseMenu(app)
            }
            waitEnabled(strike)
            assertTemplateStatusVisible(app)
            XCTAssertTrue(app.staticTexts["母球进袋"].exists, "Fixture predicts a real scratch")
            try capture(app, "p01-15-slots-scratch-before-" + dimension)
            strike.tap(); waitEnabled(replay)
            let after = try p01Balls(app)
            let cue = try XCTUnwrap(after["cueBall"])
            XCTAssertNotEqual(cue, before["cueBall"], "Cue automatically returned after scratching")
            XCTAssertLessThan(abs(cue[0]), 1.27 - 0.028575)
            XCTAssertLessThan(abs(cue[2]), 0.635 - 0.028575)
            for key in ["_1", "_8"] {
                XCTAssertEqual(after[key], before[key], "Returning the cue must not move target balls")
                let target = try XCTUnwrap(after[key])
                XCTAssertGreaterThan(hypot(cue[0] - target[0], cue[2] - target[2]), 2 * 0.028575)
            }
            assertTemplateStatusVisible(app)
            try capture(app, "p01-auto-cue-return-" + dimension)
            replay.tap(); waitEnabled(replay)
            assertP01BallsEqual(try p01Balls(app), after)
            app.buttons["dailyClearance.undo"].tap()
            assertP01BallsEqual(try p01Balls(app), before)
        }
    }

    func testP01C56PlacementAndShotLifecycle() throws {
        let app = try launchP01(); defer { app.terminate() }
        let original = try p01Balls(app)
        app.buttons["paletteBall__1"].tap()
        XCTAssertEqual(try p01Balls(app).count, 3)
        app.buttons["paletteBall__2"].tap()
        XCTAssertEqual(try p01Balls(app).count, 3)
        XCTAssertFalse(try p01Balls(app).keys.contains("_2"))
        try capture(app, "p01-target-limit")
        p01More(app); p01MenuItem(app, "shotSimulation.reset").tap()
        assertP01BallsEqual(try p01Balls(app), original)
        let table = element(app, "table.scene")
        let target = table.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35))
        app.buttons["paletteBall__1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: target)
        XCTAssertTrue(try p01Balls(app).keys.contains("_1"))
        try capture(app, "p01-palette-drag-in")
        let balls = try XCTUnwrap(try p01Scene(app)["balls"] as? [[String: Any]])
        let placed = try XCTUnwrap(balls.first { $0["key"] as? String == "_1" })
        let point = try XCTUnwrap(placed["screen"] as? [Double])
        let source = table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1]))
        source.press(forDuration: 0.1, thenDragTo: app.buttons["paletteBall__1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertFalse(try p01Balls(app).keys.contains("_1"))
        try capture(app, "p01-table-drag-back")
        p01More(app); p01MenuItem(app, "shotSimulation.reset").tap()
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)], timeout: 15), .completed)
        strike.tap()
        let replay = app.buttons["dailyClearance.playback"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)], timeout: 30), .completed)
        let afterShot = try p01Balls(app)
        replay.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)], timeout: 30), .completed)
        assertP01BallsEqual(try p01Balls(app), afterShot)
        app.buttons["dailyClearance.undo"].tap()
        assertP01BallsEqual(try p01Balls(app), original)
        try capture(app, "p01-shot-replay-retry")
    }
}

/// The v67 control recording uses the actual training card, never a direct scene fixture.
final class CameraV67BaselineUITests: XCTestCase {
    private var originalBoard: [String: [Double]]?

    private func node(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func settle(_ app: XCUIApplication) {
        let probe = node(app, "v63.cameraDiagnostics")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = probe.value as? String else { return false }
            return value.contains("twoViewComputing=false") && value.contains("twoViewMoving=false")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    @discardableResult
    private func capture(_ app: XCUIApplication, _ name: String) throws -> [String: Any] {
        settle(app)
        let raw = try XCTUnwrap(node(app, "v63.cameraDiagnostics").value as? String)
        let encoded = try XCTUnwrap(raw.split(separator: " ").first { $0.hasPrefix("v67Baseline=") })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst("v67Baseline=".count))))
        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        row["name"] = name
        row["timestamp"] = Date().timeIntervalSince1970
        row["diagnostics"] = raw
        let rawScene = try XCTUnwrap(node(app, "table.scene").value as? String)
        row["scene"] = rawScene
        let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(rawScene.utf8)) as? [String: Any])
        let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
        let board = try Dictionary(uniqueKeysWithValues: balls.map {
            (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
        })
        if let originalBoard { XCTAssertEqual(board, originalBoard, "Camera baseline must never move a ball") }
        else { originalBoard = board }
        XCTAssertEqual(scene["grabCount"] as? Int, 0, "A camera gesture must not grab a ball")
        row["controls"] = node(app, "dailyLayout.controlsProbe").value as? String
        row["page"] = node(app, "composer.landscape").label
        var frames: [String: [CGFloat]] = [:]
        for id in ["table.scene", "freeplay.stage", "shotStage.aimWheel", "shotStage.powerBar", "shotCamera.firstPerson", "shotCamera.thirdPerson"] {
            let f = node(app, id).frame
            frames[id] = [f.minX, f.minY, f.width, f.height]
        }
        row["frames"] = frames
        let json = XCTAttachment(data: try JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        json.name = name + ".json"; json.lifetime = .keepAlways; add(json)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        return row
    }

    func testFormalP01OriginalCameraBaseline() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics", "-v67.cameraBaseline"])
        defer { app.terminate() }
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_走位"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons["分离角与走位"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        card.tap()
        XCTAssertTrue(node(app, "composer.landscape").waitForExistence(timeout: 15))
        XCTAssertTrue(node(app, "composer.landscape").label.contains("分离角与走位"))
        // The route's orientation lock may still rotate after the AX page appears.
        // Wait for the actual window and menu frame to remain landscape and stable.
        var stableSince: Date?
        var previousMenuFrame = CGRect.zero
        let landscapeReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.frame
            let menu = app.buttons["freeplay.moreMenu"]
            guard frame.width > frame.height, menu.isHittable else { stableSince = nil; return false }
            let current = menu.frame
            if current != previousMenuFrame { previousMenuFrame = current; stableSince = nil }
            if stableSince == nil { stableSince = Date() }
            return Date().timeIntervalSince(stableSince!) >= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscapeReady], timeout: 15), .completed)
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        if mode.value as? String != "3D" { mode.tap() }
        let close = app.buttons["dailyClearance.menuClose"]
        if close.exists { close.tap() } else { app.buttons["关闭菜单"].firstMatch.tap() }
        let third = app.buttons["shotCamera.thirdPerson"]
        XCTAssertTrue(third.waitForExistence(timeout: 5)); third.tap()
        let base = try capture(app, "v67-01-original-third")
        XCTAssertEqual(base["surface"] as? Bool, true)
        XCTAssertEqual(base["orthographic"] as? Bool, false)
        let stage = node(app, "table.scene")
        // Choose a measured empty point outside the production 48pt ball-grab zone.
        func drag(_ dx: CGFloat, _ dy: CGFloat) throws {
            let raw = try XCTUnwrap(stage.value as? String)
            let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
            let projected = try balls.map { try XCTUnwrap($0["screen"] as? [Double]) }
            let candidates = [CGPoint(x: 0.35, y: 0.22), CGPoint(x: 0.65, y: 0.22),
                              CGPoint(x: 0.35, y: 0.35), CGPoint(x: 0.65, y: 0.35)]
            func clearance(_ p: CGPoint) -> CGFloat {
                projected.map { hypot(p.x * stage.frame.width - $0[0], p.y * stage.frame.height - $0[1]) }.min() ?? .infinity
            }
            let point = try XCTUnwrap(candidates.max { clearance($0) < clearance($1) })
            XCTAssertGreaterThan(clearance(point), 60)
            let start = stage.coordinate(withNormalizedOffset: .init(dx: point.x, dy: point.y))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: dx, dy: dy)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        try drag(100, 0); try capture(app, "v67-02-original-orbit-right")
        try drag(-100, 0); try capture(app, "v67-03-original-orbit-return")
        try drag(0, -60); try capture(app, "v67-04-original-drag-up")
        try drag(0, 60); try capture(app, "v67-05-original-drag-down")
        third.tap(); try capture(app, "v67-06-third-reset")
        let wheel = node(app, "shotStage.aimWheel")
        let wheelStart = wheel.coordinate(withNormalizedOffset: .init(dx: 0.55, dy: 0.5))
        wheelStart.press(forDuration: 0.1, thenDragTo: wheelStart.withOffset(.init(dx: 0, dy: -60)), withVelocity: .slow, thenHoldForDuration: 0.1)
        let wheelState = try capture(app, "v67-07-third-wheel")
        XCTAssertNotEqual(base["aim"] as? [Double], wheelState["aim"] as? [Double], "The direction ruler must actually change the shaft direction")
        app.buttons["shotCamera.firstPerson"].tap()
        try capture(app, "v67-08-original-first")
        try drag(80, 0); try capture(app, "v67-09-original-first-head-right")
        try drag(-80, 0); try capture(app, "v67-10-original-first-head-left")
        let fpStart = wheel.coordinate(withNormalizedOffset: .init(dx: 0.45, dy: 0.5))
        fpStart.press(forDuration: 0.1, thenDragTo: fpStart.withOffset(.init(dx: 0, dy: 60)), withVelocity: .slow, thenHoldForDuration: 0.1)
        try capture(app, "v67-11-first-wheel")
        app.buttons["dailyClearance.observeTable"].tap()
        try capture(app, "v67-12-original-observation")
        try drag(100, 0); try capture(app, "v67-13-observation-orbit")
    }
}

/// Native pilot, reached through the public practice card without a policy launch flag.
final class CameraV67PilotUITests: XCTestCase {
    private var originalBoard: [String: [Double]]?
    private var expectedGrabs = 0

    private func node(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    private func settle(_ app: XCUIApplication) {
        let probe = node(app, "v63.cameraDiagnostics")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = probe.value as? String else { return false }
            return value.contains("twoViewComputing=false") && value.contains("twoViewMoving=false")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    @discardableResult
    private func capture(_ app: XCUIApplication, _ name: String, input: [String: Any]? = nil) throws -> [String: Any] {
        settle(app)
        let raw = try XCTUnwrap(node(app, "v63.cameraDiagnostics").value as? String)
        let encoded = try XCTUnwrap(raw.split(separator: " ").first { $0.hasPrefix("v67Baseline=") })
        let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst("v67Baseline=".count))))
        var row = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        row["name"] = name
        row["timestamp"] = Date().timeIntervalSince1970
        row["input"] = input
        row["diagnostics"] = raw
        let rawScene = try XCTUnwrap(node(app, "table.scene").value as? String)
        row["scene"] = rawScene
        let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(rawScene.utf8)) as? [String: Any])
        let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
        let board = try Dictionary(uniqueKeysWithValues: balls.map {
            (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double]))
        })
        if let originalBoard { XCTAssertEqual(board, originalBoard, "Camera baseline must never move a ball") }
        else { originalBoard = board }
        XCTAssertEqual(scene["grabCount"] as? Int, expectedGrabs, "A camera gesture must not grab a ball")
        row["controls"] = node(app, "dailyLayout.controlsProbe").value as? String
        row["page"] = node(app, "composer.landscape").label
        row["business"] = node(app, "composer.landscape").value as? String
        var frames: [String: [CGFloat]] = [:]
        for id in ["table.scene", "freeplay.stage", "shotStage.aimWheel", "shotStage.powerBar", "shotCamera.firstPerson", "shotCamera.thirdPerson"] {
            let element=node(app,id)
            guard element.exists else { continue } // 2D intentionally omits 3D camera buttons.
            let f = element.frame
            frames[id] = [f.minX, f.minY, f.width, f.height]
        }
        row["frames"] = frames
        try attachCapture(row, name: name)
        return row
    }

    private func attachCapture(_ row: [String: Any], name: String) throws {
        let json = XCTAttachment(data: try JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        json.name = name + ".json"; json.lifetime = .keepAlways; add(json)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func launchFormal(traceTouches: Bool = false, lightCapture: Bool = false) throws -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let diagnostics = lightCapture ? [] : ["-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics", "-v67.cameraBaseline"]
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"] + diagnostics)
        // Each case starts from the real default board, not the previous case's saved edits.
        app.terminate()
        app.launchEnvironment["BOARD_MEMORY_TEST_DOMAIN"] = UUID().uuidString
        if traceTouches, let library = ProcessInfo.processInfo.environment["FRAME_PAN_UIKIT_TRACE_LIBRARY"] {
            let existing = app.launchEnvironment["DYLD_INSERT_LIBRARIES"]
            app.launchEnvironment["DYLD_INSERT_LIBRARIES"] = [existing, library].compactMap { $0 }.joined(separator: ":")
        }
        app.launch()
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_走位"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons["分离角与走位"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        card.tap()
        XCTAssertTrue(node(app, "composer.landscape").waitForExistence(timeout: 15))
        XCTAssertTrue(node(app, "composer.landscape").label.contains("分离角与走位"))
        // The route's orientation lock may still rotate after the AX page appears.
        // Wait for the actual window and menu frame to remain landscape and stable.
        var stableSince: Date?
        var previousMenuFrame = CGRect.zero
        let landscapeReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.frame
            let menu = app.buttons["freeplay.moreMenu"]
            guard frame.width > frame.height, menu.isHittable else { stableSince = nil; return false }
            let current = menu.frame
            if current != previousMenuFrame { previousMenuFrame = current; stableSince = nil }
            if stableSince == nil { stableSince = Date() }
            return Date().timeIntervalSince(stableSince!) >= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscapeReady], timeout: 15), .completed)
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        if mode.value as? String != "3D" { mode.tap() }
        closeMenu(app)
        let third = app.buttons["shotCamera.thirdPerson"]
        XCTAssertTrue(third.waitForExistence(timeout: 5)); third.tap()
        return app
    }

    func testFormalFramePacingTouchPaths() throws {
        let lightCapture = ProcessInfo.processInfo.environment["FRAME_PAN_LIGHT_CAPTURE"] == "1"
        let app = try launchFormal(traceTouches: true, lightCapture: lightCapture)
        defer { app.terminate() }
        let stage = lightCapture ? app : node(app, "table.scene")
        let third = app.buttons["shotCamera.thirdPerson"]
        let page = node(app, "composer.landscape")
        let anchor = CGVector(dx: 0.34, dy: 0.24)
        let lightViewport = lightCapture ? app.frame.size : .zero
        let lightStart = lightCapture ? app.coordinate(withNormalizedOffset: anchor).screenPoint : .zero

        func setAim(_ mode: String) {
            app.buttons["freeplay.moreMenu"].tap()
            node(app, "dailyClearance.aimModeMenu").tap()
            app.buttons["dailyClearance.aim." + mode].tap()
            closeMenu(app)
            if lightCapture {
                XCTAssertTrue((page.value as? String ?? "").contains(mode == "free" ? "自由模式" : "进袋模式"))
            }
        }
        func run(_ name: String, legs: [(CGFloat, CGFloat, Double)], hold: Double, outcome: String) throws {
            if lightCapture {
                func captureLight(_ suffix: String, input: [String: Any]? = nil) throws {
                    let captureName = "v69-" + name + "-" + suffix
                    var data: [String: Any] = ["name": captureName, "timestamp": Date().timeIntervalSince1970,
                                               "viewport": [lightViewport.width, lightViewport.height],
                                               "page": page.label, "business": page.value as? String ?? ""]
                    data["input"] = input
                    try attachCapture(data, name: captureName)
                }
                try captureLight("before")
                let touch = try sendFramePacingPath(app, name: name, from: lightStart, viewport: lightViewport, legs: legs, hold: hold)
                try captureLight("after", input: touch)
                return
            }
            let before = try capture(app, "v69-" + name + "-before")
            let balls = try XCTUnwrap(try rawScene(app)["balls"] as? [[String: Any]])
            let points = try balls.map { try XCTUnwrap($0["screen"] as? [Double]) }
            let frame = stage.frame
            let clearance = points.map { hypot(anchor.dx * frame.width - $0[0], anchor.dy * frame.height - $0[1]) }
                .min() ?? .infinity
            XCTAssertGreaterThan(clearance, 60, "The identical touch path must begin off the balls")
            let start = stage.coordinate(withNormalizedOffset: anchor).screenPoint
            let touch = try sendFramePacingPath(app, name: name, from: start, viewport: frame.size, legs: legs, hold: hold)
            let after = try capture(app, "v69-" + name + "-after", input: touch)
            let beforeAim = try XCTUnwrap(before["aim"] as? [Double])
            let afterAim = try XCTUnwrap(after["aim"] as? [Double])
            let beforeEye = try XCTUnwrap(before["eye"] as? [Double])
            let afterEye = try XCTUnwrap(after["eye"] as? [Double])
            XCTAssertEqual(after["playerView"] as? String, "thirdPerson")
            if outcome == "aim" {
                XCTAssertNotEqual(beforeAim, afterAim, "Free swipe must visibly change the shot")
                XCTAssertTrue((after["business"] as? String ?? "").contains("自由模式"))
            } else {
                XCTAssertEqual(beforeAim, afterAim, "Pocket observation must keep the shot direction")
                if outcome == "height" {
                    XCTAssertGreaterThan(afterEye[1] - beforeEye[1], 0.03, "Downward swipe must raise the camera")
                } else {
                    XCTAssertEqual(afterEye[1], beforeEye[1], accuracy: 0.002)
                    XCTAssertGreaterThan(hypot(afterEye[0] - beforeEye[0], afterEye[2] - beforeEye[2]), 0.02,
                                         "The injected horizontal path must rotate the camera")
                }
            }
        }

        setAim("pocket")
        try run("01-pocket-horizontal", legs: [(132, 0, 2.4)], hold: 0.35, outcome: "orbit")
        third.tap()
        try run("02-pocket-height", legs: [(0, 74, 2.0)], hold: 0.35, outcome: "height")
        third.tap()
        try run("03-pocket-reverse", legs: [(108, 0, 1.4), (-84, 0, 1.1)], hold: 0.35, outcome: "orbit")
        third.tap()
        setAim("free")
        try run("04-free-aim-stop", legs: [(110, 0, 2.0)], hold: 0.75, outcome: "aim")
    }

    private func sendFramePacingPath(
        _ app: XCUIApplication, name: String, from screenPoint: CGPoint, viewport: CGSize,
        legs: [(CGFloat, CGFloat, Double)], hold: Double
    ) throws -> [String: Any] {
        // XCTest's public drag helper sends a single segment. Use the same underlying
        // XCUI synthesizer to keep one contact down through both legs of a reversal.
        func implementation(_ cls: AnyClass, _ selector: Selector) throws -> IMP {
            method_getImplementation(try XCTUnwrap(class_getInstanceMethod(cls, selector)))
        }
        func allocate(_ cls: AnyClass) throws -> AnyObject {
            let result = try XCTUnwrap((cls as AnyObject).perform(NSSelectorFromString("alloc")))
            return result.takeUnretainedValue()
        }
        let orientationSelector = NSSelectorFromString("interfaceOrientation")
        typealias Orientation = @convention(c) (AnyObject, Selector) -> Int
        let orientation = unsafeBitCast(try implementation(type(of: app), orientationSelector), to: Orientation.self)
        let interfaceOrientation = orientation(app, orientationSelector)
        XCTAssertTrue(interfaceOrientation == 3 || interfaceOrientation == 4, "Capture requires a landscape device")
        let landscapeLeft = interfaceOrientation == 3
        // Public XCUI actions archive portrait device coordinates even for a landscape app.
        let start = landscapeLeft ? CGPoint(x: screenPoint.y, y: viewport.height - screenPoint.x)
            : CGPoint(x: viewport.width - screenPoint.y, y: screenPoint.x)
        func devicePoint(_ viewPoint: CGPoint) -> CGPoint {
            landscapeLeft ? CGPoint(x: viewport.height - viewPoint.y, y: viewPoint.x)
                : CGPoint(x: viewPoint.y, y: viewport.width - viewPoint.x)
        }
        let pathClass: AnyClass = try XCTUnwrap(NSClassFromString("XCPointerEventPath"))
        let pathInit = NSSelectorFromString("initForTouchAtPoint:offset:")
        typealias InitPath = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Unmanaged<AnyObject>?
        let newPath = unsafeBitCast(try implementation(pathClass, pathInit), to: InitPath.self)
        let path = try XCTUnwrap(newPath(try allocate(pathClass), pathInit, screenPoint, 0)).takeRetainedValue()
        let moveSelector = NSSelectorFromString("moveToPoint:atOffset:")
        typealias Move = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Void
        let move = unsafeBitCast(try implementation(pathClass, moveSelector), to: Move.self)
        let liftSelector = NSSelectorFromString("liftUpAtOffset:")
        typealias Lift = @convention(c) (AnyObject, Selector, Double) -> Void
        let lift = unsafeBitCast(try implementation(pathClass, liftSelector), to: Lift.self)

        var time = 0.18
        var point = start
        var samples: [[String: Any]] = [["time": 0.0, "x": start.x, "y": start.y, "phase": "down"]]
        let interval = 1.0 / 60
        for (dx, dy, duration) in legs {
            let count = Int((duration / interval).rounded())
            for step in 1...count {
                let fraction = Double(step) / Double(count)
                let position = CGPoint(x: point.x + dx * fraction, y: point.y + dy * fraction)
                let offset = time + duration * fraction
                move(path, moveSelector, devicePoint(position), offset)
                samples.append(["time": offset, "x": position.x, "y": position.y, "phase": "move"])
            }
            time += duration
            point.x += dx
            point.y += dy
        }
        let end = time + hold
        lift(path, liftSelector, end)
        samples.append(["time": end, "x": point.x, "y": point.y, "phase": "up"])

        let recordClass: AnyClass = try XCTUnwrap(NSClassFromString("XCSynthesizedEventRecord"))
        let recordInit = NSSelectorFromString("initWithName:interfaceOrientation:")
        typealias InitRecord = @convention(c) (AnyObject, Selector, NSString, Int) -> Unmanaged<AnyObject>?
        let newRecord = unsafeBitCast(try implementation(recordClass, recordInit), to: InitRecord.self)
        let record = try XCTUnwrap(newRecord(try allocate(recordClass), recordInit, name as NSString, 1))
            .takeRetainedValue()
        _ = (record as AnyObject).perform(NSSelectorFromString("addPointerEventPath:"), with: path)
        let device = XCUIDevice.shared
        let synthesizer = try XCTUnwrap(device.perform(NSSelectorFromString("eventSynthesizer"))?.takeUnretainedValue())
        let submitSelector = NSSelectorFromString("synthesizeEvent:completion:")
        let synthesizerClass: AnyClass = try XCTUnwrap(object_getClass(synthesizer))
        typealias Completion = @convention(block) (Bool, NSError?) -> Void
        typealias Submit = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        let submit = unsafeBitCast(try implementation(synthesizerClass, submitSelector), to: Submit.self)
        let completed = expectation(description: "Synthesized touch path completed")
        var succeeded = false
        var completedAt = 0.0
        let dispatchTime = Date().timeIntervalSince1970
        let completion: Completion = { result, error in
            succeeded = result && error == nil
            completedAt = Date().timeIntervalSince1970
            completed.fulfill()
        }
        let completionBlock = completion as AnyObject
        submit(synthesizer, submitSelector, record, completionBlock)
        withExtendedLifetime(completionBlock) { wait(for: [completed], timeout: 12) }
        XCTAssertTrue(succeeded, "XCTest must acknowledge the original single-contact event")
        RunLoop.current.run(until: Date(timeIntervalSince1970: dispatchTime + end + 0.45))
        return [
            "kind": "scheduledXCTestTouchPath",
            "dispatchedAt": dispatchTime,
            "completedAt": completedAt,
            "oneContact": true,
            "interfaceOrientation": interfaceOrientation,
            "samples": samples
        ]
    }

    func testOpeningSaved3DBoardStartsInThirdPersonWithoutCameraTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-firstRun.profileFlow.v1", "completed", "-forcePremium"]
        func openPage() {
            app.launch()
            app.switchTab(.angle)
            app.buttons["angleHomeTab_走位"].tap()
            app.buttons["分离角与走位"].tap()
        }
        openPage()
        let third = app.buttons["shotCamera.thirdPerson"]
        if !third.waitForExistence(timeout: 5) { toggleMode(app) }
        app.terminate()
        openPage()
        XCTAssertTrue(third.waitForExistence(timeout: 10))
        XCTAssertEqual(third.value as? String, "已选中")
    }

    func testThreeCameraButtonsAndTemporaryTopDownReturn() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-firstRun.profileFlow.v1", "completed",
                               "-forcePremium", "-dailyLayout.probe"]
        app.launch()
        app.switchTab(.angle)
        app.buttons["angleHomeTab_走位"].tap()
        app.buttons["分离角与走位"].tap()
        let third = app.buttons["shotCamera.thirdPerson"]
        if !third.waitForExistence(timeout: 5) { toggleMode(app) }
        XCTAssertTrue(third.waitForExistence(timeout: 8))
        let first = app.buttons["shotCamera.firstPerson"]
        let peek = app.buttons["shotCamera.temporaryTopDown"]
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        XCTAssertEqual(peek.label, "临时俯视")
        let step = third.frame.midY - peek.frame.midY
        XCTAssertGreaterThan(step, 0)
        XCTAssertEqual(first.frame.midY - third.frame.midY, step, accuracy: 1)
        let shell = node(app, "shotStage.powerShell")
        XCTAssertTrue(shell.exists)
        XCTAssertEqual(first.frame.midY, shell.frame.midY + 1.5 * step, accuracy: 1)
        for button in [third, first] {
            button.tap()
            peek.tap()
            XCTAssertEqual(peek.value as? String, "已选中")
            XCTAssertFalse(first.isEnabled)
            XCTAssertFalse(third.isEnabled)
            peek.tap()
            XCTAssertEqual(peek.value as? String, "未选中")
            XCTAssertEqual(button.value as? String, "已选中")
            XCTAssertTrue(button.isEnabled)
        }
    }

    func testIdleFirstAndThirdButtonsMoveTheRenderedCamera() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-firstRun.profileFlow.v1", "completed",
                               "-forcePremium", "-3dDrag.probe"]
        app.launch()
        app.switchTab(.angle)
        app.buttons["angleHomeTab_走位"].tap()
        app.buttons["分离角与走位"].tap()
        let third = app.buttons["shotCamera.thirdPerson"]
        if !third.waitForExistence(timeout: 5) { toggleMode(app) }
        XCTAssertTrue(third.waitForExistence(timeout: 8))
        let first = app.buttons["shotCamera.firstPerson"]

        func idleCamera(_ label: String) throws -> [Double] {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (try? self.rawScene(app)["rendererActive"] as? Bool) == false
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
            let state = try rawScene(app)
            let camera = try XCTUnwrap(state["camera"] as? [Double])
            XCTAssertEqual(camera.count, 12)
            try attachCapture(state, name: "idle-switch-" + label)
            return Array(camera.suffix(3))
        }
        third.tap()
        let original = try idleCamera("third")
        first.tap()
        let close = try idleCamera("first")
        third.tap()
        let returned = try idleCamera("third-return")
        func separation(_ a: [Double], _ b: [Double]) -> Double {
            sqrt(zip(a, b).reduce(0.0) { $0 + pow($1.0 - $1.1, 2) })
        }
        XCTAssertGreaterThan(separation(original, close), 0.05)
        XCTAssertLessThan(separation(original, returned), 0.002)
    }

    func testFormalSelectionSwitchAndModeSwipes() throws {
        let app = try launchFormal()
        defer { app.terminate() }
        let stage = node(app, "table.scene")
        let third = app.buttons["shotCamera.thirdPerson"]
        let first = app.buttons["shotCamera.firstPerson"]

        func ballScreen(_ key: String) throws -> [Double] {
            let balls = try XCTUnwrap(try rawScene(app)["balls"] as? [[String: Any]])
            let ball = try XCTUnwrap(balls.first { $0["key"] as? String == key })
            return try XCTUnwrap(ball["screen"] as? [Double])
        }

        func localPoint(_ x: Double, _ y: Double) -> XCUICoordinate {
            stage.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: x, dy: y))
        }

        func setAimMode(_ mode: String) {
            app.buttons["freeplay.moreMenu"].tap()
            let menu = node(app, "dailyClearance.aimModeMenu")
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            menu.tap()
            let choice = app.buttons["dailyClearance.aim." + mode]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            closeMenu(app)
        }

        // Both cameras use the same real board. Move 8 forward with the normal 2D
        // drag so it is visible when aimed at either object ball in 3D.
        toggleMode(app)
        let setup = try capture(app, "v68-setup-2d")
        let basis = try XCTUnwrap(setup["planeBasis"] as? [[Double]])
        let source = try ballScreen("_8")
        let x = basis[0][0] + 0.55 * (basis[1][0] - basis[0][0]) - 0.24 * (basis[2][0] - basis[0][0])
        let y = basis[0][1] + 0.55 * (basis[1][1] - basis[0][1]) - 0.24 * (basis[2][1] - basis[0][1])
        let dx = x - source[0], dy = y - source[1]
        let length = hypot(dx, dy)
        XCTAssertGreaterThan(length, 52)
        localPoint(source[0], source[1]).press(
            forDuration: 0.2, thenDragTo: localPoint(x + 52 * dx / length, y + 52 * dy / length),
            withVelocity: .slow, thenHoldForDuration: 0.1
        )
        let edited = try rawScene(app)
        let editedBalls = try XCTUnwrap(edited["balls"] as? [[String: Any]])
        let editedEight = try XCTUnwrap(editedBalls.first { $0["key"] as? String == "_8" })
        let world = try XCTUnwrap(editedEight["world"] as? [Double])
        XCTAssertEqual(world[0], 0.55, accuracy: 0.08)
        XCTAssertEqual(world[2], -0.24, accuracy: 0.08)
        expectedGrabs = try XCTUnwrap(edited["grabCount"] as? Int)
        originalBoard = nil
        toggleMode(app)
        third.tap()
        settle(app)
        setAimMode("pocket")
        let aligned = try capture(app, "v68-01-third-pocket-initial")

        @discardableResult
        func perform(_ name: String, input: [String: Any], _ action: () -> Void) throws -> [String: Any] {
            var event = input
            event["startedAt"] = Date().timeIntervalSince1970
            action()
            event["returnedAt"] = Date().timeIntervalSince1970
            return try capture(app, "v68-" + name, input: event)
        }

        @discardableResult
        func tapBall(_ key: String, _ name: String) throws -> [String: Any] {
            let screen = try ballScreen(key)
            let frame = stage.frame
            XCTAssertTrue(CGRect(origin: .zero, size: frame.size).insetBy(dx: 65, dy: 26)
                .contains(CGPoint(x: screen[0], y: screen[1])), "Fixture ball must be on the visible table")
            let target = localPoint(screen[0], screen[1])
            return try perform(name, input: ["kind": "tableBallTap", "ball": key, "point": Array(screen.prefix(2))]) {
                target.tap()
            }
        }

        @discardableResult
        func swipe(_ dx: CGFloat, _ name: String) throws -> [String: Any] {
            let balls = try XCTUnwrap(try rawScene(app)["balls"] as? [[String: Any]])
            let points = try balls.map { try XCTUnwrap($0["screen"] as? [Double]) }
            let frame = stage.frame
            let candidates = [CGPoint(x: 0.35, y: 0.23), CGPoint(x: 0.65, y: 0.23),
                              CGPoint(x: 0.35, y: 0.36), CGPoint(x: 0.65, y: 0.36)]
            func clearance(_ point: CGPoint) -> CGFloat {
                points.map { hypot(point.x * frame.width - $0[0], point.y * frame.height - $0[1]) }
                    .min() ?? .infinity
            }
            let point = try XCTUnwrap(candidates.max { clearance($0) < clearance($1) })
            XCTAssertGreaterThan(clearance(point), 60, "Swipe must start outside the ball pickup zone")
            let start = stage.coordinate(withNormalizedOffset: .init(dx: point.x, dy: point.y))
            let end = start.withOffset(.init(dx: dx, dy: 0))
            return try perform(name, input: ["kind": "tableSwipe", "point": [point.x * frame.width, point.y * frame.height],
                                      "delta": [dx, 0]]) {
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            }
        }

        let side = try swipe(85, "02-third-pocket-side")
        let reselected = try tapBall("_1", "03-side-reselect-same")
        func observationYaw(_ row: [String: Any]) throws -> Double {
            let camera = try XCTUnwrap(row["p01"] as? [String: Any])
            let state = try XCTUnwrap(camera["state"] as? [String: Any])
            return try XCTUnwrap(state["observationYaw"] as? Double)
        }
        XCTAssertGreaterThan(abs(try observationYaw(side)), 0.01)
        XCTAssertEqual(try observationYaw(reselected), 0, accuracy: 0.001)
        XCTAssertEqual(reselected["aim"] as? [Double], aligned["aim"] as? [Double])
        XCTAssertEqual(reselected["business"] as? String, aligned["business"] as? String)
        try swipe(85, "04-third-pocket-side-again")
        try tapBall("_8", "05-side-select-other")
        try perform("06-third-align", input: ["kind": "cameraButton", "view": "thirdPerson"]) { third.tap() }
        try tapBall("_1", "07-aligned-select-other")
        try perform("08-switch-to-first", input: ["kind": "cameraButton", "view": "firstPerson"]) { first.tap() }
        let beforeSwipe = try capture(app, "first-pocket-before-manual-aim")
        XCTAssertTrue((beforeSwipe["business"] as? String ?? "").contains("进袋"))
        try swipe(80, "09-first-pocket-swipe")
        let afterSwipe = try capture(app, "first-pocket-after-manual-aim")
        XCTAssertEqual(afterSwipe["playerView"] as? String, "firstPerson")
        XCTAssertTrue((afterSwipe["business"] as? String ?? "").contains("自由"))
        XCTAssertNotEqual(try XCTUnwrap(beforeSwipe["aim"] as? [Double]), try XCTUnwrap(afterSwipe["aim"] as? [Double]))
        try perform("10-switch-to-third", input: ["kind": "cameraButton", "view": "thirdPerson"]) { third.tap() }
        try perform("11-third-free-initial", input: ["kind": "aimModeMenu", "mode": "free"]) { setAimMode("free") }
        try swipe(85, "12-third-free-swipe")
        try perform("13-free-switch-to-first", input: ["kind": "cameraButton", "view": "firstPerson"]) { first.tap() }
        try swipe(80, "14-first-free-swipe")
        try perform("15-free-switch-to-third", input: ["kind": "cameraButton", "view": "thirdPerson"]) { third.tap() }
    }

    func testFormalP01PilotInputsAndRestoration() throws {
        let app=try launchFormal();defer { app.terminate() }
        let third=app.buttons["shotCamera.thirdPerson"]
        let base = try capture(app, "v67-pilot-01-new-third")
        XCTAssertEqual(base["surface"] as? Bool, false)
        XCTAssertEqual(base["policy"] as? String, "p01Replayable")
        XCTAssertEqual(base["orthographic"] as? Bool, false)
        let stage = node(app, "table.scene")
        // Choose a measured empty point outside the production 48pt ball-grab zone.
        func drag(_ dx: CGFloat, _ dy: CGFloat) throws {
            let raw = try XCTUnwrap(stage.value as? String)
            let scene = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
            let projected = try balls.map { try XCTUnwrap($0["screen"] as? [Double]) }
            let candidates = [CGPoint(x: 0.35, y: 0.22), CGPoint(x: 0.65, y: 0.22),
                              CGPoint(x: 0.35, y: 0.35), CGPoint(x: 0.65, y: 0.35)]
            // One native frame read per gesture. Re-querying AX inside the comparator
            // floods iOS 17 XCTest logging and can crash its injected runtime callback.
            let stageFrame=stage.frame
            func clearance(_ p: CGPoint) -> CGFloat {
                projected.map { hypot(p.x * stageFrame.width - $0[0], p.y * stageFrame.height - $0[1]) }.min() ?? .infinity
            }
            let point = try XCTUnwrap(candidates.max { clearance($0) < clearance($1) })
            XCTAssertGreaterThan(clearance(point), 60)
            let start = stage.coordinate(withNormalizedOffset: .init(dx: point.x, dy: point.y))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: dx, dy: dy)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        try drag(100, 0); let observed = try capture(app, "v67-pilot-02-new-orbit-right")
        XCTAssertEqual(base["aim"] as? [Double], observed["aim"] as? [Double])
        XCTAssertEqual(base["business"] as? String, observed["business"] as? String)
        XCTAssertNotEqual(base["eye"] as? [Double], observed["eye"] as? [Double])
        try drag(-100, 0); try capture(app, "v67-pilot-03-new-orbit-return")
        try drag(0, -60); try capture(app, "v67-pilot-04-new-drag-up")
        try drag(0, 60); try capture(app, "v67-pilot-05-new-drag-down")
        third.tap(); try capture(app, "v67-pilot-06-third-reset")
        let wheel = node(app, "shotStage.aimWheel")
        let wheelStart = wheel.coordinate(withNormalizedOffset: .init(dx: 0.55, dy: 0.5))
        wheelStart.press(forDuration: 0.1, thenDragTo: wheelStart.withOffset(.init(dx: 0, dy: -60)), withVelocity: .slow, thenHoldForDuration: 0.1)
        let wheelState = try capture(app, "v67-pilot-07-third-wheel")
        XCTAssertTrue((wheelState["business"] as? String ?? "").contains("自由"))
        XCTAssertFalse((wheelState["diagnostics"] as? String ?? "").contains("twoViewCameraBusy=true"))
        XCTAssertNotEqual(base["aim"] as? [Double], wheelState["aim"] as? [Double], "The direction ruler must actually change the shaft direction")
        app.buttons["shotCamera.firstPerson"].tap()
        let first = try capture(app, "v67-pilot-08-new-first")
        XCTAssertTrue((first["business"] as? String ?? "").contains("自由"))
        try drag(80, 0); let right = try capture(app, "v67-pilot-09-new-first-head-right")
        XCTAssertEqual(right["playerView"] as? String, "firstPerson")
        XCTAssertTrue((right["business"] as? String ?? "").contains("自由"))
        let firstAim = try XCTUnwrap(first["aim"] as? [Double])
        let rightAim = try XCTUnwrap(right["aim"] as? [Double])
        XCTAssertNotEqual(firstAim, rightAim, "In free aim, a first-person table swipe must change the shaft direction")
        try drag(-80, 0); let returned = try capture(app, "v67-pilot-10-new-first-head-left")
        XCTAssertEqual(returned["playerView"] as? String, "firstPerson")
        XCTAssertTrue((returned["business"] as? String ?? "").contains("自由"))
        XCTAssertNotEqual(rightAim, try XCTUnwrap(returned["aim"] as? [Double]))
        let fpStart = wheel.coordinate(withNormalizedOffset: .init(dx: 0.45, dy: 0.5))
        fpStart.press(forDuration: 0.1, thenDragTo: fpStart.withOffset(.init(dx: 0, dy: 60)), withVelocity: .slow, thenHoldForDuration: 0.1)
        try capture(app, "v67-pilot-11-first-wheel")
        XCTAssertFalse(app.buttons["dailyClearance.observeTable"].exists)
        let beforeOverlay = try capture(app, "v67-pilot-before-peek")
        let overlay = app.buttons["shotCamera.temporaryTopDown"]
        overlay.tap(); XCTAssertEqual(overlay.value as? String, "已选中")
        overlay.tap()
        let afterOverlay = try capture(app, "v67-pilot-14-overlay-return")
        XCTAssertEqual(beforeOverlay["eye"] as? [Double],afterOverlay["eye"] as? [Double])
        XCTAssertEqual(beforeOverlay["orientationXYZW"] as? [Double],afterOverlay["orientationXYZW"] as? [Double])
        toggleMode(app); toggleMode(app)
        let after2D = try capture(app, "v67-pilot-15-2d-return")
        XCTAssertEqual(beforeOverlay["eye"] as? [Double],after2D["eye"] as? [Double])
        XCTAssertEqual(after2D["orthographic"] as? Bool,false)
        let resumeWheel = wheel.coordinate(withNormalizedOffset: .init(dx:0.5,dy:0.5))
        resumeWheel.press(forDuration:0.1,thenDragTo:resumeWheel.withOffset(.init(dx:0,dy:-35)),withVelocity:.slow,thenHoldForDuration:0.1)
        let resumed = try capture(app,"v67-pilot-16-resumed-aim")
        XCTAssertEqual(resumed["playerView"] as? String,"firstPerson")
        XCTAssertTrue((resumed["business"] as? String ?? "").contains("自由"))
    }
    private func closeMenu(_ app: XCUIApplication) {
        let identified=app.buttons["dailyClearance.menuClose"]
        let close=identified.exists ? identified : app.buttons["关闭菜单"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout:3))
        // Do not tap the backdrop element's centre: XCTest's iOS 17 modal
        // interruption handling can retarget that tap to a ball after dismissal.
        // Use the window's empty top strip, outside the measured menu and palette.
        func selection() -> [String] {
            ((node(app,"composer.landscape").value as? String) ?? "").split(separator:"，").prefix(4).map(String.init)
        }
        let businessBefore=selection()
        XCTAssertEqual(businessBefore.count,4)
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 17 {
            app.coordinate(withNormalizedOffset:.init(dx:0.30,dy:0.04)).tap()
        } else { close.tap() }
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            !app.buttons["freeplay.cameraMode"].exists
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:5),.completed)
        XCTAssertEqual(selection(),businessBefore,
            "Dismissing the menu must not select a ball or change aim mode")
    }
    private func toggleMode(_ app: XCUIApplication) {
        app.buttons["freeplay.moreMenu"].tap()
        let mode=app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:5))
        let previous=mode.value as? String
        mode.tap()
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            (mode.value as? String) == (previous == "3D" ? "2D" : "3D")
        },object:nil)],timeout:5),.completed)
        closeMenu(app)
    }
    private func rawScene(_ app: XCUIApplication) throws -> [String:Any] {
        let raw=try XCTUnwrap(node(app,"table.scene").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(raw.utf8)) as? [String:Any])
    }
    func testFormalRailPositionsPinchAndTabletRotation() throws {
        let app=try launchFormal();defer { app.terminate() }
        let table=node(app,"table.scene")
        for (index,position) in [[0.0,0.55],[1.18,0], [1.18,0.55],[-1.18,-0.55]].enumerated() {
            toggleMode(app)
            let before=try capture(app,"v67-rail-\(index)-before-edit")
            let basis=try XCTUnwrap(before["planeBasis"] as? [[Double]])
            let balls=try XCTUnwrap(try rawScene(app)["balls"] as? [[String:Any]])
            let cue=try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" })
            let screen=try XCTUnwrap(cue["screen"] as? [Double])
            let x=basis[0][0]+position[0]*(basis[1][0]-basis[0][0])+position[1]*(basis[2][0]-basis[0][0])
            let y=basis[0][1]+position[0]*(basis[1][1]-basis[0][1])+position[1]*(basis[2][1]-basis[0][1])
            // Production 2D dragging keeps the ball 52pt behind the finger
            // (BTBallDragMetrics.fingerClearance); the intended ball point is not the finger endpoint.
            let dx=x-screen[0],dy=y-screen[1],length=hypot(dx,dy)
            XCTAssertGreaterThan(length,1)
            let fingerX=x+52*dx/length,fingerY=y+52*dy/length
            let origin=table.coordinate(withNormalizedOffset:.zero)
            origin.withOffset(.init(dx:screen[0],dy:screen[1])).press(forDuration:0.2,
                thenDragTo:origin.withOffset(.init(dx:fingerX,dy:fingerY)),withVelocity:.slow,thenHoldForDuration:0.1)
            let edited=try rawScene(app)
            let editedBalls=try XCTUnwrap(edited["balls"] as? [[String:Any]])
            let editedCue=try XCTUnwrap(editedBalls.first { $0["key"] as? String == "cueBall" })
            let world=try XCTUnwrap(editedCue["world"] as? [Double])
            XCTAssertEqual(world[0],position[0],accuracy:0.08);XCTAssertEqual(world[2],position[1],accuracy:0.08)
            XCTAssertGreaterThan(try XCTUnwrap(edited["grabCount"] as? Int),expectedGrabs)
            expectedGrabs=try XCTUnwrap(edited["grabCount"] as? Int);originalBoard=nil
            toggleMode(app)
            app.buttons["shotCamera.thirdPerson"].tap()
            let tp=try capture(app,"v67-rail-\(index)-third")
            table.pinch(withScale:1.15,velocity:1)
            let close=try capture(app,"v67-rail-\(index)-closer")
            XCTAssertNotEqual(tp["eye"] as? [Double],close["eye"] as? [Double])
            XCTAssertEqual(try XCTUnwrap(tp["eye"] as? [Double])[1],try XCTUnwrap(close["eye"] as? [Double])[1],accuracy:0.0001)
            app.buttons["shotCamera.firstPerson"].tap()
            let fp=try capture(app,"v67-rail-\(index)-first")
            XCTAssertEqual(fp["playerView"] as? String,"firstPerson")
            XCTAssertEqual(fp["policy"] as? String,"p01Replayable")
            table.pinch(withScale:1.1,velocity:1)
            let fpPinch=try capture(app,"v67-rail-\(index)-first-pinch")
            let fpEye = try XCTUnwrap(fp["eye"] as? [Double])
            let fpPinchEye = try XCTUnwrap(fpPinch["eye"] as? [Double])
            let fpTravel = zip(fpEye, fpPinchEye).map { $0 - $1 }.map { $0 * $0 }.reduce(0, +).squareRoot()
            XCTAssertGreaterThan(fpTravel, 0.0001, "First-person pinch must move the eye along the shaft")
            XCTAssertEqual(fp["fov"] as? Double,fpPinch["fov"] as? Double)
            let beforeRotation = try XCTUnwrap(fp["orientationXYZW"] as? [Double])
            let afterRotation = try XCTUnwrap(fpPinch["orientationXYZW"] as? [Double])
            XCTAssertEqual(beforeRotation.count, 4)
            XCTAssertEqual(afterRotation.count, 4)
            for (before, after) in zip(beforeRotation, afterRotation) {
                XCTAssertEqual(before, after, accuracy: 0.00001)
            }
            app.buttons["shotCamera.firstPerson"].tap()
            let fpReset=try capture(app,"v67-rail-\(index)-first-reset")
            XCTAssertEqual(fp["eye"] as? [Double],fpReset["eye"] as? [Double],
                           "Tapping first-person again must restore its default eye")
            app.buttons["shotCamera.thirdPerson"].tap();settle(app)
            app.buttons["shotCamera.firstPerson"].tap();settle(app)
            let fpRoundTrip=try capture(app,"v67-rail-\(index)-third-first-reset")
            XCTAssertEqual(fp["eye"] as? [Double],fpRoundTrip["eye"] as? [Double],
                           "Third-person to first-person must enter the default first-person eye")
            let wheel=node(app,"shotStage.aimWheel"),p=node(app,"shotStage.aimWheel").coordinate(withNormalizedOffset:.init(dx:0.5,dy:0.5))
            XCTAssertTrue(wheel.isEnabled)
            p.press(forDuration:0.1,thenDragTo:p.withOffset(.init(dx:0,dy:-20)),withVelocity:.slow,thenHoldForDuration:0.1)
            let manual=try capture(app,"v67-rail-\(index)-manual")
            XCTAssertTrue((manual["business"] as? String ?? "").contains("自由"))
            if index == 0 {
                app.buttons["shotCamera.thirdPerson"].tap();settle(app)
                let rows=try XCTUnwrap(try rawScene(app)["balls"] as? [[String:Any]])
                let ball=try XCTUnwrap(rows.first { $0["key"] as? String == "cueBall" })
                let screen=try XCTUnwrap(ball["screen"] as? [Double])
                let p=table.coordinate(withNormalizedOffset:.zero).withOffset(.init(dx:screen[0],dy:screen[1]))
                p.press(forDuration:0.2,thenDragTo:p.withOffset(.init(dx:100,dy:-70)),withVelocity:.slow,thenHoldForDuration:0.1)
                let changed=try rawScene(app)
                let changedBalls=try XCTUnwrap(changed["balls"] as? [[String:Any]])
                let changedCue=try XCTUnwrap(changedBalls.first { $0["key"] as? String == "cueBall" })
                XCTAssertNotEqual(ball["world"] as? [Double],changedCue["world"] as? [Double],"Drag must cross the existing finger dead zone and actually move the cue")
                XCTAssertGreaterThan(try XCTUnwrap(changed["grabCount"] as? Int),expectedGrabs)
                expectedGrabs=try XCTUnwrap(changed["grabCount"] as? Int);originalBoard=nil
                try capture(app,"v67-rail-legitimate-3d-drag")
            }
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            for orientation in [UIDeviceOrientation.portrait,.landscapeLeft] {
                XCUIDevice.shared.orientation=orientation
                let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                    let f=app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height>f.width : f.width>f.height
                },object:nil)
                XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:10),.completed)
                app.buttons["shotCamera.thirdPerson"].tap()
                try capture(app,"v67-tablet-\(orientation.rawValue)-third")
                app.buttons["shotCamera.firstPerson"].tap()
                try capture(app,"v67-tablet-\(orientation.rawValue)-first")
                let peek = app.buttons["shotCamera.temporaryTopDown"]
                peek.tap()
                XCTAssertEqual(peek.value as? String, "已选中")
                peek.tap()
                try capture(app,"v67-tablet-\(orientation.rawValue)-first-restored")
            }
        }
    }

    func testFirstPersonZoomKeepsPitchAndReentersDefault() throws {
        let app = try launchFormal()
        defer { app.terminate() }

        func cameraSnapshot() throws -> [String: Any] {
            settle(app)
            let raw = try XCTUnwrap(node(app, "v63.cameraDiagnostics").value as? String)
            let encoded = try XCTUnwrap(raw.split(separator: " ").first { $0.hasPrefix("v67Baseline=") })
            let data = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst("v67Baseline=".count))))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }

        app.buttons["shotCamera.firstPerson"].tap()
        let initial = try cameraSnapshot()
        let table = node(app, "table.scene")
        table.pinch(withScale: 1.1, velocity: 1)
        let zoomed = try cameraSnapshot()
        let initialEye = try XCTUnwrap(initial["eye"] as? [Double])
        let zoomedEye = try XCTUnwrap(zoomed["eye"] as? [Double])
        XCTAssertNotEqual(initialEye, zoomedEye)
        let initialOrientation = try XCTUnwrap(initial["orientationXYZW"] as? [Double])
        let zoomedOrientation = try XCTUnwrap(zoomed["orientationXYZW"] as? [Double])
        XCTAssertEqual(initialOrientation.count, 4)
        XCTAssertEqual(zoomedOrientation.count, 4)
        for (before, after) in zip(initialOrientation, zoomedOrientation) {
            XCTAssertEqual(before, after, accuracy: 0.00001)
        }

        app.buttons["shotCamera.firstPerson"].tap()
        let reset = try cameraSnapshot()
        XCTAssertEqual(initialEye, try XCTUnwrap(reset["eye"] as? [Double]))

        table.pinch(withScale: 1.1, velocity: 1)
        _ = try cameraSnapshot()
        app.buttons["shotCamera.thirdPerson"].tap()
        settle(app)
        app.buttons["shotCamera.firstPerson"].tap()
        let roundTrip = try cameraSnapshot()
        XCTAssertEqual(initialEye, try XCTUnwrap(roundTrip["eye"] as? [Double]))
    }

    func testFormalShotRetryPlaybackAndBackground() throws {
        let app=try launchFormal();defer { app.terminate() }
        app.buttons["shotCamera.firstPerson"].tap()
        let before=try capture(app,"v67-lifecycle-before-shot")
        let strike=app.buttons["dailyClearance.strike"]
        func enabled(_ element:XCUIElement,_ timeout:TimeInterval=45) {
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:element)],timeout:timeout),.completed)
        }
        enabled(strike);strike.tap();enabled(app.buttons["dailyClearance.undo"])
        originalBoard=nil
        let after=try capture(app,"v67-lifecycle-settled")
        enabled(app.buttons["dailyClearance.playback"]);app.buttons["dailyClearance.playback"].tap()
        enabled(app.buttons["dailyClearance.undo"])
        // Replay restores Float world positions; permit only sub-micrometre conversion noise.
        // The observation-only series above still requires exact ball equality.
        originalBoard=nil
        let replayed=try capture(app,"v67-lifecycle-replay-return")
        func positions(_ row:[String:Any]) throws -> [String:[Double]] {
            let data=Data(try XCTUnwrap(row["scene"] as? String).utf8)
            let scene=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            let balls=try XCTUnwrap(scene["balls"] as? [[String:Any]])
            return try Dictionary(uniqueKeysWithValues:balls.map { (try XCTUnwrap($0["key"] as? String),try XCTUnwrap($0["world"] as? [Double])) })
        }
        let expected=try positions(after),actual=try positions(replayed)
        XCTAssertEqual(Set(expected.keys),Set(actual.keys))
        for (key,point) in expected {
            let restored=try XCTUnwrap(actual[key]);XCTAssertEqual(restored.count,point.count)
            for (a,b) in zip(point,restored) { XCTAssertEqual(a,b,accuracy:0.000001) }
        }
        XCTAssertEqual(after["eye"] as? [Double],replayed["eye"] as? [Double])
        app.buttons["dailyClearance.undo"].tap();originalBoard=nil
        let retried=try capture(app,"v67-lifecycle-retry")
        XCTAssertEqual(before["aim"] as? [Double],retried["aim"] as? [Double])
        let prior=try rawScene(app)
        XCUIDevice.shared.press(.home);app.activate()
        let foreground=try capture(app,"v67-lifecycle-foreground")
        // Native scene reattachment can renormalize Float poses by one ULP.
        // 1 micrometre still rejects the recorded 1.4–3mm restoration regressions.
        for key in ["eye","aim","orientationXYZW"] {
            let expected=try XCTUnwrap(retried[key] as? [Double])
            let actual=try XCTUnwrap(foreground[key] as? [Double])
            XCTAssertEqual(actual.count,expected.count)
            for (a,b) in zip(expected,actual) { XCTAssertEqual(a,b,accuracy:0.000001,"Foreground must preserve \(key)") }
        }
        XCTAssertEqual(try XCTUnwrap(retried["fov"] as? Double),try XCTUnwrap(foreground["fov"] as? Double),accuracy:0.00001)
        XCTAssertEqual(try rawScene(app)["rendererID"] as? String,prior["rendererID"] as? String)
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout:8))
    }

    func testFormalTabletActualWindowResize() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom,.pad)
        let app=try launchFormal();defer { app.terminate() }
        let original=app.windows.firstMatch.frame
        let before=try capture(app,"v67-window-full")
        let origin=app.coordinate(withNormalizedOffset:.zero)
        origin.withOffset(.init(dx:original.width-7,dy:original.height-7)).press(forDuration:0.5,
            thenDragTo:origin.withOffset(.init(dx:original.width*0.7,dy:original.height*0.78)))
        let resized=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.windows.firstMatch.frame.width<original.width-80 },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[resized],timeout:10),.completed)
        let small=try capture(app,"v67-window-small")
        XCTAssertEqual(before["aim"] as? [Double],small["aim"] as? [Double])
        XCTAssertEqual(small["policy"] as? String,"p01Replayable")
        let window=app.windows.firstMatch,f=app.windows.firstMatch.frame
        window.coordinate(withNormalizedOffset:.zero).withOffset(.init(dx:52,dy:32)).tap()
        if abs(app.windows.firstMatch.frame.width-f.width)<1 {
            window.coordinate(withNormalizedOffset:.zero).withOffset(.init(dx:104,dy:32)).tap()
        }
        let restored=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in abs(app.windows.firstMatch.frame.width-original.width)<1 },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[restored],timeout:10),.completed)
        let after=try capture(app,"v67-window-restored")
        XCTAssertEqual(before["aim"] as? [Double],after["aim"] as? [Double])
        XCTAssertEqual(after["playerView"] as? String,"thirdPerson")
        XCTAssertTrue(app.buttons["shotCamera.firstPerson"].isHittable)
    }

}

/// Camera isolation only; unrelated authoring/menu workflows retain their own suites.
final class CameraV67LegacyIsolationUITests: XCTestCase {
    private func verify(_ argument:String,_ prefix:String) throws {
        continueAfterFailure=false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app=XCUIApplication.launchClean(extraArgs:["-forcePremium","-dailyLayout.probe","-3dDrag.probe","-v63.cameraDiagnostics","-v67.cameraBaseline",argument])
        defer { app.terminate() }
        let page=app.descendants(matching:.any).matching(identifier:"composer.landscape").firstMatch
        XCTAssertTrue(page.waitForExistence(timeout:25))
        let brief=app.descendants(matching:.any).matching(identifier:"tryout.briefCard").firstMatch
        if brief.exists { brief.tap() }
        let menu=app.buttons["freeplay.moreMenu"]
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in app.frame.width>app.frame.height && menu.isHittable },object:nil)],timeout:10),.completed)
        menu.tap();let mode=app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:4));if mode.value as? String != "3D" { mode.tap() }
        app.buttons["关闭菜单"].firstMatch.tap()
        let probe=app.descendants(matching:.any).matching(identifier:"v63.cameraDiagnostics").firstMatch
        func capture(_ suffix:String) throws -> [String:Any] {
            XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                guard let value=probe.value as? String else { return false }
                return value.contains("twoViewComputing=false") && value.contains("twoViewMoving=false")
            },object:nil)],timeout:15),.completed)
            let raw=try XCTUnwrap(probe.value as? String)
            let token=try XCTUnwrap(raw.split(separator:" ").first { $0.hasPrefix("v67Baseline=") })
            let data=try XCTUnwrap(Data(base64Encoded:String(token.dropFirst("v67Baseline=".count))))
            let row=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            XCTAssertEqual(row["policy"] as? String,"legacy");XCTAssertEqual(row["surface"] as? Bool,true)
            XCTAssertNil(row["p01"]);XCTAssertEqual(row["orthographic"] as? Bool,false)
            let json=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");json.name=prefix+suffix+".json";json.lifetime = .keepAlways;add(json)
            let shot=XCTAttachment(screenshot:XCUIScreen.main.screenshot());shot.name=prefix+suffix;shot.lifetime = .keepAlways;add(shot)
            return row
        }
        for id in ["shotCamera.firstPerson","shotCamera.thirdPerson","dailyClearance.observeTable"] {
            let button=app.buttons[id];XCTAssertTrue(button.waitForExistence(timeout:5));button.tap();_ = try capture("-"+id)
        }
        let before=try capture("-before-overlay")
        let overlay=app.buttons["shotCamera.temporaryTopDown"];overlay.tap();overlay.tap()
        let after=try capture("-after-overlay")
        XCTAssertEqual(before["eye"] as? [Double],after["eye"] as? [Double])
        XCTAssertEqual(before["orientationXYZW"] as? [Double],after["orientationXYZW"] as? [Double])
    }
    func testCustomComposerKeepsLegacyCamera() throws { try verify("-dailyInteraction.sharedPage=composer","v67-legacy-custom") }
    func testActionTryoutKeepsLegacyCamera() throws { try verify("-deeplink.tryout=drill_c042","v67-legacy-tryout") }
}
