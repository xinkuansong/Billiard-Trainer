import SwiftUI
import SwiftData

struct DrillDetailView: View {
    let drillId: String

    @State private var drill: DrillContent?
    @State private var showSubscription = false
    @State private var showTutorial = false
    /// 「上手试打」push（试打模式方案 §1.6：入口直进试打页，不做预览页）。
    @State private var showTryout = false
    /// 试打球形集合（D4，与视频示范同源；空 = 无序列，回退 shotIntent 球局）。
    @State private var tryoutFormations: [DrillTryoutFormation] = []
    /// 选中的试打球形（nil = shotIntent 兜底路径）。
    @State private var selectedFormation: DrillTryoutFormation?
    /// 多球形选择 sheet（>1 个球形时弹出，单球形直进）。
    /// 用 item 承载列表快照：iOS 26 上 `.sheet(isPresented:)` 内容闭包会以陈旧
    /// state 求值（tryoutFormations 渲染为空，B4 发现，c042/c053 均复现）。
    @State private var formationPicker: FormationPickerPayload?
    /// E15：加入训练（自定义计划 / 今日训练）选择 sheet。
    @State private var showAddToTraining = false
    @State private var toast: BTToastMessage?

    /// sheet(item:) 载荷：球形列表快照。
    private struct FormationPickerPayload: Identifiable {
        let id = UUID()
        let formations: [DrillTryoutFormation]
    }
    @Query private var favorites: [DrillFavorite]
    @Query(sort: \CustomPlan.createdAt, order: .reverse) private var customPlans: [CustomPlan]
    @Query private var activePlans: [UserActivePlan]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private var isFavorited: Bool {
        favorites.contains { $0.drillId == drillId }
    }

    private var isLocked: Bool {
        guard let drill else { return false }
        return drill.isPremium && !subscriptionManager.isPremium
    }

    private var activeCustomPlan: CustomPlan? {
        guard let active = activePlans.first(where: \.isCustom),
              let uuid = UUID(uuidString: active.planId) else { return nil }
        return customPlans.first { $0.id == uuid }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                if let drill {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        tableSection(drill)

                        Text(drill.nameZh)
                            .font(.btTitle)
                            .foregroundStyle(.btText)
                            .padding(.horizontal, Spacing.lg)

                        // F-DD-01：露出 Bundle 已有 description（转化页信息权重）。
                        Text(drill.description)
                            .font(.btCallout)
                            .foregroundStyle(.btTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.lg)

                        tagsRow(drill)

                        if isLocked {
                            // F-DD-04/09：锁态紧凑预览、不露假「查看精讲」；不改 isPremium 门槛。
                            BTPremiumLock(mode: .progressive(visibleItems: 1), onSubscribeTap: {
                                showSubscription = true
                            }) {
                                coachingSection(drill, includeTutorialCTA: false, maxPoints: 2)
                            }
                        } else {
                            coachingSection(drill, includeTutorialCTA: true)
                            criteriaSection(drill)
                            dimensionsSection(drill)
                        }
                    }
                    .padding(.bottom, 100)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
            .background(.btBG)

            if drill != nil {
                bottomBar
            }

            if let toast {
                BTToastBanner(message: toast)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 固定顶栏始终显示材质背景，避免滚动内容穿透状态栏/标题（UR-20260529 U-06）。
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(drill?.nameZh ?? "")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .btAccent : .btTextSecondary)
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
        .navigationDestination(isPresented: $showTryout) {
            if let drill {
                PositionPlayComposerView(sourceDrill: drill, tryoutFormation: selectedFormation)
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
                    activeCustomPlanId: activeCustomPlan?.id,
                    onAddToPlan: { plan in
                        addDrill(drill, to: plan)
                    },
                    onCreatePlan: { name, activate in
                        createPlan(name: name, drill: drill, activateAsToday: activate)
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
        // 「上手试打」（试打模式方案 §1.6）：Premium 锁定态带皇冠、点击弹订阅（Freemium 钩子）；
        // 解锁态直进试打页（复用 showTutorial 同 push 模式）。
        DrillSceneView(
            drill: drill,
            tryoutLocked: isLocked,
            onTryoutTap: {
                if isLocked { showSubscription = true } else { startTryout() }
            }
        )
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Tryout entry（D4：球形与视频示范同源）

    /// 解锁态入口：>1 个球形弹选择，单球形/无序列直进。
    private func startTryout() {
        tryoutFormations = DrillTryoutBoardStore.formations(for: drillId)
        if tryoutFormations.count > 1 {
            formationPicker = FormationPickerPayload(formations: tryoutFormations)
        } else {
            selectedFormation = tryoutFormations.first
            showTryout = true
        }
    }

    /// 多球形选择 sheet：球形名 + 杆数，选中即进试打页（暗材质，与试打页衔接）。
    private func formationPickerSheet(_ formations: [DrillTryoutFormation]) -> some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(formations.enumerated()), id: \.element.id) { index, formation in
                        Button {
                            selectedFormation = formation
                            formationPicker = nil
                            showTryout = true
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Text("\(index + 1)")
                                    .font(.btCTALabelRounded.weight(.bold))
                                    .foregroundStyle(.btPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.btPrimary.opacity(0.14)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formation.title)
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
        HStack(spacing: Spacing.sm) {
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

            BTLevelBadge(level: DrillLevel(rawValue: drill.level) ?? .L0)
        }
        .padding(.horizontal, Spacing.lg)
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
            Text("训练要点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(points, id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.btCaption2)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.btPrimary)
                            .clipShape(Circle())

                        Text(point)
                            .font(.btCallout)
                            .foregroundStyle(.btText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if includeTutorialCTA, drill.tutorial != nil {
                Button {
                    showTutorial = true
                } label: {
                    Text("查看精讲")
                }
                .buttonStyle(BTButtonStyle.primary)
            }
        }
        .padding(includeTutorialCTA ? Spacing.lg : Spacing.md)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Standard Criteria（E17：达标标准与默认组次对照合并）

    private func criteriaSection(_ drill: DrillContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("达标标准")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            HStack(alignment: .top, spacing: Spacing.md) {
                criteriaColumn(
                    title: "目标",
                    icon: BTIcon.target,
                    value: drill.standardCriteria
                )

                Rectangle()
                    .fill(Color.btSeparator)
                    .frame(width: 1)
                    .padding(.vertical, Spacing.xs)

                criteriaColumn(
                    title: "建议量",
                    icon: "square.stack.3d.up",
                    value: "\(drill.sets.defaultSets) 组 × \(drill.sets.defaultBallsPerSet) 球"
                )
                .frame(maxWidth: 140, alignment: .leading)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
        .accessibilityIdentifier("criteriaSection")
    }

    private func criteriaColumn(title: String, icon: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .labelStyle(.titleAndIcon)

            Text(value)
                .font(.btBodyMedium)
                .foregroundStyle(.btText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Training Dimensions（E14 / D-v25-13：定性 chip，保留五维）

    private func dimensionsSection(_ drill: DrillContent) -> some View {
        let dims = trainingDimensions(for: drill)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("训练维度")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            // D-v25-13：五维全景 chip；去进度条与免责文案。
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108), spacing: Spacing.sm)],
                alignment: .leading,
                spacing: Spacing.sm
            ) {
                ForEach(dims, id: \.name) { dim in
                    dimensionChip(name: dim.name, weight: Self.dimensionWeightLabel(dim.value))
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .padding(.horizontal, Spacing.lg)
        .accessibilityIdentifier("dimensionsSection")
    }

    private func dimensionChip(name: String, weight: String) -> some View {
        let emphasis = weight == "重点"
        return Text("\(name) · \(weight)")
            .font(.btCaption)
            .foregroundStyle(emphasis ? Color.btPrimary : Color.btTextSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .background(emphasis ? Color.btPrimaryMuted : Color.btBGTertiary)
            .clipShape(Capsule())
            .accessibilityLabel("\(name)，\(weight)")
    }

    /// F-DD-02：启发式权重 → 定性档，不用伪装百分数。
    private static func dimensionWeightLabel(_ value: CGFloat) -> String {
        switch value {
        case 0.65...: return "重点"
        case 0.4..<0.65: return "中等"
        default: return "辅助"
        }
    }

    private struct DimensionData {
        let name: String
        let value: CGFloat
    }

    private func trainingDimensions(for drill: DrillContent) -> [DimensionData] {
        let cat = drill.category
        let diff = CGFloat(drill.difficulty) / 5.0

        var accuracy: CGFloat = 0.3
        var forceCtrl: CGFloat = 0.3
        var positioning: CGFloat = 0.2
        var cueSkill: CGFloat = 0.2
        var mental: CGFloat = 0.1

        switch cat {
        case "accuracy":
            accuracy = 0.7 + diff * 0.2
            forceCtrl = 0.3 + diff * 0.1
        case "fundamentals":
            accuracy = 0.5; forceCtrl = 0.3; cueSkill = 0.2
        case "cueAction":
            cueSkill = 0.7 + diff * 0.2
            forceCtrl = 0.5 + diff * 0.1
        case "separation":
            positioning = 0.6 + diff * 0.2
            cueSkill = 0.5
        case "positioning":
            positioning = 0.7 + diff * 0.2
            accuracy = 0.4
        case "forceControl":
            forceCtrl = 0.7 + diff * 0.2
            cueSkill = 0.4
        case "specialShots":
            cueSkill = 0.6 + diff * 0.2
            mental = 0.4 + diff * 0.1
        case "combined":
            accuracy = 0.5 + diff * 0.15
            forceCtrl = 0.5 + diff * 0.1
            positioning = 0.5 + diff * 0.1
            cueSkill = 0.4 + diff * 0.1
            mental = 0.3 + diff * 0.15
        default: break
        }

        return [
            DimensionData(name: "准度", value: min(accuracy, 1.0)),
            DimensionData(name: "力量控制", value: min(forceCtrl, 1.0)),
            DimensionData(name: "走位判断", value: min(positioning, 1.0)),
            DimensionData(name: "杆法技巧", value: min(cueSkill, 1.0)),
            DimensionData(name: "心理素质", value: min(mental, 1.0)),
        ]
    }

    // MARK: - Bottom Bar（E15：恢复「加入训练」且接线落库）

    private var bottomBar: some View {
        HStack(spacing: Spacing.md) {
            if isLocked {
                Button { showSubscription = true } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: BTIcon.crown)
                            .font(.btFootnote14)
                        Text("解锁 Pro")
                    }
                }
                .buttonStyle(BTButtonStyle.goldFilled)
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
                .buttonStyle(BTButtonStyle.secondary)
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
        .padding(.horizontal, Spacing.xxl)
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
        } catch DrillTrainingPlanService.ServiceError.emptyName {
            BTToast.present("请填写计划名称", tone: .warning) { toast = $0 }
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
                : "已加入计划「\(planName)」"
        case .alreadyPresent(let planName, let appearsInToday):
            text = appearsInToday
                ? "已在今日训练「\(planName)」中"
                : "已在计划「\(planName)」中"
        }
        BTToast.present(text, tone: .success) { toast = $0 }
    }

    // MARK: - Helpers

    private func loadDrill() async {
        let service = DrillContentService.shared
        drill = await service.loadDrillFromBundle(id: drillId)
    }

    private func toggleFavorite() {
        // F-DD-07：收藏切换短过渡。
        withAnimation(BTMotion.easeFast) {
            if let existing = favorites.first(where: { $0.drillId == drillId }) {
                modelContext.delete(existing)
            } else {
                modelContext.insert(DrillFavorite(drillId: drillId))
            }
        }
    }
}

// MARK: - Add to training sheet

private struct AddDrillToTrainingSheet: View {
    let drill: DrillContent
    let customPlans: [CustomPlan]
    let activeCustomPlanId: UUID?
    let onAddToPlan: (CustomPlan) -> Void
    let onCreatePlan: (_ name: String, _ activateAsToday: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newPlanName: String = ""
    @State private var activateNewAsToday = true

    var body: some View {
        NavigationStack {
            List {
                if let today = customPlans.first(where: { $0.id == activeCustomPlanId }) {
                    Section {
                        Button {
                            onAddToPlan(today)
                        } label: {
                            planRow(
                                title: "今日训练 · \(today.name)",
                                subtitle: DrillTrainingPlanService.planContainsDrill(today, drillId: drill.id)
                                    ? "已包含该动作"
                                    : "加入后会出现在训练 Tab 今日清单",
                                systemImage: "sun.max.fill",
                                emphasized: true
                            )
                        }
                        .accessibilityIdentifier("addToTodayTrainingRow")
                    } header: {
                        Text("今日训练")
                    }
                } else {
                    Section {
                        Text("当前没有自定义「今日训练」。可新建计划并设为今日，或先加入已有计划。")
                            .font(.btFootnote)
                            .foregroundStyle(.btTextSecondary)
                    }
                }

                if !customPlans.isEmpty {
                    Section("我的计划") {
                        ForEach(customPlans, id: \.id) { plan in
                            Button {
                                onAddToPlan(plan)
                            } label: {
                                planRow(
                                    title: plan.name,
                                    subtitle: DrillTrainingPlanService.planContainsDrill(plan, drillId: drill.id)
                                        ? "已包含 · \(plan.drills.count) 项"
                                        : "\(plan.drills.count) 项 · 每周 \(plan.sessionsPerWeek) 练",
                                    systemImage: plan.id == activeCustomPlanId
                                        ? "checkmark.circle.fill"
                                        : "list.bullet.clipboard",
                                    emphasized: false
                                )
                            }
                            .accessibilityIdentifier("addToPlan_\(plan.id.uuidString)")
                        }
                    }
                }

                Section("新建计划") {
                    TextField("计划名称", text: $newPlanName)
                        .accessibilityIdentifier("newPlanNameField")
                    Toggle("设为今日训练", isOn: $activateNewAsToday)
                    Button {
                        let name = newPlanName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let fallback = "从动作库 · \(drill.nameZh)"
                        onCreatePlan(name.isEmpty ? fallback : name, activateNewAsToday)
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
