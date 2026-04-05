import SwiftUI

struct TrainingShareView: View {
    let session: TrainingSessionSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTheme: ShareCardTheme = .defaultGreen
    @State private var selectedFont: ShareCardFont = .system
    @State private var hideNote = false
    @State private var hideSuccessRate = false
    @State private var hideBallTable = false
    @State private var showSavedAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cardPreview
                customizationPanel
            }
            .background(Color.btBG.ignoresSafeArea())
            .navigationTitle("分享训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                            Text("返回")
                        }
                    }
                }
            }
            .alert("已保存到相册", isPresented: $showSavedAlert) {
                Button("好的", role: .cancel) {}
            }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        ScrollView {
            BTShareCard(
                session: session,
                theme: selectedTheme,
                fontChoice: selectedFont,
                hideSuccessRate: hideSuccessRate,
                hideBallTable: hideBallTable
            )
            .frame(maxWidth: 361)
            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.18), radius: 12, x: 0, y: 4)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Customization Panel

    private var customizationPanel: some View {
        VStack(spacing: Spacing.xxl) {
            fontSelector
            themeSelector
            optionToggles
            Divider()
            shareActions
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.xxl)
        .padding(.bottom, Spacing.xl)
        .background(
            Color.btBGSecondary
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.08), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Font Selector

    private var fontSelector: some View {
        HStack {
            Text("字体")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            HStack(spacing: 0) {
                ForEach(ShareCardFont.allCases, id: \.rawValue) { font in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFont = font
                        }
                    } label: {
                        Text(font.rawValue)
                            .font(.btFootnote14)
                            .fontWeight(.medium)
                            .foregroundStyle(selectedFont == font ? .white : .btTextSecondary)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.sm)
                            .frame(minHeight: 44)
                            .background(selectedFont == font ? Color.btPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .background(Color.btBGTertiary)
            .clipShape(Capsule())
        }
    }

    // MARK: - Theme Selector

    private var themeSelector: some View {
        HStack(alignment: .top) {
            Text("颜色")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            HStack(spacing: Spacing.lg) {
                ForEach(ShareCardTheme.allCases) { theme in
                    themeCircle(theme)
                }
            }
        }
    }

    private func themeCircle(_ theme: ShareCardTheme) -> some View {
        VStack(spacing: Spacing.sm) {
            Circle()
                .fill(theme.previewColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(selectedTheme == theme ? Color.btPrimary : Color.clear, lineWidth: 2)
                        .padding(-3)
                )
            Text(theme.rawValue)
                .font(.btCaption2)
                .fontWeight(.regular)
                .foregroundStyle(selectedTheme == theme ? .btText : .btTextSecondary)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTheme = theme
            }
        }
    }

    // MARK: - Option Toggles

    private var optionToggles: some View {
        HStack(alignment: .top) {
            Text("选项")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            HStack(spacing: Spacing.sm) {
                togglePill("隐藏备注", isActive: $hideNote)
                togglePill("隐藏成功率", isActive: $hideSuccessRate)
                togglePill("隐藏球台图", isActive: $hideBallTable)
            }
        }
    }

    private func togglePill(_ title: String, isActive: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isActive.wrappedValue.toggle()
            }
        } label: {
            Text(title)
                .font(.btFootnote)
                .foregroundStyle(isActive.wrappedValue ? .white : .btTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 44)
                .background(isActive.wrappedValue ? Color.btPrimary : Color.btBGTertiary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Share Actions

    private let wechatGreen = Color(red: 0.027, green: 0.757, blue: 0.376)

    private var shareActions: some View {
        HStack(alignment: .top) {
            HStack(spacing: Spacing.xl) {
                shareButton(icon: "message.fill", label: "微信好友", color: wechatGreen) {
                    // WeChat friend share — H-05 deferred
                }
                shareButton(icon: "camera.fill", label: "朋友圈", color: wechatGreen) {
                    // WeChat moments share — H-05 deferred
                }
                shareButton(icon: "arrow.down.to.line.compact", label: "保存相册", color: .btPrimary) {
                    showSavedAlert = true
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("返回")
                    .font(.btSubheadline)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(.top, Spacing.md)
        }
        .padding(.bottom, Spacing.sm)
    }

    private func shareButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.btTitle)
                        .foregroundStyle(.white)
                }
                Text(label)
                    .font(.btCaption2)
                    .fontWeight(.regular)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private let previewSession = TrainingSessionSummary(
    date: Date(),
    planName: "力量训练 Day 1",
    durationMinutes: 48,
    completedDrills: 3,
    totalSets: 12,
    overallSuccessRate: 0.72,
    drills: [
        .init(name: "定点红球进袋", setsCount: 4, madeBalls: 31, targetBalls: 40),
        .init(name: "斯诺克直线进袋", setsCount: 3, madeBalls: 28, targetBalls: 30),
        .init(name: "走位练习 A", setsCount: 5, madeBalls: 28, targetBalls: 50),
    ]
)

#Preview("Light") {
    TrainingShareView(session: previewSession)
}

#Preview("Dark") {
    TrainingShareView(session: previewSession)
        .preferredColorScheme(.dark)
}
