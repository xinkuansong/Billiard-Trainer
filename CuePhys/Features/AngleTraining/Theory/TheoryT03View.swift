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
                    headline: "先找切线，再判断母球会怎样偏离",
                    detail: "切线给碰后的母球一个方向参照。到球时几乎没有前后旋，路线接近这个方向；带着前旋或后旋时，后续路线会向不同一侧弯开。",
                    caption: "两球接触处的切线垂直于连心线。判断球心路线时，要把同方向的参照线移到碰撞时的母球中心。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认切角 30°，也就是半球。图中目标球进球方向固定，因此与它垂直的切线方向也固定。"
                        : "本图改变母球入射方向，目标球进球方向保持不变。三条路径用于比较杆法，不是当前切角下的精确轨迹。",
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
            .learnDocumentWidth()
        }
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .theoryPageChrome(title: "切线法则", stableReadingNavigation: true)
        .accessibilityIdentifier("theoryPage_t03")
    }

    // MARK: - 为什么一定是切线（T03 §2 直觉）+ 主图

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "切线给了我们什么参照") {
            LearnDocText.body("先把碰撞时的两个球心连起来，再找垂直于连心线的方向，这就是这里说的切线方向。几何方向本身不随力度变化，但实际母球是否沿它走，还要看碰撞条件和旋转。")

            TangentPerpendicularFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT03.tangentFigure")

            LearnDocText.footnote("图中按理想碰撞画出连心线与目标球方向的对应，直角标记说明垂直关系。实战中的投掷可能使目标球偏离连心线方向。")

            LearnDocText.body("在等质量、完全弹性且忽略球间摩擦的模型里，母球沿连心线的速度分量传给目标球，切向分量保留下来，因此碰后瞬间沿切线方向运动。真实碰撞会有能量损失和摩擦，所以把切线当参照比把它当绝对路线更合适。")
            LearnDocText.body("90° 法则用它描述斯登球的分离方向；30° 法则则继续考虑自然滚动母球碰后的旋转变化。两者有关联，但角度的测量基准不同。")
        }
    }

    // MARK: - 三条参考线（T03 §3 reference line 表）+ 复用三路径图

    private var referenceLines: some View {
        LearnDocSectionCard(title: "三条参考线") {
            LearnDocText.body("同一球形下，改变到球时的前后旋，可以比较母球怎样从切线附近向两侧偏开。先认识方向差别，再到演示页看完整路线。")

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
                    .init("斯登", ["几乎没有前后旋", "碰后大致沿切线方向走"]),
                    .init("自然滚动", ["前进与转动匹配", "后续向前弯；合适厚度内，相对碰前方向偏约 30°"]),
                    .init("后旋", ["到球时仍在倒转", "后续向后旋一侧弯，幅度取决于剩余后旋与球形"]),
                ]
            )
            LearnDocText.footnote("图上三条是教学折线示意（相对进球线 90° / 60° / 120°），用来记住三种走向；实战分离角随切角、力度与滑动→滚动进度连续变化，见「分离角图谱」。")
            LearnDocText.footnote("看的是碰球时的状态。母球带后旋时也可能在台呢上滑动，所以不能把所有滑动都叫斯登；斯登特指到球时几乎没有前后旋。")
        }
    }

    // MARK: - 沿切线能走多远（T03 §3 curve delay + 抛物线）

    private var curveDelay: some View {
        LearnDocSectionCard(title: "碰后最初那段路线也要看") {
            LearnDocText.body("带前后旋时，母球碰后会逐渐改变方向。靠近碰撞点的路线可能看起来接近切线，但不代表它先走完一段固定直线才开始转弯。同样旋转状态下，速度越快，方向变化展开的距离通常越长。")
            LearnDocText.body("因此，切线附近有球或袋口时，不能只看母球最终朝向。要同时检查最初离开的位置、弯曲过程以及之后的停位。")
        }
    }

    // MARK: - 怎么在台上找到切线（T03 §5 三种可视化）

    private var findTangent: some View {
        LearnDocSectionCard(title: "怎么在台上把切线找出来") {
            LearnDocText.body("先按理想进球方向找到假想球，再过假想球中心看一条垂直方向。这样观察的是母球球心将经过的位置，不会把两球接触处的切线误当球心路线。")
            TheoryNumberedList(steps: [
                .init(
                    "球杆比一下",
                    detail: "练习时用杆身在空中比出与目标球进球方向垂直的方向，不碰动台上的球，再把这个方向对应到假想球中心。"
                ),
                .init(
                    "三指量一下",
                    detail: "手指可以帮助估计通道宽度，但每个人的手宽不同。先与实际球径对照；判断会不会碰到旁边的球，还要给母球本身的半径留位置。"
                ),
                .init(
                    "V 字手势",
                    detail: "用手势比较两条方向。使用 30° 口诀时，一指要沿母球碰前方向，不能把切线当作 30° 的起点；后旋也没有统一偏 30° 的规则。"
                ),
            ])
        }
    }

    // MARK: - 用切线挑走位（T03 §5.4 Come into the Line）

    private var pickPosition: some View {
        LearnDocSectionCard(title: "用切线挑走位") {
            LearnDocText.body("估出母球碰后大致会走到哪之后，再想一下下一杆的进球线——也就是下一颗目标球到袋口那条线，往母球这一侧延长出来。")
            LearnDocText.body("如果母球能沿着所需落位区较长的方向进入，走长或走短一点仍可能留下合适角度。横穿很窄的区域时，力度就更难控制。先选有余量的路线，再配合打点和力度，不为追求一条线而增加不必要的难度。")
        }
    }

    // MARK: - 适用边界（T03 §4）

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("垂直于连心线的方向始终可以作为几何参照；母球严格沿这个方向离开，则有理想碰撞的前提。直球时没有侧向速度分量，斯登接近停住，前旋会跟进，后旋会拉回。")
            LearnDocFormulaNest(title: "两个容易混的说法") {
                LearnDocText.footnote("切线方向不等于最终停位：即使斯登方向判断正确，速度和之后的吃库仍会影响停点。")
                LearnDocText.footnote("切线 ≠ 切角：切线是一条几何方向，切角是瞄准线与进球线的夹角。")
            }
        }
    }

    // MARK: - 常见误区（contracts T03.common_errors 三条展开）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "「母球沿切线走」= 母球最后停在切线上",
            right: "斯登时可以沿切线估方向；带前后旋时，后续路线会弯开。还要把吃库和速度一起考虑，才能判断停位。"
        ),
        .init(
            wrong: "打高杆、距离又近，以为母球会「立刻往前跑」",
            right: "先观察母球从碰撞点怎样离开，再看前旋如何改变后续路线。不要把高杆理解成母球一碰球就沿目标球方向前进。"
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
                subtitle: "区分到球时的斯登、前旋与后旋",
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
                subtitle: "理想斯登时，两球出射方向相差 90°",
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
                // 瞄准线（母球 → 假想球）：白实线，主线宽保证在台呢底图上可读。
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.75), lineWidth: proj.lineMainWidth)

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
