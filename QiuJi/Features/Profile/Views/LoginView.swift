import SwiftUI

struct LoginView: View {
    /// The presenter commits the identity after this sheet has finished dismissing.
    var onAuthenticated: ((AppUser) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authState: AuthState
    @State private var activeMethod: MobileLoginMethod?
    @State private var confirmingAge = false
    @State private var requestedMethod: MobileLoginMethod?
    @State private var age14Confirmed = false
    @State private var newIdentity: MobileLoginMethod?
    @State private var operation: Task<Void, Never>?
    @State private var errorMessage: String?


    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Spacing.xl)

                loginPhotoHero
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

                if authState.localTrainingOnly {
                    Text(AuthState.localTrainingMessage)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                } else {
                    loginButtons
                }

                Spacer(minLength: Spacing.lg)

                Button("暂不登录，匿名使用") {
                    authState.loginAnonymously()
                    dismiss()
                }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .disabled(activeMethod != nil)
                .padding(.bottom, Spacing.xxl)

                legalFooter
                    .padding(.bottom, Spacing.xxxl)
            }
        }
        .onDisappear { operation?.cancel() }
        .confirmationDialog("你是否已满 14 周岁？", isPresented: $confirmingAge, titleVisibility: .visible) {
            Button("已满 14 周岁") {
                age14Confirmed = true
                if let requestedMethod { signIn(requestedMethod) }
            }
            Button("不满 14 周岁，继续本机训练") {
                authState.chooseLocalTrainingForAge()
                dismiss()
            }
            Button("暂不回答，继续本机训练", role: .cancel) {
                authState.loginAnonymously()
                dismiss()
            }
        }
        .alert(item: $newIdentity) { method in
            let other: MobileLoginMethod = method == .apple ? .wechat : .apple
            return Alert(title: Text("尚未关联 CuePhys 账号"),
                         message: Text("已有账号请用原方式登录，再到设置的“账号安全”绑定\(method.title)。首次使用可以创建账号。"),
                         primaryButton: .default(Text("创建新账号")) { signIn(method, create: true) },
                         secondaryButton: .cancel(Text(other.available ? "返回选择登录方式" : "返回")))
        }
    }

    private var loginPhotoHero: some View {
        ZStack(alignment: .topLeading) {
            BTTrainingAtmosphere()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Spacing.sm) {
                    BTBrandLogo(size: 34, style: .onDisc)
                    Text(AppMetadata.displayName)
                        .font(.btSubheadlineSemibold)
                }
                Spacer()
                Text("球路计算 · 训练记录 · 数据复盘")
                    .font(.btCaption2)
            }
            .foregroundStyle(TrainingPhotoStyle.foreground)
            .padding(Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppMetadata.displayName)，球路计算、训练记录与数据复盘")
    }

    @ViewBuilder
    private var legalFooter: some View {
        if let termsURL = AppConfig.termsURL,
           let privacyURL = AppConfig.privacyURL {
            VStack(spacing: Spacing.xs) {
                Text("登录即表示您已阅读并同意")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                HStack(spacing: Spacing.lg) {
                    Link("用户协议", destination: termsURL)
                    Link("隐私政策", destination: privacyURL)
                }
                .font(.btCaption)
                .foregroundStyle(.btPrimary)
            }
        } else {
            Text("用户协议与隐私政策发布后将在此提供可访问链接")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Login Buttons

    private var loginButtons: some View {
        VStack(spacing: Spacing.md) {
            Button {
                signIn(.apple)
            } label: {
                HStack(spacing: Spacing.sm) {
                    if activeMethod == .apple {
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
            .disabled(activeMethod != nil)

            if MobileLoginMethod.wechat.available {
                Button {
                    signIn(.wechat)
                } label: {
                    HStack {
                        if activeMethod == .wechat { ProgressView() }
                        Text("通过微信登录")
                    }
                    .font(.btHeadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .disabled(activeMethod != nil)
                .accessibilityIdentifier("login.wechat")
                if activeMethod == .wechat { Button("取消授权") { operation?.cancel() } }
            }
        }
        .padding(.horizontal, Spacing.xxl)
    }

    // MARK: - Sign in with Apple

    private func signIn(_ method: MobileLoginMethod, create: Bool = false) {
        guard activeMethod == nil, !authState.localTrainingOnly else { return }
        let confirmed = age14Confirmed || authState.hasEligibleGuestAgeAnswer
        guard confirmed else {
            requestedMethod = method
            confirmingAge = true
            return
        }
        activeMethod = method
        errorMessage = nil
        operation = Task { @MainActor in
            defer { activeMethod = nil; operation = nil }
            do {
                let user = try await AuthService.shared.signIn(method, create: create, age14Confirmed: confirmed, state: authState)
                if let onAuthenticated { onAuthenticated(user) }
                else { authState.login(user: user) }
                dismiss()
            } catch is CancellationError {
                return
            } catch AccountIdentityError.unregistered {
                newIdentity = method
            } catch {
                errorMessage = error.localizedDescription
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
            case .identity: return AppMetadata.displayName
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
            case .identity: return "\(AppMetadata.displayName)，球路计算、训练记录与数据复盘"
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
