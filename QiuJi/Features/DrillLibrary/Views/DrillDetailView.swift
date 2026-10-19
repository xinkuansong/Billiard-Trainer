import SwiftUI
import SwiftData
import UIKit

struct DrillDetailView: View {
    let drillId: String
    let ownerKey: String

    @State private var drill: DrillContent?
    @State private var didFinishLoading = false
    @State private var showSubscription = false
    @State private var showTutorial = false
    /// 「上手试打」push（试打模式方案 §1.6：入口直进试打页，不做预览页）。
    @State private var tryoutDestination: TryoutDestination?
    /// 试打球形集合（D4，与视频示范同源；空 = 无序列，回退 shotIntent 球局）。
    @State private var tryoutFormations: [DrillTryoutFormation] = []
    /// 多球形选择 sheet（>1 个球形时弹出，单球形直进）。
    /// 用 item 承载列表快照：iOS 26 上 `.sheet(isPresented:)` 内容闭包会以陈旧
    /// state 求值（tryoutFormations 渲染为空，B4 发现，c042/c053 均复现）。
    @State private var formationPicker: FormationPickerPayload?
    /// E15：加入训练（自定义计划 / 今日训练）选择 sheet。
    @State private var showAddToTraining = false
    @State private var toast: BTToastMessage?

    private struct TryoutDestination: Hashable {
        let id = UUID()
        let drill: DrillContent
        let formation: DrillTryoutFormation?
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// sheet(item:) 载荷：球形列表快照。
    private struct FormationPickerPayload: Identifiable {
        let id = UUID()
        let formations: [DrillTryoutFormation]
    }
    @Query private var favorites: [DrillFavorite]
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]
    @Query private var activePlans: [UserActivePlan]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    init(drillId: String, ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        self.drillId = drillId
        self.ownerKey = ownerKey
        _favorites = Query(filter: #Predicate { $0.ownerKey == ownerKey })
        _customPlans = Query(
            filter: #Predicate { $0.ownerKey == ownerKey },
            sort: \CustomPlan.createdAt,
            order: .reverse
        )
        _activePlans = Query(filter: #Predicate { $0.ownerKey == ownerKey })
    }

    private var isFavorited: Bool {
        favorites.contains { $0.drillId == drillId }
    }

    private var isLocked: Bool {
        guard let drill else { return false }
        return drill.isPremium && !subscriptionManager.isPremium
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if let drill {
                    VStack(alignment: .leading, spacing: Spacing.xxl) {
                        tableSection(drill)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            tagsRow(drill)

                            // F-DD-01：露出 Bundle 已有 description（转化页信息权重）。
                            Text(DrillCopyDisplay.text(drill.description, drillID: drill.id,
                                field: "description", orientation: .landscape))
                                .font(.btSubheadline)
                                .foregroundStyle(.btTextSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, Spacing.xs)

                            Divider()
                                .padding(.top, Spacing.xs)
                        }
                        .padding(.horizontal, Spacing.lg)

                        if isLocked {
                            // F-DD-04/09：锁态紧凑预览、不露假「查看精讲」；不改 isPremium 门槛。
                            BTPremiumLock(mode: .progressive(visibleItems: 1), onSubscribeTap: {
                                showSubscription = true
                            }) {
                                coachingSection(drill, includeTutorialCTA: false, maxPoints: 2)
                            }
                        } else {
                            coachingSection(drill, includeTutorialCTA: true)
                            trainingRequirementsSection(drill)
                        }

                        loadRadarSection(drill)
                    }
                    .padding(.bottom, 100)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if didFinishLoading {
                    BTEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "动作暂不可用",
                        subtitle: "内容可能已更新，请返回后选择其他动作。"
                    )
                    .accessibilityIdentifier("drillDetail.unavailable")
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .background(.btBG)

            if drill != nil {
                bottomBar
                    .frame(maxWidth: .infinity)
                    .btTrainingPillObstacle()
            }

            if let toast {
                BTToastBanner(message: toast)
            }
        }
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .navigationTitle(drill?.nameZh ?? "动作详情")
        .navigationBarTitleDisplayMode(.inline)
        // 固定顶栏始终显示材质背景，避免滚动内容穿透状态栏/标题（UR-20260529 U-06）。
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(drill?.nameZh ?? "动作详情")
                    .font(.btHeadline)
                    .foregroundStyle(.btPrimary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .btPrimary : .btTextSecondary)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: isFavorited)
                }
                .accessibilityLabel(isFavorited ? "取消收藏" : "收藏")
            }
        }
        .task {
            await loadDrill()
        }
        .navigationDestination(isPresented: $showTutorial) {
            if let drill {
                DrillTutorialView(drill: drill)
            }
        }
        .navigationDestination(item: $tryoutDestination) { destination in
            ProAccessGate(requiresPremium: destination.drill.isPremium) {
                PositionPlayComposerView(sourceDrill: destination.drill, tryoutFormation: destination.formation)
            }
        }
        .sheet(item: $formationPicker) { payload in
            formationPickerSheet(payload.formations)
        }
        .sheet(isPresented: $showAddToTraining) {
            if let drill {
                AddDrillToTrainingSheet(
                    drill: drill,
                    customPlans: customPlans,
                    onAddToToday: { addDrillToToday(drill) },
                    onAddToPlan: { plan in
                        addDrill(drill, to: plan)
                    },
                    onCreatePlan: { name in
                        createPlan(name: name, drill: drill, activateAsToday: false)
                    }
                )
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    // MARK: - Table Canvas

    private func tableSection(_ drill: DrillContent) -> some View {
        // 留一点点横向内边距（8pt），露出的是页面浅灰背景而非球台绿边——
        // 绿边已由 DrillSceneView 的相框比例(1.81)+取景(0.77)消除，与此 padding 无关。
        // 「上手试打」仅底栏（DR-057）；锁态底栏为「解锁 Pro」。
        DrillSceneView(drill: drill, preferencePage: .drillDetailPreview)
            .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Tryout entry（D4：球形与视频示范同源）

    /// 解锁态入口：>1 个球形弹选择，单球形/无序列直进。
    private func startTryout() {
        guard let drill, subscriptionManager.accessDecision(requiresPremium: drill.isPremium) == .allowed else {
            showSubscription = true
            return
        }
        tryoutFormations = DrillTryoutBoardStore.formations(for: drillId)
        if tryoutFormations.count > 1 {
            formationPicker = FormationPickerPayload(formations: tryoutFormations)
        } else {
            tryoutDestination = .init(drill: drill, formation: tryoutFormations.first)
        }
    }

    /// 多球形选择 sheet：球形名 + 杆数，选中即进试打页（暗材质，与试打页衔接）。
    private func formationPickerSheet(_ formations: [DrillTryoutFormation]) -> some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(formations.enumerated()), id: \.element.id) { index, formation in
                        Button {
                            guard let drill else { return }
                            formationPicker = nil
                            tryoutDestination = .init(drill: drill, formation: formation)
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Text("\(index + 1)")
                                    .font(.btCTALabelRounded.weight(.bold))
                                    .foregroundStyle(.btPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.btPrimary.opacity(0.14)))
                                VStack(alignment: .leading, spacing: 2) {
                                    // 序号制展示名，与录入/示意图切换器同一口径。
                                    Text(formation.displayName)
                                        .font(.btBody)
                                        .foregroundStyle(.btText)
                                    Text("\(formation.stepCount) 杆 · \(formation.objectBallCount) 球")
                                        .font(.btCaption2)
                                        .foregroundStyle(.btTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.btCaption2)
                                    .foregroundStyle(.btTextTertiary)
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("tryoutFormation_\(index)")

                        if index < formations.count - 1 {
                            Divider().padding(.leading, Spacing.lg + 28 + Spacing.md)
                        }
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .navigationTitle("选择球形")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Tags Row

    private static let ballTypeDisplayNames: [String: String] = [
        "chinese8": "中式台球",
        "8ball": "中式台球",
        "snooker": "斯诺克",
        "nineBall": "9球",
        "pool9": "9球",
        "9ball": "9球",
        "universal": "通用",
    ]

    private func tagsRow(_ drill: DrillContent) -> some View {
        MetadataLayout(spacing: Spacing.sm) {
            BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)

            ForEach(drill.ballType, id: \.self) { ball in
                Text(Self.ballTypeDisplayNames[ball] ?? ball)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(.btBGTertiary)
                    .clipShape(Capsule())
            }

            Text(DrillCategory(rawValue: drill.category)?.nameZh ?? drill.category)
                .font(.btCaption2)
                .foregroundStyle(.btTextSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(.btBGTertiary)
                .clipShape(Capsule())

            // 副分类次徽章（v31 R1）：只影响浏览/筛选，统计不记，故视觉次于主分类。
            ForEach(drill.secondaryCategories ?? [], id: \.self) { secondary in
                Text(DrillCategory(rawValue: secondary)?.nameZh ?? secondary)
                    .font(.btCaption2)
                    .foregroundStyle(.btTextTertiary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .overlay(Capsule().stroke(Color.btSeparator, lineWidth: 1))
                    .accessibilityLabel("副分类 \(DrillCategory(rawValue: secondary)?.nameZh ?? secondary)")
            }
        }
    }

    /// Keep the leading level badge on the left and right-align each wrapped row of tags.
    private struct MetadataLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            arrangement(width: proposal.width, subviews: subviews).size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let layout = arrangement(width: bounds.width, subviews: subviews)
            for (subview, frame) in zip(subviews, layout.frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }

        private func arrangement(width proposedWidth: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
            let idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let idealWidth = idealSizes.reduce(0) { $0 + $1.width }
                + spacing * CGFloat(max(0, subviews.count - 1))
            let width = max(0, proposedWidth.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth)
            var frames: [CGRect] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(
                    ProposedViewSize(width: min(idealSizes[index].width, width), height: nil)
                )
                if x > 0, x + size.width > width {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            // Shift tags as a group per row, leaving the first (level) subview in place.
            var rowStart = 1
            while rowStart < frames.count {
                var rowEnd = rowStart + 1
                while rowEnd < frames.count, frames[rowEnd].minY == frames[rowStart].minY {
                    rowEnd += 1
                }
                let offset = max(0, width - frames[rowEnd - 1].maxX)
                for index in rowStart..<rowEnd {
                    frames[index].origin.x += offset
                }
                rowStart = rowEnd
            }

            return (CGSize(width: width, height: y + rowHeight), frames)
        }
    }

    // MARK: - Coaching Points

    /// - Parameters:
    ///   - includeTutorialCTA: 解锁态才露「查看精讲」（F-DD-04：锁态不露假按钮）。
    ///   - maxPoints: 锁态 progressive 预览收束点数（F-DD-09）；`nil` = 全部。
    private func coachingSection(
        _ drill: DrillContent,
        includeTutorialCTA: Bool,
        maxPoints: Int? = nil
    ) -> some View {
        let points: [(offset: Int, element: String)] = {
            let enumerated = Array(drill.coachingPoints.enumerated())
            if let maxPoints { return Array(enumerated.prefix(maxPoints)) }
            return enumerated
        }()

        return VStack(alignment: .leading, spacing: Spacing.md) {
            // DR-057：精讲为标题行 trailing 文字链，避免卡内再造主色全宽钮与底栏 CTA 抢权。
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text("训练要点")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)

                Spacer(minLength: Spacing.sm)

                if includeTutorialCTA, drill.tutorial != nil {
                    Button {
                        showTutorial = true
                    } label: {
                        HStack(spacing: 2) {
                            Text("查看精讲")
                                .font(.btCallout)
                            Image(systemName: BTIcon.chevronRight)
                                .font(.btCaption.weight(.semibold))
                        }
                        .foregroundStyle(.btPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看精讲")
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(points, id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.btCaption2)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.btPrimary)
                            .clipShape(Circle())

                        Text(DrillCopyDisplay.text(point, drillID: drill.id,
                            field: "coachingPoints[\(index)]", orientation: .landscape))
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(includeTutorialCTA ? Spacing.lg : Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Training Requirements

    /// 达标目标与建议训练量同属「怎么练」。六轴负荷不在此卡（见页底雷达，DR-071）。
    /// 长目标使用全宽纵向排版，不再与短数值强行二等分。
    private func trainingRequirementsSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("训练要求")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label("达标目标", systemImage: BTIcon.target)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)

                standardCriteriaView(DrillCopyDisplay.text(drill.standardCriteria, drillID: drill.id,
                    field: "standardCriteria", orientation: .landscape))
            }

            Divider()

            suggestedDoseSection(drill)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        }
        .padding(.horizontal, Spacing.lg)
        .accessibilityIdentifier("trainingRequirementsSection")
    }

    @ViewBuilder
    private func standardCriteriaView(_ criteria: String) -> some View {
        let items = criteria.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if items.count > 1 {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text("\(index + 1).")
                            .monospacedDigit()
                            .fixedSize()
                        Text(items[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.btCallout)
            .foregroundStyle(.btText)
            .lineSpacing(3)
        } else {
            Text(criteria)
                .font(.btCallout)
                .foregroundStyle(.btText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 建议训练量：逐球形一行（v34 R10 紧凑口径：球形名 + 模式标签 + m × n），
    /// 末行合计以杆计（各行不再含总量，此处是总量唯一出处）。
    @ViewBuilder
    private func suggestedDoseSection(_ drill: DrillContent) -> some View {
        let options = TrainingDoseResolver.formationOptions(forDrillId: drill.id)
        let resolved = TrainingDoseResolver.resolve(content: drill, formationOptions: options)
        let lines = resolved.suggestedDoseLines()
        let totalText = resolved.suggestedDoseTotalText()

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("建议训练量", systemImage: "square.stack.3d.up")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    if let title = line.title {
                        Text(title)
                            .font(.btFootnote)
                            .foregroundStyle(.btTextSecondary)
                            .frame(minWidth: 44, alignment: .leading)
                    }
                    if let modeLabel = line.modeLabel {
                        Text(modeLabel)
                            .font(.btFootnote)
                            .foregroundStyle(.btTextTertiary)
                    }
                    Text(line.text)
                        .font(.btBodyMedium)
                        .foregroundStyle(.btText)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }

            if let totalText {
                Text(totalText)
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .monospacedDigit()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("suggestedDoseSection")
    }

    /// 页底六轴雷达。数据 = drill 代表分；展示分 = 存储分 + 1（1–5）。无 load 时仍画网格、不崩。
    private func loadRadarSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(LoadRadarCopy.sectionTitle)
                .font(.btHeadline)
                .foregroundStyle(.btText)

            BTLoadRadarChart(load: drill.load)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        }
        .padding(.horizontal, Spacing.lg)
        .accessibilityIdentifier("loadRadarSection")
    }

    // MARK: - Bottom Bar（E15：恢复「加入训练」且接线落库）

    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            if isLocked {
                Button { showSubscription = true } label: {
                    BTProUnlockLabel()
                }
                .buttonStyle(BTButtonStyle.goldFilled)
                .accessibilityIdentifier("unlockProButton")
            } else {
                Button {
                    showAddToTraining = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle")
                            .font(.btFootnote14)
                        Text("加入训练")
                    }
                }
                .buttonStyle(BTButtonStyle.primary)
                .accessibilityIdentifier("addToTrainingButton")

                Button { startTryout() } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: BTIcon.playCircleFilled)
                            .font(.btFootnote14)
                        Text("上手试打")
                    }
                }
                .buttonStyle(BTButtonStyle.primary)
                .accessibilityIdentifier("bottomTryoutButton")
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.btBG.opacity(0.8))
        .background(.ultraThinMaterial)
    }

    // MARK: - Add to training (E15)

    private func addDrill(_ drill: DrillContent, to plan: CustomPlan) {
        do {
            let result = try DrillTrainingPlanService.addDrill(drill, to: plan, context: modelContext)
            showAddToTraining = false
            flashAddResult(result)
        } catch let error as ProContentAccess.Failure {
            BTToast.present(error.localizedDescription, tone: .warning) { toast = $0 }
        } catch {
            BTToast.present("加入失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func addDrillToToday(_ drill: DrillContent) {
        do {
            let result = try TodayTrainingScheduleService(context: modelContext).addLibraryDrill(
                id: drill.id, title: drill.nameZh, ownerKey: ownerKey
            )
            showAddToTraining = false
            switch result {
            case .added: BTToast.present("已加入今日安排") { toast = $0 }
            case .alreadyPresent: BTToast.present("已在今日安排", tone: .info) { toast = $0 }
            }
        } catch let error as ProContentAccess.Failure {
            BTToast.present(error.localizedDescription, tone: .warning) { toast = $0 }
        } catch {
            BTToast.present("加入失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func createPlan(name: String, drill: DrillContent, activateAsToday: Bool) {
        do {
            let (_, result) = try DrillTrainingPlanService.createPlan(
                name: name,
                drill: drill,
                activateAsToday: activateAsToday,
                context: modelContext
            )
            showAddToTraining = false
            flashAddResult(result)
        } catch let error as ProContentAccess.Failure {
            BTToast.present(error.localizedDescription, tone: .warning) { toast = $0 }
        } catch DrillTrainingPlanService.ServiceError.emptyName {
            BTToast.present("请填写模版名称", tone: .warning) { toast = $0 }
        } catch {
            BTToast.present("创建失败，请稍后重试", tone: .error) { toast = $0 }
        }
    }

    private func flashAddResult(_ result: DrillTrainingPlanService.AddResult) {
        let text: String
        switch result {
        case .added(let planName, let appearsInToday):
            text = appearsInToday
                ? "已加入今日训练「\(planName)」"
                : "已加入模版「\(planName)」"
        case .alreadyPresent(let planName, let appearsInToday):
            text = appearsInToday
                ? "已在今日训练「\(planName)」中"
                : "已在模版「\(planName)」中"
        }
        BTToast.present(text, tone: .success) { toast = $0 }
    }

    // MARK: - Helpers

    private func loadDrill() async {
        defer { didFinishLoading = true }
        let service = DrillContentService.shared
        drill = await service.loadDrillFromBundle(id: drillId)
    }

    private func toggleFavorite() {
        // F-DD-07：收藏切换短过渡。
        withAnimation(BTMotion.easeFast) {
            if let existing = favorites.first(where: { $0.drillId == drillId }) {
                modelContext.delete(existing)
            } else {
                modelContext.insert(DrillFavorite(drillId: drillId, ownerKey: ownerKey))
            }
        }
    }
}

// MARK: - Add to training sheet

private struct AddDrillToTrainingSheet: View {
    let drill: DrillContent
    let customPlans: [CustomPlan]
    let onAddToToday: () -> Void
    let onAddToPlan: (CustomPlan) -> Void
    let onCreatePlan: (_ name: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newPlanName: String = ""

    var body: some View {
        NavigationStack {
            List {
                todaySection

                if !customPlans.isEmpty {
                    Section("我的模版") {
                        ForEach(customPlans, id: \.id) { plan in
                            Button {
                                onAddToPlan(plan)
                            } label: {
                                planRow(
                                    title: plan.name,
                                    subtitle: DrillTrainingPlanService.planContainsDrill(plan, drillId: drill.id)
                                        ? "已包含 · \(plan.drills.count) 项"
                                        : "\(plan.drills.count) 项",
                                    systemImage: "list.bullet.clipboard",
                                    emphasized: false
                                )
                            }
                            .accessibilityIdentifier("addToPlan_\(plan.id.uuidString)")
                        }
                    }
                }

                Section("新建模版") {
                    PlanNameInput(text: $newPlanName)
                    Button {
                        requestCreatePlan()
                    } label: {
                        Label("创建并加入「\(drill.nameZh)」", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("createPlanAndAddButton")
                }
            }
            .navigationTitle("加入训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if newPlanName.isEmpty {
                newPlanName = "从动作库 · \(drill.nameZh)"
            }
        }
    }

    @ViewBuilder
    private var todaySection: some View {
        Section("今日安排") {
            Button(action: onAddToToday) {
                planRow(
                    title: "加入今日安排",
                    subtitle: "作为独立训练项，不影响当前官方计划",
                    systemImage: "sun.max.fill",
                    emphasized: true
                )
            }
            .accessibilityIdentifier("addToTodayTrainingRow")
        }
    }

    private func requestCreatePlan() {
        let name = newPlanName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "从动作库 · \(drill.nameZh)"
        let resolved = name.isEmpty ? fallback : name
        onCreatePlan(resolved)
    }

    private func planRow(
        title: String,
        subtitle: String,
        systemImage: String,
        emphasized: Bool
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(emphasized ? Color.btPrimary : Color.btTextSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.btBodyMedium)
                    .foregroundStyle(.btText)
                Text(subtitle)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            Spacer()
            Image(systemName: "plus")
                .font(.btCaption)
                .foregroundStyle(.btPrimary)
        }
        .contentShape(Rectangle())
    }
}

/// Owns the initial tap so UIKit's caret-placement gesture cannot undo the selection.
/// Once editing starts, all touches and marked-text handling belong to UITextField.
private struct PlanNameInput: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> PlanNameInputView {
        PlanNameInputView()
    }

    func updateUIView(_ view: PlanNameInputView, context: Context) {
        view.onChange = { text = $0 }
        if view.field.markedTextRange == nil, view.field.text != text {
            view.field.text = text
        }
        view.field.textColor = UIColor(Color.btText)
        view.field.tintColor = UIColor(Color.btPrimary)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PlanNameInputView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? uiView.field.intrinsicContentSize.width,
               height: uiView.field.intrinsicContentSize.height)
    }
}

private final class PlanNameInputView: UIView, UITextFieldDelegate {
    let field = PlanNameTextField()
    private let activationButton = UIButton(type: .custom)
    var onChange: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        field.placeholder = "模版名称"
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .done
        field.accessibilityLabel = "模版名称"
        field.accessibilityHint = "点按后全选名称，可直接输入替换"
        field.accessibilityIdentifier = "newPlanNameField"
        field.delegate = self
        field.activate = { [weak self] in self?.activateEditing() ?? false }
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(field)
        // This button only intercepts the first tap; it is never an extra AX element.
        activationButton.isAccessibilityElement = false
        activationButton.addTarget(self, action: #selector(beginEditingFromTap), for: .touchUpInside)
        addSubview(activationButton)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        field.frame = bounds
        activationButton.frame = bounds
    }

    @objc private func beginEditingFromTap() { _ = activateEditing() }

    private func activateEditing() -> Bool {
        guard window != nil else { return false }
        guard !field.isFirstResponder else { return true }
        guard field.becomeFirstResponder() else { return false }
        activationButton.isHidden = true
        field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        activationButton.isHidden = true
        // Also covers keyboard/VoiceOver focus without depending on notification AX IDs.
        textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        activationButton.isHidden = false
        onChange?(textField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc private func textChanged() {
        // Publish the visible draft even during composition; updateUIView never
        // writes back into marked text, so creation cannot read the old name.
        onChange?(field.text ?? "")
    }
}

private final class PlanNameTextField: UITextField {
    var activate: (() -> Bool)?

    override func accessibilityActivate() -> Bool {
        activate?() ?? super.accessibilityActivate()
    }
}

#Preview("Light") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    NavigationStack {
        DrillDetailView(drillId: "drill_c001")
    }
    .modelContainer(ModelContainerFactory.makeInMemoryContainer())
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}
