import SwiftUI

/// The preview shares the current room, table and cloth selections.
struct ClothColorSelectionView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AppearanceCombinationPreview(label: prefs.clothColor.displayName + "台呢预览",
                                             identifier: "clothColor.preview")
                Text("当前搭配：" + prefs.roomStyle.displayName + " · " + prefs.tableStyle.displayName + " · " + prefs.clothColor.displayName)
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("选择后自动保存，预览同步显示当前搭配。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                VStack(spacing: 0) {
                    ForEach(ClothColor.allCases) { style in
                        Button { prefs.clothColor = style } label: {
                            HStack(spacing: Spacing.md) {
                                Circle().fill(Color(uiColor: style.swatch))
                                    .frame(width: 24, height: 24).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(style.displayName).font(.btBody).foregroundStyle(.btText)
                                }
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: prefs.clothColor == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(prefs.clothColor == style ? Color.btPrimary : Color.btTextSecondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.clothColor." + style.rawValue)
                        .accessibilityLabel(style.displayName)
                        .accessibilityValue(prefs.clothColor == style ? "已选择" : "未选择")
                        .accessibilityAddTraits(prefs.clothColor == style ? .isSelected : [])
                        if style != ClothColor.allCases.last { Divider().padding(.leading, Spacing.lg) }
                    }
                }
                .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("台呢颜色")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview("Light") { NavigationStack { ClothColorSelectionView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { ClothColorSelectionView() }.preferredColorScheme(.dark) }
