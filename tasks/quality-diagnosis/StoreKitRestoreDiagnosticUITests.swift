import XCTest
import StoreKit
import StoreKitTest

/// Independent restore diagnosis. No purchase error injection or failed-run history reuse.
final class StoreKitRestoreDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private let runID = UUID().uuidString
    private let monthlyID = "com.xinkuan.qiuji.premium.monthly"
    private struct Stop: Error { let reason: String }

    override func tearDownWithError() throws {
        defer { app?.terminate(); session?.clearTransactions(); session?.resetToDefaultState() }
        if app != nil { try capture("terminal-before-cleanup") }
    }

    @MainActor
    func testNormalLocalPurchaseThenRestartRestoreErrorClearRetryKeepsSamePurchase() async throws {
        let env = ProcessInfo.processInfo.environment
        try require((env["QD_STOREKIT_RESTORE_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_RESTORE_AUTH"]) == "DEDICATED_LOCAL_STOREKIT_SIMULATOR", "Dedicated local simulator guard required")
        _ = try outputDirectory()
        guard let catalog = Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit") else {
            throw Stop(reason: "Local Products resource missing; cannot proceed")
        }
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState(); local.clearTransactions()
        local.disableDialogs = true; local.askToBuyEnabled = false; local.timeRate = .realTime
        try require(local.disableDialogs && !local.askToBuyEnabled && local.timeRate == .realTime, "Session property mismatch")
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let syncError = await local.simulatedError(forAPI: .appStoreSync)
        try require(purchaseError == nil && loadError == nil && syncError == nil, "Initial simulated errors must all be nil")
        try require(local.allTransactions().isEmpty, "Start with empty local transaction history")
        app = launchFixture()
        let application = try XCTUnwrap(app)
        application.switchTab(.profile)
        try assertProfile(premium: false)
        try openSubscription()
        let scroll = application.scrollViews["subscription.scroll"]
        try require(scroll.waitForExistence(timeout: 8), "Normal subscription sheet missing")
        let monthly = application.buttons["subscription.product." + monthlyID]
        try require(monthly.waitForExistence(timeout: 15), "Monthly catalog missing")
        let purchase = application.buttons["subscription.purchase"]
        try require(purchase.exists, "Purchase CTA missing")
        try reveal(monthly, in: scroll, bottom: purchase.frame.minY)
        try ready(monthly); monthly.tap()
        try waitState("Monthly selection missing") { monthly.exists && monthly.isSelected }
        try ready(purchase)
        try require(purchase.label.contains("每月"), "CTA is not monthly")
        try capture("before-normal-monthly-purchase")
        purchase.tap() // One uninjected purchase only. No purchase retry in this scenario.
        let membership = application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        let purchasedInUI = membership.waitForExistence(timeout: 15)
        if !purchasedInUI {
            try capture("normal-purchase-precondition-failed")
            try require(false, "Uninjected purchase did not create Pro; stop before restart or restore")
        }
        let close = application.buttons["subscription.close"]
        try require(close.waitForNonExistence(timeout: 10), "Successful purchase must dismiss the sheet")
        try assertProfile(premium: true)
        let purchased = local.allTransactions().filter { $0.state == .purchased }
        try require(purchased.count == 1 && purchased.first?.productIdentifier == monthlyID, "Need exactly one actual purchased monthly transaction")
        let originalIDs = successIDs(local)
        try capture("verified-normal-purchase-pro-one-transaction")

        application.terminate()
        try require(application.wait(for: .notRunning, timeout: 8), "Old App process did not terminate")
        // Same local SK session; no reset, clear, replacement history, or preview route.
        app = launchFixture()
        let restarted = try XCTUnwrap(app)
        restarted.switchTab(.profile)
        try assertProfile(premium: true)
        try require(successIDs(local) == originalIDs, "Restart changed successful transaction identity")
        try capture("verified-normal-restart-existing-pro")
        try openSubscription()
        try assertMonthlyStatus()
        let restore = restarted.buttons["恢复购买"].firstMatch
        try ready(restore)
        try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        let installed = await local.simulatedError(forAPI: .appStoreSync)
        try require(installed != nil, "Restore error injection missing")
        try capture("sync-error-installed-before-restore")
        restore.tap()
        let alert = restarted.alerts["恢复购买"]
        try require(alert.waitForExistence(timeout: 15), "Restore error alert missing")
        try require(alert.staticTexts["恢复购买失败，请稍后重试"].exists, "Actual restore failure text missing")
        try require(successIDs(local) == originalIDs, "Failed restore changed successful purchases")
        try capture("observed-restore-network-failure")
        try dismiss(alert)
        try assertMonthlyStatus()
        try backFromStatus()
        try assertProfile(premium: true)
        try capture("verified-pro-retained-after-restore-failure")

        try await local.setSimulatedError(nil, forAPI: .appStoreSync)
        let cleared = await local.simulatedError(forAPI: .appStoreSync)
        try require(cleared == nil, "Restore error did not clear")
        try capture("sync-error-cleared-before-retry")
        try openSubscription()
        try assertMonthlyStatus()
        try ready(restore); restore.tap()
        try require(alert.waitForExistence(timeout: 15), "Restore retry alert missing")
        try require(alert.staticTexts["已恢复购买，Pro 功能已解锁"].exists, "Restore retry did not report success")
        try require(successIDs(local) == originalIDs, "Restore retry created or changed purchased transactions")
        try capture("verified-restore-retry-success")
        try dismiss(alert)
        try assertMonthlyStatus(); try backFromStatus(); try assertProfile(premium: true)
        try require(successIDs(local) == originalIDs, "Final purchase set changed")
        try capture("verified-final-pro-same-purchase")
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else { XCTFail(message); throw Stop(reason: message) }
    }
    private func waitState(_ message: String, timeout: TimeInterval = 15, condition: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, message)
    }
    private func ready(_ element: XCUIElement) throws {
        try waitState("Action not ready") { element.exists && element.isHittable && element.isEnabled }
    }
    private func launchFixture() -> XCUIApplication {
        XCUIApplication.launchClean(extraArgs: ["-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"])
    }
    private func assertProfile(premium: Bool) throws {
        let application = try XCTUnwrap(app)
        try require(application.state == .runningForeground, "App not foreground")
        let account = application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch
        try require(account.waitForExistence(timeout: 10) && account.label.contains("服务端球友"), "Fixture identity missing or changed")
        let member = application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        if premium {
            try require(member.waitForExistence(timeout: 15) && member.label.contains("Pro 会员"), "Actual profile premium state missing")
        } else { try require(!member.exists, "Initial profile must be free") }
    }
    private func openSubscription() throws {
        let application = try XCTUnwrap(app)
        let tabs = application.tabBars.firstMatch
        try require(tabs.waitForExistence(timeout: 8) && !tabs.frame.isEmpty, "Actual tab bar boundary missing")
        let entry = application.staticTexts["订阅管理"].firstMatch
        try reveal(entry, in: application, bottom: tabs.frame.minY)
        try ready(entry); entry.tap()
    }
    private func assertMonthlyStatus() throws {
        let application = try XCTUnwrap(app)
        try require(application.navigationBars["订阅管理"].waitForExistence(timeout: 8), "Normal Pro subscription status route missing")
        try require(application.staticTexts["月度订阅"].exists, "Dynamic monthly entitlement status missing")
        try require(!application.buttons["subscription.purchase"].exists, "Unexpected free paywall")
    }
    private func backFromStatus() throws {
        let back = app!.navigationBars["订阅管理"].buttons.firstMatch
        try ready(back); back.tap()
    }
    private func dismiss(_ alert: XCUIElement) throws {
        let confirm = alert.buttons["确定"]
        try ready(confirm); confirm.tap()
        try require(alert.waitForNonExistence(timeout: 8), "Alert did not dismiss")
    }
    private func successIDs(_ local: SKTestSession) -> Set<String> {
        Set(local.allTransactions().filter { $0.state == .purchased }.map { String($0.identifier) })
    }
    private func reveal(_ element: XCUIElement, in container: XCUIElement, bottom: CGFloat) throws {
        let window = app!.windows.firstMatch
        try require(window.exists && !window.frame.isEmpty && container.exists && !container.frame.isEmpty, "Viewport missing")
        let top = max(window.frame.minY, container.frame.minY)
        let lower = min(bottom, min(window.frame.maxY, container.frame.maxY))
        try require(lower > top, "Invalid visible bounds")
        for _ in 0..<8 {
            if element.exists && !element.frame.isEmpty {
                let frame = element.frame
                if window.frame.contains(frame) && frame.minY >= top && frame.maxY < lower && element.isHittable { return }
                if frame.minY < top { container.swipeDown() } else { container.swipeUp() }
            } else { container.swipeUp() }
        }
        try require(false, "Cannot reveal complete action inside actual bounds")
    }
    private func outputDirectory() throws -> URL {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"], !path.isEmpty else { throw Stop(reason: "Output directory missing") }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func capture(_ stage: String) throws {
        let application = try XCTUnwrap(app)
        let directory = try outputDirectory()
        let stem = "storekit-restore-" + runID + "-" + stage
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
