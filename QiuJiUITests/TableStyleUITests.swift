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
        for (key, title) in [("walnut","深胡桃木"), ("charcoal","炭黑木纹"), ("ivory","象牙白蜡木"), ("blossom","樱花粉木纹"), ("standard","标准")] {
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
        app.terminate()
        app.launchArguments.removeAll { $0 == "-deeplink.settings" }
        app.launch()
        app.switchTab(.angle)
        let category = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(category.waitForExistence(timeout: 10)); category.tap()
        for (title, prefix) in [("自由击球","freeplay"), ("分离角与走位","shotSimulation")] {
            let card = app.buttons[title]
            XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
            let mode = app.buttons[prefix + ".cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 25))
            if mode.value as? String != "3D" { mode.tap() }
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "球桌风格：樱花粉木纹"), object: table)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
            attach(prefix + "-pink")
            app.navigationBars.buttons.element(boundBy: 0).tap()
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
        app.buttons["angleHomeTab_打"].tap()
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
                if row.frame.minY < app.navigationBars.firstMatch.frame.maxY { app.swipeDown() }
                else { app.swipeUp() }
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
        preview("tableStyle.preview", contains: ["球桌：炭黑木纹"], capture: "table-charcoal")
        back()
        tap("settings.clothColor")
        preview("clothColor.preview", contains: ["球桌：炭黑木纹"], capture: "cloth-inherits-charcoal")
        tap("settings.clothColor.tournamentBlue")
        preview("clothColor.preview", contains: ["球桌：炭黑木纹", "台呢：赛事蓝"], capture: "cloth-blue-charcoal")
        back()
        tap("settings.roomStyle")
        for (key, title) in [("walnut", "温润木质"), ("eastern", "当代东方"), ("tournament", "极简赛事")] {
            tap("settings.roomStyle." + key)
            preview("roomStyle.preview", contains: ["球房：" + title, "球桌：炭黑木纹", "台呢：赛事蓝"], capture: "room-combination-" + key)
        }
        back()
        let toggle = app.switches["settings.tableSights"]
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        if toggle.value as? String == "1" { toggle.tap() }
        app.terminate(); app.launch()
        tap("settings.tableStyle")
        preview("tableStyle.preview", contains: ["球房：极简赛事", "球桌：炭黑木纹", "台呢：赛事蓝", "颗星参考点隐藏"], capture: "combination-restored-after-launch")
        tap("settings.tableStyle.standard")
        preview("tableStyle.preview", contains: ["球桌：标准", "台呢：赛事蓝"], capture: "table-standard-keeps-blue")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
