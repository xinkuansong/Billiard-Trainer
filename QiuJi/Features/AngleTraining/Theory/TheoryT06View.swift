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
                    headline: "决定成败的不是最后一颗，而是关键球",
                    detail: "关键球是为最后一颗安排好母球的那一颗；关键球二是为关键球安排母球的那一颗。两层要分开选、优先保护。",
                    caption: "桌上剩五颗及以下时概念最清晰；更多球时，五球以外都当承转球，不必全盘规划。"
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
        LearnDocSectionCard(title: "自由度在关键球，不在最后一颗") {
            LearnDocText.body("最后一颗（8 / 9 / 黑 8）的打法通常只有一两种，自由度很低。真正的自由度在关键球——你怎么把母球停在它的最佳进位点，决定了最后一颗能不能打成。")

            KeyBallLayerFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT06.layerFigure")
                .accessibilityLabel("关键球双层结构：最后一颗约束最死；关键球承接全部末端约束；关键球二再往前一层。失败多半发生在关键球阶段。")

            LearnDocText.footnote("约束从末端往上传：关键球既要伺候最后一颗，又要自己能进——可行域比最后一颗还窄。")

            LearnDocText.body("业余的失败，大约 90% 发生在关键球阶段，却以为自己败在最后一颗上。关键球与关键球二要分两条独立选——不是一次拍板两颗。")
        }
    }

    // MARK: - 四问（T06 §5）

    private var fourQuestions: some View {
        LearnDocSectionCard(title: "选关键球的四问") {
            LearnDocText.body("候选关键球必须四问全过，否则换下一颗。")
            TheoryNumberedList(steps: [
                .init(
                    "可达吗？",
                    detail: "母球能否从现在的位置，经过不超过两步，到达这颗关键球的进位点。"
                ),
                .init(
                    "角度自然吗？",
                    detail: "打完它，母球能否不靠加塞，自然走到最后一颗的安排区。理想是走完后与最后一颗成大约 15°–45° 切角。"
                ),
                .init(
                    "有保险吗？",
                    detail: "母球稍微走偏一点，是否还有备用解——另一袋口，或滑动停球走位。"
                ),
                .init(
                    "不破局吗？",
                    detail: "打它会不会打散球团，或干扰其他必要的球。"
                ),
            ])
            LearnDocFormulaNest(title: "关键球二怎么选") {
                LearnDocText.footnote("把上面四问里的「最后一颗」换成「关键球」，重做一遍。")
            }
            LearnDocText.body("理想形态：最后一杆前是轻松的滑动停球；再前一杆也是轻松的滑动停球把关键球摆好——两层都「容易」，收官才稳。")
        }
    }

    // MARK: - 袋口球（T06 §4 hangers 修订）

    private var hangers: some View {
        LearnDocSectionCard(title: "袋口球能不能当关键球") {
            LearnDocText.body("旧说法是「袋口球永远不能当关键球」——走位余量太小。修订后改成按水平条件使用：")
            TheoryMatrixTable(
                columnTitles: ["水平", "关键球", "关键球二"],
                rows: [
                    .init("业余（未掌握半球双规则）", ["不作", "不作"]),
                    .init("进阶（掌握半球双规则）", ["可作，限合适接近角", "仍不作"]),
                    .init("高手", ["可作", "通常仍避免"]),
                ]
            )
            LearnDocText.footnote("用袋口球作关键球时，母球必须以「沿库」或「沿对角线」两种角度之一接近；别的角度接近时，半球双规则失效，走位会变差。进袋后母球走位精度大约在正负一颗球径量级。")
            LearnDocText.body("晚打还是早打，是另一个问题：能清台时，早打袋口球简化收官；清不了时，可留作防守资源或挡袋干扰对手。")
        }
    }

    // MARK: - 适用边界（T06 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("桌上剩五颗及以下时永远适用。球更多时，五球以外都视为承转球，不必全规划。")
            LearnDocText.body("关键球选择会变——前面几杆若失位，原计划可能要换。每杆复盘后重新评估它是否仍合适。")
            LearnDocText.body("所有非决胜球都「死」在死角时，关键球概念退化——转去打安全球。桌上只剩两颗（决胜球 + 一颗）时，那一颗就是关键球，选择已被强制。")
            LearnDocFormulaNest(title: "三禁忌") {
                LearnDocText.footnote("① 业余未掌握半球双规则前，不要把袋口球当关键球 / 关键球二。② 不要把要破球团的承转球当关键球——它的母球落点在球团里，不是关键球进位区。③ 桌中央剩孤立球时，不要把它当关键球二——中央球走位选项受限。")
            }
        }
    }

    // MARK: - 常见误区（contracts T06.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "把袋口球当关键球",
            right: "走位余量小。业余默认不作；进阶只有掌握半球双规则、且接近角合适时，才可作关键球（仍不作关键球二）。"
        ),
        .init(
            wrong: "关键球与关键球二一次拍板",
            right: "两层要独立选。一次定两颗，容易漏掉其中一层的约束。"
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
                subtitle: "球团不能埋住关键球；破解排在关键球之前",
                route: .theoryPage(.t07)
            )
            LearnDocTextLink(
                title: "风险报酬决策矩阵",
                subtitle: "四问其实是三问在关键球上的特化",
                route: .theoryPage(.t08)
            )
            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "袋口球半球击打后，母球偏约 30° 的两条精确走向",
                route: .theoryPage(.t01)
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目：剩五颗时先锁定关键球与关键球二，再开打，最见效。")
        }
    }
}

// MARK: - 抽象图示：关键球双层

/// 最后一颗 ← 关键球 ← 关键球二（非球形，红线 5 合规）。
private struct KeyBallLayerFigure: View {
    private static let layers: [(title: String, detail: String, tint: Bool)] = [
        ("最后一颗", "打法通常只有 1–2 种", true),
        ("关键球", "为它安排母球 · 自由度在这里", false),
        ("关键球二", "为关键球安排母球 · 独立再选", false),
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

                Text("约束\n上传")
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
