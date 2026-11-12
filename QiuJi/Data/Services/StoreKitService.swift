import StoreKit
import CryptoKit

struct StoreEntitlementSnapshot: Equatable, Sendable {
    let productID: String
    let expirationDate: Date?
    let revocationDate: Date?
    var appAccountToken: UUID? = nil
}

/// Shared authorization rules. Snapshots must come from verified current entitlements,
/// never from transaction history or a persisted premium Boolean.
enum ProAccessPolicy {
    enum Decision: Equatable {
        case allowed
        case requiresLogin
        case checkingEntitlements
        case requiresPro
    }

    static func decision(requiresPremium: Bool, hasSession: Bool,
                         isPremium: Bool, hasResolvedEntitlements: Bool) -> Decision {
        if !requiresPremium { return .allowed }
        guard hasSession else { return .requiresLogin }
        if isPremium { return .allowed }
        return hasResolvedEntitlements ? .requiresPro : .checkingEntitlements
    }

    static func currentProEntitlements(in snapshots: [StoreEntitlementSnapshot]) -> [StoreEntitlementSnapshot] {
        // StoreKit's currentEntitlements includes eligible billing grace periods.
        // An expiration-date-only filter would incorrectly remove those rights.
        snapshots.filter {
            StoreKitService.allProductIDs.contains($0.productID) && $0.revocationDate == nil
        }
    }
}

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

    // Stable for the lifetime of a CuePhys user, across providers and devices.
    // This namespace and byte layout are part of the persisted transaction format.
    static func accountToken(for userID: String) -> UUID {
        let digest = SHA256.hash(data: Data(("CuePhys/StoreKit/account/v1/" + userID).utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return bytes.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
    }

    // MARK: - Product Loading

    func loadProducts() async throws -> [Product] {
        try await Product.products(for: [Self.lifetimeID])
    }

    // MARK: - Purchase

    func purchase(_ product: Product, accountToken: UUID) async throws -> Transaction {
        guard product.id == Self.lifetimeID, product.type == .nonConsumable else { throw StoreError.unknown }
        let result = try await product.purchase(options: [.appAccountToken(accountToken)])
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
        Set(await currentEntitlements().map(\.productID))
    }

    func currentEntitlements() async -> [StoreEntitlementSnapshot] {
        var snapshots: [StoreEntitlementSnapshot] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                if tx.revocationDate == nil {
                    snapshots.append(StoreEntitlementSnapshot(
                        productID: tx.productID,
                        expirationDate: tx.expirationDate,
                        revocationDate: tx.revocationDate,
                        appAccountToken: tx.appAccountToken
                    ))
                }
            }
        }
        return ProAccessPolicy.currentProEntitlements(in: snapshots)
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
