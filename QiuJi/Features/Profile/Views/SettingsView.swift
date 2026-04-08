import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @EnvironmentObject private var authState: AuthState
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showClearCacheConfirmation = false
    @State private var cacheSize: String = "计算中…"

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    appearanceSection
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
        .alert("清除缓存", isPresented: $showClearCacheConfirmation) {
            Button("确认清除", role: .destructive) { clearCache() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除所有缓存数据（\(cacheSize)），不会影响训练记录。")
        }
        .alert("注销账号", isPresented: $showDeleteConfirmation) {
            Button("确认注销", role: .destructive) { deleteAccount() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将永久删除你的账号和云端数据，本地数据保留。此操作不可撤销。")
        }
        .alert("注销失败", isPresented: .constant(authState.errorMessage != nil && isDeletingAccount)) {
            Button("重试") { deleteAccount() }
            Button("取消", role: .cancel) {
                authState.errorMessage = nil
                isDeletingAccount = false
            }
        } message: {
            Text(authState.errorMessage ?? "网络问题，请稍后重试。")
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
                Button { showDeleteConfirmation = true } label: {
                    settingsRow(title: "注销账号", detail: nil, detailColor: .btDestructive, titleColor: .btDestructive)
                }
                .buttonStyle(.plain)
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
        isDeletingAccount = true
        Task {
            do {
                try await BackendSyncService.shared.deleteAccount()
                isDeletingAccount = false
                authState.logout()
            } catch {
                authState.errorMessage = "网络问题，请稍后重试。"
            }
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthState())
    }
}

#Preview("Settings Dark") {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthState())
    }
    .preferredColorScheme(.dark)
}

#Preview("Settings Logged In") {
    let state = AuthState()
    state.login(user: AppUser(id: "test123", provider: .apple, displayName: "球迹用户"))
    return NavigationStack {
        SettingsView()
            .environmentObject(state)
    }
}
