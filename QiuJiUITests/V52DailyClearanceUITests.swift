import XCTest

extension V52DailyClearanceUITests {
    func testDailyModeSwitchKeepsRendererAndTableHitCoordinates() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled", "-3dDrag.probe"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let table = app.descendants(matching: .any)["table.scene"].firstMatch
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        func probe() throws -> [String: Any] {
            let raw = try XCTUnwrap(table.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        }
        let initial = try probe()
        let rendererID = try XCTUnwrap(initial["rendererID"] as? String)
        let initialFrame = table.frame
        XCTAssertEqual(initialFrame.minX, stage.frame.minX, accuracy: 0.5)
        XCTAssertEqual(initialFrame.minY, stage.frame.minY, accuracy: 0.5)
        XCTAssertEqual(initialFrame.width, stage.frame.width, accuracy: 0.5)
        XCTAssertEqual(initialFrame.height, stage.frame.height, accuracy: 0.5)
        var savedCamera: [Double]?
        for index in 0..<3 {
            mode.tap()
            XCTAssertEqual(mode.value as? String, "3D")
            let perspective = try probe()
            XCTAssertEqual(perspective["rendererID"] as? String, rendererID, "Switch must not destroy the renderer")
            XCTAssertEqual(table.frame.minX, app.frame.minX, accuracy: 0.5)
            XCTAssertEqual(table.frame.minY, app.frame.minY, accuracy: 0.5)
            XCTAssertEqual(table.frame.width, app.frame.width, accuracy: 0.5)
            XCTAssertEqual(table.frame.height, app.frame.height, accuracy: 0.5)
            let camera = try XCTUnwrap(perspective["camera"] as? [Double])
            if let savedCamera {
                for (actual, expected) in zip(camera, savedCamera) { XCTAssertEqual(actual, expected, accuracy: 0.001) }
            } else { savedCamera = camera }
            snap(app, "stable-renderer-3d-\(index)")
            mode.tap()
            XCTAssertEqual(mode.value as? String, "2D")
            let topDown = try probe()
            XCTAssertEqual(topDown["rendererID"] as? String, rendererID)
            XCTAssertEqual(table.frame, initialFrame)
            let before = try XCTUnwrap(initial["balls"] as? [[String: Any]])
            let after = try XCTUnwrap(topDown["balls"] as? [[String: Any]])
            XCTAssertEqual(before.count, after.count)
            for (old, new) in zip(before, after) {
                XCTAssertEqual(old["key"] as? String, new["key"] as? String)
                XCTAssertEqual(old["world"] as? [Double], new["world"] as? [Double])
            }
            snap(app, "stable-renderer-2d-\(index)")
        }
        // Exercise the real hit-test after round trips, using rendered screen coordinates.
        let balls = try XCTUnwrap(try probe()["balls"] as? [[String: Any]])
        let ball = try XCTUnwrap(balls.first { ($0["key"] as? String) == "_1" })
        let point = try XCTUnwrap(ball["screen"] as? [Double])
        table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1])).tap()
        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            (status.value as? String ?? "").contains("目标_1")
        }, evaluatedWith: status)], timeout: 5), .completed)
    }
}

extension V52DailyClearanceUITests {
    func testSpinPadDragKeepsPointClearOfFingerInBothModes() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        for dimension in ["2D", "3D"] {
            if mode.value as? String != dimension { mode.tap() }
            app.buttons["shotStage.spinEntry"].tap()
            let disc = app.descendants(matching: .any)["spinPad.disc"].firstMatch
            XCTAssertTrue(disc.waitForExistence(timeout: 5))
            app.buttons["回中"].tap()
            XCTAssertEqual(disc.value as? String, "中心球")
            let away = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25))
            away.press(forDuration: 0.1, thenDragTo: away.withOffset(CGVector(dx: 20, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertEqual(disc.value as? String, "中心球", "Pickup and motion inside the clearance gate must not jump")
            let center = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 85, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.1)
            let moved = disc.value as? String ?? ""
            XCTAssertTrue(moved.contains("右"), moved)
            XCTAssertFalse(moved.contains("100%"), "Clearance travel must not become full spin")
            snap(app, "spin-finger-clearance-\(dimension.lowercased())")
            // A new pickup preserves the selected point, even from elsewhere on the disc.
            away.press(forDuration: 0.1, thenDragTo: away.withOffset(CGVector(dx: 20, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertEqual(disc.value as? String, moved)
            app.buttons["shotStage.spinEntry"].tap()
            app.buttons["shotStage.spinEntry"].tap()
            center.tap()
            XCTAssertEqual(disc.value as? String, "中心球", "Tap-to-select remains available after reopening")
            app.buttons["高杆增加 1%"].tap()
            XCTAssertEqual(disc.value as? String, "高1%")
            app.buttons["shotStage.spinEntry"].tap()
        }
    }
}

extension V52DailyClearanceUITests {
    private var dailyHUDEvidence: URL {
        let env = ProcessInfo.processInfo.environment
        return URL(fileURLWithPath: env["DAILY_HUD_EVIDENCE_DIR"] ?? env["TEST_RUNNER_DAILY_HUD_EVIDENCE_DIR"]
            ?? "/Users/song/projects/13.billiard_trainer/output/daily-hud-avoidance-20261005/standard-complete")
    }

    private func dailyHUDShot(_ name: String) throws {
        try FileManager.default.createDirectory(at: dailyHUDEvidence, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: dailyHUDEvidence.appendingPathComponent(name + ".png"))
    }

    private func holdDailyControl(_ control: XCUIElement, name: String) throws {
        try FileManager.default.createDirectory(at: dailyHUDEvidence, withIntermediateDirectories: true)
        try Data().write(to: dailyHUDEvidence.appendingPathComponent(name + ".hold"))
        let start = control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -1)),
                    withVelocity: .slow, thenHoldForDuration: 7)
    }

    func testDailyHUDAlignmentMenuAndFeedback() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        var app = launch(["-dailyClearance.fixture=closeup0", "-dailyClearance.fixtureSettled"])
        let more = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(more.waitForExistence(timeout: 20))
        let back = app.buttons["dailyClearance.back"], mode = app.buttons["freeplay.cameraMode"]
        XCTAssertEqual(back.frame.midY, more.frame.midY, accuracy: 0.5)
        XCTAssertEqual(back.frame.midY, mode.frame.midY, accuracy: 0.5)
        XCTAssertTrue(app.staticTexts["杆速"].exists)
        XCTAssertFalse(app.staticTexts["力度"].exists)
        try dailyHUDShot("hud-2d")
        more.tap()
        XCTAssertFalse(app.buttons["dailyClearance.rerackMenu"].exists)
        XCTAssertFalse(app.buttons["重新开球"].exists)
        let shooting = app.staticTexts["击球设置"], display = app.staticTexts["显示"]
        XCTAssertTrue(shooting.exists, app.debugDescription)
        XCTAssertTrue(display.exists, app.debugDescription)
        XCTAssertLessThan(shooting.frame.midY, display.frame.midY)
        try dailyHUDShot("settings-order")
        app.descendants(matching: .any)["freeplay.stage"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.8)).tap()
        try holdDailyControl(app.buttons["dailyClearance.strike"], name: "strike-pressed")
        // Releasing intentionally strikes; reset the input fixture before the next control.
        app.terminate()
        app = launch(["-dailyClearance.fixture=closeup0", "-dailyClearance.fixtureSettled"])
        XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout:20))
        try holdDailyControl(app.buttons["freeplay.cameraMode"], name: "mode-pressed")
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
        try holdDailyControl(app.buttons["shotStage.spinEntry"], name: "spin-pressed")
        try dailyHUDShot("spin-panel")
        app.terminate()
    }

    func testDailyCloseupSixPocketMatrix() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for index in 0..<6 {
            let app = launch(["-dailyClearance.fixture=closeup\(index)", "-dailyClearance.fixtureSettled"])
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: 20))
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 30), .completed)
            for mode in ["2d", "3d"] {
                if mode == "3d" { app.buttons["freeplay.cameraMode"].tap() }
                Thread.sleep(forTimeInterval: 0.8)
                try holdDailyControl(wheel, name: "pocket-\(index)-\(mode)-held")
                try dailyHUDShot("pocket-\(index)-\(mode)-released")
                if index == 0, mode == "2d" {
                    let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
                    stage.pinch(withScale:0.75,velocity:-1)
                    try holdDailyControl(wheel,name:"pocket-0-2d-zoomed-held")
                    stage.pinch(withScale:1.333333,velocity:1)
                }
            }
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    func testDailySpinTransparencySettingPersistsAcrossModesAndRelaunch() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled",
                          "-dailyClearance.spinDiscTransparency", "0.5"])
        let menu = app.buttons["freeplay.moreMenu"]
        let slider = app.sliders["dailyClearance.spinTransparencySlider"]
        let done = app.buttons["dailyClearance.spinTransparencyDone"]
        func openSetting() {
            XCTAssertTrue(menu.waitForExistence(timeout: 15))
            menu.tap()
            let item = app.buttons["dailyClearance.spinTransparencyMenu"]
            XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
            item.tap()
            XCTAssertTrue(slider.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(slider.isHittable)
            XCTAssertGreaterThan(slider.frame.minX, app.frame.midX, "Settings stay by the upper-right entry")
            XCTAssertLessThan(slider.frame.maxY, app.frame.midY)
        }
        openSetting()
        XCTAssertEqual(slider.value as? String, "50%")
        snap(app, "spin-transparency-settings-default")
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(slider.value as? String, "100%")
        done.tap()
        XCTAssertTrue(app.descendants(matching: .any)["spinPad.card"].firstMatch.exists)
        snap(app, "spin-transparency-2d-clear")
        app.buttons["shotStage.spinEntry"].tap()
        openSetting()
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(slider.value as? String, "0%")
        done.tap()
        snap(app, "spin-transparency-2d-opaque")
        app.buttons["shotStage.spinEntry"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        if mode.value as? String != "3D" { mode.tap() }
        openSetting()
        XCTAssertEqual(slider.value as? String, "0%")
        slider.adjust(toNormalizedSliderPosition: 0.75)
        // SwiftUI's accessibility value can lag behind the native slider's drag completion.
        let adjustedValue = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let raw = (slider.value as? String ?? "").replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (70...80).contains(Int(raw) ?? -1)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [adjustedValue], timeout: 3), .completed,
                       "Slider should reach approximately 75%; actual: \(slider.value ?? "nil")")
        let savedValue = slider.value as? String
        let savedPercent = Int(savedValue?.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? -1
        XCTAssertTrue((70...80).contains(savedPercent), "Slider should reach approximately 75%")
        snap(app, "spin-transparency-settings-3d")
        done.tap()
        snap(app, "spin-transparency-3d-adjusted")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-dailyClearance.spinDiscTransparency" || $0 == "0.5" }
        app.launch()
        openSetting()
        XCTAssertEqual(slider.value as? String, savedValue)
        slider.adjust(toNormalizedSliderPosition: 0.5)
        done.tap()
    }

    func testCaptureDailySpinDiscOpacityComparison() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("build/daily-spin-opacity-20261005/capture.enabled").path) else {
            throw XCTSkip("Opt-in native spin disc appearance comparison")
        }
        let output = root.appendingPathComponent("output/daily-spin-opacity-20261005")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = .landscapeRight
        for transparency in [0, 25, 50, 75, 100] {
            let opacity = 1 - Double(transparency) / 100
            let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled",
                              "-dailyClearance.spinDiscOpacity=\(opacity)"])
            let mode = app.buttons["freeplay.cameraMode"]
            let entry = app.buttons["shotStage.spinEntry"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            for dimension in ["2D", "3D"] {
                if mode.value as? String != dimension { mode.tap() }
                XCTAssertEqual(mode.value as? String, dimension)
                XCTAssertTrue(entry.waitForExistence(timeout: 5))
                XCTAssertTrue(entry.isEnabled)
                XCTAssertGreaterThanOrEqual(entry.frame.width, 48)
                XCTAssertGreaterThanOrEqual(app.buttons["break.entry"].frame.width, 48)
                entry.tap()
                let card = app.descendants(matching: .any)["spinPad.card"].firstMatch
                XCTAssertTrue(card.waitForExistence(timeout: 5))
                XCTAssertTrue(app.buttons["高杆增加 1%"].isHittable)
                Thread.sleep(forTimeInterval: 1.2)
                let shot = XCUIScreen.main.screenshot()
                let name = "\(dimension.lowercased())-transparent-\(transparency)"
                try shot.pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
                entry.tap()
                XCTAssertTrue(card.waitForNonExistence(timeout: 3))
            }
            app.terminate()
        }
    }

    func testCaptureDailyCameraHUDBounds() throws {
        let base = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath:base.appendingPathComponent("build/daily-camera-factors-20260929/capture.enabled").path) else {
            throw XCTSkip("Opt-in camera HUD measurement")
        }
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress","-dailyClearance.cameraPreview"])
        XCTAssertTrue(app.buttons["cameraPreview.profile.1"].waitForExistence(timeout:20))
        Thread.sleep(forTimeInterval:2)
        app.buttons["cameraPreview.collapse"].tap()
        let out = base.appendingPathComponent("output/daily-camera-factors-20260929")
        func rect(_ r: CGRect) -> [CGFloat] { [r.minX,r.minY,r.width,r.height] }
        let ids = ["dailyClearance.singleRowPalette","dailyClearance.back","freeplay.cameraMode",
            "shotStage.aimWheel","shotStage.instrument","dailyClearance.strike","break.entry",
            "shotCamera.firstPerson","shotCamera.thirdPerson","dailyClearance.observeTable"]
        var controls: [[String:Any]] = []
        for id in ids {
            let element = app.descendants(matching:.any)[id].firstMatch
            if element.exists, element.frame.width>0, element.frame.height>0 {
                controls.append(["id":id,"frame":rect(element.frame)])
            }
        }
        XCTAssertGreaterThanOrEqual(controls.count,7)
        let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
        XCTAssertTrue(stage.exists)
        let data: [String:Any] = ["screen":rect(app.frame),"stage":rect(stage.frame),"controls":controls,
            "note":"Actual accessibility bounds, including transparent space; not opaque pixel coverage"]
        try JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("hud.json"))
        try XCUIScreen.main.screenshot().pngRepresentation.write(to:out.appendingPathComponent("hud-reference.png"))
    }

    func testDailyObserverPreviewComparison() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress", "-dailyClearance.cameraPreview", "-v63.cameraDiagnostics"])
        let profile = app.buttons["cameraPreview.profile.1"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20))
        let output = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/output/daily-camera-preview-20260929", isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func ready() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                evaluatedWith: profile)], timeout: 20), .completed)
            Thread.sleep(forTimeInterval: 1.1)
        }
        func capture(_ name: String) {
            let collapse = app.buttons["cameraPreview.collapse"]
            let expanded = collapse.label == "收起对照"
            if expanded { collapse.tap() }
            let shot = XCUIScreen.main.screenshot()
            try! shot.pngRepresentation.write(to: output.appendingPathComponent(name + ".png"))
            let value = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
            try! value.write(to: output.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
            if expanded { collapse.tap() }
        }
        ready()
        for (index, title) in ["长台远球", "短距离球", "大角度球", "母球近库"].enumerated() {
            app.buttons["cameraPreview.scenario"].tap()
            app.buttons[title].firstMatch.tap()
            ready()
            for p in 0..<3 {
                app.buttons["cameraPreview.profile.\(p)"].tap()
                ready()
                XCTAssertEqual(app.buttons["cameraPreview.profile.\(p)"].value as? String, "已选中")
                capture("scene-\(index)-profile-\(p)")
            }
        }
        app.buttons["cameraPreview.gesture"].tap()
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        for (name, from, to) in [
            ("right", CGVector(dx: 0.42, dy: 0.42), CGVector(dx: 0.60, dy: 0.43)),
            ("left", CGVector(dx: 0.60, dy: 0.42), CGVector(dx: 0.42, dy: 0.41)),
            ("up", CGVector(dx: 0.50, dy: 0.55), CGVector(dx: 0.51, dy: 0.33)),
            ("down", CGVector(dx: 0.50, dy: 0.33), CGVector(dx: 0.49, dy: 0.55))
        ] {
            stage.coordinate(withNormalizedOffset: from).press(forDuration: 0.15,
                thenDragTo: stage.coordinate(withNormalizedOffset: to))
            ready(); capture("gesture-\(name)")
        }
        stage.pinch(withScale: 1.3, velocity: 1); ready(); capture("gesture-zoom-in")
        stage.pinch(withScale: 0.7, velocity: -1); ready(); capture("gesture-zoom-out")
        app.buttons["cameraPreview.reset"].tap(); ready()
        app.buttons["cameraPreview.collapse"].tap()
        XCTAssertEqual(app.buttons["cameraPreview.collapse"].label, "展开对照")
        capture("collapsed")
    }
}

final class V52DailyClearanceUITests: XCTestCase {
    private var outDir: URL {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["V52_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V52_SHOT_DIR"]
            ?? "/Users/song/projects/13.billiard_trainer/build/v52-screenshots/after"
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private func launch(_ extra: [String], game: String = "chineseEightBall") -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: [
            "-deeplink.dailyClearance",
            "-dailyClearance.resetState",
            "-dailyClearance.preferredGame.v1", game
        ] + extra)
    }

    private func assertCenteredPalette(_ app: XCUIApplication, numbers: [Int]) {
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch.frame
        let targets = numbers.map { app.buttons["paletteBall__\($0)"].frame }
        let cue = app.buttons["paletteBall_cueBall"].frame
        XCTAssertEqual(stage.midX, app.frame.midX, accuracy: 0.5)
        for (left, right) in zip(targets, targets.reversed()) {
            XCTAssertEqual((left.midX + right.midX) / 2, stage.midX, accuracy: 0.5)
            XCTAssertEqual(left.midY, cue.midY, accuracy: 0.5)
            // Standard-screen faces are visibly larger; SE preserves its compact fit.
            XCTAssertEqual(left.width, app.frame.width < 740 ? 27 : 32, accuracy: 0.5)
        }
        XCTAssertLessThan(cue.maxX, targets.first!.minX)
        XCTAssertGreaterThanOrEqual(cue.minX, app.buttons["dailyClearance.back"].frame.maxX)
        XCTAssertLessThanOrEqual(targets.last!.maxX, app.buttons["freeplay.cameraMode"].frame.minX)
        let aim = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch.frame
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch.frame
        XCTAssertEqual(aim.height, 144, accuracy: 1)
        XCTAssertEqual(power.height, 144, accuracy: 1)
        XCTAssertEqual(aim.minY, power.minY, accuracy: 1)
        XCTAssertEqual(aim.maxY, power.maxY, accuracy: 1)
        XCTAssertEqual(app.buttons["break.entry"].frame.minY,
                       app.buttons["shotStage.spinEntry"].frame.minY, accuracy: 1)
        if app.buttons["freeplay.cameraMode"].value as? String == "3D" {
            let camera = app.buttons["shotCamera.temporaryTopDown"].frame
            XCTAssertGreaterThan(camera.minX, power.maxX)
            XCTAssertLessThanOrEqual(camera.maxX, app.frame.maxX)
        }
        let strike = app.buttons["dailyClearance.strike"].frame
        let instrument = app.descendants(matching: .any)["shotStage.instrument"].firstMatch.frame
        XCTAssertGreaterThanOrEqual(strike.minX, stage.maxX)
        XCTAssertEqual(strike.width, 60, accuracy: 0.5)
        // Keep half the former flexible gap; the table stage is lifted 8pt independently.
        let actionSpace = stage.maxY + 8 - 8 - instrument.maxY - 4
        XCTAssertEqual(strike.minY, instrument.maxY + 2 + max(0, actionSpace - 60) / 4, accuracy: 1)
        for (left, right) in zip(targets, targets.dropFirst()) {
            XCTAssertLessThanOrEqual(left.maxX, right.minX + 0.5)
        }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("截图写入失败：\(url.path)，\(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRerackDuringLiveBreakKeepsCueAtNewRack() {
        let app = launch(["-dailyClearance.fixture=manual", "-v63.cameraDiagnostics"])
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 15))
        if camera.value as? String != "3D" { camera.tap() }
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        XCTAssertTrue(strike.isEnabled)
        func assertAddress() {
            let value = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
            func number(_ name: String) -> Double? {
                value.split(separator: " ").first(where: { $0.hasPrefix(name + "=") })
                    .flatMap { Double($0.dropFirst(name.count + 1)) }
            }
            XCTAssertGreaterThan(number("cueAddressAlignment") ?? -1, 0.9999, value)
            XCTAssertLessThan(number("cueAddressDistance") ?? 100, 0.001, value)
            XCTAssertTrue(value.contains("cueAddressHidden=false"), value)
            XCTAssertEqual(number("cueAddressOpacity") ?? -1, 1, accuracy: 0.001, value)
        }
        for delay in [0, 1, 4] {
            // Deliberately turn the old shot away from the new rack's default.
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
            strike.tap()
            if delay > 0 { sleep(UInt32(delay)) }
            XCTAssertFalse(strike.isEnabled, "The preceding break must still be running")
            snap(app, "cue-restart-old-break-moving-\(delay)")
            app.buttons["break.entry"].tap()
            app.buttons["dailyClearance.rerackAfterBreak"].tap()
            XCTAssertTrue(strike.isEnabled)
            sleep(1)
            assertAddress()
            snap(app, "cue-restart-new-rack-\(delay)")
            sleep(2)
            assertAddress()
        }
        strike.tap()
        sleep(1)
        snap(app, "cue-restart-new-stroke")
    }

    func testFirstEntryWaitsForManualBreakAndAllowsInputChanges() {
        let app = launch([])
        let strike = app.buttons["dailyClearance.strike"]
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        XCTAssertTrue(strike.waitForExistence(timeout: 15))
        XCTAssertTrue(strike.isEnabled)
        let initialPower = power.value as? String
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
        XCTAssertNotEqual(power.value as? String, initialPower)
        let spin = app.buttons["shotStage.spinEntry"]
        spin.tap()
        app.buttons["高杆增加 1%"].tap()
        XCTAssertTrue(app.staticTexts["高1%"].waitForExistence(timeout: 3))
        spin.tap()
        XCTAssertTrue(strike.isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["dailyClearance.autoBreaking"].exists)
        snap(app, "manual-first-entry-adjusted")
    }

    func testNineBallDefaultWaitsForManualBreak() {
        let app = launch([], game: "nineBall")
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 15))
        XCTAssertTrue(strike.isEnabled)
        for number in 1...15 {
            XCTAssertEqual(app.buttons["paletteBall__\(number)"].exists, number <= 9)
        }
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        snap(app, "manual-nine-ball-ready")
    }

    func testRerackCancelAndConfirmKeepStageFrameStable() {
        let app = launch(["-dailyClearance.fixture=progress"])
        let stage = app.descendants(matching: .any)["freeplay.stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 12))
        let playingFrame = stage.frame

        let rerack = app.descendants(matching: .any)["break.entry"]
        XCTAssertTrue(rerack.waitForExistence(timeout: 5))
        rerack.tap()
        XCTAssertTrue(app.buttons["放弃并重新开球"].waitForExistence(timeout: 4))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 4))

        rerack.tap()
        XCTAssertTrue(app.buttons["放弃并重新开球"].waitForExistence(timeout: 4))
        app.buttons["放弃并重新开球"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.breakStatus"].waitForExistence(timeout: 6))
        XCTAssertEqual(stage.frame.width, playingFrame.width, accuracy: 0.5)
        XCTAssertEqual(stage.frame.height, playingFrame.height, accuracy: 0.5)
        snap(app, "v52-daily-manual-rack")
    }

    func testTemporaryGameChangeRequiresAbandonConfirmation() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress"])
        let menu = app.buttons["freeplay.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 12))
        menu.tap()
        XCTAssertTrue(app.buttons["临时换玩法"].waitForExistence(timeout: 4))
        app.buttons["临时换玩法"].tap()
        let nineBall = app.descendants(matching: .any)["dailyClearance.game.nineBall"]
        XCTAssertTrue(nineBall.waitForExistence(timeout: 4))
        nineBall.tap()
        XCTAssertTrue(app.buttons["放弃并切换"].waitForExistence(timeout: 4))
        app.buttons["放弃并切换"].tap()
        // The landscape HUD expresses the selected game through its fixed target roster.
        XCTAssertTrue(app.buttons["paletteBall__9"].waitForExistence(timeout: 6))
        for number in 1...15 {
            XCTAssertEqual(app.buttons["paletteBall__\(number)"].exists, number <= 9)
        }
        snap(app, "menu-game-change-confirmed")
    }

    func testCompletedReplayPreservesCompletionAndStartsAnotherBoard() {
        let app = launch(["-dailyClearance.fixture=completed"])
        let replay = app.buttons["dailyClearance.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 12))
        snap(app, "v52-daily-completed")
        replay.tap()
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        XCTAssertTrue(strike.isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        XCTAssertFalse(replay.exists)
        snap(app, "manual-replay-ready")
    }

    func testPerspectiveRoundTripsPreserveDailyProgress() {
        checkPerspectiveRoundTrips(arguments: [])
    }

    func testSpecializedPerspectiveRoundTripsAndBackground() {
        checkPerspectiveRoundTrips(arguments: ["-specializedRendering", "RS", "-renderProfileProbe"])
    }

    private func checkPerspectiveRoundTrips(arguments: [String]) {
        let app = launch(["-dailyClearance.fixture=progress"] + arguments)
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.exists)
        for _ in 0..<3 {
            camera.tap()
            XCTAssertEqual(camera.value as? String, "3D")
            XCTAssertTrue(hud.label.contains("2 杆"))
            XCTAssertTrue(hud.label.contains("1 次犯规"))
            app.buttons["freeplay.observation"].tap()
            app.buttons["freeplay.observe.table"].tap()
            snap(app, "v63-daily-3d-progress")
            camera.tap()
            XCTAssertEqual(camera.value as? String, "2D")
            XCTAssertTrue(hud.label.contains("2 杆"))
            XCTAssertTrue(hud.label.contains("1 次犯规"))
        }
        if arguments.contains("-renderProfileProbe") {
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(hud.waitForExistence(timeout: 12))
            XCTAssertTrue(hud.label.contains("2 杆"))
            let scene = app.descendants(matching: .any)["table.scene"].firstMatch
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value CONTAINS %@", "静止"), evaluatedWith: scene)], timeout: 15), .completed)
            XCTAssertNotNil((scene.value as? String ?? "").range(of: "reflection=[1-9][0-9]* shadow=[1-9][0-9]*", options: .regularExpression))
        }
        snap(app, "v63-daily-returned-progress")
    }

    func testManualRackRelaunchWaitsForPlayerIn3D() {
        let app = launch([], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 15))
        if camera.value as? String != "3D" { camera.tap() }
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        snap(app, "manual-rack-before-relaunch")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-dailyClearance.resetState" }
        app.launch()
        XCTAssertTrue(camera.waitForExistence(timeout: 15))
        if camera.value as? String != "3D" { camera.tap() }
        XCTAssertTrue(strike.isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["dailyClearance.autoBreaking"].exists)
        XCTAssertTrue(app.buttons["paletteBall__9"].exists)
        snap(app, "manual-rack-restored-3d")
    }

    /// Explicitly gated performance capture of the real 2D daily-clearance page.
    func testNormal2DShotPerformancePhases() throws {
        let gate = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/daily-performance-20260920/expanded/run-diagnostics")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: gate.path), "Explicit diagnostic run required")
        func phase(_ name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: ["phase": name, "unix": Date().timeIntervalSince1970])
            try data.write(to: outDir.appendingPathComponent("normal-shot-phase.json"), options: .atomic)
        }
        let app = launch([])
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 90))
        let camera = app.buttons["freeplay.cameraMode"]
        if camera.value as? String != "2D" { camera.tap() }
        XCTAssertEqual(camera.value as? String, "2D")
        app.buttons["瞄准模式：进袋，点击切换"].tap()
        let strike = app.buttons["击球"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 20), .completed)
        try phase("idle-before")
        Thread.sleep(forTimeInterval: 6)
        try phase("aiming")
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        XCTAssertTrue(wheel.exists)
        let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for delta in [12.0, -12.0] {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 20), .completed)
        try phase("pre-shot")
        Thread.sleep(forTimeInterval: 3)
        snap(app, "normal-2d-before-shot")
        try phase("playback")
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "1 杆"), evaluatedWith: hud)], timeout: 60), .completed)
        try phase("idle-after")
        Thread.sleep(forTimeInterval: 6)
        snap(app, "normal-2d-after-shot")
        try phase("finished")
    }

    /// Real page, not the isolated renderer: prove the activity state settles
    /// after both entry and a normal shot. This is not a thermal measurement.
    func testNormal2DShotReturnsToIdle() throws {
        // The normal 2D accessibility value omits the FPS readout.
        // This diagnostic flag exposes scheduling state without changing rendering.
        try checkNormal3DShotReturnsToIdle(arguments: ["-renderProfileProbe"], mode: "2D")
    }

    func testNormal3DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: [])
    }

    func testDaily3DDiagnosticsPreserveShotAndIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-daily3D.diagnostics"])
    }

    func testDaily3DDiagnosticsPreserveAimWheelResume() {
        checkAimWheelResume(arguments: ["-daily3D.diagnostics"])
    }

    func testDailyAimWheelResumesAndReturnsToIdle() {
        checkAimWheelResume(arguments: [])
    }

    func testClothPrototypeAimWheelResumesAndReturnsToIdle() {
        checkAimWheelResume(arguments: ["-dailyClearance.rendering", "RS", "-dailyClearance.clothPrototype"])
    }

    func testDailyBrightnessAimWheel() {
        checkAimWheelResume(arguments: ["-dailyClearance.rendering", "RS", "-dailyClearance.clothPrototype",
                                       "-dailyClearance.exposure", "-0.1"])
    }

    func testDailyReferenceShadowAndLensAimWheel() {
        checkAimWheelResume(arguments: ["-dailyClearance.rendering", "R", "-dailyClearance.clothPrototype",
                                       "-dailyClearance.exposure", "-0.1", "-dailyClearance.perspectivePrototype"])
    }

    private func checkAimWheelResume(arguments: [String]) {
        let evidencePrefix = arguments.contains("-daily3D.diagnostics") ? "daily3D-diagnostics-" : ""
        let app = launch(["-dailyClearance.fixtureSettled", "-renderProfileProbe"] + arguments)
        let pageState = app.descendants(matching: .any)["dailyClearance.landscape"]
        XCTAssertTrue(pageState.waitForExistence(timeout: 20))
        let aimMode = app.buttons["瞄准模式：进袋，点击切换"]
        if aimMode.exists { aimMode.tap() }
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        let scene = app.descendants(matching: .any)["table.scene"].firstMatch
        let camera = app.buttons["freeplay.cameraMode"]
        for mode in ["2D", "3D"] {
            if camera.value as? String != mode { camera.tap() }
            XCTAssertEqual(camera.value as? String, mode)
            let asleep = expectation(for: NSPredicate(format: "value CONTAINS %@", "调度=静止"), evaluatedWith: scene)
            XCTAssertEqual(XCTWaiter.wait(for: [asleep], timeout: 10), .completed)
            snap(app, "\(evidencePrefix)resume-\(mode)-before")
            let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 24)),
                withVelocity: .slow, thenHoldForDuration: 0.1)
            let settled = expectation(for: NSPredicate(format: "value CONTAINS %@", "调度=静止"), evaluatedWith: scene)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed)
            XCTAssertTrue(pageState.exists)
            XCTAssertTrue((pageState.value as? String ?? "").contains(mode))
            snap(app, "\(evidencePrefix)resume-\(mode)-after")
        }
    }

    func testBalancedSamplingNormal3DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-balancedRendering"])
    }

    func testSpecializedCompletedReplay() {
        let app = launch(["-dailyClearance.fixture=completed", "-dailyClearance.fixtureSettled", "-specializedRendering", "RS", "-renderProfileProbe"])
        let replay = app.buttons["dailyClearance.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 12))
        snap(app, "specialized-completed")
        replay.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 12))
        XCTAssertFalse(replay.exists)
        let scene = app.descendants(matching: .any)["table.scene"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value CONTAINS %@", "静止"), evaluatedWith: scene)], timeout: 15), .completed)
        XCTAssertNotNil((scene.value as? String ?? "").range(of: "reflection=[1-9][0-9]* shadow=[1-9][0-9]*", options: .regularExpression))
        snap(app, "specialized-replay")
    }

    func testSpecializedNormal3DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-specializedRendering", "RS", "-renderProfileProbe"])
    }

    func testSpecializedNormal2DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-specializedRendering", "RS", "-renderProfileProbe"], mode: "2D")
    }

    func testDailyShadowNormal2DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-dailyClearance.rendering", "S", "-renderProfileProbe"], mode: "2D")
    }

    func testDailyShadowNormal3DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-dailyClearance.rendering", "S", "-renderProfileProbe"])
    }

    func testDailyReflectionNormal3DShotReturnsToIdle() throws {
        try checkNormal3DShotReturnsToIdle(arguments: ["-dailyClearance.rendering", "R", "-renderProfileProbe"])
    }

    private func checkNormal3DShotReturnsToIdle(arguments: [String], mode: String = "3D") throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(arguments)
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        let acceptBreak = app.buttons["dailyClearance.confirmBreak"]
        XCTAssertTrue(acceptBreak.waitForExistence(timeout: 90))
        acceptBreak.tap()
        XCTAssertTrue(acceptBreak.waitForNonExistence(timeout: 5))
        XCTAssertTrue((hud.value as? String ?? "").components(separatedBy: "，").contains("0杆"))
        let camera = app.buttons["freeplay.cameraMode"]
        if camera.value as? String != mode { camera.tap() }
        XCTAssertEqual(camera.value as? String, mode)
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 10))
        let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 24)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue((hud.value as? String ?? "").contains("自由模式"))
        let fps = app.descendants(matching: .any)["table.scene"].firstMatch
        func expectIdle() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(
                for: NSPredicate(format: "value CONTAINS %@", "静止"), evaluatedWith: fps
            )], timeout: 15), .completed, "Real 3D page must settle its render activity")
        }
        expectIdle()
        if arguments.contains("-renderProfileProbe") {
            let value=fps.value as? String ?? ""
            let profile = arguments.firstIndex(of: "-dailyClearance.rendering").map { arguments[$0 + 1] } ?? "R"
            let reflection = profile == "S" ? "0" : "[1-9][0-9]*"
            let shadow = profile == "R" ? "0" : "[1-9][0-9]*"
            XCTAssertNotNil(value.range(of: "reflection=\(reflection) shadow=\(shadow)", options: .regularExpression), "Actual material profiles: \(value)")
        }
        let prefix = arguments.contains("-daily3D.diagnostics") ? "daily3D-diagnostics-" :
            (arguments.firstIndex(of: "-dailyClearance.rendering").map { "daily-\(arguments[$0 + 1])-" } ?? "normal-")
        snap(app, "\(prefix)\(mode.lowercased())-idle-before")
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertFalse(undo.isEnabled, "The automatic opening break does not create a player-shot undo")
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 20), .completed)
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: undo)], timeout: 60), .completed,
                       "A completed player shot must produce an undo snapshot")
        XCTAssertTrue((hud.value as? String ?? "").components(separatedBy: "，").contains("1杆"))
        expectIdle()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue((fps.value as? String)?.contains("静止") == true, "Idle state must persist after the shot")
        XCTAssertEqual(camera.value as? String, mode)
        snap(app, "\(prefix)\(mode.lowercased())-idle-after")
    }

    func testRealManualBreakDeliversAndRestoresIn3D() {
        let app = launch(["-dailyClearance.fixture=manual"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        XCTAssertEqual(camera.value as? String, "3D")
        let strike = app.buttons["break.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        XCTAssertTrue(strike.isEnabled)
        snap(app, "v63-daily-manual-ready-3d")
        XCTAssertFalse(app.buttons["取消"].exists, "An abandoned daily attempt cannot restore the previous board")
        app.buttons["break.rerack"].tap()
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=manual"
        }
        app.launch()
        XCTAssertTrue(strike.waitForExistence(timeout: 12))
        XCTAssertFalse(app.buttons["取消"].exists)
        if camera.value as? String != "3D" { camera.tap() }
        // This second rerack must deliver without a restart masking stale controller state.
        app.buttons["break.rerack"].tap()
        XCTAssertTrue(strike.waitForExistence(timeout: 8))
        strike.tap()
        let confirm = app.buttons["break.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 90))
        XCTAssertFalse(app.buttons["取消"].exists)
        snap(app, "v63-daily-manual-settled-3d")
        confirm.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("0 杆"))
        XCTAssertFalse(confirm.exists)
        XCTAssertTrue(app.buttons["击球"].exists)
        snap(app, "v63-daily-manual-delivered-3d")
        app.terminate()
        app.launchArguments.removeAll {
            $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=manual"
        }
        app.launch()
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("0 杆"))
        XCTAssertFalse(app.buttons["break.strike"].exists)
    }

    func testCompletedAndFailedResultsRemainUsableIn3D() {
        for state in ["completed", "failed"] {
            let app = launch(["-dailyClearance.fixture=" + state])
            let camera = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(camera.waitForExistence(timeout: 12))
            camera.tap()
            XCTAssertEqual(camera.value as? String, "3D")
            let action = app.buttons[state == "completed" ? "dailyClearance.replay" : "dailyClearance.rerack"]
            XCTAssertTrue(action.isHittable)
            XCTAssertGreaterThanOrEqual(action.frame.minY, 0)
            XCTAssertFalse(app.buttons["击球"].exists, "A finished daily attempt must not expose another shot")
            XCTAssertLessThanOrEqual(action.frame.maxY, app.frame.maxY)
            snap(app, "v63-daily-3d-" + state)
            camera.tap()
            XCTAssertTrue(action.isHittable)
            XCTAssertFalse(app.buttons["击球"].exists)
            camera.tap()
            XCTAssertTrue(action.isHittable)
            app.terminate()
        }
    }

    func testFinalNineBallPhysicallyCompletesAndReplays() {
        let app = launch(["-dailyClearance.fixture=lastBall"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        let strike = app.buttons["击球"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                      evaluatedWith: strike)], timeout: 30), .completed)
        snap(app, "v63-daily-last-ball-ready")
        strike.tap()
        let replay = app.buttons["dailyClearance.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 60), "The simulated final ball must reach completion")
        XCTAssertFalse(strike.exists)
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].label.contains("1 杆"))
        snap(app, "v63-daily-last-ball-completed")
        replay.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "0 杆"),
                                                      evaluatedWith: hud)], timeout: 90), .completed)
        XCTAssertFalse(replay.exists)
        XCTAssertEqual(camera.value as? String, "3D")
        snap(app, "v63-daily-new-rack-after-completion")
    }

    func testPhysicalScratchRestoresCueAndAllowsNextShot() {
        let app = launch(["-dailyClearance.fixture=scratch"], game: "nineBall")
        let camera = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(camera.waitForExistence(timeout: 12))
        camera.tap()
        let strike = app.buttons["击球"]
        func waitForStrike() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                          evaluatedWith: strike)], timeout: 30), .completed)
        }
        waitForStrike()
        snap(app, "v63-daily-scratch-ready")
        strike.tap()
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "1 次犯规"),
                                                      evaluatedWith: hud)], timeout: 60), .completed)
        waitForStrike()
        app.buttons["freeplay.observation"].tap()
        XCTAssertTrue(app.buttons["freeplay.observe.cue"].isEnabled, "The physically pocketed cue must be restored")
        app.buttons["freeplay.observe.table"].tap()
        snap(app, "v63-daily-scratch-cue-restored")
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label CONTAINS %@", "2 杆"),
                                                      evaluatedWith: hud)], timeout: 60), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=scratch" }
        app.launch()
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("2 杆"))
        snap(app, "v63-daily-scratch-resumed")
    }
}

extension V52DailyClearanceUITests {
    func testInteractionHUDPaletteAndTwoActionChoice() {
        for (game, numbers) in [("chineseEightBall", Array(1...15)), ("nineBall", Array(1...9)),
                                ("sixBall", [1,2,3,4,5,9]), ("fiveBall", [1,2,3,4,9]), ("fourBall", [1,2,3,9])] {
            let app = launch(["-dailyClearance.fixture=progress"], game: game)
            let toggle = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            let cue = app.buttons["paletteBall_cueBall"]
            XCTAssertTrue(cue.exists)
            for number in 1...15 {
                XCTAssertEqual(app.buttons["paletteBall__\(number)"].exists, numbers.contains(number), game)
            }
            XCTAssertEqual(cue.frame.midY, toggle.frame.midY, accuracy: 2)
            XCTAssertTrue(app.staticTexts["方向"].exists)
            XCTAssertFalse(app.staticTexts["松手击球"].exists)
            assertCenteredPalette(app, numbers: numbers)
            snap(app, "interaction-\(game)-2d")
            toggle.tap()
            XCTAssertEqual(toggle.value as? String, "3D")
            XCTAssertEqual(cue.frame.midY, toggle.frame.midY, accuracy: 2)
            assertCenteredPalette(app, numbers: numbers)
            snap(app, "interaction-\(game)-3d")
            app.buttons["break.entry"].tap()
            let again = app.buttons["dailyClearance.rerackAfterBreak"]
            let resume = app.buttons["dailyClearance.confirmBreak"]
            XCTAssertTrue(again.waitForExistence(timeout: 4))
            XCTAssertTrue(resume.exists)
            XCTAssertEqual(resume.label, "继续击球")
            XCTAssertFalse(app.buttons["取消"].exists)
            snap(app, "interaction-\(game)-choice")
            resume.tap()
            XCTAssertFalse(again.exists)
            app.terminate()
        }
    }

    func testLandscapeEntryPaletteAndPortraitReturn() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: [
            "-dailyClearance.seedHomeState=progress", "-dailyClearance.fixture=progress"
        ])
        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        snap(app, "landscape-home-before")
        entry.tap()
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 12))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            stage.frame.width > stage.frame.height * 1.5
        }, evaluatedWith: stage)], timeout: 8), .completed)
        XCTAssertFalse(app.descendants(matching: .any)["dailyClearance.hud"].exists)
        for id in ["break.entry", "dailyClearance.undo", "dailyClearance.playback", "dailyClearance.strike"] {
            XCTAssertTrue(app.buttons[id].exists, "Common action must stay visible: \(id)")
        }
        let balls = PositionPlayPaletteIDs.all.map { app.buttons[$0] }
        XCTAssertTrue(balls.allSatisfy(\.exists))
        let ys = balls.map { $0.frame.midY }
        XCTAssertLessThan((ys.max() ?? 0) - (ys.min() ?? 0), 2)
        snap(app, "landscape-table")
        app.buttons["freeplay.moreMenu"].tap()
        let trajectorySetting = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@", "dailyClearance.trajectoryMenu", "轨迹显示")).firstMatch
        XCTAssertTrue(trajectorySetting.waitForExistence(timeout: 3), app.debugDescription)
        snap(app, "landscape-menu")
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)).tap()
        app.buttons["freeplay.cameraMode"].tap()
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 8))
        XCTAssertTrue((hud.value as? String ?? "").contains("2 杆"))
        XCTAssertEqual(app.buttons["freeplay.cameraMode"].value as? String, "3D")
        XCTAssertGreaterThan(stage.frame.width, stage.frame.height * 1.5)
        snap(app, "landscape-3d")
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertTrue(app.buttons["dailyClearance.back"].waitForExistence(timeout: 8))
        app.buttons["dailyClearance.back"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            app.frame.height > app.frame.width
        }, evaluatedWith: app)], timeout: 8), .completed)
        snap(app, "landscape-home-return")
    }

    func testLandscapeFirstManualBreakBecomesShootable() {
        let app = launch([])
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 15))
        XCTAssertTrue(strike.isEnabled)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        snap(app, "manual-first-rack")
        strike.tap()
        waitForDailyBreakDelivery(app)
        snap(app, "landscape-break-direct-play")
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        XCTAssertTrue(power.waitForExistence(timeout: 20))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: power)], timeout: 60), .completed)
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertGreaterThan(stage.frame.width, stage.frame.height * 1.5)
        snap(app, "landscape-real-break")
        app.buttons["freeplay.cameraMode"].tap()
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 8))
        XCTAssertTrue((hud.value as? String ?? "").contains("1杆"), "Manual opening break counts as a played visit")
    }

    private func waitForDailyBreakDelivery(_ app: XCUIApplication) {
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            (hud.value as? String ?? "").components(separatedBy: "，").contains("1杆")
        }, evaluatedWith: nil)], timeout: 90), .completed)
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        XCTAssertFalse(app.buttons["dailyClearance.rerackAfterBreak"].exists)
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 40), .completed)
    }

    func testLandscapeManualRerackAfterAutomaticDelivery() {
        let app = launch(["-dailyClearance.fixture=progress"])
        XCTAssertTrue(app.buttons["break.entry"].waitForExistence(timeout: 15))
        let confirm = app.buttons["dailyClearance.rerackAfterBreak"]
        let resume = app.buttons["dailyClearance.confirmBreak"]
        let strike = app.buttons["dailyClearance.strike"]
        for attempt in 0..<2 {
            app.buttons["break.entry"].tap()
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            XCTAssertEqual(resume.label, "继续击球")
            snap(app, "manual-rerack-request-\(attempt)")
            if attempt == 1 {
                resume.tap()
                XCTAssertFalse(confirm.exists)
                XCTAssertTrue(strike.isEnabled)
                app.buttons["break.entry"].tap()
                XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            }
            confirm.tap()
            XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                evaluatedWith: strike)], timeout: 10), .completed)
            strike.tap()
            waitForDailyBreakDelivery(app)
            snap(app, "manual-rerack-delivered-\(attempt)")
        }
    }

    func testRuleAwareSelectionInBothDimensions() {
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        for dimension in ["2d", "3d"] {
            if dimension == "3d" { mode.tap() }
            XCTAssertTrue(diagnostics.waitForExistence(timeout: 5))
            func tap(_ key: String) {
                let values = (diagnostics.value as? String ?? "").components(separatedBy: "window_\(key)=")
                XCTAssertEqual(values.count, 2)
                guard values.count == 2 else { return }
                let coords = values[1].components(separatedBy: " ")[0].split(separator: ",").compactMap { Double($0) }
                XCTAssertEqual(coords.count, 3)
                guard coords.count == 3 else { return }
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: coords[0], dy: coords[1])).tap()
            }
            tap("_2")
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
                (status.value as? String ?? "").contains("目标_2")
            }, evaluatedWith: status)], timeout: 5), .completed)
            let before = status.value as? String
            tap("_9")
            XCTAssertTrue(app.staticTexts["请先击打全色球"].waitForExistence(timeout: 3))
            XCTAssertEqual(status.value as? String, before)
            snap(app, "selection-rejected-\(dimension)")
            tap("_1")
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
                (status.value as? String ?? "").contains("目标_1")
            }, evaluatedWith: status)], timeout: 5), .completed)
            snap(app, "selection-valid-\(dimension)")
        }
    }

    func testCueAccessRestrictsLowSpinInBothModes() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=cueAccess"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 15), .completed)
        snap(app, "cue-access-auto-default")
        for dimension in ["2d", "3d"] {
            if dimension == "3d" { mode.tap() }
            app.buttons["shotStage.spinEntry"].tap()
            let disc = app.descendants(matching: .any)["spinPad.disc"].firstMatch
            XCTAssertTrue(disc.waitForExistence(timeout: 5))
            XCTAssertFalse((disc.value as? String ?? "").isEmpty,"默认打点应可读取")
            let start = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 140)), withVelocity: .slow, thenHoldForDuration: 0.1)
            let selected = disc.value as? String ?? ""
            XCTAssertNotEqual(selected,"低100%","近库向下拖动必须停在可用区域：\(selected)")
            app.buttons["低杆增加 1%"].tap()
            XCTAssertEqual(disc.value as? String, selected)
            app.buttons["回中"].tap()
            XCTAssertEqual(disc.value as? String,"中心球","可行的中心点应保留，不能强制改成高杆")
            snap(app, "cue-access-\(dimension)")
            app.buttons["关闭打点"].tap()
        }
    }

    func testCueAccessNearFrozenHighSpin() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app=launch(["-dailyClearance.fixture=cueAccessHigh"])
        let mode=app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:15));mode.tap()
        app.buttons["shotStage.spinEntry"].tap()
        let disc=app.descendants(matching:.any)["spinPad.disc"].firstMatch
        XCTAssertTrue(disc.waitForExistence(timeout:5))
        let start = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Include the 52pt finger-clearance travel before reaching the spin limit.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -140)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(disc.value as? String,"高100%")
        snap(app,"cue-access-high-near-frozen-3d")
        app.buttons["关闭打点"].tap()
        XCTAssertTrue(app.buttons["dailyClearance.strike"].isEnabled)
    }

    func testCueAccessRearTouchingHighSpin() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app=launch(["-dailyClearance.fixture=cueAccessRear"])
        let mode=app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:15));mode.tap()
        app.buttons["shotStage.spinEntry"].tap()
        let disc=app.descendants(matching:.any)["spinPad.disc"].firstMatch
        XCTAssertTrue(disc.waitForExistence(timeout:5))
        let start = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Include the 52pt finger-clearance travel before reaching the spin limit.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -140)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(disc.value as? String,"高100%")
        snap(app,"cue-crown-rear-touching-high-3d")
        app.buttons["关闭打点"].tap()
        let strike=app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for:[expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:strike)],timeout:10),.completed)
    }

    func testCueAccessAllowsLowSpinWithRoomForElevation() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=cueAccessRoom"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:15))
        mode.tap()
        app.buttons["shotStage.spinEntry"].tap()
        let disc=app.descendants(matching:.any)["spinPad.disc"].firstMatch
        XCTAssertTrue(disc.waitForExistence(timeout:5))
        let start = disc.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Include the 52pt finger-clearance travel before reaching the spin limit.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 140)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertEqual(disc.value as? String,"低100%")
        snap(app,"cue-access-room-low-3d")
    }


    func testSpinPadCrossInBothModes() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress"])
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let windowControls = springboard.buttons["window-controls:com.xinkuan.qiuji"]
        if windowControls.exists {
            windowControls.tap()
            let zoom = springboard.buttons["Zoom-button"]
            if zoom.waitForExistence(timeout: 2) { zoom.tap() }
        }
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        var referenceFrames: [CGRect] = []
        for dimension in ["2d", "3d"] {
            if dimension == "3d" { mode.tap() }
            let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
            XCTAssertTrue(power.waitForExistence(timeout: 5))
            XCTAssertEqual(power.frame.height, 144, accuracy: 1)
            let entry = app.buttons["shotStage.spinEntry"]
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            let card = app.descendants(matching: .any)["spinPad.card"].firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            let up = app.buttons["高杆增加 1%"], down = app.buttons["低杆增加 1%"]
            let left = app.buttons["左塞增加 1%"], right = app.buttons["右塞增加 1%"]
            XCTAssertLessThan(up.frame.midY, left.frame.midY)
            XCTAssertGreaterThan(down.frame.midY, left.frame.midY)
            XCTAssertEqual(up.frame.midX, down.frame.midX, accuracy: 1)
            XCTAssertLessThan(left.frame.midX, up.frame.midX)
            XCTAssertGreaterThan(right.frame.midX, up.frame.midX)
            let frames = [card.frame, up.frame, down.frame, left.frame, right.frame]
            if dimension == "2d" {
                referenceFrames = frames
            } else {
                for (actual, expected) in zip(frames, referenceFrames) {
                    XCTAssertEqual(actual.minX, expected.minX, accuracy: 1)
                    XCTAssertEqual(actual.minY, expected.minY, accuracy: 1)
                    XCTAssertEqual(actual.width, expected.width, accuracy: 1)
                    XCTAssertEqual(actual.height, expected.height, accuracy: 1)
                }
            }
            XCTAssertEqual(card.frame.width, 264, accuracy: 1)
            XCTAssertEqual(card.frame.height, 264, accuracy: 1)
            snap(app, "spin-pad-layout-\(dimension)")
            // AX rect subtraction can yield 43.99999999999997 for a 44pt frame.
            for key in [up, down, left, right] {
                XCTAssertEqual(key.frame.height, 44, accuracy: 0.001)
                XCTAssertEqual(key.frame.width, 44, accuracy: 0.001)
            }
            XCTAssertGreaterThanOrEqual(card.frame.minY, 0)
            XCTAssertLessThanOrEqual(card.frame.maxY, app.frame.maxY)
            up.tap()
            snap(app, "spin-pad-nudge-\(dimension)")
            XCTAssertTrue(app.staticTexts["高1%"].waitForExistence(timeout: 3), app.debugDescription)
            app.buttons["回中"].tap()
            XCTAssertTrue(app.staticTexts["中心球"].exists)
            snap(app, "spin-pad-\(dimension)")
            entry.tap()
            XCTAssertTrue(card.waitForNonExistence(timeout: 3))
        }
    }

    func testFixedPlayerViewsAndFirstPersonShotTransition() {
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        let first = app.buttons["shotCamera.firstPerson"], third = app.buttons["shotCamera.thirdPerson"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let strike = app.buttons["dailyClearance.strike"]
        func ready() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                evaluatedWith: strike)], timeout: 12), .completed)
        }
        ready()
        first.tap()
        ready()
        XCTAssertEqual(first.value as? String, "已选中")
        snap(app, "camera-first-person")
        third.tap()
        ready()
        XCTAssertEqual(third.value as? String, "已选中")
        snap(app, "camera-third-person")
        first.tap()
        ready()
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "已选中"),
            evaluatedWith: third)], timeout: 10), .completed)
        snap(app, "camera-first-shot-standing")
        ready()
        XCTAssertEqual(third.value as? String, "已选中")
        mode.tap()
        mode.tap()
        XCTAssertEqual(third.value as? String, "已选中")
        snap(app, "camera-round-trip")
    }

    func testLandscape3DManualBreakDeliversWithoutPrompt() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        app.buttons["break.entry"].tap()
        let confirm = app.buttons["dailyClearance.rerackAfterBreak"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 10), .completed)
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
        XCTAssertTrue(strike.isEnabled, "Releasing break power must leave the rack ready to strike")
        XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)
        strike.tap()
        waitForDailyBreakDelivery(app)
        snap(app, "landscape-3d-break-direct-play")
        XCTAssertEqual(mode.value as? String, "3D")
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertGreaterThan(stage.frame.width, stage.frame.height * 1.5)
        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue((status.value as? String ?? "").components(separatedBy: "，").contains("1杆"),
                      "A manual opening break counts as a played visit")
    }

    func testLandscape3DCameraAndShot() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        mode.tap()
        XCTAssertEqual(mode.value as? String, "3D")
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertGreaterThan(stage.frame.width, stage.frame.height * 1.5)
        let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 8))
        func field(_ name: String) -> String {
            let text = diagnostics.value as? String ?? ""
            let prefix = "\(name)="
            return text.split(separator: " ").first { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) } ?? ""
        }
        let yaw = field("yaw")
        XCTAssertTrue(Double(yaw)?.isFinite == true, "A numeric camera yaw is required")
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.16))
            .press(forDuration: 0.1, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.16)))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in field("yaw") != yaw }, evaluatedWith: diagnostics)], timeout: 6), .completed)
        let fov = field("fov")
        XCTAssertTrue(Double(fov)?.isFinite == true, "A numeric field of view is required")
        stage.pinch(withScale: 1.3, velocity: 1)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in field("fov") != fov }, evaluatedWith: diagnostics)], timeout: 6), .completed)
        snap(app, "landscape-3d-camera")
        let manualYaw = field("yaw")
        // Read projected world balls, then tap the real scene (no test-only action).
        func tapBall(_ key: String) {
            let coordinates = field("window_\(key)").split(separator: ",").compactMap { Double($0) }
            XCTAssertEqual(coordinates.count, 3, diagnostics.value as? String ?? "")
            guard coordinates.count == 3 else { return }
            XCTAssertTrue(coordinates[2] > 0 && coordinates[2] < 1)
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: coordinates[0] - app.frame.minX, dy: coordinates[1] - app.frame.minY)).tap()
        }
        // The progress fixture's legal object ball is _1; the black is not yet a legal target.
        let targetPoint = field("window__1").split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(targetPoint.count, 3, diagnostics.value as? String ?? "")
        guard targetPoint.count == 3 else { return }
        XCTAssertTrue(stage.frame.insetBy(dx: 20, dy: 20).contains(CGPoint(x: targetPoint[0], y: targetPoint[1])),
                      "The target and stage must share window coordinates")
        tapBall("_1")
        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue((status.value as? String ?? "").components(separatedBy: "，").contains("目标_1"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in field("yaw") != manualYaw }, evaluatedWith: diagnostics)], timeout: 6), .completed)
        // Wait for the existing transition and a diagnostic refresh.
        Thread.sleep(forTimeInterval: 1.2)
        snap(app, "landscape-3d-target-view")
        tapBall("cueBall")
        Thread.sleep(forTimeInterval: 1.2)
        snap(app, "landscape-3d-cue-view")
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue((status.value as? String ?? "").components(separatedBy: "，").contains("0杆"))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 30), .completed)
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
            (status.value as? String ?? "").components(separatedBy: "，").contains("1杆")
        }, evaluatedWith: status)], timeout: 40), .completed)
        XCTAssertEqual(mode.value as? String, "3D")
        snap(app, "landscape-3d-shot")
        mode.tap()
        XCTAssertEqual(mode.value as? String, "2D")
        XCTAssertTrue((status.value as? String ?? "").components(separatedBy: "，").contains("1杆"))
    }

    func testFixedPowerAdjustsWithoutFiring() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=progress"])
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(power.waitForExistence(timeout: 15))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 15), .completed)
        let initialStatus = status.value as? String
        let initialPower = power.value as? String
        XCTAssertEqual(power.frame.height, 144, accuracy: 1)
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        XCTAssertNotEqual(power.value as? String, initialPower)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 15), .completed)
        XCTAssertEqual(status.value as? String, initialStatus, "Adjusting power must not advance the game")
        XCTAssertTrue(power.isEnabled)
        snap(app, "fixed-power-adjusted")
    }

    func testLandscapePowerCancelAndRelease() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled", "-v63.cameraDiagnostics"])
        func shotCount() -> Int? {
            let diagnostic = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
            let raw = diagnostic.value as? String ?? ""
            return raw.split(separator: " ").first { $0.hasPrefix("dailyShotCount=") }
                .flatMap { Int($0.split(separator: "=").last ?? "") }
        }
        let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
        XCTAssertTrue(power.waitForExistence(timeout: 15))
        // The old progress fixture places cue.y at 0.50 and black.y at 0.56,
        // outside the legal ball-center range. Use the shared legal selection board.
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 15), .completed)
        let from = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let cancel = power.coordinate(withNormalizedOffset: CGVector(dx: -1.2, dy: 0.45))
        from.press(forDuration: 0.1, thenDragTo: cancel)
        app.buttons["freeplay.cameraMode"].tap()
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 8))
        XCTAssertEqual(shotCount(), 0, "Dragging outside cancels the shot")
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertTrue(power.waitForExistence(timeout: 8))
        let end = power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        from.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(shotCount(), 0, "Release adjusts power without firing")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 15), .completed)
        XCTAssertEqual(shotCount(), 0, "Finishing the solve cannot fire")
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: power)], timeout: 10), .completed)
        snap(app, "landscape-shot-playing")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: power)], timeout: 35), .completed)
        app.buttons["freeplay.cameraMode"].tap()
        XCTAssertTrue(hud.waitForExistence(timeout: 8))
        XCTAssertEqual(shotCount(), 1, "The strike button fires exactly one actual shot")
        snap(app, "landscape-shot-finished")
    }
}

extension V52DailyClearanceUITests {
    func testRuleCompletionInBothGamesAndDimensions() {
        for (game, threeD) in [("chineseEightBall", false), ("nineBall", true)] {
            let app = launch(["-dailyClearance.fixture=lastBall"], game: game)
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            if threeD { mode.tap() }
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 30), .completed)
            snap(app, "rules-\(game)-ready")
            strike.tap()
            let again = app.buttons["dailyClearance.replay"]
            XCTAssertTrue(again.waitForExistence(timeout: 60))
            XCTAssertTrue(again.isHittable)
            XCTAssertEqual(again.frame.midY, app.frame.midY, accuracy: 65, "带操作的清台结果与确认选项统一在屏幕正中")
            XCTAssertGreaterThan(again.frame.width, 44)
            XCTAssertFalse(app.buttons["dailyClearance.undo"].isEnabled)
            snap(app, "rules-\(game)-complete")
            app.terminate()
        }
    }

    func testUndoAndRerackDuringStrokeAreTransactional() {
        let app = launch(["-dailyClearance.fixture=selection"])
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 15))
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        func ready() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 40), .completed)
        }
        ready()
        strike.tap()
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: undo)], timeout: 60), .completed)
        XCTAssertTrue((hud.value as? String ?? "").contains("1 杆"))
        undo.tap()
        XCTAssertTrue((hud.value as? String ?? "").contains("0 杆"))
        ready()
        strike.tap()
        app.buttons["break.entry"].tap()
        let rerack = app.buttons["dailyClearance.rerackAfterBreak"]
        XCTAssertTrue(rerack.waitForExistence(timeout: 5))
        rerack.tap()
        ready()
        // Wait beyond the old physical playback; it must not increment the new attempt.
        let stable = expectation(for: NSPredicate { _, _ in (hud.value as? String ?? "").contains("1 杆") }, evaluatedWith: hud)
        stable.isInverted = true
        wait(for: [stable], timeout: 8)
        XCTAssertTrue((hud.value as? String ?? "").contains("0 杆"))
        snap(app, "rules-rerack-during-stroke")
    }

}

extension V52DailyClearanceUITests {
    func testCameraPresetsZoomManualOwnershipAndSpinPad() {
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15)); mode.tap()
        let strike = app.buttons["dailyClearance.strike"]
        func ready() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 30), .completed)
        }
        for id in ["shotCamera.firstPerson", "shotCamera.thirdPerson"] {
            app.buttons[id].tap(); ready()
            app.buttons["shotStage.spinEntry"].tap()
            let card = app.otherElements["spinPad.card"].firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 4))
            XCTAssertGreaterThanOrEqual(card.frame.minY, app.frame.minY)
            XCTAssertLessThanOrEqual(card.frame.maxY, app.frame.maxY)
            snap(app, "preset-pad-\(id)")
            app.buttons["shotStage.spinEntry"].tap()
            XCTAssertTrue(card.waitForNonExistence(timeout: 4))
        }
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.1)))
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "未选中"),
            evaluatedWith: app.buttons["shotCamera.thirdPerson"])], timeout: 5), .completed)
        let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        func field(_ name: String) -> Double {
            let value = diagnostics.value as? String ?? ""
            return Double(value.components(separatedBy: "\(name)=").last?.components(separatedBy: " ").first ?? "") ?? -1
        }
        stage.pinch(withScale: 3, velocity: 1)
        snap(app, "camera-zoom-near")
        stage.pinch(withScale: 0.2, velocity: -1)
        snap(app, "camera-zoom-far-limit")
        ready()
        // Diagnostics refresh independently of gestures. Capture the completed observation,
        // after both pinch gestures, before testing whether the shot changes it.
        Thread.sleep(forTimeInterval: 1.2)
        let yaw = field("yaw")
        strike.tap(); ready()
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(field("yaw"), yaw, accuracy: 0.02, "Manual observation is retained after the shot")
        XCTAssertEqual(app.buttons["shotCamera.thirdPerson"].value as? String, "未选中")
    }
}

private enum PositionPlayPaletteIDs {
    static let all = ["paletteBall_cueBall"] + (1...15).map { "paletteBall__\($0)" }

}

extension V52DailyClearanceUITests {
    func testRuleSelectionPromptMatrix() {
        let cases: [(String, String, String, String)] = [
            ("selectionStripe", "chineseEightBall", "_1", "请先击打花色球"),
            ("selection", "chineseEightBall", "_8", "先打完全色球，再打黑八"),
            ("selectionOpen", "chineseEightBall", "_8", "尚未定组，请选全色或花色球"),
            ("selectionBlack", "chineseEightBall", "_9", "本组已清空，请击打黑八"),
            ("selectionNine", "nineBall", "_9", "先碰1号球，可组合进9"),
            ("selectionNine", "sixBall", "_2", "请先碰1号球"),
            ("selectionNine", "fiveBall", "_2", "请先碰1号球"),
            ("selectionNine", "fourBall", "_9", "先碰1号球，可组合进9")
        ]
        for (fixture, game, key, message) in cases {
            let app = launch(["-dailyClearance.fixture=\(fixture)"], game: game)
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            let state = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
            for dimension in ["2d", "3d"] {
                if dimension == "3d" { mode.tap() }
                let before = state.value as? String
                app.buttons["paletteBall_\(key)"].tap()
                XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 4))
                XCTAssertFalse(app.staticTexts["dailyClearance.turn"].exists, "球库承担当前球组状态，无常驻文字")
                XCTAssertEqual(state.value as? String, before, "非法选球不能改变目标或袋口")
                snap(app, "prompt-\(fixture)-\(game)-\(dimension)")
            }
            app.terminate()
        }
    }

    func testSharedInteractiveInstruments() {
        XCUIDevice.shared.orientation = .portrait
        let pages: [(String, String)] = [
            ("-deeplink.freePlay", "freeplay"),
            ("-dailyInteraction.sharedPage=shot", "shotSimulation"),
            ("-dailyInteraction.sharedPage=bank", "bankshot"),
            ("-dailyInteraction.sharedPage=diamond", "reflection"),
            ("-dailyInteraction.sharedPage=cushion", "cushionEnglishAtlas"),
            ("-dailyInteraction.sharedPage=separation", "separationAngleAtlas"),
            ("-deeplink.planThree", "planthree"),
            ("-deeplink.silu", "silu"),
            ("-deeplink.snooker", "snooker"),
            ("-dailyInteraction.sharedPage=composer", "composer")
        ]
        let pageFilter = ProcessInfo.processInfo.environment["SHARED_PAGE"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SHARED_PAGE"]
        for (argument, prefix) in pages where pageFilter == nil || prefix == pageFilter {
            let app = XCUIApplication.launchClean(extraArgs: [argument])
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let windowControls = springboard.buttons["window-controls:com.xinkuan.qiuji"]
            if windowControls.exists {
                windowControls.tap()
                let zoom = springboard.buttons["Zoom-button"]
                if zoom.waitForExistence(timeout: 2) { zoom.tap() }
            }
            let mode = app.buttons["\(prefix).cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 20), prefix)
            let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
            XCTAssertTrue(power.waitForExistence(timeout: 10), prefix)
            for dimension in ["2d", "3d"] {
                if dimension == "3d" { mode.tap() }
                XCTAssertTrue(power.isHittable, prefix)
                XCTAssertTrue(app.staticTexts["力度"].firstMatch.exists, prefix)
                snap(app, "shared-\(prefix)-\(dimension)")
                let spin = app.buttons["shotStage.spinEntry"].firstMatch
                if spin.exists && spin.isEnabled {
                    spin.tap()
                    let up = app.buttons["高杆增加 1%"]
                    XCTAssertTrue(up.waitForExistence(timeout: 3), prefix)
                    XCTAssertGreaterThanOrEqual(up.frame.height, 43.5, prefix)
                    up.tap()
                    snap(app, "shared-\(prefix)-pad-\(dimension)")
                    app.buttons["关闭打点"].firstMatch.tap()
                    XCTAssertTrue(up.waitForNonExistence(timeout: 3), prefix)
                }
            }
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    func testQuizAndBatchSharedControlsPreserveEditingSemantics() {
        XCUIDevice.shared.orientation = .portrait
        for page in ["aimpoint2d", "aimpoint3d"] {
            let app = XCUIApplication.launchClean(extraArgs: ["-dailyInteraction.sharedPage=\(page)"])
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            XCTAssertTrue(wheel.waitForExistence(timeout: 20))
            XCTAssertTrue(app.buttons["提交"].exists)
            wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(forDuration: 0.1, thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
            XCTAssertTrue(app.buttons["提交"].exists, "调方向不能替用户提交答案")
            snap(app, "shared-\(page)-direction")
            app.terminate()
        }
        let app = XCUIApplication.launchClean(extraArgs: ["-dailyInteraction.sharedPage=batch"])
        let entry = app.buttons["shotStage.spinEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        let up = app.buttons["高杆增加 1%"]
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        up.tap()
        snap(app, "shared-batch-pad")
        XCTAssertTrue(app.buttons["回中"].exists)
        app.buttons["关闭打点"].firstMatch.tap()
        XCTAssertTrue(up.waitForNonExistence(timeout: 3))
        snap(app, "shared-batch-editor")
    }
}

extension V52DailyClearanceUITests {
    func testRestoredBreakRulingRequiresChoiceAndGrantsBallInHand() {
        let app = launch(["-dailyClearance.fixture=weakBreak"])
        let accept = app.buttons["dailyClearance.ruleChoice.acceptBallInHand"]
        XCTAssertTrue(accept.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["开球未满足碰库要求"].exists)
        XCTAssertTrue(app.buttons["dailyClearance.ruleChoice.rerackByIncoming"].exists)
        XCTAssertTrue(app.buttons["dailyClearance.ruleChoice.rerackByBreaker"].exists)
        XCTAssertFalse(app.buttons["dailyClearance.strike"].isEnabled)
        snap(app, "rules-weak-break-restored")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "自由球")).firstMatch.waitForExistence(timeout: 4))
        app.launchArguments.removeAll { $0 == "-dailyClearance.resetState" || $0 == "-dailyClearance.fixture=weakBreak" }
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["freeplay.cameraMode"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["dailyClearance.ruleChoice.acceptBallInHand"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "自由球")).firstMatch.exists)
        snap(app, "rules-ball-in-hand-restored")
    }
}

extension V52DailyClearanceUITests {
    func testFeedbackSurfacesKeepStateAndDoNotStack() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-v54.forceLight", "-roomStyle.v1", "walnut"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let controls = springboard.buttons["window-controls:com.xinkuan.qiuji"]
        if controls.exists {
            controls.tap()
            let zoom = springboard.buttons["Zoom-button"]
            if zoom.waitForExistence(timeout: 2) { zoom.tap() }
        }
        var topDownNoticeFrame: CGRect?
        for dimension in ["2d", "3d"] {
            if dimension == "3d" { mode.tap() }
            let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
            let viewport = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
            let stageBefore = stage.frame
            XCTAssertGreaterThanOrEqual(stageBefore.height, viewport.frame.height - 44.5, "提示不得额外占据球桌高度")
            snap(app, "feedback-table-maximized-\(dimension)")
            app.buttons["paletteBall__9"].tap()
            let notice = app.staticTexts["请先击打全色球"]
            XCTAssertTrue(notice.waitForExistence(timeout: 4))
            if let topDownNoticeFrame {
                XCTAssertEqual(notice.frame.minY, topDownNoticeFrame.minY, accuracy: 0.5,
                               "3D提示必须和2D同高，不能跟随透视机位")
                XCTAssertEqual(notice.frame.midX, topDownNoticeFrame.midX, accuracy: 0.5)
            } else {
                topDownNoticeFrame = notice.frame
            }
            let turn = app.staticTexts["dailyClearance.turn"]
            XCTAssertFalse(turn.exists, "当前球组由球库表达，不常驻文字")
            XCTAssertEqual(stage.frame, stageBefore, "提示出现不得改变球桌布局")
            snap(app, "feedback-selection-\(dimension)")
            XCTAssertEqual(notice.frame.midX, stage.frame.midX, accuracy: 24)
            XCTAssertGreaterThanOrEqual(notice.frame.minY, app.buttons["paletteBall__9"].frame.maxY)
            XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "本轮可击打")
            XCTAssertNotEqual(app.buttons["paletteBall__9"].value as? String, "本轮可击打")
            app.buttons["break.entry"].tap()
            let resume = app.buttons["dailyClearance.confirmBreak"]
            XCTAssertTrue(resume.waitForExistence(timeout: 3))
            XCTAssertFalse(notice.exists, "决策面板不能叠加轻提示")
            XCTAssertFalse(turn.exists)
            XCTAssertTrue(resume.isHittable)
            XCTAssertGreaterThanOrEqual(resume.frame.height, 44)
            XCTAssertEqual(resume.frame.midY, app.frame.midY, accuracy: 24, "需要选择的操作保持屏幕正中")
            XCTAssertLessThan(resume.frame.width, 160)
            snap(app, "feedback-decision-\(dimension)")
            resume.tap()
            XCTAssertTrue(resume.waitForNonExistence(timeout: 3))
            XCTAssertFalse(turn.exists, "当前球组由球库表达，不常驻文字")
            XCTAssertEqual(stage.frame, stageBefore, "弹窗关闭不得改变球桌布局")
            XCTAssertFalse(notice.exists, "关闭面板不能重放过期提示")
        }
    }
}


extension V52DailyClearanceUITests {
    func testPhysicalFoulFeedbackRetainsReasonAndNextAction() {
        XCUIDevice.shared.orientation = .landscapeRight
        for dimension in ["2d", "3d"] {
            let app = launch(["-dailyClearance.fixture=scratch"], game: "nineBall")
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            if dimension == "3d" { mode.tap() }
            let strike = app.buttons["击球"]
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                          evaluatedWith: strike)], timeout: 30), .completed)
            strike.tap()
            let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "犯规：", "自由球")).firstMatch
            XCTAssertTrue(notice.waitForExistence(timeout: 60))
            XCTAssertTrue(notice.label.contains("白球") || notice.label.contains("母球"), notice.label)
            XCTAssertFalse(app.staticTexts["dailyClearance.turn"].exists, "球组状态保留在球库")
            snap(app, "feedback-physical-foul-\(dimension)")
            XCTAssertTrue(notice.waitForNonExistence(timeout: 6))
            XCTAssertFalse(app.staticTexts["dailyClearance.turn"].exists, "球组状态保留在球库")
            snap(app, "feedback-foul-status-\(dimension)")
            app.terminate()
        }
    }
}


extension V52DailyClearanceUITests {
    func testAimModeFeedbackAndFailureCopy() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-v54.forceDark"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        for dimension in ["2d", "3d"] {
            if dimension == "3d" { mode.tap() }
            let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
            let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 12)))
            XCTAssertTrue(app.staticTexts["已调整方向，暂用自由模式"].waitForExistence(timeout: 4))
            snap(app, "feedback-temporary-free-\(dimension)")
            app.buttons["paletteBall__1"].tap()
            XCTAssertTrue(app.staticTexts["进袋模式"].waitForExistence(timeout: 4))
            snap(app, "feedback-pocket-restored-\(dimension)")
        }
        app.terminate()
        let failed = launch(["-dailyClearance.fixture=failed", "-v54.forceDark"])
        XCTAssertTrue(failed.buttons["dailyClearance.rerack"].waitForExistence(timeout: 15))
        XCTAssertFalse(failed.staticTexts["dailyClearance.turn"].exists)
        XCTAssertTrue(failed.staticTexts["本局已结束"].exists)
        snap(failed, "feedback-failed")
    }
}

extension V52DailyClearanceUITests {
    func testDailyCameraVisualMatrix() {
        XCUIDevice.shared.orientation = .landscapeRight
        for fixture in ["selection", "cameraLift"] {
            let app = launch(["-dailyClearance.fixture=\(fixture)", "-v63.cameraDiagnostics"])
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let controls = springboard.buttons["window-controls:com.xinkuan.qiuji"]
            if controls.exists {
                controls.tap()
                let zoom = springboard.buttons["Zoom-button"]
                if zoom.waitForExistence(timeout: 2) { zoom.tap() }
            }
            mode.tap()
            let strike = app.buttons["dailyClearance.strike"]
            func ready() {
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 25), .completed)
                Thread.sleep(forTimeInterval: 1.2)
            }
            func capture(_ name: String) {
                snap(app, name)
                let state = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
                do { try state.write(to: outDir.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8) }
                catch { XCTFail("Cannot write camera diagnostics: \(error)") }
            }
            ready(); capture("\(fixture)-01-overview")
            app.buttons["shotCamera.firstPerson"].tap(); ready()
            capture("\(fixture)-02-first")
            app.buttons["shotCamera.thirdPerson"].tap(); ready()
            capture("\(fixture)-03-third")
            let diagnostics = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
            func tapBall(_ key: String) {
                let value = diagnostics.value as? String ?? ""
                let values = value.components(separatedBy: "window_\(key)=")
                XCTAssertEqual(values.count, 2)
                guard values.count == 2 else { return }
                let coords = values[1].components(separatedBy: " ")[0].split(separator: ",").compactMap { Double($0) }
                XCTAssertEqual(coords.count, 3)
                guard coords.count == 3 else { return }
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: coords[0], dy: coords[1])).tap()
            }
            tapBall("_1"); ready()
            capture("\(fixture)-04-target")
            let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
            stage.pinch(withScale: 2, velocity: 1); ready()
            capture("\(fixture)-05-zoom")
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.15))
                .press(forDuration: 0.1, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.15)))
            ready(); capture("\(fixture)-06-orbit")
            XCTAssertEqual(app.buttons["shotCamera.thirdPerson"].value as? String, "已选中")
            stage.pinch(withScale: 0.2, velocity: -1); ready()
            capture("\(fixture)-07-standing-wide-limit")
            let overview = app.buttons["dailyClearance.observeTable"]
            XCTAssertTrue(overview.waitForExistence(timeout: 4)); overview.tap()
            ready(); capture("\(fixture)-07-return-table")
            tapBall("cueBall"); ready()
            XCTAssertEqual(app.buttons["shotCamera.firstPerson"].value as? String, "已选中")
            capture("\(fixture)-08-tap-cue")
            mode.tap(); mode.tap(); ready()
            capture("\(fixture)-09-roundtrip")
            app.terminate()
        }
    }
}


extension V52DailyClearanceUITests {
    func testGroupedPaletteStatesRemainCenteredInBothModes() {
        XCUIDevice.shared.orientation = .landscapeRight
        for (fixture, active) in [("selection", "_1"), ("selectionStripe", "_9"),
                                  ("selectionBlack", "_8"), ("selectionOpen", "")] {
            let app = launch(["-dailyClearance.fixture=\(fixture)"])
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            for dimension in ["2d", "3d"] {
                if dimension == "3d" { mode.tap() }
                for key in ["_1", "_9", "_8"] {
                    let value = app.buttons["paletteBall_\(key)"].value as? String
                    if key == active { XCTAssertEqual(value, "本轮可击打") }
                    else { XCTAssertNotEqual(value, "本轮可击打") }
                }
                XCTAssertEqual(app.buttons["paletteBall__3"].value as? String, "已进袋")
                XCTAssertFalse(app.staticTexts["dailyClearance.turn"].exists)
                let tray = app.descendants(matching: .any)["dailyClearance.singleRowPalette"].firstMatch
                let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
                XCTAssertEqual(tray.frame.midX, stage.frame.midX, accuracy: 0.5)
                assertCenteredPalette(app, numbers: Array(1...15))
                if !active.isEmpty {
                    app.buttons["paletteBall_\(active)"].tap()
                    let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                    XCTAssertTrue((status.value as? String ?? "").contains("目标\(active)"))
                }
                snap(app, "palette-\(fixture)-\(dimension)")
            }
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    func testCameraIconStates() {
        XCUIDevice.shared.orientation = .landscapeRight
        for appearance in ["Dark", "Light"] {
            let app = launch(["-dailyClearance.fixture=selection", "-v54.force\(appearance)"])
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 15))
            // Wait for the fixture and landscape scene, not just the header's early appearance.
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
                app.frame.width > app.frame.height && mode.value as? String == "2D"
                    && app.buttons["paletteBall__1"].value as? String == "本轮可击打"
            }, evaluatedWith: nil)], timeout: 10), .completed)
            mode.tap()
            XCTAssertEqual(mode.value as? String, "3D")
            let overview = app.buttons["dailyClearance.observeTable"]
            XCTAssertTrue(overview.waitForExistence(timeout: 10))
            for (name, identifier) in [("overview", "dailyClearance.observeTable"),
                                       ("standing", "shotCamera.thirdPerson"),
                                       ("aiming", "shotCamera.firstPerson")] {
                let button = app.buttons[identifier]
                XCTAssertTrue(button.isEnabled)
                button.tap()
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "已选中"),
                    evaluatedWith: button)], timeout: 5), .completed)
                Thread.sleep(forTimeInterval: 1.2)
                snap(app, "camera-icons-\(appearance)-\(name)")
            }
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    func testRerackReturns3DToGlobalCamera() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for preset in ["shotCamera.thirdPerson", "shotCamera.firstPerson"] {
            let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 20))
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate { _, _ in
                mode.value as? String == "2D" && app.buttons["paletteBall__1"].isEnabled
            }, evaluatedWith: nil)], timeout: 10), .completed)
            mode.tap()
            settleDailyCamera(app)
            let player = app.buttons[preset]
            player.tap()
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "value == %@", "已选中"),
                evaluatedWith: player)], timeout: 5), .completed)
            settleDailyCamera(app)
            try captureDailyCamera(app, name: "rerack-\(preset)-before")

            app.buttons["break.entry"].tap()
            app.buttons["dailyClearance.confirmBreak"].tap()
            XCTAssertEqual(player.value as? String, "已选中", "取消重开应保留当前视角")
            app.buttons["break.entry"].tap()
            app.buttons["dailyClearance.rerackAfterBreak"].tap()
            settleDailyCamera(app)
            try captureDailyCamera(app, name: "rerack-\(preset)-after")
            XCTAssertEqual(mode.value as? String, "3D")
            XCTAssertEqual(app.buttons["dailyClearance.observeTable"].value as? String, "已选中")
            XCTAssertEqual(cameraDiagnosticNumber("elevation", app: app) * 180 / .pi, 35, accuracy: 0.05)
            XCTAssertFalse(app.buttons["dailyClearance.confirmBreak"].exists)

            // A second rack while already waiting to break uses the same reset path.
            app.buttons["shotCamera.firstPerson"].tap()
            settleDailyCamera(app)
            app.buttons["break.entry"].tap()
            app.buttons["dailyClearance.rerackAfterBreak"].tap()
            settleDailyCamera(app)
            XCTAssertEqual(app.buttons["dailyClearance.observeTable"].value as? String, "已选中")
            mode.tap()
            app.buttons["break.entry"].tap()
            app.buttons["dailyClearance.rerackAfterBreak"].tap()
            XCTAssertEqual(mode.value as? String, "2D", "2D 重开不应强切到 3D")
            app.terminate()
        }
    }

    private func cameraDiagnosticNumber(_ name: String, app: XCUIApplication) -> Double {
        let text = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
        return Double(text.components(separatedBy: "\(name)=").last?.components(separatedBy: " ").first ?? "") ?? -1
    }

    private func settleDailyCamera(_ app: XCUIApplication) {
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: strike)], timeout: 30), .completed)
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func captureDailyCamera(_ app: XCUIApplication, name: String) throws {
        snap(app, name)
        let text = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
        try text.write(to: outDir.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
    }

    func testCaptureDailyOverviewAngleComparison() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        var referenceYaw: Double?
        for degrees in [45, 40, 35, 30] {
            let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics",
                              "-dailyClearance.overviewAngle=\(degrees)"])
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 20))
            mode.tap()
            settleDailyCamera(app)
            let overview = app.buttons["dailyClearance.observeTable"]
            XCTAssertTrue(overview.isEnabled)
            overview.tap()
            settleDailyCamera(app)
            let text = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
            XCTAssertEqual(cameraDiagnosticNumber("elevation", app: app) * 180 / .pi,
                           Double(degrees), accuracy: 0.05)
            let yaw = cameraDiagnosticNumber("yaw", app: app)
            if let referenceYaw {
                XCTAssertEqual(atan2(sin(yaw-referenceYaw),cos(yaw-referenceYaw)), 0, accuracy: 0.001)
            } else { referenceYaw = yaw }
            let viewportRegex = try NSRegularExpression(pattern: #"viewport=\(([0-9.]+),\s*([0-9.]+)\)"#)
            let match = try XCTUnwrap(viewportRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)))
            let width = try XCTUnwrap(Double(text[Range(match.range(at: 1), in: text)!]))
            let height = try XCTUnwrap(Double(text[Range(match.range(at: 2), in: text)!]))
            XCTAssertGreaterThan(width, height, "Comparison uses the same landscape viewport")
            let corners = text.components(separatedBy: "corners=").last?.components(separatedBy: " pivot=").first ?? ""
            let cornerRegex = try NSRegularExpression(pattern: #"x: ([^,]+), y: ([^,]+), z: ([^)]+)"#)
            let points = cornerRegex.matches(in: corners, range: NSRange(corners.startIndex..., in: corners))
            XCTAssertEqual(points.count, 4)
            for point in points {
                let x = try XCTUnwrap(Double(corners[Range(point.range(at: 1), in: corners)!]))
                let y = try XCTUnwrap(Double(corners[Range(point.range(at: 2), in: corners)!]))
                let z = try XCTUnwrap(Double(corners[Range(point.range(at: 3), in: corners)!]))
                XCTAssertTrue((0...width).contains(x) && (0...height).contains(y) && (0...1).contains(z),
                              "Each angle refits the complete table: \(corners)")
            }
            XCTAssertEqual(app.buttons["paletteBall__1"].value as? String, "本轮可击打")
            try captureDailyCamera(app, name: "overview-angle-\(degrees)")
            app.terminate()
        }
    }

    func testDailyObservationRequestResetsZoomAndElevation() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20)); mode.tap()
        settleDailyCamera(app)
        let observation = app.buttons["shotCamera.thirdPerson"]
        observation.tap(); settleDailyCamera(app)
        let standardDistance = cameraDiagnosticNumber("distance", app: app)
        let standardFOV = cameraDiagnosticNumber("fov", app: app)
        let standardElevation = cameraDiagnosticNumber("elevation", app: app)
        let standardPitch = cameraDiagnosticNumber("pitch", app: app)
        XCTAssertGreaterThan(standardDistance, 0)
        try captureDailyCamera(app, name: "observation-reset-standard")
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        stage.pinch(withScale: 2, velocity: 1); settleDailyCamera(app)
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.18))
            .press(forDuration: 0.1, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.38)))
        settleDailyCamera(app)
        XCTAssertLessThan(cameraDiagnosticNumber("fov", app: app), standardFOV - 0.5)
        XCTAssertGreaterThan(abs(cameraDiagnosticNumber("pitch", app: app)-standardPitch), 0.01)
        try captureDailyCamera(app, name: "observation-reset-manual")
        observation.tap(); settleDailyCamera(app)
        XCTAssertEqual(cameraDiagnosticNumber("distance", app: app), standardDistance, accuracy: 0.005)
        XCTAssertEqual(cameraDiagnosticNumber("fov", app: app), standardFOV, accuracy: 0.02)
        XCTAssertEqual(cameraDiagnosticNumber("elevation", app: app), standardElevation, accuracy: 0.002)
        try captureDailyCamera(app, name: "observation-reset-again")
    }

    func testDailyObservationRequestResetsAfterCompletedShot() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20)); mode.tap()
        settleDailyCamera(app)
        let observation = app.buttons["shotCamera.thirdPerson"]
        observation.tap(); settleDailyCamera(app)
        let normalFOV = cameraDiagnosticNumber("fov", app: app)
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        stage.pinch(withScale: 2, velocity: 1); settleDailyCamera(app)
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.18))
            .press(forDuration: 0.1, thenDragTo: stage.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.38)))
        settleDailyCamera(app)
        let manualPitch = cameraDiagnosticNumber("pitch", app: app)
        XCTAssertLessThan(cameraDiagnosticNumber("fov", app: app), normalFOV - 0.5)
        try captureDailyCamera(app, name: "observation-post-shot-manual-before-strike")
        app.buttons["dailyClearance.strike"].tap()
        let undo = app.buttons["dailyClearance.undo"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
            evaluatedWith: undo)], timeout: 60), .completed)
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertNotNil((hud.value as? String ?? "").range(of: #"1\s*杆"#, options: .regularExpression))
        XCTAssertTrue(observation.isEnabled, "The selection fixture must leave another legal shot after settlement")
        settleDailyCamera(app)
        try captureDailyCamera(app, name: "observation-post-shot-settled")
        observation.tap(); settleDailyCamera(app)
        let distance = cameraDiagnosticNumber("distance", app: app)
        let fov = cameraDiagnosticNumber("fov", app: app)
        let elevation = cameraDiagnosticNumber("elevation", app: app)
        XCTAssertGreaterThanOrEqual(fov, 35.6, "A new ball layout gets its own standard wide lens")
        XCTAssertGreaterThan(abs(cameraDiagnosticNumber("pitch", app: app)-manualPitch), 0.01,
                             "A fresh observation request resets the pre-shot manual gaze angle")
        try captureDailyCamera(app, name: "observation-post-shot-reset")
        observation.tap(); settleDailyCamera(app)
        XCTAssertEqual(cameraDiagnosticNumber("distance", app: app), distance, accuracy: 0.005)
        XCTAssertEqual(cameraDiagnosticNumber("fov", app: app), fov, accuracy: 0.02)
        XCTAssertEqual(cameraDiagnosticNumber("elevation", app: app), elevation, accuracy: 0.002)
        try captureDailyCamera(app, name: "observation-post-shot-reset-again")
    }

    func testDailyOverviewAndObservationZoomRespectSeparateFarLimits() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection", "-v63.cameraDiagnostics"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout:15)); mode.tap()
        let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
        let diagnostics = app.descendants(matching:.any)["v63.cameraDiagnostics"].firstMatch
        func settled() {
            let strike = app.buttons["dailyClearance.strike"]
            XCTAssertEqual(XCTWaiter.wait(for:[expectation(for:NSPredicate(format:"enabled == true"), evaluatedWith:strike)],timeout:30),.completed)
            Thread.sleep(forTimeInterval:1.2)
        }
        func value() -> String { diagnostics.value as? String ?? "" }
        func field(_ name:String) -> Double {
            Double(value().components(separatedBy:"\(name)=").last?.components(separatedBy:" ").first ?? "") ?? -1
        }
        func pivot() -> String {
            value().components(separatedBy:"pivot=").last?.components(separatedBy:" yaw=").first ?? ""
        }
        func tableScale() throws -> Double {
            let corners = value().components(separatedBy:"corners=").last?.components(separatedBy:" pivot=").first ?? ""
            let regex = try NSRegularExpression(pattern:#"x: ([^,]+), y: ([^,]+), z:"#)
            let points = regex.matches(in:corners,range:NSRange(corners.startIndex...,in:corners)).map { match -> (Double,Double) in
                let x = Range(match.range(at:1),in:corners)!, y = Range(match.range(at:2),in:corners)!
                return (Double(corners[x])!,Double(corners[y])!)
            }
            XCTAssertEqual(points.count,4)
            let viewportRegex = try NSRegularExpression(pattern:#"viewport=\(([0-9.]+),\s*([0-9.]+)\)"#)
            let text = value()
            let match = try XCTUnwrap(viewportRegex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)))
            let width = Double(text[Range(match.range(at:1),in:text)!])!
            let height = Double(text[Range(match.range(at:2),in:text)!])!
            guard points.count == 4 else { return -1 }
            return max((points.map { $0.0 }.max()! - points.map { $0.0 }.min()!)/width,
                       (points.map { $0.1 }.max()! - points.map { $0.1 }.min()!)/height)
        }
        func capture(_ name:String) throws {
            snap(app,name)
            try value().write(to:outDir.appendingPathComponent(name+".txt"),atomically:true,encoding:.utf8)
        }
        settled()
        app.buttons["dailyClearance.observeTable"].tap(); settled()
        let defaultScale = try tableScale()
        try capture("zoom-global-default")
        stage.pinch(withScale:0.1,velocity:-1); settled()
        stage.pinch(withScale:0.1,velocity:-1); settled()
        let minimumScale = try tableScale()
        // Verify the global bound using the actual visible table span.
        XCTAssertLessThan(minimumScale,defaultScale)
        XCTAssertGreaterThan(minimumScale/defaultScale,0.8)
        try capture("zoom-global-far")
        app.buttons["shotCamera.thirdPerson"].tap(); settled()
        let subject = pivot(), yaw = field("yaw"), distance = field("distance")
        try capture("zoom-observer-initial")
        stage.pinch(withScale:0.95,velocity:-1); settled()
        XCTAssertLessThanOrEqual(field("distance")/distance,1.15,"A small shrink cannot refit to a tiny whole table")
        XCTAssertEqual(pivot(),subject)
        XCTAssertEqual(atan2(sin(field("yaw")-yaw),cos(field("yaw")-yaw)),0,accuracy:0.005)
        try capture("zoom-observer-small-shrink")
        stage.pinch(withScale:0.1,velocity:-1); settled()
        stage.pinch(withScale:0.1,velocity:-1); settled()
        XCTAssertEqual(pivot(),subject)
        XCTAssertEqual(atan2(sin(field("yaw")-yaw),cos(field("yaw")-yaw)),0,accuracy:0.005)
        XCTAssertEqual(field("distance")/distance,1.15,accuracy:0.01,
                       "Observation shrinks only 15% beyond its own standard distance")
        try capture("zoom-observer-far")
        let farDistance = field("distance")
        stage.pinch(withScale:0.2,velocity:-1); settled()
        XCTAssertEqual(field("distance"),farDistance,accuracy:0.002)
        mode.tap(); mode.tap(); settled()
        XCTAssertEqual(field("distance"),farDistance,accuracy:0.002)
        XCTAssertEqual(pivot(),subject)
        try capture("zoom-observer-far-restored")
    }
}


extension V52DailyClearanceUITests {
    /// Screenshots use production Daily camera poses; the DEBUG argument only places balls.
    func testCaptureDailyObservationFormationMatrix() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for scenario in 0..<4 {
            let app = launch(["-dailyClearance.fixture=progress", "-v63.cameraDiagnostics",
                              "-dailyClearance.cameraScenario=\(scenario)"])
            XCTAssertTrue(app.buttons["shotCamera.thirdPerson"].waitForExistence(timeout:30))
            settleDailyCamera(app)
            let observation = app.buttons["shotCamera.thirdPerson"]
            observation.tap(); settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-standard")
            let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
            stage.pinch(withScale:0.1,velocity:-1); settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-far")
            observation.tap(); settleDailyCamera(app)
            stage.pinch(withScale:2,velocity:1); settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-near")
            observation.tap(); settleDailyCamera(app)
            stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.40))
                .press(forDuration:0.1,thenDragTo:stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.10)))
            settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-vertical-one")
            observation.tap(); settleDailyCamera(app)
            stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.10))
                .press(forDuration:0.1,thenDragTo:stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.40)))
            settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-vertical-two")
            observation.tap(); settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-reset")
            app.buttons["dailyClearance.observeTable"].tap(); settleDailyCamera(app)
            XCTAssertEqual(cameraDiagnosticNumber("elevation",app:app)*180 / .pi,35,accuracy:0.05,
                           "Production default overview is the user-selected 35 degrees")
            try captureDailyCamera(app,name:"formation-\(scenario)-global-35")
            app.terminate()
        }
    }
}


extension V52DailyClearanceUITests {
    private func assertDailyShotSubjectsVisible(_ app: XCUIApplication) throws {
        let text = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch.value as? String ?? ""
        func numbers(_ pattern: String) throws -> [Double] {
            let regex = try NSRegularExpression(pattern: pattern)
            let match = try XCTUnwrap(regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)))
            return try (1..<match.numberOfRanges).map {
                try XCTUnwrap(Double(text[Range(match.range(at: $0), in: text)!]))
            }
        }
        let viewport = try numbers(#"viewport=\(([0-9.]+),\s*([0-9.]+)\)"#)
        let pocket = try numbers(#"pocketScreen=SCNVector3\(x: ([^,]+), y: ([^,]+), z: ([^)]+)\)"#)
        let cue = try numbers(#"ball_cueBall=([^,]+),([^,]+),([^ ]+)"#)
        let target = try numbers(#"ball__1=([^,]+),([^,]+),([^ ]+)"#)
        for point in [cue, target, pocket] {
            XCTAssertTrue((viewport[0]*0.175...viewport[0]*0.825).contains(point[0])
                          && (viewport[1]*0.175...viewport[1]*0.825).contains(point[1])
                          && (0...1).contains(point[2]), "Shot subject must clear HUD: \(text)")
        }
        XCTAssertGreaterThan(cameraDiagnosticNumber("fov", app: app), 35,
                             "Observation retains its wider normal lens")
    }

    func testCaptureDailyObservationTwelveStandardAndFarFormations() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for scenario in 0..<12 {
            let app = launch(["-dailyClearance.fixture=progress", "-v63.cameraDiagnostics",
                              "-dailyClearance.cameraScenario=\(scenario)"])
            XCTAssertTrue(app.buttons["shotCamera.thirdPerson"].waitForExistence(timeout:30))
            settleDailyCamera(app)
            app.buttons["shotCamera.thirdPerson"].tap(); settleDailyCamera(app)
            try assertDailyShotSubjectsVisible(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-standard")
            let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
            stage.pinch(withScale:0.1,velocity:-1); settleDailyCamera(app)
            try assertDailyShotSubjectsVisible(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-far")
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    /// Geometric counterexamples supplement ordinary screenshots; use the actual shot solver.
    func testCaptureDailyObservationCounterexamples() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        for scenario in [12,13] {
            let app = launch(["-dailyClearance.fixture=progress", "-v63.cameraDiagnostics",
                              "-dailyClearance.cameraScenario=\(scenario)"])
            XCTAssertTrue(app.buttons["shotCamera.thirdPerson"].waitForExistence(timeout:30))
            settleDailyCamera(app)
            let observation = app.buttons["shotCamera.thirdPerson"]
            observation.tap(); settleDailyCamera(app)
            try assertDailyShotSubjectsVisible(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-standard")
            let stage = app.descendants(matching:.any)["freeplay.stage"].firstMatch
            stage.pinch(withScale:0.1,velocity:-1); settleDailyCamera(app)
            try assertDailyShotSubjectsVisible(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-far")
            observation.tap(); settleDailyCamera(app)
            stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.10))
                .press(forDuration:0.1,thenDragTo:stage.coordinate(withNormalizedOffset:CGVector(dx:0.40,dy:0.40)))
            settleDailyCamera(app)
            try captureDailyCamera(app,name:"formation-\(scenario)-vertical-two")
            app.terminate()
        }
    }
}

extension V52DailyClearanceUITests {
    func test3DTrajectoryOffKeeps2DGuidesAndRemembersChoice() {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch(["-dailyClearance.fixture=selection"])
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 20))
        let strike = app.buttons["dailyClearance.strike"]
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                                                      evaluatedWith: strike)], timeout: 30), .completed)
        func openTrajectories() {
            app.buttons["freeplay.moreMenu"].tap()
            let menu = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@",
                "dailyClearance.trajectoryMenu", "轨迹显示")).firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 5), app.debugDescription)
            menu.tap()
        }
        func dismissMenu() {
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)).tap()
        }
        func assertOrder(_ labels: [String]) {
            let options = labels.map { app.buttons[$0].firstMatch }
            XCTAssertTrue(options.allSatisfy(\.exists))
            for (first, next) in zip(options, options.dropFirst()) {
                XCTAssertLessThan(first.frame.midY, next.frame.midY)
            }
        }
        openTrajectories()
        XCTAssertFalse(app.buttons["关闭"].exists, "2D needs its direction guide")
        assertOrder(["瞄准线", "双线", "全部"])
        dismissMenu()
        app.buttons["freeplay.cameraMode"].tap()
        openTrajectories()
        app.buttons["全部"].firstMatch.tap()
        snap(app, "trajectory-3d-before-full")
        openTrajectories()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 4))
        assertOrder(["关闭", "瞄准线", "双线", "全部"])
        snap(app, "trajectory-3d-four-options")
        app.buttons["关闭"].tap()
        XCTAssertTrue(strike.isEnabled)
        snap(app, "trajectory-3d-off")
        app.buttons["freeplay.cameraMode"].tap()
        openTrajectories()
        XCTAssertFalse(app.buttons["关闭"].exists)
        dismissMenu()
        snap(app, "trajectory-2d-retains-guides")
        app.buttons["freeplay.cameraMode"].tap()
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "轨迹显示 · 关闭")).firstMatch.waitForExistence(timeout: 5))
        dismissMenu()
        app.terminate()
        app.launch()
        XCTAssertTrue(stage.waitForExistence(timeout: 20))
        app.buttons["freeplay.cameraMode"].tap()
        app.buttons["freeplay.moreMenu"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "轨迹显示 · 关闭")).firstMatch.waitForExistence(timeout: 5))
        dismissMenu()
        snap(app, "trajectory-3d-off-after-relaunch")
        openTrajectories()
        app.buttons["双线"].firstMatch.tap()
        XCTAssertTrue(strike.isEnabled)
        snap(app, "trajectory-3d-restored-core")
    }
}

extension V52DailyClearanceUITests {
    func testContinuousTrajectoryUpdatesDuringPowerAndAimDragInBothModes() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-dailyClearance.fixture=selection", "-dailyClearance.fixtureSettled", "-trajectoryDetail", "0", "-v63.cameraDiagnostics", "-dailyClearance.3DTrajectoryHidden", "NO"])
        let mode = app.buttons["freeplay.cameraMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 15))
        let hud = app.descendants(matching: .any)["v63.cameraDiagnostics"].firstMatch
        let strike = app.buttons["dailyClearance.strike"]
        func count() -> Int {
            let raw = hud.value as? String ?? ""
            return raw.split(separator: " ").first { $0.hasPrefix("livePreviewDuringDrag=") }
                .flatMap { Int($0.split(separator: "=").last ?? "") } ?? 0
        }
        func ready() {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: strike)], timeout: 15), .completed)
        }
        ready()
        for dimension in ["2D", "3D"] {
            if mode.value as? String != dimension { mode.tap(); ready() }
            snap(app, "live-trajectory-\(dimension)-before")
            for control in ["shotStage.powerBar", "shotStage.aimWheel"] {
                let element = app.descendants(matching: .any)[control].firstMatch
                XCTAssertTrue(element.isHittable)
                let oldCount = count()
                let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -45)),
                            withVelocity: XCUIGestureVelocity(rawValue: 18), thenHoldForDuration: 0)
                XCTAssertGreaterThan(count(), oldCount + 1, "Multiple complete trajectories must arrive before finger-up: \(dimension)/\(control)")
                ready()
                snap(app, "live-trajectory-\(dimension)-\(control)")
            }
        }
        // Releasing either control only updates the preview. The explicit button still shoots.
        XCTAssertTrue(strike.isEnabled)
        strike.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: strike)], timeout: 5), .completed)
        snap(app, "live-trajectory-struck")
    }
}
