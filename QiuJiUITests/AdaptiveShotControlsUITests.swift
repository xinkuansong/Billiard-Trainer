import XCTest

final class AdaptiveShotControlsUITests: XCTestCase {
    func testRulerAudioEnabledAndMutedInBothDimensions() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("build/control-audio-20261001/ui")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for enabled in [true, false] {
            let arguments = ["-deeplink.dailyClearance", "-dailyClearance.resetState",
                "-dailyClearance.fixture=progress", "-soundEffectsEnabled", enabled ? "YES" : "NO"]
                + (enabled ? ["-shotAudioPreview"] : [])
            let app = XCUIApplication.launchClean(extraArgs: arguments)
            for dimension in ["2d", "3d"] {
                let strike = app.buttons["dailyClearance.strike"]
                XCTAssertTrue(strike.waitForExistence(timeout: 20))
                if dimension == "3d" { app.buttons["freeplay.cameraMode"].tap() }
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
                let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
                let before = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                for control in [power, wheel] {
                    control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                        .press(forDuration: 0.1,
                               thenDragTo: control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                               withVelocity: XCUIGestureVelocity(rawValue: 150), thenHoldForDuration: 0.3)
                }
                XCTAssertGreaterThan(try XCTUnwrap(Double(try XCTUnwrap(power.value as? String))), before)
                // Aim edits recompute the prediction asynchronously before enabling strike.
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                XCTAssertTrue((status.value as? String)?.contains("自由模式") == true)
                try XCUIScreen.main.screenshot().pngRepresentation.write(to:
                    directory.appendingPathComponent("\(enabled ? "enabled" : "muted")-\(dimension).png"))
            }
            app.terminate()
        }
        // Playback and mute evidence is collected from the simulator audio-engine log.
        // This UI assertion only verifies that actual gestures and shot controls still work.
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeRight
    }

    func testSamePowerTravelIsFinerWhenSlowInBothDimensions() throws {
        for dimension in ["2d", "3d"] {
            var changes: [Double] = []
            for speed in [20.0, 300.0] {
                let app = XCUIApplication.launchClean(extraArgs: [
                    "-deeplink.dailyClearance", "-dailyClearance.resetState",
                    "-dailyClearance.fixture=progress"
                ])
                let power = app.descendants(matching: .any)["shotStage.powerBar"].firstMatch
                XCTAssertTrue(power.waitForExistence(timeout: 15))
                if dimension == "3d" { app.buttons["freeplay.cameraMode"].tap() }
                let strike = app.buttons["dailyClearance.strike"]
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let status = app.descendants(matching: .any)["dailyClearance.landscape"].firstMatch
                let beforeStatus = status.value as? String
                let initial = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                    .press(forDuration: 0.1,
                           thenDragTo: power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                           withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: 0.1)
                let final = try XCTUnwrap(Double(try XCTUnwrap(power.value as? String)))
                changes.append(final - initial)
                XCTAssertGreaterThan(final, initial)
                XCTAssertEqual(status.value as? String, beforeStatus, "Adjustment never fires a shot")
                XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "enabled == true"),
                    evaluatedWith: strike)], timeout: 15), .completed)
                let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
                wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                    .press(forDuration: 0.1,
                           thenDragTo: wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)),
                           withVelocity: XCUIGestureVelocity(rawValue: speed), thenHoldForDuration: 0.1)
                XCTAssertEqual(wheel.value as? String, speed < 30 ? "精细刻度" : "常规刻度")
                XCTAssertEqual(try XCTUnwrap(Double(try XCTUnwrap(power.value as? String))), final)
                let afterAim = try XCTUnwrap(status.value as? String)
                XCTAssertEqual(Array(afterAim.components(separatedBy: "，").prefix(4)),
                               Array((beforeStatus ?? "").components(separatedBy: "，").prefix(4)),
                               "Aiming can change aim mode, but cannot advance the game")
                XCTAssertTrue(afterAim.contains("自由模式"))
                let shot = XCUIScreen.main.screenshot()
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = "adaptive-\(dimension)-\(Int(speed))-power-\(final)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let directory = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/adaptive-controls-r2-20260928/after")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try shot.pngRepresentation.write(to: directory.appendingPathComponent("\(dimension)-\(Int(speed))-\(Int(app.frame.width)).png"))
                app.terminate()
            }
            XCTAssertLessThan(changes[0], changes[1] * 0.5, "\(dimension): slow=\(changes[0]), fast=\(changes[1])")
        }
    }
}
