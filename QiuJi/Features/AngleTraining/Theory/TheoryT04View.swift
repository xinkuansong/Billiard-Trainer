import SwiftUI

/// 球理详情页「母球速度分级」（v30 W2：物理定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T04-speed-zones.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T04 条目；
///   **App 五档数值**取自 `StrokePhysics.SpeedLevel`（`BTPhysicsConstants.swift`），
///   ⛔ 不凭 16 原文另造杆速。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.7。
/// - **配图判类**：B 控制/分级决策类 → 非球形抽象图示 `AppSpeedSpectrumFigure`
///  （五档条形 + 代码真源杆速）。参数扫描叠加图本轮不做；页内不留「图待补」。
/// - **X-v30-7**：T03 §5.5「45° 入端库必经桌中央」**不**并入本页（见真源 §七复议结论）。
struct TheoryT04View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t04,
                    headline: "把常用力度练成能重复的几档",
                    detail: "先分清轻、中、重，再逐渐熟悉中间的差别。每一档都要与实际球速和停位联系起来，出手时才有参照，而不是临时猜要用多大力。",
                    caption: "本页保留九档记法和 App 五档杆速作对照。档位是练习工具，不是所有球手、球台共用的固定标准。"
                )

                whyItWorks
                appFiveLevels
                elimination
                cushionsAsBrakes
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "母球速度分级")
        .accessibilityIdentifier("theoryPage_t04")
    }

    // MARK: - 为什么要分档

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么要收成几档") {
            LearnDocText.body("面对一杆走位，先想它接近自己练熟的哪种力度，通常比从零开始估计更容易。反复打相同球形，记住母球经过哪里、停在哪里，再逐渐增加中间档，力度感觉就有了依据。")
            LearnDocText.body("回杆幅度和出杆节奏可以帮助重复速度，但同样的出杆长度也能打出不同速度。不要只追求杆走多长，更不要临近触球才突然加力。力度较大的球，同样需要稳定的打点和出杆方向。")
            LearnDocFormulaNest(title: "完整 9 档怎么记") {
                LearnDocText.footnote("九档记法：轻 1–3，中 4–6，重 7–9。这些数字表示相对轻重；熟悉后可以细调，不必给每一杆都报出一个精确档号。")
            }
        }
    }

    // MARK: - App 五档 = T04 落地

    private var appFiveLevels: some View {
        LearnDocSectionCard(title: "用 App 五档比较速度变化") {
            LearnDocText.body("球迹提供五个杆速参照，便于在同一球形中比较路线和远近。它们不与九档记法逐档对应，也不能直接换算成你在球台上的回杆长度。")

            AppSpeedSpectrumFigure()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT04.spectrumFigure")

            TheoryMatrixTable(
                columnTitles: ["杆头速度", "典型用途"],
                rows: StrokePhysics.SpeedLevel.allCases.map { level in
                    .init(
                        level.label,
                        [
                            String(format: "%.1f m/s", level.velocity),
                            Self.usage(for: level),
                        ]
                    )
                }
            )
            LearnDocText.footnote("表中是 App 的杆头速度，不是母球碰到目标球时的速度。典型用途只帮助理解轻重，实际选择还要看距离、厚度、旋转和吃库。")
        }
    }

    private static func usage(for level: StrokePhysics.SpeedLevel) -> String {
        switch level {
        case .soft:       return "近距走位 / 防守"
        case .mediumSoft: return "轻走位"
        case .medium:     return "走位主力区"
        case .mediumHard: return "中长台分离"
        case .hard:       return "长台 / 强分离"
        }
    }

    // MARK: - 排除法

    private var elimination: some View {
        LearnDocSectionCard(title: "台上怎么挑档：排除法") {
            TheoryNumberedList(steps: [
                .init(
                    "看清速度画面",
                    detail: "先确定母球路线和目标停球区域，再想相近球形里自己用过的力度。"
                ),
                .init(
                    "定上界",
                    detail: "估计多大力度会走过目标区，或碰到不想碰的球与库边。"
                ),
                .init(
                    "定下界",
                    detail: "估计多轻会停短，或无法完成所需吃库与旋转效果。"
                ),
                .init(
                    "选有余量的一档",
                    detail: "比较上下限，尽量把停位安排在可接受区域内。若只容许极窄的力度变化，考虑换路线。"
                ),
                .init(
                    "用熟悉的节奏执行",
                    detail: "试运杆时体会所需速度，配合熟悉的回杆幅度。趴下后仍拿不准，就起身重新判断。"
                ),
            ])
            LearnDocText.body("能用较温和的力度完成路线时，通常没必要额外发力；但也不是越轻越好。速度会影响到球旋转、吃库和台呢偏移。选的是适合这条路线、自己又能稳定重复的力度。")
        }
    }

    // MARK: - 库当刹车

    private var cushionsAsBrakes: some View {
        LearnDocSectionCard(title: "临近库边，比较两种停位办法") {
            LearnDocText.body("想让母球停在库边附近，可以比较直接停住和吃库后停住。若直接停位稍一走长就会撞库，主动安排吃库可能更容易控制；但要确认反弹方向和下一杆角度仍合适。")
            LearnDocText.body("库边会改变速度和方向，也会受旋转影响。能否增加容错取决于具体路线，没有统一的距离门槛或“容错翻倍”。")
            LearnDocFormulaNest(title: "力度还会改变到球状态") {
                LearnDocText.footnote("同一打点换了力度，母球到达目标球时的前后旋也可能不同。练停球或斯登时，要把距离、打点、力度一起核对，不能只记一档速度。")
            }
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候这样用") {
            LearnDocText.body("需要控制停位时，都可以用分档建立参照。先把几种常用力度练熟，再按需要细分；不必为了进阶而增加档数。换球台后，也要重新感受台呢和库边。")
            LearnDocFormulaNest(title: "体系外的两头") {
                LearnDocText.footnote("极慢推杆防守，有时比最轻档还轻——落在分档下限之外，只能单独练手感。")
                LearnDocText.footnote("加塞吃库、强低杆等打法中，速度和旋转共同影响路线。分档仍可作起点，但不能只按档号推断最终停位。")
            }
        }
    }

    // MARK: - 常见误区（contracts T04.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "临到触球才突然加力",
            right: "提前确定所需速度，用熟悉的幅度和节奏完成出杆。突然发力容易连打点和方向一起改变。"
        ),
        .init(
            wrong: "怕不够就直接选最重档",
            right: "先查路线需要多远、是否吃库和需要什么到球状态。只因担心不够就加大力度，可能把母球送过可接受区域。"
        ),
        .init(
            wrong: "中段球也开大力",
            right: "按这一杆的实际任务选力度。保留大力完成长距离或特定杆法的能力，也要练好轻力下的方向和打点。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "五档力度上手试",
                destination: "分离角与走位：同一杆换力度看母球多走多远",
                route: .shotSimulation
            )

            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "自然滚动时，方向参照与行进距离怎样配合",
                route: .theoryPage(.t01)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "检查母球碰后的起始方向与弯曲过程",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "换高低杆与力度，看碰后轨迹变化",
                route: .separationAngleAtlas
            )

            LearnDocText.footnote("把五档在演示页里打熟，比只看静图更有用。")
        }
    }
}

// MARK: - 抽象图示：App 五档杆速谱

/// App 五档速度条（非球形）。杆速数字只读 `StrokePhysics.SpeedLevel.velocity`。
private struct AppSpeedSpectrumFigure: View {
    private let levels = StrokePhysics.SpeedLevel.allCases

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = CGFloat(levels.map(\.velocity).max() ?? 1)
            let barMaxH = h * 0.55
            let top = h * 0.12
            let slotW = w / CGFloat(levels.count)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))

                Text("App 五档 · 杆头速度")
                    .font(.btCaption2)
                    .foregroundStyle(.btTextSecondary)
                    .position(x: w * 0.50, y: h * 0.08)

                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    let frac = CGFloat(level.velocity) / maxV
                    let barH = max(barMaxH * frac, h * 0.08)
                    let x = slotW * (CGFloat(index) + 0.5)
                    let y = top + (barMaxH - barH) + barH / 2

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", level.velocity))
                            .font(.btCaption2.monospacedDigit())
                            .foregroundStyle(.btTextSecondary)
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btPrimary.opacity(0.18 + 0.14 * frac))
                            .overlay(
                                RoundedRectangle(cornerRadius: BTRadius.sm)
                                    .stroke(Color.btPrimary.opacity(0.55), lineWidth: 1)
                            )
                            .frame(width: slotW * 0.55, height: barH)
                        Text(level.label)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btText)
                    }
                    .position(x: x, y: y + h * 0.12)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilitySummary)
    }

    private static var accessibilitySummary: String {
        let parts = StrokePhysics.SpeedLevel.allCases.map {
            "\($0.label) \($0.velocity) 米每秒"
        }
        return "App 五档杆头速度：" + parts.joined(separator: "，")
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT04View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT04View() }
        .preferredColorScheme(.dark)
}
#endif
