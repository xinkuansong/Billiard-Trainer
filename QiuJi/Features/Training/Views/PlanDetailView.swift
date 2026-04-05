import SwiftUI
import SwiftData

struct PlanDetailView: View {
    let planId: String

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var plan: OfficialPlan?
    @State private var isLoading = true
    @State private var expandedWeeks: Set<Int> = []
    @State private var showActivateConfirm = false
    @State private var hasActivePlan = false
    @State private var isCurrentPlanActive = false
    @State private var drillNames: [String: String] = [:]
    @State private var showSubscription = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let plan {
                planContent(plan)
            } else {
                BTEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "无法加载计划",
                    subtitle: "计划数据可能已损坏"
                )
            }
        }
        .background(.btBG)
        .navigationTitle(plan?.nameZh ?? "计划详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await loadPlan()
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
        .alert("激活训练计划", isPresented: $showActivateConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定激活") { activatePlan() }
        } message: {
            if hasActivePlan {
                Text("当前已有激活的训练计划，激活新计划将替换旧计划。确定要继续吗？")
            } else {
                Text("确定要开始「\(plan?.nameZh ?? "")」训练计划吗？激活后将从第 1 周第 1 天开始。")
            }
        }
    }

    // MARK: - Plan Content

    private func planContent(_ plan: OfficialPlan) -> some View {
        VStack(spacing: Spacing.xl) {
            planHeader(plan)
                .padding(.horizontal, Spacing.lg)

            statsGrid(plan)
                .padding(.horizontal, Spacing.lg)

            activateSection(plan)
                .padding(.horizontal, Spacing.lg)

            weeksList(plan)
                .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.xxxxl)
        }
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Plan Header

    private func planHeader(_ plan: OfficialPlan) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                if let level = DrillLevel(rawValue: plan.targetLevel.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? plan.targetLevel) {
                    BTLevelBadge(level: level)
                }

                if plan.isPremium {
                    HStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .font(.btMicro)
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

            Text(plan.description)
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Stats Grid

    private func statsGrid(_ plan: OfficialPlan) -> some View {
        HStack(spacing: Spacing.md) {
            statCell(icon: "calendar", value: "\(plan.durationWeeks)", unit: "周")
            statCell(icon: "repeat", value: "\(plan.sessionsPerWeek)", unit: "次/周")
            statCell(icon: "clock", value: "\(plan.minutesPerSession)", unit: "分钟/次")
            statCell(icon: "target", value: plan.targetLevel, unit: "目标")
        }
    }

    private func statCell(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.btTitle2)
                .foregroundStyle(.btPrimary)

            Text(value)
                .font(.btStatNumber)
                .foregroundStyle(.btPrimary)

            Text(unit)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Activate Section

    private func activateSection(_ plan: OfficialPlan) -> some View {
        VStack(spacing: Spacing.sm) {
            if isCurrentPlanActive {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.btSuccess)
                    Text("当前已激活此计划")
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btSuccess)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .background(Color.btSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            } else if !plan.isPremium || subscriptionManager.isPremium {
                Button {
                    showActivateConfirm = true
                } label: {
                    Label("开始此计划", systemImage: "play.fill")
                }
                .buttonStyle(BTButtonStyle.primary)
            }
        }
    }

    // MARK: - Weeks List

    private func weeksList(_ plan: OfficialPlan) -> some View {
        let isPremiumLocked = plan.isPremium && !subscriptionManager.isPremium
        let freePreviewCount = 1

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("训练安排")
                .font(.btTitle2)
                .foregroundStyle(.btText)

            if isPremiumLocked {
                ForEach(Array(plan.weeks.prefix(freePreviewCount))) { week in
                    weekSection(week, plan: plan)
                }

                BTPremiumLock(mode: .progressive(visibleItems: freePreviewCount)) {
                    showSubscription = true
                } content: {
                    EmptyView()
                }
            } else {
                ForEach(plan.weeks) { week in
                    weekSection(week, plan: plan)
                }
            }
        }
    }

    private func weekSection(_ week: PlanWeek, plan: OfficialPlan) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if expandedWeeks.contains(week.weekNumber) {
                        expandedWeeks.remove(week.weekNumber)
                    } else {
                        expandedWeeks.insert(week.weekNumber)
                    }
                }
            } label: {
                weekHeader(week, plan: plan)
            }
            .buttonStyle(.plain)

            if expandedWeeks.contains(week.weekNumber) {
                VStack(spacing: Spacing.sm) {
                    ForEach(week.sessions) { session in
                        daySection(session, weekNumber: week.weekNumber)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private let weekBadgeSize: CGFloat = Spacing.xxxl + Spacing.xs

    private func weekHeader(_ week: PlanWeek, plan: OfficialPlan) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: weekBadgeSize, height: weekBadgeSize)
                Text("W\(week.weekNumber)")
                    .font(.btCaption2)
                    .foregroundStyle(.btPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("第 \(week.weekNumber) 周")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(week.theme)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            Text("\(week.sessions.count) 天")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            Image(systemName: expandedWeeks.contains(week.weekNumber) ? "chevron.up" : "chevron.down")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.md)
    }

    // MARK: - Day Section

    private func daySection(_ session: PlanSession, weekNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("第 \(session.dayNumber) 天")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)

                Spacer()

                let totalMin = session.phases.reduce(0) { $0 + $1.durationMinutes }
                Text("\(totalMin) 分钟")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            ForEach(session.phases) { phase in
                if !phase.drills.isEmpty {
                    phaseRow(phase)
                }
            }
        }
        .padding(Spacing.md)
        .background(.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    private func phaseRow(_ phase: SessionPhase) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: phase.icon)
                    .font(.btCaption2)
                    .foregroundStyle(.btPrimary)
                Text(phase.typeZh)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                Text("· \(phase.durationMinutes)分钟")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }

            ForEach(phase.drills) { ref in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.btPrimary.opacity(0.3))
                        .frame(width: 5, height: 5)

                    Text(drillNames[ref.drillId] ?? ref.drillId)
                        .font(.btCallout)
                        .foregroundStyle(.btText)
                        .lineLimit(1)

                    Spacer()

                    Text("\(ref.sets)组×\(ref.ballsPerSet)球")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadPlan() async {
        isLoading = true
        defer { isLoading = false }

        plan = await PlanContentService.shared.loadPlanFromBundle(id: planId)

        let descriptor = FetchDescriptor<UserActivePlan>()
        if let active = try? modelContext.fetch(descriptor).first {
            hasActivePlan = true
            isCurrentPlanActive = (active.planId == planId)
        }

        guard let plan else { return }
        let drillService = DrillContentService.shared
        let allDrillIds = Set(plan.weeks.flatMap { week in
            week.sessions.flatMap { session in
                session.phases.flatMap { phase in
                    phase.drills.map(\.drillId)
                }
            }
        })
        var names: [String: String] = [:]
        for id in allDrillIds {
            if let drill = await drillService.loadDrillFromBundle(id: id) {
                names[id] = drill.nameZh
            }
        }
        drillNames = names
    }

    // MARK: - Activate Plan

    private func activatePlan() {
        let descriptor = FetchDescriptor<UserActivePlan>()
        if let existing = try? modelContext.fetch(descriptor) {
            for old in existing {
                modelContext.delete(old)
            }
        }
        let newPlan = UserActivePlan(planId: planId)
        modelContext.insert(newPlan)
        try? modelContext.save()

        isCurrentPlanActive = true
        hasActivePlan = true
    }
}

// MARK: - Previews

#Preview("Beginner") {
    NavigationStack {
        PlanDetailView(planId: "plan_beginner")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
}

#Preview("Premium - Dark") {
    NavigationStack {
        PlanDetailView(planId: "plan_advanced")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .preferredColorScheme(.dark)
}
