import SwiftUI
import SwiftData

struct TrainingHomeView: View {
    @StateObject private var viewModel = TrainingHomeViewModel()
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]
    @Query private var activePlans: [UserActivePlan]

    private var activePlanSignature: String {
        activePlans
            .map { "\($0.planId)|\($0.isCustom)" }
            .sorted()
            .joined(separator: ";")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                pageHeader

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if viewModel.isLoading {
                            BTDrillListSkeleton()
                                .transition(.opacity)
                                .frame(maxWidth: .infinity, minHeight: 300)
                        } else if viewModel.hasActivePlan {
                            activePlanContent
                                .transition(.opacity)
                        } else {
                            emptyStateContent
                                .transition(.opacity)
                        }
                    }
                    .padding(.bottom, 176)
                    .animation(BTMotion.easeFast, value: viewModel.isLoading)
                }
            }
            .background(.btBG)

            // F-AT-04: show bottom chrome when minimized even without an active plan
            // (free-record minimize must still surface the full-width「继续训练」bar).
            if (viewModel.hasActivePlan || router.isTrainingMinimized) && !viewModel.isLoading {
                fixedStartButton
            }
        }
        .task {
            await viewModel.load(context: modelContext)
        }
        .onChange(of: activePlanSignature) { _, _ in
            Task { await viewModel.load(context: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRequestResumeTraining)) { _ in
            router.resumeMinimizedTraining()
        }
        .fullScreenCover(item: $router.activeTrainingMode) {
            router.onTrainingDismissed()
            Task { await viewModel.load(context: modelContext) }
        } content: { _ in
            if let vm = router.activeTrainingVM {
                ActiveTrainingView(viewModel: vm)
            }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        HStack {
            Text("训练")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)

            Spacer()

            HStack(spacing: Spacing.md) {
                Button {
                    router.trainingPath.append(TrainingRoute.planList)
                } label: {
                    Image(systemName: BTIcon.personGroup)
                        .font(.btBody)
                        .foregroundStyle(.btTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Menu {
                    Button {
                        router.trainingPath.append(TrainingRoute.planList)
                    } label: {
                        Label("训练计划", systemImage: "list.bullet.rectangle.portrait")
                    }
                    Button {
                        router.trainingPath.append(TrainingRoute.customPlanBuilder)
                    } label: {
                        Label("新建自定义计划", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: BTIcon.menu)
                        .font(.btBody)
                        .foregroundStyle(.btTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.btBG)
    }

    // MARK: - Active Plan Content

    private var activePlanContent: some View {
        VStack(spacing: Spacing.xl) {
            if let session = viewModel.todaySession {
                todayScheduleSection(session)
            }

            planBrowsingSection
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Today Schedule Section

    private func todayScheduleSection(_ session: TodaySessionInfo) -> some View {
        let firstIncompleteId = session.drills.first(where: { !$0.isCompleted })?.id
        let visibleDrills = Array(session.drills.prefix(3))

        return VStack(alignment: .leading, spacing: Spacing.lg) {
            todayScheduleHeader(session)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.md) {
                ForEach(Array(visibleDrills.enumerated()), id: \.element.id) { index, drill in
                    todayDrillCard(
                        drill,
                        session: session,
                        index: index,
                        total: session.drills.count,
                        isCurrentDrill: drill.id == firstIncompleteId
                    )
                }

                if session.isAllCompleted {
                    allCompletedBanner
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func todayScheduleHeader(_ session: TodaySessionInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text("第 \(session.weekNumber) 周")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .monospacedDigit()
                Circle()
                    .fill(Color.btAccent)
                    .frame(width: 3, height: 3)
                Text("第 \(session.dayNumber) 天")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .monospacedDigit()
                Spacer()
                Text("\(session.completedCount) / \(session.totalCount)")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text("今日安排")
                    .font(.btTitle)
                    .foregroundStyle(.btText)

                BTGoldRule()
                    .padding(.bottom, 6)

                Spacer()
            }

            // F-PL-02: surface existing planNameZh / weekTheme (no new entry)
            if !session.planNameZh.isEmpty {
                Text(session.planNameZh)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)
            }
            if !session.weekTheme.isEmpty {
                Text(session.weekTheme)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .lineLimit(2)
            }
        }
    }

    private func todayDrillCard(
        _ drill: TodayDrillItem,
        session: TodaySessionInfo,
        index: Int,
        total: Int,
        isCurrentDrill: Bool
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Text(String(format: "%02d", index + 1))
                .font(.btSubheadlineSemibold)
                .foregroundStyle(drill.isCompleted ? .btTextTertiary : .btTextSecondary)
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(drill.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(drill.isCompleted ? .btTextSecondary : .btText)
                    .lineLimit(1)

                Text("第 \(index + 1) 项 / \(total) · \(drill.sets) 组×\(drill.ballsPerSet)")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer()

            if drill.isCompleted {
                Image(systemName: BTIcon.checkmarkCircle)
                    .font(.btTitle)
                    .foregroundStyle(.btSuccess)
            } else if isCurrentDrill {
                // F-TR-06: press feedback aligned with primary chrome (compact label kept)
                Button {
                    router.startTraining(mode: .plan(drills: session.drills))
                } label: {
                    Text("GO!")
                        .font(.btFootnote14.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.btPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                }
                .buttonStyle(BTPressableStyle.capsule)
            } else {
                // F-TR-05: non-affordance queue label (was BTIcon.menu — looked tappable)
                Text("排队")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("排队中，尚未开始")
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
                radius: 4, x: 0, y: 2)
    }

    private var allCompletedBanner: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: BTIcon.completeSeal)
                .font(.btStatNumber)
                .foregroundStyle(.btSuccess)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("今日训练已完成")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text("做得不错！明天继续加油")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(Color.btSuccess.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Plan Browsing Section

    private var planBrowsingSection: some View {
        VStack(spacing: 0) {
            BTSegmentedTab(
                tabs: PlanBrowseTab.allCases,
                selected: $viewModel.selectedTab,
                label: { $0.rawValue }
            )
            .padding(.horizontal, Spacing.lg)

            Divider().foregroundStyle(.btSeparator)

            // F-PL-05: short opacity ≤200ms on segmented content swap
            Group {
                if viewModel.selectedTab == .official {
                    officialPlanBrowsing
                        .transition(.opacity)
                } else {
                    customPlanBrowsing
                        .transition(.opacity)
                }
            }
            .animation(BTMotion.easeFast, value: viewModel.selectedTab)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(PlanLevelFilter.allCases, id: \.self) { filter in
                    BTFilterChip(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation(BTMotion.easeFast) {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Official Plan List

    private var officialPlanBrowsing: some View {
        VStack(spacing: 0) {
            filterChips

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                ForEach(Array(viewModel.filteredPlans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink(value: TrainingRoute.planDetail(planId: plan.id)) {
                        planPosterCard(plan, issueNumber: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
    }

    private func planPosterCard(_ plan: PlanBrowseItem, issueNumber: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            BTPlanCover(targetLevel: plan.targetLevel, issueNumber: issueNumber)

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(plan.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(planLevelName(plan.targetLevel)) · \(plan.durationWeeks) 周")
                    .font(.btCaption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            .padding(Spacing.md)

            if plan.isPremium {
                VStack {
                    HStack {
                        Spacer()
                        BTProBadge()
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
            }
        }
        .aspectRatio(0.92, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func customIssueThumbnail(number: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [Color.btAccent.opacity(0.18), Color.btAccent.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Spacing.xs) {
                Text(String(format: "%02d", number))
                    .font(.btDisplaySmall)
                    .foregroundStyle(Color.btAccent)
                    .monospacedDigit()
                Image(systemName: BTIcon.hammer)
                    .font(.btCaption2)
                    .foregroundStyle(Color.btAccent.opacity(0.7))
            }
        }
        // F-TR-14: align with PlanListView custom thumbnail (72)
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityHidden(true)
    }

    private func planLevelName(_ level: String) -> String {
        let displayLevel = level.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? level
        return DrillLevel(rawValue: displayLevel)?.displayName ?? level
    }

    // MARK: - Custom Plan List

    private var customPlanBrowsing: some View {
        VStack(spacing: Spacing.md) {
            if customPlans.isEmpty {
                BTEmptyState(
                    icon: "list.bullet.clipboard",
                    title: "还没有自定义计划",
                    subtitle: "创建你自己的训练方案",
                    actionTitle: "创建计划",
                    actionStyle: .secondary,
                    action: {
                        router.trainingPath.append(TrainingRoute.customPlanBuilder)
                    }
                )
            } else {
                ForEach(Array(customPlans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
                        customPlanCard(plan, issueNumber: index + 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private func customPlanCard(_ plan: CustomPlan, issueNumber: Int) -> some View {
        HStack(spacing: Spacing.md) {
            customIssueThumbnail(number: issueNumber)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(plan.name)
                        .font(.btTitleMedium)
                        .foregroundStyle(.btText)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: BTIcon.chevronRight)
                        .font(.btFootnote14)
                        .foregroundStyle(.btTextTertiary)
                }

                Text("\(plan.sessionsPerWeek) 次/周 · \(plan.drills.count) 项训练")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()

                HStack(spacing: Spacing.xs) {
                    Image(systemName: BTIcon.sliders)
                        .font(.btMicro)
                    Text("自定义")
                        .font(.btCaption2)
                }
                .foregroundStyle(.btAccent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                .padding(.top, Spacing.xs)
            }
        }
        // F-TR-13: match PlanListView — both modes btBGSecondary + BTRadius.md
        .padding(Spacing.md)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: Spacing.xl) {
            quickStartBanner

            planBrowsingSection
        }
        .padding(.vertical, Spacing.md)
    }

    private var quickStartBanner: some View {
        VStack(spacing: Spacing.md) {
            BTTrainingIcon(size: 56, filled: true)

            Text("选择一个计划开始训练")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Text("或直接进行自由记录")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)

            Button {
                router.startTraining(mode: .free)
            } label: {
                Text("自由记录")
                    .font(.btCallout.weight(.medium))
                    .foregroundStyle(.btPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Fixed Start Button

    private var fixedStartButton: some View {
        VStack {
            Spacer()

            if router.isTrainingMinimized {
                // F-AT-04: keep full-width form; share copy/color/icon language with float
                Button {
                    resumeMinimizedTraining()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: BTIcon.playCircle)
                            .font(.btSubheadlineMedium)
                        Text("继续训练")
                        if let elapsed = router.minimizedTrainingVM?.elapsedSeconds {
                            Text(Self.formatElapsed(elapsed))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        }
                    }
                }
                .buttonStyle(BTButtonStyle.primary)
                .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity))
            } else {
                Button {
                    if let session = viewModel.todaySession {
                        router.startTraining(mode: .plan(drills: session.drills))
                    } else {
                        router.startTraining(mode: .free)
                    }
                } label: {
                    Text("开始训练")
                }
                .buttonStyle(BTButtonStyle.primary)
                .transition(.opacity)
            }
        }
        .animation(BTMotion.springPanel, value: router.isTrainingMinimized)
        .shadow(color: colorScheme == .dark ? .clear : Color.btPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal, Spacing.xxl)
        .padding(.bottom, Spacing.sm)
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [Color.btBG.opacity(0), Color.btBG],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 80)
            .allowsHitTesting(false)
        }
    }

    private func resumeMinimizedTraining() {
        router.resumeMinimizedTraining()
    }

    /// Shared elapsed formatting with `BTFloatingIndicator` (F-AT-04).
    private static func formatElapsed(_ elapsedSeconds: Int) -> String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Previews

#Preview("With Plan") {
    NavigationStack {
        TrainingHomeView()
            .navigationTitle("训练")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
}

#Preview("No Plan - Dark") {
    NavigationStack {
        TrainingHomeView()
            .navigationTitle("训练")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}
