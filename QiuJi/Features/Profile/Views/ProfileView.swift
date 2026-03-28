import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var router: AppRouter
    @State private var showLoginSheet = false

    var body: some View {
        NavigationStack(path: $router.profilePath) {
            ZStack {
                Color.btBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        if authState.isLoggedIn {
                            LoggedInHeaderView()
                        } else {
                            GuestHeaderView(onLoginTap: { showLoginSheet = true })
                        }

                        Divider()
                            .padding(.vertical, Spacing.lg)

                        ProfileMenuSection()
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .alert("数据同步", isPresented: $authState.showMigrationPrompt) {
            Button("立即同步") { authState.confirmMigration() }
            Button("暂不同步", role: .cancel) { authState.dismissMigration() }
        } message: {
            Text("检测到本地训练记录，登录后可同步至云端，换机也不会丢失。")
        }
    }
}

// MARK: - 未登录头部

private struct GuestHeaderView: View {
    let onLoginTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(Color.btBGSecondary)
                    .frame(width: 80, height: 80)
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.btTextTertiary)
            }

            VStack(spacing: Spacing.sm) {
                Text("未登录")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Text("登录后数据云端同步，换机不丢失")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onLoginTap) {
                Text("立即登录")
                    .font(.btHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color.btPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .padding(.horizontal, Spacing.xxl)

            HStack(spacing: Spacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                Text("本地数据安全保存中")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - 已登录头部

private struct LoggedInHeaderView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.btBGSecondary)
                    .frame(width: 80, height: 80)
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.btPrimary)

                Circle()
                    .fill(Color.btBG)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: providerIcon)
                            .font(.system(size: 13))
                            .foregroundStyle(providerColor)
                    }
            }

            VStack(spacing: Spacing.xs) {
                Text(authState.currentUser?.displayName ?? "球迹用户")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Text(providerLabel)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.btCaption)
                    .foregroundStyle(.btSuccess)
                Text("数据已云端同步")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
        }
        .padding(.bottom, Spacing.xl)
    }

    private var providerIcon: String {
        switch authState.currentUser?.provider {
        case .apple:  return "applelogo"
        case .phone:  return "phone.fill"
        case .wechat: return "message.fill"
        default:      return "person.fill"
        }
    }

    private var providerColor: Color {
        switch authState.currentUser?.provider {
        case .apple:  return .btText
        case .phone:  return .btPrimary
        case .wechat: return .green
        default:      return .btTextTertiary
        }
    }

    private var providerLabel: String {
        switch authState.currentUser?.provider {
        case .apple:  return "Apple ID 登录"
        case .phone:  return authState.currentUser?.phoneNumber ?? "手机号登录"
        case .wechat: return "微信登录"
        default:      return ""
        }
    }
}

// MARK: - 菜单区域

private struct ProfileMenuSection: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if authState.isLoggedIn {
                MenuRow(icon: "icloud.and.arrow.up", title: "同步数据", color: .btPrimary) {}
            }
            MenuRow(icon: "questionmark.circle", title: "帮助与反馈", color: .btAccent) {}
            MenuRow(icon: "doc.text", title: "隐私政策", color: .btTextSecondary) {}
            MenuRow(icon: "info.circle", title: "关于球迹", color: .btTextSecondary) {}

            if authState.isLoggedIn {
                Button {
                    authState.logout()
                } label: {
                    Text("退出登录")
                        .font(.btBody)
                        .foregroundStyle(.btDestructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                }
                .padding(.top, Spacing.lg)
            }
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
                    .frame(width: 28)
                Text(title)
                    .font(.btBody)
                    .foregroundStyle(.btText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.lg)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }
}

// MARK: - Previews

#Preview("未登录") {
    ProfileView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
}

#Preview("已登录 Apple") {
    let state = AuthState()
    state.login(user: AppUser(id: "1", provider: .apple, displayName: "张三"))
    return ProfileView()
        .environmentObject(state)
        .environmentObject(AppRouter())
}

#Preview("Dark") {
    ProfileView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
