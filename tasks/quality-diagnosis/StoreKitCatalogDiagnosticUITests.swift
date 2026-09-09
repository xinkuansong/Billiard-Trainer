import XCTest
import StoreKit
import StoreKitTest

/// Draft for snapshot004 registration by the orchestrator. Dedicated local simulator only.
/// Exercises the real SubscriptionManager catalog flow; never taps purchase or debug unlock.
final class StoreKitCatalogDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        // Capture before clearing local state, including on assertion failure.
        defer {
            app?.terminate()
            session?.clearTransactions()
            session?.resetToDefaultState()
        }
        if app != nil { try capture("terminal") }
    }

    @MainActor
    func testProductLoadFailureShowsRetryAndRecoversLocalCatalog() async throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_STOREKIT_CATALOG_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_CATALOG_AUTH"],
                       "DEDICATED_LOCAL_STOREKIT_SIMULATOR")
        _ = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let catalog = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState()
        local.disableDialogs = true
        local.clearTransactions()
        XCTAssertEqual(local.allTransactions().count, 0)
        try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let installed = await local.simulatedError(forAPI: .loadProducts)
        XCTAssertNotNil(installed, "The local catalog error must actually be installed before app launch")

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
        try capture("authenticated-free-profile")

        // Profile's free subscription row has no identifier; its real Text is tappable
        // inside the Button, as used by the existing OnboardingProUITests.
        let entry = application.staticTexts["订阅管理"].firstMatch
        reveal(entry, in: application)
        ready(entry); entry.tap()
        let close = application.buttons["subscription.close"]
        ready(close)
        let scroll = application.scrollViews["subscription.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        let retry = application.buttons["subscription.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15))
        reveal(retry, in: scroll)
        ready(retry)
        let errors = application.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "加载失败："))
        // Read-only error copy requires existence, not a touch target or a fixed OS translation.
        XCTAssertTrue(errors.firstMatch.waitForExistence(timeout: 5))
        let products = application.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subscription.product."))
        XCTAssertEqual(products.count, 0)
        let purchase = application.buttons["subscription.purchase"]
        XCTAssertTrue(purchase.exists)
        XCTAssertFalse(purchase.isEnabled)
        XCTAssertEqual(local.allTransactions().count, 0)
        try capture("injected-load-failure-retry-visible")

        try await local.setSimulatedError(nil, forAPI: .loadProducts)
        let cleared = await local.simulatedError(forAPI: .loadProducts)
        XCTAssertNil(cleared, "Retry only after the local injection is confirmed removed")
        retry.tap()
        let prefix = "subscription.product.com.xinkuan.qiuji.premium."
        let yearly = application.buttons[prefix + "yearly"]
        XCTAssertTrue(yearly.waitForExistence(timeout: 15))
        waitSelected(yearly)
        XCTAssertEqual(products.count, 3)
        XCTAssertEqual(Set(products.allElementsBoundByIndex.map(\.identifier)),
                       Set([prefix + "monthly", prefix + "yearly", prefix + "lifetime"]))
        XCTAssertFalse(retry.exists)
        XCTAssertEqual(errors.count, 0)
        XCTAssertTrue(purchase.isEnabled)
        reveal(yearly, in: scroll)
        try capture("catalog-restored-yearly-default")
        for suffix in ["monthly", "lifetime"] {
            let product = application.buttons[prefix + suffix]
            reveal(product, in: scroll)
            ready(product); product.tap()
            waitSelected(product)
            XCTAssertEqual(products.allElementsBoundByIndex.filter { $0.isSelected }.count, 1)
            XCTAssertTrue(purchase.isEnabled)
            XCTAssertEqual(local.allTransactions().count, 0)
            try capture("catalog-select-" + suffix)
        }
        ready(close); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 8))
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        XCTAssertTrue(account.label.contains("服务端球友"))
        XCTAssertFalse(membership.exists)
        XCTAssertEqual(local.allTransactions().count, 0)
        try capture("returned-profile-still-free-no-transactions")
    }

    private func ready(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)], timeout: 12), .completed)
    }

    private func waitSelected(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND selected == true"), object: element)], timeout: 8), .completed)
    }

    private func reveal(_ element: XCUIElement, in container: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            container.swipeUp()
        }
    }

    private func capture(_ stage: String) throws {
        let application = try XCTUnwrap(app)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = "storekit-catalog-" + runID + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        let tree = application.debugDescription
        let transactions = session?.allTransactions().map {
            "id=\($0.identifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)"
        }.joined(separator: "\n") ?? "no local session"
        let details = "Local StoreKit transactions:\n" + transactions + "\n\n" + tree
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let text = XCTAttachment(string: details); text.name = stem + "-AX-transactions"; text.lifetime = .keepAlways; add(text)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        try Data(details.utf8).write(to: directory.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
