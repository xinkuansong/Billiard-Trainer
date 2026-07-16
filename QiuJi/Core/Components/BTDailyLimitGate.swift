import SwiftUI

/// Shared Freemium daily-limit card for Angle Training pages (W2-9 / F-ST-04).
/// Does **not** change usage limits — only visual + CTA copy.
struct BTDailyLimitGate: View {
    /// Unified unlock verb (aligned with `BTPremiumLock`).
    static let unlockCTATitle = "解锁 Pro"

    var dailyLimit: Int = AngleUsageLimiter.dailyLimit
    var onUnlock: () -> Void

    /// Compact inline variant used inside result sections.
    var compact: Bool = false

    var body: some View {
        if compact {
            compactBody
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.btHeroSymbol)
                .foregroundStyle(.btAccent)

            Text("今日免费次数已用完")
                .font(.btHeadline)
                .foregroundStyle(.white)

            Text("每日可免费练习 \(dailyLimit) 题，升级 Pro 后不限次数。")
                .font(.btSubheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button(action: onUnlock) {
                Label(Self.unlockCTATitle, systemImage: "crown.fill")
                    .font(.btCTALabelRounded)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.btPrimary))
            }
            .buttonStyle(BTPressableStyle.capsule)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private var compactBody: some View {
        VStack(spacing: Spacing.sm) {
            Text("今日免费次数已用完")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.white.opacity(0.65))

            Button(action: onUnlock) {
                Label(Self.unlockCTATitle, systemImage: "crown.fill")
                    .font(.btCTALabelRounded)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.btPrimary))
            }
            .buttonStyle(BTPressableStyle.capsule)
        }
    }
}

/// Unified PRO / lock corner badge (grid + plan cards + list rows).
struct BTProBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: BTIcon.lock)
                .font(.btMicro.weight(.bold))
            Text("PRO")
                .font(.btCaption2.weight(.heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color.btAccent)
        .clipShape(Capsule())
        .accessibilityLabel("Pro 内容")
    }
}
