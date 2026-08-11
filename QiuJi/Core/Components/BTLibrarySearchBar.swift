import SwiftUI

/// Shared library search field for Practice / Drill list pages (v28 W0).
///
/// Layout: tertiary fill, `BTRadius.sm`, optional trailing accessory (e.g. filter Menu).
struct BTLibrarySearchBar<Trailing: View>: View {
    /// 字段固定高（= 筛选按钮边长）：无论有无 trailing，各页搜索框高度一致。
    static var fieldHeight: CGFloat { 44 }

    let placeholder: String
    @Binding var text: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.btTextTertiary)
                TextField(placeholder, text: $text)
                    .font(.btCallout)
                    .foregroundStyle(.btText)
                    .accessibilityIdentifier("librarySearchField")
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.btTextTertiary)
                    }
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: Self.fieldHeight)
            .background(Color.btBGTertiary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            trailing()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }
}

extension BTLibrarySearchBar where Trailing == EmptyView {
    init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
        self.trailing = { EmptyView() }
    }
}
