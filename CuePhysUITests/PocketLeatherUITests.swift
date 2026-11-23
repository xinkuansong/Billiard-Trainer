import XCTest

final class PocketLeatherUITests: XCTestCase {
    private let evidence = URL(fileURLWithPath: URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/pocket-leather/ui").path)

    func testBaselineDaily() throws { try capture("daily", args: ["-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.fixture=progress", "-dailyClearance.fixtureSettled"]) }
    func testBaselinePlanThree() throws { try capture("planthree", args: ["-planThree.twoBall"]) }
    func testBaseline3D() throws { try capture("aim3d", title: "3D 瞄准点训练") }

    private func capture(_ name: String, args: [String] = [], title: String? = nil) throws {
        continueAfterFailure = false
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium"] + args)
        if let title {
            app.switchTab(.angle)
            let search = app.textFields["librarySearchField"]
            XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap(); search.typeText(title)
            let card = app.buttons[title]; XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
        }
        if name == "daily" {
            XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 15))
        } else if name == "planthree" {
            XCTAssertTrue(app.buttons["清空计划"].waitForExistence(timeout: 15))
        } else {
            XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 15), app.debugDescription)
        }
        Thread.sleep(forTimeInterval: 3)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.descendants(matching: .any)["table.scene"].exists)
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: evidence.appendingPathComponent("\(name).png"))
        try app.debugDescription.write(to: evidence.appendingPathComponent("\(name)-ax.txt"), atomically: true, encoding: .utf8)
        let attachment = XCTAttachment(screenshot: shot); attachment.lifetime = .keepAlways; attachment.name = name; add(attachment)
        if name == "aim3d" {
            let table=app.descendants(matching:.any)["table.scene"].firstMatch
            let target=table.value as? String
            table.swipeLeft();table.swipeUp();table.pinch(withScale:1.15,velocity:1)
            XCTAssertEqual(table.value as? String,target,"Camera gestures must not change the fixed target")
            XCTAssertEqual(app.state,.runningForeground)
            let moved=XCUIScreen.main.screenshot()
            try moved.pngRepresentation.write(to:evidence.appendingPathComponent("aim3d-camera-moved.png"))
            let proof=XCTAttachment(screenshot:moved);proof.name="aim3d-camera-moved";proof.lifetime = .keepAlways;add(proof)
        }
    }
}
