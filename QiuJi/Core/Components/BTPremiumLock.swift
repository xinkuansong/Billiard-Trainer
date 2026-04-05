import SwiftUI

// MARK: - Lock Mode

enum PremiumLockMode {
    case progressive(visibleItems: Int)
    case fullMask
}

// MARK: - BTPremiumLock

struct BTPremiumLock<Content: View>: View {
    let mode: PremiumLockMode
    var onSubscribeTap: () -> Void = {}
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    private var goldColor: Color { .btAccent }

    private var goldBadgeBg: Color {
        Color.btAccent.opacity(colorScheme == .dark ? 0.15 : 0.12)
    }

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

            VStack(spacing: Spacing.lg) {
                lockIcon
                goldOutlineCTA
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
        }
    }

    // MARK: - Full Mask Lock

    private var fullMaskLock: some View {
        ZStack(alignment: .bottom) {
            content()

            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0), Color.black.opacity(0.95)]
                    : [Color.white.opacity(0), Color.white.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            VStack(spacing: Spacing.lg) {
                lockIcon
                goldFilledCTA
            }
            .padding(.bottom, Spacing.xxxl)
        }
    }

    // MARK: - Shared Elements

    private var lockIcon: some View {
        ZStack {
            Circle()
                .fill(colorScheme == .dark
                      ? goldColor.opacity(0.20)
                      : Color(red: 0xFF / 255.0, green: 0xDD / 255.0, blue: 0xAF / 255.0))
                .frame(width: 56, height: 56)

            Image(systemName: "lock.fill")
                .font(.btTitle)
                .fontWeight(.regular)
                .foregroundStyle(goldColor)
        }
    }

    private var goldOutlineCTA: some View {
        Button(action: onSubscribeTap) {
            HStack(spacing: Spacing.sm) {
                proBadge
                Text("解锁 Pro")
                    .font(.btHeadline)
                    .foregroundStyle(goldColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .stroke(goldColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xxl)
    }

    private var goldFilledCTA: some View {
        Button(action: onSubscribeTap) {
            HStack(spacing: Spacing.sm) {
                proBadge
                Text("解锁 Pro")
                    .font(.btHeadline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(goldColor)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xxl)
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.btCaption2)
            .fontWeight(.bold)
            .foregroundStyle(goldColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(goldBadgeBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Convenience modifier

struct PremiumGateModifier: ViewModifier {
    let contentIsPremium: Bool
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showSubscription = false

    func body(content: Content) -> some View {
        ZStack {
            content

            if contentIsPremium && !subscriptionManager.isPremium {
                BTPremiumLock(mode: .fullMask) {
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
    func premiumGate(isPremium: Bool) -> some View {
        modifier(PremiumGateModifier(contentIsPremium: isPremium))
    }
}

// MARK: - Preview

#Preview("Progressive Lock Light") {
    BTPremiumLock(mode: .progressive(visibleItems: 2)) {
        // Simulated visible content
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
    BTPremiumLock(mode: .fullMask) {} content: {
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

#Preview("Full Mask Dark") {
    BTPremiumLock(mode: .fullMask) {} content: {
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
    .preferredColorScheme(.dark)
}
