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
                    headline: "力度先分档，再用出杆长度来调",
                    detail: "把连续力度收成少数离散档（完整体系是 9 档、并成轻 / 中 / 重三段）；靠出杆长短而不是「加力气」来稳定重复。",
                    caption: "本 App 的五档杆速，就是这套分级在练习里的落地——业余用 5 档通常就够覆盖大多数走位。"
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
            LearnDocText.body("压力下人很难稳定输出「连续力度」，但能稳定区分少数几档。档位一定，每档母球大概停在哪就变成已知量——走位变成「挑档」，而不是临场拧力气。")
            LearnDocText.body("出杆长度是物理上更好重复的变量：短 → 轻，长 → 重。架桥长短和手腕动作只是辅助；7–9 那一档的大力才需要专门练手腕释放。")
            LearnDocFormulaNest(title: "完整 9 档怎么记") {
                LearnDocText.footnote("轻：1–3　中：4–6　重：7–9。整数档是认知锚点；熟了以后可以在 4.5、5.3 这类小数上微调。")
            }
        }
    }

    // MARK: - App 五档 = T04 落地

    private var appFiveLevels: some View {
        LearnDocSectionCard(title: "App 里的五档就是它的落地") {
            LearnDocText.body("完整体系是 9 档；进阶路上常见「先去掉最轻与最重、先用 5 档」。球迹练习页的力度选择，就是这 5 个稳定杆速锚点：")

            AppSpeedSpectrumFigure()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("theoryT04.spectrumFigure")

            TheoryMatrixTable(
                columnTitles: ["档", "杆头速度", "典型用途"],
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
            LearnDocText.footnote("速度数字来自代码 `StrokePhysics.SpeedLevel`（注释已标明源自本条速度分级），与演示页滑条同一真源——不是另写一套。")
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
                    detail: "母球、目标球、想停的区域，三者的位置关系先收进眼里。"
                ),
                .init(
                    "定上界",
                    detail: "「这一档过了吗？」找到第一个明显过的档。"
                ),
                .init(
                    "定下界",
                    detail: "「这一档够吗？」找到第一个够得到的档。"
                ),
                .init(
                    "中间二分",
                    detail: "上下界之间通常只剩 1–2 档窗口，再挑一档。"
                ),
                .init(
                    "按出杆长度执行",
                    detail: "选定以后只调杆走多长，不靠「再加把劲」。"
                ),
            ])
            LearnDocText.body("能用低档完成的，绝不用高档——误差大致随速度放大，低档走位容错也更大。训练时优先把中段（对应完整体系的 4–6）打熟，再补轻档与大力档。")
        }
    }

    // MARK: - 库当刹车

    private var cushionsAsBrakes: some View {
        LearnDocSectionCard(title: "要贴库停，不如计划撞库") {
            LearnDocText.body("想让母球停在距库大约一掌到一球杆头那段（大约 ≤ 30 cm）时，别精控成「刚好停在库前」——力度差一点就会停短或弹飞。")
            LearnDocText.body("改成：选稍重一点的档，让母球撞库后再停。库边会吃掉大量能量，速度容差能放大大约一倍以上。桌中央没有库可借时，才回到精细力度。")
            LearnDocFormulaNest(title: "和滑动停球的距离门槛") {
                LearnDocText.footnote("母球离目标球超过大约 1 钻石（约 31.75 cm）时，想打停球就不能只靠中杆——路上已经转成滚动，需要带一点后旋才能在碰撞瞬间回到滑动。")
            }
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候这样用") {
            LearnDocText.body("所有「要把母球停在某区」的决策都适用。初学先记轻 / 中 / 重三段，进阶用 5 档，再往上才铺开完整 9 档。")
            LearnDocFormulaNest(title: "体系外的两头") {
                LearnDocText.footnote("极慢推杆防守，有时比最轻档还轻——落在分档下限之外，只能单独练手感。")
                LearnDocText.footnote("极复杂的「加塞 + 速度」连续组合很少见；那时离散档只是起点，还得靠连续微调。")
            }
        }
    }

    // MARK: - 常见误区（contracts T04.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "靠「用力大小」调力度",
            right: "改成看出杆长短：短则轻、长则重。用力思维在压力下最不稳。"
        ),
        .init(
            wrong: "怕不够就直接选最重档",
            right: "误差大致随速度放大，越重越容易走位失控。能低档完成就别跳高档。"
        ),
        .init(
            wrong: "中段球也开大力",
            right: "中段走位是精度区，不是力量区。大力留给真需要长台或强分离的少数杆。"
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
                subtitle: "力度越大，沿切线先走的那段越长，再弯到约 30°",
                route: .theoryPage(.t01)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "速度决定沿切线能走多远才被旋转带弯",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "换高低杆与力度，看碰后轨迹变化",
                route: .separationAngleAtlas
            )

            LearnDocText.footnote("参数扫描叠加图本轮不做；把五档在演示页里打熟，比看一张静图更有用。")
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
