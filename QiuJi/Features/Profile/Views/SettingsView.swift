import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    @State private var transparencyDraft = 0.5
    @State private var editingTransparency = false
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var ownerContext: CurrentOwnerContext
    @EnvironmentObject private var dataCoordinator: AccountDataCoordinator
    @EnvironmentObject private var avatarStore: AvatarStore
    @Environment(\.colorScheme) private var colorScheme
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
                    practiceDisplaySection
                    trainingAidSection
                    appearanceSection
                    frameRateSection
                    soundSection
                    #if DEBUG && targetEnvironment(simulator)
                    simulatorDebugSection
                    #endif
                    equipmentSection
                    dailyClearanceSection
                    dataSection
                    if authState.isLoggedIn {
                        accountSection
                    }
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
            .accessibilityIdentifier("settings.content")
            .accessibilityValue(colorScheme == .dark ? "dark" : "light")
        }
        .navigationTitle("通用设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            cacheSize = calculateCacheSize()
            transparencyDraft = tablePreferences.general[.transparency]
        }
        .onChange(of: tablePreferences.revision) { _, _ in
            if !editingTransparency { transparencyDraft = tablePreferences.general[.transparency] }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("统一应用到相关页面") {
                        ForEach(TablePreferenceField.allCases, id: \.self) { field in
                            Button(field.title + " · " + preferenceLabel(field)) {
                                applyPreference(field, tablePreferences.general[field])
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("统一应用设置")
                .accessibilityIdentifier("settings.reapply")
            }
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var frameRateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("球桌帧率")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)
            BTTogglePillGroup(options: RenderFrameRate.allCases,
                              selected: $prefs.renderFrameRate) { $0.displayName }
                .accessibilityIdentifier("settings.frameRate")
            Text("默认 60 帧。更高帧率更流畅，也更耗电；实际帧率受屏幕、温度和低电量模式影响。静止时自动减少重绘。")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xs)
        }
    }

    private var equipmentSection: some View {
        VStack(spacing: 0) {
            equipmentLink("球房风格", value: prefs.roomStyle.displayName,
                          identifier: "settings.roomStyle") { RoomStyleSelectionView() }
            equipmentDivider
            equipmentLink("球桌风格", value: prefs.tableStyle.displayName,
                          identifier: "settings.tableStyle") { TableStyleSelectionView() }
            equipmentDivider
            equipmentLink("台呢颜色", value: prefs.clothColor.displayName,
                          identifier: "settings.clothColor") { ClothColorSelectionView() }
            equipmentDivider
            equipmentLink("球贴纸", value: prefs.ballStickerStyle.displayName,
                          identifier: "settings.ballSticker.open") { BallStickerSettingsView() }
            equipmentDivider
            equipmentLink("球杆外观", value: prefs.cueStyle.displayName,
                          identifier: "settings.cueStyle.open") { CueStyleSettingsView() }
            equipmentDivider
            Toggle("显示颗星参考点", isOn: $prefs.showsTableSights)
                .font(.btBody).foregroundStyle(.btText).tint(.btPrimary)
                .padding(Spacing.lg)
                .accessibilityIdentifier("settings.tableSights")
        }
        .background(Color.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private var equipmentDivider: some View { Divider().padding(.leading, Spacing.lg) }

    private func equipmentLink<Destination: View>(_ title: String, value: String,
                                                   identifier: String,
                                                   @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Spacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.md) {
                        Text(title).font(.btBody).foregroundStyle(.btText).fixedSize()
                        Spacer(minLength: Spacing.sm)
                        Text(value).font(.btSubheadline).foregroundStyle(.btTextSecondary).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title).font(.btBody).foregroundStyle(.btText)
                        Text(value).font(.btSubheadline).foregroundStyle(.btTextSecondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.lg).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("声音")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Toggle(isOn: $prefs.backgroundMusicEnabled) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("背景音乐")
                            .font(.btBody)
                            .foregroundStyle(.btText)
                        Text("在练习页播放")
                            .font(.btFootnote)
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                .tint(.btPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .accessibilityIdentifier("settings.backgroundMusic")

                Divider().padding(.leading, Spacing.lg)

                Toggle(isOn: $prefs.soundEffectsEnabled) {
                    Text("击球音效")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                }
                .tint(.btPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .accessibilityIdentifier("settings.shotSoundEffects")
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Training Aids

    private var dailyClearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("每日清台")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    Label("默认玩法", systemImage: "circle.grid.3x3.fill")
                        .font(.btBody)
                        .foregroundStyle(.btText)

                    Spacer(minLength: Spacing.sm)

                    Picker("默认玩法", selection: Binding(
                        get: { prefs.dailyClearanceGame },
                        set: { prefs.selectDailyClearanceGame($0) }
                    )) {
                        ForEach(DailyClearanceGame.allCases) { game in
                            Text(game.displayName).tag(game)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.btPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("settings.dailyClearanceGame")
                }

                Text("只影响下一个新局；正在进行的清台会保留原玩法。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private func applyPreference(_ field: TablePreferenceField, _ value: Double) {
        tablePreferences.apply(field, value: value)
    }

    private func generalToggle(_ field: TablePreferenceField) -> Binding<Bool> {
        Binding(get: { tablePreferences.general.enabled(field) },
                set: { applyPreference(field, $0 ? 1 : 0) })
    }

    private func preferenceLabel(_ field: TablePreferenceField) -> String {
        let values = tablePreferences.general
        switch field {
        case .view3D: return values.enabled(field) ? "3D" : "2D"
        case .transparency: return "\(Int((values[field] * 100).rounded()))%"
        case .trajectory: return values.trajectoryDetail.label
        default: return values.enabled(field) ? "开启" : "关闭"
        }
    }

    private var practiceDisplaySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("练习显示").font(.btSubheadlineMedium).foregroundStyle(.btTextSecondary)
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("默认视图").font(.btBody)
                    Spacer()
                    BTTogglePillGroup(options: [false, true], selected: generalToggle(.view3D)) { $0 ? "3D" : "2D" }
                }
                .accessibilityIdentifier("settings.defaultView")
                Text("用于同时支持 2D / 3D 的页面；固定视图训练保持原题型。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                NavigationLink { ControlLayoutLibrary() } label: {
                    HStack { Text("操作布局"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                        .frame(minHeight: 44)
                }.accessibilityIdentifier("settings.controlLayout")
                Divider()
                Toggle("台面网格 4×8", isOn: generalToggle(.grid)).accessibilityIdentifier("settings.grid")
                Divider()
                Toggle("瞄准特写", isOn: generalToggle(.closeup)).accessibilityIdentifier("settings.closeup")
                Divider()
                HStack {
                    Text("打点盘透明度")
                    Spacer()
                    Text("\(Int((transparencyDraft * 100).rounded()))%").monospacedDigit()
                }
                Slider(value: $transparencyDraft, in: 0...1, onEditingChanged: { editing in
                    editingTransparency = editing
                    if !editing { applyPreference(.transparency, transparencyDraft) }
                }).accessibilityLabel("打点盘透明度").accessibilityIdentifier("settings.transparency")
                Divider()
                Menu {
                    ForEach(TrajectoryDetail.allCases, id: \.rawValue) { detail in
                        Button { applyPreference(.trajectory, Double(detail.rawValue)) } label: {
                            if detail == tablePreferences.general.trajectoryDetail { Label(detail.label, systemImage: "checkmark") }
                            else { Text(detail.label) }
                        }
                    }
                } label: {
                    HStack {
                        Text("轨迹档位").foregroundStyle(.btText)
                        Spacer()
                        Text(tablePreferences.general.trajectoryDetail.label)
                        Image(systemName: "chevron.up.chevron.down")
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("settings.trajectory")
                Text("选中档位会统一更新，并开启相关页面的 3D 轨迹。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                Toggle("3D 显示轨迹", isOn: generalToggle(.shows3DTrajectory)).accessibilityIdentifier("settings.trajectory3D")
                Text("关闭仅隐藏 3D 预测辅助；再开启时保留各页轨迹档位，2D 不变。")
                    .font(.btCaption).foregroundStyle(.btTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .font(.btBody).foregroundStyle(.btText).tint(.btPrimary)
            .padding(Spacing.lg).background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private var trainingAidSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("击球辅助")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle(isOn: generalToggle(.separation)) {
                    Text("显示 90° 分离角辅助线")
                        .font(.btBody)
                        .foregroundStyle(.btText)
                }
                .tint(.btPrimary)
                Text("在支持的练习页显示分离角参考线，不改变教学图谱本身的轨迹。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Toggle("运杆演示", isOn: generalToggle(.rehearsal))
                    .font(.btBody)
                    .foregroundStyle(.btText)
                    .tint(.btPrimary)
                    .accessibilityIdentifier("settings.cueRehearsal")
                Text("击球前试运一次，展示完整准备节奏。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                .tint(.btPrimary)
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
                if authState.isLoggedIn {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Toggle("训练数据云同步", isOn: Binding(
                            get: { authState.cloudSyncEnabled },
                            set: { authState.setCloudSyncEnabled($0) }
                        ))
                        .font(.btBody)
                        .tint(.btPrimary)
                        .accessibilityIdentifier("settings.cloudSync")
                        Text("关闭后不再上传或下载训练数据，已保存在本机和云端的记录会保留。")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                        Text("同步训练记录、角度与瞄准成绩，以及自定义球形。收藏、计划和训练安排目前仅保存在本机。")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                        if authState.cloudSyncEnabled {
                            Button {
                                guard let userId = authState.currentUser?.id else { return }
                                Task {
                                    await dataCoordinator.handleCompletedLogin(userId: userId, authState: authState)
                                }
                            } label: {
                                Text(dataCoordinator.syncingOwnerKey == ownerContext.ownerKey ? "正在同步…" : "立即同步")
                                    .font(.btCallout)
                                    .foregroundStyle(.btPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(dataCoordinator.syncingOwnerKey == ownerContext.ownerKey)
                            .accessibilityIdentifier("settings.syncNow")
                            if dataCoordinator.statusOwnerKey == ownerContext.ownerKey,
                               let message = dataCoordinator.statusMessage {
                                Text(message)
                                    .font(.btCaption)
                                    .foregroundStyle(.btTextSecondary)
                                    .accessibilityIdentifier("settings.syncStatus")
                            }
                        }
                    }
                    .padding(Spacing.lg)
                    Divider().padding(.leading, Spacing.lg)
                }
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
        let totalBytes = Int64(URLCache.shared.currentDiskUsage) + avatarStore.diskUsage
        if totalBytes < 1024 * 1024 {
            return String(format: "%.0f KB", Double(totalBytes) / 1024.0)
        }
        return String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        _ = avatarStore.clearDiskCache()
        cacheSize = calculateCacheSize()
        Task {
            await avatarStore.load(user: authState.currentUser, ownerKey: ownerContext.ownerKey)
        }
    }

    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        guard let userId = authState.currentUser?.id, authState.isLoggedIn else { return }
        isDeletingAccount = true
        deleteErrorMessage = nil
        showDeleteErrorAlert = false
        Task {
            do {
                try await BackendSyncService.shared.deleteAccount()
                let accountOwner = OwnerKey.account(userId)
                dataCoordinator.markAccountDeletionForLocalCleanup(userId: userId)
                var localDataPreserved = true
                do {
                    try dataCoordinator.preserveDeletedAccountDataAsGuest(userId: userId)
                } catch {
                    localDataPreserved = false
                }
                SyncRestoreService.shared.clearAnchors(userId: userId)
                OwnerProfileStore.removeLocalProfile(ownerKey: accountOwner)
                let clearedAvatarCache = avatarStore.removeCachedAccountData(userId: userId)
                isDeletingAccount = false
                authState.finishAccountDeletion()
                if !localDataPreserved {
                    authState.errorMessage = "账号已注销；本机训练数据将在下次启动时自动恢复为游客数据。"
                } else if !clearedAvatarCache {
                    authState.errorMessage = "账号已注销，但部分本机头像缓存清理失败，请重新打开 App 后清除缓存。"
                }
            } catch {
                deleteErrorMessage = "注销失败，请检查网络后重试。"
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
            .environmentObject(CurrentOwnerContext.shared)
            .environmentObject(AccountDataCoordinator())
            .environmentObject(AvatarStore.shared)
    }
}

#Preview("Settings Dark") {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthState())
            .environmentObject(SubscriptionManager.shared)
            .environmentObject(CurrentOwnerContext.shared)
            .environmentObject(AccountDataCoordinator())
            .environmentObject(AvatarStore.shared)
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
            .environmentObject(CurrentOwnerContext.shared)
            .environmentObject(AccountDataCoordinator())
            .environmentObject(AvatarStore.shared)
    }
}
