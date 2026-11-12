import XCTest

final class LaunchPermissionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCancelBothSystemPickers() {
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium", "-pro.route=photo"])
        let pick = app.buttons["选择照片"]
        XCTAssertTrue(pick.waitForExistence(timeout: 10))
        pick.tap()
        cancelSystemPicker(app)
        XCTAssertTrue(pick.isHittable)
        XCTAssertFalse(app.buttons["下一步"].exists)

        app.terminate()
        let guest = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore"])
        guest.switchTab(.profile)
        let info = guest.staticTexts["个人信息"]
        XCTAssertTrue(info.waitForExistence(timeout: 8))
        info.tap()
        let avatar = guest.buttons["personalInfo.avatarPicker"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 8))
        avatar.tap()
        cancelSystemPicker(guest)
        XCTAssertTrue(avatar.isHittable)
    }

    private func cancelSystemPicker(_ app: XCUIApplication) {
        let names = ["取消", "Cancel", "关闭", "Close"]
        let close = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@ OR identifier IN %@", names, names)).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 8), app.debugDescription)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 6))
    }

    // Run the allow/deny cases under distinct fresh app identifiers for real TCC prompts.
    func testGuestTrainingAndSharePhotoDecision() throws {
        let choice = ProcessInfo.processInfo.environment["CUEPHYS_PHOTO_CHOICE"]
        try XCTSkipUnless(choice == "allow" || choice == "deny", "Specify the decision and use a fresh isolated app identifier")
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-v51.activeTraining"])
        let share = finishGuestSession(app)
        share.tap()
        let save = app.buttons["shareSaveToPhotos"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "点击保存相册才应触发系统请求")
        let labels = choice == "allow"
            ? ["允许", "好", "允许添加照片", "Allow", "OK", "Allow Adding Photos"]
            : ["不允许", "Don’t Allow", "Don't Allow"]
        let action = alert.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(action.exists, alert.debugDescription)
        action.tap()
        if choice == "deny" {
            let failure = app.alerts["保存失败"]
            XCTAssertTrue(failure.waitForExistence(timeout: 8))
            XCTAssertTrue(failure.staticTexts.containing(NSPredicate(format: "label CONTAINS '写入照片'")).firstMatch.exists)
            failure.buttons["确定"].tap()
            app.buttons["返回"].tap()
        }
        XCTAssertTrue(save.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 6), "已成功保存训练记录")
        if choice == "deny" {
            app.terminate()
            app.launch()
            let nextShare = finishGuestSession(app)
            nextShare.tap()
            XCTAssertTrue(save.waitForExistence(timeout: 8))
            app.buttons["返回"].tap()
            XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 6))
        }
    }

    private func finishGuestSession(_ app: XCUIApplication) -> XCUIElement {
        let timer = app.buttons["activeTraining.timerToggle"]
        XCTAssertTrue(timer.waitForExistence(timeout: 12))
        XCTAssertEqual(timer.label, "暂停计时")
        timer.tap()
        XCTAssertEqual(timer.label, "继续计时")
        timer.tap()
        let end = app.buttons["activeTraining.end"]
        if end.exists { end.tap() } else {
            app.buttons["activeTraining.more"].tap()
            app.buttons["结束训练"].tap()
        }
        app.alerts.buttons["结束"].tap()
        let hideKeyboard = app.buttons["trainingNote.dismissKeyboard"]
        if hideKeyboard.waitForExistence(timeout: 3) { hideKeyboard.tap() }
        app.buttons["跳过"].tap()
        let share = app.buttons["生成分享图"]
        XCTAssertTrue(share.waitForExistence(timeout: 8))
        return share
    }
}
