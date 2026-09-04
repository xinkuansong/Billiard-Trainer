import SwiftUI

/// Shared filter chip for Training / Drill Library lists.
/// v56: selection is expressed as a low-intensity brand surface plus green
/// text/border in both appearances. Color is reinforced by `.isSelected`.
struct BTFilterChip: View {
    let title: String
    let isSelected: Bool
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

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
                    Capsule().stroke(borderColor, lineWidth: 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "filterChip_\(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        isSelected ? .btPrimary : .btTextSecondary
    }

    private var backgroundColor: Color {
        isSelected ? .btPrimaryMuted : .btBGSecondary
    }

    private var borderColor: Color {
        isSelected ? Color.btPrimary.opacity(0.55) : .btSeparator
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
