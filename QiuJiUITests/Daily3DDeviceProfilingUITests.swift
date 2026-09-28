import XCTest

/// Physical-device attribution preflight, not a frame-rate or thermal acceptance test.
/// Opt in with TEST_RUNNER_DAILY3D_DEVICE_PROFILE=1 (the unprefixed key also works).
/// Optional 0/1 keys: DAILY3D_CAMERA_REFERENCE, DAILY3D_MERGE_CLOTH_SUPPORT,
/// DAILY3D_FACTOR_CLOTH_BRDF. No arbitrary app arguments or business fixtures.
///
/// The normal daily entry restores today's draft/completion. With no draft or
/// completion it may create and automatically break a new board. This test only
/// accepts the ordinary settled-break confirmation; it never strikes, reracks,
/// moves a ball, resolves a rule choice, or clears persisted data/preferences.
/// Page usage and draft active time follow production behavior. Aim/camera state
/// changes are transient. The 60 FPS launch argument overrides the process's
/// defaults lookup; actual scheduling must be checked in configuration signposts.
///
/// READY is emitted in 2D. Start xctrace during the following 30-second window.
/// The test then enters 3D, exercises aim/camera controls, and returns to 2D to
/// close the page signpost before a final 5-second hold. Console times are only
/// coordination markers, never presentation timestamps or phase-manifest times.
final class Daily3DDeviceProfilingUITests: XCTestCase {
    private enum PreflightError: Error {
        case invalidConfiguration(String)
        case unavailablePage(String)
    }

    func test_attributionPreflight_optedInDevice_preservesCurrentBoard() throws {
        let environment = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? {
            environment[key] ?? environment["TEST_RUNNER_\(key)"]
        }
        guard setting("DAILY3D_DEVICE_PROFILE") == "1" else {
            throw XCTSkip("Set TEST_RUNNER_DAILY3D_DEVICE_PROFILE=1 for an explicitly coordinated device preflight.")
        }
        #if targetEnvironment(simulator)
        throw XCTSkip("This opt-in preflight requires a physical device.")
        #endif

        continueAfterFailure = false
        var arguments = ["-deeplink.dailyClearance", "-daily3D.diagnostics", "-renderFrameRate", "60"]
        for (key, argument) in [
            ("DAILY3D_CAMERA_REFERENCE", "-daily3D.cameraReference"),
            ("DAILY3D_MERGE_CLOTH_SUPPORT", "-daily3D.mergeClothSupport"),
            ("DAILY3D_FACTOR_CLOTH_BRDF", "-daily3D.factorClothBRDF")
        ] {
            let value = setting(key) ?? "0"
            guard value == "0" || value == "1" else {
                throw PreflightError.invalidConfiguration("\(key) must be 0 or 1, received \(value)")
            }
            if value == "1" { arguments.append(argument) }
        }

        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchArguments = arguments
        log("LAUNCH arguments=\(arguments.joined(separator: " "))")
        app.launch()
        defer { attachScreenshot("daily3D-device-preflight-final") }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App must be running in the foreground")

        let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 20), "The complete daily-clearance page must be visible")
        let camera = app.buttons["freeplay.cameraMode"]
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        let cue = app.buttons["paletteBall_cueBall"]
        let confirmBreak = app.buttons["dailyClearance.confirmBreak"]
        let completed = app.buttons["dailyClearance.replay"]
        let failed = app.buttons["dailyClearance.rerack"]
        let ruleChoice = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "dailyClearance.ruleChoice."
        )).firstMatch

        // A racked/manual-break board leaves the palette disabled. Do not strike
        // to make it ready. Completed/failed/rule-choice states also remain intact.
        waitUntil("Normal entry must settle without replacing the current board", timeout: 60) {
            confirmBreak.exists || completed.exists || failed.exists || ruleChoice.exists
                || (wheel.exists && wheel.isEnabled && cue.exists && cue.isEnabled)
        }
        guard !completed.exists, !failed.exists, !ruleChoice.exists else {
            throw PreflightError.unavailablePage("Daily page requires a business decision; preflight leaves it untouched. \(status.value ?? "")")
        }
        if confirmBreak.exists {
            XCTAssertEqual(confirmBreak.label, "完成", "Only the normal settled-break confirmation is allowed")
            XCTAssertTrue(confirmBreak.isHittable)
            log("CONFIRM_SETTLED_BREAK")
            confirmBreak.tap()
            XCTAssertTrue(confirmBreak.waitForNonExistence(timeout: 5))
        }
        waitUntil("Aim controls must be enabled on a settled playing board", timeout: 10) {
            wheel.exists && wheel.isEnabled && wheel.isHittable && cue.exists && cue.isEnabled
        }
        XCTAssertTrue(camera.exists && camera.isHittable)
        XCTAssertEqual(camera.value as? String, "2D", "Preparation must remain in 2D until xctrace starts")
        let stage = app.descendants(matching: .any)["freeplay.stage"].firstMatch
        XCTAssertTrue(stage.exists)
        XCTAssertGreaterThan(stage.frame.width, stage.frame.height * 1.5, "The full page must be in landscape")
        let initialProgress = try progressFields(status)
        attachScreenshot("daily3D-device-preflight-ready-2D")
        log("READY mode=2D trace_start_window_seconds=30 progress=\(initialProgress.joined(separator: "，"))")
        Thread.sleep(forTimeInterval: 30)

        XCTAssertEqual(app.state, .runningForeground)
        log("ENTER_3D")
        camera.tap()
        waitUntil("Camera must enter 3D", timeout: 6) { camera.value as? String == "3D" }
        let scene = app.descendants(matching: .any)["table.scene"].firstMatch
        expectIdle(scene)
        log("IDLE_BEFORE_AIM")
        Thread.sleep(forTimeInterval: 3)

        log("AIM_BEGIN")
        // Element-local normalized UIKit coordinates: +x right, +y down.
        // Keep both endpoints inside the dedicated wheel; no scene/ball dragging.
        for direction in [true, false, true, false] {
            XCTAssertTrue(wheel.isEnabled && wheel.isHittable)
            let upper = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let lower = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let start = direction ? upper : lower
            let end = direction ? lower : upper
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            Thread.sleep(forTimeInterval: 1)
        }
        waitUntil("Real wheel input must activate free aiming", timeout: 5) {
            (status.value as? String ?? "").components(separatedBy: "，").contains("自由模式")
        }
        log("AIM_END")
        expectIdle(scene)

        log("ORBIT_BEGIN source=cameraButtons")
        for identifier in ["shotCamera.firstPerson", "shotCamera.thirdPerson", "dailyClearance.observeTable"] {
            let button = app.buttons[identifier]
            waitUntil("Camera control must be available: \(identifier)", timeout: 10) {
                button.exists && button.isEnabled && button.isHittable
            }
            button.tap()
            waitUntil("Camera selection must respond: \(identifier)", timeout: 5) {
                button.value as? String == "已选中"
            }
            expectIdle(scene)
            Thread.sleep(forTimeInterval: 2)
        }
        log("ORBIT_END")
        expectIdle(scene)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(try progressFields(status), initialProgress, "Aiming and camera controls must preserve visit/ball/foul counts")
        attachScreenshot("daily3D-device-preflight-idle-3D")

        log("EXIT_3D")
        camera.tap()
        waitUntil("Returning to 2D must close the diagnostic page", timeout: 6) { camera.value as? String == "2D" }
        XCTAssertEqual(try progressFields(status), initialProgress)
        log("CLOSED mode=2D tail_seconds=5")
        Thread.sleep(forTimeInterval: 5)
        log("COMPLETE scope=attribution_preflight performance_acceptance=false")
    }

    private func waitUntil(_ message: String, timeout: TimeInterval, condition: @escaping () -> Bool) {
        let predicate = NSPredicate { _, _ in condition() }
        let pending = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [pending], timeout: timeout), .completed, message)
    }

    private func expectIdle(_ scene: XCUIElement) {
        waitUntil("The render scheduler must actually become idle; this is not a presented-frame measurement", timeout: 10) {
            scene.exists && (scene.value as? String ?? "").contains("静止")
        }
    }

    private func progressFields(_ status: XCUIElement) throws -> [String] {
        let fields = (status.value as? String ?? "").components(separatedBy: "，")
        guard fields.count >= 4, !fields[1].isEmpty,
              fields[2].hasPrefix("剩余 "), fields[3].hasSuffix(" 次犯规") else {
            throw PreflightError.unavailablePage("Missing exact daily progress fields: \(status.value ?? "")")
        }
        return Array(fields[1...3])
    }

    private func log(_ event: String) {
        let line = "DAILY3D_DEVICE_PROFILE \(event)\n"
        // Write directly so the root process can act on READY without stdio buffering.
        FileHandle.standardOutput.write(Data(line.utf8))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
