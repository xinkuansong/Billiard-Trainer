import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        heroSection
                        benefitsList
                        planCards
                        purchaseButton
                        restoreButton
                        legalLinks
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xxxxl)
                }
            }
            .navigationTitle("球迹 Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.btTextSecondary)
                }
            }
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
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.btAccent, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, Spacing.xl)

            Text("解锁全部功能")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)

            Text("系统训练，持续进步")
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            benefitRow(icon: "list.bullet.rectangle", text: "全部 72 项训练动作")
            benefitRow(icon: "calendar", text: "6 套官方训练计划")
            benefitRow(icon: "chart.bar", text: "完整统计图表与趋势分析")
            benefitRow(icon: "clock.arrow.circlepath", text: "全部训练历史回顾")
            benefitRow(icon: "angle", text: "无限角度测试 + 历史趋势")
            benefitRow(icon: "hammer", text: "自定义训练计划")
            benefitRow(icon: "icloud", text: "多设备云端数据同步")
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.btPrimary)
                .frame(width: 24)

            Text(text)
                .font(.btBody)
                .foregroundStyle(.btText)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.btSuccess)
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: Spacing.md) {
            if let monthly = subscriptionManager.monthlyProduct {
                planCard(
                    product: monthly,
                    title: "月度订阅",
                    subtitle: "灵活订阅，随时取消",
                    badge: nil
                )
            }

            if let yearly = subscriptionManager.yearlyProduct {
                planCard(
                    product: yearly,
                    title: "年度订阅",
                    subtitle: yearlySubtitle(yearly),
                    badge: "最划算"
                )
            }

            if let lifetime = subscriptionManager.lifetimeProduct {
                planCard(
                    product: lifetime,
                    title: "终身买断",
                    subtitle: "一次购买，永久享用",
                    badge: nil
                )
            }

            if subscriptionManager.products.isEmpty && !subscriptionManager.isLoading {
                Text("无法加载订阅方案，请检查网络后重试")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.xl)
            }

            if subscriptionManager.isLoading && subscriptionManager.products.isEmpty {
                ProgressView()
                    .padding(Spacing.xl)
            }
        }
    }

    private func planCard(product: Product, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedProductID = product.id
            }
        } label: {
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(title)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)

                        if let badge {
                            Text(badge)
                                .font(.btCaption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, 2)
                                .background(Color.btAccent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.btTitle)
                    .foregroundStyle(isSelected ? .btPrimary : .btText)
            }
            .padding(Spacing.lg)
            .background(isSelected ? Color.btPrimary.opacity(0.08) : Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(isSelected ? Color.btPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func yearlySubtitle(_ product: Product) -> String {
        if let monthly = subscriptionManager.monthlyProduct {
            let monthlyAnnual = NSDecimalNumber(decimal: monthly.price).multiplying(by: 12).decimalValue
            let saved = NSDecimalNumber(decimal: monthlyAnnual).subtracting(NSDecimalNumber(decimal: product.price)).decimalValue
            if saved > 0 {
                let pct = NSDecimalNumber(decimal: saved)
                    .dividing(by: NSDecimalNumber(decimal: monthlyAnnual))
                    .multiplying(by: 100)
                    .intValue
                return "较月订阅节省 \(pct)%"
            }
        }
        return "年付更优惠"
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            Task { await handlePurchase() }
        } label: {
            Group {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if subscriptionManager.isPremium {
                    Label("已是 Pro 会员", systemImage: "checkmark.seal.fill")
                } else {
                    Text("立即订阅")
                }
            }
        }
        .buttonStyle(BTButtonStyle.primary)
        .disabled(selectedProductID == nil || subscriptionManager.isLoading || subscriptionManager.isPremium)
        .opacity(subscriptionManager.isPremium ? 0.6 : 1)
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await handleRestore() }
        } label: {
            Text("恢复购买")
                .font(.btCallout)
                .foregroundStyle(.btPrimary)
        }
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Legal

    private var legalLinks: some View {
        VStack(spacing: Spacing.xs) {
            Text("订阅将通过 Apple ID 账户扣费。除非在当前订阅期结束前至少 24 小时关闭自动续订，否则订阅将自动续期。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.lg) {
                Link("服务条款", destination: URL(string: "https://example.com/terms")!)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)

                Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.lg)
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
