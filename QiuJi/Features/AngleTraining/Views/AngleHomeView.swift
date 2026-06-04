import SwiftUI

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
    case contactPointTable
    case aimingPrinciple
    case angleDynamic
    case geometricQuiz
    case scene2DAiming
    case scene3DAiming
    case ballFeel
    case bankShot
    case diamondSystem
    case shotSimulation
}

// MARK: - Entry Model

private struct AngleEntry: Identifiable {
    let id = UUID()
    let route: AngleRoute
    let icon: String
    let title: String
    let subtitle: String
    var chip: String? = nil
}

// MARK: - Home View

struct AngleHomeView: View {
    private let learnEntries: [AngleEntry] = [
        .init(route: .aimingPrinciple, icon: "scope",
              title: "瞄准原理", subtitle: "切入角、假想球法、厚薄球概念"),
        .init(route: .angleDynamic, icon: "arrow.triangle.swap",
              title: "角度与打点", subtitle: "角度/接触点/厚薄球动态关系"),
        .init(route: .ballFeel, icon: "hand.point.up.left.fill",
              title: "浅谈球感", subtitle: "从理性分析到直觉判断")
    ]

    private let trainEntries: [AngleEntry] = [
        .init(route: .geometricQuiz, icon: "ruler.fill",
              title: "几何角度训练", subtitle: "纯几何角度预测练习"),
        .init(route: .scene2DAiming, icon: "square.grid.2x2.fill",
              title: "2D 瞄准训练", subtitle: "俯视球台角度预测", chip: "2D"),
        .init(route: .scene3DAiming, icon: "rotate.3d.fill",
              title: "3D 瞄准训练", subtitle: "3D 视角角度预测", chip: "3D")
    ]

    private let toolEntries: [AngleEntry] = [
        .init(route: .contactPointTable, icon: "tablecells.fill",
              title: "进球点对照表", subtitle: "角度与接触点对照")
    ]

    private let advancedEntries: [AngleEntry] = [
        .init(route: .bankShot, icon: "arrow.uturn.left",
              title: "翻袋解球器", subtitle: "选目标袋，自动求 1–3 库翻袋路线与母球瞄准", chip: "2D"),
        .init(route: .diamondSystem, icon: "diamond.fill",
              title: "反射解球器", subtitle: "任意摆球，自动求 1–多库反射走位路线", chip: "2D"),
        .init(route: .shotSimulation, icon: "scope",
              title: "分离角与走位", subtitle: "物理引擎模拟分离角、母球走位；可调力度与塞", chip: "物理")
    ]

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    CollapsibleSection(title: "学习", entries: learnEntries)
                    CollapsibleSection(title: "训练", entries: trainEntries)
                    CollapsibleSection(title: "工具", entries: toolEntries)
                    CollapsibleSection(title: "进阶", entries: advancedEntries)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .background(.btBG)
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
}

// MARK: - Collapsible Section

private struct CollapsibleSection: View {
    let title: String
    let entries: [AngleEntry]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(.btCaption)
                        .foregroundStyle(.btPrimary)
                        .textCase(.uppercase)

                    Text("\(entries.count)")
                        .font(.btCaption2)
                        .foregroundStyle(.btTextTertiary)
                        .monospacedDigit()

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(.btTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.vertical, Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: Spacing.md) {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry.route) {
                            FeatureCard(icon: entry.icon,
                                        title: entry.title,
                                        subtitle: entry.subtitle,
                                        chipText: entry.chip)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var chipText: String? = nil

    var body: some View {
        HStack(spacing: Spacing.lg) {
            BTIconBadge(systemName: icon, size: 48, glyphRatio: 0.46, weight: .medium)

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
                            .background(Color.btPrimaryMuted)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(2)
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
