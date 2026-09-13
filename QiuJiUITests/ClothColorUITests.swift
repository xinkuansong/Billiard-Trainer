import XCTest

final class ClothColorUITests: XCTestCase {
    func testPalettePersistenceAndTraining() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v51.followSystemAppearance", "-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium", "-deeplink.settings", "-v62.s267Lighting"])
        let entry = app.buttons["settings.clothColor"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15));
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        attach("settings-entry"); entry.tap()
        let preview = app.images["clothColor.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        for (key, title) in [("green", "经典绿"), ("tournamentBlue", "赛事蓝"), ("mistGray", "雾灰"), ("burgundy", "酒红"), ("blueGray", "蓝灰"), ("camel", "暖驼")] {
            let row = app.buttons["settings.clothColor." + key]
            for _ in 0..<4 where !row.isHittable || row.frame.maxY > app.windows.firstMatch.frame.maxY - 40 { app.swipeUp() }
            XCTAssertTrue(row.isHittable); row.tap()
            XCTAssertEqual(row.value as? String, "已选择")
            XCTAssertEqual(preview.label, title + "台呢预览")
            for _ in 0..<4 where !preview.isHittable || preview.frame.minY < app.navigationBars.firstMatch.frame.maxY { app.swipeDown() }
            attach("palette-" + key)
        }
        app.terminate(); app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 15));
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertEqual(app.buttons["settings.clothColor.camel"].value as? String, "已选择")
        app.terminate(); app.launchArguments.removeAll { $0 == "-deeplink.settings" }; app.launch()
        app.switchTab(.angle)
        app.buttons["angleHomeTab_打"].tap()
        for (title, prefix) in [("自由击球", "freeplay"), ("分离角与走位", "shotSimulation")] {
            let card = app.buttons[title]
            XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
            let mode = app.buttons[prefix + ".cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 25))
            if mode.value as? String != "3D" { mode.tap() }
            let table = app.descendants(matching: .any)["table.scene"].firstMatch
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "台呢颜色：暖驼"), object: table)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
            Thread.sleep(forTimeInterval: 1) // Let the camera and toolbar transition finish before capture.
            attach(prefix + "-camel-3d")
            mode.tap()
            Thread.sleep(forTimeInterval: 1)
            XCTAssertEqual(mode.value as? String, "2D")
            attach(prefix + "-camel-2d")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.terminate(); app.launchArguments.append("-deeplink.settings"); app.launch()
        XCTAssertTrue(entry.waitForExistence(timeout: 15));
        for _ in 0..<6 where !entry.isHittable { app.swipeUp() }
        entry.tap()
        let green = app.buttons["settings.clothColor.green"]
        XCTAssertTrue(green.waitForExistence(timeout: 10)); green.tap()
        XCTAssertEqual(green.value as? String, "已选择")
        attach("palette-restored-green")
    }
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
