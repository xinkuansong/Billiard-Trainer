import SwiftUI

/// The preview shares the current room, table and cloth selections.
struct TableStyleSelectionView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AppearanceCombinationPreview(label: prefs.tableStyle.displayName + "球桌预览",
                                             identifier: "tableStyle.preview")
                Text("当前搭配：" + prefs.roomStyle.displayName + " · " + prefs.tableStyle.displayName + " · " + prefs.clothColor.displayName)
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("选择后自动保存，预览同步显示当前搭配。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                VStack(spacing: 0) {
                    ForEach(TableStyle.allCases) { style in
                        Button { prefs.tableStyle = style } label: {
                            HStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(style.displayName).font(.btBody).foregroundStyle(.btText)
                                    Text(style.subtitle).font(.btFootnote).foregroundStyle(.btTextSecondary)
                                }
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: prefs.tableStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(prefs.tableStyle == style ? Color.btPrimary : Color.btTextSecondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.tableStyle." + style.rawValue)
                        .accessibilityLabel(style.displayName)
                        .accessibilityValue(prefs.tableStyle == style ? "已选择" : "未选择")
                        .accessibilityAddTraits(prefs.tableStyle == style ? .isSelected : [])
                        if style != TableStyle.allCases.last { Divider().padding(.leading, Spacing.lg) }
                    }
                }
                .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("球桌风格")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview("Light") { NavigationStack { TableStyleSelectionView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { TableStyleSelectionView() }.preferredColorScheme(.dark) }
