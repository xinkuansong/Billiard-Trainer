import XCTest

/// Production-entry regression for the remaining daily-template adoption gaps.
final class RemainingTeachingAdoptionUITests: XCTestCase {
    private var app: XCUIApplication!
    private var pageOrientation: UIDeviceOrientation = .landscapeLeft
    private var closeupIn3D = false
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func ready(_ item: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: item)],
            timeout: timeout), .completed)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = (pageOrientation == .portrait ? "portrait-" : "") + (closeupIn3D ? "3D-" : "") + name
        image.lifetime = .keepAlways; add(image)
    }
    private func launch(_ page: String) {
        app?.terminate()
        XCUIDevice.shared.orientation = pageOrientation
        let deep = ["silu": "silu", "planthree": "planThree", "snooker": "snooker"]
        var args = ["-forcePremium", "-v50.inMemoryStore", "-3dDrag.probe", "-v51.followSystemAppearance", "-appearanceMode", "system"]
        if let route = deep[page] { args += ["-deeplink." + route] }
        if page == "planthree" { args += ["-planThree.twoBall"] }
        if page == "snooker" { args += ["-snooker.full"] }
        app = XCUIApplication.launchClean(extraArgs: args)
        if deep[page] == nil {
            app.switchTab(.angle)
            ready(app.buttons["angleHomeTab_解"]); app.buttons["angleHomeTab_解"].tap()
            let card = app.buttons[page == "bankshot" ? "翻袋解球" : "颗星解球"]
            ready(card); card.tap()
        }
        XCTAssertTrue(element(page + ".template").waitForExistence(timeout: 30))
        if UIDevice.current.userInterfaceIdiom == .pad {
            let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let frame = self.app.windows.firstMatch.frame
                return self.pageOrientation.isLandscape ? frame.width > frame.height : frame.height > frame.width
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 8), .completed,
                           "The native window must actually reach the requested iPad orientation")
        }
    }

    func testTransparencyShowsDiscAcrossFivePages() {
        for page in ["silu", "planthree", "snooker", "bankshot", "reflection"] {
            launch(page)
            for mode in ["2D", "3D"] {
                let more = app.buttons[page + ".more"]
                ready(more)
                more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                let camera = app.buttons[page + ".cameraMode"]
                ready(camera)
                if camera.value as? String != mode { camera.tap() }
                let item = app.buttons[page + ".transparency"]
                ready(item); item.tap()
                let disc = element("spinPad.disc")
                XCTAssertTrue(disc.exists, "Transparency must show the actual disc on " + page)
                let slider = app.sliders["dailyClearance.spinTransparencySlider"]
                ready(slider)
                for value in [0.0, 0.5, 1.0] {
                    slider.adjust(toNormalizedSliderPosition: value)
                    func displayedPercent() -> Double {
                        Double(app.staticTexts["dailyClearance.spinTransparencyPercent"].label
                            .replacingOccurrences(of: "%", with: "")) ?? -1
                    }
                    var percent = displayedPercent()
                    // Always make a full-length drag from a known endpoint. Tiny
                    // corrective drags can remain below the native pan threshold.
                    // Read visible percentages to calibrate the touch destination;
                    // UIKit thumb insets differ between OS versions and presentations.
                    let native = UISlider(frame: CGRect(origin: .zero, size: slider.frame.size))
                    let track = native.trackRect(forBounds: native.bounds)
                    let origin = slider.coordinate(withNormalizedOffset: .zero)
                    func drag(from current: Double, to x: CGFloat) {
                        let thumb = native.thumbRect(forBounds: native.bounds, trackRect: track,
                                                     value: Float(current / 100))
                        origin.withOffset(CGVector(dx: thumb.midX, dy: thumb.midY))
                            .press(forDuration: 0.1, thenDragTo: origin.withOffset(
                                CGVector(dx: x, dy: thumb.midY)),
                                withVelocity: .slow, thenHoldForDuration: 0.2)
                    }
                    if value == 0 || value == 1 {
                        if percent != value * 100 {
                            drag(from: percent, to: value == 0 ? -native.bounds.width / 2
                                 : native.bounds.width * 1.5)
                            percent = displayedPercent()
                        }
                    } else {
                        var lower: CGFloat = 0, upper = native.bounds.width
                        var observations: [String] = []
                        for _ in 0..<8 where abs(percent - 50) > 1 {
                            drag(from: percent, to: -native.bounds.width / 2)
                            XCTAssertEqual(displayedPercent(), 0, "Calibration starts at the real opaque endpoint")
                            let destination = (lower + upper) / 2
                            drag(from: 0, to: destination)
                            percent = displayedPercent()
                            observations.append("destination=\(destination), displayed=\(percent)")
                            if percent < 50 { lower = destination } else { upper = destination }
                        }
                        let calibration = XCTAttachment(string: observations.joined(separator: "\n"))
                        calibration.name = page + "-" + mode + "-slider-calibration"
                        calibration.lifetime = .keepAlways; add(calibration)
                    }
                    if abs(percent - value * 100) > 1 { capture(page + "-slider-target-missed") }
                    XCTAssertEqual(percent, value * 100, accuracy: 1)
                    capture(page + "-" + mode + "-transparency-" + String(Int(value * 100)))
                }
                app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
                XCTAssertTrue(disc.exists, "Closing settings retains the disc")
                ready(app.buttons["关闭打点"]); app.buttons["关闭打点"].tap()
            }
            // A new process must retain this page's last setting and show its real disc.
            launch(page); openMore(page)
            ready(app.buttons[page + ".transparency"]); app.buttons[page + ".transparency"].tap()
            XCTAssertTrue(element("spinPad.disc").exists)
            XCTAssertEqual(app.staticTexts["dailyClearance.spinTransparencyPercent"].label, "100%")
            capture(page + "-transparency-reentered")
        }
    }

    private func prepareSolution(_ page: String) {
        if page == "silu" {
            app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
            let table = element("table.scene")
            let information = app.scrollViews.containing(.any, identifier: "silu.status").firstMatch
            let frame = table.frame
            // Start on exposed cloth, not on the scrollable information overlay.
            let cloth = CGRect(x: frame.minX + frame.width * 0.25, y: frame.minY + frame.height * 0.3,
                               width: frame.width * 0.55, height: frame.height * 0.45)
            let obstacle = information.frame.intersection(cloth)
            let candidates = obstacle.isNull ? [cloth] : [
                CGRect(x: cloth.minX, y: cloth.minY, width: max(0, obstacle.minX - cloth.minX), height: cloth.height),
                CGRect(x: obstacle.maxX, y: cloth.minY, width: max(0, cloth.maxX - obstacle.maxX), height: cloth.height),
                CGRect(x: cloth.minX, y: cloth.minY, width: cloth.width, height: max(0, obstacle.minY - cloth.minY)),
                CGRect(x: cloth.minX, y: obstacle.maxY, width: cloth.width, height: max(0, cloth.maxY - obstacle.maxY))]
            let clear = candidates.max { $0.width * $0.height < $1.width * $1.height }!
            XCTAssertGreaterThan(clear.width, 20); XCTAssertGreaterThan(clear.height, 20)
            let start = table.coordinate(withNormalizedOffset: CGVector(
                dx: (clear.minX + clear.width * 0.15 - frame.minX) / frame.width,
                dy: (clear.minY + clear.height * 0.15 - frame.minY) / frame.height))
            let end = table.coordinate(withNormalizedOffset: CGVector(
                dx: (clear.maxX - clear.width * 0.15 - frame.minX) / frame.width,
                dy: (clear.maxY - clear.height * 0.15 - frame.minY) / frame.height))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        if page == "silu" || page == "planthree" {
            ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap()
        }
    }
    private func openMore(_ page: String) {
        let more = app.buttons[page + ".more"]; ready(more)
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func revealMenuItem(_ id: String) -> XCUIElement {
        let item = app.buttons[id], scroll = element("dailyClearance.menuScroll")
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<16 where !item.exists || !scroll.frame.contains(item.frame) {
            let above = item.exists && item.frame.minY < scroll.frame.minY
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.35 : 0.65))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.65 : 0.35)))
        }
        XCTAssertTrue(item.exists && scroll.frame.contains(item.frame), "Menu item must be visible: " + id)
        XCTAssertTrue(item.isHittable)
        return item
    }
    private func holdAimRulerForNativeCapture(_ label: String) {
        let wheel = element("shotStage.aimWheel"); ready(wheel)
        let name = (closeupIn3D ? "3D-" : "2D-") + label
        FileHandle.standardOutput.write(Data("CLOSEUP_HOLD \(name)\n".utf8))
        let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: 2)),
                    withVelocity: .slow, thenHoldForDuration: 8)
    }

    func testSolvedCloseupsAndBackgroundRecovery() {
        for page in ["silu", "planthree", "snooker"] {
            launch(page); prepareSolution(page)
            ready(app.buttons[page + ".strike"])
            openMore(page)
            let camera = app.buttons[page + ".cameraMode"]; ready(camera)
            let expectedCamera = closeupIn3D ? "3D" : "2D"
            if camera.value as? String != expectedCamera { camera.tap() }
            XCTAssertEqual(camera.value as? String, expectedCamera)
            let closeup = revealMenuItem("menu.aimCloseup"); ready(closeup)
            if closeup.value as? String == "已选" { closeup.tap() }
            app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
            let hud = element("aimCloseup.hud")
            XCTAssertFalse(hud.exists, "Disabled closeup must not appear at rest")
            capture(page + "-closeup-off")
            openMore(page); revealMenuItem("menu.aimCloseup").tap()
            app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
            XCTAssertFalse(hud.exists, "Enabling the preference must not show a persistent loupe")
            capture(page + "-enabled-idle")
            XCTAssertFalse(element("shotStage.aimWheel").exists,
                           "Ordinary planning has no direction ruler; solving is not an aiming gesture")
            app.buttons["shotStage.spinEntry"].tap()
            let disc = element("spinPad.disc"); ready(disc)
            disc.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.4)).tap()
            XCTAssertFalse(hud.exists, "Spin adjustment must not reveal an aim closeup")
            app.buttons["关闭打点"].tap()
            ready(app.buttons[page + ".strike"])
            XCTAssertFalse(hud.exists, "An updated solution must not reveal an aim closeup")
            capture(page + "-spin-updated-idle")
            let notice = element(page + ".status")
            if notice.exists {
                let viewport = app.scrollViews.containing(.any, identifier: page + ".status").firstMatch
                XCTAssertTrue(viewport.exists)
                XCTAssertTrue(element("table.scene").frame.contains(viewport.frame))
            }
            XCTAssertFalse(element("planthree.rolesSummary").exists)
            if page == "planthree" {
                XCTAssertFalse((app.buttons["paletteBall__1"].value as? String ?? "").isEmpty)
            }
            capture(page + "-closeup-on")
            XCUIDevice.shared.press(.home); app.activate()
            ready(app.buttons[page + ".strike"])
            openMore(page); _ = revealMenuItem("menu.aimCloseup"); ready(closeup)
            XCTAssertEqual(closeup.value as? String, "已选")
            app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
            XCTAssertFalse(hud.exists, "Returning to the foreground must not revive a released loupe")
            capture(page + "-foreground-closeup")
        }
    }
    func testThreeDimensionalCloseups() {
        closeupIn3D = true
        testSolvedCloseupsAndBackgroundRecovery()
    }

    func testIPadPortraitCloseupInformation() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Portrait contract applies to iPad")
        pageOrientation = .portrait
        testSolvedCloseupsAndBackgroundRecovery()
        testThreeDimensionalCloseups()
    }

    func testIPadPortraitAdoption() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Portrait contract applies to iPad")
        pageOrientation = .portrait
        testTransparencyShowsDiscAcrossFivePages()
        testSolvedCloseupsAndBackgroundRecovery()
        testThreeDimensionalCloseups()
        testFreePreviewDragStrikeUndoAndBackground()
    }

    func testFreeCloseupOnlyWhileDirectionRulerIsHeld() {
        for page in ["bankshot", "reflection"] {
            launch(page)
            ready(app.buttons["solver.mode"]); app.buttons["solver.mode"].tap()
            for mode in ["2D", "3D"] {
                closeupIn3D = mode == "3D"
                openMore(page)
                let camera = app.buttons[page + ".cameraMode"]; ready(camera)
                if camera.value as? String != mode { camera.tap() }
                let toggle = revealMenuItem("menu.aimCloseup")
                if toggle.value as? String == "已选" { toggle.tap() }
                app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
                let hud = element("aimCloseup.hud")
                XCTAssertFalse(hud.exists)
                holdAimRulerForNativeCapture(page + "-disabled-drag")
                XCTAssertFalse(hud.exists)
                openMore(page); revealMenuItem("menu.aimCloseup").tap()
                app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
                XCTAssertFalse(hud.exists, "Preference alone must not show the loupe")
                capture(page + "-free-enabled-idle")
                holdAimRulerForNativeCapture(page + "-enabled-drag")
                XCTAssertFalse(hud.exists, "Release must immediately remove the loupe")
                capture(page + "-free-released")
                XCUIDevice.shared.press(.home); app.activate()
                XCTAssertFalse(hud.exists, "Foreground must not revive the loupe")
            }
        }
    }

    func testFreePreviewDragStrikeUndoAndBackground() {
        for page in ["bankshot", "reflection"] {
            launch(page)
            ready(app.buttons["solver.mode"]); app.buttons["solver.mode"].tap()
            let wheel = element("shotStage.aimWheel"); ready(wheel)
            for _ in 0..<3 {
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                    .press(forDuration: 0.1, thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)), withVelocity: .slow, thenHoldForDuration: 0.1)
            }
            ready(app.buttons[page + ".strike"])
            capture(page + "-free-full-preview")
            app.buttons[page + ".strike"].tap()
            ready(app.buttons["solver.undo"], timeout: 90)
            capture(page + "-free-settled")
            app.buttons["solver.undo"].tap()
            ready(app.buttons[page + ".strike"])
            XCUIDevice.shared.press(.home); app.activate()
            ready(app.buttons[page + ".strike"])
            capture(page + "-free-restored")
            app.buttons["solver.mode"].tap()
            XCTAssertEqual(app.buttons["solver.mode"].value as? String, "求解")
        }
    }

    func testPairedSpinOnPlanningAndSolverPages() throws {
        for page in ["silu", "planthree", "snooker", "bankshot", "reflection"] {
            launch(page)
            prepareSolution(page)
            ready(app.buttons["shotStage.spinEntry"])
            app.buttons["shotStage.spinEntry"].tap()
            let disc = element("spinPad.disc"); ready(disc)
            // Physical contact uses both axes; a mirrored second point cannot
            // accidentally pass by retaining a catalog's existing spin.
            var firstPoint = true
            for (dx, dy, xLabel, yLabel) in [(0.38, 0.38, "左", "高"), (0.62, 0.38, "右", "高"),
                                                (0.38, 0.62, "左", "低"), (0.62, 0.62, "右", "低")] {
                let point = CGVector(dx: dx, dy: dy)
                if firstPoint {
                    disc.coordinate(withNormalizedOffset: point).tap()
                    firstPoint = false
                } else {
                    app.buttons["回中"].tap()
                    XCTAssertEqual(disc.value as? String, "中心球")
                    // The documented gesture first moves the finger 52pt clear,
                    // then adjusts relatively. A short in-disc drag intentionally does nothing.
                    let dx = point.dx - 0.5, dy = point.dy - 0.5
                    let length = hypot(dx, dy)
                    let travel = 52 + min(disc.frame.width, disc.frame.height) / 2
                    let start = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    start.press(forDuration: 0.1,
                        thenDragTo: start.withOffset(CGVector(dx: dx / length * travel, dy: dy / length * travel)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
                }
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let value = disc.value as? String ?? ""
                    return value.contains(xLabel) && value.contains(yLabel)
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 30), .completed,
                               page + " must accept both axes from one point")
                capture(page + "-paired-" + xLabel + yLabel)
            }
            // Use the exact-zero control; a rounded screen coordinate can be off-centre on SE.
            app.buttons["回中"].tap()
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == '中心球'"), object: disc)], timeout: 30), .completed)
        }
    }
}

/// W1-A native evidence. The audit case intentionally records the baseline
/// before a repair; acceptance assertions live in separate cases.
final class ATeachingStandardsUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    private func launch(_ args: [String] = []) {
        app?.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v62.fixture", "-3dDrag.probe", "-appearanceMode", "system"] + args)
    }
    private func capture(_ name: String) {
        usleep(name.contains("temporary") || name.contains("3D-one-track") ? 1_000_000 : 350_000) // Allow camera and label transitions to settle.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func geometry(_ ids: [String], name: String) throws {
        var values: [String: [String: Any]] = [:]
        for id in ids {
            let e = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(e.exists, id)
            values[id] = ["frame": [e.frame.minX,e.frame.minY,e.frame.width,e.frame.height],
                          "label": e.label, "value": String(describing: e.value), "hittable": e.isHittable]
        }
        let data = try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testAuditAtlasTargetsAndTeachingNotice() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            let ids = (0..<8).map { prefix + ".spinLegend.\($0)" }
            try geometry(ids + [prefix + ".metrics",prefix + ".trackCount"], name: page + "-baseline-frames")
            capture(page + "-baseline-eight")
            for i in 0..<8 {
                let item = app.buttons[ids[i]]
                XCTAssertTrue(item.isHittable); item.tap(); XCTAssertEqual(item.value as? String, "未选")
                item.tap(); XCTAssertEqual(item.value as? String, "已选")
            }
        }
        launch(["-dailyInteraction.sharedPage=angleDynamic", "-angleDynamic.hasDraggedOnce", "NO"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["母球和目标球都可以拖动，指标实时联动"].waitForExistence(timeout: 5))
        capture("ad01-baseline-first-drag-notice")
    }
    func testAuditMissingTargetNotices() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            app.buttons["paletteBall__8"].tap()
            XCTAssertTrue(app.staticTexts["请摆好母球与目标球"].waitForExistence(timeout: 10))
            capture(page + "-baseline-missing-target")
        }
    }

    private func openTraining(_ title: String) {
        XCUIDevice.shared.orientation = .portrait
        launch()
        app.switchTab(.angle)
        let practice = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(practice.waitForExistence(timeout: 8)); practice.tap()
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 5) { card.tap() }
        else { app.staticTexts[title].tap() }
    }

    func testAngleTrainingBothModes() throws {
        for mode in ["2D", "3D"] {
            openTraining(mode + "角度")
            let start = app.buttons["angleTraining.start"]
            XCTAssertTrue(start.waitForExistence(timeout: 10))
            capture(mode + "-settings-system")
            start.tap()
            let action = app.buttons["angleTraining.primaryAction"]
            XCTAssertTrue(action.waitForExistence(timeout: 10))
            let assist = app.buttons["angleTraining.assist"]
            XCTAssertEqual(assist.frame.width, assist.frame.height, accuracy: 1)
            XCTAssertGreaterThanOrEqual(assist.frame.width, 44)
            capture(mode + "-actions-neutral")
            assist.tap(); capture(mode + "-assist-enabled")
            action.tap()
            let submit = app.buttons["提交"]
            XCTAssertTrue(submit.waitForExistence(timeout: 5))
            XCTAssertFalse(submit.isEnabled)
            capture(mode + "-keypad-empty-system")
            app.buttons["4"].tap(); app.buttons["5"].tap()
            XCTAssertTrue(submit.isEnabled)
            capture(mode + "-keypad-value-system")
            app.buttons["取消"].tap()
            XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
            app.buttons["4"].tap(); app.buttons["5"].tap(); app.buttons["提交"].tap()
            XCTAssertTrue(app.buttons["下一题"].waitForExistence(timeout: 8))
            capture(mode + "-next-neutral")
            app.buttons["下一题"].tap()
            XCTAssertTrue(app.buttons["答题"].waitForExistence(timeout: 8))
            app.buttons["angleTraining.settings"].tap()
            let display = app.staticTexts["显示"].firstMatch
            let settings = app.buttons["angleTraining.trainingSettings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            XCTAssertLessThan(display.frame.minY, settings.frame.minY)
            capture(mode + "-display-first-menu")
            settings.tap()
            XCTAssertTrue(app.buttons["training.settingsCancel"].waitForExistence(timeout: 5))
            capture(mode + "-settings-sheet-system")
        }
    }

    func testAimPointBothModes() throws {
        for mode in ["2D", "3D"] {
            openTraining(mode + "瞄准点")
            app.buttons["aimPointTraining.start"].tap()
            let submit = app.buttons["aimPointTraining.submit"]
            XCTAssertTrue(submit.waitForExistence(timeout: 15))
            let ruler = app.descendants(matching: .any).matching(identifier: "aimPointTraining.aimWheel").firstMatch
            try geometry(["aimPointTraining.aimWheel", "aimPointTraining.questionInfo", "aimPointTraining.submit"], name: mode + "-ruler-frames")
            capture(mode + "-ruler-and-submit")
            if mode == "3D" {
                let top = app.buttons["shotCamera.temporaryTopDown"]
                top.tap(); capture(mode + "-temporary-top")
                top.tap(); capture(mode + "-temporary-return")
            }
            ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
            submit.tap()
            let next = app.buttons["aimPointTraining.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            capture(mode + "-static-result")
            sleep(3)
            XCTAssertFalse(submit.exists)
            next.tap()
            XCTAssertTrue(submit.waitForExistence(timeout: 10))
            capture(mode + "-next-question")
        }
    }

    func testAtlasSingleColumnAndNotices() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (page,prefix) in [("separation","separationAngleAtlas"),("cushion","cushionEnglishAtlas")] {
            launch(["-dailyInteraction.sharedPage=\(page)"])
            XCTAssertTrue(app.buttons[prefix + ".more"].waitForExistence(timeout: 25))
            let ids = (0..<8).map { prefix + ".spinLegend.\($0)" }
            try geometry(ids + [prefix + ".trackCount"], name: page + "-final-eight-frames")
            capture(page + "-final-eight")
            for i in 0..<8 {
                let item = app.buttons[ids[i]]
                XCTAssertTrue(item.isHittable); XCTAssertFalse(item.label.isEmpty)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(item.frame))
                if i > 0 { XCTAssertLessThanOrEqual(app.buttons[ids[i-1]].frame.maxY, item.frame.minY) }
                item.tap(); XCTAssertEqual(item.value as? String, "未选")
                item.tap(); XCTAssertEqual(item.value as? String, "已选")
            }
            for i in 0..<7 { app.buttons[ids[i]].tap() }
            app.buttons[ids[7]].tap()
            XCTAssertEqual(app.buttons[ids[7]].value as? String, "已选")
            XCTAssertEqual(app.staticTexts[prefix + ".trackCount"].label, "1/8")
            capture(page + "-one-track-retained")
            app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons[prefix + ".cameraMode"].tap()
            app.buttons[prefix + ".dismissMenu"].tap()
            let top = app.buttons["shotCamera.temporaryTopDown"]
            XCTAssertTrue(top.waitForExistence(timeout: 8))
            capture(page + "-3D-one-track")
            top.tap()
            let scene = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
            func snapshot() throws -> [String: Any] {
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(scene.value as? String).utf8)) as? [String: Any])
            }
            var previous = try snapshot()
            var stable = false
            for _ in 0..<8 {
                usleep(250_000)
                let current = try snapshot()
                if current["diagramSurface"] as? String == "temporaryTopDown",
                   (current["camera"] as? [Double]) == (previous["camera"] as? [Double]),
                   (current["displayedTable"] as? [Double]) == (previous["displayedTable"] as? [Double]) {
                    stable = true; break
                }
                previous = current
            }
            XCTAssertTrue(stable, "Temporary overlay and camera/table projection must settle")
            XCTAssertEqual(try snapshot()["standardTemporaryTable"] as? Bool, false, "Non-planning atlas retains its existing legacy temporary projection")
            try geometry(["table.scene"], name: page + "-temporary-stable-probe")
            capture(page + "-temporary-one-track")
            top.tap()
            XCTAssertEqual(app.buttons[ids[7]].value as? String, "已选")
            app.buttons[prefix + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons[prefix + ".cameraMode"].tap()
            app.buttons[prefix + ".dismissMenu"].tap()
            app.buttons["paletteBall__8"].tap()
            let notice = app.descendants(matching: .any).matching(identifier: prefix + ".status").firstMatch
            XCTAssertTrue(notice.waitForExistence(timeout: 10))
            XCTAssertLessThan(notice.frame.midY, app.windows.firstMatch.frame.midY)
            capture(page + "-missing-target-top")
        }
    }

    func testAngleDynamicNoticeAtTop() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(["-dailyInteraction.sharedPage=angleDynamic", "-angleDynamic.hasDraggedOnce", "NO"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        let notice = app.descendants(matching: .any).matching(identifier: "angleDynamic.status").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertLessThan(notice.frame.midY, app.windows.firstMatch.frame.midY)
        capture("ad01-first-drag-notice-top")
        let table = app.descendants(matching: .any).matching(identifier: "table.scene").firstMatch
        let metrics = app.descendants(matching: .any).matching(identifier: "angleDynamic.metrics").firstMatch
        let before = metrics.label
        let probe = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(try XCTUnwrap(table.value as? String).utf8)) as? [String: Any])
        let balls = try XCTUnwrap(probe["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { $0["key"] as? String == "_8" })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        let origin = table.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: point[0], dy: point[1])).press(forDuration: 0.2,
            thenDragTo: origin.withOffset(CGVector(dx: point[0] + 110, dy: point[1] + 40)),
            withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.2)
        XCTAssertNotEqual(metrics.label, before)
        // NSArgumentDomain's NO override is intentionally fixed during this
        // launch. Drop it on relaunch to verify the drag persisted completion.
        launch(["-dailyInteraction.sharedPage=angleDynamic"])
        XCTAssertTrue(app.buttons["angleDynamic.more"].waitForExistence(timeout: 25))
        let restoredNotice = app.descendants(matching: .any).matching(identifier: "angleDynamic.status").firstMatch
        XCTAssertFalse(restoredNotice.exists && restoredNotice.label.contains("母球和目标球都可以拖动"))
        capture("ad01-after-drag-relaunch-guidance-cleared")
    }

    func testAimPointFreeReadoutCapacity() throws {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimitNear", "-v50.inMemoryStore", "-v62.fixture", "-appearanceMode", "system"])
        app.switchTab(.angle); app.buttons["angleHomeTab_练"].tap()
        let card = app.buttons["2D瞄准点"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.buttons["aimPointTraining.start"].waitForExistence(timeout: 15))
        app.buttons["aimPointTraining.start"].tap()
        XCTAssertTrue(app.buttons["aimPointTraining.submit"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.staticTexts["aimPointTraining.remaining"].exists)
        let answer = app.descendants(matching: .any).matching(identifier: "aimPointTraining.answerInfo").firstMatch
        XCTAssertTrue(answer.exists)
        XCTAssertTrue(answer.label.contains("作答")); XCTAssertTrue(answer.label.contains("均差"))
        XCTAssertTrue(app.windows.firstMatch.frame.contains(answer.frame))
        let question = app.descendants(matching: .any).matching(identifier: "aimPointTraining.questionInfo").firstMatch
        let track = app.descendants(matching: .any).matching(identifier: "aimPointTraining.aimWheel").firstMatch
        XCTAssertTrue(track.exists)
        XCTAssertEqual(track.frame.width, 44, accuracy: 1)
        XCTAssertLessThanOrEqual(question.frame.maxY, track.frame.minY)
        XCTAssertLessThanOrEqual(track.frame.maxY, answer.frame.minY)
        try geometry(["aimPointTraining.questionInfo", "aimPointTraining.answerInfo", "aimPointTraining.aimWheel"], name: "2D-free-capacity-44-hit")
        capture("2D-free-answer-status-and-ruler")
    }

}

/// Information hierarchy evidence uses identical boards before and after migration.
final class PlanningInformationUITests: XCTestCase {
    private var app: XCUIApplication!
    private var phase = "before"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private func item(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element)], timeout: timeout), .completed)
    }
    private func snap(_ name: String) throws {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "pad" : (app.windows.firstMatch.frame.height < 390 ? "compact" : "phone")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/information-simplification-20261014/\(phase)/\(device)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        usleep(350_000)
        let screenshot = XCUIScreen.main.screenshot()
        if !["help", "details", "-plan", "guide-reopened"].contains(where: name.contains) {
            XCTAssertGreaterThan(tableGreenFraction(screenshot.image), 0.02,
                "The rendered table must remain visible even with no notice: " + name)
        }
        try screenshot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
        try app.debugDescription.write(to: root.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
        let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func tableGreenFraction(_ image: UIImage) -> Double {
        guard let image = image.cgImage else { return 0 }
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 64, height: 64, bitsPerComponent: 8,
                bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        var greenPixelCount = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let green = Double(pixels[index + 1])
            let other = max(Double(pixels[index]), Double(pixels[index + 2]))
            if green > other * 1.3 && green > 45 {
                greenPixelCount += 1
            }
        }
        return Double(greenPixelCount) / 4096
    }
    private func launch(_ page: String, scenario: String = "full", extraArgs: [String] = [], learned: Bool? = true) {
        app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        var args = ["-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system",
                    "-deeplink." + (page == "planthree" ? "planThree" : page)]
        if let learned { args += ["-\(page).informationLearned", learned ? "YES" : "NO"] }
        if page == "planthree" { args += ["-planThree.twoBall"] }
        if page == "snooker" { args += ["-snooker." + scenario] }
        app = XCUIApplication.launchClean(extraArgs: args + extraArgs)
        XCTAssertTrue(item(page + ".template").waitForExistence(timeout: 45))
        usleep(500_000)
        mode(page, "2D")
    }
    private func mode(_ page: String, _ mode: String) {
        ready(app.buttons[page + ".more"]); app.buttons[page + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let camera = app.buttons[page + ".cameraMode"]; ready(camera)
        if camera.value as? String != mode { camera.tap() }
        app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    }
    private func solve(_ page: String) {
        if page == "silu" {
            app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
            let table = item("table.scene")
            table.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4)).press(forDuration: 0.1,
                thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.77)))
        }
        if page != "snooker" { ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap() }
        ready(app.buttons[page + ".strike"])
    }
    func testBefore() throws { try capturePages() }
    func testAfter() throws { phase = "after"; try capturePages() }
    private func capturePages() throws {
        for page in ["planthree", "silu", "snooker"] {
            launch(page); try snap(page + "-initial")
            solve(page); try snap(page + "-solved")
            if page == "planthree" {
                try snap(page + "-plan")
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
            }
            if phase == "after" {
                XCTAssertFalse(item("planthree.rolesSummary").exists)
                let solution = app.buttons["solver.nextSolution"]
                XCTAssertTrue(solution.exists)
                XCTAssertTrue(solution.label.hasPrefix("解"))
                XCTAssertFalse(app.buttons["当前方案详情"].exists)
            }
            app.buttons["shotStage.spinEntry"].tap(); XCTAssertTrue(item("spinPad.disc").waitForExistence(timeout: 5))
            try snap(page + "-spin"); app.buttons["关闭打点"].tap()
            mode(page, "3D"); try snap(page + "-3d")
            if phase == "after" {
                app.buttons[page + ".strike"].tap(); ready(app.buttons[page + ".undo"])
                try snap(page + "-settled")
                app.buttons[page + ".undo"].tap(); ready(app.buttons[page + ".strike"])
                try snap(page + "-undo")
            }
        }
    }

    private func openHelp(_ page: String) {
        app.buttons[page + ".more"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let help = app.buttons[page + ".help"]
        let scroll = item("dailyClearance.menuScroll")
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<16 where !help.exists || !scroll.frame.contains(help.frame) {
            let above = help.exists && help.frame.minY < scroll.frame.minY
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.35 : 0.65))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.4, dy: above ? 0.65 : 0.35)))
        }
        XCTAssertTrue(help.exists && scroll.frame.contains(help.frame))
        ready(help); help.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(item("planning.help").waitForExistence(timeout: 5))
    }
    func testAdaptiveHelpAndSelection() throws {
        phase = "after"
        for page in ["planthree", "silu", "snooker"] {
            launch(page, extraArgs: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCUIDevice.shared.orientation = .portrait
                XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width
                }, object: nil)], timeout: 10), .completed)
            }
            try snap(page + "-maximum-type")
            openHelp(page); try snap(page + "-help-maximum-type")
            item("planning.help").swipeUp(); try snap(page + "-help-scrolled")
            app.buttons["planning.close"].tap()
            XCTAssertTrue(item(page + ".template").exists)
            if page == "planthree" {
                app.buttons["paletteBall__1"].tap()
                XCTAssertTrue((app.buttons["paletteBall__1"].value as? String ?? "").contains("当前击打球"))
                try snap("planthree-select-step")
            }
            mode(page, "3D")
            app.buttons["shotCamera.temporaryTopDown"].tap()
            try snap(page + "-temporary-maximum-type")
            app.buttons["shotCamera.temporaryTopDown"].tap()
        }
    }
    func testFailurePersistsAndFineTuningIsMarked() throws {
        phase = "r2/after"
        launch("snooker", scenario: "none")
        let status = item("snooker.status")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            status.exists && status.label.contains("未找到")
        }, object: nil)], timeout: 90), .completed)
        let reason = status.label; usleep(3_500_000)
        XCTAssertEqual(status.label, reason)
        try snap("snooker-no-solution-persistent")
        openHelp("snooker"); XCTAssertTrue(app.staticTexts["当前问题"].exists)
        try snap("snooker-failure-help"); app.buttons["planning.close"].tap()
        launch("silu"); solve("silu")
        app.buttons["shotStage.spinEntry"].tap()
        item("spinPad.disc").coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.42)).tap()
        app.buttons["关闭打点"].tap(); ready(app.buttons["silu.strike"])
        XCTAssertTrue((app.buttons["solver.nextSolution"].value as? String ?? "").contains("微调"))
        try snap("silu-adjusted")
    }

    func testFirstGuideDismissalIsRememberedAndHelpCanReopen() throws {
        phase = "after"
        launch("silu", learned: false)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: item("silu.status"))], timeout: 6), .completed)
        try snap("silu-first-guide-expired")
        launch("silu", learned: nil)
        XCTAssertFalse(item("silu.status").exists)
        openHelp("silu"); try snap("silu-guide-reopened")
        app.buttons["planning.close"].tap()
    }

    func testDefenseTargetMenuKeepsGroupAndCountReadable() throws {
        phase = "after"
        launch("snooker"); solve("snooker")
        app.buttons["snooker.tool"].tap()
        let summary = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "对方球组")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("花色"))
        XCTAssertTrue(summary.label.contains("1颗"))
        try snap("snooker-targets")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
        XCTAssertTrue(app.buttons["snooker.strike"].isEnabled)
    }
}

/// User-approved second pass: one visible solution count, no secondary solution menu.
final class InformationConsistencyUITests: XCTestCase {
    private var app: XCUIApplication!
    private var phase = "before"
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private func item(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement, timeout: TimeInterval = 90) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: timeout), .completed)
    }
    private func launch(_ page: String, maximum: Bool = false, scenario: String = "twoBall") {
        app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        var args = ["-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-3dDrag.probe",
                    "-planthree.informationLearned", "YES", "-silu.informationLearned", "YES", "-snooker.informationLearned", "YES"]
        if maximum { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        switch page {
        case "planthree": args += ["-deeplink.planThree", "-planThree." + scenario]
        case "silu": args += ["-deeplink.silu"]
        case "snooker": args += ["-deeplink.snooker", "-snooker.full"]
        case "composer": args += ["-dailyInteraction.sharedPage=composer"]
        case "freeplay": args += ["-deeplink.freePlay"]
        case "angleDynamic": args += ["-dailyInteraction.sharedPage=angleDynamic"]
        default: break
        }
        app = XCUIApplication.launchClean(extraArgs: args)
        if ["bankshot", "reflection"].contains(page) {
            app.switchTab(.angle); ready(app.buttons["angleHomeTab_解"]); app.buttons["angleHomeTab_解"].tap()
            let card = app.buttons[page == "bankshot" ? "翻袋解球" : "颗星解球"]; ready(card); card.tap()
        }
        let anchor = ["composer", "freeplay"].contains(page) ? page + ".landscape" : page + ".template"
        XCTAssertTrue(item(anchor).waitForExistence(timeout: 45))
        if !["composer", "freeplay"].contains(page) { mode(page, "2D") }
    }
    private func mode(_ page: String, _ mode: String) {
        let more = app.buttons[page + ".more"]; ready(more)
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let camera = app.buttons[page + ".cameraMode"]; ready(camera)
        if camera.value as? String != mode { camera.tap() }
        app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
    }
    private func snap(_ name: String) throws {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "pad" : (min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) < 390 ? "compact" : "phone")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/information-simplification-20261014/r2/\(phase)/\(device)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let hierarchy = app.debugDescription
        usleep(350_000) // Capture after the popover presentation transaction commits.
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: root.appendingPathComponent(name + ".png"))
        try hierarchy.write(to: root.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func solve(_ page: String) {
        if page == "silu" {
            app.buttons["silu.tool"].tap(); app.buttons["落区"].tap()
            let table = item("table.scene")
            table.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4)).press(forDuration: 0.1,
                thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.77)))
        }
        if ["planthree", "silu"].contains(page) { ready(app.buttons["solver.solve"]); app.buttons["solver.solve"].tap() }
        ready(app.buttons[page + ".strike"])
    }
    func testBefore() throws { try capturePages() }
    func testAfter() throws { phase = "after"; try capturePages() }
    private func capturePages() throws {
        for page in ["planthree", "silu", "snooker", "bankshot", "reflection"] {
            launch(page); solve(page); try snap(page + "-solved")
            if page == "planthree" {
                ready(app.buttons["paletteBall__1"]); try snap(page + "-roles")
                if phase == "after" {
                    XCTAssertTrue((app.buttons["paletteBall__1"].value as? String ?? "").contains("当前击打球"))
                    XCTAssertFalse(app.buttons["planthree.role.4"].exists, "One/two-ball fixtures have no third slot")
                }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
            }
            if phase == "after" {
                let next = app.buttons["solver.nextSolution"]
                XCTAssertTrue(next.label.hasPrefix("解1/"))
                let count = Int(next.label.split(separator: "/").last!)!
                if count > 1 {
                    next.tap(); XCTAssertEqual(next.label, "解2/\(count)")
                    for _ in 1..<count { next.tap() }
                    XCTAssertEqual(next.label, "解1/\(count)")
                    next.press(forDuration: 1)
                    XCTAssertFalse(app.buttons["当前方案详情"].exists)
                    XCTAssertFalse(app.buttons["solver.selectSolution.0"].exists)
                } else { XCTAssertFalse(next.isEnabled) }
                try snap(page + "-simple-control")
            }
            mode(page, "3D"); try snap(page + "-3d")
        }
        for page in ["composer", "freeplay", "angleDynamic"] {
            launch(page); try snap(page + "-initial")
            if phase == "after" {
                let redundant = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "进袋 ·"))
                XCTAssertEqual(redundant.count, 0)
            }
        }
    }
    func testRolePromptExpiresAndMenuRemainsReadable() throws {
        phase = "after"
        launch("planthree"); solve("planthree")
        ready(app.buttons["paletteBall__1"]); try snap("planthree-roles")
        launch("planthree", maximum: true)
        XCTAssertEqual(app.buttons["solver.nextSolution"].label, "解")
        XCTAssertFalse(app.buttons["solver.nextSolution"].isEnabled)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width
            }, object: nil)], timeout: 10), .completed)
        }
        ready(app.buttons["paletteBall__1"]); try snap("planthree-roles-maximum")
        let menuScroll = app.popovers.firstMatch.scrollViews.firstMatch
        if menuScroll.exists {
            menuScroll.swipeUp(); try snap("planthree-roles-maximum-bottom")
            menuScroll.swipeDown()
        }
        app.buttons["paletteBall__1"].press(forDuration: 1)
        app.buttons["清除此项"].tap()
        app.buttons["solver.solve"].tap()
        let status = item("planthree.status")
        XCTAssertTrue(status.waitForExistence(timeout: 2)); XCTAssertTrue(status.label.contains("当前球"))
        try snap("planthree-prompt")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: status)], timeout: 6), .completed)
        try snap("planthree-prompt-expired")
        app.buttons["solver.solve"].tap()
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        mode("planthree", "3D"); app.buttons["shotCamera.temporaryTopDown"].tap(); try snap("planthree-temporary")
        launch("planthree", scenario: "twoBallDimmed"); try snap("planthree-user-region")
    }
}

/// Native palette placement: the preview's projected centre must survive release.
final class PalettePlacementUITests: XCTestCase {
    private var app: XCUIApplication!
    private var phase = "before"
    private var page = ""
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }
    private func item(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func ready(_ e: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: e)], timeout: 60), .completed)
    }
    private var folder: URL {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "pad" : (min(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height) < 390 ? "compact" : "phone")
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/palette-drag-20261014/\(phase == "after" ? "after-real" : phase)/\(device)")
    }
    private func snap(_ name: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ax = app.debugDescription; usleep(300_000)
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: folder.appendingPathComponent(page + "-" + name + ".png"))
        try ax.write(to: folder.appendingPathComponent(page + "-" + name + ".txt"), atomically: true, encoding: .utf8)
    }
    private func probe() throws -> [String: Any] {
        let raw = try XCTUnwrap(item("table.scene").value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func launch(_ route: String, maximum: Bool = false) {
        app?.terminate(); XCUIDevice.shared.orientation = .landscapeLeft
        let prefix = ["bank": "bankshot", "diamond": "reflection", "separation": "separationAngleAtlas", "cushion": "cushionEnglishAtlas", "shot": "shotSimulation", "batch": "batchAuthor"]
        page = prefix[route] ?? route
        var args = ["-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-appearanceMode", "system", "-3dDrag.probe", "-planthree.informationLearned", "YES", "-silu.informationLearned", "YES", "-snooker.informationLearned", "YES"]
        if maximum { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if ["planthree", "silu", "snooker"].contains(route) {
            args += ["-deeplink." + (route == "planthree" ? "planThree" : route)]
            if route == "planthree" { args += ["-planThree.twoBall"] }
        } else { args += ["-dailyInteraction.sharedPage=" + route] }
        app = XCUIApplication.launchClean(extraArgs: args)
        XCTAssertTrue(item("table.scene").waitForExistence(timeout: 45))
        let more = app.buttons[page + ".more"]
        if more.exists && !["composer", "shotSimulation", "batchAuthor"].contains(page) {
            more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); let mode = app.buttons[page + ".cameraMode"]; ready(mode)
            if mode.value as? String != "2D" { mode.tap() }
            app.buttons[page + ".dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
        }
    }
    private func drag(_ suffix: String = "drop", nearRail: Bool = false) throws {
        let key = try XCTUnwrap((1...15).map { "_\($0)" }.first {
            let e = item("paletteBall_" + $0)
            return e.exists && e.isEnabled && (e.value as? String) == "未在桌上"
        })
        let palette = item("paletteBall_" + key); ready(palette)
        let table = item("table.scene")
        let p = try probe()
        let rect = try XCTUnwrap(p["displayedTable"] as? [Double])
        let window = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let end = window.withOffset(CGVector(dx: rect[0] + (rect[2] - rect[0]) * (nearRail ? 0.015 : 0.62), dy: rect[1] + (rect[3] - rect[1]) * 0.65))
        try snap(suffix + "-start")
        let started = Date().timeIntervalSince1970
        palette.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.2, thenDragTo: end, withVelocity: 150, thenHoldForDuration: 1.5)
        let finished = Date().timeIntervalSince1970
        try snap(suffix + "-end")
        let result = try probe()
        let event: [String: Any] = ["start": started, "end": finished, "key": key, "probe": result, "tableFrame": [table.frame.minX, table.frame.minY, table.frame.width, table.frame.height]]
        try JSONSerialization.data(withJSONObject: event, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent(page + "-" + suffix + ".json"))
        if phase == "after" {
            XCTAssertTrue(["在桌上", "本轮可击打"].contains(palette.value as? String ?? ""))
            let preview = try XCTUnwrap(result["palettePlacement"] as? [String: Any])
            let expected = try XCTUnwrap(preview["screen"] as? [Double])
            let balls = try XCTUnwrap(result["balls"] as? [[String: Any]])
            let ball = try XCTUnwrap(balls.first { $0["key"] as? String == key })
            let actual = try XCTUnwrap(ball["screen"] as? [Double])
            XCTAssertEqual(actual[0], expected[0], accuracy: 1)
            XCTAssertEqual(actual[1], expected[1], accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(preview["diameter"] as? Double), try XCTUnwrap(ball["diameter"] as? Double), accuracy: 0.5)
        }
    }
    func testBefore() throws {
        for route in ["planthree", "angleDynamic", "composer", "bank"] { launch(route); try drag() }
        try prompts()
    }
    func testAfter() throws {
        phase = "after"
        for route in ["planthree", "angleDynamic", "composer", "bank", "diamond", "silu", "snooker", "separation", "cushion", "shot", "batch"] { launch(route); try drag() }
        try prompts()
    }
    func testAfterCompact() throws {
        phase = "after"
        for route in ["planthree", "angleDynamic", "composer"] { launch(route); try drag() }
        try prompts()
    }
    func testProjectionAndExtraction() throws {
        phase = "after"
        launch("planthree")
        item("table.scene").pinch(withScale: 1.4, velocity: 1)
        try drag("zoomed")
        item("table.scene").doubleTap()
        try drag("near-rail", nearRail: true)
        let more = app.buttons["planthree.more"]
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["planthree.cameraMode"].tap()
        app.buttons["planthree.dismissMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)).tap()
        ready(app.buttons["shotCamera.temporaryTopDown"]); app.buttons["shotCamera.temporaryTopDown"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.probe()["standardTemporaryTable"] as? Bool) == true
        }, object: nil)], timeout: 10), .completed)
        try drag("temporary")
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width
            }, object: nil)], timeout: 10), .completed)
            try drag("portrait-temporary")
        }
        app.terminate(); page = "extract"
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-extract.confirmDemo", "-3dDrag.probe", "-v51.followSystemAppearance", "-appearanceMode", "system"])
        app.switchTab(.angle); ready(app.buttons["angleHomeTab_打"]); app.buttons["angleHomeTab_打"].tap()
        let card = app.buttons["拍照建球形"]; ready(card); card.tap()
        XCTAssertTrue(item("table.scene").waitForExistence(timeout: 30))
        try drag("confirm")
    }

    func testComposerHostIntegration() throws {
        phase = "after"
        for route in ["composer", "batch"] {
            launch(route); page += "-integration"; try drag()
        }
    }

    func testTableDragAndPersistentHint() throws {
        phase = "after"
        launch("planthree")
        let initial = try probe()
        let before = try XCTUnwrap((initial["balls"] as? [[String: Any]])?.first { $0["key"] as? String == "_2" })
        let centre = try XCTUnwrap(before["screen"] as? [Double])
        let frame = item("table.scene").frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: frame.minX + centre[0], dy: frame.minY + centre[1]))
        let end = origin.withOffset(CGVector(dx: frame.minX + centre[0] - 60, dy: frame.minY + centre[1] - 20))
        try snap("table-drag-start")
        let started = Date().timeIntervalSince1970
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: 100, thenHoldForDuration: 1.5)
        let finished = Date().timeIntervalSince1970
        try snap("table-drag-end")
        let result = try probe()
        let after = try XCTUnwrap((result["balls"] as? [[String: Any]])?.first { $0["key"] as? String == "_2" })
        XCTAssertEqual(before["scale"] as? [Double], after["scale"] as? [Double])
        XCTAssertNotEqual(before["world"] as? [Double], after["world"] as? [Double])
        try JSONSerialization.data(withJSONObject: ["start": started, "end": finished, "before": initial, "probe": result], options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("planthree-table-drag.json"))
        app.terminate(); page = "snooker"
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-deeplink.snooker", "-snooker.none", "-snooker.informationLearned", "YES", "-v51.followSystemAppearance", "-appearanceMode", "system"])
        let status = item("snooker.status")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            status.exists && status.label.contains("未找到")
        }, object: nil)], timeout: 90), .completed)
        let reason = status.label
        usleep(3_500_000)
        XCTAssertEqual(status.label, reason)
        XCTAssertFalse(item("planning.dismissNotice").exists)
        try snap("persistent-hint")
    }

    private func prompts() throws {
        for maximum in [false, true] {
            launch("planthree", maximum: maximum)
            ready(app.buttons["paletteBall__1"]); app.buttons["paletteBall__1"].tap()
            XCTAssertTrue(item("planthree.status").waitForExistence(timeout: 2))
            if phase == "after" { XCTAssertFalse(item("planning.dismissNotice").exists) }
            try snap(maximum ? "prompt-maximum" : "prompt")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: item("planthree.status"))], timeout: 6), .completed)
        }
    }
}
