import SwiftUI
import SwiftData

struct TrainingHomeView: View {
    let ownerKey: String
    @StateObject private var viewModel = TrainingHomeViewModel()
    @StateObject private var profile: OwnerProfileStore
    @EnvironmentObject private var authState: AuthState
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]
    @Query private var activePlans: [UserActivePlan]
    @Query private var schedules: [TodayTrainingSchedule]
    @Query(sort: \TrainingSession.date, order: .reverse) private var trainingSessions: [TrainingSession]
    @State private var toast: BTToastMessage?
    @State private var planToDelete: CustomPlan?
    @State private var showDeleteConfirm = false
    @State private var dailyClearanceState: DailyClearanceHomeState = .notStarted
    @State private var dailyClearanceGame = UserPreferences.shared.dailyClearanceGame
    @State private var didInstallDailyClearanceHomeFixture = false
    @State private var didInstallV54ScheduleFixture = false
    @State private var expandedScheduleItemID: UUID?
    @State private var suggestionExpanded = false
    @StateObject private var scrollReference = TrainingHomeScrollReference()
    @State private var retainedContentHeight: CGFloat = 0
    @State private var historySelection: TrainingSession?

    init(ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.ownerKey = ownerKey
        _profile = StateObject(wrappedValue: OwnerProfileStore(ownerKey: ownerKey))
        _customPlans = Query(
            filter: #Predicate { $0.ownerKey == ownerKey },
            sort: \CustomPlan.createdAt,
            order: .reverse
        )
        _activePlans = Query(filter: #Predicate { $0.ownerKey == ownerKey })
        _schedules = Query(filter: #Predicate { $0.ownerKey == ownerKey })
        _trainingSessions = Query(
            filter: #Predicate { $0.ownerKey == ownerKey },
            sort: \TrainingSession.date,
            order: .reverse
        )
    }

    private enum DailyClearanceHomeState {
        case notStarted, inProgress, completed

        var title: String {
            switch self {
            case .notStarted: return "每日清台"
            case .inProgress: return "继续清台"
            case .completed: return "今日已清"
            }
        }

        var accessibilityState: String {
            switch self {
            case .notStarted: return "未开始"
            case .inProgress: return "进行中"
            case .completed: return "已完成"
            }
        }
    }

    private enum HeaderLogoMetrics {
        static let size: CGFloat = 50
        /// `BrandLogoMark.svg` 的有色路径底边约在 viewBox 高度的 73.6%。
        /// 裁掉下方透明画布后，文字底边才能与 Logo 的真实视觉底边对齐。
        static let visibleHeight = size * (1_507.0 / 2_048.0)
    }

    private static let maximumVisibleTodayRows = 3
    private static let todayRowHeight: CGFloat = 82

    /// 含周 / 天游标：计划推进（训练完成或手动跳过 / 回退）后「今日安排」随之刷新（W7）。
    private var activePlanSignature: String {
        activePlans
            .map { "\($0.id)|\($0.planId)|\($0.isCustom)|\($0.status)|\($0.currentLessonId ?? "")|\($0.currentWeek)|\($0.currentDay)" }
            .sorted()
            .joined(separator: ";")
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.btBG
                .ignoresSafeArea()

            TrainingHomeBlueprintBackground(
                color: Color.btPrimary.opacity(colorScheme == .dark ? 0.13 : 0.08)
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                pageHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Spacing.sm) {
                            Color.clear
                                .frame(height: 0)
                                .id(TrainingHomeViewModel.scrollTopID)
                                .accessibilityHidden(true)

                            if viewModel.isLoading {
                                BTDrillListSkeleton()
                                    .transition(.opacity)
                                    .frame(maxWidth: .infinity, minHeight: 300)
                            } else {
                                activePlanContent
                                    .transition(.opacity)
                            }
                        }
                        // Clearance for the native floating Tab Bar.
                        .padding(.bottom, 88)
                        .frame(minHeight: retainedContentHeight, alignment: .top)
                        .background(TrainingHomeScrollResolver(reference: scrollReference))
                        .animation(BTMotion.easeFast, value: viewModel.isLoading)
                    }
                    .coordinateSpace(name: "trainingHomeScroll")
                    .onChange(of: viewModel.browseScrollTick) { _, _ in
                        let id = viewModel.browseScrollTarget
                        let anchor: UnitPoint =
                            (id == TrainingHomeViewModel.scrollTopID
                             || id == TrainingHomeViewModel.scrollBrowsingID) ? .top : .center
                        proxy.scrollTo(id, anchor: anchor)
                    }
                    .onChange(of: router.trainingPath.count) { oldCount, newCount in
                        if newCount < oldCount { refreshDailyClearanceState() }
                        guard newCount < oldCount, let restore = viewModel.restorePlanID else { return }
                        viewModel.requestBrowseScroll(to: restore)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The training home keeps one primary entry point; drill rows are informational.
            if canStartPrimaryTraining && !viewModel.isLoading && !router.isTrainingMinimized {
                startTrainingCircle
            }
        }
        .task {
            profile.load(from: authState.currentUser)
            installV54ScheduleFixtureIfNeeded()
            _ = try? TodayTrainingScheduleService(context: modelContext)
                .today(ownerKey: ownerKey, createIfNeeded: false)
            await viewModel.load(context: modelContext, ownerKey: ownerKey)
            await installDailyClearanceHomeFixtureIfNeeded()
            refreshDailyClearanceState()
        }
        .onChange(of: authState.currentUser) { _, user in
            profile.load(from: user)
        }
        .onChange(of: activePlanSignature) { oldValue, _ in
            if !oldValue.isEmpty {
                viewModel.restorePlanID = nil
                viewModel.requestBrowseScroll(to: TrainingHomeViewModel.scrollTopID)
            }
            Task { await viewModel.load(context: modelContext, ownerKey: ownerKey) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRequestResumeTraining)) { _ in
            router.resumeMinimizedTraining()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didDismissActiveTraining)) { _ in
            Task { await viewModel.load(context: modelContext, ownerKey: ownerKey) }
        }
        .sheet(item: $historySelection) { session in
            NavigationStack {
                TrainingDetailView(sessionId: session.id, ownerKey: ownerKey)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { historySelection = nil } } }
            }
        }
        .btToast($toast)
        .alert(
            "无法调整计划进度",
            isPresented: Binding(
                get: { viewModel.progressError != nil },
                set: { if !$0 { viewModel.progressError = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.progressError ?? "")
        }
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
    }

    private var hasActivePlan: Bool { PlanProgressService.currentOfficialPlan(in: activePlans) != nil }

    private var todayProjection: TodayTrainingProjection {
        TodayTrainingProjection.make(ownerKey: ownerKey, schedules: schedules,
            sessions: trainingSessions, suggestion: viewModel.todaySession)
    }

    private var currentSchedule: TodayTrainingSchedule? {
        let key = TodayTrainingScheduleService.localDayKey(for: .now, timeZone: .current)
        return TodayTrainingScheduleService.currentSchedule(in: schedules, ownerKey: ownerKey, dayKey: key)
    }

    private var orderedScheduleItems: [TodayScheduleItem] {
        (currentSchedule?.items ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    private var nextScheduleItem: TodayScheduleItem? {
        orderedScheduleItems.first {
            $0.state == TodayScheduleItemState.inProgress || $0.state == TodayScheduleItemState.pending
        }
    }

    /// An active official plan is a suggestion source, not an implicit queue item.
    /// Keep one primary CTA visible so the user can accept the current lesson with one tap.
    private var canStartPrimaryTraining: Bool {
        true
    }

    private var activeOfficialPlan: UserActivePlan? {
        PlanProgressService.currentOfficialPlan(in: activePlans)
    }

    /// Launch-argument-only fixture used by the v54 UI matrix. Production launches never enter it.
    private func installV54ScheduleFixtureIfNeeded() {
        guard !didInstallV54ScheduleFixture else { return }
        didInstallV54ScheduleFixture = true
        let args = ProcessInfo.processInfo.arguments
        guard let state = args.first(where: { $0.hasPrefix("-v54.todayState=") })?
            .replacingOccurrences(of: "-v54.todayState=", with: "") else { return }
        guard state != "empty" else { return }
        do {
            if state == "freeCompleted" {
                let saved = TrainingSession(ownerKey: ownerKey)
                saved.totalDurationMinutes = 8
                modelContext.insert(saved)
                let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球")
                modelContext.insert(entry)
                let set = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8)
                modelContext.insert(set)
                entry.sets = [set]
                saved.drillEntries = [entry]
                try modelContext.save()
                return
            }
            guard let plan = PlanContentService.decodePlanFromBundle(id: "plan_beginner"),
                  let lesson = plan.lessons.first else { return }
            let active = UserActivePlan(planId: plan.id, ownerKey: ownerKey)
            active.currentLessonId = lesson.id
            modelContext.insert(active)
            if state == "planStatuses" {
                for (id, status) in [("plan_accuracy", "paused"), ("plan_force", "completed")] {
                    guard let content = PlanContentService.decodePlanFromBundle(id: id) else {
                        throw ScheduledTrainingBlock.DecodeError.invalidPayload
                    }
                    let saved = UserActivePlan(planId: id, ownerKey: ownerKey)
                    saved.status = status
                    saved.currentLessonId = content.lessons.dropFirst().first?.id ?? content.lessons.first?.id
                    modelContext.insert(saved)
                }
                try modelContext.save()
                return
            }
            if state == "suggestion" {
                try modelContext.save()
                return
            }
            let fixtureDate = state == "yesterday"
                ? Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
                : .now
            let service = TodayTrainingScheduleService(
                context: modelContext, now: { fixtureDate }, timeZone: .current
            )
            var results: [TodayTrainingScheduleService.AddResult] = []
            if state != "suggestionTemplate" && state != "templateOnly" {
                results += try service.addOfficialLessons(
                    plan: plan, lessonIDs: [lesson.id], activePlan: active
                )
            }
            if state != "single" {
                let template = CustomPlan(name: "赛前热身", sessionsPerWeek: 1, ownerKey: ownerKey)
                modelContext.insert(template)
                let templateDrill = CustomPlanDrill(
                    drillId: "drill_c001", drillNameZh: "直线球", roundsPerFormation: 1, order: 0
                )
                modelContext.insert(templateDrill)
                template.drills = [templateDrill]
                if state != "templateOnly" { results.append(try service.addTemplate(template)) }
                if state != "suggestionTemplate" && state != "templateOnly" {
                    results.append(try service.addLibraryDrill(
                        id: "drill_c053", title: "中袋角度球", ownerKey: ownerKey
                    ))
                }
            }
            let items = results.map { result in
                switch result {
                case .added(let item), .alreadyPresent(let item): return item
                }
            }
            for (index, item) in items.enumerated() {
                if state == "completed" || (state == "partial" && index == 0) {
                    let block = try ScheduledTrainingBlock(item: item)
                    let saved = TrainingSession(ownerKey: ownerKey)
                    saved.date = fixtureDate
                    saved.totalDurationMinutes = 8
                    saved.scheduleItemId = item.id
                    saved.planId = block.planID
                    saved.lessonId = block.lessonID
                    saved.sourceKind = block.sourceKind
                    saved.sourceId = block.sourceID
                    saved.sourceParentId = block.sourceParentID
                    saved.sourceTitleSnapshot = block.sourceTitle
                    saved.sourceSubtitleSnapshot = block.sourceSubtitle
                    saved.sourcePayloadVersion = block.payloadVersion
                    saved.sourcePayloadSnapshot = block.payloadSnapshot
                    saved.setProgress(role: block.progressRole, effect: nil)
                    modelContext.insert(saved)
                    saved.drillEntries = block.drills.enumerated().map { order, drill in
                        let entry = DrillEntry(drillId: drill.drillID, drillNameZh: drill.name, orderIndex: order)
                        modelContext.insert(entry)
                        let set = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8)
                        modelContext.insert(set)
                        entry.sets = [set]
                        return entry
                    }
                    item.trainingSessionId = saved.id
                    item.state = TodayScheduleItemState.completed
                    item.completedAt = fixtureDate
                } else if state == "partial" && index == 1 {
                    item.state = TodayScheduleItemState.inProgress
                    item.startedAt = fixtureDate
                }
            }
            try modelContext.save()
        } catch {
            assertionFailure("v54/v57 schedule fixture failed: \(error)")
            toast = BTToastMessage("测试数据创建失败", tone: .error)
        }
    }

    // MARK: - Page Header

    /// Reference layout: a compact coaching line fills the formerly empty top-left area.
    private var pageHeader: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                BTBrandLogo(size: HeaderLogoMetrics.size, style: .markOnly)
                    .frame(
                        width: HeaderLogoMetrics.size,
                        height: HeaderLogoMetrics.size
                    )
                    .alignmentGuide(.bottom) { _ in
                        HeaderLogoMetrics.visibleHeight
                    }
                    .accessibilityHidden(true)

                Text("每一次专注，都是在拉近理想的距离。")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btPrimary)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.70)
                    .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                viewModel.hasActivePlan ? "今日训练进行中" : "今日训练待安排"
            )

            Spacer(minLength: Spacing.xs)
            headerActions
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }

    private var headerActions: some View {
        HStack(spacing: Spacing.md) {
            Button {
                viewModel.restorePlanID = nil
                router.trainingPath.append(TrainingRoute.planList)
            } label: {
                Image(systemName: BTIcon.personGroup)
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("好友")

            Menu {
                Button {
                    viewModel.restorePlanID = nil
                    router.trainingPath.append(TrainingRoute.planList)
                } label: {
                    Label("训练计划", systemImage: "list.bullet.rectangle.portrait")
                }
                Button {
                    viewModel.restorePlanID = nil
                    router.trainingPath.append(TrainingRoute.customPlanBuilder)
                } label: {
                    Label("新建模版", systemImage: "plus")
                }


            } label: {
                Image(systemName: BTIcon.menu)
                    .font(.btBody)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("trainingHome.moreMenu")
        }
    }

    // MARK: - Active Plan Content

    private var activePlanContent: some View {
        VStack(spacing: Spacing.xl) {
            weeklyTrainingSection
            if !todayProjection.queued.isEmpty || todayProjection.suggestion != nil || !todayProjection.history.isEmpty {
                scheduledBlocksSection
            } else {
                if latestArchivedUnfinished != nil { unfinishedCarryBanner }
                quickStartBanner
            }
            if let message = viewModel.progressError {
                Text(message).font(.btFootnote).foregroundStyle(.btDestructive)
                    .padding(.horizontal, Spacing.lg)
            }

            planBrowsingSection
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Weekly / Today Training

    private var scheduledBlocksSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text("今日安排").font(.btTitle2).foregroundStyle(.btText)
                    .accessibilityIdentifier("trainingHome.todaySchedule")
                Spacer(minLength: Spacing.sm)
                todaySummary
            }
            .padding(Spacing.md)

            if let archived = latestArchivedUnfinished {
                Button {
                    carryForward(archived)
                } label: {
                    HStack {
                        Text("昨日有 \(archived.items.filter { $0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress }.count) 项未完成")
                        Spacer()
                        Text("加入今天").fontWeight(.semibold)
                    }
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trainingHome.carryYesterday")
            }

            Divider().padding(.horizontal, Spacing.md)

            ForEach(Array(orderedScheduleItems.enumerated()), id: \.element.id) { index, item in
                scheduleItemRow(item, index: index)
                if index < orderedScheduleItems.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
            if let suggestion = todayProjection.suggestion {
                if !orderedScheduleItems.isEmpty { Divider().padding(.horizontal, Spacing.md) }
                suggestedLessonRow(suggestion)
            }
            ForEach(todayProjection.history) { history in
                Divider().padding(.horizontal, Spacing.md)
                savedTrainingRows(history)
            }

        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay { RoundedRectangle(cornerRadius: BTRadius.lg).stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0) }
        .padding(.horizontal, Spacing.lg)
    }

    private var unfinishedCarryBanner: some View {
        Group {
            if let archived = latestArchivedUnfinished {
                Button { carryForward(archived) } label: {
                    HStack {
                        Text("昨日有未完成训练")
                        Spacer()
                        Text("加入今天").fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                    }
                    .font(.btSubheadline)
                    .foregroundStyle(.btPrimary)
                    .padding(Spacing.md)
                    .background(.btBGSecondary, in: RoundedRectangle(cornerRadius: BTRadius.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trainingHome.carryYesterday")
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private var todaySummary: some View {
        let projection = todayProjection
        return VStack(alignment: .trailing, spacing: Spacing.xs) {
            if projection.totalCount > 0 {
                Text("已完成 \(projection.completedCount) / \(projection.totalCount) 动作")
                    .font(.btSubheadlineSemibold).foregroundStyle(.btPrimary).monospacedDigit()
                if projection.allActionsCompleted {
                    Label("全部完成", systemImage: "checkmark.circle.fill")
                        .font(.btCaption).foregroundStyle(.btSuccess)
                } else if projection.allArrangedTrainingEnded {
                    Text("本次训练已结束").font(.btCaption).foregroundStyle(.btTextSecondary)
                }
            } else if projection.suggestion != nil {
                Text("建议课尚未加入").font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            if projection.estimatedMinutes > 0 {
                Text("预计共 \(projection.estimatedMinutes) 分钟")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            if projection.recordedMinutes > 0 {
                Text("已记录用时 \(projection.recordedMinutes) 分钟")
                    .font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            if projection.hasUnavailableContent {
                Text("部分内容暂不可用").font(.btCaption).foregroundStyle(.btWarning)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trainingHome.todaySummary")
    }

    private func suggestedLessonRow(_ session: TodaySessionInfo) -> some View {
        let expanded = orderedScheduleItems.isEmpty || suggestionExpanded
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(BTMotion.easeFast) { suggestionExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "book.closed").foregroundStyle(.btPrimary).frame(width: 30)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(session.planNameZh).font(.btSubheadlineSemibold).foregroundStyle(.btText)
                        Text("官方建议 · 第 \(session.dayNumber) 课 · 未加入")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                        Text("\(session.drills.count) 动作 · 预计 \(session.totalMinutes) 分钟")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                    }
                    Spacer(minLength: 0)
                    if !orderedScheduleItems.isEmpty {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.btCaption).foregroundStyle(.btTextTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trainingHome.suggestion")
            if expanded {
                ForEach(session.drills) { drill in
                    HStack(alignment: .firstTextBaseline) {
                        Text(drill.nameZh).font(.btSubheadline).foregroundStyle(.btText)
                        Spacer(minLength: Spacing.sm)
                        Text(drill.volumeText).font(.btCaption).foregroundStyle(.btTextSecondary)
                    }
                    .padding(.leading, 42)
                }
                HStack {
                    Spacer()
                    Button("加入并开始") { arrangeAndStartCurrentLesson() }
                        .buttonStyle(BTButtonStyle.text)
                        .accessibilityIdentifier("trainingHome.suggestion.start")
                }
            }
        }
        .padding(Spacing.md)
    }

    private func savedTrainingRows(_ history: TodayTrainingProjection.SavedTraining) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button { historySelection = history.session } label: {
                HStack {
                    Label(history.session.sourceTitleSnapshot ?? (history.session.planId == nil ? "自由训练" : "计划训练"),
                          systemImage: "checkmark.circle.fill")
                        .font(.btSubheadlineSemibold).foregroundStyle(.btSuccess)
                    Spacer()
                    Text("已保存").font(.btCaption).foregroundStyle(.btTextSecondary)
                    Image(systemName: "chevron.right").font(.btCaption).foregroundStyle(.btTextTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ForEach(history.entries) { entry in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Image(systemName: "checkmark").foregroundStyle(.btSuccess)
                    Text(entry.drillNameZh).font(.btSubheadline).foregroundStyle(.btText)
                    Spacer(minLength: Spacing.sm)
                    Text("\(entry.sets.count) 组").font(.btCaption).foregroundStyle(.btTextSecondary)
                }
            }
        }
        .padding(Spacing.md)
    }

    private func scheduleItemRow(_ item: TodayScheduleItem, index: Int) -> some View {
        let isSingleItem = orderedScheduleItems.count + (todayProjection.suggestion == nil ? 0 : 1) == 1
        let isExpanded = isSingleItem || expandedScheduleItemID == item.id

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isSingleItem {
                    scheduleItemHeader(item, isExpanded: true, showsDisclosure: false)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.sourceTitleSnapshot)，\(scheduleStateTitle(item))，\(scheduleSubtitle(item))，详细内容已显示")
                        .accessibilityIdentifier("trainingHome.scheduleItem.\(item.sourceId)")
                } else {
                    Button {
                        withAnimation(BTMotion.easeInOutFast) {
                            expandedScheduleItemID = isExpanded ? nil : item.id
                        }
                    } label: {
                        scheduleItemHeader(item, isExpanded: isExpanded, showsDisclosure: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.sourceTitleSnapshot)，\(scheduleStateTitle(item))，\(scheduleSubtitle(item))")
                    .accessibilityValue(isExpanded ? "已展开" : "已折叠")
                    .accessibilityHint(isExpanded ? "轻点折叠课程内容" : "轻点展开课程内容")
                    .accessibilityIdentifier("trainingHome.scheduleItem.\(item.sourceId)")
                }

                if item.state == TodayScheduleItemState.pending {
                    scheduleItemMenu(item, index: index)
                }
            }

            if isExpanded {
                scheduleItemDetails(item)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func scheduleItemHeader(
        _ item: TodayScheduleItem,
        isExpanded: Bool,
        showsDisclosure: Bool
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: scheduleIcon(item))
                .font(.btHeadline)
                .foregroundStyle(item.state == TodayScheduleItemState.completed ? Color.btSuccess : Color.btPrimary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.sourceTitleSnapshot)
                    .font(.btCallout.weight(.medium))
                    .foregroundStyle(.btText)
                    .lineLimit(1)
                Text(scheduleSubtitle(item))
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if item.state == TodayScheduleItemState.completed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.btSuccess)
            } else if item.state == TodayScheduleItemState.inProgress {
                Text("进行中").font(.btFootnote.weight(.semibold)).foregroundStyle(.btPrimary)
            }
            if showsDisclosure {
                Image(systemName: "chevron.down")
                    .font(.btCaption2.weight(.semibold))
                    .foregroundStyle(.btTextTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private func scheduleItemMenu(_ item: TodayScheduleItem, index: Int) -> some View {
        Menu {
            Button("上移", systemImage: "arrow.up") { moveScheduleItem(item, offset: -1) }
                .disabled(index == 0)
            Button("下移", systemImage: "arrow.down") { moveScheduleItem(item, offset: 1) }
                .disabled(index == orderedScheduleItems.count - 1)
            Button("删除", systemImage: "trash", role: .destructive) { removeScheduleItem(item) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.btTextTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("管理\(item.sourceTitleSnapshot)")
    }

    @ViewBuilder
    private func scheduleItemDetails(_ item: TodayScheduleItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider()

            if let projected = todayProjection.queued.first(where: { $0.id == item.id }),
               !projected.drills.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(Array(projected.drills.enumerated()), id: \.offset) { index, drill in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            if projected.completedDrills[index] {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.btSuccess)
                                    .accessibilityLabel("已完成")
                            }
                            Text(drill.phaseTitle)
                                .font(.btCaption)
                                .foregroundStyle(.btPrimary)
                                .lineLimit(1)
                                .frame(width: 62, alignment: .leading)
                            Text(drill.name)
                                .font(.btSubheadlineMedium)
                                .foregroundStyle(.btText)
                                .lineLimit(2)
                            Spacer(minLength: Spacing.xs)
                            Text(scheduleDose(for: drill))
                                .font(.btFootnote)
                                .foregroundStyle(.btTextSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            } else {
                Text("训练内容暂时无法读取")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }

            if let reason = todayProjection.queued.first(where: { $0.id == item.id })?.unavailableReason {
                Text(reason).font(.btFootnote).foregroundStyle(.btWarning)
            }

            if (item.state == TodayScheduleItemState.pending || item.state == TodayScheduleItemState.inProgress)
                && todayProjection.queued.first(where: { $0.id == item.id })?.unavailableReason == nil {
                HStack {
                    Spacer()
                    let actionTitle = item.state == TodayScheduleItemState.inProgress
                        ? "继续这节课" : "开始这节课"
                    Button(actionTitle) {
                        startScheduledItem(item)
                    }
                    .buttonStyle(BTButtonStyle.text)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(actionTitle)
                    .accessibilityIdentifier("trainingHome.scheduleItem.\(item.sourceId).start")
                }
            }
        }
        .padding(.leading, 58)
        .padding(.trailing, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private func scheduledDrills(for item: TodayScheduleItem) -> [ScheduledDrillSnapshot]? {
        do {
            return try ScheduledTrainingBlock(item: item).drills
        } catch {
            return nil
        }
    }

    private func scheduleDose(for drill: ScheduledDrillSnapshot) -> String {
        guard !drill.sets.isEmpty else { return "已编排" }
        let unit = DrillUnitLabel.label(category: drill.category, subcategory: drill.subcategory)
        let total = drill.sets.reduce(0) { $0 + max($1.targetBalls, 0) }
        if drill.sets.count == 1 { return "\(total)\(unit)" }
        return "\(drill.sets.count)组 · \(total)\(unit)"
    }

    private func scheduleIcon(_ item: TodayScheduleItem) -> String {
        switch item.sourceKind {
        case TodayScheduleSourceKind.officialLesson: return "book.closed"
        case TodayScheduleSourceKind.template: return "list.bullet.clipboard"
        default: return "circle.grid.cross"
        }
    }

    private func scheduleSubtitle(_ item: TodayScheduleItem) -> String {
        let state = scheduleStateTitle(item)
        if let subtitle = item.sourceSubtitleSnapshot, !subtitle.isEmpty { return "\(subtitle) · \(state)" }
        return state
    }

    private func scheduleStateTitle(_ item: TodayScheduleItem) -> String {
        switch item.state {
        case TodayScheduleItemState.inProgress: return "进行中"
        case TodayScheduleItemState.completed:
            if let row = todayProjection.queued.first(where: { $0.id == item.id }),
               row.completedCount < row.totalCount { return "已结束" }
            return "已完成"
        case TodayScheduleItemState.abandoned: return "已放弃"
        default: return "待训练"
        }
    }

    private var latestArchivedUnfinished: TodayTrainingSchedule? {
        schedules.filter { schedule in
            schedule.archivedAt != nil && schedule.items.contains {
                $0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress
            }
        }.max { $0.localDayKey < $1.localDayKey }
    }

    private func startScheduledItem(_ item: TodayScheduleItem) {
        do {
            if item.state == TodayScheduleItemState.pending {
                try TodayTrainingScheduleService(context: modelContext).markStarted(item)
            }
            router.startTraining(mode: .scheduled(try ScheduledTrainingBlock(item: item)))
        } catch {
            toast = BTToastMessage("无法开始这项训练，请重新编排", tone: .error)
        }
    }

    private func moveScheduleItem(_ item: TodayScheduleItem, offset: Int) {
        guard let schedule = currentSchedule else { return }
        var unfinished = orderedScheduleItems.filter {
            $0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress
        }
        guard let index = unfinished.firstIndex(where: { $0.id == item.id }) else { return }
        let target = index + offset
        guard unfinished.indices.contains(target) else { return }
        unfinished.swapAt(index, target)
        do {
            try TodayTrainingScheduleService(context: modelContext)
                .reorderUnfinished(unfinished.map(\.id), in: schedule)
        } catch {
            toast = BTToastMessage("调整顺序失败", tone: .error)
        }
    }

    private func removeScheduleItem(_ item: TodayScheduleItem) {
        do { try TodayTrainingScheduleService(context: modelContext).removePending(item) }
        catch { toast = BTToastMessage("进行中的训练不能删除", tone: .warning) }
    }

    private func carryForward(_ archived: TodayTrainingSchedule) {
        let active = PlanProgressService.currentOfficialPlan(in: activePlans)
        let official = active.flatMap { PlanContentService.decodePlanFromBundle(id: $0.planId) }
        do {
            _ = try TodayTrainingScheduleService(context: modelContext).carryForwardLatestUnfinished(
                ownerKey: ownerKey, activePlan: active, officialPlan: official
            )
            toast = BTToastMessage("已加入今天")
        } catch {
            toast = BTToastMessage("加入失败，请稍后重试", tone: .error)
        }
    }

    private func displayTodayDrills(for session: TodaySessionInfo?) -> [TodayDrillItem] {
        (session?.drills ?? []) + viewModel.todaySupplementalDrills
    }

    private var weeklyTrainingSection: some View {
        weeklyProgressCard
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
    }

    private func todayTrainingSection(_ session: TodaySessionInfo?) -> some View {
        let visibleDrills = displayTodayDrills(for: session)
        let completedCount = visibleDrills.filter(\.isCompleted).count
        let isAllCompleted = !visibleDrills.isEmpty && completedCount == visibleDrills.count

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text("今日安排")
                    .font(.btTitle2)
                    .foregroundStyle(.btText)
                    .layoutPriority(1)

                Spacer(minLength: Spacing.xs)

                if isAllCompleted {
                    Label("全部完成！", systemImage: BTIcon.completeSeal)
                        .font(.btSubheadlineSemibold)
                        .foregroundStyle(.btPrimary)
                } else {
                    todayScheduleMetrics(
                        completedCount: completedCount,
                        totalCount: visibleDrills.count,
                        expectedMinutes: expectedMinutesValue(for: session)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)

            Divider()
                .foregroundStyle(.btSeparator)
                .padding(.horizontal, Spacing.md)

            Group {
                if visibleDrills.count > Self.maximumVisibleTodayRows {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            todayDrillRows(visibleDrills)
                        }
                    }
                    .frame(height: Self.todayRowHeight * CGFloat(Self.maximumVisibleTodayRows))
                    .scrollIndicators(.visible)
                } else {
                    VStack(spacing: 0) {
                        todayDrillRows(visibleDrills)
                    }
                }
            }
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        }
        .shadow(
            color: colorScheme == .dark ? .clear : Color.btText.opacity(0.05),
            radius: 12,
            x: 0,
            y: 5
        )
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func todayDrillRows(_ drills: [TodayDrillItem]) -> some View {
        ForEach(Array(drills.enumerated()), id: \.element.id) { index, drill in
            NavigationLink {
                DrillDetailView(drillId: drill.drillId, ownerKey: ownerKey)
            } label: {
                todayDrillRow(drill, number: index + 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                drill.isCompleted
                    ? "\(drill.nameZh)，已完成，查看动作详情"
                    : "\(drill.nameZh)，查看动作详情"
            )

            if index < drills.count - 1 {
                Divider()
                    .padding(.leading, 138)
            }
        }
    }

    private func arrangeAndStartCurrentLesson() {
        guard let active = activeOfficialPlan,
              let lessonID = active.currentLessonId,
              let plan = PlanContentService.decodePlanFromBundle(id: active.planId) else {
            toast = BTToastMessage("当前课程暂时无法加载", tone: .error)
            return
        }
        do {
            let result = try TodayTrainingScheduleService(context: modelContext)
                .addOfficialLessons(plan: plan, lessonIDs: [lessonID], activePlan: active)
                .first
            let item: TodayScheduleItem?
            switch result {
            case .added(let value), .alreadyPresent(let value): item = value
            case nil: item = nil
            }
            guard let item else { throw TodayTrainingScheduleService.Error.lessonNotFound }
            startScheduledItem(item)
        } catch {
            toast = BTToastMessage("无法开始当前课程，请重新编排", tone: .error)
        }
    }

    private var weeklyProgressCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Text("本周训练")
                    .font(.btTitle2)
                    .foregroundStyle(.btText)
                    .layoutPriority(1)

                Spacer(minLength: Spacing.xs)

                Button {
                    router.trainingPath.append(TrainingRoute.dailyClearance)
                } label: {
                    HStack(spacing: 6) {
                        BreakRackGlyph(color: .btPrimary, size: 14)
                            .accessibilityHidden(true)
                        Text(dailyClearanceState.title)
                            .font(.btSubheadlineSemibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.right")
                            .font(.btCaption2.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 44)
                    .background(
                        Color.btPrimary.opacity(colorScheme == .dark ? 0.14 : 0.08),
                        in: Capsule()
                    )
                    .overlay { Capsule().stroke(Color.btPrimary.opacity(0.22), lineWidth: 1) }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("trainingHome.dailyClearance")
                .accessibilityLabel("每日清台，\(dailyClearanceState.accessibilityState)，\(dailyClearanceGame.displayName)")
                .accessibilityHint("打开单人清台挑战")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            Divider()
                .foregroundStyle(.btSeparator)
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text("本周")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)

                        Text("\(daysTrainedThisWeek) / \(displayedWeeklyGoalDays) 天")
                            .font(.btSubheadlineSemibold)
                            .foregroundStyle(.btText)
                            .monospacedDigit()
                    }

                    Spacer()

                    Rectangle()
                        .fill(Color.btSeparator)
                        .frame(width: 1, height: 18)
                        .accessibilityHidden(true)

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text("连续")
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)

                        Text("\(currentTrainingStreak) 天")
                            .font(.btSubheadlineSemibold)
                            .foregroundStyle(.btText)
                            .monospacedDigit()

                        if currentTrainingStreak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.btCaption2)
                                .foregroundStyle(.btWarning)
                                .accessibilityHidden(true)
                        }
                    }
                }

                HStack(spacing: Spacing.xs) {
                    ForEach(Array(currentWeekDays.enumerated()), id: \.element) { index, date in
                        weeklyDayCell(
                            label: Self.weekdayLabels[index],
                            date: date
                        )
                    }
                }
            }
            .padding(Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "本周训练 \(daysTrainedThisWeek) / \(displayedWeeklyGoalDays) 天，"
                + "连续训练 \(currentTrainingStreak) 天"
            )
        }
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: BTRadius.lg)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        }
        .shadow(
            color: colorScheme == .dark ? .clear : Color.btText.opacity(0.05),
            radius: 12,
            x: 0,
            y: 5
        )
    }

    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    private var currentWeekDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    private func weeklyDayCell(label: String, date: Date) -> some View {
        let isTrained = goalTrainingDays.contains(date)
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: Spacing.xs) {
            Text(label)
                .font(.btCaption2)
                .foregroundStyle(isToday ? .btText : .btTextSecondary)

            ZStack {
                Circle()
                    .fill(isTrained ? Color.btPrimary : Color.clear)

                Circle()
                    .stroke(
                        isTrained ? Color.btPrimary : Color.btSeparator,
                        lineWidth: 1.5
                    )

                if isTrained {
                    Image(systemName: "checkmark")
                        .font(.btCaption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: BTRadius.sm)
                .fill(isToday ? Color.btBGTertiary : Color.clear)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("周\(label)，\(isTrained ? "已训练" : "未训练")\(isToday ? "，今天" : "")")
    }

    private func todayScheduleMetrics(
        completedCount: Int,
        totalCount: Int,
        expectedMinutes: String
    ) -> some View {
        HStack(spacing: Spacing.xs) {
            todayScheduleMetric(
                symbol: "scope",
                title: "今日训练",
                value: "\(completedCount) / \(totalCount)"
            )

            Rectangle()
                .fill(Color.btSeparator)
                .frame(width: 1, height: 18)
                .accessibilityHidden(true)

            todayScheduleMetric(
                symbol: "clock",
                title: "用时",
                value: expectedMinutes,
                unit: expectedMinutes == "—" ? nil : "分钟"
            )
        }
    }

    private func todayScheduleMetric(
        symbol: String,
        title: String,
        value: String,
        unit: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.btCaption2)
            .foregroundStyle(.btTextSecondary)
            .fixedSize(horizontal: true, vertical: false)

            Text(value)
                .font(.btSubheadlineSemibold)
                .foregroundStyle(.btPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let unit {
                Text(unit)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(value)\(unit ?? "")")
    }

    private var goalTrainingDays: Set<Date> {
        Set(
            TrainingGoalMetrics.goalCounting(trainingSessions)
                .map { calendar.startOfDay(for: $0.date) }
        )
    }

    private func refreshDailyClearanceState() {
        let store = DailyClearanceStore()
        if let completion = store.loadTodayCompletion() {
            dailyClearanceState = .completed
            dailyClearanceGame = completion.game
        } else if let draft = store.loadTodayDraft() {
            dailyClearanceState = .inProgress
            dailyClearanceGame = draft.game
        } else {
            dailyClearanceState = .notStarted
            dailyClearanceGame = UserPreferences.shared.dailyClearanceGame
        }
    }

    /// v52 首页状态与重启持久化取证 seam。仅显式 UI 测试参数可触发，生产无入口。
    private func installDailyClearanceHomeFixtureIfNeeded() async {
        #if DEBUG
        guard !didInstallDailyClearanceHomeFixture else { return }
        didInstallDailyClearanceHomeFixture = true
        let args = ProcessInfo.processInfo.arguments
        let store = DailyClearanceStore()
        if args.contains("-dailyClearance.resetHomeState") {
            store.clearDraft()
            store.clearCompletion()
        }

        if args.contains("-dailyClearance.seedActivePlan"), activePlans.isEmpty {
            let plan = CustomPlan(name: "清台矩阵训练", sessionsPerWeek: 5,
                                  ownerKey: ownerKey)
            plan.drills.append(CustomPlanDrill(
                drillId: "drill_c001",
                drillNameZh: "五分点",
                roundsPerFormation: 1,
                order: 0
            ))
            modelContext.insert(plan)
            modelContext.insert(UserActivePlan(planId: plan.id.uuidString, isCustom: true,
                                               ownerKey: ownerKey))
            try? modelContext.save()
            await viewModel.load(context: modelContext, ownerKey: ownerKey)
        }

        guard let fixture = args.first(where: { $0.hasPrefix("-dailyClearance.seedHomeState=") })?
            .replacingOccurrences(of: "-dailyClearance.seedHomeState=", with: "") else { return }

        store.clearDraft()
        store.clearCompletion()
        var draft = store.makeDraft(game: .chineseEightBall, seed: 52)
        draft.phase = .playing
        draft.board = BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: CanvasPoint(x: 0.72, y: 0.50),
            "_1": CanvasPoint(x: 0.30, y: 0.42),
            "_8": CanvasPoint(x: 0.43, y: 0.56),
        ])

        switch fixture {
        case "progress":
            draft.shotCount = 2
            store.saveDraft(draft)
        case "completed":
            draft.shotCount = 7
            _ = store.complete(draft)
        default:
            break
        }
        #endif
    }

    private var displayedWeeklyGoalDays: Int {
        max(daysTrainedThisWeek, profile.weeklyGoalDays)
    }

    private var daysTrainedThisWeek: Int {
        guard let weekStart = currentWeekDays.first else {
            return 0
        }
        return TrainingGoalMetrics.daysTrained(
            trainingSessions,
            since: weekStart,
            calendar: calendar
        )
    }

    private func expectedMinutesValue(for session: TodaySessionInfo?) -> String {
        guard let minutes = session?.totalMinutes, minutes > 0 else { return "—" }
        return "\(minutes)"
    }

    private var currentTrainingStreak: Int {
        guard !goalTrainingDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: .now)
        if !goalTrainingDays.contains(cursor),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = yesterday
        }

        var streak = 0
        while goalTrainingDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    private func phaseColor(for type: String) -> Color {
        switch type {
        case "warmup":
            return .btSuccess
        case "focused":
            return .btPrimary
        case "combined":
            return .btDataSecondary
        default:
            return .btTextSecondary
        }
    }

    private func todayDrillThumbnail(_ drill: TodayDrillItem) -> some View {
        BTDrillListThumbnail(
            drillId: drill.drillId,
            opacity: 1
        )
    }

    private func todayDrillRow(
        _ drill: TodayDrillItem,
        number: Int
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(String(format: "%02d", number))
                .font(.btSubheadlineSemibold)
                .foregroundStyle(.btPrimary)
                .monospacedDigit()
                .frame(width: 38, height: 48)
                .background(Color.btPrimary.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            todayDrillThumbnail(drill)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(phaseColor(for: drill.phaseType))
                        .frame(width: 5, height: 5)
                    Text(drill.phaseZh)
                        .font(.btCaption2.weight(.medium))
                        .foregroundStyle(.btTextSecondary)
                        .lineLimit(1)
                }

                Text(drill.nameZh)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                    .lineLimit(2)

                Text(drill.volumeText)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if drill.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.btTitle2)
                    .foregroundStyle(.btPrimary)
                    .accessibilityHidden(true)
            }

            Image(systemName: "chevron.right")
                .font(.btFootnote)
                .foregroundStyle(.btTextTertiary)
                .frame(width: 24)
                .accessibilityHidden(true)

        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .frame(minHeight: Self.todayRowHeight)
        .contentShape(Rectangle())
    }

    // MARK: - Plan Browsing Section

    private var planBrowsingSection: some View {
        VStack(spacing: 0) {
            BTSegmentedTab(
                tabs: PlanBrowseTab.allCases,
                selected: Binding(get: { viewModel.selectedTab }, set: { value in
                    preserveBrowsePosition()
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { viewModel.selectedTab = value }
                }),
                label: { $0.rawValue }
            )
            .padding(.horizontal, Spacing.lg)

            Divider().foregroundStyle(.btSeparator)

            Group {
                if viewModel.selectedTab == .official {
                    officialPlanBrowsing
                } else {
                    customPlanBrowsing
                }
            }
        }
        .id(TrainingHomeViewModel.scrollBrowsingID)
    }

    private func preserveBrowsePosition() {
        // Read the hosting scroll view: SwiftUI's named-space preferences may be
        // resolved inside the content on iOS 26 and report zero while it scrolls.
        // Keeping enough content for this exact offset prevents UIKit's bottom clamp.
        if let scroll = scrollReference.scrollView {
            retainedContentHeight = max(0, scroll.contentOffset.y + scroll.bounds.height
                - scroll.adjustedContentInset.bottom)
        }
        viewModel.restorePlanID = nil
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
                        guard viewModel.selectedFilter != filter else { return }
                        preserveBrowsePosition()
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) { viewModel.selectedFilter = filter }
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
                    Button {
                        viewModel.restorePlanID = plan.id
                        router.trainingPath.append(TrainingRoute.planDetail(planId: plan.id))
                    } label: {
                        planPosterCard(plan, issueNumber: index + 1)
                    }
                    .buttonStyle(.plain)
                    .id(plan.id)
                    .accessibilityIdentifier("planPoster-\(plan.id)")
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
    }

    private func planPosterCard(_ plan: PlanBrowseItem, issueNumber: Int) -> some View {
        BTContentGridCard(
            title: plan.nameZh,
            subtitle: "\(plan.durationWeeks) 阶段 · \(plan.lessonCount) 课",
            // Shorter than 1:1 so title/meta clear the fixed bottom CTA when the grid peeks.
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
            .overlay(alignment: .bottomLeading) {
                BTPlanActivationBadge(status: PlanProgressService.displayState(for: plan.id, in: activePlans))
                    .padding(Spacing.sm)
            }
        }
    }

    private func customIssueThumbnail(planId: UUID, issueNumber: Int) -> some View {
        CustomPlanThumbnail(planId: planId, issueNumber: issueNumber)
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
                    title: "还没有模版",
                    subtitle: "创建你自己的训练方案",
                    actionTitle: "新建模版",
                    actionStyle: .secondary,
                    action: {
                        viewModel.restorePlanID = nil
                        router.trainingPath.append(TrainingRoute.customPlanBuilder)
                    }
                )
            } else {
                ForEach(Array(customPlans.enumerated()), id: \.element.id) { index, plan in
                    customPlanCard(plan, issueNumber: index + 1)
                        .id(plan.id.uuidString)
                }
                createTemplateRow
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
    }

    private func customPlanCard(_ plan: CustomPlan, issueNumber: Int) -> some View {
        let isActive = isUsedToday(plan)

        return HStack(spacing: Spacing.md) {
            Button {
                viewModel.restorePlanID = plan.id.uuidString
                router.trainingPath.append(TrainingRoute.customPlanEdit(planId: plan.id))
            } label: {
            HStack(spacing: Spacing.md) {
                customIssueThumbnail(planId: plan.id, issueNumber: issueNumber)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(plan.name)
                        .font(.btTitleMedium)
                        .foregroundStyle(.btText)
                        .lineLimit(1)

                    Text(customPlanSubtitle(plan))
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: BTIcon.sliders)
                                .font(.btMicro)
                            Text("模版")
                                .font(.btCaption2)
                        }
                        .foregroundStyle(.btPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.btPrimaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))

                        if isActive {
                            HStack(spacing: 2) {
                                Image(systemName: BTIcon.checkmarkCircle)
                                    .font(.btMicro)
                                Text("已在今日安排")
                                    .font(.btCaption2)
                            }
                            .foregroundStyle(.btPrimary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.btPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                        }
                    }
                    .padding(.top, Spacing.xs)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑模版，\(plan.name)")
            .accessibilityIdentifier("trainingHome.template.edit.\(plan.id)")

            Menu {
                Button {
                    viewModel.restorePlanID = plan.id.uuidString
                    router.trainingPath.append(TrainingRoute.customPlanEdit(planId: plan.id))
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button {
                    requestUseForToday(plan)
                } label: {
                    Label(isActive ? "已在今日安排" : "加入今日安排", systemImage: "plus.circle")
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("管理模版，\(plan.name)")
            .accessibilityIdentifier("trainingHome.template.menu.\(plan.id)")
        }
        // F-TR-13: match PlanListView — both modes btBGSecondary + BTRadius.md
        .padding(Spacing.md)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .onLongPressGesture { requestDelete(plan) }
    }

    private var createTemplateRow: some View {
        Button {
            viewModel.restorePlanID = nil
            router.trainingPath.append(TrainingRoute.customPlanBuilder)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: BTIcon.plusCircleFilled)
                    .font(.btTitle2)
                    .fontWeight(.regular)
                    .foregroundStyle(.btPrimary)
                Text("新建模版")
                    .font(.btBody)
                    .foregroundStyle(.btPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .buttonStyle(BTPressableStyle.row)
    }

    private func isUsedToday(_ plan: CustomPlan) -> Bool {
        orderedScheduleItems.contains {
            $0.sourceKind == TodayScheduleSourceKind.template &&
            $0.sourceId == plan.id.uuidString &&
            ($0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress)
        }
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
            BTToast.present("已在今日安排", tone: .info) { toast = $0 }
            return
        }
        addTemplateToToday(plan)
    }

    private func requestDelete(_ plan: CustomPlan) {
        planToDelete = plan
        showDeleteConfirm = true
    }

    private func addTemplateToToday(_ plan: CustomPlan) {
        do {
            _ = try TodayTrainingScheduleService(context: modelContext).addTemplate(plan)
            toast = BTToastMessage("已加入今日安排")
        } catch {
            print("[TrainingHomeView] add template failed: \(error)")
            BTToast.present("无法加入今日安排，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func deleteCustomPlan() {
        guard let plan = planToDelete else { return }
        let planIdStr = plan.id.uuidString
        do {
            let descriptor = FetchDescriptor<UserActivePlan>(
                predicate: #Predicate { $0.ownerKey == ownerKey && $0.planId == planIdStr }
            )
            let actives = try modelContext.fetch(descriptor)
            modelContext.delete(plan)
            for active in actives {
                modelContext.delete(active)
            }
            try modelContext.save()
            planToDelete = nil
        } catch {
            print("[TrainingHomeView] delete failed: \(error)")
            BTToast.present("删除失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: Spacing.xl) {
            weeklyTrainingSection
            if latestArchivedUnfinished != nil { unfinishedCarryBanner }
            if !viewModel.todaySupplementalDrills.isEmpty {
                todayTrainingSection(nil)
            }

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

            Text("或直接进行自由训练")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)

            Button {
                startFreeTraining()
            } label: {
                Text("自由训练")
                    .font(.btCallout.weight(.medium))
                    .foregroundStyle(.btPrimary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, Spacing.lg)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("trainingHome.freeRecord")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private var isFreeTrainingPrimary: Bool { nextScheduleItem == nil && todayProjection.suggestion == nil }

    private func startFreeTraining() {
        if router.isTrainingMinimized { router.resumeMinimizedTraining(); return }
        router.startTraining(mode: .free)
        router.activeTrainingVM?.showDrillPicker = true
    }

    // MARK: - Fixed Start Button

    /// The single primary action for today's whole session. Individual rows stay informational.
    private var startTrainingCircle: some View {
        Button {
            if router.isTrainingMinimized { router.resumeMinimizedTraining() }
            else if let item = nextScheduleItem { startScheduledItem(item) }
            else if todayProjection.suggestion != nil { arrangeAndStartCurrentLesson() }
            else { startFreeTraining() }
        } label: {
            Text(isFreeTrainingPrimary ? "自由训练" : (nextScheduleItem?.state == TodayScheduleItemState.inProgress ? "继续" : "训练"))
                .font(.btHeadline)
                .foregroundStyle(.white)
                .frame(width: isFreeTrainingPrimary ? 112 : 64, height: 64)
                .background(
                    RadialGradient(
                        colors: [Color.btPrimary.opacity(0.95), Color.btPrimary],
                        center: .center,
                        startRadius: 4,
                        endRadius: 36
                    ),
                    in: Capsule()
                )
        }
        .buttonStyle(BTPressableStyle.capsule)
        .accessibilityIdentifier(isFreeTrainingPrimary ? "trainingHome.freeTraining" : "trainingHome.startTraining")
        .accessibilityLabel(
            isFreeTrainingPrimary ? "自由训练" : (nextScheduleItem?.state == TodayScheduleItemState.inProgress ? "继续" : "开始训练")
        )
        .shadow(color: Color.btPrimary.opacity(0.24), radius: 14, x: 0, y: 6)
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, 18)
        .ignoresSafeArea(.container, edges: .bottom)
        .transition(.scale.combined(with: .opacity))
        .animation(BTMotion.springPanel, value: router.isTrainingMinimized)
    }

}

// MARK: - Previews

private final class TrainingHomeScrollReference: ObservableObject {
    weak var scrollView: UIScrollView?
}

private struct TrainingHomeScrollResolver: UIViewRepresentable {
    let reference: TrainingHomeScrollReference

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let current = ancestor {
                if let scroll = current as? UIScrollView {
                    reference.scrollView = scroll
                    return
                }
                ancestor = current.superview
            }
        }
    }
}

#Preview("With Plan") {
    NavigationStack {
        TrainingHomeView()
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
}

#Preview("No Plan - Dark") {
    NavigationStack {
        TrainingHomeView()
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(AppRouter())
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}

/// Page-local decoration in this view's 2D point coordinate space (top-left origin).
/// It is ornamental only and intentionally makes no table, angle, or pocket claim.
private struct TrainingHomeBlueprintBackground: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            drawReticle(
                in: &context,
                center: CGPoint(x: size.width - 28, y: 92),
                radius: 22
            )

            drawReticle(
                in: &context,
                center: CGPoint(x: 24, y: size.height * 0.48),
                radius: 15
            )

            var route = Path()
            route.move(to: CGPoint(x: size.width * 0.58, y: 270))
            route.addLine(to: CGPoint(x: size.width * 0.82, y: 220))
            route.addLine(to: CGPoint(x: size.width + 18, y: 304))
            context.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            context.stroke(
                Path(ellipseIn: CGRect(
                    x: size.width * 0.82 - 6,
                    y: 214,
                    width: 12,
                    height: 12
                )),
                with: .color(color),
                lineWidth: 1
            )

            var ruler = Path()
            let rulerY = size.height * 0.73
            ruler.move(to: CGPoint(x: 0, y: rulerY))
            ruler.addLine(to: CGPoint(x: min(size.width * 0.34, 144), y: rulerY))
            for index in 0...10 {
                let x = CGFloat(index) * 12
                let tick = index.isMultiple(of: 5) ? 9.0 : 5.0
                ruler.move(to: CGPoint(x: x, y: rulerY))
                ruler.addLine(to: CGPoint(x: x, y: rulerY + tick))
            }
            context.stroke(ruler, with: .color(color), lineWidth: 1)

            var arc = Path()
            arc.addArc(
                center: CGPoint(x: size.width - 18, y: size.height * 0.86),
                radius: 44,
                startAngle: .degrees(120),
                endAngle: .degrees(270),
                clockwise: false
            )
            context.stroke(arc, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawReticle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        context.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(color),
            lineWidth: 1
        )

        var crosshair = Path()
        crosshair.move(to: CGPoint(x: center.x - radius - 8, y: center.y))
        crosshair.addLine(to: CGPoint(x: center.x + radius + 8, y: center.y))
        crosshair.move(to: CGPoint(x: center.x, y: center.y - radius - 8))
        crosshair.addLine(to: CGPoint(x: center.x, y: center.y + radius + 8))
        context.stroke(crosshair, with: .color(color), lineWidth: 1)

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
            with: .color(color)
        )
    }
}
