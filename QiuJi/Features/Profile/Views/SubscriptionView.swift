import SwiftUI
import StoreKit

enum ProBenefits {
    struct Item: Identifiable {
        let id: String
        let number: String
        let title: String
        let subtitle: String
    }

    static let premium: [Item] = [
        .init(id: "drills", number: "01", title: "进阶动作与精讲", subtitle: "解锁 Pro 动作与配套精讲，理解练习要点与走位思路。"),
        .init(id: "plans", number: "02", title: "官方进阶计划", subtitle: "围绕准度、杆法与走位，按计划安排专项练习。"),
        .init(id: "aiming", number: "03", title: "专项练习不限题数", subtitle: "解锁3D训练与自由训练；角度、瞄准点、准度、分离角、两球及多球走位不限题数。"),
        .init(id: "atlases", number: "04", title: "分离角与加塞吃库图谱", subtitle: "对比不同打点下的球路变化，帮助理解母球路线。"),
        .init(id: "snake", number: "05", title: "每日清台与蛇彩练习", subtitle: "每日清台不限局数，蛇彩练习解锁连续击球与走位衔接。"),
        .init(id: "position", number: "06", title: "自由走位推演", subtitle: "调整球形与击球参数，观察、比较走位路线。"),
        .init(id: "three", number: "07", title: "打一走二想三", subtitle: "把当前进球与后续走位连起来，练习多杆规划。"),
        .init(id: "safety", number: "08", title: "防守推演", subtitle: "结合球形观察防守线路，练习进攻之外的选择。"),
        .init(id: "photo", number: "09", title: "拍照建球形", subtitle: "将球桌照片转成可继续编辑和推演的球形。"),
        .init(id: "history", number: "10", title: "训练统计与长期回顾", subtitle: "查看训练趋势，回看超过最近 60 天的训练记录详情。"),
        .init(id: "bank", number: "11", title: "翻袋解球", subtitle: "选择目标袋口，推演一至三库线路，练习翻袋与吃库判断。"),
        .init(id: "diamond", number: "12", title: "颗星公式解球", subtitle: "结合颗星刻度与公式，理解瞄准点和吃库线路的关系。")
    ]
}

/// Shared editorial presentation for the purchase and membership-status pages.
struct ProBenefitsSections: View {
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxl) {
            section(title: "Pro 专属权益", detail: isUnlocked ? "以下 \(ProBenefits.premium.count) 项进阶权益已解锁" : "解锁以下 \(ProBenefits.premium.count) 项进阶内容与工具",
                    items: ProBenefits.premium)
        }
    }

    private func section(title: String, detail: String, items: [ProBenefits.Item]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title).font(.btProSection).foregroundStyle(Color("introLabWhite"))
                    .accessibilityAddTraits(.isHeader)
                Text(detail).font(.btProBody).foregroundStyle(Color("introLabMuted"))
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: Spacing.lg) {
                    Text(item.number).font(.btProCaption).monospacedDigit()
                        .foregroundStyle(Color("introLabMuted"))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: Spacing.xxl, alignment: .leading)
                        .padding(.top, Spacing.xs)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(item.title).font(.btProHeadline)
                            .foregroundStyle(Color("introLabWhite"))
                        Text(item.subtitle).font(.btProBody)
                            .foregroundStyle(Color("introLabMuted"))
                            .lineSpacing(Spacing.xs)
                        Text(isUnlocked ? "PRO · 已解锁" : "PRO")
                            .font(.btProCaption)
                            .foregroundStyle(Color.btPremiumOnDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("subscription.feature.\(item.id)")
            }
        }
        .padding(.top, Spacing.xxl)
        .overlay(alignment: .top) {
            Rectangle().fill(Color("introLabWhite").opacity(0.12)).frame(height: 1)
        }
    }
}

struct ProBrandHero: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image("BrandLogoMark").resizable().scaledToFit()
                .frame(width: 88, height: 88).accessibilityHidden(true)
            VStack(spacing: Spacing.sm) {
                Text(title).font(.btProTitle).foregroundStyle(Color("introLabWhite"))
                    .accessibilityAddTraits(.isHeader)
                Text("让每一杆，都更有把握。")
                    .font(.btProHeadline).foregroundStyle(Color.btOverviewDays)
            }
            Text(detail).font(.btProBody).foregroundStyle(Color("introLabMuted"))
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }
}

struct ProBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BTProUnlockButtonStyle(font: .btProHeadline, minHeight: 56)
            .makeBody(configuration: configuration)
            // Subscription pages retain their always-dark brand background.
            .environment(\.colorScheme, .dark)
    }
}

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
    @State private var pendingLoginUser: AppUser?

    @State private var purchaseMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    heroSection
                    pricingSection
                    featuresList
                    legalSection
                    #if DEBUG && targetEnvironment(simulator)
                    simulatorUnlockSection
                    #endif
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("subscription.scroll")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            subscribeButton
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background(Color("introLabBackground"))
        }
        .background { IntroBackground() }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(Color.btOverviewDays)
        .task {
            await subscriptionManager.loadProducts()
            selectAvailableProduct()
        }
        .onChange(of: subscriptionManager.products.map(\.id)) { _, _ in
            selectAvailableProduct()
        }
        .sheet(isPresented: $showLogin, onDismiss: {
            if let user = pendingLoginUser {
                pendingLoginUser = nil
                authState.login(user: user)
            }
        }) {
            LoginView(onAuthenticated: { pendingLoginUser = $0 })
        }
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("确定") {}
        } message: {
            Text(restoreMessage)
        }
        .alert("购买状态", isPresented: $showPurchaseErrorAlert) {
            Button("确定") {}
        } message: {
            Text(purchaseMessage)
        }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.btProHeadline)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("关闭")
            .accessibilityIdentifier("subscription.close")
            Spacer(minLength: Spacing.sm)
            Button("恢复购买") {
                if authState.hasLocalAccount { Task { await handleRestore() } }
                else { showLogin = true }
            }
            .font(.btProCaption)
            .foregroundStyle(Color.btOverviewDays)
            .frame(minHeight: 44)
            .disabled(subscriptionManager.isLoading)
            .accessibilityIdentifier("subscription.restore")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: 600)
    }

    private var heroSection: some View {
        ProBrandHero(title: "解锁球迹 Pro", detail: "从看懂球路，到有方向地练习。\n进阶内容与工具，陪你把思路练成手感。")
    }

    private var featuresList: some View {
        ProBenefitsSections(isUnlocked: subscriptionManager.isPremium)
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("选择 Pro 方案")
                .font(.btProBody)
                .foregroundStyle(.btTextSecondary)
            if subscriptionManager.products.isEmpty {
                VStack(spacing: Spacing.sm) {
                    if subscriptionManager.isLoading {
                        ProgressView("正在加载订阅方案…")
                            .tint(.btPrimary)
                    } else {
                        Text(productLoadingMessage)
                            .font(.btProCaption)
                            .foregroundStyle(.btTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("重新加载") {
                            Task { await reloadProducts() }
                        }
                        .font(.btProBody)
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
            if !authState.hasLocalAccount {
                Text("购买或恢复前需登录，已选方案会保留。")
                    .font(.btProCaption)
                    .foregroundStyle(.btTextSecondary)
            }
        }
    }

    private func pricingCard(_ product: Product, title: String, period: String) -> some View {
        let isSelected = selectedProductID == product.id
        return Button { selectedProductID = product.id } label: {
            VStack(spacing: Spacing.sm) {
                Text(title).font(.btProBody)
                Text(product.displayPrice).font(.btProHeadline)
                Text(period).font(.btProCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .foregroundStyle(.btText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.xs)
            .background(isSelected ? Color.btOverviewDays.opacity(0.16) : Color("introLabWhite").opacity(0.04),
                        in: RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(isSelected ? Color.btOverviewDays : Color("introLabWhite").opacity(0.18), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("subscription.product.\(product.id)")
    }

    @ViewBuilder
    private var subscribeButton: some View {
        if subscriptionManager.isLoading || (selectedProductID.map { !subscriptionManager.canPurchase(productID: $0) } ?? false) {
            Button {} label: {
                subscribeButtonLabel
                    .font(.btProHeadline)
                    .foregroundStyle(.btTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.btBGQuaternary, in: RoundedRectangle(cornerRadius: BTRadius.sm))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityIdentifier("subscription.purchase")
        } else {
            Button {
                if selectedProduct == nil { Task { await reloadProducts() } }
                else if authState.hasLocalAccount { Task { await handlePurchase() } }
                else { showLogin = true }
            } label: {
                subscribeButtonLabel.frame(maxWidth: .infinity)
            }
            .buttonStyle(ProBrandButtonStyle())
            .accessibilityIdentifier("subscription.purchase")
        }
    }

    private var subscribeButtonLabel: some View {
        HStack {
            if subscriptionManager.isLoading && !subscriptionManager.isPremium {
                ProgressView().tint(.btTextSecondary)
            }
            if selectedProduct != nil && !subscriptionManager.isLoading {
                BTProfileCrown(width: 32)
            }
            Text(subscribeButtonText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedProduct: Product? {
        subscriptionManager.products.first(where: { $0.id == selectedProductID })
    }

    private var subscribeButtonText: String {
        if subscriptionManager.awaitingProductID != nil { return "等待 Apple 确认，可恢复购买刷新" }
        if let id = selectedProductID, subscriptionManager.isPremium, !subscriptionManager.canPurchase(productID: id) { return "已拥有 Pro 权益" }
        if subscriptionManager.isLoading {
            return selectedProduct == nil ? "正在加载订阅方案…" : "正在处理…"
        }
        guard let product = selectedProduct else {
            return "重新加载订阅方案"
        }
        let period = product.id == StoreKitService.lifetimeID ? "一次性"
            : product.id == StoreKitService.yearlyID ? "每年" : "每月"
        return "解锁 Pro · \(product.displayPrice) / \(period)"
    }

    private var productLoadingMessage: String {
        let message = subscriptionManager.errorMessage ?? "暂时无法加载订阅方案"
        #if DEBUG && targetEnvironment(simulator)
        if message == "模拟器未注入商店配置，无法购买。请点下方「模拟器解锁 Pro」。" {
            return "模拟器未注入商店配置，当前无法购买。请配置商店后重新加载订阅方案。"
        }
        #endif
        return message
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(selectedProductID == StoreKitService.lifetimeID
                 ? "终身方案为一次性购买。已有月度或年度订阅不会自动取消，请在系统订阅设置中管理。确认后将通过 Apple 账户付款。"
                 : "月度与年度方案自动续订。确认后将通过 Apple 账户付款，可在系统订阅设置中管理或取消。")
                .font(.btProCaption)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if subscriptionManager.awaitingProductID != nil {
                Text("等待 Apple 确认期间无需重复购买，可通过恢复购买刷新权益。")
                    .font(.btProCaption).foregroundStyle(.btTextSecondary)
                if subscriptionManager.purchaseOutcome == .pending {
                    Button("购买已取消或被拒绝，重新选择") {
                        subscriptionManager.resetWaitingPurchaseAfterCancellation()
                    }.font(.btProCaption)
                }
            }
            Text("Pro 权益以当前 Apple 购买为依据；球迹账号分别保存各自的训练数据。")
                .font(.btProCaption).foregroundStyle(.btTextSecondary)
            HStack(spacing: Spacing.lg) {
                if let termsURL = AppConfig.termsURL, let privacyURL = AppConfig.privacyURL {
                    Link("服务条款", destination: termsURL)
                    Link("隐私政策", destination: privacyURL)
                } else {
                    Text("法律文件链接待发布")
                        .foregroundStyle(.btTextSecondary)
                }
            }
            .font(.btProCaption)
            .tint(.btPrimary)
            .frame(minHeight: 44)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    @ViewBuilder
    private var simulatorUnlockSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if ProcessInfo.processInfo.arguments.contains(SubscriptionManager.forceNonPremiumArgument) {
                Text("当前为强制免费评审，无法在此解锁 Pro。")
            } else if ProcessInfo.processInfo.arguments.contains(SubscriptionManager.forcePremiumArgument) {
                Text("当前为强制 Pro 评审，无法在此切换会员状态。")
            } else if !authState.hasLocalAccount {
                Text("模拟器解锁 Pro 需先登录。")
                Button("登录") { showLogin = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("subscription.simulatorLogin")
            } else if subscriptionManager.isPremium &&
                        (!subscriptionManager.isDebugPremiumPersisted || !subscriptionManager.purchasedProductIDs.isEmpty) {
                Text("当前已是 Pro 会员，无需模拟器解锁。")
            } else {
                Button(subscriptionManager.isPremium ? "关闭模拟器 Pro" : "模拟器解锁 Pro") {
                    subscriptionManager.setDebugPremiumUnlocked(!subscriptionManager.isPremium)
                    dismiss()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier(subscriptionManager.isPremium
                                         ? "simulatorLockProButton" : "simulatorUnlockProButton")
            }
        }
        .font(.btProCaption)
        .foregroundStyle(.btTextSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    #endif

    private func reloadProducts() async {
        await subscriptionManager.retryLoadProducts()
        selectAvailableProduct()
    }

    private func selectAvailableProduct() {
        guard !subscriptionManager.products.contains(where: { $0.id == selectedProductID }) else { return }
        selectedProductID = (subscriptionManager.isPremium ? subscriptionManager.lifetimeProduct?.id : nil)
            ?? subscriptionManager.yearlyProduct?.id
            ?? subscriptionManager.monthlyProduct?.id ?? subscriptionManager.lifetimeProduct?.id
    }

    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        switch await subscriptionManager.purchaseResult(product) {
        case .unlocked: dismiss(); return
        case .cancelled, .busy: return
        case .pending: purchaseMessage = "购买待批准。批准后会自动刷新权益，无需重复购买。"
        case .confirming: purchaseMessage = "购买已完成，权益正在确认。请稍后刷新或恢复购买，无需重复付款。"
        case .sessionChanged: purchaseMessage = "球迹账号已切换，请在当前账号刷新权益或恢复购买。"
        case .failed: purchaseMessage = subscriptionManager.errorMessage ?? "购买未完成，请稍后重试"
        }
        showPurchaseErrorAlert = true
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
