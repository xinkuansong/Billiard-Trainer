import XCTest

final class TrainingAtmosphereUITests: XCTestCase {
    func testWeeklyCardCompletedDayAndClearanceNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for appearance in ["Light", "Dark"] {
            app.launchArguments = ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(zh-Hans)",
                                   "-v50.inMemoryStore", "-v54.force\(appearance)",
                                   "-v54.todayState=freeCompleted", "-dailyClearance.resetHomeState",
                                   "-dailyClearance.seedHomeState=progress", "-dailyClearance.fixtureSettled"]
            app.launchEnvironment["QIUJI_DAYPART"] = appearance == "Light" ? "day" : "evening"
            app.launch()
            let entry = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(entry.waitForExistence(timeout: 20))
            XCTAssertTrue(entry.isHittable)
            XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
            XCTAssertTrue(entry.label.contains("进行中"))
            XCTAssertTrue(app.staticTexts["本周训练"].exists)
            let summary = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "本周训练 1 / 3 天，连续训练 1 天")
            ).firstMatch
            XCTAssertTrue(summary.waitForExistence(timeout: 10), "真实训练夹具应驱动进度和完成圆点")
            try capture("weekly-final-\(appearance)")
            entry.tap()
            XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 15))
            XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.hud"].waitForExistence(timeout: 10))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            XCTAssertTrue(entry.isHittable)
            XCTAssertTrue(summary.exists, "返回后周训练记录应保留")
            app.terminate()
        }
    }

    func testDaypartsAndProfileNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        for part in ["morning", "day", "evening"] {
            app.launchArguments = ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(zh-Hans)",
                                   "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance"]
            app.launchEnvironment["QIUJI_DAYPART"] = part
            app.launch()
            let clearance = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(clearance.waitForExistence(timeout: 20))
            XCTAssertTrue(clearance.isHittable)
            XCTAssertTrue(app.staticTexts["本周训练"].exists)
            try capture("training-\(part)")
            if part == "day" {
                app.switchTab(.profile)
                let login = app.buttons["profile.login"]
                XCTAssertTrue(login.waitForExistence(timeout: 10))
                try capture("profile-8")
                login.tap()
                XCTAssertTrue(app.buttons["通过 Apple 登录"].waitForExistence(timeout: 5),
                              "头像卡仍须打开现有登录页")
            }
            app.terminate()
        }
        app.launchArguments += ["-dailyClearance.preferredGame.v1", "nineBall"]
        app.launch()
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 20))
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 10))
        try capture("profile-9")
        app.terminate()
    }

    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let env = ProcessInfo.processInfo.environment
        if let path = env["DAYPART_SHOTS"] ?? env["TEST_RUNNER_DAYPART_SHOTS"] {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try shot.pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
        }
    }
}
