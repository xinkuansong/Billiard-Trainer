import XCTest

final class CueStyleUITests: XCTestCase {
    func testSelectedCueInFreePlay() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings", "-forcePremium"])
        let link = app.buttons["settings.cueStyle.open"]
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        let inkDragon = app.buttons["settings.cue.inkDragon"]
        for _ in 0..<8 where !inkDragon.isHittable { app.swipeUp() }
        inkDragon.tap();XCTAssertEqual(inkDragon.value as? String, "已选择")
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
        try capture("freeplay-2d-inkDragon")
        mode.tap()
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "3D"), object: mode)
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 5), .completed)
        let ready = NSPredicate(format: "enabled == true")
        let strike = app.buttons["击球"]
        expectation(for: ready, evaluatedWith: strike);waitForExpectations(timeout: 20)
        try capture("freeplay-3d-inkDragon")
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

    func testSelectTenStylesAndPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-deeplink.settings"])
        let link = app.buttons["settings.cueStyle.open"]
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        for style in ["inkDragon", "porcelain", "landscape", "blackGold", "heritage", "wave", "orbit", "racing", "koi", "circuit"] {
            let card = app.buttons["settings.cue." + style]
            reveal(card, in: app)
            XCTAssertTrue(card.isHittable);card.tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "已选择"), object: card)
            let result = XCTWaiter.wait(for: [selected], timeout: 3)
            if result != .completed { try capture("failed-" + style) }
            XCTAssertEqual(result, .completed, style)
            if ["inkDragon","landscape","circuit"].contains(style) { try capture(style) }
        }
        app.terminate();app.launch()
        XCTAssertTrue(link.waitForExistence(timeout: 15));link.tap()
        let circuit = app.buttons["settings.cue.circuit"]
        reveal(circuit, in: app)
        XCTAssertEqual(circuit.value as? String,"已选择")
        try capture("persisted-circuit")
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
        let inkDragon = app.buttons["settings.cue.inkDragon"]
        XCTAssertTrue(inkDragon.isHittable);inkDragon.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["跟随系统"].tap()
    }

    private func reveal(_ card: XCUIElement, in app: XCUIApplication) {
        let bottom = app.windows.firstMatch.frame.maxY - 40
        for _ in 0..<12 {
            if card.exists && card.isHittable && card.frame.minY >= 100 && card.frame.maxY <= bottom { return }
            if card.exists && card.frame.minY < 100 { app.swipeDown() }
            else { app.swipeUp() }
        }
    }

    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot);attachment.name = "cue-styles-" + name
        attachment.lifetime = .keepAlways;add(attachment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/cue-stickers/ui")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
    }
}
