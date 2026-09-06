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
    @State private var showSubscription = false
    @State private var showOnboarding = false

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
                        if authState.isLoggedIn {
                            loggedInHeader
                            monthlyOverviewCard
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
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .alert("开启训练数据云同步？", isPresented: $authState.showCloudSyncPrompt) {
            Button("开启云同步") { authState.setCloudSyncEnabled(true) }
            Button("仅保存在本机", role: .cancel) { authState.setCloudSyncEnabled(false) }
        } message: {
            Text("开启后会上传本机的账号训练记录，并下载云端记录。你可以随时在偏好设置中关闭，不影响登录和 Pro 权益。")
        }
        .alert("合并本机游客记录？", isPresented: $authState.showMigrationPrompt) {
            Button("合并并同步") { authState.confirmMigration() }
            Button("不合并", role: .cancel) { authState.dismissMigration() }
        } message: {
            Text("合并后，游客期间的记录将归入当前账号并上传。不合并则保留在游客模式下，账号云同步仍保持开启。")
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
                    ProfileAvatarView(size: 56)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.xs) {
                            Text("修改信息")
                                .font(.btCaption)
                                .foregroundStyle(.btTextSecondary)
                            Image(systemName: BTIcon.chevronRight)
                                .font(.btMicro)
                                .foregroundStyle(.btTextTertiary)
                        }
                        Text("ID: \(String(authState.currentUser?.id.prefix(7) ?? "—"))")
                            .font(.btCaption)
                            .foregroundStyle(.btTextTertiary)
                    }
                    Spacer(minLength: Spacing.sm)
                }

                if subscriptionManager.isPremium {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        BTPremiumMaterialSymbol(systemName: BTIcon.star, size: 18)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Pro 会员")
                                .font(.btCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.btPremiumForeground)
                            Text(subscriptionManager.entitlementStatusLabel)
                                .font(.btCaption)
                                .foregroundStyle(.btTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.btPremiumSurface, in: RoundedRectangle(cornerRadius: BTRadius.sm))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile.membershipSummary")
                }
            }
            .padding(Spacing.lg)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile.accountHeader")
        .accessibilityLabel("个人信息，\(profile.displayName)")
    }

    // MARK: - Monthly Overview

    private var monthlyOverviewCard: some View {
        let overview = TrainingGoalMetrics.monthlyOverview(
            trainingSessions,
            at: .now,
            calendar: calendar
        )
        return ProfileMonthlyOverviewCard(
            trainingDays: "\(overview.trainingDays)",
            duration: overview.formattedDuration,
            longestStreak: "\(overview.longestStreak)"
        )
    }

    // MARK: - Guest Header

    private var guestHeader: some View {
        Button { showLoginSheet = true } label: {
            HStack(spacing: Spacing.md) {
                ProfileAvatarView(size: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName == "球迹用户" ? "点击登录" : profile.displayName)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text("游客模式 · 点击登录")
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                Image(systemName: BTIcon.chevronRight)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(Spacing.lg)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
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
                    title: "我的收藏"
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
                    title: subscriptionManager.purchasedProductIDs.contains(StoreKitService.lifetimeID)
                        ? "Pro 权益" : "订阅管理",
                    detail: subscriptionManager.entitlementStatusLabel,
                    detailColor: .btTextSecondary
                )
            }
            .buttonStyle(.plain)
        } else {
            Button { showSubscription = true } label: {
                ProfileMenuRow(
                    icon: BTIcon.crown,
                    tint: .accent,
                    title: "订阅管理",
                    detail: "升级 Pro",
                    detailColor: .btPremiumForeground
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Secondary Menu Group

    private var secondaryMenuGroup: some View {
        VStack(spacing: 0) {
            Button { showOnboarding = true } label: {
                ProfileMenuRow(
                    icon: "book.closed",
                    tint: .neutral,
                    title: "认识球迹"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.onboarding")

            Divider().padding(.leading, 56)

            NavigationLink(value: "settings") {
                ProfileMenuRow(
                    icon: BTIcon.gear,
                    tint: .neutral,
                    title: "偏好设置"
                )
            }
            .buttonStyle(.plain)

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
    let trainingDays: String
    let duration: String
    let longestStreak: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: BTIcon.calendar)
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextSecondary)
                Text("本月概览")
                    .font(.btFootnote.weight(.semibold))
                    .foregroundStyle(.btTextSecondary)
            }

            HStack(spacing: 0) {
                statColumn(
                    value: trainingDays,
                    label: "练习天数",
                    identifier: "profile.monthlyOverview.trainingDays",
                    valueColor: .btPrimary
                )
                Divider().frame(height: 32).overlay(Color.btSeparator)
                statColumn(
                    value: duration,
                    label: "训练时长",
                    identifier: "profile.monthlyOverview.duration",
                    valueColor: .btPrimary
                )
                Divider().frame(height: 32).overlay(Color.btSeparator)
                statColumn(
                    value: longestStreak,
                    label: "最长连续",
                    identifier: "profile.monthlyOverview.longestStreak",
                    valueColor: .btSuccess
                )
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func statColumn(value: String,
                            label: String,
                            identifier: String,
                            valueColor: Color = .btText) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.btTitle)
                .foregroundStyle(valueColor)
                .monospacedDigit()
            Text(label)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(label)，\(value)")
    }
}

// MARK: - Profile Menu Row

private struct ProfileMenuRow: View {
    let icon: String
    var tint: BTIconBadge.Tint = .neutral
    let title: String
    var detail: String? = nil
    var detailColor: Color = .btTextSecondary

    var body: some View {
        HStack(spacing: Spacing.md) {
            BTIconBadge(systemName: icon, size: 32, tint: tint)
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
