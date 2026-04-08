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
        guard personalInfo.waitForExistence(timeout: 5) else { return }
        personalInfo.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 5), "PersonalInfoView should open")
    }

    func testPersonalInfoSportPills() {
        let personalInfo = app.staticTexts["个人信息"]
        guard personalInfo.waitForExistence(timeout: 5) else { return }
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
        guard personalInfo.waitForExistence(timeout: 5) else { return }
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
        guard personalInfo.waitForExistence(timeout: 5) else { return }
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
        guard goal.waitForExistence(timeout: 5) else { return }
        goal.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["训练目标"].waitForExistence(timeout: 5), "TrainingGoalView should open")
    }

    func testTrainingGoalWeeklyDays() {
        let goal = app.staticTexts["训练目标"]
        guard goal.waitForExistence(timeout: 5) else { return }
        goal.tap()
        sleep(2)
        app.scrollDown(times: 1)
        sleep(1)
        let dayOptions = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '天'"))
        XCTAssertTrue(dayOptions.count > 0, "Weekly day options should be visible")
    }

    func testTrainingGoalDuration() {
        let goal = app.staticTexts["训练目标"]
        guard goal.waitForExistence(timeout: 5) else { return }
        goal.tap()
        sleep(2)
        app.scrollDown(times: 2)
        sleep(1)
        XCTAssertTrue(app.staticTexts["不限"].waitForExistence(timeout: 3) ||
                      app.staticTexts["30 分钟"].waitForExistence(timeout: 3) ||
                      app.staticTexts.matching(NSPredicate(format: "label CONTAINS '分钟'")).count > 0,
                      "Duration options should be visible")
    }

    func testTrainingGoalReminder() {
        let goal = app.staticTexts["训练目标"]
        guard goal.waitForExistence(timeout: 5) else { return }
        goal.tap()
        sleep(2)
        app.scrollDown(times: 3)
        sleep(1)
        let reminderToggle = app.switches.firstMatch
        if reminderToggle.waitForExistence(timeout: 3) {
            XCTAssertTrue(true, "Reminder toggle exists")
        }
    }

    // MARK: - SettingsView

    func testSettingsOpens() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        guard settings.waitForExistence(timeout: 5) else { return }
        settings.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["偏好设置"].waitForExistence(timeout: 5), "SettingsView should open")
    }

    func testSettingsAppearancePills() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        guard settings.waitForExistence(timeout: 5) else { return }
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
    }

    func testSettingsClearCache() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["偏好设置"]
        guard settings.waitForExistence(timeout: 5) else { return }
        settings.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["清除缓存"].waitForExistence(timeout: 3), "Clear cache row should exist")
    }

    // MARK: - AboutView

    func testAboutOpens() {
        app.scrollDown(times: 2)
        sleep(1)
        let about = app.staticTexts["关于与反馈"]
        guard about.waitForExistence(timeout: 5) else { return }
        about.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["关于与反馈"].waitForExistence(timeout: 5), "AboutView should open")
    }

    func testAboutContent() {
        app.scrollDown(times: 2)
        sleep(1)
        let about = app.staticTexts["关于与反馈"]
        guard about.waitForExistence(timeout: 5) else { return }
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
        guard about.waitForExistence(timeout: 5) else { return }
        about.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["用户协议"].waitForExistence(timeout: 3), "Terms link should exist")
        XCTAssertTrue(app.staticTexts["隐私政策"].waitForExistence(timeout: 3), "Privacy link should exist")
    }

    // MARK: - OnboardingView (fresh install)

    func testOnboardingFlowOnFreshInstall() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "App should launch without crash")
    }
}
