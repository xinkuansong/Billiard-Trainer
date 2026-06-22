import SwiftUI

// MARK: - Angle Navigation

enum AngleRoute: Hashable {
    case contactPointTable
    case aimingPrinciple
    case angleDynamic
    case geometricQuiz
    case scene2DAiming
    case scene3DAiming
    case ballFeel
    case bankShot
    case diamondSystem
    case shotSimulation
    case positionPlayComposer
    case positionPlaySolver
    case planThree
    case snookerTactics
    case ballExtraction
    case rackGenerator
    /// 批量出片台（仅模拟器，内容生产工具）。
    case batchDrillStudio
}

// MARK: - Entry Model

private struct AngleEntry: Identifiable {
    let id = UUID()
    let route: AngleRoute
    /// 海报封面大字水印（纯排版封面，与训练计划 `BTPlanCover` 同语言）。
    let glyph: String
    let title: String
    let subtitle: String
    let coverTop: Color
    let coverBottom: Color
    var chip: String? = nil
}

// MARK: - Home View

/// 角度 Tab 首页（ADR-P11-08）：与「训练」首页同一套设计语言——
/// 大标题 + 分段 Tab（学习 / 训练 / 工具）+ 双列「杂志封面」海报卡
///（饱和渐变 + 超大字水印 + 底部标题），每个分段一屏内可达，无需长滚动。
struct AngleHomeView: View {
    private enum HomeTab: String, CaseIterable {
        case learn = "学习"
        case train = "训练"
        case tools = "工具"
    }

    @State private var selectedTab: HomeTab = .learn

    private let learnEntries: [AngleEntry] = [
        .init(route: .aimingPrinciple, glyph: "瞄",
              title: "瞄准原理", subtitle: "切入角 · 假想球 · 厚薄球",
              coverTop: Color(red: 0.16, green: 0.55, blue: 0.34),
              coverBottom: Color(red: 0.09, green: 0.34, blue: 0.21)),
        .init(route: .angleDynamic, glyph: "打",
              title: "角度与打点", subtitle: "角度 / 接触点动态关系",
              coverTop: Color(red: 0.11, green: 0.46, blue: 0.95),
              coverBottom: Color(red: 0.05, green: 0.24, blue: 0.58)),
        .init(route: .ballFeel, glyph: "感",
              title: "浅谈球感", subtitle: "从理性分析到直觉判断",
              coverTop: Color(red: 0.48, green: 0.36, blue: 0.72),
              coverBottom: Color(red: 0.28, green: 0.20, blue: 0.46)),
        .init(route: .contactPointTable, glyph: "表",
              title: "进球点对照表", subtitle: "角度与接触点对照",
              coverTop: Color(red: 0.42, green: 0.45, blue: 0.50),
              coverBottom: Color(red: 0.24, green: 0.26, blue: 0.30))
    ]

    private let trainEntries: [AngleEntry] = [
        .init(route: .geometricQuiz, glyph: "角",
              title: "几何角度训练", subtitle: "纯几何角度预测练习",
              coverTop: Color(red: 0.85, green: 0.52, blue: 0.13),
              coverBottom: Color(red: 0.55, green: 0.32, blue: 0.05)),
        .init(route: .scene2DAiming, glyph: "2D",
              title: "2D 瞄准训练", subtitle: "俯视球台角度预测",
              coverTop: Color(red: 0.0, green: 0.60, blue: 0.60),
              coverBottom: Color(red: 0.0, green: 0.36, blue: 0.40), chip: "2D"),
        .init(route: .scene3DAiming, glyph: "3D",
              title: "3D 瞄准训练", subtitle: "3D 视角角度预测",
              coverTop: Color(red: 0.30, green: 0.34, blue: 0.78),
              coverBottom: Color(red: 0.16, green: 0.18, blue: 0.48), chip: "3D")
    ]

    private var toolEntries: [AngleEntry] {
        var entries = baseToolEntries
        #if targetEnvironment(simulator)
        // 仅模拟器：批量出片台（内容生产工具，真机/发布版不可见）。
        entries.append(.init(route: .batchDrillStudio, glyph: "批",
                             title: "批量出片台", subtitle: "drill 截图 → 序列 → 素材",
                             coverTop: Color(red: 0.20, green: 0.40, blue: 0.70),
                             coverBottom: Color(red: 0.10, green: 0.22, blue: 0.42), chip: "SIM"))
        #endif
        return entries
    }

    private let baseToolEntries: [AngleEntry] = [
        .init(route: .bankShot, glyph: "翻",
              title: "翻袋解球器", subtitle: "自动求 1–3 库翻袋路线",
              coverTop: Color(red: 0.62, green: 0.14, blue: 0.14),
              coverBottom: Color(red: 0.36, green: 0.06, blue: 0.06), chip: "2D"),
        .init(route: .diamondSystem, glyph: "反",
              title: "反射解球器", subtitle: "自动求 1–多库反射路线",
              coverTop: Color(red: 0.0, green: 0.45, blue: 0.55),
              coverBottom: Color(red: 0.0, green: 0.26, blue: 0.34), chip: "2D"),
        .init(route: .shotSimulation, glyph: "分",
              title: "分离角与走位", subtitle: "物理引擎模拟分离角与走位",
              coverTop: Color(red: 0.13, green: 0.55, blue: 0.36),
              coverBottom: Color(red: 0.06, green: 0.33, blue: 0.20), chip: "物理"),
        .init(route: .positionPlayComposer, glyph: "走",
              title: "走位编排台", subtitle: "自由摆球 · 连续击打推演",
              coverTop: Color(red: 0.72, green: 0.55, blue: 0.13),
              coverBottom: Color(red: 0.45, green: 0.33, blue: 0.05), chip: "物理"),
        .init(route: .positionPlaySolver, glyph: "思",
              title: "思路训练器", subtitle: "反解走位 · 塞与力度求解",
              coverTop: Color(red: 0.50, green: 0.20, blue: 0.62),
              coverBottom: Color(red: 0.28, green: 0.10, blue: 0.40), chip: "物理"),
        .init(route: .planThree, glyph: "三",
              title: "打一走二想三", subtitle: "连续走位规划 · 停球扇形提示",
              coverTop: Color(red: 0.16, green: 0.46, blue: 0.62),
              coverBottom: Color(red: 0.08, green: 0.26, blue: 0.38), chip: "走位"),
        .init(route: .snookerTactics, glyph: "斯",
              title: "做斯诺克", subtitle: "安全球反解 · 障碍遮挡做杆",
              coverTop: Color(red: 0.60, green: 0.10, blue: 0.30),
              coverBottom: Color(red: 0.34, green: 0.04, blue: 0.16), chip: "物理"),
        .init(route: .ballExtraction, glyph: "拍",
              title: "拍照建球形", subtitle: "照片提取球号与位置",
              coverTop: Color(red: 0.16, green: 0.50, blue: 0.62),
              coverBottom: Color(red: 0.07, green: 0.28, blue: 0.36), chip: "识别"),
        .init(route: .rackGenerator, glyph: "开",
              title: "球形生成器", subtitle: "中八 / 9 球开球 · 真实物理散开",
              coverTop: Color(red: 0.78, green: 0.30, blue: 0.10),
              coverBottom: Color(red: 0.48, green: 0.16, blue: 0.04), chip: "物理")
    ]

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            BTSegmentedTab(
                tabs: HomeTab.allCases,
                selected: $selectedTab,
                label: { $0.rawValue },
                accessibilityIdentifierPrefix: "angleHomeTab"
            )
            .padding(.horizontal, Spacing.lg)

            Divider().foregroundStyle(.btSeparator)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    sectionCaption
                    posterGrid(entries(for: selectedTab))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .background(.btBG)
    }

    private var pageHeader: some View {
        HStack {
            Text("角度")
                .font(.btLargeTitle)
                .foregroundStyle(.btText)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private func entries(for tab: HomeTab) -> [AngleEntry] {
        switch tab {
        case .learn: learnEntries
        case .train: trainEntries
        case .tools: toolEntries
        }
    }

    private var sectionCaption: some View {
        Text(captionText)
            .font(.btCaption)
            .foregroundStyle(.btTextSecondary)
    }

    private var captionText: String {
        switch selectedTab {
        case .learn: "理解瞄准的几何与手感"
        case .train: "每天几分钟，校准你的角度直觉"
        case .tools: "实战解球与走位推演工具"
        }
    }

    private func posterGrid(_ entries: [AngleEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md),
                            GridItem(.flexible(), spacing: Spacing.md)],
                  spacing: Spacing.md) {
            ForEach(entries) { entry in
                NavigationLink(value: entry.route) {
                    AnglePosterCard(entry: entry)
                }
                .buttonStyle(.plain)
                // 卡片按钮会合并子元素 AX 标签，UI 测试需用 identifier 精确定位。
                .accessibilityIdentifier(entry.title)
            }
        }
    }
}

// MARK: - Poster Card（与训练计划海报同语言：渐变封面 + 大字水印 + 底部标题）

private struct AnglePosterCard: View {
    let entry: AngleEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [entry.coverTop, entry.coverBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(entry.glyph)
                .font(.system(size: 76, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.16))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(Spacing.md)

            if let chip = entry.chip {
                VStack {
                    HStack {
                        Spacer()
                        Text(chip)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
            }
        }
        .aspectRatio(0.92, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
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
