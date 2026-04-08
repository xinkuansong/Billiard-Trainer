import SwiftUI

struct SubscriptionStatusView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    private let goldColor = Color.btAccent

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    statusCard
                    actionsSection
                    featuresSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("订阅管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("恢复购买", isPresented: $showRestoreAlert) {
            Button("好的") {}
        } message: {
            Text(restoreMessage)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(goldColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(goldColor)
            }

            VStack(spacing: Spacing.xs) {
                Text("Pro 会员")
                    .font(.btTitle2)
                    .foregroundStyle(.btText)

                Text(subscriptionTypeLabel)
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)

                Text(expiryLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "creditcard")
                        .font(.btSubheadline)
                    Text("管理订阅")
                        .font(.btCallout.weight(.medium))
                }
                .foregroundStyle(.btPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.btPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .buttonStyle(.plain)

            Button {
                Task { await handleRestore() }
            } label: {
                Text("恢复购买")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("已解锁功能")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                featureRow(title: "完整动作库", subtitle: "全部 72 个训练动作")
                Divider().padding(.leading, 56)
                featureRow(title: "统计与趋势图表", subtitle: "可视化训练进度")
                Divider().padding(.leading, 56)
                featureRow(title: "自定义训练计划", subtitle: "打造专属训练方案")
                Divider().padding(.leading, 56)
                featureRow(title: "无限角度测试", subtitle: "不限次数提升角度感知")
                Divider().padding(.leading, 56)
                featureRow(title: "训练分享卡全样式", subtitle: "所有配色主题与分享模版")
                Divider().padding(.leading, 56)
                featureRow(title: "云端同步", subtitle: "多设备数据无缝同步")
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private func featureRow(title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.btCaption.weight(.bold))
                    .foregroundStyle(.btPrimary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.btCallout)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
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
        return "自动续费中"
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
