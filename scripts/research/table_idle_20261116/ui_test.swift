
final class TableIdleResearchTests: XCTestCase {
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
        print("TABLE_IDLE_CHECKPOINT", label,
              (data["objects"] as? [[String: Any]] ?? []).filter { $0["alive"] as? Bool == true }.map { "\($0["kind"] ?? "?"):\($0["owner"] ?? "?")" },
              "jobs", data["jobs"] ?? [:], "cpu", data["processCPUSeconds"] ?? -1, "counters", data["counters"] ?? [:])
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
    private let routes = [("composer", "分离角与走位", "dailyClearance.back", "dailyClearance.strike", "dailyClearance.undo"),
                          ("two", "两球走位", "twoBall.back", "twoBall.strike", "twoBall.retry"),
                          ("three", "三球走位", "threeBall.back", "threeBall.strike", "threeBall.retry")]
    private func enter(_ route: (String, String, String, String, String)) throws {
        let entry = app.buttons[route.1].firstMatch
        reveal(entry); ready(entry); entry.tap()
        if route.0 != "composer" {
            let start = app.buttons[route.0 == "two" ? "twoBall.start" : "threeBall.start"]
            if start.waitForExistence(timeout: 2) { ready(start); start.tap() }
        }
        ready(app.buttons[route.2], timeout: 180)
        ready(app.buttons[route.3], timeout: 180)
        if route.0 == "three" {
            sleep(2)
            let table = node("table.scene"); ready(table)
            let value = try XCTUnwrap(table.value as? String)
            let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
            let pockets = try XCTUnwrap(state["pockets"] as? [[String: Any]])
            let pocket = try XCTUnwrap(pockets.first { ($0["index"] as? Int) == 5 })
            let point = try XCTUnwrap(pocket["screen"] as? [Double])
            table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
            let selected = try activity("three")
            XCTAssertEqual(selected["plannedPocket"] as? Int, 5)
        }
    }
    private func activity(_ owner: String) throws -> [String: Any] {
        let value = try XCTUnwrap(node(owner + "Ball.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func leave(_ route: (String, String, String, String, String)) {
        ready(app.buttons[route.2]); app.buttons[route.2].tap()
        ready(app.buttons["angleHomeTab_走位"])
    }
    private func measureIdle(_ name: String) throws {
        _ = try capture(name + ".start")
        sleep(20) // Observation window, not an animation-completion condition.
        _ = try capture(name + ".end")
    }
    func testFourWorkloadStates() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-tableLife.probe", "-v50.inMemoryStore", "-freeLayout.ephemeral", "-forcePremium", "-twoBall.fixedSeed", "-threeBall.fixedSeed", "-twoBall.probe", "-threeBall.probe", "-3dDrag.probe"])
        defer { app.terminate() }
        app.switchTab(.angle)
        ready(app.buttons["angleHomeTab_走位"]); app.buttons["angleHomeTab_走位"].tap()
        sleep(10)
        try measureIdle("list.initial")
        for route in routes {
            try enter(route); sleep(10)
            _ = try capture(route.0 + ".screen", screenshot: true)
            try measureIdle(route.0 + ".firstIdle")
            _ = try capture(route.0 + ".shots.start")
            for shot in 0..<3 {
                ready(app.buttons[route.3])
                XCTAssertEqual(app.buttons[route.3].label, "击球")
                if route.0 != "composer" { XCTAssertEqual(try activity(route.0)["playsStroke"] as? Bool, true) }
                app.buttons[route.3].tap()
                // Retry readiness belongs to the production playback-completion state.
                ready(app.buttons[route.4], timeout: 90)
                if route.0 != "composer" {
                    let result = try activity(route.0)
                    if route.0 == "three" {
                        // A successful first stroke advances to the second-stage aiming state.
                        XCTAssertEqual(result["phase"] as? String, "aiming")
                        XCTAssertEqual(result["stage"] as? Int, 1)
                        XCTAssertNotNil(result["firstScore"] as? Double)
                    } else {
                        XCTAssertEqual(result["phase"] as? String, "result")
                    }
                    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                    let evidence = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    evidence.name = route.0 + ".shot-\(shot)-result"; evidence.lifetime = .keepAlways; add(evidence)
                }
                _ = try capture(route.0 + ".shot-\(shot)-finished")
                if shot < 2 {
                    app.buttons[route.4].tap()
                    ready(app.buttons[route.3], timeout: 90)
                }
            }
            _ = try capture(route.0 + ".shots.end")
            sleep(10)
            try measureIdle(route.0 + ".afterShotsIdle")
            ready(app.buttons[route.4]); app.buttons[route.4].tap()
            ready(app.buttons[route.3], timeout: 90)
            leave(route); sleep(5)
            assertReleased(try capture(route.0 + ".returned"), checkpoint: route.0)
        }
        _ = try capture("switching.start")
        for cycle in 0..<2 {
            for route in routes {
                try enter(route); sleep(3)
                _ = try capture("switching.\(cycle)." + route.0)
                leave(route); sleep(3)
            }
        }
        _ = try capture("switching.end")
        for route in routes {
            try enter(route); sleep(10)
            try measureIdle(route.0 + ".reenteredIdle")
            leave(route); sleep(5)
            assertReleased(try capture(route.0 + ".final-returned"), checkpoint: route.0)
        }
        sleep(10)
        try measureIdle("list.final")
        assertReleased(try capture("final", screenshot: true), checkpoint: "final")
    }
}
