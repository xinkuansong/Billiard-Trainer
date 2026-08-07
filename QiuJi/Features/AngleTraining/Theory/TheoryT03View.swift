import SwiftUI

/// 球理详情页「切线法则」（v30 W1 试点：物理定理模板样板；返工 r1 加页内说明图 + 风格收敛）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T03-tangent-line.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T03 条目（`common_errors` / `key_data`）。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §五 T03 对照表。
/// - **配图策略（r1 改）**：两张页内真台说明图，都用共享栈 `BTTableFigure` + `FigureLine` +
///   `BTFigureBall` / `BTGhostCircle` / `BTContactDot` / `BTFigureTag`（⛔ 无 Theory 专用绘图件）：
///   ① `TangentPerpendicularFigure`（本文件）画「切线 ⊥ 连心线」；
///   ② 三条参考线复用现有学页的 `SeparationPathsFigure`（`SpinAndEnglishView.swift`，
///      `emphasizeAll: true` 三条同显）。深链降级为「看更多」。
/// - **几何真源**：`SpinAndEnglishGeometry.scene / tangentDir / objectBallEnd` +
///   `AimingMethodsGeometry.scene`（后者被前者转调）。⛔ 页内零手填坐标常量；
///   只有「线段画多长」这类纯视觉长度是本页常量（`Metrics`，米）。
/// - **坐标契约回显**（技能 `geometry-spatial-reasoning` §1）：本页图走
///   SceneKit 世界台面米坐标，水平面 = X–Z（`CGPoint.x` = 世界 X，`.y` = 世界 Z），Y 朝上，
///   原点台心，单位米；`BTTableFigure(orientation: .landscape)` ⇒ 屏幕右 = +X、屏幕上 = −Z。
///   世界 → 视图为**均匀缩放**线性映射（`Backdrop.imagePoint` 与 `TableFigureProjection.point`
///   的 x/z 系数同为 `H/(2·orthoScale)`），故世界里的直角在屏上仍是直角。
/// - **正文几何纪律**：文字表述只用两球相对关系（切线 ⊥ 连心线、连心线 = 目标球入袋方向），
///   不含依赖球桌朝向的方位词，故无 portrait / landscape 屏幕系歧义。
struct TheoryT03View: View {
    /// 共享切角 θ（5°–75°，对齐 `LearnControlStrip.Theta` 默认档）：只驱动球形。
    /// 切线本身由连心线决定 ⇒ 拖动 θ 时切线不动，正是本页要讲的「切线是纯几何」。
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    private var isHalfBall: Bool {
        abs(cutAngleDeg - AngleSceneCalculator.halfBall.cutAngleDegrees) < 0.5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t03,
                    headline: "碰撞那一瞬间，母球总是先沿切线走",
                    detail: "之后偏不偏、偏多少，取决于它此刻带着什么旋转。",
                    caption: "切线 = 过两球接触点、垂直于两球连心线的那条线。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认 30°（半球）。拖动切角只挪母球——切线跟着连心线，不跟着切角。"
                        : "母球位置随切角变了，切线方向没变：它只由两球连心线决定。下方三条路径为教学折线示意，不声称精确分离角。",
                    accessibilityIdentifier: "theoryT03.thetaSlider"
                )

                whyItWorks
                referenceLines
                curveDelay
                findTangent
                pickPosition
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "切线法则")
        .accessibilityIdentifier("theoryPage_t03")
    }

    // MARK: - 为什么一定是切线（T03 §2 直觉）+ 主图

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么一定是切线") {
            LearnDocText.body("切线是一条纯几何的线：只看碰撞那一刻两颗球在哪，跟力度、跟旋转都没有关系。")

            TangentPerpendicularFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT03.tangentFigure")

            LearnDocText.footnote("图中连心线 = 碰撞瞬间两球球心连成的线，方向就是目标球的入袋方向；切线过两球接触点、与它成 90°。")

            LearnDocText.body("两颗球接触时只能互相推、不能互相拉，所以垂直于连心线的那个方向上没有力交换。母球在这个方向上的速度被完整保留下来，只有连心线方向的那一份动量交给了目标球——于是母球离开时先走切线。")
            LearnDocText.body("「30° 法则」和「90° 法则」都是从这里长出来的：它们是切线加上两种不同旋转状态之后的特例。")
        }
    }

    // MARK: - 三条参考线（T03 §3 reference line 表）+ 复用三路径图

    private var referenceLines: some View {
        LearnDocSectionCard(title: "三条参考线") {
            LearnDocText.body("同一杆、同一条切线，母球碰后会走出三种不同的路线——差别只在碰撞那一刻它带着什么旋转。")

            SeparationPathsFigure(
                selected: .stun,
                cutAngleDeg: CGFloat(cutAngleDeg),
                emphasizeAll: true
            )
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("theoryT03.pathsFigure")

            TheoryMatrixTable(
                columnTitles: ["碰撞瞬间的旋转", "母球碰后怎么走"],
                rows: [
                    .init("滑动线", ["几乎不带前后旋", "全程沿切线走"]),
                    .init("滚动线", ["已经是自然滚动", "从切线朝原瞄准线一侧偏约 30°"]),
                    .init("后旋线", ["还带着强后旋", "朝相反一侧偏出去（约 30°），分离角大于 90°"]),
                ]
            )
            LearnDocText.footnote("图上三条是教学折线示意（相对进球线 90° / 60° / 120°），用来记住三种走向；实战分离角随切角、力度与滑动→滚动进度连续变化，见「分离角图谱」。")
            LearnDocText.footnote("要看的是碰撞那一刻的旋转，不是出杆那一刻的。中杆打远距，母球到位时往往已经转成自然滚动，走的是滚动线而不是滑动线。")
        }
    }

    // MARK: - 沿切线能走多远（T03 §3 curve delay + 抛物线）

    private var curveDelay: some View {
        LearnDocSectionCard(title: "沿切线能走多远") {
            LearnDocText.body("就算打了高杆或低杆，母球也不是一碰完就拐弯：它先沿切线走一段，之后才被旋转带弯。力度越大，这一段走得越长、弯得越晚。")
            LearnDocText.body("拐出去之后的那段轨迹是一条抛物线，一直到母球从滑动转成自然滚动为止。")
        }
    }

    // MARK: - 怎么在台上找到切线（T03 §5 三种可视化）

    private var findTangent: some View {
        LearnDocSectionCard(title: "怎么在台上把切线找出来") {
            LearnDocText.body("先看目标球到袋口那条线——那就是碰撞瞬间的连心线方向。切线垂直于它，从两球接触点出发。")
            TheoryNumberedList(steps: [
                .init(
                    "球杆比一下",
                    detail: "把球杆贴着目标球摆，让杆身垂直于目标球的入袋方向，杆身指的就是切线。"
                ),
                .init(
                    "三指量一下",
                    detail: "食指、中指、无名指并拢平贴台面，垂直于目标球的行进方向放。三指总宽差不多是一颗球（约 57 毫米），可以直接看出母球沿切线走会不会碰到旁边的球。"
                ),
                .init(
                    "V 字手势",
                    detail: "一根手指指切线，另一根指偏 30° 之后的方向，两指之间的夹角就是母球可能偏出去的范围。"
                ),
            ])
        }
    }

    // MARK: - 用切线挑走位（T03 §5.4 Come into the Line）

    private var pickPosition: some View {
        LearnDocSectionCard(title: "用切线挑走位") {
            LearnDocText.body("估出母球碰后大致会走到哪之后，再想一下下一杆的进球线——也就是下一颗目标球到袋口那条线，往母球这一侧延长出来。")
            LearnDocText.body("让母球顺着这条线的方向进入落位区，而不是横着穿过去：顺着进，力度上的容错最大；横着穿，容错最小。切角和力度就按这个来挑。")
        }
    }

    // MARK: - 适用边界（T03 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("切线方向作为母球碰后的起始方向永远成立——它来自动量分解，没有额外前提。唯一的例外是正撞直球（切角 0°）：这时切线方向退化，母球停下。")
            LearnDocFormulaNest(title: "两个容易混的说法") {
                LearnDocText.footnote("切线方向 ≠ 母球最终方向：只有滑动状态下两者才重合。")
                LearnDocText.footnote("切线 ≠ 切角：切线是一条几何方向，切角是瞄准线与进球线的夹角。")
            }
        }
    }

    // MARK: - 常见误区（contracts T03.common_errors 三条展开）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "「母球沿切线走」= 母球最后停在切线上",
            right: "只有滑动状态下才成立。带旋转时母球先沿切线走一段再拐弯，落点并不在切线上。"
        ),
        .init(
            wrong: "打高杆、距离又近，以为母球会「立刻往前跑」",
            right: "母球还是先沿切线走一段才被前旋带弯，只是近距离这一段短、容易被漏掉。"
        ),
        .init(
            wrong: "把切线画成沿着连心线的方向",
            right: "切线垂直于连心线，两者正好差 90°。画反了，预测出来的母球路线会完全错。"
        ),
    ]

    // MARK: - 页尾互链（组件规范 §六：「相关页面」.btTitle + PracticeCTA ≤2 + 文字链）

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "看切线怎么变成走位",
                destination: "分离角与走位：换杆法看母球碰后走向",
                route: .shotSimulation
            )

            LearnDocTextLink(
                title: "旋转与加塞",
                subtitle: "母球旋转四态 → 分离角：滑动沿切线，前旋后旋各偏一边",
                route: .spinAndEnglish
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "同一杆换 8 档高低杆，看碰后轨迹怎么从切线偏开",
                route: .separationAngleAtlas
            )

            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "自然滚动特例：合适厚度里碰后偏约 30°",
                route: .theoryPage(.t01)
            )
            LearnDocTextLink(
                title: "90° 法则",
                subtitle: "滑动特例：两球分离角 90°",
                route: .theoryPage(.t02)
            )
            LearnDocText.footnote("这一条还没有绑定专门的跟练题目，先用上面的演示页换着杆法看母球怎么走最直接。")
        }
    }
}

// MARK: - 主图：切线 ⊥ 连心线

/// 「切线 ⊥ 连心线」真台说明图。
///
/// 每条线都由几何真源函数给出，本视图只负责画：
/// - 连心线：`scene.ghost` → `scene.target`（= `scene.potDir` 方向，两球心距恒 2R），向两端各延一段；
/// - 切线：过接触点 `scene.contact`，方向 `SpinAndEnglishGeometry.tangentDir`（真源里
///   由「瞄准方向在 ⊥n 分量」构造 ⇒ 与 n 的点积恒为 0，单测锁定）；
/// - 直角标记：两边分别沿 `tangentDir` 与 `−potDir`，故屏上直角与世界直角同一件事；
/// - 瞄准线：`scene.cue` → `scene.ghost`；进球线：`scene.target` →
///   `SpinAndEnglishGeometry.objectBallEnd`。
private struct TangentPerpendicularFigure: View {
    let cutAngleDeg: CGFloat

    /// 纯视觉长度（世界米）：只决定线段画多长 / 直角标记画多大，不参与任何几何断言。
    private enum Metrics {
        static let tangentHalfLength: CGFloat = 0.20
        static let centerLineBackExtend: CGFloat = 0.13
        static let centerLineFrontExtend: CGFloat = 0.03
        static let rightAngleSide: CGFloat = CGFloat(AngleSceneCalculator.ballRadius) * 0.85
    }

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: cutAngleDeg)
        let n = scene.potDir
        let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
        let obEnd = SpinAndEnglishGeometry.objectBallEnd(scene: scene)

        // 取景同现有学页三路径图 / 切角全景图（`SeparationPathsFigure` / `AimingFigure`）。
        return BTTableFigure(orientation: .landscape,
                             closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let d = proj.ballDiameter
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let potFar = proj.point(x: obEnd.x, z: obEnd.y)

            let centerBack = Self.view(proj, Self.offset(scene.ghost, n, -Metrics.centerLineBackExtend))
            let centerFront = Self.view(proj, Self.offset(scene.target, n, Metrics.centerLineFrontExtend))
            let tanPlus = Self.view(proj, Self.offset(scene.contact, t, Metrics.tangentHalfLength))
            let tanMinus = Self.view(proj, Self.offset(scene.contact, t, -Metrics.tangentHalfLength))

            let s = Metrics.rightAngleSide
            let markA = Self.view(proj, Self.offset(scene.contact, t, s))
            let markB = Self.view(proj, Self.offset(Self.offset(scene.contact, t, s), n, -s))
            let markC = Self.view(proj, Self.offset(scene.contact, n, -s))
            let markTag = Self.view(
                proj, Self.offset(Self.offset(scene.contact, t, s * 2.6), n, -s * 2.6)
            )

            ZStack {
                // 瞄准线（母球 → 假想球）：弱化的白实线，只作定位参考。
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.35), lineWidth: proj.lineHintWidth)

                // 连心线（过两球心，含两端延长）：白虚线释义层。
                Path { p in p.move(to: centerBack); p.addLine(to: centerFront) }
                    .stroke(FigureLine.hint.opacity(0.85),
                            style: StrokeStyle(
                                lineWidth: proj.lineHintWidth,
                                dash: FigureLine.hintDashPattern(width: proj.lineHintWidth)
                            ))

                // 进球线（目标球 → 袋口方向）：绑目标球本色虚线。
                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)

                // 切线（过接触点，⊥ 连心线）：品牌绿短虚线 = 90° 分离角释义线语言（DR-021）。
                Path { p in p.move(to: tanMinus); p.addLine(to: tanPlus) }
                    .stroke(FigureLine.separation,
                            style: StrokeStyle(
                                lineWidth: proj.lineMainWidth,
                                dash: FigureLine.hintDashPattern(width: proj.lineMainWidth)
                            ))

                // 直角标记：两边分别沿切线与连心线。
                Path { p in
                    p.move(to: markA)
                    p.addLine(to: markB)
                    p.addLine(to: markC)
                }
                .stroke(FigureLine.separation, lineWidth: proj.lineHintWidth)

                BTContactDot(diameter: max(4, d * 0.22)).position(q)

                BTFigureTag(text: "90°", color: FigureLine.separation).position(markTag)
                BTFigureTag(text: "切线", color: FigureLine.separation)
                    .position(Self.alongLabel(from: q, to: tanPlus, t: 0.82, offset: 12))
                // 标签取「够读懂这张图」的最小集：假想球 / 接触点的解释由节内正文与
                // 三路径图承担，这里不再堆标签（两球心只隔 2R，标签会互叠）。
                BTFigureTag(text: "连心线")
                    .position(Self.alongLabel(from: centerBack, to: ghost, t: 0.02, offset: -11))
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(Self.alongLabel(from: target, to: potFar, t: 0.55, offset: -14))
                BTFigureTag(text: "母球").position(x: cue.x, y: cue.y + d / 2 + 12)
            }
        }
    }

    /// 世界点沿单位方向平移（米）。
    private static func offset(_ p: CGPoint, _ dir: CGPoint, _ meters: CGFloat) -> CGPoint {
        CGPoint(x: p.x + dir.x * meters, y: p.y + dir.y * meters)
    }

    /// 世界台面点（`.x` = 世界 X，`.y` = 世界 Z）→ 视图点。
    private static func view(_ proj: TableFigureProjection, _ p: CGPoint) -> CGPoint {
        proj.point(x: p.x, z: p.y)
    }

    /// 视图系：沿线段取点后向法向偏移，放标签（同现有学页插图做法）。
    private static func alongLabel(from a: CGPoint, to b: CGPoint,
                                   t: CGFloat, offset: CGFloat) -> CGPoint {
        let pt = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        return CGPoint(x: pt.x - dy / len * offset, y: pt.y + dx / len * offset)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        TheoryT03View()
    }
}

#Preview("Dark") {
    NavigationStack {
        TheoryT03View()
    }
    .preferredColorScheme(.dark)
}
#endif
