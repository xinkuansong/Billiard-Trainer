import XCTest
import StoreKit
import StoreKitTest

/// Local Ask to Buy only; no entitlement override, purchase seeding, or app restart.
final class StoreKitPendingDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private var approvedPendingID: String?
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate(); session?.clearTransactions(); session?.resetToDefaultState() }
        if app != nil { try capture("terminal") }
    }

    @MainActor
    func testAskToBuyStaysFreeUntilApprovalThenUnlocksAtlasWithoutRestart() async throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_STOREKIT_PENDING_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_PENDING_AUTH"],
                       "DEDICATED_LOCAL_STOREKIT_SIMULATOR")
        _ = try outputDirectory()
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState(); local.clearTransactions()
        local.disableDialogs = true
        local.askToBuyEnabled = true
        XCTAssertTrue(local.disableDialogs)
        XCTAssertTrue(local.askToBuyEnabled)
        XCTAssertEqual(local.allTransactions().count, 0)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        XCTAssertNil(loadError); XCTAssertNil(purchaseError)
        let application = XCUIApplication.launchClean(extraArgs: [
            "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"
        ])
        app = application
        XCTAssertEqual(application.state, .runningForeground)
        application.switchTab(.profile)
        let account = application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 12))
        XCTAssertTrue(account.label.contains("服务端球友"))
        let membership = application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
        XCTAssertFalse(membership.exists)
        try capture("initial-authenticated-free")
        let tabs = application.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 8)); XCTAssertFalse(tabs.frame.isEmpty)
        let entry = application.staticTexts["订阅管理"].firstMatch
        reveal(entry, in: application, below: tabs.frame.minY)
        ready(entry); entry.tap()
        let scroll = application.scrollViews["subscription.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let monthly = application.buttons["subscription.product.com.xinkuan.qiuji.premium.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 15))
        let purchase = application.buttons["subscription.purchase"]
        XCTAssertTrue(purchase.exists)
        reveal(monthly, in: scroll, below: purchase.frame.minY)
        ready(monthly); monthly.tap(); waitSelected(monthly)
        ready(purchase)
        XCTAssertTrue(purchase.label.contains("每月"))
        try capture("monthly-before-ask-to-buy")
        purchase.tap()
        let pendingAlert = application.alerts["购买失败"]
        XCTAssertTrue(pendingAlert.waitForExistence(timeout: 15))
        // This is the current implementation's title, recorded rather than endorsed UX.
        XCTAssertTrue(pendingAlert.staticTexts["购买正在处理中，请稍候"].exists)
        let pending = try await waitForPending(local)
        XCTAssertEqual(pending.productIdentifier, "com.xinkuan.qiuji.premium.monthly")
        XCTAssertEqual(local.allTransactions().count, 1)
        XCTAssertEqual(local.allTransactions().filter { $0.state == .purchased }.count, 0)
        try capture("pending-message-and-local-transaction")
        let dismissMessage = pendingAlert.buttons["确定"]
        ready(dismissMessage); dismissMessage.tap()
        XCTAssertTrue(pendingAlert.waitForNonExistence(timeout: 8))
        waitSelected(monthly); ready(purchase)
        let close = application.buttons["subscription.close"]
        ready(close); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 8))
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        XCTAssertFalse(membership.exists)
        try capture("pending-profile-still-free")

        // Pro gate must actually reject the same normal route while pending.
        try openAtlasCard()
        ready(close)
        XCTAssertFalse(application.buttons["separationAngleAtlas.spinLegend.0"].exists)
        try capture("pending-atlas-remains-paywalled")
        close.tap(); XCTAssertTrue(close.waitForNonExistence(timeout: 8))
        application.switchTab(.profile)
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        XCTAssertFalse(membership.exists)
        let stillPending = try await waitForPending(local)
        XCTAssertEqual(stillPending.identifier, pending.identifier)
        approvedPendingID = String(pending.identifier)
        try capture("before-approving-same-pending-transaction")
        try local.approveAskToBuyTransaction(identifier: pending.identifier)

        // Stay on the current profile. No activate/relaunch/restore call to mask updates.
        XCTAssertTrue(membership.waitForExistence(timeout: 15), "Transaction.updates must refresh the live profile")
        XCTAssertTrue(membership.label.contains("Pro 会员"))
        XCTAssertTrue(account.label.contains("服务端球友"))
        let approved = try await waitForApproved(local)
        XCTAssertEqual(approved.productIdentifier, pending.productIdentifier)
        try capture("approved-live-profile-pro")
        try openAtlasCard()
        let track = application.buttons["separationAngleAtlas.spinLegend.0"]
        XCTAssertTrue(track.waitForExistence(timeout: 45))
        ready(track)
        XCTAssertFalse(close.exists)
        XCTAssertEqual(track.value as? String, "已选")
        try capture("approved-real-atlas-open")
        track.tap()
        XCTAssertEqual(track.value as? String, "未选")
        XCTAssertFalse(track.isSelected)
        try capture("approved-atlas-track-hidden")
        track.tap()
        XCTAssertEqual(track.value as? String, "已选")
        XCTAssertTrue(track.isSelected)
        try capture("approved-atlas-track-restored")
        let back = application.navigationBars.buttons.firstMatch
        ready(back); back.tap()
        application.switchTab(.profile)
        XCTAssertTrue(membership.waitForExistence(timeout: 8))
        XCTAssertTrue(membership.label.contains("Pro 会员"))
        _ = try await waitForApproved(local)
        try capture("final-live-profile-pro")
    }

    private func openAtlasCard() throws {
        let application = try XCTUnwrap(app)
        application.switchTab(.angle)
        let category = application.buttons["angleHomeTab_学"]
        ready(category); category.tap()
        let tabs = application.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 8)); XCTAssertFalse(tabs.frame.isEmpty)
        let card = application.buttons["分离角图谱"].firstMatch
        reveal(card, in: application, below: tabs.frame.minY)
        ready(card); card.tap()
    }

    private func waitForPending(_ local: SKTestSession) async throws -> SKTestTransaction {
        for attempt in 0..<20 {
            let transactions = local.allTransactions()
            let pending = transactions.filter { $0.pendingAskToBuyConfirmation }
            if transactions.count == 1 && pending.count == 1 { return pending[0] }
            if attempt < 19 { try await Task.sleep(nanoseconds: 500_000_000) }
        }
        try capture("pending-transaction-oracle-failed")
        XCTFail("Expected exactly one actual local Ask to Buy pending transaction")
        throw NSError(domain: "StoreKitPendingDiagnostic", code: 1)
    }

    private func waitForApproved(_ local: SKTestSession) async throws -> SKTestTransaction {
        for attempt in 0..<20 {
            let transactions = local.allTransactions()
            if transactions.count == 1, let transaction = transactions.first,
               !transaction.pendingAskToBuyConfirmation && transaction.state == .purchased { return transaction }
            if attempt < 19 { try await Task.sleep(nanoseconds: 500_000_000) }
        }
        try capture("approved-transaction-oracle-failed")
        XCTFail("Expected exactly one purchased local transaction and no pending transaction")
        throw NSError(domain: "StoreKitPendingDiagnostic", code: 2)
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
        let stem = "storekit-pending-" + runID + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let transactions = session?.allTransactions() ?? []
        let summary = "time=\(Date()) approvedPendingID=\(String(describing: approvedPendingID)) transactionCount=\(transactions.count)\n" + transactions.map {
            "id=\($0.identifier) original=\($0.originalTransactionIdentifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)"
        }.joined(separator: "\n")
        try Data(summary.utf8).write(to: directory.appendingPathComponent(stem + "-transactions.txt"), options: .withoutOverwriting)
        let tree = application.debugDescription
        try Data(tree.utf8).write(to: directory.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let details = XCTAttachment(string: summary + "\n\n" + tree)
        details.name = stem + "-AX-transactions"; details.lifetime = .keepAlways; add(details)
    }
}
