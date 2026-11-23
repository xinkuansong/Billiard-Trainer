import SwiftUI

/// 球理详情页「30° 法则」（v30 W2：物理定理批）。
///
/// - **取材**：`16.billiard_theory/theory/theorems/T01-30-degree-rule.md` §1–§5 +
///   vendored `Theory/contracts/theorem-tags.json` 的 T01 条目（`key_data` / `common_errors`）。
///   逐段取舍见 `docs/research/20260807-v30理论转写模板.md` §5.4。
/// - **配图判类**：A 物理几何类 → 页内真台标注图 `RollThirtyDegreeFigure`。
///   几何真源：`SpinAndEnglishGeometry.scene / rollingFollowDir / rollingDeflectionDegrees`
///   + `AimingMethodsGeometry.scene`（被前者转调）。偏折角按 contract T01 `key_formula`
///   随切角连续求解（半球 33.7°，14°–49° 落在 27°–33.7°），⛔ 不复用「旋转与加塞」页
///   相对进球方向固定 60° 的教学折线——那条只在半球与本页命题重合。
/// - **坐标契约回显**（技能 `geometry-spatial-reasoning` §1）：SceneKit 世界台面米坐标，
///   水平面 = X–Z（`CGPoint.x` = 世界 X，`.y` = 世界 Z），Y 朝上，原点台心，单位米；
///   `BTTableFigure(orientation: .landscape)` ⇒ 屏幕右 = +X、屏幕上 = −Z。
///   世界 → 视图为均匀缩放线性映射 ⇒ 世界夹角在屏上保持。
struct TheoryT01View: View {
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    /// 当前切角下的实际偏折角（contract T01 `key_formula`），图与文案同取一处。
    private var deflectionDeg: Double {
        Double(SpinAndEnglishGeometry.rollingDeflectionDegrees(cutAngleDeg: CGFloat(cutAngleDeg)))
    }

    /// 口诀成立区间（contract `valid_cut_range_deg`）。
    private var isInConstantRange: Bool {
        (14.0...49.0).contains(cutAngleDeg)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                TheoryPageHeader(
                    pageID: .t01,
                    headline: "自然滚动的母球，在合适厚度里碰后偏约 30°",
                    detail: "母球碰到目标球时已经自然滚动，击球厚度又在四分之一球到四分之三球之间，就可以用约 30° 预估它接下来的走向。这个角度从母球碰前的行进方向量起。",
                    caption: "先以不加左右塞的常规击球理解。自然滚动是碰球时的状态，不由高杆或中杆的名称决定。"
                )

                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isInConstantRange
                        ? String(format: "切角在约 14°–49° 的适用范围内，图中理想模型的偏折角为 %.0f°。30° 是便于判断的近似值。", deflectionDeg)
                        : String(format: "切角已超出口诀的常用范围，图中理想模型的偏折角为 %.0f°。角度连续变化，不会在边界突然改变。", deflectionDeg),
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
            .learnDocumentWidth()
        }
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .theoryPageChrome(title: "30° 法则", stableReadingNavigation: true)
        .accessibilityIdentifier("theoryPage_t01")
    }

    // MARK: - 为什么会偏约 30°

    private var whyItWorks: some View {
        LearnDocSectionCard(title: "为什么会偏约 30°") {
            LearnDocText.body("自然滚动时，母球的前进速度与转动相匹配，接触台呢的位置没有相对滑动。碰撞改变了它的前进速度，原有的前旋却仍在起作用。母球随后与台呢发生摩擦，路线从接近切线的方向逐渐弯向前方。")

            RollThirtyDegreeFigure(cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("theoryT01.rollFigure")

            LearnDocText.footnote("白实线 = 母球到假想球的原瞄准线，白虚线是它过假想球后的延长——偏折角就是从这条延长线量起；绿色线 = 自然滚动碰后的走向。拖上面的切角，两条线的夹角会跟着变。")

            LearnDocText.body("在这段常见厚度里，重新进入滚动后的走向变化相对不大，所以能用约 30° 作快速参照。图中画的是这个稳定方向；母球刚碰完时的弯曲过程，需要在实际路线中另留余量。")
        }
    }

    // MARK: - 30° 恒定区间与半球

    private var constantRange: some View {
        LearnDocSectionCard(title: "30° 在哪一段靠得住") {
            LearnDocText.body("不是任何厚度都记 30°。只在球厚度 1/4–3/4（切角 14°–49°）这一段，偏折角才大致贴着 30° 走。")

            TheoryMatrixTable(
                columnTitles: ["切角", "偏折角约"],
                rows: [
                    .init("1/4 球", ["约 48.6°", "约 27°"]),
                    .init("半球附近", ["约 28.1°", "33.7°（极值）"]),
                    .init("半球", ["30°", "约 34°"]),
                    .init("3/4 球", ["约 14.5°", "约 27°"]),
                ]
            )
            LearnDocText.footnote("表中数值来自等质量、理想碰撞模型，极值约 33.7°，出现在切角约 28.1°。超出范围后仍要看自然滚动的实际走向，不能只因厚度变了就改套 90° 法则。")

            LearnDocFormulaNest(title: "更准一点的记法（可选）") {
                LearnDocText.footnote("理想模型中，恢复滚动后的速度向量 = 5/7 × 碰后瞬间速度向量 + 2/7 × 碰前速度向量。前一项沿切线，但大小随切角变化；这不是把两条等长方向线按 5∶2 拼起来，也不是最终停点公式。")
            }
        }
    }

    // MARK: - 怎么用

    private var howToUse: some View {
        LearnDocSectionCard(title: "台上怎么用") {
            TheoryNumberedList(steps: [
                .init(
                    "先看是不是自然滚动",
                    detail: "判断到达目标球时是否已经滚起来。打点、力度、距离和台呢都会影响这个状态，不能只凭两球相隔多远来决定。"
                ),
                .init(
                    "估厚度",
                    detail: "在脑子里看一眼瞄准线会撞到目标球多厚：1/4、半球还是 3/4。"
                ),
                .init(
                    "V 字手势",
                    detail: "先练熟约 30° 的手势夹角。一指沿母球碰前方向，另一指提示碰后的大致走向；手势是估计，不是精密量角。"
                ),
                .init(
                    "力度修正",
                    detail: "同样的到球旋转状态下，速度越快，弯向稳定方向前经过的距离通常越长。附近有障碍或袋口时，要看整段路线，不能只看最后朝向。"
                ),
            ])
        }
    }

    // MARK: - 袋口球半球双规则

    private var hangerHalfBall: some View {
        LearnDocSectionCard(title: "袋口球：用半球找走位参照") {
            LearnDocText.body("袋口球能从较宽的方向打进，难点往往在母球接下来去哪。下面两种接近方向可以帮助记忆，但要先确认目标球在袋口的实际位置、击球厚度和母球旋转。")
            TheoryMatrixTable(
                columnTitles: ["半球打完后母球往哪走"],
                rows: [
                    .init("接近沿库朝角袋", ["可向斜穿台面的方向找走位"]),
                    .init("斜向接近角袋", ["可向沿库的方向找走位"]),
                ]
            )
            LearnDocText.footnote("这两行是观察方向，不保证母球必到某个袋或严格平行库边。袋口球能否作关键球，要看能不能稳定给下一颗留下合适位置。")
        }
    }

    // MARK: - 适用边界

    private var scope: some View {
        LearnDocSectionCard(title: "什么时候成立") {
            LearnDocText.body("先确认碰球时自然滚动，再看厚度是否在常用范围内。约 30° 帮你估方向，不能单独告诉你母球会走多远，也不能替代吃库和障碍判断。")
            LearnDocFormulaNest(title: "容易失效的几处") {
                LearnDocText.footnote("极薄或极厚（切角小于约 10° 或大于约 60°）：偏折角会明显离开 30°，往 0° 靠。")
                LearnDocText.footnote("仍带后旋、前旋不足或前旋过强时，都不属于自然滚动。只有到球时几乎没有前后旋的斯登状态，才用 90° 法则作参照。")
                LearnDocText.footnote("加了塞：挤偏和弧线会先改掉母球实际入射方向，30° 仍可当参考，但要先校正那条入射线。")
                LearnDocText.footnote("自然滚动的正撞直球，母球碰后会继续向前跟进，不向侧面偏 30°。")
            }
        }
    }

    // MARK: - 常见误区（contracts T01.common_errors）

    private static let mistakes: [TheoryMistakeCard.Mistake] = [
        .init(
            wrong: "半球撞一下，以为母球会停住",
            right: "半球自然滚动时，母球碰后仍会向侧前方走。直球停球需要到球时几乎没有前后旋，是另一种状态。"
        ),
        .init(
            wrong: "以为母球一碰完就立刻偏 30°",
            right: "30° 说的是恢复滚动后的大致方向。障碍很近时，还要检查碰后最初那段路线；只看远处朝向可能漏掉碰球或落袋风险。"
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
                subtitle: "到球时几乎没有前后旋，用近似 90° 判断分离方向",
                route: .theoryPage(.t02)
            )
            LearnDocTextLink(
                title: "切线法则",
                subtitle: "先找切线参照，再理解前旋如何改变路线",
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

/// 自然滚动碰后偏折示意：瞄准线 vs 滚动线，夹角随切角连续变化（半球 ≈34°，口诀取整 30°）。
///
/// 图元 ↔ 真源：
/// - 瞄准线 ← `scene.cue` → `scene.ghost`（方向 = `scene.aimDir`），过假想球后以白虚线延长，
///   延长线即偏折角的量角基准
/// - 滚动线 ← `SpinAndEnglishGeometry.rollingFollowDir` / `rollingFollowEnd`
/// - 夹角读数 ← `rollingDeflectionDegrees(cutAngleDeg:)`（contract T01 `key_formula`，单测对拍
///   「5/7 切线 + 2/7 瞄准线」向量法）；⛔ 不写死 30°，否则非半球档标签与图形自相矛盾
/// - 进球线 ← `objectBallEnd`；球形 ← `AimingMethodsGeometry.scene`
private struct RollThirtyDegreeFigure: View {
    let cutAngleDeg: CGFloat

    /// 纯视觉长度（世界米）：只决定线画多长 / 角弧画多大，不参与几何断言。
    private enum Metrics {
        static let aimExtendFront: CGFloat = 0.20
        static let rollLength: CGFloat = 0.28
        static let angleArcRadius: CGFloat = 0.11
        /// 角标锚点：沿角平分线外推 + 朝滚动线一侧让位。
        /// 小切角时夹角只有十几度，标签放在角平分线上会压到目标球与进球线，故必须侧让。
        static let angleTagRadius: CGFloat = 0.105
        static let angleTagSideShift: CGFloat = 0.058
    }

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: cutAngleDeg)
        let rollDir = SpinAndEnglishGeometry.rollingFollowDir(scene: scene)
        let rollWorldEnd = SpinAndEnglishGeometry.rollingFollowEnd(scene: scene,
                                                                   length: Metrics.rollLength)
        let deflection = SpinAndEnglishGeometry.rollingDeflectionDegrees(cutAngleDeg: cutAngleDeg)
        let obEnd = SpinAndEnglishGeometry.objectBallEnd(scene: scene)
        let aim = scene.aimDir

        return BTTableFigure(orientation: .landscape,
                             closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let d = proj.ballDiameter
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let rollEnd = proj.point(x: rollWorldEnd.x, z: rollWorldEnd.y)
            let potFar = proj.point(x: obEnd.x, z: obEnd.y)

            let aimFront = Self.view(proj, Self.offset(scene.ghost, aim, Metrics.aimExtendFront))
            let bisector = Self.unit(CGPoint(x: aim.x + rollDir.x, y: aim.y + rollDir.y))
            let sideShift = Self.unit(CGPoint(
                x: rollDir.x - bisector.x * (rollDir.x * bisector.x + rollDir.y * bisector.y),
                y: rollDir.y - bisector.y * (rollDir.x * bisector.x + rollDir.y * bisector.y)
            ))
            let arcControl = Self.view(
                proj, Self.offset(scene.ghost, bisector, Metrics.angleArcRadius * 1.12)
            )
            let arcTag = Self.view(
                proj,
                Self.offset(
                    Self.offset(scene.ghost, bisector, Metrics.angleTagRadius),
                    sideShift,
                    Metrics.angleTagSideShift
                )
            )

            ZStack {
                // 瞄准线（母球 → 假想球）：白实线主线，图上「原瞄准线」的本体。
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.85), lineWidth: proj.lineMainWidth)

                // 瞄准线延长（假想球 → 前方）：白虚线对照层，偏折角就是从它量起。
                Path { p in p.move(to: ghost); p.addLine(to: aimFront) }
                    .stroke(FigureLine.hint.opacity(0.7),
                            style: StrokeStyle(
                                lineWidth: proj.lineHintWidth,
                                dash: FigureLine.hintDashPattern(width: proj.lineHintWidth)
                            ))

                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                Path { p in p.move(to: ghost); p.addLine(to: rollEnd) }
                    .stroke(FigureLine.separation, lineWidth: proj.lineMainWidth)

                // 夹角弧：两单位方向之间的短折线示意（非精确圆弧）。
                let a1 = Self.view(proj, Self.offset(scene.ghost, aim, Metrics.angleArcRadius))
                let a2 = Self.view(proj, Self.offset(scene.ghost, rollDir, Metrics.angleArcRadius))
                Path { p in
                    p.move(to: a1)
                    p.addQuadCurve(to: a2, control: arcControl)
                }
                .stroke(FigureLine.separation.opacity(0.85), lineWidth: proj.lineHintWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)
                BTContactDot(diameter: max(4, d * 0.22)).position(q)

                BTFigureTag(text: String(format: "偏 %.0f°", deflection),
                            color: FigureLine.separation)
                    .position(arcTag)
                BTFigureTag(text: "瞄准线")
                    .position(Self.alongLabel(from: cue, to: ghost, t: 0.5, offset: -13))
                BTFigureTag(text: "滚动线", color: FigureLine.separation)
                    .position(Self.alongLabel(from: ghost, to: rollEnd, t: 0.85, offset: 14))
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(Self.alongLabel(from: target, to: potFar, t: 0.72, offset: -14))
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

    private static func unit(_ v: CGPoint) -> CGPoint {
        let len = hypot(v.x, v.y)
        guard len > 1e-9 else { return .zero }
        return CGPoint(x: v.x / len, y: v.y / len)
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
