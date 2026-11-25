import XCTest

/// Explicitly opted-in, individually selected checks against a real device/account.
/// No launch fixtures or account deletion. Mutation flows restore settings and only
/// delete the explicitly named verification record after server-side verification.
final class RealServiceDeviceUITests: XCTestCase {
    private let recordMarker = "CuePhys验收-20261125-REAL01"

    func testRestoreAppleSessionWithUserAuthorization() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); app.launch(); app.switchTab(.profile)
        let account = app.buttons["profile.accountHeader"]
        if !account.waitForExistence(timeout: 10) {
            let login = app.buttons["profile.login"]
            for _ in 0..<6 where !login.isHittable { app.swipeDown() }
            XCTAssertTrue(login.waitForExistence(timeout: 15)); login.tap()
            let apple = app.buttons["通过 Apple 登录"]
            XCTAssertTrue(apple.waitForExistence(timeout: 15)); apple.tap()
            print("REAL_SERVICE appleAuthorizationNeedsUser=true")
            XCTAssertTrue(account.waitForExistence(timeout: 300))
        }
        let syncChoice = app.alerts["开启训练数据云同步？"]
        if syncChoice.exists { syncChoice.buttons["仅保存在本机"].tap() }
        app.terminate(); app.launch(); app.switchTab(.profile)
        XCTAssertTrue(account.waitForExistence(timeout: 45))
        print("REAL_SERVICE restoredAppleSession=true")
    }

    func testAppleReauthenticationWithUserAuthorization() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); app.launch(); app.switchTab(.profile)
        let account = app.buttons["profile.accountHeader"]
        XCTAssertTrue(account.waitForExistence(timeout: 45))
        let originalAccountLabel = account.label
        let logout = app.buttons["退出登录"]
        for _ in 0..<6 where !logout.isHittable { app.swipeUp() }
        XCTAssertTrue(logout.isHittable); logout.tap()
        let login = app.buttons["profile.login"]
        for _ in 0..<6 where !login.isHittable { app.swipeDown() }
        XCTAssertTrue(login.waitForExistence(timeout: 30)); login.tap()
        let apple = app.buttons["通过 Apple 登录"]
        XCTAssertTrue(apple.waitForExistence(timeout: 10)); apple.tap()
        // Age confirmation and Apple biometric/password authorization belong to the user.
        let needsAgeConfirmation = app.buttons["已满 14 周岁"].waitForExistence(timeout: 3)
        print("REAL_SERVICE appleStep=" + (needsAgeConfirmation ? "age-confirmation" : "apple-authorization"))
        try app.screenshot().pngRepresentation.write(to: URL.documentsDirectory.appendingPathComponent("apple-authorization.png"))
        print("REAL_SERVICE appleAuthorizationNeedsUser=true")
        XCTAssertTrue(account.waitForExistence(timeout: 300), "Waiting for the user's real Apple authorization")
        XCTAssertEqual(account.label, originalAccountLabel)
        let syncChoice = app.alerts["开启训练数据云同步？"]
        if syncChoice.exists { syncChoice.buttons["仅保存在本机"].tap() }
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "jwt audience invalid")).firstMatch.exists)
        app.terminate(); app.launch(); app.switchTab(.profile)
        XCTAssertTrue(account.waitForExistence(timeout: 45))
        XCTAssertEqual(account.label, originalAccountLabel)
        print("REAL_SERVICE appleReauthenticationAndColdRestore=true")
    }

    func testInspectSystemNotificationSettings() throws {
        try requireRealDeviceConsent()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let search = settings.searchFields.firstMatch
        if !search.exists { settings.swipeDown() }
        if !search.exists, settings.buttons["搜索"].exists { settings.buttons["搜索"].tap() }
        XCTAssertTrue(search.waitForExistence(timeout: 15)); search.tap()
        if search.buttons["清除文本"].exists { search.buttons["清除文本"].tap() }
        search.typeText("CuePhys")
        let entry = settings.buttons["OpenInstalledAppsSettingsDeepLinks.InstalledAppsSettingsDeepLinks.com.youbilliards.cuephys"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); entry.tap()
        let notifications = settings.staticTexts["通知"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 15)); notifications.tap()
        print("REAL_SERVICE systemSettings=" + settings.debugDescription)
        let snapshot = XCTAttachment(screenshot: settings.screenshot())
        snapshot.name = "system-notification-settings-private"; snapshot.lifetime = .keepAlways; add(snapshot)
    }

    func testNotificationDeniedAndReenabled() throws {
        try requireRealDeviceConsent()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let app = XCUIApplication()
        settings.activate()
        let allowed = settings.switches["ALLOW_NOTIFICATIONS_ID"]
        XCTAssertTrue(allowed.waitForExistence(timeout: 15), "Open CuePhys notification settings before selecting this test")
        XCTAssertEqual(allowed.value as? String, "1")
        let originalSound = settings.switches["SOUNDS_ID"].value as? String
        let originalMac = settings.switches["ALLOW_REMOTE_NOTIFICATIONS_ID"].value as? String
        let originalDestinations = ["锁屏", "通知中心", "横幅"].map { settings.buttons[$0].isSelected }
        addTeardownBlock {
            settings.activate()
            if !allowed.exists, settings.staticTexts["通知"].exists { settings.staticTexts["通知"].tap() }
            XCTAssertTrue(allowed.waitForExistence(timeout: 15))
            if allowed.value as? String != "1" { allowed.switches.firstMatch.tap() }
            XCTAssertEqual(allowed.value as? String, "1")
            app.activate()
            print("REAL_SERVICE notificationPermissionRestored=allowed")
        }
        allowed.switches.firstMatch.tap()
        XCTAssertEqual(allowed.value as? String, "0")
        openReminder(app)
        let permission = app.staticTexts["trainingReminder.authorization"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "label == %@", "系统通知权限未开启"), object: permission)], timeout: 15), .completed)
        setReminderEnabled(true, app: app)
        app.navigationBars.buttons["保存"].tap()
        let error = app.alerts["提醒设置"]
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        XCTAssertTrue(error.staticTexts["请在系统设置中允许 CuePhys 发送通知，然后返回保存。"].exists)
        let denied = XCTAttachment(screenshot: app.screenshot())
        denied.name = "real-notification-denied-private"; denied.lifetime = .keepAlways; add(denied)
        error.buttons["知道了"].tap()
        XCTAssertEqual(app.switches["trainingReminder.enabled"].value as? String, "0")
        app.buttons["前往系统设置"].tap()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15))
        // Foreground can precede completion of the app-settings deep link; the
        // previous notification pane may still be present in the first snapshot.
        XCTAssertTrue(settings.navigationBars["CuePhys"].waitForExistence(timeout: 15))
        let notificationEntry = settings.buttons["NOTIFICATIONS"]
        XCTAssertTrue(notificationEntry.waitForExistence(timeout: 15)); notificationEntry.tap()
        XCTAssertTrue(allowed.waitForExistence(timeout: 15))
        allowed.switches.firstMatch.tap()
        XCTAssertEqual(allowed.value as? String, "1")
        XCTAssertEqual(settings.switches["SOUNDS_ID"].value as? String, originalSound)
        XCTAssertEqual(settings.switches["ALLOW_REMOTE_NOTIFICATIONS_ID"].value as? String, originalMac)
        XCTAssertEqual(["锁屏", "通知中心", "横幅"].map { settings.buttons[$0].isSelected }, originalDestinations)
        app.activate()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "label == %@", "系统通知权限已开启"), object: permission)], timeout: 15), .completed)
        XCTAssertEqual(app.switches["trainingReminder.enabled"].value as? String, "0")
        print("REAL_SERVICE deniedSaveAndSettingsRecovery=true")
    }

    private func openAccountSettings(_ app: XCUIApplication) {
        app.terminate(); app.launch(); app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.accountHeader"].waitForExistence(timeout: 45))
        let settings = app.staticTexts["设置"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable); settings.tap()
        let toggle = app.switches["settings.cloudSync"]
        for _ in 0..<8 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.isHittable)
    }

    private func setCloudSync(_ enabled: Bool, app: XCUIApplication) {
        let toggle = app.switches["settings.cloudSync"]
        let expected = enabled ? "1" : "0"
        if toggle.value as? String != expected {
            let control = toggle.switches.firstMatch
            if control.exists { control.tap() } else { toggle.tap() }
        }
        let migration = app.alerts["合并本机游客记录？"]
        if enabled, migration.waitForExistence(timeout: 5) { migration.buttons["不合并"].tap() }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "value == %@", expected), object: toggle)], timeout: 10), .completed)
    }

    private func syncAccountAndWait(_ app: XCUIApplication) {
        setCloudSync(true, app: app)
        let status = app.staticTexts["settings.syncStatus"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "exists == true AND label BEGINSWITH %@", "同步完成"), object: status)], timeout: 180), .completed)
        XCTAssertFalse(app.alerts["同步失败"].exists)
        print("REAL_SERVICE actualCloudSyncCompleted=true")
        print("REAL_SERVICE restoreSummary=" + status.label)
    }

    func testFullAccountRestoreAfterPaginationFix() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); openAccountSettings(app)
        XCTAssertEqual(app.switches["settings.cloudSync"].value as? String, "0")
        addTeardownBlock {
            self.openAccountSettings(app); self.setCloudSync(false, app: app)
            print("REAL_SERVICE cloudSyncRestored=off")
        }
        syncAccountAndWait(app)
    }

    func testCreateMarkedManualTraining() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); app.launch(); app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.accountHeader"].waitForExistence(timeout: 45))
        app.switchTab(.training)
        let menu = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15)); menu.tap()
        app.buttons["补记训练"].tap()
        let minutes = app.textFields["manualTraining.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 10)); minutes.tap(); minutes.typeText("1")
        app.buttons["manualTraining.dismissKeyboard"].tap()
        let content = app.textViews["manualTraining.content"].exists
            ? app.textViews["manualTraining.content"] : app.textFields["manualTraining.content"]
        content.tap(); content.typeText(recordMarker)
        app.buttons["manualTraining.dismissKeyboard"].tap()
        let note = app.textViews["manualTraining.note"].exists
            ? app.textViews["manualTraining.note"] : app.textFields["manualTraining.note"]
        note.tap(); note.typeText("真机同步验收，验证后删除本条记录。")
        app.buttons["manualTraining.dismissKeyboard"].tap()
        app.buttons["manualTraining.save"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        app.terminate(); app.launch(); app.switchTab(.training)
        menu.tap(); app.buttons["训练心得"].tap()
        XCTAssertTrue(app.staticTexts[recordMarker].waitForExistence(timeout: 15), "Saved record must survive a normal relaunch")
        print("REAL_SERVICE markedManualRecordPersisted=true")
    }

    func testUploadMarkedTrainingThroughRealAccount() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); openAccountSettings(app)
        XCTAssertEqual(app.switches["settings.cloudSync"].value as? String, "0")
        addTeardownBlock {
            self.openAccountSettings(app)
            self.setCloudSync(false, app: app)
            print("REAL_SERVICE cloudSyncRestored=off")
        }
        syncAccountAndWait(app)
    }

    func testDeleteOnlyMarkedTrainingAndSync() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication(); app.launch(); app.switchTab(.training)
        let menu = app.buttons["trainingHome.moreMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15)); menu.tap(); app.buttons["训练心得"].tap()
        let marked = app.staticTexts[recordMarker]
        XCTAssertTrue(marked.waitForExistence(timeout: 15)); marked.tap()
        XCTAssertTrue(app.buttons["trainingNotes.record"].waitForExistence(timeout: 10))
        app.buttons["trainingNotes.record"].tap()
        XCTAssertTrue(app.staticTexts[recordMarker].waitForExistence(timeout: 10), "Only the explicitly marked test record may be deleted")
        app.buttons["删除记录"].tap(); app.buttons["删除"].tap()
        XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 15))
        XCTAssertFalse(marked.exists)
        openAccountSettings(app)
        addTeardownBlock {
            self.openAccountSettings(app); self.setCloudSync(false, app: app)
            print("REAL_SERVICE cloudSyncRestored=off")
        }
        syncAccountAndWait(app)
        print("REAL_SERVICE markedRecordDeletedLocally=true")
    }

    private func requireRealDeviceConsent() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the authorized physical device")
        #else
        let env = ProcessInfo.processInfo.environment
        guard env["CUEPHYS_REAL_SERVICE_VALIDATION"] == "1"
            || env["TEST_RUNNER_CUEPHYS_REAL_SERVICE_VALIDATION"] == "1" else {
            throw XCTSkip("Explicit real-account validation opt-in is required")
        }
        #endif
        continueAfterFailure = false
    }

    private func openReminder(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
        app.switchTab(.profile)
        let goal = app.staticTexts["训练目标"]
        for _ in 0..<5 where !goal.isHittable { app.swipeUp() }
        XCTAssertTrue(goal.isHittable)
        goal.tap()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "训练提醒")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.switches["trainingReminder.enabled"].waitForExistence(timeout: 10))
    }

    private func setReminderEnabled(_ enabled: Bool, app: XCUIApplication) {
        let row = app.switches["trainingReminder.enabled"]
        let expected = enabled ? "1" : "0"
        if row.value as? String != expected { row.switches.firstMatch.tap() }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "value == %@", expected), object: row)], timeout: 10), .completed)
    }

    private func setReminderTime(hour: Int, minute: Int, app: XCUIApplication) {
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.pickerWheels.count, 2)
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: String(format: "%02d", hour))
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: String(format: "%02d", minute))
        XCTAssertEqual(app.pickerWheels.element(boundBy: 0).value as? String, "\(hour)点")
        XCTAssertEqual(app.pickerWheels.element(boundBy: 1).value as? String, String(format: "%02d分钟", minute))
        app.buttons["PopoverDismissRegion"].coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.65)).tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 10))
    }

    private func saveReminder(_ app: XCUIApplication) {
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.navigationBars["训练目标"].waitForExistence(timeout: 15))
    }

    func testReminderDeliveryTapAndCancellation() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication()
        openReminder(app)
        XCTAssertEqual(app.switches["trainingReminder.enabled"].value as? String, "0", "Verified device baseline must still be disabled")
        // Restore the observed 19:00/off baseline even if the delivery assertion fails.
        addTeardownBlock {
            self.openReminder(app)
            self.setReminderEnabled(true, app: app)
            self.setReminderTime(hour: 19, minute: 0, app: app)
            self.saveReminder(app)
            self.openReminder(app)
            self.setReminderEnabled(false, app: app)
            self.saveReminder(app)
            self.openReminder(app)
            XCTAssertEqual(app.switches["trainingReminder.enabled"].value as? String, "0")
            app.terminate(); app.launch()
            print("REAL_SERVICE reminderRestored=19:00/off")
        }
        setReminderEnabled(true, app: app)
        let calendar = Calendar.current
        let target = calendar.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(180))!
        setReminderTime(hour: calendar.component(.hour, from: target), minute: calendar.component(.minute, from: target), app: app)
        saveReminder(app)
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let title = springboard.staticTexts["今天练一会儿球吧"].firstMatch
        print("REAL_SERVICE waitingForNotification=" + target.ISO8601Format())
        XCTAssertTrue(title.waitForExistence(timeout: max(30, target.timeIntervalSinceNow + 45)), "Actual scheduled notification must be delivered")
        let notification = XCTAttachment(screenshot: springboard.screenshot())
        notification.name = "real-reminder-delivered-private"; notification.lifetime = .keepAlways; add(notification)
        title.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 20), "Notification must return to the training home")
        print("REAL_SERVICE notificationDeliveredAndRouted=true")

        openReminder(app)
        let cancelledTarget = calendar.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(180))!
        setReminderTime(hour: calendar.component(.hour, from: cancelledTarget), minute: calendar.component(.minute, from: cancelledTarget), app: app)
        saveReminder(app)
        openReminder(app)
        setReminderEnabled(false, app: app)
        saveReminder(app)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(title.waitForNonExistence(timeout: 10))
        let cancelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: title)
        cancelled.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: max(30, cancelledTarget.timeIntervalSinceNow + 30)), .completed)
        print("REAL_SERVICE cancelledReminderDidNotDeliver=true")
    }

    func testReminderPermissionAndTimeControls() throws {
        try requireRealDeviceConsent()
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate(); app.launch() }
        app.switchTab(.profile)
        XCTAssertTrue(app.buttons["profile.accountHeader"].waitForExistence(timeout: 45))
        let goal = app.staticTexts["训练目标"]
        for _ in 0..<5 where !goal.isHittable { app.swipeUp() }
        XCTAssertTrue(goal.isHittable)
        goal.tap()
        let reminder = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "训练提醒")).firstMatch
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        reminder.tap()
        let permission = app.staticTexts["trainingReminder.authorization"]
        XCTAssertTrue(permission.waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "label == %@", "系统通知权限已开启"), object: permission)], timeout: 15), .completed)
        let enabled = app.switches["trainingReminder.enabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 10))
        print("REAL_SERVICE reminderOriginallyEnabled=\(enabled.value as? String ?? "unknown")")
        if enabled.value as? String == "0" {
            // On the physical phone the identified element spans the whole row;
            // its child is the actual UISwitch, while tapping the row is inert.
            let control = enabled.switches.firstMatch
            XCTAssertTrue(control.exists)
            control.tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate:
            NSPredicate(format: "value == %@", "1"), object: enabled)], timeout: 10), .completed)
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        let snapshot = XCTAttachment(screenshot: app.screenshot())
        snapshot.name = "real-reminder-controls-private"
        snapshot.lifetime = .keepAlways
        add(snapshot)
        print("REAL_SERVICE reminderControls=" + app.debugDescription)
    }

    func testExistingAccountSurvivesNormalColdLaunch() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the authorized physical device and existing account")
        #else
        let environment = ProcessInfo.processInfo.environment
        guard environment["CUEPHYS_REAL_SERVICE_VALIDATION"] == "1"
            || environment["TEST_RUNNER_CUEPHYS_REAL_SERVICE_VALIDATION"] == "1" else {
            throw XCTSkip("Explicit real-account validation opt-in is required")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        app.switchTab(.profile)
        let account = app.buttons["profile.accountHeader"]
        XCTAssertTrue(account.waitForExistence(timeout: 45), "Existing real account should restore")
        XCTAssertFalse(app.buttons["profile.login"].exists)
        let settings = app.staticTexts["设置"]
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        settings.tap()
        let sync = app.switches["settings.cloudSync"]
        XCTAssertTrue(sync.waitForExistence(timeout: 30), "Online account settings require authenticated state")
        for _ in 0..<8 where !sync.isHittable { app.swipeUp() }
        XCTAssertTrue(sync.isHittable)
        XCTAssertTrue(["0", "1"].contains(sync.value as? String ?? ""))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "real-account-settings-private"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("REAL_SERVICE existingAccount=true cloudSync=\(sync.value as? String ?? "unknown")")
        #endif
    }
}

final class P8_ProfileSettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.profile)
        sleep(3)
    }

    func testUnder14ChoiceReturnsToGuestTraining() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-auth.deviceGuestID", UUID().uuidString, "-v50.inMemoryStore"])
        app.switchTab(.profile)
        app.buttons["profile.login"].tap()
        app.buttons["通过 Apple 登录"].tap()
        let child = app.buttons["不满 14 周岁，继续本机训练"]
        XCTAssertTrue(child.waitForExistence(timeout: 5))
        child.tap()
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 8))
        app.buttons["profile.login"].tap()
        XCTAssertTrue(app.buttons["暂不登录，匿名使用"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["通过 Apple 登录"].exists)
        app.buttons["暂不登录，匿名使用"].tap()
        app.switchTab(.training)
        XCTAssertTrue(app.buttons["trainingHome.dailyClearance"].waitForExistence(timeout: 8))
    }

    func testStartupWithoutOnboardingGoesStraightToMain() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "NO", "-v50.inMemoryStore", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        app.switchTab(.profile)
        XCTAssertFalse(app.otherElements["auth.launching"].exists)
        XCTAssertFalse(app.staticTexts["正在恢复账号…"].exists)
        XCTAssertTrue(app.buttons["profile.login"].waitForExistence(timeout: 5))
        captureSyncChoice("startup-profile")
    }

    func testCloudSyncChoiceAndSettingsPersist() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-syncChoice.explicitLogin", "-v50.inMemoryStore", "-v49.forceLight"])
        let prompt = app.alerts["开启训练数据云同步？"]
        if !prompt.waitForExistence(timeout: 2) { app.switchTab(.profile) }
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        captureSyncChoice("cloud-sync-choice")
        prompt.buttons["仅保存在本机"].tap()
        app.switchTab(.profile)
        app.staticTexts["设置"].tap()
        let toggle = app.switches["settings.cloudSync"]
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.value as? String, "0")
        captureSyncChoice("settings-sync-off")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        captureSyncChoice("settings-sync-on")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-syncChoice.explicitLogin" }
        app.launch()
        app.switchTab(.profile)
        XCTAssertFalse(app.alerts["开启训练数据云同步？"].exists)
        app.staticTexts["设置"].tap()
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
    }

    func testDeclineLogoutReloginThenEnableRestoresTraining() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-syncRepair.loginSheet", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        let login = app.buttons["profile.login"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        login.tap()
        app.buttons["通过 Apple 登录"].tap()
        app.buttons["已满 14 周岁"].tap()
        let prompt = app.alerts["开启训练数据云同步？"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 8), "登录 sheet 关闭后必须呈现同步选择")
        captureSyncChoice("repair-login-choice")
        prompt.buttons["仅保存在本机"].tap()
        app.switchTab(.history)
        XCTAssertFalse(app.staticTexts["23 分钟"].exists)
        app.switchTab(.profile)
        let logout = app.buttons["退出登录"]
        for _ in 0..<4 where !logout.isHittable { app.swipeUp() }
        logout.tap()
        if app.alerts.buttons["退出登录"].waitForExistence(timeout: 2) {
            app.alerts.buttons["退出登录"].tap()
        }
        XCTAssertTrue(login.waitForExistence(timeout: 8))
        login.tap()
        app.buttons["通过 Apple 登录"].tap()
        app.buttons["已满 14 周岁"].tap()
        XCTAssertTrue(app.buttons["profile.accountHeader"].waitForExistence(timeout: 8))
        XCTAssertFalse(prompt.exists, "拒绝的选择应保留，设置仍可重新开启")
        app.staticTexts["设置"].tap()
        let toggle = app.switches["settings.cloudSync"]
        for _ in 0..<5 where !toggle.isHittable { app.swipeUp() }
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        let status = app.staticTexts["settings.syncStatus"]
        for _ in 0..<3 where !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(status.label.contains("恢复 1 条训练记录"), status.label)
        captureSyncChoice("repair-settings-restored")
        let sync = app.buttons["settings.syncNow"]
        XCTAssertTrue(sync.isHittable)
        sync.tap()
        XCTAssertTrue(status.label.contains("恢复 0 条训练记录"), "重复恢复不能产生重复记录")
        app.navigationBars.buttons.firstMatch.tap()
        app.switchTab(.history)
        XCTAssertTrue(app.staticTexts["23 分钟"].waitForExistence(timeout: 8))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["23 分钟"].isHittable)
        captureSyncChoice("repair-history-restored")
    }

    func testRestoreFailureAndGuestMergeAreVisible() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-syncRepair.loginSheet", "-syncRepair.guestData", "-syncRepair.restoreFailure", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        app.buttons["profile.login"].tap()
        app.buttons["通过 Apple 登录"].tap()
        app.buttons["已满 14 周岁"].tap()
        let choice = app.alerts["开启训练数据云同步？"]
        XCTAssertTrue(choice.waitForExistence(timeout: 8))
        choice.buttons["开启云同步"].tap()
        let merge = app.alerts["合并本机游客记录？"]
        XCTAssertTrue(merge.waitForExistence(timeout: 8), "开启云同步后游客合并提示不可丢失")
        captureSyncChoice("repair-guest-merge")
        merge.buttons["合并并同步"].tap()
        let failure = app.alerts["同步失败"]
        XCTAssertTrue(failure.waitForExistence(timeout: 8))
        captureSyncChoice("repair-sync-failure")
        failure.buttons["确定"].tap()
        app.staticTexts["设置"].tap()
        let sync = app.buttons["settings.syncNow"]
        for _ in 0..<5 where !sync.isHittable { app.swipeUp() }
        let status = app.staticTexts["settings.syncStatus"]
        XCTAssertTrue(status.label.contains("同步未完成"))
        captureSyncChoice("repair-failure-settings")
        sync.tap()
        XCTAssertTrue(failure.waitForExistence(timeout: 8), "设置内重试失败也必须可见")
        failure.buttons["确定"].tap()
    }

    private func captureSyncChoice(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
        for sport in ["中八", "追分", "两者"] {
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
        let reminderEntry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "训练提醒")).firstMatch
        XCTAssertTrue(reminderEntry.waitForExistence(timeout: 5))
        reminderEntry.tap()
        let reminderToggle = app.switches["trainingReminder.enabled"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 3), "训练提醒开关必须存在")
        let authorization = app.staticTexts["trainingReminder.authorization"]
        XCTAssertTrue(authorization.waitForExistence(timeout: 3), "必须显示系统通知权限状态")
        XCTAssertTrue(
            ["保存并开启提醒时，将请求系统通知权限。", "系统通知权限已开启", "系统通知权限未开启"]
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

    func testAccountSecurityShowsBindingAvailability() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore"])
        app.switchTab(.profile)
        let settings = app.staticTexts["设置"]
        for _ in 0..<6 where !settings.isHittable { app.swipeUp() }
        settings.tap()
        let apple = app.buttons["settings.bind.apple"]
        for _ in 0..<10 where !apple.isHittable { app.swipeUp() }
        XCTAssertTrue(apple.exists)
        XCTAssertTrue(apple.label.contains("已绑定"))
        XCTAssertFalse(apple.isEnabled)
        XCTAssertTrue(app.buttons["settings.bind.wechat"].exists)
    }

    func testSettingsOpens() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "设置入口必须存在")
        settings.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5), "SettingsView should open")
    }

    func testSettingsAppearancePills() {
        app.scrollDown(times: 2)
        sleep(1)
        let settings = app.staticTexts["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "设置入口必须存在")
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
        let settings = app.staticTexts["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "设置入口必须存在")
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
        let reopenedSettings = app.staticTexts["设置"]
        XCTAssertTrue(reopenedSettings.waitForExistence(timeout: 5), "冷启动后设置入口必须存在")
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
        let settings = app.staticTexts["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "设置入口必须存在")
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
        XCTAssertTrue(app.staticTexts["CuePhys"].waitForExistence(timeout: 3), "App name should be visible")
        XCTAssertTrue(app.staticTexts["意见反馈"].waitForExistence(timeout: 3), "Feedback row should exist")
        XCTAssertTrue(app.staticTexts["给个好评"].waitForExistence(timeout: 3), "Rate app row should exist")
        captureSyncChoice("about-contact-current")
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
        XCTAssertFalse(app.links["about.terms"].exists)
        XCTAssertFalse(app.links["about.privacy"].exists)
        captureSyncChoice("about-legal-unpublished")
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

        let reminderEntry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "训练提醒")).firstMatch
        XCTAssertTrue(reminderEntry.waitForExistence(timeout: 5))
        reminderEntry.tap()
        let reminderToggle = app.switches["trainingReminder.enabled"]
        XCTAssertTrue(reminderToggle.waitForExistence(timeout: 5), "训练提醒开关必须存在")
        XCTAssertTrue(
            app.staticTexts["保存并开启提醒时，将请求系统通知权限。"].waitForExistence(timeout: 3),
            "全新模拟器必须从通知权限未决定态开始"
        )

        // On iPad the switch accessibility frame spans the full row.
        let trailingEdge = reminderToggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        trailingEdge.withOffset(CGVector(dx: -25, dy: 0)).tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 3), "开启开关后应出现提醒时间")
        app.navigationBars.buttons["保存"].tap()
        let systemAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(systemAlert.waitForExistence(timeout: 8), "必须看到真实通知权限弹框")
        let labels = allow ? ["允许", "好", "OK", "Allow"] : ["不允许", "Don’t Allow", "Don't Allow"]
        let action = systemAlert.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
        XCTAssertTrue(action.exists, systemAlert.debugDescription)
        action.tap()

        if allow {
            XCTAssertTrue(reminderEntry.waitForExistence(timeout: 8), "保存后返回训练目标")
            reminderEntry.tap()
            XCTAssertTrue(app.staticTexts["系统通知权限已开启"].waitForExistence(timeout: 5))
            XCTAssertEqual(reminderToggle.value as? String, "1", "允许后提醒开关必须保持开启")
        } else {
            let failure = app.alerts["提醒设置"]
            XCTAssertTrue(failure.waitForExistence(timeout: 5), "拒绝后必须解释无法开启提醒")
            XCTAssertTrue(failure.buttons["知道了"].waitForExistence(timeout: 3))
            failure.buttons["知道了"].tap()
            XCTAssertEqual(reminderToggle.value as? String, "0", "拒绝后提醒开关必须回退关闭")
        }
    }
}

extension P8_ProfileSettingsUITests {
    func testInitialProfileAutomaticImportAndFourSports() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-syncRepair.loginSheet", "-profileImport.fixture", "-v50.inMemoryStore"])
        app.switchTab(.profile)
        app.buttons["profile.login"].tap()
        app.buttons["通过 Apple 登录"].tap()
        app.buttons["已满 14 周岁"].tap()
        let sync = app.alerts["开启训练数据云同步？"]
        XCTAssertTrue(sync.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["profileImport.confirm"].exists)
        sync.buttons["仅保存在本机"].tap()
        app.staticTexts["个人信息"].tap()
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 5))
        captureSyncChoice("profile-import-personal-header")
        for _ in 0..<4 where !app.buttons["其他"].isHittable { app.swipeUp() }
        for label in ["中八", "追分", "两者", "其他"] {
            XCTAssertTrue(app.buttons[label].isHittable, "Sport must be visible and tappable: \(label)")
        }
        XCTAssertFalse(app.buttons["9 球"].exists)
        XCTAssertTrue(app.buttons["追分"].value as? String == "已选中" || app.buttons["追分"].isSelected)
        captureSyncChoice("profile-import-personal-info")
    }

    func testInitialProfileImportFailureDoesNotBlockLogin() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-syncRepair.loginSheet", "-profileImport.fixture", "-profileImport.failure", "-v50.inMemoryStore"])
        app.switchTab(.profile)
        app.buttons["profile.login"].tap()
        app.buttons["通过 Apple 登录"].tap()
        app.buttons["已满 14 周岁"].tap()
        let sync = app.alerts["开启训练数据云同步？"]
        XCTAssertTrue(sync.waitForExistence(timeout: 8))
        sync.buttons["仅保存在本机"].tap()
        XCTAssertFalse(app.buttons["profileImport.confirm"].exists)
        XCTAssertFalse(app.buttons["profileImport.decline"].exists)
        app.staticTexts["个人信息"].tap()
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 5))
        captureSyncChoice("profile-import-offline-no-prompt")
    }
}
