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
                        Text("输入手机号")
                            .font(.btLargeTitle)
                            .foregroundStyle(.btText)
                        Text("我们将发送短信验证码到您的手机")
                            .font(.btCallout)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.top, Spacing.xxxl)
                    .padding(.bottom, Spacing.xxxl)
                    .padding(.horizontal, Spacing.xxl)

                    // MARK: - Phone Input
                    HStack {
                        HStack(spacing: Spacing.sm) {
                            Text("+86")
                                .font(.btBody)
                                .foregroundStyle(.btTextSecondary)
                            Image(systemName: "chevron.down")
                                .font(.btMicro)
                                .foregroundStyle(.btTextTertiary)
                        }
                        .padding(.leading, Spacing.lg)

                        Rectangle()
                            .fill(.btSeparator)
                            .frame(width: 1, height: 20)

                        TextField("请输入手机号", text: $phone)
                            .font(.btBody)
                            .keyboardType(.phonePad)
                            .foregroundStyle(.btText)
                    }
                    .frame(height: 52)
                    .background(Color.btBGSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.btSeparator, lineWidth: 0.5))
                    .padding(.horizontal, Spacing.xxl)

                    Spacer().frame(height: Spacing.md)

                    // MARK: - Code Input
                    HStack {
                        TextField("请输入验证码", text: $code)
                            .font(.btBody)
                            .keyboardType(.numberPad)
                            .foregroundStyle(.btText)
                            .padding(.leading, Spacing.lg)

                        Button(countdown > 0 ? "\(countdown)秒" : "发送验证码") {
                            sendCode()
                        }
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(canSendCode ? .btPrimary : .btTextTertiary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(canSendCode ? Color.btPrimaryMuted : Color.btBGTertiary)
                        .clipShape(Capsule())
                        .disabled(!canSendCode || isSendingCode)
                        .padding(.trailing, Spacing.sm)
                    }
                    .frame(height: 52)
                    .background(Color.btBGSecondary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.btSeparator, lineWidth: 0.5))
                    .padding(.horizontal, Spacing.xxl)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.btFootnote)
                            .foregroundStyle(.btDestructive)
                            .padding(.horizontal, Spacing.xxl)
                            .padding(.top, Spacing.sm)
                    }

                    Spacer().frame(height: Spacing.xxxl)

                    // MARK: - Login Button
                    Button("登录") {
                        login()
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .disabled(!canLogin || isLoggingIn)
                    .padding(.horizontal, Spacing.xxl)

                    Button("收不到验证码？") {}
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.lg)

                    Spacer()

                    // MARK: - Branding
                    VStack(spacing: Spacing.xs) {
                        ZStack {
                            Circle()
                                .stroke(Color.btPrimary.opacity(0.2), lineWidth: 1)
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(Color.btPrimary.opacity(0.05))
                                .frame(width: 60, height: 60)
                            Circle()
                                .fill(Color.btPrimary)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.bottom, Spacing.md)

                        HStack(spacing: Spacing.xs) {
                            Text("球迹")
                                .font(.btSubheadlineMedium)
                            Text("·")
                                .foregroundStyle(.btTextTertiary)
                            Text("QIUJI")
                                .font(.btSubheadlineMedium)
                        }
                        .foregroundStyle(.btText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationTitle("手机号登录")
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
