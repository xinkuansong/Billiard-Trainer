import SwiftUI
import SwiftData

// MARK: - Training Navigation

enum TrainingRoute: Hashable {
    case planList
    case planDetail(planId: String)
}

// MARK: - Plan List View

struct PlanListView: View {
    @State private var plans: [OfficialPlan] = []
    @State private var isLoading = true

    private var groupedPlans: [(level: String, plans: [OfficialPlan])] {
        let levelOrder = ["L0→L1", "L1", "L1→L2", "L2", "L3", "L3→L4"]
        let grouped = Dictionary(grouping: plans) { $0.targetLevel }
        return levelOrder.compactMap { level in
            guard let items = grouped[level], !items.isEmpty else { return nil }
            return (level: level, plans: items)
        }
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if plans.isEmpty {
                BTEmptyState(
                    icon: "calendar",
                    title: "暂无训练计划",
                    subtitle: "计划内容正在准备中"
                )
            } else {
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedPlans, id: \.level) { group in
                        Section {
                            VStack(spacing: Spacing.md) {
                                ForEach(group.plans) { plan in
                                    NavigationLink(value: TrainingRoute.planDetail(planId: plan.id)) {
                                        PlanCard(plan: plan)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        } header: {
                            levelSectionHeader(level: group.level, count: group.plans.count)
                        }
                    }
                }
                .padding(.vertical, Spacing.md)
            }
        }
        .background(.btBG)
        .navigationTitle("训练计划")
        .task {
            await loadPlans()
        }
    }

    private func loadPlans() async {
        isLoading = true
        plans = await PlanContentService.shared.loadAllPlans()
        isLoading = false
    }

    private func levelSectionHeader(level: String, count: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: iconForLevel(level))
                .font(.btCallout)
                .foregroundStyle(colorForLevel(level))

            Text(titleForLevel(level))
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("\(count)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(.btBGTertiary)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.btBG)
    }

    private func titleForLevel(_ level: String) -> String {
        switch level {
        case "L0→L1":  return "入门 → 初级"
        case "L1":     return "初级专项"
        case "L1→L2":  return "初级 → 中级"
        case "L2":     return "中级突破"
        case "L3":     return "高级专项"
        case "L3→L4":  return "高级 → 专业"
        default:       return level
        }
    }

    private func iconForLevel(_ level: String) -> String {
        switch level {
        case "L0→L1":  return "figure.walk"
        case "L1":     return "figure.run"
        case "L1→L2":  return "arrow.up.right"
        case "L2":     return "bolt.fill"
        case "L3":     return "star.fill"
        case "L3→L4":  return "trophy.fill"
        default:       return "circle"
        }
    }

    private func colorForLevel(_ level: String) -> Color {
        switch level {
        case "L0→L1":  return .btTextSecondary
        case "L1":     return .btPrimary
        case "L1→L2":  return .blue
        case "L2":     return .blue
        case "L3":     return .purple
        case "L3→L4":  return .btAccent
        default:       return .btTextSecondary
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: OfficialPlan

    private var targetLevel: DrillLevel? {
        let raw = plan.targetLevel.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? plan.targetLevel
        return DrillLevel(rawValue: raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        if let level = targetLevel {
                            BTLevelBadge(level: level)
                        }

                        if plan.isPremium {
                            HStack(spacing: 2) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                Text("付费")
                                    .font(.btCaption2)
                            }
                            .foregroundStyle(.btAccent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.btAccent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                        }
                    }

                    Text(plan.nameZh)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.top, Spacing.xs)
            }

            Text(plan.description)
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .lineLimit(2)

            HStack(spacing: Spacing.lg) {
                planInfoChip(icon: "calendar", text: "\(plan.durationWeeks) 周")
                planInfoChip(icon: "repeat", text: "\(plan.sessionsPerWeek) 次/周")
                planInfoChip(icon: "clock", text: "\(plan.minutesPerSession) 分钟/次")
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay {
            if plan.isPremium {
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    .stroke(Color.btAccent.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private func planInfoChip(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.btPrimary)
            Text(text)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    NavigationStack {
        PlanListView()
    }
}

#Preview("Dark") {
    NavigationStack {
        PlanListView()
    }
    .preferredColorScheme(.dark)
}
