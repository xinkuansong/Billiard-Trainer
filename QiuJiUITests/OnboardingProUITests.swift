import XCTest
import StoreKitTest

final class OnboardingProUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testTourAndProPresentation() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        for appearance in ["-v54.forceLight", "-v54.forceDark"] {
            let app = XCUIApplication.launchClean(extraArgs: ["-intro.preview", appearance, "-v50.inMemoryStore"])
            for index in 0..<4 {
                XCTAssertTrue(app.staticTexts["onboarding.title.\(index)"].waitForExistence(timeout: 6))
                XCTAssertTrue(app.images["onboarding.image.\(index)"].exists)
                XCTAssertTrue(app.buttons["onboarding.continue"].isHittable)
                if index == 2 { XCTAssertTrue(app.staticTexts["自由走位 · Pro 功能示例"].isHittable) }
                capture("\(appearance)-intro-\(index)")
                if index < 3 { app.buttons["onboarding.continue"].tap() }
            }
            app.buttons["onboarding.page.0"].tap()
            XCTAssertTrue(app.staticTexts["onboarding.title.0"].waitForExistence(timeout: 5))
            app.terminate()

            let pro = XCUIApplication.launchClean(extraArgs: ["-subscription.preview", appearance, "-v50.inMemoryStore"])
            let yearly = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.yearly"]
            XCTAssertTrue(yearly.waitForExistence(timeout: 12))
            capture("\(appearance)-pro-top")
            reveal(yearly, in: pro)
            XCTAssertTrue(yearly.isSelected)
            let monthly = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.monthly"]
            monthly.tap()
            XCTAssertTrue(monthly.isSelected)
            XCTAssertFalse(yearly.isSelected)
            let lifetime = pro.buttons["subscription.product.com.xinkuan.qiuji.premium.lifetime"]
            lifetime.tap()
            XCTAssertTrue(lifetime.isSelected)
            XCTAssertTrue(pro.buttons["subscription.purchase"].label.contains("一次性"))
            capture("\(appearance)-pro-plans")
            // The guest's chosen product survives entering and cancelling login.
            pro.buttons["subscription.purchase"].tap()
            let cancelLogin = pro.buttons["暂不登录，匿名使用"]
            XCTAssertTrue(cancelLogin.waitForExistence(timeout: 6))
            cancelLogin.tap()
            XCTAssertTrue(lifetime.waitForExistence(timeout: 6))
            XCTAssertTrue(lifetime.isSelected)
            pro.terminate()
        }
    }

    @MainActor
    func testOptionalTourReturnsToSameAccount() {
        let app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        let identity = app.descendants(matching: .any)["profile.accountHeader"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 6))
        let originalIdentity = identity.label
        let entry = app.buttons["profile.onboarding"]
        reveal(entry, in: app)
        capture("profile-intro-entry")
        entry.tap()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        for _ in 0..<4 { app.buttons["onboarding.continue"].tap() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        app.swipeDown()
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        XCTAssertEqual(identity.label, originalIdentity, "Tour must not log out or replace an existing account")
        app.terminate()
    }

    @MainActor
    func testStoreKitPurchaseAndRestore() throws {
        let session = try storeSession()
        defer { session.clearTransactions() }
        var app = XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
        app.switchTab(.profile)
        let subscription = app.staticTexts["订阅管理"]
        reveal(subscription, in: app)
        subscription.tap()
        let monthly = app.buttons["subscription.product.com.xinkuan.qiuji.premium.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 12))
        reveal(monthly, in: app)
        monthly.tap()
        XCTAssertTrue(monthly.isSelected)
        XCTAssertTrue(app.buttons["subscription.purchase"].label.contains("每月"))
        app.buttons["subscription.purchase"].tap()
        let membership = app.staticTexts["profile.membershipSummary"]
        XCTAssertTrue(membership.waitForExistence(timeout: 12), "Successful StoreKit purchase returns to profile")
        XCTAssertTrue(membership.label.contains("Pro 会员"))
        XCTAssertFalse(app.buttons["subscription.purchase"].exists)
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.xinkuan.qiuji.premium.monthly" }.count, 1)
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-subscription.preview", "-v53.authenticatedProfileFixture", "-v50.inMemoryStore"])
        let restore = app.buttons["subscription.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: restore)
        waitForExpectations(timeout: 12)
        restore.tap()
        XCTAssertTrue(app.alerts["恢复购买"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.alerts.staticTexts["已恢复购买，Pro 功能已解锁"].exists)
        capture("storekit-restored")
        app.alerts.buttons["确定"].tap()
        app.terminate()
    }

    @MainActor
    private func storeSession() throws -> SKTestSession {
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: catalog)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            let footer = app.buttons["subscription.purchase"]
            let visibleBottom = footer.exists ? footer.frame.minY : app.frame.maxY - 84
            if element.exists && element.isHittable && element.frame.maxY < visibleBottom { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
