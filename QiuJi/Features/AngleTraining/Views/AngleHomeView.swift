import SwiftUI

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
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
    /// 加塞吃库图谱（v20 W2）：中杆 × 8 档左右塞 × 吃库后出射扇形。
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

// MARK: - Entry Model

private struct AngleEntry: Identifiable {
    let id = UUID()
    let route: AngleRoute
    /// 封面大字水印（纯排版封面，与训练计划 `BTPlanCover` 同语言）。
    let glyph: String
    let title: String
    let subtitle: String
    let coverTop: Color
    let coverBottom: Color
    var chip: String? = nil
}

// MARK: - Section Model（学 / 练 / 打 / 解，ADR-P18-01 四分类）

private enum PracticeSection: String, CaseIterable, Identifiable {
    case learn = "学"
    case train = "练"
    case play = "打"
    case solve = "解"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .learn: "book"
        case .train: "target"
        case .play:  "hand.tap"
        case .solve: "lightbulb"
        }
    }

    var filledIcon: String {
        switch self {
        case .learn: "book.fill"
        case .train: "target"
        case .play:  "hand.tap.fill"
        case .solve: "lightbulb.fill"
        }
    }

    var caption: String {
        switch self {
        case .learn: "理解瞄准与走位背后的球理"
        case .train: "每天几分钟，校准角度直觉"
        case .play:  "真实物理沙盘，摆球就能打"
        case .solve: "让引擎当教练，反解这杆怎么打"
        }
    }
}

// MARK: - Home View

/// 练习 Tab 首页（ADR-P11-08 / ADR-P18-01 / ADR-P18-03）：与「动作库」同一套布局语言——
/// 大标题 + 左侧图标分类侧栏（全部/学/练/打/解）+ 右侧双列分组网格（钉住分组头），
/// 卡片对齐 `BTDrillGridCard` 的上图下文样式（封面区保留渐变大字水印海报语言）。
struct AngleHomeView: View {
    /// nil = 全部（默认，与动作库侧栏一致）。
    @State private var selectedSection: PracticeSection? = nil
    @State private var searchText = ""

    @Environment(\.colorScheme) private var colorScheme

    private let gridColumns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    /// 「学」——球理与瞄准知识（P12 阶段 2 将升级为球理中心索引）。
    private let learnEntries: [AngleEntry] = [
        .init(route: .aimingPrinciple, glyph: "瞄",
              title: "瞄准原理", subtitle: "切入角 · 假想球 · 厚薄球",
              coverTop: AngleCoverPalette.aimingPrinciple.top,
              coverBottom: AngleCoverPalette.aimingPrinciple.bottom),
        .init(route: .aimingMethods, glyph: "法",
              title: "瞄准方法", subtitle: "管道 · 接触点 · 平行线",
              coverTop: AngleCoverPalette.aimingMethods.top,
              coverBottom: AngleCoverPalette.aimingMethods.bottom),
        .init(route: .aimingCorrection, glyph: "偏",
              title: "瞄准修正", subtitle: "投掷 · 塞偏 · 弧线：几何之外的偏差",
              coverTop: AngleCoverPalette.aimingCorrection.top,
              coverBottom: AngleCoverPalette.aimingCorrection.bottom),
        .init(route: .spinAndEnglish, glyph: "旋",
              title: "旋转与加塞", subtitle: "滑动 · 前旋后旋 · 分离角",
              coverTop: AngleCoverPalette.spinAndEnglish.top,
              coverBottom: AngleCoverPalette.spinAndEnglish.bottom),
        .init(route: .angleDynamic, glyph: "点",
              title: "角度与瞄准", subtitle: "切角变化如何影响打点",
              coverTop: AngleCoverPalette.angleDynamic.top,
              coverBottom: AngleCoverPalette.angleDynamic.bottom),
        .init(route: .separationAngleAtlas, glyph: "谱",
              title: "分离角图谱", subtitle: "高低杆 · 碰后轨迹 · 力度",
              coverTop: AngleCoverPalette.separationAngleAtlas.top,
              coverBottom: AngleCoverPalette.separationAngleAtlas.bottom),
        .init(route: .cushionEnglishAtlas, glyph: "塞",
              title: "加塞吃库图谱", subtitle: "中杆 · 左右塞 · 吃库后出射",
              coverTop: AngleCoverPalette.cushionEnglishAtlas.top,
              coverBottom: AngleCoverPalette.cushionEnglishAtlas.bottom),
        .init(route: .ballFeel, glyph: "感",
              title: "浅谈球感", subtitle: "从理性分析到直觉判断",
              coverTop: AngleCoverPalette.ballFeel.top,
              coverBottom: AngleCoverPalette.ballFeel.bottom),
        .init(route: .contactPointTable, glyph: "表",
              title: "瞄准点对照表", subtitle: "常用角度的瞄准点速查",
              coverTop: AngleCoverPalette.contactPointTable.top,
              coverBottom: AngleCoverPalette.contactPointTable.bottom)
        // 「球理」入口卡（P12 阶段 1 产物）：理论详情页落地后在此追加，
        // 路由预留 —— 详见 ADR-P18-01 / ADR-P12-01。
    ]

    /// 「练」——测验类：练角度直觉。
    private let trainEntries: [AngleEntry] = [
        .init(route: .geometricQuiz, glyph: "角",
              title: "角度预测", subtitle: "看球形，估切角，练直觉",
              coverTop: AngleCoverPalette.geometricQuiz.top,
              coverBottom: AngleCoverPalette.geometricQuiz.bottom),
        .init(route: .sceneAiming2D, glyph: "瞄",
              title: "2D 角度训练", subtitle: "俯视真台，练几何角度判断",
              coverTop: AngleCoverPalette.sceneAiming2D.top,
              coverBottom: AngleCoverPalette.sceneAiming2D.bottom, chip: "2D"),
        .init(route: .sceneAiming3D, glyph: "临",
              title: "3D 角度训练", subtitle: "站位视角，练临场球感",
              coverTop: AngleCoverPalette.sceneAiming3D.top,
              coverBottom: AngleCoverPalette.sceneAiming3D.bottom, chip: "3D"),
        .init(route: .aimPointTraining, glyph: "拖",
              title: "瞄准点训练", subtitle: "给角度拖假想球，毫米级误差",
              coverTop: AngleCoverPalette.aimPointTraining.top,
              coverBottom: AngleCoverPalette.aimPointTraining.bottom),
        .init(route: .aimPointScene2D, glyph: "调",
              title: "2D 瞄准点训练", subtitle: "微调瞄准线选打点，击球验证",
              coverTop: AngleCoverPalette.aimPointScene2D.top,
              coverBottom: AngleCoverPalette.aimPointScene2D.bottom, chip: "2D"),
        .init(route: .aimPointScene3D, glyph: "临",
              title: "3D 瞄准点训练", subtitle: "站位视角微调打点，击球验证",
              coverTop: AngleCoverPalette.aimPointScene3D.top,
              coverBottom: AngleCoverPalette.aimPointScene3D.bottom, chip: "3D")
    ]

    /// 「打」——沙盘类：摆球、击打、看真实物理结果。
    private var playEntries: [AngleEntry] {
        var entries = basePlayEntries
        #if targetEnvironment(simulator)
        // 仅模拟器：批量出片台（内容生产工具，真机/发布版不可见，不进正式 IA）。
        entries.append(.init(route: .batchDrillStudio, glyph: "批",
                             title: "批量出片台", subtitle: "drill 截图 → 序列 → 素材",
                             coverTop: AngleCoverPalette.batchDrillStudio.top,
                             coverBottom: AngleCoverPalette.batchDrillStudio.bottom, chip: "SIM"))
        #endif
        return entries
    }

    /// P11.1：入口顺序 = 分离角与走位、自由走位、自由击球、拍照建球形（、批量出片台）。
    private let basePlayEntries: [AngleEntry] = [
        .init(route: .shotSimulation, glyph: "分",
              title: "分离角与走位", subtitle: "教学演示：看懂碰撞后母球走向",
              coverTop: AngleCoverPalette.shotSimulation.top,
              coverBottom: AngleCoverPalette.shotSimulation.bottom, chip: "物理"),
        .init(route: .positionPlayComposer, glyph: "走",
              title: "自由走位", subtitle: "逐杆编排击打，推演整套走位",
              coverTop: AngleCoverPalette.positionPlayComposer.top,
              coverBottom: AngleCoverPalette.positionPlayComposer.bottom, chip: "物理"),
        .init(route: .freePlay, glyph: "击",
              title: "自由击球", subtitle: "开球散局起手，完整对局体验",
              coverTop: AngleCoverPalette.freePlay.top,
              coverBottom: AngleCoverPalette.freePlay.bottom, chip: "物理"),
        .init(route: .ballExtraction, glyph: "拍",
              title: "拍照建球形", subtitle: "拍下真实球局，导入沙盘复盘",
              coverTop: AngleCoverPalette.ballExtraction.top,
              coverBottom: AngleCoverPalette.ballExtraction.bottom, chip: "识别")
    ]

    /// 「解」——教练类：给定局面，让引擎反解怎么打。
    private let solveEntries: [AngleEntry] = [
        .init(route: .positionPlaySolver, glyph: "思",
              title: "思路训练", subtitle: "单杆走位反解：定落点，解塞与力度",
              coverTop: AngleCoverPalette.positionPlaySolver.top,
              coverBottom: AngleCoverPalette.positionPlaySolver.bottom, chip: "物理"),
        .init(route: .planThree, glyph: "三",
              title: "打一走二想三", subtitle: "三杆连续走位规划，练全局思路",
              coverTop: AngleCoverPalette.planThree.top,
              coverBottom: AngleCoverPalette.planThree.bottom, chip: "走位"),
        .init(route: .snookerTactics, glyph: "防",
              title: "防守", subtitle: "反解安全球：让对方球组看不到或只剩难球",
              coverTop: AngleCoverPalette.snookerTactics.top,
              coverBottom: AngleCoverPalette.snookerTactics.bottom, chip: "物理"),
        .init(route: .bankShot, glyph: "翻",
              title: "翻袋解球器", subtitle: "目标球翻库进袋：求 1–3 库路线",
              coverTop: AngleCoverPalette.bankShot.top,
              coverBottom: AngleCoverPalette.bankShot.bottom, chip: "2D"),
        .init(route: .diamondSystem, glyph: "反",
              title: "反射解球器", subtitle: "母球吃库绕障碍碰球的路线",
              coverTop: AngleCoverPalette.diamondSystem.top,
              coverBottom: AngleCoverPalette.diamondSystem.bottom, chip: "2D")
    ]

    private func entries(for section: PracticeSection) -> [AngleEntry] {
        switch section {
        case .learn: learnEntries
        case .train: trainEntries
        case .play: playEntries
        case .solve: solveEntries
        }
    }

    private func filteredEntries(for section: PracticeSection) -> [AngleEntry] {
        let all = entries(for: section)
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
            pageHeader
            searchBar
            mainContent
        }
        .background(.btBG)
    }

    private var pageHeader: some View {
        HStack {
            Text("练习")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.btTextTertiary)
            TextField("搜索练习", text: $searchText)
                .font(.btCallout)
                .foregroundStyle(.btText)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.btTextTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.btBGTertiary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
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
                                ForEach(group.entries) { entry in
                                    NavigationLink(value: entry.route) {
                                        AngleGridCard(entry: entry)
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

    private var searchEmptyState: some View {
        BTEmptyState(
            icon: "magnifyingglass",
            title: "没有找到相关练习",
            subtitle: "试试其他关键词或浏览分类",
            actionTitle: "浏览全部练习",
            action: { searchText = "" }
        )
        .frame(maxHeight: .infinity)
    }

    private func sectionHeader(_ section: PracticeSection) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: section.filledIcon)
                .font(.btSubheadline)
                .foregroundStyle(.btPrimary)
            Text(section.rawValue)
                .font(.btTitle2)
                .foregroundStyle(.btText)
            Text(section.caption)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBG)
    }
}

// MARK: - Grid Card（对齐 BTDrillGridCard 的上图下文样式；封面区保留渐变大字水印海报语言）

private struct AngleGridCard: View {
    let entry: AngleEntry

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay { coverArea }
                .clipped()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // K1 (D-v8-1): 去缩排，同页字号恒定 — 标题最多 2 行尾部省略，副标题单行省略
                Text(entry.title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Text(entry.subtitle)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BTRadius.md)
                .stroke(Color.btSeparator, lineWidth: colorScheme == .dark ? 0.5 : 0)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
            radius: 4, x: 0, y: 2
        )
    }

    private var coverArea: some View {
        ZStack {
            LinearGradient(
                colors: [entry.coverTop, entry.coverBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(entry.glyph)
                .font(.btCoverWatermark)
                .foregroundStyle(CoverPalette.Glyph.color(against: entry.coverTop))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: BTRadius.md,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: BTRadius.md
            )
        )
        .overlay(alignment: .topTrailing) {
            if let chip = entry.chip {
                Text(chip)
                    .font(.btMicro.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22), in: Capsule())
                    .padding(Spacing.sm)
            }
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
