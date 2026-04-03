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
        do {
            products = try await service.loadProducts()
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "无法加载订阅方案"
        }
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
