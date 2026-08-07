import SwiftUI

/// 球理详情页「反向规划」（v30 W3：战术定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T05-backwards-planning.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T05 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.8。
/// - **配图判类**：B 战术决策类 → 非球形抽象图示 `BackwardsPlanningChainFigure`
///   （末端 → 关键球 → 关键球二 → 当前一杆）。⛔ 不画具体球形局面（红线 5）；
///   候选局面登记见真源 §七。
struct TheoryT05View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t05,
                    headline: "清台要从最后一颗球往回倒推",
                    detail: "每次至少想清三步：这一杆、下一杆、再下一杆。每打完一杆，对照实际落点，重新规划。",
                    caption: "桌上还剩两颗及以上时都适用；球越少，越接近把整盘都倒推一遍。"
                )

                whyItWorks
                fiveSteps
                scope
                whenItBreaks

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "反向规划")
        .accessibilityIdentifier("theoryPage_t05")
    }

    // MARK: - 为什么要倒推（T05 §2）

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么要从尾往前想") {
            LearnDocText.body("正向想「下一杆有多少种打法」，选项会爆炸。从最后一颗球倒推，末端约束已经钉死，整条路线就变成一条线往前扫。")

            BackwardsPlanningChainFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT05.chainFigure")
                .accessibilityLabel("反向规划链条：从最后一颗球倒推到关键球、关键球二，再到当前一杆；每杆打完对照落点再重规划。")

            LearnDocText.footnote("箭头方向是「倒推」：先钉死最后一颗要的母球落点，再往前找谁能把母球送过去。")

            LearnDocText.body("把自由度放在前面、把硬约束留在后面——简单问题先消，难问题就不会堆到收官。")
            LearnDocText.body("业余走不深，往往不是不知道倒推，而是没把「至少三步」当成硬纪律。两步以下不算规划；四步以上很难稳定记住。")
        }
    }

    // MARK: - 五步固定解（T05 §5）

    private var fiveSteps: some View {
        LearnDocSectionCard(title: "上台后固定走五步") {
            TheoryNumberedList(steps: [
                .init(
                    "找到最后一颗",
                    detail: "八球 / 中式八球是黑 8；九球是 9 号；散打按自己的决胜球。"
                ),
                .init(
                    "标出它的理想母球落位区",
                    detail: "通常是与该球成大约 15°–45° 切角的几个点——留角度，别把自己逼成正撞。"
                ),
                .init(
                    "找能自然走到那个区的球",
                    detail: "这颗就是关键球：打完它，母球刚好停在最后一颗要的位置。"
                ),
                .init(
                    "再倒推一层，找关键球二",
                    detail: "能为关键球安排好母球的那一颗。"
                ),
                .init(
                    "让当前一杆对齐关键球二",
                    detail: "对不上就改击球点 / 力度，或换一颗当前可打的球。"
                ),
            ])
            LearnDocFormulaNest(title: "打完立刻复盘") {
                LearnDocText.footnote("对照「实际位置 vs 计划位置」。若失位大约达到桌长的三分之一及以上，整套五步重做，不要硬撑原计划。")
            }
            LearnDocText.body("五步想完，再进风险评估：这一杆该不该打。该打再按「角度 → 力度 → 旋转」执行。")
        }
    }

    // MARK: - 适用边界（T05 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候这样用") {
            LearnDocText.body("桌上剩余两颗及以上时永远适用。球数越少，规划深度越接近「整盘」，倒推越值钱。")
            LearnDocText.body("想象力只够一两步时，就只精规划最后三颗，其余球走承转——路过、碰开、给后面让路。")
            LearnDocText.body("中段还有五到七颗时，要混合：从最后三颗往回倒推，从当前一颗往前推，在中段会合。")
        }
    }

    private var whenItBreaks: some View {
        LearnDocSectionCard(title: "什么时候要降级") {
            LearnDocText.body("开局后第一杆球太多，精确倒推做不到——退化为：识别关键障碍、选最优起点、给后面留角度。")
            LearnDocText.body("多球团、关键球被埋、根本清不了时，倒推失效——先称风险，该防守就防守。")
            LearnDocText.body("桌上只剩两颗及以下：规划深度等于剩余球数，退化成「挑唯一一种打法」。")
        }
    }

    // MARK: - 常见误区（contracts T05.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "正向规划：「下一杆有好多选择」",
            right: "选项一多就乱。从最后一颗倒推，末端约束已知，路线才会收成一条线。"
        ),
        .init(
            wrong: "只想两步就开打",
            right: "深度不够，关键球阶段几乎必崩。硬纪律是至少三步：这一杆、下一杆、再下一杆。"
        ),
        .init(
            wrong: "失位了还硬撑原计划",
            right: "失位达到大约三分之一桌长，就整套重规划。按旧计划硬打，只会雪崩。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "先过三问再决定打不打",
                destination: "风险报酬决策矩阵：进得了吗、走得到位吗、代价扛得住吗",
                route: .theoryPage(.t08)
            )

            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "倒推链条上，真正决定成败的那一颗",
                route: .theoryPage(.t06)
            )
            LearnDocTextLink(
                title: "球团管理",
                subtitle: "球团是倒推里的先决约束，要排在关键球之前",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "标落位区时，切线告诉你母球碰后会先往哪走",
                route: .theoryPage(.t03)
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目：开局后先在脑子里报出后三杆顺序，再开打，最见效。")
        }
    }
}

// MARK: - 抽象图示：倒推链条

/// 末端 → 关键球 → 关键球二 → 当前一杆（非球形，红线 5 合规）。
private struct BackwardsPlanningChainFigure: View {
    private static let nodes = [
        ("最后一颗", "钉死落位区"),
        ("关键球", "送母球过去"),
        ("关键球二", "再倒推一层"),
        ("当前一杆", "对齐计划"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.20
            let cardH = h * 0.38
            let xs = [w * 0.14, w * 0.38, w * 0.62, w * 0.86]
            let y = h * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("倒推方向 →")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.50, y: h * 0.12)

                ForEach(0..<(Self.nodes.count - 1), id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: xs[i] + cardW * 0.42, y: y))
                        p.addLine(to: CGPoint(x: xs[i + 1] - cardW * 0.42, y: y))
                    }
                    .stroke(Color.btPrimary, lineWidth: 1.5)
                    // 箭头头
                    Path { p in
                        let tip = CGPoint(x: xs[i + 1] - cardW * 0.42, y: y)
                        p.move(to: tip)
                        p.addLine(to: CGPoint(x: tip.x - 6, y: tip.y - 4))
                        p.addLine(to: CGPoint(x: tip.x - 6, y: tip.y + 4))
                        p.closeSubpath()
                    }
                    .fill(Color.btPrimary)
                }

                ForEach(Array(Self.nodes.enumerated()), id: \.offset) { i, node in
                    VStack(spacing: 4) {
                        Text(node.0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(i == 0 ? Color.btPrimary : Color.btText)
                        Text(node.1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 4)
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(i == 0 ? Color.btPrimary.opacity(0.14) : Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(i == 0 ? Color.btPrimary.opacity(0.7) : Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: xs[i], y: y)
                }

                Text("打完对照落点 · 失位约 1/3 桌长 → 整套重做")
                    .font(.btCaption2)
                    .foregroundStyle(.btWarning)
                    .multilineTextAlignment(.center)
                    .position(x: w * 0.50, y: h * 0.86)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT05View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT05View() }
        .preferredColorScheme(.dark)
}
#endif
