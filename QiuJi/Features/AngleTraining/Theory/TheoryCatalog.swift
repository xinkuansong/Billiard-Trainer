import Foundation

// MARK: - Page identity

/// 球理页标识（问题集合 v30 W0）。
///
/// 参数化路由的载荷：`AngleRoute.theoryPage(TheoryPageID)`——12 篇共用一个 case，
/// 不往 `AngleRoute` 塞 12 个裸 case。
/// `rawValue` 同时是页面标识与数据标签（红线：编号不进用户可见正文措辞）。
enum TheoryPageID: String, Hashable, CaseIterable {
    case t01, t02, t03, t04, t05, t06, t07, t08, t09, t10
    /// 清台 5 步决策流程（`run-out-flow.json` 的转写目标，W4）。
    case flow
    /// 速查表（`quick-reference.md` 的转写目标，W4）。
    case quickRef

    /// 定理条目在 vendored `theorem-tags.json` 中的 id（`T01`…`T10`）；
    /// 流程 / 速查表不是定理，返回 nil。
    var theoremId: String? {
        switch self {
        case .flow, .quickRef: nil
        default: rawValue.uppercased()
        }
    }
}

// MARK: - Index grouping

/// 球理索引页分组（v30 W0；W6 归组时把现有 9 张学页混编进同样这四组）。
enum TheoryGroup: String, CaseIterable, Identifiable {
    case collision = "碰撞与瞄准"
    case spin = "旋转与走位"
    case tactics = "战术与决策"
    case flow = "流程与速查"

    var id: String { rawValue }

    var caption: String {
        switch self {
        case .collision: "母球碰到目标球以后会往哪走"
        case .spin: "杆法与力度怎么改变走位"
        case .tactics: "这一杆该打哪颗、该不该打"
        case .flow: "上台以后按什么顺序想，以及一页速查"
        }
    }

    var systemImage: String {
        switch self {
        case .collision: "circle.circle"
        case .spin: "arrow.triangle.2.circlepath"
        case .tactics: "brain.head.profile"
        case .flow: "list.number"
        }
    }
}

// MARK: - Entry

/// 索引页条目（静态数据，非 JSON 驱动——D-v30-1 裁定理论正文硬编码）。
struct TheoryIndexEntry: Identifiable, Hashable {
    let id: TheoryPageID
    let title: String
    /// 一句话副标题。
    ///
    /// 2026-10-16 用户授权核实理论后重写。以核实后的正文为准，不能为保持与旧
    /// vendor 文本一致而继续展示错误条件。旧 contracts 保持原始快照，纠错依据见
    /// `docs/research/20261016-理文章重写与理论核查.md`；测试守适用条件、数值来源和路由。
    let subtitle: String
    /// 练习首页单行卡片使用的行动提示。完整断言仍由 `subtitle` 承担；这里不试图
    /// 把适用条件、数值与推导压进一行，只说明点入后能帮助用户做什么判断。
    let cardSubtitle: String
    let group: TheoryGroup
    /// 详情页是否已在 `MainTabView.theoryDestination` 注册。
    ///
    /// ⚠️ 与 `theoryDestination` 的 switch **成对维护**：W1–W4 每完成一页，
    /// 在那里注册视图并把这里改 `true`。未上线条目在索引页置灰不可点（无死链）。
    let isPublished: Bool
}

/// 球理索引静态目录（12 篇：T01–T10 + 5 步流程 + 速查表）。
enum TheoryCatalog {
    static let entries: [TheoryIndexEntry] = [
        // MARK: 碰撞与瞄准
        .init(
            id: .t01,
            title: "30° 法则",
            subtitle: "到球时自然滚动，约 1/4–3/4 球厚度（切角约 14°–49°），母球碰后稳定方向相对入射方向偏约 30°",
            cardSubtitle: "自然滚动约偏30°",
            group: .collision,
            isPublished: true
        ),
        .init(
            id: .t02,
            title: "90° 法则",
            subtitle: "到球时没有前后旋的斯登击球，理想模型中两球分离角为 90°",
            cardSubtitle: "认清斯登的90°",
            group: .collision,
            isPublished: true
        ),
        .init(
            id: .t03,
            title: "切线法则",
            subtitle: "切线垂直于碰撞时的两球连心线，是理想斯登出射方向的参照；前后旋转会改变后续路线",
            cardSubtitle: "用切线判断碰后路线",
            group: .collision,
            isPublished: true
        ),
        // MARK: 旋转与走位
        .init(
            id: .t04,
            title: "母球速度分级",
            subtitle: "用 9 档建立力度参照，配合稳定的运杆幅度与节奏，再按球形和台况校准",
            cardSubtitle: "练出可重复的力度",
            group: .spin,
            isPublished: true
        ),
        .init(
            id: .t09,
            title: "最少加塞原则",
            subtitle: "加塞先有明确用途，再综合考虑挤偏、弧线和投掷，用足够完成任务的塞量",
            cardSubtitle: "先想清加塞的用途",
            group: .spin,
            isPublished: true
        ),
        // MARK: 战术与决策
        .init(
            id: .t05,
            title: "反向规划",
            subtitle: "从最后一颗球需要的落位区倒推，寻找当前路线与收尾的衔接",
            cardSubtitle: "从最后一颗倒推",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t06,
            title: "关键球原理",
            subtitle: "关键球为最后一颗安排母球位置，前一颗还要为关键球留出合适角度",
            cardSubtitle: "先找收尾关键球",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t07,
            title: "球团管理",
            subtitle: "尽早识别妨碍计划的球团，结合碰球机会、保险球和后续路线选择处理时机",
            cardSubtitle: "选好球团处理时机",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t08,
            title: "风险报酬决策矩阵",
            subtitle: "用三问一起看进球把握、走位把握和失败代价，再比较进攻与防守",
            cardSubtitle: "打前问把握与代价",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t10,
            title: "安全球三维度模型",
            subtitle: "从距离、库位和障碍球检查防守，再看执行把握与对手的应对，不能只按维度数量评质量",
            cardSubtitle: "看距离库位和障碍",
            group: .tactics,
            isPublished: true
        ),
        // MARK: 流程与速查
        .init(
            id: .flow,
            title: "清台 5 步决策流程",
            subtitle: "从上台观察到打完复盘，按顺序检查，并随实际球形调整计划",
            cardSubtitle: "按五步想完这一杆",
            group: .flow,
            isPublished: true
        ),
        .init(
            id: .quickRef,
            title: "清台速查手册",
            subtitle: "快速回看碰撞、控制与战术要点，带着适用条件使用",
            cardSubtitle: "上场前回看判断要点",
            group: .flow,
            isPublished: true
        ),
    ]

    /// 按 `TheoryGroup.allCases` 顺序分组；空组不出现。
    static var groupedEntries: [(group: TheoryGroup, entries: [TheoryIndexEntry])] {
        TheoryGroup.allCases.compactMap { group in
            let matched = entries.filter { $0.group == group }
            return matched.isEmpty ? nil : (group, matched)
        }
    }

    static func entry(for id: TheoryPageID) -> TheoryIndexEntry? {
        entries.first { $0.id == id }
    }
}
