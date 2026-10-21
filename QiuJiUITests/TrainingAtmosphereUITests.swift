import XCTest

final class TrainingAtmosphereUITests: XCTestCase {
    func testDailyClearanceLoopKeepsLabelStableAndSurvivesBackground() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        for (theme, state) in [("Light", "fresh"), ("Dark", "progress")] {
            let app = XCUIApplication.launchClean(extraArgs: [
                "-v50.inMemoryStore", "-v54.force\(theme)", "-v54.todayState=freeCompleted",
                "-dailyClearance.resetHomeState", "-dailyClearance.seedHomeState=\(state)",
            ])
            defer { app.terminate() }
            let entry = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(entry.waitForExistence(timeout: 20))
            XCTAssertTrue(entry.isHittable)
            let frame = entry.frame
            XCTAssertGreaterThanOrEqual(frame.height, 44)
            let start = Date()
            for time in [0.0, 1.5, 3.0, 5.5, 6.5, 7.5, 9.0, 11.0, 13.5] {
                Thread.sleep(forTimeInterval: max(0, time - Date().timeIntervalSince(start)))
                try capture("daily-loop-\(theme)-\(time)")
            }
            XCTAssertEqual(entry.frame, frame)
            XCTAssertFalse(entry.frame.intersects(app.staticTexts["本周训练"].frame))
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            XCTAssertTrue(entry.isHittable)
            XCTAssertEqual(entry.frame, frame)
            try capture("daily-loop-\(theme)-foreground")
        }
    }

    func testDailyClearanceEntryRoundTripKeepsLayout() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.launchClean(extraArgs: [
            "-v50.inMemoryStore", "-v54.forceLight", "-v54.todayState=freeCompleted",
            "-dailyClearance.resetHomeState", "-dailyClearance.fixtureSettled", "-forcePremium",
        ])
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let entry = app.buttons["trainingHome.dailyClearance"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        XCTAssertTrue(entry.label.contains("未开始"))
        let originalFrame = entry.frame
        XCTAssertGreaterThanOrEqual(originalFrame.height, 44)
        for visit in 1...2 {
            XCTAssertTrue(entry.isHittable)
            entry.tap()
            let back = app.buttons["dailyClearance.back"]
            XCTAssertTrue(back.waitForExistence(timeout: 15))
            XCTAssertTrue(app.descendants(matching: .any)["dailyClearance.landscape"].exists)
            // The destination appears before its forced landscape transition completes.
            let landscapeReady = NSPredicate { _, _ in
                app.frame.width > app.frame.height && back.isHittable
                    && !back.frame.isEmpty && app.frame.contains(back.frame)
            }
            expectation(for: landscapeReady, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            back.tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 15))
            let restored = NSPredicate { _, _ in
                app.frame.height > app.frame.width
                    && abs(entry.frame.minY - originalFrame.minY) < 1
            }
            expectation(for: restored, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            XCTAssertTrue(entry.label.contains("进行中"))
            XCTAssertEqual(entry.frame.height, originalFrame.height, accuracy: 0.5)
            XCTAssertEqual(entry.frame.maxX, originalFrame.maxX, accuracy: 0.5)
            XCTAssertFalse(entry.frame.intersects(app.staticTexts["本周训练"].frame))
            try capture("daily-icon-return-\(visit)")
        }
    }

    func testWeeklyCardResponsiveBackground() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        defer { XCUIDevice.shared.orientation = .portrait }
        for appearance in ["Light", "Dark"] {
            XCUIDevice.shared.orientation = .portrait
            app.launchArguments = ["-hasCompletedOnboarding", "YES", "-hasCompletedProfileOnboarding", "YES",
                                   "-AppleLanguages", "(zh-Hans)", "-v50.inMemoryStore",
                                   "-v54.force\(appearance)", "-v54.todayState=freeCompleted",
                                   "-dailyClearance.resetHomeState"]
            app.launchEnvironment["QIUJI_DAYPART"] = "day"
            app.launch()
            let entry = app.buttons["trainingHome.dailyClearance"]
            XCTAssertTrue(entry.waitForExistence(timeout: 20))
            let orientations: [UIDeviceOrientation] = isPad ? [.portrait, .landscapeLeft, .portrait] : [.portrait]
            for (index, orientation) in orientations.enumerated() {
                XCUIDevice.shared.orientation = orientation
                let landscape = orientation == .landscapeLeft
                let settled = NSPredicate { _, _ in
                    let frame = app.frame
                    return landscape ? frame.width > frame.height : frame.height > frame.width
                }
                expectation(for: settled, evaluatedWith: app)
                waitForExpectations(timeout: 10)
                XCTAssertTrue(entry.isHittable)
                XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
                XCTAssertTrue(app.staticTexts["本周训练"].exists)
                try capture("weekly-responsive-\(appearance)-\(index)-\(landscape ? "landscape" : "portrait")")
            }
            app.terminate()
        }
    }

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
