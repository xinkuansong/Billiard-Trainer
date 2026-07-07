import SwiftUI
import SceneKit

/// 瞄准原理（问题集合条 1 生产级重组）：
/// ① 名词系统（母球/目标球/假想球/瞄准线/进球线/瞄准点/接触点，配图逐一标注）
/// ② 为什么用角度瞄准（第三人称角度 → 第一人称瞄准点的转化）
/// ③ 什么是切角（θ 标在瞄准线与进球线**反向延长线**的夹角处）
/// ④ 公式推导（d = 2R·sin(θ) 的几何来历，配直角三角形推导图）
/// ⑤ 核心公式速查 ⑥ 假想球法三步 ⑦ 厚薄球对照 ⑧ 练习导流
struct AimingPrincipleView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                termsSection
                whyAngleSection
                cutAngleSection
                derivationSection
                coreFormulaSection
                ghostBallSection
                thicknessSection
                // 学→练导流（T-P18-51）：原理学完 → 抽象估角第 1 步。
                PracticeCTA(title: "去练一练",
                            destination: "角度预测 · 检验你的估角直觉",
                            route: .geometricQuiz)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("瞄准原理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Section 1: 名词系统

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("名词系统")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("先统一语言：后面所有页面（学习、训练、对局）都使用同一套名词与同一套线条样式。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            AimingFigure(showsGlossaryLabels: true)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                termRow("母球", "你用球杆直接击打的白球。")
                termRow("目标球", "你想送进袋口的球。")
                termRow("假想球", "与母球等大的虚拟球（虚线圈）：碰撞瞬间母球应到达的位置，恰好与目标球相切。")
                termRow("瞄准线", "母球球心 → 假想球球心的直线（白色实线），是你出杆的方向。")
                termRow("进球线", "目标球球心 → 袋口中心的直线（随目标球本色的虚线）。")
                termRow("瞄准点", "假想球的球心（红点）。瞄准时眼睛盯住的参考点。")
                termRow("接触点", "碰撞瞬间两球球面相触的点（绿点），在目标球表面、两球心连线上。")
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func termRow(_ term: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(term)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .frame(width: 52, alignment: .leading)
            Text(desc)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Section 2: 为什么用角度瞄准

    private var whyAngleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("为什么用角度瞄准")
                .font(.btTitle)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("站在球桌旁（第三人称视角），你能看清瞄准线与进球线的夹角 θ——这是对一杆球最客观的描述：θ 越大，球越「薄」，越难打。")
                Text("但俯身出杆时（第一人称视角），角度消失了：你只能看到母球、目标球和台面。这时能落实的只有一个「点」——瞄准点。")
                Text("角度瞄准法做的就是这件事：先在第三人称把 θ 看出来，再用几何关系把 θ 翻译成第一人称可执行的瞄准点位置。这座桥梁就是下面的公式 d = 2R × sin(θ)。")
            }
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Section 3: 什么是切角

    private var cutAngleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("什么是切角 θ")
                .font(.btTitle)
                .foregroundStyle(.btText)

            AimingFigure(showsGlossaryLabels: false)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            Text("切角 θ 是瞄准线与进球线之间的夹角，范围 0°（正对）到 90°（极薄）。图中把 θ 标注在两条线的反向延长线（虚线）夹角处——两条线在假想球心相交，向后延长后夹角相同、且不与球重叠，读图更清晰。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Section 4: 公式推导

    private var derivationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("公式从哪来")
                .font(.btTitle)
                .foregroundStyle(.btText)

            DerivationFigure()
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.md) {
                derivationStep(1, "假想球心 G 在进球线的反向延长线上，与目标球心 T 相距恰好 2R（两球相切时球心距 = 两个半径）。")
                derivationStep(2, "从 T 向瞄准线作垂线，得到直角三角形：斜边 GT = 2R，G 处的夹角就是切角 θ。")
                derivationStep(3, "直角三角形中「对边 = 斜边 × sin(夹角)」，所以垂线段长 d = 2R × sin(θ)。d 就是瞄准点相对目标球心的横移量。")
            }

            Text("这就是为什么知道了角度就能找到瞄准点：θ 决定 sin(θ)，sin(θ) 决定横移量 d，d 决定假想球（瞄准点）该放在哪。")
                .font(.btFootnote)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func derivationStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(n)")
                .font(.btCaption2)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.btPrimary, in: Circle())
            Text(text)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    // MARK: - Section 5: 核心公式速查

    private var coreFormulaSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("核心公式")
                .font(.btTitle)
                .foregroundStyle(.btText)

            HStack {
                Spacer()
                Text("d = 2R × sin(θ)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.btPrimaryMuted)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                formulaRow("d", "横移量（假想球中心偏移目标球中心的距离）")
                formulaRow("R", "球半径（中八 28.575mm）")
                formulaRow("θ", "切角（0°–90°）")
                formulaRow("d/R", "= 2sin(θ)，无量纲比")
            }

            Divider()

            formulaExampleCanvas
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            Text("30° 示例：sin(30°) = 0.5，d = 2R × 0.5 = R，即假想球中心偏移一个球半径。")
                .font(.btFootnote)
                .foregroundStyle(.btTextSecondary)

            Divider()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("派生公式")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Text("接触点偏移 = R × sin(θ)")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.btTextSecondary)
                Text("仅描述目标球表面接触点位置，不是瞄准主公式。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func formulaRow(_ symbol: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(symbol)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.btPrimary)
                .frame(width: 30, alignment: .trailing)
            Text(desc)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private var formulaExampleCanvas: some View {
        FormulaFigure()
    }

    // MARK: - Section 6: Ghost Ball Method

    private var ghostBallSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("假想球法（Ghost Ball）")
                .font(.btTitle)
                .foregroundStyle(.btText)

            ghostBallStep(number: 1, title: "确定进球线",
                         description: "连接目标球中心与袋口中心点。")

            ghostBallStep(number: 2, title: "放置假想球",
                         description: "在进球线反方向放置一个与母球等大的圆。假想球中心 = 目标球中心 − 2R × 进球方向。")

            ghostBallStep(number: 3, title: "瞄准球心",
                         description: "母球只需朝向假想球的圆心（红点 = 瞄准点）出杆。接触瞬间，白球与目标球连心线与进球线重合。")
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func ghostBallStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("步骤 \(number)")
                .font(.btCaption2)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Color.btPrimary)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text(description)
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
        }
    }

    // MARK: - Section 7: Thickness Concept

    private var thicknessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("厚薄球概念")
                .font(.btTitle)
                .foregroundStyle(.btText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Spacing.lg) {
                thicknessCard(name: "全球", angle: "0°", offset: "0%", dOverR: "0", overlapFraction: 1.0)
                thicknessCard(name: "3/4 球", angle: "14.5°", offset: "25%", dOverR: "0.50", overlapFraction: 0.75)
                thicknessCard(name: "半球", angle: "30°", offset: "50%", dOverR: "1.0", overlapFraction: 0.5)
                thicknessCard(name: "极薄球", angle: "90°", offset: "100%", dOverR: "2.0", overlapFraction: 0.0)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func thicknessCard(name: String, angle: String, offset: String, dOverR: String, overlapFraction: CGFloat) -> some View {
        VStack(spacing: Spacing.sm) {
            thicknessCanvas(overlapFraction: overlapFraction)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            Text(name)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            Text("\(angle) | d/R \(dOverR)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    private func thicknessCanvas(overlapFraction: CGFloat) -> some View {
        // 真台特写（T-P18-46）：真实台呢底 + 真球面，错位量按真实球径几何。
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        return BTTableFigure(orientation: .landscape,
                             closeup: (center: .zero, halfHeight: r * 1.65)) { proj in
            let d = proj.ballDiameter
            let sep = d * (1 - overlapFraction)
            // 目标球居右，母球居左错位重叠：θ 越大错位越多（越"薄"）。
            BTFigureBall(number: 1, diameter: d, showsShadow: false)
                .position(x: proj.size.width / 2 + sep / 2, y: proj.size.height / 2)
            BTFigureBall(diameter: d, showsShadow: false)
                .position(x: proj.size.width / 2 - sep / 2, y: proj.size.height / 2)
        }
    }
}

// MARK: - Aiming geometry figures

/// 切角全景（真台化，T-P18-46 / 条 1 修订）：真实 USDZ 台底图上，用 §1.2 线语言画出
/// 母球 / 目标球 / 假想球（球心红点 = 瞄准点）/ 进球线（绑球色，带文字标签）/
/// 瞄准线（白实线，带文字标签）/ θ 弧——标在两线**反向延长线**的夹角处（条 1.3）。
/// 几何走世界坐标真源：假想球 = 目标球心 − 2R×进球方向，瞄向真实右上角袋。
private struct AimingFigure: View {
    /// 名词系统模式：加标「瞄准点 / 接触点」详注（条 1.1 配图）。
    var showsGlossaryLabels = false

    /// 教学示例切角（°）：中等偏厚的一杆，θ 弧展开清晰。
    private let cutAngleDeg: CGFloat = 32
    private let targetNumber = 1

    private struct Layout {
        let target: CGPoint
        let pocket: CGPoint
        let ghost: CGPoint
        let cue: CGPoint
        let contact: CGPoint
        let d: CGFloat
        let potAngle: CGFloat
        let aimAngle: CGFloat
        let arcR: CGFloat
        let extLen: CGFloat
    }

    var body: some View {
        // 半台特写取景（覆盖右上 1/4 台 + 袋口）：球与标注放大约一倍，教学更易读；
        // 底图仍是同一张真台（含真实库边与右上角袋）。取景比旧版放宽（条 1.3：
        // 假想球/目标球周边留白更足，不拥挤）。
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.50, y: -0.16), halfHeight: 0.30)) { proj in
            let l = layout(proj)
            ZStack {
                // 进球线（目标球 → 袋口）：绑目标球本色（线语言 v2 虚线）。
                Path { p in p.move(to: l.target); p.addLine(to: l.pocket) }
                    .stroke(FigureLine.pot(number: targetNumber),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))

                // 瞄准线（母球 → 假想球）：白实线 lineMain。
                Path { p in p.move(to: l.cue); p.addLine(to: l.ghost) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 反向延长线（细虚线）：两条线过假想球心向后延伸，θ 标在这里（条 1.3）。
                Path { p in
                    p.move(to: l.ghost)
                    p.addLine(to: CGPoint(x: l.ghost.x - l.extLen * cos(l.potAngle),
                                          y: l.ghost.y - l.extLen * sin(l.potAngle)))
                }
                .stroke(FigureLine.pot(number: targetNumber).opacity(0.55),
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [3, 3]))
                Path { p in
                    p.move(to: l.ghost)
                    p.addLine(to: CGPoint(x: l.ghost.x - l.extLen * cos(l.aimAngle),
                                          y: l.ghost.y - l.extLen * sin(l.aimAngle)))
                }
                .stroke(FigureLine.aim.opacity(0.55),
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [3, 3]))

                // θ 弧（品牌绿）：顶点 = 假想球心，展开在反向延长线之间。
                Path { p in
                    p.addArc(center: l.ghost, radius: l.arcR,
                             startAngle: .radians(l.aimAngle + .pi),
                             endAngle: .radians(l.potAngle + .pi),
                             clockwise: l.aimAngle > l.potAngle)
                }
                .stroke(FigureLine.contact, lineWidth: proj.lineHintWidth)

                BTGhostCircle(diameter: l.d).position(l.ghost)
                BTFigureBall(number: targetNumber, diameter: l.d).position(l.target)
                BTFigureBall(diameter: l.d).position(l.cue)
                // 接触点画在球面之上（与场景页 contactDot 浮于球面同序）。
                BTContactDot(diameter: max(4, l.d * 0.22)).position(l.contact)

                BTFigureTag(text: "θ \(Int(cutAngleDeg))°")
                    .position(x: l.ghost.x - (l.arcR + 18) * cos((l.potAngle + l.aimAngle) / 2),
                              y: l.ghost.y - (l.arcR + 18) * sin((l.potAngle + l.aimAngle) / 2))
                BTFigureTag(text: "母球").position(x: l.cue.x, y: l.cue.y + l.d / 2 + 12)
                BTFigureTag(text: "目标球").position(x: l.target.x + l.d * 0.8,
                                                     y: l.target.y + l.d / 2 + 14)
                BTFigureTag(text: "假想球", color: FigureLine.contact)
                    .position(x: l.ghost.x - l.d * 0.9, y: l.ghost.y - l.d / 2 - 12)

                // 线标签（条 1.2）：贴线段靠端点 30% 处外侧，避开假想球标注群。
                BTFigureTag(text: "瞄准线")
                    .position(alongLabel(from: l.cue, to: l.ghost, t: 0.32, offset: 14))
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: targetNumber))
                    .position(alongLabel(from: l.target, to: l.pocket, t: 0.55, offset: -14))

                if showsGlossaryLabels {
                    BTFigureTag(text: "瞄准点", color: FigureLine.aimPoint)
                        .position(x: l.ghost.x + l.d * 0.15, y: l.ghost.y + l.d / 2 + 13)
                    BTFigureTag(text: "接触点", color: FigureLine.contact)
                        .position(x: l.contact.x + l.d * 0.4, y: l.contact.y - l.d * 0.9)
                }
            }
        }
    }

    /// 线段 a→b 上参数 t 处、向法线方向偏移 offset 的标签位置。
    private func alongLabel(from a: CGPoint, to b: CGPoint,
                            t: CGFloat, offset: CGFloat) -> CGPoint {
        let pt = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.001)
        return CGPoint(x: pt.x - dy / len * offset, y: pt.y + dx / len * offset)
    }

    private func layout(_ proj: TableFigureProjection) -> Layout {
        let r = CGFloat(AngleSceneCalculator.ballRadius)

        // 世界几何（米）：目标球 → 右上角袋（索引 1）。
        let targetW = CGPoint(x: 0.45, y: -0.12)
        let pocketW3 = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)[1]
        let pocketW = CGPoint(x: CGFloat(pocketW3.x), y: CGFloat(pocketW3.z))
        let potDir = unit(from: targetW, to: pocketW)
        let ghostW = CGPoint(x: targetW.x - 2 * r * potDir.x,
                             y: targetW.y - 2 * r * potDir.y)
        // 瞄准方向 = 进球方向绕假想球旋 θ（母球从另一侧来）。
        let a: CGFloat = cutAngleDeg * .pi / 180
        let cosA: CGFloat = cos(a)
        let sinA: CGFloat = sin(a)
        let aimDir = CGPoint(x: potDir.x * cosA - potDir.y * sinA,
                             y: potDir.x * sinA + potDir.y * cosA)
        let cueW = CGPoint(x: ghostW.x - aimDir.x * 0.24, y: ghostW.y - aimDir.y * 0.24)

        let target = proj.point(x: targetW.x, z: targetW.y)
        let pocket = proj.point(x: pocketW.x, z: pocketW.y)
        let ghost = proj.point(x: ghostW.x, z: ghostW.y)
        let cue = proj.point(x: cueW.x, z: cueW.y)
        let d = proj.ballDiameter

        return Layout(target: target,
                      pocket: pocket,
                      ghost: ghost,
                      cue: cue,
                      contact: CGPoint(x: (target.x + ghost.x) / 2,
                                       y: (target.y + ghost.y) / 2),
                      d: d,
                      potAngle: atan2(pocket.y - ghost.y, pocket.x - ghost.x),
                      aimAngle: atan2(ghost.y - cue.y, ghost.x - cue.x),
                      arcR: d * 1.15,
                      extLen: d * 2.1)
    }

    private func unit(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.0001 else { return .zero }
        return CGPoint(x: dx / len, y: dy / len)
    }
}

/// 公式推导图（条 1.5）：直角三角形的几何来历。
/// 假想球心 G — 目标球心 T 连线（= 进球线反向，长 2R，斜边）；
/// 过 G 的瞄准线（白实线）；从 T 向瞄准线作垂线（金，= 横移量 d）；θ 弧标在 G。
private struct DerivationFigure: View {
    private let thetaDeg: CGFloat = 32

    var body: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.03, y: 0), halfHeight: r * 3.4)) { proj in
            let d = proj.ballDiameter
            let theta = thetaDeg * .pi / 180

            // 世界坐标：G 在原点左侧，瞄准线水平向右；T 在瞄准线上方旋 θ。
            let gW = CGPoint(x: -r * 0.9, y: 0)
            let tW = CGPoint(x: gW.x + 2 * r * cos(theta), y: -2 * r * sin(theta))
            // 垂足 F：T 在瞄准线（y = gW.y 水平线）上的投影。
            let fW = CGPoint(x: tW.x, y: gW.y)

            let g = proj.point(x: gW.x, z: gW.y)
            let t = proj.point(x: tW.x, z: tW.y)
            let f = proj.point(x: fW.x, z: fW.y)
            let aimEnd = proj.point(x: gW.x + r * 3.4, z: gW.y)
            let aimStart = proj.point(x: gW.x - r * 1.0, z: gW.y)

            ZStack {
                // 瞄准线（白实线，过 G 水平）。
                Path { p in p.move(to: aimStart); p.addLine(to: aimEnd) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 斜边 G→T（进球线反向，绑球色虚线）：长 2R。
                Path { p in p.move(to: g); p.addLine(to: t) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))

                // 垂线 T→F（金 = 量值 d）。
                Path { p in p.move(to: t); p.addLine(to: f) }
                    .stroke(Color.btAccent, lineWidth: 1.8)
                // 直角小方块。
                Path { p in
                    let s: CGFloat = 7
                    p.move(to: CGPoint(x: f.x - s, y: f.y))
                    p.addLine(to: CGPoint(x: f.x - s, y: f.y - s))
                    p.addLine(to: CGPoint(x: f.x, y: f.y - s))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 1)

                // θ 弧在 G（瞄准线与斜边之间）。
                Path { p in
                    p.addArc(center: g, radius: d * 0.85,
                             startAngle: .radians(0),
                             endAngle: .radians(atan2(t.y - g.y, t.x - g.x)),
                             clockwise: true)
                }
                .stroke(FigureLine.contact, lineWidth: proj.lineHintWidth)

                BTGhostCircle(diameter: d).position(g)
                BTFigureBall(number: 1, diameter: d).position(t)

                BTFigureTag(text: "G 假想球心", color: FigureLine.contact)
                    .position(x: g.x - d * 0.3, y: g.y + d / 2 + 12)
                BTFigureTag(text: "T 目标球心")
                    .position(x: t.x + d * 0.4, y: t.y - d / 2 - 11)
                BTFigureTag(text: "θ", color: FigureLine.contact)
                    .position(x: g.x + d * 1.28, y: g.y - d * 0.42)

                Text("2R")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .position(x: (g.x + t.x) / 2 - 12, y: (g.y + t.y) / 2 - 10)
                Text("d = 2R·sin(θ)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.btAccent)
                    .position(x: f.x + 14, y: (t.y + f.y) / 2)
            }
        }
    }
}

/// d = 2R·sin(θ) 的 30° 示例（真台特写）：目标球 + 假想球（错位一个半径），标注横移量 d。
/// 量值标注用金（§1.7：金管数值）。
private struct FormulaFigure: View {
    var body: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: .zero, halfHeight: r * 2.6)) { proj in
            let d = proj.ballDiameter
            // 世界坐标：目标球居中偏右，假想球沿 X 负向错位一个半径（d/R = 1 → 30°）。
            let target = proj.point(x: r * 0.55, z: 0)
            let ghost = proj.point(x: r * 0.55 - r, z: 0)
            let dimY = target.y - d / 2 - 14

            ZStack {
                // d 横移量标尺（金 = 量值）。
                Path { p in
                    p.move(to: CGPoint(x: ghost.x, y: dimY))
                    p.addLine(to: CGPoint(x: target.x, y: dimY))
                }
                .stroke(Color.btAccent, lineWidth: 1.6)

                Text("d / R = 1.0")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.btAccent)
                    .position(x: (ghost.x + target.x) / 2, y: dimY - 11)

                BTGhostCircle(diameter: d).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)

                Text("sin(30°) = 0.5 → d = R")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .position(x: proj.size.width / 2, y: proj.size.height - 14)
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { AimingPrincipleView() }
}

#Preview("Dark") {
    NavigationStack { AimingPrincipleView() }
        .preferredColorScheme(.dark)
}
