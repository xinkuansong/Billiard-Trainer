import SwiftUI

/// The preview shares the current room, table and cloth selections.
struct RoomStyleSelectionView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AppearanceCombinationPreview(label: prefs.roomStyle.displayName + "球房预览",
                                             identifier: "roomStyle.preview", showsRoomOverview: true)
                Text("当前搭配：" + prefs.roomStyle.displayName + " · " + prefs.tableStyle.displayName + " · " + prefs.clothColor.displayName)
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("选择后自动保存，预览同步显示当前搭配。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                VStack(spacing: 0) {
                    ForEach(RoomStyle.allCases) { style in
                        Button { prefs.roomStyle = style } label: {
                            HStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(style.displayName).font(.btBody).foregroundStyle(.btText)
                                    Text(style.subtitle).font(.btFootnote).foregroundStyle(.btTextSecondary)
                                }
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: prefs.roomStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(prefs.roomStyle == style ? Color.btPrimary : Color.btTextSecondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.roomStyle." + style.rawValue)
                        .accessibilityLabel(style.displayName)
                        .accessibilityValue(prefs.roomStyle == style ? "已选择" : "未选择")
                        .accessibilityAddTraits(prefs.roomStyle == style ? .isSelected : [])
                        if style != RoomStyle.allCases.last { Divider().padding(.leading, Spacing.lg) }
                    }
                }
                .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("球房风格")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview("Light") { NavigationStack { RoomStyleSelectionView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { RoomStyleSelectionView() }.preferredColorScheme(.dark) }
