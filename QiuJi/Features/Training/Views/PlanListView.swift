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
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var modelContext
    @State private var planToDelete: CustomPlan?
    @State private var showDeleteConfirm = false
    @State private var planToActivate: CustomPlan?
    @State private var showActivateConfirm = false
    @State private var toast: BTToastMessage?
    @Query private var activePlans: [UserActivePlan]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    BTDrillListSkeleton()
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: Spacing.xxxl) {
                        if plans.isEmpty && customPlans.isEmpty {
                            // System content not ready — keep「暂无」tone (F-ST-06).
                            BTEmptyState(
                                icon: "calendar",
                                title: "暂无训练计划",
                                subtitle: "计划内容正在准备中"
                            )
                        }

                        officialPlansSection

                        customPlansSection
                    }
                    .padding(.vertical, Spacing.lg)
                    .transition(.opacity)
                }
            }
            .task {
                await loadPlans()
                restorePlanListScroll(proxy)
            }
            .onChange(of: router.trainingPath.count) { oldCount, newCount in
                guard newCount < oldCount else { return }
                restorePlanListScroll(proxy)
            }
        }
        .animation(BTMotion.easeFast, value: isLoading)
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
        .btToast($toast)
        // F-OV-02: destructive clear/delete → confirmationDialog (cancel first).
        .confirmationDialog(
            "删除模版",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) { planToDelete = nil }
            Button("删除", role: .destructive) { deleteCustomPlan() }
        } message: {
            Text("确定要删除「\(planToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
        .confirmationDialog(
            "用于今日训练",
            isPresented: $showActivateConfirm,
            titleVisibility: .visible
        ) {
            Button("取消", role: .cancel) { planToActivate = nil }
            Button("确定") {
                if let plan = planToActivate {
                    activateCustomPlan(plan)
                }
                planToActivate = nil
            }
        } message: {
            if hasActivePlan {
                Text("将替换当前的今日安排。确定用「\(planToActivate?.name ?? "")」作为今天的训练吗？")
            } else {
                Text("用「\(planToActivate?.name ?? "")」作为今天的训练吗？")
            }
        }
    }

    private var hasActivePlan: Bool { !activePlans.isEmpty }

    // MARK: - Official Plans Section

    /// 货架顺序 = `Plans/index.json`（`loadAllPlans` 保序）。不再按 `targetLevel` 分节。
    private var officialPlansSection: some View {
        Group {
            if !plans.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    officialSectionHeader
                        .padding(.horizontal, Spacing.lg)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Spacing.md),
                            GridItem(.flexible(), spacing: Spacing.md)
                        ],
                        spacing: Spacing.md
                    ) {
                        ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                            Button {
                                router.planListRestoreID = plan.id
                                router.trainingPath.append(
                                    TrainingRoute.planDetail(planId: plan.id)
                                )
                            } label: {
                                PlanCard(plan: plan, issueNumber: index + 1)
                            }
                            .buttonStyle(.plain)
                            .id(plan.id)
                            .accessibilityIdentifier("planListPoster-\(plan.id)")
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    private var officialSectionHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.btCaption2)
                    .foregroundStyle(.btAccent)
                Text("官方")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text("官方计划")
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                BTGoldRule()
                    .padding(.bottom, 6)

                Spacer()

                Text("\(plans.count)")
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
                Image(systemName: BTIcon.hammer)
                    .font(.btCaption2)
                    .foregroundStyle(.btAccent)
                Text("自建清单")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text("我的模版")
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
        let isActive = isUsedToday(plan)

        return HStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                customThumbnail(issueNumber: issueNumber)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(plan.name)
                        .font(.btTitleMedium)
                        .foregroundStyle(.btText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(customPlanSubtitle(plan))
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.sm) {
                        HStack(spacing: 2) {
                            Image(systemName: "hammer")
                                .font(.btMicro)
                            Text("模版")
                                .font(.btCaption2)
                        }
                        .foregroundStyle(.btAccent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.btAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))

                        if isActive {
                            HStack(spacing: 2) {
                                Image(systemName: BTIcon.checkmarkCircle)
                                    .font(.btMicro)
                                Text("今日使用中")
                                    .font(.btCaption2)
                            }
                            .foregroundStyle(.btSuccess)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.btSuccess.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: BTIcon.chevronRight)
                    .font(.btFootnote14)
                    .foregroundStyle(.btTextTertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { requestUseForToday(plan) }

            Menu {
                NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
                    Label("编辑", systemImage: "pencil")
                }
                Button {
                    requestUseForToday(plan)
                } label: {
                    Label("用于今日训练", systemImage: "play.circle")
                }
                Button(role: .destructive) {
                    requestDelete(plan)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: BTIcon.menuCircle)
                    .font(.btCallout)
                    .foregroundStyle(.btTextTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .onLongPressGesture { requestDelete(plan) }
        .id(plan.id.uuidString)
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
                Image(systemName: BTIcon.hammer)
                    .font(.btCaption2)
                    .foregroundStyle(Color.btAccent.opacity(0.7))
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func isUsedToday(_ plan: CustomPlan) -> Bool {
        activePlans.contains { $0.isCustom && $0.planId == plan.id.uuidString }
    }

    private func customPlanSubtitle(_ plan: CustomPlan) -> String {
        let names = plan.drills
            .sorted { $0.order < $1.order }
            .map { $0.drillNameZh.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if names.isEmpty {
            return "\(plan.drills.count) 项训练"
        }
        return "\(plan.drills.count) 项 \(names.joined(separator: "、"))"
    }

    private func requestUseForToday(_ plan: CustomPlan) {
        if isUsedToday(plan) {
            BTToast.present("已是今日训练", tone: .info) { toast = $0 }
            return
        }
        planToActivate = plan
        showActivateConfirm = true
    }

    private func requestDelete(_ plan: CustomPlan) {
        planToDelete = plan
        showDeleteConfirm = true
    }

    private func activateCustomPlan(_ plan: CustomPlan) {
        do {
            try DrillTrainingPlanService.activate(plan: plan, context: modelContext)
            try modelContext.save()
            router.trainingPath = NavigationPath()
        } catch {
            print("[PlanListView] activate failed: \(error)")
            BTToast.present("无法设为今日训练，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func deleteCustomPlan() {
        guard let plan = planToDelete else { return }
        let planIdStr = plan.id.uuidString
        do {
            let descriptor = FetchDescriptor<UserActivePlan>(
                predicate: #Predicate { $0.planId == planIdStr }
            )
            let actives = try modelContext.fetch(descriptor)
            modelContext.delete(plan)
            for active in actives {
                modelContext.delete(active)
            }
            try modelContext.save()
            planToDelete = nil
        } catch {
            print("[PlanListView] delete failed: \(error)")
            BTToast.present("删除失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func loadPlans() async {
        if !plans.isEmpty { return }
        isLoading = true
        plans = await PlanContentService.shared.loadAllPlans()
        withAnimation(BTMotion.easeFast) {
            isLoading = false
        }
    }

    private func restorePlanListScroll(_ proxy: ScrollViewProxy) {
        guard let id = router.planListRestoreID else { return }
        proxy.scrollTo(id, anchor: .center)
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
        BTContentGridCard(
            title: plan.nameZh,
            subtitle: "\(levelName) · \(plan.durationWeeks) 周",
            coverAspectRatio: 4.0 / 3.0
        ) {
            ZStack(alignment: .topTrailing) {
                BTPlanCover(
                    planId: plan.id,
                    targetLevel: plan.targetLevel,
                    issueNumber: issueNumber,
                    mode: .list
                )
                if plan.isPremium {
                    BTProBadge()
                        .padding(Spacing.sm)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    NavigationStack {
        PlanListView()
    }
    .environmentObject(AppRouter())
}

#Preview("Dark") {
    NavigationStack {
        PlanListView()
    }
    .environmentObject(AppRouter())
    .preferredColorScheme(.dark)
}
