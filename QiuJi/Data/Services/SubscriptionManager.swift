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
    @Published private(set) var isRefreshingEntitlements = false
    @Published private(set) var hasResolvedEntitlements = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isTransacting = false
    var isLoading: Bool { isLoadingProducts || isTransacting }
    enum PurchaseOutcome: Equatable { case unlocked, cancelled, pending, confirming, sessionChanged, failed, busy }
    @Published private(set) var purchaseOutcome: PurchaseOutcome?
    @Published private(set) var awaitingProductID: String?
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
            if expiration < Date(), isPremium { return "订阅有效，续订状态待确认" }
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
    var accessSessionRevision: Int { sessionRevision }
    private var entitlementRequestRevision = 0
    private var entitlementRefresh: (revision: Int, task: Task<[StoreEntitlementSnapshot], Never>)?
    private var hasAuthenticatedSession = false
    private let entitlementLoader: () async -> [StoreEntitlementSnapshot]
    private let useDebugOverrides: Bool
    private let purchaseOperation: (Product) async throws -> Void

    init(
        entitlementLoader: @escaping () async -> [StoreEntitlementSnapshot] = {
            await StoreKitService.shared.currentEntitlements()
        },
        listenForUpdates: Bool = true,
        useDebugOverrides: Bool = true,
        purchaseOperation: @escaping (Product) async throws -> Void = { product in
            _ = try await StoreKitService.shared.purchase(product)
        }
    ) {
        self.entitlementLoader = entitlementLoader
        self.useDebugOverrides = useDebugOverrides
        self.purchaseOperation = purchaseOperation
        #if DEBUG
        if useDebugOverrides { Self.applyDebugPremiumLaunchOverrides() }
        isDebugPremiumPersisted = UserDefaults.standard.bool(forKey: Self.debugPremiumUnlockedKey)
        if allowsPremiumSession && useDebugOverrides && Self.isEntitlementForcedPremium {
            isPremium = true
            hasResolvedEntitlements = true
        }
        #endif
        if listenForUpdates { transactionListener = listenForTransactions() }
    }

    deinit {
        transactionListener?.cancel()
        entitlementRefresh?.task.cancel()
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
        switch phase {
        case .authenticated(let user), .offlineAccount(let user): userID = user.id
        default: userID = nil
        }
        guard userID != authenticatedUserID else { return }
        authenticatedUserID = userID
        if userID != nil { hasAuthenticatedSession = true }
        sessionRevision += 1
        clearEntitlements()
        if userID != nil { Task { await checkEntitlements(coalescing: true) } }
    }

    private func clearEntitlements() {
        invalidateEntitlementRefresh()
        isPremium = false
        purchasedProductIDs = []
        entitlementSnapshots = []
        hasResolvedEntitlements = false
        errorMessage = nil
    }

    private func invalidateEntitlementRefresh() {
        entitlementRequestRevision += 1
        entitlementRefresh?.task.cancel()
        entitlementRefresh = nil
        isRefreshingEntitlements = false
    }

    func accessDecision(requiresPremium: Bool) -> ProAccessPolicy.Decision {
        ProAccessPolicy.decision(requiresPremium: requiresPremium,
                                 hasSession: allowsPremiumSession,
                                 isPremium: isPremium,
                                 hasResolvedEntitlements: hasResolvedEntitlements)
    }

    // MARK: - Load Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

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
                errorMessage = "暂时无法获取购买方案，请检查网络后重试"
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
        invalidateEntitlementRefresh()
        UserDefaults.standard.set(unlocked, forKey: Self.debugPremiumUnlockedKey)
        isDebugPremiumPersisted = unlocked
        if !allowsPremiumSession || ProcessInfo.processInfo.arguments.contains(Self.forceNonPremiumArgument) {
            isPremium = false
            return
        }
        if unlocked {
            isPremium = true
            hasResolvedEntitlements = true
            return
        }
        Task { await checkEntitlements() }
    }
    #endif

    // MARK: - Check Entitlements

    /// Lifecycle reads can share a pending query. Purchases, restores and transaction
    /// updates must start a new query, because they carry newer entitlement information.
    func checkEntitlements(coalescing: Bool = false) async {
        guard allowsPremiumSession else {
            clearEntitlements()
            return
        }
        let revision = sessionRevision
        #if DEBUG
        if useDebugOverrides && ProcessInfo.processInfo.arguments.contains(Self.forceNonPremiumArgument) {
            clearEntitlements()
            hasResolvedEntitlements = true
            return
        }
        if useDebugOverrides && Self.isEntitlementForcedPremium {
            invalidateEntitlementRefresh()
            isPremium = true
            hasResolvedEntitlements = true
            return
        }
        #endif
        let refresh: (revision: Int, task: Task<[StoreEntitlementSnapshot], Never>)
        if coalescing, let pending = entitlementRefresh {
            refresh = pending
        } else {
            entitlementRequestRevision += 1
            entitlementRefresh?.task.cancel()
            let loader = entitlementLoader
            refresh = (entitlementRequestRevision, Task { await loader() })
            entitlementRefresh = refresh
            isRefreshingEntitlements = true
        }
        let loaded = await refresh.task.value
        // Cancellation is cooperative; a superseded loader may still return a result.
        guard revision == sessionRevision, allowsPremiumSession,
              refresh.revision == entitlementRequestRevision else { return }
        let snapshots = ProAccessPolicy.currentProEntitlements(in: loaded)
        entitlementSnapshots = snapshots
        purchasedProductIDs = Set(snapshots.map(\.productID))
        isPremium = !snapshots.isEmpty
        hasResolvedEntitlements = true
        if let id = awaitingProductID, purchasedProductIDs.contains(id) {
            awaitingProductID = nil
            purchaseOutcome = .unlocked
        }
        entitlementRefresh = nil
        isRefreshingEntitlements = false
    }

    // MARK: - Purchase

    func canPurchase(productID: String) -> Bool {
        guard StoreKitService.allProductIDs.contains(productID), awaitingProductID == nil, !isTransacting else { return false }
        return !isPremium || (productID == StoreKitService.lifetimeID &&
            !purchasedProductIDs.contains(StoreKitService.lifetimeID))
    }

    /// Only an Ask to Buy request may be acknowledged as declined/cancelled.
    /// A completed purchase awaiting entitlement refresh must never invite another payment.
    func resetWaitingPurchaseAfterCancellation() {
        guard !isTransacting, purchaseOutcome == .pending else { return }
        awaitingProductID = nil
        purchaseOutcome = nil
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        await purchaseResult(product) == .unlocked
    }

    func purchaseResult(_ product: Product) async -> PurchaseOutcome {
        guard !isTransacting else { return .busy }
        guard allowsPremiumSession else {
            errorMessage = "请先登录后再购买 Pro"
            return .failed
        }
        guard canPurchase(productID: product.id) else {
            errorMessage = "已有此权益，可在系统订阅设置中管理订阅"
            return .failed
        }
        let revision = sessionRevision
        isTransacting = true
        errorMessage = nil
        defer { isTransacting = false }
        let result: PurchaseOutcome
        do {
            try await purchaseOperation(product)
            guard revision == sessionRevision else { return .sessionChanged }
            await checkEntitlements()
            guard revision == sessionRevision else { return .sessionChanged }
            result = purchasedProductIDs.contains(product.id) ? .unlocked : .confirming
        } catch is CancellationError {
            result = .cancelled
        } catch StoreError.purchasePending {
            result = .pending
        } catch {
            guard revision == sessionRevision else { return .sessionChanged }
            errorMessage = error.localizedDescription
            result = .failed
        }
        guard revision == sessionRevision else { return .sessionChanged }
        purchaseOutcome = result
        if result == .pending || result == .confirming { awaitingProductID = product.id }
        return result
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        guard !isTransacting else { return false }
        guard allowsPremiumSession else {
            errorMessage = "请先登录后再恢复购买"
            return false
        }
        let revision = sessionRevision
        isTransacting = true
        errorMessage = nil
        defer { isTransacting = false }
        do {
            try await service.restorePurchases()
            guard revision == sessionRevision else { return false }
            await checkEntitlements()
            guard revision == sessionRevision else { return false }
            if isPremium { return true }
            errorMessage = "未找到可恢复的购买记录"
        } catch is CancellationError {
            return false
        } catch {
            guard revision == sessionRevision else { return false }
            errorMessage = "恢复购买失败，请稍后重试"
        }
        return false
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
