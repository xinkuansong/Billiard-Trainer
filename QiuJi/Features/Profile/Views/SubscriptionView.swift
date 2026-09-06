import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var authState: AuthState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProductID: String?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showPurchaseErrorAlert = false
    @State private var showLogin = false

    private let benefits: [(icon: String, title: String, subtitle: String)] = [
        ("books.vertical", "完整动作与进阶计划", "解锁 Pro 动作、精讲与官方进阶计划"),
        ("scope", "3D 判断训练", "练习角度与瞄准点，相关判断训练不限次数"),
        ("point.3.connected.trianglepath.dotted", "进阶球路图谱", "分离角与加塞吃库，比较不同打点的路线"),
        ("point.topleft.down.to.point.bottomright.curvepath", "进阶推演工具", "自由走位、多杆规划、防守与拍照建球形"),
        ("chart.bar", "统计与长期回顾", "查看训练趋势与更长时间的历史记录")
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    heroSection
                    featuresList
                    pricingSection
                    legalSection
                    #if DEBUG && targetEnvironment(simulator)
                    simulatorUnlockSection
                    #endif
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("subscription.scroll")
        }
        .background { BTBlueprintBackground(style: .profile).ignoresSafeArea() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            subscribeButton
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background(Color.btBG)
        }
        .task {
            await subscriptionManager.loadProducts()
            selectAvailableProduct()
        }
        .onChange(of: subscriptionManager.products.map(\.id)) { _, _ in
            selectAvailableProduct()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("确定") {}
        } message: {
            Text(restoreMessage)
        }
        .alert("购买失败", isPresented: $showPurchaseErrorAlert) {
            Button("确定") {}
        } message: {
            Text(subscriptionManager.errorMessage ?? "购买未完成，请稍后重试")
        }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.btBodyMedium)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.btBGSecondary, in: Circle())
            }
            .accessibilityLabel("关闭")
            .accessibilityIdentifier("subscription.close")
            Text("球迹 Pro")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            Spacer(minLength: Spacing.sm)
            Button("恢复购买") {
                if authState.isLoggedIn { Task { await handleRestore() } }
                else { showLogin = true }
            }
            .font(.btFootnote)
            .foregroundStyle(.btPrimary)
            .frame(minHeight: 44)
            .disabled(subscriptionManager.isLoading)
            .accessibilityIdentifier("subscription.restore")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: 600)
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("解锁球迹 Pro")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                    .accessibilityAddTraits(.isHeader)
                Text("进阶内容与工具，支持你的每次练习")
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            BTPremiumMaterialSymbol(systemName: "star.fill", size: 32)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var featuresList: some View {
        VStack(spacing: 0) {
            ForEach(benefits.indices, id: \.self) { index in
                let benefit = benefits[index]
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: benefit.icon)
                        .font(.btHeadline)
                        .foregroundStyle(.btTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.btBGTertiary.opacity(0.5), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(benefit.title)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)
                        Text(benefit.subtitle)
                            .font(.btFootnote)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("subscription.benefit.\(index)")
                if index < benefits.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("选择方案")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            if subscriptionManager.products.isEmpty {
                VStack(spacing: Spacing.sm) {
                    if subscriptionManager.isLoading {
                        ProgressView("正在加载订阅方案…")
                            .tint(.btPrimary)
                    } else {
                        Text(subscriptionManager.errorMessage ?? "暂时无法加载订阅方案")
                            .font(.btFootnote)
                            .foregroundStyle(.btTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("重新加载") {
                            Task {
                                await subscriptionManager.retryLoadProducts()
                                selectAvailableProduct()
                            }
                        }
                        .font(.btSubheadline)
                        .foregroundStyle(.btPrimary)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("subscription.retry")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            } else {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: Spacing.sm))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.sm))
                layout {
                    if let product = subscriptionManager.monthlyProduct {
                        pricingCard(product, title: "月度", period: "每月续订")
                    }
                    if let product = subscriptionManager.yearlyProduct {
                        pricingCard(product, title: "年度", period: "每年续订")
                    }
                    if let product = subscriptionManager.lifetimeProduct {
                        pricingCard(product, title: "终身", period: "一次性购买")
                    }
                }
            }
            if !authState.isLoggedIn {
                Text("购买或恢复前需登录，已选方案会保留。")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
        }
    }

    private func pricingCard(_ product: Product, title: String, period: String) -> some View {
        let isSelected = selectedProductID == product.id
        return Button { selectedProductID = product.id } label: {
            VStack(spacing: Spacing.sm) {
                Text(title).font(.btSubheadlineMedium)
                Text(product.displayPrice).font(.btHeadline)
                Text(period).font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .foregroundStyle(.btText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.xs)
            .background(isSelected ? Color.btPrimaryMuted : Color.btBGSecondary,
                        in: RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(isSelected ? Color.btPrimary : Color.btSeparator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("subscription.product.\(product.id)")
    }

    private var subscribeButton: some View {
        Button {
            if authState.isLoggedIn { Task { await handlePurchase() } }
            else { showLogin = true }
        } label: {
            HStack {
                if subscriptionManager.isLoading { ProgressView().tint(.white) }
                Text(subscriptionManager.isPremium ? "已是 Pro 会员" : subscribeButtonText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BTButtonStyle.primary)
        .disabled(selectedProductID == nil || subscriptionManager.isLoading || subscriptionManager.isPremium)
        .accessibilityIdentifier("subscription.purchase")
    }

    private var subscribeButtonText: String {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else {
            return "解锁 Pro"
        }
        let period = product.id == StoreKitService.lifetimeID ? "一次性"
            : product.id == StoreKitService.yearlyID ? "每年" : "每月"
        return "解锁 Pro · \(product.displayPrice) / \(period)"
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(selectedProductID == StoreKitService.lifetimeID
                 ? "终身方案为一次性购买，不会自动续订。确认后将通过 Apple 账户付款。"
                 : "月度与年度方案自动续订。确认后将通过 Apple 账户付款，可在系统订阅设置中管理或取消。")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.lg) {
                if let termsURL = AppConfig.termsURL, let privacyURL = AppConfig.privacyURL {
                    Link("服务条款", destination: termsURL)
                    Link("隐私政策", destination: privacyURL)
                } else {
                    Text("法律文件链接待发布")
                        .foregroundStyle(.btTextSecondary)
                }
            }
            .font(.btFootnote)
            .tint(.btPrimary)
            .frame(minHeight: 44)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    private var simulatorUnlockSection: some View {
        Button(subscriptionManager.isDebugPremiumPersisted ? "关闭模拟器 Pro" : "模拟器解锁 Pro") {
            subscriptionManager.setDebugPremiumUnlocked(!subscriptionManager.isDebugPremiumPersisted)
            dismiss()
        }
        .font(.btFootnote)
        .foregroundStyle(.btTextSecondary)
        .frame(minHeight: 44)
        .accessibilityIdentifier(subscriptionManager.isDebugPremiumPersisted
                                 ? "simulatorLockProButton" : "simulatorUnlockProButton")
    }
    #endif

    private func selectAvailableProduct() {
        guard !subscriptionManager.products.contains(where: { $0.id == selectedProductID }) else { return }
        selectedProductID = subscriptionManager.yearlyProduct?.id
            ?? subscriptionManager.monthlyProduct?.id ?? subscriptionManager.lifetimeProduct?.id
    }

    private func handlePurchase() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedProductID }) else { return }
        if await subscriptionManager.purchase(product) { dismiss() }
        else if subscriptionManager.errorMessage != nil { showPurchaseErrorAlert = true }
    }

    private func handleRestore() async {
        let success = await subscriptionManager.restorePurchases()
        restoreMessage = success ? "已恢复购买，Pro 功能已解锁"
            : subscriptionManager.errorMessage ?? "未找到可恢复的购买记录"
        showRestoreAlert = true
    }
}

#Preview("Light") {
    SubscriptionView().environmentObject(SubscriptionManager.shared).environmentObject(AuthState())
}
#Preview("Dark") {
    SubscriptionView().environmentObject(SubscriptionManager.shared).environmentObject(AuthState())
        .preferredColorScheme(.dark)
}
