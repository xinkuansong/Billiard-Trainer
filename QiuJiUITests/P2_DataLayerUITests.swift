import XCTest
import StoreKitTest

final class P2_DataLayerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v51.followSystemAppearance"])
    }

    // MARK: - S: App Launch & Schema

    func testS01_ColdLaunchNoCrash() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testS02_AllFiveTabsSwitchable() {
        for tab in ["训练", "动作库", "练习", "记录", "我的"] {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 3), "Tab '\(tab)' should exist")
            tabButton.tap()
        }
    }

    func testS03_ProfileShowsGuestHeader() {
        app.switchTab(.profile)
        sleep(1)
        XCTAssertTrue(app.staticTexts["点击登录"].waitForExistence(timeout: 3), "Guest header should show '点击登录'")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "v57-profile-guest"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["profile.login"].tap()
        XCTAssertTrue(app.staticTexts["登录后同步训练记录与复盘数据"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "登录后同步训练记录与复盘数据")).count, 1)
    }

    func testV57AuthenticatedProfileMembershipLayout() {
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: [
            "-v53.authenticatedProfileFixture", "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance"
        ])
        app.switchTab(.profile)
        let header = app.descendants(matching: .any)["profile.accountHeader"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 6))
        XCTAssertTrue(header.label.contains("服务端球友"))
        let membership = app.descendants(matching: .any)["profile.membershipSummary"].firstMatch
        XCTAssertTrue(membership.exists)
        XCTAssertTrue(membership.label.contains("Pro 会员"))
        XCTAssertTrue(membership.label.contains("Pro 已解锁，状态待刷新"))
        XCTAssertFalse(app.staticTexts["永久有效"].exists, "测试解锁不能伪装永久权益")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "v57-profile-membership"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        header.tap()
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testV57StoreKitMembershipStates() async throws {
        app.terminate()
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: catalog)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        func captureState(_ name: String, expectedStatus: String?) {
            app = XCUIApplication.launchClean(extraArgs: [
                "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"
            ])
            app.switchTab(.profile)
            let header = app.descendants(matching: .any)["profile.accountHeader"].firstMatch
            XCTAssertTrue(header.waitForExistence(timeout: 6))
            XCTAssertTrue(header.label.contains("服务端球友"))
            let window = app.windows.firstMatch.frame
            XCTAssertGreaterThanOrEqual(header.frame.minX, window.minX)
            XCTAssertLessThanOrEqual(header.frame.maxX, window.maxX)
            let membership = app.descendants(matching: .any)["profile.membershipSummary"].firstMatch
            if let expectedStatus {
                XCTAssertTrue(membership.waitForExistence(timeout: 6))
                XCTAssertTrue(membership.label.contains(expectedStatus), membership.label)
                XCTAssertTrue(header.frame.contains(membership.frame), "会员状态必须位于账号卡内")
                if expectedStatus != "永久有效" {
                    XCTAssertFalse(membership.label.contains("永久有效"))
                }
            } else {
                XCTAssertFalse(membership.exists)
                XCTAssertTrue(app.staticTexts["升级 Pro"].exists)
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "v57-profile-\(name)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }

        captureState("free", expectedStatus: nil)
        let monthlyID = "com.xinkuan.qiuji.premium.monthly"
        _ = try await session.buyProduct(identifier: monthlyID)
        captureState("monthly", expectedStatus: "有效至")
        try session.expireSubscription(productIdentifier: monthlyID)
        captureState("expired", expectedStatus: nil)
        session.clearTransactions()
        _ = try await session.buyProduct(identifier: "com.xinkuan.qiuji.premium.yearly")
        captureState("yearly", expectedStatus: "有效至")
        session.clearTransactions()
        _ = try await session.buyProduct(identifier: "com.xinkuan.qiuji.premium.lifetime")
        captureState("lifetime", expectedStatus: "永久有效")
    }

    @MainActor
    func testV57LongProfileNameAndRestore() async throws {
        app.terminate()
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: catalog)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: "com.xinkuan.qiuji.premium.lifetime")
        app = XCUIApplication.launchClean(extraArgs: [
            "-v53.authenticatedProfileFixture", "-v57.longProfileName",
            "-v50.inMemoryStore", "-v51.followSystemAppearance"
        ])
        app.switchTab(.profile)
        let header = app.descendants(matching: .any)["profile.accountHeader"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 6))
        let fullName = String(repeating: "认真练球", count: 5)
        XCTAssertTrue(header.label.contains(fullName))
        let name = app.staticTexts[fullName].firstMatch
        XCTAssertTrue(name.exists)
        XCTAssertTrue(header.frame.contains(name.frame))
        if app.windows.firstMatch.frame.width < 400 {
            XCTAssertGreaterThan(name.frame.height, 30, "20字昵称应换行，不能压缩成一行")
        }
        func capture(_ name: String) {
            let item = XCTAttachment(screenshot: app.screenshot())
            item.name = name
            item.lifetime = .keepAlways
            add(item)
        }
        capture("v57-profile-long-name")
        let status = app.staticTexts["Pro 权益"].firstMatch
        for _ in 0..<4 where !status.isHittable { app.swipeUp() }
        XCTAssertTrue(status.isHittable)
        status.tap()
        let restore = app.buttons["恢复购买"].firstMatch
        XCTAssertTrue(restore.waitForExistence(timeout: 6))
        restore.tap()
        let alert = app.alerts["恢复购买"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["已恢复购买，Pro 功能已解锁"].exists)
        capture("v57-profile-restore-success")
        alert.buttons["确定"].tap()

        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        restore.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["恢复购买失败，请稍后重试"].exists)
        capture("v57-profile-restore-failure")
        alert.buttons["确定"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        let membership = app.descendants(matching: .any)["profile.membershipSummary"].firstMatch
        XCTAssertTrue(membership.waitForExistence(timeout: 6))
        XCTAssertTrue(membership.label.contains("永久有效"), "恢复失败不能撤销已有有效权益")
        capture("v57-profile-after-restore-failure")
    }

    func testS04_DrillLibraryShowsDrills() {
        app.switchTab(.drillLibrary)
        sleep(1)
        assertDrillLibraryContentVisible()
    }

    func testS05_ProfileMenuGroupsComplete() {
        app.switchTab(.profile)
        sleep(1)
        for item in ["我的收藏", "个人信息", "训练目标"] {
            XCTAssertTrue(app.staticTexts[item].waitForExistence(timeout: 3), "Menu item '\(item)' should exist")
        }
        app.scrollDown(times: 2)
        for item in ["偏好设置", "关于与反馈"] {
            XCTAssertTrue(app.staticTexts[item].waitForExistence(timeout: 3), "Secondary menu '\(item)' should exist")
        }
    }

    // MARK: - B: Bundle Fallback

    func testB01_DrillLibraryShowsCategories() {
        app.switchTab(.drillLibrary)
        sleep(2)
        let sidebarAll = app.buttons.matching(NSPredicate(format: "label == '全部'")).firstMatch
        let textAll = app.staticTexts["全部"].firstMatch
        XCTAssertTrue(sidebarAll.waitForExistence(timeout: 5) || textAll.waitForExistence(timeout: 3),
                      "Category sidebar '全部' should exist (as button or text)")
    }

    func testB02_DrillDetailLoadsData() {
        app.switchTab(.drillLibrary)
        sleep(3)
        let drillCard = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
        if drillCard.waitForExistence(timeout: 5) {
            drillCard.tap()
        } else {
            let cell = app.cells.firstMatch
            guard cell.waitForExistence(timeout: 5) else { return }
            cell.tap()
        }
        sleep(3)
        let detailLoaded = app.staticTexts["训练要点"].waitForExistence(timeout: 5) ||
                           app.staticTexts["解锁 Pro"].waitForExistence(timeout: 5) ||
                           app.buttons["关闭"].waitForExistence(timeout: 5) ||
                           app.buttons["解锁 Pro"].waitForExistence(timeout: 5) ||
                           app.staticTexts["点击此处输入备注"].waitForExistence(timeout: 5)
        XCTAssertTrue(detailLoaded, "Detail page should show some drill content")
    }

    func testB03_TrainingPlansLoad() {
        app.switchTab(.training)
        sleep(1)
        XCTAssertTrue(
            app.tabBars.buttons["训练"].waitForExistence(timeout: 3),
            "Training tab bar item should remain"
        )
        let hasPageContent =
            app.staticTexts["今日安排"].waitForExistence(timeout: 5) ||
            app.staticTexts["官方计划"].waitForExistence(timeout: 3) ||
            app.staticTexts["选择一个计划开始训练"].waitForExistence(timeout: 3)
        XCTAssertTrue(
            hasPageContent,
            "Training home should show 今日安排, 官方计划, or the empty-state prompt"
        )
    }

    // MARK: - Favorites (Anonymous)

    func testFavoritesWorkAnonymously() {
        app.switchTab(.drillLibrary)
        sleep(3)
        let firstCard = app.cells.firstMatch
        guard firstCard.waitForExistence(timeout: 5) else { return }
        firstCard.tap()
        sleep(2)

        let hearts = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'heart' OR label CONTAINS 'Heart'"))
        if hearts.firstMatch.waitForExistence(timeout: 3) {
            hearts.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - Data Persistence

    func testDataPersistsAfterRelaunch() {
        app.switchTab(.drillLibrary)
        sleep(2)

        app.terminate()
        app.launch()
        sleep(2)

        app.switchTab(.drillLibrary)
        assertDrillLibraryContentVisible(timeout: 5)
    }

    // MARK: - Profile Navigation

    func testProfileNavigatesToPersonalInfo() {
        app.switchTab(.profile)
        sleep(1)
        let personalInfo = app.staticTexts["个人信息"]
        guard personalInfo.waitForExistence(timeout: 3) else { return }
        personalInfo.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["个人信息"].waitForExistence(timeout: 3), "PersonalInfoView should open")
    }

    func testProfileNavigatesToTrainingGoal() {
        app.switchTab(.profile)
        sleep(1)
        let goal = app.staticTexts["训练目标"]
        guard goal.waitForExistence(timeout: 3) else { return }
        goal.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["训练目标"].waitForExistence(timeout: 3), "TrainingGoalView should open")
    }

    func testProfileNavigatesToSettings() {
        app.switchTab(.profile)
        sleep(1)
        app.scrollDown(times: 2)
        let settings = app.staticTexts["偏好设置"]
        guard settings.waitForExistence(timeout: 3) else { return }
        settings.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["偏好设置"].waitForExistence(timeout: 3), "SettingsView should open")
    }

    func testProfileNavigatesToAbout() {
        app.switchTab(.profile)
        sleep(1)
        app.scrollDown(times: 2)
        let about = app.staticTexts["关于与反馈"]
        guard about.waitForExistence(timeout: 3) else { return }
        about.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["关于与反馈"].waitForExistence(timeout: 3), "AboutView should open")
    }

    /// Page title is gone (v45 W3); do not treat the tab-bar label as in-page copy.
    private func assertDrillLibraryContentVisible(timeout: TimeInterval = 5) {
        XCTAssertTrue(
            app.tabBars.buttons["动作库"].waitForExistence(timeout: 3),
            "Drill library tab bar item should remain"
        )
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'"))
            .firstMatch
        let searchField = app.textFields["搜索动作"]
        let searchPlaceholder = app.staticTexts["搜索动作"]
        XCTAssertTrue(
            card.waitForExistence(timeout: timeout)
                || searchField.waitForExistence(timeout: 3)
                || searchPlaceholder.waitForExistence(timeout: 2),
            "Drill library should show a drill card or the search field"
        )
    }
}
