import SwiftUI
import SwiftData

struct TrainingHomeView: View {
    @StateObject private var viewModel = TrainingHomeViewModel()
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                pageHeader

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 300)
                        } else if viewModel.hasActivePlan {
                            activePlanContent
                        } else {
                            emptyStateContent
                        }
                    }
                    .padding(.bottom, 176)
                }
            }
            .background(.btBG)

            if viewModel.hasActivePlan && !viewModel.isLoading {
                fixedStartButton
            }
        }
        .task {
            await viewModel.load(context: modelContext)
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
                    Image(systemName: "person.2")
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
                    Image(systemName: "ellipsis")
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

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("今日安排")
                .font(.btHeadline)
                .foregroundStyle(.btText)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.md) {
                ForEach(session.drills.prefix(3)) { drill in
                    todayDrillCard(drill, session: session, isCurrentDrill: drill.id == firstIncompleteId)
                }

                if session.isAllCompleted {
                    allCompletedBanner
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func todayDrillCard(_ drill: TodayDrillItem, session: TodaySessionInfo, isCurrentDrill: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(drill.nameZh)
                    .font(.btTitle2)
                    .foregroundStyle(drill.isCompleted ? .btTextSecondary : .btText)
                    .lineLimit(1)

                Text("\(session.planNameZh) · \(drill.sets) 练")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }

            Spacer()

            if drill.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.btTitle)
                    .foregroundStyle(.btSuccess)
            } else if isCurrentDrill {
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
            } else {
                Image(systemName: "ellipsis")
                    .font(.btBody)
                    .foregroundStyle(.btTextTertiary)
                    .frame(width: 44, height: 44)
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
            Image(systemName: "checkmark.seal.fill")
                .font(.btStatNumber)
                .foregroundStyle(.btSuccess)

            VStack(alignment: .leading, spacing: 2) {
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

            if viewModel.selectedTab == .official {
                officialPlanBrowsing
            } else {
                customPlanBrowsing
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(PlanLevelFilter.allCases, id: \.self) { filter in
                    filterChipButton(filter)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.md)
    }

    private func filterChipButton(_ filter: PlanLevelFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                viewModel.selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.btFootnote14.weight(.medium))
                .foregroundStyle(chipTextColor(isSelected))
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .background(chipBackground(isSelected))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(chipBorderColor(isSelected), lineWidth: isSelected ? 0 : 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let chipActiveFillLight = Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    private static let chipActiveFillDark = Color(red: 0xF2 / 255.0, green: 0xF2 / 255.0, blue: 0xF7 / 255.0)

    private func chipTextColor(_ isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .black : Color.btBGSecondary
        }
        return colorScheme == .dark ? .btTextSecondary : .btText
    }

    private func chipBackground(_ isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? Self.chipActiveFillDark : Self.chipActiveFillLight
        }
        return colorScheme == .dark ? Color.btBGTertiary : Color.btBGSecondary
    }

    private func chipBorderColor(_ isSelected: Bool) -> Color {
        isSelected ? .clear : .btSeparator
    }

    // MARK: - Official Plan List

    private var officialPlanBrowsing: some View {
        VStack(spacing: 0) {
            filterChips

            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.filteredPlans) { plan in
                    NavigationLink(value: TrainingRoute.planDetail(planId: plan.id)) {
                        planBrowseCard(plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func planBrowseCard(_ plan: PlanBrowseItem) -> some View {
        HStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.42, blue: 0.24), Color(red: 0.07, green: 0.3, blue: 0.17)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "figure.pool.swim")
                        .font(.btStatNumber)
                        .foregroundStyle(.white.opacity(0.85))
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(plan.nameZh)
                        .font(.btCallout.weight(.bold))
                        .foregroundStyle(.btText)
                        .lineLimit(1)

                    if plan.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.btCaption)
                            .foregroundStyle(.btAccent)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.btFootnote14)
                        .foregroundStyle(.btTextTertiary)
                }

                Text(plan.description)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)

                levelBadge(plan.targetLevel)
            }
        }
        .padding(colorScheme == .dark ? Spacing.lg : Spacing.sm)
        .background(colorScheme == .dark ? Color.btBGSecondary : .clear)
        .clipShape(RoundedRectangle(cornerRadius: colorScheme == .dark ? BTRadius.lg : 0))
    }

    private func levelBadge(_ level: String) -> some View {
        let displayLevel = level.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? level
        let drillLevel = DrillLevel(rawValue: displayLevel)
        let badgeText = drillLevel?.displayName ?? level

        return Text(badgeText)
            .font(.btCaption2.weight(.bold))
            .foregroundStyle(.btPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.btPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
    }

    // MARK: - Custom Plan List

    private var customPlanBrowsing: some View {
        VStack(spacing: Spacing.md) {
            if customPlans.isEmpty {
                BTEmptyState(
                    icon: "hammer",
                    title: "暂无自定义计划",
                    subtitle: "创建你自己的训练方案"
                )

                Button("创建计划") {
                    router.trainingPath.append(TrainingRoute.customPlanBuilder)
                }
                .buttonStyle(BTButtonStyle.secondary)
                .padding(.horizontal, Spacing.xxl)
            } else {
                ForEach(customPlans) { plan in
                    NavigationLink(value: TrainingRoute.customPlanEdit(planId: plan.id)) {
                        customPlanCard(plan)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private func customPlanCard(_ plan: CustomPlan) -> some View {
        HStack(spacing: Spacing.lg) {
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .fill(Color.btAccent.opacity(0.12))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "hammer.fill")
                        .font(.btStatNumber)
                        .foregroundStyle(.btAccent)
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(plan.name)
                        .font(.btCallout.weight(.bold))
                        .foregroundStyle(.btText)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.btFootnote14)
                        .foregroundStyle(.btTextTertiary)
                }

                Text("\(plan.sessionsPerWeek) 次/周 · \(plan.drills.count) 项训练")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)

                HStack(spacing: 2) {
                    Image(systemName: "hammer")
                        .font(.btMicro)
                    Text("自定义")
                        .font(.btCaption2)
                }
                .foregroundStyle(.btAccent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
            }
        }
        .padding(colorScheme == .dark ? Spacing.lg : Spacing.sm)
        .background(colorScheme == .dark ? Color.btBGSecondary : .clear)
        .clipShape(RoundedRectangle(cornerRadius: colorScheme == .dark ? BTRadius.lg : 0))
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
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 36))
                .foregroundStyle(.btTextTertiary)

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
                Button {
                    resumeMinimizedTraining()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text("继续训练")
                    }
                }
                .buttonStyle(BTButtonStyle.primary)
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
            }
        }
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
