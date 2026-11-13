import XCTest

/// Normal-entry rollout checks plus explicit reference/research selectors.
/// Pixel equality is tested separately with frozen render targets.
final class ClothSupportPageResearchUITests: XCTestCase {
    private enum Recipe: String, CaseIterable {
        case reference, plain, guarded
        var arguments: [String] {
            switch self {
            case .reference: return ["-rendering.referenceCloth"]
            case .plain: return ["-daily3D.safeClothSupport"]
            case .guarded: return ["-daily3D.guardClothSupport"]
            }
        }
        var request: String {
            switch self {
            case .reference: return "off"
            case .plain: return "plain-safe"
            case .guarded: return "guard-combo"
            }
        }
        var variant: String {
            switch self {
            case .reference: return "off"
            case .plain: return "height-safe-below-r3-signbit-finite-rig-20261113"
            case .guarded: return "legacy-cone-plus-safe-hoisted-finite-domain-guard-r1-20261113"
            }
        }
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
    }

    private func launch(style: String, extra: [String], fromHome: Bool = false) -> XCUIApplication {
        if fromHome { XCUIDevice.shared.orientation = .portrait }
        let route = fromHome ? ["-dailyClearance.resetHomeState", "-v50.inMemoryStore"] : ["-deeplink.dailyClearance"]
        let app = XCUIApplication.launchClean(extraArgs: route + [
            "-dailyClearance.resetState", "-dailyClearance.fixture=selection",
            "-dailyClearance.fixtureSettled", "-forcePremium", "-3dDrag.probe",
            "-renderProfileProbe", "-roomStyle.v1", style] + extra)
        if fromHome {
            app.switchTab(.training)
            let entry = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(entry.waitForExistence(timeout: 20))
            XCTAssertTrue(entry.isHittable)
            entry.tap()
        }
        return app
    }

    private func probe(_ app: XCUIApplication) throws -> [String: Any] {
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        let raw = try XCTUnwrap(table.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }

    private func settle(_ app: XCUIApplication) {
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            (try? self.probe(app)["rendererActive"] as? Bool) == false
        }, evaluatedWith: table)], timeout: 20), .completed)
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let state = XCTAttachment(data: try JSONSerialization.data(withJSONObject: probe(app),
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        state.name = name + "-state"
        state.lifetime = .keepAlways
        add(state)
    }

    private func selectMode(_ app: XCUIApplication, _ dimension: String) throws {
        let menu = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        if mode.value as? String != dimension { mode.tap() }
        XCTAssertEqual(mode.value as? String, dimension)
        app.buttons["关闭菜单"].tap()
        settle(app)
        XCTAssertEqual(try probe(app)["cameraMode"] as? String, dimension)
    }

    private func assertRecipe(_ app: XCUIApplication, recipe: Recipe, effective: Bool) throws {
        let state = try XCTUnwrap(try probe(app)["clothSupport"] as? [String: Any])
        XCTAssertEqual(state["requested"] as? Bool, recipe != .reference)
        XCTAssertEqual(state["requestedVariant"] as? String, recipe.request)
        XCTAssertEqual(state["effective"] as? Bool, effective, "Actual installation: \(state)")
        if effective {
            XCTAssertEqual(state["variant"] as? String, recipe.variant)
            XCTAssertEqual(state["capacity"] as? Int, 16)
        }
    }

    func testDefaultRecipeOnDailyAndOrdinaryFreePlay() throws {
        for daily in [true, false] {
            let app = daily ? launch(style: "tournament", extra: [], fromHome: true)
                : XCUIApplication.launchClean(extraArgs: ["-deeplink.freePlay", "-forcePremium",
                    "-v63.freePlayScratch", "-3dDrag.probe", "-renderProfileProbe",
                    "-roomStyle.v1", "tournament"])
            defer { app.terminate() }
            settle(app)
            let renderer = try XCTUnwrap(try probe(app)["rendererID"] as? String)
            for dimension in ["2D", "3D"] {
                try selectMode(app, dimension)
                try assertRecipe(app, recipe: .guarded, effective: true)
                XCTAssertEqual(try probe(app)["rendererID"] as? String, renderer)
                try capture(app, "cloth-default-\(daily ? "daily" : "freeplay")-\(dimension)")
            }
        }
    }

    func testOriginalAndSafeRecipeAcrossRoomStylesAndProjectionLifecycle() throws {
        for style in ["tournament", "walnut", "eastern"] {
            for recipe in Recipe.allCases {
                let name = "cloth-page-\(style)-\(recipe.rawValue)"
                let app = launch(style: style, extra: recipe.arguments, fromHome: true)
                defer { app.terminate() }
                settle(app)
                try assertRecipe(app, recipe: recipe, effective: recipe != .reference)
                let initial = try probe(app)
                let renderer = try XCTUnwrap(initial["rendererID"] as? String)
                let balls = try XCTUnwrap(initial["balls"] as? [[String: Any]])
                for dimension in ["2D", "3D"] {
                    try selectMode(app, dimension)
                    try assertRecipe(app, recipe: recipe, effective: recipe != .reference)
                    try capture(app, name + "-" + dimension)
                }
                let temporary = app.buttons["shotCamera.temporaryTopDown"]
                XCTAssertTrue(temporary.waitForExistence(timeout: 10))
                temporary.tap()
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "已选中"),
                    evaluatedWith: temporary)], timeout: 5), .completed)
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
                    (try? self.probe(app)["temporaryTopDownActive"] as? Bool) == true
                        && (try? self.probe(app)["diagramSurface"] as? String) == "temporaryTopDown"
                }, evaluatedWith: temporary)], timeout: 10), .completed)
                try capture(app, name + "-temporary2D")
                temporary.tap()
                settle(app)
                XCTAssertEqual(temporary.value as? String, "未选中")
                XCUIDevice.shared.press(.home)
                app.activate()
                settle(app)
                try assertRecipe(app, recipe: recipe, effective: recipe != .reference)
                let restored = try probe(app)
                XCTAssertEqual(restored["rendererID"] as? String, renderer)
                let after = try XCTUnwrap(restored["balls"] as? [[String: Any]])
                XCTAssertEqual(after.count, balls.count)
                for (before, current) in zip(balls, after) {
                    XCTAssertEqual(before["key"] as? String, current["key"] as? String)
                    XCTAssertEqual(before["world"] as? [Double], current["world"] as? [Double])
                }
                try capture(app, name + "-restored3D")
                app.buttons["dailyClearance.back"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                    .waitForNonExistence(timeout: 10))
                let entry = app.buttons["trainingHome.dailyClearance"]
                XCTAssertTrue(entry.waitForExistence(timeout: 10))
                XCTAssertTrue(entry.isHittable)
            }
        }
    }

    func testBalancedRequestFallsBackToItsOriginalRecipe() throws {
        for recipe in [Recipe.plain, .guarded] {
            let app = launch(style: "tournament", extra: recipe.arguments + ["-balancedRendering"])
            defer { app.terminate() }
            settle(app)
            try assertRecipe(app, recipe: recipe, effective: false)
            let cloth = try XCTUnwrap(try probe(app)["clothSupport"] as? [String: Any])
            XCTAssertEqual(cloth["fallbackReason"] as? String, "unsupported-sampling")
            try capture(app, "cloth-page-balanced-\(recipe.rawValue)-fallback")
        }
    }

    func testConflictingSupportFlagsFallBackWithExplicitAttribution() throws {
        let app = launch(style: "tournament", extra: Recipe.plain.arguments + Recipe.guarded.arguments)
        defer { app.terminate() }
        settle(app)
        let cloth = try XCTUnwrap(try probe(app)["clothSupport"] as? [String: Any])
        XCTAssertEqual(cloth["requested"] as? Bool, true)
        XCTAssertEqual(cloth["effective"] as? Bool, false)
        XCTAssertEqual(cloth["requestedVariant"] as? String, "conflict")
        XCTAssertEqual(cloth["variant"] as? String, "off")
        XCTAssertEqual(cloth["fallbackReason"] as? String, "conflicting-support-flags")
        try capture(app, "cloth-page-conflicting-support-fallback")
    }

    func testSafeRecipeDirectionInputAndRealShotReturnToIdle() throws {
        try exerciseDirectionAndShot(recipe: .plain)
    }

    func testGuardedRecipeDirectionInputAndRealShotReturnToIdle() throws {
        try exerciseDirectionAndShot(recipe: .guarded)
    }

    private func exerciseDirectionAndShot(recipe: Recipe) throws {
        let app = launch(style: "tournament", extra: recipe.arguments + ["-daily3D.diagnostics"])
        defer { app.terminate() }
        settle(app)
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        func strokes() -> String {
            (hud.value as? String ?? "").components(separatedBy: "，").first { $0.hasSuffix("杆") } ?? "missing"
        }
        let initialStrokes = strokes()
        XCTAssertNotEqual(initialStrokes, "missing")
        for dimension in ["2D", "3D"] {
            try selectMode(app, dimension)
            try assertRecipe(app, recipe: recipe, effective: true)
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: 10))
            XCTAssertTrue(wheel.isEnabled && wheel.isHittable)
            let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 24)),
                withVelocity: .slow, thenHoldForDuration: 0.1)
            settle(app)
            XCTAssertEqual(strokes(), initialStrokes, "Direction input cannot fire a shot")
            try capture(app, "cloth-page-\(recipe.rawValue)-aim-" + dimension)
        }
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 20), .completed)
        strike.tap()
        let playback = app.buttons["dailyClearance.playback"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: playback)], timeout: 60), .completed)
        settle(app)
        XCTAssertNotEqual(strokes(), initialStrokes)
        XCTAssertEqual(try probe(app)["cameraMode"] as? String, "3D")
        try assertRecipe(app, recipe: recipe, effective: true)
        try capture(app, "cloth-page-\(recipe.rawValue)-real-shot-idle")
    }

    // Explicit research selectors only. Inject TEST_RUNNER_CLOTH_NATIVE_PAGE_RESEARCH=1.
    // Default suites skip these; each selector launches one arm, never both renderers.
    // The runtime gate describes the test runner and must be checked in the first
    // native run. It is not inferred from the destination name or simulator timing.
    func testNativeMacReferenceFullPageTrace() throws {
        try exerciseNativeMacTrace(recipe: .reference)
    }

    func testNativeMacGuardedFullPageTrace() throws {
        try exerciseNativeMacTrace(recipe: .guarded)
    }

    private struct NativeTraceContext {
        let runID: String
        let recipe: Recipe
        let appPID: Int
        var markers: [[String: Any]] = []
    }

    private func exerciseNativeMacTrace(recipe: Recipe) throws {
        let environment = ProcessInfo.processInfo.environment
        let optedIn = environment["CLOTH_NATIVE_PAGE_RESEARCH"]
            ?? environment["TEST_RUNNER_CLOTH_NATIVE_PAGE_RESEARCH"]
        try XCTSkipUnless(optedIn == "1", "Explicit native full-page research selector; not a default performance test")
        #if targetEnvironment(simulator)
        throw XCTSkip("Native full-page trace cannot run in Simulator")
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.isiOSAppOnMac,
                         "Runner must prove isiOSAppOnMac; verify native runner semantics before interpreting evidence")
        #endif
        executionTimeAllowance = 300
        let app = launch(style: "tournament", extra: recipe.arguments + [
            "-daily3D.diagnostics", "-dailyLayout.probe", "-freeLayout.ephemeral",
            "-renderFrameRate", "60", "-clothColor.v1", "green", "-tableStyle.v1", "charcoal"
        ], fromHome: true)
        defer { app.terminate() }
        XCTAssertEqual(app.state, .runningForeground)
        settle(app)
        try assertRecipe(app, recipe: recipe, effective: recipe != .reference)
        try selectMode(app, "2D")
        let initial = try probe(app)
        let ballKeys = try XCTUnwrap(initial["balls"] as? [[String: Any]]).compactMap { $0["key"] as? String }.sorted()
        XCTAssertEqual(ballKeys, ["_1", "_2", "_8", "_9", "cueBall"], "Use the same real selection fixture for both arms")
        var context = NativeTraceContext(runID: UUID().uuidString, recipe: recipe,
                                         appPID: try nativeAppPID(initial))
        defer {
            do {
                let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: context.markers,
                    options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
                attachment.name = "cloth-native-\(recipe.rawValue)-markers"
                attachment.lifetime = .keepAlways
                add(attachment)
            } catch { XCTFail("Could not preserve native trace markers: \(error)") }
        }
        try nativeTraceSnapshot(app, stage: "prepared-2D", context: context)
        // This idle window lets the external sampler attach to the actual App PID.
        // Markers use the runner's monotonic/wall clock; App signposts remain the
        // authority for rendering/shot intervals. No duration here is an FPS result.
        try nativeTraceMarker("READY", boundary: "begin", context: &context, seconds: 20)
        Thread.sleep(forTimeInterval: 20)
        try nativeTraceMarker("READY", boundary: "end", context: &context, seconds: 20)
        try nativeTraceStage(app, stage: "2D-idle", context: &context) {}
        try nativeTraceStage(app, stage: "enter-3D", context: &context) {
            try self.selectMode(app, "3D")
        }
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        func strokes() -> String {
            (hud.value as? String ?? "").components(separatedBy: "，").first { $0.hasSuffix("杆") } ?? "missing"
        }
        let initialStrokes = strokes()
        XCTAssertNotEqual(initialStrokes, "missing")
        let aimBefore = try nativeAim(app)
        try nativeTraceStage(app, stage: "aim-wheel", context: &context) {
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: 5))
            XCTAssertTrue(wheel.isEnabled && wheel.isHittable)
            let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // Fixed displacement and velocity in both arms, not a time-dependent
            // repeat loop whose input count changes with rendering performance.
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 24)),
                        withVelocity: XCUIGestureVelocity(rawValue: 5), thenHoldForDuration: 0.1)
        }
        XCTAssertEqual(strokes(), initialStrokes, "Aiming must not fire a shot")
        XCTAssertNotEqual(try nativeAim(app), aimBefore, "The actual player aim must change, not just receive a gesture")
        for id in ["shotCamera.firstPerson", "shotCamera.thirdPerson", "dailyClearance.observeTable"] {
            try nativeTraceStage(app, stage: id, context: &context) {
                let button = app.buttons[id]
                XCTAssertTrue(button.waitForExistence(timeout: 5))
                XCTAssertTrue(button.isEnabled && button.isHittable)
                button.tap()
                XCTAssertEqual(XCTWaiter.wait(for: [self.expectation(for:
                    NSPredicate(format: "value == %@", "已选中"), evaluatedWith: button)], timeout: 5), .completed)
            }
        }
        let beforeTemporary = try XCTUnwrap(try probe(app)["camera"] as? [Double])
        try nativeTraceStage(app, stage: "temporary-top-down", context: &context) {
            let button = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertTrue(button.isEnabled && button.isHittable)
            button.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [self.expectation(for: NSPredicate { _, _ in
                let state = try? self.probe(app)
                return state?["temporaryTopDownActive"] as? Bool == true
                    && state?["diagramSurface"] as? String == "temporaryTopDown"
            }, evaluatedWith: button)], timeout: 5), .completed)
        }
        try nativeTraceStage(app, stage: "restore-3D", context: &context) {
            app.buttons["shotCamera.temporaryTopDown"].tap()
            self.settle(app)
            XCTAssertEqual(try self.probe(app)["temporaryTopDownActive"] as? Bool, false)
            XCTAssertEqual(try self.probe(app)["camera"] as? [Double], beforeTemporary)
        }
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 20), .completed)
        try nativeTraceStage(app, stage: "real-shot", context: &context) { strike.tap() }
        // The five-second observation is not an animation-completion barrier.
        // XCTest may itself wait for quiescence during tap; preserve the action
        // markers and use the App's shot signposts to select the actual active ROI.
        try nativeTraceMarker("shot-completion", boundary: "begin", context: &context)
        let playback = app.buttons["dailyClearance.playback"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: playback)], timeout: 60), .completed)
        settle(app)
        XCTAssertNotEqual(strokes(), initialStrokes)
        try assertRecipe(app, recipe: recipe, effective: recipe != .reference)
        try nativeTraceMarker("shot-completion", boundary: "end", context: &context)
        try nativeTraceStage(app, stage: "post-shot-idle", context: &context) {}
        try nativeTraceSnapshot(app, stage: "before-exit", context: context)
        try nativeTraceMarker("exit-page", boundary: "begin", context: &context)
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(hud.waitForNonExistence(timeout: 10))
        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.isHittable)
        try nativeTraceMarker("exit-page", boundary: "end", context: &context)
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "cloth-native-\(recipe.rawValue)-returned-home"; home.lifetime = .keepAlways; add(home)
        try nativeTraceMarker("COMPLETE", boundary: "end", context: &context)
    }

    private func nativeAppPID(_ state: [String: Any]) throws -> Int {
        let layout = try XCTUnwrap(state["dailyLayout"] as? [String: [String: Any]],
                                  "Existing dailyLayout probe must identify the actual App process")
        let pids = Set(layout.values.compactMap { ($0["pid"] as? NSNumber)?.intValue })
        XCTAssertEqual(pids.count, 1, "Do not attach a trace to an ambiguous or stale App PID")
        let pid = try XCTUnwrap(pids.first)
        XCTAssertGreaterThan(pid, 0)
        XCTAssertNotEqual(pid, Int(ProcessInfo.processInfo.processIdentifier), "Runner PID is not App PID")
        return pid
    }

    private func nativeAim(_ app: XCUIApplication) throws -> [Double] {
        let controls = app.descendants(matching: .any)["dailyLayout.controlsProbe"].firstMatch
        let value = try XCTUnwrap(controls.value as? String)
        return try ["aimX=", "aimZ="].map { prefix in
            let field = try XCTUnwrap(value.split(separator: " ").first { $0.hasPrefix(prefix) })
            let number = try XCTUnwrap(Double(field.dropFirst(prefix.count)), "Expected a real currentPlayerAim")
            XCTAssertTrue(number.isFinite)
            return number
        }
    }

    private func nativeTraceMarker(_ stage: String, boundary: String,
                                   context: inout NativeTraceContext, seconds: Double? = nil) throws {
        var row: [String: Any] = ["runID": context.runID, "recipe": context.recipe.rawValue,
            "stage": stage, "boundary": boundary, "appPID": context.appPID,
            "runnerPID": ProcessInfo.processInfo.processIdentifier,
            "runnerIsiOSAppOnMac": ProcessInfo.processInfo.isiOSAppOnMac,
            "wallUnixSeconds": Date().timeIntervalSince1970,
            "runnerUptimeNanoseconds": String(DispatchTime.now().uptimeNanoseconds),
            "requestedFPS": 60, "sequence": context.markers.count,
            "scope": "UI orchestration marker, not App frame/present timestamp or performance result"]
        if let seconds { row["plannedObservationSeconds"] = seconds }
        context.markers.append(row)
        print("CLOTH_NATIVE_PAGE_MARKER " + String(decoding:
            try JSONSerialization.data(withJSONObject: row, options: .sortedKeys), as: UTF8.self))
    }

    private func nativeTraceStage(_ app: XCUIApplication, stage: String,
                                  context: inout NativeTraceContext, action: () throws -> Void) throws {
        try nativeTraceSnapshot(app, stage: stage + "-before", context: context)
        try nativeTraceMarker(stage, boundary: "action.begin", context: &context)
        try action()
        try nativeTraceMarker(stage, boundary: "action.end", context: &context)
        // Screenshots and AX state reads are outside this bounded observation.
        // Action durations are recorded separately and are not forced to 5 sec.
        try nativeTraceMarker(stage, boundary: "observe.begin", context: &context, seconds: 5)
        Thread.sleep(forTimeInterval: 5)
        try nativeTraceMarker(stage, boundary: "observe.end", context: &context, seconds: 5)
        try nativeTraceSnapshot(app, stage: stage + "-after", context: context)
    }

    private func nativeTraceSnapshot(_ app: XCUIApplication, stage: String,
                                     context: NativeTraceContext) throws {
        let state = try probe(app)
        XCTAssertEqual(try nativeAppPID(state), context.appPID)
        try assertRecipe(app, recipe: context.recipe, effective: context.recipe != .reference)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        let frame = window.frame
        XCTAssertGreaterThan(frame.width, 0); XCTAssertGreaterThan(frame.height, 0)
        let controls = app.descendants(matching: .any)["dailyLayout.controlsProbe"].firstMatch
        let row: [String: Any] = ["runID": context.runID, "recipe": context.recipe.rawValue,
            "stage": stage, "appPID": context.appPID, "wallUnixSeconds": Date().timeIntervalSince1970,
            "runnerUptimeNanoseconds": String(DispatchTime.now().uptimeNanoseconds), "scene": state,
            "appState": app.state.rawValue, "launchArguments": app.launchArguments,
            "windowFrame": [frame.minX, frame.minY, frame.width, frame.height],
            "runnerDeviceOrientation": XCUIDevice.shared.orientation.rawValue,
            "controls": controls.exists ? (controls.value as? String ?? "") : "missing",
            "requestedFPS": 60,
            "actualFPSAuthority": "Daily3D diagnostics configuration selectedFPS/scheduledFPS; no FPS inferred from this test",
            "shapeContract": "Native actual window and probe layout recorded; no assumption that device orientation resizes a Mac window"]
        let data = XCTAttachment(data: try JSONSerialization.data(withJSONObject: row,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        data.name = "cloth-native-\(context.recipe.rawValue)-\(stage)-state"; data.lifetime = .keepAlways; add(data)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "cloth-native-\(context.recipe.rawValue)-\(stage)"; image.lifetime = .keepAlways; add(image)
    }
}
