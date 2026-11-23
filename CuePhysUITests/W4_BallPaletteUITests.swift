import XCTest

/// Exercises the production palette, including its SwiftUI gesture and the active renderer.
final class PaletteCameraModesUITests: XCTestCase {
    private var app: XCUIApplication!
    private var page = ""
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func wait(_ condition: @escaping () -> Bool, _ message: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() }, object: nil)], timeout: 40), .completed, message)
    }
    private func ready(_ item: XCUIElement) {
        wait({ item.exists && item.isEnabled && item.isHittable }, "Control unavailable: \(item)")
    }
    private func probe() throws -> [String: Any] {
        let raw = try XCTUnwrap(element("table.scene").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func balls() throws -> [[String: Any]] { try XCTUnwrap(probe()["balls"] as? [[String: Any]]) }
    private func matches(_ row: [String: Any], _ key: String) -> Bool {
        // Formation editors preserve an instance suffix; the library groups by ball number.
        (row["key"] as? String)?.split(separator: "@").first.map(String.init) == key
    }
    private func contains(_ key: String) -> Bool { (try? balls().contains { matches($0, key) }) == true }
    private func capture(_ name: String) throws {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = page + "-" + name; shot.lifetime = .keepAlways; add(shot)
        let data = try JSONSerialization.data(withJSONObject: probe(), options: [.sortedKeys, .prettyPrinted])
        let state = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        state.name = page + "-" + name + "-state"; state.lifetime = .keepAlways; add(state)
    }
    private func launch(_ route: String) throws {
        app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        page = ["bank": "bankshot", "diamond": "reflection", "separation": "separationAngleAtlas",
                "cushion": "cushionEnglishAtlas", "formation": "freeplay", "composer": "freeplay", "shot": "freeplay"][route] ?? route
        var args = ["-forcePremium", "-v50.inMemoryStore", "-3dDrag.probe", "-freeLayout.ephemeral"]
        if ["silu", "planthree"].contains(route) {
            args += ["-deeplink." + (route == "planthree" ? "planThree" : route)]
        } else if route == "formation" {
            args += ["-deeplink.customFormation", "-customFormation.owner=palette-\(UUID())"]
        } else { args += ["-dailyInteraction.sharedPage=" + route] }
        app = .launchClean(extraArgs: args)
        if route == "formation" {
            ready(app.buttons["formation.new"]); app.buttons["formation.new"].tap()
        }
        XCTAssertTrue(element("table.scene").waitForExistence(timeout: 45))
        if route == "formation" {
            ready(app.buttons["paletteBall__1"]); app.buttons["paletteBall__1"].tap()
            wait({ self.contains("_1") }, "Initial editable target")
            for key in ["_12", "_13", "_14", "_15"] {
                app.buttons["paletteBall_" + key].tap()
                wait({ self.contains(key) }, "Template ball created")
            }
            app.buttons["formation.edit.save"].tap()
            let save = app.alerts["保存模板"].buttons.matching(identifier: "formation.save.confirm").element(boundBy: 0)
            ready(save); save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            ready(app.buttons["formation.start"]); app.buttons["formation.start"].tap()
            XCTAssertTrue(element("table.scene").waitForExistence(timeout: 45))
            // The arrangement editor is 2D-only. Exercise the actual 2D/3D practice host,
            // returning its existing template instances to the library before restoring them.
            try setMode("2D")
            for key in ["_12", "_13", "_14", "_15"] { try returnToLibrary(key) }
        }
        try setMode("3D")
    }
    private func returnToLibrary(_ key: String) throws {
        let ball = try XCTUnwrap(try balls().first { matches($0, key) })
        let p = try XCTUnwrap(ball["screen"] as? [Double])
        element("table.scene").coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: p[0], dy: p[1]))
            .press(forDuration: 0.2, thenDragTo: app.buttons["paletteBall_" + key]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                withVelocity: 180, thenHoldForDuration: 0.4)
        wait({ !self.contains(key) }, "Ball returned to library")
    }
    private func setMode(_ mode: String) throws {
        let more = app.buttons[page + (page == "freeplay" ? ".moreMenu" : ".more")]
        ready(more); more.tap()
        let toggle = app.buttons[page + ".cameraMode"]; ready(toggle)
        if toggle.value as? String != mode { toggle.tap() }
        let close = page == "freeplay" ? app.buttons["关闭菜单"] : app.buttons[page + ".dismissMenu"]
        ready(close)
        close.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
        wait({ (try? self.probe()["diagramSurface"] as? String) == "main" }, "Main scene ready")
    }
    private func tapAdd(_ key: String, name: String) throws {
        XCTAssertFalse(contains(key))
        let ball = app.buttons["paletteBall_" + key]; ready(ball)
        ball.tap()
        // Capture even on the unfixed build, before the postcondition times out.
        try capture(name + "-tap")
        wait({ self.contains(key) }, "Tapping must add \(key) in \(name)")
    }
    private func dragAdd(_ key: String, name: String) throws {
        XCTAssertFalse(contains(key))
        let ball = app.buttons["paletteBall_" + key]; ready(ball)
        let table = element("table.scene")
        let current = try balls()
        // Use a real visible ball projection, not a guessed perspective table rectangle.
        // Formation's automatic target positions start by a corner pocket. Prefer the cue
        // in the table interior so a screen-space offset does not cross the far cushion.
        let anchors = current.filter { $0["key"] as? String == "cueBall" }
            + current.filter { $0["key"] as? String != "cueBall" }
        let anchor = try XCTUnwrap(anchors.first { row in
            guard let p = row["screen"] as? [Double] else { return false }
            return p[0] > 80 && p[0] < table.frame.width - 80 && p[1] > 70 && p[1] < table.frame.height - 100
        })
        let point = try XCTUnwrap(anchor["screen"] as? [Double])
        let diameter = try XCTUnwrap(anchor["diameter"] as? Double)
        let offsets: [(Double, Double)] = [(3, 0), (-3, 0), (0, 3), (0, -3)]
        var emptyPoint: CGPoint?
        for offset in offsets {
            let x = point[0] + offset.0 * diameter
            let y = point[1] + offset.1 * diameter
            guard x > 80, x < Double(table.frame.width) - 80,
                  y > 70, y < Double(table.frame.height) - 100 else { continue }
            var overlaps = false
            for row in current {
                guard let p = row["screen"] as? [Double], let d = row["diameter"] as? Double else {
                    overlaps = true; break
                }
                if hypot(x - p[0], y - p[1]) <= 1.6 * max(diameter, d) {
                    overlaps = true; break
                }
            }
            if !overlaps { emptyPoint = CGPoint(x: x, y: y); break }
        }
        let drop = try XCTUnwrap(emptyPoint,
            "Choose an empty visible spot: overlap-rejecting pages must keep their business constraint")
        let end = table.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: drop.x, dy: drop.y + 52))
        ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: end, withVelocity: 180, thenHoldForDuration: 0.4)
        if !contains(key) { try capture(name + "-rejected-drop") }
        wait({ self.contains(key) }, "Dragging must add \(key) in \(name)")
        let result = try probe()
        let preview = try XCTUnwrap(result["palettePlacement"] as? [String: Any])
        XCTAssertTrue(matches(preview, key))
        let expected = try XCTUnwrap(preview["world"] as? [Double])
        let actualBall = try XCTUnwrap(try balls().first { matches($0, key) })
        let actual = try XCTUnwrap(actualBall["world"] as? [Double])
        for axis in 0..<3 { XCTAssertEqual(actual[axis], expected[axis], accuracy: 0.001, "Drop must match visible preview") }
        try capture(name + "-drag")
    }
    private func exercise(_ route: String) throws {
        try launch(route)
        if route == "shot" {
            try setMode("2D"); try returnToLibrary("_8"); try setMode("3D")
        }
        try capture("before-3D")
        try tapAdd("_12", name: "3D")
        try dragAdd("_13", name: "3D")
        if route == "shot" {
            // This legacy host permits two targets. Preserve that cap and free slots before testing the next mode.
            app.buttons["paletteBall__14"].tap()
            try capture("3D-full-cap")
            XCTAssertFalse(contains("_14"))
            try setMode("2D")
            try returnToLibrary("_12"); try returnToLibrary("_13")
            try setMode("3D")
        }
        let top = app.buttons["shotCamera.temporaryTopDown"]
        // This object-only page deliberately offers global/target observation, without a temporary view.
        if route == "pocketTolerance" {
            XCTAssertFalse(top.exists)
            try setMode("2D")
            try tapAdd("_14", name: "2D")
            try dragAdd("_15", name: "2D")
        } else {
            ready(top); top.tap()
            wait({ (try? self.probe()["diagramSurface"] as? String) == "temporaryTopDown" }, "Temporary renderer visible")
            try tapAdd("_14", name: "temporary")
            try dragAdd("_15", name: "temporary")
        }
        let before = try balls()
        if route != "pocketTolerance" { top.tap() }
        wait({ (try? self.probe()["diagramSurface"] as? String) == "main" }, "Return to perspective")
        try setMode("2D")
        let after = try balls()
        for key in (route == "shot" ? ["_14", "_15"] : ["_12", "_13", "_14", "_15"]) {
            let original = try XCTUnwrap(before.first { matches($0, key) })
            let a = try XCTUnwrap(original["world"] as? [Double])
            let b = try XCTUnwrap(after.first { $0["key"] as? String == original["key"] as? String }?["world"] as? [Double])
            for axis in 0..<3 { XCTAssertEqual(a[axis], b[axis], accuracy: 0.0001) }
        }
        try capture("returned-2D")
    }
    func testComposer() throws { try exercise("composer") }
    func testShotSimulation() throws { try exercise("shot") }
    func testAngleDynamic() throws { try exercise("angleDynamic") }
    func testSeparationAtlas() throws { try exercise("separation") }
    func testCushionAtlas() throws { try exercise("cushion") }
    func testPocketTolerance() throws { try exercise("pocketTolerance") }
    func testSilu() throws { try exercise("silu") }
    func testPlanThree() throws { try exercise("planthree") }
    func testBank() throws { try exercise("bank") }
    func testDiamond() throws { try exercise("diamond") }
    func testFormation() throws { try exercise("formation") }
}

/// v7 W4：球库拖球放置 / 拖回删球 / pulse 取证。
/// 截图写入 `build/w4-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
final class W4_BallPaletteUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w4-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func paletteBall(_ app: XCUIApplication, _ key: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "paletteBall_\(key)")).firstMatch
    }

    private func openCard(app: XCUIApplication, homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        let seg = app.buttons["angleHomeTab_\(homeTab)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000)
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    /// Composer：拖 9 号上桌 → 截图 → 点库内 9 号 pulse → 再拖回球库删球。
    func testV63ComposerPlacementSurvivesObservation() {
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        XCTAssertTrue(openCard(app: app, homeTab: "走位", title: "自由走位"))
        let ball9 = paletteBall(app, "_9")
        XCTAssertTrue(ball9.waitForExistence(timeout: 8))
        // Keep the placed ball clear of the default 1-ball. The previous point
        // overlapped its pickup area after collision-safe placement adjusted 9.
        // Verify ball identity in the placed/returned/removed attachments.
        let destination = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.30))
        ball9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: destination)
        sleep(1)
        snap(app, "v63-composer-9-placed")
        destination.tap()
        snap(app, "v63-composer-9-selected")
        let camera = app.buttons["composer.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5))
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        sleep(1)
        snap(app, "v63-composer-9-observed")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        sleep(1)
        snap(app, "v63-composer-9-returned")
        destination.press(forDuration: 0.35,
                          thenDragTo: ball9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                          withVelocity: .default, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.staticTexts["已移回球库"].waitForExistence(timeout: 2),
                      "拖回操作必须触发移除；仍需核对截图中的球号，不能只凭导航通过")
        sleep(1)
        snap(app, "v63-composer-9-removed")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        app.buttons["composer.more"].tap()
        app.buttons["清空桌面"].tap()
        sleep(1)
        snap(app, "v63-composer-cleared-3d")
        XCTAssertFalse(app.buttons["击球"].isEnabled)
        XCTAssertTrue(app.staticTexts["—°"].exists, "空桌不能显示上一杆角度")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        snap(app, "v63-composer-cleared-2d")
        app.buttons["composer.more"].tap()
        app.buttons["清空并重来"].tap()
        let dismissPopover = app.otherElements["PopoverDismissRegion"]
        if dismissPopover.waitForExistence(timeout: 1) {
            dismissPopover.tap()
        } else {
            XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 3))
            app.buttons["取消"].tap()
        }
        XCTAssertFalse(app.buttons["击球"].isEnabled)
        snap(app, "v63-composer-reset-cancelled")
        app.buttons["composer.more"].tap()
        app.buttons["清空并重来"].tap()
        let confirmReset = app.buttons["清空并重来"]
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 3))
        confirmReset.tap()
        sleep(1)
        snap(app, "v63-composer-reset-default")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["自由走位"].waitForExistence(timeout: 5))
    }

    func testW4ComposerDragPlacePulseRemove() {
        let app = XCUIApplication.launchClean()
        guard openCard(app: app, homeTab: "走位", title: "自由走位") else {
            XCTFail("未能进入自由走位"); return
        }
        snap(app, "w4-composer-01-initial")

        let ball9 = paletteBall(app, "_9")
        XCTAssertTrue(ball9.waitForExistence(timeout: 8), "球库应有 9 号")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        ball9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "w4-composer-02-after-place")

        // pulse：再点库内已上桌的 9 号
        if ball9.exists {
            ball9.tap()
            usleep(500_000)
            snap(app, "w4-composer-03-after-pulse")
        }

        // 拖回删球：从台面中部拖向底部球库带
        let fromTable = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        let toPalette = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.92))
        fromTable.press(forDuration: 0.35, thenDragTo: toPalette)
        sleep(2)
        snap(app, "w4-composer-04-after-drag-back")
    }

    /// Snooker：拖球放置 + pulse。

    /// Extraction：经 `-extract.confirmDemo` 直进确认步，拖球放置 + pulse + 拖回删球取证。
    func testW4ExtractionPaletteInteraction() {
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-extract.confirmDemo"])
        guard openCard(app: app, homeTab: "走位", title: "拍照建球形") else {
            XCTFail("未能进入拍照建球形"); return
        }
        snap(app, "w4-extraction-01-entry")

        let ball1 = paletteBall(app, "_1")
        XCTAssertTrue(ball1.waitForExistence(timeout: 8), "确认步应有交互球库（-extract.confirmDemo）")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40))
        ball1.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "w4-extraction-02-after-place")
        if ball1.exists {
            ball1.tap()
            usleep(500_000)
            snap(app, "w4-extraction-03-after-pulse")
        }
        // 拖回删球：台面中部 → 底部球库带
        let fromTable = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40))
        let toPalette = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.93))
        fromTable.press(forDuration: 0.35, thenDragTo: toPalette)
        sleep(2)
        snap(app, "w4-extraction-04-after-drag-back")
    }
}
