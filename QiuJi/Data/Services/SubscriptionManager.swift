import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published State

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Sorted products for UI

    var monthlyProduct: Product?  { products.first { $0.id == StoreKitService.monthlyID } }
    var yearlyProduct: Product?   { products.first { $0.id == StoreKitService.yearlyID } }
    var lifetimeProduct: Product? { products.first { $0.id == StoreKitService.lifetimeID } }

    // MARK: - Private

    private let service = StoreKitService.shared
    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let ids = StoreKitService.allProductIDs
        print("[StoreKit] ⏳ Requesting products for IDs: \(ids)")

        do {
            let loaded = try await service.loadProducts()
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                print("[StoreKit] ⚠️ Product.products returned EMPTY")
                print("[StoreKit] 💡 Check: Xcode → Edit Scheme → Run → Options → StoreKit Configuration → select Products.storekit")
                #if targetEnvironment(simulator)
                print("[StoreKit] Running on Simulator")
                #else
                print("[StoreKit] Running on Device — ensure launched from Xcode")
                #endif
                errorMessage = "未找到订阅方案。请在 Xcode Edit Scheme → Run → Options 中选择 Products.storekit"
            } else {
                print("[StoreKit] ✅ Loaded \(loaded.count) products: \(loaded.map { "\($0.id) (\($0.displayPrice))" })")
                errorMessage = nil
            }
        } catch {
            print("[StoreKit] ❌ loadProducts error: \(error)")
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    func retryLoadProducts() async {
        products = []
        errorMessage = nil
        await loadProducts()
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        let ids = await service.currentEntitlementProductIDs()
        purchasedProductIDs = ids
        isPremium = !ids.isEmpty
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await service.purchase(product)
            await checkEntitlements()
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await service.restorePurchases()
            await checkEntitlements()
            if isPremium {
                return true
            } else {
                errorMessage = "未找到可恢复的购买记录"
                return false
            }
        } catch {
            errorMessage = "恢复购买失败，请稍后重试"
            return false
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkEntitlements()
                }
            }
        }
    }
}
