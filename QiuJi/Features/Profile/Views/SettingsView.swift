import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteErrorAlert = false
    @State private var deleteErrorMessage: String?
    @State private var showClearCacheConfirmation = false
    @State private var cacheSize: String = "计算中…"

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    appearanceSection
                    soundSection
                    trainingAidSection
                    #if DEBUG && targetEnvironment(simulator)
                    simulatorDebugSection
                    #endif
                    dataSection
                    if authState.isLoggedIn {
                        accountSection
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("偏好设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { cacheSize = calculateCacheSize() }
        // F-OV-02: destructive clear/delete → confirmationDialog (cancel first).
        .confirmationDialog(
            "清除缓存",
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("确认清除", role: .destructive) { clearCache() }
        } message: {
            Text("将清除所有缓存数据（\(cacheSize)），不会影响训练记录。")
        }
        .confirmationDialog(
            "注销账号",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) {}
            Button("确认注销", role: .destructive) { deleteAccount() }
        } message: {
            Text("将永久删除你的账号和云端数据，本地数据保留。此操作不可撤销。")
        }
        .alert("注销失败", isPresented: Binding(
            get: { showDeleteErrorAlert },
            set: { if !$0 { dismissDeleteError() } }
        )) {
            Button("重试") { deleteAccount() }
            Button("取消", role: .cancel) { dismissDeleteError() }
        } message: {
            Text(deleteErrorMessage ?? "网络问题，请稍后重试。")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .tint(.btPrimary)
                        Text("正在注销…")
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                    }
                    .padding(Spacing.xxl)
                    .background(Color.btBGSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                }
                .allowsHitTesting(true)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("外观")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            BTTogglePillGroup(
                options: AppearanceMode.allCases,
                selected: $prefs.appearanceMode
            ) { $0.displayName }
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("声音")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Toggle(isOn: $prefs.soundEffectsEnabled) {
                    Text("击球音效")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                }
                .tint(.btPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Training Aids

    private var trainingAidSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("教学辅助")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: $prefs.showSeparationAngle) {
                    Text("显示 90° 分离角辅助线")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                }
                .tint(.btPrimary)
                Text("在所有击球轨迹上叠加一条过碰撞点、垂直于撞击线的辅助线，帮助判断母球分离方向。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    private var simulatorDebugSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("开发者（模拟器）")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: debugPremiumBinding) {
                    Text("解锁 Pro")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                }
                .tint(.btAccent)
                .accessibilityIdentifier("simulatorUnlockProToggle")
                Text("make run / 点图标不会注入商店。打开后本机保持 Pro，UI 测试启动会重置。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private var debugPremiumBinding: Binding<Bool> {
        Binding(
            get: { subscriptionManager.isDebugPremiumPersisted },
            set: { subscriptionManager.setDebugPremiumUnlocked($0) }
        )
    }
    #endif

    // MARK: - Data Management

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("数据管理")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Button { showClearCacheConfirmation = true } label: {
                    settingsRow(title: "清除缓存", detail: cacheSize)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, Spacing.lg)

                settingsRow(title: "数据导出", detail: "即将推出", detailColor: .btTextTertiary)
                    .opacity(0.5)
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Account Security

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("账号安全")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Button {
                    guard !isDeletingAccount else { return }
                    showDeleteConfirmation = true
                } label: {
                    settingsRow(
                        title: "注销账号",
                        detail: isDeletingAccount ? "处理中…" : nil,
                        detailColor: .btDestructive,
                        titleColor: .btDestructive
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Row Helper

    private func settingsRow(
        title: String,
        detail: String?,
        detailColor: Color = .btTextSecondary,
        titleColor: Color = .btText
    ) -> some View {
        HStack {
            Text(title)
                .font(.btBody)
                .foregroundStyle(titleColor)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.btCaption)
                    .foregroundStyle(detailColor)
            }

            Image(systemName: "chevron.right")
                .font(.btCaption).fontWeight(.medium)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func calculateCacheSize() -> String {
        let urlCacheSize = URLCache.shared.currentDiskUsage
        let totalBytes = urlCacheSize
        if totalBytes < 1024 * 1024 {
            return String(format: "%.0f KB", Double(totalBytes) / 1024.0)
        }
        return String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        cacheSize = calculateCacheSize()
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        deleteErrorMessage = nil
        showDeleteErrorAlert = false
        Task {
            do {
                try await BackendSyncService.shared.deleteAccount()
                isDeletingAccount = false
                authState.logout()
            } catch {
                deleteErrorMessage = "网络问题，请稍后重试。"
                isDeletingAccount = false
                showDeleteErrorAlert = true
            }
        }
    }

    private func dismissDeleteError() {
        showDeleteErrorAlert = false
        deleteErrorMessage = nil
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthState())
            .environmentObject(SubscriptionManager.shared)
    }
}

#Preview("Settings Dark") {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthState())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}

#Preview("Settings Logged In") {
    let state = AuthState()
    state.login(user: AppUser(id: "test123", provider: .apple, displayName: "球迹用户"))
    return NavigationStack {
        SettingsView()
            .environmentObject(state)
            .environmentObject(SubscriptionManager.shared)
    }
}
