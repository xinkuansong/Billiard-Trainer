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
                    headline: "球团要尽早识别、尽早处理",
                    detail: "由能自然路过它的球去碰开，用最低必要力度；绝不在低成功率球上去破，绝不留到收官三球。",
                    caption: "桌上有至少一个球团时永远适用。球团：两颗及以上几乎相邻，或相互挡住进球 / 走位。"
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
        LearnDocSectionCard(title: "不确定性放在前面消解") {
            LearnDocText.body("球团是清台里最大的不确定性——破开后球落到哪里几乎不可预测。把难题放在你还有很多备用球时解决；留到最后，等于在关键球阶段引入随机性，几乎必败。")

            ClusterPhaseFigure()
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("theoryT07.phaseFigure")
                .accessibilityLabel("球团处理三段：识别所有球团并排优先级；绑定路过球与保险球；顺序上必须排在关键球之前。")

            LearnDocText.footnote("「保险球」是必备的承转球：万一球团没破开或破得不好，仍有一颗备用入袋球能继续清台。")

            LearnDocText.body("早期消解给你多颗球的容错；晚期消解只剩一两颗容错。给高方差操作配一个低方差备份，整盘的把握才抬得起来。")
        }
    }

    // MARK: - 三段式（T07 §5）

    private var threePhases: some View {
        LearnDocSectionCard(title: "处理球团的三段式") {
            TheoryNumberedList(steps: [
                .init(
                    "识别",
                    detail: "扫桌时标出所有球团，估计每个里被埋住的关键球。优先级：埋住未来关键球的 → 挡死己方多颗球的 → 挡袋的 → 单纯挡走位的。"
                ),
                .init(
                    "绑定",
                    detail: "为每个球团找一颗「路过的承转球」——它的母球落位自然带母球去碰开球团；同时找保险球。没有保险球时，推迟处理，先称风险。"
                ),
                .init(
                    "顺序",
                    detail: "倒推规划里，球团处理点必须排在关键球之前。力度若需要中重及以上，降到中等档——破开就行，不必散得很远。"
                ),
            ])
            LearnDocFormulaNest(title: "优先级一句话") {
                LearnDocText.footnote("先破「埋住未来关键球」或「挡死必入球」的；后破轻微球团。")
            }
        }
    }

    // MARK: - 四禁忌（T07 §5）

    private var taboos: some View {
        LearnDocSectionCard(title: "四禁忌") {
            TheoryNumberedList(steps: [
                .init("别用最后一颗普通球去破", detail: "那颗不是承转球，破完往往无路可走。"),
                .init("别留到剩三颗及以下", detail: "收官三球阶段再破球团，容错几乎为零。"),
                .init("别在低成功率球上破", detail: "打不进又破不好，双重损失——该想防守。"),
                .init("别朝被堵袋口方向破", detail: "也不要打得让己方关键球被堵住。"),
            ])
        }
    }

    // MARK: - 适用边界（T07 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候可以松、什么时候别破") {
            LearnDocText.body("破解会破坏关键球安排时（罕见），可推迟一杆。小球团且余球丰富，可以等到周围散球清完再破。")
            LearnDocText.body("没有保险球时：唯一选择是专门用一杆破，并接受随机性——先称「值不值得冒险」。")
            LearnDocText.body("本方没有清台路径时，球团反而是宝贵的母球藏身资源——此时不应主动破，留作防守用。")
            LearnDocText.body("有一种极端说法：球团没解前不打任何能进的球。球多时可能太激进、会留太多球妨碍走位——只作重球团局面的指导，不作硬规则。")
        }
    }

    // MARK: - 常见误区（contracts T07.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "上台扫桌时忽略球团",
            right: "球团是最大不确定性。没在识别阶段标出来，后面的倒推全是空中楼阁。"
        ),
        .init(
            wrong: "用最后一颗散球去砸球团",
            right: "破完往往无路可走。要用能自然路过的承转球，并先备好保险球。"
        ),
        .init(
            wrong: "用最重的力度砸开",
            right: "力度过大，母球失控、球落死角。破开就行，优先最低必要力度；需要中重时也降到中等档。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "破不开时先称风险",
                destination: "风险报酬决策矩阵：低成功率球上破球团，先过三问",
                route: .theoryPage(.t08)
            )

            LearnDocTextLink(
                title: "反向规划",
                subtitle: "球团是倒推里的先决约束",
                route: .theoryPage(.t05)
            )
            LearnDocTextLink(
                title: "关键球原理",
                subtitle: "球团不能埋住关键球；破解排在关键球之前",
                route: .theoryPage(.t06)
            )
            LearnDocTextLink(
                title: "安全球三维度模型",
                subtitle: "清不了时，球团可作障碍球维度的藏身资源",
                route: .theoryPage(.t10)
            )
            LearnDocTextLink(
                title: "母球速度分级",
                subtitle: "破球团用最低必要力度，靠出杆长度控档",
                route: .theoryPage(.t04)
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目：开球后先标球团与保险球，再想关键球，最见效。")
        }
    }
}

// MARK: - 抽象图示：三段式流程

/// 识别 → 绑定 → 顺序（非球形，红线 5 合规）。
private struct ClusterPhaseFigure: View {
    private static let phases = [
        ("① 识别", "标球团\n排优先级"),
        ("② 绑定", "路过球\n+ 保险球"),
        ("③ 顺序", "排在\n关键球前"),
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

                Text("没有保险球 → 推迟 + 先称风险")
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
