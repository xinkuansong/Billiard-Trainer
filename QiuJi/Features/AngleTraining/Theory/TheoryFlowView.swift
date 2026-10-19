import SwiftUI

// MARK: - 时间预算（可测数据）

/// 5 步流程的练习用时示例（秒），不是水平分级或比赛时限。
///
/// 数值**逐字**取仓内 vendored `QiuJi/Resources/Theory/contracts/run-out-flow.json`
/// 的 `states[].duration_target_s` 与 `time_budget_seconds`（转写模板 §2.4 数值纪律：
/// 不四舍五入、不换算）。运行时**不读 JSON**（D-v30-1 裁定硬编码），
/// 但 `TheoryFlowContentTests` 会拿这份硬编码值与 vendored JSON 逐项比对，防止漂移。
enum TheoryFlowTimeBudget {
    struct Step: Identifiable {
        var id: String { stateId }
        /// vendored JSON 里的状态 id，仅作测试比对锚点（⛔ 不上屏）。
        let stateId: String
        /// 上屏用的中文步骤名。
        let name: String
        let novice: Int
        let intermediate: Int
        let expert: Int
    }

    static let steps: [Step] = [
        .init(stateId: "step_1_survey", name: "全桌扫描", novice: 15, intermediate: 10, expert: 5),
        .init(stateId: "step_2_plan", name: "反向规划", novice: 30, intermediate: 15, expert: 10),
        .init(stateId: "step_3_check", name: "风险评估", novice: 10, intermediate: 5, expert: 3),
        .init(stateId: "step_4_execute", name: "执行", novice: 20, intermediate: 10, expert: 8),
        .init(stateId: "step_5_reflect", name: "复盘", novice: 5, intermediate: 3, expert: 2),
    ]

    static var noviceTotal: Int { steps.reduce(0) { $0 + $1.novice } }
    static var intermediateTotal: Int { steps.reduce(0) { $0 + $1.intermediate } }
    static var expertTotal: Int { steps.reduce(0) { $0 + $1.expert } }
}

// MARK: - 页面

/// 球理详情页「清台 5 步决策流程」（v30 W4：流程与速查批）。
///
/// - **结构来源**：仓内 vendored `Theory/contracts/run-out-flow.json`（5 个状态的目的 /
///   任务 / 产出 / 时间预算 / 违规模式）。⚠️ D-v30-1 裁定**运行时不读 JSON**——这里是
///   硬编码步骤卡，JSON 只作转写来源与数值比对基准（见 `TheoryFlowContentTests`）。
/// - **正文来源**：`16.billiard_theory/theory/execution-guide.md`。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.12。
/// - **配图判类**：B 战术决策类（判据：讲「什么条件下按什么顺序做」，与具体球位无关）
///   → 非球形抽象图示 `FiveStepFlowFigure`（五步主链 + 不通过的防守支路）+
///   `TimeBudgetFigure`（三档总时长分段条）。⛔ 不画球形局面（红线 5）。
/// - **语域**：JSON 的字段名与模块编号只作转写来源，⛔ 一律不上屏（红线 3 / 红线 4）。
struct TheoryFlowView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .flow,
                    headline: "先看清局面，再把想好的这一杆打出来",
                    detail: "扫桌、规划、评估、执行、复盘，五步把一杆球前后的思考连起来。简单局面可以很快完成，遇到问题球时，再把需要的部分想细。",
                    caption: "流程帮助你少漏掉重要信息，不要求每杆都花相同时间，也不要求把后面所有球算死。"
                )

                whyOrder
                step1
                step2
                step3
                step4
                step5
                timeBudget
                entryAndExit
                violations

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "清台 5 步决策流程")
        .accessibilityIdentifier("theoryPage_flow")
    }

    // MARK: - 为什么要按顺序（execution-guide 总览 + 违规放大）

    private var whyOrder: some View {
        LearnDocSectionCard(title: "为什么先想好，再趴下") {
            LearnDocText.body("看到一颗好进的球就马上出杆，容易漏掉后面的难题；趴下后还在换路线，又容易影响执行。五步流程让观察和选择尽量在站立时完成，准备击球后把注意力放回这一杆。")

            FiveStepFlowFigure()
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryFlow.stepsFigure")
                .accessibilityLabel("五步主链：全桌扫描、反向规划、风险评估、执行、复盘；评估后可以选择进攻或防守，两者都需要认真执行。")

            LearnDocText.footnote("风险评估后选择打法。图中的防守支路同样回到执行，提醒你防守也需要明确路线和落点。")

            LearnDocText.body("五步可以互相回看：评估发现风险太大，就重新规划；打完发现角度变了，就更新路线。熟练的目标是少遗漏，而不是机械念完五个名称。")
        }
    }

    // MARK: - 第 1 步

    private var step1: some View {
        LearnDocSectionCard(title: "第 1 步 · 全桌扫描") {
            LearnDocText.body("先看整张桌，再挑当前这一杆。重点是合法目标、可用袋口、问题球和通道，避免眼睛只跟着最好进的球走。")

            TheoryNumberedList(steps: [
                .init("换角度确认", detail: "看不清的袋口或通道，走到合适位置检查，不必为了凑固定步数绕桌。"),
                .init("数球数", detail: "己方还剩几颗、对手还剩几颗。"),
                .init("标出所有球团", detail: "位置、大小、有没有埋住将来要用的关键球。"),
                .init("标出死球与难球", detail: "贴库的、进死角的、必须踢库才能碰到的。"),
                .init("标出袋口球", detail: "在哪儿、对着哪个袋。"),
            ])

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("记住哪些球可直接打、哪些需要处理，以及袋口球和球团能提供什么机会。")
            }
        }
    }

    // MARK: - 第 2 步

    private var step2: some View {
        LearnDocSectionCard(title: "第 2 步 · 反向规划") {
            LearnDocText.body("先选一个可行的收尾，再看当前能怎样接近它。球形暂时不允许清台时，就把目标缩到改善局面或保留机会。")

            TheoryNumberedList(steps: [
                .init("确定规划范围", detail: "球少时连起剩余顺序；球多或遮挡复杂时，先确定关键衔接与问题球处理机会。"),
                .init("从最后一颗往回排", detail: "依次检查最后一颗、关键球和关键球二需要的位置，再寻找当前路线；把球团处理安排在合适时机。"),
                .init("定下当前一杆与落位区", detail: "当前一杆打哪颗、打完母球应该停在哪一片区域。"),
            ])

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("当前候选球、希望到达的区域，以及下一段怎样衔接。")
            }

            LearnDocText.body("暂时排不出完整路线，可以把防守或处理问题球作为候选。开局后信息多，先抓主要障碍和后续选择，随着局面变清楚再补全计划。")

            LearnDocText.body("尤其在八球里，简单球也可能承担保险、衔接或挡袋的作用。先看用途再打，避免清掉了眼前的球，却失去后面需要的资源。")
        }
    }

    // MARK: - 第 3 步

    private var step3: some View {
        LearnDocSectionCard(title: "第 3 步 · 风险评估") {
            LearnDocText.body("用三问比较候选方案：不只想成功时能得到什么，也想失误后会留下什么。防守同样需要这样检查。")

            TheoryNumberedList(steps: [
                .init("进得了吗？"),
                .init("走得到位吗？"),
                .init("打不进的代价扛得住吗？"),
                .init("会被挡住吗？", detail: "把进球后看不到下一颗的风险算进去，再与替代路线比较，别等走到那里才发现问题。"),
            ])

            TheoryMatrixTable(
                columnTitles: ["重点看", "再比较", "别只看"],
                rows: [
                    .init("中盘", ["后续衔接", "问题球的处理", "眼前好进"]),
                    .init("收尾", ["进球与母球安全", "失误后的局面", "固定概率线"]),
                    .init("剩球悬殊", ["双方可用路线", "防守资源", "球数倍数"]),
                    .init("压力较大", ["熟悉的打法", "实际执行把握", "一时的信心"]),
                ],
                labelWidth: 84
            )
            LearnDocText.footnote("没有通用的进攻及格线。把自己的同类球表现、当前局面和对手能力一起考虑。")

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("选定这一杆的打法、预期结果和可以接受的偏差。仍不清楚时，回到规划调整方案。")
            }
        }
    }

    // MARK: - 第 4 步

    private var step4: some View {
        LearnDocSectionCard(title: "第 4 步 · 执行") {
            LearnDocText.body("把方案变成具体的进球线、母球路线、速度和打点。这几项互相影响，要在出杆前一起确认。")

            TheoryNumberedList(steps: [
                .init("检查方向", detail: "用切线作几何参照，再根据到球时是斯登、自然滚动还是后旋，判断整段母球路线。"),
                .init("选择速度", detail: "参照练过的力度，结合运杆幅度和节奏，让母球进入可用区域。"),
                .init("确认旋转", detail: "选能完成路线的打点；需要加左右塞时，说清用途并考虑补偿，再核对进球线。"),
            ])
            LearnDocText.footnote("角度、速度、旋转是检查顺序，不是互不影响的三项。改变其中一项，其他两项也要重新核对。")

            LearnDocText.body("直接走位、避开障碍、碰开球团和防守，各有不同的检查重点。但无论哪一种，都应在趴下前说清要让球往哪里走。")

            LearnDocFormulaNest(title: "出手前的固定动作") {
                LearnDocText.footnote("站立时确认路线和速度感，入位后完成熟悉的瞄准与运杆，平顺出杆并保持身体稳定。运杆次数按自己的稳定流程安排；趴下后若改变主意，起身重新准备。")
            }

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("观察目标球是否按计划入袋，以及母球的实际路线和停点，留给下一步核对。")
            }
        }
    }

    // MARK: - 第 5 步

    private var step5: some View {
        LearnDocSectionCard(title: "第 5 步 · 复盘") {
            LearnDocText.body("目的：拿实际落位跟计划落位比一比，决定下一杆按什么策略走。")

            TheoryMatrixTable(
                columnTitles: ["下一杆怎么办"],
                rows: [
                    .init("仍在可用区域", ["确认通道后继续，不必追求停在同一个点"]),
                    .init("角度变化，仍能衔接", ["微调下一杆，并重新检查后续路线"]),
                    .init("衔接或球形改变", ["重新扫桌，比较新的顺序与打法"]),
                ],
                labelWidth: 96
            )

            LearnDocText.body("是否重排，不由偏差距离单独决定。差一点可能恰好失去角度，偏得远也可能仍有好路线。发生碰球、球团散开或必要通道变化时，重新看整张桌。")

            LearnDocText.body("最后给自己一秒钟：这次偏差是技术问题（瞄准、速度、旋转），还是决策问题（球选错了、队列排错了）？下次遇到同类局面该怎么改。")

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("决定继续、微调还是重排，并记住一个值得练习的问题。比赛中简短判断，练习后再详细复盘。")
            }
        }
    }

    // MARK: - 时间预算

    private var timeBudget: some View {
        LearnDocSectionCard(title: "整套走下来要多久") {
            TimeBudgetFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryFlow.timeFigure")
                .accessibilityLabel("练习用时的三个分配示例，总计分别为 80 秒、43 秒和 28 秒。不是水平分级、统计结果或比赛达标线。")

            TheoryMatrixTable(
                columnTitles: ["示例一", "示例二", "示例三"],
                rows: TheoryFlowTimeBudget.steps.map { step in
                    TheoryMatrixTable.Row(
                        step.name,
                        ["\(step.novice) 秒", "\(step.intermediate) 秒", "\(step.expert) 秒"]
                    )
                } + [
                    TheoryMatrixTable.Row("总计", [
                        "\(TheoryFlowTimeBudget.noviceTotal) 秒",
                        "\(TheoryFlowTimeBudget.intermediateTotal) 秒",
                        "\(TheoryFlowTimeBudget.expertTotal) 秒",
                    ]),
                ]
            )

            LearnDocText.body("这些秒数只展示练习时怎样分配时间，不代表新手或高手的实测用时，也不是必须达到的标准。可先慢慢说清思路，再练习简短完成；比赛中按当场计时规则安排，复杂局面与简单球不必同样用时。")
        }
    }

    // MARK: - 入口与出口

    private var entryAndExit: some View {
        LearnDocSectionCard(title: "什么时候启动、什么时候结束") {
            LearnDocText.body("每次回到台前，先检查变化。拿到自由球时，也要先想放在哪里、为什么放在那里，别只摆成眼前最好进的位置。")
            LearnDocText.body("继续击球时，根据上一杆结果更新计划；轮次结束后，观察对手留下的新局面。流程随信息更新，不必每次把已经确认的细节从头想一遍。")
        }
    }

    // MARK: - 违规模式

    private var violations: some View {
        LearnDocSectionCard(title: "跳步会付出什么代价") {
            TheoryMatrixTable(
                columnTitles: ["后果"],
                rows: [
                    .init("漏看全桌", ["可能错过问题球、保险球和必要通道"]),
                    .init("只想当前一杆", ["可能提前用掉后续需要的衔接球"]),
                    .init("不比较后果", ["可能忽略失误代价或更好的替代方案"]),
                    .init("仓促出杆", ["计划清楚，动作却没准备好"]),
                    .init("不核对结果", ["可能继续执行已经不适合的路线"]),
                ],
                labelWidth: 96
            )
            LearnDocText.footnote("这些是容易遗漏的环节，不是对失败率的量化预测。")
        }
    }

    // MARK: - 常见误区（取材 run-out-flow.json 的违规模式）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "上台先找最好打的那颗，直接趴下去打",
            right: "跳过了扫桌。球团和袋口球没标出来，到中后段才发现路早被堵死了。"
        ),
        .init(
            wrong: "边打边想下一杆，不做倒推",
            right: "先想一个可行收尾和眼前的衔接，再根据实际结果调整，避免把必要的过渡球提前打掉。"
        ),
        .init(
            wrong: "默认这一杆就是要进攻",
            right: "把进球、走位和失败代价一起看，也检查防守的实际把握，再选打法。"
        ),
        .init(
            wrong: "失位了还照原计划打下去",
            right: "看角度和通道有没有改变；影响衔接时就调整，不必等偏出固定距离。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "把五步压成一页带上场",
                destination: "清台速查手册：上场前 5 分钟过一遍",
                route: .theoryPage(.quickRef)
            )
            PracticeCTA(
                title: "第 3 步的三问怎么答",
                destination: "风险报酬决策矩阵：进得了吗、走得到位吗、代价扛得住吗",
                route: .theoryPage(.t08)
            )

            LearnDocTextLink(
                title: "反向规划",
                subtitle: "第 2 步的队列怎么从最后一颗往回排",
                route: .theoryPage(.t05)
            )
            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "队列里最该保护的是哪两颗",
                route: .theoryPage(.t06)
            )
            LearnDocTextLink(
                title: "球团管理",
                subtitle: "为问题球安排合适的处理时机",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "安全球三维度模型",
                subtitle: "把防守作为具体方案一起比较",
                route: .theoryPage(.t10)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "用几何参照配合到球时旋转判断路线",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "母球速度分级",
                subtitle: "第 4 步再定速度：用排除法挑档",
                route: .theoryPage(.t04)
            )
            LearnDocTextLink(
                title: "最少加塞原则",
                subtitle: "确认加塞用途与所需补偿",
                route: .theoryPage(.t09)
            )

            LearnDocText.footnote("先在练习局里说出每一步的判断，打完核对结果。熟悉后逐渐缩短思考时间，保留重要检查。")
        }
    }
}

// MARK: - 抽象图示 ①：五步主链 + 防守支路

/// 五步主链（竖排）+ 第 3 步不通过时的防守支路（非球形，红线 5 合规）。
///
/// 只画正文已有的断言：五步顺序、第 3 步二分、防守回到执行。⛔ 不标任何连续标度。
private struct FiveStepFlowFigure: View {
    private static let steps = [
        ("① 全桌扫描", "看清楚"),
        ("② 反向规划", "想清楚"),
        ("③ 风险评估", "选打法"),
        ("④ 执行", "怎么打"),
        ("⑤ 复盘", "学到什么"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.52
            let cardH = h * 0.13
            let mainX = w * 0.34
            let ys = (0..<5).map { h * (0.11 + 0.175 * CGFloat($0)) }
            let branchX = w * 0.88

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                // 主链箭头。
                ForEach(0..<4, id: \.self) { i in
                    arrow(
                        from: CGPoint(x: mainX, y: ys[i] + cardH * 0.5),
                        to: CGPoint(x: mainX, y: ys[i + 1] - cardH * 0.5),
                        color: .btPrimary
                    )
                }

                // 第 3 步不通过 → 防守支路 → 回到执行。
                Path { p in
                    p.move(to: CGPoint(x: mainX + cardW * 0.5, y: ys[2]))
                    p.addLine(to: CGPoint(x: branchX, y: ys[2]))
                    p.addLine(to: CGPoint(x: branchX, y: ys[3]))
                    p.addLine(to: CGPoint(x: mainX + cardW * 0.5, y: ys[3]))
                }
                .stroke(Color.btWarning,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                Text("选防守\n再执行")
                    .font(.btMicro)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.btWarning)
                    .position(x: (mainX + cardW * 0.5 + branchX) / 2, y: (ys[2] + ys[3]) / 2)

                ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: Spacing.sm) {
                        Text(step.0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btPrimary)
                        Spacer(minLength: 4)
                        Text(step.1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: mainX, y: ys[i])
                }

                Text("先决定打法，再专心执行")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.5, y: h * 0.955)
            }
        }
    }

    private func arrow(from: CGPoint, to: CGPoint, color: Color) -> some View {
        ZStack {
            Path { p in
                p.move(to: from)
                p.addLine(to: to)
            }
            .stroke(color, lineWidth: 1.5)
            Path { p in
                p.move(to: to)
                p.addLine(to: CGPoint(x: to.x - 4, y: to.y - 6))
                p.addLine(to: CGPoint(x: to.x + 4, y: to.y - 6))
                p.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - 抽象图示 ②：三档时间预算分段条

/// 三组练习用时示例，按五步分段（非球形，红线 5 合规）。
///
/// 分段比例直接由 `TheoryFlowTimeBudget` 的秒数算出——⛔ 不引入正文没有的标度。
private struct TimeBudgetFigure: View {
    private struct Lane {
        let title: String
        let seconds: [Int]
        var total: Int { seconds.reduce(0, +) }
    }

    private var lanes: [Lane] {
        [
            .init(title: "示例一", seconds: TheoryFlowTimeBudget.steps.map(\.novice)),
            .init(title: "示例二", seconds: TheoryFlowTimeBudget.steps.map(\.intermediate)),
            .init(title: "示例三", seconds: TheoryFlowTimeBudget.steps.map(\.expert)),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxTotal = CGFloat(lanes.map(\.total).max() ?? 1)
            let labelW = w * 0.16
            let barMaxW = w * 0.66
            let barH = h * 0.13
            let ys = [h * 0.32, h * 0.52, h * 0.72]

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("练习用时示例（非达标线）")
                    .font(.btCaption2.weight(.semibold))
                    .foregroundStyle(.btPrimary)
                    .position(x: w * 0.5, y: h * 0.12)

                ForEach(Array(lanes.enumerated()), id: \.offset) { laneIndex, lane in
                    Text(lane.title)
                        .font(.btCaption)
                        .foregroundStyle(.btTextSecondary)
                        .frame(width: labelW, alignment: .leading)
                        .position(x: w * 0.04 + labelW / 2, y: ys[laneIndex])

                    let laneW = barMaxW * CGFloat(lane.total) / maxTotal
                    HStack(spacing: 1.5) {
                        ForEach(Array(lane.seconds.enumerated()), id: \.offset) { i, seconds in
                            Rectangle()
                                .fill(Color.btPrimary.opacity(i.isMultiple(of: 2) ? 0.75 : 0.40))
                                .frame(width: max(1, laneW * CGFloat(seconds) / CGFloat(lane.total)))
                        }
                    }
                    .frame(width: laneW, height: barH, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                    .position(x: w * 0.04 + labelW + laneW / 2, y: ys[laneIndex])

                    Text("\(lane.total) 秒")
                        .font(.btCaption2)
                        .monospacedDigit()
                        .foregroundStyle(.btText)
                        .position(x: w * 0.04 + labelW + laneW + w * 0.07, y: ys[laneIndex])
                }

                Text("按球形复杂程度分配时间")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.5, y: h * 0.90)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryFlowView() }
}

#Preview("Dark") {
    NavigationStack { TheoryFlowView() }
        .preferredColorScheme(.dark)
}
#endif
