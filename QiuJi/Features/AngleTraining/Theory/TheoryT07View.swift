import SwiftUI

/// 球理详情页「球团管理」（v30 W3：战术定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T07-cluster-management.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T07 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.10。
/// - **配图判类**：B 战术决策类 → 非球形抽象图示 `ClusterPhaseFigure`
///   （识别 → 绑定 → 顺序）。⛔ 不画具体球形局面（红线 5）。
struct TheoryT07View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t07,
                    headline: "尽早看见球团，选好时机再处理",
                    detail: "先判断哪些球真的妨碍清台，再找能顺路碰开的机会。准备进攻时，尽量趁备用球还多处理难题；没有可靠后续时，也可以保留球团用于防守。",
                    caption: "球团不只指靠在一起的球，也包括相互挡住进球或走位的组合。靠得近，不一定需要碰开。"
                )

                whyItWorks
                threePhases
                taboos
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "球团管理")
        .accessibilityIdentifier("theoryPage_t07")
    }

    // MARK: - 为什么要早处理（T07 §2）

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么通常要提前考虑") {
            LearnDocText.body("碰开球团后，球的位置会变化，原来的路线也可能跟着改变。桌上还有可用球时处理，比较容易找到下一杆；把所有散球打完才碰，选择就少了。因此要尽早安排，未必是上来第一杆就碰。")

            ClusterPhaseFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT07.phaseFigure")
                .accessibilityLabel("球团处理三段：识别问题球，寻找碰球机会和保险球，再安排合适的处理顺序。")

            LearnDocText.footnote("保险球是碰开后仍有希望接着打的备用球。要看母球可能停在哪里，以及通道会不会被挡，不能只挑一颗离袋近的球就算有保险。")

            LearnDocText.body("处理前想两种结果：顺利散开后打谁；只松开一点，或母球被挡住时怎么办。能预留后续选择，才是真正降低了这次碰球的风险。")
        }
    }

    // MARK: - 三段式（T07 §5）

    private var threePhases: some View {
        LearnDocSectionCard(title: "处理球团的三段式") {
            TheoryNumberedList(steps: [
                .init(
                    "识别",
                    detail: "先找不能直接进袋、挡住必要通道或影响关键衔接的球。根据清台计划判断先处理哪组，不按外观紧不紧来决定。"
                ),
                .init(
                    "绑定",
                    detail: "寻找进球后母球能顺路碰到球团的球，同时保留保险球。看清接触球团的哪一侧，以及母球会继续走还是容易被夹住。"
                ),
                .init(
                    "顺序",
                    detail: "尽量在收尾前处理，以便重新安排路线。力度以足够打开所需通道为准；太轻打不开，太重可能撞乱好球，要结合接触位置和后续落点选择。"
                ),
            ])
            LearnDocFormulaNest(title: "优先级一句话") {
                LearnDocText.footnote("先解决真正挡住计划的问题；能直接打、能绕开或对防守有用的球团，不必为了散开而散开。")
            }
        }
    }

    // MARK: - 四禁忌（T07 §5）

    private var taboos: some View {
        LearnDocSectionCard(title: "四件容易忽略的事") {
            TheoryNumberedList(steps: [
                .init("留下后续选择", detail: "用掉最后一颗散球前，确认碰开后仍有可打的球，或有能接受的防守结果。"),
                .init("别无意拖到收尾", detail: "剩球越少，补救选择通常越少。确实要晚处理，应当有明确的接近路线和后续安排。"),
                .init("把进球和碰球一起评估", detail: "进球本身已经困难时，再承担破球团任务，整杆风险会增加；与防守或先改善位置比较。"),
                .init("看球会散向哪里", detail: "避免把球推向堵住的袋口、压住关键球，或让母球进入容易被挡的位置。"),
            ])
        }
    }

    // MARK: - 适用边界（T07 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候可以松、什么时候别破") {
            LearnDocText.body("当前接近角不好，或碰开会撞乱已经安排好的球时，可以先换位置。提前清掉挡路的散球也有意义，但不要顺手把保险球一起打没了。")
            LearnDocText.body("没有保险球时，先比较能否创造更好的机会、边处理边防守，或暂时不动球团。直接碰开只是选项之一，不是唯一选择。")
            LearnDocText.body("本方暂时没有清台路径时，球团可能限制对手，也可能用来遮挡母球。主动打开之前，要同时看它会给对手带来什么机会。")
            LearnDocText.body("「尽早处理」是一种安排顺序的提醒，不是必须马上破球的命令。先把需要解决的问题看清，再选能完成任务、后果可控的时机。")
        }
    }

    // MARK: - 常见误区（contracts T07.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "上台扫桌时忽略球团",
            right: "先找出妨碍进球与衔接的球，再规划顺序，避免打到一半才发现路线不通。"
        ),
        .init(
            wrong: "用最后一颗散球去砸球团",
            right: "先看碰开后还能打谁。尽量保留保险球；没有可靠后续时，比较能否换时机处理，或边处理边防守。"
        ),
        .init(
            wrong: "用最重的力度砸开",
            right: "先选接触位置，再选足够打开通道的力度。不能盲目加大，也不能把所有碰球一律降成中等力度。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "比较碰开后的收益与代价",
                destination: "风险报酬决策矩阵：把进球、走位和失败后果一起考虑",
                route: .theoryPage(.t08)
            )

            LearnDocTextLink(
                title: "反向规划",
                subtitle: "把处理问题球的机会放进顺序里",
                route: .theoryPage(.t05)
            )
            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "处理球团时保留收尾所需的衔接",
                route: .theoryPage(.t06)
            )
            LearnDocTextLink(
                title: "安全球三维度模型",
                subtitle: "没有清台路线时，看看球团的防守价值",
                route: .theoryPage(.t10)
            )
            LearnDocTextLink(
                title: "母球速度分级",
                subtitle: "选足够完成任务、又容易重复的力度",
                route: .theoryPage(.t04)
            )

            LearnDocText.footnote("练习时先说明要打开哪条通道、碰开后准备打谁，再观察实际结果，逐步熟悉接触位置与力度的配合。")
        }
    }
}

// MARK: - 抽象图示：三段式流程

/// 识别 → 绑定 → 顺序（非球形，红线 5 合规）。
private struct ClusterPhaseFigure: View {
    private static let phases = [
        ("① 识别", "标球团\n排优先级"),
        ("② 绑定", "路过球\n+ 保险球"),
        ("③ 顺序", "安排时机\n保留后续"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cardW = w * 0.26
            let cardH = h * 0.42
            let xs = [w * 0.18, w * 0.50, w * 0.82]
            let y = h * 0.40

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btBGTertiary.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                ForEach(0..<2, id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: xs[i] + cardW * 0.42, y: y))
                        p.addLine(to: CGPoint(x: xs[i + 1] - cardW * 0.42, y: y))
                    }
                    .stroke(Color.btPrimary, lineWidth: 1.5)
                    Path { p in
                        let tip = CGPoint(x: xs[i + 1] - cardW * 0.42, y: y)
                        p.move(to: tip)
                        p.addLine(to: CGPoint(x: tip.x - 6, y: tip.y - 4))
                        p.addLine(to: CGPoint(x: tip.x - 6, y: tip.y + 4))
                        p.closeSubpath()
                    }
                    .fill(Color.btPrimary)
                }

                ForEach(Array(Self.phases.enumerated()), id: \.offset) { i, phase in
                    VStack(spacing: 6) {
                        Text(phase.0)
                            .font(.btCaption.weight(.semibold))
                            .foregroundStyle(.btPrimary)
                        Text(phase.1)
                            .font(.btCaption2)
                            .foregroundStyle(.btTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: cardW, height: cardH)
                    .background(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .fill(Color.btBGSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.sm)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )
                    .position(x: xs[i], y: y)
                }

                Text("没有保险球 → 先比较风险与替代方案")
                    .font(.btCaption2)
                    .foregroundStyle(.btWarning)
                    .position(x: w * 0.50, y: h * 0.84)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack { TheoryT07View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT07View() }
        .preferredColorScheme(.dark)
}
#endif
