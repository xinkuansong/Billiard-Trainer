import XCTest

/// 问题集合 v3 §S2 全局规范推广验收：
/// - 逐页截图核验 G3–G11（分离角与走位 / 自由走位 / 思路训练 / 打一走二想三 / 做斯诺克）；
/// - P11.1：打页入口顺序 = 分离角与走位、自由走位、自由击球、拍照建球形。
final class S2_ShotPagesLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        // Layout evidence belongs to this run's output, never a design baseline.
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/3d-v63/W03/page-layout")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name)-\(Int(app.windows.firstMatch.frame.width)).png"))
        } catch {
            XCTFail("Cannot save layout evidence: \(error)")
        }

    }

    private func inspectCompactSpinPanel(_ name: String) {
        app.buttons["shotStage.spinEntry"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "spinPad.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(card.frame.minX, window.minX)
        XCTAssertLessThanOrEqual(card.frame.maxX, window.maxX)
        XCTAssertLessThan(card.frame.height, card.frame.width,
                          "3D must use the compact horizontal spin panel")
        snap(name)
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertFalse(card.exists)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    /// 从练习首页进入指定卡片页；返回是否成功。
    private func openCard(homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)   // 等场景装桌 + 自动取景
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        guard table.waitForExistence(timeout: 10), table.isHittable else {
            XCTFail("Target table was not reached: \(title)"); return false
        }
        XCTAssertFalse(app.buttons["解锁 Pro"].exists, "Paywall is not a table layout")
        return true
    }

    private func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }
    }

    /// P11.1：打页卡片顺序（分离角与走位 → 自由走位 → 自由击球 → 拍照建球形）。
    func testPlayEntriesOrder() throws {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab("打") else {
            XCTFail("未能切到「打」分组"); return
        }
        let titles = ["分离角与走位", "自由走位", "自由击球", "拍照建球形"]
        var positions: [CGPoint] = []
        for t in titles {
            let card = app.buttons[t]
            XCTAssertTrue(card.waitForExistence(timeout: 4), "缺少入口卡片：\(t)")
            positions.append(CGPoint(x: card.frame.midX, y: card.frame.midY))
        }
        // 网格从上到下、每行从左到右 ⇒ (y, x) 字典序递增。
        for i in 1..<positions.count {
            let prev = positions[i - 1], cur = positions[i]
            let ordered = cur.y > prev.y + 1 || (abs(cur.y - prev.y) <= 1 && cur.x > prev.x)
            XCTAssertTrue(ordered, "入口顺序错误：\(titles[i]) 应在 \(titles[i - 1]) 之后")
        }
        snap("s2-00-play-entries-order")
    }

    func testShotSimulationLayout() throws {
        guard openCard(homeTab: "打", title: "分离角与走位") else {
            XCTFail("未能进入分离角与走位"); return
        }
        snap("s2-01-shotsim")
    }

    func testShotSimulation3DPilot() throws {
        continueAfterFailure = false
        XCTAssertTrue(openCard(homeTab: "打", title: "分离角与走位"))
        let mode = app.buttons["shotSimulation.cameraMode"]
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        func capture(_ name: String) throws {
            Thread.sleep(forTimeInterval: 1) // Capture the settled SwiftUI overlay/camera pose.
            let shot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("output/shot-simulation-3d")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: root.appendingPathComponent("\(name)-\(Int(app.windows.firstMatch.frame.width)).png"))
        }
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.value as? String, "2D")
        try capture("after-2d")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("after-3d-pocket")
        for destination in ["table", "cue", "target", "pocket"] {
            app.buttons["shotSimulation.observation"].tap()
            let item = app.buttons["shotSimulation.observe.\(destination)"]
            XCTAssertTrue(item.waitForExistence(timeout: 3))
            XCTAssertTrue(item.isEnabled)
            item.tap()
            try capture("v63-observe-\(destination)")
        }
        // The selected corner pocket exercises the closest, lowest permitted
        // observation pose beside the rail, through production gestures.
        for _ in 0..<3 {
            table.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.55))
                .press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.15)))
        }
        table.pinch(withScale: 4, velocity: 2)
        try capture("v63-pocket-low-close")
        app.buttons["shotSimulation.focus"].tap()
        mode.tap()
        app.buttons["瞄准模式：进袋，点击切换"].tap()
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        XCTAssertTrue(app.buttons["shotSimulation.focus"].isHittable)
        Thread.sleep(forTimeInterval: 1)
        try capture("after-3d")
        let center = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        center.press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)))
        table.pinch(withScale: 1.2, velocity: 1)
        try capture("after-orbit")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("v63-resumed-orbit")
        mode.tap()
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("v63-restored-orbit")
        app.buttons["shotSimulation.focus"].tap()
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        XCTAssertTrue(wheel.isHittable)
        wheel.swipeUp()
        app.buttons["shotStage.spinEntry"].tap()
        try capture("after-spin")
        let lowerSpin = app.buttons["低杆增加 1%"]
        XCTAssertTrue(lowerSpin.isHittable)
        XCTAssertLessThan(lowerSpin.frame.maxY, app.buttons["shotSimulation.focus"].frame.minY)
        lowerSpin.tap()
        XCTAssertTrue(app.buttons["回中"].isHittable)
        // View switching closes the overlay while retaining the same shot state.
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        mode.tap()
        let strike = app.buttons["击球"]
        XCTAssertTrue(strike.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: strike)
        waitForExpectations(timeout: 20)
        strike.tap()
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        let replay = app.buttons["回放"]
        expectation(for: ready, evaluatedWith: replay)
        waitForExpectations(timeout: 30)
        try capture("after-shot-2d")
        mode.tap()
        replay.tap()
        expectation(for: ready, evaluatedWith: replay)
        waitForExpectations(timeout: 30)
        app.buttons["重打"].tap()
        XCTAssertTrue(app.buttons["shotSimulation.focus"].isHittable)
        try capture("after-replay-3d")
    }

    /// Actual page defaults, including the view's board override. Images verify the
    /// visible outcome; readiness assertions alone do not prove a successful pot.
    func testShotSimulationDefaultShotOutcome() throws {
        continueAfterFailure = false
        XCTAssertTrue(openCard(homeTab: "打", title: "分离角与走位"))
        let mode = app.buttons["shotSimulation.cameraMode"]
        let strike = app.buttons["击球"]
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: strike)
        waitForExpectations(timeout: 20)
        snap("v63-default-before-2d")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        strike.tap()
        let replay = app.buttons["回放"]
        expectation(for: enabled, evaluatedWith: replay)
        waitForExpectations(timeout: 30)
        snap("v63-default-after-3d")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        snap("v63-default-after-2d")
        // This page has exactly one default object ball. After it leaves the table,
        // production target selection becomes empty and another strike is disabled.
        XCTAssertTrue(app.staticTexts["点选一颗目标球"].exists)
        XCTAssertFalse(strike.isEnabled)
        mode.tap()
        replay.tap()
        expectation(for: enabled, evaluatedWith: replay)
        waitForExpectations(timeout: 30)
        XCTAssertTrue(app.staticTexts["点选一颗目标球"].exists)
        XCTAssertFalse(strike.isEnabled)
        snap("v63-default-replay-3d")
        app.buttons["重打"].tap()
        expectation(for: enabled, evaluatedWith: strike)
        waitForExpectations(timeout: 20)
        XCTAssertFalse(app.staticTexts["点选一颗目标球"].exists)
        mode.tap()
        snap("v63-default-reset-2d")
    }

    func testComposerLayout() throws {
        guard openCard(homeTab: "打", title: "自由走位") else {
            XCTFail("未能进入自由走位"); return
        }
        snap("s2-02-composer")
    }

    func testSiluLayout() throws {
        guard openCard(homeTab: "解", title: "思路训练") else {
            XCTFail("未能进入思路训练"); return
        }
        snap("s2-03-silu")
    }

    func testSilu3DPlanningRoundTrip() throws {
        XCTAssertTrue(openCard(homeTab: "解", title: "思路训练"))
        app.buttons["落区"].tap()
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.65)))
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-silu-region-2d")
        let camera = app.buttons["silu.cameraMode"]
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertFalse(app.buttons["落区"].isEnabled)
        sleep(1)
        snap("v63-silu-region-3d")
        app.buttons["break.entry"].tap()
        let game = app.descendants(matching: .any).matching(identifier: "break.game.15").firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        XCTAssertTrue(app.buttons["break.strike"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["navStatus.subtitle"].label.contains("瞄准轮"))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        XCTAssertEqual(camera.value as? String, "3D")
        snap("v63-silu-break-cancel-restored")
        app.buttons["silu.observation"].tap()
        XCTAssertFalse(app.buttons["silu.observe.aim"].isEnabled)
        app.buttons["silu.observe.table"].tap()
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        snap("v63-silu-region-orbit")
        app.buttons["求解"].tap()
        let strike = app.buttons["击球"]
        let solved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)
        XCTAssertEqual(XCTWaiter.wait(for: [solved], timeout: 90), .completed)
        snap("v63-silu-solved-3d")
        app.buttons["silu.observation"].tap()
        XCTAssertTrue(app.buttons["silu.observe.aim"].isEnabled)
        app.buttons["silu.observe.aim"].tap()
        sleep(1)
        snap("v63-silu-current-aim")
        inspectCompactSpinPanel("v63-silu-compact-spin")
        strike.tap()
        let undo = app.buttons["上一杆"]
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 60), .completed)
        snap("v63-silu-shot-finished")
        undo.tap()
        XCTAssertTrue(strike.isEnabled)
        snap("v63-silu-shot-restored")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertTrue(app.buttons["落区"].isEnabled)
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-silu-region-returned")
    }

    func testPlanThree3DConstraintRoundTrip() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-planThree.twoBallDimmed"])
        // RootView routes this existing fixture directly to PlanThreeView.
        XCTAssertTrue(app.buttons["planthree.cameraMode"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["table.scene"].isHittable)
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-planthree-roles-2d")
        app.buttons["break.entry"].tap()
        let game = app.descendants(matching: .any).matching(identifier: "break.game.15").firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        XCTAssertTrue(app.buttons["break.strike"].waitForExistence(timeout: 10))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-planthree-break-cancel-restored")
        let camera = app.buttons["planthree.cameraMode"]
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertFalse(app.buttons["清空计划"].isEnabled)
        XCTAssertFalse(app.buttons["落区"].isEnabled)
        app.buttons["planthree.observation"].tap()
        XCTAssertFalse(app.buttons["planthree.observe.aim"].isEnabled)
        app.buttons["planthree.observe.target"].tap()
        sleep(1)
        snap("v63-planthree-target-3d")
        app.buttons["planthree.observation"].tap()
        app.buttons["planthree.observe.table"].tap()
        sleep(1)
        snap("v63-planthree-table-3d")
        app.buttons["求解"].tap()
        let strike = app.buttons["打一"]
        let solved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)
        XCTAssertEqual(XCTWaiter.wait(for: [solved], timeout: 90), .completed)
        snap("v63-planthree-solved")
        app.buttons["planthree.observation"].tap()
        app.buttons["planthree.observe.aim"].tap()
        sleep(1)
        snap("v63-planthree-aim")
        inspectCompactSpinPanel("v63-planthree-compact-spin")
        strike.tap()
        let undo = app.buttons["上一杆"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 60), .completed)
        XCTAssertTrue(app.staticTexts["navStatus.subtitle"].label.contains("窗口前滑"))
        snap("v63-planthree-advanced")
        undo.tap()
        XCTAssertTrue(strike.isEnabled)
        snap("v63-planthree-restored")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertTrue(app.buttons["清空计划"].isEnabled)
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-planthree-roles-returned")
    }

    func testPlanThreeLayout() throws {
        guard openCard(homeTab: "解", title: "打一走二想三") else {
            XCTFail("未能进入打一走二想三"); return
        }
        snap("s2-04-planthree")
    }

    func testSnooker3DPlanningRoundTrip() throws {
        // A failed prerequisite must stop the flow before naming a busy screen "solved".
        continueAfterFailure = false
        XCTAssertTrue(openCard(homeTab: "解", title: "防守"))
        let camera = app.buttons["snooker.cameraMode"]
        XCTAssertTrue(app.buttons["求解"].isEnabled)
        snap("v63-snooker-before")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertFalse(app.buttons["目标球"].isEnabled)
        app.buttons["snooker.observation"].tap()
        XCTAssertFalse(app.buttons["snooker.observe.pocket"].exists)
        XCTAssertFalse(app.buttons["snooker.observe.aim"].isEnabled)
        app.buttons["snooker.observe.target"].tap()
        sleep(1)
        snap("v63-snooker-observe")
        app.buttons["求解"].tap()
        let strike = app.buttons["击球"]
        let solved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)
        XCTAssertEqual(XCTWaiter.wait(for: [solved], timeout: 90), .completed)
        snap("v63-snooker-solved")
        app.buttons["snooker.observation"].tap()
        app.buttons["snooker.observe.aim"].tap()
        sleep(1)
        snap("v63-snooker-aim")
        inspectCompactSpinPanel("v63-snooker-compact-spin")
        strike.tap()
        let undo = app.buttons["上一杆"]
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 60), .completed)
        snap("v63-snooker-finished")
        undo.tap()
        XCTAssertTrue(strike.isEnabled)
        snap("v63-snooker-restored")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertTrue(app.buttons["目标球"].isEnabled)
        snap("v63-snooker-returned")
    }

    func testSnookerLayout() throws {
        guard openCard(homeTab: "解", title: "防守") else {
            XCTFail("未能进入防守"); return
        }
        snap("s2-05-snooker")
    }
    private func runPlanning3DBreak(deeplink: String, prefix: String) {
        continueAfterFailure = false
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", deeplink])
        let camera = app.buttons[prefix + ".cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 10))
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        app.buttons["break.entry"].tap()
        let game = app.descendants(matching: .any).matching(identifier: "break.game.15").firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        let strike = app.buttons["break.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 10))
        inspectCompactSpinPanel("v63-" + prefix + "-break-spin")
        strike.tap()
        let confirm = app.buttons["break.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 60))
        snap("v63-" + prefix + "-break-settled")
        confirm.tap()
        XCTAssertTrue(app.buttons["break.entry"].waitForExistence(timeout: 5))
        XCTAssertEqual(camera.value as? String, "3D")
        snap("v63-" + prefix + "-break-delivered")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertTrue(app.buttons["摆球"].isEnabled)
    }

    func testSilu3DBreakDelivery() {
        runPlanning3DBreak(deeplink: "-deeplink.silu", prefix: "silu")
    }

    func testPlanThree3DBreakDelivery() {
        runPlanning3DBreak(deeplink: "-deeplink.planThree", prefix: "planthree")
    }

    func testPlanThreeAllRolesAdvanceAndUndoIn3D() {
        continueAfterFailure = false
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.planThree", "-planThree.threeBallDimmed"])
        let camera = app.buttons["planthree.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 10))
        func role(_ index: Int) -> String? { app.buttons["planthree.role.\(index)"].value as? String }
        XCTAssertEqual(role(0), "1号球")
        XCTAssertEqual(role(2), "2号球")
        XCTAssertEqual(role(4), "3号球")
        camera.tap()
        app.buttons["求解"].tap()
        let strike = app.buttons["打一"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 90), .completed)
        snap("v63-three-roles-ready")
        strike.tap()
        let undo = app.buttons["上一杆"]
        let stopped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [stopped], timeout: 60), .completed)
        XCTAssertEqual(role(0), "2号球")
        XCTAssertEqual(role(2), "3号球")
        XCTAssertEqual(role(4), "未选择")
        XCTAssertEqual(app.buttons["planthree.role.3"].value as? String, "未选择")
        snap("v63-three-roles-advanced")
        undo.tap()
        XCTAssertEqual(role(0), "1号球")
        XCTAssertEqual(role(2), "2号球")
        XCTAssertEqual(role(4), "3号球")
        XCTAssertTrue(strike.isEnabled)
        snap("v63-three-roles-undone")
    }

    private func runAtlas3DRoundTrip(title: String, prefix: String) {
        continueAfterFailure = false
        XCTAssertTrue(openCard(homeTab: "学", title: title))
        let camera = app.buttons[prefix + ".cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 10))
        let track = app.buttons[prefix + ".spinLegend.0"]
        XCTAssertTrue(track.waitForExistence(timeout: 10))
        let selected = track.value as? String
        track.tap()
        XCTAssertNotEqual(track.value as? String, selected, "2D baseline must toggle before testing 3D")
        track.tap()
        XCTAssertEqual(track.value as? String, selected)
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertEqual(track.value as? String, selected)
        app.buttons[prefix + ".observation"].tap()
        app.buttons[prefix + ".observe.table"].tap()
        snap("v63-" + prefix + "-3d-all")
        track.tap()
        XCTAssertNotEqual(track.value as? String, selected)
        snap("v63-" + prefix + "-3d-track-off")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertNotEqual(track.value as? String, selected)
        track.tap()
        XCTAssertEqual(track.value as? String, selected)
        snap("v63-" + prefix + "-2d-returned")
        camera.tap()
        for index in 0..<7 {
            let item = app.buttons[prefix + ".spinLegend.\(index)"]
            XCTAssertTrue(item.isHittable)
            XCTAssertGreaterThanOrEqual(item.frame.width, 44)
            XCTAssertGreaterThanOrEqual(item.frame.height, 44)
            item.tap()
            XCTAssertNotEqual(item.value as? String, selected)
        }
        let last = app.buttons[prefix + ".spinLegend.7"]
        last.tap()
        XCTAssertEqual(last.value as? String, selected, "The last visible trajectory must remain selected")
        snap("v63-" + prefix + "-3d-single-track")
        track.tap()
        last.tap()
        XCTAssertNotEqual(last.value as? String, selected, "The eighth toggle must work when another track is visible")
        for index in 1..<8 {
            let item = app.buttons[prefix + ".spinLegend.\(index)"]
            item.tap()
            XCTAssertEqual(item.value as? String, selected)
        }
        let power = app.descendants(matching: .any).matching(identifier: "solver.power").firstMatch
        let originalPower = power.value as? String
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        XCTAssertNotEqual(power.value as? String, originalPower, "Dragging the visible ruler must change power")
        let changedPower = power.value as? String
        for focus in ["cue", "target", "pocket", "table"] {
            app.buttons[prefix + ".observation"].tap()
            XCTAssertFalse(app.buttons[prefix + ".observe.aim"].isEnabled)
            let choice = app.buttons[prefix + ".observe." + focus]
            XCTAssertTrue(choice.isEnabled)
            choice.tap()
            XCTAssertEqual(power.value as? String, changedPower)
            XCTAssertEqual(track.value as? String, selected)
        }
        if prefix == "cushionEnglishAtlas" {
            app.buttons["shotStage.spinEntry"].tap()
            // This page assigns its overlay identifier to the card's Other element.
            // The dismiss backdrop has the same identifier but is a Button.
            let card = app.otherElements["cushionEnglishAtlas.spinPad"]
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["左塞增加 1%"].exists)
            XCTAssertFalse(app.buttons["右塞增加 1%"].exists)
            app.buttons["高杆增加 1%"].tap()
            XCTAssertTrue(card.staticTexts["高1%"].exists)
            snap("v63-" + prefix + "-3d-height-adjusted")
            app.buttons["回中"].tap()
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
            XCTAssertFalse(card.exists)
        }
        camera.tap()
        XCTAssertEqual(power.value as? String, changedPower, "2D return must preserve the edited power")
    }

    func testSeparationAtlas3DRoundTrip() {
        runAtlas3DRoundTrip(title: "分离角图谱", prefix: "separationAngleAtlas")
    }

    func testAngleDynamicObservationRoundTrip() {
        continueAfterFailure = false
        XCTAssertTrue(openCard(homeTab: "学", title: "角度与瞄准"))
        snap("v63-angle-dynamic-baseline")
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        XCTAssertTrue(metrics.exists)
        let initial = metrics.label
        let camera = app.buttons["angleDynamic.cameraMode"]
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertFalse(app.buttons["paletteBall__1"].exists)
        XCTAssertEqual(metrics.label, initial)
        for focus in ["cue", "target", "pocket", "table"] {
            app.buttons["angleDynamic.observation"].tap()
            app.buttons["angleDynamic.observe." + focus].tap()
            XCTAssertEqual(metrics.label, initial)
        }
        snap("v63-angle-dynamic-3d")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertEqual(metrics.label, initial)
        XCTAssertTrue(app.buttons["paletteBall__1"].exists)
        snap("v63-angle-dynamic-returned")
    }

    func testCushionAtlas3DRoundTrip() {
        runAtlas3DRoundTrip(title: "加塞吃库图谱", prefix: "cushionEnglishAtlas")
    }

    func testAtlasGridControlsAcrossModes() {
        continueAfterFailure = false
        for (title, prefix) in [("角度与瞄准", "angleDynamic"),
                                ("分离角图谱", "separationAngleAtlas"),
                                ("加塞吃库图谱", "cushionEnglishAtlas")] {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
            XCTAssertTrue(openCard(homeTab: "学", title: title))
            let camera = app.buttons[prefix + ".cameraMode"]
            XCTAssertEqual(camera.value as? String, "2D")
            app.buttons["更多"].tap()
            let grid = app.buttons["台面网格 4×8"]
            XCTAssertTrue(grid.waitForExistence(timeout: 3))
            let initial = "\(grid.value ?? "nil")/\(grid.isSelected)"
            grid.tap()
            camera.tap()
            snap("v63-" + prefix + "-grid-3d")
            app.buttons["更多"].tap()
            let changed = "\(grid.value ?? "nil")/\(grid.isSelected)"
            XCTAssertNotEqual(changed, initial)
            grid.tap()
            camera.tap()
            app.buttons["更多"].tap()
            XCTAssertEqual("\(grid.value ?? "nil")/\(grid.isSelected)", initial)
        }
    }

}
