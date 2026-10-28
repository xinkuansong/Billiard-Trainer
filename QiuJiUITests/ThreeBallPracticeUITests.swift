import XCTest

final class ThreeBallPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    private var requestedView = "2D三球走位"
    override func setUp() { continueAfterFailure = false }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 100) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: e)], timeout: timeout), .completed, e.debugDescription)
    }
    private func probe() throws -> [String: Any] {
        let text = try XCTUnwrap(node("threeBall.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }
    private func phase(_ value: String) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            (try? self.probe()["phase"] as? String) == value
        }, object: nil)], timeout: 120), .completed)
    }
    private func capture(_ label: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = label; a.lifetime = .keepAlways; add(a)
    }
    private func revealEntry(_ entry: XCUIElement) {
        for _ in 0..<8 {
            let window = app.windows.firstMatch.frame
            let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : window.minY
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : window.maxY
            if entry.exists, entry.isHittable, entry.frame.midY > top, entry.frame.midY < bottom { return }
            let height = window.height
            let target = (top + bottom) / 2
            let delta = entry.exists ? target - entry.frame.midY : -height / 4
            let bounded = min(height / 4, max(-height / 4, delta))
            print("THREE_ENTRY_REVEAL", entry.frame, "window", window, "delta", bounded)
            let start = app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(.init(dx: 0, dy: bounded)))
        }
    }
    private func open(_ is3D: Bool, animated: Bool = false, largeText: Bool = false) throws {
        requestedView = (is3D ? "3D" : "2D") + "三球走位"
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-freeLayout.ephemeral", "-forcePremium",
            "-threeBall.probe", "-threeBall.fixedSeed", "-3dDrag.probe", "-AppleInterfaceStyle", is3D ? "Dark" : "Light"]
            + (largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []) + (is3D ? ["-pro.route=mergeThree3D"] : []))
        if !is3D {
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons["三球走位"]
        revealEntry(entry)
        ready(entry); entry.tap()
        }
        ready(app.buttons["threeBall.start"])
        XCTAssertFalse(app.switches["training.verticalSpin"].exists)
        XCTAssertFalse(app.segmentedControls["twoBall.mode"].exists)
        let toggle = app.switches["separation.playsStroke"]
        for _ in 0..<16 {
            let window = app.windows.firstMatch.frame
            let navigationBottom = app.navigationBars.firstMatch.frame.maxY
            if toggle.exists, toggle.isHittable,
               toggle.frame.minY > navigationBottom + 8, toggle.frame.maxY < window.maxY - 20 { break }
            let down = toggle.exists && toggle.frame.minY <= navigationBottom + 8
            app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: down ? 0.4 : 0.6))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: down ? 0.6 : 0.4)))
        }
        ready(toggle)
        print("THREE_BALL_SETTINGS_TOGGLE frame=\(toggle.frame) nav=\(app.navigationBars.firstMatch.frame)")
        if (toggle.value as? String == "1") != animated {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        }
        XCTAssertEqual(toggle.value as? String, animated ? "1" : "0")
        capture("threeBall-settings-\(is3D)")
        app.buttons["threeBall.start"].tap(); phase("aiming")
        ready(app.buttons["threeBall.strike"])
        app.selectTrainingView(requestedView)
        XCTAssertFalse(node("threeBall.question").exists)
        let initial = try probe()
        let firstNumber = try XCTUnwrap(initial["ballNumber"] as? Int)
        let secondNumber = try XCTUnwrap(initial["nextBallNumber"] as? Int)
        XCTAssertNotEqual(firstNumber, secondNumber)
        XCTAssertTrue((1...7).contains(firstNumber) || (9...15).contains(firstNumber))
        XCTAssertTrue((1...7).contains(secondNumber) || (9...15).contains(secondNumber))
        XCTAssertEqual(firstNumber > 8, secondNumber > 8)
        XCTAssertEqual(initial["thirdBallNumber"] as? Int, 8)
        XCTAssertEqual(initial["bankCount"] as? Int, 111025)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).count, 3)
        XCTAssertEqual(node("paletteBall__\(firstNumber)").value as? String, "当前击打球")
        XCTAssertEqual(node("paletteBall__\(secondNumber)").value as? String, "下一颗目标球")
        let expectedView = is3D ? "3D" : "2D"
        if (try probe()["view"] as? String) != expectedView {
            app.buttons["threeBall.more"].tap()
            let mode = node("threeBall.cameraMode"); ready(mode); mode.tap()
            node("threeBall.dismissMenu").tap()
        }
        XCTAssertEqual(try probe()["view"] as? String, expectedView)
        if is3D { ready(app.buttons["dailyClearance.observeTable"]); app.buttons["dailyClearance.observeTable"].tap() }
        capture("threeBall-await-pocket-\(is3D)")
    }
    private func selectPocket(_ index: Int) throws {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            (try? self.probe()["cameraBusy"] as? Bool) == false
        }, object: nil)], timeout: 20), .completed)
        let overview = app.buttons["shotCamera.temporaryTopDown"]
        let usesTemporaryView = overview.exists
        if usesTemporaryView { ready(overview); overview.tap() }
        let table = node("table.scene"); ready(table)
        let json = try XCTUnwrap(table.value as? String)
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let pockets = try XCTUnwrap(state["pockets"] as? [[String: Any]])
        let pocket = try XCTUnwrap(pockets.first { ($0["index"] as? Int) == index })
        let point = try XCTUnwrap(pocket["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: point[0], dy: point[1])).tap()
        if usesTemporaryView {
            XCTAssertFalse(app.buttons["threeBall.strike"].isEnabled)
            capture("threeBall-temporary-pocket-\(index)")
            overview.tap()
        }
    }
    func testGeometryReference2D() throws { try geometryReference(false) }
    func testGeometryReference3D() throws { try geometryReference(true) }
    private func geometryReference(_ is3D: Bool) throws {
        try open(is3D)
        try selectPocket(1)
        func geometry() throws -> [String: Any] { try XCTUnwrap(probe()["geometry"] as? [String: Any]) }
        let menu = app.buttons["threeBall.geometry"]; ready(menu); menu.tap()
        let option = app.buttons["threeBall.geometry.2"]; ready(option); option.tap()
        let first = try XCTUnwrap(geometry()["first"] as? [Double])
        XCTAssertEqual(try geometry()["visible"] as? Bool, true)
        capture("threeBall-geometry-\(is3D)")
        app.buttons["threeBall.strike"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
            guard let s = try? self.probe() else { return false }
            return s["phase"] as? String == "result" || s["stage"] as? Int == 1
        }, object: nil)], timeout: 60), .completed)
        XCTAssertEqual(try geometry()["visible"] as? Bool, false)
        if try probe()["stage"] as? Int == 1 { XCTAssertEqual(try geometry()["count"] as? Int, 0) }
        let retry = app.buttons["threeBall.retry"]; ready(retry); retry.tap(); phase("aiming")
        XCTAssertEqual(try geometry()["visible"] as? Bool, true)
        XCTAssertEqual(try geometry()["first"] as? [Double], first)
        capture("threeBall-geometry-restored-\(is3D)")
        app.terminate()
    }

    func test2DTwoStagePlanning() throws { try exercise(false) }
    func test3DTwoStagePlanning() throws { try exercise(true) }
    func test2DUnplayableContinuationNoticeAndRetry() throws { try unplayableContinuation(false) }
    func test3DUnplayableContinuationNoticeAndRetry() throws { try unplayableContinuation(true) }
    private func unplayableContinuation(_ is3D: Bool) throws {
        try open(is3D)
        let initial = try probe()
        var found = false
        for pocket in 0..<6 {
            try selectPocket(pocket)
            app.buttons["threeBall.strike"].tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                guard let state = try? self.probe() else { return false }
                return state["phase"] as? String == "result" || state["stage"] as? Int == 1
            }, object: nil)], timeout: 60), .completed)
            XCTAssertFalse(app.alerts.firstMatch.exists)
            if try probe()["phase"] as? String == "result" {
                found = true
                let notice = node("threeBall.result")
                XCTAssertTrue(notice.waitForExistence(timeout: 2))
                XCTAssertEqual(notice.label, "0分，无法进指定袋，请重打")
                XCTAssertEqual(try probe()["stage"] as? Int, 0)
                XCTAssertEqual(try probe()["score"] as? Double, 0)
                capture("unplayable-notice-\(is3D)")
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
                    NSPredicate(format: "exists == false"), object: notice)], timeout: 4), .completed)
                XCTAssertFalse(app.alerts.firstMatch.exists)
                let quota = try probe()["quota"] as? Int
                capture("unplayable-expired-\(is3D)")
                app.buttons["threeBall.retry"].tap(); phase("aiming")
                let restored = try probe()
                XCTAssertEqual(restored["question"] as? String, initial["question"] as? String)
                XCTAssertEqual(restored["positions"] as? [String:[Double]], initial["positions"] as? [String:[Double]])
                XCTAssertEqual(restored["plannedPocket"] as? Int, pocket)
                XCTAssertEqual(restored["quota"] as? Int, quota)
                XCTAssertEqual(restored["attempts"] as? Int, 1)
                capture("unplayable-retry-\(is3D)")
                break
            }
            app.buttons["threeBall.retry"].tap(); phase("aiming")
        }
        XCTAssertTrue(found, "The fixed real shot must expose an unreachable chosen pocket")
    }
    private func exercise(_ is3D: Bool) throws {
        try open(is3D)
        let initial = try probe(), question = initial["question"] as? String
        let originalKeys = initial["onTableKeys"] as? [String]
        let secondNumber = try XCTUnwrap(initial["nextBallNumber"] as? Int)
        let currentPocket = try XCTUnwrap(initial["currentPocket"] as? Int)
        ready(app.buttons["threeBall.strike"])
        app.buttons["threeBall.strike"].tap()
        XCTAssertTrue(node("threeBall.question").waitForExistence(timeout: 2))
        XCTAssertTrue(node("threeBall.question").label.contains("\(secondNumber)号"))
        XCTAssertEqual(try probe()["attempts"] as? Int, 0)
        XCTAssertEqual(try probe()["quota"] as? Int, initial["quota"] as? Int)
        capture("threeBall-missing-pocket-on-demand-\(is3D)")
        try selectPocket(currentPocket)
        XCTAssertEqual((try probe()["pocketStyles"] as? [String:String])?[String(currentPocket)], "practiceBoth")
        capture("threeBall-same-pocket-\(is3D)")
        try selectPocket(5)
        XCTAssertFalse(node("threeBall.question").exists)
        Thread.sleep(forTimeInterval: 3.3)
        XCTAssertEqual((try probe()["pocketStyles"] as? [String:String])?[String(currentPocket)], currentPocket == 5 ? "practiceBoth" : "practiceCurrent")
        capture("threeBall-persistent-roles-\(is3D)")
        app.buttons["threeBall.strike"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["stage"] as? Int, 1)
        XCTAssertEqual(try probe()["ballNumber"] as? Int, secondNumber)
        XCTAssertEqual(try probe()["currentPocket"] as? Int, 5)
        XCTAssertEqual(node("paletteBall__\(secondNumber)").value as? String, "当前击打球")
        XCTAssertEqual(node("paletteBall__8").value as? String, "下一颗目标球")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paletteBall_")).count, 3)
        let quota = try probe()["quota"] as? Int
        capture("threeBall-auto-second-stage-\(is3D)")
        // Persist the checkpoint, then return to the first stroke through the actual retry button.
        app.buttons["threeBall.back"].tap()
        ready(app.buttons["angleHomeTab_打"]); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons["三球走位"]; revealEntry(entry); ready(entry); entry.tap(); phase("aiming")
        ready(app.buttons["threeBall.retry"]); app.buttons["threeBall.retry"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["stage"] as? Int, 0)
        XCTAssertEqual(try probe()["onTableKeys"] as? [String], originalKeys)
        XCTAssertEqual(try probe()["plannedPocket"] as? Int, 5)

        if is3D { app.buttons["dailyClearance.observeTable"].tap() }
        try selectPocket(4); XCTAssertEqual(try probe()["plannedPocket"] as? Int, 4)
        try selectPocket(5)
        app.buttons["threeBall.strike"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["stage"] as? Int, 1)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["question"] as? String, question)
        let first = try XCTUnwrap(probe()["firstScore"] as? Double)
        ready(app.buttons["threeBall.strike"])
        app.buttons["threeBall.strike"].tap()
        XCTAssertTrue(node("threeBall.question").waitForExistence(timeout: 2))
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        if is3D { app.buttons["dailyClearance.observeTable"].tap() }
        try selectPocket(1)
        XCTAssertFalse(app.buttons["threeBall.playback"].exists)
        XCTAssertTrue(app.buttons["threeBall.geometry"].exists)
        XCTAssertEqual(try probe()["stage"] as? Int, 1)
        XCTAssertEqual(try probe()["plannedPocket"] as? Int, 1)
        XCUIDevice.shared.press(.home); app.activate(); phase("aiming")
        XCTAssertEqual(try probe()["plannedPocket"] as? Int, 1)
        capture("threeBall-second-plan-\(is3D)")
        app.buttons["threeBall.strike"].tap(); phase("result")
        let second = try XCTUnwrap(probe()["score"] as? Double)
        XCTAssertEqual(try XCTUnwrap(probe()["average"] as? Double), (first + second)/2, accuracy: 0.0001)
        XCTAssertEqual(try probe()["quota"] as? Int, quota)
        XCTAssertEqual(try probe()["attempts"] as? Int, 2)
        capture("threeBall-final-\(is3D)")
        app.buttons["threeBall.retry"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["stage"] as? Int, 1)
        if is3D { app.buttons["dailyClearance.observeTable"].tap() }
        try selectPocket(2); XCTAssertEqual(try probe()["plannedPocket"] as? Int, 2)
        app.buttons["threeBall.strike"].tap(); phase("result")
        XCTAssertEqual(try probe()["attempts"] as? Int, 2)
        app.buttons["threeBall.strike"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["stage"] as? Int, 0); XCTAssertEqual(try probe()["plannedPocket"] as? Int, -1)
        app.terminate()
    }
    func testSettingsCancelAndAdaptiveStates() throws {
        try open(false, animated: true, largeText: true)
        try selectPocket(5)
        let question = try probe()["question"] as? String
        let pocket = try probe()["plannedPocket"] as? Int
        if UIDeviceIsPad {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                    let f = self.app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height > f.width : f.width > f.height
                }, object: nil)], timeout: 10), .completed)
                ready(app.buttons["threeBall.strike"])
                capture("threeBall-pad-rotation-\(orientation.rawValue)")
                XCTAssertEqual(try probe()["question"] as? String, question)
            }
            let full = app.windows.firstMatch.frame
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width-7, dy: full.height-7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width*0.7, dy: full.height*0.78)))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                let f = self.app.windows.firstMatch.frame
                return f.width < full.width-80 || f.height < full.height-80
            }, object: nil)], timeout: 10), .completed)
            ready(app.buttons["threeBall.strike"]); capture("threeBall-pad-small-window")
            XCTAssertEqual(try probe()["question"] as? String, question)
            let window = app.windows.firstMatch, small = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width-small.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in
                abs(self.app.windows.firstMatch.frame.width-full.width) < 1
            }, object: nil)], timeout: 10), .completed)
            ready(app.buttons["threeBall.strike"]); capture("threeBall-pad-restored-window")
            XCTAssertEqual(try probe()["plannedPocket"] as? Int, pocket)
        }
        app.buttons["threeBall.more"].tap()
        for _ in 0..<5 where !app.buttons["threeBall.trainingSettings"].isHittable {
            app.scrollViews["dailyClearance.menuScroll"].swipeUp()
        }
        ready(app.buttons["threeBall.trainingSettings"])
        app.buttons["threeBall.trainingSettings"].tap(); ready(app.buttons["threeBall.start"])
        capture("threeBall-settings-reopen")
        app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["plannedPocket"] as? Int, pocket)
        app.buttons["threeBall.more"].tap()
        let layout = app.buttons["controlLayout.open"]
        for _ in 0..<5 where !layout.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(layout); layout.tap()
        let strikeControl = app.buttons["freeLayout.select.shot.strike"]
        ready(strikeControl); let original = strikeControl.frame
        strikeControl.tap(); app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(strikeControl.frame.width, original.width)
        capture("threeBall-layout-draft")
        app.buttons["freeLayout.cancel"].tap()
        ready(app.buttons["threeBall.strike"])
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["plannedPocket"] as? Int, pocket)
        ready(app.buttons["shotStage.spinEntry"]); app.buttons["shotStage.spinEntry"].tap()
        ready(node("spinPad.disc")); capture("threeBall-spin-expanded")
        app.buttons["关闭打点"].coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.5)).tap()
        app.buttons["threeBall.strike"].tap(); phase("aiming"); XCTAssertEqual(try probe()["stage"] as? Int, 1); capture("threeBall-animated-continuation")
        app.terminate()
    }
    private var UIDeviceIsPad: Bool { min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) >= 600 }
}
