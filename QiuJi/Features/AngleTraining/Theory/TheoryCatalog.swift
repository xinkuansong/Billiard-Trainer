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
    /// **取材纪律（X-v30-2 裁定，v30 W1 起生效；原「只准截断」已放宽）**：
    /// 以 vendored `theorem-tags.json.statement_one_liner` /
    /// `run-out-flow.json.description` / 16 `quick-reference.md` 为唯一来源，
    /// 允许**语义等价的限定改写**——把英文术语与调研腔换成中文人话，
    /// 但 ⛔ 不得新增断言、不得改变适用条件、不得改动数值 / 单位 / 关键限定词。
    /// 每条改写的「原文 → 改写 → 依据」逐条记录在
    /// `docs/research/20260807-v30理论转写模板.md` §六；
    /// 约束由 `TheoryCatalogTests`（数值守恒 + 语义锚词 + 无拉丁字母 + 逐字条目集合）固化。
    let subtitle: String
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
            // 改写自 T01.statement_one_liner 前段：OB→目标球、cut→切角、球击球→球厚度。
            subtitle: "自然滚动的母球以 1/4–3/4 球厚度（切角 14°–49°）撞目标球，碰后偏约 30°",
            group: .collision,
            isPublished: true
        ),
        .init(
            id: .t02,
            title: "90° 法则",
            // 改写自 T02.statement_one_liner 前段：stun→滑动（SPEC §8.8 规范译名）、OB→目标球。
            subtitle: "母球以滑动状态撞目标球时，两球分离角 90°",
            group: .collision,
            isPublished: true
        ),
        .init(
            id: .t03,
            title: "切线法则",
            // 改写自 T03.statement_one_liner 前两句：⊥→垂直于（末句含 T 编号，按红线剔除）。
            subtitle: "碰撞瞬间母球总沿切线走（切线垂直于两球连心线）；之后偏多少由旋转决定",
            group: .collision,
            isPublished: true
        ),
        // MARK: 旋转与走位
        .init(
            id: .t04,
            title: "母球速度分级",
            // 改写自 T04.statement_one_liner 前两段：剔除来源人名、soft/medium/hard→轻/中/重。
            subtitle: "力度分 9 档，并成轻（1–3）中（4–6）重（7–9）三段；靠出杆长度而不是用力大小来调",
            group: .spin,
            isPublished: true
        ),
        .init(
            id: .t09,
            title: "最少加塞原则",
            // 改写自 T09.statement_one_liner 中段：squirt/swerve/throw→挤偏/弧线/投掷（SPEC §8.8）。
            subtitle: "加塞会同时引入挤偏、弧线、投掷三重耦合误差",
            group: .spin,
            isPublished: true
        ),
        // MARK: 战术与决策
        .init(
            id: .t05,
            title: "反向规划",
            // 逐字取 T05.statement_one_liner 前段（破折号前）——原文已是中文人话，不改写。
            subtitle: "清台决策必须从最后一颗球反向倒推到当前一杆",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t06,
            title: "关键球原理",
            // 改写自 T06.statement_one_liner 前段：key ball→关键球（与页名同字）。
            subtitle: "决定成败的不是最后一颗球，而是为它安排好母球的那一颗（关键球）",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t07,
            title: "球团管理",
            // 逐字取 T07.statement_one_liner 前段（分号前）——原文已是中文人话，不改写。
            subtitle: "球团必须尽早识别、尽早处理",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t08,
            title: "风险报酬决策矩阵",
            // 改写自 T08.statement_one_liner 前段：X/Y/Z 占位符换成口语「够不够 / 扛不扛得住」，
            // 阈值本身因人而异（原文 §4「需个体校准」），详情页给参考表。
            subtitle: "开打前先过三问：进球把握够不够、走位把握够不够、打不进的代价扛不扛得住",
            group: .tactics,
            isPublished: true
        ),
        .init(
            id: .t10,
            title: "安全球三维度模型",
            // 改写自 T10.statement_one_liner 前段：D/M/O 字母标签换成三个维度的中文说法。
            subtitle: "安全球的质量由 3 个独立维度决定：拉开距离、占住库位、用障碍球挡住",
            group: .tactics,
            isPublished: true
        ),
        // MARK: 流程与速查
        .init(
            id: .flow,
            title: "清台 5 步决策流程",
            // 改写自 run-out-flow.json.description 首句：剔除「状态机」工程腔。
            subtitle: "从上台到这一杆打完，中间该按什么顺序想",
            group: .flow,
            isPublished: false
        ),
        .init(
            id: .quickRef,
            title: "清台速查手册",
            // 逐字取 16 quick-reference.md 首段子串——原文已是中文人话，不改写。
            subtitle: "业余玩家上场前 5 分钟通读",
            group: .flow,
            isPublished: false
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
