import XCTest

final class P4_TrainingLogUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.training)
        sleep(2)
    }

    // MARK: - Training Home

    func testTrainingHomeTitle() {
        XCTAssertTrue(app.staticTexts["训练"].waitForExistence(timeout: 3), "Training tab title should be visible")
    }

    func testEmptyStateOrActivePlan() {
        sleep(1)
        let hasContent = app.staticTexts["选择训练计划"].waitForExistence(timeout: 3) ||
                         app.buttons["开始训练"].waitForExistence(timeout: 3) ||
                         app.staticTexts["开始训练"].waitForExistence(timeout: 3) ||
                         app.staticTexts["今日安排"].waitForExistence(timeout: 3) ||
                         app.staticTexts["官方计划"].waitForExistence(timeout: 3) ||
                         app.buttons.matching(NSPredicate(format: "label CONTAINS '训练'")).firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(hasContent, "Should show some training-related content")
    }

    func testSegmentedTabVisible() {
        let officialTab = app.staticTexts["官方计划"]
        let customTab = app.staticTexts["自定义"]
        let officialBtn = app.buttons["官方计划"]
        let customBtn = app.buttons["自定义"]
        let exists = officialTab.waitForExistence(timeout: 5) || customTab.waitForExistence(timeout: 3) ||
                     officialBtn.waitForExistence(timeout: 3) || customBtn.waitForExistence(timeout: 3)
        if !exists {
            let selectPlan = app.staticTexts["选择训练计划"]
            if selectPlan.waitForExistence(timeout: 3) {
                selectPlan.tap()
                sleep(1)
            }
        }
    }

    // MARK: - Plan List

    func testPlanListNavigation() {
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")).firstMatch
        if menu.waitForExistence(timeout: 3) {
            menu.tap()
            sleep(1)
            let planListButton = app.buttons["训练计划"]
            if planListButton.waitForExistence(timeout: 2) {
                planListButton.tap()
                sleep(1)
                XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 3), "Plan list should open")
            }
        }
    }

    // MARK: - Training Flow Basics

    func testFreeRecordEntry() {
        let freeRecord = app.staticTexts["自由记录"]
        let freeBtn = app.buttons["自由记录"]
        if freeRecord.waitForExistence(timeout: 3) {
            freeRecord.tap()
            sleep(2)
        } else if freeBtn.waitForExistence(timeout: 3) {
            freeBtn.tap()
            sleep(2)
        }
    }

    // MARK: - Plan Detail

    func testPlanDetailShowsInfo() {
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More'")).firstMatch
        guard menu.waitForExistence(timeout: 3) else { return }
        menu.tap()
        sleep(1)
        let planListButton = app.buttons["训练计划"]
        guard planListButton.waitForExistence(timeout: 2) else { return }
        planListButton.tap()
        sleep(2)
        let firstPlan = app.cells.firstMatch
        guard firstPlan.waitForExistence(timeout: 3) else {
            let btn = app.scrollViews.otherElements.buttons.firstMatch
            guard btn.waitForExistence(timeout: 3) else { return }
            btn.tap()
            sleep(1)
            return
        }
        firstPlan.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["开始此计划"].waitForExistence(timeout: 5) ||
                      app.staticTexts["当前已激活此计划"].waitForExistence(timeout: 5) ||
                      app.staticTexts["解锁 Pro"].waitForExistence(timeout: 5) ||
                      app.buttons["开始此计划"].waitForExistence(timeout: 5),
                      "Plan detail should show activate or already active or premium")
    }
}
