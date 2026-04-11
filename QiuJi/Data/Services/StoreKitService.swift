import StoreKit

enum StoreError: LocalizedError {
    case failedVerification
    case purchasePending
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "购买验证失败，请稍后重试"
        case .purchasePending:    return "购买正在处理中，请稍候"
        case .unknown:            return "未知错误"
        }
    }
}

actor StoreKitService {

    static let shared = StoreKitService()
    private init() {}

    static let monthlyID  = "com.xinkuan.qiuji.premium.monthly"
    static let yearlyID   = "com.xinkuan.qiuji.premium.yearly"
    static let lifetimeID = "com.xinkuan.qiuji.premium.lifetime"

    static let allProductIDs: Set<String> = [monthlyID, yearlyID, lifetimeID]

    // MARK: - Product Loading

    func loadProducts() async throws -> [Product] {
        try await Product.products(for: Self.allProductIDs)
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled:
            throw CancellationError()
        case .pending:
            throw StoreError.purchasePending
        @unknown default:
            throw StoreError.unknown
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    // MARK: - Entitlements

    func currentEntitlementProductIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                if tx.revocationDate == nil {
                    ids.insert(tx.productID)
                }
            }
        }
        return ids
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
