import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var currentPage = 0
    @State private var showLogin = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    featurePage(
                        icon: "figure.pool.swim",
                        iconSize: 36,
                        title: "动作库与训练记录",
                        subtitle: "海量练习动作，科学训练方案\n轻松记录每一次进步"
                    )
                    .tag(0)

                    featurePage(
                        icon: "angle",
                        iconSize: 36,
                        title: "角度感知训练",
                        subtitle: "模拟球台场景，精准角度判断\n系统化提升你的比赛直觉"
                    )
                    .tag(1)

                    loginPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                bottomBar
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xxxl)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    // MARK: - Feature Page (Page 1 & 2)

    private func featurePage(icon: String, iconSize _: CGFloat, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: icon)
                    .font(.btLargeTitle)
                    .foregroundStyle(.btPrimary)
            }
            .padding(.bottom, Spacing.xxxl)

            Text(title)
                .font(.btTitle2)
                .foregroundStyle(.btText)
                .padding(.bottom, Spacing.sm)

            Text(subtitle)
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Login Page (Page 3)

    private var loginPage: some View {
        VStack(spacing: 0) {
            Spacer()

            appLogo
                .padding(.bottom, Spacing.xxl)

            Text("球迹")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
                .padding(.bottom, Spacing.xs)

            Text("你的台球训练伙伴")
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)

            Spacer()

            VStack(spacing: Spacing.xl) {
                OnboardingFeatureRow(
                    icon: "figure.pool.swim",
                    title: "动作库与训练记录",
                    subtitle: "海量练习动作，轻松记录训练"
                )
                OnboardingFeatureRow(
                    icon: "angle",
                    title: "角度训练",
                    subtitle: "模拟球台场景，提升角度判断力"
                )
                OnboardingFeatureRow(
                    icon: "chart.bar.fill",
                    title: "数据统计与复盘",
                    subtitle: "可视化训练进度，发现薄弱项"
                )
            }
            .padding(.horizontal, Spacing.xxl)

            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: Spacing.md) {
            pageIndicator
                .padding(.bottom, Spacing.lg)

            if currentPage < totalPages - 1 {
                Button("继续") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(BTButtonStyle.primary)

                Button("跳过") {
                    authState.loginAnonymously()
                }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
            } else {
                Button("开始使用") {
                    authState.loginAnonymously()
                }
                .buttonStyle(BTButtonStyle.primary)

                Button("登录已有账号") {
                    showLogin = true
                }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.btPrimary : Color.btPrimary.opacity(0.2))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    // MARK: - App Logo

    private var appLogo: some View {
        ZStack {
            Circle()
                .fill(Color.btBGTertiary)
                .frame(width: 100, height: 100)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.btPrimary)
                    .frame(width: 40, height: 28)
                    .overlay(
                        Text("QJ")
                            .font(.btFootnote.weight(.bold))
                            .foregroundStyle(.white)
                    )
            }
            .offset(y: 4)
        }
    }
}

// MARK: - Feature Row

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.btTitle)
                    .foregroundStyle(.btPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
}
