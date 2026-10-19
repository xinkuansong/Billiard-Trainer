import SwiftUI

/// 球理详情页「关键球原理」（v30 W3：战术定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T06-key-ball-doctrine.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T06 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.9。
/// - **配图判类**：B 战术决策类 → 非球形抽象图示 `KeyBallLayerFigure`
///   （最后一颗 ← 关键球 ← 关键球二）。⛔ 不画具体球形局面（红线 5）。
struct TheoryT06View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t06,
                    headline: "给最后一颗，留一颗好衔接的球",
                    detail: "这里说的关键球，是用来为最后一颗安排母球位置的球；再往前，负责衔接关键球的那颗，称为关键球二。选好这两段，收尾就不必临时寻找困难路线。",
                    caption: "关键球是一颗球在计划中的用途。局面变了，它也可以重新选择。"
                )

                whyItWorks
                fourQuestions
                hangers
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "关键球原理")
        .accessibilityIdentifier("theoryPage_t06")
    }

    // MARK: - 为什么关键球决定成败（T06 §2）

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "好进，还要好走") {
            LearnDocText.body("一颗球看起来容易进，不代表适合留到最后衔接。好的关键球，既容易接近，又能用熟悉的路线把母球送到收尾位置。反过来，一颗提前打掉的简单球，也可能正是后面最需要的桥梁。")

            KeyBallLayerFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT06.layerFigure")
                .accessibilityLabel("关键球双层结构：先选最后一颗的落位区，关键球把母球送过去，关键球二为关键球留出合适角度。")

            LearnDocText.footnote("从上往下看需要什么位置，从下往上检查能否衔接。两层都要看进球线和母球路线。")

            LearnDocText.body("收尾打丢时，不妨往前多看一杆：是最后的瞄准出了问题，还是之前已经留下了难球？分别检查关键球与关键球二，再把它们连起来验证，比只责怪最后一杆更有帮助。")
        }
    }

    // MARK: - 四问（T06 §5）

    private var fourQuestions: some View {
        LearnDocSectionCard(title: "选关键球的四问") {
            LearnDocText.body("用下面四问比较候选球。没有各方面都理想的选择时，优先保留自己能稳定完成、失位后仍有余地的方案。")
            TheoryNumberedList(steps: [
                .init(
                    "可达吗？",
                    detail: "前面的球能否把母球送到它需要的位置？不要只看打完它很好走，却忽略根本走不到它的进位区。"
                ),
                .init(
                    "角度自然吗？",
                    detail: "打完它，能否用熟悉的杆法走到收尾区域？最后一颗以进球可靠、避免母球落袋为先，不必刻意留一个固定切角。"
                ),
                .init(
                    "有保险吗？",
                    detail: "母球稍微走过或走不到，是否仍有合适袋口和可控路线？落位区越宽，通常越容易重复。"
                ),
                .init(
                    "不破局吗？",
                    detail: "母球会不会撞动已经安排好的球、被挡住或落袋？需要碰球时，能否预计后果并留下备用球？"
                ),
            ])
            LearnDocFormulaNest(title: "关键球二怎么选") {
                LearnDocText.footnote("把上面四问里的「最后一颗」换成「关键球」，重做一遍。")
            }
            LearnDocText.body("停球或短距离走位，常能让收尾更简单，但不必强求连续停球。有角度时，母球仍会沿相应路线离开；应选择容易控制的衔接，而不是为了套杆法勉强找位。")
        }
    }

    // MARK: - 袋口球（T06 §4 hangers 修订）

    private var hangers: some View {
        LearnDocSectionCard(title: "袋口球能不能当关键球") {
            LearnDocText.body("袋口球容易进，常适合作为过渡球或保险球，也可能成为关键球。关键在于从哪里接近、需要把母球送到哪里，不能只凭球离袋口近就肯定或否定它。")
            TheoryMatrixTable(
                columnTitles: ["适合留下", "需要谨慎"],
                rows: [
                    .init("接近位置", ["容易走到合适一侧", "进位区被挡或很窄"]),
                    .init("碰后路线", ["方向熟悉，力度好控", "易落袋或需复杂碰库"]),
                    .init("后续衔接", ["能连到下一颗", "只有进球，没有走位"]),
                ]
            )
            LearnDocText.footnote("自然滚动、约半球厚度时，可以借助 30° 法则估计碰后方向。沿库或沿对角线接近是可练习的情形，不是仅有的两种合法选择，也不保证固定落位精度。")
            LearnDocText.body("是否早打，要看它的用途。它可能连接收尾，也可能为碰开球团提供保险；清台机会不足时，还可能保留挡袋或防守价值。先想清用途，再决定顺序。")
        }
    }

    // MARK: - 适用边界（T06 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("球少时，这种衔接关系最容易看清；球多时也可以先选一个候选收尾。八球可以在本方球中比较选择，九球则要在规定击球顺序下安排相应位置。")
            LearnDocText.body("关键球选择会变——前面几杆若失位，原计划可能要换。每杆复盘后重新评估它是否仍合适。")
            LearnDocText.body("没有能顺利衔接的球时，先考虑怎样改善局面，并与防守比较。只剩决胜球和一颗本方球时，关键球的球号已确定，但袋口、进位区和母球路线仍可以选择。")
            LearnDocFormulaNest(title: "三处值得多看一眼") {
                LearnDocText.footnote("袋口球要查碰后路线；需要破球团的球要查碰撞后的不确定性；中央孤立球要查接近角和后续方向。它们都不是一律不能用，而是不能省略这一步检查。")
            }
        }
    }

    // MARK: - 常见误区（contracts T06.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "球容易进，就认定是好关键球",
            right: "还要看是否容易接近、能否走到下一颗。袋口球也一样。"
        ),
        .init(
            wrong: "关键球与关键球二一次拍板",
            right: "分别检查两段的进球与走位，再连起来验证，避免只看好了其中一段。"
        ),
        .init(
            wrong: "中段失位后不重选关键球",
            right: "失位后原计划可能已经废了。每杆复盘，不合适就换。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "倒推流程怎么走",
                destination: "反向规划：从最后一颗往回推到当前一杆",
                route: .theoryPage(.t05)
            )

            LearnDocTextLink(
                title: "球团管理",
                subtitle: "给关键衔接保留通道和保险球",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "风险报酬决策矩阵",
                subtitle: "把收尾收益与失误代价一起比较",
                route: .theoryPage(.t08)
            )
            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "自然滚动时，估计袋口球的碰后方向",
                route: .theoryPage(.t01)
            )

            LearnDocText.footnote("练习收尾时，先选关键球和前一颗，说明各自需要的落位区，再检验两段衔接能否重复完成。")
        }
    }
}

// MARK: - 抽象图示：关键球双层

/// 最后一颗 ← 关键球 ← 关键球二（非球形，红线 5 合规）。
private struct KeyBallLayerFigure: View {
    private static let layers: [(title: String, detail: String, tint: Bool)] = [
        ("最后一颗", "选择可靠的收尾位置", true),
        ("关键球", "把母球送到收尾位置", false),
        ("关键球二", "为关键球留出合适角度", false),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardH = h * 0.22
            let cardW = w * 0.78
            let ys = [h * 0.22, h * 0.50, h * 0.78]

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                // 竖向约束上传箭头（自下而上）。
                ForEach(0..<2, id: \.self) { i in
                    Path { p in
                        let from = CGPoint(x: w * 0.12, y: ys[i + 1] - cardH * 0.45)
                        let to = CGPoint(x: w * 0.12, y: ys[i] + cardH * 0.45)
                        p.move(to: from)
                        p.addLine(to: to)
                    }
                    .stroke(Color.btPrimary, lineWidth: 1.5)
                    Path { p in
                        let tip = CGPoint(x: w * 0.12, y: ys[i] + cardH * 0.45)
                        p.move(to: tip)
                        p.addLine(to: CGPoint(x: tip.x - 4, y: tip.y + 6))
                        p.addLine(to: CGPoint(x: tip.x + 4, y: tip.y + 6))
                        p.closeSubpath()
                    }
                    .fill(Color.btPrimary)
                }

                Text("逐层\n衔接")
                    .font(.btCaption2)
                    .foregroundStyle(.btPrimary)
                    .multilineTextAlignment(.center)
                    .position(x: w * 0.12, y: h * 0.50)

                ForEach(Array(Self.layers.enumerated()), id: \.offset) { i, layer in
                    HStack(spacing: Spacing.sm) {
                        Text("\(i + 1)")
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(layer.tint ? Color.btPrimary : Color.btTextTertiary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layer.title)
                                .font(.btCaption.weight(.semibold))
                                .foregroundStyle(layer.tint ? Color.btPrimary : Color.btText)
                            Text(layer.detail)
                                .font(.btCaption2)
                                .foregroundStyle(.btTextSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(layer.tint ? Color.btPrimary.opacity(0.14) : Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(layer.tint ? Color.btPrimary.opacity(0.7) : Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: w * 0.58, y: ys[i])
                }
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT06View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT06View() }
        .preferredColorScheme(.dark)
}
#endif
