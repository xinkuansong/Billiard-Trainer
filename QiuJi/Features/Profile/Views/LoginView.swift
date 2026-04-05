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
                Spacer()

                appIcon
                    .padding(.bottom, Spacing.xxl)

                Text("欢迎使用球迹")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                    .padding(.bottom, Spacing.sm)

                Text("登录以同步你的训练数据")
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .padding(.bottom, Spacing.xxxxl)

                if let msg = errorMessage {
                    Text(msg)
                        .font(.btFootnote)
                        .foregroundStyle(.btDestructive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.bottom, Spacing.md)
                }

                loginButtons

                Spacer()

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

    // MARK: - App Icon

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.btPrimary)
                .frame(width: 80, height: 80)
            Image(systemName: "flag.checkered")
                .font(.btLargeTitle)
                .fontWeight(.medium)
                .foregroundStyle(.white)
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
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)

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
            .buttonStyle(.plain)
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
