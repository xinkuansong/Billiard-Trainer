import SwiftUI

/// 球理详情页「30° 法则」（v30 W2：物理定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T01-30-degree-rule.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T01 条目（`key_data` / `common_errors`）。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.4。
/// - **配图判类**：A 物理几何类 → 页内真台标注图 `RollThirtyDegreeFigure`。
///   几何真源：`SpinAndEnglishGeometry.scene / departureDir(.follow) / followAngleFromAimDegrees`
///   + `AimingMethodsGeometry.scene`（被前者转调）。半球 θ=30° 时教学折线相对瞄准线 ≈30°。
/// - **坐标契约回显**（技能 `geometry-spatial-reasoning` §1）：SceneKit 世界台面米坐标，
///   水平面 = X–Z（`CGPoint.x` = 世界 X，`.y` = 世界 Z），Y 朝上，原点台心，单位米；
///   `BTTableFigure(orientation: .landscape)` ⇒ 屏幕右 = +X、屏幕上 = −Z。
///   世界 → 视图为均匀缩放线性映射 ⇒ 世界夹角在屏上保持。
struct TheoryT01View: View {
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    private var isHalfBall: Bool {
        abs(cutAngleDeg - AngleSceneCalculator.halfBall.cutAngleDegrees) < 0.5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t01,
                    headline: "自然滚动的母球，在合适厚度里碰后偏约 30°",
                    detail: "球厚度落在 1/4–3/4（切角 14°–49°）时，碰后相对原瞄准线大约偏 30°；理论极值约 33.7°，出现在切角 28.1° 附近。",
                    caption: "前提：碰撞瞬间母球已是自然滚动、中杆、常规力度。滑动状态请看「90° 法则」。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认 30°（半球）。下方绿色线是自然滚动碰后的教学折线，相对瞄准线约 30°。"
                        : "非半球档：图上为教学折线示意，不声称精确偏折角。实战随切角连续变化，见「分离角图谱」。",
                    accessibilityIdentifier: "theoryT01.thetaSlider"
                )

                whyItWorks
                constantRange
                howToUse
                hangerHalfBall
                scope

                TheoryMistakeCard(mistakes: Self.mistakes)

                footerLinks
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .theoryPageChrome(title: "30° 法则")
        .accessibilityIdentifier("theoryPage_t01")
    }

    // MARK: - 为什么会偏约 30°

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么会偏约 30°") {
            LearnDocText.body("自然滚动 = 母球既往前飞、自己也在转。撞完以后，旋转带来的桌面摩擦力方向和大小都差不多恒定，轨迹就像一条抛物线：先沿切线走一段，再被摩擦力往原瞄准线一侧拽回来。")

            RollThirtyDegreeFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT01.rollFigure")

            LearnDocText.footnote("白实线 = 原瞄准线；绿色线 = 自然滚动碰后的教学折线。半球时两者夹角约 30°——这就是口诀里的「偏约 30°」。")

            LearnDocText.body("在 1/4–3/4 球厚度这一段里，「碰撞瞬间的切线」和「滑转滚之后的稳定方向」合成出来的偏折角，刚好落在约 30° 附近，所以才好记。")
        }
    }

    // MARK: - 30° 恒定区间与半球

    private var constantRange: some View {
        LearnDocSectionCard(title: "30° 在哪一段靠得住") {
            LearnDocText.body("不是任何厚度都记 30°。只在球厚度 1/4–3/4（切角 14°–49°）这一段，偏折角才大致贴着 30° 走。")

            TheoryMatrixTable(
                columnTitles: ["球厚度", "切角", "偏折角约"],
                rows: [
                    .init("1/4 球", ["约 48.6°", "约 27°"]),
                    .init("半球附近", ["约 28.1°", "33.7°（极值）"]),
                    .init("半球", ["30°", "约 34°"]),
                    .init("3/4 球", ["约 14.5°", "约 27°"]),
                ]
            )
            LearnDocText.footnote("数值照 contracts / 原文表：极值 33.7° 出现在切角 28.1°（球厚度约 0.53）。超出 14°–49° 就别硬记 30°，改查表或换「90° 法则」。")

            LearnDocFormulaNest(title: "更准一点的记法（可选）") {
                LearnDocText.footnote("自然滚动的最终方向，可以想成「5/7 沿切线 + 2/7 沿原瞄准线」——对任意切角都成立；30° 只是中间那段的速记。")
            }
        }
    }

    // MARK: - 怎么用

    private var howToUse: some View {
        LearnDocSectionCard(title: "台上怎么用") {
            TheoryNumberedList(steps: [
                .init(
                    "先看是不是自然滚动",
                    detail: "母球离目标球至少大约一颗球径、中等力度、又没明显加塞时，多半已经是自然滚动；否则先按「90° 法则」想。"
                ),
                .init(
                    "估厚度",
                    detail: "在脑子里看一眼瞄准线会撞到目标球多厚：1/4、半球还是 3/4。"
                ),
                .init(
                    "V 字手势",
                    detail: "厚度落在 1/4–3/4 里：食指对准原瞄准线，中指就是母球大概会偏出去的方向。"
                ),
                .init(
                    "力度修正",
                    detail: "打得重时，母球会先沿切线多走一段再弯到约 30°——V 字整体稍往切线一侧挪一点。慢一点反而更安全，不容易先擦到旁边的球。"
                ),
            ])
        }
    }

    // MARK: - 袋口球半球双规则

    private var hangerHalfBall: some View {
        LearnDocSectionCard(title: "袋口球：半球的两条精确走向") {
            LearnDocText.body("目标球挂在袋口附近时，业余常觉得走位余量特别小——其实半球击打有两条很干净的几何规则：")
            TheoryMatrixTable(
                columnTitles: ["母球怎么靠近", "半球打完后母球往哪走"],
                rows: [
                    .init("沿库朝角袋", ["沿对角线，朝对侧中袋离开"]),
                    .init("沿对角线朝角袋", ["沿着库边离开"]),
                ]
            )
            LearnDocText.footnote("这是 30° 法则在「目标球几乎贴着袋口」时的精确化。合适角度下，袋口球也可以当很好的关键球来用。")
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("碰撞瞬间母球已是完全自然滚动、切角在 14°–49°、常规力度、中杆——这几条都齐，才好用约 30° 来估。")
            LearnDocFormulaNest(title: "容易失效的几处") {
                LearnDocText.footnote("极薄或极厚（切角小于约 10° 或大于约 60°）：偏折角会明显离开 30°，往 0° 靠。")
                LearnDocText.footnote("短距中杆、或远距强后旋：碰撞瞬间还在滑动——改用「90° 法则」。")
                LearnDocText.footnote("加了塞：挤偏和弧线会先改掉母球实际入射方向，30° 仍可当参考，但要先校正那条入射线。")
                LearnDocText.footnote("正撞直球（切角 0°）：母球停下或前后跟进，不偏 30°。")
            }
        }
    }

    // MARK: - 常见误区（contracts T01.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "半球撞一下，以为母球会停住",
            right: "半球 + 自然滚动走的是约 30°；母球停住是直球滑动（停球）那一类，别和「90° 法则」搞混。"
        ),
        .init(
            wrong: "以为母球一碰完就立刻偏 30°",
            right: "力度越大，沿切线先走的那段越长，之后才弯到约 30°。用 30° 躲球团或防吃库时，慢一点更稳。"
        ),
    ]

    // MARK: - 页尾互链

    private var footerLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "看分离角怎么随杆法变",
                destination: "分离角与走位：换杆法看母球碰后走向",
                route: .shotSimulation
            )

            LearnDocTextLink(
                title: "90° 法则",
                subtitle: "滑动状态的另一极：两球分离角 90°",
                route: .theoryPage(.t02)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "30° 法则的几何祖父：碰撞瞬间先沿切线",
                route: .theoryPage(.t03)
            )
            LearnDocTextLink(
                title: "分离角图谱",
                subtitle: "同一杆换高低杆，看碰后轨迹怎么从切线偏开",
                route: .separationAngleAtlas
            )
            LearnDocTextLink(
                title: "瞄准原理",
                subtitle: "厚度、假想球与切角怎么对上",
                route: .aimingPrinciple
            )

            LearnDocText.footnote("这一条还没有绑定专门的跟练题目，先用上面的演示页换着杆法看母球怎么走最直接。")
        }
    }
}

// MARK: - 主图：自然滚动偏约 30°（相对瞄准线）

/// 自然滚动碰后偏折示意：瞄准线 vs 前旋/滚动教学折线，半球时夹角约 30°。
///
/// 图元 ↔ 真源：
/// - 瞄准线 ← `scene.cue` → `scene.ghost`（方向 = `scene.aimDir`）
/// - 滚动线 ← `SpinAndEnglishGeometry.departureDir(.follow)` / `pathEnd`
/// - 夹角 ← `followAngleFromAimDegrees`（半球 ≈30°，单测锁定）
/// - 进球线 ← `objectBallEnd`；球形 ← `AimingMethodsGeometry.scene`
private struct RollThirtyDegreeFigure: View {
    let cutAngleDeg: CGFloat

    private enum Metrics {
        /// 纯视觉：瞄准线向两侧延长多少（米），不参与几何断言。
        static let aimExtendBack: CGFloat = 0.08
        static let aimExtendFront: CGFloat = 0.18
        static let angleArcRadius: CGFloat = 0.10
    }

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: cutAngleDeg)
        let followEnd = SpinAndEnglishGeometry.pathEnd(scene: scene, state: .follow)
        let followDir = SpinAndEnglishGeometry.departureDir(scene: scene, state: .follow)
        let obEnd = SpinAndEnglishGeometry.objectBallEnd(scene: scene)
        let aim = scene.aimDir

        return BTTableFigure(orientation: .landscape,
                             closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let d = proj.ballDiameter
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let rollEnd = proj.point(x: followEnd.x, z: followEnd.y)
            let potFar = proj.point(x: obEnd.x, z: obEnd.y)

            let aimBack = Self.view(proj, Self.offset(scene.ghost, aim, -Metrics.aimExtendBack))
            let aimFront = Self.view(proj, Self.offset(scene.ghost, aim, Metrics.aimExtendFront))
            let arcTag = Self.view(
                proj,
                Self.offset(
                    Self.offset(scene.ghost, aim, Metrics.angleArcRadius * 0.9),
                    followDir,
                    Metrics.angleArcRadius * 0.55
                )
            )

            ZStack {
                Path { p in p.move(to: aimBack); p.addLine(to: aimFront) }
                    .stroke(FigureLine.aim.opacity(0.55), lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                Path { p in p.move(to: ghost); p.addLine(to: rollEnd) }
                    .stroke(FigureLine.separation, lineWidth: proj.lineMainWidth)

                // 夹角弧：两单位方向之间的短折线示意（非精确圆弧）。
                let a1 = Self.view(proj, Self.offset(scene.ghost, aim, Metrics.angleArcRadius))
                let a2 = Self.view(proj, Self.offset(scene.ghost, followDir, Metrics.angleArcRadius))
                Path { p in
                    p.move(to: a1)
                    p.addQuadCurve(to: a2, control: arcTag)
                }
                .stroke(FigureLine.separation.opacity(0.85), lineWidth: proj.lineHintWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)
                BTContactDot(diameter: max(4, d * 0.22)).position(q)

                BTFigureTag(text: "约 30°", color: FigureLine.separation).position(arcTag)
                BTFigureTag(text: "瞄准线")
                    .position(Self.alongLabel(from: aimBack, to: aimFront, t: 0.85, offset: -12))
                BTFigureTag(text: "滚动线", color: FigureLine.separation)
                    .position(Self.alongLabel(from: ghost, to: rollEnd, t: 0.72, offset: 14))
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
    NavigationStack { TheoryT01View() }
}

#Preview("Dark") {
    NavigationStack { TheoryT01View() }
        .preferredColorScheme(.dark)
}
#endif
