import XCTest

final class TableStyleUITests: XCTestCase {
    func testSelectPersistPreviewAndTrainingPages() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v51.followSystemAppearance", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-deeplink.settings"])
        let entry = app.buttons["settings.tableStyle"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        let preview = app.images["tableStyle.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        for (key, title) in [("walnut","深胡桃木"), ("charcoal","标准"), ("ivory","象牙白蜡木"), ("blossom","樱花粉木纹"), ("standard","经典原木")] {
            let row = app.buttons["settings.tableStyle." + key]
            for _ in 0..<3 where !row.isHittable || row.frame.maxY > app.windows.firstMatch.frame.maxY - 40 { app.swipeUp() }
            XCTAssertTrue(row.isHittable); row.tap()
            XCTAssertEqual(row.value as? String, "已选择")
            XCTAssertEqual(preview.label, title + "球桌预览")
            for _ in 0..<3 where !preview.isHittable { app.swipeDown() }
            attach("settings-" + key)
        }
        let pink = app.buttons["settings.tableStyle.blossom"]
        for _ in 0..<3 where !pink.isHittable || pink.frame.maxY > app.windows.firstMatch.frame.maxY - 40 { app.swipeUp() }
        pink.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertEqual(pink.value as? String, "已选择")
        // Both training entries now use FreePlayView and its shared menu.
        // Keep persisted preferences while launching their actual page routes.
        for (route, name) in [("-deeplink.freePlay", "freeplay"), ("-dailyInteraction.sharedPage=shot", "shotSimulation")] {
            app.terminate()
            XCUIDevice.shared.orientation = .landscapeLeft
            app.launchArguments.removeAll { $0.hasPrefix("-deeplink.") || $0.hasPrefix("-dailyInteraction.sharedPage=") }
            app.launchArguments.append(route)
            app.launch()
            setCameraMode("3D", in: app)
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "球桌风格：樱花粉木纹"), object: table)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
            attach(name + "-pink")
        }
    }

    func testSightsVisibilityPersistsAndAppliesToTraining() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v51.followSystemAppearance", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-deeplink.settings"])
        let toggle = app.switches["settings.tableSights"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<6 where !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String == "1" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "0")
        attach("sights-setting-off")
        let tableEntry = app.buttons["settings.tableStyle"]
        for _ in 0..<6 where !tableEntry.isHittable { app.swipeDown() }
        tableEntry.tap()
        let preview = app.images["tableStyle.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue((preview.value as? String)?.contains("颗星参考点隐藏") == true)
        attach("sights-preview-off")
        app.terminate(); app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<6 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        app.terminate(); app.launchArguments.removeAll { $0 == "-deeplink.settings" }; app.launch()
        app.switchTab(.angle)
        app.buttons["angleHomeTab_走位"].tap()
        app.buttons["自由击球"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 25))
        if mode.value as? String != "3D" { mode.tap() }
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "颗星参考点：隐藏"), object: table)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 15), .completed)
        attach("sights-training-off")
        app.terminate(); app.launchArguments.append("-deeplink.settings"); app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        for _ in 0..<6 where !toggle.isHittable { app.swipeUp() }; toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        attach("sights-setting-on")
    }

    func testAppearanceCombinationAcrossSettingsPages() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v51.followSystemAppearance", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-deeplink.settings", "-v62.s267Lighting"])
        func tap(_ id: String) {
            let row = app.buttons[id]
            XCTAssertTrue(row.waitForExistence(timeout: 15), id)
            for _ in 0..<6 where !row.isHittable || row.frame.maxY > app.windows.firstMatch.frame.maxY - 35 {
                // Full-screen swipes overshoot the appearance group on SE/iOS 17
                // and alternate past the same row. Scroll within the visible body.
                let movingDown = row.frame.minY < app.navigationBars.firstMatch.frame.maxY
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movingDown ? 0.4 : 0.7))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movingDown ? 0.65 : 0.45))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTAssertTrue(row.isHittable, id)
            row.tap()
        }
        func back() { app.navigationBars.buttons.element(boundBy: 0).tap() }
        func preview(_ id: String, contains values: [String], capture: String) {
            let image = app.images[id]
            XCTAssertTrue(image.waitForExistence(timeout: 20))
            for value in values { XCTAssertTrue((image.value as? String)?.contains(value) == true, value) }
            for _ in 0..<5 where image.frame.minY < app.navigationBars.firstMatch.frame.maxY { app.swipeDown() }
            attach(capture)
        }
        let room = app.buttons["settings.roomStyle"]
        XCTAssertTrue(room.waitForExistence(timeout: 15))
        attach("settings-general-top")
        for _ in 0..<6 where !room.isHittable { app.swipeUp() }
        XCTAssertLessThan(room.frame.minY, app.buttons["settings.tableStyle"].frame.minY)
        XCTAssertLessThan(app.buttons["settings.tableStyle"].frame.minY, app.buttons["settings.clothColor"].frame.minY)
        attach("appearance-settings")
        tap("settings.tableStyle")
        tap("settings.tableStyle.charcoal")
        preview("tableStyle.preview", contains: ["球桌：标准"], capture: "table-charcoal")
        back()
        tap("settings.clothColor")
        preview("clothColor.preview", contains: ["球桌：标准"], capture: "cloth-inherits-charcoal")
        tap("settings.clothColor.tournamentBlue")
        preview("clothColor.preview", contains: ["球桌：标准", "台呢：赛事蓝"], capture: "cloth-blue-charcoal")
        back()
        tap("settings.roomStyle")
        for (key, title) in [("walnut", "温润木质"), ("eastern", "当代东方"), ("tournament", "极简赛事")] {
            tap("settings.roomStyle." + key)
            preview("roomStyle.preview", contains: ["球房：" + title, "球桌：标准", "台呢：赛事蓝"], capture: "room-combination-" + key)
        }
        back()
        let toggle = app.switches["settings.tableSights"]
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String == "1" { toggle.tap() }
        app.terminate(); app.launch()
        tap("settings.tableStyle")
        preview("tableStyle.preview", contains: ["球房：极简赛事", "球桌：标准", "台呢：赛事蓝", "颗星参考点隐藏"], capture: "combination-restored-after-launch")
        tap("settings.tableStyle.standard")
        preview("tableStyle.preview", contains: ["球桌：经典原木", "台呢：赛事蓝"], capture: "table-standard-keeps-blue")
    }

    func testMaterialAimAndObservationViews() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.freePlay", "-forcePremium",
            "-tableStyle.v1", "charcoal", "-clothColor.v1", "green"])
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 20))
        setCameraMode("3D", in: app)
        func selectionState() -> String {
            // FPS is transient render telemetry, not table/target state.
            (table.value as? String ?? "").components(separatedBy: "，渲染帧率")[0]
        }
        let state = selectionState()
        for (id, name) in [("dailyClearance.observeTable", "whole"), ("shotCamera.thirdPerson", "along-cue"), ("shotCamera.firstPerson", "aim")] {
            let action = app.buttons[id]
            XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isEnabled)
            action.tap()
            XCTAssertEqual(selectionState(), state)
            attach("material-observe-" + name)
        }
        let temporary = app.buttons["shotCamera.temporaryTopDown"]
        XCTAssertTrue(temporary.waitForExistence(timeout: 5)); temporary.tap()
        // The native overlay is inside the single accessible table element.
        // Assert the public control state, then inspect its rendered screenshot.
        XCTAssertEqual(temporary.value as? String, "已选中")
        attach("material-temporary-topdown")
        temporary.tap()
        XCTAssertEqual(temporary.value as? String, "未选中")
        XCTAssertEqual(selectionState(), state)
        setCameraMode("2D", in: app)
        attach("material-topdown")
        setCameraMode("3D", in: app)
        XCTAssertEqual(selectionState(), state)
        attach("material-return-3d")
    }

    private func setCameraMode(_ value: String, in app: XCUIApplication) {
        let more = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        if mode.value as? String != value { mode.tap() }
        XCTAssertEqual(mode.value as? String, value)
        app.buttons["关闭菜单"].tap()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
