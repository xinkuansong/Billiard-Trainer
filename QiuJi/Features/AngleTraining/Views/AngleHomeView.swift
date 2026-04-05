import SwiftUI

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
    case test
    case contactPointTable
    case history
}

// MARK: - Home View

struct AngleHomeView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var limiter = AngleUsageLimiter()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                pageHeader
                featureCards
                historyLink
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .background(.btBG)
        .onReceive(subscriptionManager.$isPremium) { premium in
            limiter.isPremium = premium
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack {
            Text("角度训练")
                .font(.btTitle)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Feature cards

    private var featureCards: some View {
        VStack(spacing: Spacing.lg) {
            NavigationLink(value: AngleRoute.test) {
                FeatureCard(icon: "target",
                            title: "角度测试",
                            subtitle: "判断切球角度，AI 自适应出题",
                            badge: limiter.isPremium
                                ? nil
                                : "今日剩余 \(limiter.remainingToday) 题")
            }

            NavigationLink(value: AngleRoute.contactPointTable) {
                FeatureCard(icon: "circle.circle",
                            title: "进球点对照表",
                            subtitle: "交互式查看不同角度的接触点",
                            badge: nil)
            }
        }
    }

    // MARK: - History entry

    private var historyLink: some View {
        NavigationLink(value: AngleRoute.history) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.btPrimary)
                Text("查看测试历史")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.btStatNumber)
                .foregroundStyle(.btPrimary)
                .frame(width: 48, height: 48)
                .background(Color.btPrimary.opacity(colorScheme == .dark ? 0.15 : 0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(2)
                if let badge {
                    Text(badge)
                        .font(.btCaption2)
                        .foregroundStyle(.btAccent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }
}

// MARK: - Preview

#Preview("Light") {
    NavigationStack {
        AngleHomeView()
            .navigationTitle("角度训练")
    }
}

#Preview("Dark") {
    NavigationStack {
        AngleHomeView()
            .navigationTitle("角度训练")
    }
    .preferredColorScheme(.dark)
}
