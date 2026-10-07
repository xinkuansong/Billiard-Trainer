import XCTest

/// Evidence collector. Geometry findings are data, not an early-aborting assertion.
final class DailyAdaptivityAuditUITests: XCTestCase {
    private var findings = [[String: String]]()
    private var manifest = [[String: String]]()
    private var output: URL!
    private let identifiers = [
        "dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu", "freeplay.stage", "table.scene",
        "dailyClearance.landscape", "dailyClearance.strike", "dailyClearance.undo", "dailyClearance.playback",
        "break.entry", "shotStage.spinEntry", "shotStage.powerBar", "shotStage.aimWheel", "shotStage.instrument",
        "spinPad.card", "spinPad.disc", "dailyClearance.observeTable", "shotCamera.firstPerson",
        "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.spinTransparencyMenu",
        "dailyClearance.spinTransparencyDone", "dailyClearance.spinTransparencySlider",
        "dailyClearance.rerackAfterBreak", "dailyClearance.confirmBreak", "dailyClearance.replay",
        "dailyClearance.rerack", "dailyClearance.changeGame", "v63.cameraDiagnostics",
        "dailyLayout.controlsProbe", "dailyLayout.spinGeometry", "dailyLayout.spaceProbe",
        "dailyLayout.limited", "dailyLayout.limitedBack"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["DAILY_ADAPTIVITY_DIR"] ?? env["TEST_RUNNER_DAILY_ADAPTIVITY_DIR"],
                                "Inject a fresh DAILY_ADAPTIVITY_DIR; never write into an old audit by default")
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = .landscapeRight
    }

    private func launch(_ fixture: String, game: String = "chineseEightBall", settled: Bool = true, extra: [String] = [], deepLink: Bool = true) -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: ["-dailyClearance.resetState",
            "-dailyClearance.preferredGame.v1", game, "-dailyClearance.fixture=\(fixture)",
            "-v63.cameraDiagnostics", "-dailyLayout.probe", "-trajectoryDetail", "0",
            "-dailyClearance.3DTrajectoryHidden", "NO", "-dailyClearance.spinDiscTransparency", "0.5"] + (settled ? ["-dailyClearance.fixtureSettled"] : []) + extra
            + (deepLink ? ["-deeplink.dailyClearance"] : ["-dailyClearance.resetHomeState"]))
    }
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func rect(_ r: CGRect) -> [String: Double] {
        ["x": Double(r.minX), "y": Double(r.minY), "width": Double(r.width), "height": Double(r.height)]
    }
    private func finding(_ state: String, _ kind: String, _ detail: String) {
        findings.append(["state": state, "kind": kind, "detail": detail])
    }
    private func capture(_ app: XCUIApplication, _ state: String) throws {
        Thread.sleep(forTimeInterval: 0.6)
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: output.appendingPathComponent(state + ".png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = state; attachment.lifetime = .keepAlways; add(attachment)
        // app.snapshot() is shallow on this runtime. Query matching descendants explicitly,
        // then take each element's own snapshot once; all geometry below uses cached values.
        let root = try app.snapshot()
        let measuredIDs = identifiers + ["paletteBall_cueBall"] + (1...15).map { "paletteBall__\($0)" }
        let query = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@ OR elementType == %ld", measuredIDs, XCUIElement.ElementType.button.rawValue))
        let snapshots = try query.allElementsBoundByIndex.map { try $0.snapshot() }
        let window = app.windows.firstMatch
        let bounds = window.exists ? try window.snapshot().frame : root.frame
        let byID = Dictionary(snapshots.filter { !$0.identifier.isEmpty }.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first })
        let evidenceIDs = ["freeplay.stage", "freeplay.cameraMode", "dailyClearance.strike"]
        let validEvidenceCount = evidenceIDs.filter { id in
            guard let e = byID[id] else { return false }
            return e.frame.width > 0 && e.frame.height > 0 && !e.frame.isNull && !e.frame.isInfinite
        }.count
        let baselineGeometryValid = validEvidenceCount >= 3
        if state.hasPrefix("core-"), state.hasSuffix("-baseline"), !baselineGeometryValid {
            finding(state, "invalidGeometryEvidence", "Only \(validEvidenceCount)/3 required stage/mode/strike frames measured")
            XCTFail("Baseline geometry evidence is invalid: stage/mode/strike require nonzero frames; got \(validEvidenceCount)/3")
        }
        var controls = [[String: Any]]()
        for e in snapshots where e.elementType == .button || measuredIDs.contains(e.identifier) {
            controls.append(["identifier": e.identifier, "exists": true, "label": e.label,
                "value": e.value.map { String(describing: $0) } ?? "", "frame": rect(e.frame),
                "isEnabled": e.isEnabled, "type": String(describing: e.elementType),
                "isHittable": "not available in snapshot; recorded for actual interactions separately"])
        }
        for id in measuredIDs where byID[id] == nil { controls.append(["identifier": id, "exists": false]) }
        let actionIDs = ["dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu", "dailyClearance.strike",
            "dailyClearance.undo", "dailyClearance.playback", "break.entry", "shotStage.spinEntry",
            "dailyClearance.observeTable", "shotCamera.firstPerson", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown"]
        for id in actionIDs {
            guard let e = byID[id] else { continue }
            if !bounds.insetBy(dx: -0.5, dy: -0.5).contains(e.frame) { finding(state, "outsideWindow", id) }
            if e.frame.width < 44 || e.frame.height < 44 { finding(state, "touchTargetBelow44pt", "\(id): \(e.frame)") }
        }
        let groups = [["dailyClearance.back", "freeplay.cameraMode", "freeplay.moreMenu"],
            ["dailyClearance.undo", "dailyClearance.playback", "break.entry", "shotStage.spinEntry"],
            ["dailyClearance.observeTable", "shotCamera.firstPerson", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown"],
            ["dailyClearance.rerackAfterBreak", "dailyClearance.confirmBreak"],
            ["paletteBall_cueBall"] + (1...15).map { "paletteBall__\($0)" }]
        for group in groups {
            for i in group.indices {
                for j in group.indices where j > i {
                    guard let a = byID[group[i]], let b = byID[group[j]] else { continue }
                    let overlap = a.frame.intersection(b.frame)
                    if !overlap.isNull && overlap.width > 0.5 && overlap.height > 0.5 {
                        finding(state, "adjacentActionOverlap", "\(group[i]) / \(group[j]): \(overlap)")
                    }
                }
            }
        }
        var screenFrames = [String: [String: Double]]()
        for id in ["freeplay.stage", "shotStage.aimWheel", "shotStage.powerBar", "dailyClearance.back"] {
            let item = element(app, id)
            if item.exists { screenFrames[id] = rect(item.frame) }
        }
        let record: [String: Any] = ["state": state, "timestamp": Date().timeIntervalSince1970,
            "appFrame": rect(root.frame), "windowFrame": rect(bounds), "controls": controls,
            "liveAppFrame": rect(app.frame), "liveWindowFrame": rect(window.frame), "screenFrames": screenFrames,
            "coordinateNote": "snapshot frames are logical layout; live frames include iPadOS window scaling",
            "geometryCollectorVersion": 2, "snapshotCount": snapshots.count,
            "baselineGeometryValid": baselineGeometryValid, "keyEvidenceCount": validEvidenceCount,
            "launchArguments": app.launchArguments, "findings": findings.filter { $0["state"] == state }]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(state + ".json"))
        manifest.append(["state": state, "screenshot": state + ".png", "measurements": state + ".json"])
        try writeSummary()
    }
    private func writeSummary() throws {
        // Distinct selectors may share one evidence directory in a serial run.
        // Preserve every selector's own index as well as each original state file.
        let manifestPrefix = name.contains("Extended") ? "extended"
            : name.contains("ManualRacked") ? "manual"
            : name.contains("ShortGame") ? "short-game" : "core"
        let data: [String: Any] = ["states": manifest, "findings": findings,
            "geometryPolicy": "Findings require review; XCTest success means collection/interactions succeeded, not layout acceptance."]
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("\(manifestPrefix)-manifest.json"))
    }
    @discardableResult
    private func tap(_ app: XCUIApplication, _ id: String, state: String) throws -> Bool {
        let button = app.buttons[id].firstMatch
        // SE reproduces an AX activation-point exception for this visible Menu.
        // Independently exercise the real screen center and require the menu content below.
        if id == "freeplay.moreMenu", button.waitForExistence(timeout: 8), button.isEnabled {
            let frame = button.frame
            let bounds = app.frame
            guard frame.width > 0, frame.height > 0, bounds.contains(CGPoint(x: frame.midX, y: frame.midY)) else {
                try capture(app, state + "-invalid-menu-frame")
                XCTFail("Menu center is outside the window: \(frame)")
                return false
            }
            let interaction: [String: Any] = ["state": state, "identifier": id, "frame": rect(frame),
                "method": "screen-center touch; AX activation-point defect retained in r1/r2 evidence"]
            try JSONSerialization.data(withJSONObject: interaction, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent(state + "-interaction-" + id + ".json"))
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX - bounds.minX, dy: frame.midY - bounds.minY)).tap()
            return true
        }
        guard button.waitForExistence(timeout: 8), button.isHittable, button.isEnabled else {
            finding(state, "interactionUnavailable", id)
            try capture(app, state + "-missing-" + id)
            XCTFail("Required action unavailable: \(id), state \(state)")
            return false
        }
        let interaction: [String: Any] = ["state": state, "identifier": id, "label": button.label,
            "value": button.value.map { String(describing: $0) } ?? "", "frame": rect(button.frame),
            "isHittable": button.isHittable, "isEnabled": button.isEnabled]
        try JSONSerialization.data(withJSONObject: interaction, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent(state + "-interaction-" + id + ".json"))
        button.tap(); return true
    }
    private func require(_ app: XCUIApplication, _ id: String, state: String) throws -> Bool {
        guard element(app, id).waitForExistence(timeout: 15) else {
            try capture(app, state + "-missing-" + id)
            XCTFail("Required state marker missing: \(id), state \(state)"); return false
        }
        return true
    }

    /// Small, same-fixture R1 before/after tour; no old full matrix is resumed.
    func testR1SpaceBaseline() throws {
        let app = launch("selection")
        defer { app.terminate() }
        XCTAssertTrue(element(app, "dailyClearance.landscape").waitForExistence(timeout: 20))
        for dimension in ["2D", "3D"] {
            if app.buttons["freeplay.cameraMode"].value as? String != dimension {
                XCTAssertTrue(try tap(app, "freeplay.cameraMode", state: dimension))
            }
            XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, dimension)
            try capture(app, "core-\(dimension)-baseline")
        }
    }

    func testR1SquareContainerAndCoreControls() throws {
        let app = launch("selection", extra: ["-dailyLayout.viewport=760x760"])
        defer { app.terminate() }
        XCTAssertTrue(element(app, "dailyClearance.landscape").waitForExistence(timeout: 20))
        for dimension in ["2D", "3D"] {
            if app.buttons["freeplay.cameraMode"].value as? String != dimension {
                XCTAssertTrue(try tap(app, "freeplay.cameraMode", state: dimension))
            }
            try capture(app, "core-\(dimension)-baseline")
            // iPadOS window scaling transforms live screen frames. Snapshot
            // geometry is the app's logical space; assert both contracts separately.
            let aimElement = element(app, "shotStage.aimWheel")
            let powerElement = element(app, "shotStage.powerBar")
            let aim = try aimElement.snapshot().frame
            let power = try powerElement.snapshot().frame
            XCTAssertEqual(aimElement.frame.height, powerElement.frame.height, accuracy: 1)
            XCTAssertEqual(aimElement.frame.minY, powerElement.frame.minY, accuracy: 1)
            XCTAssertEqual(aim.height, 144, accuracy: 1)
            XCTAssertEqual(power.height, 144, accuracy: 1)
            XCTAssertEqual(aim.minY, power.minY, accuracy: 1)
            XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: dimension + "-spin"))
            XCTAssertTrue(element(app, "spinPad.disc").waitForExistence(timeout: 5))
            try capture(app, "core-\(dimension)-spin")
            XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: dimension + "-spin-close"))
            if dimension == "3D" {
                XCTAssertTrue(try tap(app, "shotCamera.temporaryTopDown", state: "peek"))
                XCTAssertEqual(app.buttons["shotCamera.temporaryTopDown"].value as? String, "已选中")
                try capture(app, "core-3D-peek")
                XCTAssertTrue(try tap(app, "shotCamera.temporaryTopDown", state: "peek-return"))
            }
        }
    }

    func testR1SquareSideAlternative() throws {
        let app = launch("selection", extra: ["-dailyLayout.viewport=760x760", "-dailyLayout.forceSide"])
        defer { app.terminate() }
        XCTAssertTrue(element(app, "dailyClearance.landscape").waitForExistence(timeout: 20))
        for dimension in ["2D", "3D"] {
            if app.buttons["freeplay.cameraMode"].value as? String != dimension {
                XCTAssertTrue(try tap(app, "freeplay.cameraMode", state: dimension))
            }
            try capture(app, "core-\(dimension)-baseline")
        }
    }

    func testR1LimitedContainerCanReturn() throws {
        try verifyLimitedContainer("600x300")
    }

    func testR1NarrowContainerCanReturn() throws {
        try verifyLimitedContainer("320x760")
    }

    private func verifyLimitedContainer(_ size: String) throws {
        // A deeplink installs FreePlayView as NavigationStack's root; dismiss
        // cannot pop that test-only root. Exercise the production home route.
        XCUIDevice.shared.orientation = .portrait
        let app = launch("selection", extra: ["-dailyLayout.viewport=\(size)"], deepLink: false)
        defer { app.terminate() }
        app.switchTab(.training)
        let home = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        home.tap()
        XCTAssertTrue(element(app, "dailyLayout.limited").waitForExistence(timeout: 20))
        try capture(app, "limited-\(size)")
        XCTAssertFalse(app.buttons["dailyClearance.strike"].isHittable)
        XCTAssertTrue(try tap(app, "dailyLayout.limitedBack", state: "limited-return"))
        let dismissed = expectation(for: NSPredicate(format: "exists == false"),
            evaluatedWith: element(app, "dailyClearance.landscape"))
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        try capture(app, "limited-\(size)-returned-home")
    }

    func testCoreStateTour() throws {
        let app = launch("selection")
        defer { app.terminate() }
        guard try require(app, "dailyClearance.landscape", state: "core") else { return }
        for dimension in ["2D", "3D"] {
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension {
                guard try tap(app, "freeplay.cameraMode", state: dimension) else { continue }
            }
            if mode.value as? String != dimension { XCTFail("Expected \(dimension), got \(String(describing: mode.value))") }
            try capture(app, "core-\(dimension)-baseline")
            if try tap(app, "shotStage.spinEntry", state: dimension + "-spin") {
                _ = try require(app, "spinPad.disc", state: dimension + "-spin")
                try capture(app, "core-\(dimension)-spin")
                _ = try tap(app, "shotStage.spinEntry", state: dimension + "-spin-close")
            }
            if try tap(app, "freeplay.moreMenu", state: dimension + "-more") {
                _ = try require(app, "dailyClearance.spinTransparencyMenu", state: dimension + "-more")
                try capture(app, "core-\(dimension)-more")
                if try tap(app, "dailyClearance.spinTransparencyMenu", state: dimension + "-transparency") {
                    _ = try require(app, "dailyClearance.spinTransparencySlider", state: dimension + "-transparency")
                    try capture(app, "core-\(dimension)-transparency")
                    _ = try tap(app, "dailyClearance.spinTransparencyDone", state: dimension + "-transparency-close")
                    if element(app, "spinPad.disc").exists { _ = try tap(app, "shotStage.spinEntry", state: dimension + "-spin-close") }
                }
            }
            if dimension == "3D", try tap(app, "shotCamera.temporaryTopDown", state: "temporary-topdown") {
                let peek = app.buttons["shotCamera.temporaryTopDown"]
                let selected = expectation(for: NSPredicate(format: "value == %@", "已选中"), evaluatedWith: peek)
                XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                    "Merged camera tap must activate temporary top-down before labeling evidence")
                try capture(app, "core-3D-temporary-topdown")
                _ = try tap(app, "shotCamera.temporaryTopDown", state: "temporary-topdown-return")
                try capture(app, "core-3D-temporary-return")
            }
            if try tap(app, "break.entry", state: dimension + "-restart") {
                _ = try require(app, "dailyClearance.rerackAfterBreak", state: dimension + "-restart")
                try capture(app, "core-\(dimension)-restart-decision")
                _ = try tap(app, "dailyClearance.confirmBreak", state: dimension + "-continue")
            }
        }
        _ = try tap(app, "freeplay.cameraMode", state: "roundtrip")
        try capture(app, "core-2D-roundtrip")
    }

    /// Explicit selector for additional fixtures. No implicit skip or conditionally green empty test.
    func testExtendedStateTour() throws {
        let cases = [("manual", "chineseEightBall", "dailyClearance.strike"),
            ("completed", "chineseEightBall", "dailyClearance.replay"),
            ("failed", "chineseEightBall", "dailyClearance.rerack"),
            ("selectionStripe", "chineseEightBall", "paletteBall__9"),
            ("selectionNine", "nineBall", "paletteBall__1"),
            ("progress", "sixBall", "paletteBall__1"),
            ("progress", "fiveBall", "paletteBall__1"),
            ("progress", "fourBall", "paletteBall__1")]
        for (fixture, game, marker) in cases {
            let app = launch(fixture, game: game, settled: fixture != "manual")
            let prefix = "extended-\(game)-\(fixture)"
            if try require(app, marker, state: prefix) {
                try capture(app, prefix + "-2D")
                if try tap(app, "freeplay.cameraMode", state: prefix + "-3D") { try capture(app, prefix + "-3D") }
            }
            app.terminate()
        }
    }

    /// Low-ball-count modes use the production legal progress fixture, never selectionNine.
    func testShortGamePaletteTour() throws {
        for game in ["sixBall", "fiveBall", "fourBall"] {
            let app = launch("progress", game: game)
            let prefix = "shortgame-\(game)-progress"
            guard try require(app, "freeplay.stage", state: prefix),
                  try require(app, "paletteBall__1", state: prefix) else {
                app.terminate()
                continue
            }
            for dimension in ["2D", "3D"] {
                let mode = app.buttons["freeplay.cameraMode"]
                guard mode.waitForExistence(timeout: 8) else {
                    XCTFail("Short-game camera mode missing: \(game)")
                    try capture(app, prefix + "-" + dimension + "-missing-mode")
                    continue
                }
                if mode.value as? String != dimension {
                    guard try tap(app, "freeplay.cameraMode", state: prefix + "-" + dimension) else { continue }
                }
                let expectedMode = expectation(for: NSPredicate(format: "value == %@", dimension), evaluatedWith: mode)
                let switched = XCTWaiter.wait(for: [expectedMode], timeout: 8)
                XCTAssertEqual(switched, .completed, "Short-game mode must be \(dimension): \(game)")
                try capture(app, prefix + "-" + dimension)
            }
            app.terminate()
        }
    }


    /// Validate the racked break through independent AX state: no played visit, all rack
    /// balls disabled for selection, and the actual break-speed default (8 m/s).
    func testV4Foundation2DBaseline() throws {
        let portrait = ProcessInfo.processInfo.environment["V4_PORTRAIT"] == "1"
        XCUIDevice.shared.orientation = portrait ? .portrait : .landscapeRight
        let app = launch("manual", settled: false)
        defer { app.terminate() }
        XCTAssertTrue(element(app, "freeplay.stage").waitForExistence(timeout: 20))
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" {
            XCTAssertTrue(try tap(app,"freeplay.cameraMode",state:"v4-2D"))
        }
        try capture(app,"v4-2D-baseline")
        let aim = try element(app,"shotStage.aimWheel").snapshot().frame
        let power = try element(app,"shotStage.powerBar").snapshot().frame
        XCTAssertEqual(aim.height,power.height,accuracy:0.5)
        XCTAssertEqual(aim.minY,power.minY,accuracy:0.5)
        XCTAssertTrue(abs(aim.height-120)<1 || abs(aim.height-144)<1)
        let strike = try app.buttons["dailyClearance.strike"].snapshot().frame
        XCTAssertEqual(strike.width,60,accuracy:1)
        XCTAssertEqual(strike.height,60,accuracy:1)
        let window = try app.windows.firstMatch.snapshot().frame
        XCTAssertEqual(window.height > window.width,portrait,"Actual App window direction must match the requested layout")
        for id in ["break.entry","shotStage.spinEntry","dailyClearance.strike","dailyClearance.undo","dailyClearance.playback"] {
            let frame = try app.buttons[id].snapshot().frame
            XCTAssertTrue(window.insetBy(dx:-1,dy:-1).contains(frame),"\(id): \(frame) outside \(window)")
        }
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String,"开球准备，不可选")
        for key in ["paletteBall_cueBall"] + (1...15).map({ "paletteBall__\($0)" }) {
            let ball = try app.buttons[key].snapshot().frame
            for id in ["break.entry", "shotStage.spinEntry"] {
                let control = try app.buttons[id].snapshot().frame
                XCTAssertFalse(ball.intersects(control), "Palette must leave side controls clear: \(key)/\(id)")
            }
        }
        XCTAssertTrue(try tap(app,"shotStage.spinEntry",state:"v4-spin-open"))
        XCTAssertTrue(element(app,"spinPad.disc").waitForExistence(timeout:5))
        try capture(app,"v4-2D-spin")
        XCTAssertTrue(try tap(app,"shotStage.spinEntry",state:"v4-spin-close"))
    }

    func testV4SharedHUDAndCameraContinuity() throws { try verifyV4SharedHUD(portrait: false) }
    func testV4PortraitSharedHUDAndCameraContinuity() throws { try verifyV4SharedHUD(portrait: true) }

    private func verifyV4SharedHUD(portrait: Bool) throws {
        if portrait { XCUIDevice.shared.orientation = .portrait }
        let app = launch("selection", extra: ["-3dDrag.probe"])
        defer { app.terminate() }
        XCTAssertTrue(element(app,"freeplay.stage").waitForExistence(timeout:20))
        let mode = app.buttons["freeplay.cameraMode"]
        if mode.value as? String != "2D" { mode.tap() }
        func renderer() throws -> String {
            let raw = try XCTUnwrap(element(app,"table.scene").value as? String)
            let data = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(raw.utf8)) as? [String:Any])
            return try XCTUnwrap(data["rendererID"] as? String)
        }
        let identity = try renderer()
        let ids = ["freeplay.stage","break.entry","shotStage.spinEntry","shotStage.powerBar","shotStage.aimWheel","dailyClearance.strike","paletteBall__1"]
        let before = try ids.map { try element(app,$0).snapshot().frame }
        let state = element(app,"dailyClearance.landscape").value as? String
        let power = element(app,"shotStage.powerBar").value as? String
        try capture(app,"v4-shared-2D")
        mode.tap()
        XCTAssertEqual(mode.value as? String,"3D")
        for (id, frame) in zip(ids,before) {
            let after = try element(app,id).snapshot().frame
            XCTAssertEqual(after.minX,frame.minX,accuracy:0.5,id)
            XCTAssertEqual(after.minY,frame.minY,accuracy:0.5,id)
            XCTAssertEqual(after.width,frame.width,accuracy:0.5,id)
            XCTAssertEqual(after.height,frame.height,accuracy:0.5,id)
        }
        XCTAssertEqual(try renderer(),identity)
        try capture(app,"v4-shared-3D")
        let primaryCamera = app.buttons["dailyClearance.observeTable"].exists ? "dailyClearance.observeTable" : "shotCamera.firstPerson"
        for id in [primaryCamera,"shotCamera.thirdPerson","shotCamera.temporaryTopDown"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.exists,id)
            XCTAssertTrue(button.isHittable,id)
            let frame = try button.snapshot().frame
            XCTAssertTrue(try app.windows.firstMatch.snapshot().frame.contains(frame),id)
            XCTAssertGreaterThanOrEqual(frame.width,44)
            XCTAssertGreaterThanOrEqual(frame.height,44)
            if id == "shotCamera.temporaryTopDown", primaryCamera == "shotCamera.firstPerson" { button.press(forDuration:0.5) }
            else if id == "shotCamera.temporaryTopDown" { button.tap(); button.tap() }
            else { button.tap() }
        }
        try capture(app,"v4-shared-camera")
        XCTAssertEqual(try renderer(),identity)
        mode.tap()
        XCTAssertEqual(element(app,"shotStage.powerBar").value as? String,power)
        XCTAssertEqual(element(app,"dailyClearance.landscape").value as? String,state)
        XCTAssertEqual(try renderer(),identity)
        try capture(app,"v4-shared-return")
    }

    func testV4PadRotationPreservesRack() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch("manual",settled:false)
        defer { app.terminate() }
        XCTAssertTrue(element(app,"freeplay.stage").waitForExistence(timeout:20))
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
        for (name, orientation) in [("portrait",UIDeviceOrientation.portrait),("landscape",.landscapeRight),("portrait-return",.portrait)] {
            XCUIDevice.shared.orientation = orientation
            let wantsPortrait = orientation == .portrait
            let ready = expectation(for: NSPredicate { _,_ in
                let frame = app.windows.firstMatch.frame
                return (frame.height > frame.width) == wantsPortrait
            }, evaluatedWith:app)
            XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:10),.completed)
            try capture(app,"v4-rotation-"+name)
            XCTAssertEqual(Double(element(app,"shotStage.powerBar").value as? String ?? ""),8)
            XCTAssertTrue((element(app,"dailyClearance.landscape").value as? String ?? "").contains("0杆"))
            XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String,"2D")
        }
    }

    func testV4NarrowTwoRowsAndInnerSpinCard() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch("manual", settled: false, extra: ["-dailyLayout.viewport=420x800"])
        defer { app.terminate() }
        XCTAssertTrue(element(app, "freeplay.stage").waitForExistence(timeout: 20))
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" {
            XCTAssertTrue(try tap(app, "freeplay.cameraMode", state: "narrow-2D"))
        }
        XCTAssertTrue(element(app, "dailyClearance.twoRowPalette").waitForExistence(timeout: 5))
        let window = try app.windows.firstMatch.snapshot().frame
        var frames: [CGRect] = []
        for number in 1...15 {
            let ball = app.buttons["paletteBall__\(number)"]
            XCTAssertTrue(ball.exists)
            let f = try ball.snapshot().frame
            XCTAssertTrue(window.contains(f))
            frames.append(f)
        }
        for i in frames.indices { for j in frames.indices where j > i {
            XCTAssertFalse(frames[i].intersects(frames[j]), "Distinct ball hit slots must not overlap")
        }}
        try capture(app, "v4-narrow-two-rows")
        XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: "narrow-spin-open"))
        XCTAssertTrue(element(app, "spinPad.card").waitForExistence(timeout: 5))
        let card = try element(app, "spinPad.card").snapshot().frame
        XCTAssertLessThan(card.width, 264)
        XCTAssertGreaterThan(card.width, 210)
        XCTAssertFalse(card.intersects(try app.buttons["dailyClearance.strike"].snapshot().frame))
        let rawGeometry = element(app, "dailyLayout.spinGeometry").value as? String ?? ""
        func geometry(_ key: String) throws -> Double {
            try XCTUnwrap(rawGeometry.split(separator: " ").first { $0.hasPrefix(key + "=") }
                .flatMap { Double($0.dropFirst(key.count + 1)) })
        }
        let inner = try CGRect(x: geometry("innerX"), y: geometry("innerY"),
                               width: geometry("innerWidth"), height: geometry("innerHeight"))
        XCTAssertTrue(inner.insetBy(dx: -0.5, dy: -0.5).contains(card), "Complete card must stay inside the inner rails")
        for label in ["高杆增加 1%", "低杆增加 1%", "左塞增加 1%", "右塞增加 1%"] {
            let key = app.buttons[label]
            XCTAssertTrue(key.exists)
            let f = try key.snapshot().frame
            XCTAssertGreaterThanOrEqual(f.width, 44)
            XCTAssertGreaterThanOrEqual(f.height, 44)
            XCTAssertTrue(key.isHittable)
            key.tap()
        }
        let reset = app.buttons["回中"]
        XCTAssertTrue(reset.isHittable); reset.tap()
        let disc = element(app, "spinPad.disc")
        let center = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 70, dy: -70)),
                     withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertNotEqual(disc.value as? String, "中心球")
        reset.tap()
        try capture(app, "v4-narrow-spin")
        XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: "narrow-spin-close"))
        XCTAssertFalse(element(app, "spinPad.card").exists)
        XCTAssertTrue((element(app, "dailyClearance.landscape").value as? String ?? "").contains("0杆"))
    }

    /// Exercise both rows and the independent black-eight slot through real taps.
    func testV4NarrowPaletteSelection() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch("selection", extra: ["-dailyLayout.viewport=420x800"])
        defer { app.terminate() }
        XCTAssertTrue(element(app, "freeplay.stage").waitForExistence(timeout: 20))
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
        XCTAssertTrue(element(app, "dailyClearance.twoRowPalette").waitForExistence(timeout: 5))
        XCTAssertTrue(try tap(app, "paletteBall__1", state: "narrow-first"))
        let status = element(app, "dailyClearance.landscape")
        let selected = expectation(for: NSPredicate { _, _ in
            (status.value as? String ?? "").contains("目标_1")
        }, evaluatedWith: app)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        for number in [8, 15] {
            let ball = app.buttons["paletteBall__\(number)"]
            XCTAssertEqual(ball.value as? String, number == 8 ? "在桌上" : "已进袋")
            XCTAssertTrue(try tap(app, "paletteBall__\(number)", state: "narrow-slot-\(number)"))
            let notice = number == 8
                ? app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "再打黑八")).firstMatch
                : app.staticTexts["这颗球已进袋"]
            XCTAssertTrue(notice.waitForExistence(timeout: 3))
            XCTAssertTrue((status.value as? String ?? "").contains("目标_1"))
        }
        try capture(app, "v4-narrow-selected")
    }

    func testV4FoundationRealControls() throws {
        let app = launch("selection")
        defer { app.terminate() }
        XCTAssertTrue(element(app, "freeplay.stage").waitForExistence(timeout: 20))
        if app.buttons["freeplay.cameraMode"].value as? String != "2D" { app.buttons["freeplay.cameraMode"].tap() }
        func field(_ key: String) -> Double? {
            let raw = element(app, "dailyLayout.controlsProbe").value as? String ?? ""
            return raw.split(separator: " ").first { $0.hasPrefix(key + "=") }
                .flatMap { Double($0.dropFirst(key.count + 1)) }
        }
        func ready(_ id: String, timeout: Double = 35) {
            let button = app.buttons[id]
            let e = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
            XCTAssertEqual(XCTWaiter.wait(for: [e], timeout: timeout), .completed)
        }
        ready("dailyClearance.strike")
        let count = try XCTUnwrap(field("dailyShotCount"))
        XCTAssertTrue(try tap(app, "dailyClearance.strike", state: "v4-shot"))
        ready("dailyClearance.undo")
        XCTAssertEqual(field("dailyShotCount"), count + 1)
        XCTAssertTrue(try tap(app, "dailyClearance.playback", state: "v4-replay"))
        ready("dailyClearance.playback")
        XCTAssertEqual(field("dailyShotCount"), count + 1)
        XCTAssertTrue(try tap(app, "dailyClearance.undo", state: "v4-undo"))
        ready("dailyClearance.strike")
        XCTAssertEqual(field("dailyShotCount"), count)
        let first = app.buttons["paletteBall__1"]
        XCTAssertTrue(first.isHittable); first.tap()
        XCTAssertTrue(try tap(app, "paletteBall__15", state: "v4-last-slot"))
        XCTAssertTrue(app.staticTexts["这颗球已进袋"].waitForExistence(timeout: 3))
        let aimBefore = try XCTUnwrap(field("aimX"))
        let aimZBefore = try XCTUnwrap(field("aimZ"))
        let wheel = element(app, "shotStage.aimWheel")
        let center = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 0, dy: -24)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertGreaterThan(hypot(try XCTUnwrap(field("aimX")) - aimBefore,
                                  try XCTUnwrap(field("aimZ")) - aimZBefore), 0.0001)
        let power = element(app, "shotStage.powerBar")
        let speed = try XCTUnwrap(field("velocity"))
        let p = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        p.press(forDuration: 0.1, thenDragTo: p.withOffset(CGVector(dx: 0, dy: -24)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertNotEqual(field("velocity"), speed)
        XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: "v4-drag-spin-open"))
        let disc = element(app, "spinPad.disc")
        XCTAssertTrue(disc.waitForExistence(timeout: 5))
        let d = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // The existing drag contract first clears the finger by 52pt. Move
        // beyond that gate while remaining inside the complete card.
        d.press(forDuration: 0.1, thenDragTo: d.withOffset(CGVector(dx: 70, dy: -70)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertGreaterThan(hypot(try XCTUnwrap(field("spinX")), try XCTUnwrap(field("spinY"))), 0.1)
        XCTAssertEqual(field("dailyShotCount"), count, "Drag/release must not fire")
        try capture(app, "v4-controls-spin-drag")
        app.buttons["回中"].tap()
        XCTAssertEqual(field("spinX"), 0); XCTAssertEqual(field("spinY"), 0)
        XCTAssertTrue(try tap(app, "shotStage.spinEntry", state: "v4-drag-spin-close"))
        try capture(app, "v4-controls-restored")
    }

    func testManualRackedTour() throws {
        let app = launch("manual", settled: false)
        defer { app.terminate() }
        guard try require(app, "freeplay.stage", state: "manual-racked"),
              try require(app, "dailyClearance.landscape", state: "manual-racked") else { return }
        for dimension in ["2D", "3D"] {
            let mode = app.buttons["freeplay.cameraMode"]
            if mode.value as? String != dimension {
                guard try tap(app, "freeplay.cameraMode", state: "manual-racked-" + dimension) else { continue }
            }
            let selected = expectation(for: NSPredicate(format: "value == %@", dimension), evaluatedWith: mode)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 8), .completed)
            let hud = element(app, "dailyClearance.landscape")
            let state = hud.value as? String ?? ""
            XCTAssertTrue(state.components(separatedBy: "，").contains("0杆"), "Manual rack must have no played visits: \(state)")
            XCTAssertTrue(state.contains("剩余 0 球"), "Manual draft has no delivered board yet: \(state)")
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertTrue(strike.exists && strike.isEnabled, "Racked break must be ready, not playing or computing")
            let power = element(app, "shotStage.powerBar")
            XCTAssertTrue(power.exists)
            XCTAssertEqual(Double(power.value as? String ?? ""), 8.0,
                "Break runner default velocity must be active; ordinary settled play is not a rack")
            for number in 1...15 {
                let ball = app.buttons["paletteBall__\(number)"]
                XCTAssertTrue(ball.exists, "Full Chinese-eight-ball rack palette must be present")
                XCTAssertFalse(ball.isEnabled, "Break mode disables target-ball selection: \(number)")
            }
            XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
            XCTAssertFalse(app.buttons["dailyClearance.rerackAfterBreak"].exists)
            try capture(app, "manual-racked-" + dimension)
        }
    }

}
