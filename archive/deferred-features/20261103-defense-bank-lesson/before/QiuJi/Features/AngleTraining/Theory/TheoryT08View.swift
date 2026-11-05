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
/// - 2026-10-16 核查：撤下缺少实证的分级概率阈值，改为比较方案的条件。
///   依据与上游差异见 `docs/research/20261016-理文章重写与理论核查.md`。
struct TheoryT08View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t08,
                    headline: "不只看能不能进，也看打完会怎样",
                    detail: "进球有多大把握，进了能走到哪里，没进会留下什么局面？把这三件事放在一起，再比较进攻、防守和其他路线。",
                    caption: "三问用来帮助选择，不是任一项拿不准就自动判防守。防守本身也有成功率和失败代价。"
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
            LearnDocText.body("看到一颗能进的球，很容易把注意力全放在袋口上。但这一杆的价值，还包括进球后的衔接，以及失误后留给对手的机会。同样难度的球，打丢后的局面不同，选择也可能不同。")

            RiskRewardZoneFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT08.zoneFigure")

            LearnDocText.footnote("图中是相对比较：把握较高、失败代价较小，通常更有利于进攻；其他区域提醒你多比较方案。虚线不是概率及格线，图里也没有包含清台收益和防守质量，不能单凭所在区域决定打法。")

            LearnDocText.body("熟悉以后，这三问可以成为上台时的短检查。遇到球团、收尾或复杂防守，再多花一点时间，把可能的结果想完整。")
            LearnDocText.body("判断的目标不是永远避开风险，而是在现有选择里，找到更有机会赢下这局、又能按自己的能力执行的一杆。")
        }
    }

    // MARK: - 三问清单（T08 §5 固定解）+ 流程图

    private var threeQuestions: some View {
        LearnDocSectionCard(title: "开打前的三问") {
            TheoryNumberedList(steps: [
                .init("进得了吗？", detail: "用自己练过的同类球作参照，考虑距离、角度、杆法和当前状态，不只凭这一眼的信心。"),
                .init("走得到位吗？", detail: "进球后能否进入可用区域？走过或走不到时，是否还有下一杆？最后一颗则重点看母球落袋等风险。"),
                .init("打不进的代价多大？", detail: "看母球和目标球可能留下的位置，对手是否有直接进攻、清台或轻松反防的机会。"),
            ])

            ThreeQuestionFlowFigure()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT08.flowFigure")

            LearnDocFormulaNest(title: "别漏掉被挡住的风险") {
                LearnDocText.footnote("进球后看不到下一颗，会明显影响衔接，应尽量避开。但这仍是比较方案的一部分；能否接受，要看替代路线和整局后果，不能独立当成无例外的禁令。")
            }
            LearnDocText.body("最后再问一句：有没有收益接近、但更容易完成的选择？同时也检查防守是否真的能做成，别把想象中的好防守与真实的进攻风险作比较。")
        }
    }

    // MARK: - 把握与代价的比较

    private var thresholds: some View {
        LearnDocSectionCard(title: "把握从哪里来") {
            TheoryMatrixTable(
                columnTitles: ["看什么", "怎么校准", "怎样使用"],
                rows: [
                    .init("进球", ["同类球表现", "重复练习并记录", "别只记成功的一杆"]),
                    .init("走位", ["进球后的落位", "记录可用区域", "把两项一起评估"]),
                    .init("失败代价", ["对手接手局面", "回看实际球位", "考虑对手能力"]),
                    .init("替代方案", ["其他进攻与防守", "同样检查后果", "比较整杆价值"]),
                ]
            )
            LearnDocText.footnote("没有适用于所有水平、球形和规则的统一进攻百分比。记录是帮助认识自己，不是把少量练习结果当成精确预测。")
            LearnDocFormulaNest(title: "收尾时多看后果") {
                LearnDocText.footnote("剩球少时，一次失误可能留下直接收尾机会。检查母球落袋、失位和对手接手路线，比机械抬高一个概率门槛更有用。")
            }
        }
    }

    // MARK: - 打不进的代价有多大（T08 §4 Tom Ross 量化）

    private var costOfMissing: some View {
        LearnDocSectionCard(title: "打不进的代价有多大") {
            LearnDocText.body("失败代价要落到具体球位上：打丢后目标球会不会停在袋口，母球会留在开阔处还是被挡住，对手最容易从哪颗开始？")
            LearnDocFormulaNest(title: "最后一颗 8 号球") {
                LearnDocText.footnote("打丢黑 8 后，对手可能获得很好的机会，也可能仍被球团限制。要看剩余球的分布和母球位置，不能把某个球数比例当成输局概率。")
            }
            LearnDocText.body("本方球逐渐减少，能用于遮挡和衔接的资源也会变化。防守应提前比较，而不是等进攻线路已经断了才临时寻找。")
        }
    }

    // MARK: - 什么时候可以松一点（T08 §4 球类调整 + 球数优势）

    private var whenToLoosen: some View {
        LearnDocSectionCard(title: "哪些因素会改变选择") {
            LearnDocText.body("打法要随局面变化。进攻成功后能否清台，防守能否限制对手，以及失误后是否还有机会，都可能改变选择。")
            LearnDocText.body("八球与九球的合法目标和击球顺序不同，打丢后留给对手的选择也不同。两种球都要判断具体结果，不能假定九球打丢就会自然变成防守。")
            LearnDocText.body("球数只是线索。对手球多可能选择更多，也可能问题球更多；自己球少可能接近收尾，也可能缺少防守资源。不能只按球数倍数降低进攻门槛。")
        }
    }

    // MARK: - 常见误区（contracts T08.common_errors 三条展开）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "决胜局只问「能不能进」，跳过失败代价",
            right: "紧张时可以先停一下，把走位和失手后的局面也想完，再决定这一杆。"
        ),
        .init(
            wrong: "为了完美走位去冒险",
            right: "比较宽一些的可用落位区，别只盯一个完美点。但一般位置是否还能继续，也要事先看清。"
        ),
        .init(
            wrong: "永远只问第三问，能防就防",
            right: "防守也可能失误或让对手反制。训练时可以专门练不熟悉的进攻，扩大能力；比赛时再按真实把握比较方案。"
        ),
    ]

    // MARK: - 页尾互链（组件规范 §六：「相关页面」.btTitle + PracticeCTA ≤2 + 文字链）

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "把防守也放进选择里",
                destination: "防守：反解安全球，看能藏到什么程度",
                route: .snookerTactics
            )

            LearnDocTextLink(
                title: "安全球三维度模型",
                subtitle: "从距离、库位和障碍比较防守方案",
                route: .theoryPage(.t10)
            )
            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "哪一颗球值得为它冒风险",
                route: .theoryPage(.t06)
            )
            LearnDocText.footnote("复盘一杆球时，分别记录当时的判断、实际结果和可选方案。判断合理仍可能失误，偶然打进也不代表原来的选择最好。")
        }
    }
}

// MARK: - 抽象图示 ①：三问判定流程

/// 三问判定流程图（非球形抽象图示，红线 5 合规）。
///
/// 只画「依次考虑三问，并与其他方案比较」的决策顺序，
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
                    Text("继续")
                        .font(.btCaption2)
                        .foregroundStyle(.btPrimary)
                        .position(x: nodeX - 14, y: (from.y + to.y) / 2)
                }

                // 横向「不过」链：三问各自右出 → 汇流 → 安全球。
                ForEach(0..<3, id: \.self) { i in
                    let from = CGPoint(x: nodeX + nodeW / 2, y: ys[i])
                    FlowArrow(from: from, to: CGPoint(x: busX, y: ys[i]),
                              color: .btWarning, showsHead: false)
                    Text("再看")
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

                FlowNode(text: "选进攻", tint: .btPrimary, emphasized: true)
                    .frame(width: nodeW * 0.62, height: nodeH)
                    .position(x: nodeX, y: outcomeY)

                FlowNode(text: "比较\n其他方案", tint: .btWarning, emphasized: true)
                    .frame(width: w * 0.28, height: h * 0.24)
                    .position(x: safetyX, y: safetyY)

                // 硬性项：无条件直连安全球（虚线，不进三问顺序）。
                Path { p in
                    p.move(to: CGPoint(x: safetyX, y: safetyY + h * 0.14))
                    p.addLine(to: CGPoint(x: safetyX, y: h * 0.74))
                }
                .stroke(Color.btWarning.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                Text("含被挡风险")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .multilineTextAlignment(.center)
                    .position(x: safetyX, y: h * 0.82)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("依次考虑进球、走位和失败代价；有疑问时比较其他进攻或防守，也要考虑被挡风险。完成比较后选择打法。")
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

                Text("较有利")
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btPrimary)
                    .position(x: (plot.minX + midX) / 2, y: (plot.minY + midY) / 2)

                Text("再比方案")
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
        .accessibilityLabel("风险与把握的相对比较：把握高、失败代价小通常较有利；其余区域需进一步比较方案。虚线不是概率及格线。")
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
