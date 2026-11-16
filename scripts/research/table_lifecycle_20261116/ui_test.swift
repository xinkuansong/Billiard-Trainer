
final class TableLifecycleResearchTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)], timeout: timeout), .completed)
    }
    private func capture(_ label: String, screenshot: Bool = false) throws -> [String: Any] {
        let value = try XCTUnwrap(node("tableLife.probe").value as? String)
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
        data["checkpoint"] = label
        let bytes = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "lifecycle-" + label; attachment.lifetime = .keepAlways; add(attachment)
        if screenshot {
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = label; image.lifetime = .keepAlways; add(image)
        }
        print("TABLE_LIFECYCLE_CHECKPOINT", label,
              (data["objects"] as? [[String: Any]] ?? []).filter { $0["alive"] as? Bool == true }.map { "\($0["kind"] ?? "?"):\($0["owner"] ?? "?")" },
              "jobs", data["jobs"] ?? [:])
        return data
    }
    private func reveal(_ entry: XCUIElement) {
        for _ in 0..<12 {
            let window = app.windows.firstMatch.frame
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : window.minY
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : window.maxY
            if entry.exists, entry.isHittable, entry.frame.midY > top, entry.frame.midY < bottom { return }
            let delta = entry.exists ? (top + bottom) / 2 - entry.frame.midY : -window.height / 4
            let start = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(.init(dx: 0, dy: min(window.height/4, max(-window.height/4, delta)))))
        }
        ready(entry)
    }
    private func assertReleased(_ snapshot: [String: Any], checkpoint: String) {
        let objects = snapshot["objects"] as? [[String: Any]] ?? []
        let alive = objects.filter { $0["alive"] as? Bool == true }
        XCTAssertTrue(alive.isEmpty, "Old page objects retained at \(checkpoint): \(alive)")
        XCTAssertEqual((snapshot["jobs"] as? [String: String])?.count, 0, "Old compute jobs still running")
    }
    func testThirtyRealPageVisits() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-tableLife.probe", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-forcePremium", "-twoBall.fixedSeed", "-threeBall.fixedSeed", "-twoBall.probe", "-threeBall.probe"])
        defer { app.terminate() }
        app.switchTab(.angle)
        ready(app.buttons["angleHomeTab_走位"]); app.buttons["angleHomeTab_走位"].tap()
        sleep(2)
        let baseline = try capture("baseline", screenshot: true)
        assertReleased(baseline, checkpoint: "baseline")
        let routes = [("composer", "分离角与走位", "dailyClearance.back", "dailyClearance.strike"),
                      ("two", "两球走位", "twoBall.back", "twoBall.strike"),
                      ("three", "三球走位", "threeBall.back", "threeBall.strike")]
        for cycle in 0..<10 {
            for (owner, title, backID, strikeID) in routes {
                let label = "\(cycle)-\(owner)"
                let entry = app.buttons[title].firstMatch
                reveal(entry); ready(entry); entry.tap()
                if owner != "composer" {
                    let start = app.buttons[owner == "two" ? "twoBall.start" : "threeBall.start"]
                    if start.waitForExistence(timeout: 2) { ready(start); start.tap() }
                }
                ready(app.buttons[backID], timeout: 180)
                XCTAssertTrue(app.buttons[strikeID].exists)
                sleep(3)
                let entered = try capture(label + "-entered", screenshot: cycle == 0)
                let liveVMs = (entered["objects"] as? [[String: Any]] ?? []).filter { $0["kind"] as? String == "vm" && $0["alive"] as? Bool == true }
                XCTAssertEqual(liveVMs.count, 1, "Exactly this page's VM should remain")
                XCTAssertEqual(liveVMs.first?["owner"] as? String, owner)
                if cycle % 3 == 1, app.buttons[strikeID].isEnabled {
                    app.buttons[strikeID].tap()
                    _ = try capture(label + "-after-strike")
                }
                if cycle % 3 == 2 {
                    XCUIDevice.shared.press(.home); sleep(2); app.activate()
                    ready(app.buttons[backID]); sleep(2)
                    _ = try capture(label + "-resumed")
                }
                ready(app.buttons[backID]); app.buttons[backID].tap()
                XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 15))
                sleep(5)
                let returned = try capture(label + "-returned", screenshot: cycle == 0)
                assertReleased(returned, checkpoint: label)
                if cycle == 2 {
                    XCUIDevice.shared.press(.home); sleep(2); app.activate(); sleep(3)
                    assertReleased(try capture(label + "-home-resumed"), checkpoint: label + "-home-resumed")
                }
            }
        }
        sleep(5)
        assertReleased(try capture("final", screenshot: true), checkpoint: "final")
    }
}
