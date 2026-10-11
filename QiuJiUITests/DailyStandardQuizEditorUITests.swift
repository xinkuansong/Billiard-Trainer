import XCTest

/// C2 regression uses real navigation and interactions; it never saves a batch archive.
final class DailyStandardQuizEditorUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
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
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
            let audit = element("batch.nudgeAudit")
            if audit.exists, let trace = audit.value as? String {
                try trace.write(to: folder.appendingPathComponent(name + "-gesture.txt"), atomically: true, encoding: .utf8)
            }
        }
    }
    private func assertControls(file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        for id in ["batch.back", "batch.more", "batch.tool", "shotStage.spinEntry"] {
            let control = app.buttons[id]
            XCTAssertTrue(control.isHittable, id, file: file, line: line)
            XCTAssertTrue(window.contains(control.frame), "\(id): \(control.frame)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44, id, file: file, line: line)
        }
        let scene = element("table.scene").frame
        let table = element("batch.tableBounds").frame
        XCTAssertGreaterThan(table.height, 100, file: file, line: line)
        XCTAssertTrue(window.contains(table), "table=\(table) window=\(window)", file: file, line: line)
        XCTAssertTrue(scene.contains(table), "table=\(table) scene=\(scene)", file: file, line: line)
        if window.width > window.height {
            XCTAssertGreaterThan(table.width, table.height, file: file, line: line)
        } else {
            XCTAssertGreaterThan(table.height, table.width, file: file, line: line)
        }
        for number in 1...15 {
            let ball = app.buttons["paletteBall__\(number)"]
            XCTAssertTrue(ball.exists, "ball \(number)", file: file, line: line)
            XCTAssertTrue(window.contains(ball.frame), file: file, line: line)
            // The shared header reserves a 44 pt hit slot around a shorter visible capsule.
            // The visible lower edge is reviewed in native images; AX H is not V.
            XCTAssertLessThan(ball.frame.midY, table.minY, file: file, line: line)
        }
    }
    private func selectTool(_ title: String) {
        let tool = app.buttons["batch.tool"]
        if element("batch.toolScroll").exists { _ = revealEditor("batch.tool") }
        XCTAssertTrue(tool.isHittable); tool.tap()
        let choice = app.buttons["batch.tool.\(title)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 3)); choice.tap()
    }
    private func revealMenuItem(_ id: String) -> XCUIElement {
        let item = app.buttons[id]
        let scroll = element("dailyClearance.menuScroll")
        for _ in 0..<16 where !item.exists || !scroll.frame.contains(item.frame) {
            let above = item.exists && item.frame.minY < scroll.frame.minY
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.35 : 0.65))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.65 : 0.35))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        if !item.exists || !scroll.frame.contains(item.frame) { try? capture("missing-menu-" + id) }
        XCTAssertTrue(item.exists && scroll.frame.contains(item.frame), id)
        return item
    }
    private func closeRootMenu() {
        // The shared C51 root menu has no title row; dismiss via its outside shield.
        // Nested menus have a header close button, but root intentionally does not.
        let shield = app.buttons["batch.dismissMenu"]
        XCTAssertTrue(shield.exists)
        shield.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        XCTAssertFalse(element("dailyClearance.menuPanel").exists)
        XCTAssertTrue(element("table.scene").exists, "Outside dismissal must not leave the editor")
    }
    private func inspectSaveMenu(_ state: String) throws {
        app.buttons["batch.more"].tap()
        for (id, label) in [("batch.saveImage", "保存并选择下一张图"), ("batch.saveDrill", "保存并进入下一个练习")] {
            let control = revealMenuItem(id)
            XCTAssertEqual(control.label, label)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(control.frame))
        }
        try capture(state + "-save-menu")
        closeRootMenu()
    }
    private func ballWorld(_ key: String) -> CGPoint {
        let raw = element("batch.ball." + key).value as? String ?? ""
        let components = raw.split(separator: ";").map { Double($0.split(separator: "=").last ?? "") ?? .nan }
        XCTAssertEqual(components.count, 2, raw)
        return components.count == 2 ? CGPoint(x: components[0], y: components[1]) : .zero
    }
    private func revealEditor(_ id: String) -> XCUIElement {
        let item = app.buttons[id]
        let scroll = element("batch.toolScroll")
        for _ in 0..<16 where !item.exists || !scroll.frame.contains(item.frame) {
            let before = element("batch.ball._1").exists ? ballWorld("_1") : nil
            let above = item.exists && item.frame.minY < scroll.frame.minY
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.65))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.65 : 0.35))
            start.press(forDuration: 0.1, thenDragTo: end)
            if let before {
                let after = ballWorld("_1")
                XCTAssertEqual(after.x, before.x, accuracy: 0.000001, "Scrolling tools must not nudge a ball")
                XCTAssertEqual(after.y, before.y, accuracy: 0.000001, "Scrolling tools must not nudge a ball")
            }
        }
        if !item.isHittable || !scroll.frame.contains(item.frame) { try? capture("missing-editor-" + id) }
        XCTAssertTrue(item.isHittable && scroll.frame.contains(item.frame), id)
        return item
    }
    private func verifyNudgeAndSwap(_ state: String) throws {
        let ball = element("batch.ball._1")
        XCTAssertTrue(ball.waitForExistence(timeout: 4))
        ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        for (direction, dx, dy) in [("up", 0.0, -1.0), ("down", 0.0, 1.0), ("left", -1.0, 0.0), ("right", 1.0, 0.0)] {
            let button = revealEditor("batch.nudge." + direction)
            let before = ballWorld("_1")
            let portrait = app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
            button.tap()
            let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let now = self.ballWorld("_1")
                return hypot(now.x - before.x, now.y - before.y) > 0.0001
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 4), .completed)
            let after = ballWorld("_1")
            XCTAssertEqual(hypot(after.x - before.x, after.y - before.y), 0.0005, accuracy: 0.00001)
            // Native 0.5 mm is subpixel at table scale. Assert the independent camera-axis contract
            // in world metres rather than rounding AX screen bounds into a false failure.
            let worldDX = after.x - before.x, worldDZ = after.y - before.y
            let screenDX = portrait ? worldDZ : worldDX
            let screenDY = portrait ? -worldDX : worldDZ
            XCTAssertGreaterThan(screenDX * dx + screenDY * dy, 0, direction)
        }
        let held = revealEditor("batch.nudge.up")
        let beforeHold = ballWorld("_1")
        try capture(state + "-before-hold")
        held.press(forDuration: 0.65)
        let repeated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let now = self.ballWorld("_1")
            return hypot(now.x - beforeHold.x, now.y - beforeHold.y) > 0.0005
        }, object: nil)
        let holdResult = XCTWaiter.wait(for: [repeated], timeout: 3)
        if holdResult != .completed { try capture(state + "-hold-failed") }
        XCTAssertEqual(holdResult, .completed, "Long press changes the real ball marker")
        let afterHold = ballWorld("_1")
        let distance = hypot(afterHold.x - beforeHold.x, afterHold.y - beforeHold.y)
        XCTAssertGreaterThan(distance, 0.0005, "Long press still repeats")
        XCTAssertEqual(distance / 0.0005, (distance / 0.0005).rounded(), accuracy: 0.02)
        let drift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let now = self.ballWorld("_1")
            return hypot(now.x - afterHold.x, now.y - afterHold.y) > 0.000001
        }, object: nil)
        drift.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [drift], timeout: 0.4), .completed, "Release stops repetition")
        try capture(state + "-nudge")
        let cueBefore = ballWorld("cueBall"), targetBefore = ballWorld("_1")
        // Twice restores the comparison fixture while proving true one-shot exchanges.
        for _ in 0..<2 {
            let cue = ballWorld("cueBall"), target = ballWorld("_1")
            revealEditor("batch.swap").tap()
            ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let exchanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let now = self.ballWorld("cueBall")
                return hypot(now.x - target.x, now.y - target.y) < 0.00001
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [exchanged], timeout: 4), .completed)
            let now = ballWorld("_1")
            XCTAssertEqual(now.x, cue.x, accuracy: 0.00001); XCTAssertEqual(now.y, cue.y, accuracy: 0.00001)
        }
        XCTAssertEqual(ballWorld("cueBall").x, cueBefore.x, accuracy: 0.00001)
        XCTAssertEqual(ballWorld("_1").y, targetBefore.y, accuracy: 0.00001)
    }
    private func verifyGuide() throws {
        selectTool("摆球")
        revealEditor("batch.guide").tap()
        XCTAssertFalse(app.buttons["batch.guideConfirm"].isEnabled)
        let table = element("batch.playingBounds")
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.25)).tap()
        XCTAssertTrue(app.buttons["batch.guideConfirm"].isEnabled)
        try capture("batch-author-guide-start")
        app.buttons["batch.guideConfirm"].tap()
        XCTAssertFalse(app.buttons["batch.guideConfirm"].isEnabled)
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.75)).tap()
        XCTAssertTrue(app.buttons["batch.guideConfirm"].isEnabled)
        try capture("batch-author-guide-end")
        app.buttons["batch.guideConfirm"].tap()
        XCTAssertFalse(app.buttons["batch.guideConfirm"].exists)
        try capture("batch-author-guide-placed")
        revealEditor("batch.guide").tap()
        XCTAssertEqual(app.buttons["batch.guide"].label, "辅助线")
        app.buttons["batch.guide"].tap()
        app.buttons["batch.guideCancel"].tap()
        XCTAssertFalse(app.buttons["batch.guideConfirm"].exists)
    }
    private func rotate(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let landscape = orientation == .landscapeLeft
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let f = self.app.windows.firstMatch.frame
            return landscape ? f.width > f.height : f.height > f.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
        if element("batch.tableBounds").exists { waitForStableBatchLayout() }
    }
    private func waitForStableBatchLayout() {
        var previous: [CGRect] = []
        var unchangedSince = Date()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frames = [self.app.windows.firstMatch.frame, self.element("batch.tableBounds").frame,
                          self.element("batch.playingBounds").frame, self.app.buttons["batch.more"].frame]
            guard frames.allSatisfy({ $0.width > 0 && $0.height > 0 }), frames[0].contains(frames[1]) else { return false }
            if frames != previous { previous = frames; unchangedSince = Date(); return false }
            return Date().timeIntervalSince(unchangedSince) >= 0.8
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed, "Capture only after rotation and layout settle")
    }
    func testBatchControlsNoticeAndRotationWithoutSaving() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-batchAuthor.markers"])
        app.switchTab(.angle)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("批量出片台")
        app.buttons["批量出片台"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "drill_c065")).firstMatch
        for _ in 0..<50 where !row.isHittable {
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(row.isHittable); row.tap()
        let plus = app.staticTexts["+ 新增球形"]
        XCTAssertTrue(plus.waitForExistence(timeout: 8)); plus.tap()
        app.buttons["空台面（仅母球）"].tap()
        XCTAssertTrue(element("table.scene").waitForExistence(timeout: 12))
        XCTAssertFalse(element("batch.nudgeAudit").exists, "Final checks run without gesture event tracing")
        if UIDevice.current.userInterfaceIdiom != .pad {
            let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = self.app.windows.firstMatch.frame
                return frame.width > frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 10), .completed)
        }
        waitForStableBatchLayout()
        try capture("batch-author-empty"); assertControls()
        try inspectSaveMenu("batch-author")
        let scene = element("table.scene").frame
        let swap = app.buttons["batch.swap"]
        for _ in 0..<8 where !swap.isHittable { element("batch.toolScroll").swipeUp() }
        XCTAssertTrue(swap.isHittable); swap.tap()
        let notice = element("batch.notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 2))
        XCTAssertTrue(scene.contains(notice.frame), "notice=\(notice.frame), scene=\(scene)")
        try capture("batch-author-notice")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: notice)], timeout: 4), .completed)
        app.buttons["batch.swap"].tap()
        selectTool("摆球")
        let ball = app.buttons["paletteBall__1"]
        ball.tap(); XCTAssertEqual(ball.value as? String, "在桌上")
        try capture("batch-author-arrange")
        try verifyNudgeAndSwap("batch-author")
        selectTool("摆球")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let portraitCue = ballWorld("cueBall"), portraitTarget = ballWorld("_1")
            rotate(.landscapeLeft); assertControls(); try capture("batch-author-landscape")
            XCTAssertEqual(ball.value as? String, "在桌上")
            XCTAssertTrue(app.buttons["batch.tool"].label.contains("摆球"))
            XCTAssertEqual(ballWorld("cueBall").x, portraitCue.x, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("cueBall").y, portraitCue.y, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("_1").x, portraitTarget.x, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("_1").y, portraitTarget.y, accuracy: 0.000001)
            try inspectSaveMenu("batch-author-landscape")
            try verifyNudgeAndSwap("batch-author-landscape")
            selectTool("摆球")
            let landscapeCue = ballWorld("cueBall"), landscapeTarget = ballWorld("_1")
            rotate(.portrait); assertControls(); try capture("batch-author-portrait-return")
            XCTAssertEqual(ball.value as? String, "在桌上")
            XCTAssertEqual(ballWorld("cueBall").x, landscapeCue.x, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("cueBall").y, landscapeCue.y, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("_1").x, landscapeTarget.x, accuracy: 0.000001)
            XCTAssertEqual(ballWorld("_1").y, landscapeTarget.y, accuracy: 0.000001)
        } else {
            // User 2026-10-09 explicitly replaces the earlier portrait contract.
            XCUIDevice.shared.orientation = .portrait
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            assertControls(); try capture("batch-author-phone-landscape")
        }
        for tool in ["落区", "落点", "过点"] {
            selectTool(tool)
            let table = element("batch.playingBounds")
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.36))
            let end = table.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.64))
            start.press(forDuration: 0.1, thenDragTo: end)
            XCTAssertTrue(app.buttons["batch.solve"].isEnabled, "\(tool) screen gesture reaches world constraint")
            try capture("batch-author-constraint-" + tool)
            app.buttons["batch.clearConstraint"].tap()
            XCTAssertFalse(app.buttons["batch.solve"].isEnabled)
        }
        try verifyGuide()
        selectTool("自由")
        try capture("batch-author-free")
        app.buttons["batch.more"].tap()
        let sequence = revealMenuItem("batch.playSequence")
        XCTAssertEqual(sequence.label, "播放当前录制序列")
        XCTAssertFalse(sequence.isEnabled, "No recorded shot must keep sequence preview disabled")
        closeRootMenu()
        app.buttons["shotStage.spinEntry"].tap()
        let card = element("spinPad.card")
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertTrue(element("batch.playingBounds").frame.insetBy(dx: -1, dy: -1).contains(card.frame))
        try capture("batch-author-spin")
        app.buttons["batch.more"].tap()
        XCTAssertFalse(card.exists, "Opening another panel closes the spin panel")
        closeRootMenu()
        app.buttons["batch.back"].tap()
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        if UIDevice.current.userInterfaceIdiom != .pad { rotate(.portrait) }
        try capture("batch-author-return-picker")
    }
    func testAimPointRadiusRemainsThroughAnswer() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        app.switchTab(.angle)
        let section = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(section.waitForExistence(timeout: 5)); section.tap()
        let card = app.buttons["瞄准点训练"]
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        card.tap()
        let radius = element("aimPointDiagram.radius")
        XCTAssertTrue(radius.waitForExistence(timeout: 8))
        XCTAssertTrue(radius.label.contains("球半径 R ="))
        XCTAssertTrue(radius.label.contains("mm"))
        try capture("quiz-point-radius")
        let submit = app.buttons["提交瞄准点"]
        for _ in 0..<4 where !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.buttons["下一题"].waitForExistence(timeout: 4))
        XCTAssertTrue(radius.exists, "尺寸说明是常驻教学内容")
        try capture("quiz-point-radius-result")
    }
}
