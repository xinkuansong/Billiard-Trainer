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
                    headline: "安全球质量看三个独立维度",
                    detail: "拉开距离、占住库位、用障碍球挡住。理想一手三维都拿到；三问没过时，按「满足几个维度」逐级降级。",
                    caption: "任一维度都能独立抬高质量；维度越多越强，也越难做。"
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
            LearnDocText.body("防守不是消极——是把局面交还时，让对手处于比你更差的位置。业余常把安全球等同于「藏球」，其实那只是障碍球这一个维度；任一维度都能独立抬高质量。")

            SafetyDimensionFigure()
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT10.dimensionFigure")
                .accessibilityLabel("安全球三个独立维度：拉开距离、占住库位、用障碍球挡住。理想是三维全包含。")

            LearnDocText.footnote("理想安全球三维全包含；只做成一两个，也仍有很大机会再上台。")
        }
    }

    // MARK: - 三维度详解（T10 §3）

    private var dimensions: some View {
        LearnDocSectionCard(title: "三个维度分别做什么") {
            TheoryNumberedList(steps: [
                .init(
                    "拉开距离",
                    detail: "母球与目标球尽量远，典型至少约三分之二桌长。长距逼对手更准的瞄准、更难的弧线与加塞估算。这是最容易拿到的维度——通常只需控好一颗球的速度。"
                ),
                .init(
                    "占住库位",
                    detail: "母球与目标球各自落在对侧库的中段。母球贴库时，对手往往只能看到球顶，难加塞、难打后旋。「中段」要离袋口够远，避免对手直接进或翻袋。"
                ),
                .init(
                    "用障碍球挡住",
                    detail: "两球之间被另一颗球或球团挡住直接路径，逼对手至少踢一库或起跳。这是最强也最难的维度——要同时控母球与目标球的位置。"
                ),
            ])
            LearnDocFormulaNest(title: "沿阴影走，别横切") {
                LearnDocText.footnote("把对手的目标球想成光源、中间障碍想成遮光物，桌面上投出的阴影区就是母球可藏身区。母球应沿阴影方向走（容差大），而不是垂直穿过阴影（容差小）。")
            }
        }
    }

    // MARK: - 降级路径（T10 §5）

    private var degradePath: some View {
        LearnDocSectionCard(title: "三问没过后怎么选") {
            SafetyDegradeLadderFigure()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT10.ladderFigure")
                .accessibilityLabel("安全球按维度数降级：先试三维，不行退到二维，再退到一维；通常一维先拿距离。")

            TheoryNumberedList(steps: [
                .init("评估资源", detail: "有没有球团、挡袋球、半桌空间、库边可用。"),
                .init("优先试三维", detail: "同时满足距离 + 库位 + 障碍。"),
                .init("退到二维", detail: "选最强组合，常见是「远 + 挡」。"),
                .init("退到一维", detail: "通常先拿距离——最容易实现。"),
                .init("加上执行修正", detail: "只控母球或只控目标球（优先控母球）；避开决胜球旁边；沿障碍球线进入；目标球离库别太近（约十五厘米内踢库容易碰到）。"),
            ])
            TheoryMatrixTable(
                columnTitles: ["维度数", "质量", "难度"],
                rows: [
                    .init("1 维", ["低", "易"]),
                    .init("2 维", ["中", "中"]),
                    .init("3 维", ["高", "难"]),
                ]
            )
        }
    }

    // MARK: - 自检（T10 §5 六问精简）

    private var checklist: some View {
        LearnDocSectionCard(title: "出手前再过一遍") {
            TheoryNumberedList(steps: [
                .init("距离够吗？", detail: "两球距离大约有没有到三分之二桌长。"),
                .init("库位占住了吗？", detail: "母球贴库？目标球在对侧库中段？"),
                .init("有障碍吗？", detail: "中间有没有球或球团挡住。"),
                .init("只控一个？", detail: "同时控两球，精度会乘性变差——优先只控母球。"),
                .init("有没有踩雷？", detail: "目标球别贴决胜球；别贴库太近；别给对手容易的一库踢。"),
                .init("路径是沿阴影还是横切？", detail: "沿阴影走，速度容差更大。"),
            ])
            LearnDocText.body("六问过了再执行。安全球要按高难度球标准对待——完整准备、完整跟进，不是「打丢了也没事」的备选。")
        }
    }

    // MARK: - 适用边界（T10 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候进这条线") {
            LearnDocText.body("开打前三问任一不过关，就必须进安全球这条线。决胜阶段已确认无法清台时，或自由球却清不了时，也进这里——有时把目标球放到球团附近，下次自由球再破。")
            LearnDocText.body("不要把安全球当成「打不进才退而求其次」——被动防守效果差。要按「主动塑造对手困境」的姿态打。")
            LearnDocText.body("球种差异：九球打丢有时还能变成防守；八球 / 中式八球打丢往往不能，安全球必须更精。中式八球球多桌相对紧，障碍球维度出现更勤，适合多做三维。")
            LearnDocText.body("对手水平远高于自己时，弱防守可能反被踢库利用——反而要选高风险高回报的进攻。桌上空旷无球团时，障碍维拿不到，只能做一到二维。")
        }
    }

    // MARK: - 常见误区（contracts T10 + 原文反例合并）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "以为安全球就是「藏球」",
            right: "藏球只是障碍维。距离与库位各自都能独立抬高质量；理想是三维都拿到。"
        ),
        .init(
            wrong: "同时精确控母球和目标球",
            right: "精度乘性变差。优先只控母球——切线加力度更稳。"
        ),
        .init(
            wrong: "把目标球推到贴库约十五厘米内",
            right: "贴库太近会变成「大目标」，对手踢库更容易碰到。目标球要离库远一点。"
        ),
        .init(
            wrong: "停在第一眼看到的方案就出手",
            right: "至少再剥两三层：优化路径、看阴影区、估对手多库踢的难度，再出手。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "先过三问，不过再进这里",
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
                subtitle: "拉开距离这一维，靠出杆长度控档最稳",
                route: .theoryPage(.t04)
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目：先在练习里只做「远 + 贴库」二维，再加障碍维。")
        }
    }
}

// MARK: - 抽象图示 ①：三维度并列

private struct SafetyDimensionFigure: View {
    private static let items = [
        ("距离", "越远越难打"),
        ("库位", "贴库 / 对侧中段"),
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

                Text("理想 = 三维全包含")
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

                Text("任一维独立有效 · 叠加更强")
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
        ("1 维", "通常先拿距离", false),
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

                Text("做不到就降一级")
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
