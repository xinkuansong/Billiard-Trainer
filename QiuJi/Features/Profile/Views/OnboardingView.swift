import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authState: AuthState
    @State private var showLogin = false

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Hero 区域
                VStack(spacing: Spacing.xl) {
                    Image(systemName: "figure.pool.swim")
                        .font(.system(size: 72))
                        .foregroundStyle(.btPrimary)

                    VStack(spacing: Spacing.sm) {
                        Text("球迹")
                            .font(.btLargeTitle)
                            .foregroundStyle(.btText)
                        Text("台球训练，从记录开始")
                            .font(.btTitle2)
                            .foregroundStyle(.btTextSecondary)
                    }
                }

                Spacer()

                // MARK: - 核心价值点
                VStack(spacing: Spacing.lg) {
                    FeatureRow(icon: "chart.line.uptrend.xyaxis",
                               title: "追踪进球率",
                               subtitle: "每次训练数据精准记录，看见成长曲线")
                    FeatureRow(icon: "list.bullet.rectangle",
                               title: "系统动作库",
                               subtitle: "80+ 基础到高阶练习，按体系分级训练")
                    FeatureRow(icon: "angle",
                               title: "角度速查",
                               subtitle: "击球角度快查，训练更有针对性")
                }
                .padding(.horizontal, Spacing.xxl)

                Spacer()

                // MARK: - 操作按钮
                VStack(spacing: Spacing.md) {
                    Button("开始使用") {
                        authState.loginAnonymously()
                    }
                    .buttonStyle(BTButtonStyle.primary)

                    Button("已有账号，登录") {
                        showLogin = true
                    }
                    .buttonStyle(BTButtonStyle.text)
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

// MARK: - 特性行

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.btPrimary)
                .frame(width: 40)

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
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}

#Preview("Light") {
    OnboardingView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
}

#Preview("Dark") {
    OnboardingView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
