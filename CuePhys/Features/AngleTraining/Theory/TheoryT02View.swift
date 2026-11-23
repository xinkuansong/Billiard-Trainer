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
                    headline: "到球时没有前后旋，先用 90° 判断走向",
                    detail: "母球碰到目标球时几乎没有前后旋，这种状态叫斯登。切球时，母球大致沿切线离开，与目标球的走向接近垂直；正撞直球则接近停球。",
                    caption: "严格 90° 来自等质量、完全弹性且忽略球间摩擦的模型。实际偏差随条件变化，不能统一修正为 85°。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认切角 30°，也就是半球。绿色虚线为理想斯登的切线方向，与目标球方向成 90°。"
                        : "改变切角，观察理想斯登的两条分离方向。图中的直角是几何参照，不是实测修正角。",
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
            .learnDocumentWidth()
        }
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .theoryPageChrome(title: "90° 法则", stableReadingNavigation: true)
        .accessibilityIdentifier("theoryPage_t02")
    }

    // MARK: - 为什么是 90°

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "直角从哪里来") {
            LearnDocText.body("先看一个简化的碰撞：两球质量相同，目标球静止，碰撞完全弹性，并忽略球间摩擦。母球沿连心线的速度分量传给目标球，自己留下垂直于连心线的分量，也就是切线方向。")

            StunNinetyFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT02.stunFigure")

            LearnDocText.footnote("绿色虚线表示母球的理想离开方向，彩色虚线表示目标球方向。这里的 90° 是两球分离角，不是出杆前的切角。")

            LearnDocText.body("到球时没有前后旋，母球碰后就不会因前后旋而明显弯离这条参照方向。因此，切线能帮助你判断母球先往哪边走，再用速度判断走多远。")
            LearnDocText.body("如果到球时已经自然滚动，就要考虑前旋带来的后续弯曲。在合适厚度内，可用 30° 法则估计稳定走向；它量的是相对母球碰前方向的偏折，和这里的分离角不是同一个角。")
        }
    }

    // MARK: - 怎么做出滑动

    private var howToGetStun: some View {
        LearnDocSectionCard(title: "怎样把斯登状态送到目标球") {
            LearnDocText.body("关键是到球那一刻，而不是刚出杆时。常见做法是用中下打点，让母球起初带一点后旋；后旋沿途衰减，到目标球附近恰好接近零。距离和力度变了，合适的打点也会变。")
            TheoryMatrixTable(
                columnTitles: ["怎样理解"],
                rows: [
                    .init("距离较近", ["到球前旋转变化较少，打点要避免留下过多后旋"]),
                    .init("距离增加", ["通常需要更低的打点或更快的速度，延后转为前旋"]),
                    .init("换台呢或力度", ["重新核对到球状态，旧的距离与打点搭配未必适用"]),
                ]
            )
            LearnDocText.footnote("先用直球停球练习建立参照，再把相近的到球状态用于切球。没有一个固定距离，能替所有台呢、力度和打点划出斯登的边界。")
        }
    }

    // MARK: - 怎么用

    private var howToUse: some View {
        LearnDocSectionCard(title: "台上怎么用") {
            TheoryNumberedList(steps: [
                .init(
                    "先画出切线",
                    detail: "先确定目标球的进球方向，再找与它垂直的方向。估母球球心路线时，从碰撞时的母球中心，也就是假想球中心，沿这个方向看出去。"
                ),
                .init(
                    "配合打点与力度",
                    detail: "用熟悉的停球参照判断到球状态。想改变母球走多远时，也要复核改力度后是否仍是斯登，不能只改速度而忽略旋转。"
                ),
                .init(
                    "落点预判留一点余量",
                    detail: "切线附近有袋口或障碍时，不要让预计路线刚好擦着通过。真实碰撞和出杆都有偏差，具体修正应来自当前球形的练习反馈。"
                ),
            ])
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("对有明确切角的斯登球，90° 是很有用的近似参照。它不保证真实球台上的每一杆都形成严格直角。目标球再撞另一颗球时，也必须重新判断那一刻的运动状态，不能直接照搬上一撞的结论。")
            LearnDocFormulaNest(title: "不成立的几处") {
                LearnDocText.footnote("正撞直球：斯登时母球接近停下，没有可比较的两条离开方向。接近擦边的极薄球，目标球运动很小，也不适合拿直角作精细判断。")
                LearnDocText.footnote("到球时仍有后旋，母球后续路线会向后弯，通常偏到切线的另一侧；不能把这条弯曲路线当成斯登直线。")
                LearnDocText.footnote("前旋会让母球后续路线偏向前方；只有到球时自然滚动且厚度合适，才进一步使用约 30° 的口诀。")
                LearnDocText.footnote("左右塞需要另考虑挤偏、弧线和投掷；两球的真实离开方向未必与图中一致。")
            }
        }
    }

    // MARK: - 常见误区（contracts T02.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "以为斯登一定会让母球停住",
            right: "直球斯登接近停球；切球斯登仍会向切线方向走。到球状态相近，击球厚度不同，结果也不同。"
        ),
        .init(
            wrong: "远距还用中杆，以为到球时仍是斯登",
            right: "距离增加后，同样打点和力度可能已让母球滚起来。先判断实际旋转，再选择方向参照，不按距离直接套规则。"
        ),
        .init(
            wrong: "盯着出杆那一刻有没有旋",
            right: "有后旋不等于到球时仍有后旋，中杆也不保证斯登。观察直球能否停住，能帮助你建立打点、力度与距离的对应关系。"
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
                subtitle: "理解垂直方向，并从母球中心判断路线",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "30° 法则",
                subtitle: "自然滚动时，相对碰前方向估计偏折",
                route: .theoryPage(.t01)
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "同一杆换高低杆，看碰后轨迹怎么从切线偏开",
                route: .separationAngleAtlas
            )

            LearnDocText.footnote("在演示页对比斯登与自然滚动，再到球台上核对：同一条进球线，母球为什么会走向不同的位置。")
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
                // 瞄准线（母球 → 假想球）：白实线，主线宽保证在台呢底图上可读。
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.75), lineWidth: proj.lineMainWidth)

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
                BTFigureTag(text: "瞄准线")
                    .position(Self.alongLabel(from: cue, to: ghost, t: 0.5, offset: -13))
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
