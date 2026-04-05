import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var prefs = UserPreferences.shared
    @State private var showLoginSheet = false
    @State private var showSubscription = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false

    /// Fixed light text on guaranteed-dark promo card background
    private let proCardSubtitle = Color.white.opacity(0.7)

    var body: some View {
        NavigationStack(path: $router.profilePath) {
            ZStack {
                Color.btBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        HStack {
                            Text("我的")
                                .font(.btTitle)
                                .foregroundStyle(.btText)
                            Spacer()
                        }

                        if authState.isLoggedIn {
                            loggedInHeader
                            monthlyOverview
                        } else {
                            guestHeader
                            guestWarning
                            proPromotionCard
                        }

                        primaryMenuGroup
                        secondaryMenuGroup

                        if authState.isLoggedIn {
                            logoutButton
                        } else {
                            guestBottomActions
                        }

                        Text("版本 1.0.0")
                            .font(.btCaption)
                            .foregroundStyle(.btTextTertiary)
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, Spacing.xxxl)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "favorites":
                    FavoriteDrillsView()
                        .navigationDestination(for: String.self) { drillId in
                            DrillDetailView(drillId: drillId)
                        }
                case "settings":
                    SettingsView()
                default:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .alert("数据同步", isPresented: $authState.showMigrationPrompt) {
            Button("立即同步") { authState.confirmMigration() }
            Button("暂不同步", role: .cancel) { authState.dismissMigration() }
        } message: {
            Text("检测到本地训练记录，登录后可同步至云端，换机也不会丢失。")
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

    // MARK: - Logged In Header

    private var loggedInHeader: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.fill")
                    .font(.btTitle)
                    .foregroundStyle(.btPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(authState.currentUser?.displayName ?? "球迹用户")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                HStack(spacing: Spacing.xs) {
                    Text("修改信息")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                    Image(systemName: "chevron.right")
                        .font(.btMicro)
                        .foregroundStyle(.btTextTertiary)
                }
                Text("ID: \(String(authState.currentUser?.id.prefix(7) ?? "—"))")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            Spacer()

            if subscriptionManager.isPremium {
                VStack(spacing: 2) {
                    Text("Pro 会员")
                        .font(.btCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.btAccent)
                    Text("2027.04 到期")
                        .font(.btMicro)
                        .foregroundStyle(.btTextSecondary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Monthly Overview

    private var monthlyOverview: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextSecondary)
                Text("本月概览")
                    .font(.btFootnote.weight(.semibold))
                    .foregroundStyle(.btTextSecondary)
            }

            HStack(spacing: 0) {
                statColumn(value: "—", label: "练习天数", valueColor: .btPrimary)
                Divider().frame(height: 32).overlay(Color.btSeparator)
                statColumn(value: "—", label: "训练时长", valueColor: .btPrimary)
                Divider().frame(height: 32).overlay(Color.btSeparator)
                statColumn(value: "—", label: "连续打卡", valueColor: .btAccent)
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func statColumn(value: String, label: String, valueColor: Color = .btText) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.btTitle)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Guest Header

    private var guestHeader: some View {
        Button { showLoginSheet = true } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.btBGTertiary)
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.btTitle)
                        .foregroundStyle(.btTextTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("点击登录")
                        .font(.btHeadline)
                        .foregroundStyle(.btPrimary)
                    Text("游客模式")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(Spacing.lg)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .buttonStyle(.plain)
    }

    private var guestWarning: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.btHeadline)
                .foregroundStyle(.btAccent)

            Text("游客模式下训练数据不会同步到云端，请尽快登录以保存您的练球记录。")
                .font(.btFootnote)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.btAccent.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btAccent.opacity(0.3), lineWidth: 1)
        )
    }

    private var proPromotionCard: some View {
        Button(action: { showSubscription = true }) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("解锁球迹 Pro")
                        .font(.btHeadline).fontWeight(.bold)
                        .foregroundStyle(.btAccent)
                    Text("让你的训练更高效")
                        .font(.btCaption)
                        .foregroundStyle(proCardSubtitle)
                    HStack(spacing: Spacing.xs) {
                        Text("了解更多")
                            .font(.btFootnote).fontWeight(.medium)
                            .foregroundStyle(.btAccent)
                        Image(systemName: "chevron.right")
                            .font(.btMicro).fontWeight(.semibold)
                            .foregroundStyle(.btAccent)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.btAccent.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "star.fill")
                        .font(.btStatNumber)
                        .foregroundStyle(.btAccent)
                }
            }
            .padding(Spacing.xl)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary Menu Group

    private var primaryMenuGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(value: "favorites") {
                ProfileMenuRow(
                    icon: "heart.fill",
                    iconBG: Color.red.opacity(0.12),
                    iconColor: .red,
                    title: "我的收藏"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            NavigationLink(value: "settings") {
                ProfileMenuRow(
                    icon: "person.fill",
                    iconBG: Color.blue.opacity(0.12),
                    iconColor: .blue,
                    title: "个人信息",
                    detail: prefs.sportSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            NavigationLink(value: "settings") {
                ProfileMenuRow(
                    icon: "target",
                    iconBG: Color.btPrimary.opacity(0.12),
                    iconColor: .btPrimary,
                    title: "训练目标",
                    detail: prefs.goalSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            Button { showSubscription = true } label: {
                ProfileMenuRow(
                    icon: "crown.fill",
                    iconBG: Color.btAccent.opacity(0.12),
                    iconColor: .btAccent,
                    title: "订阅管理",
                    detail: subscriptionManager.isPremium ? "Pro 年度会员" : "升级 Pro",
                    detailColor: subscriptionManager.isPremium ? .btTextSecondary : .btPrimary
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Secondary Menu Group

    private var secondaryMenuGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(value: "settings") {
                ProfileMenuRow(
                    icon: "gearshape.fill",
                    iconBG: Color.gray.opacity(0.12),
                    iconColor: .gray,
                    title: "偏好设置"
                )
            }
            .buttonStyle(.plain)

            if authState.isLoggedIn {
                Divider().padding(.leading, 56)

                Button { showDeleteConfirmation = true } label: {
                    ProfileMenuRow(
                        icon: "shield.fill",
                        iconBG: Color.blue.opacity(0.12),
                        iconColor: .blue,
                        title: "账号注销",
                        detail: nil,
                        detailColor: .btDestructive
                    )
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.leading, 56)

            Button {
                if let url = URL(string: "https://qiuji.app/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                ProfileMenuRow(
                    icon: "checkmark.shield.fill",
                    iconBG: Color.btPrimary.opacity(0.12),
                    iconColor: .btPrimary,
                    title: "隐私政策"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            ProfileMenuRow(
                icon: "info.circle.fill",
                iconBG: Color.purple.opacity(0.12),
                iconColor: .purple,
                title: "关于与反馈"
            )
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            authState.logout()
        } label: {
            Text("退出登录")
                .font(.btHeadline)
                .foregroundStyle(.btDestructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account Deletion

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

    // MARK: - Guest Bottom Actions

    private var guestBottomActions: some View {
        VStack(spacing: Spacing.md) {
            Button("登录 / 注册") {
                showLoginSheet = true
            }
            .buttonStyle(BTButtonStyle.primary)

            Button("跳过，以游客身份继续") {}
                .buttonStyle(BTButtonStyle.text)
        }
    }
}

// MARK: - Profile Menu Row

private struct ProfileMenuRow: View {
    let icon: String
    let iconBG: Color
    let iconColor: Color
    let title: String
    var detail: String? = nil
    var detailColor: Color = .btTextSecondary

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconBG)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.btSubheadline)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40)

            Text(title)
                .font(.btCallout)
                .foregroundStyle(.btText)

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
}

// MARK: - Previews

#Preview("Guest") {
    ProfileView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Logged In") {
    let state = AuthState()
    state.login(user: AppUser(id: "2086753", provider: .apple, displayName: "台球小王子"))
    return ProfileView()
        .environmentObject(state)
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Guest Dark") {
    ProfileView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}

#Preview("Logged In Dark") {
    let state = AuthState()
    state.login(user: AppUser(id: "2086753", provider: .apple, displayName: "台球小王子"))
    return ProfileView()
        .environmentObject(state)
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .preferredColorScheme(.dark)
}
