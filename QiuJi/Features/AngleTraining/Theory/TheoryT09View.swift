import SwiftUI

/// 球理详情页「最少加塞原则」（v30 W2：物理定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T09-minimum-english.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T09 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.6。
/// - **配图判类**：B 战术/控制决策类（与具体球位无关）→ 非球形抽象图示
///   `EnglishErrorCouplingFigure`（三种影响）+ `EnglishLevelLadderFigure`（四级优先）。
///   ⛔ 不画具体球形局面（红线 5）。术语：挤偏 / 弧线 / 投掷（⛔ 不用「塞偏」）。
struct TheoryT09View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t09,
                    headline: "先明确加塞的目的，再选需要的塞量",
                    detail: "如果不加左右塞就能完成进球和走位，可以先选这条更熟悉的路线。需要改变吃库方向或完成特定走位时，再用足够完成任务的塞量，不把加塞变成每杆的习惯动作。",
                    caption: "不加塞仍可使用高杆、低杆或斯登。少用不必要的塞，与练好加塞技术并不矛盾。"
                )

                whyItWorks
                mythBusting
                levels
                decisionSteps
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "最少加塞原则")
        .accessibilityIdentifier("theoryPage_t09")
    }

    // MARK: - 为什么少加塞

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "加塞后，要多判断哪些变化") {
            LearnDocText.body("加塞时，母球出手可能偏离杆身指向，这叫挤偏；行进途中，侧旋配合抬杆会使路线弯曲，这叫弧线；碰撞时，球间摩擦还可能改变目标球的方向，这叫投掷。先分清变化发生在哪个阶段，才知道该观察什么。")

            EnglishErrorCouplingFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT09.errorFigure")

            LearnDocText.footnote("三种效应可能相互抵消，也可能加强，不能把误差简单相乘。不加塞也可能有切球投掷；合适的外侧塞可减小它，但仍要考虑挤偏和弧线。")

            LearnDocText.body("距离越长，出手方向的一点偏差越容易变成明显的位置偏差。实际难度还取决于塞量、速度、抬杆、球杆和球台条件，不能用一个固定的精度百分比概括所有长台加塞球。")
        }
    }

    // MARK: - 流派神话破除（T09 §3 Spin/Speed）

    private var mythBusting: some View {
        LearnDocSectionCard(title: "先把打点和补偿练稳定") {
            LearnDocText.body("加塞确实能扩展走位选择，但效果要靠稳定的打点和速度来重复。只说「松握一点」或「抖一下手腕」，并不能说明母球会带多少侧旋，更不能代替瞄准修正。")
            LearnDocText.body("练习时，先固定球形、速度和抬杆程度，只改变一个条件，观察母球出手、目标球方向和吃库后的变化。这样积累的参照，才能用到比赛里。")
            LearnDocFormulaNest(title: "球杆能帮到哪里") {
                LearnDocText.footnote("低偏杆可以减小挤偏，但不会消除弧线和投掷。换杆后仍需重新熟悉补偿量；不要把器材变化当成免修正。")
            }
        }
    }

    // MARK: - 四级优先

    private var levels: some View {
        LearnDocSectionCard(title: "加塞量的四级优先") {
            EnglishLevelLadderFigure()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT09.levelFigure")

            TheoryMatrixTable(
                columnTitles: ["加多少", "什么时候用"],
                rows: [
                    .init("0", ["不加塞", "先看是否已有合适路线"]),
                    .init("1", ["少量塞", "先试能否完成需要的调整"]),
                    .init("2", ["增加塞量", "少量不够时，重新核对补偿"]),
                    .init("3", ["较大偏心", "需要专门练习，留意打滑风险"]),
                ]
            )
            LearnDocText.footnote("这里的四级表示选择顺序，不是统一的打点刻度。高低杆可以提供不加左右塞的替代路线，但也要控制到球时的旋转状态。")
        }
    }

    // MARK: - 决策三步 + 四问

    private var decisionSteps: some View {
        LearnDocSectionCard(title: "决定加不加塞") {
            TheoryNumberedList(steps: [
                .init(
                    "先看不加塞的路线",
                    detail: "结合到球时的旋转状态，用 30°、90°和切线判断方向，再看力度是否好控制。"
                ),
                .init(
                    "再试上下旋",
                    detail: "比较高杆、低杆或斯登能否完成走位，选自己更熟悉、落位范围更宽的方案。"
                ),
                .init(
                    "说清加塞的收益",
                    detail: "例如改变吃库后的方向，或减少切球投掷。先用较少的塞量试出效果，再决定是否增加。"
                ),
                .init(
                    "长距离再比较一次",
                    detail: "距离长、目标薄或落位区窄时，补偿更难重复。重新比较路线收益与自己的实际把握。"
                ),
            ])

            LearnDocFormulaNest(title: "每次加塞前的四问") {
                LearnDocText.footnote("① 这点塞具体要改变什么？有没有更熟悉的替代路线？")
                LearnDocText.footnote("② 少一点塞能否达到同样目的？")
                LearnDocText.footnote("③ 当前距离和角度下，我练过这种补偿吗？")
                LearnDocText.footnote("④ 挤偏、弧线和投掷的综合影响，是否已考虑到瞄准里？")
            }
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候仍要加塞") {
            LearnDocText.body("当需要调整吃库后的方向和速度，或某条路线用侧旋更容易完成时，加塞就是有用的工具。判断标准是它是否让整杆球更可靠，而不是塞量越少就一定越好。")
            LearnDocText.body("绕过障碍的明显弧线球还涉及抬杆和专门技术，不能理解成普通水平加塞就能拐弯。加塞后的碰撞判断，要以母球实际到球方向为参照，不能直接沿用杆身指向。")
        }
    }

    // MARK: - 常见误区（contracts T09.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "每杆都习惯性加一点塞",
            right: "先说明它要完成什么。没有明确收益的加塞，只会增加需要判断的变化。"
        ),
        .init(
            wrong: "以为某种握杆或抖腕能改掉挤偏比例",
            right: "先稳定打点、速度和抬杆，再练补偿。动作名称本身不能保证消除挤偏。"
        ),
        .init(
            wrong: "看职业加塞就照着加",
            right: "先看他为什么用塞、路线有什么收益，再用自己的练习结果判断是否适合照用。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "先认清到球时的旋转",
                destination: "旋转与加塞：斯登、前旋和后旋怎样影响碰后路线",
                route: .spinAndEnglish
            )

            LearnDocTextLink(
                title: "旋转与加塞",
                subtitle: "挤偏、弧线、投掷在击球面上怎么对上",
                route: .spinAndEnglish
            )
            LearnDocTextLink(
                title: "加塞吃库图谱",
                subtitle: "真要用塞吃库时，内侧外侧怎么改反弹",
                route: .cushionEnglishAtlas
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "判断碰后路线的几何参照",
                route: .theoryPage(.t03)
            )

            LearnDocText.footnote("练习时选同一个球形，对比不加塞和少量加塞的路线，记录进球与落位是否都能重复。")
        }
    }
}

// MARK: - 抽象图示 ①：三种加塞影响

/// 挤偏 / 弧线 / 投掷三种影响示意（非球形，红线 5 合规）。
private struct EnglishErrorCouplingFigure: View {
    private static let items = [
        ("挤偏", "出手时偏离杆身方向"),
        ("弧线", "途中因侧旋和抬杆弯曲"),
        ("投掷", "碰撞摩擦改变目标球方向"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.28
            let cardH = h * 0.42
            let ys = h * 0.38
            let xs = [w * 0.18, w * 0.50, w * 0.82]

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Text("分清三个阶段")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.50, y: h * 0.12)

                ForEach(0..<3, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text(Self.items[i].0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btWarning)
                        Text(Self.items[i].1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.sm)
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btWarning.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(Color.btWarning.opacity(0.45), lineWidth: 1)
                    )
                    .position(x: xs[i], y: ys)
                }

                Text("综合判断：可能抵消，也可能加强")
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btText)
                    .position(x: w * 0.50, y: h * 0.86)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("出手看挤偏，途中看弧线，碰撞看投掷；综合影响可能抵消，也可能加强。")
    }
}

// MARK: - 抽象图示 ②：四级优先阶梯

/// 加塞量 Level 0–3 优先阶梯（非球形，红线 5 合规）。
private struct EnglishLevelLadderFigure: View {
    private static let rows: [(String, String, Bool)] = [
        ("0 不加塞", "默认首选", true),
        ("1 少量塞", "先试够不够", false),
        ("2 增加塞量", "核对补偿", false),
        ("3 大偏心", "专门练习", false),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rowH = h * 0.18
            let gap = h * 0.04
            let top = h * 0.08

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))

                ForEach(0..<4, id: \.self) { i in
                    let y = top + CGFloat(i) * (rowH + gap) + rowH / 2
                    let widthFactor = 1.0 - CGFloat(i) * 0.12
                    let rowW = w * 0.86 * widthFactor
                    HStack {
                        Text(Self.rows[i].0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(Self.rows[i].2 ? Color.btPrimary : Color.btText)
                        Spacer()
                        Text(Self.rows[i].1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(width: rowW, height: rowH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Self.rows[i].2
                                  ? Color.btPrimary.opacity(0.16)
                                  : Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(Self.rows[i].2
                                    ? Color.btPrimary.opacity(0.6)
                                    : Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: w * 0.50, y: y)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("加塞的选择顺序：先看不加塞的路线，再试少量塞，需要时增加塞量；较大偏心需要专门练习。这不是统一的打点刻度。")
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT09View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT09View() }
        .preferredColorScheme(.dark)
}
#endif
