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
                for (id, name) in [("dailyClearance.observeTable", "overview"),
                    ("shotCamera.thirdPerson", "third"), ("shotCamera.firstPerson", "first"),
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

    func testC54ActionStatesAndFourCameraRoundTrip() throws {
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
        let ids = ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        let buttons = ids.map { app.buttons[$0] }
        for button in buttons { contain(app, button, hit: true); XCTAssertTrue(button.isEnabled) }
        let shell = element(app, "shotStage.powerShell").frame
        try capture(app, "c54-alignment-measured")
        XCTAssertEqual((buttons[0].frame.minY + buttons[3].frame.maxY) / 2, shell.midY, accuracy: 0.75)
        for button in buttons { XCTAssertEqual(button.frame.midX, buttons[0].frame.midX, accuracy: 0.5) }
        try capture(app, "c54-third-person")
        buttons[2].tap()
        let diagnostics = element(app, "v63.cameraDiagnostics")
        let firstPerson = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "twoViewMode=firstPerson"), object: diagnostics)
        XCTAssertEqual(XCTWaiter.wait(for: [firstPerson], timeout: 5), .completed)
        waitValue(buttons[2], "已选中")
        try capture(app, "c54-first-person")
        buttons[3].tap()
        waitValue(buttons[3], "已选中")
        for button in buttons.prefix(3) { XCTAssertFalse(button.isEnabled) }
        XCTAssertFalse(app.buttons["dailyClearance.undo"].isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.playback"].isEnabled)
        try capture(app, "c54-peek-disabled")
        buttons[3].tap()
        waitValue(buttons[2], "已选中")
        buttons[0].tap(); waitValue(buttons[0], "已选中")
        try capture(app, "c54-overview")
        buttons[1].tap(); waitValue(buttons[1], "已选中")
        unchanged(original, try state(app))
        XCTAssertEqual(element(app, "freeplay.stage").frame, stage)
        try capture(app, "c54-restored")
        let replay = app.buttons["dailyClearance.playback"]
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertFalse(undo.isEnabled); XCTAssertFalse(replay.isEnabled)
        app.buttons["dailyClearance.strike"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
        XCTAssertTrue(undo.isEnabled)
        try capture(app, "c54-history-enabled")
        replay.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: replay)], timeout: 25), .completed)
        undo.tap()
        XCTAssertFalse(undo.isEnabled)
        try capture(app, "c54-history-undone")
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
        if node.value as? String != dimension { node.tap() }
        waitValue(node, dimension)
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
            mode(app, dimension)
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
            openTransparency(app)
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
            let travel = try XCTUnwrap(cameraField("surfaceTravel"))
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
            XCTAssertEqual(cameraField("surfaceTravel"), travel)
            XCTAssertEqual(cameraField("twoViewTemporary2D"), temporary)
            try capture(app, "camera-" + tag + "-dismissed-no-through")
            XCTAssertEqual(control.frame, originalFrame)
            tap(app, at: center)
        }
        try dismissThenActivate("dailyClearance.observeTable", "overview")
        try waitCamera("surfaceTravel", "1.0")
        unchanged(before, try state(app))
        try dismissThenActivate("shotCamera.temporaryTopDown", "topdown")
        try waitCamera("twoViewTemporary2D", "true")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        try waitCamera("twoViewTemporary2D", "false")
        unchanged(before, try state(app))
        try dismissThenActivate("shotCamera.thirdPerson", "player")
        try waitCamera("surfaceTravel", "0.5")
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
        for dimension in ["2D", "3D"] {
            for fixture in ["completed", "failed"] {
                let app = try launch(fixture: fixture); defer { app.terminate() }
                mode(app, dimension)
                let prefix = "result-\(dimension)-\(fixture)"
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
            let weak = try launch(fixture: "weakBreak"); defer { weak.terminate() }
            mode(weak, dimension)
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
                app.buttons["freeplay.moreMenu"].tap()
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
            app.buttons["freeplay.moreMenu"].tap()
            customItem(app, "menu.aimCloseup").tap()
            XCTAssertEqual(try aimCloseup(app), original)
            app.buttons["freeplay.moreMenu"].tap()
            let grid = customItem(app, "menu.tableGrid")
            let originalGrid = grid.value as? String
            grid.tap()
            app.buttons["freeplay.moreMenu"].tap()
            XCTAssertNotEqual(customItem(app, "menu.tableGrid").value as? String, originalGrid)
            customItem(app, "menu.tableGrid").tap()
            app.buttons["freeplay.moreMenu"].tap()
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
            XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, dimension)
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
    private func launchP01(requiresLandscape: Bool = true, extraArgs: [String] = []) throws -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics"] + extraArgs)
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons["分离角与走位"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(element(app, "shotSimulation.landscape").waitForExistence(timeout: 15))
        if requiresLandscape {
            let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        }
        _ = try state(app)
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

    private func p01More(_ app: XCUIApplication) {
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(element(app, "dailyClearance.menuPanel").waitForExistence(timeout: 3))
    }

    private func p01MenuItem(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let item = app.buttons[id]
        let scroll = app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<3 {
            if item.exists && item.isHittable { return item }
            scroll.swipeUp()
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
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
                _ = try state(app)
            }
            try capture(app, "p01-" + dimension + "-base-ready", extraIDs: ["shotSimulation.landscape", "shotSimulation.readout"])
            assertP01BallsEqual(try p01Balls(app), originalBalls)
            XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
            XCTAssertEqual(element(app, "freeplay.stage").frame, stage)
            p01More(app)
            try capture(app, "p01-" + dimension + "-more-top")
            app.scrollViews["dailyClearance.menuScroll"].swipeUp()
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
        let ids = ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        let shell = element(app, "shotStage.powerShell").frame
        XCTAssertEqual((app.buttons[ids[0]].frame.minY + app.buttons[ids[3]].frame.maxY)/2, shell.midY, accuracy: 1)
        for id in ids {
            app.buttons[id].tap(); waitValue(app.buttons[id], "已选中")
            try capture(app, "p01-3D-" + id)
        }
        app.buttons[ids[3]].tap(); waitValue(app.buttons[ids[2]], "已选中")
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        XCTAssertEqual(try p01Scene(app)["rendererID"] as? String, renderer)
        // Palette in 3D is a status/reference surface, while existing table drag remains supported.
        app.buttons["paletteBall__1"].tap()
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        p01More(app); app.buttons["freeplay.cameraMode"].tap()
        waitValue(app.buttons["freeplay.cameraMode"], "2D"); app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
        assertP01BallsEqual(try p01Balls(app), originalBalls)
        try capture(app, "p01-2D-restored")
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_打"].waitForExistence(timeout: 5))
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
        app.buttons["dailyClearance.aim.pocket"].tap(); waitMode("进袋")
        let wheel = element(app, "shotStage.aimWheel")
        wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        waitMode("自由")
        try capture(app, "p01-temporary-free")
        shootAndSettle(); waitMode("进袋")
        try capture(app, "p01-next-shot-pocket")
        p01More(app); p01MenuItem(app, "dailyClearance.aimModeMenu").tap()
        app.buttons["dailyClearance.aim.free"].tap(); waitMode("自由")
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
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
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
                    app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
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
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
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
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
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
