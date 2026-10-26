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
        launch(); app.otherElements["multiBall.length"].buttons["自由训练"].tap()
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
        XCTAssertEqual(app.otherElements["multiBall.length"].buttons["自由训练"].value as? String, "需要 Pro")
        try capture("39-free-mode-lock")
        app.otherElements["multiBall.length"].buttons["自由训练"].tap()
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

}
