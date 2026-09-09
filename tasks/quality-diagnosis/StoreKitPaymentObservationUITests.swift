import XCTest
import StoreKit
import StoreKitTest

/// Observation only: completing this method never establishes payment cancellation.
/// Registers no interruption handler and clicks no system payment controls.
final class StoreKitPaymentObservationUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        defer {
            app?.terminate()
            session?.clearTransactions()
            session?.resetToDefaultState()
        }
        if app != nil { try capture("terminal-observation-no-cancellation-verdict") }
    }

    @MainActor
    func testObserveLocalMonthlyPaymentDialogWithoutConfirmingOrCancelling() async throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_STOREKIT_PAYMENT_OBSERVATION_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_PAYMENT_OBSERVATION_AUTH"],
                       "DEDICATED_LOCAL_STOREKIT_SIMULATOR")
        _ = try outputDirectory()
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState()
        local.clearTransactions()
        local.disableDialogs = false
        local.askToBuyEnabled = false
        XCTAssertFalse(local.disableDialogs)
        XCTAssertFalse(local.askToBuyEnabled)
        XCTAssertEqual(local.allTransactions().count, 0)
        let catalogError = await local.simulatedError(forAPI: .loadProducts)
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        XCTAssertNil(catalogError)
        XCTAssertNil(purchaseError)

        let application = XCUIApplication.launchClean(extraArgs: [
            "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-v51.followSystemAppearance"
        ])
        app = application
        XCTAssertEqual(application.state, .runningForeground)
        application.switchTab(.profile)
        let account = application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 12))
        XCTAssertTrue(account.label.contains("服务端球友"))
        XCTAssertFalse(application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch.exists)
        try capture("profile-free")

        let entry = application.staticTexts["订阅管理"].firstMatch
        let tabBar = application.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        XCTAssertFalse(tabBar.frame.isEmpty)
        reveal(entry, in: application, below: tabBar.frame.minY)
        ready(entry); entry.tap()
        let scroll = application.scrollViews["subscription.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let monthly = application.buttons["subscription.product.com.xinkuan.qiuji.premium.monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 15))
        let purchase = application.buttons["subscription.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 8))
        reveal(monthly, in: scroll, below: purchase.frame.minY)
        ready(monthly); monthly.tap()
        waitSelected(monthly)
        ready(purchase)
        XCTAssertTrue(purchase.label.contains("每月"))
        XCTAssertEqual(local.allTransactions().count, 0)
        XCTAssertFalse(local.disableDialogs)
        try capture("before-purchase-monthly-selected")

        // Exactly one purchase tap. Unknown payment-sheet identity is deliberately
        // recorded for review rather than guessed or asserted as any generic alert.
        purchase.tap()
        let observationStart = Date()
        try capture("after-purchase-immediate")
        for seconds in [2.0, 5.0, 10.0] {
            let remaining = seconds - Date().timeIntervalSince(observationStart)
            if remaining > 0 {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            try capture("after-purchase-target-\(Int(seconds))s")
        }
        // No postcondition here asserts cancellation, sheet identity, or free entitlement:
        // an unexpected automatic local purchase must remain visible in the evidence.
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
        let stem = "storekit-payment-observation-" + runID + "-" + stage
        // Persist the whole screen BEFORE AX queries, which can stall on system sheets.
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let image = XCTAttachment(screenshot: shot)
        image.name = stem; image.lifetime = .keepAlways; add(image)
        let transactions = session?.allTransactions() ?? []
        let summary = "OBSERVATION ONLY; cancellation not evaluated.\nTime: \(Date())\ntransactionCount=\(transactions.count)\n" + transactions.map {
            "id=\($0.identifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)"
        }.joined(separator: "\n")
        try write(summary, stem: stem + "-transactions", directory: directory)
        try write("appState=\(application.state.rawValue)\n" + application.debugDescription,
                  stem: stem + "-app-AX", directory: directory)
        // Read only: never launch, activate, or tap SpringBoard. It may not own the sheet.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        try write("springboardState=\(springboard.state.rawValue)\n" + springboard.debugDescription,
                  stem: stem + "-springboard-AX", directory: directory)
    }

    private func write(_ text: String, stem: String, directory: URL) throws {
        try Data(text.utf8).write(to: directory.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
        let attachment = XCTAttachment(string: text)
        attachment.name = stem; attachment.lifetime = .keepAlways; add(attachment)
    }
}
