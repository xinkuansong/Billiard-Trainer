import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authState: AuthState
    @State private var selectedFlow: LoginFlow?
    @State private var isAppleSignInLoading = false
    @State private var errorMessage: String?

    private static let wechatGreen = Color(red: 0.027, green: 0.757, blue: 0.376)

    enum LoginFlow: Identifiable {
        case phone
        var id: Self { self }
    }

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Spacing.xl)

                ProfileBrandTrainingHero(mode: .identity)
                    .frame(height: 208)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xl)

                Text("看懂球路，练出结果")
                    .font(.btChapterNumber)
                    .foregroundStyle(.btText)
                    .padding(.bottom, Spacing.sm)

                Text("登录后同步训练记录与复盘数据")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .padding(.bottom, Spacing.xxxl)

                if let msg = errorMessage {
                    Text(msg)
                        .font(.btFootnote)
                        .foregroundStyle(.btDestructive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.bottom, Spacing.md)
                }

                loginButtons

                Spacer(minLength: Spacing.lg)

                Button("暂不登录，匿名使用") {
                    authState.loginAnonymously()
                    dismiss()
                }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .padding(.bottom, Spacing.xxl)

                VStack(spacing: 2) {
                    Text("登录即表示您同意")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                    HStack(spacing: 4) {
                        Text("用户协议")
                            .font(.btCaption)
                            .foregroundStyle(.btPrimary)
                            .underline()
                        Text("和")
                            .font(.btCaption)
                            .foregroundStyle(.btTextTertiary)
                        Text("隐私政策")
                            .font(.btCaption)
                            .foregroundStyle(.btPrimary)
                            .underline()
                    }
                }
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .sheet(item: $selectedFlow) { flow in
            switch flow {
            case .phone:
                PhoneLoginView()
            }
        }
    }

    // MARK: - Login Buttons

    private var loginButtons: some View {
        VStack(spacing: Spacing.md) {
            Button {
                signInWithApple()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isAppleSignInLoading {
                        ProgressView()
                            .tint(colorScheme == .dark ? .black : .white)
                    } else {
                        Image(systemName: "applelogo")
                    }
                    Text("通过 Apple 登录")
                }
                .font(.btHeadline)
                .foregroundStyle(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(colorScheme == .dark ? Color.white : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
            // F-PF-04: keep plain tint semantics (FL-004/008); add scale via BTPressableStyle.
            .buttonStyle(BTPressableStyle.capsule)
            .disabled(isAppleSignInLoading)

            Button {
                // T-P1-08 WeChat login (pending H-05)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "message.fill")
                    Text("微信登录")
                }
                .font(.btHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Self.wechatGreen)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            }
            .buttonStyle(BTPressableStyle.capsule)

            Button {
                selectedFlow = .phone
            } label: {
                Text("手机号登录")
                    .font(.btHeadline)
                    .foregroundStyle(colorScheme == .dark ? .btPrimary : .btText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(colorScheme == .dark ? Color.btBGTertiary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(colorScheme == .dark ? Color.btPrimary : Color.btSeparator, lineWidth: 1)
                    )
            }
            .buttonStyle(BTPressableStyle.capsule)
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Sign in with Apple

    private func signInWithApple() {
        guard !isAppleSignInLoading else { return }
        isAppleSignInLoading = true
        errorMessage = nil
        Task {
            defer { isAppleSignInLoading = false }
            do {
                let user = try await AuthService.shared.loginWithApple()
                authState.login(user: user)
                dismiss()
            } catch let error as AppError {
                if case .authFailed(let msg) = error, msg == "已取消 Apple 登录" {
                    return
                }
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Apple 登录失败，请重试"
            }
        }
    }
}

/// Profile 页面族私有的品牌构图：使用屏幕局部归一化坐标表达瞄准、碰撞与复盘，
/// 只承担产品识别，不声明真实球桌角度、袋口或物理结果。
struct ProfileBrandTrainingHero: View {
    enum Mode {
        case route
        case review
        case identity

        var eyebrow: String {
            switch self {
            case .route: return "球路计算"
            case .review: return "训练复盘"
            case .identity: return "球迹 · QIUJI"
            }
        }

        var footer: String {
            switch self {
            case .route: return "瞄准点 · 碰撞点 · 行进路径"
            case .review: return "训练量 · 趋势 · 薄弱项"
            case .identity: return "球路计算 · 训练记录 · 数据复盘"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .route: return "球路计算示意"
            case .review: return "训练复盘示意"
            case .identity: return "球迹，球路计算、训练记录与数据复盘"
            }
        }
    }

    let mode: Mode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.btBGSecondary,
                                Color.btPrimary.opacity(colorScheme == .dark ? 0.12 : 0.07),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                            .stroke(Color.btPrimary.opacity(0.16), lineWidth: 1)
                    }

                routeDiagram(width: width, height: height)

                VStack(spacing: 0) {
                    HStack(spacing: Spacing.sm) {
                        BTBrandLogo(size: 34, style: .onDisc)
                        Text(mode.eyebrow)
                            .font(.btSubheadlineSemibold)
                            .foregroundStyle(.btPrimary)
                        Spacer()
                        Text("路径 / 复盘")
                            .font(.btCaption2)
                            .foregroundStyle(.btTextTertiary)
                    }

                    Spacer()

                    Text(mode.footer)
                        .font(.btCaption2)
                        .foregroundStyle(.btTextSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.btBG.opacity(colorScheme == .dark ? 0.72 : 0.82))
                        .clipShape(Capsule())
                }
                .padding(Spacing.lg)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.accessibilityLabel)
    }

    private func routeDiagram(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: width * 0.20, y: height * 0.64))
                path.addLine(to: CGPoint(x: width * 0.55, y: height * 0.48))
            }
            .stroke(
                Color.btPrimary.opacity(colorScheme == .dark ? 0.72 : 0.54),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            Path { path in
                path.move(to: CGPoint(x: width * 0.57, y: height * 0.47))
                path.addLine(to: CGPoint(x: width * 0.84, y: height * 0.30))
            }
            .stroke(
                Color.btPathTarget,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 5])
            )

            Path { path in
                path.move(to: CGPoint(x: width * 0.57, y: height * 0.50))
                path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.68))
            }
            .stroke(Color.btPrimary.opacity(0.26), lineWidth: 1)

            Circle()
                .stroke(Color.btPrimary.opacity(0.34), lineWidth: 2)
                .frame(width: 34, height: 34)
                .position(x: width * 0.56, y: height * 0.48)

            Circle()
                .fill(Color.btBallCue)
                .overlay(Circle().stroke(Color.btSeparator, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .frame(width: 28, height: 28)
                .position(x: width * 0.20, y: height * 0.64)

            Circle()
                .fill(Color.btBallTarget)
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .frame(width: 26, height: 26)
                .position(x: width * 0.56, y: height * 0.48)

            Circle()
                .fill(Color.btPrimary)
                .frame(width: 8, height: 8)
                .position(x: width * 0.84, y: height * 0.30)
        }
    }
}

#Preview("Light") {
    LoginView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
}

#Preview("Dark") {
    LoginView()
        .environmentObject(AuthState())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
