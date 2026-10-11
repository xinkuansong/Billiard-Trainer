import XCTest

final class W1BOperationsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var prefix = ""
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 60) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: timeout), .completed)
    }
    private func launch(_ route: String, args: [String] = []) {
        continueAfterFailure = false; prefix = route == "diamond" ? "reflection" : route
        XCUIDevice.shared.orientation = .portrait
        let deep = ["silu": "silu", "planthree": "planThree", "snooker": "snooker"]
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-3dDrag.probe", "-v51.followSystemAppearance"] + args + (deep[route].map { ["-deeplink." + $0] } ?? []))
        if deep[route] == nil {
            app.switchTab(.angle); ready(app.buttons["angleHomeTab_解"]); app.buttons["angleHomeTab_解"].tap()
            let card = app.buttons[route == "bankshot" ? "翻袋解球" : "颗星解球"]
            ready(card); card.tap()
        }
        XCTAssertTrue(element(prefix + ".template").waitForExistence(timeout: 25))
        XCTAssertTrue(element("table.scene").waitForExistence(timeout: 10))
    }
    private func mode(_ value: String) {
        app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let mode = app.buttons[prefix + ".cameraMode"]; ready(mode)
        if mode.value as? String != value { mode.tap() }
        XCTAssertEqual(mode.value as? String, value)
        app.buttons[prefix + ".dismissMenu"].tap()
    }
    private func probe() throws -> [String: Any] {
        let raw = try XCTUnwrap(element("table.scene").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func ball(_ key: String) throws -> [String: Any] {
        let balls = try XCTUnwrap(try probe()["balls"] as? [[String: Any]])
        return try XCTUnwrap(balls.first { $0["key"] as? String == key })
    }
    private func point(_ key: String) throws -> XCUICoordinate {
        let p = try XCTUnwrap(try ball(key)["screen"] as? [Double])
        return element("table.scene").coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: p[0], dy: p[1]))
    }
    private func snap(_ state: String) {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = "w1b-" + prefix + "-" + state; att.lifetime = .keepAlways; add(att)
        let ax = XCTAttachment(string: app.debugDescription); ax.name = (att.name ?? state) + "-ax"; ax.lifetime = .keepAlways; add(ax)
    }
    private func editTemporary() throws {
        mode("3D"); ready(app.buttons["shotCamera.temporaryTopDown"])
        snap("3d")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            (try? self.probe()["standardTemporaryTable"] as? Bool) == true
        }, object: nil)], timeout: 10), .completed)
        let cameraBefore = try XCTUnwrap(try probe()["camera"] as? [Double])
        XCTAssertFalse(app.buttons[prefix + ".strike"].isEnabled)
        let palette = app.buttons["paletteBall__7"]; ready(palette)
        XCTAssertEqual(palette.value as? String, "未在桌上"); palette.tap()
        XCTAssertEqual(palette.value as? String, "在桌上")
        let before = try XCTUnwrap(try ball("_7")["world"] as? [Double])
        let start = try point("_7")
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 34, dy: 21)))
        let after = try XCTUnwrap(try ball("_7")["world"] as? [Double])
        XCTAssertGreaterThan(hypot(after[0] - before[0], after[2] - before[2]), 0.01)
        snap("temporary-edited")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            (try? self.probe()["standardTemporaryTable"] as? Bool) == false
        }, object: nil)], timeout: 10), .completed)
        let restored = try XCTUnwrap(try probe()["camera"] as? [Double])
        XCTAssertEqual(restored.count, cameraBefore.count)
        for (a,b) in zip(restored,cameraBefore) { XCTAssertEqual(a,b,accuracy:0.001) }
        snap("restored")
    }
    func testSiluEditingAndConstraintInTemporary2D() throws {
        launch("silu"); snap("2d")
        mode("3D")
        app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
        let pose = try XCTUnwrap(try probe()["camera"] as? [Double])
        let scene = element("table.scene")
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.46, dy: 0.46)).press(forDuration: 0.1,
            thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.6)))
        ready(app.buttons["silu.clearConstraint"])
        let afterDraw = try XCTUnwrap(try probe()["camera"] as? [Double])
        for (a,b) in zip(pose,afterDraw) { XCTAssertEqual(a,b,accuracy:0.001) }
        snap("3d-constraint")
        app.buttons["silu.tool"].tap(); app.buttons["摆球"].tap()
        try editTemporary()
        app.buttons["shotCamera.temporaryTopDown"].tap()
        app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
        let table = element("table.scene")
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.43, dy: 0.45)).press(forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.65)))
        ready(app.buttons["silu.clearConstraint"])
        snap("temporary-constraint")
        app.buttons["paletteBall__4"].tap()
        XCTAssertTrue(app.buttons["silu.tool"].label.contains("摆球"))
        snap("new-ball-placement")
    }
    func testPlanRolesAndCompletion() throws {
        launch("planthree"); snap("2d")
        try editTemporary()
        app.buttons["shotCamera.temporaryTopDown"].tap()
        app.buttons["planthree.roles"].tap(); ready(app.buttons["planthree.role.0"]); app.buttons["planthree.role.0"].tap()
        try point("_7").tap()
        XCTAssertTrue(element("planthree.rolesSummary").label.contains("①球:7号球"))
        snap("temporary-role-selected")
        app.terminate(); launch("planthree", args: ["-planThree.oneBall"])
        ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        ready(app.buttons["planthree.strike"], timeout: 90)
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(element("planthree.spinPad").waitForExistence(timeout: 5))
        XCTAssertFalse(element("planthree.status").exists)
        XCTAssertTrue(element("planthree.rolesSummary").exists)
        XCTAssertFalse(element("planthree.rolesSummary").frame.intersects(app.otherElements["planthree.spinPad"].firstMatch.frame))
        snap("spin-with-persistent-roles")
        app.buttons["关闭打点"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        app.buttons["planthree.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let entry = app.buttons["break.entry"]
        for _ in 0..<4 where !entry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(entry); entry.tap(); ready(app.buttons["break.game.4"]); app.buttons["break.game.4"].tap()
        ready(app.buttons["break.rerack"])
        XCTAssertFalse(element("planthree.rolesSummary").exists)
        snap("break-paired-rulers")
        app.terminate(); launch("planthree", args: ["-planThree.cleared"])
        XCTAssertTrue(element("planthree.status").label.contains("清台完成"))
        XCTAssertFalse(element("planthree.rolesSummary").exists)
        snap("completed")
    }
    func testDailyLegacyTemporaryProjectionAndCameraRestore() throws {
        continueAfterFailure = false; prefix = "daily"
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.preferredGame.v1", "chineseEightBall", "-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled", "-3dDrag.probe"])
        let more = app.buttons["freeplay.moreMenu"]; ready(more)
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let mode = app.buttons["freeplay.cameraMode"]; ready(mode)
        if mode.value as? String != "3D" { mode.tap() }
        XCTAssertEqual(mode.value as? String, "3D")
        // Daily 3D closes its panel via the outside-table dismiss layer, as in DailyAdaptivePanelUITests.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(element("dailyClearance.menuPanel").exists)
        let temp = app.buttons["shotCamera.temporaryTopDown"]; ready(temp)
        temp.tap()
        XCTAssertEqual(temp.value as? String, "已选中")
        let before = try XCTUnwrap(try probe()["camera"] as? [Double])
        XCTAssertEqual(try probe()["standardTemporaryTable"] as? Bool, false)
        snap("legacy-temporary")
        temp.tap(); XCTAssertEqual(temp.value as? String, "未选中")
        let after = try XCTUnwrap(try probe()["camera"] as? [Double])
        for (a,b) in zip(before,after) { XCTAssertEqual(a,b,accuracy:0.001) }
        snap("legacy-restored")
    }

    func testDefenseEditing() throws { launch("snooker"); snap("2d"); try editTemporary() }
    func testBankSelectionAndEditing() throws { try solver("bankshot") }
    func testDiamondSelectionAndEditing() throws { try solver("diamond") }
    private func solver(_ route: String) throws {
        launch(route)
        let next = app.buttons["solver.nextSolution"]
        ready(app.buttons[prefix + ".strike"], timeout: 90)
        if route == "bankshot" {
            let pockets = try XCTUnwrap(try probe()["pockets"] as? [[String: Any]])
            for pocket in pockets where !next.isEnabled {
                let p = try XCTUnwrap(pocket["screen"] as? [Double])
                element("table.scene").coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:p[0],dy:p[1])).tap()
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                    !self.element("solver.status").label.contains("求解中")
                }, object: nil)], timeout: 90), .completed)
            }
        }
        ready(next, timeout: 90)
        snap("solved")
        next.press(forDuration: 1)
        let second = app.buttons["solver.selectSolution.1"]; ready(second); snap("solution-menu"); second.tap()
        XCTAssertTrue((next.value as? String ?? "").hasPrefix("解 2/"))
        XCTAssertTrue(element("solver.status").label.hasPrefix("解 2/"))
        snap("selected-second")
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(element(prefix + ".spinPad").waitForExistence(timeout: 5))
        XCTAssertFalse(element("solver.status").exists)
        snap("spin-expanded")
        app.buttons["关闭打点"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        try editTemporary()
        mode("2D"); app.buttons["solver.mode"].tap()
        XCTAssertEqual(app.buttons["solver.mode"].value as? String, "自由")
        snap("free-paired-rulers")
        if route == "bankshot" {
            ready(app.buttons[prefix + ".strike"]); app.buttons[prefix + ".strike"].tap()
            ready(app.buttons["solver.replay"], timeout: 60)
            mode("3D"); app.buttons["shotCamera.temporaryTopDown"].tap()
            XCTAssertFalse(app.buttons["solver.replay"].isEnabled)
            XCTAssertFalse(app.buttons["solver.undo"].isEnabled)
            snap("temporary-replay-disabled")
        }
    }

    func testMatrixPlanReplayReachableInCompactToolColumn() throws {
        launch("planthree", args: ["-planThree.oneBall"])
        ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        try verifyReplayReachableAfterShot()
    }

    func testMatrixSiluReplayReachableInCompactToolColumn() throws {
        launch("silu")
        app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
        let table = element("table.scene")
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.48)).press(forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.76)))
        ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        try verifyReplayReachableAfterShot()
    }

    private func verifyReplayReachableAfterShot() throws {
        ready(app.buttons[prefix + ".strike"], timeout: 90)
        // A solved shot enables the spin editor; a completed shot deliberately does not.
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(element(prefix + ".spinPad").waitForExistence(timeout: 5))
        verifyReplayTargetCanScrollIntoView(state: "spin-expanded")
        app.buttons["关闭打点"].coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        app.buttons[prefix + ".strike"].tap()
        let replay = app.buttons[prefix + ".replay"]
        ready(replay, timeout: 90)
        verifyReplayTargetCanScrollIntoView(state: "after-shot")
        XCTAssertTrue(replay.isHittable)
        replay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: replay)], timeout: 5), .completed)
        snap("compact-replay-running")
        ready(replay, timeout: 90)
        snap("compact-replay-finished")
    }

    private func verifyReplayTargetCanScrollIntoView(state: String) {
        let replay = app.buttons[prefix + ".replay"]
        let column = app.scrollViews.containing(.button, identifier: prefix + ".replay").firstMatch
        XCTAssertTrue(column.exists)
        let viewport = column.frame
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.insetBy(dx: -0.5, dy: -0.5).contains(viewport), "Tool viewport must stay inside the window")
        let before = replay.frame
        snap("compact-replay-" + state + "-before-explicit-scroll")
        // Explicitly drag inside the tool column; do not let XCTest auto-reveal on tap.
        column.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).press(forDuration: 0.1,
            thenDragTo: column.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        let visibleFrame = replay.frame
        XCTAssertGreaterThanOrEqual(visibleFrame.width, 44)
        XCTAssertGreaterThanOrEqual(visibleFrame.height, 44)
        XCTAssertTrue(viewport.insetBy(dx: -0.5, dy: -0.5).contains(visibleFrame), "Entire replay target must be visible after explicit scrolling")
        if before.maxY > viewport.maxY + 0.5 {
            XCTAssertLessThan(visibleFrame.minY, before.minY, "Overflow content must actually scroll")
        }
        snap("compact-replay-" + state + "-fully-visible")
    }

    // Final unified-build evidence gaps. These use existing real solver/fixture paths.
    func testMatrixSiluShortSummaryAndBreakRerackCamera() throws {
        launch("silu")
        app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
        let table = element("table.scene")
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.48)).press(forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.76)))
        ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        ready(app.buttons["silu.strike"], timeout: 90)
        assertMatrixShortSummary("silu.status")
        snap("matrix-solved-short-summary")
        try captureMatrixBreakAndVerifyRerackCamera()
    }

    func testMatrixDefenseShortSummaryAndPlanRerackCamera() throws {
        // Existing fixture configures a board and calls the real defensive solver.
        launch("snooker", args: ["-snooker.full"])
        ready(app.buttons["snooker.strike"], timeout: 90)
        assertMatrixShortSummary("snooker.status")
        snap("matrix-solved-short-summary")
        app.terminate()
        launch("planthree")
        try captureMatrixBreakAndVerifyRerackCamera()
    }

    private func assertMatrixShortSummary(_ identifier: String) {
        let status = element(identifier).label
        XCTAssertTrue(status.hasPrefix("解 "), "Capture only a real solved state: \(status)")
        XCTAssertTrue(status.hasSuffix("库"), "Summary should end with its cushion count: \(status)")
        XCTAssertFalse(status.contains("容错"))
        XCTAssertFalse(status.contains("求解中"))
    }

    private func captureMatrixBreakAndVerifyRerackCamera() throws {
        mode("2D")
        app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let entry = app.buttons["break.entry"]
        for _ in 0..<4 where !entry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(entry); entry.tap()
        let game = app.buttons["break.game.4"]; ready(game); game.tap()
        let rerack = app.buttons["break.rerack"]; ready(rerack)
        snap("matrix-break-paired-rulers")
        mode("3D")
        let first = app.buttons["shotCamera.firstPerson"]
        let third = app.buttons["shotCamera.thirdPerson"]
        ready(first); first.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "已选中"), object: first)], timeout: 10), .completed)
        let firstPose = try XCTUnwrap(try probe()["camera"] as? [Double])
        XCTAssertFalse(firstPose.isEmpty)
        snap("matrix-break-first-person-before-rerack")
        ready(rerack); rerack.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "已选中"), object: third)], timeout: 10), .completed)
        // A selection-label change alone is insufficient: rendered camera pose must also move.
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let pose = try? self.probe()["camera"] as? [Double], pose.count == firstPose.count else { return false }
            return zip(pose, firstPose).contains { abs($0.0 - $0.1) > 0.001 }
        }, object: nil)], timeout: 10), .completed)
        XCTAssertEqual(first.value as? String, "未选中")
        snap("matrix-break-rerack-restored-third-person")
    }
}
