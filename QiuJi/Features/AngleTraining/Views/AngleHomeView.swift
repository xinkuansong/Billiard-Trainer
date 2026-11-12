import SwiftUI
import OSLog

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
    /// 球理索引（v30 W0 / v32 理区）：分组列出 T01–T10 + 流程 + 速查表。
    case theoryIndex
    /// 球理详情页（v30 W0）：12 篇共用一个参数化 case，载荷见 `TheoryPageID`；
    /// 目的地在 `MainTabView.theoryDestination` 的 switch 中逐页注册（W1–W4）。
    case theoryPage(TheoryPageID)
    case contactPointTable
    case aimingPrinciple
    /// 瞄准方法（v11 Y1）：管道 / 接触点·重合比例 / 平行线。
    case aimingMethods
    /// 瞄准修正（v12 Z1）：投掷 · 挤偏 · 弧线；几何之外的偏差。
    case aimingCorrection
    /// 旋转与加塞（v11 Y2）：母球旋转状态 → 分离角；最小加塞 / 打滑极限。
    case spinAndEnglish
    /// 分离角图谱（v11 Y3）：8 档高低杆碰后→第一库轨迹对比。
    case separationAngleAtlas
    /// 加塞吃库图谱（v20 W2 / DR-075）：选定高低杆 × 该高度允许加塞弦 × 8 档吃库后出射。
    case cushionEnglishAtlas
    case pocketTolerance
    case angleDynamic
    case geometricQuiz
    /// 2D 瞄准训练（T-P18-48 拆两卡）：俯视练几何判断。
    case snakePractice
    case multiBallPractice, multiBallPractice3D
    case customFormationPractice
    case sceneAiming2D
    /// 3D 瞄准训练（T-P18-48 拆两卡）：站位视角练临场球感。
    case sceneAiming3D
    /// 瞄准点训练（条 8）：给角度拖假想球，mm 误差反馈。
    case aimPointTraining
    /// 2D 瞄准点训练（条 9）：真台出题，瞄准线微调 + 自动击球验证。
    case aimPointScene2D
    /// 3D 瞄准点训练（条 10）：站位相机版。
    case aimPointScene3D
    case accuracy2D, accuracy3D
    case separationPractice2D, separationPractice3D
    case kickPractice2D
    case defensePractice2D
    case bankPractice2D
    case kBallPractice2D
    case twoBallPractice2D, twoBallPractice3D
    case threeBallPractice2D, threeBallPractice3D
    case ballFeel
    case bankShot
    case diamondSystem
    case shotSimulation
    case positionPlayComposer
    /// 自由击球（ADR-P18-01）：编排台自由瞄准模式直达入口；B2 补齐手动瞄准 UI 后成为完整形态。
    case freePlay
    case positionPlaySolver
    case planThree
    case ballExtraction
    /// 批量出片台（仅模拟器，内容生产工具）。
    case batchDrillStudio
    /// 学区 CTA → 动作库 drill 详情（v21 W5；练习 Tab 内嵌 DrillDetailView）。
    case drillDetail(String)

    var requiresPremium: Bool {
        switch self {
        case .separationAngleAtlas, .cushionEnglishAtlas,
             .snakePractice, .positionPlaySolver,
             .ballExtraction, .planThree, .bankShot, .diamondSystem:
            return true
        case .sceneAiming3D, .aimPointScene3D, .accuracy3D, .separationPractice3D, .twoBallPractice3D, .threeBallPractice3D, .multiBallPractice3D,
             .theoryIndex, .theoryPage, .contactPointTable, .aimingPrinciple,
             .aimingMethods, .aimingCorrection, .spinAndEnglish, .angleDynamic, .pocketTolerance,
             .geometricQuiz, .multiBallPractice, .customFormationPractice, .sceneAiming2D,
             .kickPractice2D, .defensePractice2D, .bankPractice2D, .kBallPractice2D, .aimPointTraining, .aimPointScene2D, .accuracy2D, .separationPractice2D, .twoBallPractice2D, .threeBallPractice2D, .ballFeel, .freePlay, .positionPlayComposer, .shotSimulation,
             .batchDrillStudio, .drillDetail:
            return false
        }
    }
}

// MARK: - Topic Filter Model

/// 练习页主题筛选标签（与六组侧栏正交：侧栏按学习任务分区，主题按内容横切）。
private enum PracticeTopic: String, CaseIterable, Identifiable {
    case accuracy = "准度"
    case english = "加塞"
    case position = "走位"
    case cushion = "吃库"
    case safety = "防守"

    var id: String { rawValue }
}

// MARK: - Entry Model

/// The primary activity on the destination, independent of the sidebar section.
private enum PracticeContentKind: String, CaseIterable {
    case reading = "阅读"
    case quiz = "答题"
    case striking = "击球"
    case interactive = "交互"

    static func theory(_ page: TheoryPageID) -> Self {
        switch page {
        case .t01, .t02, .t03: .interactive
        case .t04, .t05, .t06, .t07, .t08, .t09, .t10, .flow, .quickRef: .reading
        }
    }
}

private enum PracticeLearningDifficulty {
    case introductory, applied, integrated, tool, reference

    var starCount: Int? {
        switch self {
        case .introductory: 3
        case .applied: 4
        case .integrated: 5
        case .tool, .reference: nil
        }
    }

    var usageLabel: String? {
        switch self {
        case .tool: "工具"
        case .reference: "速查"
        case .introductory, .applied, .integrated: nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .introductory: "学习难度三星，入门"
        case .applied: "学习难度四星，应用"
        case .integrated: "学习难度五星，综合"
        case .tool: "工具，不评级"
        case .reference: "速查，不评级"
        }
    }
}

private struct AngleEntry: Identifiable {
    var id: AngleRoute { route }
    func accessibilityContext(isUnlocked: Bool) -> String {
        guard isPremium else { return contentKind.rawValue }
        return contentKind.rawValue + (isUnlocked ? "，Pro 内容已解锁" : "，Pro 内容未解锁")
    }

    let route: AngleRoute
    let title: String
    let subtitle: String
    let contentKind: PracticeContentKind
    let difficulty: PracticeLearningDifficulty
    let palette: CoverPalette.Pair
    var isPremium: Bool { route.requiresPremium }
    /// 主题标签（可多个）；空 = 综合内容，仅在未选主题时出现。
    var topics: Set<PracticeTopic> = []

    init(
        route: AngleRoute,
        title: String,
        subtitle: String,
        contentKind: PracticeContentKind,
        difficulty: PracticeLearningDifficulty,
        topics: Set<PracticeTopic> = []
    ) {
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.contentKind = contentKind
        self.difficulty = difficulty
        self.palette = AtmosphereCatalog.cover(for: route).pair
        self.topics = topics
    }
}

// MARK: - Sections (six learning tasks; see the 2026-11-06 plan)

private enum PracticeSection: String, CaseIterable, Identifiable {
    case basics = "基础"
    case accuracy = "准度"
    case cueControl = "控球"
    case position = "走位"
    case advanced = "进阶"
    case strategy = "策略"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .basics: "book"
        case .accuracy: "target"
        case .cueControl: "circle.circle"
        case .position: "arrow.triangle.branch"
        case .advanced: "square.stack.3d.up"
        case .strategy: "lightbulb"
        }
    }

    var filledIcon: String {
        switch self {
        case .basics: "book.fill"
        case .accuracy: "target"
        case .cueControl: "circle.circle"
        case .position: "arrow.triangle.branch"
        case .advanced: "square.stack.3d.up.fill"
        case .strategy: "lightbulb.fill"
        }
    }

    var caption: String {
        switch self {
        case .basics: "理解瞄准、旋转与进球空间"
        case .accuracy: "从判断角度到瞄准进球"
        case .cueControl: "掌握母球碰撞、旋转与速度"
        case .position: "规划落点，练习连续衔接"
        case .advanced: "练习翻袋、解球、K球与防守"
        case .strategy: "安排球序，权衡攻防与风险"
        }
    }
}

// MARK: - Home View

/// 练习 Tab 首页（ADR-P11-08 / ADR-P18-01 / ADR-P18-03 / v28 / v32 / v45）：与「动作库」同一套布局语言——
/// 母题矮带 + 左侧图标分类侧栏（全部、基础、准度、控球、走位、进阶、策略）+ 右侧双列分组网格（钉住分组头），
/// 卡片外壳保留 v28 `BTContentGridCard`，封面为 Bundle 静物 + 现网分类色罩。
struct AngleHomeView: View {
    /// nil = 全部（默认，与动作库侧栏一致）。
    @State private var selectedSection: PracticeSection? = nil
    @State private var scrollToken = 0
    @State private var searchText = ""
    /// nil = 不按主题筛选（v34：与动作库搜索栏同款筛选 Menu）。
    @State private var selectedTopic: PracticeTopic? = nil
    @State private var showSubscription = false
    @State private var pendingSeparationRoute: AngleRoute?
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    private let basicsEntries: [AngleEntry] = [
        .init(route: .aimingPrinciple, title: "瞄准原理", subtitle: "理解切角、厚薄与瞄准点的关系", contentKind: .reading, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .aimingMethods, title: "瞄准方法", subtitle: "对比同一球形的三种瞄准方法", contentKind: .interactive, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .spinAndEnglish, title: "旋转与加塞", subtitle: "认识打点、旋转与母球走向", contentKind: .interactive, difficulty: .applied, topics: [.english, .position]),
        .init(route: .aimingCorrection, title: "瞄准修正", subtitle: "观察力度与旋转造成的瞄准偏差", contentKind: .interactive, difficulty: .applied, topics: [.accuracy, .english]),
        .init(route: .contactPointTable, title: "瞄准点对照表", subtitle: "按切角查瞄准点与接触点", contentKind: .interactive, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .ballFeel, title: "浅谈凭感觉瞄准", subtitle: "用参照和练习建立瞄准感觉", contentKind: .reading, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .pocketTolerance, title: "进球容错角", subtitle: "摆球查看可进袋的方向范围", contentKind: .interactive, difficulty: .introductory, topics: [.accuracy]),
    ]

    private let accuracyEntries: [AngleEntry] = [
        .init(route: .angleDynamic, title: "角度与瞄准", subtitle: "拖动球形观察切角与瞄准方向", contentKind: .interactive, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .geometricQuiz, title: "角度预测", subtitle: "看简图估切角，对照答案与误差", contentKind: .quiz, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .sceneAiming2D, title: TrainingProject.angle.title, subtitle: "在球桌场景中练习切角判断", contentKind: .quiz, difficulty: .applied, topics: [.accuracy]),
        .init(route: .aimPointTraining, title: "假想球练习", subtitle: "根据切角摆准假想球位置", contentKind: .quiz, difficulty: .introductory, topics: [.accuracy]),
        .init(route: .aimPointScene2D, title: TrainingProject.aimPoint.title, subtitle: "在球桌上选准瞄准方向", contentKind: .quiz, difficulty: .applied, topics: [.accuracy]),
        .init(route: .accuracy2D, title: TrainingProject.accuracy.title, subtitle: "调整瞄准与杆速，击球检验进袋", contentKind: .quiz, difficulty: .applied, topics: [.accuracy]),
    ]

    private let cueControlInteractiveEntries: [AngleEntry] = [
        .init(route: .separationAngleAtlas, title: "分离角图谱", subtitle: "对比不同高低杆的母球路线", contentKind: .interactive, difficulty: .applied, topics: [.position]),
        .init(route: .cushionEnglishAtlas, title: "加塞吃库图谱", subtitle: "对比不同左右塞的母球吃库路线", contentKind: .interactive, difficulty: .applied, topics: [.english, .cushion]),
    ]

    private var cueControlEntries: [AngleEntry] {
        cueControlInteractiveEntries + theoryEntries(for: [.t01, .t02, .t03, .t04, .t09])
    }

    private let basePositionEntries: [AngleEntry] = [
        .init(route: .positionPlayComposer, title: TablePreferencePage.composer.layoutTitle, subtitle: "自由摆球试打，观察母球走位", contentKind: .striking, difficulty: .applied, topics: [.position, .english]),
        .init(route: .positionPlaySolver, title: TablePreferencePage.silu.layoutTitle, subtitle: "指定落位要求，求解击球方案", contentKind: .striking, difficulty: .applied, topics: [.position, .english]),
        .init(route: .planThree, title: TablePreferencePage.planThree.layoutTitle, subtitle: "根据后两颗球倒推当前走位", contentKind: .striking, difficulty: .integrated, topics: [.position]),
        .init(route: .separationPractice2D, title: TrainingProject.separation.title, subtitle: "调整打点与力度，复现母球路线", contentKind: .quiz, difficulty: .applied, topics: [.position, .english]),
        .init(route: .twoBallPractice2D, title: "两球走位", subtitle: "打进第一球，为第二球留下位置", contentKind: .quiz, difficulty: .applied, topics: [.position, .english]),
        .init(route: .threeBallPractice2D, title: "三球走位", subtitle: "提前选袋，完成两杆走位衔接", contentKind: .quiz, difficulty: .integrated, topics: [.position, .english]),
        .init(route: .multiBallPractice, title: "多球走位", subtitle: "规划球序，练习残局连续走位", contentKind: .striking, difficulty: .integrated, topics: [.position]),
        .init(route: .snakePractice, title: "蛇彩练习", subtitle: "按指定顺序连续进球与走位", contentKind: .striking, difficulty: .integrated, topics: [.position, .accuracy]),
        .init(route: .customFormationPractice, title: "自定义球形", subtitle: "编辑保存球形，随时重复练习", contentKind: .striking, difficulty: .tool, topics: [.position, .accuracy]),
        .init(route: .ballExtraction, title: "拍照建球形", subtitle: "从照片还原球形，校准后推演", contentKind: .interactive, difficulty: .tool),
    ]

    private var positionEntries: [AngleEntry] {
        var entries = basePositionEntries
        #if targetEnvironment(simulator)
        // Internal production tool; excluded from the 43 public cards.
        entries.append(.init(
            route: .batchDrillStudio,
            title: "批量出片台",
            subtitle: "drill 截图 → 序列 → 素材",
            contentKind: .interactive,
            difficulty: .tool
        ))
        #endif
        return entries
    }

    private let advancedEntries: [AngleEntry] = [
        .init(route: .bankShot, title: "翻袋", subtitle: "摆球求解目标球翻库入袋", contentKind: .striking, difficulty: .applied, topics: [.cushion, .accuracy]),
        .init(route: .diamondSystem, title: "颗星解球", subtitle: "摆球求解母球绕库碰球", contentKind: .striking, difficulty: .applied, topics: [.cushion]),
        .init(route: .bankPractice2D, title: "翻袋练习", subtitle: "按指定库序将目标球翻进袋", contentKind: .quiz, difficulty: .integrated, topics: [.accuracy, .english, .cushion]),
        .init(route: .kickPractice2D, title: "解球练习", subtitle: "按指定库序让母球解到目标球", contentKind: .quiz, difficulty: .integrated, topics: [.position, .english, .cushion]),
        .init(route: .kBallPractice2D, title: "K球练习", subtitle: "进球同时让母球碰到第二球", contentKind: .quiz, difficulty: .integrated, topics: [.position, .english, .cushion]),
        .init(route: .defensePractice2D, title: "防守练习", subtitle: "控制双方球位，限制对手进攻", contentKind: .quiz, difficulty: .integrated, topics: [.accuracy, .english, .cushion]),
    ]

    private var strategyEntries: [AngleEntry] {
        theoryEntries(for: [.t05, .t06, .t07, .t08, .t10, .flow, .quickRef])
    }

    private func theoryEntries(for pageIDs: [TheoryPageID]) -> [AngleEntry] {
        pageIDs.compactMap { pageID in
            guard let entry = TheoryCatalog.entries.first(where: { $0.id == pageID }) else {
                Logger(subsystem: "com.xinkuan.qiuji", category: "PracticeCatalog")
                    .error("Missing theory page: \(pageID.rawValue, privacy: .public)")
                assertionFailure("Missing theory page: \(pageID.rawValue)")
                return nil
            }
            guard entry.isPublished else { return nil }
            return AngleEntry(
                route: .theoryPage(entry.id),
                title: entry.title,
                subtitle: entry.cardSubtitle,
                contentKind: .theory(entry.id),
                difficulty: Self.theoryDifficulty(for: entry.id),
                topics: Self.theoryTopics(for: entry.id)
            )
        }
    }

    private static func theoryDifficulty(for pageID: TheoryPageID) -> PracticeLearningDifficulty {
        switch pageID {
        case .t01: .applied
        case .t02: .applied
        case .t03: .applied
        case .t04: .introductory
        case .t09: .applied
        case .t05: .applied
        case .t06: .applied
        case .t07: .integrated
        case .t08: .integrated
        case .t10: .applied
        case .flow: .integrated
        case .quickRef: .reference
        }
    }

    private static func theoryTopics(for pageID: TheoryPageID) -> Set<PracticeTopic> {
        switch pageID {
        case .t01, .t02, .t03: [.accuracy, .position]   // 碰撞法则：瞄准 + 碰后走向
        case .t04: [.position]                          // 母球速度分级
        case .t09: [.english]                           // 最少加塞原则
        case .t05, .t06, .t07: [.position]              // 反向规划 / 关键球 / 球团
        case .t08: [.position, .safety]                 // 风险报酬决策
        case .t10: [.safety]                            // 安全球三维度
        case .flow, .quickRef: []
        }
    }

    private func entries(for section: PracticeSection) -> [AngleEntry] {
        switch section {
        case .basics: basicsEntries
        case .accuracy: accuracyEntries
        case .cueControl: cueControlEntries
        case .position: positionEntries
        case .advanced: advancedEntries
        case .strategy: strategyEntries
        }
    }

    private func filteredEntries(for section: PracticeSection) -> [AngleEntry] {
        var all = entries(for: section)
        if let topic = selectedTopic {
            all = all.filter { $0.topics.contains(topic) }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    /// 搜索时只保留有命中的分组；分组头保留以标示命中所属分类。
    private var visibleGroups: [(section: PracticeSection, entries: [AngleEntry])] {
        let sections = selectedSection.map { [$0] } ?? PracticeSection.allCases
        return sections.compactMap { section in
            let matched = filteredEntries(for: section)
            return matched.isEmpty ? nil : (section, matched)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BTLibrarySearchBar(placeholder: "搜索练习", text: $searchText) {
                topicFilterMenu
            }
            mainContent
        }
        .background { BTBlueprintBackground(style: .practice).ignoresSafeArea() }
        .sheet(isPresented: $showSubscription, onDismiss: {
            defer { pendingSeparationRoute = nil }
            if let route = pendingSeparationRoute,
               subscriptionManager.accessDecision(requiresPremium: true) == .allowed {
                router.anglePath.append(route)
            }
        }) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
    }

    /// 主题筛选 Menu（v34：与动作库 `libraryFilterMenu` 同视觉——44pt 图标 + 激活徽标）。
    private var topicFilterMenu: some View {
        Menu {
            Section("主题") {
                Button {
                    withAnimation(BTMotion.easeFast) {
                        selectedTopic = nil
                    }
                } label: {
                    if selectedTopic == nil {
                        Label("全部", systemImage: "checkmark")
                    } else {
                        Text("全部")
                    }
                }
                ForEach(PracticeTopic.allCases) { topic in
                    Button {
                        withAnimation(BTMotion.easeFast) {
                            selectedTopic = topic
                        }
                    } label: {
                        if selectedTopic == topic {
                            Label(topic.rawValue, systemImage: "checkmark")
                        } else {
                            Text(topic.rawValue)
                        }
                    }
                    .accessibilityIdentifier("practiceTopicMenu_\(topic.rawValue)")
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: BTIcon.filter)
                    .font(.btBody)
                    .foregroundStyle(selectedTopic != nil ? Color.btPrimary : Color.btTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(selectedTopic != nil ? Color.btPrimaryMuted : Color.btBGTertiary)
                    )
                    .contentShape(Rectangle())

                if selectedTopic != nil {
                    Text("1")
                        .font(.btCaption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.btPrimary, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityIdentifier("practiceTopicFilterMenu")
        .accessibilityLabel(
            selectedTopic.map { "筛选主题，已选 \($0.rawValue)" } ?? "筛选主题"
        )
    }

    // MARK: - Main Content (Sidebar + Grid)

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 0) {
            sectionSidebar
            entryGrid(columns: gridColumns)
        }
    }

    // MARK: - Section Sidebar

    private var sectionSidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                sidebarItem(
                    label: "全部",
                    icon: "square.grid.2x2",
                    filledIcon: "square.grid.2x2.fill",
                    isSelected: selectedSection == nil
                ) {
                    selectedSection = nil
                    scrollToken &+= 1
                }

                ForEach(PracticeSection.allCases) { section in
                    sidebarItem(
                        label: section.rawValue,
                        icon: section.icon,
                        filledIcon: section.filledIcon,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                        scrollToken &+= 1
                    }
                }
            }
        }
        .frame(width: 76)
        .background(Color.btBGSecondary)
    }

    private func sidebarItem(
        label: String,
        icon: String,
        filledIcon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: isSelected ? filledIcon : icon)
                    .font(.btSubheadline)
                    .foregroundStyle(isSelected ? .btPrimary : .btTextSecondary)
                    .frame(height: 22)

                Text(label)
                    .font(isSelected ? .btCaption.weight(.semibold) : .btCaption)
                    .foregroundStyle(isSelected ? .btPrimary : .btTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isSelected ? Color.btBG : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(Color.btPrimary)
                        .frame(width: 3)
                }
            }
        }
        .buttonStyle(BTPressableStyle.row)
        // iOS 17 在 Accessibility 最大字号下会把 Button 的 AX frame 收缩到
        // 图标 + 文本联合区；外层也锁定 60pt，保证语义命中区不小于 44pt。
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        // 沿用 P18 B1 的分段定位标识，UI 测试（P5 / ScreenshotTour）无需改选择器。
        .accessibilityIdentifier("angleHomeTab_\(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Entry Grid

    @ViewBuilder
    private func entryGrid(columns: [GridItem]) -> some View {
        if visibleGroups.isEmpty {
            searchEmptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                        ForEach(visibleGroups, id: \.section) { group in
                            Section {
                                LazyVGrid(columns: columns, spacing: Spacing.md) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        Button {
                                            open(entry)
                                        } label: {
                                            AngleGridCard(entry: entry, sequenceNumber: index + 1, isUnlocked: subscriptionManager.isPremium)
                                        }
                                        .buttonStyle(BTPressableStyle.row)
                                        // 卡片按钮会合并子元素 AX 标签，UI 测试需用 identifier 精确定位。
                                        .accessibilityIdentifier(entry.title)
                                        .accessibilityLabel("\(entry.title)，\(entry.difficulty.accessibilityLabel)，\(entry.subtitle)")
                                        .accessibilityValue(entry.accessibilityContext(isUnlocked: subscriptionManager.isPremium))
                                    }
                                }
                                .padding(.horizontal, Spacing.md)
                            } header: {
                                sectionHeader(group.section)
                                    .id(group.section)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xxxxl)
                }
                // React to the rendered results, including search/topic changes.
                .onChange(of: visibleGroups.flatMap { $0.entries.map(\.id) }) { _, _ in
                    if let first = visibleGroups.first {
                        proxy.scrollTo(first.section, anchor: .top)
                    }
                }
            }
            // A lazy pinned header may not exist at the old offset after switching sections.
            // Start the content pane at its natural top, leaving the sidebar and search intact.
            .id(scrollToken)
        }
    }

    private func open(_ entry: AngleEntry) {
        let decision = subscriptionManager.accessDecision(requiresPremium: entry.route.requiresPremium)
        guard decision != .requiresLogin && decision != .requiresPro else {
            pendingSeparationRoute = (entry.route == .separationPractice3D || entry.route == .twoBallPractice3D || entry.route == .threeBallPractice3D || entry.route == .multiBallPractice3D) ? entry.route : nil
            showSubscription = true
            return
        }
        router.anglePath.append(entry.route)
    }

    private var searchEmptyState: some View {
        BTEmptyState(
            icon: searchText.isEmpty ? "line.3.horizontal.decrease" : "magnifyingglass",
            title: "没有找到相关练习",
            subtitle: searchText.isEmpty ? "试试其他主题或浏览分类" : "试试其他关键词或浏览分类",
            actionTitle: "浏览全部练习",
            action: {
                searchText = ""
                selectedTopic = nil
            }
        )
        .frame(maxHeight: .infinity)
    }

    private func sectionHeader(_ section: PracticeSection) -> some View {
        BTLibrarySectionHeader(
            systemImage: section.filledIcon,
            title: section.rawValue,
            caption: section.caption
        )
    }
}

// MARK: - Grid Card（v28 shared shell + v45 atmosphere + existing palette wash）

private struct AngleGridCard: View {
    let entry: AngleEntry
    let sequenceNumber: Int
    let isUnlocked: Bool

    var body: some View {
        BTContentGridCard(
            title: entry.title,
            coverAspectRatio: 4.0 / 3.0,
            titleLineLimit: 2
        ) {
            coverArea
        } meta: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 0) {
                    if let count = entry.difficulty.starCount {
                        Text(String(repeating: "★", count: count))
                            .foregroundStyle(Color.btPrimary)
                        if count < 5 {
                            Text(String(repeating: "☆", count: 5 - count))
                        }
                    } else if let label = entry.difficulty.usageLabel {
                        Text(label)
                    }
                }
                .fixedSize()
                .font(.btCaption2)
                .foregroundStyle(Color.btTextSecondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.difficulty.accessibilityLabel)

                Text(entry.subtitle)
                    .font(.btCaption)
                    .foregroundStyle(Color.btTextSecondary)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var coverArea: some View {
        let cover = AtmosphereCatalog.cover(for: entry.route)

        return BTAtmosphereLayer(
            image: cover.image,
            pair: entry.palette,
            crop: .list,
            showsColorWash: false,
            showsNeutralScrim: true
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: BTRadius.md,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: BTRadius.md
            )
        )
        .overlay(alignment: .topTrailing) {
            if entry.isPremium {
                BTProBadge(isUnlocked: isUnlocked)
                    .padding(Spacing.sm)
            }
        }
        .overlay(alignment: .topLeading) {
            Text(String(format: "%02d", sequenceNumber))
                .font(.btSubheadlineSemibold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btTablePocket.opacity(0.32), in: RoundedRectangle(cornerRadius: BTRadius.xs))
                .padding(Spacing.sm)
        }
        .overlay(alignment: .bottomTrailing) {
            PracticeContentBadge(kind: entry.contentKind)
                .padding(Spacing.sm)
        }
    }
}

/// DR-387: the approved compact, non-interactive cover badge.
private struct PracticeContentBadge: View {
    let kind: PracticeContentKind

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if kind == .striking {
                BTTrainingIcon(size: 14, filled: true, asTemplate: true)
            } else {
                PracticeContentGlyph(kind: kind)
                    .stroke(style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round))
                    .frame(width: 14, height: 14)
            }
            Text(kind.rawValue)
                .font(.btCaption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color.btPracticeBadgeForeground)
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(Color.btPracticeBadgeBackground, in: RoundedRectangle(cornerRadius: BTRadius.xs))
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.rawValue)
    }
}

/// Vector paths from the approved badge preview, in a 24 × 24 design space.
private struct PracticeContentGlyph: Shape {
    let kind: PracticeContentKind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        switch kind {
        case .reading:
            path.move(to: CGPoint(x: 12, y: 5.5))
            path.addCurve(to: CGPoint(x: 3, y: 4.5), control1: CGPoint(x: 9, y: 3.5), control2: CGPoint(x: 5.5, y: 3.5))
            path.addLine(to: CGPoint(x: 3, y: 18.5))
            path.addCurve(to: CGPoint(x: 12, y: 19.5), control1: CGPoint(x: 6, y: 17.5), control2: CGPoint(x: 9, y: 17.5))
            path.addCurve(to: CGPoint(x: 21, y: 18.5), control1: CGPoint(x: 15, y: 17.5), control2: CGPoint(x: 18, y: 17.5))
            path.addLine(to: CGPoint(x: 21, y: 4.5))
            path.addCurve(to: CGPoint(x: 12, y: 5.5), control1: CGPoint(x: 18.5, y: 3.5), control2: CGPoint(x: 15, y: 3.5))
            path.closeSubpath()
            line([CGPoint(x: 12, y: 5.5), CGPoint(x: 12, y: 19.5)])
        case .quiz:
            path.addRoundedRect(in: CGRect(x: 4, y: 3, width: 16, height: 18), cornerSize: CGSize(width: 2, height: 2))
            for y: CGFloat in [8, 14] {
                line([CGPoint(x: 7, y: y), CGPoint(x: 8, y: y + 1), CGPoint(x: 10, y: y - 1)])
                line([CGPoint(x: 13, y: y), CGPoint(x: 17, y: y)])
            }
        case .interactive:
            line([CGPoint(x: 12, y: 3), CGPoint(x: 12, y: 21)])
            line([CGPoint(x: 3, y: 12), CGPoint(x: 21, y: 12)])
            line([CGPoint(x: 9, y: 6), CGPoint(x: 12, y: 3), CGPoint(x: 15, y: 6)])
            line([CGPoint(x: 9, y: 18), CGPoint(x: 12, y: 21), CGPoint(x: 15, y: 18)])
            line([CGPoint(x: 6, y: 9), CGPoint(x: 3, y: 12), CGPoint(x: 6, y: 15)])
            line([CGPoint(x: 18, y: 9), CGPoint(x: 21, y: 12), CGPoint(x: 18, y: 15)])
        case .striking:
            break // Uses the existing BTTrainingIcon above.
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}

#Preview("Practice badges · Light") {
    HStack { ForEach(PracticeContentKind.allCases, id: \.self) { PracticeContentBadge(kind: $0) } }
        .padding().background(Color.btBG).preferredColorScheme(.light)
}

#Preview("Practice badges · Dark") {
    HStack { ForEach(PracticeContentKind.allCases, id: \.self) { PracticeContentBadge(kind: $0) } }
        .padding().background(Color.btBG).preferredColorScheme(.dark)
}

// MARK: - Learn → Practice CTA（T-P18-51 学→练导流，设计稿 §3.1/§5-10）

/// 学页页末导流卡：把「刚学的概念」接到「能练它的页面」。
/// 走 `NavigationLink(value: AngleRoute)`，复用练习 Tab 根部的 navigationDestination。
struct PracticeCTA: View {
    let title: String
    let destination: String
    let route: AngleRoute
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "figure.walk.arrival")
                    .font(.btTitle.weight(.semibold))
                    .foregroundStyle(Color.btPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.btPrimaryMuted, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.btHeadline)
                        .foregroundStyle(.btText)
                    Text(destination)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                }
                Spacer()
                Image(systemName: BTIcon.chevronRight)
                    .font(.btFootnote.weight(.semibold))
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(Spacing.lg)
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.lg)
                    // F-AK-12：弱化导流卡描边，保留 NavigationLink。
                    .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 1)
            )
        }
        .buttonStyle(BTPressableStyle.row)
        .accessibilityLabel(title)
    }
}

// MARK: - Preview

#Preview("Light") {
    NavigationStack {
        AngleHomeView()
    }
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Dark") {
    NavigationStack {
        AngleHomeView()
    }
    .environmentObject(SubscriptionManager.shared)
    .preferredColorScheme(.dark)
}
