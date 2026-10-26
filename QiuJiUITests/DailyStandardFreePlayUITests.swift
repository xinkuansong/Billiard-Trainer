import XCTest

final class TableMenuRetentionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch(_ route: String, more: String, start: String? = nil) {
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-v53.authenticatedProfileFixture", "-dailyClearance.resetState", "-dailyClearance.fixture=selection",
            "-dailyLayout.probe", route])
        if let start {
            XCTAssertTrue(app.buttons[start].waitForExistence(timeout: 15))
            app.buttons[start].tap()
        }
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return frame.width > frame.height
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 15), .completed)
        let button = app.buttons[more]
        XCTAssertTrue(button.waitForExistence(timeout: 25))
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func reveal(_ id: String) -> XCUIElement {
        let item = app.buttons[id]
        let scroll = app.scrollViews["dailyClearance.menuScroll"]
        for _ in 0..<8 {
            if item.isHittable && scroll.frame.contains(item.frame) { break }
            if item.exists && item.frame.minY < scroll.frame.minY { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(item.isHittable, id)
        return item
    }

    private func toggleTwice(_ id: String) {
        let item = reveal(id)
        let original = item.value as? String
        XCTAssertTrue(original == "已选" || original == "未选")
        capture(id + "-before")
        item.tap()
        capture(id + "-after-toggle")
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].exists, "Changing a setting must keep its menu open")
        XCTAssertEqual(item.value as? String, original == "已选" ? "未选" : "已选")
        item.tap()
        XCTAssertEqual(item.value as? String, original)
        XCTAssertTrue(item.isHittable)
    }

    private func selectTrajectory(entry: String, prefix: String) {
        reveal(entry).tap()
        let first = reveal(prefix + ".2")
        first.tap()
        XCTAssertTrue(app.buttons["dailyClearance.menuBack"].exists)
        XCTAssertEqual(first.value as? String, "已选")
        let full = reveal(prefix + ".0")
        full.tap()
        XCTAssertEqual(full.value as? String, "已选")
        XCTAssertEqual(first.value as? String, "未选")
        capture(prefix + "-selected")
        app.buttons["dailyClearance.menuBack"].tap()
        XCTAssertTrue(app.scrollViews["dailyClearance.menuScroll"].exists)
    }

    func testDailySettingsStayOpenAcrossSelections() {
        launch("-deeplink.dailyClearance", more: "freeplay.moreMenu")
        toggleTwice("menu.aimCloseup")
        toggleTwice("menu.tableGrid")
        selectTrajectory(entry: "dailyClearance.trajectoryMenu", prefix: "dailyClearance.trajectory")
        reveal("dailyClearance.aimModeMenu").tap()
        let free = reveal("dailyClearance.aim.free")
        free.tap(); XCTAssertEqual(free.value as? String, "已选")
        XCTAssertTrue(app.buttons["dailyClearance.menuClose"].exists)
        app.buttons["dailyClearance.menuClose"].tap()
        XCTAssertFalse(app.scrollViews["dailyClearance.menuScroll"].exists)
    }

    func testFreePlaySettingsStayOpenAndLayoutActionClosesMenu() {
        launch("-deeplink.freePlay", more: "freeplay.moreMenu")
        toggleTwice("menu.aimCloseup")
        toggleTwice("menu.tableGrid")
        reveal("controlLayout.open").tap()
        XCTAssertFalse(app.scrollViews["dailyClearance.menuScroll"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "freeLayout.editor").firstMatch.waitForExistence(timeout: 5))
        capture("freeplay-layout-action")
    }

    func testTeachingDisplayChoicesStayOpen() {
        launch("-dailyInteraction.sharedPage=angleDynamic", more: "angleDynamic.more")
        toggleTwice("menu.tableGrid")
        toggleTwice("angleDynamic.aimLine")
        toggleTwice("angleDynamic.potLine")
        let window = app.windows.firstMatch.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.midX, dy: window.midY)).tap()
        XCTAssertFalse(app.scrollViews["dailyClearance.menuScroll"].exists)
    }

    func testPlanningOptionsStayOpen() {
        launch("-deeplink.silu", more: "silu.more")
        XCTAssertFalse(reveal("menu.aimCloseup").isEnabled, "An unsolved board must retain its closeup availability restriction")
        toggleTwice("menu.tableGrid")
        toggleTwice("silu.sideSpin")
        toggleTwice("silu.basicOnly")
        selectTrajectory(entry: "silu.trajectory", prefix: "silu.trajectory")
    }

    func testQuizSettingsStayOpen() {
        for (route, prefix) in [("aimpoint2d", "aimPointTraining"), ("anglequiz2d", "angleTraining")] {
            app?.terminate()
            launch("-dailyInteraction.sharedPage=" + route, more: prefix + ".settings", start: prefix + ".start")
            toggleTwice("menu.tableGrid")
            if prefix == "aimPointTraining" { toggleTwice("menu.aimCloseup") }
            reveal(prefix + ".trainingSettings").tap()
            XCTAssertFalse(app.scrollViews["dailyClearance.menuScroll"].exists)
            XCTAssertTrue(app.buttons[prefix + ".start"].waitForExistence(timeout: 5))
            capture(route + "-training-settings")
        }
    }

    func testBatchSettingsStayOpen() {
        launch("-dailyInteraction.sharedPage=batch", more: "batch.more")
        toggleTwice("menu.aimCloseup")
        toggleTwice("menu.tableGrid")
        selectTrajectory(entry: "batch.trajectory", prefix: "batch.trajectory")
    }
}

/// Renderer placement must follow the visible stage across the real detail navigation route.
/// The baseline failure is retained in fixes-20261009/before-p1; no production delay is used.
final class DailyStandardFreePlayUITests: XCTestCase {
    private var app: XCUIApplication!

    /// A real detail push must reserve exactly the reference table space,
    /// independently of the drill name and the selected camera mode.
    func testTryoutLongTitlesPreserveDailyTableSize() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let common = ["-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture",
                      "-dailyLayout.probe", "-drillTryout.hasSeenGestureHint", "YES"]
        // Match tryout's 15-ball palette; a persisted nine-ball game has a
        // different header height on compact screens even at the same table size.
        app = XCUIApplication.launchClean(extraArgs: common + ["-deeplink.dailyClearance",
            "-dailyClearance.resetState", "-dailyClearance.preferredGame.v1", "chineseEightBall"])
        XCTAssertTrue(element("dailyClearance.landscape").waitForExistence(timeout: 20))
        XCTAssertTrue(element("freeplay.stage").waitForExistence(timeout: 10))
        let reference = element("freeplay.stage").frame
        XCTAssertGreaterThan(reference.width, reference.height)
        try capture("title-daily-reference")
        app.terminate()

        for (id, name) in [("drill_c003", "高杆跟进"), ("drill_c029", "定杆分离角精确控制"),
                           ("drill_c034", "不吃库短距离走位"), ("drill_c065", "Ghost Game 单人练习")] {
            app = XCUIApplication.launchClean(extraArgs: common + ["-deeplink.drillDetail=" + id])
            let entry = app.buttons["bottomTryoutButton"]
            XCTAssertTrue(entry.waitForExistence(timeout: 15)); entry.tap()
            let formation = app.buttons["tryoutFormation_0"]
            if formation.waitForExistence(timeout: 2) { formation.tap() }
            XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 15))
            let title = element("tryout.title")
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            XCTAssertEqual(title.label, name)
            XCTAssertLessThanOrEqual(title.frame.width, 60.5)
            let stage = element("freeplay.stage").frame
            XCTAssertEqual(stage.width, reference.width, accuracy: 1, name)
            XCTAssertEqual(stage.height, reference.height, accuracy: 1, name)
            XCTAssertEqual(stage.minY, reference.minY, accuracy: 1, name)
            assertRendererMatchesStage()
            try capture("title-" + id + "-2D")
            app.buttons["freeplay.moreMenu"].tap()
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 5)); mode.tap()
            XCTAssertEqual(mode.value as? String, "3D")
            app.buttons["关闭菜单"].tap()
            try capture("title-" + id + "-3D")
            XCTAssertEqual(element("freeplay.stage").frame.size, stage.size)
            app.buttons["dailyClearance.back"].tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            app.terminate()
        }
    }
    func testTryoutModeAndManualSequenceControls() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-v53.authenticatedProfileFixture", "-dailyLayout.probe", "-drillTryout.hasSeenGestureHint", "YES",
            "-deeplink.drillDetail=drill_c029"])
        XCTAssertTrue(app.buttons["bottomTryoutButton"].waitForExistence(timeout: 15))
        app.buttons["bottomTryoutButton"].tap()
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 15))
        let main = app.buttons["dailyClearance.strike"]
        let previous = app.buttons["dailyClearance.undo"]
        let next = app.buttons["dailyClearance.playback"]
        let status = element("composer.status")
        func wait(_ predicate: String, _ item: XCUIElement, timeout: TimeInterval = 45) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: predicate), object: item)], timeout: timeout), .completed)
        }
        func step(_ number: Int) { wait("label CONTAINS '第 \(number)/6 杆'", status) }
        func mainLabel(_ label: String) { wait("label == '\(label)' AND enabled == true", main) }
        func menu() { app.buttons["freeplay.moreMenu"].tap() }
        func closeMenu() { app.buttons["关闭菜单"].tap() }
        app.buttons["tryout.rearrange"].tap()
        step(1); mainLabel("开始")
        XCTAssertFalse(previous.isEnabled); XCTAssertEqual(next.label, "下一杆")
        let stage = element("freeplay.stage").frame
        try capture("tryout-sequence-ready")
        menu()
        let mode = app.buttons["tryout.mode"]
        let aim = app.buttons["dailyClearance.aimModeMenu"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.value as? String, "序列")
        XCTAssertGreaterThan(mode.frame.minY, app.buttons["freeplay.cameraMode"].frame.minY)
        XCTAssertFalse(aim.isEnabled)
        try capture("tryout-sequence-settings")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "自由")
        XCTAssertTrue(aim.isEnabled)
        try capture("tryout-free-settings")
        aim.tap()
        XCTAssertTrue(app.buttons["tryoutAim_自由"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tryoutMode_序列"].exists)
        try capture("tryout-aim-options")
        app.buttons["tryoutAim_自由"].tap()
        closeMenu()
        step(1); mainLabel("击球")
        next.tap(); step(2); mainLabel("击球")
        next.tap(); step(3); previous.tap(); step(2); previous.tap(); step(1)
        XCTAssertFalse(previous.isEnabled)
        mainLabel("击球"); main.tap(); mainLabel("重打")
        try capture("tryout-free-shot-result")
        main.tap(); mainLabel("击球"); step(1)
        try capture("tryout-free-retry")
        next.tap(); step(2)
        menu(); mode.tap(); closeMenu()
        step(1); mainLabel("开始")
        main.tap(); mainLabel("暂停"); main.tap(); mainLabel("继续"); step(1)
        try capture("tryout-sequence-paused")
        next.tap(); mainLabel("继续"); step(2)
        previous.tap(); mainLabel("继续"); step(1)
        XCTAssertFalse(previous.isEnabled)
        next.tap(); mainLabel("继续"); step(2)
        main.tap(); mainLabel("暂停"); main.tap(); mainLabel("继续"); step(3)
        menu(); app.buttons["freeplay.cameraMode"].tap(); closeMenu()
        try capture("tryout-sequence-3D-paused")
        for number in 4...6 {
            next.tap()
            mainLabel(number == 6 ? "重新开始" : "继续")
            if number < 6 { step(number) }
        }
        XCTAssertFalse(next.isEnabled)
        try capture("tryout-sequence-finished")
        // The last result must not vanish under the old 1.2-second automatic reset.
        XCTAssertEqual(main.label, "重新开始")
        previous.tap(); mainLabel("继续"); step(5)
        menu(); mode.tap(); closeMenu()
        step(1); mainLabel("击球")
        XCTAssertFalse(previous.isEnabled)
        XCTAssertEqual(element("freeplay.stage").frame, stage)
        try capture("tryout-mode-reset-first")
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func assertRendererMatchesStage(file: StaticString = #filePath, line: UInt = #line) {
        let stage = element("freeplay.stage").frame
        let renderer = element("table.scene").frame
        XCTAssertGreaterThan(stage.width, 100, file: file, line: line)
        XCTAssertTrue(renderer.contains(CGPoint(x: stage.midX, y: stage.midY)), "renderer=\(renderer), stage=\(stage)", file: file, line: line)
        XCTAssertEqual(renderer.minX, stage.minX, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.minY, stage.minY, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.width, stage.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(renderer.height, stage.height, accuracy: 2, file: file, line: line)
    }
    func testTryoutRendererFollowsStageAfterDetailCameraSwitch() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.drillDetail=drill_c001", "-v54.forceLight", "-dailyLayout.probe", "-drillTryout.hasSeenGestureHint", "YES"])
        let mode = app.buttons["drillScene.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let originalMode = mode.value as? String
        mode.tap()
        XCTAssertNotEqual(mode.value as? String, originalMode)
        mode.tap()
        XCTAssertEqual(mode.value as? String, originalMode)
        // Current phone contract: detail stays portrait and tryout owns landscape.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        app.buttons["bottomTryoutButton"].tap()
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 15))
        try capture("tryout-renderer-entry")
        assertRendererMatchesStage()
        try capture("tryout-renderer-second")
        assertRendererMatchesStage()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        try capture("tryout-renderer-device-portrait"); assertRendererMatchesStage()
        app.buttons["freeplay.moreMenu"].tap()
        let tryoutMode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(tryoutMode.waitForExistence(timeout: 5)); tryoutMode.tap()
        app.buttons["关闭菜单"].tap()
        try capture("tryout-renderer-3d")
        // Perspective uses the full scene viewport; the fitted stage is a 2D contract.
        XCTAssertTrue(element("table.scene").frame.contains(element("freeplay.stage").frame))
        app.buttons["freeplay.moreMenu"].tap(); tryoutMode.tap()
        app.buttons["关闭菜单"].tap()
        assertRendererMatchesStage()
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width }, object: nil)], timeout: 10), .completed)
    }
    private func openPlayPage(_ title: String) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-dailyLayout.probe"])
        app.switchTab(.angle)
        let tab = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5)); tab.tap()
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.buttons["freeplay.moreMenu"].waitForExistence(timeout: 15))
    }
    func testSimulationReadoutAndRenderer() throws {
        continueAfterFailure = false
        openPlayPage("分离角与走位")
        // The assertions below measure the 2D stage; this page remembers its last view.
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        if mode.value as? String != "2D" { mode.tap() }
        XCTAssertEqual(mode.value as? String, "2D")
        app.buttons["关闭菜单"].tap()
        let metric = element("shotSimulation.readout")
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        XCTAssertTrue(metric.label.contains("切角"))
        XCTAssertFalse(metric.label.contains("球形"))
        try capture("p01-readout-portrait")
        assertRendererMatchesStage()
        print("P01 renderer.isHittable=\(element("table.scene").isHittable), frame=\(element("table.scene").frame)")
        let state = element("shotSimulation.landscape")
        let target = app.buttons["paletteBall__2"]
        XCTAssertTrue(target.exists)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.35, thenDragTo: element("table.scene").coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "_2"), object: state)], timeout: 10), .completed)
        try capture("p01-ball-placed-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        try capture("p01-readout-landscape"); assertRendererMatchesStage()
    }
    func testManualBreakSettledActionsAreCentralAndUsable() throws {
        continueAfterFailure = false
        openPlayPage("自由击球")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height }, object: nil)], timeout: 10), .completed)
        app.buttons["break.entry"].tap()
        XCTAssertTrue(app.buttons["break.game.9"].waitForExistence(timeout: 5))
        app.buttons["break.game.9"].tap()
        func ready(_ button: XCUIElement, timeout: TimeInterval = 75) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: button)], timeout: timeout), .completed)
        }
        let strike = app.buttons["break.strike"], confirm = app.buttons["break.confirm"], rerack = app.buttons["break.rerack"]
        ready(strike); strike.tap(); ready(confirm)
        XCTAssertEqual(app.buttons.matching(identifier: "break.confirm").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "break.rerack").count, 1)
        let stage = element("freeplay.stage").frame
        for button in [confirm, rerack] {
            XCTAssertTrue(stage.contains(CGPoint(x: button.frame.midX, y: button.frame.midY)))
            XCTAssertEqual(button.frame.midX, stage.midX, accuracy: stage.width * 0.15)
            XCTAssertEqual(button.frame.midY, stage.midY, accuracy: 2)
        }
        let actions = confirm.frame.union(rerack.frame)
        XCTAssertEqual(actions.midX, stage.midX, accuracy: stage.width * 0.08)
        XCTAssertEqual(actions.midY, stage.midY, accuracy: stage.height * 0.15)
        try capture("p02-settled-central-actions")
        // The old side controls disallowed actions while temporarily observing from above.
        // Moving them to the table center must preserve the same gate and recovery path.
        app.buttons["freeplay.moreMenu"].tap()
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
        app.buttons["关闭菜单"].tap()
        let temporary = app.buttons["shotCamera.temporaryTopDown"]
        ready(temporary); temporary.tap()
        XCTAssertFalse(confirm.isEnabled); XCTAssertFalse(rerack.isEnabled)
        try capture("p02-settled-temporary-disabled")
        temporary.tap(); ready(confirm); ready(rerack)
        try capture("p02-settled-temporary-return")
        rerack.tap(); ready(strike)
        XCTAssertFalse(confirm.exists)
        try capture("p02-reracked")
        strike.tap(); ready(confirm); confirm.tap()
        XCTAssertTrue(element("freeplay.gameStatus").waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
        try capture("p02-confirmed")
    }

}

final class TablePreferencesUITests: XCTestCase {
    func testCustomChoicesAndNativeSwitchEvidence() throws {
        continueAfterFailure = false
        launch("settings")
        XCTAssertTrue(app.switches["settings.grid"].waitForExistence(timeout: 15))
        try capture("native-switches-preserved")
        let room = app.buttons["settings.roomStyle"]
        for _ in 0..<8 where !room.isHittable { app.scrollViews["settings.content"].swipeUp() }
        XCTAssertTrue(room.isHittable); room.tap()
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings.roomStyle."))
        XCTAssertGreaterThan(options.count, 1)
        let unselected = options.allElementsBoundByIndex.first { $0.value as? String == "未选择" }!
        unselected.tap()
        XCTAssertEqual(unselected.value as? String, "已选择")
        XCTAssertTrue(unselected.images["checkmark"].waitForExistence(timeout: 5),
                      "The selected row must render its checkmark, not only update its accessibility value")
        try capture("room-style-choices")
    }

    private var app: XCUIApplication!
    private func launch(_ route: String) {
        app?.terminate()
        XCUIDevice.shared.orientation = route == "settings" ? .portrait : .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture",
            "-forcePremium", "-v51.followSystemAppearance",
            route.hasPrefix("shared:") ? "-dailyInteraction.sharedPage=" + route.dropFirst(7) : "-deeplink." + route])
    }
    private func openMenu() {
        if app.buttons["dailyClearance.menuBack"].exists {
            app.buttons["dailyClearance.menuBack"].tap()
        }
        if app.scrollViews["dailyClearance.menuScroll"].exists { return }
        let more = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(more.waitForExistence(timeout: 15)); more.tap()
        XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout: 5))
    }
    private func assertMode(_ mode: String) {
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, mode)
    }
    private func capture(_ name: String) throws {
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let root = ProcessInfo.processInfo.environment["TABLE_PREFERENCES_OUTPUT"].map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("output/profile-settings-20261017/implementation/ui")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try image.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
    }
    func testSharedTeachingPagesAndPreviewRememberIndependentViews() throws {
        continueAfterFailure = false
        launch("settings")
        XCTAssertTrue(app.buttons["3D"].waitForExistence(timeout: 15)); app.buttons["3D"].tap()
        let routes = [("silu", "silu"), ("planThree", "planthree"), ("snooker", "snooker"),
            ("shared:bank", "bankshot"), ("shared:diamond", "reflection"),
            ("shared:angleDynamic", "angleDynamic"), ("shared:separation", "separationAngleAtlas"),
            ("shared:cushion", "cushionEnglishAtlas"), ("shared:composer", "freeplay"), ("shared:shot", "freeplay")]
        for (route, id) in routes {
            func menu() {
                let more = app.buttons[id == "freeplay" ? "freeplay.moreMenu" : id + ".more"]
                XCTAssertTrue(more.waitForExistence(timeout: 20), route)
                // The landscape header can have a fractional negative origin; its visible center remains tappable.
                more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                XCTAssertTrue(app.buttons[id + ".cameraMode"].waitForExistence(timeout: 5), route)
            }
            launch(route); menu()
            XCTAssertEqual(app.buttons[id + ".cameraMode"].value as? String, "3D", route)
            app.buttons[id + ".cameraMode"].tap()
            XCTAssertEqual(app.buttons[id + ".cameraMode"].value as? String, "2D", route)
            launch(route); menu()
            XCTAssertEqual(app.buttons[id + ".cameraMode"].value as? String, "2D", route)
            try capture("memory-" + id + (route == "shared:shot" ? "-shot" : ""))
        }
        launch("drillDetail=drill_c001")
        let camera = app.buttons["drillScene.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 20))
        XCTAssertEqual(camera.value as? String, "3D")
        camera.tap(); XCTAssertEqual(camera.value as? String, "2D")
        launch("drillDetail=drill_c001")
        XCTAssertTrue(camera.waitForExistence(timeout: 20)); XCTAssertEqual(camera.value as? String, "2D")
        try capture("memory-detail-preview")
    }

    func testViewMemoryIsolationAndSameValueReapply() throws {
        continueAfterFailure = false
        launch("settings")
        XCTAssertTrue(app.buttons["2D"].waitForExistence(timeout: 15)); app.buttons["2D"].tap()
        let grid = app.switches["settings.grid"]
        if grid.value as? String == "1" { grid.tap() }
        app.buttons["settings.reapply"].tap()
        let applyGrid = app.buttons["台面网格 4×8 · 关闭"].firstMatch
        XCTAssertTrue(applyGrid.waitForExistence(timeout: 5)); applyGrid.tap()
        try capture("settings-initial")
        launch("freePlay"); openMenu(); assertMode("2D")
        app.buttons["freeplay.cameraMode"].tap(); assertMode("3D")
        app.buttons["menu.tableGrid"].tap()
        openMenu()
        XCTAssertEqual(app.buttons["menu.tableGrid"].value as? String, "已选")
        try capture("freeplay-3d-local-grid")
        launch("freePlay"); openMenu(); assertMode("3D")
        XCTAssertEqual(app.buttons["menu.tableGrid"].value as? String, "已选")
        launch("dailyClearance"); openMenu(); assertMode("2D")
        XCTAssertNotEqual(app.buttons["menu.tableGrid"].value as? String, "已选")
        launch("settings"); app.buttons["2D"].tap() // same general value must overwrite local 3D
        app.buttons["settings.reapply"].tap()
        app.buttons["台面网格 4×8 · 关闭"].firstMatch.tap()
        launch("freePlay"); openMenu(); assertMode("2D")
        XCTAssertNotEqual(app.buttons["menu.tableGrid"].value as? String, "已选")
        try capture("freeplay-after-same-value-override")
    }
    func testLocalTrajectoryHiddenMemoryAndGlobalSameDetailUnhides() throws {
        continueAfterFailure = false
        func generalFull() {
            launch("settings")
            XCTAssertTrue(app.buttons["3D"].waitForExistence(timeout: 15)); app.buttons["3D"].tap()
            let field = app.buttons["settings.trajectory"]
            for _ in 0..<5 where !field.isHittable { app.scrollViews["settings.content"].swipeUp() }
            field.tap(); app.buttons["轨迹·全"].firstMatch.tap()
        }
        func trajectoryMenu() {
            let field = app.buttons["dailyClearance.trajectoryMenu"]
            for _ in 0..<5 where !field.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            field.tap()
            XCTAssertTrue(app.buttons["dailyClearance.trajectory.2"].waitForExistence(timeout: 5))
        }
        generalFull()
        launch("freePlay"); openMenu(); trajectoryMenu()
        app.buttons["dailyClearance.trajectory.2"].tap()
        openMenu(); trajectoryMenu(); app.buttons["dailyClearance.trajectory.3"].tap()
        launch("freePlay"); openMenu(); trajectoryMenu()
        XCTAssertEqual(app.buttons["dailyClearance.trajectory.3"].value as? String, "已选")
        try capture("trajectory-local-hidden-restored")
        launch("shared:shot"); openMenu(); trajectoryMenu()
        XCTAssertEqual(app.buttons["dailyClearance.trajectory.0"].value as? String, "已选")
        generalFull() // reselect the same global detail: also clears the local hidden state
        launch("freePlay"); openMenu(); trajectoryMenu()
        XCTAssertEqual(app.buttons["dailyClearance.trajectory.0"].value as? String, "已选")
        XCTAssertNotEqual(app.buttons["dailyClearance.trajectory.3"].value as? String, "已选")
        try capture("trajectory-global-full-unhides")
    }

    func testGeneralSettingsReachabilityAndTrajectoryReapply() throws {
        continueAfterFailure = false
        launch("settings")
        XCTAssertTrue(app.buttons["settings.reapply"].waitForExistence(timeout: 15))
        try capture("settings-top")
        let scroll = app.scrollViews["settings.content"]
        let trajectory = app.buttons["settings.trajectory"]
        for _ in 0..<5 where !trajectory.isHittable { scroll.swipeUp() }
        XCTAssertTrue(trajectory.isHittable); trajectory.tap()
        let full = app.buttons["轨迹·全"].firstMatch
        XCTAssertTrue(full.waitForExistence(timeout: 5)); full.tap()
        XCTAssertEqual(app.switches["settings.trajectory3D"].value as? String, "1")
        try capture("settings-trajectory")
        let rehearsal = app.switches["settings.cueRehearsal"]
        for _ in 0..<5 where !rehearsal.isHittable { scroll.swipeUp() }
        XCTAssertTrue(rehearsal.isHittable)
        try capture("settings-assists")
        for _ in 0..<8 { scroll.swipeUp() }
        try capture("settings-bottom")
    }
}
