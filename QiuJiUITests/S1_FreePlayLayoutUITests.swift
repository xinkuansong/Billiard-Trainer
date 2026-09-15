import XCTest

/// 问题集合 v3 §S1 自由击球基准页布局验收：
/// - 截图核验 G3–G11（贴边 / 对齐 / 不遮挡 / 三圆圈开球按钮）；
/// - G10 断言：进袋/自由切换、进入开球模式时 `freeplay.stage` frame 零变化（球桌尺寸锁定）。
final class S1_FreePlayLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.freePlay", "-v51.followSystemAppearance"])
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private var outDir: URL {
        #if !targetEnvironment(simulator)
        return FileManager.default.temporaryDirectory.appendingPathComponent("v63-freeplay")
        #else
        let environment = ProcessInfo.processInfo.environment
        let path = environment["V52_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V52_SHOT_DIR"]
            ?? "/Users/song/projects/13.billiard_trainer/build/v52-screenshots/after-standard"
        return URL(fileURLWithPath: path, isDirectory: true)
        #endif
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("截图写入失败：\(url.path)，\(error)")
        }
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openFreePlay() -> Bool {
        return app.navigationBars["自由击球"].waitForExistence(timeout: 8)
    }

    func testFreePlayLayoutAndTableSizeLock() throws {
        guard openFreePlay() else {
            XCTFail("未能进入自由击球页")
            return
        }
        sleep(3)
        let stage = app.descendants(matching: .any)["freeplay.stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 5), "自由击球 stage 应可访问")
        let framePocket = stage.frame
        snap("s1-01-freeplay-pocket")

        // 进袋 ⇄ 自由 切换：G10 球桌尺寸不变。
        let toggle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '瞄准模式'")).firstMatch
        if toggle.waitForExistence(timeout: 2) {
            toggle.tap(); sleep(2)
            snap("s1-02-freeplay-free")
            let frameFree = stage.frame
            XCTAssertEqual(frameFree.width, framePocket.width, accuracy: 0.5, "切换瞄准模式球桌宽不变（G10）")
            XCTAssertEqual(frameFree.height, framePocket.height, accuracy: 0.5, "切换瞄准模式球桌高不变（G10）")
        }

        // 进入开球模式：底栏换成开球条，G10 stage frame 仍不变。
        let breakBtn = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        if breakBtn.waitForExistence(timeout: 5) {
            breakBtn.tap(); sleep(1)
            // 玩法选择 sheet：选中式八球。
            _ = app.staticTexts["中式八球"].waitForExistence(timeout: 3)
            if app.staticTexts["中式八球"].exists { app.staticTexts["中式八球"].tap() }
            else if app.buttons["中式八球"].exists { app.buttons["中式八球"].tap() }
            sleep(2)
            snap("s1-03-freeplay-break")
            let frameBreak = stage.frame
            XCTAssertEqual(frameBreak.width, framePocket.width, accuracy: 0.5, "开球模式球桌宽不变（G10）")
            XCTAssertEqual(frameBreak.height, framePocket.height, accuracy: 0.5, "开球模式球桌高不变（G10）")
        }
    }

    func testAimWheelExposesAccessibilityControl() {
        XCTAssertTrue(openFreePlay())
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        app.buttons["瞄准模式：进袋，点击切换"].tap()
        let wheel = app.otherElements["shotStage.aimWheel"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "The aim control must be discoverable in the app accessibility tree")
        XCTAssertTrue(wheel.isEnabled)
        XCTAssertEqual(wheel.label, "瞄准微调")
        snap("v63-aim-adjustable")
    }

    func testPerspectiveBreakAndContinue() throws {
        XCTAssertTrue(openFreePlay())
        let mode = app.buttons["freeplay.cameraMode"]
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        func capture(_ name: String) throws {
            Thread.sleep(forTimeInterval: 1)
            let shot = XCUIScreen.main.screenshot()
            #if targetEnvironment(simulator)
            let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("output/freeplay-3d/after")
            #else
            let root = outDir
            #endif
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let name = "\(name)-\(Int(app.windows.firstMatch.frame.width))"
            try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
            let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
        }
        func waitEnabled(_ element: XCUIElement, seconds: TimeInterval = 30) {
            let e = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)
            let result = XCTWaiter.wait(for: [e], timeout: seconds)
            if result != .completed {
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "disabled-action-timeout"; screenshot.lifetime = .keepAlways; add(screenshot)
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "disabled-action-hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
            }
            XCTAssertEqual(result, .completed)
        }
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        try capture("initial-2d")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("initial-3d")
        for count in [15, 9] {
            app.descendants(matching: .any)["break.entry"].firstMatch.tap()
            let game = app.buttons["break.game.\(count)"]
            XCTAssertTrue(game.waitForExistence(timeout: 5)); game.tap()
            let strike = app.buttons["break.strike"]
            waitEnabled(strike)
            XCTAssertEqual(mode.value as? String, "3D")
            XCTAssertTrue(app.buttons["freeplay.focus"].isEnabled)
            try capture("rack-\(count)-3d")
            app.buttons["freeplay.observation"].tap()
            let wholeTable = app.buttons["freeplay.observe.table"]
            XCTAssertTrue(wholeTable.waitForExistence(timeout: 3))
            wholeTable.tap()
            try capture("v63-whole-rack-\(count)")
            let center = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            center.press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.25)))
            table.pinch(withScale: 1.1, velocity: 1)
            app.buttons["freeplay.focus"].tap()
            let from = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52)))
            app.buttons["shotStage.spinEntry"].tap()
            try capture("break-spin-\(count)")
            let lower = app.buttons["低杆增加 1%"]
            XCTAssertTrue(lower.isHittable)
            XCTAssertLessThan(lower.frame.maxY, strike.frame.minY)
            lower.tap()
            app.buttons["回中"].tap()
            mode.tap()
            XCTAssertFalse(app.buttons["回中"].exists)
            XCTAssertEqual(mode.value as? String, "2D")
            try capture("rack-\(count)-2d")
            mode.tap()
            app.buttons["break.rerack"].tap()
            try capture("reracked-\(count)-3d")
            strike.tap()
            try capture("breaking-\(count)-3d")
            mode.tap()
            XCTAssertEqual(mode.value as? String, "2D")
            try capture("breaking-\(count)-2d")
            mode.tap()
            let confirm = app.buttons["break.confirm"]
            waitEnabled(confirm, seconds: 60)
            try capture("settled-\(count)-3d")
            mode.tap()
            XCTAssertTrue(confirm.isHittable)
            try capture("settled-\(count)-2d")
            mode.tap()
            confirm.tap()
            XCTAssertTrue(app.descendants(matching: .any)["break.entry"].firstMatch.waitForExistence(timeout: 10))
            XCTAssertEqual(mode.value as? String, "3D")
            try capture("delivered-\(count)-3d")
        }
        let toggle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '瞄准模式'")).firstMatch
        toggle.tap()
        let strike = app.buttons["击球"]
        waitEnabled(strike)
        strike.tap()
        waitEnabled(app.buttons["重打"], seconds: 45)
        try capture("continued-shot-3d")
        app.buttons["重打"].tap()
        app.descendants(matching: .any)["break.entry"].firstMatch.tap()
        let game = app.buttons["break.game.4"]
        XCTAssertTrue(game.waitForExistence(timeout: 5)); game.tap()
        waitEnabled(app.buttons["break.strike"])
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["击球"].waitForExistence(timeout: 5))
        XCTAssertEqual(mode.value as? String, "3D")
        try capture("cancelled-3d")
    }

    func testFirstPerspectiveEntryAfterStartingBreakIn2D() throws {
        continueAfterFailure = false
        XCTAssertTrue(openFreePlay())
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertEqual(mode.value as? String, "2D")
        app.descendants(matching: .any)["break.entry"].firstMatch.tap()
        let game = app.buttons["break.game.9"]
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        let strike = app.buttons["break.strike"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: strike)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        strike.tap()
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        Thread.sleep(forTimeInterval: 1)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "v63-first-3d-during-break"
        attachment.lifetime = .keepAlways
        add(attachment)
        #if targetEnvironment(simulator)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/3d-v63/W02")
        #else
        let root = outDir
        #endif
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: root.appendingPathComponent("first-3d-during-break-\(Int(app.windows.firstMatch.frame.width)).png"))
        let observation = app.buttons["freeplay.observation"]
        XCTAssertTrue(observation.exists)
        // iOS 17 exposes a nested Menu button whose parent reports non-hittable.
        // Physical-tap evidence is retained in first-3d-se-ax5-r3; verify the action.
        observation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let wholeTable = app.buttons["freeplay.observe.table"]
        XCTAssertTrue(wholeTable.waitForExistence(timeout: 5))
        XCTAssertTrue(wholeTable.isHittable)
        let menuShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        menuShot.name = "v63-first-3d-observation-menu"
        menuShot.lifetime = .keepAlways
        add(menuShot)
        wholeTable.tap()
        XCTAssertFalse(wholeTable.exists)
        XCTAssertEqual(mode.value as? String, "3D")
    }
}

extension S1_FreePlayLayoutUITests {
    func testPerspectiveScratchCanRestoreCueFromPalette() throws {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-deeplink.freePlay", "-v63.freePlayScratch"])
        XCTAssertTrue(openFreePlay())
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.tap()
        let strike = app.buttons["击球"]
        let enabled = NSPredicate(format: "exists == true AND enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: strike)], timeout: 30), .completed)
        strike.tap()
        let replay = app.buttons["回放"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: replay)], timeout: 30), .completed)
        XCTAssertTrue(app.staticTexts["切回2D补回母球"].exists)
        snap("v63-scratch-3d")
        replay.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: replay)], timeout: 30), .completed)
        XCTAssertTrue(app.staticTexts["切回2D补回母球"].exists)
        mode.tap()
        let cue = app.descendants(matching: .any)["paletteBall_cueBall"].firstMatch
        XCTAssertTrue(cue.waitForExistence(timeout: 5))
        cue.tap()
        mode.tap()
        XCTAssertTrue(app.staticTexts["移母球切回2D"].exists)
        XCTAssertTrue(app.buttons["freeplay.focus"].isEnabled)
        snap("v63-scratch-restored-3d")
    }
}
