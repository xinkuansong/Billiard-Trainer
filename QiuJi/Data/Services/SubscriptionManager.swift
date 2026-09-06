import Combine
import StoreKit
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published State

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var entitlementSnapshots: [StoreEntitlementSnapshot] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Sorted products for UI

    var monthlyProduct: Product?  { products.first { $0.id == StoreKitService.monthlyID } }
    var yearlyProduct: Product?   { products.first { $0.id == StoreKitService.yearlyID } }
    var lifetimeProduct: Product? { products.first { $0.id == StoreKitService.lifetimeID } }

    var entitlementStatusLabel: String {
        Self.entitlementStatusLabel(
            productIDs: purchasedProductIDs,
            snapshots: entitlementSnapshots,
            isPremium: isPremium
        )
    }

    static func entitlementStatusLabel(productIDs: Set<String>,
                                       snapshots: [StoreEntitlementSnapshot],
                                       isPremium: Bool) -> String {
        if productIDs.contains(StoreKitService.lifetimeID) { return "永久有效" }
        let subscriptionIDs: Set<String> = [StoreKitService.monthlyID, StoreKitService.yearlyID]
        if let expiration = snapshots
            .filter({ subscriptionIDs.contains($0.productID) && $0.revocationDate == nil })
            .compactMap(\.expirationDate)
            .max() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年M月d日"
            return "有效至 \(formatter.string(from: expiration))"
        }
        if !productIDs.isDisjoint(with: subscriptionIDs) { return "订阅有效，状态待刷新" }
        return isPremium ? "Pro 已解锁，状态待刷新" : "未订阅"
    }

    // MARK: - Private

    private let service = StoreKitService.shared
    private var transactionListener: Task<Void, Error>?

    private var authObservation: AnyCancellable?
    private var authenticatedUserID: String?
    private var sessionRevision = 0
    private var hasAuthenticatedSession = false
    private let entitlementLoader: () async -> [StoreEntitlementSnapshot]
    private let useDebugOverrides: Bool

    init(
        entitlementLoader: @escaping () async -> [StoreEntitlementSnapshot] = {
            await StoreKitService.shared.currentEntitlements()
        },
        listenForUpdates: Bool = true,
        useDebugOverrides: Bool = true
    ) {
        self.entitlementLoader = entitlementLoader
        self.useDebugOverrides = useDebugOverrides
        #if DEBUG
        if useDebugOverrides { Self.applyDebugPremiumLaunchOverrides() }
        isDebugPremiumPersisted = UserDefaults.standard.bool(forKey: Self.debugPremiumUnlockedKey)
        if allowsPremiumSession && useDebugOverrides && Self.isEntitlementForcedPremium {
            isPremium = true
        }
        #endif
        if listenForUpdates { transactionListener = listenForTransactions() }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Bind before bootstrap so every account transition clears presentation synchronously.
    func bind(to authState: AuthState) {
        authObservation = authState.$phase.sink { [weak self] phase in
            self?.updateSession(phase)
        }
    }

    private var allowsPremiumSession: Bool {
        if authenticatedUserID != nil { return true }
        #if DEBUG
        // Explicit UI launch fixtures may render Pro without a server login. Once an
        // account has logged in, even this fixture must respect its subsequent logout.
        if useDebugOverrides && !hasAuthenticatedSession &&
            ProcessInfo.processInfo.arguments.contains(Self.forcePremiumArgument) {
            return true
        }
        #endif
        return false
    }

    private func updateSession(_ phase: AuthPhase) {
        let userID: String?
        if case .authenticated(let user) = phase { userID = user.id }
        else { userID = nil }
        guard userID != authenticatedUserID else { return }
        authenticatedUserID = userID
        if userID != nil { hasAuthenticatedSession = true }
        sessionRevision += 1
        clearEntitlements()
        if userID != nil { Task { await checkEntitlements() } }
    }

    private func clearEntitlements() {
        isPremium = false
        purchasedProductIDs = []
        entitlementSnapshots = []
        errorMessage = nil
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let ids = StoreKitService.allProductIDs
        print("[StoreKit] ⏳ Requesting products for IDs: \(ids)")

        do {
            // 加超时：StoreKit 在模拟器未配置 .storekit / 无网络时 `Product.products`
            // 可能长期挂起，导致 isLoading 永不归位、Paywall 价格/按钮一直转圈
            // （UR-20260529 U-04）。超时后归入错误态，复用既有「重试」UI。
            let loaded = try await loadProductsWithTimeout(seconds: 8)
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                print("[StoreKit] ⚠️ Product.products returned EMPTY")
                print("[StoreKit] 💡 Check: Xcode → Edit Scheme → Run → Options → StoreKit Configuration → select Products.storekit")
                #if targetEnvironment(simulator)
                print("[StoreKit] Running on Simulator")
                #else
                print("[StoreKit] Running on Device — ensure launched from Xcode")
                #endif
                #if DEBUG && targetEnvironment(simulator)
                errorMessage = "模拟器未注入商店配置，无法购买。请点下方「模拟器解锁 Pro」。"
                #else
                errorMessage = "未找到订阅方案。请在 Xcode Edit Scheme → Run → Options 中选择 Products.storekit"
                #endif
            } else {
                print("[StoreKit] ✅ Loaded \(loaded.count) products: \(loaded.map { "\($0.id) (\($0.displayPrice))" })")
                errorMessage = nil
            }
        } catch is TimeoutError {
            print("[StoreKit] ⏱️ loadProducts timed out")
            errorMessage = "加载超时，请检查网络后重试"
        } catch {
            print("[StoreKit] ❌ loadProducts error: \(error)")
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private struct TimeoutError: Error {}

    /// Race the StoreKit product load against a timeout so a hung request can't
    /// pin the paywall in a perpetual loading state.
    private func loadProductsWithTimeout(seconds: Double) async throws -> [Product] {
        let svc = service
        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask { try await svc.loadProducts() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw TimeoutError() }
            return result
        }
    }

    func retryLoadProducts() async {
        products = []
        errorMessage = nil
        await loadProducts()
    }

    // MARK: - Test-only Entitlement Override（X-v31-3 / 模拟器持久解锁）

    #if DEBUG
    /// 强制订阅态：`simctl launch` / 点图标不会注入 `Products.storekit`，
    /// 模拟器买不成 Pro。`-forcePremium` 与 UserDefaults 持久开关把 `isPremium`
    /// 注入，使**所有**依赖它的门禁看到同一状态。
    static let forcePremiumArgument = "-forcePremium"
    /// 既有开关：强制未订阅态。同时传入时它优先，保持既有 premium-gate 用例确定性。
    static let forceNonPremiumArgument = "-forceNonPremium"
    /// UI 测试启动时清掉本机持久解锁，避免手动解锁污染用例。
    static let resetDebugPremiumArgument = "-resetDebugPremium"
    static let debugPremiumUnlockedKey = "debug.premiumUnlocked"

    @Published private(set) var isDebugPremiumPersisted: Bool = false

    static var isEntitlementForcedPremium: Bool {
        isEntitlementForcedPremium(
            arguments: ProcessInfo.processInfo.arguments,
            defaults: .standard
        )
    }

    nonisolated static func isEntitlementForcedPremium(
        arguments: [String],
        defaults: UserDefaults
    ) -> Bool {
        guard !arguments.contains(forceNonPremiumArgument) else { return false }
        if arguments.contains(forcePremiumArgument) { return true }
        return defaults.bool(forKey: debugPremiumUnlockedKey)
    }

    /// `-resetDebugPremium` 先清持久位；随后若带 `-forcePremium`（且无 `-forceNonPremium`）再写入。
    nonisolated static func applyDebugPremiumLaunchOverrides(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) {
        if arguments.contains(resetDebugPremiumArgument) {
            defaults.set(false, forKey: debugPremiumUnlockedKey)
        }
        if arguments.contains(forcePremiumArgument),
           !arguments.contains(forceNonPremiumArgument) {
            defaults.set(true, forKey: debugPremiumUnlockedKey)
        }
    }

    func setDebugPremiumUnlocked(_ unlocked: Bool) {
        UserDefaults.standard.set(unlocked, forKey: Self.debugPremiumUnlockedKey)
        isDebugPremiumPersisted = unlocked
        if !allowsPremiumSession || ProcessInfo.processInfo.arguments.contains(Self.forceNonPremiumArgument) {
            isPremium = false
            return
        }
        if unlocked {
            isPremium = true
            return
        }
        Task { await checkEntitlements() }
    }
    #endif

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        guard allowsPremiumSession else {
            clearEntitlements()
            return
        }
        let revision = sessionRevision
        #if DEBUG
        if useDebugOverrides && ProcessInfo.processInfo.arguments.contains(Self.forceNonPremiumArgument) {
            clearEntitlements()
            return
        }
        if useDebugOverrides && Self.isEntitlementForcedPremium {
            isPremium = true
            return
        }
        #endif
        let snapshots = await entitlementLoader()
        // Logout, expiry or account switching invalidates any in-flight StoreKit result.
        guard revision == sessionRevision, allowsPremiumSession else { return }
        entitlementSnapshots = snapshots
        purchasedProductIDs = Set(snapshots.map(\.productID))
        isPremium = !snapshots.isEmpty
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard allowsPremiumSession else {
            errorMessage = "请先登录后再购买 Pro"
            return false
        }
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
        guard allowsPremiumSession else {
            errorMessage = "请先登录后再恢复购买"
            return false
        }
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
