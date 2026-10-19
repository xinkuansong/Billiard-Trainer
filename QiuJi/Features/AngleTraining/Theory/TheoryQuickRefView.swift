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
        line: "扫桌 → 规划 → 评估 → 执行 → 复盘；先想清打法，打完按实际角度和通道更新计划"
    )

    static let collisionRows: [TheoryQuickRefRow] = [
        .init(page: .t01, line: "到球时自然滚动、约 1/4–3/4 球厚度，母球稳定后的方向相对入射方向偏约 30°；不是从出手起一直走直线"),
        .init(page: .t02, line: "到球时没有前后旋的斯登击球，理想模型中两球出射方向相差 90°；实际偏差不是固定 85°"),
        .init(page: .t03, line: "切线垂直于碰撞时连心线；理想斯登时母球沿平行于切线的方向离开，前后旋会改变后续路线"),
    ]

    static let controlRows: [TheoryQuickRefRow] = [
        .init(page: .t04, line: "9 档是建立力度参照的方法；用稳定的运杆幅度与节奏练习，按球形和台况校准，不能直接当成到球速度"),
        .init(page: .t09, line: "先看不加左右塞的路线；加塞要有明确用途，并综合考虑挤偏、弧线和投掷。能用较少的塞量完成，就不必多加"),
    ]

    static let decisionRows: [TheoryQuickRefRow] = [
        .init(page: .t05, line: "从最后一颗的落位区往回找衔接；可从三杆练起，每杆检查角度和通道，变化影响后续时就调整"),
        .init(page: .t06, line: "关键球为收尾安排母球，关键球二衔接关键球；分别检查可达、角度、备用路线和碰球风险，再连起来验证"),
        .init(page: .t07, line: "尽早识别问题球，选好处理时机；找顺路碰球的机会和保险球，用足够打开所需通道的力度"),
        .init(page: .t08, line: "一起看进球把握、走位把握和失败代价，再与其他进攻及防守比较；没有通用概率及格线"),
        .init(page: .t10, line: "从距离、库位和障碍检查防守；数量不等于质量，还要看执行把握和对手实际的应对路线"),
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
                    headline: "上场前，回想这些判断要点",
                    detail: "把碰撞、控制和战术的重点放在一起，方便快速回看。遇到不熟悉的条件，点开对应页面看完整说明。",
                    caption: "速记帮助你想起方法，不能省掉适用条件。数字是参照，具体球形还要具体判断。"
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
        LearnDocSectionCard(title: "五步流程") {
            TheoryNumberedList(steps: [
                .init("全桌扫描", detail: "数球数、标球团、找袋口球、标死球。"),
                .init("反向规划", detail: "先选收尾和关键衔接，球形复杂时先抓主要问题。"),
                .init("风险评估", detail: "比较进球、走位和失败后果，选定进攻或防守。"),
                .init("执行", detail: "一起确认方向、速度和旋转，再专心出杆。"),
                .init("复盘", detail: "看实际角度和通道是否仍能衔接，决定继续或调整。"),
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
                LearnDocText.footnote("尽量沿可用落位区较长的方向进入，通常比横穿狭窄区域更容易控制；仍要保留下一杆需要的角度。")
                LearnDocText.footnote("袋口球可练习沿库、沿对角线等接近方式，用到球时的旋转和实际厚度判断碰后路线，不把它们当成仅有的两条固定走向。")
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
                columnTitles: ["练习参照", "控制重点"],
                rows: [
                    .init("1 档", ["极慢、短距控制", "小幅度也要顺畅"]),
                    .init("2–3 档", ["较轻的短距走位", "稳定幅度与节奏"]),
                    .init("4–6 档", ["中等速度的常用参照", "观察到球状态与停点"]),
                    .init("7–8 档", ["需要更大速度的路线", "别让动作随加速走样"]),
                    .init("9 档", ["高速度的专门练习", "不能当成所有开球标准"]),
                ],
                labelWidth: 62
            )

            LearnDocFormulaNest(title: "三条力度速记") {
                LearnDocText.footnote("停球要让母球正撞时没有前后旋。距离、速度和台呢共同影响后旋何时消退，没有固定的距离分界。")
                LearnDocText.footnote("靠近库边落位时，可比较直接停下与碰库后停下；哪条更宽容，要看入库角度、旋转和可用区域。")
                LearnDocText.footnote("加塞选择顺序：先看不加塞，再试少量，需要时增加。四级是选择顺序，不是统一打点刻度；距离越长，越要核对补偿。")
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
                    .init("拉开距离", ["检查长距离是否真的增加对手进攻难度"]),
                    .init("占住库位", ["检查是否限制出杆，以及仍有哪些进攻或解球路线"]),
                    .init("用障碍球挡住", ["确认直接路线被挡，也检查其他合法目标与库线"]),
                ],
                labelWidth: 96
            )
            LearnDocText.footnote("确定哪颗球必须精确到位，给另一颗留出较宽区域。再看组合球、翻袋和解球机会；不要只数满足了几个维度。")
        }
    }

    // MARK: - 局面 → 立刻做什么

    private var jumpTable: some View {
        LearnDocSectionCard(title: "遇到这些局面，先检查什么") {
            TheoryMatrixTable(
                columnTitles: ["检查重点"],
                rows: [
                    .init("有球团", ["是否妨碍计划，何时处理，碰开后打谁"]),
                    .init("中盘选择较多", ["保留关键衔接，从当前路线接近收尾"]),
                    .init("准备收尾", ["进球是否可靠，母球是否安全，失误会留下什么"]),
                    .init("路径上有障碍", ["比较自己练过、规则允许的替代路线"]),
                    .init("三问有疑问", ["再比较其他进攻与防守，不自动判定打法"]),
                    .init("决定防守", ["能否做成，对手还可以怎样应对"]),
                    .init("拿到自由球", ["比较处理问题球、衔接与防守的机会"]),
                    .init("碰后附近有障碍", ["检查整段曲线路径，不能只看最终方向"]),
                ],
                labelWidth: 108
            )
            LearnDocText.footnote("母球碰后路线随速度、旋转和台况变化，不能用固定的一段距离判断是否避开障碍。")
        }
    }

    // MARK: - 关键数字

    private var keyNumbers: some View {
        LearnDocSectionCard(title: "分清这几个参照") {
            TheoryMatrixTable(
                columnTitles: ["含义"],
                rows: [
                    .init("约 30°", ["自然滚动、约 1/4–3/4 厚度时，碰后稳定方向相对入射方向的偏折"]),
                    .init("33.7°", ["理想滚动模型的最大偏折，切角约 28.1°，不是实战固定角度"]),
                    .init("90°", ["理想斯登时两球出射方向的夹角；正撞停球与极薄极限需另看"]),
                    .init("5/7 与 2/7", ["滚动模型中的速度向量权重，不是两条单位方向线或停点的比例"]),
                    .init("三杆", ["练习反向规划的起点，不是所有局面的最低深度"]),
                    .init("9 档", ["力度练习参照；App 五档是另一套标尺，不能一一等同"]),
                    .init("三问", ["进球、走位、失败代价，结合替代方案作判断"]),
                    .init("三维", ["距离、库位、障碍，数量不直接代表防守质量"]),
                    .init("四级加塞", ["选择顺序，不是统一的杆头偏移刻度"]),
                    .init("五步", ["观察到复盘的检查流程，用时随局面调整"]),
                ],
                labelWidth: 92
            )
        }
    }

    // MARK: - 金句

    private var goldenLines: some View {
        LearnDocSectionCard(title: "八句上台提醒") {
            TheoryNumberedList(steps: [
                .init("先认清到球时的旋转，再选碰后方向的参照。"),
                .init("从收尾往回看，也从当前找路接上。"),
                .init("关键球不只要好进，还要好接近、好走位。"),
                .init("碰开球团前，先想下一杆打谁。"),
                .init("成功的收益与失败的代价，要一起比较。"),
                .init("加塞要有目的，补偿要有练习参照。"),
                .init("藏住之后，再站到对手的位置看一遍。"),
                .init("打完核对角度和通道，计划可以随结果调整。"),
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
            right: "用练过的运杆幅度与节奏形成速度，避免临时猛发力破坏动作。"
        ),
        .init(
            wrong: "习惯性地加一点塞",
            right: "先说清它要改变什么，再判断收益是否值得承担额外补偿。"
        ),
        .init(
            wrong: "用最后一颗散球去破球团",
            right: "先检查碰开后的衔接，尽量留下保险球。若没有可靠后续，再比较其他处理时机或防守方案。"
        ),
        .init(
            wrong: "顺手把袋口球当关键球",
            right: "检查接近位置、碰后路线和下一段衔接；容易进不代表一定适合，也不代表一定不适合。"
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
