import SwiftUI

// MARK: - 时间预算（可测数据）

/// 5 步流程的时间预算（秒）。
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
                    headline: "上台以后，按固定顺序走完五步",
                    detail: "先扫桌，再倒推，然后过三问，接着执行，最后复盘。每一步只做自己那件事，做完把结论交给下一步。",
                    caption: "每次轮到自己上台都从第一步开始：自由球、防守后回台也一样，不要凭感觉直接打。"
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
        LearnDocSectionCard(title: "顺序本身就是纪律") {
            LearnDocText.body("业余最常见的打法是「看到一颗能打的就趴下去打」。五步流程做的事很简单：把「看清楚」「想清楚」「敢不敢打」「怎么打」「打完学到什么」分成互不干扰的五段，每段只做一件事。")

            FiveStepFlowFigure()
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryFlow.stepsFigure")
                .accessibilityLabel("五步主链：全桌扫描、反向规划、风险评估、执行、复盘；风险评估不通过时转到防守支路，防守也回到执行。")

            LearnDocText.footnote("风险评估这一步有两条出路：过了才进执行；没过就转去打安全球，安全球同样按执行那一步的标准打。")

            LearnDocText.body("每跳过一步，失败率大约翻一倍。完整五步不是「高手才做的功课」，而是最低必要纪律。")
        }
    }

    // MARK: - 第 1 步

    private var step1: some View {
        LearnDocSectionCard(title: "第 1 步 · 全桌扫描") {
            LearnDocText.body("目的：把整张桌的信息装进脑子——这一步不做任何决策。")

            TheoryNumberedList(steps: [
                .init("绕桌走至少半圈", detail: "别用单一视角看桌。换个角度才看得出哪些球是真的挡住了袋口或走位线。"),
                .init("数球数", detail: "己方还剩几颗、对手还剩几颗。"),
                .init("标出所有球团", detail: "位置、大小、有没有埋住将来要用的关键球。"),
                .init("标出死球与难球", detail: "贴库的、进死角的、必须踢库才能碰到的。"),
                .init("标出袋口球", detail: "在哪儿、对着哪个袋。"),
            ])

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("球数对比、球团清单（含大致优先级）、难球与死球清单、袋口球位置。时间：新手 15 秒 / 进阶 10 秒 / 高手 5 秒。")
            }
        }
    }

    // MARK: - 第 2 步

    private var step2: some View {
        LearnDocSectionCard(title: "第 2 步 · 反向规划") {
            LearnDocText.body("目的：排出一条完整的倒推队列，并选定当前这一杆打哪颗。这一步占整个流程最大一块时间。")

            TheoryNumberedList(steps: [
                .init("先看还剩几颗", detail: "桌上还有 4 颗及以上，走完整倒推；只剩 3 颗及以下，按收官三球来打——尺子更严。"),
                .init("从最后一颗往回排", detail: "最后一颗 ← 关键球 ← 关键球二 ←（球团处理）← 当前这一杆。"),
                .init("定下当前一杆与落位区", detail: "当前一杆打哪颗、打完母球应该停在哪一片区域。"),
            ])

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("倒推队列、当前一杆候选、理想落位区。时间：新手 30 秒 / 进阶 15 秒 / 高手 10 秒。")
            }

            LearnDocText.body("两种边界情况：完全排不出队列，就直接进第 3 步、用更严的尺子评估，多半会转去打安全球；球特别多时（开球后第一杆，十颗以上），退化成「找出关键障碍、选一个最好的起点、给自己留角度」，不强求完整队列。")

            LearnDocText.body("为什么这一步不能省：每打进一颗自己的球，可用来防守的资源就少一颗；一旦决定开打，就必须有完整规划。八球里错掉最后一颗黑球，等于把 87.5% 的可击球送到对手手上，基本就是输局。")
        }
    }

    // MARK: - 第 3 步

    private var step3: some View {
        LearnDocSectionCard(title: "第 3 步 · 风险评估") {
            LearnDocText.body("目的：用三问快速校验——这一杆到底打，还是转防守。")

            TheoryNumberedList(steps: [
                .init("进得了吗？"),
                .init("走得到位吗？"),
                .init("打不进的代价扛得住吗？"),
                .init("会被挡死吗？", detail: "这是硬性下限：只要这一杆有可能把自己弄成连目标球都看不到，就必须转防守，前三问答得再漂亮也不算。"),
            ])

            TheoryMatrixTable(
                columnTitles: ["进球把握", "走位把握", "代价上限"],
                rows: [
                    .init("中段 / 默认", ["≥ 65%", "≥ 55%", "不送 1 颗易球"]),
                    .init("收官阶段", ["≥ 80%", "≥ 75%", "任何失误 = 输局"]),
                    .init("球数劣势", ["-10%", "-10%", "同上"]),
                    .init("决胜局", ["不可下调", "不可下调", "同上"]),
                ],
                labelWidth: 84
            )
            LearnDocText.footnote("「球数劣势」指自己剩的球数只有对手的一半左右，这时前两问可以各放宽 10%。决胜局不放宽。")

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("一个决定：通过就进第 4 步；不通过就转防守线——用更严的尺子重估、修正球数对比、在进攻与防守之间定夺，选了防守就按安全球的标准去执行。时间：新手 10 秒 / 进阶 5 秒 / 高手 3 秒。")
            }
        }
    }

    // MARK: - 第 4 步

    private var step4: some View {
        LearnDocSectionCard(title: "第 4 步 · 执行") {
            LearnDocText.body("目的：按「角度 → 速度 → 旋转」的固定顺序完成这一杆。")

            TheoryNumberedList(steps: [
                .init("先定角度", detail: "先画切线、定切角，用切线法则加上 5/7 + 2/7 的记法估母球碰后往哪走。"),
                .init("再定速度", detail: "用排除法挑档，靠出杆长度而不是「加力气」。"),
                .init("最后定旋转", detail: "默认中杆；确实不加塞走不到，才加最小必要量。"),
            ])
            LearnDocText.footnote("业余最常见的错误是倒着来：先想力度，力度想偏了，瞄准被迫跟着改，结果失位。")

            LearnDocText.body("这一杆属于哪一类，决定你调用哪套打法：单球进位没有障碍、路径上有障碍要绕、要去碰开球团、或者第 3 步已经选了防守——四种情况的处理方式不同，但顺序铁律都一样。")

            LearnDocFormulaNest(title: "出手前的固定动作") {
                LearnDocText.footnote("站位前空挥 2–3 次找速度感 → 站位、架杆长度按速度档调整 → 在杆上预热挥 2–4 次 → 最后一杆平滑加速进接触 → 完整跟进 → 定住 1 秒。收官、安全球、重力度这三种情况严格走完整流程；中段简单球可以压到一半。")
            }

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("这一杆的实际结果，以及母球实际停在哪——后者是下一步复盘的输入。时间：新手 20 秒 / 进阶 10 秒 / 高手 8 秒。")
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
                    .init("差 1 颗球径以内", ["完美，按原计划继续"]),
                    .init("1 颗球径到 1/3 桌长", ["微调：关键球与关键球二不动，改下一杆的瞄准与力度"]),
                    .init("超过 1/3 桌长", ["重做：回第 1 步，整局重新规划"]),
                ],
                labelWidth: 96
            )

            LearnDocText.body("还要看桌面变没变。碰开球团之后，或者打了高杆、低杆之后，可能冒出新的球团、关键球被推走、袋口球被撞下去。只要发生其中任意一种，都必须回第 1 步重新扫桌。")

            LearnDocText.body("最后给自己一秒钟：这次偏差是技术问题（瞄准、速度、旋转），还是决策问题（球选错了、队列排错了）？下次遇到同类局面该怎么改。")

            LearnDocFormulaNest(title: "这一步交出什么") {
                LearnDocText.footnote("下一杆的策略（继续 / 微调 / 重做），以及一条留给自己的学习记录。时间：新手 5 秒 / 进阶 3 秒 / 高手 2 秒。")
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
                .accessibilityLabel("三档总时长条：新手 80 秒、进阶 43 秒、高手 28 秒，按五步分段，反向规划占最长一段。")

            TheoryMatrixTable(
                columnTitles: ["新手", "进阶", "高手"],
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

            LearnDocText.body("比赛常规是一杆 30 到 60 秒。也就是说，新手必须把这套流程练熟才不会超时；熟练之后，完整走完五步只要半分钟左右。")
        }
    }

    // MARK: - 入口与出口

    private var entryAndExit: some View {
        LearnDocSectionCard(title: "什么时候启动、什么时候结束") {
            LearnDocText.body("启动：每次轮到自己上台就从第一步开始。对手犯规、自己拿到自由球时也要完整走五步，不要因为「随便摆」就凭感觉打。打完安全球再回到台前，同样完整走五步。")
            LearnDocText.body("结束：这一杆进了，回到复盘，然后重新扫桌——因为桌面已经变了。自己犯规，整盘交给对手，下次回台时重新启动。全部清完，这一局结束。")
        }
    }

    // MARK: - 违规模式

    private var violations: some View {
        LearnDocSectionCard(title: "跳步会付出什么代价") {
            TheoryMatrixTable(
                columnTitles: ["后果"],
                rows: [
                    .init("跳过扫桌", ["漏看球团和袋口球，中后段直接崩"]),
                    .init("跳过倒推", ["没有队列，到关键球那一杆必崩"]),
                    .init("跳过三问", ["默认进攻，等于把清台机会送给对手"]),
                    .init("跳过固定动作", ["重力度球和收官球最容易垮"]),
                    .init("跳过复盘", ["失位了还按原计划打，一路雪崩"]),
                ],
                labelWidth: 96
            )
            LearnDocText.footnote("每跳一步，失败率大约翻一倍。")
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
            right: "没有队列，前面几颗看着都顺，到关键球那一杆必崩。"
        ),
        .init(
            wrong: "默认这一杆就是要进攻",
            right: "跳过三问，等于把清台机会送给对手。三问里任一不过，就该转防守。"
        ),
        .init(
            wrong: "失位了还照原计划打下去",
            right: "偏差超过三分之一桌长就该整局重做。硬撑只会一路雪崩。"
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
                subtitle: "扫桌标出的球团，要排在关键球之前处理",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "安全球三维度模型",
                subtitle: "三问没过时，转到这条线上来打",
                route: .theoryPage(.t10)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "第 4 步先定角度：碰后母球先沿切线走",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "母球速度分级",
                subtitle: "第 4 步再定速度：用排除法挑档",
                route: .theoryPage(.t04)
            )
            LearnDocTextLink(
                title: "最少加塞原则",
                subtitle: "第 4 步最后定旋转：默认中杆",
                route: .theoryPage(.t09)
            )

            LearnDocText.footnote("还没有绑定专门的跟练题目：先在自己的练习局里强制走完五步，哪怕只剩两颗球也走一遍，最见效。")
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
        ("③ 风险评估", "敢不敢打"),
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

                Text("不通过\n转防守")
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

                Text("每跳一步，失败率约翻一倍")
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

/// 新手 / 进阶 / 高手三档总时长条，按五步分段（非球形，红线 5 合规）。
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
            .init(title: "新手", seconds: TheoryFlowTimeBudget.steps.map(\.novice)),
            .init(title: "进阶", seconds: TheoryFlowTimeBudget.steps.map(\.intermediate)),
            .init(title: "高手", seconds: TheoryFlowTimeBudget.steps.map(\.expert)),
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

                Text("一杆用多久（按五步分段）")
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

                Text("最长那段永远是反向规划")
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
