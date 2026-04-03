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
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    customPlansSection

                    if plans.isEmpty && customPlans.isEmpty {
                        BTEmptyState(
                            icon: "calendar",
                            title: "暂无训练计划",
                            subtitle: "计划内容正在准备中"
                        )
                    }

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: TrainingRoute.customPlanBuilder) {
                    Label("新建", systemImage: "plus")
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
                Section {
                    VStack(spacing: Spacing.md) {
                        ForEach(customPlans) { plan in
                            customPlanCard(plan)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                } header: {
                    customSectionHeader
                }
            }
        }
    }

    private var customSectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "hammer.fill")
                .font(.btCallout)
                .foregroundStyle(.btAccent)

            Text("我的计划")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("\(customPlans.count)")
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

    private func customPlanCard(_ plan: CustomPlan) -> some View {
        NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "hammer")
                                .font(.system(size: 10))
                                .foregroundStyle(.btAccent)
                            Text("自定义")
                                .font(.btCaption2)
                                .foregroundStyle(.btAccent)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.btAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))

                        Text(plan.name)
                            .font(.btHeadline)
                            .foregroundStyle(.btText)
                            .lineLimit(2)
                    }

                    Spacer()

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
                            .padding(Spacing.xs)
                    }
                }

                HStack(spacing: Spacing.lg) {
                    planInfoChip(icon: "repeat", text: "\(plan.sessionsPerWeek) 次/周")
                    planInfoChip(icon: "list.bullet", text: "\(plan.drills.count) 项训练")
                }
            }
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        }
        .buttonStyle(.plain)
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
