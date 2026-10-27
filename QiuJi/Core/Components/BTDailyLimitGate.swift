import SwiftUI

/// Existing SF Symbols remain the geometry source; the generated image is only
/// sampled inside the mask. Small or high-contrast presentations deliberately
/// fall back to the flat semantic foreground for a crisp silhouette.
struct BTPremiumMaterialSymbol: View {
    let systemName: String
    var size: CGFloat
    var weight: Font.Weight = .regular

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var usesTexture: Bool {
        size >= 24 && colorSchemeContrast != .increased && !reduceTransparency
    }

    var body: some View {
        Group {
            if usesTexture {
                Image("btPremiumTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 1.3, height: size * 1.3)
                    .mask(symbolMask)
            } else {
                symbolMask
                    .foregroundStyle(.btPremiumForeground)
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .accessibilityHidden(true)
    }

    private var symbolMask: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: weight))
            .frame(width: size * 1.3, height: size * 1.3)
    }
}

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
            BTProfileCrown(width: 48)

            Text("今日免费次数已用完")
                .font(.btHeadline)
                .foregroundStyle(.white)

            Text("每日可免费练习 \(dailyLimit) 题，升级 Pro 后不限次数。")
                .font(.btSubheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button(action: onUnlock) {
                BTProUnlockLabel()
            }
            .buttonStyle(BTProUnlockButtonStyle(font: .btCTALabelRounded, expands: false))
            // This gate is hosted on the permanently dark table/scene surface.
            .environment(\.colorScheme, .dark)
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
                BTProUnlockLabel()
            }
            .buttonStyle(BTProUnlockButtonStyle(font: .btCTALabelRounded, expands: false))
            // This gate is hosted on the permanently dark table/scene surface.
            .environment(\.colorScheme, .dark)
        }
    }
}

/// Unified PRO / lock corner badge (grid + plan cards + list rows).
struct BTProBadge: View {
    let isUnlocked: Bool
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .font(prominent ? .btFootnote.weight(.bold) : .btMicro.weight(.bold))
            Text("PRO")
                .font(prominent ? .btSubheadline.weight(.heavy) : .btCaption2.weight(.heavy))
        }
        .foregroundStyle(.btPremiumOnDark)
        .padding(.horizontal, prominent ? Spacing.md : Spacing.sm)
        .padding(.vertical, prominent ? Spacing.sm : Spacing.xs)
        .background(Color.black.opacity(0.88))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.btPremiumBorder.opacity(0.72), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pro 内容")
        .accessibilityValue(isUnlocked ? "已解锁" : "未解锁")
        .accessibilityIdentifier("proBadge")
    }
}


/// A segmented choice with a real, readable Pro capsule. The whole segment is
/// tappable, including its badge; the caller owns purchase/cancellation intent.
struct BTTrainingModePicker: View {
    let count: Int
    let isPremium: Bool
    @Binding var freePractice: Bool
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 2) {
            segment("\(count)题", free: false)
            segment("持续练习", free: true)
        }
        .padding(3)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("训练量")
    }
    private func segment(_ title: String, free: Bool) -> some View {
        Button { freePractice = free } label: {
            HStack(spacing: Spacing.xs) {
                Text(title).font(.btFootnote.weight(.medium))
                if free && !isPremium { BTProBadge(isUnlocked: false).accessibilityHidden(true) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(freePractice == free ? (colorScheme == .dark ? Color(uiColor: .systemGray2) : Color(uiColor: .systemBackground)) : .clear,
                        in: RoundedRectangle(cornerRadius: 15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.btText)
        .accessibilityLabel(title)
        .accessibilityValue(free && !isPremium ? "需要 Pro" : (freePractice == free ? "已选" : "未选"))
        .accessibilityAddTraits(freePractice == free ? .isSelected : [])
    }
}
