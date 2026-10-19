import SwiftUI
import SwiftData

struct ProfileView: View {
    let ownerKey: String
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var avatarStore: AvatarStore
    @Environment(\.calendar) private var calendar
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @StateObject private var profile: OwnerProfileStore
    @State private var showLoginSheet = false
    @State private var pendingLoginUser: AppUser?
    @State private var showSubscription = false
    @State private var showOnboarding = false
    #if DEBUG
    @State private var showIntroStyleLab = false
    #endif

    init(ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.ownerKey = ownerKey
        _profile = StateObject(wrappedValue: OwnerProfileStore(ownerKey: ownerKey))
        _trainingSessions = Query(
            filter: #Predicate { $0.ownerKey == ownerKey },
            sort: \TrainingSession.date,
            order: .reverse
        )
    }

    private let proCardDarkBG = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let proCardSubtitle = Color.white.opacity(0.7)

    var body: some View {
        NavigationStack(path: $router.profilePath) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        if authState.hasLocalAccount {
                            loggedInHeader
                            monthlyOverviewCard
                            if case .offlineAccount = authState.phase {
                                VStack(spacing: Spacing.sm) {
                                    Text("当前离线，可使用本机记录与有效的 Apple 购买权益")
                                        .font(.btCaption).foregroundStyle(.btTextSecondary)
                                    Button("重新连接账号") { Task { await authState.retryBootstrap() } }
                                        .font(.btCallout)
                                }
                            }
                        } else {
                            guestHeader
                            guestWarning
                            proPromotionCard
                        }

                        primaryMenuGroup
                        secondaryMenuGroup

                        if authState.hasLocalAccount {
                            logoutButton
                        } else {
                            guestBottomActions
                        }

                        Text(AppMetadata.versionDisplay)
                            .font(.btCaption)
                            .foregroundStyle(.btTextTertiary)
                            .padding(.top, Spacing.sm)
                            .padding(.bottom, 80)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                }
            }
            .background { BTBlueprintBackground(style: .profile).ignoresSafeArea() }
            .scrollContentBackground(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "favorites":
                    FavoriteDrillsView(ownerKey: ownerKey)
                case "personalInfo":
                    PersonalInfoView(ownerKey: ownerKey, profile: profile)
                case "trainingGoal":
                    TrainingGoalView(ownerKey: ownerKey, profile: profile)
                case "subscriptionStatus":
                    SubscriptionStatusView()
                case "settings":
                    SettingsView()
                case "about":
                    AboutView()
                default:
                    DrillDetailView(drillId: destination, ownerKey: ownerKey)
                }
            }
        }
        .sheet(isPresented: $showLoginSheet, onDismiss: {
            if let user = pendingLoginUser {
                pendingLoginUser = nil
                authState.login(user: user)
            }
        }) {
            LoginView(onAuthenticated: { pendingLoginUser = $0 })
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showIntroStyleLab) { OnboardingStyleLab() }
        #endif
        .alert("开启训练数据云同步？", isPresented: $authState.showCloudSyncPrompt) {
            Button("开启云同步") { authState.setCloudSyncEnabled(true) }
            Button("仅保存在本机", role: .cancel) { authState.setCloudSyncEnabled(false) }
        } message: {
            Text("开启后会上传本机的账号训练记录、成绩和自定义球形，并下载云端数据。你可以随时在设置中关闭，不影响登录和 Pro 权益。")
        }
        .alert("合并本机游客记录？", isPresented: $authState.showMigrationPrompt) {
            Button("合并并同步") { authState.confirmMigration() }
            Button("不合并", role: .cancel) { authState.dismissMigration() }
        } message: {
            Text("合并后，游客期间的数据将归入当前账号，训练记录、角度与瞄准成绩和自定义球形会上传。收藏、计划和训练安排目前仅保存在本机。不合并则保留在游客模式下，账号云同步仍保持开启。")
        }
        .alert("同步失败", isPresented: Binding(
            get: { authState.errorMessage != nil },
            set: { if !$0 { authState.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { authState.errorMessage = nil }
        } message: {
            Text(authState.errorMessage ?? "数据同步失败，稍后会自动重试")
        }
        .task(id: authState.currentUser) {
            profile.load(from: authState.currentUser)
            await avatarStore.load(user: authState.currentUser, ownerKey: ownerKey)
        }
    }

    // MARK: - Logged In Header

    private var loggedInHeader: some View {
        NavigationLink(value: "personalInfo") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    ProfileAvatarView(size: 56, gender: profile.gender)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(profile.displayName)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)
                            .lineLimit(1)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Spacing.sm) { accountID; editProfileLabel }
                            VStack(alignment: .leading, spacing: Spacing.xs) { accountID; editProfileLabel }
                        }
                    }
                    Spacer(minLength: Spacing.sm)
                    BTProfileGameBall(sport: profile.preferredSport, isPremium: subscriptionManager.isPremium)
                }

            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.accountHeader")
        .accessibilityLabel("个人信息，\(profile.displayName)")
        .accessibilityValue(subscriptionManager.isPremium ? "Pro 已解锁" : "普通用户")
    }

    private var accountID: some View {
        Text("ID: \(String(authState.currentUser?.id.prefix(7) ?? "—"))")
            .font(.btCaption).foregroundStyle(.btTextTertiary).fixedSize()
            .accessibilityIdentifier("profile.accountID")
    }

    private var editProfileLabel: some View {
        HStack(spacing: Spacing.xs) {
            Text("修改信息").font(.btCaption)
            Image(systemName: BTIcon.chevronRight).font(.btMicro)
        }
        .foregroundStyle(.btTextSecondary).fixedSize()
        .accessibilityIdentifier("profile.editInfo")
    }

    // MARK: - Monthly Overview

    private var monthlyOverviewCard: some View {
        let overview = TrainingGoalMetrics.monthlyOverview(
            trainingSessions,
            at: .now,
            calendar: calendar
        )
        return ProfileMonthlyOverviewCard(
            trainingDays: overview.trainingDays,
            durationMinutes: overview.durationMinutes,
            longestStreak: overview.longestStreak
        )
    }

    // MARK: - Guest Header

    private var guestHeader: some View {
        Button { showLoginSheet = true } label: {
            HStack(spacing: Spacing.md) {
                ProfileAvatarView(size: 56, gender: profile.gender)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName == "球迹用户" ? "点击登录" : profile.displayName)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text("游客模式 · 点击登录")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer(minLength: Spacing.sm)
                BTProfileGameBall(sport: profile.preferredSport, isPremium: subscriptionManager.isPremium)

                Image(systemName: BTIcon.chevronRight)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.login")
        .accessibilityLabel("\(profile.displayName)，游客模式，点击登录")
    }

    private var guestWarning: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: BTIcon.warningTriangle)
                .font(.btHeadline)
                .foregroundStyle(.btWarning)

            Text("游客记录保存在本机。登录后可自行选择是否开启云同步。")
                .font(.btFootnote)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .background(Color.btWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btWarning.opacity(0.32), lineWidth: 1)
        )
    }

    private var proPromotionCard: some View {
        Button(action: { showSubscription = true }) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("解锁球迹 Pro")
                        .font(.btHeadline).fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("让你的训练更高效")
                        .font(.btCaption)
                        .foregroundStyle(proCardSubtitle)
                    HStack(spacing: Spacing.xs) {
                        Text("了解更多")
                            .font(.btFootnote).fontWeight(.medium)
                            .foregroundStyle(.btPremiumOnDark)
                        Image(systemName: BTIcon.chevronRight)
                            .font(.btMicro).fontWeight(.semibold)
                            .foregroundStyle(.btPremiumOnDark)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.btPremiumSurface.opacity(0.22))
                        .frame(width: 56, height: 56)
                    BTPremiumMaterialSymbol(systemName: BTIcon.star, size: 32)
                }
            }
            .padding(Spacing.xl)
            .background(proCardDarkBG)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary Menu Group

    private var primaryMenuGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(value: "favorites") {
                ProfileMenuRow(
                    icon: BTIcon.heartFilled,
                    foregroundColor: .btPrimary,
                    title: "收藏"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            NavigationLink(value: "personalInfo") {
                ProfileMenuRow(
                    icon: BTIcon.person,
                    title: "个人信息",
                    detail: profile.personalInfoSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            NavigationLink(value: "trainingGoal") {
                ProfileMenuRow(
                    icon: BTIcon.target,
                    foregroundColor: .btPrimary,
                    title: "训练目标",
                    detail: profile.goalSummary
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            subscriptionRow
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    @ViewBuilder
    private var subscriptionRow: some View {
        if subscriptionManager.isPremium {
            NavigationLink(value: "subscriptionStatus") {
                ProfileMenuRow(
                    icon: BTIcon.crown,
                    tint: .accent,
                    usesCrownArtwork: true,
                    title: subscriptionManager.purchasedProductIDs.contains(StoreKitService.lifetimeID)
                        ? "Pro 权益" : "订阅管理",
                    detail: subscriptionManager.entitlementStatusLabel,
                    detailColor: .btTextSecondary
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.subscription")
        } else {
            Button { showSubscription = true } label: {
                ProfileMenuRow(
                    icon: BTIcon.crown,
                    tint: .accent,
                    usesCrownArtwork: true,
                    title: "订阅管理",
                    detail: "升级 Pro",
                    detailColor: .btPremiumForeground
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.subscription")
        }
    }

    // MARK: - Secondary Menu Group

    private var secondaryMenuGroup: some View {
        VStack(spacing: 0) {
            NavigationLink(value: "settings") {
                ProfileMenuRow(
                    icon: BTIcon.gear,
                    tint: .neutral,
                    title: "设置"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 56)

            Button { showOnboarding = true } label: {
                ProfileMenuRow(
                    icon: "book.closed",
                    tint: .neutral,
                    foregroundColor: .btPrimary,
                    title: "认识球迹"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.onboarding")
            #if DEBUG
            Divider().padding(.leading, 56)
            Button { showIntroStyleLab = true } label: {
                ProfileMenuRow(icon: "rectangle.3.group", title: "引导设计预览")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.introStyleLab")
            #endif

            Divider().padding(.leading, 56)

            NavigationLink(value: "about") {
                ProfileMenuRow(
                    icon: BTIcon.info,
                    title: "关于与反馈"
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            Task { await authState.logout() }
        } label: {
            Text("退出登录")
                .font(.btHeadline)
                .foregroundStyle(.btDestructive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guest Bottom Actions

    private var guestBottomActions: some View {
        Text("当前已是游客模式，训练记录仅保存在本机")
            .font(.btCaption)
            .foregroundStyle(.btTextTertiary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("游客模式，训练记录仅保存在本机")
    }
}

struct ProfileMonthlyOverviewCard: View {
    let trainingDays: Int
    let durationMinutes: Int
    let longestStreak: Int
    @Environment(\.colorScheme) private var colorScheme

    private var durationValue: Text {
        let hours = max(0, durationMinutes) / 60
        let minutes = max(0, durationMinutes) % 60
        if hours == 0 { return number(minutes) + unit(" 分") }
        if minutes == 0 { return number(hours) + unit(" 小时") }
        return number(hours) + unit(" 小时 ") + number(minutes) + unit(" 分")
    }

    private var durationLabel: String {
        let hours = max(0, durationMinutes) / 60
        let minutes = max(0, durationMinutes) % 60
        if hours == 0 { return "\(minutes)分钟" }
        if minutes == 0 { return "\(hours)小时" }
        return "\(hours)小时\(minutes)分钟"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("本月概览", systemImage: BTIcon.calendar)
                .font(.btFootnote.weight(.semibold))
                .foregroundStyle(.btTextSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { metrics(compact: false) }
                VStack(spacing: Spacing.sm) { metrics(compact: true) }
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    @ViewBuilder private func metrics(compact: Bool) -> some View {
        statColumn(value: number(trainingDays) + unit(" 天"), label: "练习天数",
                   spokenValue: "\(trainingDays)天", identifier: "trainingDays", color: .btOverviewDays, compact: compact)
        statColumn(value: durationValue, label: "训练时长", spokenValue: durationLabel,
                   identifier: "duration", color: .btOverviewDuration, compact: compact)
        statColumn(value: number(longestStreak) + unit(" 天"), label: "连续练习",
                   spokenValue: "本月最长连续\(longestStreak)天", identifier: "longestStreak",
                   color: .btOverviewStreak, compact: compact)
    }

    private func number(_ value: Int) -> Text {
        Text("\(value)").font(.btTitle).monospacedDigit()
    }

    private func unit(_ value: String) -> Text {
        Text(value).font(.btCaption)
    }

    private func statColumn(value: Text, label: String, spokenValue: String,
                            identifier: String, color: Color, compact: Bool) -> some View {
        Group {
            if compact {
                HStack(spacing: Spacing.md) {
                    Text(label).font(.btCaption).fixedSize()
                    Spacer(minLength: Spacing.sm)
                    value.fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(spacing: Spacing.sm) {
                    value.fixedSize(horizontal: true, vertical: false)
                    Text(label).font(.btCaption).fixedSize()
                }
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(color.opacity(colorScheme == .dark ? 0.16 : 0.08),
                    in: RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("profile.monthlyOverview.\(identifier)")
        .accessibilityLabel("\(label)，\(spokenValue)")
    }
}

// MARK: - Profile Menu Row

private struct ProfileMenuRow: View {
    let icon: String
    var tint: BTIconBadge.Tint = .neutral
    var foregroundColor: Color? = nil
    var usesCrownArtwork = false
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var detail: String? = nil
    var detailColor: Color = .btTextSecondary

    var body: some View {
        HStack(spacing: Spacing.md) {
            Group {
                if usesCrownArtwork {
                    BTProfileCrown(width: 24)
                        .frame(width: 32, height: 32)
                        .background(tint.background(colorScheme), in: Circle())
                } else {
                    BTIconBadge(systemName: icon, size: 32, tint: tint, foregroundColor: foregroundColor)
                }
            }
            .frame(width: 40)
            .accessibilityHidden(true)

            Text(title)
                .font(.btCallout)
                .foregroundStyle(.btText)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.btCaption)
                    .foregroundStyle(detailColor)
            }

            Image(systemName: BTIcon.chevronRight)
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
        .environmentObject(AvatarStore.shared)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}

#Preview("Logged In") {
    let state = AuthState()
    state.login(user: AppUser(id: "2086753", provider: .apple, displayName: "台球小王子"))
    return ProfileView()
        .environmentObject(state)
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AvatarStore.shared)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}

#Preview("Guest Dark") {
    ProfileView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AvatarStore.shared)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
        .preferredColorScheme(.dark)
}

#Preview("Logged In Dark") {
    let state = AuthState()
    state.login(user: AppUser(id: "2086753", provider: .apple, displayName: "台球小王子"))
    return ProfileView()
        .environmentObject(state)
        .environmentObject(AppRouter())
        .environmentObject(SubscriptionManager.shared)
        .environmentObject(AvatarStore.shared)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer())
        .preferredColorScheme(.dark)
}
