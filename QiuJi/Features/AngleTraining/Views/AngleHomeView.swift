import SwiftUI

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
    case test
    case contactPointTable
    case history
    case aimingPrinciple
    case angleDynamic
    case geometricQuiz
    case scene2DAiming
    case scene3DAiming
    case ballFeel
}

// MARK: - Home View

struct AngleHomeView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var limiter = AngleUsageLimiter()

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    learnSection
                    trainingSection
                    toolsSection
                    historyLink
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .background(.btBG)
        .onReceive(subscriptionManager.$isPremium) { premium in
            limiter.isPremium = premium
        }
    }

    private var pageHeader: some View {
        HStack {
            Text("角度训练")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Learn section

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("学习")

            NavigationLink(value: AngleRoute.aimingPrinciple) {
                FeatureCard(icon: "scope",
                            title: "瞄准原理",
                            subtitle: "切入角、假想球法、厚薄球概念")
            }

            NavigationLink(value: AngleRoute.angleDynamic) {
                FeatureCard(icon: "arrow.triangle.swap",
                            title: "角度与打点",
                            subtitle: "角度/接触点/厚薄球动态关系")
            }

            NavigationLink(value: AngleRoute.ballFeel) {
                FeatureCard(icon: "hand.point.up.left.fill",
                            title: "浅淡球感",
                            subtitle: "从理性分析到直觉判断")
            }
        }
    }

    // MARK: - Training section

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("训练")

            NavigationLink(value: AngleRoute.geometricQuiz) {
                FeatureCard(icon: "ruler.fill",
                            title: "几何角度训练",
                            subtitle: "纯几何角度预测练习")
            }

            NavigationLink(value: AngleRoute.scene2DAiming) {
                FeatureCard(icon: "square.grid.2x2.fill",
                            title: "2D 瞄准训练",
                            subtitle: "俯视球台角度预测",
                            chipText: "2D")
            }

            NavigationLink(value: AngleRoute.scene3DAiming) {
                FeatureCard(icon: "rotate.3d.fill",
                            title: "3D 瞄准训练",
                            subtitle: "3D 视角角度预测",
                            chipText: "3D")
            }

            NavigationLink(value: AngleRoute.test) {
                FeatureCard(icon: "target",
                            title: "角度测试",
                            subtitle: "训练角度视觉感知",
                            badge: limiter.isPremium
                                ? nil
                                : "今日剩余 \(limiter.remainingToday) 题")
            }
        }
    }

    // MARK: - Tools section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionHeader("工具")

            NavigationLink(value: AngleRoute.contactPointTable) {
                FeatureCard(icon: "tablecells.fill",
                            title: "进球点对照表",
                            subtitle: "角度与接触点对照")
            }
        }
    }

    // MARK: - History entry

    private var historyLink: some View {
        NavigationLink(value: AngleRoute.history) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.btPrimary)
                Text("测试历史")
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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.btCaption)
            .foregroundStyle(.btPrimary)
            .textCase(.uppercase)
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var badge: String? = nil
    var chipText: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.btPrimary)
                .frame(width: 48, height: 48)
                .background(Color.btPrimary.opacity(colorScheme == .dark ? 0.15 : 0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    if let chipText {
                        Text(chipText)
                            .font(.btCaption2)
                            .foregroundStyle(.btPrimary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.btPrimary.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            .clipShape(Capsule())
                    }
                }
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
    }
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    NavigationStack {
        AngleHomeView()
    }
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}
