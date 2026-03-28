import SwiftUI

struct PhoneLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authState: AuthState

    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var isSendingCode = false
    @State private var countdown: Int = 0
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    private var canSendCode: Bool { phone.count == 11 && countdown == 0 }
    private var canLogin: Bool { phone.count == 11 && code.count == 6 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.btBG.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("手机号登录")
                            .font(.btLargeTitle)
                            .foregroundStyle(.btText)
                        Text("未注册手机号将自动创建账号")
                            .font(.btCallout)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.top, Spacing.xxxl)
                    .padding(.bottom, Spacing.xxxl)
                    .padding(.horizontal, Spacing.xxl)

                    // MARK: - 手机号输入
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("手机号")
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btTextSecondary)
                            .padding(.horizontal, Spacing.xxl)

                        HStack {
                            Text("+86")
                                .font(.btBody)
                                .foregroundStyle(.btTextSecondary)
                                .padding(.leading, Spacing.lg)

                            Rectangle()
                                .fill(.btSeparator)
                                .frame(width: 1, height: 20)

                            TextField("请输入手机号", text: $phone)
                                .font(.btBody)
                                .keyboardType(.phonePad)
                                .foregroundStyle(.btText)
                        }
                        .padding(.vertical, Spacing.lg)
                        .background(.btBGTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                        .padding(.horizontal, Spacing.xxl)
                    }

                    Spacer().frame(height: Spacing.xl)

                    // MARK: - 验证码输入
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("验证码")
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(.btTextSecondary)
                            .padding(.horizontal, Spacing.xxl)

                        HStack {
                            TextField("请输入验证码", text: $code)
                                .font(.btBody)
                                .keyboardType(.numberPad)
                                .foregroundStyle(.btText)
                                .padding(.leading, Spacing.lg)

                            Button(countdown > 0 ? "\(countdown)秒后重发" : "发送验证码") {
                                sendCode()
                            }
                            .font(.btSubheadlineMedium)
                            .foregroundStyle(canSendCode ? .btPrimary : .btTextTertiary)
                            .disabled(!canSendCode || isSendingCode)
                            .padding(.trailing, Spacing.lg)
                        }
                        .frame(height: 52)
                        .background(.btBGTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                        .padding(.horizontal, Spacing.xxl)
                    }

                    // MARK: - 错误提示
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.btFootnote)
                            .foregroundStyle(.btDestructive)
                            .padding(.horizontal, Spacing.xxl)
                            .padding(.top, Spacing.sm)
                    }

                    Spacer()

                    // MARK: - 登录按钮
                    Button("登录 / 注册") {
                        login()
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .disabled(!canLogin || isLoggingIn)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.btPrimary)
                    }
                }
            }
        }
    }

    private func sendCode() {
        isSendingCode = true
        errorMessage = nil
        // T-P1-07 REST API SMS 实现（待 H-14/H-15 完成后接入真实 API）
        // 当前为占位实现
        Task {
            try? await Task.sleep(for: .seconds(1))
            isSendingCode = false
            countdown = 60
            startCountdown()
        }
    }

    private func startCountdown() {
        guard countdown > 0 else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            countdown -= 1
            startCountdown()
        }
    }

    private func login() {
        isLoggingIn = true
        errorMessage = nil
        // T-P1-07 REST API SMS 登录（待 H-14/H-15 完成后接入真实 API）
        Task {
            try? await Task.sleep(for: .seconds(1))
            isLoggingIn = false
            authState.loginAnonymously()
            dismiss()
        }
    }
}

#Preview("Light") {
    PhoneLoginView()
        .environmentObject(AuthState())
}

#Preview("Dark") {
    PhoneLoginView()
        .environmentObject(AuthState())
        .preferredColorScheme(.dark)
}
