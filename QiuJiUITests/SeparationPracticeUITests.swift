import XCTest

final class SeparationPracticeUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() { continueAfterFailure = false }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 90) {
        if app.buttons["separation.start"].exists {
            for _ in 0..<16 {
                let top = app.navigationBars.firstMatch.frame.maxY + 4
                if element.exists && element.isHittable && (element.frame.minY >= top || app.navigationBars.firstMatch.frame.contains(element.frame)) { break }
                let up = !element.exists || element.frame.minY >= top
                app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: up ? 0.72 : 0.42))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: up ? 0.42 : 0.72)))
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)],
            timeout: timeout), .completed, element.debugDescription)
    }
    private func capture(_ name: String) {
        let screen = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: screen); a.name = name; a.lifetime = .keepAlways; add(a)
        if let path = ProcessInfo.processInfo.environment["V52_SHOT_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V52_SHOT_DIR"] {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                try screen.pngRepresentation.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
            } catch { XCTFail("Screenshot export: \(error)") }
        }
    }
    private func node(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func probe() throws -> [String: Any] {
        let value = try XCTUnwrap(node("separation.probe").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    }
    private func waitPhase(_ phase: String, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["phase"] as? String) == phase
        }, object: app)], timeout: timeout), .completed)
    }
    private func open(_ is3D: Bool, premium: Bool = true, nearLimit: Bool = false, largeText: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        var args = ["-v50.inMemoryStore", "-freeLayout.ephemeral", "-separation.probe", "-separation.fixedSeed", "-3dDrag.probe",
                    "-shotAudio.probe", "-soundEffectsEnabled", "YES"]
        if premium { args.append("-forcePremium") }
        if nearLimit { args.append("-w7.forceDailyLimitNear") }
        args += ["-AppleInterfaceStyle", largeText ? "Light" : "Dark"]
        if largeText { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app = XCUIApplication.launchClean(extraArgs: args)
        app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
        let entry = app.buttons[is3D ? "3D分离角" : "2D分离角"]
        ready(entry); capture("play-entries"); entry.tap()
    }
    private func start() {
        ready(app.buttons["separation.start"])
        capture("separation-settings")
        app.buttons["separation.start"].tap()
        ready(app.buttons["separation.strike"], timeout: 180)
        waitPhase("aiming")
    }

    func testGeometryReference2D() throws { try geometryReference(false) }
    func testGeometryReference3D() throws { try geometryReference(true) }
    private func geometryReference(_ is3D: Bool) throws {
        open(is3D)
        let toggle = app.switches["separation.playsStroke"]; ready(toggle)
        if toggle.value as? String == "1" { toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap() }
        start()
        func geometry() throws -> [String: Any] { try XCTUnwrap(probe()["geometry"] as? [String: Any]) }
        let menu = app.buttons["separation.geometry"]; ready(menu); menu.tap()
        let option = app.buttons["separation.geometry.3"]; ready(option); option.tap()
        XCTAssertEqual(try geometry()["visible"] as? Bool, true)
        let first = try XCTUnwrap(geometry()["first"] as? [Double])
        capture("separation-geometry-\(is3D)")
        app.buttons["separation.strike"].tap(); waitPhase("result")
        XCTAssertEqual(try geometry()["visible"] as? Bool, false)
        app.buttons["separation.retry"].tap(); waitPhase("aiming")
        XCTAssertEqual(try geometry()["first"] as? [Double], first)
        XCTAssertEqual(try geometry()["visible"] as? Bool, true)
        app.buttons["separation.strike"].tap(); waitPhase("result")
        app.buttons["separation.strike"].tap(); waitPhase("aiming")
        XCTAssertEqual(try geometry()["count"] as? Int, 0)
        app.terminate()
    }

    func test2DResultNoticeExpires() throws { try resultNoticeExpires(is3D: false) }
    func test3DResultNoticeExpires() throws { try resultNoticeExpires(is3D: true) }
    private func resultNoticeExpires(is3D: Bool) throws {
        open(is3D)
        let toggle = app.switches["separation.playsStroke"]; ready(toggle)
        if toggle.value as? String == "1" { toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap() }
        start()
        app.buttons["separation.strike"].tap(); waitPhase("result")
        let notice = node("separation.result")
        XCTAssertTrue(notice.label.contains("本杆") || notice.label == "0分，无法进指定袋，请重打")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture("score-visible-\(is3D)")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(node("separation.latestScore").label.contains("本杆得分"))
        capture("score-expired-\(is3D)")
        app.buttons["separation.retry"].tap(); waitPhase("aiming")
        XCTAssertTrue(notice.label.contains("上杆") || notice.label == "0分，无法进指定袋，请重打")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertTrue(node("separation.latestScore").label.contains("上杆得分"))
        capture("previous-expired-\(is3D)")
        app.buttons["separation.strike"].tap(); waitPhase("result")
        XCTAssertTrue(notice.label.contains("本杆") || notice.label == "0分，无法进指定袋，请重打")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
    }
    func test2DFeasibleSpinPad() throws { try exerciseFeasibleSpinPad(is3D: false) }
    func test3DFeasibleSpinPad() throws { try exerciseFeasibleSpinPad(is3D: true) }
    private func exerciseFeasibleSpinPad(is3D: Bool) throws {
        open(is3D)
        let toggle = app.switches["separation.playsStroke"]; ready(toggle)
        if toggle.value as? String == "1" { toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap() }
        start()
        func checkAccess() throws {
            XCTAssertEqual(try probe()["inputAccessible"] as? Bool, true)
        }
        func showPad() {
            let entry = app.buttons["shotStage.spinEntry"]; ready(entry); entry.tap()
            ready(node("spinPad.disc"))
        }
        func closePad() {
            app.buttons["关闭打点"].coordinate(withNormalizedOffset: .init(dx: 0.05, dy: 0.5)).tap()
        }
        showPad()
        let disc = node("spinPad.disc")
        disc.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.97)).tap()
        try checkAccess()
        capture("separation-access-low-\(is3D)")
        for label in ["低杆增加 1%", "左塞增加 1%", "右塞增加 1%", "高杆增加 1%", "回中"] {
            app.buttons[label].tap(); try checkAccess()
        }
        capture("separation-access-reset-\(is3D)"); closePad()
        app.buttons["separation.strike"].tap(); waitPhase("result")
        app.buttons["separation.retry"].tap(); waitPhase("aiming"); try checkAccess()
        let input = try probe()["input"] as? [Double]
        let question = try probe()["question"] as? String
        app.buttons["separation.geometry"].tap()
        app.buttons["separation.geometry.1"].tap(); try checkAccess()
        XCUIDevice.shared.press(.home); app.activate(); waitPhase("aiming")
        app.buttons["separation.back"].tap()
        let entry = app.buttons[is3D ? "3D分离角" : "2D分离角"]; ready(entry); entry.tap()
        ready(app.buttons["separation.strike"]); waitPhase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["input"] as? [Double], input)
        try checkAccess(); showPad(); capture("separation-access-restored-\(is3D)"); closePad()
        app.buttons["separation.strike"].tap(); waitPhase("result")
        app.buttons["separation.strike"].tap(); waitPhase("aiming")
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        showPad(); app.buttons["回中"].tap(); try checkAccess()
        capture("separation-access-next-\(is3D)"); closePad()
        app.buttons["separation.back"].tap()
    }
    func test2DPrefetchedNextAndExitRestoration() throws { try exercisePrefetch(is3D: false) }
    func test3DPrefetchedNextAndExitRestoration() throws { try exercisePrefetch(is3D: true) }
    private func exercisePrefetch(is3D: Bool) throws {
        open(is3D)
        let toggle = app.switches["separation.playsStroke"]; ready(toggle)
        if toggle.value as? String == "1" { toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap() }
        start()
        func waitReady() {
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (try? self.probe()["nextQuestionReady"] as? Bool) == true
            }, object: app)], timeout: 90), .completed)
        }
        waitReady()
        let first = try probe()["question"] as? String
        XCTAssertEqual(try probe()["attempts"] as? Int, 0)
        app.buttons["separation.strike"].tap(); waitPhase("result")
        waitReady()
        let quota = try probe()["quota"] as? Int
        app.buttons["separation.strike"].tap(); waitPhase("aiming")
        let second = try probe()["question"] as? String
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        XCTAssertEqual(try probe()["quota"] as? Int, quota)
        capture("prefetched-next-\(is3D ? "3D" : "2D")")
        waitReady()
        app.buttons["separation.back"].tap(); ready(app.buttons["angleHomeTab_打"])
        app.buttons[is3D ? "3D分离角" : "2D分离角"].tap()
        ready(app.buttons["separation.strike"]); waitPhase("aiming")
        XCTAssertEqual(try probe()["question"] as? String, second)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        waitReady()
        capture("prefetch-restored-\(is3D ? "3D" : "2D")")
        app.buttons["separation.back"].tap()
    }
    private func waitReference(_ visible: Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["referenceVisible"] as? Bool) == visible
        }, object: app)], timeout: 30), .completed)
        XCTAssertEqual(node("separation.referenceLegend").exists, visible)
    }
    func test2DReferenceStageVisibility() throws { try exerciseReferenceStages(is3D: false) }
    func test3DReferenceStageVisibility() throws { try exerciseReferenceStages(is3D: true) }
    private func exerciseReferenceStages(is3D: Bool) throws {
        for keep in [false, true] {
            open(is3D)
            let reference = app.switches["separation.showsReference"]
            let stroke = app.switches["separation.playsStroke"]
            ready(reference); ready(stroke)
            XCTAssertEqual(reference.label, "提交后保留中杆参考")
            if (reference.value as? String == "1") != keep {
                reference.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
            }
            if stroke.value as? String == "1" { stroke.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap() }
            XCTAssertEqual(reference.value as? String, keep ? "1" : "0")
            XCTAssertEqual(stroke.value as? String, "0")
            capture("stages-\(is3D)-\(keep)-settings")
            start(); waitReference(true)
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
            capture("stages-\(is3D)-\(keep)-first")
            let primary = app.buttons["separation.strike"]
            primary.tap(); waitPhase("result"); waitReference(keep)
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
            capture("stages-\(is3D)-\(keep)-result")
            // The independent geometry tool must preserve the physical reference policy.
            XCTAssertFalse(app.buttons["separation.geometry"].isEnabled)
            waitReference(keep)
            app.buttons["separation.retry"].tap(); waitPhase("aiming")
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, true); waitReference(keep)
            capture("stages-\(is3D)-\(keep)-retry")
            app.buttons["separation.geometry"].tap(); app.buttons["separation.geometry.1"].tap()
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, true); waitReference(keep)
            XCUIDevice.shared.press(.home); app.activate(); waitPhase("aiming")
            let id = try probe()["question"] as? String
            app.buttons["separation.back"].tap()
            let entry = app.buttons[is3D ? "3D分离角" : "2D分离角"]
            ready(entry); entry.tap(); ready(primary); waitPhase("aiming"); waitReference(keep)
            XCTAssertEqual(try probe()["question"] as? String, id)
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
            capture("stages-\(is3D)-\(keep)-restored-retry")
            primary.tap(); waitPhase("result"); waitReference(keep)
            XCTAssertEqual(try probe()["attempts"] as? Int, 1)
            app.buttons["separation.back"].tap(); ready(entry); entry.tap(); ready(primary)
            waitPhase("result"); waitReference(keep)
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
            capture("stages-\(is3D)-\(keep)-restored-result")
            primary.tap(); waitPhase("aiming"); waitReference(true)
            XCTAssertNotEqual(try probe()["question"] as? String, id)
            XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
            capture("stages-\(is3D)-\(keep)-next")
            app.buttons["separation.back"].tap(); app.terminate()
        }
    }
    func test2DCompleteShotRetryReplayAndSummary() throws { try exercise(is3D: false) }
    func test3DCompleteShotRetryReplayAndSummary() throws { try exercise(is3D: true) }
    func test2DTrajectoryOnlySubmission() throws { try exerciseSubmission(is3D: false) }
    func test3DTrajectoryOnlySubmission() throws { try exerciseSubmission(is3D: true) }
    private func exerciseSubmission(is3D: Bool) throws {
        open(is3D)
        let toggle = app.switches["separation.playsStroke"]
        ready(toggle)
        let reference = app.switches["separation.showsReference"]
        ready(reference)
        if reference.value as? String == "0" {
            reference.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        }
        XCTAssertEqual(reference.label, "提交后保留中杆参考")
        XCTAssertLessThan(toggle.frame.minY, reference.frame.minY)
        // Shared simulator preferences survive launchClean and a failed previous run.
        // Fresh-install default is covered with an isolated UserDefaults suite in the unit test.
        if toggle.value as? String == "0" {
            toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertLessThan(node("training.length").frame.minY, node("separation.shotSettingsHeader").frame.minY)
        XCTAssertLessThan(node("separation.shotSettingsHeader").frame.minY, toggle.frame.minY)
        XCTAssertTrue(node("separation.aimCompensationNote").exists)
        XCTAssertGreaterThanOrEqual(node("separation.aimCompensationNote").frame.minY, reference.frame.maxY)
        capture("submit-\(is3D ? "3D" : "2D")-entry-setting-default")
        toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        capture("submit-\(is3D ? "3D" : "2D")-entry-setting-off")
        start()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["referenceReady"] as? Bool) == true
        }, object: app)], timeout: 30), .completed)
        let initial = try probe()
        XCTAssertEqual(initial["referenceVisible"] as? Bool, true)
        XCTAssertTrue(node("separation.referenceLegend").label.contains("参考"))
        XCTAssertFalse(node("separation.cutAngle").label.contains("球"))
        capture("reference-\(is3D ? "3D" : "2D")-aiming")
        XCTAssertTrue(node("separation.cutAngle").label.contains("切角"))
        XCTAssertTrue(node("separation.questionAverageScore").exists)
        XCTAssertFalse(node("separation.result").exists)
        XCTAssertEqual(initial["playsStroke"] as? Bool, false)
        XCTAssertEqual(app.buttons["separation.retry"].label, "重试")
        XCTAssertEqual(app.buttons["separation.geometry"].label, "几何参考")
        app.buttons["separation.more"].tap()
        XCTAssertFalse(node("separation.playsStroke").exists)
        capture("submit-menu-without-stroke-option")
        app.buttons["separation.dismissMenu"].tap()
        let submit = app.buttons["separation.strike"]
        XCTAssertEqual(submit.label, "提交")
        submit.tap(); waitPhase("result")
        let result = try probe()
        XCTAssertEqual(result["scoreVersion"] as? String, "arc1cm-rms-p2-t20-potgate-v3")
        XCTAssertEqual(result["referenceVisible"] as? Bool, true)
        XCTAssertEqual(result["referencePointCount"] as? Int, initial["referencePointCount"] as? Int)
        XCTAssertEqual(result["objectRouteVisible"] as? Bool, true)
        XCTAssertEqual(result["idealPocketLineVisible"] as? Bool, false)
        XCTAssertTrue(node("separation.result").label.contains("本杆"))
        XCTAssertTrue(node("separation.latestScore").exists)
        XCTAssertFalse(node("separation.result").label.contains("本题均分"))
        XCTAssertTrue(node("separation.result").isHittable)
        XCTAssertEqual(result["actualVisible"] as? Bool, true)
        XCTAssertEqual(result["targetVisible"] as? Bool, true)
        XCTAssertEqual(result["cuePosition"] as? [Double], initial["cuePosition"] as? [Double])
        XCTAssertEqual(result["targetPosition"] as? [Double], initial["targetPosition"] as? [Double])
        XCTAssertEqual(result["strokeStartedAt"] as? Double, 0)
        XCTAssertEqual(result["revealedAt"] as? Double, 0)
        XCTAssertEqual(result["attempts"] as? Int, 1)
        XCTAssertTrue(node("separation.latestScore").label.contains("本杆"))
        capture("submit-\(is3D ? "3D" : "2D")-result")
        XCUIDevice.shared.press(.home); app.activate(); waitPhase("result")
        XCTAssertEqual(try probe()["cuePosition"] as? [Double], initial["cuePosition"] as? [Double])
        XCTAssertFalse(app.buttons["separation.geometry"].isEnabled)
        XCTAssertEqual(try probe()["cuePosition"] as? [Double], initial["cuePosition"] as? [Double])
        app.buttons["separation.retry"].tap(); waitPhase("aiming")
        XCTAssertEqual(submit.label, "提交")
        XCTAssertTrue(node("separation.latestScore").label.contains("上杆得分"))
        XCTAssertEqual(try probe()["idealPocketLineVisible"] as? Bool, true)
        XCTAssertEqual(try probe()["objectRouteVisible"] as? Bool, false)
        capture("submit-retry-previous-score")
        let bar = node("shotStage.powerBar")
        ready(bar)
        for _ in 0..<8 where ((try probe()["input"] as? [Double])?.last ?? 0) > 0.5 {
            bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.05)).press(forDuration: 0.05,
                thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95)),
                withVelocity: .fast, thenHoldForDuration: 0)
        }
        XCTAssertEqual((try probe()["input"] as? [Double])?.last, 0.5)
        submit.tap(); waitPhase("result")
        XCTAssertTrue(node("separation.result").label.contains("本杆"))
        XCTAssertEqual(try probe()["idealPocketLineVisible"] as? Bool, false)
        XCTAssertTrue(node("separation.result").label.contains("目标球未进指定袋") || node("separation.result").label.contains("未碰到目标球"))
        XCTAssertEqual(try probe()["referenceVisible"] as? Bool, true)
        XCTAssertEqual(try probe()["referencePointCount"] as? Int, initial["referencePointCount"] as? Int)
        capture("submit-low-power-real-object-route")
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        // Cancelling entry settings must discard the draft and keep this question.
        let currentQuestion = try probe()["question"] as? String
        app.buttons["separation.more"].tap()
        let settings = app.buttons["separation.trainingSettings"]
        for _ in 0..<5 where !settings.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(settings); settings.tap(); ready(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        reference.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap(); app.buttons["training.settingsCancel"].tap(); waitPhase("result")
        XCTAssertEqual(try probe()["referenceVisible"] as? Bool, true)
        XCTAssertTrue(node("separation.referenceLegend").exists)
        XCTAssertEqual(try probe()["playsStroke"] as? Bool, false)
        XCTAssertEqual(try probe()["question"] as? String, currentQuestion)
        app.buttons["separation.more"].tap()
        for _ in 0..<5 where !settings.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(settings); settings.tap(); ready(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(reference.value as? String, "1", "Cancel discards the reference draft")
        reference.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        toggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap(); start()
        XCTAssertEqual(try probe()["showsReference"] as? Bool, false)
        waitReference(true)
        XCTAssertFalse(node("separation.actualLegend").exists)
        capture("reference-off-\(is3D ? "3D" : "2D")")
        XCTAssertEqual(submit.label, "击球")
        XCTAssertEqual(app.buttons["separation.retry"].label, "重打")
        XCTAssertEqual(app.buttons["separation.geometry"].label, "几何参考")
        submit.tap(); waitPhase("result", timeout: 120)
        XCTAssertGreaterThan(try XCTUnwrap(probe()["strokeStartedAt"] as? Double), 0)
        capture("submit-\(is3D ? "3D" : "2D")-stroke-restored")
        XCTAssertEqual(try probe()["referenceVisible"] as? Bool, false)
        app.buttons["separation.more"].tap()
        for _ in 0..<5 where !settings.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
        ready(settings); settings.tap(); ready(reference)
        XCTAssertEqual(reference.value as? String, "0")
        reference.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap(); start()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["referenceVisible"] as? Bool) == true
        }, object: app)], timeout: 30), .completed)
        XCTAssertTrue(node("separation.referenceLegend").exists)
        capture("reference-restored-\(is3D ? "3D" : "2D")")
    }
    func testPersistedSoundSettingWithOrdinaryQuestionsAndForegroundReplay() throws {
        XCUIDevice.shared.orientation = .portrait
        // Do not override soundEffectsEnabled or the question seed: exercise the
        // persisted setting and ordinary question path used outside the test fixture.
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore",
            "-freeLayout.ephemeral", "-separation.probe", "-shotAudio.probe"])
        func soundSetting() -> XCUIElement {
            app.switchTab(.profile)
            let settings = app.buttons["设置"]
            for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
            ready(settings); settings.tap()
            let toggle = app.switches["settings.shotSoundEffects"]
            for _ in 0..<8 where !toggle.isHittable { node("settings.content").swipeUp() }
            ready(toggle)
            return toggle
        }
        let toggle = soundSetting()
        let wasEnabled = toggle.value as? String == "1"
        if wasEnabled { toggle.tap() }
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.terminate(); app.launch()
        for is3D in [false, true] {
            app.switchTab(.angle); app.buttons["angleHomeTab_打"].tap()
            let entry = app.buttons[is3D ? "3D分离角" : "2D分离角"]
            ready(entry); entry.tap(); start()
            XCTAssertEqual((try probe()["audio"] as? [String: Any])?["enabled"] as? Bool, true)
            let bar = node("shotStage.powerBar")
            ready(bar)
            bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)).press(forDuration: 0.1,
                thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.48)))
            XCUIDevice.shared.press(.home); app.activate(); waitPhase("aiming")
            app.buttons["separation.strike"].tap(); waitPhase("result", timeout: 120)
            func checkOutput(_ phase: String) throws {
                let state = try probe()
                let audio = try XCTUnwrap(state["audio"] as? [String: Any])
                print("SEPARATION_PERSISTED_AUDIO \(is3D ? "3D" : "2D") \(phase) input=\(state["input"] ?? "") \(audio)")
                XCTAssertGreaterThan(try XCTUnwrap(audio["peak"] as? Double), 0.0001)
                let sounds = try XCTUnwrap(audio["played"] as? [String: Int])
                XCTAssertGreaterThan(sounds["cueStrike"] ?? 0, 0)
                XCTAssertGreaterThan(sounds["ballHit"] ?? 0, 0)
            }
            try checkOutput("shot")
            XCUIDevice.shared.press(.home); app.activate(); waitPhase("result")
            app.buttons["separation.retry"].tap(); waitPhase("aiming")
            app.buttons["separation.strike"].tap(); waitPhase("result", timeout: 120)
            try checkOutput("retry-shot")
            capture("persisted-audio-\(is3D ? "3D" : "2D")")
            app.buttons["separation.back"].tap()
        }
        if !wasEnabled { soundSetting().tap() }
    }
    private func exercise(is3D: Bool) throws {
        open(is3D)
        let strokeToggle = app.switches["separation.playsStroke"]; ready(strokeToggle)
        if strokeToggle.value as? String == "0" {
            strokeToggle.coordinate(withNormalizedOffset: .init(dx: 1, dy: 0.5)).withOffset(.init(dx: -30, dy: 0)).tap()
        }
        start()
        let initial = try probe(), question = try XCTUnwrap(initial["question"] as? String)
        XCTAssertEqual(initial["actualVisible"] as? Bool, false)
        XCTAssertEqual(initial["targetVisible"] as? Bool, true)
        XCTAssertEqual(initial["guidesVisible"] as? Bool, true)
        XCTAssertFalse(node("separation.aimWheel").exists)
        XCTAssertTrue(node("separation.averageScore").isHittable)
        XCTAssertTrue(node("separation.questionAverageScore").exists)
        XCTAssertTrue(node("separation.latestScore").exists)
        XCTAssertGreaterThan(app.buttons["separation.retry"].frame.minY,
                             node("shotStage.powerBar").frame.maxY)
        capture(is3D ? "3D-target" : "2D-target")
        app.buttons["separation.more"].tap()
        XCTAssertFalse(app.buttons["separation.rehearsal"].exists)
        XCTAssertFalse(app.buttons["separation.trajectory"].exists)
        XCTAssertFalse(app.buttons["menu.aimCloseup"].exists)
        capture("separation-menu")
        app.buttons["separation.dismissMenu"].tap()
        if is3D {
            let top = app.buttons["shotCamera.temporaryTopDown"]
            ready(top); top.tap()
            XCTAssertFalse(app.buttons["separation.strike"].isEnabled)
            capture("3D-temporary-topdown"); top.tap(); ready(app.buttons["separation.strike"])
            XCTAssertEqual(try probe()["question"] as? String, question)
            let scene = node("table.scene")
            func camera() throws -> [Double] {
                let text = try XCTUnwrap(scene.value as? String)
                let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
                return try XCTUnwrap(state["camera"] as? [Double])
            }
            let originalCamera = try camera(), originalInput = try probe()["input"] as? [Double]
            scene.coordinate(withNormalizedOffset: .init(dx: 0.35, dy: 0.6)).press(forDuration: 0.05,
                thenDragTo: scene.coordinate(withNormalizedOffset: .init(dx: 0.65, dy: 0.55)))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (try? camera()) != originalCamera
            }, object: nil)], timeout: 5), .completed)
            XCTAssertEqual(try probe()["input"] as? [Double], originalInput)
            XCTAssertEqual(try probe()["question"] as? String, question)
            capture("3D-manual-camera-preserves-input")
        }
        app.buttons["separation.strike"].tap()
        waitPhase("result", timeout: 120)
        let first = try probe()
        XCTAssertEqual(first["scoreVersion"] as? String, "arc1cm-rms-p2-t20-potgate-v3")
        if first["scoreZeroReason"] as? String == "" {
            let distance = try XCTUnwrap(first["rmsDistanceCM"] as? Double)
            XCTAssertEqual(try XCTUnwrap(first["latestScore"] as? Double), 100 * exp2(-distance / 20), accuracy: 1e-8)
        }
        XCTAssertEqual(first["attempts"] as? Int, 1)
        XCTAssertEqual(first["actualVisible"] as? Bool, true)
        // Result uses the frozen object-ball route in place of the ideal pocket line (page plan §15).
        XCTAssertEqual(first["objectRouteVisible"] as? Bool, true)
        XCTAssertEqual(first["idealPocketLineVisible"] as? Bool, false)
        let reveal = try XCTUnwrap(first["revealedAt"] as? Double), stroke = try XCTUnwrap(first["strokeStartedAt"] as? Double)
        XCTAssertGreaterThan(reveal, 0); XCTAssertGreaterThanOrEqual(stroke-reveal, 0); XCTAssertLessThan(stroke-reveal, 0.25)
        XCTAssertEqual(first["cueVisibleAtReveal"] as? Bool, true)
        XCTAssertEqual(first["cueVisibleAtStroke"] as? Bool, true)
        XCTAssertTrue(node("separation.result").label.contains("本杆"))
        XCTAssertFalse(node("separation.averageScore").label.contains("/100"))
        XCTAssertLessThanOrEqual(node("separation.averageScore").frame.height,
                                 node("separation.questionInfo").frame.height + 1,
                                 "Average must stay on one value line in the standard sidebar")
        XCTAssertFalse(node("separation.result").label.contains("本题均分"))
        XCTAssertFalse(node("separation.averageScore").label.contains("—"))
        XCTAssertFalse(node("separation.result").label.contains("—"))
        let audio = try XCTUnwrap(first["audio"] as? [String: Any])
        print("SEPARATION_AUDIO \(is3D ? "3D" : "2D") \(audio)")
        XCTAssertEqual(audio["enabled"] as? Bool, true)
        XCTAssertGreaterThan(try XCTUnwrap(audio["peak"] as? Double), 0.0001, "Real mixer must emit non-silent PCM")
        let sounds = try XCTUnwrap(audio["played"] as? [String: Int])
        XCTAssertGreaterThan(sounds["cueStrike"] ?? 0, 0)
        XCTAssertGreaterThan(sounds["ballHit"] ?? 0, 0)
        capture("separation-result")
        XCTAssertFalse(app.buttons["separation.playback"].exists)
        XCTAssertTrue(app.buttons["separation.geometry"].exists)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        app.buttons["separation.retry"].tap(); waitPhase("aiming")
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, true)
        XCTAssertEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["guidesVisible"] as? Bool, true)
        capture("separation-retry")
        let bar = node("shotStage.powerBar")
        ready(bar)
        for _ in 0..<8 where ((try probe()["input"] as? [Double])?.last ?? 0) < 8 {
            bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.95)).press(forDuration: 0.05,
                thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.05)),
                withVelocity: .fast, thenHoldForDuration: 0)
        }
        XCTAssertEqual((try probe()["input"] as? [Double])?.last, 8)
        capture("standard-power-maximum")
        app.buttons["separation.strike"].tap(); waitPhase("result", timeout: 120)
        let retry = try probe()
        XCTAssertEqual(retry["attempts"] as? Int, 1)
        let firstScore = try XCTUnwrap(first["latestScore"] as? Double)
        let latestScore = try XCTUnwrap(retry["latestScore"] as? Double)
        XCTAssertEqual(try XCTUnwrap(retry["averageScore"] as? Double), firstScore, accuracy: 1e-8)
        XCTAssertEqual(try XCTUnwrap(retry["questionAverageScore"] as? Double), (firstScore + latestScore) / 2, accuracy: 1e-8)
        XCTAssertTrue(node("separation.latestScore").label.contains(String(format: "%.1f", latestScore)))
        capture("repeat-mean-result")
        app.buttons["separation.more"].tap(); app.buttons["separation.finish"].tap()
        ready(app.buttons["training.restart"])
        XCTAssertTrue(app.staticTexts["已练题数"].exists)
        XCTAssertTrue(app.staticTexts["首杆均分"].exists)
        XCTAssertFalse(app.staticTexts["进球率"].exists)
        capture("separation-summary")
        app.buttons["training.restart"].tap(); ready(app.buttons["training.settingsCancel"])
        app.buttons["training.settingsCancel"].tap(); ready(app.buttons["training.complete"])
        app.buttons["training.complete"].tap(); ready(app.buttons["angleHomeTab_打"])
        app.switchTab(.history)
        XCTAssertTrue(node("history.separation").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "首杆均分")).firstMatch.exists)
        app.swipeUp()
        ready(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "首杆均分")).firstMatch)
        capture("history-score")
        app.terminate()
    }
    func testFree3DGateAndIndependent2DLastQuestion() throws {
        open(true, premium: false)
        ready(app.buttons["subscription.close"])
        XCTAssertFalse(app.buttons["separation.start"].exists)
        capture("3D-free-pro-gate"); app.buttons["subscription.close"].tap(); app.terminate()
        open(false, premium: false, nearLimit: true)
        let free = node("training.length").buttons["持续练习"]
        XCTAssertEqual(free.value as? String, "需要 Pro")
        capture("2D-free-mode-lock")
        free.tap(); ready(app.buttons["subscription.close"])
        app.buttons["subscription.close"].tap(); ready(app.buttons["separation.start"])
        XCTAssertTrue(node("training.length").buttons["20题"].isSelected)
        start()
        XCTAssertEqual(try probe()["nextQuestionPending"] as? Bool, false)
        app.buttons["separation.strike"].tap(); waitPhase("result", timeout: 120)
        XCTAssertEqual(try probe()["quota"] as? Int, 20)
        XCTAssertEqual(try probe()["nextQuestionPending"] as? Bool, false)
        app.buttons["separation.retry"].tap(); waitPhase("aiming")
        app.buttons["separation.strike"].tap(); waitPhase("result", timeout: 120)
        XCTAssertEqual(try probe()["quota"] as? Int, 20)
        app.buttons["separation.strike"].tap(); ready(app.buttons["training.restart"])
        XCTAssertEqual(app.buttons["training.restart"].label, "重新开始")
        capture("2D-free-quota-summary")
        app.buttons["training.restart"].tap(); ready(app.buttons["subscription.close"])
        app.buttons["subscription.close"].tap(); ready(app.buttons["training.restart"])
        XCTAssertTrue(node("separation.summary").exists)
        app.terminate()
    }
    func testBackgroundCancelsPendingAutomaticStrike() throws {
        open(false); start()
        let id = try probe()["question"] as? String
        app.buttons["separation.strike"].tap()
        XCUIDevice.shared.press(.home); app.activate()
        let resumedPhase = try XCTUnwrap(probe()["phase"] as? String)
        XCTAssertTrue(["aiming", "result"].contains(resumedPhase))
        XCTAssertEqual(try probe()["question"] as? String, id)
        let state = try probe()
        XCTAssertEqual(state["actualVisible"] as? Bool, (state["attempts"] as? Int ?? 0) > 0)
        capture("background-no-automatic-shot"); app.terminate()
    }
    func test2DExpandedControlsLayoutAndRotation() throws { try expanded(is3D: false) }
    func test3DExpandedControlsLayoutAndRotation() throws { try expanded(is3D: true) }
    func testLightLargeTextMenuAndExpandedPad() throws {
        for is3D in [false, true] {
            open(is3D, largeText: true); start()
            capture("large-text-\(is3D ? "3D" : "2D")-base")
            app.buttons["separation.more"].tap()
            let transparency = app.buttons["separation.transparency"]
            for _ in 0..<5 where !transparency.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(transparency); transparency.tap()
            XCTAssertTrue(node("spinPad.disc").exists)
            let done = app.buttons["dailyClearance.spinTransparencyDone"]
            for _ in 0..<5 where !done.isHittable { app.scrollViews["dailyClearance.spinTransparencyScroll"].swipeUp() }
            ready(done); capture("large-text-expanded"); done.tap()
            app.coordinate(withNormalizedOffset: .init(dx: 0.2, dy: 0.5)).tap()
            ready(app.buttons["separation.strike"])
            XCTAssertEqual(try probe()["attempts"] as? Int, 0)
            app.terminate()
        }
    }
    private func expanded(is3D: Bool) throws {
        open(is3D); start()
        let question = try probe()["question"] as? String
        let primary = app.buttons["separation.strike"]
        func menu(_ id: String) {
            app.buttons["separation.more"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(node("dailyClearance.menuPanel").waitForExistence(timeout: 5))
            let item = app.buttons[id]
            for _ in 0..<5 where !item.isHittable { app.scrollViews["dailyClearance.menuScroll"].swipeUp() }
            ready(item); item.tap()
        }
        menu("separation.transparency")
        let slider = app.sliders["dailyClearance.spinTransparencySlider"]
        ready(slider)
        for opacity in [CGFloat(0), 0.5, 1] {
            slider.adjust(toNormalizedSliderPosition: opacity)
            capture("\(is3D ? "3D" : "2D")-transparency-\(opacity)")
        }
        slider.adjust(toNormalizedSliderPosition: 0.5)
        app.buttons["dailyClearance.spinTransparencyDone"].tap()
        // Closing the subpanel keeps the expanded, editable standard pad.
        let up = app.buttons["高杆增加 1%"], side = app.buttons["右塞增加 1%"]
        ready(up); up.tap(); ready(side); side.tap()
        let input = try XCTUnwrap(try probe()["input"] as? [Double])
        XCTAssertGreaterThan(abs(input[0]), 0); XCTAssertGreaterThan(abs(input[1]), 0)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        XCTAssertFalse(app.staticTexts["计算中"].exists)
        app.buttons["回中"].tap()
        XCTAssertEqual(try probe()["input"] as? [Double], [0, 0, 2.5])
        capture("expanded-editable-pad")
        app.coordinate(withNormalizedOffset: .init(dx: 0.25, dy: 0.5)).tap()
        let bar = node("shotStage.powerBar")
        ready(bar)
        let beforePower = try XCTUnwrap((try probe()["input"] as? [Double])?.last)
        bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.7)).press(forDuration: 0.1,
            thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)))
        let increased = try XCTUnwrap((try probe()["input"] as? [Double])?.last)
        XCTAssertGreaterThan(increased, beforePower); XCTAssertLessThanOrEqual(increased, 8)
        bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.3)).press(forDuration: 0.1,
            thenDragTo: bar.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.7)))
        XCTAssertLessThan(try XCTUnwrap((try probe()["input"] as? [Double])?.last), increased)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        menu("menu.tableGrid")
        capture("grid-enabled-menu")
        XCTAssertFalse(app.buttons["separation.rehearsal"].exists)
        app.buttons["separation.dismissMenu"].tap()
        menu("controlLayout.open")
        let control = app.buttons["freeLayout.select.shot.strike"]
        ready(control); let original = control.frame
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["freeLayout.larger"].tap()
        XCTAssertGreaterThan(control.frame.width, original.width)
        app.buttons["freeLayout.collapse"].tap()
        let from = control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(.init(dx: -24, dy: -10)))
        capture("layout-draft-moved")
        app.buttons["freeLayout.cancel"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(node("freeLayout.editor").waitForNonExistence(timeout: 5)); ready(primary)
        XCTAssertEqual(primary.frame.midX, original.midX, accuracy: 1)
        menu("controlLayout.open"); ready(control)
        control.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        app.buttons["freeLayout.larger"].tap()
        let saved = control.frame
        app.buttons["freeLayout.save"].tap()
        let field = app.alerts.textFields.firstMatch; ready(field)
        field.tap(); field.typeText("Separation UI \(is3D ? "3D" : "2D")")
        app.alerts.buttons["保存"].tap(); ready(primary)
        XCTAssertEqual(primary.frame.width, saved.width, accuracy: 1)
        if min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) >= 600 {
            for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
                XCUIDevice.shared.orientation = orientation
                // iPadOS restores the last floating window independently for each
                // orientation. Normalize that system state before testing fullscreen rotation.
                let rotatedWindow = app.windows.firstMatch
                if rotatedWindow.frame.minX > 1 || rotatedWindow.frame.minY > 40 {
                    let before = rotatedWindow.frame
                    rotatedWindow.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
                    if abs(rotatedWindow.frame.width-before.width) < 1 {
                        rotatedWindow.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
                    }
                    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        self.app.windows.firstMatch.frame.minX < 1
                    }, object: nil)], timeout: 10), .completed)
                }
                let rotation = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let f = self.app.windows.firstMatch.frame
                    return orientation == .portrait ? f.height > f.width : f.width > f.height
                }, object: nil)], timeout: 10)
                print("SEPARATION_ROTATION requested=\(orientation.rawValue) window=\(app.windows.firstMatch.frame) scene=\(node("table.scene").frame)")
                capture("rotation-\(orientation.rawValue)-actual-window")
                XCTAssertEqual(rotation, .completed)
                ready(primary); XCTAssertTrue(app.windows.firstMatch.frame.contains(primary.frame))
                XCTAssertEqual(try probe()["question"] as? String, question)
                capture(orientation == .portrait ? "ipad-portrait" : "ipad-landscape-return")
            }
            let full = app.windows.firstMatch.frame, fullPrimaryWidth = primary.frame.width
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(.init(dx: full.width-7, dy: full.height-7)).press(forDuration: 0.5,
                thenDragTo: origin.withOffset(.init(dx: full.width*0.7, dy: full.height*0.78)))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let f = self.app.windows.firstMatch.frame
                return f.width < full.width-80 || f.height < full.height-80
            }, object: nil)], timeout: 10), .completed, "Real system window resizing")
            ready(primary); XCTAssertEqual(try probe()["question"] as? String, question)
            XCTAssertFalse(primary.frame.intersects(bar.frame), "Resized strike must not overlap the power control")
            XCTAssertFalse(app.buttons["separation.retry"].frame.intersects(app.buttons["separation.geometry"].frame))
            if is3D {
                for id in ["shotCamera.firstPerson", "shotCamera.thirdPerson", "shotCamera.temporaryTopDown", "dailyClearance.observeTable"] {
                    XCTAssertFalse(app.buttons[id].frame.intersects(bar.frame), "Camera must not overlap power after resize")
                }
            }
            capture("ipad-real-small-window")
            let window = app.windows.firstMatch, small = window.frame
            window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width-small.width) < 1 {
                window.coordinate(withNormalizedOffset: .zero).withOffset(.init(dx: 104, dy: 32)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(self.app.windows.firstMatch.frame.width-full.width) < 1
            }, object: nil)], timeout: 10), .completed)
            ready(primary); XCTAssertEqual(try probe()["question"] as? String, question)
            XCTAssertEqual(primary.frame.width, fullPrimaryWidth, accuracy: 1, "Same window restores the prior displayed layout")
            capture("ipad-full-window-restored")
        }
        if is3D {
            for id in ["shotCamera.firstPerson", "dailyClearance.observeTable", "shotCamera.thirdPerson"] {
                ready(app.buttons[id]); app.buttons[id].tap(); ready(primary); capture(id)
            }
        }
        primary.tap(); waitPhase("result", timeout: 120)
        XCTAssertEqual(try probe()["attempts"] as? Int, 1)
        capture("moved-primary-real-shot")
        primary.tap(); waitPhase("aiming", timeout: 180)
        XCTAssertNotEqual(try probe()["question"] as? String, question)
        XCTAssertEqual(try probe()["actualVisible"] as? Bool, false)
        capture("next-question-clean")
        app.terminate()
    }
}
