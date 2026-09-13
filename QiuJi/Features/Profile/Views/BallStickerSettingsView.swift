import SwiftUI

struct BallStickerSettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("选择喜欢的号码与花纹，应用于球桌上的编号球。")
                    .font(.btFootnote).foregroundStyle(.btTextSecondary)
                ForEach(BallStickerStyle.allCases) { style in
                    Button { prefs.ballStickerStyle = style } label: {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text(style.displayName).font(.btHeadline).foregroundStyle(.btText)
                                Spacer(minLength: Spacing.sm)
                                Image(systemName: prefs.ballStickerStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(prefs.ballStickerStyle == style ? Color.btPrimary : Color.btTextSecondary)
                            }
                            if let image = BallStickerAppearance.image(named: style.previewName) {
                                Image(uiImage: image).resizable().scaledToFit()
                                    .frame(maxWidth: .infinity).frame(height: 88)
                                    .accessibilityHidden(true)
                            }
                            Text(style.subtitle).font(.btFootnote).foregroundStyle(.btTextSecondary)
                        }
                        .padding(Spacing.lg).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.ballSticker." + style.rawValue)
                    .accessibilityLabel(style.displayName + "，" + style.subtitle)
                    .accessibilityValue(prefs.ballStickerStyle == style ? "已选择" : "未选择")
                }
            }.padding(Spacing.lg)
        }
        .background(Color.btBG.ignoresSafeArea())
        .navigationTitle("球贴纸")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.ballStickers")
    }
}
