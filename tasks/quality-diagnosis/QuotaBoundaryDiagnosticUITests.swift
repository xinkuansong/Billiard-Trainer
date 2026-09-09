import XCTest
import StoreKit
import StoreKitTest

/// Draft: 19 prior uses are an explicit fixture, both subsequent answers and purchase use normal UI.
final class QuotaBoundaryDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var session: SKTestSession?
    private var output: URL?
    private var sequence = 0
    private let monthlyID = "com.xinkuan.qiuji.premium.monthly"
    private var day = ""
    private struct Stop: Error { let reason: String }
    private var application: XCUIApplication { app! }
    private func env(_ key: String) -> String? {
        let e = ProcessInfo.processInfo.environment
        return e[key] ?? e["TEST_RUNNER_" + key]
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate(); session?.clearTransactions(); session?.resetToDefaultState() }
        if output != nil { try capture("terminal-before-local-cleanup") }
    }

    @MainActor
    func testLastFreeAnswerExhaustsQuotaThenLocalMonthlyPurchaseAllowsNextAnswerWithoutRestart() async throws {
        try require(env("QD_QUOTA_AUTHORIZATION") == "NEW_DEDICATED_LOCAL_STOREKIT_NEAR_LIMIT_OFFLINE_FIXTURE", "New dedicated local StoreKit device and 19-use fixture authorization required")
        guard let expected = env("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env("SIMULATOR_UDID")?.lowercased() == expected.lowercased()
        else { throw Stop(reason: "Authorized new UDID must equal actual runner") }
        try require(env("QD_ACCOUNT_API_GUARD") == "SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED", "Installed Debug APIClient offline pretransport guard must be independently verified")
        guard let path = env("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else { throw Stop(reason: "Absolute dedicated evidence root required") }
        let dir = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("quota-" + UUID().uuidString, isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: dir.path), "New evidence directory required")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        output = dir
        guard let catalog = Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit") else { throw Stop(reason: "Actual bundled local Products.storekit required") }
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState(); local.clearTransactions()
        local.disableDialogs = true; local.askToBuyEnabled = false; local.timeRate = .realTime
        try require(local.disableDialogs && !local.askToBuyEnabled && local.timeRate == .realTime, "Local session configuration must read back")
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let syncError = await local.simulatedError(forAPI: .appStoreSync)
        try require(purchaseError == nil && loadError == nil && syncError == nil && local.allTransactions().isEmpty, "Empty local transactions and no error injection required")
        day = today()
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-resetDebugPremium", "-v53.authenticatedProfileFixture", "-v50.inMemoryStore", "-w7.forceDailyLimitNear"]
        app.launchEnvironment = [:]
        do {
            app.launch() // Exactly once: relaunch would reapply 19-use fixture and invalidate bypass proof.
            try require(app.wait(for: .runningForeground, timeout: 20), "One live App launch required")
            try tab("我的")
            let account = app.buttons["profile.accountHeader"]
            try waitState("Exact offline synthetic identity required") { account.exists && account.label == "个人信息，服务端球友" && !app.buttons["profile.login"].exists }
            try require(!app.descendants(matching: .any)["profile.membershipSummary"].exists, "Must start Free")
            try capture("fixed-offline-free")
            try tab("练习")
            try uniqueTap("angleHomeTab_练")
            let card = app.buttons.matching(identifier: "角度预测")
            try require(card.count == 1, "One normal geometric entry required")
            try reveal(card.firstMatch); try tap(card.firstMatch)
            try waitState("Actual geometric page required") { app.navigationBars["角度预测"].exists }
            try require(try readout("次数") == "0" && readout("剩余") == "1", "Fresh geometric session and actual one remaining use required")
            try require(!app.staticTexts["今日免费次数已用完"].exists, "Last free question must not be prematurely locked")
            try capture("fixture-19-used-one-remaining-unsubmitted")
            try submitThirty()
            try waitState("Real last answer must reach limit gate") { app.staticTexts["今日免费次数已用完"].exists }
            try require(try readout("次数") == "1" && readout("剩余") == "0", "Actual submission must consume the final free use")
            try require(!app.buttons["下一题"].exists && app.buttons["换题"].exists && !app.buttons["换题"].isEnabled && !app.buttons["答题"].exists, "Free cannot continue at exhausted quota")
            let gate = app.buttons.matching(identifier: "解锁 Pro")
            try require(gate.count == 1, "One actual compact quota unlock CTA required")
            try reveal(gate.firstMatch)
            try capture("last-free-submitted-quota-exhausted")
            try require(local.allTransactions().isEmpty, "No transaction before normal purchase")
            try tap(gate.firstMatch)
            let scroll = app.scrollViews["subscription.scroll"]
            try waitState("Actual subscription sheet required") { scroll.exists }
            let monthly = app.buttons["subscription.product." + monthlyID]
            try waitState("Real local monthly product required") { monthly.exists }
            let purchase = app.buttons["subscription.purchase"]
            try require(purchase.exists && !purchase.frame.isEmpty, "Actual bottom purchase CTA required")
            try reveal(monthly, container: scroll, lowerBoundary: purchase.frame.minY)
            try tap(monthly)
            try waitState("Monthly must be selected") { monthly.isSelected }
            try require(purchase.label.contains("每月"), "Purchase CTA must explicitly identify monthly selection")
            try capture("normal-local-monthly-before-purchase")
            try tap(purchase)
            try waitState("Same geometric result must unlock after purchase", timeout: 20) {
                app.state == .runningForeground && !app.buttons["subscription.close"].exists && app.buttons["下一题"].exists && !app.staticTexts["今日免费次数已用完"].exists
            }
            let transactions = local.allTransactions()
            try require(transactions.count == 1 && transactions[0].productIdentifier == monthlyID && transactions[0].state == .purchased && !transactions[0].pendingAskToBuyConfirmation, "Exactly one successful local monthly transaction required")
            let transactionID = transactions[0].identifier
            try require(try readout("次数") == "1", "Purchase must not fabricate or erase submitted answer")
            try require(!app.staticTexts["剩余"].exists && app.buttons["换题"].isEnabled, "Actual Pro quota UI must bypass the limit")
            try capture("same-process-result-unlocked-by-local-purchase")
            let next = app.buttons["下一题"]
            try reveal(next); try tap(next)
            try waitState("Normal next question must be answerable") { app.buttons["答题"].exists && !app.buttons["下一题"].exists }
            try submitThirty()
            try waitState("Post-quota Pro answer must yield next question action") { app.buttons["下一题"].exists }
            try require(try readout("次数") == "2", "Second real answer must be counted beyond exhausted free quota")
            try require(!app.staticTexts["今日免费次数已用完"].exists && !app.staticTexts["剩余"].exists, "Pro must not relock after another submitted answer")
            let finalTransactions = local.allTransactions()
            try require(finalTransactions.count == 1 && finalTransactions[0].identifier == transactionID, "No duplicate local purchase")
            try require(today() == day && app.state == .runningForeground, "No date rollover or process loss may masquerade as quota bypass")
            try capture("verified-second-answer-after-quota-without-relaunch")
        } catch {
            try capture("failure-before-cleanup")
            throw error
        }
    }
    private func today() -> String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }
    private func submitThirty() throws {
        try require(today() == day, "Date rollover invalidates same-day case")
        let answer = application.buttons["答题"]
        try reveal(answer); try tap(answer)
        try uniqueTap("3"); try uniqueTap("0")
        try capture("keypad-real-thirty-before-submit")
        try uniqueTap("提交")
        try waitState("Submitted result must display actual entered answer") {
            self.application.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "你答了", "30°")).count == 1
        }
    }
    /// BTReadout emits separate label/value Text. Match nearest numeric text to its right,
    /// vertically overlapping the actual label; never use global '1' (the table ball has that label).
    private func readout(_ name: String) throws -> String {
        let labels = application.staticTexts.matching(identifier: name)
        try require(labels.count == 1, "Unique HUD label required: " + name)
        let frame = labels.firstMatch.frame
        let values = application.staticTexts.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && $0.frame.minX >= frame.maxX && $0.frame.minY < frame.maxY && $0.frame.maxY > frame.minY && !$0.label.isEmpty && $0.label.allSatisfy(\.isNumber)
        }.sorted { $0.frame.minX < $1.frame.minX }
        try require(!values.isEmpty, "Source-shaped HUD numeric value missing: " + name)
        if values.count > 1 { try require(values[0].frame.minX < values[1].frame.minX, "Ambiguous HUD numeric candidate") }
        return values[0].label
    }
    private func uniqueTap(_ id: String) throws {
        let q = application.buttons.matching(identifier: id)
        try require(q.count == 1, "One exact button required: " + id)
        try tap(q.firstMatch)
    }
    private func tab(_ title: String) throws {
        try waitState("Unique TabBar required") { self.application.tabBars.count == 1 }
        let q = application.tabBars.firstMatch.buttons.matching(identifier: title)
        try require(q.count == 1, "Unique actual Tab required")
        try tap(q.firstMatch)
        try waitState("Actual Tab selected") { q.firstMatch.isSelected }
    }
    private func require(_ value: Bool, _ reason: String) throws { if !value { throw Stop(reason: reason) } }
    private func waitState(_ reason: String, timeout: TimeInterval = 15, _ body: @escaping () -> Bool) throws {
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in body() }, object: nil)], timeout: timeout) == .completed, reason)
    }
    private func tap(_ e: XCUIElement) throws {
        try waitState("Actual enabled hittable control required") { e.exists && e.isEnabled && e.isHittable }
        try require(!e.frame.isEmpty && application.windows.firstMatch.frame.contains(e.frame), "Full control must lie inside actual window")
        e.tap()
    }
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
        let dir = try XCTUnwrap(output)
        sequence += 1
        let stem = "\(sequence)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app?.debugDescription ?? "App not yet launched"
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: dir.appendingPathComponent(stem + "-AX.txt"), options: .withoutOverwriting)
        let transactions = session?.allTransactions() ?? []
        let evidence = "uptime=\(ProcessInfo.processInfo.systemUptime) date=\(today()) initialDay=\(day) appState=\(String(describing: app?.state))\n" + transactions.map { "id=\($0.identifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation)" }.joined(separator: "\n")
        try Data(evidence.utf8).write(to: dir.appendingPathComponent(stem + "-transactions.txt"), options: .withoutOverwriting)
        let tx = XCTAttachment(string: evidence); tx.name = stem + "-transactions"; tx.lifetime = .keepAlways; add(tx)
    }
}
