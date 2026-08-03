import SwiftUI

/// Shared filter chip for Training / Drill Library lists.
/// Baseline: Training Tab `filterChips` (SPEC §6.3 / §7 — `btChipActiveFill*`).
struct BTFilterChip: View {
    let title: String
    let isSelected: Bool
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.btFootnote14.weight(.medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(borderColor, lineWidth: isSelected ? 0 : 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "filterChip_\(title)")
    }

    private var textColor: Color {
        if isSelected {
            return colorScheme == .dark ? .black : Color.btBGSecondary
        }
        return colorScheme == .dark ? .btTextSecondary : .btText
    }

    private var backgroundColor: Color {
        if isSelected {
            return colorScheme == .dark ? .btChipActiveFillDark : .btChipActiveFillLight
        }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private var borderColor: Color {
        isSelected ? .clear : .btSeparator
    }
}

#Preview("Filter Chips Light") {
    HStack(spacing: Spacing.sm) {
        BTFilterChip(title: "全部", isSelected: true, action: {})
        BTFilterChip(title: "初级", isSelected: false, action: {})
        BTFilterChip(title: "中级", isSelected: false, action: {})
    }
    .padding()
    .background(.btBG)
}

#Preview("Filter Chips Dark") {
    HStack(spacing: Spacing.sm) {
        BTFilterChip(title: "全部", isSelected: true, action: {})
        BTFilterChip(title: "初级", isSelected: false, action: {})
        BTFilterChip(title: "中级", isSelected: false, action: {})
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
