import SwiftUI

/// 球理详情页「最少加塞原则」（v30 W2：物理定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T09-minimum-english.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T09 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.6。
/// - **配图判类**：B 战术/控制决策类（与具体球位无关）→ 非球形抽象图示
///   `EnglishErrorCouplingFigure`（三重误差）+ `EnglishLevelLadderFigure`（四级优先）。
///   ⛔ 不画具体球形局面（红线 5）。术语：挤偏 / 弧线 / 投掷（⛔ 不用「塞偏」）。
struct TheoryT09View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t09,
                    headline: "能用中杆走到位，就绝不加塞",
                    detail: "加塞会同时引入挤偏、弧线、投掷三重耦合误差；长距加塞往往需要约 1% 的精度估算，超出业余的稳定能力。",
                    caption: "默认先用中杆配合「30° / 90° / 切线」三条；真不够，再加最小必要的塞。"
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
        LearnDocSectionCard(title: "中杆只有一个误差，加塞变成三个") {
            LearnDocText.body("中杆击球，误差源基本就是瞄准本身。一加塞，马上多出三条独立误差：挤偏、弧线、投掷——而且它们会叠在一起放大，不是简单相加。")

            EnglishErrorCouplingFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT09.errorFigure")

            LearnDocText.footnote("三块都要从瞄准里补掉：杆头侧偏带来的挤偏、杆微抬带来的弧线、碰撞时目标球被「拉」开的投掷。忘补任意一块，这一杆就歪。")

            LearnDocText.body("长距、目标球又在桌面中部附近时，容差可能只剩大约 1 毫米量级——大约相当于 1% 的精度。业余很难稳定做到；换低偏杆可以把同样局面放到大约 10% 精度量级，但最好的办法仍是：能不加就不加。")
        }
    }

    // MARK: - 流派神话破除（T09 §3 Spin/Speed）

    private var mythBusting: some View {
        LearnDocSectionCard(title: "加塞不是「多一种控制」") {
            LearnDocText.body("侧旋和前进速度的比值，几乎只由杆头打点偏离中心的多少决定——跟球多重、皮头软硬、手腕怎么抖、跟进多长，都对不上号。")
            LearnDocText.body("所以「抖腕」「松握」「硬皮头」这类说法，改变不了挤偏的比例。它们最多影响总速度或击球稳不稳，减不掉三重误差本身。")
            LearnDocFormulaNest(title: "真能减少挤偏的办法") {
                LearnDocText.footnote("① 不加塞（首选）② 只加最小必要量 ③ 换低偏的杆（设备层，改善幅度大约数倍）。")
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
                columnTitles: ["级别", "加多少", "什么时候用"],
                rows: [
                    .init("0", ["不加塞", "默认，能走到位就停在这"]),
                    .init("1", ["约 1/4 杆头", "必须加时的优选"]),
                    .init("2", ["约 1/2 杆头", "1 级不够才升"]),
                    .init("3", ["接近打滑极限", "极罕见，专门技术"]),
                ]
            )
            LearnDocText.footnote("能用前旋 / 后旋（上下旋）替代左右塞时，优先上下旋——上下旋不引入挤偏。")
        }
    }

    // MARK: - 决策三步 + 四问

    private var decisionSteps: some View {
        LearnDocSectionCard(title: "决定加不加塞") {
            TheoryNumberedList(steps: [
                .init(
                    "先试中杆解",
                    detail: "用 30° / 90° / 切线，再配合力度档，估一遍不加塞能不能走到。"
                ),
                .init(
                    "再试上下旋",
                    detail: "高杆或低杆往往比左右塞更可控。"
                ),
                .init(
                    "仍无解才加塞",
                    detail: "按 1 → 2 → 3 级往上加；用到 2、3 级时，把自己的瞄准容差再放宽大约一半到一倍。"
                ),
                .init(
                    "超过半桌重新评估",
                    detail: "长距加塞的 1% 精度需求，多半超出能力——回头找不加塞的替代路线。"
                ),
            ])

            LearnDocFormulaNest(title: "每次加塞前的四问") {
                LearnDocText.footnote("① 真的非用不可吗？上下旋 / 中杆 / 换个切角能不能替代？")
                LearnDocText.footnote("② 是 1 级还是已经要到 2、3 级？尽量降级。")
                LearnDocText.footnote("③ 距离还允许吗？（不到半桌更可接受。）")
                LearnDocText.footnote("④ 挤偏、弧线、投掷三个修正都补了吗？漏一个就容易打丢。")
            }
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候仍要加塞") {
            LearnDocText.body("少数局面中杆和上下旋都到不了：要拐过障碍球、吃库后需要「反常」反弹角、或长距走位末段要靠一点点内侧/外侧塞微调速度。即便如此，也只加最小必要量。")
            LearnDocText.body("加了塞以后，「30° / 90° / 切线」的输入端都要先按挤偏校正——母球实际飞向已经不是杆身指向。")
        }
    }

    // MARK: - 常见误区（contracts T09.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "以为加塞就能「多控制」母球",
            right: "每加一份塞，就多一份变量。控制感常常是错觉，实打实增加的是瞄准负担。"
        ),
        .init(
            wrong: "以为某种握杆或抖腕能改掉挤偏比例",
            right: "侧旋与速度的比值几乎只由打点偏离决定，流派出杆改不了这个物理量。"
        ),
        .init(
            wrong: "看职业加塞就照着加",
            right: "职业的手感建立在上万小时的精度上；业余精度够不到长距约 1% 的需求时，直接模仿往往更糟。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "先把中杆四态看熟",
                destination: "旋转与加塞：滑动 / 前旋 / 后旋怎么改变分离角",
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
                subtitle: "中杆走位的几何起点",
                route: .theoryPage(.t03)
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目：先逼自己用中杆走完最近十杆，比空练加塞更见效。")
        }
    }
}

// MARK: - 抽象图示 ①：三重误差耦合

/// 挤偏 / 弧线 / 投掷三重误差示意（非球形，红线 5 合规）。
private struct EnglishErrorCouplingFigure: View {
    private static let items = [
        ("挤偏", "杆头侧偏，母球出手就不沿杆"),
        ("弧线", "杆微抬，路上慢慢弯"),
        ("投掷", "碰撞时目标球被「拉」开"),
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

                Text("中杆：1 个误差")
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

                Text("三者同时出现 → 误差叠乘放大")
                    .font(.btCaption.weight(.semibold))
                    .foregroundStyle(.btText)
                    .position(x: w * 0.50, y: h * 0.86)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("加塞引入挤偏、弧线、投掷三重误差，同时出现时误差叠乘放大。")
    }
}

// MARK: - 抽象图示 ②：四级优先阶梯

/// 加塞量 Level 0–3 优先阶梯（非球形，红线 5 合规）。
private struct EnglishLevelLadderFigure: View {
    private static let rows: [(String, String, Bool)] = [
        ("0 不加塞", "默认首选", true),
        ("1 约 1/4 杆头", "必须时优选", false),
        ("2 约 1/2 杆头", "1 级不够才升", false),
        ("3 接近打滑", "极罕见", false),
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
        .accessibilityLabel("加塞四级优先：0 不加塞默认，1 约四分之一杆头，2 约二分之一杆头，3 接近打滑极少用。")
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
