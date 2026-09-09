import XCTest
import StoreKit
import StoreKitTest

/// Hosted QiuJiTests only. Direct Product.purchase(), not session.buyProduct or App UI.
/// Run L0 alone first; the orchestrator selects L1 only after reviewing L0.
@MainActor
final class StoreKitPurchaseErrorLifecycleDiagnosticTests: XCTestCase {
    private var session: SKTestSession?
    private let runID = UUID().uuidString
    private let monthlyID = "com.xinkuan.qiuji.premium.monthly"
    private var eventIndex = 0
    private var outputURL: URL?

    private struct DiagnosticFailure: Error { let reason: String }

    override func tearDown() async throws {
        defer { session?.clearTransactions(); session?.resetToDefaultState() }
        if session != nil { try await evidence("terminal-before-cleanup") }
    }

    func testLocalProductPurchaseWithoutInjectedError() async throws {
        do {
            let local = try await configureLocalSession()
            let product = try await loadMonthly()
            try await evidence("L0-before-purchase")
            let result = try await product.purchase()
            try await requireVerifiedSuccess(result, local: local, stage: "L0-result")
        } catch {
            if session != nil { try await evidence("L0-error", error: error) }
            throw DiagnosticFailure(reason: "L0 stopped; see bounded error-chain evidence")
        }
    }

    func testLocalProductPurchaseInjectedErrorThenClearRetrySameProduct() async throws {
        do {
            let local = try await configureLocalSession()
            let product = try await loadMonthly() // Retain this exact instance for retry.
            try await evidence("L1-before-injection")
            try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
            let installed = await local.simulatedError(forAPI: .purchase)
            try await evidence("L1-injection-readback", extra: ["purchaseErrorIsNil": installed == nil,
                "requestedInjection": "generic.networkError.NSURLErrorDomain.-1009"])
            try require(installed != nil, "Purchase error injection was not installed")

            var firstResult: Product.PurchaseResult?
            var firstError: Error?
            // Catch only the API call, not the assertions surrounding the expected error.
            do { firstResult = try await product.purchase() }
            catch { firstError = error }
            if let result = firstResult {
                try await evidence("L1-unexpected-first-result", extra: ["result": resultLabel(result)])
                try require(false, "Injected purchase returned a result instead of throwing")
            }
            guard let actualError = firstError else {
                try require(false, "Injected purchase produced neither result nor error")
                throw DiagnosticFailure(reason: "Missing first error")
            }
            try await evidence("L1-first-purchase-threw", error: actualError)
            let chain = errorChain(actualError)
            try require(chain.contains { ($0["domain"] as? String) == NSURLErrorDomain && ($0["code"] as? Int) == -1009 },
                        "Injected call threw, but no bounded NSError chain entry identifies network error -1009")
            try require(local.allTransactions().filter { $0.state == .purchased }.isEmpty,
                        "Injected failure unexpectedly created a purchased transaction")

            // Keep failed transactions, same session, and same Product. No reset or refetch.
            try await local.setSimulatedError(nil, forAPI: .purchase)
            let cleared = await local.simulatedError(forAPI: .purchase)
            try await evidence("L1-clear-readback-before-retry", extra: ["purchaseErrorIsNil": cleared == nil])
            try require(cleared == nil, "Purchase error did not clear")
            let retry = try await product.purchase()
            try await requireVerifiedSuccess(retry, local: local, stage: "L1-retry-result")
        } catch {
            if session != nil { try await evidence("L1-error", error: error) }
            throw DiagnosticFailure(reason: "L1 stopped; see bounded error-chain evidence")
        }
    }

    func testLocalProductRetryAfterClearWithRefetchedProduct() async throws {
        do {
            let local = try await configureLocalSession()
            let product = try await loadMonthly()
            try await evidence("L2-before-injection")
            try await local.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
            let installed = await local.simulatedError(forAPI: .purchase)
            try await evidence("L2-injection-readback", extra: ["purchaseErrorIsNil": installed == nil,
                "requestedInjection": "generic.networkError.NSURLErrorDomain.-1009"])
            try require(installed != nil, "Purchase error injection was not installed")

            var firstResult: Product.PurchaseResult?
            var firstError: Error?
            // Catch only the API call, not the assertions surrounding the expected error.
            do { firstResult = try await product.purchase() }
            catch { firstError = error }
            if let result = firstResult {
                try await evidence("L2-unexpected-first-result", extra: ["result": resultLabel(result)])
                try require(false, "Injected purchase returned a result instead of throwing")
            }
            guard let actualError = firstError else {
                try require(false, "Injected purchase produced neither result nor error")
                throw DiagnosticFailure(reason: "Missing first error")
            }
            try await evidence("L2-first-purchase-threw", error: actualError)
            let chain = errorChain(actualError)
            try require(chain.contains { ($0["domain"] as? String) == NSURLErrorDomain && ($0["code"] as? Int) == -1009 },
                        "Injected call threw, but no bounded NSError chain entry identifies network error -1009")
            try require(local.allTransactions().filter { $0.state == .purchased }.isEmpty,
                        "Injected failure unexpectedly created a purchased transaction")

            // Keep failed transactions and same session; refetch is the only changed variable.
            try await local.setSimulatedError(nil, forAPI: .purchase)
            let cleared = await local.simulatedError(forAPI: .purchase)
            try await evidence("L2-clear-readback-before-retry", extra: ["purchaseErrorIsNil": cleared == nil])
            try require(cleared == nil, "Purchase error did not clear")
            let refreshed = try await loadMonthly()
            try await evidence("L2-refetched-before-retry")
            let retry = try await refreshed.purchase()
            try await requireVerifiedSuccess(retry, local: local, stage: "L2-retry-result")
        } catch {
            if session != nil { try await evidence("L2-error", error: error) }
            throw DiagnosticFailure(reason: "L2 stopped; see bounded error-chain evidence")
        }
    }

    private func configureLocalSession() async throws -> SKTestSession {
        let env = ProcessInfo.processInfo.environment
        try require((env["QD_STOREKIT_LIFECYCLE_AUTH"] ?? env["TEST_RUNNER_QD_STOREKIT_LIFECYCLE_AUTH"]) == "DEDICATED_LOCAL_STOREKIT_SIMULATOR",
                    "Dedicated local StoreKit diagnostic authorization is required")
        guard let path = env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"], !path.isEmpty else {
            try require(false, "Diagnostic output directory is required")
            throw DiagnosticFailure(reason: "Missing output")
        }
        outputURL = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputURL!, withIntermediateDirectories: true)
        // QiuJiTests TEST_HOST is 球迹.app/球迹. Products is in the App resource phase;
        // unlike the UI runner, this test bundle has no separately copied Products catalog.
        try require(Bundle.main.bundleIdentifier == "com.xinkuan.qiuji", "Must run inside the QiuJi App host")
        guard let catalog = Bundle.main.url(forResource: "Products", withExtension: "storekit") else {
            try require(false, "Host Products.storekit resource is missing; never fall back to a real store")
            throw DiagnosticFailure(reason: "Missing local catalog")
        }
        let local = try SKTestSession(contentsOf: catalog)
        session = local
        local.resetToDefaultState()
        local.clearTransactions()
        local.disableDialogs = true
        local.askToBuyEnabled = false
        local.timeRate = .realTime
        let purchaseError = await local.simulatedError(forAPI: .purchase)
        let loadError = await local.simulatedError(forAPI: .loadProducts)
        let syncError = await local.simulatedError(forAPI: .appStoreSync)
        try await evidence("local-session-configured", extra: [
            "hostBundleID": Bundle.main.bundleIdentifier ?? "missing", "catalogResource": "host/Products.storekit",
            "disableDialogs": local.disableDialogs, "askToBuyEnabled": local.askToBuyEnabled,
            "timeRateIsRealTime": local.timeRate == .realTime,
            "purchaseErrorIsNil": purchaseError == nil, "loadErrorIsNil": loadError == nil, "syncErrorIsNil": syncError == nil
        ])
        try require(local.disableDialogs && !local.askToBuyEnabled && local.timeRate == .realTime, "Local session properties do not match")
        try require(purchaseError == nil && loadError == nil && syncError == nil, "Unexpected initial simulated error")
        try require(local.allTransactions().isEmpty, "Initial local transactions must be empty")
        let entitlements = await currentEntitlements()
        try require(entitlements.isEmpty, "Initial local current entitlements must be empty")
        return local
    }

    private func loadMonthly() async throws -> Product {
        let products = try await Product.products(for: [monthlyID])
        try require(products.count == 1 && products.first?.id == monthlyID, "Expected the one canonical local monthly product")
        guard let product = products.first else { throw DiagnosticFailure(reason: "Missing product") }
        try require(product.type == .autoRenewable, "Monthly product must be auto-renewable")
        return product
    }

    private func requireVerifiedSuccess(_ result: Product.PurchaseResult, local: SKTestSession, stage: String) async throws {
        try await evidence(stage, extra: ["purchaseResult": resultLabel(result)])
        guard case .success(.verified(let transaction)) = result else {
            try require(false, "Expected verified purchase success; pending, cancellation and unverified results are failures")
            throw DiagnosticFailure(reason: "Unexpected purchase result")
        }
        try require(transaction.productID == monthlyID, "Verified purchase product mismatch")
        // Result, transaction history and current entitlements were persisted above before finish.
        await transaction.finish()
        let purchased = local.allTransactions().filter { $0.state == .purchased }
        try await evidence(stage + "-after-finish")
        try require(purchased.count == 1 && purchased.first?.productIdentifier == monthlyID, "Expected exactly one purchased monthly transaction")
        let entitlements = await currentEntitlements()
        try require(entitlements.contains { ($0["productID"] as? String) == monthlyID && ($0["verified"] as? Bool) == true && ($0["revoked"] as? Bool) == false },
                    "Verified monthly current entitlement is missing")
    }

    private func resultLabel(_ result: Product.PurchaseResult) -> String {
        switch result {
        case .success(.verified): return "success.verified"
        case .success(.unverified): return "success.unverified"
        case .pending: return "pending"
        case .userCancelled: return "userCancelled"
        @unknown default: return "unknown"
        }
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            XCTFail(message)
            throw DiagnosticFailure(reason: message)
        }
    }

    private func currentEntitlements() async -> [[String: Any]] {
        var rows: [[String: Any]] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                rows.append(["verified": true, "productID": transaction.productID, "id": String(transaction.id),
                             "revoked": transaction.revocationDate != nil])
            case .unverified(let transaction, _):
                rows.append(["verified": false, "productID": transaction.productID, "id": String(transaction.id)])
            }
        }
        return rows
    }

    private func errorChain(_ error: Error) -> [[String: Any]] {
        var rows: [[String: Any]] = []
        var current: NSError? = error as NSError
        // StoreKitError.networkError carries URLError as a Swift associated value.
        // Bridging it to NSError does not expose that value via NSUnderlyingErrorKey.
        if let storeError = error as? StoreKitError, case let .networkError(underlying) = storeError {
            let outer = error as NSError
            rows.append(["domain": outer.domain, "code": outer.code, "description": outer.localizedDescription])
            current = underlying as NSError
        }
        for _ in rows.count..<4 {
            guard let item = current else { break }
            rows.append(["domain": item.domain, "code": item.code, "description": item.localizedDescription])
            // Only follow this specific link. Never serialize or print complete userInfo.
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return rows
    }

    private func evidence(_ stage: String, error: Error? = nil, extra: [String: Any] = [:]) async throws {
        guard let outputURL else { throw DiagnosticFailure(reason: "Evidence output not configured") }
        eventIndex += 1
        let transactions = session?.allTransactions() ?? []
        var record: [String: Any] = [
            "runID": runID, "eventIndex": eventIndex, "stage": stage,
            "wallTime": ISO8601DateFormatter().string(from: Date()), "systemUptime": ProcessInfo.processInfo.systemUptime,
            "transactionCount": transactions.count,
            "transactions": transactions.map { ["id": String($0.identifier), "originalID": String($0.originalTransactionIdentifier),
                "productID": $0.productIdentifier, "state": $0.state.rawValue, "pending": $0.pendingAskToBuyConfirmation] as [String: Any] },
            "currentEntitlements": await currentEntitlements(), "extra": extra
        ]
        if let error { record["errorChain"] = errorChain(error) }
        let data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        let name = "storekit-lifecycle-\(runID)-\(eventIndex)-\(stage)"
        try data.write(to: outputURL.appendingPathComponent(name + ".json"), options: .withoutOverwriting)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
