import SwiftUI
import Photos

struct TrainingShareView: View {
    let session: TrainingSessionSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTheme: ShareCardTheme = .paper
    @State private var selectedFont: ShareCardFont = .system
    @State private var hideSuccessRate = false
    @State private var toast: BTToastMessage?
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var isSavingToPhotos = false

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
            // F-OV-04: short success → non-blocking toast; errors stay as alert.
            .btToast($toast)
            .alert("保存失败", isPresented: $showSaveErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Card Preview

    private var shareCard: some View {
        BTShareCard(
            session: session,
            theme: selectedTheme,
            fontChoice: selectedFont,
            hideSuccessRate: hideSuccessRate
        )
    }

    private var cardPreview: some View {
        ScrollView {
            // W1: preview uses the same width contract as off-screen export
            // (`ShareCardImageRenderer.cardWidth`); height follows content in both paths.
            shareCard
                .frame(width: ShareCardImageRenderer.cardWidth)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.18), radius: 12, x: 0, y: 4)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Customization Panel

    private var customizationPanel: some View {
        // 长图预览需要尽量多的竖向空间，面板保持紧凑。
        VStack(spacing: Spacing.lg) {
            themeSelector
            fontSelector
            optionToggles
            Divider()
            shareActions
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Spacing.lg)
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
                        withAnimation(BTMotion.easeFast) {
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
            Text("背景")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            HStack(spacing: Spacing.md) {
                ForEach(ShareCardTheme.allCases) { theme in
                    themeCircle(theme)
                }
            }
        }
    }

    private func themeCircle(_ theme: ShareCardTheme) -> some View {
        Button {
            withAnimation(BTMotion.easeFast) {
                selectedTheme = theme
            }
        } label: {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(theme.previewColor)
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 12, height: 12)
                }
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(selectedTheme == theme ? Color.btPrimary : Color.clear, lineWidth: 2)
                        .padding(-3)
                )
                // Hairline so light paper and near-black swatches stay visible on both schemes.
                .overlay(
                    Circle()
                        .stroke(Color.btSeparator.opacity(0.5), lineWidth: 1)
                )
                Text(theme.rawValue)
                    .font(.btCaption2)
                    .fontWeight(.regular)
                    .foregroundStyle(selectedTheme == theme ? .btText : .btTextSecondary)
            }
        }
        .buttonStyle(BTPressableStyle.capsule)
    }

    // MARK: - Option Toggles
    // F-TR-02: hide dead switches (隐藏备注 / 隐藏球台图). Keep wired「隐藏成功率」.

    private var optionToggles: some View {
        HStack(alignment: .top) {
            Text("选项")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            togglePill("隐藏成功率", isActive: $hideSuccessRate)
        }
    }

    private func togglePill(_ title: String, isActive: Binding<Bool>) -> some View {
        Button {
            withAnimation(BTMotion.easeFast) {
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
        // F-TS-08: keep toolbar「返回」only — drop duplicate bottom dismiss.
        HStack(alignment: .top) {
            HStack(spacing: Spacing.xl) {
                shareButton(icon: "message.fill", label: "微信好友", color: wechatGreen) {
                    // WeChat friend share — H-05 deferred
                }
                shareButton(icon: "camera.fill", label: "朋友圈", color: wechatGreen) {
                    // WeChat moments share — H-05 deferred
                }
                shareButton(
                    icon: "arrow.down.to.line.compact",
                    label: isSavingToPhotos ? "保存中" : "保存相册",
                    color: .btPrimary,
                    showsProgress: isSavingToPhotos,
                    accessibilityId: "shareSaveToPhotos"
                ) {
                    Task { await saveCardToPhotos() }
                }
            }

            Spacer()
        }
        .padding(.bottom, Spacing.sm)
    }

    private func shareButton(
        icon: String,
        label: String,
        color: Color,
        showsProgress: Bool = false,
        accessibilityId: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 52, height: 52)
                    if showsProgress {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.btTitle)
                            .foregroundStyle(.white)
                    }
                }
                Text(label)
                    .font(.btCaption2)
                    .fontWeight(.regular)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .buttonStyle(BTPressableStyle.capsule)
        .disabled(showsProgress)
        .accessibilityLabel(label)
        .modifier(OptionalAccessibilityIdentifier(accessibilityId))
    }

    // MARK: - Save to Photos (F-TR-01)

    @MainActor
    private func saveCardToPhotos() async {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        defer { isSavingToPhotos = false }

        // Let SwiftUI paint「保存中」before synchronous ImageRenderer work.
        await Task.yield()

        guard let image = ShareCardImageRenderer.render(
            session: session,
            theme: selectedTheme,
            fontChoice: selectedFont,
            hideSuccessRate: hideSuccessRate
        ) else {
            saveErrorMessage = "无法生成分享图，请稍后重试"
            showSaveErrorAlert = true
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveErrorMessage = "未获得相册权限，请在系统设置中允许球迹写入照片"
            showSaveErrorAlert = true
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            withAnimation(BTMotion.easeChrome) {
                toast = BTToastMessage("已保存到相册", tone: .success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + BTToast.defaultDuration) {
                withAnimation(BTMotion.easeChrome) {
                    if toast?.text == "已保存到相册" { toast = nil }
                }
            }
        } catch {
            saveErrorMessage = error.localizedDescription.isEmpty
                ? "保存到相册失败，请稍后重试"
                : error.localizedDescription
            showSaveErrorAlert = true
        }
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
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
