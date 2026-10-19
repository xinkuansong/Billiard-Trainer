import SwiftUI

/// 球理详情页「安全球三维度模型」（v30 W3：战术定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T10-safety-hierarchy.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T10 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.11。
/// - **配图判类**：B 战术决策类 → 非球形抽象图示
///   `SafetyDimensionFigure`（三维并列）+ `SafetyDegradeLadderFigure`（按维度数降级）。
///   层级清单用 `TheoryNumberedList`（参照风险报酬页）。⛔ 不画具体球形局面。
struct TheoryT10View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t10,
                    headline: "从距离、库位和障碍，看防守留下了什么",
                    detail: "拉开距离可以增加进攻难度，贴库可能限制杆法，障碍球可以挡住直接路线。用这三个角度检查防守，再看自己能否做成、对手会怎样应对。",
                    caption: "三个维度可以配合使用，但数量不等于质量。一个可靠的限制，有时比勉强凑齐三个更有效。"
                )

                whyItWorks
                dimensions
                degradePath
                checklist
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "安全球三维度模型")
        .accessibilityIdentifier("theoryPage_t10")
    }

    // MARK: - 直觉（T10 §2）

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "防守是主动塑造对手困境") {
            LearnDocText.body("防守的目标，是限制对手下一杆，同时为自己保留机会。把母球藏住是一种方法，留下难以进攻的距离或不舒服的出杆位置，也可能有价值。要看对手实际剩下什么选择，而不只看球藏得深不深。")

            SafetyDimensionFigure()
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT10.dimensionFigure")
                .accessibilityLabel("防守的三个观察角度：距离、库位和障碍。可以组合，但要检查实际限制与执行把握，不能按数量直接评定质量。")

            LearnDocText.footnote("图中的连线表示可以组合使用，不表示三项彼此独立，也不保证叠加后一定更好。")
        }
    }

    // MARK: - 三维度详解（T10 §3）

    private var dimensions: some View {
        LearnDocSectionCard(title: "三个维度分别做什么") {
            TheoryNumberedList(steps: [
                .init(
                    "拉开距离",
                    detail: "增加母球与合法目标球之间的距离，往往能提高瞄准和控制难度。但还要看目标球离袋多远、角度是否简单，不能只用两球距离判定安全。"
                ),
                .init(
                    "占住库位",
                    detail: "母球贴库可能限制低打点和舒适出杆，目标球靠库也会改变进攻与解球路线。但贴库不自动等于难打，还要检查薄球、翻袋和一库解球等选择。"
                ),
                .init(
                    "用障碍球挡住",
                    detail: "用另一颗球或球团挡住直接路径，让对手需要绕路。检查是否真的挡住了合法目标，以及仍可用哪些库线；即使完全遮挡，也未必难解。"
                ),
            ])
            LearnDocFormulaNest(title: "沿阴影走，别横切") {
                LearnDocText.footnote("可把目标球想成光源、障碍球想成遮光物，帮助寻找遮挡区。这只是直观比喻，实际要算上球的大小和可击边缘。若母球沿遮挡区较长的方向进入，通常比横穿狭窄区域更容易控制停点。")
            }
        }
    }

    // MARK: - 降级路径（T10 §5）

    private var degradePath: some View {
        LearnDocSectionCard(title: "从想要的结果，退到能稳定做到的结果") {
            SafetyDegradeLadderFigure()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT10.ladderFigure")
                .accessibilityLabel("检查三种限制的组合，复杂方案难以执行时简化到两种或一种。阶梯表示简化思路，不是防守质量等级。")

            TheoryNumberedList(steps: [
                .init("评估资源", detail: "看看可用的障碍球、库边和空间，也看对手有哪些合法目标。"),
                .init("检查组合", detail: "能否同时利用距离、库位和障碍？先看路线是否可靠，不为凑齐三项增加无谓难度。"),
                .init("简化到两项", detail: "例如远距离加遮挡。检查其中一项失手后，另一项是否仍有效。"),
                .init("保住一项", detail: "复杂方案不稳时，选一个能做成的限制，再与进攻方案比较。"),
                .init("确定主要控制对象", detail: "可以重点控制母球或目标球，让另一颗去较宽的区域；必要时仍需同时控制两球。检查落袋、组合球和容易的解球路线。"),
            ])
            TheoryMatrixTable(
                columnTitles: ["可以得到什么", "还要检查什么"],
                rows: [
                    .init("1 项", ["集中做好一个限制", "是否仍留简单进攻"]),
                    .init("2 项", ["两种限制相互补充", "路线是否难以兼顾"]),
                    .init("3 项", ["限制更多种选择", "能否稳定执行"]),
                ]
            )
        }
    }

    // MARK: - 自检（T10 §5 六问精简）

    private var checklist: some View {
        LearnDocSectionCard(title: "出手前再过一遍") {
            TheoryNumberedList(steps: [
                .init("距离有用吗？", detail: "拉开后，对手是否仍有简单的进球角度或袋口球？"),
                .init("库位限制了什么？", detail: "是否真的影响出杆、杆法或进攻路线？"),
                .init("障碍挡住了吗？", detail: "检查目标球两侧，以及对手其他合法目标。"),
                .init("控制重点清楚吗？", detail: "哪颗球必须到位，哪颗可以落在较宽的区域？"),
                .init("有没有遗漏的机会？", detail: "再看组合球、翻袋、容易的解球，以及自己击球的合法性。"),
                .init("落位区够宽吗？", detail: "尽量沿可用区域较长的方向进入，留出力度余地。"),
            ])
            LearnDocText.body("选好后，像认真进攻一样完成准备和出杆。防守也需要准确的厚度、速度和旋转，不能因为不瞄袋口就随手一推。")
        }
    }

    // MARK: - 适用边界（T10 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候进这条线") {
            LearnDocText.body("进攻把握不足、后续路线困难，或防守能明显改善局面时，都值得把安全球放进比较。有自由球也不等于必须清台，可以先改善问题球，但不能把对手下一次犯规当成必然。")
            LearnDocText.body("尽早比较进攻与防守，能保留更多选择。决定防守后，也要有明确的预期落点和下一步目的。")
            LearnDocText.body("八球与九球的合法目标不同，障碍是否有效必须按当前规则判断。藏住一颗目标，不代表八球里其他合法球也被挡住。")
            LearnDocText.body("面对解球能力强的对手，要重新评估防守的实际收益，而不是一律转成冒险进攻。桌面空旷时，可以更多利用距离、角度和库位。")
        }
    }

    // MARK: - 常见误区（contracts T10 + 原文反例合并）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "以为安全球就是「藏球」",
            right: "还要看距离与库位，并检查对手实际有哪些进攻和解球路线。"
        ),
        .init(
            wrong: "同时精确控母球和目标球",
            right: "先确定哪颗必须精确到位，让另一颗有更宽的容许区域。两球都要精确控制时，重新评估执行把握。"
        ),
        .init(
            wrong: "目标球靠库，就认为一定难解",
            right: "靠库有时会增加可碰到目标球的解球路线。看具体库线和可击范围，不能用固定离库距离一概判断。"
        ),
        .init(
            wrong: "停在第一眼看到的方案就出手",
            right: "再看一个替代方案，并从对手的位置检查解球与反防路线，再作选择。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "比较进攻与防守的后果",
                destination: "风险报酬决策矩阵：进得了吗、走得到位吗、代价扛得住吗",
                route: .theoryPage(.t08)
            )
            PracticeCTA(
                title: "防守怎么藏到什么程度",
                destination: "防守：反解安全球，看能藏到什么程度",
                route: .snookerTactics
            )

            LearnDocTextLink(
                title: "球团管理",
                subtitle: "进攻时球团是问题，防守时是障碍维资源",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "优先控母球时，切线告诉你碰后先往哪走",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "母球速度分级",
                subtitle: "把预期落点换成可重复的力度",
                route: .theoryPage(.t04)
            )

            LearnDocText.footnote("练习时先定一个明确的防守目标，打完站到对手的位置检查效果。能稳定做成后，再练加入第二种限制。")
        }
    }
}

// MARK: - 抽象图示 ①：三维度并列

private struct SafetyDimensionFigure: View {
    private static let items = [
        ("距离", "检查长距离难度"),
        ("库位", "检查出杆与路线"),
        ("障碍", "挡住直接路径"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.28
            let cardH = h * 0.52
            let xs = [w * 0.18, w * 0.50, w * 0.82]
            let y = h * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("三个角度，检查实际限制")
                    .font(.btCaption2.weight(.semibold))
                    .foregroundStyle(.btPrimary)
                    .position(x: w * 0.50, y: h * 0.12)

                // 底部汇合线，表示可叠加。
                Path { p in
                    p.move(to: CGPoint(x: xs[0], y: h * 0.78))
                    p.addLine(to: CGPoint(x: xs[2], y: h * 0.78))
                }
                .stroke(Color.btPrimary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                ForEach(Array(Self.items.enumerated()), id: \.offset) { i, item in
                    VStack(spacing: 6) {
                        Text(item.0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btPrimary)
                        Text(item.1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btPrimary.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(Color.btPrimary.opacity(0.45), lineWidth: 1)
                    )
                    .position(x: xs[i], y: y)

                    Path { p in
                        p.move(to: CGPoint(x: xs[i], y: y + cardH * 0.52))
                        p.addLine(to: CGPoint(x: xs[i], y: h * 0.78))
                    }
                    .stroke(Color.btPrimary.opacity(0.4), lineWidth: 1.2)
                }

                Text("可以组合 · 数量不等于质量")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.50, y: h * 0.90)
            }
        }
    }
}

// MARK: - 抽象图示 ②：按维度数降级阶梯

private struct SafetyDegradeLadderFigure: View {
    private static let rungs = [
        ("3 维", "距离 + 库位 + 障碍", true),
        ("2 维", "常见：远 + 挡", false),
        ("1 维", "保住可靠限制", false),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // 三档收紧到中上区域，避免元素级截图裁掉最底一档。
            let cardH = h * 0.18
            let widths: [CGFloat] = [0.86, 0.72, 0.58]
            let ys = [h * 0.24, h * 0.48, h * 0.72]

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("难以执行时，简化方案")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.50, y: h * 0.08)

                ForEach(0..<2, id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.50, y: ys[i] + cardH * 0.55))
                        p.addLine(to: CGPoint(x: w * 0.50, y: ys[i + 1] - cardH * 0.55))
                    }
                    .stroke(Color.btWarning, lineWidth: 1.5)
                    Path { p in
                        let tip = CGPoint(x: w * 0.50, y: ys[i + 1] - cardH * 0.55)
                        p.move(to: tip)
                        p.addLine(to: CGPoint(x: tip.x - 4, y: tip.y - 6))
                        p.addLine(to: CGPoint(x: tip.x + 4, y: tip.y - 6))
                        p.closeSubpath()
                    }
                    .fill(Color.btWarning)
                }

                ForEach(Array(Self.rungs.enumerated()), id: \.offset) { i, rung in
                    let cardW = w * widths[i]
                    HStack {
                        Text(rung.0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(rung.2 ? Color.btPrimary : Color.btText)
                        Spacer(minLength: 8)
                        Text(rung.1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(rung.2 ? Color.btPrimary.opacity(0.14) : Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(rung.2 ? Color.btPrimary.opacity(0.7) : Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: w * 0.50, y: ys[i])
                }
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT10View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT10View() }
        .preferredColorScheme(.dark)
}
#endif
