import SwiftUI

/// 球理详情页「风险报酬决策矩阵」（v30 W1 试点：战术决策模板样板；返工 r1 加抽象图示 + 风格收敛）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T08-risk-reward-matrix.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T08 条目（`thresholds` / `common_errors` /
///   `tom_ross_quantification`）。逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §五 T08 对照表。
/// - **配图策略（r1 改）**：⛔ 受 v30 红线 5 约束（AI 不生成球形坐标，战术示意局面必须
///   人工编排台录制），本页**不画任何具体球形局面**；改用两张**非球形抽象图示**，
///   走 `GeometryReader` + 设计 token 色（范式同现有学页打点盘 / 曲线图）：
///   ① `ThreeQuestionFlowFigure` 三问判定流程；② `RiskRewardZoneFigure` 风险 / 把握分区。
///   候选真实局面图已按要求登记为文字描述，交人工录制（见返工汇报「待人工录制」）。
/// - ⚠️ **已登记的上游不一致**：16 正文 §4 阈值表与 contracts `thresholds.*.max_loss` 对
///   新手 / 进阶的「失败代价上限」给出不同措辞。本页取 16 正文（正文真源），差异回传 16。
struct TheoryT08View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t08,
                    headline: "每一杆开打前先过三问",
                    detail: "进得了吗？走得到位吗？打不进的代价扛不扛得住？有一问不过关，就转去打安全球。",
                    caption: "三条问题本身是不变的，及格线因人而异——新手要定得高，高手可以定得低。"
                )

                whyItWorks
                threeQuestions
                thresholds
                costOfMissing
                whenToLoosen

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "风险报酬决策矩阵")
        .accessibilityIdentifier("theoryPage_t08")
    }

    // MARK: - 为什么这三问管用（T08 §2 直觉）+ 分区图

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么这三问管用") {
            LearnDocText.body("业余选手几乎从来不问第三问，结果常常两头亏：球没进，还把一个好局面送了出去。")

            RiskRewardZoneFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT08.zoneFigure")

            LearnDocText.footnote("两根轴都是相对的：把握是自己的真实命中率，代价是打丢之后留给对手的局面。只有「把握够高、代价够小」这一块才该开打，其余三块都该转安全球。分界线的位置就是下文的及格线，因人而异。")

            LearnDocText.body("三问把「凭感觉打」压缩成一个三秒钟能过一遍的流程——记得住、做得到、打完还能复盘。")
            LearnDocText.body("看清球形、看出球路只是清台能力的一半；另一半就是把风险和回报称一称，再决定这一杆到底打不打。")
        }
    }

    // MARK: - 三问清单（T08 §5 固定解）+ 流程图

    private var threeQuestions: some View {
        LearnDocSectionCard(title: "开打前的三问") {
            TheoryNumberedList(steps: [
                .init("进得了吗？", detail: "这一杆的进球把握够不够。不够，就不要开打。"),
                .init("走得到位吗？", detail: "就算进了，母球能不能停到下一杆需要的位置上。"),
                .init("打不进的代价多大？", detail: "万一没进，留给对手的是什么局面。"),
            ])

            ThreeQuestionFlowFigure()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT08.flowFigure")

            LearnDocFormulaNest(title: "还有一条硬性的") {
                LearnDocText.footnote("会不会把自己挡死、连目标球都看不到？会 —— 就必须改打安全球，这一条没有例外。")
            }
            LearnDocText.body("三问都过了，再多问一句：还有没有更稳、回报又差不多的选择？有就换过去。")
        }
    }

    // MARK: - 及格线参考（T08 §4 阈值表 + contracts thresholds）

    private var thresholds: some View {
        LearnDocSectionCard(title: "及格线定在哪") {
            TheoryMatrixTable(
                columnTitles: ["新手", "进阶", "高手"],
                rows: [
                    .init("进球把握", ["≥ 80%", "≥ 65%", "≥ 50%"]),
                    .init("走位把握", ["≥ 70%", "≥ 55%", "≥ 40%"]),
                    .init("代价上限", ["不让对手有袋口连击", "不送一颗易球", "不送对手清台机会"]),
                    .init("硬性下限", ["不被挡死", "不被挡死", "不被挡死"]),
                ]
            )
            LearnDocText.footnote("这张表是参考起点，要按自己真实的命中率校准，不是照抄。")
            LearnDocFormulaNest(title: "收官阶段要抬高") {
                LearnDocText.footnote("打到最后三颗球时：进球把握 80%、走位把握 75%，任何一次失误基本就是输局。")
            }
        }
    }

    // MARK: - 打不进的代价有多大（T08 §4 Tom Ross 量化）

    private var costOfMissing: some View {
        LearnDocSectionCard(title: "打不进的代价有多大") {
            LearnDocText.body("第三问最容易被当成「感觉」糊过去，其实它有具体数字。")
            LearnDocFormulaNest(title: "最后一颗 8 号球") {
                LearnDocText.footnote("最后那颗 8 号一旦打丢，对手接手时大约 87.5% 的球是他能直接打的——基本等于输局。")
            }
            LearnDocText.body("而且越往后打，想临时补一手防守就越难。决胜局里想起这个数字，就该把「绝不冒险」当成硬纪律。")
        }
    }

    // MARK: - 什么时候可以松一点（T08 §4 球类调整 + 球数优势）

    private var whenToLoosen: some View {
        LearnDocSectionCard(title: "什么时候可以松一点") {
            LearnDocText.body("三问是每一杆都要过的，不是只在难球上才做。松紧的调整只有两处：")
            LearnDocText.body("一是球种：8 球比 9 球更看重第三问——9 球打丢经常还能变成一次防守，8 球往往不能。")
            LearnDocText.body("二是球数：如果台上对手的球数已经是自己的两倍以上，第一问的及格线可以往下放大约 10%。这种局面下，哪怕成功率不高的进攻，通常也比防守划算。")
        }
    }

    // MARK: - 常见误区（contracts T08.common_errors 三条展开）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "决胜局只问「能不能进」，跳过失败代价",
            right: "压力越大越容易只剩第一问。这不是新手专属的错，是顶级选手也会犯的失败模式。"
        ),
        .init(
            wrong: "为了完美走位去冒险",
            right: "宁可稳稳进球、拿个一般的位置，也别为了完美位置把球打丢——一般的位置至少还留着防守这条退路。"
        ),
        .init(
            wrong: "永远只问第三问，能防就防",
            right: "全程只防守会挡住自己进步。练球时应该主动把前两问的及格线调高，逼自己去打该打的球。"
        ),
    ]

    // MARK: - 页尾互链（组件规范 §六：「相关页面」.btTitle + PracticeCTA ≤2 + 文字链）

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "三问没过，这一手怎么藏",
                destination: "防守：反解安全球，看能藏到什么程度",
                route: .snookerTactics
            )

            LearnDocText.footnote("相关球理：安全球三维度模型、关键球原理（即将上线）——前者讲三问没过之后怎么挑安全球，后者讲哪一颗球值得为它冒风险。")
            LearnDocText.footnote("这一条还没有绑定专门的跟练题目，先拿自己最近打丢的球回过来走一遍三问，最见效。")
        }
    }
}

// MARK: - 抽象图示 ①：三问判定流程

/// 三问判定流程图（非球形抽象图示，红线 5 合规）。
///
/// 只画「三问顺序 + 任一问不过 → 改打安全球 + 挡死是无条件硬性项」这几件正文已有的事，
/// ⛔ 不引入任何球位、坐标、概率数字。布局按 `GeometryReader` 比例算，色只取设计 token。
private struct ThreeQuestionFlowFigure: View {
    private static let questions = ["① 进得了吗？", "② 走得到位吗？", "③ 代价扛得住吗？"]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let nodeW = w * 0.44
            let nodeH = h * 0.15
            let nodeX = w * 0.30
            let ys = [h * 0.12, h * 0.38, h * 0.64]
            let busX = w * 0.62
            let safetyX = w * 0.82
            let safetyY = h * 0.38
            let outcomeY = h * 0.90

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                // 竖向「过」链：问 1 → 问 2 → 问 3 → 开打。
                ForEach(0..<3, id: \.self) { i in
                    let from = CGPoint(x: nodeX, y: ys[i] + nodeH / 2)
                    let to = CGPoint(x: nodeX, y: (i < 2 ? ys[i + 1] : outcomeY) - nodeH / 2)
                    FlowArrow(from: from, to: to, color: .btPrimary)
                    Text("过")
                        .font(.btCaption2)
                        .foregroundStyle(.btPrimary)
                        .position(x: nodeX - 14, y: (from.y + to.y) / 2)
                }

                // 横向「不过」链：三问各自右出 → 汇流 → 安全球。
                ForEach(0..<3, id: \.self) { i in
                    let from = CGPoint(x: nodeX + nodeW / 2, y: ys[i])
                    FlowArrow(from: from, to: CGPoint(x: busX, y: ys[i]),
                              color: .btWarning, showsHead: false)
                    Text("不过")
                        .font(.btCaption2)
                        .foregroundStyle(.btWarning)
                        .position(x: (from.x + busX) / 2, y: ys[i] - 11)
                }
                Path { p in
                    p.move(to: CGPoint(x: busX, y: ys[0]))
                    p.addLine(to: CGPoint(x: busX, y: ys[2]))
                }
                .stroke(Color.btWarning, lineWidth: 1.5)
                FlowArrow(from: CGPoint(x: busX, y: safetyY),
                          to: CGPoint(x: safetyX - w * 0.08, y: safetyY),
                          color: .btWarning)

                ForEach(Array(Self.questions.enumerated()), id: \.offset) { i, text in
                    FlowNode(text: text, tint: .btPrimary)
                        .frame(width: nodeW, height: nodeH)
                        .position(x: nodeX, y: ys[i])
                }

                FlowNode(text: "开打", tint: .btPrimary, emphasized: true)
                    .frame(width: nodeW * 0.62, height: nodeH)
                    .position(x: nodeX, y: outcomeY)

                FlowNode(text: "改打\n安全球", tint: .btWarning, emphasized: true)
                    .frame(width: w * 0.28, height: h * 0.24)
                    .position(x: safetyX, y: safetyY)

                // 硬性项：无条件直连安全球（虚线，不进三问顺序）。
                Path { p in
                    p.move(to: CGPoint(x: safetyX, y: safetyY + h * 0.14))
                    p.addLine(to: CGPoint(x: safetyX, y: h * 0.74))
                }
                .stroke(Color.btWarning.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                Text("硬性：被挡死")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
                    .position(x: safetyX, y: h * 0.82)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("三问判定流程：进得了吗、走得到位吗、代价扛得住吗，三问全过才开打；任一问不过或会被挡死，改打安全球。")
    }
}

/// 流程图节点（token 色，无球形）。
private struct FlowNode: View {
    let text: String
    let tint: Color
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .font(.btCaption)
            .foregroundStyle(emphasized ? tint : Color.btText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .fill(emphasized ? tint.opacity(0.14) : Color.btBGSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BTRadius.sm)
                    .stroke(emphasized ? tint.opacity(0.7) : Color.btSeparator, lineWidth: 1)
            )
    }
}

/// 流程箭头（直线 + 可选箭头头）。
private struct FlowArrow: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    var showsHead: Bool = true

    var body: some View {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        let ux = dx / len, uy = dy / len
        let head: CGFloat = 6
        return ZStack {
            Path { p in p.move(to: from); p.addLine(to: to) }
                .stroke(color, lineWidth: 1.5)
            if showsHead {
                Path { p in
                    p.move(to: to)
                    p.addLine(to: CGPoint(x: to.x - ux * head - uy * head * 0.6,
                                          y: to.y - uy * head + ux * head * 0.6))
                    p.addLine(to: CGPoint(x: to.x - ux * head + uy * head * 0.6,
                                          y: to.y - uy * head - ux * head * 0.6))
                    p.closeSubpath()
                }
                .fill(color)
            }
        }
    }
}

// MARK: - 抽象图示 ②：风险 / 把握分区

/// 风险（打不进的代价）× 把握（进球 + 走位）分区示意（非球形抽象图示，红线 5 合规）。
///
/// 只表达正文原有断言：把握够高 **且** 代价够小 → 开打；其余 → 安全球；
/// 分界线位置 = 及格线，因人而异。⛔ 两轴不标数字（正文没有给连续标度）。
private struct RiskRewardZoneFigure: View {
    var body: some View {
        GeometryReader { geo in
            let padL = geo.size.width * 0.13
            let padB = geo.size.height * 0.16
            let padT = geo.size.height * 0.08
            let padR = geo.size.width * 0.05
            let plot = CGRect(x: padL, y: padT,
                              width: geo.size.width - padL - padR,
                              height: geo.size.height - padT - padB)
            let midX = plot.minX + plot.width * 0.45
            let midY = plot.minY + plot.height * 0.45

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))

                // 该防守区（整块底）+ 该打区（左上角块）。
                Rectangle()
                    .fill(Color.btWarning.opacity(0.10))
                    .frame(width: plot.width, height: plot.height)
                    .offset(x: plot.minX, y: plot.minY)
                Rectangle()
                    .fill(Color.btPrimary.opacity(0.18))
                    .frame(width: midX - plot.minX, height: midY - plot.minY)
                    .offset(x: plot.minX, y: plot.minY)

                // 及格线（两条分界虚线）。
                Path { p in
                    p.move(to: CGPoint(x: midX, y: plot.minY))
                    p.addLine(to: CGPoint(x: midX, y: plot.maxY))
                    p.move(to: CGPoint(x: plot.minX, y: midY))
                    p.addLine(to: CGPoint(x: plot.maxX, y: midY))
                }
                .stroke(Color.btTextTertiary.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // 坐标轴。
                Path { p in
                    p.move(to: CGPoint(x: plot.minX, y: plot.minY))
                    p.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                    p.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                }
                .stroke(Color.btSeparator, lineWidth: 1.5)

                Text("开打")
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btPrimary)
                    .position(x: (plot.minX + midX) / 2, y: (plot.minY + midY) / 2)

                Text("改打安全球")
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btWarning)
                    .position(x: (midX + plot.maxX) / 2, y: (midY + plot.maxY) / 2)

                Text("把握\n高")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.trailing)
                    .position(x: plot.minX - padL * 0.52, y: plot.minY + plot.height * 0.14)
                Text("低")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: plot.minX - padL * 0.52, y: plot.maxY - plot.height * 0.06)
                Text("打不进的代价 →")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: plot.midX, y: plot.maxY + padB * 0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("风险与把握分区示意：把握高、代价小的一块才开打，其余区域改打安全球；分界线就是及格线，因人而异。")
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        TheoryT08View()
    }
}

#Preview("Dark") {
    NavigationStack {
        TheoryT08View()
    }
    .preferredColorScheme(.dark)
}
#endif
