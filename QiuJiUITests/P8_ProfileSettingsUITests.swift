import XCTest

final class P8_ProfileSettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.profile)
        sleep(3)
    }

    // MARK: - PersonalInfoView

    func testPersonalInfoOpens() {
        let personalInfo = app.staticTexts["个人信息"]
        XCTAssertTrue(personalInfo.waitForExistence(timeout: 5), "个人信息入口必须存在")
        personalInfo.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 5), "PersonalInfoView should open")
        XCTAssertTrue(
            app.buttons["personalInfo.avatarPicker"].waitForExistence(timeout: 3),
            "个人信息页必须提供可操作的头像选择入口"
        )
    }

    func testPersonalInfoSportPills() {
        let personalInfo = app.staticTexts["个人信息"]
        XCTAssertTrue(personalInfo.waitForExistence(timeout: 5), "个人信息入口必须存在")
        personalInfo.tap()
        sleep(2)
        var found = false
        for sport in ["中式台球", "9球", "两者"] {
            if app.staticTexts[sport].waitForExistence(timeout: 3) ||
               app.buttons[sport].waitForExistence(timeout: 2) {
                found = true
            }
        }
        XCTAssertTrue(found, "At least one sport pill should exist")
    }

    func testPersonalInfoLevelPills() {
        let personalInfo = app.staticTexts["个人信息"]
        XCTAssertTrue(personalInfo.waitForExistence(timeout: 5), "个人信息入口必须存在")
        personalInfo.tap()
        sleep(2)
        var found = false
        for level in ["入门", "初级", "中级", "高级"] {
            if app.staticTexts[level].waitForExistence(timeout: 3) ||
               app.buttons[level].waitForExistence(timeout: 2) {
                found = true
            }
        }
        XCTAssertTrue(found, "At least one level pill should exist")
    }

    func testPersonalInfoBallAge() {
        let personalInfo = app.staticTexts["个人信息"]
        XCTAssertTrue(personalInfo.waitForExistence(timeout: 5), "个人信息入口必须存在")
        personalInfo.tap()
        sleep(2)
        app.scrollDown(times: 2)
        sleep(1)
        XCTAssertTrue(app.staticTexts["不到 1 年"].waitForExistence(timeout: 3) ||
                      app.staticTexts["1-3 年"].waitForExistence(timeout: 3) ||
                      app.staticTexts.matching(NSPredicate(format: "label CONTAINS '年'")).count > 0,
                      "Ball age options should be visible")
    }

    // MARK: - TrainingGoalView

    func testTrainingGoalOpens() {
        let goal = app.staticTexts["训练目标"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "训练目标入口必须存在")
        goal.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["训练目标"].waitForExistence(timeout: 5), "TrainingGoalView should open")
    }

    func testTrainingGoalWeeklyDays() {
        let goal = app.staticTexts["训练目标"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "训练目标入口必须存在")
        goal.tap()
        sleep(2)
        app.scrollDown(times: 1)
        sleep(1)
        let dayOptions = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '天'"))
        XCTAssertTrue(dayOptions.count > 0, "Weekly day options should be visible")
    }

    func testTrainingGoalHasNoDurationTarget() {
        let goal = app.staticTexts["训练目标"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "训练目标入口必须存在")
        goal.tap()
        sleep(2)
        app.scrollDown(times: 2)
        sleep(1)
        XCTAssertFalse(app.staticTexts["每次训练时长目标"].exists)
        XCTAssertFalse(app.staticTexts["30 分钟"].exists)
        XCTAssertFalse(app.staticTexts["不限"].exists)
    }

    func testTrainingGoalReminder() {
        let goal = app.staticTexts["训练目标"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "训练目标入口必须存在")
        goal.tap()
        sleep(2)
        app.scrollDown(times: 3)
        sleep(1)
        let reminderToggle = app.switches["trainingGoal.reminderEnabled"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 3), "训练提醒开关必须存在")
        let authorization = app.staticTexts["trainingGoal.reminderAuthorization"]
        XCTAssertTrue(authorization.waitForExistence(timeout: 3), "必须显示系统通知权限状态")
        XCTAssertTrue(
            ["首次开启时会请求系统通知权限", "系统通知权限已开启", "系统通知权限未开启，请前往系统设置允许通知"]
                .contains(authorization.label),
            "通知权限状态不能是空白或伪成功：\(authorization.label)"
        )
    }

    func testTrainingReminderRealSystemPromptAllowed() throws {
        try exerciseTrainingReminderPermission(allow: true)
    }

    func testTrainingReminderRealSystemPromptDenied() throws {
        try exerciseTrainingReminderPermission(allow: false)
    }

    // MARK: - SettingsView

    func testSettingsOpens() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "偏好设置入口必须存在")
        settings.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["偏好设置"].waitForExistence(timeout: 5), "SettingsView should open")
    }

    func testSettingsAppearancePills() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "偏好设置入口必须存在")
        settings.tap()
        sleep(2)
        var found = false
        for mode in ["跟随系统", "浅色", "深色"] {
            if app.staticTexts[mode].waitForExistence(timeout: 3) ||
               app.buttons[mode].waitForExistence(timeout: 2) {
                found = true
            }
        }
        XCTAssertTrue(found, "At least one appearance mode should exist")

        let dark = app.buttons["深色"]
        XCTAssertTrue(dark.waitForExistence(timeout: 3), "深色选项必须存在")
        dark.tap()
        let content = app.scrollViews["settings.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 3), "设置内容必须存在")
        XCTAssertEqual(content.value as? String, "dark", "选择深色后环境色彩方案必须立即更新")
    }

    func testSettingsAppearancePersistsAcrossColdRelaunch() {
        app.scrollDown(times: 2)
        let settings = app.staticTexts["偏好设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "偏好设置入口必须存在")
        settings.tap()

        let content = app.scrollViews["settings.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 3), "设置内容必须存在")
        let targetLabel = (content.value as? String) == "dark" ? "浅色" : "深色"
        let expectedValue = targetLabel == "深色" ? "dark" : "light"
        let target = app.buttons[targetLabel]
        XCTAssertTrue(target.waitForExistence(timeout: 3), "目标外观选项必须存在")
        target.tap()
        XCTAssertEqual(content.value as? String, expectedValue, "外观必须立即切换")

        app.terminate()
        app.launch()
        app.switchTab(.profile)
        app.scrollDown(times: 2)
        let reopenedSettings = app.staticTexts["偏好设置"]
        XCTAssertTrue(reopenedSettings.waitForExistence(timeout: 5), "冷启动后偏好设置入口必须存在")
        reopenedSettings.tap()
        let reopenedContent = app.scrollViews["settings.content"]
        XCTAssertTrue(reopenedContent.waitForExistence(timeout: 3), "冷启动后设置内容必须存在")
        XCTAssertEqual(
            reopenedContent.value as? String,
            expectedValue,
            "冷启动后必须恢复用户选择的外观"
        )
    }

    func testAuthenticatedProfileUsesServerIdentityAcrossColdRelaunch() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture"])
        app.switchTab(.profile)

        let header = app.descendants(matching: .any)["profile.accountHeader"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "恢复登录后必须展示账号头卡")
        XCTAssertTrue(header.label.contains("服务端球友"), "头卡必须使用服务端恢复的昵称")
        XCTAssertFalse(app.buttons["profile.login"].exists, "恢复账号后不能仍显示游客登录头卡")

        app.terminate()
        app.launch()
        app.switchTab(.profile)
        let relaunchedHeader = app.descendants(matching: .any)["profile.accountHeader"]
        XCTAssertTrue(relaunchedHeader.waitForExistence(timeout: 5), "冷启动恢复后必须再次展示账号头卡")
        XCTAssertTrue(relaunchedHeader.label.contains("服务端球友"), "冷启动后昵称仍须来自恢复的服务端资料")
    }

    func testSettingsClearCache() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "偏好设置入口必须存在")
        settings.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["清除缓存"].waitForExistence(timeout: 3), "Clear cache row should exist")
    }

    // MARK: - AboutView

    func testAboutOpens() {
        app.scrollDown(times: 2)
        sleep(1)
        let about = app.staticTexts["关于与反馈"]
        XCTAssertTrue(about.waitForExistence(timeout: 5), "关于与反馈入口必须存在")
        about.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["关于与反馈"].waitForExistence(timeout: 5), "AboutView should open")
    }

    func testAboutContent() {
        app.scrollDown(times: 2)
        sleep(1)
        let about = app.staticTexts["关于与反馈"]
        XCTAssertTrue(about.waitForExistence(timeout: 5), "关于与反馈入口必须存在")
        about.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["球迹"].waitForExistence(timeout: 3), "App name should be visible")
        XCTAssertTrue(app.staticTexts["意见反馈"].waitForExistence(timeout: 3), "Feedback row should exist")
        XCTAssertTrue(app.staticTexts["给个好评"].waitForExistence(timeout: 3), "Rate app row should exist")
    }

    func testAboutLegalLinks() {
        app.scrollDown(times: 2)
        sleep(1)
        let about = app.staticTexts["关于与反馈"]
        XCTAssertTrue(about.waitForExistence(timeout: 5), "关于与反馈入口必须存在")
        about.tap()
        sleep(2)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '尚未发布'")).firstMatch
                .waitForExistence(timeout: 3),
            "未发布法律页时必须明确提示，不能展示伪链接"
        )
    }

    // MARK: - OnboardingView (fresh install)

    func testOnboardingFlowOnFreshInstall() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App should launch without crash")
    }

    private func exerciseTrainingReminderPermission(allow: Bool) throws {
        let goal = app.staticTexts["训练目标"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5), "训练目标入口必须存在")
        goal.tap()
        app.scrollDown(times: 3)

        let reminderToggle = app.switches["trainingGoal.reminderEnabled"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5), "训练提醒开关必须存在")
        XCTAssertTrue(
            app.staticTexts["首次开启时会请求系统通知权限"].waitForExistence(timeout: 3),
            "全新模拟器必须从通知权限未决定态开始"
        )

        var handledSystemPrompt = false
        let monitor = addUIInterruptionMonitor(
            withDescription: allow ? "允许通知权限" : "拒绝通知权限"
        ) { alert in
            let predicate = allow
                ? NSPredicate(format: "(label CONTAINS '允许' AND NOT label CONTAINS '不允许') OR label == '好' OR label == 'OK'")
                : NSPredicate(format: "label CONTAINS '不允许' OR label CONTAINS \"Don't Allow\"")
            let action = alert.buttons.matching(predicate).firstMatch
            guard action.exists else { return false }
            handledSystemPrompt = true
            action.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }

        reminderToggle.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemAlert = springboard.alerts.firstMatch
        if systemAlert.waitForExistence(timeout: 5) {
            let predicate = allow
                ? NSPredicate(format: "(label CONTAINS '允许' AND NOT label CONTAINS '不允许') OR label == '好' OR label == 'OK'")
                : NSPredicate(format: "label CONTAINS '不允许' OR label CONTAINS \"Don't Allow\"")
            let action = systemAlert.buttons.matching(predicate).firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 3), "系统通知权限弹框缺少预期操作")
            action.tap()
            handledSystemPrompt = true
        } else {
            app.tap()
        }

        XCTAssertTrue(handledSystemPrompt, "必须实际处理系统通知权限弹框，禁止用预授权冒充")
        let expectedStatus = allow
            ? "系统通知权限已开启"
            : "系统通知权限未开启，请前往系统设置允许通知"
        XCTAssertTrue(
            app.staticTexts[expectedStatus].waitForExistence(timeout: 8),
            "App 必须回显系统通知权限结果"
        )

        if allow {
            XCTAssertEqual(reminderToggle.value as? String, "1", "允许后提醒开关必须保持开启")
        } else {
            let failure = app.alerts["无法开启提醒"]
            XCTAssertTrue(failure.waitForExistence(timeout: 5), "拒绝后必须解释无法开启提醒")
            XCTAssertTrue(failure.buttons["知道了"].waitForExistence(timeout: 3))
            failure.buttons["知道了"].tap()
            XCTAssertEqual(reminderToggle.value as? String, "0", "拒绝后提醒开关必须回退关闭")
        }
    }
}
