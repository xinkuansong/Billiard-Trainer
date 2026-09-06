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
    @State private var expandedScheduleItemIDs: Set<UUID> = []
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
            BTBlueprintBackground(style: .training)
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

        }
        .btTrainingPillOverlay(isPresented: !router.isTrainingMinimized, includesTabBar: true) {
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

    private var unfinishedScheduleItems: [TodayScheduleItem] {
        orderedScheduleItems.filter {
            $0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress
        }
    }

    private var endedScheduleItems: [TodayScheduleItem] {
        orderedScheduleItems.filter {
            $0.state != TodayScheduleItemState.pending && $0.state != TodayScheduleItemState.inProgress
        }
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
            if state == "freeCompleted" || state == "multipleFree" {
                let saved = TrainingSession(ownerKey: ownerKey)
                saved.totalDurationMinutes = 8
                modelContext.insert(saved)
                let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球")
                modelContext.insert(entry)
                let set = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8)
                modelContext.insert(set)
                entry.sets = [set]
                saved.drillEntries = [entry]
                if state == "multipleFree" {
                    let start = Calendar.current.startOfDay(for: .now)
                    saved.date = start.addingTimeInterval(60)
                    for (offset, made) in [(120.0, 5), (-60.0, 2)] {
                        let another = TrainingSession(ownerKey: ownerKey)
                        another.date = start.addingTimeInterval(offset)
                        modelContext.insert(another)
                        let anotherEntry = DrillEntry(drillId: "drill_c001", drillNameZh: "直线球")
                        modelContext.insert(anotherEntry)
                        let anotherSet = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: made)
                        modelContext.insert(anotherSet)
                        anotherEntry.sets = [anotherSet]
                        another.drillEntries = [anotherEntry]
                    }
                }
                try modelContext.save()
                return
            }
            if state == "templateCard" {
                let count = Int(args.first(where: { $0.hasPrefix("-v54.templateCount=") })?
                    .replacingOccurrences(of: "-v54.templateCount=", with: "") ?? "6") ?? 6
                let names = ["半台直线球", "直线推白球", "底袋直线出杆", "中袋直线出杆", "近台小角度进球", "高杆跟进"]
                let template = CustomPlan(name: "测试名字", sessionsPerWeek: 1, ownerKey: ownerKey)
                template.id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
                modelContext.insert(template)
                for index in 0..<count {
                    let drill = CustomPlanDrill(drillId: "drill_c001", drillNameZh: names[index % names.count],
                                               roundsPerFormation: 1, order: index)
                    modelContext.insert(drill)
                    template.drills.append(drill)
                }
                _ = try TodayTrainingScheduleService(context: modelContext).addTemplate(template)
                for _ in 0..<3 {
                    let session = TrainingSession(ownerKey: ownerKey)
                    modelContext.insert(session)
                    session.sourceKind = TodayScheduleSourceKind.template
                    session.sourceId = template.id.uuidString
                    session.planId = template.id.uuidString
                    for drill in template.drills {
                        let entry = DrillEntry(drillId: drill.drillId, drillNameZh: drill.drillNameZh)
                        modelContext.insert(entry)
                        session.drillEntries.append(entry)
                    }
                }
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
                if state == "completed" || ((state == "partial" || state == "suggestionAfterCompleted") && index == 0) {
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
            if state == "suggestionAfterCompleted" {
                active.currentLessonId = plan.lessons[1].id
            }
            if state == "unifiedHistory" {
                for item in items {
                    let block = try ScheduledTrainingBlock(item: item)
                    let saved = TrainingSession(ownerKey: ownerKey)
                    saved.planId = block.planID
                    saved.lessonId = block.lessonID
                    saved.sourceKind = block.sourceKind
                    saved.sourceTitleSnapshot = block.sourceTitle
                    saved.sourcePayloadSnapshot = block.payloadSnapshot
                    modelContext.insert(saved)
                    let entry = DrillEntry(drillId: block.drills[0].drillID,
                                           drillNameZh: block.drills[0].name)
                    modelContext.insert(entry)
                    let set = DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8)
                    modelContext.insert(set)
                    entry.sets = [set]
                    saved.drillEntries = [entry]
                }
            }
            try modelContext.save()
        } catch {
            assertionFailure("v54/v57 schedule fixture failed: \(error)")
            BTToast.present("测试数据创建失败", tone: .error) { toast = $0 }
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
                        Text("昨日有 \(carryForwardCandidates(archived).count) 项未完成")
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

            ForEach(Array(unfinishedScheduleItems.enumerated()), id: \.element.id) { index, item in
                scheduleItemRow(item, index: index)
                if index < unfinishedScheduleItems.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
            if let suggestion = todayProjection.suggestion {
                if !unfinishedScheduleItems.isEmpty { Divider().padding(.horizontal, Spacing.md) }
                suggestedLessonRow(suggestion)
            }
            ForEach(Array(endedScheduleItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 || !unfinishedScheduleItems.isEmpty || todayProjection.suggestion != nil {
                    Divider().padding(.leading, 58)
                }
                scheduleItemRow(item, index: index)
            }
            ForEach(Array(todayProjection.history.enumerated()), id: \.element.id) { index, history in
                if index > 0 || !orderedScheduleItems.isEmpty || todayProjection.suggestion != nil {
                    Divider().padding(.leading, 58)
                }
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
            if projection.allActionsCompleted {
                Text("全部完成")
                    .font(.btSubheadlineSemibold).foregroundStyle(.btSuccess)
            } else {
                if projection.totalCount > 0 {
                    Text("已完成 \(projection.completedCount) / \(projection.totalCount) 动作")
                        .font(.btSubheadlineSemibold).foregroundStyle(.btPrimary).monospacedDigit()
                    if projection.allArrangedTrainingEnded {
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
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("trainingHome.todaySummary")
    }

    private func suggestedLessonRow(_ session: TodaySessionInfo) -> some View {
        let expanded = suggestionExpanded
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(BTMotion.easeFast) { suggestionExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "book.closed").foregroundStyle(.btPrimary).frame(width: 30)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("\(session.planNameZh) · 第 \(session.dayNumber) 课").font(.btCallout.weight(.medium)).foregroundStyle(.btText)
                        Text("官方建议 · 未加入")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                        Text("\(session.drills.count) 动作 · 预计 \(session.totalMinutes) 分钟")
                            .font(.btCaption).foregroundStyle(.btTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.btCaption).foregroundStyle(.btTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "已展开" : "已折叠")
            .accessibilityIdentifier("trainingHome.suggestion")
            if expanded {
                ForEach(session.drills) { drill in
                    trainingDrillRow(
                        type: drill.phaseZh, name: drill.nameZh, dose: drill.volumeText,
                        completed: drill.isCompleted, drillID: drill.drillId
                    )
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
        let expanded = expandedScheduleItemIDs.contains(history.id)
        let source = savedTrainingSource(history.session)
        return VStack(spacing: 0) {
            Button {
                withAnimation(BTMotion.easeInOutFast) {
                    toggleScheduleItem(history.id)
                }
            } label: {
                trainingDisclosureHeader(title: source.title, icon: source.icon,
                                         state: TodayScheduleItemState.completed, isExpanded: expanded)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(source.title)，已完成")
            .accessibilityValue(expanded ? "已展开" : "已折叠")
            .accessibilityHint(expanded ? "轻点折叠训练内容" : "轻点展开训练内容")
            .accessibilityIdentifier("trainingHome.savedTraining.\(history.id)")
            if expanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Divider()
                    ForEach(history.entries) { entry in
                        trainingDrillRow(
                            type: trainingDetailType(kind: source.kind), name: entry.drillNameZh,
                            dose: savedTrainingDose(entry),
                            completed: true, drillID: entry.drillId
                        )
                    }
                    HStack {
                        Spacer()
                        Button("查看训练记录") { historySelection = history.session }
                            .buttonStyle(BTButtonStyle.text)
                            .accessibilityIdentifier("trainingHome.savedTraining.\(history.id).detail")
                    }
                }
                .padding(.leading, 58)
                .padding(.trailing, Spacing.md)
                .padding(.bottom, Spacing.sm)
            }
        }
    }

    private func scheduleItemRow(_ item: TodayScheduleItem, index: Int) -> some View {
        let isExpanded = expandedScheduleItemIDs.contains(item.id)

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(BTMotion.easeInOutFast) {
                        toggleScheduleItem(item.id)
                    }
                } label: {
                    trainingDisclosureHeader(title: scheduleTitle(item), icon: scheduleIcon(item),
                                             state: item.state, isExpanded: isExpanded)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(scheduleTitle(item))，\(scheduleStateTitle(item))")
                .accessibilityValue(isExpanded ? "已展开" : "已折叠")
                .accessibilityHint(isExpanded ? "轻点折叠课程内容" : "轻点展开课程内容")
                .accessibilityIdentifier("trainingHome.scheduleItem.\(item.sourceId)")

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

    private func toggleScheduleItem(_ id: UUID) {
        if !expandedScheduleItemIDs.insert(id).inserted {
            expandedScheduleItemIDs.remove(id)
        }
    }

    private func savedTrainingDose(_ entry: DrillEntry) -> String {
        let groups = Dictionary(grouping: entry.sets, by: \.unitLabel)
        let totals = groups.keys.sorted().map { unit in
            "\(groups[unit, default: []].reduce(0) { $0 + max(0, $1.targetBalls) })\(unit)"
        }
        return (["\(entry.sets.count)组"] + totals).joined(separator: " · ")
    }

    private func trainingDetailType(kind: String, phase: String = "专项训练") -> String {
        switch kind {
        case TodayScheduleSourceKind.template: return "模版"
        case TodayScheduleSourceKind.officialLesson: return phase
        default: return "自由"
        }
    }

    private func trainingDrillRow(
        type: String, name: String, dose: String, completed: Bool, drillID: String
    ) -> some View {
        NavigationLink(value: TrainingRoute.drillDetail(drillId: drillID)) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.btSuccess)
                }
                Text(type)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                    .lineLimit(1)
                    .frame(width: 52, alignment: .trailing)
                BTBakedDrillTable(drillId: drillID)
                    .frame(width: 64, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.xxs))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(name)
                        .font(.btSubheadlineMedium)
                        .foregroundStyle(.btText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(dose)
                        .font(.btFootnote)
                        .foregroundStyle(.btTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("trainingHome.drillDetail.\(drillID)")
        .accessibilityLabel("\(type)，\(name)，\(dose)\(completed ? "，已完成" : "")")
        .accessibilityHint("查看动作详情，返回后保留今日安排位置")
    }

    private func trainingDisclosureHeader(
        title: String, icon: String, state: String, isExpanded: Bool
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.btHeadline)
                .foregroundStyle(state == TodayScheduleItemState.completed ? Color.btSuccess : Color.btPrimary)
                .frame(width: 30)
            scheduleDisclosureTitle(title)
                .font(.btCallout.weight(.medium))
                .foregroundStyle(.btText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            if state == TodayScheduleItemState.completed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.btSuccess)
            } else if state == TodayScheduleItemState.inProgress {
                Text("进行中").font(.btFootnote.weight(.semibold)).foregroundStyle(.btPrimary)
                    .fixedSize()
            } else if state == TodayScheduleItemState.abandoned {
                Text("已结束").font(.btFootnote).foregroundStyle(.btTextSecondary)
                    .fixedSize()
            }
            Image(systemName: "chevron.down")
                .font(.btCaption2.weight(.semibold))
                .foregroundStyle(.btTextTertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func scheduleDisclosureTitle(_ title: String) -> some View {
        if let separator = title.range(of: " · ", options: .backwards),
           title[..<separator.lowerBound].count <= 4 {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                // Measure four Chinese characters in the actual inherited font,
                // so the shared separator position also follows Dynamic Type.
                Text("训练计划")
                    .hidden()
                    .overlay(alignment: .leading) {
                        Text(String(title[..<separator.lowerBound]))
                    }
                Text(String(title[separator.lowerBound...]))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
        } else {
            Text(title)
        }
    }

    private var freeTrainingOrdinals: [UUID: Int] {
        TodayTrainingProjection.freeTrainingOrdinals(
            sessions: trainingSessions, ownerKey: ownerKey, day: .now
        )
    }

    private func scheduleTitle(_ item: TodayScheduleItem) -> String {
        if let session = trainingSessions.last(where: {
            $0.scheduleItemId == item.id || $0.id == item.trainingSessionId
        }), let ordinal = freeTrainingOrdinals[session.id] {
            return "自由训练 · 第\(ordinal)次"
        }
        return trainingSourceTitle(kind: item.sourceKind, title: item.sourceTitleSnapshot,
                            payload: item.payloadSnapshot, planID: item.planId, lessonID: item.lessonId)
    }

    private func savedTrainingSource(_ session: TrainingSession) -> (title: String, icon: String, kind: String) {
        let template = customPlans.first { $0.id.uuidString == session.planId }
        let kind = session.sourceKind ?? (template != nil ? TodayScheduleSourceKind.template
            : (session.planId != nil ? TodayScheduleSourceKind.officialLesson : TodayScheduleSourceKind.libraryDrill))
        let title = freeTrainingOrdinals[session.id].map { "自由训练 · 第\($0)次" }
            ?? trainingSourceTitle(kind: kind, title: session.sourceTitleSnapshot ?? template?.name,
                                        payload: session.sourcePayloadSnapshot,
                                        planID: session.planId, lessonID: session.lessonId)
        let icon = kind == TodayScheduleSourceKind.officialLesson ? "book.closed"
            : (kind == TodayScheduleSourceKind.template ? "list.bullet.clipboard" : "circle.grid.cross")
        return (title, icon, kind)
    }

    private func trainingSourceTitle(
        kind: String, title: String?, payload: Data?, planID: String?, lessonID: String?
    ) -> String {
        if kind == TodayScheduleSourceKind.officialLesson {
            if let payload {
                do {
                    let lesson = try JSONDecoder().decode(ScheduledLessonPayload.self, from: payload)
                    return "\(lesson.planTitle) · 第 \(lesson.lesson.order) 课"
                } catch {
                    print("[TrainingHome] Cannot decode lesson title (\(lessonID ?? "unknown")): \(error)")
                }
            }
            let plan = planID.flatMap { PlanContentService.decodePlanFromBundle(id: $0) }
            let name = plan?.nameZh ?? title ?? "计划训练"
            if let lesson = plan?.lessons.first(where: { $0.id == lessonID }) {
                return "\(name) · 第 \(lesson.order) 课"
            }
            // Legacy sessions without a lesson identifier cannot recover a reliable lesson number.
            return name
        }
        let name = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = kind == TodayScheduleSourceKind.template ? "训练模版" : "自由训练"
        return "\(name.flatMap { $0.isEmpty ? nil : $0 } ?? fallback) · \(kind == TodayScheduleSourceKind.template ? "模版" : "自由")"
    }

    private func scheduleItemMenu(_ item: TodayScheduleItem, index: Int) -> some View {
        Menu {
            Button("上移", systemImage: "arrow.up") { moveScheduleItem(item, offset: -1) }
                .disabled(index == 0)
            Button("下移", systemImage: "arrow.down") { moveScheduleItem(item, offset: 1) }
                .disabled(index == unfinishedScheduleItems.count - 1)
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
                        trainingDrillRow(
                            type: trainingDetailType(kind: item.sourceKind, phase: drill.phaseTitle),
                            name: drill.name, dose: scheduleDose(for: drill),
                            completed: projected.completedDrills[index], drillID: drill.drillID
                        )
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

            ForEach(trainingSessions.filter {
                $0.ownerKey == ownerKey && $0.kind == TrainingSessionKind.drill
                    && ($0.scheduleItemId == item.id || $0.id == item.trainingSessionId)
            }) { session in
                HStack {
                    Spacer()
                    Button("查看训练记录") { historySelection = session }
                        .buttonStyle(BTButtonStyle.text)
                        .accessibilityIdentifier("trainingHome.scheduleItem.\(item.sourceId).detail")
                }
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
        return "\(drill.sets.count)组 · \(total)\(unit)"
    }

    private func scheduleIcon(_ item: TodayScheduleItem) -> String {
        switch item.sourceKind {
        case TodayScheduleSourceKind.officialLesson: return "book.closed"
        case TodayScheduleSourceKind.template: return "list.bullet.clipboard"
        default: return "circle.grid.cross"
        }
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
        let latest = schedules.filter { schedule in
            schedule.ownerKey == ownerKey && schedule.archivedAt != nil
                && schedule.items.contains {
                    $0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress
                }
        }.max { $0.localDayKey < $1.localDayKey }
        guard let latest, !carryForwardCandidates(latest).isEmpty else { return nil }
        return latest
    }

    private func carryForwardCandidates(_ schedule: TodayTrainingSchedule) -> [TodayScheduleItem] {
        TodayTrainingScheduleService.carryForwardCandidates(
            from: schedule, todayItems: orderedScheduleItems,
            activePlanID: activeOfficialPlan?.planId)
    }

    private func startScheduledItem(_ item: TodayScheduleItem) {
        do {
            if item.state == TodayScheduleItemState.pending {
                try TodayTrainingScheduleService(context: modelContext).markStarted(item)
            }
            router.startTraining(mode: .scheduled(try ScheduledTrainingBlock(item: item)))
        } catch {
            BTToast.present("无法开始这项训练，请重新编排", tone: .error) { toast = $0 }
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
            BTToast.present("调整顺序失败", tone: .error) { toast = $0 }
        }
    }

    private func removeScheduleItem(_ item: TodayScheduleItem) {
        do { try TodayTrainingScheduleService(context: modelContext).removePending(item) }
        catch { BTToast.present("进行中的训练不能删除", tone: .warning) { toast = $0 } }
    }

    private func carryForward(_ archived: TodayTrainingSchedule) {
        let active = PlanProgressService.currentOfficialPlan(in: activePlans)
        let official = active.flatMap { PlanContentService.decodePlanFromBundle(id: $0.planId) }
        do {
            _ = try TodayTrainingScheduleService(context: modelContext).carryForwardLatestUnfinished(
                ownerKey: ownerKey, activePlan: active, officialPlan: official
            )
            BTToast.present("已加入今天") { toast = $0 }
        } catch {
            BTToast.present("加入失败，请稍后重试", tone: .error) { toast = $0 }
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
        guard todayProjection.suggestion != nil else { return }
        guard let active = activeOfficialPlan,
              let lessonID = active.currentLessonId,
              let plan = PlanContentService.decodePlanFromBundle(id: active.planId) else {
            BTToast.present("当前课程暂时无法加载", tone: .error) { toast = $0 }
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
            BTToast.present("无法开始当前课程，请重新编排", tone: .error) { toast = $0 }
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
                    BTProBadge(isUnlocked: subscriptionManager.isPremium)
                        .padding(Spacing.sm)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                BTPlanActivationBadge(status: PlanProgressService.displayState(for: plan.id, in: activePlans))
                    .padding(Spacing.sm)
            }
        }
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

    private var templatePracticeCounts: [UUID: Int] {
        TemplatePracticeCounts.make(sessions: trainingSessions, ownerKey: ownerKey)
    }

    private func customPlanCard(_ plan: CustomPlan, issueNumber: Int) -> some View {
        let isActive = isUsedToday(plan)
        let practiceCount = templatePracticeCounts[plan.id, default: 0]

        return BTTemplateCard(
            planID: plan.id, issueNumber: issueNumber, title: plan.name,
            actionNames: plan.drills.sorted { $0.order < $1.order }.map(\.drillNameZh),
            isScheduled: isActive, practiceCount: practiceCount,
            editIdentifier: "trainingHome.template.edit.\(plan.id)",
            onEdit: {
                viewModel.restorePlanID = plan.id.uuidString
                router.trainingPath.append(TrainingRoute.customPlanEdit(planId: plan.id))
            }
        ) {
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
                    .frame(width: 44, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("管理模版，\(plan.name)")
            .accessibilityIdentifier("trainingHome.template.menu.\(plan.id)")
        }
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
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 44)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityIdentifier("trainingHome.createTemplate")
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func isUsedToday(_ plan: CustomPlan) -> Bool {
        orderedScheduleItems.contains {
            $0.sourceKind == TodayScheduleSourceKind.template &&
            $0.sourceId == plan.id.uuidString &&
            ($0.state == TodayScheduleItemState.pending || $0.state == TodayScheduleItemState.inProgress)
        }
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
            BTToast.present("已加入今日安排") { toast = $0 }
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
        BTTrainingPill(
            title: isFreeTrainingPrimary ? "自由" : (nextScheduleItem?.state == TodayScheduleItemState.inProgress ? "继续" : "训练"),
            icon: isFreeTrainingPrimary ? "plus" : BTIcon.playCircle
        ) {
            if router.isTrainingMinimized { router.resumeMinimizedTraining() }
            else if let item = nextScheduleItem { startScheduledItem(item) }
            else if todayProjection.suggestion != nil { arrangeAndStartCurrentLesson() }
            else { startFreeTraining() }
        }
        .accessibilityIdentifier(isFreeTrainingPrimary ? "trainingHome.freeTraining" : "trainingHome.startTraining")
        .accessibilityLabel(
            isFreeTrainingPrimary ? "自由训练" : (nextScheduleItem?.state == TodayScheduleItemState.inProgress ? "继续" : "开始训练")
        )
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
