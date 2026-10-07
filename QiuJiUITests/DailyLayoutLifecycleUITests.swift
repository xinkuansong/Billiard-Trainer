import XCTest

/// Current-run evidence only. The caller must inject a fresh output leaf and set
/// the simulator's real content size before selecting the maximum-type test.
final class DailyLayoutLifecycleUITests: XCTestCase {
    private var output: URL!
    private var captures = [[String: String]]()
    private let diagnosticIDs = ["dailyLayout.entryProbe",
        "v63.cameraDiagnostics", "table.scene", "dailyClearance.landscape", "freeplay.stage",
        "dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu",
        "paletteBall_cueBall", "paletteBall__1", "paletteBall__15", "dailyLayout.headerProbe",
        "dailyLayout.controlsProbe", "shotStage.aimWheel", "shotStage.powerBar", "shotStage.instrument",
        "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback",
        "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.observeTable"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        let path = env["DAILY_ADAPTIVITY_DIR"] ?? env["TEST_RUNNER_DAILY_ADAPTIVITY_DIR"]
        output = URL(fileURLWithPath: try XCTUnwrap(path,
            "Inject DAILY_ADAPTIVITY_DIR; lifecycle evidence has no legacy output fallback"))
            .appendingPathComponent(name.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func frame(_ rect: CGRect) -> [String: Double] {
        ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
    }

    private func capture(_ app: XCUIApplication, _ state: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: output.appendingPathComponent(state + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = state; attachment.lifetime = .keepAlways; add(attachment)
        try app.debugDescription.write(to: output.appendingPathComponent(state + "-ax.txt"),
                                      atomically: true, encoding: .utf8)
        var diagnostics = [[String: Any]]()
        for id in diagnosticIDs {
            let node = element(app, id)
            var row: [String: Any] = ["identifier": id, "exists": node.exists]
            if node.exists {
                row["frame"] = frame(node.frame)
                row["label"] = node.label
                row["value"] = node.value.map { String(describing: $0) } ?? ""
            }
            diagnostics.append(row)
        }
        let window = app.windows.firstMatch
        let record: [String: Any] = ["state": state, "timestamp": Date().timeIntervalSince1970,
            "appState": app.state.rawValue, "launchArguments": app.launchArguments,
            "windowExists": window.exists, "windowFrame": frame(window.exists ? window.frame : app.frame),
            "diagnostics": diagnostics]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(state + ".json"))
        captures.append(["state": state, "screenshot": state + ".png", "measurements": state + ".json",
                         "rawAX": state + "-ax.txt"])
        try JSONSerialization.data(withJSONObject: captures, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("manifest.json"))
    }

    private func launch(fixture: String? = nil, deepLink: Bool = true, settled: Bool = true, extraArgs: [String] = []) -> XCUIApplication {
        var args = ["-dailyLayout.probe", "-3dDrag.probe", "-v63.cameraDiagnostics",
                    "-dailyClearance.resetState", "-dailyClearance.resetHomeState", "-forcePremium",
                    "-dailyClearance.preferredGame.v1", "chineseEightBall"]
        if deepLink { args.append("-deeplink.dailyClearance") }
        if let fixture {
            args.append("-dailyClearance.fixture=\(fixture)")
            if settled { args.append("-dailyClearance.fixtureSettled") }
        }
        return XCUIApplication.launchClean(extraArgs: args + extraArgs)
    }

    /// Preserve a failed entry before asserting. Keep the audit's existing 15s
    /// deadline so an entry regression cannot be hidden by extending the wait.
    private func requireEntry(_ app: XCUIApplication, marker: String, state: String) throws -> Bool {
        let reached = element(app, marker).waitForExistence(timeout: 15)
        try capture(app, state + (reached ? "-ready" : "-failed"))
        XCTAssertTrue(element(app, "dailyLayout.entryProbe").exists,
                      "DEBUG daily layout entry diagnostic must be present")
        XCTAssertTrue(reached, "Daily entry did not reach \(marker) within the existing 15s audit deadline")
        return reached
    }

    func testRepeatedColdSelectionAndFailedEntriesRecordReadiness() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        continueAfterFailure = true
        for fixture in ["failed", "selection", "failed", "selection"] {
            let index = captures.count
            let app = launch(fixture: fixture)
            defer { app.terminate() }
            let marker = fixture == "failed" ? "dailyClearance.rerack" : "freeplay.stage"
            guard try requireEntry(app, marker: marker, state: "cold-\(index)-\(fixture)") else {
                app.terminate()
                continue
            }
            XCTAssertTrue(element(app, "dailyClearance.landscape").exists)
            XCTAssertTrue(app.buttons["dailyClearance.back"].isHittable)
            if fixture == "selection" {
                let raw = try XCTUnwrap(element(app, "table.scene").value as? String)
                let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                XCTAssertNotNil(probe["rendererID"] as? String)
                XCTAssertNotNil(probe["dailyLayout"], "Table probe must carry the current layout snapshot")
                XCTAssertFalse(try XCTUnwrap(probe["balls"] as? [[String: Any]]).isEmpty)
            }
            app.terminate()
        }
    }

    func testHomeEntryExitAndReentryRecordWindowAndRenderer() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(deepLink: false)
        defer { app.terminate() }
        app.switchTab(.training)
        let home = app.buttons["trainingHome.dailyClearance"]
        for visit in 1...2 {
            let atHome = home.waitForExistence(timeout: 12)
            try capture(app, "home-\(visit)-before")
            XCTAssertTrue(atHome)
            XCTAssertTrue(home.isHittable)
            home.tap()
            guard try requireEntry(app, marker: "dailyClearance.landscape", state: "home-\(visit)-entry") else { return }
            XCTAssertTrue(app.buttons["dailyClearance.back"].isHittable)
            XCTAssertTrue(element(app, "table.scene").exists)
            app.buttons["dailyClearance.back"].tap()
            let returned = home.waitForExistence(timeout: 8)
            try capture(app, "home-\(visit)-returned")
            XCTAssertTrue(returned)
            let window = app.windows.firstMatch.frame
            XCTAssertGreaterThan(window.height, window.width, "Phone exit restores portrait")
        }
    }

    private func revealPaletteBall(_ app: XCUIApplication, number: Int) throws -> XCUIElement {
        let ball = app.buttons["paletteBall__\(number)"]
        XCTAssertTrue(ball.waitForExistence(timeout: 5))
        for attempt in 0..<5 {
            let window = app.windows.firstMatch.frame
            let palettes = app.scrollViews.containing(.button, identifier: "paletteBall__\(number)")
            let scroll = palettes.firstMatch
            let visibleBounds = scroll.exists ? scroll.frame : window
            if ball.isHittable && visibleBounds.contains(ball.frame) { return ball }
            if scroll.exists {
                if number == 1 { scroll.swipeRight() } else { scroll.swipeLeft() }
            } else {
                try capture(app, "palette-\(number)-no-scroll-\(attempt)")
                XCTFail("Clipped palette ball has no accessible scrolling container")
                return ball
            }
        }
        try capture(app, "palette-\(number)-unreachable")
        XCTFail("Palette end remains unreachable after bounded scrolling")
        return ball
    }

    func testHeaderModeAndMoreUseSeparateHitRegions() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "selection")
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "header-entry") else { return }
        let mode = app.buttons["freeplay.cameraMode"]
        let more = app.buttons["freeplay.moreMenu"]
        for dimension in ["2D", "3D"] {
            if mode.value as? String != dimension { mode.tap() }
            try capture(app, "header-\(dimension)-before")
            XCTAssertEqual(more.frame.width, 44, accuracy: 0.5,
                           "The actual native Menu button must occupy its 44pt slot")
            // The mode's 1pt stroked capsule extends its AX envelope by 0.5pt.
            XCTAssertLessThanOrEqual(mode.frame.maxX, more.frame.minX + 0.5)
            XCTAssertLessThan(app.buttons["paletteBall__15"].frame.maxX, mode.frame.minX)
            let title = app.staticTexts["每日清台"].firstMatch
            XCTAssertTrue(title.exists)
            XCTAssertLessThan(title.frame.maxX, app.buttons["paletteBall_cueBall"].frame.minX)
            // Near the shared edge: verify routing, not just AX rectangles.
            more.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()
            let item = app.buttons["dailyClearance.spinTransparencyMenu"]
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            XCTAssertEqual(mode.value as? String, dimension)
            try capture(app, "header-\(dimension)-more-open")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
            XCTAssertFalse(item.exists)
            mode.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let expected = dimension == "2D" ? "3D" : "2D"
            let switched = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: mode)
            XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 5), .completed)
            XCTAssertFalse(item.exists, "Mode edge must not open the adjacent Menu")
            try capture(app, "header-\(dimension)-edge-switched")
        }
    }

    /// Controlled header proposal only; actual system windows are a separate test.
    func testScrollingHeaderSelectsBothEdgesAndRestoresWithoutStateLoss() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "layoutPaletteEdges", extraArgs: ["-dailyLayout.headerAudit"])
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "header-host-entry") else { return }
        let status = element(app, "dailyClearance.landscape")
        func renderer() throws -> String {
            let raw = try XCTUnwrap(element(app, "table.scene").value as? String)
            let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            return try XCTUnwrap(data["rendererID"] as? String)
        }
        let identity = try renderer()
        let toggle = app.buttons["dailyLayout.toggleHeaderWidth"]
        for dimension in ["2D", "3D"] {
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension { mode.tap() }
            toggle.tap()
            let scroll = app.scrollViews["dailyClearance.scrollingPalette"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 5))
            try capture(app, "header-host-\(dimension)-narrow-initial")
            for number in [1, 15] {
                let prior = status.value as? String
                let ball = try revealPaletteBall(app, number: number)
                XCTAssertEqual(status.value as? String, prior, "Scrolling alone must not change the selected target")
                // Open-table fixtures intentionally have no assigned-group
                // highlight. Actual first/last selection below proves legality.
                XCTAssertEqual(ball.value as? String, "在桌上")
                XCTAssertEqual(ball.frame.width, 44, accuracy: 0.5)
                XCTAssertTrue(scroll.frame.contains(ball.frame))
                XCTAssertTrue(app.buttons["paletteBall_cueBall"].isHittable)
                // Exercise each outer slot edge, inside the rectangular clip.
                ball.coordinate(withNormalizedOffset: CGVector(dx: number == 1 ? 0.08 : 0.92, dy: 0.5)).tap()
                let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    (status.value as? String ?? "").contains("目标_\(number)，")
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
                try capture(app, "header-host-\(dimension)-selected-\(number)")
            }
            let selected = status.value as? String
            toggle.tap()
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: scroll)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
            XCTAssertTrue(element(app, "dailyClearance.singleRowPalette").waitForExistence(timeout: 5))
            XCTAssertEqual(status.value as? String, selected)
            XCTAssertEqual(try renderer(), identity)
            try capture(app, "header-host-\(dimension)-restored")
        }
    }

    /// Use a wide real device so the controlled header can cross its own measured
    /// threshold. The window itself is unchanged; this is a component boundary test.
    func testHeaderCapacityBoundaryRoundTripKeepsState() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "layoutPaletteEdges",
                         extraArgs: ["-dailyLayout.headerAudit", "-dailyLayout.headerBoundaryAudit"])
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "boundary-entry") else { return }
        let probe = element(app, "dailyLayout.headerProbe")
        func field(_ name: String) -> String? {
            (probe.value as? String)?.split(separator: " ").first { $0.hasPrefix(name + "=") }
                .map { String($0.dropFirst(name.count + 1)) }
        }
        let threshold = try XCTUnwrap(field("regularThreshold").flatMap(Double.init))
        let original = try XCTUnwrap(field("proposal").flatMap(Double.init))
        let scale = try XCTUnwrap(field("displayScale").flatMap(Double.init))
        XCTAssertGreaterThanOrEqual(scale, 1)
        let pixel = 1 / scale
        XCTAssertGreaterThan(original, threshold + 1, "Select a wide device; do not silently clamp the T+1 case")
        let status = element(app, "dailyClearance.landscape")
        let before = status.value as? String
        for (step, expectedWidth) in [(1, threshold - 1), (2, threshold - pixel), (3, threshold),
                                      (4, threshold + pixel), (5, threshold + 1), (6, original)] {
            app.buttons["dailyLayout.toggleHeaderWidth"].tap()
            let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let width = field("proposal").flatMap(Double.init) else { return false }
                return abs(width - expectedWidth) < 0.01
            }, object: nil)
            let reached = XCTWaiter.wait(for: [resized], timeout: 5)
            try capture(app, "boundary-step-\(step)")
            XCTAssertEqual(reached, .completed, "The requested header proposal must actually be applied")
            XCTAssertEqual(try XCTUnwrap(field("proposal").flatMap(Double.init)), expectedWidth, accuracy: 0.01)
            XCTAssertEqual(field("style"), step <= 2 ? "compact" : "regular")
            XCTAssertEqual(field("presentation"), "fullRow")
            XCTAssertEqual(status.value as? String, before)
            let title = app.staticTexts["每日清台"].firstMatch
            XCTAssertTrue(title.exists)
            let compact = step <= 2
            let naturalWidth = try XCTUnwrap(field(compact ? "title13" : "title15").flatMap(Double.init),
                                            "Header probe must expose the actual natural title width")
            XCTAssertTrue(naturalWidth.isFinite && naturalWidth > 0)
            // A complete AX label can accompany clipped or compressed glyphs.
            // Protect the measured rendered width: regular keeps only the existing
            // 2pt fit, compact keeps its full natural width, with at most 0.5pt
            // tolerance for AX frame quantization across simulator runtimes.
            let minimumTitleWidth = naturalWidth - (compact ? 0 : 2)
            XCTAssertGreaterThanOrEqual(Double(title.frame.width), minimumTitleWidth - 0.5,
                "Title must retain its content width at boundary step \(step): natural=\(naturalWidth), AX=\(title.frame.width)")
            XCTAssertLessThan(title.frame.maxX,
                              app.buttons["paletteBall_cueBall"].frame.minX)
            XCTAssertLessThan(app.buttons["paletteBall__15"].frame.maxX,
                              app.buttons["freeplay.cameraMode"].frame.minX)
            XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
        }
    }

    func testHeaderPaletteFirstAndLastSlotsRemainReachable() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "selection")
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "palette-entry") else { return }
        let status = element(app, "dailyClearance.landscape")
        for dimension in ["2D", "3D"] {
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension { mode.tap() }
            let first = try revealPaletteBall(app, number: 1)
            XCTAssertTrue(first.isEnabled)
            first.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (status.value as? String ?? "").contains("目标_1")
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            try capture(app, "palette-\(dimension)-first-selected")
            let last = try revealPaletteBall(app, number: 15)
            XCTAssertEqual(last.value as? String, "已进袋", "Selection fixture intentionally has no 15 ball")
            last.tap()
            XCTAssertTrue(app.staticTexts["这颗球已进袋"].waitForExistence(timeout: 3))
            XCTAssertTrue((status.value as? String ?? "").contains("目标_1"),
                          "Tapping the empty end slot must preserve the legal selected target")
            try capture(app, "palette-\(dimension)-last-slot")
            _ = try revealPaletteBall(app, number: 1)
        }
    }

    /// Run only after the orchestrator sets and reads back system maximum content
    /// size. This environment declaration records qualification, not a font override.
    func testMaximumTypeTransparencyEndpointsAndCloseRemainReachable() throws {
        let env = ProcessInfo.processInfo.environment
        let size = env["DAILY_LAYOUT_CONTENT_SIZE"] ?? env["TEST_RUNNER_DAILY_LAYOUT_CONTENT_SIZE"]
        XCTAssertEqual(size, "accessibility-extra-extra-extra-large",
                       "Caller must set/read back real simulator content_size and inject the result")
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "selection")
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "ax-entry") else { return }
        for dimension in ["2D", "3D"] {
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension { mode.tap() }
            app.buttons["freeplay.moreMenu"].tap()
            let item = app.buttons["dailyClearance.spinTransparencyMenu"]
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            XCTAssertTrue(item.isHittable)
            item.tap()
            let slider = app.sliders["dailyClearance.spinTransparencySlider"]
            let done = app.buttons["dailyClearance.spinTransparencyDone"]
            let opened = slider.waitForExistence(timeout: 5)
            try capture(app, "ax-\(dimension)-panel-open")
            XCTAssertTrue(opened)
            XCTAssertTrue(slider.isHittable)
            let title = app.staticTexts["打点盘透明度"].firstMatch
            XCTAssertTrue(title.exists)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(title.frame))
            XCTAssertTrue(done.isHittable)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(done.frame))
            for (position, percent) in [(CGFloat(0), "0%"), (CGFloat(1), "100%")] {
                slider.adjust(toNormalizedSliderPosition: position)
                let endpoint = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", percent), object: slider)
                let reached = XCTWaiter.wait(for: [endpoint], timeout: 3)
                try capture(app, "ax-\(dimension)-endpoint-\(percent)")
                XCTAssertEqual(reached, .completed)
            }
            done.tap()
            XCTAssertFalse(slider.exists)
            XCTAssertTrue(element(app, "spinPad.disc").exists)
            app.buttons["shotStage.spinEntry"].tap()
            XCTAssertFalse(element(app, "spinPad.disc").exists)
            XCTAssertTrue(app.buttons["dailyClearance.strike"].isHittable)
            try capture(app, "ax-\(dimension)-closed")
        }
    }

    private func diagnosticField(_ app: XCUIApplication, id: String, key: String) -> String? {
        (element(app, id).value as? String)?.split(separator: " ")
            .first { $0.hasPrefix(key + "=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    private func shotCount(_ app: XCUIApplication) throws -> Int {
        try XCTUnwrap(diagnosticField(app, id: "v63.cameraDiagnostics", key: "dailyShotCount").flatMap(Int.init),
                      "A missing diagnostic must not masquerade as zero shots")
    }

    private func powerValue(_ app: XCUIApplication) throws -> Double {
        let value = try XCTUnwrap(element(app, "shotStage.powerBar").value as? String)
        return try XCTUnwrap(Double(value), "Power AX value must expose the actual numeric velocity")
    }

    private func waitForControl(_ app: XCUIApplication, _ id: String, state: String,
                                timeout: TimeInterval = 15) throws {
        let control = element(app, id)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            control.exists && control.isEnabled && control.isHittable
        }, object: nil)
        let reached = XCTWaiter.wait(for: [expectation], timeout: timeout)
        try capture(app, state)
        XCTAssertEqual(reached, .completed, "Required control must be enabled and reachable: \(id)")
    }

    private func assertControlsFit(_ app: XCUIApplication, dimension: String) throws {
        let probe = element(app, "dailyLayout.controlsProbe")
        XCTAssertTrue(probe.exists, "W3 must expose actual measurement/fit diagnostics")
        XCTAssertEqual(diagnosticField(app, id: "dailyLayout.controlsProbe", key: "controlsFit"), "true")
        let measuredHeight = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe",
            key: "instrumentHeight").flatMap(Double.init))
        let padding = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe",
            key: "controlsVerticalPadding").flatMap(Double.init))
        XCTAssertTrue(padding.isFinite && padding >= 0 && padding <= 8)
        XCTAssertTrue(measuredHeight.isFinite && measuredHeight > 0)
        // v4 uses a 4pt inter-group gap, and the diagnostic normalizes to the
        // shared component's old 6pt gap. Verify visible geometry directly.
        let instrument = try element(app, "shotStage.instrument").snapshot().frame
        let spinEntry = try element(app, "shotStage.spinEntry").snapshot().frame
        let power = try element(app, "shotStage.powerBar").snapshot().frame
        XCTAssertTrue(instrument.insetBy(dx: -0.5, dy: -0.5).contains(spinEntry))
        XCTAssertTrue(instrument.insetBy(dx: -0.5, dy: -0.5).contains(power))
        let strike = try element(app, "dailyClearance.strike").snapshot().frame
        XCTAssertEqual(strike.minY - instrument.maxY, 4, accuracy: 0.5)
        XCTAssertEqual(strike.width, 60, accuracy: 0.5)
        XCTAssertEqual(strike.height, 60, accuracy: 0.5)
        let window = app.windows.firstMatch.frame
        let ids = ["break.entry", "shotStage.spinEntry", "shotStage.aimWheel", "shotStage.powerBar",
                   "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback"]
            + (dimension == "3D" ? ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown"] : [])
        var frames = [(String, CGRect)]()
        for id in ids {
            let node = element(app, id)
            XCTAssertTrue(node.exists, "Core action must not disappear in the supported window: \(id)")
            let rect = try node.snapshot().frame
            let screenRect = node.frame
            XCTAssertGreaterThan(rect.width, 0)
            XCTAssertGreaterThan(rect.height, 0)
            XCTAssertTrue(window.insetBy(dx: -0.01, dy: -0.01).contains(screenRect), "Control outside real window: \(id) \(rect)")
            if id == "shotStage.aimWheel" || id == "shotStage.powerBar" {
                XCTAssertGreaterThanOrEqual(rect.height, 119.5, "v4 preserves at least the compact 120pt travel")
                XCTAssertLessThanOrEqual(rect.height, 144.5)
            } else {
                XCTAssertGreaterThanOrEqual(rect.width, 43.5)
                XCTAssertGreaterThanOrEqual(rect.height, 43.5)
            }
            frames.append((id, rect))
        }
        for i in frames.indices {
            for j in frames.indices where j > i {
                let intersection = frames[i].1.intersection(frames[j].1)
                XCTAssertTrue(intersection.isNull || intersection.width <= 0.5 || intersection.height <= 0.5,
                              "Distinct actual controls must not share a hit region: \(frames[i].0)/\(frames[j].0)")
            }
        }
    }

    private func dragPowerToEndpoint(_ app: XCUIApplication, expected: Double, upward: Bool,
                                     state: String) throws {
        let power = element(app, "shotStage.powerBar")
        // Even the minimum gain 0.1 accepts 0.7 * 0.1 * 0.6 of
        // the fractional range per stroke. This bounded displacement budget
        // can cover the entire range without increasing any readiness timeout.
        let maximumStrokes = Int(ceil(1 / (0.7 * 0.1 * 0.6))) + 1
        for _ in 0..<maximumStrokes {
            if abs(try powerValue(app) - expected) <= 0.01 { break }
            XCTAssertTrue(power.isHittable && power.isEnabled)
            let from = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.85 : 0.15))
            let to = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.15 : 0.85))
            from.press(forDuration: 0.1, thenDragTo: to,
                           withVelocity: XCUIGestureVelocity(rawValue: 600), thenHoldForDuration: 0.1)
        }
        try capture(app, state)
        XCTAssertEqual(try powerValue(app), expected, accuracy: 0.01, "Bounded real drags must reach the business endpoint")
    }

    private func checkPowerRange(manual: Bool) throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: manual ? "manual" : "selection", settled: !manual)
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "power-entry") else { return }
        let initialCount = try shotCount(app)
        if manual {
            XCTAssertEqual(initialCount, 0)
            XCTAssertEqual(try powerValue(app), 8, accuracy: 0.01)
            XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled, "Manual break must remain an undelivered rack")
        }
        let mode = app.buttons["freeplay.cameraMode"]
        for dimension in ["2D", "3D"] {
            if mode.value as? String != dimension { mode.tap() }
            try waitForControl(app, "shotStage.powerBar", state: "power-\(dimension)-ready")
            try assertControlsFit(app, dimension: dimension)
            let minimum = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe", key: "velocityMin").flatMap(Double.init))
            let maximum = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe", key: "velocityMax").flatMap(Double.init))
            XCTAssertEqual(minimum, 0.5, accuracy: 0.001)
            XCTAssertEqual(maximum, manual ? 10 : 8, accuracy: 0.001,
                           "Undelivered break and settled play must use their distinct business ranges")
            try dragPowerToEndpoint(app, expected: 0.5, upward: false, state: "power-\(dimension)-minimum")
            XCTAssertEqual(try shotCount(app), initialCount)
            try dragPowerToEndpoint(app, expected: manual ? 10 : 8, upward: true, state: "power-\(dimension)-maximum")
            XCTAssertEqual(try shotCount(app), initialCount)
            // At 18pt/s (below fineSpeed24), 5pt is accepted with gain0.1.
            // The 144pt travel and 0.6 mapping yield fraction delta 0.002083;
            // gamma1.8 predicts about 0.028/0.036m/s from ordinary/break maxima.
            // Check an observed sub-detent change, not a fabricated 1pt=.01 law.
            let power = element(app, "shotStage.powerBar")
            let old = try powerValue(app)
            let center = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 5)),
                         withVelocity: XCUIGestureVelocity(rawValue: 18), thenHoldForDuration: 0.1)
            try capture(app, "power-\(dimension)-fine")
            let difference = old - (try powerValue(app))
            XCTAssertGreaterThan(difference, 0)
            XCTAssertLessThan(difference, 0.1)
            XCTAssertEqual(try shotCount(app), initialCount)
            // Release outside the power lane cancels firing regardless of the
            // accepted value change. Keep the endpoint inside the real window.
            let frame = power.frame
            let window = app.windows.firstMatch.frame
            let cancelX = frame.minX - 24
            XCTAssertTrue(window.contains(CGPoint(x: cancelX, y: frame.midY)))
            center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: cancelX - frame.midX, dy: 0)))
            try capture(app, "power-\(dimension)-cancel")
            XCTAssertEqual(try shotCount(app), initialCount)
            try waitForControl(app, "dailyClearance.strike", state: "power-\(dimension)-released")
        }
    }

    func testDailyPowerEndpointsAndFineAdjustmentDoNotFireInBothModes() throws {
        try checkPowerRange(manual: false)
    }

    func testManualBreakPowerRangeIsDistinctAndDoesNotFireInBothModes() throws {
        try checkPowerRange(manual: true)
    }

    func testDailyAimChangesWithoutFiringAndControlsStayInsideWindow() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(fixture: "selection")
        defer { app.terminate() }
        guard try requireEntry(app, marker: "freeplay.stage", state: "aim-entry") else { return }
        let mode = app.buttons["freeplay.cameraMode"]
        let count = try shotCount(app)
        func aim() throws -> [Double] {
            try ["aimX", "aimZ"].map { key in
                try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe", key: key).flatMap(Double.init))
            }
        }
        for dimension in ["2D", "3D"] {
            if mode.value as? String != dimension { mode.tap() }
            try waitForControl(app, "dailyClearance.strike", state: "aim-\(dimension)-ready")
            try assertControlsFit(app, dimension: dimension)
            let velocity = try powerValue(app)
            let initialAim = try aim()
            let wheel = element(app, "shotStage.aimWheel")
            XCTAssertTrue(wheel.isEnabled && wheel.isHittable)
            let center = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 0, dy: -24)),
                         withVelocity: .slow, thenHoldForDuration: 0.1)
            try capture(app, "aim-\(dimension)-up")
            let moved = try aim()
            XCTAssertGreaterThan(hypot(moved[0] - initialAim[0], moved[1] - initialAim[1]), 0.0001)
            center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 0, dy: 12)),
                         withVelocity: .slow, thenHoldForDuration: 0.1)
            try capture(app, "aim-\(dimension)-reverse")
            let reversed = try aim()
            XCTAssertGreaterThan(hypot(reversed[0] - moved[0], reversed[1] - moved[1]), 0.0001)
            let directionDot = (moved[0] - initialAim[0]) * (reversed[0] - moved[0])
                + (moved[1] - initialAim[1]) * (reversed[1] - moved[1])
            XCTAssertLessThan(directionDot, 0, "Reversing wheel travel must reverse the direction response")
            XCTAssertEqual(try powerValue(app), velocity, accuracy: 0.01)
            XCTAssertEqual(try shotCount(app), count)
            try waitForControl(app, "dailyClearance.strike", state: "aim-\(dimension)-released")
        }
    }

    func testDailyCoreActionsAndCameraRemainReachableAfterRealShot() throws {
        try verifyCoreActionsAfterRealShot(extraArgs: [])
    }

    func testR1SquareCoreActionsAfterRealShot() throws {
        try verifyCoreActionsAfterRealShot(extraArgs: ["-dailyLayout.viewport=760x760"])
    }

    private func verifyCoreActionsAfterRealShot(extraArgs: [String]) throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for dimension in ["2D", "3D"] {
            let app = launch(fixture: "selection", extraArgs: extraArgs)
            defer { app.terminate() }
            guard try requireEntry(app, marker: "freeplay.stage", state: "actions-\(dimension)-entry") else { return }
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension { mode.tap() }
            try waitForControl(app, "dailyClearance.strike", state: "actions-\(dimension)-ready")
            try assertControlsFit(app, dimension: dimension)
            let before = try shotCount(app)
            if dimension == "3D" {
                for id in ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown"] {
                    try waitForControl(app, id, state: "camera-\(id)-ready")
                    app.buttons[id].tap()
                    try capture(app, "camera-\(id)-selected")
                    if id == "shotCamera.temporaryTopDown" {
                        XCTAssertEqual(app.buttons[id].value as? String, "已选中")
                        app.buttons[id].tap()
                        XCTAssertEqual(app.buttons[id].value as? String, "未选中")
                    }
                    XCTAssertEqual(try shotCount(app), before)
                }
                try waitForControl(app, "dailyClearance.strike", state: "camera-returned")
            }
            app.buttons["dailyClearance.strike"].tap()
            try waitForControl(app, "dailyClearance.undo", state: "actions-\(dimension)-settled", timeout: 35)
            XCTAssertEqual(try shotCount(app), before + 1)
            try waitForControl(app, "dailyClearance.playback", state: "actions-\(dimension)-playback-ready")
            app.buttons["dailyClearance.playback"].tap()
            let busy = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"),
                                                 object: app.buttons["dailyClearance.playback"])
            XCTAssertEqual(XCTWaiter.wait(for: [busy], timeout: 5), .completed, "Actual replay must start")
            try waitForControl(app, "dailyClearance.playback", state: "actions-\(dimension)-replay-returned", timeout: 35)
            XCTAssertEqual(try shotCount(app), before + 1, "Playback must not append a new visit")
            try assertControlsFit(app, dimension: dimension)
            app.buttons["dailyClearance.undo"].tap()
            let undone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.diagnosticField(app, id: "v63.cameraDiagnostics", key: "dailyShotCount").flatMap(Int.init) == before
            }, object: nil)
            let restored = XCTWaiter.wait(for: [undone], timeout: 5)
            try capture(app, "actions-\(dimension)-undone")
            XCTAssertEqual(restored, .completed)
            app.terminate()
        }
    }

    /// The aim ruler is relative: its edges are touch regions, not absolute angle endpoints.
    func testDailyAimEdgeTouchesAndFineAdjustmentRemainResponsive() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        func idle(_ app: XCUIApplication, state: String) throws {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.diagnosticField(app, id: "v63.cameraDiagnostics", key: "twoViewComputing") == "false"
            }, object: nil)
            let reached = XCTWaiter.wait(for: [expectation], timeout: 5)
            try capture(app, state)
            XCTAssertEqual(reached, .completed, "Read the actual solve-idle state, without a sleep fallback")
        }
        func aim(_ app: XCUIApplication) throws -> (Double, Double) {
            let x = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe", key: "aimX").flatMap(Double.init))
            let z = try XCTUnwrap(diagnosticField(app, id: "dailyLayout.controlsProbe", key: "aimZ").flatMap(Double.init))
            XCTAssertTrue(x.isFinite && z.isFinite)
            XCTAssertGreaterThan(hypot(x, z), 0)
            return (x, z)
        }
        func angle(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
            abs(atan2(a.0 * b.1 - a.1 * b.0, a.0 * b.0 + a.1 * b.1))
        }
        for dimension in ["2D", "3D"] {
            var measured = [String: Double]()
            var initialAim: (Double, Double)?
            // Fresh identical selection fixtures make coarse/fine comparisons start at the
            // same aim and precision-session state, rather than relying on inverse drags.
            for input in ["edges", "fine", "coarse"] {
                let app = launch(fixture: "selection")
                defer { app.terminate() }
                guard try requireEntry(app, marker: "freeplay.stage", state: "aim-edge-\(dimension)-\(input)-entry") else { return }
                let mode = app.buttons["freeplay.cameraMode"]
                if mode.value as? String != dimension { mode.tap() }
                try waitForControl(app, "shotStage.aimWheel", state: "aim-edge-\(dimension)-\(input)-ready")
                try idle(app, state: "aim-edge-\(dimension)-\(input)-idle")
                let ruler = element(app, "shotStage.aimWheel")
                XCTAssertEqual(ruler.frame.height, 144, accuracy: 0.5)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(ruler.frame))
                let count = try shotCount(app)
                let power = try powerValue(app)
                let before = try aim(app)
                if input == "edges" {
                    for (label, startY, endY) in [("top", CGFloat(0.08), CGFloat(0.18)),
                                                  ("bottom", CGFloat(0.92), CGFloat(0.82))] {
                        let from = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                        let to = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
                        let edgeBefore = try aim(app)
                        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: XCUIGestureVelocity(rawValue: 600), thenHoldForDuration: 0)
                        try idle(app, state: "aim-edge-\(dimension)-\(label)-changed")
                        XCTAssertGreaterThan(angle(edgeBefore, try aim(app)), 0.000001, "Actual edge touch must change direction")
                        XCTAssertEqual(try shotCount(app), count)
                        XCTAssertEqual(try powerValue(app), power, accuracy: 0.001)
                    }
                } else {
                    if let reference = initialAim {
                        XCTAssertLessThan(angle(reference, before), 0.000001, "Compare the same fixture aim")
                    } else { initialAim = before }
                    let from = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    let distance: CGFloat = input == "fine" ? 5 : 24
                    let to = from.withOffset(CGVector(dx: 0, dy: -distance))
                    from.press(forDuration: 0.1, thenDragTo: to,
                               withVelocity: XCUIGestureVelocity(rawValue: input == "fine" ? 18 : 600), thenHoldForDuration: 0)
                    try idle(app, state: "aim-edge-\(dimension)-\(input)-changed")
                    measured[input] = angle(before, try aim(app))
                    XCTAssertGreaterThan(measured[input]!, 0.000001, "Synthetic input must produce a real direction change")
                    XCTAssertEqual(try shotCount(app), count)
                    XCTAssertEqual(try powerValue(app), power, accuracy: 0.001)
                }
                app.terminate()
            }
            XCTAssertLessThan(try XCTUnwrap(measured["fine"]), try XCTUnwrap(measured["coarse"]),
                              "Actual short slow input must adjust less than actual longer fast input")
            try JSONSerialization.data(withJSONObject: measured, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("aim-edge-\(dimension)-angle-comparison.json"))
        }
    }

}
