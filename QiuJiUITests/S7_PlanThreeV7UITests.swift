import XCTest

/// 问题集合 v5 · V7（打一走二想三 Q15.1/Q15.2/Q15.3）截图核验。
///
/// 经 `RootView` 深链 launch arg 直接进反解页（绕过 Tab 导航——SceneKit 页在冷启动导航
/// 偶发卡顿；深链启动稳定），中盘状态由 `PlanThreeView.onAppear` 读同一 arg 确定性注入。
/// 生产无这些 arg ⇒ 深链/注入永不触发。
///
/// - Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（打三 + 思路两页）。
/// - Q15.1：扇形默认落区（高亮）↔ 用户自选约束后扇形降级（灰）。
/// - Q15.2：1 球 pot-only（「仅剩此球」可求解）+ 清台终局提示。
final class S7_PlanThreeV7UITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 深链启动到反解页并截图。每次调用都新起一次干净 App 进程（状态干净），
    /// 因此单个用例内连续多次调用即「每页各 launch 一次干净 App」。
    private func capture(arg: String, name: String, expectStatus: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-\(arg)"]
        app.launch()
        // 求解页顶栏「摆球」chip 为常驻 Button（BTChipRow）。等它出现即证明顶栏/球桌
        // 已完成布局与淡入，避免截到启动或页面过渡的泛白/发灰帧。
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "求解页顶栏「摆球」chip 应出现")
        if let s = expectStatus {
            let match = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", s)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 5), "应显示状态含：\(s)")
        }
        // 顶栏可交互后，SceneKit 球桌仍可能处于淡入尾段；再稳一拍确保整帧清晰。
        sleep(2)
        snap(app, name)
        // 显式回收当前进程，避免同一用例内下一次 launch 与旧进程重启竞态。
        app.terminate()
    }

    /// Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（打三 + 思路两页）。
    /// 两页各自独立 launch 一次干净 App 取证，互不影响。
    func testV7ClearKeyLayout() {
        capture(arg: "deeplink.planThree", name: "v7-planthree-clearkey")
        capture(arg: "deeplink.silu", name: "v7-silu-clearkey")
    }

    func testV7SectorDefault() {
        capture(arg: "planThree.twoBall", name: "v7-sector-default",
                expectStatus: "扇形为默认落区")
    }

    func testV7SectorDimmed() {
        capture(arg: "planThree.twoBallDimmed", name: "v7-sector-dimmed",
                expectStatus: "约束就绪")
    }

    func testV7OneBallPotOnly() {
        capture(arg: "planThree.oneBall", name: "v7-oneball-potonly",
                expectStatus: "台面仅剩此球")
    }

    func testV7ClearedEndgame() {
        capture(arg: "planThree.cleared", name: "v7-endgame-cleared",
                expectStatus: "清台完成")
    }
}

final class BallRoleFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: timeout), .completed, app.debugDescription)
    }
    private func launch(_ scenario: String? = nil, large: Bool = false) {
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-deeplink.planThree", "-3dDrag.probe", "-dailyLayout.probe", "-planthree.informationLearned", "YES"]
            + (scenario.map { ["-planThree." + $0] } ?? [])
            + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []))
        ready(app.buttons["paletteBall__1"])
    }
    private func snap(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: image); a.name = name; a.lifetime = .keepAlways; add(a)
        let state = XCTAttachment(string: app.debugDescription); state.name = name + "-hierarchy"; state.lifetime = .keepAlways; add(state)
    }
    private func pocket(_ index: Int) throws {
        let table = node("table.scene")
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
        let pockets = try XCTUnwrap(state["pockets"] as? [[String: Any]])
        let point = try XCTUnwrap(pockets.first { ($0["index"] as? Int) == index }?["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
    }
    private func mode(_ target: String) {
        app.buttons["planthree.more"].tap()
        let button = app.buttons["planthree.cameraMode"]; ready(button)
        if button.value as? String != target { button.tap() }
        app.buttons["planthree.dismissMenu"].coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.8)).tap()
    }
    func testDirectThreeRoleSelectionAndSamePocketAcrossViews() throws {
        launch()
        XCTAssertFalse(app.buttons["planthree.roles"].exists)
        app.buttons["planthree.strike"].tap()
        XCTAssertTrue(node("planthree.status").label.contains("当前球"))
        app.buttons["paletteBall__1"].tap(); try pocket(1)
        app.buttons["paletteBall__2"].tap(); try pocket(1)
        app.buttons["paletteBall__3"].tap()
        XCTAssertTrue((node("paletteBall__1").value as? String ?? "").hasPrefix("当前击打球"))
        XCTAssertTrue((node("paletteBall__2").value as? String ?? "").hasPrefix("下一颗目标球"))
        XCTAssertTrue((node("paletteBall__3").value as? String ?? "").hasPrefix("后续目标球"))
        snap("after-three-roles-same-pocket-2d")
        app.buttons["paletteBall__2"].tap()
        XCTAssertFalse(app.buttons["planthree.role.0"].exists)
        XCTAssertFalse(app.buttons["planthree.role.2"].exists)
        XCTAssertFalse(app.buttons["planthree.role.4"].exists)
        XCTAssertTrue((node("paletteBall__2").value as? String ?? "").hasPrefix("下一颗目标球"))
        try pocket(3)
        snap("after-three-roles-different-pockets-2d")
        mode("3D"); snap("after-three-roles-3d")
        mode("2D")
        app.buttons["paletteBall__3"].press(forDuration: 1)
        let clear = app.buttons["清除此项"]; ready(clear); clear.tap()
        XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "在桌上")
        app.buttons["paletteBall__4"].tap()
        XCTAssertTrue((node("paletteBall__4").value as? String ?? "").hasPrefix("后续目标球"))
        snap("after-third-role-reassigned")
    }
    func testSolvedStrikeRetryAndReplayPreserveNextDraft() throws {
        launch()
        app.buttons["paletteBall__1"].tap(); try pocket(1)
        app.buttons["paletteBall__2"].tap(); try pocket(3)
        app.buttons["paletteBall__3"].tap()
        app.buttons["solver.solve"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "解1/"), object: app.buttons["solver.nextSolution"])], timeout: 60), .completed)
        ready(app.buttons["planthree.strike"])
        snap("after-solved")
        app.buttons["planthree.strike"].tap()
        ready(app.buttons["planthree.undo"], timeout: 120)
        XCTAssertTrue((node("paletteBall__2").value as? String ?? "").hasPrefix("当前击打球"))
        XCTAssertTrue((app.buttons["paletteBall__2"].value as? String ?? "").contains("已锁定"))
        snap("after-advance-lock")
        app.buttons["paletteBall__2"].tap(); try pocket(0)
        XCTAssertTrue(node("planthree.status").label.contains("重打"))
        app.buttons["paletteBall__3"].tap(); try pocket(0)
        app.buttons["paletteBall__4"].tap()
        let value = app.buttons["paletteBall__2"].value as? String
        let nextValue = app.buttons["paletteBall__3"].value as? String
        let thirdValue = app.buttons["paletteBall__4"].value as? String
        XCTAssertTrue((nextValue ?? "").contains("下一颗目标球"))
        XCTAssertTrue((thirdValue ?? "").contains("后续目标球"))
        app.buttons["planthree.replay"].tap()
        ready(app.buttons["planthree.undo"], timeout: 120)
        XCTAssertEqual(app.buttons["paletteBall__2"].value as? String, value)
        XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, nextValue)
        XCTAssertEqual(app.buttons["paletteBall__4"].value as? String, thirdValue)
        snap("after-replay-preserves-edited-next-draft")
        app.buttons["planthree.more"].tap()
        let retry = app.buttons["planthree.retryShot"]
        for _ in 0..<6 where !retry.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(retry); retry.tap()
        XCTAssertTrue((node("paletteBall__1").value as? String ?? "").hasPrefix("当前击打球"))
        XCTAssertTrue((node("paletteBall__2").value as? String ?? "").hasPrefix("下一颗目标球"))
        XCTAssertTrue(app.buttons["planthree.undo"].isEnabled)
        XCTAssertEqual(app.buttons["planthree.undo"].label, "上一步")
        app.buttons["paletteBall__2"].tap(); try pocket(0)
        XCTAssertFalse(app.buttons["solver.nextSolution"].isEnabled)
        snap("after-retry-edit-next-pocket")
    }
    func testPreviousStepEditsSecondPocketThenSecondBall() throws {
        launch()
        app.buttons["paletteBall__1"].tap(); try pocket(1)
        app.buttons["paletteBall__2"].tap(); try pocket(3)
        app.buttons["paletteBall__3"].tap()
        let back = app.buttons["planthree.undo"]
        XCTAssertEqual(back.label, "上一步")
        let first = app.buttons["paletteBall__1"].value as? String
        let second = app.buttons["paletteBall__2"].value as? String
        back.tap()
        XCTAssertEqual(app.buttons["paletteBall__2"].value as? String, second)
        try pocket(4)
        XCTAssertNotEqual(app.buttons["paletteBall__2"].value as? String, second)
        XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, first)
        back.tap(); back.tap()
        app.buttons["paletteBall__4"].tap()
        XCTAssertTrue((app.buttons["paletteBall__4"].value as? String ?? "").hasPrefix("下一颗目标球"))
        XCTAssertTrue((app.buttons["paletteBall__3"].value as? String ?? "").hasPrefix("后续目标球"))
        snap("previous-second-pocket-and-ball")
    }

    func testLargeTextAndPadRotation() throws {
        launch("threeBallDimmed", large: true)
        snap("after-large-text-roles")
        for id in ["paletteBall__1", "paletteBall__2", "paletteBall__3", "solver.solve", "planthree.strike"] { ready(app.buttons[id]) }
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
            ready(app.buttons["paletteBall__3"]); snap("after-pad-portrait")
            XCUIDevice.shared.orientation = .landscapeLeft
            ready(app.buttons["paletteBall__3"]); snap("after-pad-landscape-return")
        }
    }
}
