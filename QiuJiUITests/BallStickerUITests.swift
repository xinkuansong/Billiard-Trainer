import XCTest

final class BallStickerUITests: XCTestCase {
    func testSelectedStickerInFreePlay() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings", "-forcePremium", "-v62.s267Lighting"])
        let link = app.buttons["settings.ballSticker.open"]
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        let badge = app.buttons["settings.ballSticker.badge"]
        for _ in 0..<8 where !badge.isHittable { app.swipeUp() }
        badge.tap();XCTAssertEqual(badge.value as? String, "已选择")
        app.terminate();app.launchArguments.removeAll { $0 == "-deeplink.settings" };app.launch()
        app.switchTab(.angle)
        let play = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(play.waitForExistence(timeout: 15));play.tap()
        let entry = app.buttons["自由击球"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10));entry.tap()
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertTrue(table.exists)
        try capture("freeplay-2d-badge")
        mode.tap()
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "3D"), object: mode)
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 5), .completed)
        let ready = NSPredicate(format: "enabled == true")
        let strike = app.buttons["击球"]
        expectation(for: ready, evaluatedWith: strike);waitForExpectations(timeout: 20)
        try capture("freeplay-3d-badge")
        strike.tap()
        let replay = app.buttons["回放"]
        expectation(for: ready, evaluatedWith: replay);waitForExpectations(timeout: 30)
        try capture("freeplay-after-shot")
        replay.tap()
        expectation(for: ready, evaluatedWith: replay);waitForExpectations(timeout: 30)
        app.buttons["重打"].tap()
        XCTAssertTrue(app.buttons["freeplay.focus"].isHittable)
        try capture("freeplay-reset")
    }

    func testSelectSixStylesAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings"])
        let link = app.buttons["settings.ballSticker.open"]
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        for style in ["modern", "minimal", "american", "badge", "broadcast", "vintage"] {
            let card = app.buttons["settings.ballSticker." + style]
            for _ in 0..<8 where !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.isHittable);card.tap()
            XCTAssertEqual(card.value as? String, "已选择")
            if ["modern","american","vintage"].contains(style) { try capture(style) }
        }
        app.terminate();app.launch()
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        let vintage = app.buttons["settings.ballSticker.vintage"]
        for _ in 0..<8 where !vintage.isHittable { app.swipeUp() }
        XCTAssertEqual(vintage.value as? String,"已选择")
        try capture("persisted-vintage")
        // Check the same selection page in light appearance.
        app.navigationBars.buttons.firstMatch.tap()
        let light = app.buttons["浅色"]
        for _ in 0..<8 where !light.isHittable { app.swipeDown() }
        light.tap();app.terminate()
        // Settings deep-link fixtures deliberately force Dark unless overridden.
        app.launchArguments.append("-v54.forceLight")
        app.launch()
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        XCTAssertEqual(app.scrollViews["settings.content"].value as? String, "light")
        link.tap()
        try capture("light-top")
        let modern = app.buttons["settings.ballSticker.modern"]
        XCTAssertTrue(modern.isHittable);modern.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["跟随系统"].tap()
    }

    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot);attachment.name = "ball-stickers-" + name
        attachment.lifetime = .keepAlways;add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/ball-stickers-20260913-v2/ui")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
    }
}
