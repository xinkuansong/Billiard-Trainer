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
                    detail: "先想最后一颗球从哪里打最合适，再找哪颗球能把母球送到那里。这样回头看当前一杆，就更容易知道该留什么角度、哪些球还不能先打。",
                    caption: "球少时可以连起整段顺序；球多时先选收尾方案，再从当前局面找路接上。"
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
            LearnDocText.body("只看眼前最容易进的球，可能连续打进几颗，却把最后的走位路线打没了。倒推先回答「最后需要站在哪里」，让前面每一杆有一个明确的去处。它帮助筛选路线，不保证只剩唯一答案。")

            BackwardsPlanningChainFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT05.chainFigure")
                .accessibilityLabel("反向规划链条：从最后一颗球倒推到关键球、关键球二，再到当前一杆；每杆打完对照落点再重规划。")

            LearnDocText.footnote("箭头表示思考顺序：从最后一颗的合适落位区，往前找能衔接它的球。实际击球顺序与箭头相反。")

            LearnDocText.body("先留住那些能连接困难位置的球，别因为它们好进就提前清掉。选择多的时候处理难题，通常比只剩一条路线时再补救更从容。")
            LearnDocText.body("练习可以从三杆衔接开始：这一杆把母球送到哪里，下一杆需要什么角度，再下一杆能否接上。三杆是练习方法，不是必须遵守的深度；球形复杂时先抓关键衔接，简单时可以看得更远。")
        }
    }

    // MARK: - 五步固定解（T05 §5）

    private var fiveSteps: some View {
        LearnDocSectionCard(title: "把倒推分成五步") {
            TheoryNumberedList(steps: [
                .init(
                    "找到最后一颗",
                    detail: "先确定收尾目标。八球通常围绕黑 8 安排收尾；九球还要遵守击球顺序，不能任意挑选关键球。"
                ),
                .init(
                    "标出它的理想母球落位区",
                    detail: "选进球可靠、母球不容易落袋的位置。最后一颗不再需要为下一球留角，正撞也可能很好；前面的衔接球才要按后续路线留角度。"
                ),
                .init(
                    "找能自然走到那个区的球",
                    detail: "这颗可以作为收尾的关键球。优先考虑走位短、落位区宽，而且容易接近的选择。"
                ),
                .init(
                    "再倒推一层，找关键球二",
                    detail: "也就是能为关键球留出合适角度的前一颗。关键球再好，也要有办法走到它需要的位置。"
                ),
                .init(
                    "让当前一杆对齐关键球二",
                    detail: "检查当前路线能否接上这段顺序。接不上时，比较其他合法击球、落位区或收尾方案，不必勉强原计划。"
                ),
            ])
            LearnDocFormulaNest(title: "打完立刻复盘") {
                LearnDocText.footnote("每杆后都看实际角度和通道。只偏一点也可能失去走位角度，偏得较远也可能仍有好路线；是否重排，看衔接有没有改变，不看固定距离。")
            }
            LearnDocText.body("有了路线，再比较进攻与防守的收益和代价。准备击球前，把进球线、母球路线、力度和旋转一起确认好，避免趴下后临时换主意。")
        }
    }

    // MARK: - 适用边界（T05 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候这样用") {
            LearnDocText.body("球少、通道清楚时，适合把剩余顺序完整连起来。别只记球号，还要记住每颗球需要的母球位置和出球方向。")
            LearnDocText.body("还不习惯看多杆时，先练最后几颗的衔接。其他球也要有用途：接近关键球、处理障碍，或为下一杆保留选择。")
            LearnDocText.body("中盘可以两头一起看：从收尾往回倒推，从当前往前寻找稳妥路线，在容易衔接的位置接起来。")
        }
    }

    private var whenItBreaks: some View {
        LearnDocSectionCard(title: "什么时候先看眼前的问题") {
            LearnDocText.body("开局后球多、相互遮挡时，不必假装已经算清每一杆。先找问题球和可用通道，保留一个暂定收尾方案，随着局面变化再细化。")
            LearnDocText.body("球团没法安全处理，或关键衔接暂时不可达时，倒推仍能帮你看清缺什么。此时可以先改善局面或防守，不必把清台当成唯一目标。")
            LearnDocText.body("只剩两颗时，仍要比较不同袋口、落位区和母球路线。球少不代表打法只有一种。")
        }
    }

    // MARK: - 常见误区（contracts T05.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "每杆只挑眼前最好进的球",
            right: "先看它在后续路线里有没有用途。正向寻找机会与反向检查收尾，可以一起使用。"
        ),
        .init(
            wrong: "记住了顺序，却没想过落位",
            right: "球号顺序还不够。用三杆衔接练习，把每一杆需要的角度和落位区连起来。"
        ),
        .init(
            wrong: "失位了还硬撑原计划",
            right: "下一杆的角度或通道一变，就重新比较方案，不必等偏出某个距离。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "用三问比较进攻与防守",
                destination: "风险报酬决策矩阵：进得了吗、走得到位吗、代价扛得住吗",
                route: .theoryPage(.t08)
            )

            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "选择并保留容易衔接收尾的球",
                route: .theoryPage(.t06)
            )
            LearnDocTextLink(
                title: "球团管理",
                subtitle: "规划中提前考虑问题球和处理时机",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "标落位区时，切线告诉你母球碰后会先往哪走",
                route: .theoryPage(.t03)
            )

            LearnDocText.footnote("练习时先说出计划的顺序和落位区，打完再比较实际结果。先把短段衔接做稳定，再增加规划长度。")
        }
    }
}

// MARK: - 抽象图示：倒推链条

/// 末端 → 关键球 → 关键球二 → 当前一杆（非球形，红线 5 合规）。
private struct BackwardsPlanningChainFigure: View {
    private static let nodes = [
        ("最后一颗", "选择落位区"),
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

                Text("每杆核对落位 · 衔接改变时重新规划")
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
