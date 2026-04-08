import SwiftUI
import StoreKit

struct AboutView: View {
    @Environment(\.requestReview) private var requestReview

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.btBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    appIdentitySection
                    feedbackSection
                    legalSection
                    copyrightFooter
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
        }
        .navigationTitle("关于与反馈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - App Identity

    private var appIdentitySection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .fill(Color.btPrimary)
                    .frame(width: 72, height: 72)

                Text("QJ")
                    .font(.btTitle.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: Spacing.xs) {
                Text("球迹")
                    .font(.btTitle2)
                    .foregroundStyle(.btText)

                Text("专为台球爱好者设计的训练工具")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)

                Text(appVersion)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("联系与反馈")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Button { sendFeedback() } label: {
                    aboutRow(
                        icon: "envelope.fill",
                        iconBG: Color.blue.opacity(0.12),
                        iconColor: .blue,
                        title: "意见反馈"
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56)

                Button { requestReview() } label: {
                    aboutRow(
                        icon: "star.fill",
                        iconBG: Color.btAccent.opacity(0.12),
                        iconColor: .btAccent,
                        title: "给个好评"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("法律信息")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                Button {
                    openURL("https://qiuji.app/terms")
                } label: {
                    aboutRow(
                        icon: "doc.text.fill",
                        iconBG: Color.gray.opacity(0.12),
                        iconColor: .gray,
                        title: "用户协议"
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56)

                Button {
                    openURL("https://qiuji.app/privacy")
                } label: {
                    aboutRow(
                        icon: "checkmark.shield.fill",
                        iconBG: Color.btPrimary.opacity(0.12),
                        iconColor: .btPrimary,
                        title: "隐私政策"
                    )
                }
                .buttonStyle(.plain)
            }
            .background(Color.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    // MARK: - Footer

    private var copyrightFooter: some View {
        Text("© 2026 球迹")
            .font(.btCaption)
            .foregroundStyle(.btTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.lg)
    }

    // MARK: - Row Helper

    private func aboutRow(
        icon: String,
        iconBG: Color,
        iconColor: Color,
        title: String
    ) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconBG)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.btSubheadline)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40)

            Text(title)
                .font(.btCallout)
                .foregroundStyle(.btText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.btCaption).fontWeight(.medium)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func sendFeedback() {
        let device = UIDevice.current
        let subject = "球迹 \(appVersion) 意见反馈"
        let body = "\n\n---\n设备: \(device.model)\n系统: \(device.systemName) \(device.systemVersion)"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:feedback@qiuji.app?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}

#Preview("About Dark") {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
