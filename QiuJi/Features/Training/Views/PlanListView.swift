import SwiftUI
import SwiftData

// MARK: - Training Navigation

enum TrainingRoute: Hashable {
    case planList
    case planDetail(planId: String)
    case customPlanBuilder
    case customPlanEdit(planId: UUID)
}

// MARK: - Plan List View

struct PlanListView: View {
    @State private var plans: [OfficialPlan] = []
    @State private var isLoading = true
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]
    @Environment(\.modelContext) private var modelContext
    @State private var planToDelete: CustomPlan?
    @State private var showDeleteConfirm = false

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
            } else {
                LazyVStack(spacing: Spacing.xxxl) {
                    if plans.isEmpty && customPlans.isEmpty {
                        BTEmptyState(
                            icon: "calendar",
                            title: "暂无训练计划",
                            subtitle: "计划内容正在准备中"
                        )
                    }

                    ForEach(groupedPlans, id: \.level) { group in
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            levelSectionHeader(level: group.level, count: group.plans.count)
                                .padding(.horizontal, Spacing.lg)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: Spacing.md),
                                    GridItem(.flexible(), spacing: Spacing.md)
                                ],
                                spacing: Spacing.md
                            ) {
                                ForEach(Array(group.plans.enumerated()), id: \.element.id) { index, plan in
                                    NavigationLink(value: TrainingRoute.planDetail(planId: plan.id)) {
                                        PlanCard(plan: plan, issueNumber: index + 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                    }

                    customPlansSection
                }
                .padding(.vertical, Spacing.lg)
            }
        }
        .background(.btBG)
        .navigationTitle("训练计划")
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: TrainingRoute.customPlanBuilder) {
                    Text("新建")
                }
            }
        }
        .task {
            await loadPlans()
        }
        .alert("删除计划", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteCustomPlan() }
        } message: {
            Text("确定要删除「\(planToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
    }

    // MARK: - Custom Plans Section

    private var customPlansSection: some View {
        Group {
            if !customPlans.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    customSectionHeader
                        .padding(.horizontal, Spacing.lg)

                    VStack(spacing: Spacing.md) {
                        ForEach(Array(customPlans.enumerated()), id: \.element.id) { index, plan in
                            customPlanCard(plan, issueNumber: index + 1)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private var customSectionHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "hammer.fill")
                    .font(.btCaption2)
                    .foregroundStyle(.btAccent)
                Text("用户创建")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text("我的计划")
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                BTGoldRule()
                    .padding(.bottom, 6)

                Spacer()

                Text("\(customPlans.count)")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(.btBGTertiary)
                    .clipShape(Capsule())
            }
        }
    }

    private func customPlanCard(_ plan: CustomPlan, issueNumber: Int) -> some View {
        NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
            HStack(spacing: Spacing.md) {
                customThumbnail(issueNumber: issueNumber)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text(plan.name)
                            .font(.btTitleMedium)
                            .foregroundStyle(.btText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: Spacing.xs)

                        Menu {
                            NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button {
                                activateCustomPlan(plan)
                            } label: {
                                Label("激活此计划", systemImage: "play.circle")
                            }
                            Button(role: .destructive) {
                                planToDelete = plan
                                showDeleteConfirm = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.btCallout)
                                .foregroundStyle(.btTextTertiary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                    }

                    Text("\(plan.sessionsPerWeek) 次/周 · \(plan.drills.count) 项训练")
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                        .monospacedDigit()

                    HStack(spacing: 2) {
                        Image(systemName: "hammer")
                            .font(.btMicro)
                        Text("自定义")
                            .font(.btCaption2)
                    }
                    .foregroundStyle(.btAccent)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.btAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                }

                Image(systemName: "chevron.right")
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextTertiary)
            }
            .padding(Spacing.md)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .buttonStyle(.plain)
    }

    private func customThumbnail(issueNumber: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [Color.btAccent.opacity(0.18), Color.btAccent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 2) {
                Text(String(format: "%02d", issueNumber))
                    .font(.btDisplaySmall)
                    .foregroundStyle(Color.btAccent)
                    .monospacedDigit()
                Image(systemName: "hammer.fill")
                    .font(.btCaption2)
                    .foregroundStyle(Color.btAccent.opacity(0.7))
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func activateCustomPlan(_ plan: CustomPlan) {
        let descriptor = FetchDescriptor<UserActivePlan>()
        if let existing = try? modelContext.fetch(descriptor) {
            for old in existing { modelContext.delete(old) }
        }
        let active = UserActivePlan(planId: plan.id.uuidString, isCustom: true)
        modelContext.insert(active)
        try? modelContext.save()
    }

    private func deleteCustomPlan() {
        guard let plan = planToDelete else { return }
        let planIdStr = plan.id.uuidString
        modelContext.delete(plan)

        let descriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.planId == planIdStr }
        )
        if let active = try? modelContext.fetch(descriptor).first {
            modelContext.delete(active)
        }
        try? modelContext.save()
        planToDelete = nil
    }

    private func loadPlans() async {
        isLoading = true
        plans = await PlanContentService.shared.loadAllPlans()
        isLoading = false
    }

    // MARK: - Section Header

    private func levelSectionHeader(level: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(level.replacingOccurrences(of: "→", with: " → "))
                .font(.btCaption2)
                .foregroundStyle(.btTextTertiary)
                .monospacedDigit()

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text(titleForLevel(level))
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                BTGoldRule()
                    .padding(.bottom, 6)

                Spacer()

                Text("\(count)")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(.btBGTertiary)
                    .clipShape(Capsule())
            }
        }
    }

    private func titleForLevel(_ level: String) -> String {
        switch level {
        case "L0→L1":  return "入门计划"
        case "L1":     return "初级计划"
        case "L1→L2":  return "进阶计划"
        case "L2":     return "中级计划"
        case "L3":     return "高级计划"
        case "L3→L4":  return "专业计划"
        default:       return level
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: OfficialPlan
    let issueNumber: Int

    private var levelName: String {
        let raw = plan.targetLevel.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? plan.targetLevel
        return DrillLevel(rawValue: raw)?.displayName ?? plan.targetLevel
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            BTPlanCover(targetLevel: plan.targetLevel, issueNumber: issueNumber)

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(levelName) · \(plan.durationWeeks) 周")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            .padding(Spacing.md)

            if plan.isPremium {
                VStack {
                    HStack {
                        Spacer()
                        Text("PRO")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.btAccent)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
            }
        }
        .aspectRatio(0.92, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
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
