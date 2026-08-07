import SwiftUI

/// 球理详情页「90° 法则」（v30 W2：物理定理批；与 T01 成对——滑动 vs 自然滚动）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T02-90-degree-rule.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T02 条目。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.5。
/// - **配图判类**：A 物理几何类 → 页内真台标注图 `StunNinetyFigure`。
///   几何真源：`SpinAndEnglishGeometry.scene / tangentDir / departureDir(.stun) /
///   separationDegrees` + `objectBallEnd`。教学折线下任意 θ 分离角恒 90°。
/// - **坐标契约回显**：同 T01 / T03——SceneKit 台面米，X–Z 水平，`landscape` 屏右=+X、屏上=−Z。
struct TheoryT02View: View {
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    private var isHalfBall: Bool {
        abs(cutAngleDeg - AngleSceneCalculator.halfBall.cutAngleDegrees) < 0.5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t02,
                    headline: "滑动状态下，两球分离角正好 90°",
                    detail: "母球以纯滑动（几乎没有前后旋）撞目标球时，母球沿切线走、目标球沿连心线走，两条线互相垂直——跟切角无关。唯一例外是正撞直球：母球停下。",
                    caption: "实测因球间恢复系数略小于 1，分离角大约 85°；业余实战仍按 90° 记就够。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认 30°（半球）。绿色虚线是滑动碰后的切线；它与进球线始终成 90°。"
                        : "拖动切角只挪母球位置——分离角仍是 90°。下方为教学折线示意。",
                    accessibilityIdentifier: "theoryT02.thetaSlider"
                )

                whyItWorks
                howToGetStun
                howToUse
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "90° 法则")
        .accessibilityIdentifier("theoryPage_t02")
    }

    // MARK: - 为什么是 90°

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么一定是 90°") {
            LearnDocText.body("两颗质量差不多的球弹性相撞时：原来静止的那颗，拿走连心线方向上的全部动量；原来在动的那颗，只留下垂直于连心线的那一份速度——也就是切线方向。")

            StunNinetyFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT02.stunFigure")

            LearnDocText.footnote("绿色虚线 = 滑动碰后母球走的切线；彩色虚线 = 目标球进球线。直角标记标的就是分离角 90°——跟切角无关。")

            LearnDocText.body("两条方向天生垂直，所以分离角是 90°。这和「切线法则」是同一件事：滑动状态把切线方向完整执行到底，没有前后旋把它拽弯。")
            LearnDocText.body("自然滚动那一极则是「30° 法则」：旋转会把母球从切线往瞄准线一侧拽回来，稳定后偏约 30°。")
        }
    }

    // MARK: - 怎么做出滑动

    private var howToGetStun: some View {
        LearnDocSectionCard(title: "怎么保证碰撞瞬间是滑动") {
            LearnDocText.body("关键的是撞上目标球那一刻几乎没有前后旋，不是出杆那一刻。短距中杆往往还在滑动；同样打法打远了，母球路上已经转成自然滚动，90° 就失效了。")
            TheoryMatrixTable(
                columnTitles: ["距离大概", "怎么打"],
                rows: [
                    .init("短距（不到约 1/4 桌长）", ["中杆通常就够"]),
                    .init("中距（约 1/4–1/2 桌长）", ["击点略偏中下（约 1/4）"]),
                    .init("远距", ["击点更靠下，并配合力度，让后旋刚好衰减到 0 时撞上"]),
                ]
            )
            LearnDocText.footnote("约 1 钻石（约 31.75 cm）是停球 / 滑动距离的实用门槛：超过这个距离，中杆很难再保持滑动到碰撞瞬间。")
        }
    }

    // MARK: - 怎么用

    private var howToUse: some View {
        LearnDocSectionCard(title: "台上怎么用") {
            TheoryNumberedList(steps: [
                .init(
                    "先画出切线",
                    detail: "过两球接触点、垂直于连心线的那条线——就是母球滑动碰后会走的方向（详见「切线法则」）。"
                ),
                .init(
                    "按距离选击点",
                    detail: "照上表保证碰撞瞬间是滑动；力度只决定沿切线走多远，不改变分离方向。"
                ),
                .init(
                    "落点预判留一点余量",
                    detail: "实战大约是 85° 而不是完美 90°，所以按 90° 估完，心里稍微「过一点」是常态。"
                ),
            ])
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("碰撞瞬间没有前后旋时，任意切角（除直球外）、任意力度都成立——力度只影响沿切线走多远。目标球再撞下一颗目标球时，只要第一颗撞击瞬间也是滑动，同样适用。")
            LearnDocFormulaNest(title: "不成立的几处") {
                LearnDocText.footnote("正撞直球：母球停下，不再走切线——这是唯一例外。")
                LearnDocText.footnote("短距强后旋：到目标球时还带着后旋 → 分离角大于 90°。")
                LearnDocText.footnote("强前旋：到目标球时带着前旋 → 分离角小于 90°，往「30° 法则」靠。")
                LearnDocText.footnote("加了塞：挤偏和弧线会改掉入射方向，也容易破坏滑动假设。")
            }
        }
    }

    // MARK: - 常见误区（contracts T02.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "把直球停球和滑动 90° 混成一件事",
            right: "直球滑动：母球停下。非直球滑动：母球沿切线走，两球分离角 90°。"
        ),
        .init(
            wrong: "远距还用中杆，以为仍是滑动",
            right: "走远了母球路上已经转成自然滚动，该改用「30° 法则」，不是 90°。"
        ),
        .init(
            wrong: "盯着出杆那一刻有没有旋",
            right: "管用的是撞上目标球那一刻。短距中杆往往仍滑动；远距同样打法可能已经滚起来了。"
        ),
    ]

    // MARK: - 页尾互链

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
                title: "切线法则",
                subtitle: "90° 法则的几何祖父：碰撞瞬间先沿切线",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "自然滚动的另一极：碰后偏约 30°",
                route: .theoryPage(.t01)
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "同一杆换高低杆，看碰后轨迹怎么从切线偏开",
                route: .separationAngleAtlas
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目，先用上面的演示页把滑动和自然滚动对比看一遍最直接。")
        }
    }
}

// MARK: - 主图：滑动分离角 90°

/// 滑动碰后：切线 ⊥ 进球线（分离角 90°）。
///
/// 图元 ↔ 真源：
/// - 切线 / 滑动线 ← `tangentDir` / `departureDir(.stun)` / `pathEnd(.stun)`
/// - 进球线 ← `potDir` / `objectBallEnd`
/// - 直角 ← `separationDegrees(.stun)` 恒 90°（单测全域 θ 锁定）
private struct StunNinetyFigure: View {
    let cutAngleDeg: CGFloat

    private enum Metrics {
        static let rightAngleSide: CGFloat = CGFloat(AngleSceneCalculator.ballRadius) * 0.9
    }

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: cutAngleDeg)
        let n = scene.potDir
        let t = SpinAndEnglishGeometry.tangentDir(scene: scene)
        let stunEnd = SpinAndEnglishGeometry.pathEnd(scene: scene, state: .stun)
        let obEnd = SpinAndEnglishGeometry.objectBallEnd(scene: scene)

        return BTTableFigure(orientation: .landscape,
                             closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let d = proj.ballDiameter
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let pathFar = proj.point(x: stunEnd.x, z: stunEnd.y)
            let potFar = proj.point(x: obEnd.x, z: obEnd.y)

            let s = Metrics.rightAngleSide
            // 直角画在假想球心处：一边沿切线，一边沿进球方向。
            let markA = Self.view(proj, Self.offset(scene.ghost, t, s))
            let markB = Self.view(proj, Self.offset(Self.offset(scene.ghost, t, s), n, s))
            let markC = Self.view(proj, Self.offset(scene.ghost, n, s))
            let markTag = Self.view(
                proj, Self.offset(Self.offset(scene.ghost, t, s * 2.4), n, s * 2.4)
            )

            ZStack {
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.35), lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                Path { p in p.move(to: ghost); p.addLine(to: pathFar) }
                    .stroke(FigureLine.separation,
                            style: StrokeStyle(
                                lineWidth: proj.lineMainWidth,
                                dash: FigureLine.hintDashPattern(width: proj.lineMainWidth)
                            ))

                Path { p in
                    p.move(to: markA)
                    p.addLine(to: markB)
                    p.addLine(to: markC)
                }
                .stroke(FigureLine.separation, lineWidth: proj.lineHintWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)
                BTContactDot(diameter: max(4, d * 0.22)).position(q)

                BTFigureTag(text: "90°", color: FigureLine.separation).position(markTag)
                BTFigureTag(text: "切线", color: FigureLine.separation)
                    .position(Self.alongLabel(from: ghost, to: pathFar, t: 0.72, offset: 14))
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(Self.alongLabel(from: target, to: potFar, t: 0.55, offset: -14))
                BTFigureTag(text: "母球").position(x: cue.x, y: cue.y + d / 2 + 12)
            }
        }
    }

    private static func offset(_ p: CGPoint, _ dir: CGPoint, _ meters: CGFloat) -> CGPoint {
        CGPoint(x: p.x + dir.x * meters, y: p.y + dir.y * meters)
    }

    private static func view(_ proj: TableFigureProjection, _ p: CGPoint) -> CGPoint {
        proj.point(x: p.x, z: p.y)
    }

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
    NavigationStack { TheoryT02View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT02View() }
        .preferredColorScheme(.dark)
}
#endif
