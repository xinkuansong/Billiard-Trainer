import SwiftUI

struct PersonalInfoView: View {
    @EnvironmentObject private var authState: AuthState
    @ObservedObject private var prefs = UserPreferences.shared
    @State private var editingName = false
    @State private var nameText = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    avatarSection
                    ballInfoSection
                    yearsSection
                    if authState.isLoggedIn {
                        accountBindingSection
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("个人信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            nameText = authState.displayNameOrDefault
        }
    }

    // MARK: - Avatar + Name

    private var avatarSection: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.btPrimary)
            }

            if editingName {
                HStack(spacing: Spacing.sm) {
                    TextField("输入昵称", text: $nameText)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                        .multilineTextAlignment(.center)
                        .focused($nameFieldFocused)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.btBGTertiary)
                        .clipShape(Capsule())
                        .onSubmit { saveName() }

                    Button("完成") { saveName() }
                        .font(.btCallout.weight(.medium))
                        .foregroundStyle(.btPrimary)
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                Button {
                    editingName = true
                    nameFieldFocused = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(authState.displayNameOrDefault)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)
                        Image(systemName: "pencil")
                            .font(.btCaption)
                            .foregroundStyle(.btTextTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            if let user = authState.currentUser, authState.isLoggedIn {
                Text("ID: \(String(user.id.prefix(8)))")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Ball Info

    private var ballInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("球种与水平")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("主打球种")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                    BTTogglePillGroup(
                        options: PreferredSport.allCases,
                        selected: $prefs.preferredSport
                    ) { $0.displayName }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("当前水平")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                    BTTogglePillGroup(
                        options: SkillLevel.allCases,
                        selected: $prefs.skillLevel
                    ) { $0.displayName }
                }
            }
            .padding(Spacing.lg)
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Years Playing

    private var yearsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("球龄")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(YearsPlaying.allCases) { years in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            prefs.yearsPlaying = years
                        }
                    } label: {
                        HStack {
                            Text(years.displayName)
                                .font(.btBody)
                                .foregroundStyle(.btText)

                            Spacer()

                            if prefs.yearsPlaying == years {
                                Image(systemName: "checkmark")
                                    .font(.btSubheadlineMedium)
                                    .foregroundStyle(.btPrimary)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if years != YearsPlaying.allCases.last {
                        Divider().padding(.leading, Spacing.lg)
                    }
                }
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Account Binding

    private var accountBindingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("账号绑定")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                bindingRow(
                    icon: "apple.logo",
                    title: "Apple ID",
                    status: authState.currentUser?.provider == .apple ? "已绑定" : "未绑定",
                    isBound: authState.currentUser?.provider == .apple
                )

                Divider().padding(.leading, 56)

                bindingRow(
                    icon: "message.fill",
                    title: "微信",
                    status: "即将支持",
                    isBound: false,
                    isDisabled: true
                )

                Divider().padding(.leading, 56)

                bindingRow(
                    icon: "phone.fill",
                    title: "手机号",
                    status: authState.currentUser?.phoneNumber ?? "即将支持",
                    isBound: authState.currentUser?.phoneNumber != nil,
                    isDisabled: authState.currentUser?.phoneNumber == nil
                )
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private func bindingRow(
        icon: String,
        title: String,
        status: String,
        isBound: Bool,
        isDisabled: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.btSubheadline)
                .foregroundStyle(isDisabled ? .btTextTertiary : .btText)
                .frame(width: 40)

            Text(title)
                .font(.btBody)
                .foregroundStyle(isDisabled ? .btTextTertiary : .btText)

            Spacer()

            Text(status)
                .font(.btCaption)
                .foregroundStyle(isBound ? .btPrimary : .btTextTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .opacity(isDisabled ? 0.6 : 1)
    }

    // MARK: - Actions

    private func saveName() {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            authState.currentUser?.displayName = trimmed
        }
        editingName = false
        nameFieldFocused = false
    }
}

#Preview("Personal Info - Guest") {
    NavigationStack {
        PersonalInfoView()
            .environmentObject(AuthState())
    }
}

#Preview("Personal Info - Logged In") {
    let state = AuthState()
    state.login(user: AppUser(id: "abc12345678", provider: .apple, displayName: "台球小王子"))
    return NavigationStack {
        PersonalInfoView()
            .environmentObject(state)
    }
}

#Preview("Personal Info - Dark") {
    let state = AuthState()
    state.login(user: AppUser(id: "abc12345678", provider: .apple, displayName: "台球小王子"))
    return NavigationStack {
        PersonalInfoView()
            .environmentObject(state)
    }
    .preferredColorScheme(.dark)
}
