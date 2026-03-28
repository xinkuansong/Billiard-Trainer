import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authState: AuthState
    @State private var selectedFlow: LoginFlow?
    @State private var isAppleSignInLoading = false
    @State private var errorMessage: String?

    enum LoginFlow: Identifiable {
        case phone
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btBG.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - 标题
                    VStack(spacing: Spacing.sm) {
                        Text("登录球迹")
                            .font(.btLargeTitle)
                            .foregroundStyle(.btText)
                        Text("登录后数据云端同步，换机不丢失")
                            .font(.btCallout)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.top, Spacing.xxxl)
                    .padding(.bottom, Spacing.xxxxl)

                    // MARK: - 错误提示
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.btCallout)
                            .foregroundStyle(.btDestructive)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xxl)
                            .padding(.bottom, Spacing.md)
                    }

                    // MARK: - 登录选项
                    VStack(spacing: Spacing.md) {
                        LoginOptionButton(
                            icon: "message.fill",
                            iconColor: .green,
                            title: "微信登录",
                            subtitle: "使用微信账号快速登录"
                        ) {
                            // T-P1-08 微信登录（待 H-05 完成后实现）
                        }

                        LoginOptionButton(
                            icon: "phone.fill",
                            iconColor: .btPrimary,
                            title: "手机号登录",
                            subtitle: "使用手机号 + 验证码登录"
                        ) {
                            selectedFlow = .phone
                        }

                        LoginOptionButton(
                            icon: "applelogo",
                            iconColor: .btText,
                            title: "Apple 登录",
                            subtitle: "使用 Apple ID 私密登录",
                            isLoading: isAppleSignInLoading
                        ) {
                            signInWithApple()
                        }
                    }
                    .padding(.horizontal, Spacing.xxl)

                    Spacer()

                    // MARK: - 跳过
                    Button("跳过，先体验") {
                        authState.loginAnonymously()
                        dismiss()
                    }
                    .buttonStyle(BTButtonStyle.text)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.btTextTertiary)
                    }
                }
            }
        }
        .sheet(item: $selectedFlow) { flow in
            switch flow {
            case .phone:
                PhoneLoginView()
            }
        }
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

// MARK: - 登录选项按钮

private struct LoginOptionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text(subtitle)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.btTextTertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextTertiary)
                }
            }
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .disabled(isLoading)
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
