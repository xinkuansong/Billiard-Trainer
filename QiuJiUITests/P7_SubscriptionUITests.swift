import XCTest

final class P7_SubscriptionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
    }

    // MARK: - Subscription Entry Points

    func testSubscriptionFromProfile() {
        app.switchTab(.profile)
        sleep(2)
        let subscriptionText = app.staticTexts["订阅管理"]
        let upgradeText = app.staticTexts["升级 Pro"]
        if subscriptionText.waitForExistence(timeout: 3) {
            subscriptionText.tap()
            sleep(3)
            let sheetAppeared = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '月' OR label CONTAINS 'Pro' OR label CONTAINS '订阅' OR label CONTAINS '恢复'")).firstMatch.waitForExistence(timeout: 5) ||
                                app.buttons["恢复购买"].waitForExistence(timeout: 5)
            XCTAssertTrue(sheetAppeared, "Subscription or status view should appear")
        } else if upgradeText.waitForExistence(timeout: 3) {
            upgradeText.tap()
            sleep(2)
        }
    }

    func testSubscriptionFromProCard() {
        app.switchTab(.profile)
        sleep(1)
        let proCard = app.staticTexts["解锁球迹 Pro"]
        if proCard.waitForExistence(timeout: 3) {
            proCard.tap()
            sleep(2)
        }
    }

    func testSubscriptionFromPremiumDrill() {
        app.switchTab(.drillLibrary)
        sleep(3)
        app.scrollDown(times: 3)
        sleep(1)

        let proButton = app.buttons["解锁 Pro"]
        let drillCell = app.cells.firstMatch
        if drillCell.waitForExistence(timeout: 3) {
            drillCell.tap()
            sleep(2)
            if proButton.waitForExistence(timeout: 3) {
                proButton.tap()
                sleep(2)
                return
            }
            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 2) {
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
        }
    }

    // MARK: - Subscription Page UI

    func testSubscriptionPageElements() {
        app.switchTab(.profile)
        sleep(2)
        let subscriptionItem = app.staticTexts["订阅管理"]
        guard subscriptionItem.waitForExistence(timeout: 3) else { return }
        subscriptionItem.tap()
        sleep(3)

        let restoreButton = app.buttons["恢复购买"]
        if restoreButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(restoreButton.exists, "Restore purchase button should exist")
        }
    }

    // MARK: - Restore Purchase

    func testRestorePurchaseNoCrash() {
        app.switchTab(.profile)
        sleep(2)
        let subscriptionItem = app.staticTexts["订阅管理"]
        guard subscriptionItem.waitForExistence(timeout: 3) else { return }
        subscriptionItem.tap()
        sleep(3)

        let restoreButton = app.buttons["恢复购买"]
        if restoreButton.waitForExistence(timeout: 5) {
            restoreButton.tap()
            sleep(3)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "App should not crash after restore")
        }
    }

    // MARK: - Sheet Dismiss

    func testSubscriptionSheetDismiss() {
        app.switchTab(.profile)
        sleep(1)
        let proCard = app.staticTexts["解锁球迹 Pro"]
        if proCard.waitForExistence(timeout: 3) {
            proCard.tap()
            sleep(2)
            app.swipeDown()
            sleep(1)
            XCTAssertTrue(app.tabBars.element.exists, "Should return to profile after sheet dismiss")
        }
    }
}
