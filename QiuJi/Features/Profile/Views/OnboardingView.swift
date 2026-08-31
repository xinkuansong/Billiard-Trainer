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
                        mode: .route,
                        title: "看懂球路，再开始练",
                        subtitle: "瞄准点、碰撞点与行进路径\n让每一杆先有清晰目标"
                    )
                    .tag(0)

                    featurePage(
                        mode: .review,
                        title: "记录每杆，复盘趋势",
                        subtitle: "训练记录沉淀为进度与薄弱项\n下一次练习更有方向"
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
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    // MARK: - Feature Page (Page 1 & 2)

    private func featurePage(
        mode: ProfileBrandTrainingHero.Mode,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)

            ProfileBrandTrainingHero(mode: mode)
                .frame(height: 220)
                .padding(.horizontal, Spacing.xxl)
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

            Spacer(minLength: Spacing.xl)
        }
    }

    // MARK: - Login Page (Page 3)

    private var loginPage: some View {
        VStack(spacing: 0) {
            Spacer()

            ProfileBrandTrainingHero(mode: .identity)
                .frame(height: 176)
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xl)

            Text("球迹")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
                .padding(.bottom, Spacing.xs)

            Text("球路计算 · 训练记录 · 数据复盘")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Spacer()

            VStack(spacing: Spacing.xxxl) {
                OnboardingFeatureRow(
                    leading: { AnyView(Image(systemName: "square.grid.2x2.fill").font(.btTitle).foregroundStyle(.btPrimary)) },
                    title: "球路计算与动作训练",
                    subtitle: "从瞄准路径到专项动作，目标更清楚"
                )
                OnboardingFeatureRow(
                    leading: { AnyView(Image(systemName: "angle").font(.btTitle).foregroundStyle(.btPrimary)) },
                    title: "角度训练",
                    subtitle: "模拟球台场景，提升角度判断力"
                )
                OnboardingFeatureRow(
                    leading: { AnyView(Image(systemName: "chart.bar.fill").font(.btTitle).foregroundStyle(.btPrimary)) },
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
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
            } else {
                Button("开始使用") {
                    authState.loginAnonymously()
                }
                .buttonStyle(BTButtonStyle.primary)

                Button("登录已有账号") {
                    showLogin = true
                }
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
                .padding(.top, 6)
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
                    .animation(BTMotion.easeInOutChrome, value: currentPage)
            }
        }
    }

}

// MARK: - Feature Row

private struct OnboardingFeatureRow: View {
    let leading: () -> AnyView
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: 48, height: 48)
                leading()
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btSubheadline)
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
