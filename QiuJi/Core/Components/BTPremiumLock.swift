import SwiftUI

/// Keep every upgrade entry on the same crown artwork as the profile.
struct BTProUnlockLabel: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            BTProfileCrown(width: 32)
            Text(BTDailyLimitGate.unlockCTATitle)
        }
    }
}

/// The destination is constructed only after authorization, including direct navigation.
struct ProAccessGate<Content: View>: View {
    var requiresPremium = true
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showSubscription = false

    var body: some View {
        let decision = subscriptionManager.accessDecision(requiresPremium: requiresPremium)
        Group {
            switch decision {
            case .allowed:
                content()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("pro.authorized")
            case .checkingEntitlements:
                VStack(spacing: Spacing.lg) {
                    ProgressView("正在确认 Pro 权益…")
                    Button("刷新权益") { Task { await subscriptionManager.checkEntitlements() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("pro.checking")
            case .requiresLogin, .requiresPro:
                BTPremiumLock(mode: .fullMask, title: "此功能为 Pro 专属",
                              subtitle: decision == .requiresLogin
                                  ? "登录后可购买或恢复已有的 Apple 购买权益"
                                  : "购买 Pro 或恢复已有的 Apple 购买权益",
                              onSubscribeTap: { showSubscription = true }) {
                    Color.btBG
                }
                .accessibilityIdentifier("pro.locked")
            }
        }
        .task { if requiresPremium { await subscriptionManager.checkEntitlements(coalescing: true) } }
        .sheet(isPresented: $showSubscription) { SubscriptionView() }
    }
}

// MARK: - Lock Mode

enum PremiumLockMode {
    case progressive(visibleItems: Int)
    case fullMask
}

// MARK: - BTPremiumLock

struct BTPremiumLock<Content: View>: View {
    let mode: PremiumLockMode
    var title: String = "升级 Pro 解锁更多内容"
    var subtitle: String = "订阅后即可使用完整功能"
    var onSubscribeTap: () -> Void = {}
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    private var goldColor: Color { .btPremiumForeground }

    var body: some View {
        switch mode {
        case .progressive:
            progressiveLock
        case .fullMask:
            fullMaskLock
        }
    }

    // MARK: - Progressive Lock

    private var progressiveLock: some View {
        VStack(spacing: 0) {
            content()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.25),
                            .init(color: .clear, location: 0.65),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                lockIcon
                goldFilledCTA
                restorePurchaseLink
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
        }
    }

    // MARK: - Full Mask Lock

    private var fullMaskLock: some View {
        ZStack {
            content()
                .blur(radius: 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.lg) {
                fullMaskLockIcon
                Text(title)
                    .font(.btTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
                goldFilledCTA
            }
        }
    }

    private var fullMaskLockIcon: some View {
        ZStack {
            Circle()
                .fill(Color.btPremiumSurface)
                .frame(width: 72, height: 72)

            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(goldColor)
        }
    }

    private var restorePurchaseLink: some View {
        Button {
            onSubscribeTap()
        } label: {
            Text("已购买？恢复购买")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared Elements

    private var lockIcon: some View {
        ZStack {
            Circle()
                .fill(Color.btPremiumSurface)
                .frame(width: 56, height: 56)

            Image(systemName: "lock.fill")
                .font(.btTitle)
                .fontWeight(.regular)
                .foregroundStyle(goldColor)
        }
    }

    /// F-ST-08: progressive and full-mask gates share the same Pro CTA.
    private var goldFilledCTA: some View {
        Button(action: onSubscribeTap) {
            BTProUnlockLabel()
        }
        .buttonStyle(BTProUnlockButtonStyle(font: .btHeadline))
        .accessibilityIdentifier("premiumLock.unlock")
        .padding(.horizontal, Spacing.xxl)
    }

}

// MARK: - Convenience modifier

struct PremiumGateModifier: ViewModifier {
    let contentIsPremium: Bool
    var title: String
    var subtitle: String
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showSubscription = false

    func body(content: Content) -> some View {
        ZStack {
            content

            if contentIsPremium && !subscriptionManager.isPremium {
                BTPremiumLock(
                    mode: .fullMask,
                    title: title,
                    subtitle: subtitle
                ) {
                    showSubscription = true
                } content: {
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }
}

extension View {
    /// Requires contextual lock copy (F-ST-08) — no statistics-default string.
    func premiumGate(
        isPremium: Bool,
        title: String,
        subtitle: String
    ) -> some View {
        modifier(PremiumGateModifier(
            contentIsPremium: isPremium,
            title: title,
            subtitle: subtitle
        ))
    }
}

// MARK: - Preview

#Preview("Progressive Lock Light") {
    BTPremiumLock(mode: .progressive(visibleItems: 2)) {
    } content: {
        VStack(spacing: Spacing.sm) {
            ForEach(0..<2, id: \.self) { i in
                HStack {
                    Text("可见内容行 \(i + 1)")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                    Spacer()
                }
                .padding()
                .background(Color.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    .background(Color.btBG)
}

#Preview("Full Mask Light") {
    BTPremiumLock(
        mode: .fullMask,
        title: "统计功能为 Pro 专属",
        subtitle: "升级 Pro 解锁训练统计、趋势图表和分类对比"
    ) {} content: {
        VStack(spacing: Spacing.sm) {
            ForEach(0..<6, id: \.self) { i in
                HStack {
                    Text("被遮挡的内容行 \(i + 1)")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                    Spacer()
                }
                .padding()
                .background(Color.btBGSecondary)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
    .background(Color.btBG)
}
