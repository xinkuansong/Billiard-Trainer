import XCTest

/// 问题集合 v3 §S5 训练页布局与渲染验收截图：
/// - P4.1–P4.3 角度与打点：球桌在球库上方不遮挡、球库对齐球桌左右、黑 8 进球线黑色；
/// - P6.1–P6.4 + P7.1 2D/3D 角度训练：布局同 P4、辅助/答题在球桌右侧、假想球心红点；
/// - P5.1 角度预测：紧凑键盘不遮挡「换题 / 显示参考」；
/// - G2 台面网格提亮为灰白（0.55 alpha）。
final class S5_TrainingPagesLayoutUITests: XCTestCase {
    private var trainingTitle = ""

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    // Scoped trial: real routes, deterministic layout, input/cancel/result/next.
    func testAngleTrial2D() throws { try checkAngleTrial(mode: "2D") }
    func testAngleTrial3D() throws { try checkAngleTrial(mode: "3D") }

    func testAngleTrialFreeLimit3D() throws { try checkAngleTrial(mode: "3D", nearLimit: true) }

    func testAngleTrialFreeLimit2D() throws { try checkAngleTrial(mode: "2D", nearLimit: true) }

    private func checkAngleTrial(mode: String, nearLimit: Bool = false) throws {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: [nearLimit ? "-w7.forceDailyLimitNear" : "-forcePremium", "-v50.inMemoryStore", "-v62.fixture", "-3dDrag.probe", "-dailyLayout.probe"])
        let prefix = nearLimit ? "free-\(mode)" : mode
        func capture(_ state: String) throws {
            sleep(1)
            snap("trial-\(prefix)-\(state)")
            let env = ProcessInfo.processInfo.environment
            if let path = env["TEST_RUNNER_ANGLE_SHOTS"] ?? env["ANGLE_SHOTS"] {
                let folder = URL(fileURLWithPath: path, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(prefix)-\(state).png"))
            }
        }
        XCTAssertTrue(openCard(homeTab: "练", title: "\(mode)角度"))
        do {
            XCTAssertTrue(app.buttons["angleTraining.start"].waitForExistence(timeout: 5))
            let initial = app.windows.firstMatch.frame
            XCTAssertGreaterThan(initial.height, initial.width, "首次设置必须保持竖屏，确认前不得旋转")
            XCTAssertFalse(app.otherElements["angleTraining.scene"].exists)
            try capture("initial-settings")
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
            app.buttons["training.settingsCancel"].tap()
            XCTAssertTrue(openCard(homeTab: "练", title: "\(mode)角度"))
            XCTAssertTrue(app.buttons["angleTraining.start"].waitForExistence(timeout: 5))
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        }
        XCTAssertTrue(startAimingTrainingFromSheet())
        let isTablet = min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) >= 600
        if isTablet {
            print("P09b orientation before rotation: \(String(describing: app.descendants(matching: .any).matching(identifier: "dailyLayout.entryProbe").firstMatch.value))")
        }
        if isTablet { XCUIDevice.shared.orientation = .landscapeLeft }
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        if isTablet {
            print("P09b orientation after rotation: \(String(describing: app.descendants(matching: .any).matching(identifier: "dailyLayout.entryProbe").firstMatch.value))")
        }
        func sceneProbe() throws -> [String: Any] {
            let element = app.descendants(matching: .any).matching(identifier: "angleTraining.scene").firstMatch
            let raw = try XCTUnwrap(element.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        }
        var temporaryTable: [Double]?
        let answer = app.buttons["答题"].firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 8))
        try capture("observe")
        let window = app.windows.firstMatch
        XCTAssertGreaterThan(window.frame.width, window.frame.height, "两个入口都应自动横屏")
        let stage = app.otherElements["angleTraining.stage"].firstMatch
        XCTAssertTrue(stage.exists)
        let stageFrame = stage.frame
        let referenceBallFrame = mode == "2D" ? app.descendants(matching: .any).matching(identifier: "angleTraining.ball._1").firstMatch.frame : .zero
        XCTAssertTrue(app.staticTexts["angleTraining.targetPocket"].label.contains("目标袋"))
        XCTAssertTrue(app.staticTexts["1/15"].exists)
        let palette = app.otherElements["angleTraining.palette"]
        XCTAssertTrue(palette.exists)
        let info = app.otherElements["angleTraining.questionInfo"]
        XCTAssertTrue(info.exists)
        do {
            XCTAssertLessThanOrEqual(info.frame.maxX, stageFrame.minX)
            XCTAssertLessThanOrEqual(palette.frame.maxY, stageFrame.minY + 12)
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "angleTraining.ball.cueBall").firstMatch.exists)
            for n in 1...15 {
                let ball = app.descendants(matching: .any).matching(identifier: "angleTraining.ball._\(n)").firstMatch
                XCTAssertTrue(ball.exists)
                XCTAssertTrue(window.frame.insetBy(dx: -1, dy: -1).contains(ball.frame))
            }
        }
        let actionFrame = answer.frame
        XCTAssertGreaterThanOrEqual(actionFrame.width, 52)
        XCTAssertGreaterThanOrEqual(actionFrame.height, 52)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(actionFrame))
        if mode == "3D" {
            let firstPerson = app.buttons["shotCamera.firstPerson"]
            let observation = app.buttons["shotCamera.thirdPerson"]
            XCTAssertTrue(firstPerson.exists)
            firstPerson.tap()
            XCTAssertEqual(firstPerson.value as? String, "已选中")
            try capture("first-person")
            observation.tap()
            XCTAssertEqual(observation.value as? String, "已选中")
            try capture("player-observation")
        }
        let assist = app.buttons["辅助"].firstMatch
        XCTAssertTrue(assist.exists)
        assist.tap()
        XCTAssertEqual(app.buttons["angleTraining.assist"].value as? String, "已开启")
        try capture("assist")
        if mode == "3D" {
            let topDown = app.buttons["shotCamera.temporaryTopDown"]
            topDown.tap()
            try capture("temporary-assist")
            XCTAssertEqual(try sceneProbe()["cueVisible"] as? Bool, true)
            XCTAssertEqual(app.buttons["angleTraining.assist"].value as? String, "已开启")
            app.buttons["angleTraining.assist"].tap()
            try capture("temporary-assist-hidden")
            XCTAssertEqual(try sceneProbe()["cueVisible"] as? Bool, false)
            app.buttons["辅助"].tap()
            try capture("temporary-assist-restored")
            XCTAssertEqual(try sceneProbe()["cueVisible"] as? Bool, true)
            topDown.tap()
            XCTAssertEqual(app.buttons["angleTraining.assist"].value as? String, "已开启")
        }
        answer.tap()
        XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 4))
        try capture("input")
        XCTAssertEqual(stage.frame, stageFrame, "输入不得缩桌")
        for key in ["1", "0", "取消", "提交"] {
            XCTAssertGreaterThanOrEqual(app.buttons[key].firstMatch.frame.height, 44)
        }
        if mode == "3D" {
            XCTAssertFalse(app.buttons["shotCamera.temporaryTopDown"].isEnabled)
            XCTAssertFalse(app.buttons["dailyClearance.observeTable"].isEnabled)
            XCTAssertFalse(app.buttons["shotCamera.firstPerson"].isEnabled)
        }
        app.buttons["取消"].firstMatch.tap()
        XCTAssertTrue(answer.waitForExistence(timeout: 4))
        XCTAssertEqual(answer.frame, actionFrame)
        answer.tap()
        XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 4))
        app.buttons["4"].firstMatch.tap()
        app.buttons["5"].firstMatch.tap()
        app.buttons["提交"].tap()
        let next = app.buttons["下一题"].firstMatch
        if nearLimit {
            XCTAssertTrue(app.buttons["总结"].waitForExistence(timeout: 5))
            XCTAssertFalse(next.exists)
            XCTAssertTrue(app.staticTexts["angleTraining.result"].label.contains("答案"))
            try capture("limit-result")
            verifyAngleTrialExit()
            return
        }
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        try capture("result")
        XCTAssertEqual(try sceneProbe()["cueVisible"] as? Bool, true)
        if mode == "3D" {
            let topDown = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertTrue(topDown.isEnabled, "结果允许用临时2D复盘同一道题")
            topDown.tap()
            try capture("temporary-result")
            let probe = try sceneProbe()
            XCTAssertEqual(probe["standardTemporaryTable"] as? Bool, true)
            XCTAssertEqual(probe["hasMeasuredStage"] as? Bool, true)
            let temporaryViewport = try XCTUnwrap(probe["displayedViewport"] as? [Double])
            for (a,b) in zip(temporaryViewport, [stageFrame.minX, stageFrame.minY, stageFrame.width, stageFrame.height]) {
                XCTAssertEqual(a, b, accuracy: 1, "临时渲染区域必须直接来自实际stage")
            }
            XCTAssertEqual(probe["cueVisible"] as? Bool, true)
            let diagram = try XCTUnwrap(probe["diagram"] as? [String: Any])
            XCTAssertEqual(diagram["labelFontSize"] as? Double, 11)
            XCTAssertEqual(diagram["labelHidden"] as? Bool, false)
            temporaryTable = try XCTUnwrap(probe["displayedTable"] as? [Double])
            topDown.tap()
            try capture("result-return")
            XCTAssertTrue(app.staticTexts["angleTraining.result"].label.contains("答案"))
            XCTAssertEqual(try sceneProbe()["cueVisible"] as? Bool, true)
        }
        if mode == "2D" {
            let scene = app.descendants(matching: .any).matching(identifier: "angleTraining.scene").firstMatch
            let raw = try XCTUnwrap(scene.value as? String)
            let data = try XCTUnwrap(raw.data(using: .utf8))
            let probe = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let diagram = try XCTUnwrap(probe["diagram"] as? [String: Any])
            XCTAssertEqual(diagram["labelFontSize"] as? Double, 11)
            XCTAssertEqual(diagram["labelHidden"] as? Bool, false)
            let actual = try XCTUnwrap(diagram["arcStart"] as? [Double])
            let expected = try XCTUnwrap(diagram["expectedArcStart"] as? [Double])
            XCTAssertEqual(actual[0], expected[0], accuracy: 0.1)
            XCTAssertEqual(actual[1], expected[1], accuracy: 0.1)
        }
        XCTAssertEqual(stage.frame, stageFrame, "反馈不得缩桌")
        XCTAssertEqual(next.frame, actionFrame, "下一题与答题共用位置及命中尺寸")
        XCTAssertTrue(app.staticTexts["angleTraining.result"].label.contains("答案"))
        next.tap()
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["辅助"].exists)
        try capture("next")
        XCTAssertTrue(app.staticTexts["2/15"].exists)
        XCTAssertEqual(answer.frame, actionFrame)
        if mode == "3D" {
            XCTAssertEqual(app.buttons["shotCamera.thirdPerson"].value as? String, "已选中", "下一题沿用观察视角")
            let whole = app.buttons["dailyClearance.observeTable"]
            XCTAssertTrue(whole.isEnabled)
            whole.tap()
            XCTAssertEqual(whole.value as? String, "已选中")
            try capture("whole-table")
            app.buttons["shotCamera.firstPerson"].tap()
            try capture("return-to-aim")
            XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
            let topDown = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertTrue(topDown.exists)
            topDown.tap()
            XCTAssertEqual(topDown.value as? String, "已选中")
            XCTAssertFalse(app.buttons["shotCamera.firstPerson"].isEnabled)
            try capture("temporary-top-down")
            topDown.tap()
            XCTAssertEqual(topDown.value as? String, "未选中")
            XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
            try capture("temporary-return")

        }
        do {
            app.buttons["angleTraining.settings"].tap()
            let trainingSettings = app.buttons["angleTraining.trainingSettings"]
            XCTAssertTrue(trainingSettings.waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["menu.tableGrid"].exists)
            XCTAssertFalse(app.buttons["freeplay.cameraMode"].exists)
            try capture("more")
            app.buttons["menu.tableGrid"].tap()
            XCTAssertTrue(app.staticTexts["2/15"].exists)
            trainingSettings.tap()
            XCTAssertTrue(app.buttons["angleTraining.start"].waitForExistence(timeout: 3))
            try capture("training-settings")
            app.buttons["training.settingsCancel"].tap()
            XCTAssertTrue(app.staticTexts["2/15"].waitForExistence(timeout: 3), "关闭设置保留当前轮次")
            app.buttons["angleTraining.settings"].tap()
            trainingSettings.tap()
            app.buttons["持续练习"].tap()
            app.buttons["training.range.straight"].tap()
            app.buttons["angleTraining.start"].tap(); app.selectTrainingView(trainingTitle)
            XCTAssertTrue(answer.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["1"].exists)
            XCTAssertFalse(app.staticTexts["2/15"].exists)
            try capture("restarted-free")
            if isTablet {
                XCUIDevice.shared.orientation = .portrait
                let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    window.frame.height > window.frame.width
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
                XCTAssertTrue(window.frame.contains(answer.frame))
                XCTAssertTrue(window.frame.insetBy(dx: -1, dy: -1).contains(stage.frame))
                try capture("portrait")
                answer.tap()
                XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 3))
                try capture("portrait-keypad")
                app.buttons["取消"].tap()
            }
        }
        verifyAngleTrialExit()
        if mode == "3D", let temporaryTable {
            XCTAssertTrue(openCard(homeTab: "练", title: "2D角度"))
            XCTAssertTrue(startAimingTrainingFromSheet())
            if isTablet { XCUIDevice.shared.orientation = .landscapeLeft }
            try capture("reference-2D-table")
            let referenceProbe = try sceneProbe()
            let fixedViewport = try XCTUnwrap(referenceProbe["displayedViewport"] as? [Double])
            for (a,b) in zip(fixedViewport, [stageFrame.minX, stageFrame.minY, stageFrame.width, stageFrame.height]) {
                XCTAssertEqual(a, b, accuracy: 1, "固定2D不能回退到全屏或隐藏的参考视图")
            }
            let reference = try XCTUnwrap(referenceProbe["displayedTable"] as? [Double])
            for (actual, expected) in zip(temporaryTable, reference) {
                XCTAssertEqual(actual, expected, accuracy: 1, "临时2D与固定2D实际桌框必须一致")
            }
            verifyAngleTrialExit()
        }
        if mode == "2D" {
            app.terminate()
            XCUIDevice.shared.orientation = .landscapeLeft
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-dailyInteraction.sharedPage=angleDynamic", "-v54.forceLight"])
            XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 15))
            try capture("reference-angle-dynamic")
            let reference = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch.frame
            for (a,b) in zip([stageFrame.minX, stageFrame.minY, stageFrame.width, stageFrame.height],
                             [reference.minX, reference.minY, reference.width, reference.height]) {
                XCTAssertEqual(a, b, accuracy: 1, "同窗口必须沿用参考页台面范围")
            }
            let ball = app.buttons["paletteBall__1"].frame
            // The read-only face exposes its visible diameter; the reference Button
            // includes the slot's 1pt padding on each side (diameter + 2).
            // Compare visual bounds, not a face against a button hit frame.
            XCTAssertEqual(referenceBallFrame.width, ball.width - 2, accuracy: 1, "球库可见球面直径同源")
            print("P09a reference layout: trainingStage=\(stageFrame), referenceStage=\(reference), trainingFace=\(referenceBallFrame), referenceSlot=\(ball)")
            XCTAssertEqual(referenceBallFrame.midY, ball.midY, accuracy: 1, "球库下沿同源")
        }
    }

    private func verifyAngleTrialExit() {
        app.buttons["angleTraining.back"].tap()
        let window = app.windows.firstMatch
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.height > window.frame.width
        }, object: window)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 6), .completed,
                       "离开角度训练应恢复竖屏")
    }

    private func checkObservationMenu(prefix: String) {
        for id in ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertEqual(button.value as? String, "已选中")
            snap("camera-\(prefix)-\(id)")
        }
    }

    func testComposerPerspectiveRoundTrip() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-freeLayout.ephemeral"])
        XCTAssertTrue(openCard(homeTab: "打", title: "自由走位"))
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 15))
        func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func openMenu() { app.buttons["freeplay.moreMenu"].tap() }
        func closeMenu() {
            let close = app.buttons["dailyClearance.menuClose"]
            if close.exists { close.tap() }
            else if app.buttons["关闭菜单"].firstMatch.exists {
                app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.03, dy: 0.7)).tap()
            }
            XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
        }
        openMenu(); app.buttons["dailyClearance.aimModeMenu"].tap()
        app.buttons["dailyClearance.aim.free"].tap(); closeMenu()
        openMenu(); app.buttons["composer.rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (field.value as? String ?? "").count))
        field.typeText("v63 往返"); app.alerts.buttons["保存"].tap()
        func setView(_ value: String) {
            openMenu()
            let camera = node("freeplay.cameraMode")
            XCTAssertTrue(camera.waitForExistence(timeout: 5))
            if camera.value as? String != value { camera.tap() }
            XCTAssertEqual(camera.value as? String, value); closeMenu()
        }
        setView("3D"); snap("composer-current-3d")
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)], timeout: 30), .completed)
        strike.tap()
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: undo)], timeout: 45), .completed)
        snap("composer-current-settled"); undo.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: strike)], timeout: 30), .completed)
        setView("2D"); snap("composer-current-returned")
        openMenu(); app.buttons["dailyClearance.aimModeMenu"].tap()
        XCTAssertEqual(app.buttons["dailyClearance.aim.free"].value as? String, "已选"); closeMenu()
        openMenu(); app.buttons["composer.rename"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertEqual(field.value as? String, "v63 往返")
        app.alerts.buttons["取消"].tap()
    }

    func testAngleAssistRailExtension() throws {
        for mode in ["2D", "3D"] {
            app.terminate()
            app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
            XCTAssertTrue(openCard(homeTab: "练", title: "\(mode)角度"))
            XCTAssertTrue(startAimingTrainingFromSheet())
            let assist = app.buttons["辅助"].firstMatch
            XCTAssertTrue(assist.waitForExistence(timeout: 5))
            assist.tap()
            let hide = app.buttons["angleTraining.assist"]
            XCTAssertEqual(hide.value as? String, "已开启")
            snap("rail-\(mode)-assist")
            hide.tap()
            XCTAssertTrue(assist.waitForExistence(timeout: 5))
            snap("rail-\(mode)-hidden")
        }
    }

    func testTrainingAssist3D() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        XCTAssertTrue(openCard(homeTab: "练", title: "3D 角度训练"))
        XCTAssertTrue(startAimingTrainingFromSheet())
        let assist = app.buttons["辅助"].firstMatch
        XCTAssertTrue(assist.waitForExistence(timeout: 5))
        snap("training-3D-off")
        assist.tap()
        let hide = app.buttons["angleTraining.assist"]
        XCTAssertEqual(hide.value as? String, "已开启")
        snap("training-3D-on")
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.55))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55)))
        snap("training-3D-rotated")
        hide.tap()
        XCTAssertTrue(assist.waitForExistence(timeout: 5))
        snap("training-3D-hidden")
    }

    func testAimPointTrainingMarkers3D() throws { try checkAimPointTrainingMarkers(mode: "3D") }

    func testAimPointTrainingMarkers2D() throws { try checkAimPointTrainingMarkers(mode: "2D") }

    private func checkAimPointTrainingMarkers(mode: String) throws {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v62.fixture", "-3dDrag.probe", "-dailyLayout.probe", "-v54.forceLight"])
        func capture(_ state: String) throws {
            snap("aim-point-\(mode)-\(state)")
            let env = ProcessInfo.processInfo.environment
            if let path = env["TEST_RUNNER_ANGLE_SHOTS"] ?? env["ANGLE_SHOTS"] {
                let folder = URL(fileURLWithPath: path, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("point-\(mode)-\(state).png"))
            }
        }
        func probe() throws -> [String: Any] {
            let scene = app.descendants(matching: .any).matching(identifier: "aimPointTraining.scene").firstMatch
            let raw = try XCTUnwrap(scene.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        }
        XCTAssertTrue(openCard(homeTab: "练", title: "\(mode)瞄准点"))
        let tablet = UIDevice.current.userInterfaceIdiom == .pad
        if tablet { XCUIDevice.shared.orientation = .landscapeLeft; sleep(2) }
        app.buttons["aimPointTraining.start"].tap(); app.selectTrainingView(trainingTitle)
        let submit = app.buttons["aimPointTraining.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 40))
        let title = app.staticTexts["training.pageTitle"]
        XCTAssertEqual(title.label, "瞄准点练习")
        // The merged title reserves 80 × 34 points; AX reports glyph bounds.
        XCTAssertLessThanOrEqual(title.frame.width, 80)
        XCTAssertGreaterThan(title.frame.width, 50)
        XCTAssertLessThanOrEqual(title.frame.height, 18)
        let stage = app.descendants(matching: .any).matching(identifier: "aimPointTraining.stage").firstMatch
        let stageFrame = stage.frame
        XCTAssertGreaterThanOrEqual(submit.frame.width, 44)
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        XCTAssertFalse(title.frame.intersects(app.descendants(matching: .any).matching(identifier: "aimPointTraining.ball._1").firstMatch.frame))
        XCTAssertEqual(try probe()["cueVisible"] as? Bool, true)
        try capture("aiming")
        app.buttons["aimPointTraining.settings"].tap()
        XCTAssertTrue(app.buttons["menu.tableGrid"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["menu.aimCloseup"].exists)
        try capture("settings")
        app.buttons["menu.tableGrid"].tap()
        app.buttons["aimPointTraining.dismissMenu"].coordinate(withNormalizedOffset: .init(dx: 0.1, dy: 0.5)).tap()
        XCTAssertTrue(submit.isHittable)
        if mode == "3D" {
            for name in ["firstPerson", "thirdPerson"] {
                app.buttons["shotCamera." + name].tap(); sleep(1)
                XCTAssertEqual(app.buttons["shotCamera." + name].value as? String, "已选中")
                try capture(name)
            }
            let top = app.buttons["shotCamera.temporaryTopDown"]
            top.tap(); sleep(1)
            let info = try probe()
            XCTAssertEqual(info["hasMeasuredStage"] as? Bool, true)
            XCTAssertEqual(info["standardTemporaryTable"] as? Bool, true)
            XCTAssertEqual(info["cueVisible"] as? Bool, true)
            let viewport = try XCTUnwrap(info["displayedViewport"] as? [Double])
            XCTAssertEqual(viewport.count, 4)
            for (a,b) in zip(viewport, [stageFrame.minX,stageFrame.minY,stageFrame.width,stageFrame.height]) {
                XCTAssertEqual(a,b,accuracy:1)
            }
            try capture("temporary")
            top.tap(); sleep(1)
            try capture("temporary-return")
        } else {
            let info = try probe()
            let viewport = try XCTUnwrap(info["displayedViewport"] as? [Double])
            // Formal 2D renders the same room floor across the window; the table
            // remains fitted to its original reserved stage inside that renderer.
            let window = app.windows.firstMatch.frame
            XCTAssertEqual(viewport.count, 4)
            for (a,b) in zip(viewport, [window.minX,window.minY,window.width,window.height]) {
                XCTAssertEqual(a,b,accuracy:1)
            }
            let table = try XCTUnwrap(info["displayedTable"] as? [Double])
            XCTAssertEqual(table.count, 4)
            XCTAssertTrue(stageFrame.insetBy(dx: -1, dy: -1).contains(CGRect(
                x: table[0], y: table[1], width: table[2] - table[0], height: table[3] - table[1])))
        }
        let wheel = app.descendants(matching: .any).matching(identifier: "aimPointTraining.aimWheel").firstMatch
        wheel.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.4))
            .press(forDuration:0.1, thenDragTo:wheel.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.65)))
        try capture("adjusted")
        submit.tap()
        try capture("result")
        XCTAssertTrue(app.buttons["aimPointTraining.next"].exists)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:submit)],timeout:5),.completed)
        sleep(3)
        XCTAssertFalse(submit.exists)
        app.buttons["aimPointTraining.next"].tap()
        XCTAssertTrue(submit.waitForExistence(timeout:10))
        try capture("next")
        if tablet {
            XCUIDevice.shared.orientation = .portrait; sleep(2)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.height,app.windows.firstMatch.frame.width)
            XCTAssertTrue(submit.isHittable)
            try capture("portrait")
            XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
            XCTAssertTrue(submit.isHittable)
            try capture("landscape-return")
        }
        app.buttons["aimPointTraining.back"].tap()
        XCTAssertTrue(app.buttons["angleHomeTab_练"].waitForExistence(timeout:5))
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openCard(homeTab: String, title: String) -> Bool {
        let nativePracticeTab = app.tabBars.buttons[XCUIApplication.Tab.angle.rawValue]
        if nativePracticeTab.waitForExistence(timeout: 2) {
            nativePracticeTab.tap()
        } else {
            app.switchTab(.angle)
        }
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        trainingTitle = title
        let card = app.buttons[XCUIApplication.trainingCardTitle(title)]
        if card.waitForExistence(timeout: 4) {
            card.tap()
        } else if app.staticTexts[XCUIApplication.trainingCardTitle(title)].waitForExistence(timeout: 2) {
            app.staticTexts[XCUIApplication.trainingCardTitle(title)].tap()
        } else {
            return false
        }
        sleep(2)
        return true
    }

    /// 2D/3D 角度训练进页先弹训练设置 sheet，点「开始训练」后才出题。
    @discardableResult
    private func startAimingTrainingFromSheet() -> Bool {
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 4) {
            // Each independent standard trial explicitly selects its round length.
            let standard = app.otherElements["training.length"].buttons["15题"]
            if standard.exists { standard.tap() }
            start.tap(); app.selectTrainingView(trainingTitle)
            sleep(2)
            return true
        }
        // Reopening the merged project restores its active round.
        if app.buttons["angleTraining.settings"].exists {
            app.selectTrainingView(trainingTitle)
            return true
        }
        return false
    }

    /// P4.1–P4.3：角度与瞄准——默认布局（球桌上、球库下、宽度对齐）+ 黑 8 上桌进球线黑色。
    func testAngleDynamicLayout() throws {
        guard openCard(homeTab: "学", title: "角度与瞄准") else {
            XCTFail("未能进入角度与瞄准"); return
        }
        sleep(2)
        snap("s5-01-angledynamic-default")

        // P4.2/P4.3：点球库黑 8 上桌 → 进球线应为黑色虚线。
        let ball8 = app.otherElements["paletteBall_8"].firstMatch
        let ball8Alt = app.buttons["paletteBall_8"].firstMatch
        if ball8.waitForExistence(timeout: 3) {
            ball8.tap()
        } else if ball8Alt.waitForExistence(timeout: 2) {
            ball8Alt.tap()
        }
        sleep(2)
        snap("s5-02-angledynamic-black8-potline")
    }

    /// P6.1/P6.2/P6.3：2D 角度训练——布局 + 辅助/答题在球桌右侧 + 假想球心红点 + 键盘悬浮。
    func testSceneAiming2DLayout() throws {
        guard openCard(homeTab: "练", title: "2D角度") else {
            XCTFail("未能进入 2D 角度训练"); return
        }
        startAimingTrainingFromSheet()
        sleep(2)
        snap("s5-03-aiming2d-layout")

        // 辅助档：假想球 + 球心红点（P6.3）。
        let assist = app.buttons["辅助"]
        if assist.waitForExistence(timeout: 4) {
            assist.tap()
            sleep(1)
            snap("s5-04-aiming2d-assist-ghost-dot")
        }

        // 答题：键盘悬浮不改变球桌高度（G10）。
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 4) {
            answer.tap()
            sleep(1)
            snap("s5-05-aiming2d-keypad-overlay")
        }
    }

    /// P7.1：3D 角度训练——底部不留空条、按钮悬浮右下。
    func testV57AimingFramingAndLargerControls() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore"])
        XCTAssertTrue(openCard(homeTab: "练", title: "3D 角度训练"))
        XCTAssertTrue(startAimingTrainingFromSheet())
        checkObservationMenu(prefix: "angleTraining")
        for question in 1...3 {
            let answer = app.buttons["答题"].firstMatch
            XCTAssertTrue(answer.waitForExistence(timeout: 8))
            let assist = app.buttons["辅助"].firstMatch
            XCTAssertTrue(assist.exists)
            for button in [answer, assist] {
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(button.frame))
            }
            sleep(2)
            snap("v57-framed-q\(question)")
            answer.tap()
            XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 4))
            for id in ["dailyClearance.observeTable", "shotCamera.thirdPerson", "shotCamera.firstPerson"] {
                XCTAssertTrue(app.buttons[id].exists)
                XCTAssertFalse(app.buttons[id].isEnabled)
            }
            snap("v57-framed-keypad-q\(question)")
            app.buttons["4"].firstMatch.tap()
            app.buttons["5"].firstMatch.tap()
            app.buttons["提交"].tap()
            let next = app.buttons["下一题"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            if question < 3 { next.tap() }
        }
    }

    func testSceneAiming3DLayout() throws {
        guard openCard(homeTab: "练", title: "3D 角度训练") else {
            XCTFail("未能进入 3D 角度训练"); return
        }
        startAimingTrainingFromSheet()
        sleep(3)
        snap("s5-06-aiming3d-layout")
    }

    /// P5.1：角度预测——紧凑键盘弹出时「换题 / 显示参考」仍完整可见可点。
    func testGeometricQuizCompactKeypad() throws {
        guard openCard(homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测"); return
        }
        sleep(1)
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 4) {
            answer.tap()
            sleep(1)
        }
        snap("s5-07-geoquiz-compact-keypad")

        let changeQuestion = app.buttons["换题"]
        XCTAssertTrue(changeQuestion.waitForExistence(timeout: 3), "键盘弹出时应能看到换题按钮")
        XCTAssertTrue(changeQuestion.isHittable, "键盘不应遮挡换题按钮")
        let showReference = app.buttons["显示参考"]
        if showReference.exists {
            XCTAssertTrue(showReference.isHittable, "键盘不应遮挡显示参考按钮")
        }
    }

    /// G2：台面网格提亮——齿轮菜单开启「台面网格 4×8」后截图核验灰白网格。
    func testTableGridBrightness() throws {
        XCTAssertTrue(openCard(homeTab: "学", title: "角度与瞄准"))
        app.buttons["angleDynamic.more"].tap()
        let grid = app.buttons["menu.tableGrid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))
        let original = grid.value as? String
        grid.tap(); XCTAssertNotEqual(grid.value as? String, original)
        snap("table-grid-current-toggled")
        grid.tap(); XCTAssertEqual(grid.value as? String, original)
        app.buttons["angleDynamic.dismissMenu"].tap()
    }
}
