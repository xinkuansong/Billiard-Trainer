import XCTest

final class MultiBallPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private var state: XCUIElement { app.descendants(matching: .any)["multiBall.landscape"] }
    private var table: XCUIElement { app.descendants(matching: .any)["table.scene"] }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: timeout), .completed, e.debugDescription)
    }
    private func launch(direct: Bool = true, dark: Bool = true, is3D: Bool = false) {
        var args = ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-3dDrag.probe", "-multiBall.fixedSeed", dark ? "-v54.forceDark" : "-v54.forceLight"]
        if direct { args.append(is3D ? "-pro.route=multiBall3D" : "-pro.route=multiBall") }
        app = .launchClean(extraArgs: args)
        if !direct {
            app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
            let entry = app.buttons[is3D ? "3D多球走位" : "2D多球走位"]
            for _ in 0..<5 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
            ready(entry); entry.tap()
        }
        ready(app.buttons["multiBall.start"])
        let picker = app.segmentedControls["multiBall.positionMode"]
        revealInSettings(picker); picker.buttons["自主走位"].tap()
    }
    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot(), attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
        }
    }
    func testGeometryReference2D() throws { try geometryReference(false) }
    func testGeometryReference3D() throws { try geometryReference(true) }
    private func geometryReference(_ is3D: Bool) throws {
        launch(is3D: is3D); start()
        if is3D, app.buttons["dailyClearance.observeTable"].exists {
            ready(app.buttons["dailyClearance.observeTable"]); app.buttons["dailyClearance.observeTable"].tap()
        }
        func handle() throws -> [String: Any] {
            let value = try XCTUnwrap(table.value as? String)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
            return try XCTUnwrap(json["geometryHandle"] as? [String: Any])
        }
        let menu = app.buttons["multiBall.geometry"]; ready(menu); menu.tap()
        let choice = app.buttons["multiBall.geometry.4"]; ready(choice); choice.tap()
        XCTAssertEqual(try handle()["visible"] as? Bool, true)
        let first = try XCTUnwrap(handle()["world"] as? [Double])
        try capture("multiBall-geometry-\(is3D)")
        let strike = app.buttons["dailyClearance.strike"]; ready(strike); strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            (try? handle()["visible"] as? Bool) == false
        }, object: nil)], timeout: 90), .completed)
        XCTAssertEqual(menu.value as? String, "关闭")
        let failureRetry = app.buttons["multiBall.failure.retry"]
        if failureRetry.exists { ready(failureRetry); failureRetry.tap() }
        else { ready(app.buttons["dailyClearance.undo"]); app.buttons["dailyClearance.undo"].tap() }
        XCTAssertEqual(try handle()["visible"] as? Bool, true)
        XCTAssertEqual(try handle()["world"] as? [Double], first)
        XCTAssertEqual(menu.value as? String, "4库")
        try capture("multiBall-geometry-restored-\(is3D)")
    }

    private func balls() throws -> [[String: Any]] {
        let text = try XCTUnwrap(table.value as? String)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        return try XCTUnwrap(json["balls"] as? [[String: Any]])
    }
    private func positions() throws -> [String: [Double]] {
        try Dictionary(uniqueKeysWithValues: balls().map { (try XCTUnwrap($0["key"] as? String), try XCTUnwrap($0["world"] as? [Double])) })
    }
    private func same(_ expected: [String: [Double]]) throws {
        let actual = try positions(); XCTAssertEqual(Set(actual.keys), Set(expected.keys))
        for (key, p) in expected { let q = try XCTUnwrap(actual[key]); XCTAssertEqual(p[0], q[0], accuracy: 0.0001); XCTAssertEqual(p[2], q[2], accuracy: 0.0001) }
    }
    private func start() {
        app.buttons["multiBall.start"].tap(); XCTAssertTrue(state.waitForExistence(timeout: 30))
        rotate(.landscapeLeft)
        ready(app.buttons["freeplay.moreMenu"])
    }
    private func rotate(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        // iPadOS retains a different floating window for each orientation.
        // Normalize it through the system window controls for the fullscreen matrix.
        let window = app.windows.firstMatch
        if window.frame.minX > 1 || window.frame.minY > 40 {
            let before = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - before.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return frame.minX < 1 && (orientation == .portrait ? frame.height > frame.width : frame.width > frame.height)
        }, object: nil)], timeout: 10), .completed)
    }
    private func menu() { ready(app.buttons["freeplay.moreMenu"]); app.buttons["freeplay.moreMenu"].tap(); XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].waitForExistence(timeout: 5)) }
    private func closeMenu() {
        let close = app.buttons["dailyClearance.menuClose"]
        if close.exists { close.tap() } else {
            // This is the full-window backdrop. Its center lies underneath the
            // menu in a narrow iPad window; tap the exposed left edge instead.
            app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.03, dy: 0.7)).tap()
        }
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].waitForNonExistence(timeout: 5))
    }
    private func mode(_ is3D: Bool) {
        menu(); XCTAssertFalse(app.buttons["freeplay.cameraMode"].exists)
        closeMenu(); ready(app.buttons["freeplay.moreMenu"])
        XCTAssertEqual(app.buttons["shotCamera.temporaryTopDown"].exists, is3D)
    }
    private func revealInSettings(_ element: XCUIElement, down: Bool = true) {
        let form = app.collectionViews.firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        var dragX: CGFloat?
        for _ in 0..<16 {
            var viewport = form.frame.intersection(app.windows.firstMatch.frame)
            let nav = app.navigationBars.firstMatch
            if nav.exists { viewport.origin.y = max(viewport.minY, nav.frame.maxY) }
            let bottom = min(form.frame.maxY, app.windows.firstMatch.frame.maxY) - 20
            viewport.size.height = max(1, bottom - viewport.minY)
            var forward = down
            if element.exists && element.frame.height > 0 {
                let frame = element.frame
                dragX = max(viewport.minX + 4, frame.minX - 6)
                print("MULTI_SETTINGS_REVEAL", element.identifier, frame, viewport)
                if element.isHittable && frame.minY >= viewport.minY + 8 && frame.maxY <= viewport.maxY - 8 { break }
                forward = frame.midY > viewport.midY
            }
            // Native segmented pickers consume drags starting on them. Scroll
            // in the List gutter, outside the actual cells, without changing game.
            let cellLeft = form.cells.allElementsBoundByIndex.first(where: { $0.frame.width > 0 })?.frame.minX ?? viewport.minX + 10
            let x = dragX ?? max(viewport.minX + 4, cellLeft - 6)
            let travel = min(CGFloat(75), viewport.height * 0.3)
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let window = app.windows.firstMatch.frame
            let from = origin.withOffset(.init(dx: x - window.minX, dy: viewport.midY - window.minY + (forward ? travel / 2 : -travel / 2)))
            let to = origin.withOffset(.init(dx: x - window.minX, dy: viewport.midY - window.minY + (forward ? -travel / 2 : travel / 2)))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        ready(element)
    }
    private func choose(_ id: String, _ title: String) {
        let suffix = id == "multiBall.opponents" ? (title == "0 颗" ? "zero" : "random") : String(title.prefix(1))
        let option = app.buttons[id + "." + suffix]
        revealInSettings(option); option.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已选"), object: option)], timeout: 5), .completed)
    }
    func testEntryRotationSettingsRestartAndViews() throws {
        launch(direct: false)
        app.segmentedControls["multiBall.game"].buttons["顺序清台"].tap()
        choose("multiBall.rotationCount", "9 颗")
        try capture("01-rotation-settings"); start(); mode(false)
        XCTAssertEqual(try balls().count, 10)
        let initial = try positions()
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆true"))
        try capture("02-rotation-nine-2d")
        app.buttons["multiBall.restart"].tap(); ready(app.buttons["multiBall.restart.confirm"])
        try capture("03-restart-confirm"); app.buttons["multiBall.restart.confirm"].tap()
        ready(app.buttons["freeplay.moreMenu"]); try same(initial)
        mode(false); try same(initial); try capture("04-rotation-nine-fixed-2d")
        mode(false); try same(initial)
        menu(); app.buttons["multiBall.settings"].tap()
        choose("multiBall.rotationCount", "4 颗")
        app.buttons["multiBall.settingsCancel"].tap(); ready(app.buttons["freeplay.moreMenu"]); try same(initial)
        menu(); app.buttons["multiBall.next"].tap(); ready(app.buttons["freeplay.moreMenu"])
        XCTAssertNotEqual(try positions(), initial)
        XCTAssertEqual(try balls().count, 10)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let orientationBoard = try positions()
            rotate(.portrait); ready(app.buttons["freeplay.moreMenu"]); try same(orientationBoard); try capture("05-ipad-portrait")
            mode(false); try same(orientationBoard)
            mode(false)
            rotate(.landscapeLeft); ready(app.buttons["freeplay.moreMenu"]); try same(orientationBoard); try capture("06-ipad-landscape-return")
            let full = app.windows.firstMatch.frame
            let fullPaletteSlotWidth = app.buttons["paletteBall__1"].frame.width
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width - 7, dy: full.height - 7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width * 0.7, dy: full.height * 0.78)))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = self.app.windows.firstMatch.frame
                return frame.width < full.width - 80 || frame.height < full.height - 80
            }, object: nil)], timeout: 10), .completed)
            ready(app.buttons["multiBall.restart"]); try same(orientationBoard)
            let smallPaletteSlotWidth = app.buttons["paletteBall__1"].frame.width
            XCTAssertLessThan(smallPaletteSlotWidth, fullPaletteSlotWidth,
                "A narrow table must shrink the nine-ball palette instead of keeping its full-window size")
            XCTAssertGreaterThanOrEqual(smallPaletteSlotWidth, 27)
            app.buttons["paletteBall__1"].tap()
            XCTAssertTrue((state.value as? String ?? "").contains("目标_1"))
            print("PALETTE_PROPORTION fullSlot=\(fullPaletteSlotWidth) smallSlot=\(smallPaletteSlotWidth)")
            try capture("07-ipad-small-window-2d")
            menu(); closeMenu()
            app.buttons["multiBall.restart"].tap(); ready(app.buttons["multiBall.restart.confirm"])
            app.buttons["multiBall.restart.confirm"].tap(); try same(orientationBoard)
            mode(false); try same(orientationBoard)
            mode(false)
            let window = app.windows.firstMatch, small = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - small.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(self.app.windows.firstMatch.frame.width - full.width) < 1
            }, object: nil)], timeout: 10), .completed)
            ready(app.buttons["multiBall.restart"]); try same(orientationBoard); try capture("09-ipad-full-window-restored")
            XCTAssertEqual(app.buttons["paletteBall__1"].frame.width, fullPaletteSlotWidth, accuracy: 0.5)
        }
    }
    func testChineseSubsetSelectionAndModePersistence() throws {
        launch(); revealInSettings(app.otherElements["multiBall.length"])
        app.otherElements["multiBall.length"].buttons["持续练习"].tap()
        revealInSettings(app.segmentedControls["multiBall.game"])
        app.segmentedControls["multiBall.game"].buttons["中八残局"].tap()
        choose("multiBall.ownCount", "8 颗"); choose("multiBall.opponents", "随机 1–7 颗")
        try capture("10-chinese-settings"); start(); mode(false)
        // Exercise the maximum 15-object palette through the real random/new-rack flow.
        for _ in 0..<20 {
            if try balls().count == 16 { break }
            menu(); app.buttons["multiBall.next"].tap(); ready(app.buttons["freeplay.moreMenu"])
        }
        let before = try positions(); XCTAssertEqual(before.count, 16)
        let notice = app.descendants(matching: .any)["multiBall.ballInHand"].label
        let solids = notice.contains("全色")
        let own = (solids ? Array(1...7) : Array(9...15)).map { "_\($0)" }
        for key in [own.first!, own.last!] {
            app.buttons["paletteBall_" + key].tap()
            XCTAssertTrue((state.value as? String ?? "").contains("目标\(key)"), state.value as? String ?? "")
        }
        try capture("11-chinese-2d")
        let selected = state.value as? String ?? ""
        app.buttons["paletteBall__8"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["multiBall.selectionNotice"].waitForExistence(timeout: 3))
        XCTAssertTrue((state.value as? String ?? "").contains("目标\(own.last!)"), selected)
        try same(before)
        mode(false); try same(before); try capture("12-chinese-fixed-2d")
        menu(); app.buttons["dailyClearance.aimModeMenu"].tap(); app.buttons["dailyClearance.aim.free"].tap()
        XCTAssertTrue(app.buttons["dailyClearance.aim.free"].exists)
        closeMenu()
        XCTAssertTrue((state.value as? String ?? "").contains("自由"))
        try capture("13-free-mode")
        mode(false); try same(before)
        menu(); app.buttons["multiBall.settings"].tap()
        choose("multiBall.ownCount", "4 颗"); choose("multiBall.opponents", "0 颗"); start()
        XCTAssertEqual(try balls().count, 5); try capture("14-chinese-no-opponents")
    }
    func testCuePlacementMissRetryAndSettingsReset() throws {
        launch(); app.segmentedControls["multiBall.game"].buttons["顺序清台"].tap()
        choose("multiBall.rotationCount", "4 颗"); start(); mode(false)
        let objects = try positions().filter { $0.key != "cueBall" }
        let cue = try XCTUnwrap(try balls().first { $0["key"] as? String == "cueBall" })
        XCTAssertEqual(cue["draggable"] as? Bool, true)
        for b in try balls() where b["key"] as? String != "cueBall" { XCTAssertEqual(b["draggable"] as? Bool, false) }
        let point = try XCTUnwrap(cue["screen"] as? [Double]), old = try XCTUnwrap(cue["world"] as? [Double])
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(.init(dx: table.frame.minX - app.windows.firstMatch.frame.minX + point[0],
                                          dy: table.frame.minY - app.windows.firstMatch.frame.minY + point[1]))
        print("MULTI_DRAG_BEFORE", table.frame, table.value ?? "nil")
        try capture("drag-before")
        let direction: CGFloat = point[0] < table.frame.width / 2 ? 1 : -1
        from.press(forDuration: 0.15, thenDragTo: from.withOffset(.init(dx: 110 * direction, dy: 0)))
        menu(); closeMenu()
        print("MULTI_DRAG_AFTER", table.frame, table.value ?? "nil")
        try capture("drag-after")
        let placed = try XCTUnwrap(try positions()["cueBall"])
        XCTAssertGreaterThan(hypot(old[0]-placed[0], old[2]-placed[2]), 0.01)
        XCTAssertEqual(try positions().filter { $0.key != "cueBall" }, objects)
        try capture("20-cue-placed")
        menu(); app.buttons["dailyClearance.aimModeMenu"].tap(); app.buttons["dailyClearance.aim.free"].tap(); closeMenu()
        let power = app.descendants(matching: .any)["shotStage.powerBar"]
        // Relative power travel is adaptive; establish the actual value instead
        // of assuming one fast gesture reaches the minimum on every runtime.
        for _ in 0..<6 {
            if power.value as? String == "0.50" { break }
            power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1)).press(forDuration: 0.15,
                thenDragTo: power.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95)))
        }
        XCTAssertEqual(power.value as? String, "0.50")
        let aim = app.descendants(matching: .any)["shotStage.aimWheel"]
        aim.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.8)).press(forDuration: 0.15,
            thenDragTo: aim.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.2)))
        ready(app.buttons["dailyClearance.strike"])
        try capture("20b-miss-input")
        let before = try positions()
        app.buttons["dailyClearance.strike"].tap()
        ready(app.buttons["multiBall.failure.retry"], timeout: 60)
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆false"))
        try capture("21-failure-choice")
        app.buttons["multiBall.failure.retry"].tap(); ready(app.buttons["dailyClearance.strike"])
        try same(before)
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆true"))
        try capture("22-retry-restores")
        app.buttons["multiBall.restart"].tap(); app.buttons["multiBall.restart.confirm"].tap()
        ready(app.buttons["freeplay.moreMenu"]); try same(before)
        menu(); let grid = app.buttons["menu.tableGrid"]; grid.tap()
        XCTAssertTrue(app.buttons["menu.tableGrid"].exists); grid.tap()
        app.buttons["multiBall.settings"].tap()
        app.segmentedControls["multiBall.game"].buttons["中八残局"].tap()
        choose("multiBall.ownCount", "8 颗")
        let reset = app.buttons["training.resetDefaults"]
        try capture("23-reset-before-scroll")
        revealInSettings(reset)
        try capture("23-reset-scrolled")
        ready(reset); reset.tap()
        XCTAssertTrue(app.staticTexts["已恢复默认设置"].waitForExistence(timeout: 5))
        revealInSettings(app.segmentedControls["multiBall.game"], down: false)
        XCTAssertTrue(app.segmentedControls["multiBall.game"].buttons["顺序清台"].isSelected)
        try capture("23-reset-defaults")
        app.buttons["multiBall.settingsCancel"].tap(); ready(app.buttons["freeplay.moreMenu"]); try same(before)
    }

    func testLightTemporaryPlacementSpinAndLayoutCancel() throws {
        launch(dark: false, is3D: true)
        app.segmentedControls["multiBall.game"].buttons["顺序清台"].tap()
        choose("multiBall.rotationCount", "6 颗")
        try capture("30-light-settings"); start(); mode(true)
        ready(app.buttons["shotCamera.temporaryTopDown"]); app.buttons["shotCamera.temporaryTopDown"].tap()
        let before = try positions()
        let cue = try XCTUnwrap(try balls().first { $0["key"] as? String == "cueBall" })
        let point = try XCTUnwrap(cue["screen"] as? [Double])
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(.init(dx: table.frame.minX - app.windows.firstMatch.frame.minX + point[0],
                                          dy: table.frame.minY - app.windows.firstMatch.frame.minY + point[1]))
        print("MULTI_DRAG_BEFORE", table.frame, table.value ?? "nil")
        try capture("drag-before")
        let direction: CGFloat = point[0] < table.frame.width/2 ? 1 : -1
        from.press(forDuration: 0.15, thenDragTo: from.withOffset(.init(dx: 110 * direction, dy: 0)))
        print("MULTI_DRAG_AFTER", table.frame, table.value ?? "nil")
        try capture("drag-after")
        let after = try positions()
        XCTAssertNotEqual(after["cueBall"], before["cueBall"])
        XCTAssertEqual(after.filter { $0.key != "cueBall" }, before.filter { $0.key != "cueBall" })
        try capture("31-temporary-placement")
        app.buttons["shotCamera.temporaryTopDown"].tap(); try same(after)
        mode(true); try same(after)
        menu(); app.buttons["dailyClearance.spinTransparencyMenu"].tap()
        let slider = app.sliders["dailyClearance.spinTransparencySlider"]; ready(slider)
        slider.adjust(toNormalizedSliderPosition: 0)
        if slider.value as? String != "0%" {
            // XCTest's normalized endpoint can round to 1% on iPad. Drag the
            // native thumb to the track boundary and assert the actual value.
            print("MULTI_SLIDER_ENDPOINT", slider.frame, slider.value ?? "nil")
            try capture("32a-slider-endpoint-before")
            slider.coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.5)).press(forDuration: 0.15,
                thenDragTo: slider.coordinate(withNormalizedOffset: .init(dx: 0, dy: 0.5)).withOffset(.init(dx: -20, dy: 0)))
        }
        XCTAssertEqual(slider.value as? String, "0%")
        try capture("32-spin-transparency")
        app.buttons["dailyClearance.spinTransparencyDone"].tap()
        let disc = app.descendants(matching: .any)["spinPad.disc"]; ready(disc)
        try capture("33-spin-panel")
        app.buttons["shotStage.spinEntry"].tap(); try same(after)
        let restart = app.buttons["multiBall.restart"], original = app.buttons["multiBall.restart"].frame
        menu(); app.buttons["controlLayout.open"].tap()
        let control = app.buttons["freeLayout.select.multiBall.restart"]; ready(control)
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        let size = control.frame.size
        app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(control.frame.width, size.width)
        try capture("34-layout-draft")
        app.buttons["freeLayout.cancel"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        ready(restart); XCTAssertEqual(restart.frame.width, original.width, accuracy: 1); try same(after)
        try capture("35-layout-cancelled")
    }

    func testNonProQuotaAndFreeTrainingGate() throws {
        app = .launchClean(extraArgs: ["-forceNonPremium", "-v54.forceLight", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-w7.forceDailyLimitNear", "-3dDrag.probe", "-pro.route=multiBall"])
        ready(app.buttons["multiBall.start"])
        XCTAssertTrue(app.staticTexts["今日剩余 1 题，所有多球玩法共用"].exists)
        revealInSettings(app.otherElements["multiBall.length"])
        XCTAssertEqual(app.otherElements["multiBall.length"].buttons["持续练习"].value as? String, "需要 Pro")
        try capture("39-free-mode-lock")
        app.otherElements["multiBall.length"].buttons["持续练习"].tap()
        ready(app.buttons["subscription.close"]); try capture("40-free-training-pro")
        app.buttons["subscription.close"].tap()
        XCTAssertTrue(app.otherElements["multiBall.length"].buttons["3题"].isSelected)
        app.segmentedControls["multiBall.game"].buttons["中八残局"].tap()
        choose("multiBall.ownCount", "4 颗")
        start(); mode(false)
        let before = try positions()
        app.buttons["multiBall.restart"].tap(); app.buttons["multiBall.restart.confirm"].tap()
        ready(app.buttons["freeplay.moreMenu"]); try same(before)
        menu(); app.buttons["multiBall.next"].tap()
        XCTAssertTrue(app.alerts["今日免费次数已用完"].waitForExistence(timeout: 5)); try capture("41-quota-exhausted")
        app.buttons["继续当前局"].tap(); try same(before)
        menu(); app.buttons["multiBall.settings"].tap()
        XCTAssertTrue(app.staticTexts["今日剩余 0 题，所有多球玩法共用"].waitForExistence(timeout: 5))
        app.segmentedControls["multiBall.game"].buttons["顺序清台"].tap()
        XCTAssertFalse(app.buttons["multiBall.start"].label.contains("Pro"))
        try capture("42-exhausted-start-plain")
        app.buttons["multiBall.start"].tap(); ready(app.buttons["subscription.close"])
        app.terminate()
        app = .launchClean(extraArgs: ["-forceNonPremium", "-v50.inMemoryStore", "-pro.route=multiBall"])
        ready(app.buttons["multiBall.start"])
        XCTAssertTrue(app.staticTexts["今日剩余 0 题，所有多球玩法共用"].exists)
    }
    func testNonProCannotOpen3DDirectRoute() throws {
        app = .launchClean(extraArgs: ["-forceNonPremium", "-v50.inMemoryStore", "-pro.route=multiBall3D"])
        XCTAssertTrue(app.descendants(matching: .any)["pro.locked"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["multiBall.start"].exists); XCTAssertFalse(table.exists)
        try capture("42-3d-pro-locked")
    }

    func testPlanningFlow2D() throws { try planningFlow(is3D: false) }
    func testPlanningFlow3D() throws { try planningFlow(is3D: true) }

    private func planningFlow(is3D: Bool) throws {
        app = .launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-multiBall.fixedSeed", "-pocketSelection.probe", is3D ? "-v54.forceDark" : "-v54.forceLight", is3D ? "-pro.route=multiBall3D" : "-pro.route=multiBall"])
        ready(app.buttons["multiBall.start"])
        let reset = app.buttons["training.resetDefaults"]
        revealInSettings(reset); reset.tap()
        let picker = app.segmentedControls["multiBall.positionMode"]
        revealInSettings(picker, down: false)
        XCTAssertTrue(picker.buttons["规划走位"].isSelected)
        try capture(is3D ? "planning-3d-settings" : "planning-2d-settings")
        start()
        let plan = app.buttons["paletteBall__2"]
        ready(plan)
        XCTAssertEqual(plan.value as? String, "下一球")
        XCTAssertFalse(app.buttons["multiBall.role.1"].exists)
        XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "后续球")
        ready(app.buttons["dailyClearance.strike"])
        let before = try XCTUnwrap(state.value as? String)
        app.buttons["dailyClearance.strike"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["multiBall.scoreNotice"].waitForExistence(timeout: 3))
        XCTAssertTrue((state.value as? String ?? "").contains("评分杆数0"))
        XCTAssertTrue((state.value as? String ?? "").contains("母球可摆true"))
        try capture(is3D ? "planning-3d-select-pocket" : "planning-2d-select-pocket")
        let chosen = try tapVisiblePlanningPocket()
        ready(plan)
        XCTAssertTrue((state.value as? String ?? "").contains("规划_2:\(chosen)"))
        // Selecting the continuation must preserve the current target and pocket.
        let aimBefore = before.components(separatedBy: "，规划")[0]
        XCTAssertEqual((state.value as? String ?? "").components(separatedBy: "，规划")[0], aimBefore)
        let pockets = try pocketProbe()
        XCTAssertTrue([5, 7].contains(pockets.first { $0["index"] as? Int == chosen }?["style"] as? Int ?? -1))
        try capture(is3D ? "planning-3d-ready-gold" : "planning-2d-ready-gold")
        if UIDevice.current.userInterfaceIdiom == .pad {
            rotate(.portrait); ready(plan)
            try capture(is3D ? "planning-3d-portrait" : "planning-2d-portrait")
            rotate(.landscapeLeft); ready(plan)
        }
        if is3D {
            let topDown = app.buttons["shotCamera.temporaryTopDown"]
            ready(topDown); topDown.tap()
            XCTAssertTrue((state.value as? String ?? "").contains("规划_2:\(chosen)"))
            try capture("planning-3d-temporary-topdown")
            topDown.tap(); ready(plan)
            XCTAssertTrue([5, 7].contains(try pocketProbe().first { $0["index"] as? Int == chosen }?["style"] as? Int ?? -1))
        }
        ready(app.buttons["dailyClearance.strike"], timeout: 60)
        app.buttons["dailyClearance.strike"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (self.state.value as? String ?? "").contains("评分杆数1")
        }, object: nil)], timeout: 60), .completed)
        try capture(is3D ? "planning-3d-result" : "planning-2d-result")
        let retry = app.buttons["multiBall.failure.retry"]
        if retry.exists {
            XCTAssertTrue((state.value as? String ?? "").contains("本杆走位 0 分"))
            retry.tap()
        } else {
            XCTAssertTrue((state.value as? String ?? "").contains("目标_2，"))
            XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "下一球")
            XCTAssertEqual(app.buttons["paletteBall__9"].value as? String, "后续球")
            XCTAssertTrue((state.value as? String ?? "").contains("锁袋\(chosen)"))
            let undo = app.buttons["dailyClearance.undo"]
            ready(undo); undo.tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let value = self.state.value as? String ?? ""
            return value.contains("评分杆数0") && value.contains("规划_2:\(chosen)")
        }, object: nil)], timeout: 10), .completed)
        try capture(is3D ? "planning-3d-retry" : "planning-2d-retry")
        menu(); app.buttons["multiBall.settings"].tap()
        revealInSettings(picker, down: false); picker.buttons["自主走位"].tap()
        app.buttons["multiBall.settingsCancel"].tap(); ready(plan)
        XCTAssertTrue((state.value as? String ?? "").contains("规划_2:\(chosen)"))
        menu(); app.buttons["multiBall.settings"].tap()
        revealInSettings(picker, down: false); picker.buttons["自主走位"].tap()
        start()
        XCTAssertNotEqual(plan.value as? String, "下一球")
        try capture(is3D ? "independent-3d" : "independent-2d")
        let independentState = try XCTUnwrap(state.value as? String)
        let independentPositions = try positions()
        menu(); app.buttons["multiBall.settings"].tap()
        revealInSettings(picker, down: false)
        XCTAssertTrue(picker.buttons["自主走位"].isSelected)
        picker.buttons["规划走位"].tap()
        app.buttons["multiBall.settingsCancel"].tap(); ready(app.buttons["dailyClearance.strike"])
        XCTAssertEqual(state.value as? String, independentState)
        try same(independentPositions)
        menu(); app.buttons["multiBall.settings"].tap()
        revealInSettings(picker, down: false); picker.buttons["规划走位"].tap()
        start(); ready(plan)
        XCTAssertEqual(plan.value as? String, "下一球")
        let newPocket = try tapVisiblePlanningPocket()
        XCTAssertTrue((state.value as? String ?? "").contains("规划_2:\(newPocket)"))
        ready(app.buttons["dailyClearance.strike"])
        try capture(is3D ? "planning-restored-3d" : "planning-restored-2d")
    }

    private func selectionFeedback() throws -> [String: Int] {
        let text = try XCTUnwrap(table.value as? String)
        let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        return try XCTUnwrap(data["selectionFeedback"] as? [String: Int])
    }

    private func pocketProbe() throws -> [[String: Any]] {
        let text = try XCTUnwrap(table.value as? String)
        let data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        return try XCTUnwrap(data["pockets"] as? [[String: Any]])
    }
    private func tapVisiblePlanningPocket() throws -> Int {
        let window = app.windows.firstMatch.frame
        // Use actual frontmost leather hits, not pocket centres inside the holes.
        let candidates = try pocketProbe().filter { ($0["tapWindow"] as? [Double])?.count == 3 }.sorted {
            let a = ($0["tapWindow"] as? [Double])?[1] ?? -10000
            let b = ($1["tapWindow"] as? [Double])?[1] ?? -10000
            return abs(a - window.height / 2) < abs(b - window.height / 2)
        }
        let entry = try XCTUnwrap(candidates.first { item in
            guard let p = item["tapWindow"] as? [Double], p.count == 3 else { return false }
            let screen = CGPoint(x: window.minX + p[0], y: window.minY + p[1])
            // Avoid the central instruction and the side instruments.
            return p[2] > 0 && p[2] < 1 && screen.x > window.minX + 100 && screen.x < window.maxX - 100
                && screen.y > window.minY + 70 && screen.y < window.maxY - 20
        })
        let point = try XCTUnwrap(entry["tapWindow"] as? [Double])
        print("MULTI_POCKET_TAP", "window", window, "table", table.frame, "probe", entry)
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
        print("MULTI_POCKET_AFTER", table.value ?? "nil")
        return try XCTUnwrap(entry["index"] as? Int)
    }

    func testChinesePlanningSelection() throws {
        app = .launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-multiBall.fixedSeed", "-pocketSelection.probe", "-v54.forceLight", "-pro.route=multiBall"])
        ready(app.buttons["multiBall.start"])
        let picker = app.segmentedControls["multiBall.positionMode"]
        revealInSettings(picker); picker.buttons["规划走位"].tap()
        revealInSettings(app.segmentedControls["multiBall.game"], down: false)
        app.segmentedControls["multiBall.game"].buttons["中八残局"].tap()
        choose("multiBall.ownCount", "4 颗"); start()
        let current = try XCTUnwrap((state.value as? String)?.components(separatedBy: "，目标").last?.components(separatedBy: "，").first)
        let candidates = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall__")).allElementsBoundByIndex
        let next = try XCTUnwrap(candidates.first { ($0.value as? String ?? "").contains("己方球") && $0.identifier != "paletteBall_" + current && $0.identifier != "paletteBall__8" })
        let feedbackBefore = try selectionFeedback()
        next.tap()
        XCTAssertEqual(try selectionFeedback()["balls"], feedbackBefore["balls"]! + 1)
        XCTAssertTrue((state.value as? String ?? "").contains("步骤3"))
        let chosen = try tapVisiblePlanningPocket()
        XCTAssertEqual(try selectionFeedback()["rolePockets"], feedbackBefore["rolePockets"]! + 1)
        XCTAssertTrue((state.value as? String ?? "").contains("步骤4"))
        let third = try XCTUnwrap(candidates.first { ($0.value as? String ?? "").contains("己方球") && $0.identifier != next.identifier && $0.identifier != "paletteBall_" + current && $0.identifier != "paletteBall__8" })
        third.tap()
        XCTAssertEqual(try selectionFeedback()["balls"], feedbackBefore["balls"]! + 2)
        third.tap()
        XCTAssertEqual(try selectionFeedback()["balls"], feedbackBefore["balls"]! + 3)
        XCTAssertTrue((third.value as? String ?? "").hasPrefix("后续球"))
        try capture("planning-chinese-third-ball")
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertEqual(undo.label, "上一步")
        undo.tap()
        XCTAssertTrue((state.value as? String ?? "").contains("步骤3"))
        XCTAssertTrue((third.value as? String ?? "").hasPrefix("后续球"))
        undo.tap()
        XCTAssertTrue((state.value as? String ?? "").contains("步骤2"))
        XCTAssertTrue((next.value as? String ?? "").hasPrefix("下一球"))
        ready(next)
        XCTAssertTrue((state.value as? String ?? "").contains("规划" + next.identifier.replacingOccurrences(of: "paletteBall_", with: "") + ":\(chosen)"))
        try capture("planning-chinese-ready")
    }

}
