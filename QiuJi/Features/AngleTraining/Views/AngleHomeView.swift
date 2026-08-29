import SwiftUI

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
    case angleDynamic
    case geometricQuiz
    /// 2D 瞄准训练（T-P18-48 拆两卡）：俯视练几何判断。
    case sceneAiming2D
    /// 3D 瞄准训练（T-P18-48 拆两卡）：站位视角练临场球感。
    case sceneAiming3D
    /// 瞄准点训练（条 8）：给角度拖假想球，mm 误差反馈。
    case aimPointTraining
    /// 2D 瞄准点训练（条 9）：真台出题，瞄准线微调 + 自动击球验证。
    case aimPointScene2D
    /// 3D 瞄准点训练（条 10）：站位相机版。
    case aimPointScene3D
    case ballFeel
    case bankShot
    case diamondSystem
    case shotSimulation
    case positionPlayComposer
    /// 自由击球（ADR-P18-01）：编排台自由瞄准模式直达入口；B2 补齐手动瞄准 UI 后成为完整形态。
    case freePlay
    case positionPlaySolver
    case planThree
    case snookerTactics
    case ballExtraction
    /// 批量出片台（仅模拟器，内容生产工具）。
    case batchDrillStudio
    /// 学区 CTA → 动作库 drill 详情（v21 W5；练习 Tab 内嵌 DrillDetailView）。
    case drillDetail(String)
}

// MARK: - Topic Filter Model

/// 练习页主题筛选标签（与侧栏「学/理/练/打/解」正交：侧栏按形态分区，主题按内容横切）。
private enum PracticeTopic: String, CaseIterable, Identifiable {
    case accuracy = "准度"
    case english = "加塞"
    case position = "走位"
    case cushion = "吃库"
    case safety = "防守"

    var id: String { rawValue }
}

// MARK: - Entry Model

private struct AngleEntry: Identifiable {
    let id = UUID()
    let route: AngleRoute
    let title: String
    let subtitle: String
    let palette: CoverPalette.Pair
    var isPremium: Bool = false
    /// 主题标签（可多个）；空 = 综合内容，仅在未选主题时出现。
    var topics: Set<PracticeTopic> = []

    init(
        route: AngleRoute,
        title: String,
        subtitle: String,
        isPremium: Bool = false,
        topics: Set<PracticeTopic> = []
    ) {
        self.route = route
        self.title = title
        self.subtitle = subtitle
        self.palette = AtmosphereCatalog.cover(for: route).pair
        self.isPremium = isPremium
        self.topics = topics
    }
}

// MARK: - Section Model（学 / 理 / 练 / 打 / 解，ADR-P18-01 + v32 五分类）

private enum PracticeSection: String, CaseIterable, Identifiable {
    case learn = "学"
    case theory = "理"
    case train = "练"
    case play = "打"
    case solve = "解"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .learn: "book"
        case .theory: "scroll"
        case .train: "target"
        case .play:  "hand.tap"
        case .solve: "lightbulb"
        }
    }

    var filledIcon: String {
        switch self {
        case .learn: "book.fill"
        case .theory: "scroll.fill"
        case .train: "target"
        case .play:  "hand.tap.fill"
        case .solve: "lightbulb.fill"
        }
    }

    var caption: String {
        switch self {
        case .learn: "交互弄懂瞄准、旋转与走位"
        case .theory: "定理、流程与速查：分主题看懂原理"
        case .train: "每天几分钟，校准角度直觉"
        case .play:  "真实物理沙盘，摆球就能打"
        case .solve: "让引擎当教练，反解这杆怎么打"
        }
    }
}

// MARK: - Home View

/// 练习 Tab 首页（ADR-P11-08 / ADR-P18-01 / ADR-P18-03 / v28 / v32 / v45）：与「动作库」同一套布局语言——
/// 母题矮带 + 左侧图标分类侧栏（全部/学/理/练/打/解）+ 右侧双列分组网格（钉住分组头），
/// 卡片外壳保留 v28 `BTContentGridCard`，封面为 Bundle 静物 + 现网分类色罩。
struct AngleHomeView: View {
    /// nil = 全部（默认，与动作库侧栏一致）。
    @State private var selectedSection: PracticeSection? = nil
    @State private var searchText = ""
    /// nil = 不按主题筛选（v34：与动作库搜索栏同款筛选 Menu）。
    @State private var selectedTopic: PracticeTopic? = nil
    @State private var showSubscription = false
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    /// 「学」——交互/文档学页（v32：球理入口已迁至「理」区）。
    private let learnEntries: [AngleEntry] = [
        .init(route: .aimingPrinciple, title: "瞄准原理", subtitle: "切入角 · 假想球 · 厚薄球", topics: [.accuracy]),
        .init(route: .aimingMethods, title: "瞄准方法", subtitle: "管道 · 接触点 · 平行线", topics: [.accuracy]),
        .init(route: .aimingCorrection, title: "瞄准修正", subtitle: "投掷 · 塞偏 · 弧线：几何之外的偏差", topics: [.accuracy, .english]),
        .init(route: .spinAndEnglish, title: "旋转与加塞", subtitle: "滑动 · 前旋后旋 · 分离角", topics: [.english, .position]),
        .init(route: .angleDynamic, title: "角度与瞄准", subtitle: "切角变化如何影响打点", topics: [.accuracy]),
        .init(route: .separationAngleAtlas, title: "分离角图谱", subtitle: "高低杆 · 碰后轨迹 · 力度", isPremium: true, topics: [.position]),
        .init(route: .cushionEnglishAtlas, title: "加塞吃库图谱", subtitle: "高低杆 · 左右塞 · 吃库后出射", isPremium: true, topics: [.english, .cushion]),
        .init(route: .ballFeel, title: "浅谈球感", subtitle: "从理性分析到直觉判断", topics: [.accuracy]),
        .init(route: .contactPointTable, title: "瞄准点对照表", subtitle: "常用角度的瞄准点速查", topics: [.accuracy]),
    ]

    /// 「理」——16 理论体系（v32.2：每篇一卡直达详情；索引页仅深链可达，首页不再放「球理」总卡）。
    private var theoryEntries: [AngleEntry] {
        TheoryCatalog.entries
            .filter(\.isPublished)
            .map { entry in
                AngleEntry(
                    route: .theoryPage(entry.id),
                    title: entry.title,
                    subtitle: entry.subtitle,
                    topics: Self.theoryTopics(for: entry.id)
                )
            }
    }

    /// 理区逐页映射主题（流程/速查为综合内容，不挂主题）。
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

    /// 「练」——测验类：练角度直觉。
    private let trainEntries: [AngleEntry] = [
        .init(route: .geometricQuiz, title: "角度预测", subtitle: "看球形，估切角，练直觉", topics: [.accuracy]),
        .init(route: .sceneAiming2D, title: "2D 角度训练", subtitle: "俯视真台，练几何角度判断", topics: [.accuracy]),
        .init(route: .sceneAiming3D, title: "3D 角度训练", subtitle: "站位视角，练临场球感", isPremium: true, topics: [.accuracy]),
        .init(route: .aimPointTraining, title: "瞄准点训练", subtitle: "给角度拖假想球，毫米级误差", topics: [.accuracy]),
        .init(route: .aimPointScene2D, title: "2D 瞄准点训练", subtitle: "微调瞄准线选打点，击球验证", topics: [.accuracy]),
        .init(route: .aimPointScene3D, title: "3D 瞄准点训练", subtitle: "站位视角微调打点，击球验证", isPremium: true, topics: [.accuracy]),
    ]

    /// 「打」——沙盘类：摆球、击打、看真实物理结果。
    private var playEntries: [AngleEntry] {
        var entries = basePlayEntries
        #if targetEnvironment(simulator)
        // 仅模拟器：批量出片台（内容生产工具，真机/发布版不可见，不进正式 IA）。
        entries.append(.init(
            route: .batchDrillStudio,
            title: "批量出片台",
            subtitle: "drill 截图 → 序列 → 素材"
        ))
        #endif
        return entries
    }

    /// P11.1：入口顺序 = 分离角与走位、自由走位、自由击球、拍照建球形（、批量出片台）。
    private let basePlayEntries: [AngleEntry] = [
        .init(route: .shotSimulation, title: "分离角与走位", subtitle: "教学演示：看懂碰撞后母球走向", topics: [.position, .english]),
        .init(route: .positionPlayComposer, title: "自由走位", subtitle: "逐杆编排击打，推演整套走位", isPremium: true, topics: [.position, .english]),
        .init(route: .freePlay, title: "自由击球", subtitle: "开球散局起手，完整对局体验"),
        .init(route: .ballExtraction, title: "拍照建球形", subtitle: "拍下真实球局，导入沙盘复盘", isPremium: true),
    ]

    /// 「解」——教练类：给定局面，让引擎反解怎么打。
    private let solveEntries: [AngleEntry] = [
        .init(route: .positionPlaySolver, title: "思路训练", subtitle: "单杆走位反解：定落点，解塞与力度", topics: [.position, .english]),
        .init(route: .planThree, title: "打一走二想三", subtitle: "三杆连续走位规划，练全局思路", isPremium: true, topics: [.position]),
        .init(route: .snookerTactics, title: "防守", subtitle: "反解安全球：让对方球组看不到或只剩难球", isPremium: true, topics: [.safety]),
        .init(route: .bankShot, title: "翻袋解球器", subtitle: "目标球翻库进袋：求 1–3 库路线", topics: [.cushion, .accuracy]),
        .init(route: .diamondSystem, title: "反射解球器", subtitle: "母球吃库绕障碍碰球的路线", topics: [.cushion]),
    ]

    private func entries(for section: PracticeSection) -> [AngleEntry] {
        switch section {
        case .learn: learnEntries
        case .theory: theoryEntries
        case .train: trainEntries
        case .play: playEntries
        case .solve: solveEntries
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
        .background(.btBG)
        .sheet(isPresented: $showSubscription) {
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
            entryGrid
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
                }

                ForEach(PracticeSection.allCases) { section in
                    sidebarItem(
                        label: section.rawValue,
                        icon: section.icon,
                        filledIcon: section.filledIcon,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
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
        // 沿用 P18 B1 的分段定位标识，UI 测试（P5 / ScreenshotTour）无需改选择器。
        .accessibilityIdentifier("angleHomeTab_\(label)")
    }

    // MARK: - Entry Grid

    @ViewBuilder
    private var entryGrid: some View {
        if visibleGroups.isEmpty {
            searchEmptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.xl, pinnedViews: [.sectionHeaders]) {
                    ForEach(visibleGroups, id: \.section) { group in
                        Section {
                            LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                                ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                    Button {
                                        open(entry)
                                    } label: {
                                        AngleGridCard(entry: entry, sequenceNumber: index + 1)
                                    }
                                    .buttonStyle(BTPressableStyle.row)
                                    // 卡片按钮会合并子元素 AX 标签，UI 测试需用 identifier 精确定位。
                                    .accessibilityIdentifier(entry.title)
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        } header: {
                            sectionHeader(group.section)
                        }
                    }
                }
                .padding(.bottom, Spacing.xxxxl)
            }
        }
    }

    private func open(_ entry: AngleEntry) {
        guard !entry.isPremium || subscriptionManager.isPremium else {
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

    var body: some View {
        BTContentGridCard(
            title: entry.title,
            subtitle: entry.subtitle,
            coverAspectRatio: 4.0 / 3.0
        ) {
            coverArea
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
                BTProBadge()
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
    }
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
