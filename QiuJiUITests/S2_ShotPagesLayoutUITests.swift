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

    private func assertTeachingDiagramAlignment(surface: String = "main", file: StaticString = #filePath, line: UInt = #line) throws {
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        let json = try XCTUnwrap(table.value as? String)
        let data = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(data["diagramSurface"] as? String, surface, file: file, line: line)
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
        XCTAssertEqual(diagram["arcHidden"] as? Bool, false, file: file, line: line)
    }

    func testSeparationAtlas3DRoundTrip() throws {
        try runTeachingAtlas(page: "separation", prefix: "separationAngleAtlas", shotPrefix: "p08a")
    }

    func testCushionAtlas3DRoundTrip() throws {
        try runTeachingAtlas(page: "cushion", prefix: "cushionEnglishAtlas", shotPrefix: "p08b", hasSpin: true)
    }

    private func runTeachingAtlas(page: String, prefix: String, shotPrefix: String, hasSpin: Bool = false) throws {
        continueAfterFailure = false
        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=\(page)", "-v54.forceLight", "-3dDrag.probe"])
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
        for removed in ["力度", "打点", "可加塞"] { XCTAssertFalse(metrics.label.contains(removed)) }
        try assertTeachingDiagramAlignment()
        snap(shotPrefix + "-2d")
        func inspectSpin(_ state: String) {
            app.buttons["shotStage.spinEntry"].tap()
            XCTAssertTrue(app.buttons["高杆增加 1%"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["左塞增加 1%"].exists)
            XCTAssertFalse(app.buttons["右塞增加 1%"].exists)
            app.buttons["高杆增加 1%"].tap()
            XCTAssertTrue(app.staticTexts["高1%"].exists)
            let disc = app.descendants(matching: .any).matching(identifier: "spinPad.disc").firstMatch
            XCTAssertTrue(app.windows.firstMatch.frame.contains(disc.frame))
            snap(shotPrefix + "-spin-" + state)
            app.buttons["回中"].tap()
            XCTAssertTrue(app.staticTexts["中心球"].exists)
            app.buttons["关闭打点"].tap()
            XCTAssertFalse(app.buttons["高杆增加 1%"].exists)
        }
        if hasSpin { inspectSpin("2d") }
        for i in 0..<7 { toggle(i, selected: false) }
        toggle(7, selected: true)
        XCTAssertEqual(trackCount.label, "1/8")
        snap(shotPrefix + "-last-track")
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
        menu(); snap(shotPrefix + "-settings-light")
        app.buttons[prefix + ".cameraMode"].tap(); app.buttons[prefix + ".dismissMenu"].tap()
        selected("shotCamera.thirdPerson")
        XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled)
        snap(shotPrefix + "-3d")
        if hasSpin { inspectSpin("3d") }
        let ids = ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson", "shotCamera.temporaryTopDown"]
        for id in ids { XCTAssertTrue(app.buttons[id].isHittable) }
        // Camera stack uses the complete ruler shell's centre, exactly as daily.
        let shell = hasSpin ? app.descendants(matching: .any).matching(identifier: "shotStage.powerShell").firstMatch.frame : power.frame
        let first = app.buttons[ids[0]].frame, last = app.buttons[ids[3]].frame
        XCTAssertEqual((first.minY + last.maxY) / 2, shell.midY, accuracy: 1)
        XCTAssertLessThan(first.midX, shell.minX)
        app.buttons["shotCamera.firstPerson"].tap(); selected("shotCamera.firstPerson"); snap(shotPrefix + "-first-person")
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.temporaryTopDown")
        try assertTeachingDiagramAlignment(surface: "temporaryTopDown")
        snap(shotPrefix + "-temporary-topdown")
        for id in ids.prefix(3) { XCTAssertFalse(app.buttons[id].isEnabled) }
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.firstPerson")
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.temporaryTopDown")
        try assertTeachingDiagramAlignment(surface: "temporaryTopDown")
        app.buttons["shotCamera.temporaryTopDown"].tap(); selected("shotCamera.firstPerson")
        app.buttons["dailyClearance.observeTable"].tap(); selected("dailyClearance.observeTable"); snap(shotPrefix + "-overview")
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
        snap(shotPrefix + "-dragged")
        for key in ["_1", "_2"] { app.buttons["paletteBall_" + key].tap(); XCTAssertEqual(app.buttons["paletteBall_" + key].value as? String, "在桌上") }
        for key in ["_1", "_2", "_8"] { app.buttons["paletteBall_" + key].tap() }
        XCTAssertTrue(metrics.label.contains("—")); app.buttons["paletteBall__8"].tap(); XCTAssertFalse(metrics.label.contains("—"))
        menu(); app.buttons["menu.tableGrid"].tap()
        let beforeRotation = metrics.label
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        XCTAssertEqual(metrics.label, beforeRotation); snap(shotPrefix + "-portrait-2d")
        menu(); app.buttons[prefix + ".cameraMode"].tap(); app.buttons[prefix + ".dismissMenu"].tap()
        XCTAssertTrue(app.buttons["shotCamera.firstPerson"].isHittable); snap(shotPrefix + "-portrait-3d")
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
        try assertTeachingDiagramAlignment(surface: "temporaryTopDown")
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

    func testAtlasGridControlsAcrossModes() {
        continueAfterFailure = false
        for (title, prefix) in [("分离角图谱", "separationAngleAtlas"),
                                ("加塞吃库图谱", "cushionEnglishAtlas")] {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
            XCTAssertTrue(openCard(homeTab: "学", title: title))
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

/// P03: exercise the editor configuration of the shared daily table, including read-only sequences.
final class P03_ComposerTemplateUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ value: XCUIElement, timeout: TimeInterval = 40) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: value)], timeout: timeout), .completed)
    }
    private func launch(tryout: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyLayout.probe", "-3dDrag.probe",
            tryout ? "-deeplink.tryout=drill_c042" : "-dailyInteraction.sharedPage=composer"])
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 25))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "须实际进入横屏，不能只发送旋转指令")
        }
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
        }
    }
    private func menu() { app.buttons["freeplay.moreMenu"].tap(); XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout: 3)) }
    private func viewMode(_ value: String) {
        menu(); app.buttons["freeplay.cameraMode"].tap()
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, value)
        app.buttons["关闭菜单"].tap(); sleep(1)
    }
    private func aimMode(_ value: String, tryout: Bool = false) {
        menu(); app.buttons["dailyClearance.aimModeMenu"].tap()
        let item = app.buttons[tryout ? "tryoutMode_" + value : "dailyClearance.aim." + value]
        ready(item); item.tap()
    }
    func testEditableBoardAndCameraRoundTrip() throws {
        launch()
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_'")).count, 15)
        let stage = element("freeplay.stage").frame
        try capture("composer-2d")
        let ball = app.buttons["paletteBall__3"]
        XCTAssertEqual(ball.value as? String, "未在桌上"); ball.tap()
        XCTAssertNotEqual(ball.value as? String, "未在桌上")
        // More than two target balls are allowed in the editor.
        app.buttons["paletteBall__4"].tap()
        XCTAssertTrue((element("composer.landscape").value as? String ?? "").contains("_4"))
        aimMode("free")
        let wheel = element("shotStage.aimWheel"); XCTAssertTrue(wheel.isEnabled)
        menu(); XCTAssertTrue(app.buttons["composer.rename"].exists)
        XCTAssertTrue(app.buttons["composer.clear"].exists); XCTAssertTrue(app.buttons["composer.reset"].exists)
        XCTAssertFalse(app.buttons["freeplay.clearTable"].exists)
        try capture("composer-settings")
        app.buttons["关闭菜单"].tap()
        viewMode("3D")
        for id in ["shotCamera.firstPerson", "shotCamera.thirdPerson", "dailyClearance.observeTable"] {
            ready(app.buttons[id]); app.buttons[id].tap(); sleep(1)
        }
        try capture("composer-3d")
        let temp = app.buttons["shotCamera.temporaryTopDown"]
        ready(temp); temp.tap(); sleep(1); try capture("composer-temporary2d")
        temp.tap(); viewMode("2D")
        XCTAssertEqual(element("freeplay.stage").frame.width, stage.width, accuracy: 1)
        XCTAssertEqual(element("freeplay.stage").frame.height, stage.height, accuracy: 1)
        let strike = app.buttons["dailyClearance.strike"]
        ready(strike); strike.tap(); ready(app.buttons["dailyClearance.playback"])
        try capture("composer-settled")
        app.buttons["dailyClearance.playback"].tap(); ready(app.buttons["dailyClearance.undo"])
        app.buttons["dailyClearance.undo"].tap(); ready(strike)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            try capture("composer-ipad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
        }
        try capture("composer-restored")
    }
    func testTryoutSequenceAndEditableModes() throws {
        launch(tryout: true)
        let brief = element("tryout.briefCard")
        XCTAssertTrue(brief.waitForExistence(timeout: 5)); try capture("tryout-brief"); brief.tap()
        XCTAssertTrue(app.buttons["tryout.rearrange"].exists)
        XCTAssertFalse(app.buttons["break.entry"].exists)
        XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled)
        XCTAssertFalse(element("shotStage.aimWheel").isEnabled)
        viewMode("3D"); try capture("tryout-sequence-3d")
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(strike.label, "击打"); ready(strike); strike.tap()
        XCTAssertEqual(strike.label, "暂停"); ready(strike); strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ AND enabled == true", "继续"), object: strike)], timeout: 60), .completed)
        let status = element("composer.status").label
        XCTAssertTrue(status.contains("第 1/"), status)
        app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(element("spinPad.card").waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["回中"].exists); XCTAssertFalse(app.buttons["高杆增加 1%"].exists)
        try capture("tryout-paused-readonly-spin")
        viewMode("2D"); XCTAssertEqual(element("composer.status").label, status)
        app.buttons["dailyClearance.playback"].tap(); ready(strike, timeout: 60)
        XCTAssertEqual(element("composer.status").label, status)
        try capture("tryout-replayed")
        aimMode("自由", tryout: true)
        XCTAssertEqual(strike.label, "击球"); XCTAssertTrue(app.buttons["paletteBall__15"].isEnabled)
        XCTAssertTrue(element("shotStage.aimWheel").isEnabled)
        try capture("tryout-free")
        aimMode("进袋", tryout: true); try capture("tryout-pocket")
        aimMode("序列", tryout: true)
        XCTAssertEqual(strike.label, "击打"); XCTAssertFalse(app.buttons["paletteBall__1"].isEnabled)
        app.buttons["tryout.rearrange"].tap()
        XCTAssertFalse(app.buttons["break.game.15"].exists, "重摆试打球形不能打开普通开球玩法")
        XCTAssertTrue(element("composer.status").label.contains("第 1/"))
        menu(); app.buttons["tryout.info"].tap(); XCTAssertTrue(brief.waitForExistence(timeout: 3))
        try capture("tryout-returned")
    }
}

/// P04: draw a real constraint, solve, preserve it across the daily camera and palette layout.
final class P04_SiluTemplateUITests: XCTestCase {
    private var app: XCUIApplication!
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ value: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: value)], timeout: timeout), .completed)
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func menu() { app.buttons["silu.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); XCTAssertTrue(app.buttons["silu.cameraMode"].waitForExistence(timeout: 3)) }
    private func mode(_ value: String) {
        menu(); let button = app.buttons["silu.cameraMode"]
        if button.value as? String != value { button.tap() }
        XCTAssertEqual(button.value as? String, value)
        app.buttons["silu.dismissMenu"].tap(); sleep(1)
    }
    private func chooseMenu(_ id: String) {
        menu()
        let button = app.buttons[id]
        for _ in 0..<4 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(button); button.tap()
    }
    func testSiluBreakCancelDeliveryAndClear() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.silu"])
        XCTAssertTrue(element("silu.template").waitForExistence(timeout: 25))
        let before = app.buttons["paletteBall__2"].value as? String
        mode("3D")
        chooseMenu("break.entry"); ready(app.buttons["break.game.4"]); app.buttons["break.game.4"].tap()
        ready(app.buttons["break.rerack"])
        try capture("silu-break-ready")
        chooseMenu("silu.cancelBreak")
        XCTAssertEqual(app.buttons["paletteBall__2"].value as? String, before)
        chooseMenu("break.entry"); app.buttons["break.game.4"].tap()
        ready(app.buttons["silu.strike"]); app.buttons["silu.strike"].tap()
        let strike = app.buttons["silu.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '完成' AND enabled == true"), object: strike)], timeout: 60), .completed)
        try capture("silu-break-settled"); strike.tap()
        XCTAssertFalse(app.buttons["break.rerack"].exists)
        mode("2D"); chooseMenu("silu.clear")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' AND value == '在桌上'")).count, 0)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        try capture("silu-cleared-cue-retained")
    }
    func testSiluConstraintCameraAndPalette() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.silu", "-v63.cameraDiagnostics"])
        XCTAssertTrue(element("silu.template").waitForExistence(timeout: 25))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "须实际进入横屏，不能只发送旋转指令")
        }
        let table = element("table.scene")
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' ")).count, 15)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        try capture("silu-2d")
        let frame = table.frame
        app.buttons["paletteBall__3"].tap()
        XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "在桌上")
        menu(); let reset = app.buttons["silu.reset"]
        if !reset.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(reset); reset.tap()
        app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.37, dy: 0.48)).press(forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.76)))
        ready(app.buttons["solver.solve"]); try capture("silu-constraint")
        app.buttons["solver.solve"].tap()
        ready(app.buttons["silu.strike"], timeout: 90)
        try capture("silu-solved")
        let status = app.staticTexts["silu.status"].label
        mode("3D")
        ready(app.buttons["shotCamera.thirdPerson"])
        app.buttons["shotCamera.firstPerson"].tap(); sleep(1)
        app.buttons["shotCamera.thirdPerson"].tap(); sleep(1)
        XCTAssertGreaterThanOrEqual(table.frame.maxY, app.windows.firstMatch.frame.maxY - 1, "3D must cover the bottom safe area")
        try capture("silu-3d")
        menu(); app.buttons["silu.trajectory"].tap(); app.buttons["silu.trajectory.off"].tap()
        try capture("silu-3d-guides-off")
        menu(); app.buttons["silu.trajectory"].tap(); app.buttons["silu.trajectory.0"].tap()
        let temp = app.buttons["shotCamera.temporaryTopDown"]
        ready(temp); temp.tap(); sleep(1); try capture("silu-temporary2d"); temp.tap()
        mode("2D")
        XCTAssertEqual(table.frame.width, frame.width, accuracy: 1)
        XCTAssertEqual(table.frame.height, frame.height, accuracy: 1)
        XCTAssertEqual(app.staticTexts["silu.status"].label, status)
        ready(app.buttons["shotStage.spinEntry"]); app.buttons["shotStage.spinEntry"].tap()
        XCTAssertTrue(element("silu.spinPad").waitForExistence(timeout: 3)); try capture("silu-spin")
        app.buttons["关闭打点"].firstMatch.tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            try capture("silu-ipad-portrait")
        }
    }
}

final class P05_PlanThreeTemplateUITests: XCTestCase {
    private var app: XCUIApplication!
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ value: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: value)], timeout: timeout), .completed)
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func menu() { app.buttons["planthree.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); XCTAssertTrue(app.buttons["planthree.cameraMode"].waitForExistence(timeout: 3)) }
    private func mode(_ value: String) {
        menu(); let button = app.buttons["planthree.cameraMode"]
        if button.value as? String != value { button.tap() }
        XCTAssertEqual(button.value as? String, value)
        app.buttons["planthree.dismissMenu"].tap(); sleep(1)
    }
    private func chooseMenu(_ id: String) {
        menu()
        let button = app.buttons[id]
        for _ in 0..<4 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(button); button.tap()
    }

    private var roles: String { app.buttons["planthree.roles"].value as? String ?? "" }
    private func launch(_ fixture: String? = nil) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.planThree", "-3dDrag.probe"] + (fixture.map { ["-planThree." + $0] } ?? []))
        XCTAssertTrue(element("planthree.template").waitForExistence(timeout: 25))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "须实际进入横屏，不能只发送旋转指令")
        }
    }
    private func tapBall(_ key: String) throws {
        let table = element("table.scene")
        let raw = try XCTUnwrap(table.value as? String)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let balls = try XCTUnwrap(dict["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == key })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1])).tap()
    }
    func testPlanRolesCameraAndRestoration() throws {
        launch("threeBallDimmed")
        let table = element("table.scene"), beforeFrame = element("table.scene").frame
        let initialRoles = roles
        XCTAssertTrue(roles.contains("①球:1号球")); XCTAssertTrue(roles.contains("②球:2号球")); XCTAssertTrue(roles.contains("③球:3号球"))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' ")).count, 15)
        try capture("planthree-2d")
        mode("3D")
        chooseMenu("break.entry"); ready(app.buttons["break.game.4"]); app.buttons["break.game.4"].tap()
        ready(app.buttons["break.rerack"]); try capture("planthree-break")
        chooseMenu("planthree.cancelBreak"); XCTAssertEqual(roles, initialRoles)
        app.buttons["solver.solve"].tap(); ready(app.buttons["planthree.strike"], timeout: 90)
        try capture("planthree-solved-3d")
        let temp = app.buttons["shotCamera.temporaryTopDown"]
        ready(temp); temp.tap(); sleep(1); try capture("planthree-temporary2d"); temp.tap()
        app.buttons["planthree.strike"].tap(); ready(app.buttons["planthree.undo"], timeout: 60)
        XCTAssertTrue(roles.contains("①球:2号球")); XCTAssertTrue(roles.contains("②球:3号球")); XCTAssertTrue(roles.contains("③球:未选择")); XCTAssertTrue(roles.contains("②袋:未选择"))
        try capture("planthree-advanced")
        let advancedRoles = roles
        ready(app.buttons["planthree.replay"]); app.buttons["planthree.replay"].tap()
        ready(app.buttons["planthree.undo"], timeout: 60)
        XCTAssertEqual(roles, advancedRoles, "Replay must preserve the current role plan")
        try capture("planthree-replayed")
        app.buttons["planthree.undo"].tap(); XCTAssertEqual(roles, initialRoles)
        XCTAssertFalse(app.buttons["planthree.replay"].isEnabled, "Undo consumes the previous-shot context")
        ready(app.buttons["planthree.strike"]); try capture("planthree-undone")
        mode("2D"); XCTAssertEqual(table.frame.width, beforeFrame.width, accuracy: 1); XCTAssertEqual(table.frame.height, beforeFrame.height, accuracy: 1)
        app.buttons["shotStage.spinEntry"].tap(); try capture("planthree-spin"); app.buttons["关闭打点"].firstMatch.tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            try capture("planthree-ipad-portrait")
        }
    }
    func testPlanRoleSelectionAndClear() throws {
        launch()
        app.buttons["planthree.roles"].tap()
        XCTAssertTrue(app.buttons["planthree.role.4"].waitForExistence(timeout: 3))
        app.buttons["planthree.role.4"].tap()
        try tapBall("_3")
        XCTAssertTrue(roles.contains("③球:3号球"))
        chooseMenu("planthree.clearPlan")
        XCTAssertFalse(roles.contains("3号球"))
        try tapBall("_1")
        XCTAssertTrue(roles.contains("①球:1号球"))
        XCTAssertTrue(app.staticTexts["planthree.status"].label.contains("选袋"))
        try capture("planthree-roles-assigned")
        chooseMenu("planthree.clear")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' AND value == '在桌上'")).count, 0)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        try capture("planthree-cleared")
    }
}

final class P06_DefenseTemplateUITests: XCTestCase {
    private var app: XCUIApplication!
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ value: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: value)], timeout: timeout), .completed)
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func menu() { app.buttons["snooker.more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); XCTAssertTrue(app.buttons["snooker.cameraMode"].waitForExistence(timeout: 3)) }
    private func mode(_ value: String) {
        menu(); let button = app.buttons["snooker.cameraMode"]
        if button.value as? String != value { button.tap() }
        XCTAssertEqual(button.value as? String, value)
        app.buttons["snooker.dismissMenu"].tap(); sleep(1)
    }
    private func chooseMenu(_ id: String) {
        menu()
        let button = app.buttons[id]
        for _ in 0..<4 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(button); button.tap()
    }
    private func tapBall(_ key: String) throws {
        let table = element("table.scene")
        let raw = try XCTUnwrap(table.value as? String)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let balls = try XCTUnwrap(dict["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == key })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1])).tap()
    }

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.snooker", "-3dDrag.probe"])
        XCTAssertTrue(element("snooker.template").waitForExistence(timeout: 25))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "须实际进入横屏，不能只发送旋转指令")
        }
    }
    func testDefenseSolutionCameraAndRestore() throws {
        launch()
        let table = element("table.scene"), frame = element("table.scene").frame
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' ")).count, 15)
        try capture("defense-2d")
        ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        ready(app.buttons["snooker.strike"], timeout: 90)
        let solved = app.staticTexts["snooker.status"].label
        try capture("defense-solved")
        mode("3D"); ready(app.buttons["shotCamera.firstPerson"])
        app.buttons["shotCamera.firstPerson"].tap(); sleep(1)
        app.buttons["shotCamera.thirdPerson"].tap(); sleep(1)
        XCTAssertGreaterThanOrEqual(table.frame.maxY, app.windows.firstMatch.frame.maxY - 1)
        try capture("defense-3d")
        menu(); app.buttons["snooker.trajectory"].tap(); app.buttons["snooker.trajectory.off"].tap()
        try capture("defense-guides-off")
        menu(); app.buttons["snooker.trajectory"].tap(); app.buttons["snooker.trajectory.0"].tap()
        let temp = app.buttons["shotCamera.temporaryTopDown"]
        ready(temp); temp.tap(); sleep(1); try capture("defense-temporary2d"); temp.tap()
        app.buttons["snooker.strike"].tap(); ready(app.buttons["snooker.undo"], timeout: 60)
        try capture("defense-settled")
        ready(app.buttons["snooker.replay"]); app.buttons["snooker.replay"].tap()
        ready(app.buttons["snooker.undo"], timeout: 60)
        app.buttons["snooker.undo"].tap(); ready(app.buttons["snooker.strike"])
        XCTAssertTrue(app.staticTexts["snooker.status"].label.contains("已退回"))
        XCTAssertFalse(solved.isEmpty)
        mode("2D")
        XCTAssertEqual(table.frame.width, frame.width, accuracy: 1); XCTAssertEqual(table.frame.height, frame.height, accuracy: 1)
        app.buttons["shotStage.spinEntry"].tap(); try capture("defense-spin"); app.buttons["关闭打点"].firstMatch.tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            try capture("defense-ipad-portrait")
        }
    }
    func testDefenseLegalSelectionAndClear() throws {
        launch()
        app.buttons["paletteBall__8"].tap()
        XCTAssertEqual(app.buttons["paletteBall__8"].value as? String, "在桌上")
        app.buttons["snooker.tool"].tap(); app.buttons["目标球"].tap()
        try tapBall("_8")
        XCTAssertTrue(app.staticTexts["snooker.status"].label.contains("不能选 8"))
        try tapBall("_9")
        XCTAssertTrue(app.staticTexts["snooker.status"].label.contains("已就绪"))
        try capture("defense-selected")
        app.buttons["snooker.clearSelection"].tap()
        XCTAssertFalse(app.buttons["solver.solve"].isEnabled)
        chooseMenu("snooker.clear")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' AND value == '在桌上'")).count, 0)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        try capture("defense-cleared")
    }
}

final class P07_BankKickTemplateUITests: XCTestCase {
    private var app: XCUIApplication!
    private var route = "bankshot"
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ value: XCUIElement, timeout: TimeInterval = 45) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: value)], timeout: timeout), .completed)
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot(); let att = XCTAttachment(screenshot: shot)
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func menu() { app.buttons["\(route).more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); XCTAssertTrue(app.buttons["\(route).cameraMode"].waitForExistence(timeout: 3)) }
    private func mode(_ value: String) {
        menu(); let button = app.buttons["\(route).cameraMode"]
        if button.value as? String != value { button.tap() }
        XCTAssertEqual(button.value as? String, value)
        app.buttons["\(route).dismissMenu"].tap(); sleep(1)
    }
    private func chooseMenu(_ id: String) {
        menu()
        let button = app.buttons[id]
        for _ in 0..<4 where !button.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(button); button.tap()
    }
    private func tapBall(_ key: String) throws {
        let table = element("table.scene")
        let raw = try XCTUnwrap(table.value as? String)
        let dict = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let balls = try XCTUnwrap(dict["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == key })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1])).tap()
    }

    private func launch() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-3dDrag.probe"])
        app.switchTab(.angle)
        let section = app.buttons["angleHomeTab_解"]
        XCTAssertTrue(section.waitForExistence(timeout: 5)); section.tap()
        let card = app.buttons[route == "bankshot" ? "翻袋解球" : "颗星解球"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(element("\(route).template").waitForExistence(timeout: 25))
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height, "须实际进入横屏，不能只发送旋转指令")
        }
    }
    func testBankSolverAndFreeState() throws { route = "bankshot"; try solverFlow() }
    func testKickSolverAndFreeState() throws { route = "reflection"; try solverFlow() }
    private func solverFlow() throws {
        launch()
        let table = element("table.scene"), frame = table.frame
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'paletteBall_' ")).count, 15)
        XCTAssertFalse(app.buttons["paletteBall_cueBall"].exists)
        try capture(route + "-2d")
        // Search completion and route readiness are separate from multiple-solution availability.
        // Default engine search retains the established unit-test 60-second budget.
        ready(app.buttons[route + ".strike"], timeout: 60)
        if app.buttons["solver.nextSolution"].isEnabled { app.buttons["solver.nextSolution"].tap() }
        let solved = app.staticTexts["solver.status"].label
        try capture(route + "-solved")
        mode("3D"); ready(app.buttons["shotCamera.firstPerson"])
        app.buttons["shotCamera.firstPerson"].tap(); sleep(1)
        app.buttons["shotCamera.thirdPerson"].tap(); sleep(1)
        XCTAssertGreaterThanOrEqual(table.frame.maxY, app.windows.firstMatch.frame.maxY - 1)
        XCTAssertEqual(app.staticTexts["solver.status"].label, solved)
        try capture(route + "-3d")
        let temp = app.buttons["shotCamera.temporaryTopDown"]
        temp.tap(); sleep(1); try capture(route + "-temporary2d"); temp.tap()
        menu(); app.buttons[route + ".trajectory"].tap(); app.buttons[route + ".trajectory.off"].tap()
        try capture(route + "-guides-off")
        menu(); app.buttons[route + ".trajectory"].tap(); app.buttons[route + ".trajectory.0"].tap()
        app.buttons["shotStage.spinEntry"].tap(); try capture(route + "-spin"); app.buttons["关闭打点"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["solver.status"].label, solved)
        app.buttons[route + ".strike"].tap()
        ready(app.buttons["solver.replay"], timeout: 40)
        app.buttons["solver.replay"].tap(); ready(app.buttons["solver.undo"], timeout: 40)
        app.buttons["solver.undo"].tap(); ready(app.buttons[route + ".strike"])
        XCTAssertEqual(app.staticTexts["solver.status"].label, solved)
        try capture(route + "-solve-restored")
        app.buttons["solver.mode"].tap()
        XCTAssertEqual(app.buttons["solver.mode"].value as? String, "自由")
        mode("2D")
        XCTAssertEqual(table.frame.width, frame.width, accuracy: 1)
        XCTAssertEqual(table.frame.height, frame.height, accuracy: 1)
        app.buttons["paletteBall__1"].tap()
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "在桌上")
        try capture(route + "-free-obstacle")
        app.buttons[route + ".strike"].tap(); ready(app.buttons["solver.replay"], timeout: 40)
        try capture(route + "-free-settled")
        app.buttons["solver.replay"].tap(); ready(app.buttons["solver.undo"], timeout: 40)
        app.buttons["solver.undo"].tap(); ready(app.buttons[route + ".strike"])
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "在桌上")
        app.buttons["solver.restore"].tap(); ready(app.buttons[route + ".strike"])
        XCTAssertEqual(app.buttons["solver.mode"].value as? String, "自由")
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "未在桌上")
        app.buttons["solver.mode"].tap(); ready(app.buttons[route + ".strike"])
        XCTAssertEqual(app.buttons["solver.mode"].value as? String, "求解")
        try capture(route + "-board-restored")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            try capture(route + "-ipad-portrait")
        }
    }
}

/// Reading figures keep document navigation and compare the same figure across rotation.
final class P11_ReadingTableUITests: XCTestCase {
    func testReadingTablesRotateAndScroll() throws {
        continueAfterFailure = false
        let pages = [("学", "瞄准原理"), ("学", "瞄准方法"), ("学", "瞄准修正"),
                     ("学", "旋转与加塞"), ("学", "浅谈球感"), ("学", "瞄准点对照表"),
                     ("理", "30° 法则"), ("理", "90° 法则"), ("理", "切线法则")]
        let filter = ProcessInfo.processInfo.environment["READING_PAGE_FILTER"]
        for (index, page) in pages.enumerated() {
            if let filter, !filter.split(separator: ",").contains(Substring(String(index))) { continue }
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyLayout.probe"])
            app.switchTab(.angle)
            let section = app.buttons["angleHomeTab_" + page.0]
            XCTAssertTrue(section.waitForExistence(timeout: 5)); section.tap()
            let card = app.buttons[page.1]
            for _ in 0..<5 where !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.isHittable, page.1); card.tap()
            XCTAssertTrue(app.navigationBars[page.1].waitForExistence(timeout: 6))
            sleep(1)
            try capture(app, "reading-\(index)-portrait-top")
            let slider = app.sliders.firstMatch
            if slider.exists && slider.isHittable {
                let before = slider.value as? String
                slider.adjust(toNormalizedSliderPosition: 0.8)
                XCTAssertNotEqual(slider.value as? String, before, "教学滑块必须仍能改变参数")
                try capture(app, "reading-\(index)-adjusted")
            }
            app.swipeUp(); sleep(1)
            try capture(app, "reading-\(index)-portrait-figure")
            let baseline = ProcessInfo.processInfo.environment["READING_BASELINE_PORTRAIT"] == "1"
            if UIDevice.current.userInterfaceIdiom == .pad && !baseline {
                XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
                XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
                try capture(app, "reading-\(index)-landscape-figure")
                XCUIDevice.shared.orientation = .portrait; sleep(2)
                try capture(app, "reading-\(index)-portrait-return")
            }
            for _ in 0..<3 { app.swipeUp() }
            try capture(app, "reading-\(index)-lower")
            XCTAssertEqual(app.state, .runningForeground)
        }
    }
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let shot = XCUIScreen.main.screenshot(), att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name; att.lifetime = .keepAlways; add(att)
        let env = ProcessInfo.processInfo.environment
        if let path = env["V52_SHOT_DIR"] ?? env["TEST_RUNNER_V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
}

final class P12_StandaloneQuizUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func open(_ title: String) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-geometricQuiz.forcedAngle", "45"])
        app.switchTab(.angle)
        let section = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(section.waitForExistence(timeout: 5)); section.tap()
        let card = app.buttons[title]
        for _ in 0..<5 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable); card.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 6))
    }
    private func visible(_ element: XCUIElement) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot); att.name = name; att.lifetime = .keepAlways; add(att)
        if let path = ProcessInfo.processInfo.environment["V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func rotateIfEnabled(_ name: String) throws {
        if UIDevice.current.userInterfaceIdiom == .pad && ProcessInfo.processInfo.environment["QUIZ_BASELINE_PORTRAIT"] != "1" {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            try capture(name + "-landscape")
            XCUIDevice.shared.orientation = .portrait; sleep(2)
        }
    }
    func testAngleKeypadResultAndNext() throws {
        open("角度预测")
        try capture("quiz-angle-initial")
        try rotateIfEnabled("quiz-angle")
        app.buttons["显示参考"].tap()
        app.buttons["答题"].tap()
        XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["换题"].isHittable)
        XCTAssertTrue(app.buttons["隐藏参考"].isHittable)
        try capture("quiz-angle-keypad")
        app.buttons["4"].firstMatch.tap(); app.buttons["5"].firstMatch.tap(); app.buttons["提交"].tap()
        let next = app.buttons["下一题"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 4)); visible(next)
        try capture("quiz-angle-result")
        next.tap(); visible(app.buttons["答题"])
        try capture("quiz-angle-next")
    }
    func testAimPointDragResultAndNext() throws {
        open("瞄准点训练")
        try capture("quiz-point-initial")
        try rotateIfEnabled("quiz-point")
        let figure = app.descendants(matching: .any).matching(identifier: "aimPointDiagram.figure").firstMatch
        XCTAssertTrue(figure.exists)
        let start = figure.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.65))
        let end = figure.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.65))
        start.press(forDuration: 0.1, thenDragTo: end)
        let offset = app.staticTexts["aimPointDiagram.offset"]
        XCTAssertFalse(offset.label.contains("0.0 mm"), "拖动必须真实改变毫米偏移")
        let submit = app.buttons["提交瞄准点"]
        visible(submit); submit.tap()
        let next = app.buttons["下一题"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 4)); visible(next)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "正确偏移")).firstMatch.exists)
        try capture("quiz-point-result")
        next.tap(); visible(submit)
        try capture("quiz-point-next")
    }
}

/// Photo confirmation, internal authoring, and embedded tables keep their own workflows.
final class P13_15_EmbeddedTableUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; XCUIDevice.shared.orientation = .portrait }
    private func launch(_ args: [String] = []) {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture"] + args)
    }
    private func open(_ title: String) {
        app.switchTab(.angle)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText(title)
        let card = app.buttons[title]; XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func capture(_ name: String) throws {
        sleep(1) // Capture the settled page, not the navigation transition.
        let shot = XCUIScreen.main.screenshot(), att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name; att.lifetime = .keepAlways; add(att)
        if let path = ProcessInfo.processInfo.environment["V52_SHOT_DIR"] {
            let folder = URL(fileURLWithPath: path)
            try shot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: folder.appendingPathComponent(name + "-ax.txt"), atomically: true, encoding: .utf8)
        }
    }
    private func landscape(_ name: String) throws {
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            try capture(name + "-landscape")
        }
    }
    private func portrait(_ name: String) throws {
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        try capture(name + "-portrait-return")
    }
    func testExtractionConfirmUndoRedoAndRotation() throws {
        launch(["-extract.confirmDemo"]); open("拍照建球形")
        let table = element("table.scene"), ball = app.buttons["paletteBall__1"]
        XCTAssertTrue(table.waitForExistence(timeout: 15)); XCTAssertTrue(ball.exists)
        XCTAssertTrue(app.buttons["paletteBall_cueBall"].exists, "母球编号在照片编辑器中必须保留")
        try capture("extraction-confirm")
        ball.tap(); XCTAssertEqual(ball.value as? String, "在桌上")
        app.buttons["撤销"].tap(); XCTAssertEqual(ball.value as? String, "未在桌上")
        app.buttons["重做"].tap(); XCTAssertEqual(ball.value as? String, "在桌上")
        try landscape("extraction-confirm"); XCTAssertEqual(ball.value as? String, "在桌上")
        try portrait("extraction-confirm"); XCTAssertEqual(ball.value as? String, "在桌上")
        app.buttons["送入…"].tap()
        XCTAssertTrue(app.buttons["自由走位"].waitForExistence(timeout: 4)); app.buttons["自由走位"].tap()
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 20))
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "本轮可击打")
        XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "本轮可击打")
        try capture("extraction-to-composer")
    }
    func testBatchAuthoringRotateWithoutSaving() throws {
        launch(); open("批量出片台")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "drill_c065")).firstMatch
        for _ in 0..<50 where !row.isHittable {
            // A full-screen fling can skip a row on the short SE viewport.
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(row.isHittable); row.tap()
        let plus = app.staticTexts["+ 新增球形"]
        XCTAssertTrue(plus.waitForExistence(timeout: 8))
        try capture("batch-picker"); try landscape("batch-picker"); try portrait("batch-picker")
        plus.tap(); app.buttons["空台面（仅母球）"].tap()
        XCTAssertTrue(element("table.scene").waitForExistence(timeout: 12))
        try capture("batch-author-empty")
        app.buttons["摆球"].tap()
        let ball = app.buttons["paletteBall__1"]
        XCTAssertTrue(ball.exists); ball.tap(); XCTAssertEqual(ball.value as? String, "在桌上")
        try landscape("batch-author"); XCTAssertEqual(ball.value as? String, "在桌上")
        try portrait("batch-author")
        app.buttons["自由"].tap()
        XCTAssertTrue(app.buttons["播放当前录制序列"].exists)
        try capture("batch-author-free")
        XCTAssertFalse(app.buttons["轨迹标注档位"].exists, "轨迹设置收进菜单，不能遮挡打点盘")
        app.buttons["更多"].firstMatch.tap()
        let trajectory = app.buttons["轨迹标注档位"]
        XCTAssertTrue(trajectory.waitForExistence(timeout: 4))
        let previous = trajectory.identifier // Native Menu exports its selected system image, not SwiftUI value.
        try capture("batch-display-menu")
        trajectory.tap()
        app.buttons["更多"].firstMatch.tap()
        XCTAssertTrue(trajectory.waitForExistence(timeout: 4))
        XCTAssertNotEqual(trajectory.identifier, previous)
        // Complete the cycle to restore the shared preference.
        trajectory.tap(); app.buttons["更多"].firstMatch.tap()
        XCTAssertTrue(trajectory.waitForExistence(timeout: 4)); trajectory.tap()

        // No save, overwrite, delete, or export action is invoked.
    }
    func testDetailViewCameraPlaybackAndRotation() throws {
        launch(["-deeplink.drillDetail=drill_c001", "-v54.forceLight"])
        let mode = app.buttons["drillScene.cameraMode"], play = app.buttons["drillPlayButton"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15)); XCTAssertTrue(play.exists)
        XCTAssertGreaterThanOrEqual(play.frame.width, 44); XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        try capture("detail-2d"); try landscape("detail-2d")
        mode.tap(); XCTAssertEqual(mode.value as? String, "3D")
        app.buttons["drillScene.overview"].tap(); try capture("detail-3d")
        mode.tap(); XCTAssertEqual(mode.value as? String, "2D")
        play.tap(); XCTAssertTrue(play.label == "暂停" || play.label == "本杆结束后暂停")
        play.tap()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == '继续' OR label == '回放'"), object: play)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 40), .completed)
        try capture("detail-paused"); try portrait("detail")
        app.buttons["bottomTryoutButton"].tap()
        XCTAssertTrue(element("composer.landscape").waitForExistence(timeout: 15))
        try capture("detail-to-tryout")
    }
    func testTrainingRecordEmbeddedTableWithoutSaving() throws {
        launch(); app.switchTab(.training)
        let free = app.buttons["trainingHome.freeTraining"].firstMatch
        XCTAssertTrue(free.waitForExistence(timeout: 10)); free.tap()
        // Free training opens the picker itself; do not tap the underlying page through its sheet.
        let row = app.buttons["添加半台直线球"]
        XCTAssertTrue(row.waitForExistence(timeout: 12)); XCTAssertTrue(row.isHittable); row.tap()
        XCTAssertTrue(app.buttons["取消选择半台直线球"].waitForExistence(timeout: 4))
        try capture("record-drill-selected")
        let done = app.buttons["完成(1)"]
        XCTAssertTrue(done.waitForExistence(timeout: 6)); done.tap()
        let single = app.buttons["切换到单项视图"]
        XCTAssertTrue(single.waitForExistence(timeout: 6)); XCTAssertTrue(single.isHittable); single.tap()
        let mode = app.buttons["drillScene.cameraMode"]
        for _ in 0..<10 where !mode.isHittable { app.swipeUp() }
        XCTAssertTrue(mode.exists); XCTAssertTrue(mode.isHittable)
        try capture("record-table-2d"); try landscape("record-table")
        for _ in 0..<4 where !mode.isHittable { app.swipeUp() }
        mode.tap(); XCTAssertEqual(mode.value as? String, "3D")
        try capture("record-table-3d"); try portrait("record-table")
        // All training data is in memory; no training completion or save occurs.
    }
}
