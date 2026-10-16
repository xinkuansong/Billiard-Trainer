import SwiftUI
import SceneKit

/// 瞄准修正（问题集合 v12 Z1–Z3）：理想角度瞄准法 vs 真实物理偏差。
///
/// Z3：②③ 插图改为学区统一 `BTTableFigure` 语言；④ 加塞节 + ⑤ 求解对比 + 速查表；
/// 共享控件开放左右塞轴（打滑极限圆盘钳制）。数值真源 `AimingCorrectionMath`；
/// 定性符号以 `build/z1-evidence/` / `z2-evidence/` / `z3-evidence/` 草稿为准。
struct AimingCorrectionView: View {
    @StateObject private var vm = AimingCorrectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                sharedControls
                idealVsRealitySection
                throwSection
                thicknessSection
                englishSection
                solverCompareSection
                crossRefsSection
                practiceCTASection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
            .learnDocumentWidth()
        }
        .background(.btBG)
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .learnReadingNavigation(title: "瞄准修正")
        .onAppear { vm.onAppear() }
    }

    // MARK: - ① 开篇

    private var introSection: some View {
        LearnDocSectionCard {
            Text("找到几何方向以后，还要看什么")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.intro.title")

            LearnDocText.body("按假想球找到方向以后，同一个球形，换一种力度或杆法，目标球可能不再沿原来的方向走。原因有的发生在碰球时，有的发生在母球到达之前：球间摩擦会带来投掷，加塞还会涉及挤偏与弧线。先分清偏差从哪里来，再讨论怎样调整瞄准。")

            LearnDocText.footnote("d = 2R × sin(θ) 仍是几何参照。下面的交互用当前模拟条件展示修正量，帮助你比较变化；具体让多少，还需要在自己的球杆、球台和打法下核对。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.intro")
    }

    // MARK: - Shared controls（力度 + 高低杆 + 左右塞）→ LearnControlStrip.LiveAxes

    private var sharedControls: some View {
        LearnControlStrip.LiveAxes(
            velocity: Binding(
                get: { vm.velocity },
                set: { vm.setVelocity($0) }
            ),
            spinYTier: Binding(
                get: { vm.spinYTier },
                set: { vm.setSpinYTier($0) }
            ),
            spinX: Binding(
                get: { vm.spinX },
                set: { vm.setSpinX($0) }
            ),
            spinXRange: -vm.spinXMaxAbs...max(vm.spinXMaxAbs, 1e-6),
            spinXDisabled: vm.spinXMaxAbs < 1e-4,
            footer: "改变力度、高低杆或左右塞，下面四组图会重新计算。先一次改一项，比较瞄准线和碰后方向怎样变化。打点范围与 App 打点盘一致，上下打得越偏，可选的左右塞越少。",
            velocityAccessibilityIdentifier: "aimingCorrection.velocitySlider",
            spinYAccessibilityIdentifier: "aimingCorrection.spinYPicker",
            spinXAccessibilityIdentifier: "aimingCorrection.spinXSlider"
        )
        .accessibilityIdentifier("aimingCorrection.controls")
    }

    // MARK: - ① Δ 实况图

    private var idealVsRealitySection: some View {
        LearnDocSectionCard(title: "同一局面：几何瞄准 vs 求解瞄准") {
            LearnDocText.body("虚线是按假想球找到的几何方向，实线是当前力度和杆法下自动求解得到的方向。两线的夹角记作 Δ。先保持球位不变，调整上方控件，看看需要修正的方向和幅度是否改变。")

            DeltaAimFigure(snapshot: vm.snapshot, setup: vm.setup)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingCorrection.deltaFigure")

            if let snap = vm.snapshot {
                HStack {
                    Text(String(format: "Δ = %+.2f°", snap.aimOffsetDegrees))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.btPrimary)
                    Spacer()
                    Text(String(format: "切角 ≈ %.1f°", snap.cutAngleDeg))
                        .font(.btCaption)
                        .foregroundStyle(.btText)
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.deltaReadout")
            } else if vm.isComputing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let status = vm.statusText {
                Text(status)
                    .font(.btCaption)
                    .foregroundStyle(.btWarning)
            }

            LearnDocText.footnote("偏差是否影响进球，还与目标球到袋口的距离和袋口容错有关。不要只看 Δ 的数字大小，也要看这样的方向差会把目标球带到袋口哪里。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section1")
    }

    // MARK: - ② 投掷效应

    private var throwSection: some View {
        LearnDocSectionCard {
            Text("投掷效应（Throw）")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section2.title")

            ThrowCollisionFigure(sample: vm.throwSample, setup: vm.setup)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingCorrection.throwFigure")

            if let sample = vm.throwSample {
                HStack {
                    Text(String(format: "投掷角 ≈ %.2f°", sample.throwDegrees))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.btPrimary)
                    Spacer()
                    Text(String(format: "力度 %.1f · %@", sample.velocity, vm.spinYTier.label))
                        .font(.btCaption)
                        .foregroundStyle(.btText)
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.throwReadout")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("两球碰撞时，除了沿连心线的挤压，接触面的摩擦也会给目标球一个侧向作用，使它偏离理想离开方向。这种现象叫投掷。图中把方向差放大，方便观察；读数来自当前模拟结果。")
                LearnDocText.body("不加左右塞，切球本身也能产生投掷，称为切角投掷（CIT）。加塞会改变接触面相对滑动，形成塞致投掷（SIT）。两种作用可能加强，也可能抵消，不能把塞量直接换成固定的目标球偏转角。")
                LearnDocText.body("碰球时接近斯登状态，也就是几乎没有前旋和后旋，投掷通常比较明显。无塞斯登球的切角投掷常在半球附近较大，不能理解为切得越薄就一直增大。较慢的击球在不少条件下投掷更明显，但小切角斯登球对速度可能并不敏感；判断时还要看碰球时的旋转。")
            }

            LearnDocText.footnote("切角与假想球几何见「瞄准原理」「瞄准方法」；本节省去复述。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section2")
    }

    // MARK: - ③ 高低杆改变有效厚度

    private var thicknessSection: some View {
        LearnDocSectionCard {
            Text("为什么换了高低杆，原来的瞄法会变")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section3.title")

            ThicknessTripleFigure(triple: vm.thicknessTriple, active: vm.spinYTier)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingCorrection.thicknessFigure")

            if let triple = vm.thicknessTriple {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(triple.lanes, id: \.tier) { lane in
                        let biasLabel = lane.thicknessBiasDegrees >= 0 ? "偏薄侧" : "偏厚侧"
                        HStack {
                            Text(lane.tier.label)
                                .font(.btSubheadlineMedium)
                                .foregroundStyle(lane.tier == vm.spinYTier ? .btPrimary : .btText)
                                .frame(width: 40, alignment: .leading)
                            Text(String(format: "偏差 %+0.2f°（%@）",
                                         lane.thicknessBiasDegrees, biasLabel))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.btText)
                            Spacer()
                        }
                    }
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.thicknessReadout")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("有时同一球形，中杆能进，换成高杆或低杆却偏了，看起来像是碰厚或碰薄了。两球的大小没有变；需要检查的是，换打法以后，母球到达时的速度、旋转和实际入射方向发生了什么变化。")
                LearnDocText.body("上图保留相同的几何瞄准方向，比较三种打点。读数表示目标球离开方向相对理想进球方向的偏差，正值标作偏薄侧，负值标作偏厚侧；它不是要直接照搬的让点量，也不是相对中杆的差值。")
                LearnDocText.body("关键是碰球时的状态，不只是出杆时打得高还是低。低杆的后旋可能在途中逐渐消失，甚至转成自然滚动。前旋和后旋都可能使投掷比斯登时减小，因此「高杆一律瞄厚、低杆一律瞄薄」不能作为通用口诀。先比较同一球形下自己熟悉的打法，再根据实际偏差调整。")
            }

            LearnDocText.footnote("厚度与切角对照仍见「瞄准点对照表」；本页只讲杆法对有效厚度的修正。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section3")
    }

    // MARK: - ④ 加塞：挤偏 + 弧线

    private var englishSection: some View {
        LearnDocSectionCard {
            Text("加塞：挤偏与弧线")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section4.title")

            SquirtSwerveFigure(snapshot: vm.snapshot, setup: vm.setup)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingCorrection.englishFigure")

            if let snap = vm.snapshot {
                let swerve = AimingCorrectionMath.swerveLateralSigned(
                    segments: snap.preContactSegments
                )
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text(String(format: "挤偏 ≈ %+.2f°", snap.squirtDegrees))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.btPrimary)
                        Spacer()
                        Text(snap.squirtDegrees < -0.01
                             ? "负值 = 向右"
                             : (snap.squirtDegrees > 0.01 ? "正值 = 向左" : "无挤偏"))
                            .font(.btCaption)
                            .foregroundStyle(.btText)
                    }
                    if let swerve {
                        Text(String(format: "弧线横向漂移 ≈ %+.1f mm（%@）",
                                     swerve.signedMeters * 1000, swerve.signLabel))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.btText)
                    }
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.englishReadout")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("挤偏（Squirt）发生在出杆瞬间：杆头打在母球左侧，母球通常先偏向杆线右侧出发；右塞则相反。它主要与偏心打点和球杆特性有关。图中的白虚线是杆指向，亮绿轨迹是母球实际行进路线，可以比较两者从哪里开始分开。")
                LearnDocText.body("弧线（Swerve）发生在行进途中。加塞并带有杆身仰角时，台呢摩擦会使母球路线逐渐向加塞一侧弯回；仰角、速度、行程和上下旋都会影响弯回的过程。理想水平出杆、纯侧旋的母球，不会只因为有左右塞就必然画出明显弧线。")
                LearnDocText.body("挤偏先改变出发方向，弧线再改变到达位置和入射方向，碰球时还可能产生投掷。最终需要让向哪边、让多少，要看这些作用合起来的结果。换距离或力度以后，原来合适的让点就未必仍然合适。")
            }

            LearnDocText.footnote("母球旋转状态与分离角见「旋转与加塞」；本页只讲加塞对瞄准线的影响。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section4")
    }

    // MARK: - ⑤ 求解对比 + 速查表

    private var solverCompareSection: some View {
        LearnDocSectionCard {
            Text("自动求解在替你算什么")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section5.title")

            SolverCompareFigure(comparison: vm.solveComparison, setup: vm.setup)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingCorrection.compareFigure")

            if let cmp = vm.solveComparison {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    compareReadoutRow(
                        label: "档 A · 中杆中速",
                        degrees: cmp.a.aimOffsetDegrees,
                        color: .btPrimary
                    )
                    compareReadoutRow(
                        label: "档 B · 低杆轻推+左塞",
                        degrees: cmp.b.aimOffsetDegrees,
                        color: .btWarning
                    )
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.compareReadout")
            }

            LearnDocText.body("自动求解会在当前模拟条件下尝试不同的瞄准方向，计算母球怎样到达目标球、碰后目标球朝哪里走，再寻找通向袋口的方向。上图固定比较两套打法：A 是中杆中速无塞，B 是低杆轻推加左塞。它们的力度和打点同时不同，所以两条线的差别是综合结果，不能只归因于其中一个因素。")

            Text("判断修正时，先核对这些条件")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.quickref.title")

            VStack(spacing: Spacing.sm) {
                quickRefRow("轻力", "留意投掷与弯回的变化", "仍要比较碰球速度、旋转和行程")
                quickRefRow("切角", "半球附近的斯登球值得特别留意", "投掷不会随切角无限增大")
                quickRefRow("高杆", "检查到达时是怎样的前旋", "不能一律按「瞄厚一点」处理")
                quickRefRow("低杆", "检查后旋是否还保留到碰球", "打低不等于到达时仍有后旋")
                quickRefRow("左塞", "母球通常先向杆线右侧挤偏", "最终让点还取决于弧线和投掷")
                quickRefRow("挤偏", "先看打点和球杆特性", "起始偏角与最终横向偏差要分开")
                quickRefRow("弧线", "看仰角、速度和行程", "它发生在途中，不是出杆瞬间的偏角")
            }
            .accessibilityIdentifier("aimingCorrection.quickref")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section5")
    }

    private func compareReadoutRow(label: String, degrees: Float, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.btCaption)
                .foregroundStyle(color)
            Spacer()
            Text(String(format: "Δ = %+.2f°", degrees))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.btText)
        }
    }

    private func quickRefRow(_ condition: String, _ conclusion: String, _ note: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(condition)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(conclusion)
                    .font(.btCaption)
                    .foregroundStyle(.btText)
                Text(note)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Cross refs

    /// D-v14-6：页末大卡 ≤2（学→练优先）；同「学」互链改文字行。
    private var crossRefsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            LearnDocTextLink(
                title: "回看瞄准原理",
                subtitle: "切球角 · 假想球 · d = 2R·sinθ",
                route: .aimingPrinciple
            )

            LearnDocTextLink(
                title: "打开瞄准方法",
                subtitle: "管道 · 接触点 · 平行线",
                route: .aimingMethods
            )

            LearnDocTextLink(
                title: "旋转与加塞",
                subtitle: "旋转四态 · 分离角 · 打滑极限",
                route: .spinAndEnglish
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.crossRefs")
    }

    // MARK: - ⑥ 导流

    private var practiceCTASection: some View {
        LearnDocSectionCard {
            Text("实战启示")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section6.title")

            LearnDocText.body("练习时，先固定一个容易重摆的球形，用熟悉的力度和打点建立参照。再一次改变一项，观察目标球偏向哪里，并检查出杆是否按原计划完成。把调整后的瞄准与这套打法一起记住；换球距或换球台后，再重新核对。也可以到「思路训练」中比较不同打法的瞄准线，帮助理解变化从哪里来。")

            PracticeCTA(
                title: "去思路训练看实况",
                destination: "自动求解 · 力度与塞如何改瞄准线",
                route: .positionPlaySolver
            )

            PracticeCTA(
                title: "练挤偏认知",
                destination: "直球近台 · 比较带塞后的瞄准变化",
                route: .drillDetail("drill_c073")
            )
            .accessibilityIdentifier("aimingCorrection.squirtDrillCTA")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section6")
    }
}

// MARK: - Shared geometry helpers

private func extend(from: SCNVector3, dir: SCNVector3, meters: Float) -> SCNVector3 {
    let len = sqrtf(dir.x * dir.x + dir.z * dir.z)
    guard len > 1e-9 else { return from }
    let ux = dir.x / len, uz = dir.z / len
    return SCNVector3(from.x + ux * meters, from.y, from.z + uz * meters)
}

private func alongLabel(from a: CGPoint, to b: CGPoint,
                        t: CGFloat, offset: CGFloat) -> CGPoint {
    let pt = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    let dx = b.x - a.x, dy = b.y - a.y
    let len = max(sqrt(dx * dx + dy * dy), 0.001)
    return CGPoint(x: pt.x - dy / len * offset, y: pt.y + dx / len * offset)
}

// MARK: - Δ figure（①）

private struct DeltaAimFigure: View {
    let snapshot: AimingCorrectionMath.Snapshot?
    let setup: AimingCorrectionMath.TeachingSetup

    var body: some View {
        let closeCenter = CGPoint(x: CGFloat(setup.target.x) - 0.05,
                                  y: CGFloat(setup.target.z) + 0.02)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: closeCenter, halfHeight: 0.38)) { proj in
            BTFigureBall(number: 1, diameter: proj.ballDiameter)
                .position(proj.point(setup.target))
            BTFigureBall(diameter: proj.ballDiameter)
                .position(proj.point(setup.cue))

            if let snap = snapshot {
                let cue = setup.cue
                let geoEnd = extend(from: cue, dir: snap.geometricAimDir, meters: 0.45)
                let solEnd = extend(from: cue, dir: snap.solvedAimDir, meters: 0.45)

                dashedLine(proj: proj, from: cue, to: geoEnd, color: FigureLine.hint)
                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(solEnd))
                }
                .stroke(FigureLine.actual, style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                BTGhostCircle(diameter: proj.ballDiameter, showsAimPoint: true)
                    .position(proj.point(snap.ghost))

                BTFigureTag(text: "Δ", color: FigureLine.actual)
                    .position(alongLabel(from: proj.point(geoEnd),
                                         to: proj.point(solEnd), t: 0.5, offset: 0))
            }
        }
    }

    @ViewBuilder
    private func dashedLine(proj: TableFigureProjection,
                            from: SCNVector3, to: SCNVector3,
                            color: Color) -> some View {
        let a = proj.point(from)
        let b = proj.point(to)
        Path { p in
            p.move(to: a)
            p.addLine(to: b)
        }
        .stroke(color, style: StrokeStyle(lineWidth: max(1.2, proj.lineHintWidth),
                                          lineCap: .round,
                                          dash: [5, 4]))
    }
}

// MARK: - ② Throw collision（BTTableFigure closeup）

private struct ThrowCollisionFigure: View {
    let sample: AimingCorrectionMath.ThrowDiagramSample?
    let setup: AimingCorrectionMath.TeachingSetup

    /// Δ 夸大倍率上限（视觉可读；读数仍用真实 throwDegrees）。
    /// 大 Δ（如加塞后 10°+）时按 maxDisplayDeg 收缩倍率，避免离开线转出画面。
    private let exaggerate: Float = 8
    private let maxDisplayDeg: Float = 26

    var body: some View {
        let center: CGPoint = {
            if let s = sample {
                return CGPoint(x: CGFloat(s.contactPoint.x),
                               y: CGFloat(s.contactPoint.z))
            }
            return CGPoint(x: CGFloat(setup.target.x),
                           y: CGFloat(setup.target.z))
        }()
        BTTableFigure(orientation: .landscape,
                      closeup: (center: center, halfHeight: 0.14)) { proj in
            // 坐标契约回显（Z3 风格迁移）：
            // SceneKit 水平面 X–Z，+Y 朝上。BTTableFigure landscape：
            //   x_n ∝ +X，y_n ∝ +Z（SwiftUI y 向下 ⇒ 屏上向上 = 世界 −Z）。
            // 与 Z2 裸 Canvas 示意帧（x_s=X、y_s=−Z）不同——本图偏转在世界系
            // 用 pot.rotatedY(signed×夸大) 完成后再 proj.point，禁止屏上手性翻号。
            if let sample {
                let ghost = sample.ghost
                let target = sample.target
                let contact = sample.contactPoint
                let lineM: Float = 0.22
                let potEnd = extend(from: target, dir: sample.potDir, meters: lineM)
                let signed = AimingCorrectionMath.signedAngleXZ(
                    from: sample.potDir, to: sample.objPostDir
                )
                let signedDeg = abs(signed) * 180 / .pi
                let effExaggerate = max(1, min(exaggerate, maxDisplayDeg / max(signedDeg, 0.05)))
                let leaveDir = sample.potDir.rotatedY(signed * effExaggerate)
                let leaveEnd = extend(from: target, dir: leaveDir, meters: lineM)
                let frEnd = extend(from: contact, dir: sample.frictionTangentDir, meters: 0.06)

                // Ideal pot (dashed) + actual leave (solid, exaggerated)
                Path { p in
                    p.move(to: proj.point(target))
                    p.addLine(to: proj.point(potEnd))
                }
                .stroke(FigureLine.pot(number: 1).opacity(0.9),
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 4]))

                Path { p in
                    p.move(to: proj.point(target))
                    p.addLine(to: proj.point(leaveEnd))
                }
                .stroke(FigureLine.actual,
                        style: StrokeStyle(lineWidth: proj.lineMainWidth + 0.4, lineCap: .round))

                // Friction arrow (token color; Path only — no Text labels)
                frictionArrow(proj: proj, from: contact, to: frEnd)

                BTGhostCircle(diameter: proj.ballDiameter, showsAimPoint: false)
                    .position(proj.point(ghost))
                BTFigureBall(number: 1, diameter: proj.ballDiameter)
                    .position(proj.point(target))
                BTContactDot(diameter: max(5, proj.ballDiameter * 0.22))
                    .position(proj.point(contact))

                BTFigureTag(text: "接触点", color: FigureLine.contact)
                    .position(x: proj.point(contact).x,
                              y: proj.point(contact).y - proj.ballDiameter * 0.7)
                BTFigureTag(text: "理想进球线", color: FigureLine.pot(number: 1))
                    .position(alongLabel(from: proj.point(target),
                                         to: proj.point(potEnd), t: 0.75, offset: -14))
                let leaveLabel = alongLabel(from: proj.point(target),
                                            to: proj.point(leaveEnd), t: 0.8, offset: 14)
                // Four 10pt characters plus capsule padding stay within the figure.
                BTFigureTag(text: "实际离开", color: FigureLine.actual)
                    .position(x: min(max(30, leaveLabel.x), max(30, proj.size.width - 30)),
                              y: leaveLabel.y)
                BTFigureTag(text: "摩擦", color: FigureLine.effect)
                    .position(alongLabel(from: proj.point(contact),
                                         to: proj.point(frEnd), t: 0.85, offset: -12))
                BTFigureTag(text: "Δ ×\(max(1, Int(effExaggerate.rounded()))) 夸大", color: FigureLine.contact)
                    .position(x: proj.size.width - 52, y: 16)
                BTFigureTag(text: "假想球", color: FigureLine.ghost)
                    .position(x: proj.point(ghost).x,
                              y: proj.point(ghost).y + proj.ballDiameter * 0.65)
                BTFigureTag(text: "目标球")
                    .position(x: proj.point(target).x,
                              y: proj.point(target).y + proj.ballDiameter * 0.65)
            } else {
                ProgressView().tint(.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func frictionArrow(proj: TableFigureProjection,
                               from: SCNVector3, to: SCNVector3) -> some View {
        let a = proj.point(from)
        let b = proj.point(to)
        Path { p in
            p.move(to: a)
            p.addLine(to: b)
            let angle = atan2(b.y - a.y, b.x - a.x)
            let head: CGFloat = 7
            p.move(to: b)
            p.addLine(to: CGPoint(x: b.x - head * cos(angle - 0.4),
                                  y: b.y - head * sin(angle - 0.4)))
            p.move(to: b)
            p.addLine(to: CGPoint(x: b.x - head * cos(angle + 0.4),
                                  y: b.y - head * sin(angle + 0.4)))
        }
        .stroke(FigureLine.effect, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

// MARK: - ③ Thickness triple（单图三线，参照 SeparationPathsFigure）

private struct ThicknessTripleFigure: View {
    let triple: AimingCorrectionMath.ThicknessTriple?
    let active: AimingCorrectionMath.SpinYTier

    private let exaggerate: Float = 10
    private let maxDisplayDeg: Float = 32

    var body: some View {
        let setup = AimingCorrectionMath.teachingSetup()
        let closeCenter = CGPoint(x: CGFloat(setup.target.x) + 0.02,
                                  y: CGFloat(setup.target.z) + 0.04)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: closeCenter, halfHeight: 0.28)) { proj in
            let target = setup.target
            let d = proj.ballDiameter
            let lineM: Float = 0.32

            if let triple {
                let potEnd = extend(from: target, dir: triple.potDir, meters: lineM)
                Path { p in
                    p.move(to: proj.point(target))
                    p.addLine(to: proj.point(potEnd))
                }
                .stroke(FigureLine.pot(number: 1),
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                let midBias = triple.mid?.thicknessBiasDegrees
                // 三档共用同一夸大倍率（保持相对差真实）；大 Δ 时收缩，避免线转出画面。
                let maxAbsDeg = triple.lanes
                    .map { abs(AimingCorrectionMath.signedAngleXZ(from: triple.potDir, to: $0.objPostDir)) * 180 / .pi }
                    .max() ?? 0
                let effExaggerate = max(1, min(exaggerate, maxDisplayDeg / max(maxAbsDeg, 0.05)))
                ForEach(triple.lanes, id: \.tier) { lane in
                    let signed = AimingCorrectionMath.signedAngleXZ(
                        from: triple.potDir, to: lane.objPostDir
                    )
                    let leaveDir = triple.potDir.rotatedY(signed * effExaggerate)
                    let leaveEnd = extend(from: target, dir: leaveDir, meters: lineM)
                    let isActive = lane.tier == active
                    let color = laneColor(lane.tier)
                    Path { p in
                        p.move(to: proj.point(target))
                        p.addLine(to: proj.point(leaveEnd))
                    }
                    .stroke(color.opacity(isActive ? 1 : 0.85),
                            style: StrokeStyle(
                                lineWidth: isActive ? proj.lineMainWidth : proj.lineHintWidth,
                                lineCap: .round
                            ))
                    if isActive {
                        BTFigureTag(text: relLabel(lane: lane, midBias: midBias),
                                    color: color)
                            .position(alongLabel(from: proj.point(target),
                                                 to: proj.point(leaveEnd),
                                                 t: 0.72, offset: 16))
                    }
                }

                BTFigureBall(number: 1, diameter: d).position(proj.point(target))
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(alongLabel(from: proj.point(target),
                                         to: proj.point(potEnd), t: 0.55, offset: -14))
                BTFigureTag(text: "目标球")
                    .position(x: proj.point(target).x,
                              y: proj.point(target).y + d * 0.65)
            } else {
                ProgressView().tint(.white.opacity(0.5))
            }
        }
    }

    private func laneColor(_ tier: AimingCorrectionMath.SpinYTier) -> Color {
        switch tier {
        case .low: return FigureLine.effect
        case .mid: return FigureLine.separation
        case .high: return FigureLine.follow
        }
    }

    /// 相对中杆的定性标签（由实况 bias 比较，不硬编码高/低杆结论）。
    private func relLabel(lane: AimingCorrectionMath.ThicknessLane,
                          midBias: Float?) -> String {
        if lane.tier == .mid { return "基准" }
        guard let mid = midBias else { return lane.tier.label }
        let d = lane.thicknessBiasDegrees - mid
        if abs(d) < 0.005 { return "≈中杆" }
        return d > 0 ? "较中杆薄" : "较中杆厚"
    }
}

// MARK: - ④ Squirt + Swerve overhead

private struct SquirtSwerveFigure: View {
    let snapshot: AimingCorrectionMath.Snapshot?
    let setup: AimingCorrectionMath.TeachingSetup

    var body: some View {
        let mid = SCNVector3(
            (setup.cue.x + setup.target.x) * 0.5,
            setup.surfaceY,
            (setup.cue.z + setup.target.z) * 0.5
        )
        let closeCenter = CGPoint(x: CGFloat(mid.x), y: CGFloat(mid.z))
        BTTableFigure(orientation: .landscape,
                      closeup: (center: closeCenter, halfHeight: 0.42)) { proj in
            let d = proj.ballDiameter
            BTFigureBall(number: 1, diameter: d).position(proj.point(setup.target))
            BTFigureBall(diameter: d).position(proj.point(setup.cue))

            if let snap = snapshot {
                // Aim line: solved aim through cue, extend both ways
                let aimFwd = extend(from: setup.cue, dir: snap.solvedAimDir, meters: 0.55)
                let aimBack = extend(from: setup.cue, dir: snap.solvedAimDir, meters: -0.18)
                Path { p in
                    p.move(to: proj.point(aimBack))
                    p.addLine(to: proj.point(aimFwd))
                }
                .stroke(FigureLine.aim,
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [4, 3]))

                // Pre-contact curve
                let pts = AimingCorrectionMath.samplePreContactPath(snap.preContactSegments)
                if pts.count >= 2 {
                    Path { p in
                        p.move(to: proj.point(pts[0]))
                        for i in 1..<pts.count {
                            p.addLine(to: proj.point(pts[i]))
                        }
                    }
                    .stroke(FigureLine.actual,
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))
                }

                BTGhostCircle(diameter: d, showsAimPoint: true)
                    .position(proj.point(snap.ghost))

                BTFigureTag(text: "瞄准线", color: FigureLine.aim)
                    .position(alongLabel(from: proj.point(aimBack),
                                         to: proj.point(aimFwd), t: 0.2, offset: -14))
                BTFigureTag(text: "实际轨迹", color: FigureLine.actual)
                    .position(pts.count >= 2
                              ? alongLabel(from: proj.point(pts[0]),
                                           to: proj.point(pts[pts.count / 2]),
                                           t: 0.6, offset: 14)
                              : proj.point(setup.cue))
                BTFigureTag(text: "假想球", color: FigureLine.ghost)
                    .position(x: proj.point(snap.ghost).x,
                              y: proj.point(snap.ghost).y - d * 0.7)
                if abs(snap.squirtDegrees) > 0.05 {
                    BTFigureTag(
                        text: String(format: "挤偏 %+.1f°", snap.squirtDegrees),
                        color: FigureLine.effect
                    )
                    .position(x: proj.point(setup.cue).x,
                              y: proj.point(setup.cue).y + d * 0.75)
                }
            } else {
                ProgressView().tint(.white.opacity(0.5))
            }
        }
    }
}

// MARK: - ⑤ Solver compare

private struct SolverCompareFigure: View {
    let comparison: AimingCorrectionMath.SolveComparison?
    let setup: AimingCorrectionMath.TeachingSetup

    var body: some View {
        let closeCenter = CGPoint(x: CGFloat(setup.target.x) - 0.05,
                                  y: CGFloat(setup.target.z) + 0.02)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: closeCenter, halfHeight: 0.40)) { proj in
            let d = proj.ballDiameter
            BTFigureBall(number: 1, diameter: d).position(proj.point(setup.target))
            BTFigureBall(diameter: d).position(proj.point(setup.cue))

            if let cmp = comparison {
                let cue = setup.cue
                let geoEnd = extend(from: cue, dir: cmp.a.geometricAimDir, meters: 0.48)
                let aEnd = extend(from: cue, dir: cmp.a.solvedAimDir, meters: 0.48)
                let bEnd = extend(from: cue, dir: cmp.b.solvedAimDir, meters: 0.48)

                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(geoEnd))
                }
                .stroke(FigureLine.hint,
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [5, 4]))

                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(aEnd))
                }
                .stroke(FigureLine.actual,
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(bEnd))
                }
                .stroke(FigureLine.effect,
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                BTGhostCircle(diameter: d, showsAimPoint: true)
                    .position(proj.point(cmp.a.ghost))

                BTFigureTag(text: "几何", color: FigureLine.hint)
                    .position(alongLabel(from: proj.point(cue),
                                         to: proj.point(geoEnd), t: 0.85, offset: -12))
                BTFigureTag(
                    text: String(format: "A Δ%+.1f°", cmp.a.aimOffsetDegrees),
                    color: FigureLine.actual
                )
                .position(alongLabel(from: proj.point(cue),
                                     to: proj.point(aEnd), t: 0.7, offset: 14))
                BTFigureTag(
                    text: String(format: "B Δ%+.1f°", cmp.b.aimOffsetDegrees),
                    color: FigureLine.effect
                )
                .position(alongLabel(from: proj.point(cue),
                                     to: proj.point(bEnd), t: 0.55, offset: -16))
            } else {
                ProgressView().tint(.white.opacity(0.5))
            }
        }
    }
}

#Preview("Light") {
    NavigationStack { AimingCorrectionView() }
}

#Preview("Dark") {
    NavigationStack { AimingCorrectionView() }
        .preferredColorScheme(.dark)
}
