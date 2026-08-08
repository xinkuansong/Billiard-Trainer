import SwiftUI

/// 速查手册里的一条「速记 → 详情页」条目。
///
/// 标题不在这里写死：一律从 `TheoryCatalog` 取页名，保证「索引页条目标题 =
/// 导航标题 = 互链文案」三处逐字一致（组件规范 §一）。
struct TheoryQuickRefRow: Identifiable {
    var id: TheoryPageID { page }
    let page: TheoryPageID
    /// 速查用的一句话，取材 16 `quick-reference.md` 的对应行。
    let line: String
}

/// 球理详情页「清台速查手册」（v30 W4：流程与速查批）。
///
/// - **取材**：`16.billiard_theory/theory/quick-reference.md`（本就面向业余读者，
///   接近原样转写）+ 仓内 vendored `Theory/contracts/*.json` 的对应条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.13。
/// - **深链**：按主题分节，每条速记都链回对应球理详情页
///   （`AngleRoute.theoryPage`）。链接目标与页名由 `TheoryFlowContentTests` 守。
/// - **配图判类**：B 战术决策类 → 非球形抽象图示 `QuickRefRouteFigure`
///   （五步流程各自会用到哪几条球理的导航图）。⛔ 不画球形局面（红线 5）。
/// - **语域**：⛔ 原文的 定理 / 模块编号、英文术语、人名与来源一律不上屏；
///   固定解模块（未上线）一律用人话展开（红线 3 / 红线 4）。
struct TheoryQuickRefView: View {

    // MARK: - 速查条目（可测数据）

    static let flowRow = TheoryQuickRefRow(
        page: .flow,
        line: "扫桌 → 倒推 → 三问 → 执行 → 复盘；目标用时：新手 80 秒 / 进阶 43 秒 / 高手 28 秒"
    )

    static let collisionRows: [TheoryQuickRefRow] = [
        .init(page: .t01, line: "自然滚动 + 1/4–3/4 球厚度（切角 14°–49°）→ 碰后偏约 30°；精确版：终点 = 5/7 切线 + 2/7 瞄准线"),
        .init(page: .t02, line: "滑动状态撞球 → 两球分离 90°（实测约 85°）；短距、中下击、距离允许滑动时用"),
        .init(page: .t03, line: "碰撞瞬间母球总沿切线走（垂直于连心线）；永远成立"),
    ]

    static let controlRows: [TheoryQuickRefRow] = [
        .init(page: .t04, line: "9 档并成轻 / 中 / 重三段；靠出杆长度调而不是加力气；训练优先中间 4–6 档"),
        .init(page: .t09, line: "加塞引入挤偏 + 弧线 + 投掷三重耦合；能用中杆绝不加塞；长距加塞需要约 1% 的精度"),
    ]

    static let decisionRows: [TheoryQuickRefRow] = [
        .init(page: .t05, line: "从最后一颗往回推；每杆复盘后重新规划；最低规划深度 3 步"),
        .init(page: .t06, line: "关键球与关键球二必须分开选；用四问选定（够得到 / 有角度 / 有保险 / 不破局）"),
        .init(page: .t07, line: "球团必须早处理；必须有保险球；用最低必要力度；不在低成功率球上破"),
        .init(page: .t08, line: "三问：进得了？走得到位？代价扛得住？硬性下限是不让自己被挡死"),
        .init(page: .t10, line: "拉开距离 + 占住库位 + 用障碍球挡住，三维独立组合；三维全包含最强"),
    ]

    /// 全部深链条目（测试用：必须覆盖除本页外的 11 篇，且每篇都已上线）。
    static var allRows: [TheoryQuickRefRow] {
        [flowRow] + collisionRows + controlRows + decisionRows
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .quickRef,
                    headline: "上场前 5 分钟，把这一页过一遍",
                    detail: "十条球理加一套五步流程，压缩成一页速记。每一条后面都能点进去看为什么。",
                    caption: "这一页只给「怎么做」，不讲推导；想知道为什么，点开对应的那一页。"
                )

                flowSection
                collisionSection
                controlSection
                decisionSection
                jumpTable
                keyNumbers
                goldenLines

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "清台速查手册")
        .accessibilityIdentifier("theoryPage_quickRef")
    }

    // MARK: - 五步流程

    private var flowSection: some View {
        LearnDocSectionCard(title: "五步流程（每杆都走）") {
            TheoryNumberedList(steps: [
                .init("全桌扫描", detail: "数球数、标球团、找袋口球、标死球。"),
                .init("反向规划", detail: "还剩 4 颗及以上排完整倒推队列；只剩 3 颗及以下按收官三球打。"),
                .init("风险评估", detail: "过三问；不通过就转防守线。"),
                .init("执行", detail: "顺序铁律：角度 → 速度 → 旋转。"),
                .init("复盘", detail: "失位超过 1/3 桌长，整局重做。"),
            ])

            QuickRefRouteFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryQuickRef.routeFigure")
                .accessibilityLabel("五步流程各自会用到哪几条球理：扫桌用球团管理，倒推用反向规划与关键球原理，评估用风险报酬三问，执行用切线法则、速度分级与最少加塞，复盘回到反向规划。")

            refLink(Self.flowRow)
        }
    }

    // MARK: - 碰撞与瞄准

    private var collisionSection: some View {
        LearnDocSectionCard(title: "碰撞与瞄准") {
            ForEach(Self.collisionRows) { row in
                refLink(row)
            }
            LearnDocFormulaNest(title: "两条配套速记") {
                LearnDocText.footnote("沿着下一杆的进球线进入落位区，速度容差最大；横穿过去容差最小。")
                LearnDocText.footnote("袋口球的半球两条固定走向：沿库朝角袋打半球，母球走对角线；沿对角线朝角袋打半球，母球沿库走。两个方向只能取一个。")
            }
        }
    }

    // MARK: - 力度与加塞

    private var controlSection: some View {
        LearnDocSectionCard(title: "力度与加塞") {
            ForEach(Self.controlRows) { row in
                refLink(row)
            }

            TheoryMatrixTable(
                columnTitles: ["典型用途", "出杆长度"],
                rows: [
                    .init("1 档", ["极慢防守 / 短距精控", "极短"]),
                    .init("2–3 档", ["短距走位 / 轻碰球团 / 防守微推", "短"]),
                    .init("4–6 档", ["大多数走位与关键球进位（训练核心）", "中等"]),
                    .init("7–8 档", ["大力走位 / 远距 / 跨桌", "长"]),
                    .init("9 档", ["薄球必须走位时的最重一档 / 开球", "极长"]),
                ],
                labelWidth: 62
            )

            LearnDocFormulaNest(title: "三条力度速记") {
                LearnDocText.footnote("母球离目标球超过大约 1 钻石（约 31.75 厘米）还想打停球，就不能只用中杆——要带一点后旋。")
                LearnDocText.footnote("想让母球停在离库 30 厘米以内，与其精细收力，不如让它撞库后停：速度容差大约翻倍。")
                LearnDocText.footnote("加塞四级：0 不加 → 1 约 1/4 杆头 → 2 约 1/2 杆头 → 3 接近打滑极限。长于半张桌还要加塞，多数情况该放弃这条线路。")
            }
        }
    }

    // MARK: - 决策与安全球

    private var decisionSection: some View {
        LearnDocSectionCard(title: "决策与安全球") {
            ForEach(Self.decisionRows) { row in
                refLink(row)
            }

            TheoryMatrixTable(
                columnTitles: ["怎么实现"],
                rows: [
                    .init("拉开距离", ["母球与目标球拉到至少约三分之二桌长"]),
                    .init("占住库位", ["母球贴库，目标球推到对侧库中段"]),
                    .init("用障碍球挡住", ["两球之间隔一颗球或一个球团"]),
                ],
                labelWidth: 96
            )
            LearnDocText.footnote("做成一维是一般安全球，两维算好，三维全包含最强。出手前自检：三个维度各自满足吗？我控的是母球还是目标球（只控一个）？有没有踩雷——贴着决胜球、离库太近、给对手一个容易的一库踢？")
        }
    }

    // MARK: - 局面 → 立刻做什么

    private var jumpTable: some View {
        LearnDocSectionCard(title: "看到这个局面，立刻做什么") {
            TheoryMatrixTable(
                columnTitles: ["立刻做"],
                rows: [
                    .init("桌上有球团没破", ["安排破球团，排在关键球之前"]),
                    .init("还剩 4–7 颗", ["排完整倒推队列"]),
                    .init("只剩 3 颗及以下", ["按收官三球打，尺子更严"]),
                    .init("路径上有障碍", ["优先直接打，其次踢一库，再考虑弧线、多库、跳球"]),
                    .init("三问任一不达标", ["转防守线"]),
                    .init("决定打安全球", ["按三个维度挑一手，能拿几维拿几维"]),
                    .init("拿到自由球", ["先解决最大的问题（球团、难球），再清简单球"]),
                    .init("切线段内有障碍", ["改用高杆，或者换一个切角"]),
                ],
                labelWidth: 108
            )
            LearnDocText.footnote("切线段指母球碰后沿切线走的那一小段，中速、半球厚度下大约 25 厘米。")
        }
    }

    // MARK: - 关键数字

    private var keyNumbers: some View {
        LearnDocSectionCard(title: "记住这几个数") {
            TheoryMatrixTable(
                columnTitles: ["含义"],
                rows: [
                    .init("30°", ["自然滚动母球的碰后偏折角（切角 14°–49°）"]),
                    .init("33.7°", ["偏折角理论极值，出现在切角 28.1° 附近"]),
                    .init("90° → 85°", ["滑动分离角的理论值与实测值"]),
                    .init("5/7 + 2/7", ["母球最终方向 = 5/7 切线 + 2/7 瞄准线"]),
                    .init("3", ["反向规划的最低深度（步）"]),
                    .init("9", ["完整力度档位数"]),
                    .init("约 25 厘米", ["切线持续距离（中速 + 半球厚度）"]),
                    .init("约 31.75 厘米", ["1 钻石：想打停球就得从中杆换后旋的距离"]),
                    .init("约 15 厘米", ["目标球离库近到这个程度，会变成对手的「大目标」"]),
                    .init("87.5%", ["八球错掉最后一颗黑球，送给对手的可击球比例"]),
                ],
                labelWidth: 92
            )
        }
    }

    // MARK: - 金句

    private var goldenLines: some View {
        LearnDocSectionCard(title: "八句能立刻用的话") {
            TheoryNumberedList(steps: [
                .init("先画切线，再加旋转修正。"),
                .init("反向规划最少三步。"),
                .init("关键球输了，整局就输了。"),
                .init("早处理球团，而且必须有保险球。"),
                .init("打不进的代价，比能不能进更重要。"),
                .init("能用中杆，绝不加塞。"),
                .init("把对手的目标球想成太阳，障碍球投下阴影，母球停进阴影就是安全。"),
                .init("八球错掉最后一颗黑球，等于送对手 87.5% 的球，基本必输。"),
            ])
        }
    }

    // MARK: - 常见误区（取材 quick-reference 第八节失败模式 Top 10）
    //
    // 只取「与流程本身无关」的四条：跳过扫桌 / 不倒推 / 跳过三问 / 失位不复盘
    // 已由清台 5 步决策流程页的误区卡承载，本页不重复（不重复原则）。

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "「这一杆要用点力」",
            right: "力度不是用力大小，是出杆长度。想着加力气，节奏和瞄准会一起走样。"
        ),
        .init(
            wrong: "习惯性地加一点塞",
            right: "一加塞就同时多出挤偏、弧线、投掷三条误差。能用中杆走到位就别加。"
        ),
        .init(
            wrong: "用最后一颗散球去破球团",
            right: "那颗不是承转球，破完往往无路可走。要用能自然路过的球，并先备好保险球。"
        ),
        .init(
            wrong: "顺手把袋口球当关键球",
            right: "袋口球默认不作关键球——太容易进反而没角度。掌握半球的两条固定走向后才可以考虑。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "把顺序练成习惯",
                destination: "清台 5 步决策流程：每一步做什么、交出什么",
                route: .theoryPage(.flow)
            )

            LearnDocText.footnote("这一页是速记，不替代逐条细读：先把三问和五步走顺，再回头补几何与力度的细节。")
        }
    }

    // MARK: - Row rendering

    private func refLink(_ row: TheoryQuickRefRow) -> some View {
        LearnDocTextLink(
            title: TheoryCatalog.entry(for: row.page)?.title ?? "",
            subtitle: row.line,
            route: .theoryPage(row.page)
        )
        .accessibilityIdentifier("quickRefLink_\(row.page.rawValue)")
    }
}

// MARK: - 抽象图示：五步 ↔ 球理导航

/// 五步流程各自会用到哪几条球理（非球形，红线 5 合规）。
///
/// 对应关系取自 16 `execution-guide.md` 每步的「调用」行，⛔ 不新增关系。
private struct QuickRefRouteFigure: View {
    private static let lanes = [
        ("① 扫桌", "球团管理"),
        ("② 倒推", "反向规划 · 关键球原理"),
        ("③ 评估", "风险报酬三问"),
        ("④ 执行", "切线 · 速度 · 加塞"),
        ("⑤ 复盘", "回到反向规划"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let stepW = w * 0.22
            let laneH = h * 0.13
            let stepX = w * 0.17
            let tagX = w * 0.63
            let tagW = w * 0.62
            let ys = (0..<5).map { h * (0.20 + 0.155 * CGFloat($0)) }

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("每一步会用到哪几条球理")
                    .font(.btCaption2.weight(.semibold))
                    .foregroundStyle(.btPrimary)
                    .position(x: w * 0.5, y: h * 0.08)

                // 最左侧竖脊：五步是有序的（贴在步骤卡外侧，不压字）。
                Path { p in
                    let spineX = stepX - stepW * 0.5 - w * 0.025
                    p.move(to: CGPoint(x: spineX, y: ys[0] - laneH * 0.5))
                    p.addLine(to: CGPoint(x: spineX, y: ys[4] + laneH * 0.5))
                }
                .stroke(Color.btPrimary.opacity(0.35), lineWidth: 1.5)

                ForEach(Array(Self.lanes.enumerated()), id: \.offset) { i, lane in
                    Text(lane.0)
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(.btPrimary)
                        .frame(width: stepW, height: laneH)
                        .background(
                            RoundedRectangle(cornerRadius: BTRadius.sm)
                                .fill(Color.btPrimary.opacity(0.12))
                        )
                        .position(x: stepX, y: ys[i])

                    Path { p in
                        p.move(to: CGPoint(x: stepX + stepW * 0.5, y: ys[i]))
                        p.addLine(to: CGPoint(x: tagX - tagW * 0.5, y: ys[i]))
                    }
                    .stroke(Color.btSeparator, lineWidth: 1)

                    Text(lane.1)
                        .font(.btCaption2)
                        .foregroundStyle(.btTextSecondary)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.sm)
                        .frame(width: tagW, height: laneH, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: BTRadius.sm)
                                .fill(Color.btBGSecondary)
                        )
                        .position(x: tagX, y: ys[i])
                }

                Text("点开任意一条看为什么")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.5, y: h * 0.95)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryQuickRefView() }
}

#Preview("Dark") {
    NavigationStack { TheoryQuickRefView() }
        .preferredColorScheme(.dark)
}
#endif
