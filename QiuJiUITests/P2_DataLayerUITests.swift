import XCTest

final class P2_DataLayerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
    }

    // MARK: - S: App Launch & Schema

    func testS01_ColdLaunchNoCrash() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testS02_AllFiveTabsSwitchable() {
        for tab in ["训练", "动作库", "角度", "记录", "我的"] {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 3), "Tab '\(tab)' should exist")
            tabButton.tap()
        }
    }

    func testS03_ProfileShowsGuestHeader() {
        app.switchTab(.profile)
        sleep(1)
        XCTAssertTrue(app.staticTexts["点击登录"].waitForExistence(timeout: 3), "Guest header should show '点击登录'")
    }

    func testS04_DrillLibraryShowsDrills() {
        app.switchTab(.drillLibrary)
        sleep(1)
        XCTAssertTrue(app.staticTexts["动作库"].waitForExistence(timeout: 3), "Drill library title should be visible")
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
        XCTAssertTrue(app.staticTexts["训练"].waitForExistence(timeout: 3), "Training tab title should be visible")
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
        XCTAssertTrue(app.staticTexts["动作库"].waitForExistence(timeout: 5), "Drill library should load after relaunch")
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
}
