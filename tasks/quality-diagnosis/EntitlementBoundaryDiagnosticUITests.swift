import XCTest
import StoreKit
import StoreKitTest

/// Unregistered snapshot004 diagnostic. Exactly one App launch and one local UI purchase.
/// Preflight: Products.storekit must be in the UITest runner bundle, as in Restore001.
/// QD_ENTITLEMENT_AUTH=DEDICATED_LOCAL_STOREKIT_SIMULATOR,
/// QD_ENTITLEMENT_DEVICE_UDID=the new dedicated runner SIMULATOR_UDID,
/// QD_SHOT_DIR=new absolute output leaf; direct or TEST_RUNNER_ keys supported.
/// Normal c039 and plan navigation AX has not yet been observed in this combined chain.
/// If those strong route assertions fail, inspect PNG/AX; do not substitute guessed coordinates.
/// Only local Xcode transactions; authenticatedProfileFixture prevents APIClient transport.
final class EntitlementBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private var output: URL?
    private let runID = UUID().uuidString
    private let monthlyID = "com.xinkuan.qiuji.premium.monthly"
    private var sequence = 0
    private var purchasedIDs = Set<String>()
    private var expiryRequested = false
    private struct Stop: Error { let reason: String }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        // Evidence precedes transaction cleanup, including failed prerequisites.
        defer { app?.terminate(); session?.clearTransactions(); session?.resetToDefaultState() }
        if output != nil { try capture("terminal-before-cleanup") }
    }

    @MainActor
    func testLocalMonthlyUnlocksThreeCategoriesAndExpiryRelocksWithoutRestart() async throws {
        func setting(_ key: String) -> String? {
            let env = ProcessInfo.processInfo.environment
            return env[key] ?? env["TEST_RUNNER_" + key]
        }
        try require(setting("QD_ENTITLEMENT_AUTH") == "DEDICATED_LOCAL_STOREKIT_SIMULATOR", "Dedicated local StoreKit authorization required")
        guard let expected = setting("QD_ENTITLEMENT_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              let actual = ProcessInfo.processInfo.environment["SIMULATOR_UDID"],
              actual.lowercased() == expected.lowercased() else {
            throw Stop(reason: "Explicit new dedicated device UDID must equal runner SIMULATOR_UDID")
        }
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else {
            throw Stop(reason: "Absolute dedicated output leaf required")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse existing output evidence")
        output = directory
        guard let catalog = Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit") else {
            throw Stop(reason: "Local runner Products.storekit missing")
        }
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState(); local.clearTransactions()
        local.disableDialogs = true; local.askToBuyEnabled = false; local.timeRate = .realTime
        try require(local.disableDialogs && !local.askToBuyEnabled && local.timeRate == .realTime, "Local session readback mismatch")
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let syncError = await local.simulatedError(forAPI: .appStoreSync)
        try require(purchaseError == nil && loadError == nil && syncError == nil, "No error injection permitted")
        try require(local.allTransactions().isEmpty, "Initial local transactions must be empty")
        try capture("initialized-local-empty-errors-nil")

        let application = XCUIApplication()
        app = application
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-resetDebugPremium", "-v53.authenticatedProfileFixture",
            "-v50.inMemoryStore", "-v51.followSystemAppearance"]
        application.launch() // Deliberately not launchClean: its fallback may launch again.
        try require(application.wait(for: .runningForeground, timeout: 20), "Single launch must reach foreground")
        try profile(premium: false)
        try capture("initial-fixed-offline-identity-free")
        try threeCategories(premium: false, phase: "initial-free")
        try profile(premium: false)
        try require(local.allTransactions().isEmpty, "Browsing locks must not purchase")

        let subscription = application.staticTexts["订阅管理"].firstMatch
        try reveal(subscription); try tap(subscription)
        let scroll = application.scrollViews["subscription.scroll"]
        try require(scroll.waitForExistence(timeout: 12), "Normal subscription sheet missing")
        let monthly = application.buttons["subscription.product." + monthlyID]
        try require(monthly.waitForExistence(timeout: 15), "Actual monthly product missing")
        let purchase = application.buttons["subscription.purchase"]
        try require(purchase.exists && !purchase.frame.isEmpty, "Measured purchase CTA required")
        try reveal(monthly, container: scroll, lowerBoundary: purchase.frame.minY)
        try tap(monthly)
        try waitState("Real monthly selection required") { monthly.exists && monthly.isSelected }
        try ready(purchase)
        try require(purchase.label.contains("每月"), "Actual purchase CTA must name monthly plan")
        try capture("monthly-selected-before-only-purchase")
        purchase.tap()
        try waitState("Uninjected monthly purchase must dismiss subscription") {
            !application.buttons["subscription.close"].exists && self.membership.exists && self.membership.label.contains("Pro 会员")
        }
        try profile(premium: true)
        let bought = local.allTransactions()
        try require(bought.count == 1 && bought[0].state == .purchased && !bought[0].pendingAskToBuyConfirmation
                    && bought[0].productIdentifier == monthlyID, "Exactly one successful actual monthly purchase required")
        purchasedIDs = Set(bought.map { String($0.identifier) })
        try capture("verified-one-local-monthly-pro")
        try threeCategories(premium: true, phase: "purchased-pro")
        try profile(premium: true)
        try unchangedTransactionHistory()
        try capture("before-local-expiry-same-live-process")

        // Existing SDK call used by V53ProfilePreferencesTests. No restore/relaunch/force.
        try local.expireSubscription(productIdentifier: monthlyID)
        expiryRequested = true
        try capture("expiry-requested-await-live-ui-not-yet-verified")
        try waitState("Transaction update must remove live Pro without restart", timeout: 20) {
            application.state == .runningForeground && !self.membership.exists
        }
        try profile(premium: false)
        try capture("verified-live-profile-free-after-expiry")
        try threeCategories(premium: false, phase: "expired-free")
        try profile(premium: false)
        try unchangedTransactionHistory()
        try capture("verified-three-categories-relocked-no-restart")
    }

    private var application: XCUIApplication { app! }
    private var membership: XCUIElement {
        application.descendants(matching: .any).matching(identifier: "profile.membershipSummary").firstMatch
    }
    private func tab(_ title: String) throws {
        try require(application.state == .runningForeground, "Unexpected process/background transition")
        let button = application.tabBars.buttons[title]
        try tap(button)
        try waitState("Tab selection failed: " + title) { button.isSelected }
    }
    private func profile(premium: Bool) throws {
        try tab("我的")
        let account = application.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch
        try waitState("Fixed offline identity must remain 服务端球友") {
            account.exists && account.label.contains("服务端球友") && !self.application.buttons["profile.login"].exists
        }
        if premium {
            try waitState("Expected actual Pro membership") { self.membership.exists && self.membership.label.contains("Pro 会员") }
        } else { try require(!membership.exists, "Expected Free, no stale Pro summary") }
    }
    private func threeCategories(premium: Bool, phase: String) throws {
        try tab("动作库")
        let search = application.textFields["librarySearchField"]
        try tap(search)
        // The same exact query is retained on return; no caret-dependent replacement.
        let value = search.value as? String
        if value == "直线球组合走位" {
            // Dismiss focus via Return without changing the known exact query.
            search.typeText("\n")
        } else {
            try require(value == "搜索动作" || value == "" || value == search.placeholderValue,
                        "Refuse overwriting unknown search contents")
            search.typeText("直线球组合走位\n")
        }
        let drill = application.descendants(matching: .any).matching(identifier: "drillCard_drill_c039").firstMatch
        try reveal(drill); try tap(drill)
        let unlock = application.buttons["unlockProButton"]
        let tryout = application.buttons["bottomTryoutButton"]
        if premium {
            try ready(tryout); try require(!unlock.exists, "Paid drill must no longer be locked")
            try capture(phase + "-paid-drill-action")
            try tap(tryout)
            // c039 has one real board; no silent formation-picker bypass.
            let rearrange = application.buttons["tryout.rearrange"]
            try ready(rearrange)
            try require(!application.navigationBars["选择球形"].exists, "Unexpected c039 formation route: observe before adapting")
            try tap(rearrange)
            try ready(rearrange)
            try capture(phase + "-paid-drill-real-tryout-rearranged")
            try back(); try ready(tryout)
        } else {
            try ready(unlock)
            try require(!tryout.isHittable, "Free must not operate paid drill tryout")
            try tap(unlock); try verifyAndClosePaywall(phase + "-paid-drill-locked")
            try ready(unlock)
        }
        try back(); try require(search.waitForExistence(timeout: 10), "Return to actual library required")

        try tab("训练")
        let plan = application.buttons["planPoster-plan_positioning"]
        try reveal(plan); try tap(plan)
        let primary = application.buttons["planDetail.primaryCTA"]
        let planLock = application.buttons["解锁此计划"]
        if premium {
            try ready(primary)
            try require(primary.label == "开始此计划" && !planLock.exists, "Fresh paid plan must be activatable")
            try tap(primary)
            let confirmation = application.alerts["激活训练计划"]
            try require(confirmation.waitForExistence(timeout: 10), "Actual plan activation confirmation missing")
            try require(confirmation.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "走位Ⅰ·短距到一库")).count == 1,
                        "Confirmation must identify actual paid plan")
            try capture(phase + "-paid-plan-actual-activation-confirmation")
            try tap(confirmation.buttons["取消"])
            try require(confirmation.waitForNonExistence(timeout: 8), "Plan cancellation must dismiss")
            try ready(primary); try require(primary.label == "开始此计划", "Cancellation must not activate plan")
        } else {
            try ready(planLock); try require(!primary.exists, "Free paid plan must not expose activation CTA")
            try tap(planLock); try verifyAndClosePaywall(phase + "-paid-plan-locked")
            try ready(planLock)
        }
        try back(); try require(application.tabBars.firstMatch.waitForExistence(timeout: 10), "Return to training root required")

        try tab("练习")
        try tap(application.buttons["angleHomeTab_学"])
        let atlas = application.buttons["分离角图谱"].firstMatch
        try reveal(atlas); try tap(atlas)
        let track = application.buttons["separationAngleAtlas.spinLegend.0"]
        if premium {
            try ready(track, timeout: 45)
            try require(!application.buttons["subscription.close"].exists, "Pro tool must be real destination, not paywall")
            try require(track.value as? String == "已选", "Actual initial atlas track state required")
            try tap(track)
            try waitState("Atlas track must become hidden") { track.value as? String == "未选" && !track.isSelected }
            try capture(phase + "-advanced-atlas-track-hidden")
            try tap(track)
            try waitState("Atlas track must restore") { track.value as? String == "已选" && track.isSelected }
            try capture(phase + "-advanced-atlas-track-restored")
            try back()
        } else {
            try require(!track.exists, "Free must not open actual advanced atlas")
            try verifyAndClosePaywall(phase + "-advanced-atlas-locked")
            try require(!track.exists, "Closing paywall must not reveal advanced tool")
        }
    }
    private func verifyAndClosePaywall(_ stage: String) throws {
        let close = application.buttons["subscription.close"]
        try ready(close)
        try require(application.scrollViews["subscription.scroll"].exists, "Real subscription sheet required")
        try capture(stage); try tap(close)
        try require(close.waitForNonExistence(timeout: 10), "Paywall must close normally")
    }
    private func back() throws {
        let bars = application.navigationBars.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
        try require(bars.count == 1, "Need one actual navigation bar; preserve AX rather than guess")
        let button = bars[0].buttons.firstMatch
        try ready(button)
        try require(button.identifier == "BackButton" || button.label == "返回" || button.label == "Back",
                    "Unobserved navigation control identity; do not tap arbitrary first button")
        try tap(button)
    }
    private func unchangedTransactionHistory() throws {
        let local = try XCTUnwrap(session)
        let transactions = local.allTransactions()
        try require(Set(transactions.map { String($0.identifier) }) == purchasedIDs && transactions.count == 1,
                    "Only original local purchase transaction may remain; no renewal/duplicate")
        try require(transactions[0].productIdentifier == monthlyID && !transactions[0].pendingAskToBuyConfirmation,
                    "Original monthly identity must remain")
        // Historical purchased state is not an active-entitlement oracle after expiry.
    }
    private func require(_ condition: Bool, _ reason: String) throws {
        guard condition else { XCTFail(reason); throw Stop(reason: reason) }
    }
    private func waitState(_ reason: String, timeout: TimeInterval = 15, _ body: @escaping () -> Bool) throws {
        let e = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)
        try require(XCTWaiter.wait(for: [e], timeout: timeout) == .completed, reason)
    }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 15) throws {
        try waitState("Actual control must exist, be enabled and hittable", timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
    }
    private func tap(_ element: XCUIElement) throws { try ready(element); element.tap() }
    private func reveal(_ element: XCUIElement, container explicit: XCUIElement? = nil, lowerBoundary: CGFloat? = nil) throws {
        let window = application.windows.firstMatch
        try require(window.exists && !window.frame.isEmpty, "Measured window required")
        for _ in 0..<18 {
            let bars = application.navigationBars.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
            let top = max(window.frame.minY, bars.map { $0.frame.maxY }.max() ?? window.frame.minY)
            let tabs = application.tabBars.firstMatch
            let bottom = min(lowerBoundary ?? window.frame.maxY, tabs.exists ? tabs.frame.minY : window.frame.maxY)
            if element.exists && !element.frame.isEmpty && window.frame.contains(element.frame)
                && element.frame.minY >= top && element.frame.maxY < bottom && element.isHittable { return }
            let candidates = application.scrollViews.allElementsBoundByIndex.filter {
                $0.exists && !$0.frame.isEmpty && $0.frame.width > window.frame.width * 0.75 && $0.frame.height > 150
            }
            let scroll: XCUIElement
            if let explicit { scroll = explicit } else {
                try require(candidates.count == 1, "Need unique real scroll container; capture unknown AX")
                scroll = candidates[0]
            }
            try require(scroll.exists && !scroll.frame.isEmpty && window.frame.intersects(scroll.frame), "Real scroll frame required")
            let upper = max(top, scroll.frame.minY), lower = min(bottom, scroll.frame.maxY)
            try require(lower > upper, "Nonempty usable viewport required")
            let direction: CGFloat = element.exists && !element.frame.isEmpty && element.frame.minY < upper ? -1 : 1
            let base = scroll.coordinate(withNormalizedOffset: .zero)
            let mid = (upper + lower) / 2 - scroll.frame.minY
            let distance = (lower - upper) / 5
            base.withOffset(CGVector(dx: scroll.frame.width / 2, dy: mid + direction * distance / 2))
                .press(forDuration: 0.05, thenDragTo: base.withOffset(CGVector(dx: scroll.frame.width / 2, dy: mid - direction * distance / 2)))
        }
        try require(false, "Bounded reveal failed; retain actual evidence without guessing coordinates")
    }
    private func capture(_ stage: String) throws {
        let directory = try XCTUnwrap(output)
        sequence += 1
        let stem = "entitlement-" + runID + "-\(sequence)-" + stage
        let screenshot = XCUIScreen.main.screenshot()
        let shot = XCTAttachment(screenshot: screenshot); shot.name = stem; shot.lifetime = .keepAlways; add(shot)
        try screenshot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let transactions = session?.allTransactions() ?? []
        let summary = "time=\(Date()) uptime=\(ProcessInfo.processInfo.systemUptime) expiryRequested=\(expiryRequested) appState=\(String(describing: app?.state)) count=\(transactions.count)\n"
            + transactions.map { "id=\($0.identifier) original=\($0.originalTransactionIdentifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)" }.joined(separator: "\n")
        try Data(summary.utf8).write(to: directory.appendingPathComponent(stem + "-transactions.txt"), options: .withoutOverwriting)
        let text = XCTAttachment(string: summary); text.name = stem + "-transactions"; text.lifetime = .keepAlways; add(text)
        let ax = app?.debugDescription ?? "App not launched; local session initialization evidence only"
        try Data(ax.utf8).write(to: directory.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let tree = XCTAttachment(string: ax); tree.name = stem + "-AX"; tree.lifetime = .keepAlways; add(tree)
    }
}
