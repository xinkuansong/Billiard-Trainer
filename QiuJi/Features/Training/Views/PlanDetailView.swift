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
    @State private var drillContents: [String: DrillContent] = [:]
    @State private var showSubscription = false
    @State private var seriesIssueNumber: Int = 1
    @State private var seriesIssueTotal: Int = 1
    @State private var coachingQuotes: [Int: String] = [:]
    @State private var planCoachingPoint: String? = nil
    @State private var activeCurrentWeek: Int? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        heroHeader(plan)

                        VStack(spacing: Spacing.xl) {
                            if let point = planCoachingPoint {
                                trainingPointsBar(point)
                            }

                            weeksList(plan)
                        }
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

    // MARK: - Hero Header（杂志封面，方向 A：色块 + 大字，无图片）

    private func heroHeader(_ plan: OfficialPlan) -> some View {
        ZStack(alignment: .bottomLeading) {
            BTPlanCover(
                targetLevel: plan.targetLevel,
                issueNumber: seriesIssueNumber,
                glyphSize: 170,
                corner: 0,
                showIssueLabel: false
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
            }
            .padding(Spacing.lg)
            .padding(.bottom, Spacing.sm)

            if plan.isPremium {
                VStack {
                    HStack {
                        Spacer()
                        proTag
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 60)
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func heroSubtitle(_ plan: OfficialPlan) -> String {
        [
            "\(plan.durationWeeks) 周",
            "\(plan.sessionsPerWeek) 次/周",
            "\(plan.minutesPerSession) 分钟/次",
            planLevelName(plan.targetLevel)
        ].joined(separator: " · ")
    }

    private var proTag: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 2)
            .background(Color.btAccent)
            .clipShape(Capsule())
    }

    private func planLevelName(_ level: String) -> String {
        let last = level.components(separatedBy: "→").last?.trimmingCharacters(in: .whitespaces) ?? level
        return DrillLevel(rawValue: last)?.displayName ?? level
    }

    // MARK: - Training Points Bar

    private func trainingPointsBar(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.btFootnote)
                .foregroundStyle(.btAccent)

            Text(text)
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btAccent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("训练要点：\(text)")
    }

    // MARK: - Fixed Activate Button

    @ViewBuilder
    private func fixedActivateButton(_ plan: OfficialPlan) -> some View {
        VStack {
            Spacer()

            Group {
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
                    .background(Color.btSuccess.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                } else if !plan.isPremium || subscriptionManager.isPremium {
                    Button {
                        showActivateConfirm = true
                    } label: {
                        Label("开始此计划", systemImage: "play.fill")
                    }
                    .buttonStyle(BTButtonStyle.primary)
                } else {
                    Button {
                        showSubscription = true
                    } label: {
                        Label("解锁此计划", systemImage: "lock.fill")
                    }
                    .buttonStyle(BTButtonStyle.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
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

    // MARK: - Weeks List

    private func weeksList(_ plan: OfficialPlan) -> some View {
        let isPremiumLocked = plan.isPremium && !subscriptionManager.isPremium
        let freePreviewCount = 1

        return VStack(alignment: .leading, spacing: Spacing.lg) {
            planSectionHeader(zh: "训练安排", trailing: "共 \(plan.weeks.count) 周")

            BTPlanWeekTimeline(
                items: BTPlanWeekTimeline.build(
                    total: plan.weeks.count,
                    currentWeek: isCurrentPlanActive ? activeCurrentWeek : nil,
                    premiumUnlockedFromWeek: isPremiumLocked ? freePreviewCount : nil
                )
            )
            .padding(.bottom, Spacing.xs)

            if isPremiumLocked {
                ForEach(Array(plan.weeks.prefix(freePreviewCount).enumerated()), id: \.element.weekNumber) { index, week in
                    weekSection(week, plan: plan, isLast: index == freePreviewCount - 1 && plan.weeks.count == freePreviewCount)
                }

                BTPremiumLock(mode: .progressive(visibleItems: freePreviewCount)) {
                    showSubscription = true
                } content: {
                    EmptyView()
                }
            } else {
                ForEach(Array(plan.weeks.enumerated()), id: \.element.weekNumber) { index, week in
                    weekSection(week, plan: plan, isLast: index == plan.weeks.count - 1)
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

    private func weekSection(_ week: PlanWeek, plan: OfficialPlan, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(BTMotion.springPanel) {
                    if expandedWeeks.contains(week.weekNumber) {
                        expandedWeeks.remove(week.weekNumber)
                    } else {
                        expandedWeeks.insert(week.weekNumber)
                    }
                }
            } label: {
                chapterHeader(week)
            }
            .buttonStyle(.plain)

            if expandedWeeks.contains(week.weekNumber) {
                VStack(spacing: Spacing.md) {
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
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func chapterHeader(_ week: PlanWeek) -> some View {
        let totalMinutes = week.sessions.reduce(0) { acc, session in
            acc + session.phases.reduce(0) { $0 + $1.durationMinutes }
        }
        let isExpanded = expandedWeeks.contains(week.weekNumber)

        return HStack(alignment: .top, spacing: Spacing.lg) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("第")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Text("\(week.weekNumber)")
                    .font(.btChapterNumber)
                    .foregroundStyle(.btText)
                    .monospacedDigit()
                Text("周")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .fixedSize()
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text(week.theme)
                        .font(.btTitle2)
                        .foregroundStyle(.btText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: Spacing.sm)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.btHeadline)
                        .foregroundStyle(.btTextTertiary)
                }

                Text("\(week.sessions.count) 天 · \(totalMinutes) 分钟")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
            }
        }
        .padding(Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(week.weekNumber) 周，\(week.theme)，\(week.sessions.count) 天 \(totalMinutes) 分钟")
    }

    // MARK: - Day Section

    private func daySection(_ session: PlanSession, weekNumber: Int) -> some View {
        let totalMin = session.phases.reduce(0) { $0 + $1.durationMinutes }
        let activePhases = session.phases.filter { !$0.drills.isEmpty }

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("第 \(session.dayNumber) 天")
                    .font(.btTitleMedium)
                    .foregroundStyle(.btText)
                    .monospacedDigit()

                Spacer()

                Text("\(totalMin) 分钟")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .monospacedDigit()
            }

            BTPhaseTimeline(
                phases: activePhases.map(BTPhaseEntry.from)
            ) { index, _ in
                let phase = activePhases[index]
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(phase.drills.enumerated()), id: \.element.id) { drillIndex, ref in
                        drillTrackRow(index: drillIndex, ref: ref)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .background(.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    private func drillTrackRow(index: Int, ref: PlanDrillRef) -> some View {
        HStack(spacing: Spacing.md) {
            drillThumbnail(ref)

            Text(String(format: "%02d", index + 1))
                .font(.btFootnote)
                .foregroundStyle(.btTextTertiary)
                .monospacedDigit()
                .frame(width: 20, alignment: .leading)

            Text(drillNames[ref.drillId] ?? ref.drillId)
                .font(.btCallout)
                .foregroundStyle(.btText)
                .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            Text("\(ref.sets)×\(ref.ballsPerSet)")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func drillThumbnail(_ ref: PlanDrillRef) -> some View {
        if let drill = drillContents[ref.drillId] {
            BTBakedDrillTable(drillId: drill.id)
                .frame(width: 40, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xxs))
        } else {
            RoundedRectangle(cornerRadius: BTRadius.xxs)
                .fill(Color.btBGQuaternary.opacity(0.5))
                .frame(width: 40, height: 20)
                .overlay {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 10))
                        .foregroundStyle(.btTextTertiary)
                }
        }
    }

    // MARK: - Helpers

    private func seriesName(for targetLevel: String) -> String {
        switch targetLevel {
        case "L0→L1":  return "入门系列"
        case "L1":     return "初级系列"
        case "L1→L2":  return "进阶系列"
        case "L2":     return "中级系列"
        case "L3":     return "高级系列"
        case "L3→L4":  return "专业系列"
        default:       return "训练系列"
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
            if isCurrentPlanActive {
                activeCurrentWeek = active.currentWeek
            }
        }

        guard let plan else { return }

        await computeSeriesIssue(for: plan)

        let drillService = DrillContentService.shared
        let allDrillIds = Set(plan.weeks.flatMap { week in
            week.sessions.flatMap { session in
                session.phases.flatMap { phase in
                    phase.drills.map(\.drillId)
                }
            }
        })
        var names: [String: String] = [:]
        var quotesByWeek: [Int: String] = [:]
        var loadedDrills: [String: DrillContent] = [:]

        for id in allDrillIds {
            if let drill = await drillService.loadDrillFromBundle(id: id) {
                names[id] = drill.nameZh
                loadedDrills[id] = drill
            }
        }

        for week in plan.weeks {
            let firstDrillId = week.sessions
                .flatMap { $0.phases }
                .flatMap { $0.drills }
                .first?.drillId
            if let drillId = firstDrillId,
               let drill = loadedDrills[drillId],
               let firstPoint = drill.coachingPoints.first(where: { !$0.isEmpty }) {
                quotesByWeek[week.weekNumber] = firstPoint
            }
        }

        drillNames = names
        drillContents = loadedDrills
        coachingQuotes = quotesByWeek
        planCoachingPoint = quotesByWeek[1] ?? quotesByWeek.sorted { $0.key < $1.key }.first?.value
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

// MARK: - Gold Rule

struct BTGoldRule: View {
    var width: CGFloat = 32
    var height: CGFloat = 1

    var body: some View {
        Rectangle()
            .fill(Color.btAccent.opacity(0.6))
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
                with: .color(.btAccent.opacity(opacity)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )

            let dotRadius: CGFloat = 2.5
            let dotRect = CGRect(
                x: arcEnd.x - dotRadius,
                y: arcEnd.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            ctx.fill(Path(ellipseIn: dotRect), with: .color(.btAccent.opacity(opacity)))
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
