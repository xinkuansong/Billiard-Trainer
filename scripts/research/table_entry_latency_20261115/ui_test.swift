
final class TableEntryLatencyResearchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testEntryStages() throws {
        let env = ProcessInfo.processInfo.environment
        let mode = env["ENTRY_MODE"] ?? env["TEST_RUNNER_ENTRY_MODE"] ?? "3D"
        let arm = env["ENTRY_ARM"] ?? env["TEST_RUNNER_ENTRY_ARM"] ?? "default"
        let routes = (env["ENTRY_ROUTES"] ?? env["TEST_RUNNER_ENTRY_ROUTES"] ?? "composer,daily").split(separator: ",").map(String.init)
        let cycles = Int(env["ENTRY_CYCLES"] ?? env["TEST_RUNNER_ENTRY_CYCLES"] ?? "3")!
        var args = ["-entry.probe", "-entry."+mode, "-freeLayout.ephemeral"]
        if arm == "reference" { args.append("-rendering.referenceCloth") }
        if arm == "stacks" { args.append("-entry.stacks") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        defer { app.terminate() }
        for route in routes {
            if route == "composer" {
                app.switchTab(.angle)
                let tab = app.buttons["angleHomeTab_走位"]
                XCTAssertTrue(tab.waitForExistence(timeout: 10)); tab.tap()
            } else { app.switchTab(.training) }
            for cycle in 0..<cycles {
                let entry = app.buttons[route == "composer" ? "分离角与走位" : "trainingHome.dailyClearance"].firstMatch
                for _ in 0..<5 { if entry.isHittable { break }; app.swipeUp() }
                XCTAssertTrue(entry.waitForExistence(timeout: 10)); XCTAssertTrue(entry.isHittable)
                entry.tap()
                // No AX calls in the initial measurement window after XCTest returns.
                sleep(3)
                let back = app.buttons["dailyClearance.back"]
                XCTAssertTrue(back.waitForExistence(timeout: 15)); XCTAssertTrue(back.isHittable)
                let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
                XCTAssertTrue(stage.exists)
                if cycle == 0 {
                    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    image.name = "entry-\(mode)-\(arm)-\(route)"; image.lifetime = .keepAlways; add(image)
                }
                // Prove actual input acceptance, not just presence of controls.
                let more = app.buttons["freeplay.moreMenu"]
                XCTAssertTrue(more.isHittable); more.tap()
                let menu = app.descendants(matching: .any)["dailyClearance.menuPanel"].firstMatch
                XCTAssertTrue(menu.waitForExistence(timeout: 5))
                let close = app.buttons["dailyClearance.menuClose"]
                if close.isHittable { close.tap() }
                else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                XCTAssertTrue(back.isHittable); back.tap()
                XCTAssertTrue(entry.waitForExistence(timeout: 10))
                sleep(1)
            }
        }
    }
}
