import SwiftUI

struct CueStyleSettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                Text("从前节到后把，选择喜欢的整杆外观。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                styleButton(.original)
                ForEach(CueKind.allCases) { kind in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(kind.displayName).font(.btTitle).foregroundStyle(.btText)
                        Text(kind.detail).font(.btFootnote).foregroundStyle(.btTextSecondary)
                    }.padding(.top, Spacing.sm)
                    ForEach(CueStyle.allCases.filter { $0.kind == kind }) { style in
                        styleButton(style)
                    }
                }
                Text("外观选择保存在本机，不改变击球参数。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
            }.padding(Spacing.lg)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("球杆外观")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.cueStyles")
    }

    private func styleButton(_ style: CueStyle) -> some View {
        Button { prefs.cueStyle = style } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(style.displayName).font(.btHeadline).foregroundStyle(.btText)
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: prefs.cueStyle == style ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(prefs.cueStyle == style ? Color.btPrimary : Color.btTextSecondary)
                }
                Text(style.detail).font(.btCaption).foregroundStyle(.btTextSecondary)
                if let image = CueStyleModel.preview(style) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .accessibilityHidden(true)
                }
                if let detail = CueStyleModel.preview(style, detail: true) {
                    Image(uiImage: detail).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.lg).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.cue." + style.rawValue)
        .accessibilityLabel(style.displayName + (style.kind.map { "，" + $0.displayName } ?? ""))
        .accessibilityValue(prefs.cueStyle == style ? "已选择" : "未选择")
    }
}

#Preview("Light") { NavigationStack { CueStyleSettingsView() }.preferredColorScheme(.light) }
#Preview("Dark") { NavigationStack { CueStyleSettingsView() }.preferredColorScheme(.dark) }
