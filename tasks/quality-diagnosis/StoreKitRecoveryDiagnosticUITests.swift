import XCTest
import StoreKit
import StoreKitTest

/// Local purchase and restore failures through normal UI; same SK session across restart.
final class StoreKitRecoveryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private let runID = UUID().uuidString
    private let monthlyID = "com.xinkuan.qiuji.premium.monthly"

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate(); session?.clearTransactions(); session?.resetToDefaultState() }
        if app != nil { try capture("terminal") }
    }

    @MainActor
    func testLocalPurchaseFailureRetryThenRestartRestoreFailureRetryKeepsOnePurchase() async throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_STOREKIT_RECOVERY_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_RECOVERY_AUTH"],
                       "DEDICATED_LOCAL_STOREKIT_SIMULATOR")
        _ = try outputDirectory()
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState(); local.clearTransactions()
        local.disableDialogs = true; local.askToBuyEnabled = false; local.timeRate = .realTime
        XCTAssertTrue(local.disableDialogs); XCTAssertFalse(local.askToBuyEnabled)
        XCTAssertEqual(local.timeRate, .realTime)
        XCTAssertEqual(local.allTransactions().count, 0)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let syncError = await local.simulatedError(forAPI: .appStoreSync)
        XCTAssertNil(loadError); XCTAssertNil(syncError)
        try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        XCTAssertNotNil(purchaseError)
        app = launchFixture()
        let application = try XCTUnwrap(app)
        application.switchTab(.profile)
        assertProfile(premium: false)
        try openProfileSubscription()
        try selectMonthly()
        let purchase = application.buttons["subscription.purchase"]
        ready(purchase); purchase.tap()
        let error = application.alerts["购买失败"]
        XCTAssertTrue(error.waitForExistence(timeout: 15))
        // The injected URLError's localized text varies by OS. Require actual message text.
        let messageLabels = error.staticTexts.allElementsBoundByIndex.map(\.label)
            .filter { !$0.isEmpty && $0 != "购买失败" }
        XCTAssertFalse(messageLabels.isEmpty)
        XCTAssertFalse(messageLabels.contains("购买正在处理中，请稍候"))
        XCTAssertEqual(successIDs(local).count, 0)
        try capture("purchase-network-error")
        let confirm = error.buttons["确定"]
        ready(confirm); confirm.tap()
        XCTAssertTrue(error.waitForNonExistence(timeout: 8))
        waitSelected(application.buttons["subscription.product." + monthlyID])
        ready(purchase)
        let close = application.buttons["subscription.close"]
        ready(close); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 8))
        assertProfile(premium: false)
        XCTAssertEqual(successIDs(local).count, 0)
        try capture("failed-purchase-still-free")

        try await local.setSimulatedError(nil, forAPI: .purchase)
        let clearedPurchaseError = await local.simulatedError(forAPI: .purchase)
        XCTAssertNil(clearedPurchaseError)
        try openProfileSubscription()
        try selectMonthly()
        ready(purchase); purchase.tap() // Exactly one retry; never a third purchase tap.
        let membership = application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        XCTAssertTrue(membership.waitForExistence(timeout: 15))
        XCTAssertTrue(close.waitForNonExistence(timeout: 12), "Normal successful purchase must dismiss its subscription sheet")
        assertProfile(premium: true)
        let originalSuccessIDs = successIDs(local)
        XCTAssertEqual(originalSuccessIDs.count, 1)
        let successes = local.allTransactions().filter { $0.state == .purchased }
        XCTAssertEqual(successes.count, 1)
        XCTAssertEqual(successes.first?.productIdentifier, monthlyID)
        try capture("purchase-retry-success-one-purchased")

        application.terminate()
        XCTAssertTrue(application.wait(for: .notRunning, timeout: 8), "Confirm the old process ended before the restart observation")
        // Preserve the SAME local session and transaction history across normal app launch.
        app = launchFixture()
        let restarted = try XCTUnwrap(app)
        restarted.switchTab(.profile)
        let restartedMembership = restarted.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        XCTAssertTrue(restartedMembership.waitForExistence(timeout: 15))
        assertProfile(premium: true)
        XCTAssertEqual(successIDs(local), originalSuccessIDs)
        try capture("normal-restart-restored-existing-entitlement")
        try openProfileSubscription()
        assertMonthlyStatus()
        // Premium normal entry is SubscriptionStatusView, not SubscriptionView.
        let restore = restarted.buttons["恢复购买"].firstMatch
        ready(restore)
        try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        let installedSyncError = await local.simulatedError(forAPI: .appStoreSync)
        XCTAssertNotNil(installedSyncError)
        restore.tap()
        let restoreAlert = restarted.alerts["恢复购买"]
        XCTAssertTrue(restoreAlert.waitForExistence(timeout: 15))
        XCTAssertTrue(restoreAlert.staticTexts["恢复购买失败，请稍后重试"].exists)
        XCTAssertEqual(successIDs(local), originalSuccessIDs)
        try capture("restore-network-error-existing-purchase")
        ready(restoreAlert.buttons["确定"]); restoreAlert.buttons["确定"].tap()
        XCTAssertTrue(restoreAlert.waitForNonExistence(timeout: 8))
        assertMonthlyStatus()
        try capture("failed-restore-monthly-status-retained")
        backFromStatus()
        assertProfile(premium: true)
        try capture("failed-restore-profile-pro-retained")

        try await local.setSimulatedError(nil, forAPI: .appStoreSync)
        let clearedSyncError = await local.simulatedError(forAPI: .appStoreSync)
        XCTAssertNil(clearedSyncError)
        try openProfileSubscription()
        assertMonthlyStatus()
        ready(restore); restore.tap()
        XCTAssertTrue(restoreAlert.waitForExistence(timeout: 15))
        XCTAssertTrue(restoreAlert.staticTexts["已恢复购买，Pro 功能已解锁"].exists)
        XCTAssertEqual(successIDs(local), originalSuccessIDs)
        try capture("restore-retry-success-no-new-purchase")
        ready(restoreAlert.buttons["确定"]); restoreAlert.buttons["确定"].tap()
        XCTAssertTrue(restoreAlert.waitForNonExistence(timeout: 8))
        assertMonthlyStatus(); backFromStatus(); assertProfile(premium: true)
        XCTAssertEqual(successIDs(local), originalSuccessIDs)
        try capture("final-profile-pro-same-purchase")
    }

    private func launchFixture() -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
    }
    private func assertProfile(premium: Bool) {
        let application = app!
        XCTAssertEqual(application.state, .runningForeground)
        let account = application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        XCTAssertTrue(account.label.contains("服务端球友"))
        let membership = application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        if premium {
            XCTAssertTrue(membership.waitForExistence(timeout: 8))
            XCTAssertTrue(membership.label.contains("Pro 会员"))
        } else { XCTAssertFalse(membership.exists) }
    }
    private func openProfileSubscription() throws {
        let application = try XCTUnwrap(app)
        let tabs = application.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 8)); XCTAssertFalse(tabs.frame.isEmpty)
        let entry = application.staticTexts["订阅管理"].firstMatch
        reveal(entry, in: application, below: tabs.frame.minY)
        ready(entry); entry.tap()
    }
    private func selectMonthly() throws {
        let application = try XCTUnwrap(app)
        let scroll = application.scrollViews["subscription.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let monthly = application.buttons["subscription.product." + monthlyID]
        XCTAssertTrue(monthly.waitForExistence(timeout: 15))
        let purchase = application.buttons["subscription.purchase"]
        XCTAssertTrue(purchase.exists)
        reveal(monthly, in: scroll, below: purchase.frame.minY)
        ready(monthly); monthly.tap(); waitSelected(monthly)
        ready(purchase); XCTAssertTrue(purchase.label.contains("每月"))
    }
    private func assertMonthlyStatus() {
        let application = app!
        XCTAssertTrue(application.navigationBars["订阅管理"].waitForExistence(timeout: 8))
        // Unlike the unconditional Pro title, this text derives from purchasedProductIDs.
        XCTAssertTrue(application.staticTexts["月度订阅"].exists)
        XCTAssertFalse(application.buttons["subscription.purchase"].exists)
    }
    private func backFromStatus() {
        let back = app!.navigationBars["订阅管理"].buttons.firstMatch
        ready(back); back.tap()
    }
    private func successIDs(_ local: SKTestSession) -> Set<String> {
        Set(local.allTransactions().filter { $0.state == .purchased }.map { String($0.identifier) })
    }

    private func ready(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)], timeout: 12), .completed)
    }

    private func waitSelected(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND selected == true"), object: element)], timeout: 8), .completed)
    }

    private func reveal(_ element: XCUIElement, in container: XCUIElement, below bottom: CGFloat) {
        let application = app!
        let window = application.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 8))
        XCTAssertFalse(window.frame.isEmpty)
        XCTAssertTrue(container.exists)
        XCTAssertFalse(container.frame.isEmpty)
        let visibleTop = max(window.frame.minY, container.frame.minY)
        let visibleBottom = min(bottom, min(window.frame.maxY, container.frame.maxY))
        XCTAssertGreaterThan(visibleBottom, visibleTop)
        for _ in 0..<8 {
            if element.exists {
                let frame = element.frame
                if !frame.isEmpty && window.frame.contains(frame)
                    && frame.minY >= visibleTop && frame.maxY < visibleBottom && element.isHittable { return }
                // When the card has scrolled above the viewport, reveal it downward.
                // Do not push it farther away with another upward swipe.
                if !frame.isEmpty && frame.minY < visibleTop {
                    container.swipeDown()
                } else {
                    container.swipeUp()
                }
            } else {
                container.swipeUp()
            }
        }
        XCTAssertTrue(element.exists && element.isHittable)
        XCTAssertFalse(element.frame.isEmpty)
        XCTAssertTrue(window.frame.contains(element.frame))
        XCTAssertGreaterThanOrEqual(element.frame.minY, visibleTop)
        XCTAssertLessThan(element.frame.maxY, visibleBottom)
    }

    private func outputDirectory() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        XCTAssertFalse(path.isEmpty)
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func capture(_ stage: String) throws {
        let application = try XCTUnwrap(app)
        let directory = try outputDirectory()
        let stem = "storekit-recovery-" + runID + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let transactions = session?.allTransactions() ?? []
        let summary = "time=\(Date()) transactionCount=\(transactions.count) purchasedCount=\(transactions.filter { $0.state == .purchased }.count)\n" + transactions.map {
            "id=\($0.identifier) original=\($0.originalTransactionIdentifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)"
        }.joined(separator: "\n")
        try Data(summary.utf8).write(to: directory.appendingPathComponent(stem + "-transactions.txt"), options: .withoutOverwriting)
        let tree = application.debugDescription
        try Data(tree.utf8).write(to: directory.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let detail = XCTAttachment(string: summary + "\n\n" + tree)
        detail.name = stem + "-AX-transactions"; detail.lifetime = .keepAlways; add(detail)
    }
}
