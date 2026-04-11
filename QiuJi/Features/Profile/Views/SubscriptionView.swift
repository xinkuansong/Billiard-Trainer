import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    // Paywall uses a near-black background distinct from btBG to create a premium feel
    private static let bgPaywall = Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x11 / 255.0)
    private let bgColor = Self.bgPaywall
    private let goldColor = Color.btAccent

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Spacing.lg)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, Spacing.xxl)

                        featuresList
                            .padding(.bottom, Spacing.xxl)
                    }
                    .padding(.horizontal, Spacing.xxl)
                }

                bottomSection
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xxl)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await subscriptionManager.loadProducts()
            if selectedProductID == nil {
                selectedProductID = subscriptionManager.yearlyProduct?.id
            }
        }
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("好的") {}
        } message: {
            Text(restoreMessage)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.btBodyMedium)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
        }
        .frame(height: 48)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.btPrimary.opacity(0.4), Color.btBGTertiary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle().stroke(Color.btPrimary.opacity(0.2), lineWidth: 2)
                    )

                Image(systemName: "target")
                    .font(.btStatNumber)
                    .foregroundStyle(Color.btPrimary)
            }

            VStack(spacing: Spacing.xs) {
                (Text("解锁球迹 ").foregroundColor(.white) +
                 Text("Pro").foregroundColor(goldColor))
                    .font(.btTitle)

                Text("专为台球爱好者设计的专业训练系统")
                    .font(.btCaption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Features

    private var featuresList: some View {
        VStack(spacing: Spacing.md) {
            featureRow(number: 1, title: "完整动作库", subtitle: "解锁全部 72 个训练动作")
            featureRow(number: 2, title: "统计与趋势图表", subtitle: "可视化你的训练进度")
            featureRow(number: 3, title: "自定义训练计划", subtitle: "打造你的专属训练方案")
            featureRow(number: 4, title: "无限角度测试", subtitle: "不限次数提升角度感知")
            featureRow(number: 5, title: "训练分享卡全样式", subtitle: "所有配色主题与分享模版")
            featureRow(number: 6, title: "云端同步", subtitle: "多设备数据无缝同步")
        }
    }

    private func featureRow(number: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .stroke(goldColor.opacity(0.5), lineWidth: 1)
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.btMicro).fontWeight(.bold)
                    .foregroundStyle(goldColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.btFootnote).fontWeight(.medium)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.btCaption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    // MARK: - Bottom Section (fixed)

    private var bottomSection: some View {
        VStack(spacing: Spacing.lg) {
            pricingGrid
            subscribeButton
            legalSection
        }
    }

    // MARK: - Pricing Grid

    private var pricingGrid: some View {
        HStack(spacing: Spacing.sm) {
            if let monthly = subscriptionManager.monthlyProduct {
                pricingCard(
                    product: monthly,
                    label: "月订阅",
                    period: "/月",
                    borderColor: .white.opacity(0.1),
                    isRecommended: false
                )
            }

            if let yearly = subscriptionManager.yearlyProduct {
                pricingCard(
                    product: yearly,
                    label: "年订阅",
                    period: monthlyEquivalent(yearly),
                    borderColor: Color.btPrimary,
                    isRecommended: true
                )
            }

            if let lifetime = subscriptionManager.lifetimeProduct {
                pricingCard(
                    product: lifetime,
                    label: "终身买断",
                    period: "一次性",
                    borderColor: goldColor.opacity(0.4),
                    isRecommended: false
                )
            }

            if subscriptionManager.products.isEmpty {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                } else {
                    VStack(spacing: Spacing.sm) {
                        Text(subscriptionManager.errorMessage ?? "无法加载订阅方案")
                            .font(.btCaption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Button {
                            Task { await subscriptionManager.retryLoadProducts() }
                        } label: {
                            Label("重试", systemImage: "arrow.clockwise")
                                .font(.btCaption2)
                                .foregroundStyle(goldColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                }
            }
        }
    }

    private func pricingCard(
        product: Product,
        label: String,
        period: String,
        borderColor: Color,
        isRecommended: Bool
    ) -> some View {
        let isSelected = selectedProductID == product.id
        let activeBorder = isRecommended ? Color.btPrimary : borderColor

        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedProductID = product.id
            }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(label)
                    .font(.btMicro)
                    .foregroundStyle(isRecommended ? .white.opacity(0.8) : .white.opacity(0.5))

                Text(product.displayPrice)
                    .font(.btCallout).fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(period)
                    .font(.btMicro)
                    .foregroundStyle(isRecommended ? Color.btPrimary : periodColor(product))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(glassBackground(isSelected: isSelected, isRecommended: isRecommended))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .stroke(isSelected ? activeBorder : borderColor,
                            lineWidth: isRecommended ? 2 : 1)
            )
            .overlay(alignment: .top) {
                if isRecommended {
                    Text("推荐")
                        .font(.btMicro).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.btPrimary)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isRecommended && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.btCaption)
                        .foregroundStyle(Color.btPrimary)
                        .padding(Spacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func glassBackground(isSelected: Bool, isRecommended: Bool) -> some ShapeStyle {
        if isRecommended && isSelected {
            return Color.btPrimary.opacity(0.1)
        }
        return Color.white.opacity(0.04)
    }

    private func monthlyEquivalent(_ yearly: Product) -> String {
        let monthlyPrice = NSDecimalNumber(decimal: yearly.price)
            .dividing(by: 12)
            .doubleValue
        return String(format: "月均¥%.1f", monthlyPrice)
    }

    private func periodColor(_ product: Product) -> Color {
        if product.id == StoreKitService.lifetimeID {
            return goldColor
        }
        return .white.opacity(0.3)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            Group {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if subscriptionManager.isPremium {
                    Label("已是 Pro 会员", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.white)
                } else {
                    Text(subscribeButtonText)
                        .foregroundStyle(.white)
                }
            }
            .font(.btCallout).fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(subscriptionManager.isPremium ? Color.btBGTertiary : Color.btPrimary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .disabled(selectedProductID == nil || subscriptionManager.isLoading || subscriptionManager.isPremium)
    }

    private var subscribeButtonText: String {
        guard let id = selectedProductID,
              let product = subscriptionManager.products.first(where: { $0.id == id }) else {
            return "立即订阅"
        }
        if product.id == StoreKitService.lifetimeID {
            return "立即购买 — 终身 \(product.displayPrice)"
        }
        let label = product.id == StoreKitService.yearlyID ? "年订阅" : "月订阅"
        return "立即订阅 — \(label) \(product.displayPrice)"
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: Spacing.sm) {
            Text("确认购买后将向您的 iTunes 账户扣款。订阅将自动续期，除非在当前期限结束前至少 24 小时关闭。")
                .font(.btMicro)
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            HStack(spacing: Spacing.lg) {
                Button { Task { await handleRestore() } } label: {
                    Text("恢复购买")
                        .font(.btMicro)
                        .foregroundStyle(.white.opacity(0.2))
                }
                .disabled(subscriptionManager.isLoading)

                Link("服务条款", destination: URL(string: "https://example.com/terms")!)
                    .font(.btMicro)
                    .foregroundStyle(.white.opacity(0.2))

                Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    .font(.btMicro)
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    // MARK: - Actions

    private func handlePurchase() async {
        guard let id = selectedProductID,
              let product = subscriptionManager.products.first(where: { $0.id == id }) else { return }
        let success = await subscriptionManager.purchase(product)
        if success { dismiss() }
    }

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

// MARK: - Preview

#Preview("Default") {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    SubscriptionView()
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
