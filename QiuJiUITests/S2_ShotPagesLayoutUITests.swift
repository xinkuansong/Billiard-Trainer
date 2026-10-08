import XCTest

/// 问题集合 v3 §S2 全局规范推广验收：
/// - 逐页截图核验 G3–G11（分离角与走位 / 自由走位 / 思路训练 / 打一走二想三 / 做斯诺克）；
/// - P11.1：打页入口顺序 = 分离角与走位、自由走位、自由击球、拍照建球形。
final class S2_ShotPagesLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    func testV63BankCameraModes() {
        checkBankKickCamera(title: "翻袋解球", prefix: "bankshot")
    }

    func testV63ReflectionCameraModes() {
        checkBankKickCamera(title: "颗星解球", prefix: "reflection")
    }

    private func checkBankKickCamera(title: String, prefix: String) {
        guard openCard(homeTab: "解", title: title) else { XCTFail(title); return }
        let camera = app.buttons[prefix + ".cameraMode"]
        let next = app.buttons["solver.nextSolution"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5))
        XCTAssertEqual(camera.value as? String, "2D")
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: next)], timeout: 30) == .completed)
        next.tap()
        let status = app.staticTexts["navStatus.subtitle"].label
        snap(prefix + "-2d-before")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        XCTAssertEqual(app.staticTexts["navStatus.subtitle"].label, status)
        snap(prefix + "-3d-overview")
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.45))
            .press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        table.pinch(withScale: 1.2, velocity: 1)
        snap(prefix + "-3d-orbit")
        camera.tap()
        XCTAssertEqual(app.staticTexts["navStatus.subtitle"].label, status)
        snap(prefix + "-2d-returned")
        camera.tap()
        for focus in ["table", "cue", "target", "aim"] {
            app.buttons[prefix + ".observation"].tap()
            XCTAssertEqual(app.buttons[prefix + ".observe.pocket"].exists, prefix == "bankshot")
            app.buttons[prefix + ".observe." + focus].tap()
        }
        snap(prefix + "-3d-aim")
        inspectCompactSpinPanel(prefix + "-3d-spin", cardIdentifier: "solver.spinPad")
        app.buttons["击打"].tap()
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        camera.tap()
        let solveUndo = app.buttons["上一杆"]
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: solveUndo)], timeout: 40) == .completed)
        solveUndo.tap()
        XCTAssertEqual(app.staticTexts["navStatus.subtitle"].label, status)
        app.buttons["solver.mode"].tap()
        let strike = app.buttons["击球"]
        XCTAssertTrue(strike.isEnabled)
        strike.tap()
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        let undo = app.buttons["上一杆"]
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: undo)], timeout: 40) == .completed)
        XCTAssertFalse(app.staticTexts["navStatus.subtitle"].label.contains("拖动台面"))
        snap(prefix + "-3d-settled")
        undo.tap()
        XCTAssertTrue(strike.isEnabled)
        camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        snap(prefix + "-2d-undo")
    }

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
        #if targetEnvironment(simulator)
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/3d-v63/W03/page-layout")
        #else
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("v63-shot-pages")
        #endif
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name)-\(Int(app.windows.firstMatch.frame.width)).png"))
        } catch {
            XCTFail("Cannot save layout evidence: \(error)")
        }

    }

    private func inspectCompactSpinPanel(_ name: String, cardIdentifier: String = "spinPad.card") {
        app.buttons["shotStage.spinEntry"].tap()
        let card = app.otherElements.matching(identifier: cardIdentifier).firstMatch
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
            #if targetEnvironment(simulator)
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("output/shot-simulation-3d")
            #else
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("v63-shot-pages")
            #endif
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

    private func assertTeachingDiagramAlignment(file: StaticString = #filePath, line: UInt = #line) throws {
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        let json = try XCTUnwrap(table.value as? String)
        let data = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let diagram = try XCTUnwrap(data["diagram"] as? [String: Any])
        let actual = try XCTUnwrap(diagram["arcStart"] as? [Double])
        let expected = try XCTUnwrap(diagram["expectedArcStart"] as? [Double])
        XCTAssertEqual(actual[0], expected[0], accuracy: 1, "Arc must use the current cloth projection", file: file, line: line)
        XCTAssertEqual(actual[1], expected[1], accuracy: 1, "Arc must use the current cloth projection", file: file, line: line)
        let ghost = try XCTUnwrap(diagram["ghost"] as? [Double])
        let label = try XCTUnwrap(diagram["labelCenter"] as? [Double])
        XCTAssertLessThanOrEqual(hypot(label[0] - ghost[0], label[1] - ghost[1]), 60.1, file: file, line: line)
        XCTAssertEqual(diagram["labelFontSize"] as? Double, 11, file: file, line: line)
        XCTAssertEqual(diagram["labelHidden"] as? Bool, false, file: file, line: line)
    }

    func testSeparationAtlas3DRoundTrip() throws {
        continueAfterFailure = false
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=separation", "-v54.forceLight", "-3dDrag.probe"])
        let prefix = "separationAngleAtlas"
        let more = app.buttons[prefix + ".more"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        let metrics = app.descendants(matching: .any).matching(identifier: prefix + ".metrics").firstMatch
        let legend = app.descendants(matching: .any).matching(identifier: prefix + ".spinLegend").firstMatch
        XCTAssertTrue(legend.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).count, 15)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        func toggle(_ index: Int, selected: Bool) {
            let item = app.buttons[prefix + ".spinLegend.\(index)"]
            XCTAssertTrue(item.isHittable)
            XCTAssertTrue(legend.frame.insetBy(dx: -1, dy: -1).contains(item.frame), "Entire row must be visible")
            XCTAssertGreaterThanOrEqual(item.frame.width, 44 - 0.001)
            XCTAssertGreaterThanOrEqual(item.frame.height, 24, "Compact eight-row layout must retain distinct usable rows")
            item.tap()
            XCTAssertEqual(item.value as? String, selected ? "已选" : "未选")
        }
        XCTAssertFalse(app.scrollViews[prefix + ".spinLegend"].exists)
        for i in 0..<8 {
            let item = app.buttons[prefix + ".spinLegend.\(i)"]
            XCTAssertTrue(item.isHittable)
            XCTAssertTrue(legend.frame.insetBy(dx: -1, dy: -1).contains(item.frame))
            if i > 0 { XCTAssertGreaterThanOrEqual(item.frame.minY, app.buttons[prefix + ".spinLegend.\(i - 1)"].frame.maxY) }
        }
        let trackCount = app.staticTexts[prefix + ".trackCount"]
        XCTAssertEqual(trackCount.label, "8/8")
        XCTAssertGreaterThanOrEqual(trackCount.frame.minY, app.buttons[prefix + ".spinLegend.7"].frame.maxY)
        XCTAssertLessThanOrEqual(metrics.frame.maxY, app.buttons[prefix + ".spinLegend.0"].frame.minY)
        XCTAssertFalse(metrics.label.contains("/8"))
        try assertTeachingDiagramAlignment()
        snap("p08a-2d")
        for i in 0..<7 { toggle(i, selected: false) }
        toggle(7, selected: true)
        XCTAssertEqual(trackCount.label, "1/8")
        snap("p08a-last-track")
        for i in 0..<7 { toggle(i, selected: true) }
        let initial = metrics.label
        let power = app.descendants(matching: .any).matching(identifier: "solver.power").firstMatch
        let speed = power.value as? String
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.2, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)),
                   withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
        XCTAssertNotEqual(power.value as? String, speed)
        let changedSpeed = power.value as? String
        func menu() { more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        func selected(_ id: String) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已选中"), object: app.buttons[id])], timeout: 6), .completed)
        }
        menu(); snap("p08a-settings-light")
        app.buttons[prefix + ".cameraMode"].tap(); app.buttons[prefix + ".dismissMenu"].tap()
        selected("shotCamera.thirdPerson")
        XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled)
        snap("p08a-3d")
        let ids = ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        for id in ids { XCTAssertTrue(app.buttons[id].isHittable) }
        // Camera stack uses the complete ruler shell's centre, exactly as daily.
        let shell = power.frame
        let first = app.buttons[ids[0]].frame, last = app.buttons[ids[3]].frame
        XCTAssertEqual((first.minY + last.maxY) / 2, shell.midY, accuracy: 1)
        XCTAssertLessThan(first.midX, shell.minX)
        app.buttons["shotCamera.firstPerson"].tap(); selected("shotCamera.firstPerson"); snap("p08a-first-person")
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.temporaryTopDown"); snap("p08a-temporary-topdown")
        for id in ids.prefix(3) { XCTAssertFalse(app.buttons[id].isEnabled) }
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.firstPerson")
        app.buttons["dailyClearance.observeTable"].tap(); selected("dailyClearance.observeTable"); snap("p08a-overview")
        XCTAssertEqual(power.value as? String, changedSpeed)
        XCTAssertEqual(metrics.label, initial)
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)))
        table.pinch(withScale: 1.2, velocity: 1)
        menu(); app.buttons[prefix + ".cameraMode"].tap(); app.buttons[prefix + ".dismissMenu"].tap()
        let probe = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == "_8" })
        let screen = try XCTUnwrap(ball["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: screen[0], dy: screen[1]))
            .press(forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: screen[0] + 110, dy: screen[1] + 40)),
                   withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
        XCTAssertNotEqual(metrics.label, initial)
        try assertTeachingDiagramAlignment()
        snap("p08a-dragged")
        for key in ["_1", "_2"] { app.buttons["paletteBall_" + key].tap(); XCTAssertEqual(app.buttons["paletteBall_" + key].value as? String, "在桌上") }
        for key in ["_1", "_2", "_8"] { app.buttons["paletteBall_" + key].tap() }
        XCTAssertTrue(metrics.label.contains("—")); app.buttons["paletteBall__8"].tap(); XCTAssertFalse(metrics.label.contains("—"))
        menu(); app.buttons["menu.tableGrid"].tap()
        let beforeRotation = metrics.label
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        XCTAssertEqual(metrics.label, beforeRotation); snap("p08a-portrait-2d")
        menu(); app.buttons[prefix + ".cameraMode"].tap(); app.buttons[prefix + ".dismissMenu"].tap()
        XCTAssertTrue(app.buttons["shotCamera.firstPerson"].isHittable); snap("p08a-portrait-3d")
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testAngleDynamicObservationRoundTrip() throws {
        continueAfterFailure = false
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=angleDynamic", "-v54.forceLight", "-3dDrag.probe"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 20))
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        XCTAssertTrue(metrics.exists)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).count, 15)
        for key in ["_1", "_2", "_3"] {
            let ball = app.buttons["paletteBall_" + key]
            ball.tap(); XCTAssertEqual(ball.value as? String, "在桌上")
        }
        for key in ["_1", "_2", "_3"] { app.buttons["paletteBall_" + key].tap() }
        let initial = metrics.label
        try assertTeachingDiagramAlignment()
        snap("ad01-2d")
        app.buttons["angleDynamic.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["menu.tableGrid"].exists)
        snap("ad01-settings-light")
        let camera = app.buttons["angleDynamic.cameraMode"]
        camera.tap(); XCTAssertEqual(camera.value as? String, "3D")
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled)
        XCTAssertEqual(metrics.label, initial)
        XCTAssertFalse(app.buttons["angleDynamic.observation"].exists)
        let cameraIDs = ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        func selected(_ id: String) {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已选中"), object: app.buttons[id])
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed)
        }
        for id in cameraIDs { XCTAssertTrue(app.buttons[id].isHittable) }
        selected("shotCamera.thirdPerson")
        snap("ad01-3d")
        app.buttons["shotCamera.firstPerson"].tap()
        selected("shotCamera.firstPerson")
        XCTAssertEqual(metrics.label, initial)
        snap("ad01-first-person")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        selected("shotCamera.temporaryTopDown")
        for id in cameraIDs.prefix(3) { XCTAssertFalse(app.buttons[id].isEnabled) }
        XCTAssertEqual(metrics.label, initial)
        snap("ad01-temporary-topdown")
        app.buttons["shotCamera.temporaryTopDown"].tap()
        selected("shotCamera.firstPerson")
        app.buttons["dailyClearance.observeTable"].tap()
        selected("dailyClearance.observeTable")
        snap("ad01-overview")
        app.buttons["shotCamera.thirdPerson"].tap()
        selected("shotCamera.thirdPerson")
        XCTAssertEqual(metrics.label, initial)
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)))
        table.pinch(withScale: 1.2, velocity: 1)
        app.buttons["angleDynamic.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); camera.tap()
        XCTAssertEqual(camera.value as? String, "2D")
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertEqual(metrics.label, initial)
        XCTAssertTrue(app.buttons["paletteBall__1"].isEnabled)
        let beforeDrag = metrics.label
        let probe = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == "_8" })
        let screen = try XCTUnwrap(ball["screen"] as? [Double])
        print("AD01 drag frame=\(table.frame), screen=\(screen), probe=\(probe)")
        // Move beyond the shared 52pt finger-offset dead zone, then continue placing the ball.
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: screen[0], dy: screen[1]))
            .press(forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: screen[0] + 110, dy: screen[1] + 40)),
                   withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
        print("AD01 after drag=\(table.value ?? "nil")")
        XCTAssertNotEqual(metrics.label, beforeDrag, "拖球须真实更新教学读数")
        snap("ad01-dragged")
        app.buttons["paletteBall__8"].tap()
        XCTAssertEqual(app.buttons["paletteBall__8"].value as? String, "未在桌上")
        for readout in ["切角、—", "d/R、—", "横移、—", "偏移、—"] {
            XCTAssertTrue(metrics.label.contains(readout), metrics.label)
        }
        XCTAssertEqual(metrics.label.filter { $0 == "—" }.count, 5, metrics.label)
        app.buttons["paletteBall__8"].tap()
        XCTAssertFalse(metrics.label.contains("—"))
    }

    func testAngleDynamicTemplateRotationAndGrid() {
        continueAfterFailure = false
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=angleDynamic", "-v54.forceDark"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 20))
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        let initial = metrics.label
        app.buttons["angleDynamic.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let grid = app.buttons["menu.tableGrid"]
        let initialGrid = grid.value as? String
        grid.tap()
        app.buttons["angleDynamic.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertNotEqual(grid.value as? String, initialGrid)
        snap("ad01-settings-dark")
        app.buttons["angleDynamic.cameraMode"].tap()
        app.buttons["angleDynamic.dismissMenu"].tap()
        XCTAssertEqual(metrics.label, initial)
        snap("ad01-landscape-3d")
        XCUIDevice.shared.orientation = .portrait
        sleep(2)
        XCTAssertEqual(metrics.label, initial)
        snap("ad01-portrait-3d")
        app.buttons["angleDynamic.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["angleDynamic.cameraMode"].tap()
        grid.tap()
        XCTAssertEqual(metrics.label, initial)
        XCTAssertTrue(app.buttons["paletteBall__15"].isHittable)
        snap("ad01-portrait-2d")
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testSeparationAtlasDarkSettings() {
        continueAfterFailure = false
        app.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=separation", "-v54.forceDark"])
        let more = app.buttons["separationAngleAtlas.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["menu.tableGrid"].isHittable)
        snap("p08a-settings-dark")
        app.buttons["separationAngleAtlas.cameraMode"].tap()
        app.buttons["separationAngleAtlas.dismissMenu"].tap()
        XCTAssertTrue(app.buttons["shotCamera.thirdPerson"].isHittable)
        snap("p08a-dark-3d")
    }

    func testCushionAtlas3DRoundTrip() {
        runAtlas3DRoundTrip(title: "加塞吃库图谱", prefix: "cushionEnglishAtlas")
    }

    func testAtlasGridControlsAcrossModes() {
        continueAfterFailure = false
        for (title, prefix) in [("分离角图谱", "separationAngleAtlas"),
                                ("加塞吃库图谱", "cushionEnglishAtlas")] {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
            XCTAssertTrue(openCard(homeTab: "学", title: title))
            if prefix == "separationAngleAtlas" {
                let more = app.buttons[prefix + ".more"]
                func openMenu() { more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                openMenu()
                let grid = app.buttons["menu.tableGrid"]
                let initial = grid.value as? String
                grid.tap(); openMenu()
                XCTAssertNotEqual(grid.value as? String, initial)
                app.buttons[prefix + ".cameraMode"].tap()
                app.buttons[prefix + ".dismissMenu"].tap()
                snap("v63-" + prefix + "-grid-3d")
                openMenu(); grid.tap(); openMenu()
                XCTAssertEqual(grid.value as? String, initial)
                continue
            }
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


extension S2_ShotPagesLayoutUITests {
    func testP01C56CurrentBefore() throws {
        continueAfterFailure = false
        let evidence = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/table-page-adaptation/P01/c56-r01/before")
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        func rect(_ r: CGRect) -> [String: Double] {
            ["x": Double(r.minX), "y": Double(r.minY), "width": Double(r.width), "height": Double(r.height)]
        }
        func capture(_ name: String) throws {
            // Deliberately sample the settled state, not the panel/mode transition.
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            let shot = XCUIScreen.main.screenshot()
            try shot.pngRepresentation.write(to: evidence.appendingPathComponent(name + ".png"))
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            try app.debugDescription.write(to: evidence.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
            let tree = try app.snapshot()
            func collect(_ node: XCUIElementSnapshot) -> [[String: Any]] {
                var result: [[String: Any]] = []
                if !node.identifier.isEmpty || node.elementType == .button || node.elementType == .navigationBar {
                    result.append(["id": node.identifier, "label": node.label,
                                   "value": String(describing: node.value ?? ""),
                                   "frame": rect(node.frame), "enabled": node.isEnabled,
                                   "type": node.elementType.rawValue])
                }
                for child in node.children { result += collect(child) }
                return result
            }
            let elements = collect(tree)
            let data: [String: Any] = ["name":name, "window":rect(app.windows.firstMatch.frame),
                                      "deviceOrientation":XCUIDevice.shared.orientation.rawValue, "elements":elements]
            try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted,.sortedKeys])
                .write(to: evidence.appendingPathComponent(name + "-metrics.json"))
        }
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(openCard(homeTab: "打", title: "分离角与走位"))
        let mode = app.buttons["shotSimulation.cameraMode"]
        XCTAssertEqual(mode.value as? String, "2D")
        try capture("01-2d-pocket")
        app.buttons["更多"].tap()
        XCTAssertTrue(app.buttons["恢复默认"].waitForExistence(timeout: 5))
        try capture("02-more")
        app.buttons["恢复默认"].tap()
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(app.buttons["回中"].waitForExistence(timeout: 5))
        try capture("03-2d-spin")
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertFalse(app.buttons["回中"].exists)
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("04-3d-pocket")
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(app.buttons["回中"].waitForExistence(timeout: 5))
        try capture("05-3d-spin")
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.75)).tap()
        XCTAssertFalse(app.buttons["回中"].exists)
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        app.buttons["瞄准模式：进袋，点击切换"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch.exists)
        try capture("06-2d-free")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("07-3d-free")
        XCUIDevice.shared.orientation = .landscapeRight
        try capture("08-rotation-request")
        XCUIDevice.shared.orientation = .portrait
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        try capture("09-2d-returned")
        goBack()
        XCTAssertTrue(app.buttons["angleHomeTab_打"].waitForExistence(timeout: 5))
        try capture("10-normal-exit")
    }
}
