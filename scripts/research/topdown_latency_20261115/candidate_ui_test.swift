    func testCandidateImmediateFirstOpen() throws {
        for (arm, mode) in ["prepare", "baseline", "reuse", "baseline", "reuse", "prepare", "reuse", "prepare", "baseline"].enumerated() {
            let app = try launchP01(requiresLandscape: true,
                extraArgs: ["-topDown.latencyProbe", "-topDown.direct3D", "-topDown.candidate=\(mode)",
                            "-topDown.candidateCold"], normalizeView: false)
            // No settling sleep: click as soon as the normal UI route is available.
            let peek = app.buttons["shotCamera.temporaryTopDown"]
            for _ in 0..<3 {
                peek.tap(); sleep(1)
                XCTAssertEqual(peek.value as? String, "已选中")
                peek.tap(); sleep(1)
                XCTAssertEqual(peek.value as? String, "未选中")
            }
            sleep(2)
            let raw = try XCTUnwrap(element(app, "topDown.candidateMetrics").value as? String)
            let metrics = XCTAttachment(data: Data(raw.utf8), uniformTypeIdentifier: "public.json")
            metrics.name = "candidate-immediate-\(arm)-\(mode)"; metrics.lifetime = .keepAlways; add(metrics)
            let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let rows = try XCTUnwrap(parsed["rows"] as? [[String: Any]])
            let activations = rows.filter { $0["event"] as? String == "activation" }
            XCTAssertEqual(activations.count, 3)
            XCTAssertTrue(activations.allSatisfy { $0["firstDidMs"] is Double })
            if arm == 0 {
                let before = try p01Balls(app)
                peek.tap(); sleep(1)
                let scene = try p01Scene(app)
                let balls = try XCTUnwrap(scene["balls"] as? [[String: Any]])
                let cue = try XCTUnwrap(balls.first { $0["key"] as? String == "cueBall" })
                let point = try XCTUnwrap(cue["screen"] as? [Double])
                let table = element(app, "table.scene")
                let start = table.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1]))
                start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 70, dy: 0)),
                    withVelocity: XCUIGestureVelocity(rawValue: 80), thenHoldForDuration: 0.1)
                sleep(1)
                let after = try p01Balls(app)
                XCTAssertNotEqual(before["cueBall"], after["cueBall"])
                peek.tap(); sleep(1); peek.tap(); sleep(1)
                assertP01BallsEqual(try p01Balls(app), after)
                let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                shot.name = "candidate-drag-reopen"; shot.lifetime = .keepAlways; add(shot)
                peek.tap()
            }
            app.terminate()
        }
    }

    func testTemporaryTopDownCandidateComparison() throws {
        for (arm, mode) in ["baseline", "reuse", "prepare", "prepare", "reuse", "baseline"].enumerated() {
            let app = try launchP01(requiresLandscape: true,
                extraArgs: ["-topDown.latencyProbe", "-topDown.direct3D", "-topDown.candidate=\(mode)"]
                    + (arm < 3 ? ["-topDown.candidateCold"] : []), normalizeView: false)
            XCTAssertEqual(try p01Scene(app)["cameraMode"] as? String, "3D")
            sleep(8)
            XCTAssertTrue(element(app, "topDown.candidateMetrics").waitForExistence(timeout: 3))
            let peek = app.buttons["shotCamera.temporaryTopDown"]
            for cycle in 0..<20 {
                peek.tap()
                sleep(1)
                XCTAssertEqual(peek.value as? String, "已选中")
                if cycle == 0 || cycle == 19 {
                    let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                    shot.name = "candidate-\(arm)-\(mode)-\(cycle)"; shot.lifetime = .keepAlways; add(shot)
                }
                peek.tap()
                sleep(1)
                XCTAssertEqual(peek.value as? String, "未选中")
            }
            sleep(12)
            let raw = try XCTUnwrap(element(app, "topDown.candidateMetrics").value as? String)
            let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let rows = try XCTUnwrap(parsed["rows"] as? [[String: Any]])
            let activations = rows.filter { $0["event"] as? String == "activation" }
            XCTAssertEqual(activations.count, 20)
            XCTAssertTrue(activations.allSatisfy { $0["firstDidMs"] is Double })
            let metrics = XCTAttachment(data: Data(raw.utf8), uniformTypeIdentifier: "public.json")
            metrics.name = "candidate-metrics-\(arm)-\(mode)"; metrics.lifetime = .keepAlways; add(metrics)
            app.buttons["dailyClearance.back"].tap()
            XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
            sleep(12)
            let exitRaw = try XCTUnwrap(element(app, "topDown.candidateMetrics").value as? String)
            let exitObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(exitRaw.utf8)) as? [String: Any])
            let exitRows = try XCTUnwrap(exitObject["rows"] as? [[String: Any]])
            XCTAssertTrue(exitRows.contains { $0["event"] as? String == "hostDismantled" })
            let exitSamples = exitRows.filter { $0["event"] as? String == "sample" && $0["phase"] as? String == "exited" }
            XCTAssertEqual(exitSamples.last?["overlayAlive"] as? Bool, false)
            let exitMetrics = XCTAttachment(data: Data(exitRaw.utf8), uniformTypeIdentifier: "public.json")
            exitMetrics.name = "candidate-exit-\(arm)-\(mode)"; exitMetrics.lifetime = .keepAlways; add(exitMetrics)
            app.terminate()
        }
    }
