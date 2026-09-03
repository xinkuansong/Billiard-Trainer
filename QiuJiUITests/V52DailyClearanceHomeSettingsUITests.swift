import XCTest

/// v52 W3：训练首页三态、训练栈路由、设置五玩法与草稿隔离。
final class V52DailyClearanceHomeSettingsUITests: XCTestCase {
    private var outDir: URL {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["V52_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V52_SHOT_DIR"]
            ?? "/Users/song/projects/13.billiard_trainer/build/v52-screenshots/after-home-settings"
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
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
        if app.navigationBars["偏好设置"].waitForExistence(timeout: 3) { return }
        app.switchTab(.profile)
        let settings = app.staticTexts["偏好设置"]
        for _ in 0..<4 where !settings.isHittable {
            app.windows.firstMatch.swipeUp()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()
        XCTAssertTrue(app.navigationBars["偏好设置"].waitForExistence(timeout: 8))
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<6 {
            if element.exists, element.isHittable { return true }
            app.windows.firstMatch.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
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
