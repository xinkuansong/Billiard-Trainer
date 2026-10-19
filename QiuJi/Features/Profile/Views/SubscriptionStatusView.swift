import SwiftUI

private struct ProBrandSurfaceVisibilityKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var proBrandSurfaceVisibility: (Bool) -> Void {
        get { self[ProBrandSurfaceVisibilityKey.self] }
        set { self[ProBrandSurfaceVisibilityKey.self] = newValue }
    }
}

/// Reports navigation appearance before animation, including cancelled edge swipes.
private struct ProBrandAppearanceLifecycle: UIViewControllerRepresentable {
    var onVisibilityChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.onVisibilityChange = onVisibilityChange
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onVisibilityChange = onVisibilityChange
    }

    final class Controller: UIViewController {
        var onVisibilityChange: (Bool) -> Void = { _ in }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            onVisibilityChange(true)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onVisibilityChange(false)
            transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
                if context.isCancelled { self?.onVisibilityChange(true) }
            }
        }
    }
}

struct SubscriptionStatusView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.proBrandSurfaceVisibility) private var setBrandSurfaceVisible
    @State private var showRestoreAlert = false
    @State private var showUpgrade = false
    @State private var restoreMessage = ""

    var body: some View {
        ZStack {
            IntroBackground()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    statusCard
                    actionsSection
                    featuresSection
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("subscription.statusScroll")
        }
        .environment(\.colorScheme, .dark)
        // RootView owns the temporary host appearance. A second preference here
        // would keep a system-following host dark until the pop finishes.
        .tint(Color.btOverviewDays)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color("introLabBackground"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(subscriptionManager.purchasedProductIDs.contains(StoreKitService.lifetimeID) ? "Pro 权益" : "订阅管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background {
            ProBrandAppearanceLifecycle(onVisibilityChange: setBrandSurfaceVisible)
                .frame(width: 0, height: 0)
        }
        .sheet(isPresented: $showUpgrade) { SubscriptionView() }
        .task { await subscriptionManager.checkEntitlements(coalescing: true) }
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("确定") {}
        } message: {
            Text(restoreMessage)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: Spacing.sm) {
            ProBrandHero(title: subscriptionManager.isPremium ? "已解锁 Pro" : "Pro 未解锁",
                         detail: "有方向地练习，有依据地回看。")
            VStack(spacing: Spacing.sm) {
                Text(subscriptionTypeLabel).font(.btProHeadline)
                    .foregroundStyle(Color.btPremiumOnDark)
                Text(expiryLabel).font(.btProBody)
                    .foregroundStyle(Color("introLabMuted"))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            Group {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                            .font(.btProBody)
                        Text("管理订阅")
                            .font(.btProBody.weight(.medium))
                    }
                    .foregroundStyle(Color.btOverviewDays)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.btOverviewDays.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                }
                .buttonStyle(.plain)
            }

            if subscriptionManager.isPremium && !subscriptionManager.purchasedProductIDs.contains(StoreKitService.lifetimeID) {
                Button { showUpgrade = true } label: {
                    HStack(spacing: Spacing.sm) {
                        BTProfileCrown(width: 32)
                        Text("升级终身 Pro")
                    }
                }
                    .buttonStyle(ProBrandButtonStyle())
                    .accessibilityIdentifier("subscription.upgradeLifetime")
            }
            Button {
                Task { await handleRestore() }
            } label: {
                Group {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .tint(.btTextSecondary)
                    } else {
                        Text("恢复购买")
                            .font(.btProBody)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isLoading)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        ProBenefitsSections(isUnlocked: subscriptionManager.isPremium)
    }

    // MARK: - Computed

    private var subscriptionTypeLabel: String {
        let ids = subscriptionManager.purchasedProductIDs
        if ids.contains(StoreKitService.lifetimeID) { return "终身买断" }
        if ids.contains(StoreKitService.yearlyID)   { return "年度订阅" }
        if ids.contains(StoreKitService.monthlyID)   { return "月度订阅" }
        return "Pro 会员"
    }

    private var expiryLabel: String {
        let ids = subscriptionManager.purchasedProductIDs
        if ids.contains(StoreKitService.lifetimeID) { return "永久有效" }
        return subscriptionManager.entitlementStatusLabel
    }

    // MARK: - Actions

    private func handleRestore() async {
        let success = await subscriptionManager.restorePurchases()
        if success {
            restoreMessage = "已恢复购买，Pro 功能已解锁"
        } else {
            restoreMessage = subscriptionManager.errorMessage ?? "未找到可恢复的购买记录"
        }
        showRestoreAlert = true
    }
}

#Preview("Subscription Status") {
    NavigationStack {
        SubscriptionStatusView()
            .environmentObject(SubscriptionManager.shared)
    }
}

#Preview("Subscription Status Dark") {
    NavigationStack {
        SubscriptionStatusView()
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}
