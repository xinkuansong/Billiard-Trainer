import XCTest

/// v52 W3：训练首页三态、训练栈路由、设置五玩法与草稿隔离。
final class V52DailyClearanceHomeSettingsUITests: XCTestCase {
    private var outDir: URL {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["V52_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V52_SHOT_DIR"]
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("daily-home-settings").path
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    /// Real home pushes with the normal manual rack, including a cold scene,
    /// retained resources and a saved daily draft in both app appearances.
    func testEntryRotationLightAndDarkWithRealRack() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for theme in ["Light", "Dark"] {
            XCUIDevice.shared.orientation = .portrait
            let app = launch(["-v50.inMemoryStore", "-v54.force\(theme)",
                              "-dailyClearance.resetHomeState", "-dailyLayout.probe", "-forcePremium"])
            defer { app.terminate() }
            let entry = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(entry.waitForExistence(timeout: 20))
            let homeFrame = entry.frame
            for visit in 1...3 {
                XCTAssertTrue(entry.isHittable)
                let started = Date()
                entry.tap()
                waitForLandscape(app)
                let elapsed = Date().timeIntervalSince(started)
                print("DAILY_ENTRY \(theme) visit=\(visit) seconds=\(elapsed)")
                let stage = app.descendants(matching: .any)["table.scene"].firstMatch
                XCTAssertTrue(stage.waitForExistence(timeout: 10))
                let window = app.windows.firstMatch.frame
                XCTAssertGreaterThan(stage.frame.width, window.width * 0.6, "Renderer must use the full landscape stage")
                XCTAssertGreaterThan(stage.frame.height, window.height * 0.65)
                XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
                snap(app, "entry-\(theme)-\(visit)-landscape")
                let probe = app.descendants(matching: .any)["dailyLayout.entryProbe"].firstMatch
                if let value = probe.value as? String {
                    let attachment = XCTAttachment(string: value)
                    attachment.name = "entry-\(theme)-\(visit)-geometry"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                // The last visit returns immediately after geometry settles.
                app.buttons["dailyClearance.back"].tap()
                let restored = NSPredicate { _, _ in
                    app.frame.height > app.frame.width && entry.isHittable
                        && abs(entry.frame.minY - homeFrame.minY) < 1
                }
                expectation(for: restored, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                snap(app, "entry-\(theme)-\(visit)-returned")
            }
        }
    }

    func testTabletEntryRotationPreservesRendererAndReturns() throws {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(["-v50.inMemoryStore", "-v54.forceLight", "-dailyClearance.resetHomeState",
                          "-dailyClearance.fixtureSettled", "-3dDrag.probe", "-forcePremium"])
        defer { app.terminate() }
        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()
        let back = app.buttons["dailyClearance.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 15))
        let stage = app.descendants(matching: .any)["table.scene"].firstMatch
        func state() throws -> [String: Any] {
            let text = try XCTUnwrap(stage.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        }
        let renderer = try XCTUnwrap(try state()["rendererID"] as? String)
        for mode in ["2D", "3D"] {
            if mode == "3D" {
                app.buttons["freeplay.moreMenu"].tap()
                let toggle = app.buttons["freeplay.cameraMode"]
                XCTAssertTrue(toggle.waitForExistence(timeout: 5))
                if toggle.value as? String != "3D" { toggle.tap() }
                XCTAssertEqual(toggle.value as? String, "3D")
                closeDailyMenu(app)
            }
            for (orientation, name) in [(UIDeviceOrientation.portrait, "portrait"), (.landscapeLeft, "landscape"), (.portrait, "portrait-restored")] {
                XCUIDevice.shared.orientation = orientation
                let ready = NSPredicate { _, _ in
                    let f = app.windows.firstMatch.frame
                    let matches = orientation == .landscapeLeft ? f.width > f.height : f.height > f.width
                    return matches && back.isHittable && f.contains(back.frame)
                }
                expectation(for: ready, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                XCTAssertEqual(try state()["rendererID"] as? String, renderer)
                XCTAssertTrue(app.buttons["freeplay.moreMenu"].isHittable)
                snap(app, "entry-pad-\(mode)-\(name)")
            }
        }
        back.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.isHittable)
        XCTAssertGreaterThan(app.frame.height, app.frame.width)
        snap(app, "entry-pad-returned")
    }

    private func closeDailyMenu(_ app: XCUIApplication) {
        // Wait for the actual modal layer to disappear after dismissal. A screen
        // capture alone does not establish that the next control can receive a tap.
        let close = app.buttons["关闭菜单"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let closed = NSPredicate(format: "exists == false")
        expectation(for: closed, evaluatedWith: app.scrollViews["dailyClearance.menuScroll"])
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["freeplay.cameraMode"].exists)
        XCTAssertTrue(app.buttons["dailyClearance.back"].isHittable)
    }

    private func waitForLandscape(_ app: XCUIApplication) {
        let back = app.buttons["dailyClearance.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 20))
        let ready = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return frame.width > frame.height && back.isHittable
                && !back.frame.isEmpty && frame.contains(back.frame)
        }
        expectation(for: ready, evaluatedWith: app)
        waitForExpectations(timeout: 10)
    }

    func testPortraitHomeEntryAndRepeatedReturn() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch([
            "-v50.inMemoryStore", "-dailyClearance.resetHomeState",
            "-dailyClearance.fixtureSettled", "-forcePremium",
        ])
        app.switchTab(.training)
        let entry = app.buttons["trainingHome.dailyClearance"]
        let hud = app.descendants(matching: .any)["dailyClearance.landscape"]
        for visit in 1...2 {
            XCTAssertTrue(entry.waitForExistence(timeout: 12))
            if visit == 1 {
                XCTAssertTrue(entry.label.contains("未开始"), "Opening the home page must not create a daily game")
            }
            let portrait = NSPredicate { _, _ in
                app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
            }
            expectation(for: portrait, evaluatedWith: app)
            waitForExpectations(timeout: 8)
            snap(app, "entry-\(visit)-home")
            entry.tap()
            XCTAssertTrue(hud.waitForExistence(timeout: 15))
            waitForLandscape(app)
            XCTAssertTrue(app.buttons["dailyClearance.back"].isHittable)
            snap(app, "entry-\(visit)-landscape")
            app.buttons["freeplay.moreMenu"].tap()
            let mode = app.buttons["freeplay.cameraMode"]
            XCTAssertTrue(mode.waitForExistence(timeout: 5))
            if mode.value as? String != "3D" { mode.tap() }
            XCTAssertEqual(mode.value as? String, "3D")
            closeDailyMenu(app)
            XCTAssertGreaterThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
            snap(app, "entry-\(visit)-3d")
            app.buttons["dailyClearance.back"].tap()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        XCTAssertTrue(entry.label.contains("进行中"))
        let portrait = NSPredicate { _, _ in
            app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width
        }
        expectation(for: portrait, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        snap(app, "entry-returned-home")
    }

    func testPortraitDeepLinkOpensLandscapeTable() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch([
            "-deeplink.dailyClearance", "-dailyClearance.fixtureSettled",
            "-dailyClearance.resetHomeState", "-forcePremium",
        ])
        XCTAssertTrue(app.buttons["dailyClearance.back"].waitForExistence(timeout: 15))
        waitForLandscape(app)
        app.buttons["freeplay.moreMenu"].tap()
        let mode = app.buttons["freeplay.cameraMode"]
        let hittable = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: mode)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: 8), .completed, app.debugDescription)
        snap(app, "entry-deeplink-landscape")
    }

    func testEmptyHomeKeepsEntryAndTrainingStackReturnsToHome() {
        let app = launch([
            "-v50.inMemoryStore",
            "-dailyClearance.resetHomeState",
            "-dailyClearance.fixtureSettled",
        ])
        app.switchTab(.training)

        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "无计划无记录仍须显示每日入口")
        XCTAssertTrue(entry.label.contains("未开始"))
        assertDailyClearanceGameIsExposed(in: entry)
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        XCTAssertTrue(app.staticTexts["今日训练待安排"].exists)
        snap(app, "home-empty-not-started")

        entry.tap()
        XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(entry.waitForExistence(timeout: 8), "返回后应留在训练 Tab 与训练栈")
        XCTAssertTrue(entry.label.contains("进行中"), "返回后应刷新为继续清台")
        snap(app, "home-return-in-progress")
    }

    func testDraftAndCompletionStatesPersistAcrossRelaunch() {
        var app = launch([
            "-v50.inMemoryStore",
            "-dailyClearance.resetHomeState",
            "-dailyClearance.seedHomeState=progress",
        ])
        app.switchTab(.training)
        assertHomeState(app, contains: "进行中")
        snap(app, "home-in-progress")
        app.terminate()

        app = launch(["-v50.inMemoryStore"])
        app.switchTab(.training)
        assertHomeState(app, contains: "进行中")

        app.terminate()
        app = launch([
            "-v50.inMemoryStore",
            "-dailyClearance.seedHomeState=completed",
            "-v49.forceLight",
        ])
        app.switchTab(.training)
        assertHomeState(app, contains: "已完成")
        snap(app, "home-completed-light")
        app.terminate()

        app = launch(["-v50.inMemoryStore", "-v49.forceLight"])
        app.switchTab(.training)
        assertHomeState(app, contains: "已完成")
    }

    func testSettingsShowsFiveGamesPersistsAndDoesNotReplaceDraftGame() {
        var app = launch([
            "-v50.inMemoryStore",
            "-dailyClearance.resetHomeState",
            "-dailyClearance.seedHomeState=progress",
            "-dailyClearance.preferredGame.v1", "chineseEightBall",
            "-v49.forceLight",
        ])
        openSettings(in: app)

        let picker = app.descendants(matching: .any)["settings.dailyClearanceGame"]
        XCTAssertTrue(scrollUntilVisible(picker, in: app), "设置页须显示每日清台默认玩法")
        XCTAssertTrue(app.staticTexts["只影响下一个新局；正在进行的清台会保留原玩法。"].exists)
        XCTAssertGreaterThanOrEqual(picker.frame.height, 43.5, "44pt 布局在 3x 像素栅格允许亚像素误差")
        snap(app, "settings-five-games-light")

        picker.tap()
        for game in ["中八", "9 球", "6 球", "5 球", "4 球"] {
            XCTAssertTrue(
                app.buttons[game].waitForExistence(timeout: 4)
                    || app.staticTexts[game].waitForExistence(timeout: 1),
                "玩法菜单应包含 \(game)"
            )
        }
        let nineBall = app.buttons["9 球"].firstMatch
        XCTAssertTrue(nineBall.exists)
        nineBall.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 4))
        XCTAssertTrue(picker.label.contains("9 球") || picker.value as? String == "9 球")
        app.terminate()

        app = launch(["-v50.inMemoryStore", "-v49.forceLight", "-deeplink.settings"])
        openSettings(in: app)
        let relaunchedPicker = app.descendants(matching: .any)["settings.dailyClearanceGame"]
        XCTAssertTrue(scrollUntilVisible(relaunchedPicker, in: app))
        XCTAssertTrue(
            relaunchedPicker.label.contains("9 球") || relaunchedPicker.value as? String == "9 球",
            "默认玩法修改后重启仍应为 9 球"
        )
        app.terminate()

        app = launch([
            "-deeplink.dailyClearance",
            "-dailyClearance.fixtureSettled",
            "-v49.forceLight",
        ])
        let hud = app.descendants(matching: .any)["dailyClearance.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.label.contains("中八"), "设置只影响新局，已有中八草稿不得换成 9 球")
    }

    func testPlannedHomeAndSettingsRemainReachableAtMaximumContentSize() {
        let app = launch([
            "-v50.inMemoryStore",
            "-dailyClearance.resetHomeState",
            "-dailyClearance.seedHomeState=progress",
            "-dailyClearance.seedActivePlan",
        ])
        app.switchTab(.training)

        let weeklyTitle = app.staticTexts["本周训练"].firstMatch
        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(weeklyTitle.waitForExistence(timeout: 12), "有计划首页仍须呈现本周卡")
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        XCTAssertTrue(entry.isHittable)
        XCTAssertGreaterThanOrEqual(entry.frame.height, 43.5)
        XCTAssertFalse(weeklyTitle.frame.intersects(entry.frame), "最大字号下标题与入口不能覆盖")
        snap(app, "home-planned-progress-max-type")

        openSettings(in: app)
        let picker = app.descendants(matching: .any)["settings.dailyClearanceGame"]
        XCTAssertTrue(scrollUntilVisible(picker, in: app))
        XCTAssertTrue(picker.isHittable)
        XCTAssertGreaterThanOrEqual(picker.frame.height, 43.5)
        XCTAssertTrue(app.staticTexts["只影响下一个新局；正在进行的清台会保留原玩法。"].exists)
        snap(app, "settings-five-games-max-type")
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: extra)
    }

    private func assertHomeState(_ app: XCUIApplication, contains state: String) {
        let entry = app.buttons["trainingHome.dailyClearance"]
        if !entry.waitForExistence(timeout: 10) {
            // CoreSimulator 偶发首个冷启动未交付 Tab 切换；同参数只重启一次，仍失败即阻断。
            app.terminate()
            app.launch()
            app.switchTab(.training)
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(entry.label.contains(state), "实际入口标签：\(entry.label)")
        assertDailyClearanceGameIsExposed(in: entry)
    }

    private func assertDailyClearanceGameIsExposed(in entry: XCUIElement) {
        let games = ["中八", "9 球", "6 球", "5 球", "4 球"]
        XCTAssertTrue(
            games.contains { entry.label.contains($0) },
            "每日清台入口的无障碍标签须包含玩法，实际：\(entry.label)"
        )
    }

    private func openSettings(in app: XCUIApplication) {
        if app.navigationBars["设置"].waitForExistence(timeout: 3) { return }
        app.switchTab(.profile)
        let settings = app.staticTexts["设置"]
        for _ in 0..<4 where !settings.isHittable {
            app.windows.firstMatch.swipeUp()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 8))
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.exists, element.isHittable { return true }
            app.windows.firstMatch.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        // The app can be landscape while the simulated physical device stays portrait.
        // Screen capture preserves the full display; app capture may crop that mismatch.
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
}
