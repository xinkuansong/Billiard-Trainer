import SwiftUI
import SwiftData

enum PlanDetailPrimaryAction: Equatable {
    case start, switchPlan, arrangeToday, review

    static func resolve(recordStatus: String?, isCurrentPlanActive: Bool, hasAnotherActivePlan: Bool) -> Self {
        if recordStatus == "completed" { return .review }
        if isCurrentPlanActive { return .arrangeToday }
        if hasAnotherActivePlan { return .switchPlan }
        return .start
    }

    var title: String {
        switch self {
        case .start: return "开始此计划"
        case .switchPlan: return "切换到此计划"
        case .arrangeToday: return "编排今天"
        case .review: return "选择课程复练"
        }
    }
}

enum PlanLessonDisplayState: Equatable {
    case current, completed, previewed, notStarted

    static func resolve(
        lessonID: String,
        lessonOrdinal: Int,
        currentLessonID: String?,
        currentOrdinal: Int?,
        planRecordStatus: String?,
        completedLessonIDs: Set<String>
    ) -> Self {
        if currentLessonID == lessonID && planRecordStatus == "active" { return .current }
        if completedLessonIDs.contains(lessonID) {
            if let currentOrdinal, lessonOrdinal >= currentOrdinal { return .previewed }
            return .completed
        }
        return .notStarted
    }
}

private struct LessonCardAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct PlanDetailView: View {
    let planId: String
    let ownerKey: String
    @StateObject private var profile: OwnerProfileStore

    init(planId: String, ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.planId = planId
        self.ownerKey = ownerKey
        _profile = StateObject(wrappedValue: OwnerProfileStore(ownerKey: ownerKey))
    }

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
    @State private var drillContents: [String: DrillContent] = [:]
    @State private var showSubscription = false
    @State private var seriesIssueNumber: Int = 1
    @State private var seriesIssueTotal: Int = 1
    @State private var activeCurrentWeek: Int? = nil
    @State private var activeLessonID: String?
    @State private var planRecordStatus: String?
    @State private var completedLessonIDs: Set<String> = []
    @State private var selectedLessonIDs: Set<String> = []
    @State private var showArrangeSheet = false
    @State private var toast: BTToastMessage?
    @State private var didInstallV54Fixture = false
    @State private var didInitializeExpansion = false
    /// 展开逐球形明细的计划条目键（week-day-phase-drill）。
    @State private var expandedDrillKeys: Set<String> = []

    var body: some View {
        content
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        heroHeader(plan)

                        weeksList(plan)
                            .padding(.horizontal, Spacing.lg)

                        Spacer(minLength: 96)
                    }
                }
                .ignoresSafeArea(edges: .top)

                fixedActivateButton(plan)
            } else {
                BTEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "无法加载计划",
                    subtitle: "计划数据可能已损坏"
                )
            }
        }
        .background(.btBG)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    proToolbarBadge
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    proToolbarBadge
                }
            }
        }
        .task {
            await loadPlan()
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showArrangeSheet) {
            if let plan { arrangementSheet(plan) }
        }
        .btToast($toast)
        .alert("激活训练计划", isPresented: $showActivateConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定激活") { activatePlan() }
        } message: {
            if hasActivePlan {
                Text("当前已有激活的训练计划，激活新计划将替换旧计划。确定要继续吗？")
            } else {
                Text("确定要开始「\(plan?.nameZh ?? "")」吗？激活后会从第一课开始建议，不会清空今日已有安排。")
            }
        }
    }

    @ViewBuilder
    private var proToolbarBadge: some View {
        if plan?.isPremium == true {
            BTProBadge(isUnlocked: subscriptionManager.isPremium, prominent: true)
        }
    }

    // MARK: - Hero Header（杂志封面，方向 A：色块 + 大字，无图片）

    private func heroHeader(_ plan: OfficialPlan) -> some View {
        ZStack(alignment: .bottomLeading) {
            BTPlanCover(
                planId: plan.id,
                targetLevel: plan.targetLevel,
                issueNumber: seriesIssueNumber,
                mode: .hero
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(seriesName(for: plan.targetLevel))
                    .font(.btFootnote)
                    .foregroundStyle(.white.opacity(0.85))

                Text(plan.nameZh)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroSubtitle(plan))
                    .font(.btFootnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()

                Text(durationEstimate(plan))
                    .font(.btCaption)
                    .foregroundStyle(.white.opacity(0.82))
                    .monospacedDigit()
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.sm)


        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func heroSubtitle(_ plan: OfficialPlan) -> String {
        [
            "\(plan.stages.count) 个阶段",
            "\(plan.lessonCount) 节课",
            "每课约 \(plan.minutesPerSession) 分钟"
        ].joined(separator: " · ")
    }

    private func durationEstimate(_ plan: OfficialPlan) -> String {
        let ordinal = activeLessonID.flatMap { id in plan.lessons.firstIndex { $0.id == id } }
        let weeks = PlanDurationEstimate.remainingWeeks(
            lessonCount: plan.lessonCount,
            currentOrdinal: planRecordStatus == "completed" ? nil : (ordinal ?? 0),
            weeklyGoalDays: profile.weeklyGoalDays
        )
        if planRecordStatus == "completed" { return "主线已完成，可随时复练" }
        return "按每周 \(profile.weeklyGoalDays) 练，预计约 \(weeks) 周完成"
    }


    private func planLevelName(_ level: String) -> String {
        let last = level.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? level
        return DrillLevel(rawValue: last)?.displayName ?? level
    }

    // MARK: - Fixed Activate Button

    @ViewBuilder
    private func fixedActivateButton(_ plan: OfficialPlan) -> some View {
        VStack {
            Spacer()

            Group {
                if !plan.isPremium || subscriptionManager.isPremium {
                    Button {
                        handlePrimaryCTA(plan)
                    } label: {
                        Label(primaryCTATitle, systemImage: primaryCTAIcon)
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .accessibilityIdentifier("planDetail.primaryCTA")
                    .transition(.opacity)
                } else {
                    Button {
                        showSubscription = true
                    } label: {
                        Label("解锁此计划", systemImage: "lock.fill")
                    }
                    .buttonStyle(BTButtonStyle.primary)
                    .transition(.opacity)
                }
            }
            .animation(BTMotion.springPanel, value: isCurrentPlanActive)
            // F-PL-13: bottom CTA horizontal inset stays Spacing.lg (Home xxl is out of W2-7 scope).
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
            .btTrainingPillObstacle()
            .background(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.btBG.opacity(0), Color.btBG],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 100)
                .allowsHitTesting(false)
            }
        }
    }

    private var primaryCTATitle: String {
        primaryAction.title
    }

    private var primaryAction: PlanDetailPrimaryAction {
        .resolve(
            recordStatus: planRecordStatus,
            isCurrentPlanActive: isCurrentPlanActive,
            hasAnotherActivePlan: hasActivePlan && !isCurrentPlanActive
        )
    }

    private var primaryCTAIcon: String {
        (isCurrentPlanActive || planRecordStatus == "completed") ? "checklist" : "play.fill"
    }

    private func handlePrimaryCTA(_ plan: OfficialPlan) {
        if primaryAction == .arrangeToday || primaryAction == .review {
            prepareSelection(plan)
            showArrangeSheet = true
        } else {
            showActivateConfirm = true
        }
    }

    // MARK: - Stage / lesson curriculum

    private func weeksList(_ plan: OfficialPlan) -> some View {
        let isPremiumLocked = plan.isPremium && !subscriptionManager.isPremium
        let freePreviewCount = 1

        return VStack(alignment: .leading, spacing: Spacing.lg) {
            planSectionHeader(zh: "课程安排", trailing: "共 \(plan.stages.count) 阶段 · \(plan.lessonCount) 课")

            if isPremiumLocked {
                ForEach(Array(plan.stages.prefix(freePreviewCount).enumerated()), id: \.element.id) { index, stage in
                    stageSection(stage, isLast: index == freePreviewCount - 1 && plan.stages.count == freePreviewCount)
                }

                BTPremiumLock(mode: .progressive(visibleItems: freePreviewCount)) {
                    showSubscription = true
                } content: {
                    EmptyView()
                }
            } else {
                ForEach(Array(plan.stages.enumerated()), id: \.element.id) { index, stage in
                    stageSection(stage, isLast: index == plan.stages.count - 1)
                }
            }
        }
    }

    private func planSectionHeader(zh: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(zh)
                .font(.btTitle)
                .foregroundStyle(.btText)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
            }
        }
    }

    private func stageSection(_ stage: PlanStage, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(BTMotion.springPanel) {
                    if expandedWeeks.contains(stage.order) {
                        expandedWeeks.remove(stage.order)
                    } else {
                        expandedWeeks.insert(stage.order)
                    }
                }
            } label: {
                chapterHeader(stage)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BTPressableStyle.row)
            .accessibilityIdentifier("planStage-\(stage.id)")
            .accessibilityValue(expandedWeeks.contains(stage.order) ? "已展开" : "已收起")

            if expandedWeeks.contains(stage.order) {
                VStack(spacing: Spacing.md) {
                    ForEach(stage.lessons.sorted { $0.order < $1.order }) { lesson in
                        lessonSection(lesson, stage: stage)
                    }
                }
                .padding(.trailing, Spacing.lg)
                .overlayPreferenceValue(LessonCardAnchorKey.self) { anchors in
                    lessonProgressTrack(stage, anchors: anchors)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func chapterHeader(_ stage: PlanStage) -> some View {
        let totalMinutes = stage.lessons.reduce(0) { $0 + lessonEstimatedMinutes($1) }
        let isExpanded = expandedWeeks.contains(stage.order)

        return HStack(alignment: .top, spacing: Spacing.lg) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("第")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Text("\(stage.order)")
                    .font(.btChapterNumber)
                    .foregroundStyle(.btText)
                    .monospacedDigit()
                Text("阶段")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .fixedSize()
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text(stage.title)
                        .font(.btTitle2)
                        .foregroundStyle(.btText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: Spacing.sm)

                    // F-PL-11: single chevron + rotation instead of up/down symbol swap.
                    Image(systemName: BTIcon.chevronDown)
                        .font(.btHeadline)
                        .foregroundStyle(.btTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                Text("\(stage.lessons.count) 节课 · 约 \(totalMinutes) 分钟")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
            }
        }
        .padding(Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(stage.order) 阶段，\(stage.title)，\(stage.lessons.count) 节课，约 \(totalMinutes) 分钟")
    }

    // MARK: - Lesson Section

    private func lessonProgressTrack(
        _ stage: PlanStage,
        anchors: [String: Anchor<CGRect>]
    ) -> some View {
        GeometryReader { proxy in
            let lessons = stage.lessons.sorted { $0.order < $1.order }
            // Span the full lesson stack; circles follow each card's actual center.
            Path { path in
                let x = proxy.size.width - Spacing.xs
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: proxy.size.height))
            }
            .stroke(Color.btSeparator, lineWidth: 1)

            // Advance only through consecutive completed lessons: a later previewed
            // lesson must not paint the unfinished lessons before it as completed.
            let completedPrefix = lessons.prefix { lessonStatus($0).isCompleted }
            if let lastCompleted = completedPrefix.last,
               let anchor = anchors[lastCompleted.id] {
                let endY = completedPrefix.count == lessons.count
                    ? proxy.size.height : proxy[anchor].midY
                Path { path in
                    let x = proxy.size.width - Spacing.xs
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: endY))
                }
                .stroke(Color.btPrimary, lineWidth: 1)
            }

            ForEach(lessons) { lesson in
                if let anchor = anchors[lesson.id] {
                    let isCompleted = lessonStatus(lesson).isCompleted
                    Circle()
                        // White unfinished nodes are intentional in both appearances.
                        .fill(isCompleted ? Color.btPrimary : Color.white)
                        .overlay {
                            Circle().strokeBorder(
                                isCompleted ? Color.btPrimary : Color.btSeparator,
                                lineWidth: 1
                            )
                        }
                        .frame(width: Spacing.sm, height: Spacing.sm)
                        .position(x: proxy.size.width - Spacing.xs, y: proxy[anchor].midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lessonSection(_ lesson: PlanLesson, stage: PlanStage) -> some View {
        let totalMin = lessonEstimatedMinutes(lesson)
        let activePhases = lesson.phases.filter { !$0.drills.isEmpty }
        let status = lessonStatus(lesson)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("第 \(lesson.order) 天")
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(.btPrimary)
                        .accessibilityIdentifier("planLessonDay-\(lesson.id)")
                    Spacer(minLength: Spacing.sm)
                    Text(status.title)
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(status.color)
                    Text("约 \(totalMin) 分钟")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                        .monospacedDigit()
                }
                Text(lesson.title)
                    .font(.btTitleMedium)
                    .foregroundStyle(.btText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("planLessonTitle-\(lesson.id)")
            }

            BTPhaseTimeline(
                phases: activePhases.map { phase in
                    var entry = BTPhaseEntry.from(phase)
                    // R7/R11：阶段分钟由球数 ÷ 2.5 反算；无动作阶段保留原文案分钟。
                    if !phase.drills.isEmpty {
                        entry = BTPhaseEntry(
                            id: entry.id,
                            typeKey: entry.typeKey,
                            typeZh: entry.typeZh,
                            durationMinutes: phaseEstimatedMinutes(phase),
                            icon: entry.icon
                        )
                    }
                    return entry
                }
            ) { index, _ in
                let phase = activePhases[index]
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(phase.drills.enumerated()), id: \.element.id) { drillIndex, ref in
                        drillTrackRow(
                            index: drillIndex,
                            ref: ref,
                            expandKey: "\(stage.id)-\(lesson.id)-\(phase.type)-\(ref.id)"
                        )
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .anchorPreference(key: LessonCardAnchorKey.self, value: .bounds) {
            [lesson.id: $0]
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第 \(lesson.order) 天，\(lesson.title)，\(status.title)，约 \(totalMin) 分钟")
    }

    private func lessonEstimatedMinutes(_ lesson: PlanLesson) -> Int {
        lesson.phases.reduce(0) { acc, phase in
            acc + (phase.countsTowardSessionMinutes ? phaseEstimatedMinutes(phase) : 0)
        }
    }

    private struct LessonVisualStatus {
        let title: String
        let color: Color
        var isCompleted: Bool = false
    }

    private func lessonStatus(_ lesson: PlanLesson) -> LessonVisualStatus {
        guard let plan else { return .init(title: "未开始", color: .btTextTertiary) }
        let ordinal = plan.lessons.firstIndex { $0.id == lesson.id } ?? 0
        let current = activeLessonID.flatMap { id in plan.lessons.firstIndex { $0.id == id } }
        switch PlanLessonDisplayState.resolve(
            lessonID: lesson.id,
            lessonOrdinal: ordinal,
            currentLessonID: activeLessonID,
            currentOrdinal: current,
            planRecordStatus: planRecordStatus,
            completedLessonIDs: completedLessonIDs
        ) {
        case .current: return .init(title: "当前", color: .btPrimary)
        case .completed: return .init(title: "已完成", color: .btSuccess, isCompleted: true)
        case .previewed: return .init(title: "提前练过", color: .btPrimary, isCompleted: true)
        case .notStarted: return .init(title: "未开始", color: .btTextTertiary)
        }
    }

    private func drillTrackRow(index: Int, ref: PlanDrillRef, expandKey: String) -> some View {
        let options = TrainingDoseResolver.formationOptions(forDrillId: ref.drillId)
        let resolved = TrainingDoseResolver.resolve(
            content: drillContents[ref.drillId],
            dose: ref.dose,
            formationOptions: options
        )
        let name = drillNames[ref.drillId] ?? "动作暂不可用"
        let lines = resolved.suggestedDoseLines()
        // 仅多球形可展开；单球形第二行直接渲染统一剂量行，无 chevron。
        let isMulti = resolved.groups.count > 1
        let isExpanded = isMulti && expandedDrillKeys.contains(expandKey)

        return HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(spacing: Spacing.xs) {
                NavigationLink(value: TrainingRoute.drillDetail(drillId: ref.drillId)) {
                    drillThumbnail(ref).frame(minHeight: 44, alignment: .top)
                }
                .buttonStyle(BTPressableStyle.row)
                .accessibilityLabel("查看\(name)动作详情")
                if isMulti {
                    Button {
                        withAnimation(BTMotion.springPanel) {
                            if isExpanded { expandedDrillKeys.remove(expandKey) }
                            else { expandedDrillKeys.insert(expandKey) }
                        }
                    } label: {
                        Image(systemName: BTIcon.chevronDown)
                            .font(.btCaption)
                            .foregroundStyle(.btTextSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .frame(width: 64, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BTPressableStyle.row)
                    .accessibilityIdentifier("planDrillDoseToggle-\(expandKey)")
                    .accessibilityLabel("\(isExpanded ? "收起" : "展开")\(name)球形剂量")
                    .accessibilityValue(isExpanded ? "已展开" : "已收起")
                }
            }
            NavigationLink(value: TrainingRoute.drillDetail(drillId: ref.drillId)) {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(name)
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                        if isMulti {
                            Text(resolved.planEntrySummaryText())
                                .font(.btFootnote)
                                .foregroundStyle(.btTextSecondary)
                        }
                        if !isMulti || isExpanded {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                    suggestedDoseLineRow(line)
                                }
                            }
                            .accessibilityIdentifier("planDrillDoseDetail-\(ref.drillId)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.btCaption2)
                        .foregroundStyle(.btTextTertiary)
                }
                .frame(minHeight: 44, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(BTPressableStyle.row)
            .accessibilityIdentifier("planDrillRow-\(ref.drillId)")
            .accessibilityLabel(resolved.planEntryAccessibilityLabel(drillName: name))
            .accessibilityHint("查看动作详情")
        }
        .padding(.vertical, Spacing.xs)
    }

    private func suggestedDoseLineRow(_ line: SuggestedDoseLine) -> some View {
        Text([line.title, line.modeLabel, line.text].compactMap { $0 }.joined(separator: " "))
            .font(.btFootnote)
            .foregroundStyle(.btTextSecondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 单阶段分钟：有动作按球数 ÷ 2.5；空阶段用 JSON 时长。
    private func phaseEstimatedMinutes(_ phase: SessionPhase) -> Int {
        if phase.drills.isEmpty { return phase.durationMinutes }
        let balls = phase.drills.reduce(0) { acc, ref in
            acc + TrainingDoseResolver.resolve(
                content: drillContents[ref.drillId],
                dose: ref.dose
            ).totalBalls
        }
        return ResolvedDose.estimatedMinutes(forBalls: balls)
    }

    private func sessionEstimatedMinutes(_ session: PlanSession) -> Int {
        session.phases.reduce(0) { acc, phase in
            acc + (phase.countsTowardSessionMinutes ? phaseEstimatedMinutes(phase) : 0)
        }
    }

    @ViewBuilder
    private func drillThumbnail(_ ref: PlanDrillRef) -> some View {
        if let drill = drillContents[ref.drillId] {
            BTBakedDrillTable(drillId: drill.id)
                .frame(width: 64, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xxs))
        } else {
            RoundedRectangle(cornerRadius: BTRadius.xxs)
                .fill(Color.btBGQuaternary.opacity(0.5))
                .frame(width: 64, height: 32)
                .overlay {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 10))
                        .foregroundStyle(.btTextTertiary)
                }
        }
    }

    // MARK: - Arrange today

    private func arrangementSheet(_ plan: OfficialPlan) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(plan.stages.sorted { $0.order < $1.order }) { stage in
                        Section("阶段 \(stage.order) · \(stage.title)") {
                            ForEach(stage.lessons.sorted { $0.order < $1.order }) { lesson in
                                Button {
                                    if selectedLessonIDs.contains(lesson.id) {
                                        selectedLessonIDs.remove(lesson.id)
                                    } else {
                                        selectedLessonIDs.insert(lesson.id)
                                    }
                                } label: {
                                    HStack(spacing: Spacing.md) {
                                        Image(systemName: selectedLessonIDs.contains(lesson.id)
                                              ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedLessonIDs.contains(lesson.id)
                                                             ? Color.btPrimary : Color.btTextTertiary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lesson.title).foregroundStyle(.btText)
                                            Text(lessonStatus(lesson).title)
                                                .font(.btCaption)
                                                .foregroundStyle(lessonStatus(lesson).color)
                                        }
                                        Spacer()
                                        Text("约 \(lessonEstimatedMinutes(lesson)) 分钟")
                                            .font(.btCaption)
                                            .foregroundStyle(.btTextSecondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "\(lesson.title)，\(lessonStatus(lesson).title)，"
                                    + "\(selectedLessonIDs.contains(lesson.id) ? "已选择" : "未选择")"
                                )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(selectionSummary(plan))
                        .font(.btSubheadline)
                        .foregroundStyle(.btTextSecondary)
                        .accessibilityIdentifier("planDetail.arrangementSummary")
                    Button("加入今日安排") { addSelectionToToday(plan) }
                        .buttonStyle(BTButtonStyle.primary)
                        .disabled(selectedLessonIDs.isEmpty)
                        .accessibilityIdentifier("planDetail.addToToday")
                }
                .padding(Spacing.lg)
                .background(.btBGSecondary)
            }
            .navigationTitle("编排今天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showArrangeSheet = false }
                }
            }
            .onAppear {
                if selectedLessonIDs.isEmpty,
                   isCurrentPlanActive,
                   let defaultID = defaultArrangementLessonID(in: plan) {
                    selectedLessonIDs = [defaultID]
                }
            }
        }
    }

    private func prepareSelection(_ plan: OfficialPlan) {
        if planRecordStatus == "completed" {
            selectedLessonIDs = []
        } else if isCurrentPlanActive, let defaultID = defaultArrangementLessonID(in: plan) {
            selectedLessonIDs = [defaultID]
        } else {
            selectedLessonIDs = []
        }
    }

    /// An active record is expected to have a cursor. The fallback keeps the
    /// composer deterministic while an old/migrated record repairs a missing
    /// cursor, choosing the first unfinished lesson instead of an arbitrary row.
    private func defaultArrangementLessonID(in plan: OfficialPlan) -> String? {
        if let activeLessonID, plan.lessons.contains(where: { $0.id == activeLessonID }) {
            return activeLessonID
        }
        return plan.lessons.first(where: { !completedLessonIDs.contains($0.id) })?.id
            ?? plan.lessons.first?.id
    }

    private func selectionSummary(_ plan: OfficialPlan) -> String {
        let ordinalByID = Dictionary(uniqueKeysWithValues: plan.lessons.enumerated().map {
            ($0.element.id, $0.offset)
        })
        let selected = Set(selectedLessonIDs.compactMap { ordinalByID[$0] })
        let current = activeLessonID.flatMap { ordinalByID[$0] }
        let roles = OfficialLessonRoleRules.classify(
            currentOrdinal: current, selectedOrdinals: selected, lessonCount: plan.lessonCount
        )
        let review = roles.values.filter { $0 == TodayScheduleProgressRole.review }.count
        let advance = roles.values.filter { $0 == TodayScheduleProgressRole.advanceEligible }.count
        let preview = roles.values.filter { $0 == TodayScheduleProgressRole.preview }.count
        var parts = ["将加入 \(selected.count) 项"]
        if review > 0 { parts.append("复练 \(review) 课") }
        if advance > 0 { parts.append("完成后最多推进 \(advance) 课") }
        if preview > 0 { parts.append("\(preview) 课为提前练习，不会跳过中间课程") }
        return parts.joined(separator: "，")
    }

    private func addSelectionToToday(_ plan: OfficialPlan) {
        let descriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        guard let record = (try? modelContext.fetch(descriptor))?.first(where: {
            $0.planId == plan.id
        }) else {
            BTToast.present("请先开始此计划", tone: .warning) { toast = $0 }
            return
        }
        do {
            let results = try TodayTrainingScheduleService(context: modelContext)
                .addOfficialLessons(plan: plan, lessonIDs: selectedLessonIDs, activePlan: record)
            let added = results.filter {
                if case .added = $0 { return true }
                return false
            }.count
            showArrangeSheet = false
            BTToast.present(added == 0 ? "所选课程已在今日安排" : "已加入今日安排") { toast = $0 }
        } catch {
            BTToast.present("加入失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    // MARK: - Helpers

    private func seriesName(for targetLevel: String) -> String {
        switch targetLevel {
        case "L0→L1":  return "入门系列"
        case "L0→L2":  return "准度入门"
        case "L1":     return "初级系列"
        case "L1→L2":  return "进阶系列"
        case "L1→L3":  return "走位进阶"
        case "L2":     return "中级系列"
        case "L2→L3":  return "中级进阶"
        case "L2→L4":  return "综合系列"
        case "L3":     return "高级系列"
        case "L3→L4":  return "专业系列"
        default:       return "训练系列"
        }
    }

    // MARK: - Data Loading

    private func loadPlan() async {
        // Keep the existing ScrollView alive when returning from drill details.
        isLoading = plan == nil
        defer { isLoading = false }

        plan = await PlanContentService.shared.loadPlanFromBundle(id: planId)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-v57.missingPlanDrill"), let loaded = plan {
            do {
                plan = try unavailableDrillFixture(loaded)
            } catch {
                BTToast.present("无法准备失效动作测试：\(error.localizedDescription)", tone: .error) { toast = $0 }
                return
            }
        }
        #endif
        profile.load(from: nil)
        if let plan { installV54FixtureIfNeeded(plan) }

        let descriptor = FetchDescriptor<UserActivePlan>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        let records: [UserActivePlan]
        do {
            records = try modelContext.fetch(descriptor)
        } catch {
            BTToast.present("读取计划进度失败，请重试", tone: .error) { toast = $0 }
            return
        }
        if let active = PlanProgressService.currentOfficialPlan(in: records) {
            hasActivePlan = true
            isCurrentPlanActive = active.planId == planId
        } else {
            hasActivePlan = false
            isCurrentPlanActive = false
        }
        if let own = records.first(where: { $0.planId == planId }) {
            activeCurrentWeek = own.currentWeek
            activeLessonID = own.currentLessonId
            planRecordStatus = own.status
        } else {
            activeCurrentWeek = nil
            activeLessonID = nil
            planRecordStatus = nil
        }

        guard let plan else { return }

        await computeSeriesIssue(for: plan)

        let drillService = DrillContentService.shared
        let allDrillIds = Set(plan.stages.flatMap { stage in
            stage.lessons.flatMap { lesson in
                lesson.phases.flatMap { phase in
                    phase.drills.map(\.drillId)
                }
            }
        })
        var names: [String: String] = [:]
        var loadedDrills: [String: DrillContent] = [:]

        for id in allDrillIds {
            if let drill = await drillService.loadDrillFromBundle(id: id) {
                names[id] = drill.nameZh
                loadedDrills[id] = drill
            }
        }

        drillNames = names
        drillContents = loadedDrills

        // 默认全展开：周章节与多球形明细一次性可见，收起交给用户手动操作。
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        do {
            completedLessonIDs = Set(try modelContext.fetch(sessionDescriptor).compactMap {
                $0.planId == planId ? $0.lessonId : nil
            })
        } catch {
            BTToast.present("读取已完成课程失败，请重试", tone: .error) { toast = $0 }
            return
        }

        guard !didInitializeExpansion else { return }
        didInitializeExpansion = true
        for stage in plan.stages {
            expandedWeeks.insert(stage.order)
            for lesson in stage.lessons {
                for phase in lesson.phases {
                    for ref in phase.drills {
                        expandedDrillKeys.insert(
                            "\(stage.id)-\(lesson.id)-\(phase.type)-\(ref.id)"
                        )
                    }
                }
            }
        }
    }

    private func computeSeriesIssue(for plan: OfficialPlan) async {
        guard let index = await PlanContentService.shared.loadPlanIndex() else {
            seriesIssueNumber = 1
            seriesIssueTotal = 1
            return
        }
        let sameLevel = index.plans.filter { $0.targetLevel == plan.targetLevel }
        seriesIssueTotal = max(sameLevel.count, 1)
        if let pos = sameLevel.firstIndex(where: { $0.id == plan.id }) {
            seriesIssueNumber = pos + 1
        } else {
            seriesIssueNumber = 1
        }
    }

    /// Launch-argument-only plan-state fixture for the v54 screenshot/accessibility matrix.
    #if DEBUG
    /// An in-memory missing reference; never modifies bundled plan/drill assets.
    private func unavailableDrillFixture(_ source: OfficialPlan) throws -> OfficialPlan {
        func replaceReference(_ value: Any) -> Any {
            if var object = value as? [String: Any] {
                if object["drillId"] as? String == "drill_c012" {
                    object["drillId"] = "v57-missing-drill"
                }
                return object.mapValues(replaceReference)
            }
            if let array = value as? [Any] { return array.map(replaceReference) }
            return value
        }
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(source))
        let data = try JSONSerialization.data(withJSONObject: replaceReference(object))
        return try JSONDecoder().decode(OfficialPlan.self, from: data)
    }
    #endif

    private func installV54FixtureIfNeeded(_ plan: OfficialPlan) {
        guard !didInstallV54Fixture else { return }
        didInstallV54Fixture = true
        let args = ProcessInfo.processInfo.arguments
        guard let state = args.first(where: { $0.hasPrefix("-v54.planState=") })?
            .replacingOccurrences(of: "-v54.planState=", with: ""),
              state != "start" else { return }

        if state == "other" {
            let other = UserActivePlan(planId: "plan_accuracy", ownerKey: ownerKey)
            other.currentLessonId = PlanContentService.decodePlanFromBundle(id: other.planId)?.lessons.first?.id
            modelContext.insert(other)
            let own = UserActivePlan(planId: plan.id, ownerKey: ownerKey)
            own.status = "paused"
            own.currentLessonId = plan.lessons.first?.id
            modelContext.insert(own)
        } else {
            let own = UserActivePlan(planId: plan.id, ownerKey: ownerKey)
            if state == "completed" {
                own.status = "completed"
                own.currentLessonId = nil
                own.completedAt = .now
            } else {
                own.currentLessonId = plan.lessons.dropFirst(2).first?.id ?? plan.lessons.first?.id
            }
            modelContext.insert(own)

            let completed = state == "completed"
                ? Array(plan.lessons)
                : [plan.lessons.first, plan.lessons.dropFirst(3).first].compactMap { $0 }
            for lesson in completed {
                let session = TrainingSession(ownerKey: ownerKey)
                session.planId = plan.id
                session.lessonId = lesson.id
                modelContext.insert(session)
            }
        }
        try? modelContext.save()
    }

    // MARK: - Activate Plan

    private func activatePlan() {
        guard let plan else { return }
        let target: UserActivePlan
        do {
            target = try PlanProgressService.activateOfficialPlan(
                plan, ownerKey: ownerKey, context: modelContext
            )
        } catch {
            BTToast.present("切换失败，已保留原计划，请稍后重试", tone: .error) { toast = $0 }
            return
        }

        withAnimation(BTMotion.springPanel) {
            isCurrentPlanActive = true
            hasActivePlan = true
            activeLessonID = target.currentLessonId
            planRecordStatus = target.status
        }
    }
}

// MARK: - Gold Rule

struct BTGoldRule: View {
    var width: CGFloat = 32
    var height: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(Color.btBrandSignature.opacity(0.6))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Arc Separator (台球母题：母球 + 弧线)

struct BTArcSeparator: View {
    var width: CGFloat = 80
    var height: CGFloat = 16
    var opacity: Double = 0.4

    var body: some View {
        Canvas { ctx, size in
            let arcStart = CGPoint(x: size.width * 0.18, y: size.height * 0.85)
            let arcEnd = CGPoint(x: size.width * 0.82, y: size.height * 0.30)
            let control = CGPoint(x: size.width * 0.42, y: size.height * 0.10)

            var arc = Path()
            arc.move(to: arcStart)
            arc.addQuadCurve(to: arcEnd, control: control)

            ctx.stroke(
                arc,
                with: .color(.btBrandSignature.opacity(opacity)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )

            let dotRadius: CGFloat = 2.5
            let dotRect = CGRect(
                x: arcEnd.x - dotRadius,
                y: arcEnd.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            ctx.fill(Path(ellipseIn: dotRect), with: .color(.btBrandSignature.opacity(opacity)))
        }
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
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
