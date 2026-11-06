import XCTest

final class DefensePracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { app?.terminate(); XCUIDevice.shared.orientation = .portrait }
    private func node(_ id: String) -> XCUIElement {
        if id == "defense.mode" { return app.segmentedControls[id] }
        if id.hasPrefix("defense.kind.") || id.hasPrefix("defense.tactic.") ||
            ["defense.cameraMode", "defense.dismissMenu", "defense.trainingSettings", "defense.referenceReplay", "defense.finish", "defense.scoreDetail"].contains(id) {
            return app.buttons[id]
        }
        return app.descendants(matching:.any).matching(identifier:id).firstMatch
    }
    private func ready(_ e: XCUIElement) {
        let result = XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND enabled == true AND hittable == true"),object:e)],timeout:90)
        // Keep diagnostics lightweight: iOS 17's injected XCTest logger crashed
        // in its high-volume log callback during repeated broad AX queries.
        XCTAssertEqual(result, .completed, "Expected an enabled, hittable control")
    }
    private func probe() -> [String:Any] {
        guard node("defense.probe").exists, let s=node("defense.probe").value as? String,let d=s.data(using:.utf8),let p=try? JSONSerialization.jsonObject(with:d) as? [String:Any] else { return [:] }
        return p
    }
    private func phase(_ value: String) {
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in self.probe()["phase"] as? String == value },object:app)],timeout:120),.completed,"expected \(value): \(probe())")
    }
    private func capture(_ name: String) {
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
    }
    private func setView(_ value: String) {
        app.buttons["defense.more"].tap()
        let row=node("defense.cameraMode");ready(row)
        XCTAssertTrue(["2D","3D"].contains(row.value as? String ?? ""))
        if row.value as? String != value { row.tap() }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@",value),object:row)],timeout:15),.completed)
        node("defense.dismissMenu").tap();ready(app.buttons["defense.strike"])
    }
    private func open(free:Bool, animated:Bool = false) {
        app=XCUIApplication.launchClean(extraArgs:["-v50.inMemoryStore","-forcePremium","-freeLayout.ephemeral","-defense.probe","-defense.fixedSeed","-pro.route=defensePractice"])
        ready(app.buttons["defense.start"])
        let reset=app.buttons["training.resetDefaults"]
        for _ in 0..<6 { if reset.isHittable { break }; app.swipeUp() }
        if reset.isHittable {
            reset.tap()
            // Reset can expand the trajectory-only section. Wait for that transaction
            // to settle before asking the virtualized Form for its top row.
            let notice = app.staticTexts["已恢复默认设置"]
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: notice)], timeout: 10), .completed)
        }
        let mode=node("defense.mode")
        for _ in 0..<6 { if mode.isHittable { break }; app.swipeDown() }
        ready(mode);mode.buttons[free ? "自由模式":"轨迹模式"].tap()
        capture("defense-settings-top")
        let toggle=app.switches["defense.playsStroke"]
        for _ in 0..<7 { if toggle.isHittable { break }; app.swipeUp() }
        ready(toggle)
        if (toggle.value as? String == "1") != animated { toggle.coordinate(withNormalizedOffset:.init(dx:1,dy:0.5)).withOffset(.init(dx:-25,dy:0)).tap() }
        XCTAssertFalse(app.buttons["defense.tactic.all"].exists)
        XCTAssertFalse(app.staticTexts["防守方式"].exists)
        capture("defense-settings-bottom")
        app.buttons["defense.start"].tap();phase("aiming");ready(app.buttons["defense.strike"])
        setView("2D")
    }
    func testFreeModeResultRetryNextAndSettingsCancel() {
        open(free:true)
        let question=probe()["question"] as? String
        XCTAssertEqual(probe()["referenceVisible"] as? Bool,false)
        ready(node("defense.aimWheel"));capture("defense-free-aiming")
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertTrue(node("defense.scores").exists);XCTAssertFalse(node("defense.aimWheel").exists)
        capture("defense-free-result")
        XCTAssertFalse(app.buttons["defense.scoreDetail"].exists)
        XCTAssertFalse(node("defense.targetLegend").exists)
        ready(app.buttons["defense.retry"]);app.buttons["defense.retry"].tap();phase("aiming")
        XCTAssertEqual(probe()["question"] as? String,question)
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertEqual(probe()["attempts"] as? Int,1)
        app.buttons["defense.strike"].tap();phase("aiming")
        XCTAssertNotEqual(probe()["question"] as? String,question)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool,false)
        capture("defense-free-next")
        app.buttons["defense.more"].tap()
        let settings=node("defense.trainingSettings")
        for _ in 0..<6 { if settings.isHittable { break }; app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(settings);settings.tap();ready(app.buttons["training.settingsCancel"])
        let next=probe()["question"] as? String
        app.buttons["training.settingsCancel"].tap();phase("aiming")
        if let next { XCTAssertEqual(probe()["question"] as? String,next) }
        app.buttons["defense.more"].tap()
        XCTAssertFalse(node("defense.finish").exists)
        XCTAssertFalse(node("defense.referenceReplay").exists)
        XCTAssertFalse(node("defense.scoreDetail").exists)
        node("defense.dismissMenu").tap()
    }
    func testAnimatedShotAndReplayPreserveAnswer() {
        open(free:true, animated:true)
        app.buttons["defense.strike"].tap();phase("playing");capture("defense-animated-shot")
        phase("result");let original=probe()["question"] as? String
        app.buttons["defense.replay"].tap();phase("playing");capture("defense-replay")
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertEqual(probe()["attempts"] as? Int,1);XCTAssertEqual(probe()["question"] as? String,original)
        app.buttons["defense.retry"].tap();phase("aiming");ready(node("defense.aimWheel"))
    }
    func testFreeRoutesIn3D() {
        open(free:true)
        setView("3D")
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool, false)
        capture("defense-free-3D-result")
        app.buttons["defense.replay"].tap();phase("playing")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        capture("defense-free-3D-replay")
        app.buttons["defense.strike"].tap();phase("result")
        app.buttons["defense.retry"].tap();phase("aiming")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        capture("defense-free-3D-retry")
    }
    func testSavedMeasurementPositionCarriesOverToDemonstration() {
        open(free: false)
        let measure = app.buttons["defense.geometry"]
        let original = measure.frame
        app.buttons["defense.more"].tap()
        let edit = app.buttons["controlLayout.open"]
        for _ in 0..<4 where !edit.isHittable { app.swipeUp() }
        ready(edit); edit.tap()
        let collapse = app.buttons["freeLayout.collapse"]
        ready(collapse); collapse.tap()
        let item = node("freeLayout.select.shot.replay")
        ready(item)
        let center = item.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.12, thenDragTo: center.withOffset(.init(dx: 90, dy: -24)))
        collapse.tap()
        app.buttons["freeLayout.save"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        if let text = field.value as? String, text.isEmpty || text == "模板名称" {
            field.tap(); field.typeText("示范布局")
        }
        alert.buttons["保存"].tap()
        ready(measure)
        let moved = measure.frame
        XCTAssertGreaterThan(moved.midX - original.midX, 55)
        let demo = app.buttons["defense.referenceReplay"]
        for _ in 0..<3 {
            app.buttons["defense.strike"].tap(); phase("result")
            if demo.exists { break }
            app.buttons["defense.retry"].tap(); phase("aiming")
        }
        ready(demo)
        XCTAssertEqual(demo.frame.midX, moved.midX, accuracy: 1)
        XCTAssertEqual(demo.frame.midY, moved.midY, accuracy: 1)
        // Accessibility reports the bounds rounded to the device pixel grid.
        XCTAssertEqual(demo.frame.width, moved.width, accuracy: 0.5)
        XCTAssertEqual(demo.frame.height, moved.height, accuracy: 0.5)
        capture("defense-custom-layout-demo")
        demo.tap(); phase("playing")
        app.buttons["defense.strike"].tap(); phase("result")
        app.buttons["defense.retry"].tap(); phase("aiming")
        XCTAssertEqual(measure.frame.midX, moved.midX, accuracy: 1)
        XCTAssertEqual(measure.frame.midY, moved.midY, accuracy: 1)
    }

    func testTrajectoryModeAndAdaptiveViews() {
        open(free:false)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool,true)
        XCTAssertFalse(node("defense.referenceLegend").exists)
        let orientations:[UIDeviceOrientation]=UIDevice.current.userInterfaceIdiom == .pad ? [.portrait,.landscapeLeft] : [.landscapeLeft]
        for mode in ["2D","3D"] {
            setView(mode)
            for orientation in orientations {
                XCUIDevice.shared.orientation=orientation;ready(app.buttons["defense.strike"])
                XCTAssertTrue(app.frame.contains(app.buttons["defense.strike"].frame));capture("defense-\(mode)-trajectory-\(orientation.rawValue)")
            }
        }
        app.buttons["defense.more"].tap();capture("defense-menu")
        node("defense.dismissMenu").tap()
        ready(app.buttons["defense.strike"]);capture("defense-3D-aiming")
        XCTAssertFalse(node("defense.referenceReplay").exists)
        let measuringSlot = node("defense.geometry").frame
        app.buttons["defense.strike"].tap();phase("result");capture("defense-trajectory-result")
        XCTAssertTrue(node("defense.scores").exists)
        let original=probe()["question"] as? String, score=probe()["score"] as? Double
        XCTAssertTrue(node("defense.targetLegend").exists)
        XCTAssertTrue(node("defense.actualLegend").exists)
        let reference=node("defense.referenceReplay")
        for _ in 0..<2 where !reference.exists {
            app.buttons["defense.retry"].tap(); phase("aiming")
            app.buttons["defense.strike"].tap(); phase("result")
        }
        ready(reference)
        let player = probe()["playerInput"] as? [Double]
        let expected = probe()["referenceInput"] as? [Double]
        XCTAssertEqual(player?.count, 3); XCTAssertEqual(expected?.count, 3)
        XCTAssertNotEqual(player, expected)
        XCTAssertFalse(app.buttons["defense.replay"].exists)
        XCTAssertFalse(reference.frame.intersects(app.buttons["defense.retry"].frame))
        XCTAssertEqual(reference.frame.midX, measuringSlot.midX, accuracy: 1)
        XCTAssertEqual(reference.frame.midY, measuringSlot.midY, accuracy: 1)
        reference.tap();phase("playing")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool, true)
        capture("defense-reference-replay")
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertEqual(probe()["attempts"] as? Int,1);XCTAssertEqual(probe()["question"] as? String,original)
        XCTAssertEqual(probe()["score"] as? Double,score)
        for mode in ["2D", "3D"] {
            // Result keeps layout/view controls locked. Switch through the supported
            // retry state, and verify that state never revives the previous route.
            app.buttons["defense.retry"].tap(); phase("aiming")
            XCTAssertEqual(probe()["actualVisible"] as? Bool, false)
            setView(mode)
            XCTAssertEqual(probe()["actualVisible"] as? Bool, false)
            app.buttons["defense.strike"].tap(); phase("result")
            for orientation in orientations {
                XCUIDevice.shared.orientation = orientation
                ready(node("defense.referenceReplay"))
                XCTAssertFalse(node("defense.referenceReplay").frame.intersects(app.buttons["defense.retry"].frame))
                XCTAssertTrue(app.frame.contains(node("defense.referenceReplay").frame))
                capture("defense-\(mode)-result-\(orientation.rawValue)")
            }
        }
        let replayScore = probe()["score"] as? Double
        node("defense.referenceReplay").tap(); phase("playing")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool, true)
        phase("result")
        XCTAssertEqual(probe()["question"] as? String, original)
        let shown = probe()["instrument"] as? [Double]
        guard let expected, let shown, shown.count == 3 else { return XCTFail("Missing instrument readout") }
        for (a, b) in zip(shown, expected) { XCTAssertEqual(a, b, accuracy: 0.00001) }
        let spin = app.buttons["shotStage.spinEntry"]
        ready(spin); spin.tap()
        XCTAssertTrue(node("defense.spinPad").waitForExistence(timeout: 5))
        capture("defense-demonstration-read-only-tip")
        app.coordinate(withNormalizedOffset: .init(dx: 0.18, dy: 0.38)).tap()
        XCTAssertEqual(probe()["score"] as? Double, replayScore)
        XCTAssertEqual(probe()["attempts"] as? Int, 1)
        app.buttons["defense.retry"].tap();phase("aiming")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, false)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool, true)
        XCTAssertEqual(probe()["instrument"] as? [Double], player)
        capture("defense-retry-cleared")
        setView("2D")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, false)
        app.buttons["defense.strike"].tap();phase("result")
        app.buttons["defense.strike"].tap();phase("aiming")
        XCTAssertTrue(node("defense.aimWheel").exists)
    }
    func testAlternateDefenseDemoKeepsQuestionScoreAndPlayerRoutes() {
        open(free: false)
        for _ in 0..<3 {
            app.buttons["defense.strike"].tap(); phase("result")
            if node("defense.referenceReplay").exists { break }
            app.buttons["defense.retry"].tap(); phase("aiming")
        }
        ready(node("defense.referenceReplay"))
        let before = probe()
        app.buttons["defense.more"].tap()
        let row = app.buttons["defense.moreRoutes"]
        for _ in 0..<5 where !row.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(row); row.tap()
        let choice = app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@", "线路 ")).firstMatch
        ready(choice); capture("defense-alternate-choices"); choice.tap()
        phase("playing")
        XCTAssertEqual(probe()["actualVisible"] as? Bool, true)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool, true)
        phase("result")
        XCTAssertEqual(probe()["question"] as? String, before["question"] as? String)
        XCTAssertEqual(probe()["attempts"] as? Int, 1)
        XCTAssertEqual(probe()["score"] as? Double, before["score"] as? Double)
    }

    func testUnfilteredTrajectoryBankStartsTraining() {
        open(free:false)
        XCTAssertEqual(probe()["referenceVisible"] as? Bool,true)
        XCTAssertFalse(node("defense.referenceLegend").exists)
        capture("defense-full-bank-opponent-pot")
        app.buttons["defense.strike"].tap();phase("result")
        XCTAssertTrue(node("defense.scores").exists)
        app.buttons["defense.strike"].tap();phase("aiming")
        XCTAssertEqual(probe()["referenceVisible"] as? Bool,true)
    }

    func testExpandedSelectionsAndCancelPreserveQuestion() {
        open(free:false)
        let original = probe()["question"] as? String
        func settings() {
            app.buttons["defense.more"].tap()
            let entry = node("defense.trainingSettings")
            for _ in 0..<6 { if entry.isHittable { break }; app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(entry); entry.tap(); ready(app.buttons["training.settingsCancel"])
        }
        func reveal(_ id: String) -> XCUIElement {
            let item = node(id)
            for _ in 0..<8 { if item.isHittable { break }; app.swipeUp() }
            ready(item); return item
        }
        settings()
        let kind = reveal("defense.kind.one")
        kind.tap(); XCTAssertEqual(kind.value as? String, "已选")
        XCTAssertEqual(node("defense.kind.all").value as? String, "未选")
        capture("defense-expanded-ball-selection")
        XCTAssertFalse(app.buttons["defense.tactic.all"].exists)
        XCTAssertFalse(app.staticTexts["防守方式"].exists)
        _ = reveal("defense.playsStroke")
        capture("defense-settings-without-tactics")
        app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(probe()["question"] as? String, original)
        settings()
        XCTAssertEqual(reveal("defense.kind.all").value as? String, "已选", "Cancelled kind must not persist")
        XCTAssertFalse(app.buttons["defense.tactic.all"].exists)
        app.buttons["training.settingsCancel"].tap(); phase("aiming")
        XCTAssertEqual(probe()["question"] as? String, original)
    }
}

extension XCTestCase {
    /// Exercise the same physical action slot on each host, including both sides of a retry.
    func verifyPracticeDemonstration(in app: XCUIApplication, page: String,
                                     phase: (String) -> Void, probe: () throws -> [String: Any]) throws {
        let strike = app.buttons[page + ".strike"], retry = app.buttons[page + ".retry"]
        let measure = app.buttons[page + ".geometry"], demo = app.buttons[page + ".referenceReplay"]
        XCTAssertTrue(measure.exists)
        XCTAssertFalse(demo.exists)
        let slot = measure.frame
        for attempt in 1...3 {
            strike.tap()
            phase("result")
            if demo.exists { break }
            XCTAssertLessThan(attempt, 3)
            XCTAssertTrue(measure.exists)
            XCTAssertFalse(measure.isEnabled)
            XCTAssertEqual(measure.frame.midX, slot.midX, accuracy: 1)
            XCTAssertEqual(measure.frame.midY, slot.midY, accuracy: 1)
            if attempt == 1 {
                let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                image.name = page + "-measurement-locked"
                image.lifetime = .keepAlways
                add(image)
            }
            retry.tap(); phase("aiming")
            XCTAssertTrue(measure.isEnabled)
        }
        XCTAssertTrue(demo.isHittable)
        XCTAssertFalse(measure.exists)
        XCTAssertEqual(demo.frame.midX, slot.midX, accuracy: 1)
        XCTAssertEqual(demo.frame.midY, slot.midY, accuracy: 1)
        let before = try probe(), player = try XCTUnwrap(before["playerInput"] as? [Double])
        demo.tap()
        phase("result")
        let displayed = try probe()
        XCTAssertEqual(displayed["demoShowing"] as? Bool, true, "\(displayed) \(app.alerts.firstMatch.exists ? app.alerts.firstMatch.debugDescription : String())")
        XCTAssertEqual(displayed["instrument"] as? [Double], before["referenceInput"] as? [Double])
        XCTAssertEqual(displayed["playerInput"] as? [Double], player)
        XCTAssertEqual(displayed["question"] as? String, before["question"] as? String)
        XCTAssertEqual(displayed["attempts"] as? Int, before["attempts"] as? Int)
        let mini = app.buttons["shotStage.spinEntry"]
        XCTAssertTrue(mini.isEnabled); mini.tap()
        let pad = app.descendants(matching: .any).matching(identifier: page + ".spinPad").firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = page + "-demonstration-tip"; attachment.lifetime = .keepAlways; add(attachment)
        app.coordinate(withNormalizedOffset: .init(dx: 0.18, dy: 0.38)).tap()
        retry.tap(); phase("aiming")
        XCTAssertFalse(demo.exists)
        XCTAssertTrue(measure.isHittable)
        XCTAssertEqual(try probe()["instrument"] as? [Double], player)
        measure.tap()
        let off = app.buttons[page + ".geometry.0"]
        XCTAssertTrue(off.waitForExistence(timeout: 5)); off.tap()
        app.buttons[page + ".more"].tap()
        let camera = app.buttons[page + ".cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 5))
        let originalView = try XCTUnwrap(camera.value as? String)
        camera.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", originalView), object: camera)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        let dismiss = app.buttons[page + ".dismissMenu"]
        if dismiss.exists { dismiss.tap() }
        strike.tap(); phase("result")
        demo.tap(); phase("result")
        XCTAssertEqual(try probe()["demoShowing"] as? Bool, true)
        XCTAssertEqual(try probe()["playerInput"] as? [Double], player)

    }
}
