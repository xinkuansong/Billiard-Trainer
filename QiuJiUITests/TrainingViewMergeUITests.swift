import XCTest

final class TrainingViewMergeUITests: XCTestCase {
    func testAccuracyDirectionDragInBothPlayerViews() throws {
        try checkDirectionDrag(route: "mergeAccuracy", prefix: "accuracy", title: "3D准度")
    }

    func testAimPointDirectionDragInBothPlayerViews() throws {
        try checkDirectionDrag(route: "mergeAim", prefix: "aimPointTraining", title: "3D瞄准点")
    }

    func testMultiBallDirectionDragInBothPlayerViews() throws {
        try checkDirectionDrag(route: "multiBall", prefix: "multiBall", title: "3D多球走位")
    }

    private func checkDirectionDrag(route: String, prefix: String, title: String) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-freeLayout.ephemeral", "-trainingMerge.probe", "-v63.cameraDiagnostics", "-dailyLayout.probe",
            "-3dDrag.probe", "-multiBall.fixedSeed", "-pro.route=" + route])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        app.maximizeTrainingTestWindow()
        func ready(_ element: XCUIElement) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
                NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)], timeout: 60), .completed)
        }
        ready(app.buttons[prefix + ".start"])
        if prefix == "multiBall" {
            let choice = app.segmentedControls["multiBall.positionMode"].buttons["自主走位"]
            for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
            ready(choice); choice.tap()
        }
        app.buttons[prefix + ".start"].tap()
        app.selectTrainingView(title)
        let diagnostic = app.descendants(matching: .any).matching(identifier: "v63.cameraDiagnostics").firstMatch
        func field(_ name: String) -> String? {
            (diagnostic.value as? String)?.split(separator: " ").first { $0.hasPrefix(name + "=") }
                .map { String($0.dropFirst(name.count + 1)) }
        }
        func direction() throws -> Double {
            // Camera references may deliberately stay frozen while observing.
            // Read the host's actual shot input, not the camera's last entry aim.
            if prefix == "multiBall" {
                let status = app.descendants(matching: .any).matching(identifier: "dailyLayout.controlsProbe").firstMatch
                let text = try XCTUnwrap(status.value as? String)
                func value(_ name: String) -> Double? {
                    text.split(separator: " ").first { $0.hasPrefix(name + "=") }
                        .flatMap { Double($0.dropFirst(name.count + 1)) }
                }
                return atan2(try XCTUnwrap(value("aimZ")), try XCTUnwrap(value("aimX")))
            }
            let id = prefix == "accuracy" ? "accuracy.mergeState" : "aimPoint.mergeState"
            let status = app.descendants(matching: .any).matching(identifier: id).firstMatch
            let text = try XCTUnwrap(status.value as? String)
            let input = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            if prefix == "accuracy" {
                return atan2(try XCTUnwrap(input["aimZ"] as? Double), try XCTUnwrap(input["aimX"] as? Double))
            }
            let aim = try XCTUnwrap(input["input"] as? [Double])
            return atan2(aim[1], aim[0])
        }
        func difference(_ a: Double, _ b: Double) -> Double { atan2(sin(a - b), cos(a - b)) }
        let wheel = prefix == "multiBall"
            ? app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "瞄准微调")).firstMatch
            : app.descendants(matching: .any).matching(identifier: prefix + ".aimWheel").firstMatch
        var thirdTravel: Double = 0
        for mode in ["thirdPerson", "firstPerson"] {
            let camera = app.buttons["shotCamera." + mode]
            ready(camera); camera.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                field("twoViewMode") == mode && field("twoViewMoving") == "false"
            }, object: app)], timeout: 15), .completed)
            ready(wheel)
            let before = try direction()
            let bottom = wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.8))
            let top = wheel.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.2))
            bottom.press(forDuration: 0.05, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.2)
            ready(wheel)
            let after = try direction(), travel = abs(difference(after, before))
            XCTAssertGreaterThan(travel, 0.001, "The full drag must change the actual shot direction")
            if mode == "thirdPerson" { thirdTravel = travel }
            else {
                XCTAssertGreaterThan(travel, thirdTravel * 0.5, "First person must consume the sustained drag, not only its first sample")
                top.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .slow, thenHoldForDuration: 0.2)
                ready(wheel)
                XCTAssertLessThan(difference(try direction(), after) * difference(after, before), 0, "Reversing the next drag must reverse the shot direction")
            }
            let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            image.name = prefix + "-continuous-aim-" + mode; image.lifetime = .keepAlways; add(image)
        }
    }

    func testAccuracySwitchKeepsQuestionInputsSceneAndQuota() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-w7.forceDailyLimitNear",
            "-trainingMerge.probe", "-3dDrag.probe", "-appearanceMode", "system", "-freeLayout.ephemeral"])
        app.maximizeTrainingTestWindow()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func state() throws -> [String: Any] {
            let data = try XCTUnwrap((node("accuracy.mergeState").value as? String)?.data(using: .utf8))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        func scene() throws -> [String: Any] {
            let data = try XCTUnwrap((node("table.scene").value as? String)?.data(using: .utf8))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons["准度"]
        if !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 8)); card.tap()
        let start = app.buttons["accuracy.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10)); try auditIfRequested(app); start.tap()
        XCTAssertTrue(app.buttons["accuracy.strike"].waitForExistence(timeout: 40))
        let initial = try state(), renderer = try scene()["rendererID"] as? String
        XCTAssertFalse((initial["question"] as? String ?? "").isEmpty)
        let firstView = try XCTUnwrap(initial["view"] as? String)
        for index in 0..<2 {
            app.buttons["accuracy.more"].tap()
            let mode = node("accuracy.cameraMode")
            XCTAssertTrue(mode.waitForExistence(timeout: 5)); XCTAssertTrue(mode.isEnabled); mode.tap()
            XCTAssertTrue(mode.exists, "Changing a segmented display choice keeps the menu open")
            let expected = index == 0 ? (firstView == "2D" ? "3D" : "2D") : firstView
            expectation(for: NSPredicate { _, _ in (try? state()["view"] as? String) == expected }, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            let next = try state()
            for key in ["session", "question", "phase", "used", "attempts", "velocity", "aimX", "aimZ", "spinX", "spinY", "pocket"] {
                XCTAssertEqual(String(describing: initial[key]), String(describing: next[key]), key)
            }
            XCTAssertEqual(try scene()["rendererID"] as? String, renderer)
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "accuracy-merged-\(expected)"; shot.lifetime = .keepAlways; add(shot)
            node("accuracy.dismissMenu").tap()
            try auditIfRequested(app)
            if index == 0 { XCUIDevice.shared.orientation = .landscapeLeft }
        }
        try resizeIfRequested(app, state: { try state() as NSDictionary })
    }
    func testAngleSwitch() throws { try switchProject(route: "mergeAngle", prefix: "angleTraining", probe: "angle.mergeState", more: "settings") }
    func testAimPointSwitch() throws { try switchProject(route: "mergeAim", prefix: "aimPointTraining", probe: "aimPoint.mergeState", more: "settings") }
    func testSeparationSwitchPreservesMeasurement() throws { try switchProject(route: "mergeSeparation", prefix: "separation", probe: "separation.probe", measurement: true) }
    func testTwoBallSwitchPreservesMeasurement() throws { try switchProject(route: "mergeTwo", prefix: "twoBall", probe: "twoBall.probe", measurement: true) }
    func testThreeBallSwitchPreservesMeasurement() throws { try switchProject(route: "mergeThree", prefix: "threeBall", probe: "threeBall.probe", measurement: true) }
    func testMultiBallSwitchPreservesRackAndMeasurement() throws { try switchProject(route: "multiBall", prefix: "multiBall", probe: "multiBall.mergeState", measurement: true) }

    private func switchProject(route: String, prefix: String, probe: String, more: String = "more", measurement: Bool = false) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", "-appearanceMode", "system",
            "-trainingMerge.probe", "-3dDrag.probe", "-separation.probe", "-twoBall.probe", "-threeBall.probe",
            "-separation.fixedSeed", "-twoBall.fixedSeed", "-threeBall.fixedSeed", "-multiBall.fixedSeed", "-pro.route=" + route])
        app.maximizeTrainingTestWindow()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func ready(_ e: XCUIElement, _ seconds: TimeInterval = 30) {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: seconds), .completed, e.debugDescription)
        }
        func state() throws -> NSDictionary {
            let text = try XCTUnwrap(node(probe).value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? NSDictionary)
        }
        ready(app.buttons[prefix + ".start"])
        try auditIfRequested(app)
        if prefix == "multiBall" {
            let choice = app.segmentedControls["multiBall.positionMode"].buttons["自主走位"]
            for _ in 0..<8 where !choice.isHittable { app.swipeUp() }
            ready(choice); choice.tap()
        }
        ready(app.buttons[prefix + ".start"]); app.buttons[prefix + ".start"].tap()
        // Generation and rotation finish before the table's AX activation points exist.
        XCTAssertTrue(app.buttons[prefix + ".start"].waitForNonExistence(timeout: 180))
        let moreID = prefix == "multiBall" ? "freeplay.moreMenu" : prefix + "." + more
        ready(app.buttons[moreID], 180)
        if measurement {
            let button = app.buttons[prefix + ".geometry"]
            ready(button); button.tap(); ready(app.buttons[prefix + ".geometry.3"]); app.buttons[prefix + ".geometry.3"].tap()
        }
        let initial = try state()
        let firstView = try XCTUnwrap(initial["view"] as? String)
        for index in 0..<2 {
            ready(app.buttons[moreID]); app.buttons[moreID].tap()
            let mode = node(prefix == "multiBall" ? "freeplay.cameraMode" : prefix + ".cameraMode")
            ready(mode); mode.tap()
            let expected = index == 0 ? (firstView == "2D" ? "3D" : "2D") : firstView
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (try? state()["view"] as? String) == expected
            }, object: app)], timeout: 12), .completed)
            XCTAssertTrue(mode.exists, "Switching views keeps the display menu open")
            let next = try state()
            for key in ["session", "question", "phase", "used", "quota", "answers", "attempts", "input", "number", "remaining", "scoreCount"] {
                XCTAssertEqual(initial[key] as? NSObject, next[key] as? NSObject, key)
            }
            if measurement {
                let before = try XCTUnwrap(initial["geometry"] as? NSDictionary), after = try XCTUnwrap(next["geometry"] as? NSDictionary)
                for key in ["count", "first", "points", "visible", "frozen"] {
                    XCTAssertEqual(before[key] as? NSObject, after[key] as? NSObject, "geometry." + key)
                }
            }
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = prefix + "-merged-" + expected; attachment.lifetime = .keepAlways; add(attachment)
            let dismiss = node(prefix == "multiBall" ? "dailyClearance.menuClose" : prefix + ".dismissMenu")
            if dismiss.exists { dismiss.tap() }
            else { app.buttons["关闭菜单"].firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.03, dy: 0.7)).tap() }
            try auditIfRequested(app)
            if index == 0 { XCUIDevice.shared.orientation = .landscapeLeft }
        }
        if ProcessInfo.processInfo.environment["MERGE_READABILITY_ACTIONS"] == "1" {
            if prefix == "aimPointTraining" {
                ready(app.buttons["aimPointTraining.angleHint"]); app.buttons["aimPointTraining.angleHint"].tap()
                ready(app.buttons["aimPointTraining.submit"]); app.buttons["aimPointTraining.submit"].tap()
                XCTAssertTrue(app.buttons["aimPointTraining.next"].waitForExistence(timeout: 20))
                try auditIfRequested(app)
                ready(app.buttons["aimPointTraining.next"])
                let finishes = app.buttons["aimPointTraining.next"].label == "总结"
                app.buttons["aimPointTraining.next"].tap()
                ready(app.buttons[finishes ? "training.complete" : "aimPointTraining.submit"])
            } else if prefix == "angleTraining" {
                ready(app.buttons["angleTraining.assist"]); app.buttons["angleTraining.assist"].tap()
                ready(app.buttons["angleTraining.primaryAction"]); app.buttons["angleTraining.primaryAction"].tap()
                ready(app.buttons["2"].firstMatch); app.buttons["2"].firstMatch.tap()
                app.buttons["0"].firstMatch.tap(); app.buttons["提交"].tap()
                XCTAssertTrue(app.staticTexts["angleTraining.result"].waitForExistence(timeout: 20))
                try auditIfRequested(app)
                ready(app.buttons["angleTraining.primaryAction"])
                let finishes = app.buttons["angleTraining.primaryAction"].label == "总结"
                app.buttons["angleTraining.primaryAction"].tap()
                ready(app.buttons[finishes ? "training.complete" : "angleTraining.assist"])
            }
        }
        try resizeIfRequested(app, state: state)
    }

    private func resizeIfRequested(_ app: XCUIApplication, state: () throws -> NSDictionary) throws {
        guard ProcessInfo.processInfo.environment["MERGE_SYSTEM_WINDOW"] == "1" else { return }
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
        let before = try state(), window = app.windows.firstMatch, full = app.windows.firstMatch.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: full.width - 7, dy: full.height - 7)).press(forDuration: 0.5,
            thenDragTo: origin.withOffset(.init(dx: full.width * 0.7, dy: full.height * 0.78)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width < full.width - 80
        }, object: app)], timeout: 10), .completed)
        func verify(_ label: String) throws {
            let after = try state()
            for key in ["session", "question", "phase", "used", "quota", "answers", "attempts", "input", "number", "remaining", "scoreCount", "geometry"] {
                XCTAssertEqual(before[key] as? NSObject, after[key] as? NSObject, key)
            }
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "system-window-" + label; screenshot.lifetime = .keepAlways; add(screenshot)
            let metadata = XCTAttachment(string: "original=\(full) actual=\(window.frame)\n\(app.debugDescription)")
            metadata.name = "system-window-" + label + "-frames"; metadata.lifetime = .keepAlways; add(metadata)
        }
        try verify("small")
        // iPadOS floating windows can retain portrait aspect after device rotation.
        // Resize the actual window to landscape and verify its measured dimensions.
        window.coordinate(withNormalizedOffset: .init(dx: 1, dy: 1)).withOffset(.init(dx: -7, dy: -7))
            .press(forDuration: 0.5, thenDragTo: window.coordinate(withNormalizedOffset: .zero)
                .withOffset(.init(dx: full.width * 0.9, dy: full.height * 0.5)))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            window.frame.width > window.frame.height + 80
        }, object: app)], timeout: 10), .completed)
        try verify("landscape")
        app.maximizeTrainingTestWindow()
        let restored = window.frame
        for (actual, expected) in zip([restored.minX, restored.minY, restored.width, restored.height],
                                     [full.minX, full.minY, full.width, full.height]) {
            XCTAssertEqual(actual, expected, accuracy: 1)
        }
        try verify("restored")
    }

    private func auditIfRequested(_ app: XCUIApplication) throws {
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = "readability-state"; evidence.lifetime = .keepAlways; add(evidence)
        let auditMode = ProcessInfo.processInfo.environment["MERGE_ACCESSIBILITY_AUDIT"]
        guard auditMode == "1" || auditMode == "all" else { return }
        let previousContinuation = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = previousContinuation }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "accessibility-system-state"; screenshot.lifetime = .keepAlways; add(screenshot)
        let metadata = XCTAttachment(string: "window=\(app.windows.firstMatch.frame)\n\(app.debugDescription)")
        metadata.name = "accessibility-hierarchy"; metadata.lifetime = .keepAlways; add(metadata)
        if #available(iOS 17.0, *) {
            let auditTypes: XCUIAccessibilityAuditType = auditMode == "all" ? .all
                : [.sufficientElementDescription, .trait, .hitRegion, .textClipped]
            try app.performAccessibilityAudit(for: auditTypes) { issue in
                let detail = "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No associated element")"
                print("MERGE_ACCESSIBILITY_ISSUE " + detail)
                let evidence = XCTAttachment(string: detail)
                evidence.name = "accessibility-issue-detail"; evidence.lifetime = .keepAlways; self.add(evidence)
                return false // Record every issue; do not suppress audit failures.
            }
        }
    }

}
