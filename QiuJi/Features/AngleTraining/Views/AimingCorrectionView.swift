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
        }
        .background(.btBG)
        .navigationTitle("瞄准修正")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { vm.onAppear() }
    }

    // MARK: - ① 开篇

    private var introSection: some View {
        LearnDocSectionCard {
            Text("理想 vs 现实")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.intro.title")

            LearnDocText.body("角度瞄准法假设碰撞无摩擦、母球走直线。真实球台两条都不成立：进球线可以固定，但「怎么瞄」会随力度与杆法变化。本页讲三个偏差源——投掷、高低杆对有效厚度的影响、加塞下的挤偏与弧线——以及自动求解如何把它们算进去。")

            LearnDocText.footnote("几何瞄准点仍由切角决定（d = 2R·sinθ，详见「瞄准原理」「瞄准方法」）；下面只讲几何之外还要补的那一截。")
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
            footer: "拖动控件时 ①–④ 节插图按引擎实况实时重算（约 20ms 去抖）。左右塞与高低杆合成幅值钳在打滑极限内（0.5R，与打点盘同口径）。",
            velocityAccessibilityIdentifier: "aimingCorrection.velocitySlider",
            spinYAccessibilityIdentifier: "aimingCorrection.spinYPicker",
            spinXAccessibilityIdentifier: "aimingCorrection.spinXSlider"
        )
        .accessibilityIdentifier("aimingCorrection.controls")
    }

    // MARK: - ① Δ 实况图

    private var idealVsRealitySection: some View {
        LearnDocSectionCard(title: "同一局面：几何瞄准 vs 求解瞄准") {
            LearnDocText.body("虚线 = 假想球几何方向（角度瞄准法）；实线 = 自动求解的瞄准方向。两线夹角 Δ 与自动求解读的是同一份引擎数值。")

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
                        .foregroundStyle(.btTextSecondary)
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

            LearnDocText.footnote("中杆中速、小切角时 Δ 往往很小，角度瞄准法够用；大切角、慢速或加塞时，这段偏差必须补偿。")
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
                        .foregroundStyle(.btTextSecondary)
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.throwReadout")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("碰撞瞬间，接触面摩擦把目标球拽离理想进球线——这就是投掷。下图夸大画出了实际离开方向相对进球线的夹角 Δ；离开方向数值与自动求解读的是同一份引擎实况。")
                LearnDocText.body("切角投掷（CIT）：不加塞也会发生，切角越大越明显、到半球附近最明显（引擎草稿：同速下 30° 切角 1.55° > 15° 切角 1.12°，45° 与半球持平）。塞致投掷（SIT）：左右塞改变接触面相对滑动，目标球离开方向再偏一截——左塞的投掷分量把目标球向右带（引擎草稿核验；净方向还叠加挤偏，见④节）。")
                LearnDocText.body("力度规律：越慢投掷越大（接触面相对速度越低，摩擦越大）。引擎草稿同局面：慢速投掷 1.454° > 快速 0.793°——轻推薄球容易不进，往往就是投掷把球带离进球线。")
            }

            LearnDocText.footnote("切角与假想球几何见「瞄准原理」「瞄准方法」；本节省去复述。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section2")
    }

    // MARK: - ③ 高低杆改变有效厚度

    private var thicknessSection: some View {
        LearnDocSectionCard {
            Text("高低杆改变有效厚度")
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
                            Text(String(format: "bias %+0.2f°（%@）",
                                         lane.thicknessBiasDegrees, biasLabel))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.btTextSecondary)
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
                LearnDocText.body("同一瞄准点下，上下旋改变碰撞瞬间接触面相对滑动方向，摩擦力水平分量变化，投掷方向跟着变——观感上就像「厚度变了」。")
                LearnDocText.body("Z1 草稿同局面（v=1.5、无塞）：高杆 bias −0.726° > 中杆 −1.546°（相对中杆更偏薄）；低杆 bias −2.995° < 中杆（相对中杆更偏厚）。正值 = 偏薄侧（符号经 ±1.5° 瞄准扰动标定）。")
                LearnDocText.body("实战翻译：高杆瞄厚一点、低杆瞄薄一点——补偿的是投掷带来的有效厚度变化，不是几何瞄准点公式本身变了。")
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
                            .foregroundStyle(.btTextSecondary)
                    }
                    if let swerve {
                        Text(String(format: "弧线横向漂移 ≈ %+.1f mm（%@）",
                                     swerve.signedMeters * 1000, swerve.signLabel))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.btTextSecondary)
                    }
                }
                .padding(Spacing.md)
                .background(Color.btPrimaryMuted)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .accessibilityIdentifier("aimingCorrection.englishReadout")
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("挤偏（Squirt）：杆头打在球侧，出杆瞬间母球出发方向偏向加塞反侧——立即发生，与行程和速度基本无关。左塞（spinX>0）挤偏向右（引擎：squirt 为负；Z1 草稿左塞 +0.35 → −1.415°；Z3 同参 −1.232°）。这是三个偏差源里唯一不随力度变的。")
                LearnDocText.body("弧线（Swerve）：滑动段侧旋与台呢摩擦使轨迹微弯，越慢累积越明显（Z3 草稿组合档：v=0.8 漂移 4.6mm > v=4.0 0.1mm）。注意：平杆纯左右塞时自转轴竖直、轨迹几乎不弯（Z3 草稿 ≈0）——弧线要叠加高低杆（自转轴倾斜）或抬杆仰角才明显（草稿仰角 5° 实测 8.9mm）。无塞时瞄准线、出发方向与碰前轨迹近乎重合；加塞后挤偏使瞄准线与实际出发分离——上图杆指向线（白虚线）、母球实际行进曲线（主色）、假想球位置可对照。")
                LearnDocText.body("净效果 = 挤偏 + 弧线 + 到达后的塞致投掷（SIT），三者叠加没有简单口诀——所以才需要⑤节的自动求解。")
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

            LearnDocText.body("收拢①–④：求解器用完整物理链——杆-球碰撞含挤偏 → 滑动/滚动含弧线 → 球-球摩擦碰撞含投掷——反向搜索瞄准方向，使目标球碰后方向正对袋口。力度和塞是搜索输入，每换一档瞄准线重算。上图档 A（中杆中速无塞，v=1.5）与档 B（低杆轻推+左塞，v=0.8 / spinY=−0.4 / spinX=+0.3）各调一次求解，几何基准虚线对照。")

            Text("定性速查（方向不给度数；符号均经数值草稿核验）")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.quickref.title")

            VStack(spacing: Spacing.sm) {
                quickRefRow("轻力", "投掷更大", "z1 CIT 慢>快")
                quickRefRow("大切角", "投掷更明显（半球附近见顶）", "z2 CIT 15→30↑ / 45≈峰")
                quickRefRow("高杆", "偏薄 → 需瞄厚一点", "z1 bias 高>中")
                quickRefRow("低杆", "偏厚 → 需瞄薄一点", "z1 bias 低<中")
                quickRefRow("左塞", "挤偏向右 + SIT 把目标球向右带", "z1 squirt<0；z2 SIT")
                quickRefRow("挤偏", "与力度基本无关（三源唯一）", "z3 squirt 无 v 参数")
                quickRefRow("弧线", "纯侧旋平杆几乎不弯；叠加高低杆/仰角才弯，越慢越明显", "z3 swerve 漂移实测")
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

    private func quickRefRow(_ condition: String, _ conclusion: String, _ source: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(condition)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(conclusion)
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Text(source)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.btTextTertiary)
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

            LearnDocText.body("边界感知：中杆中速小切角时，用角度瞄准法通常够用；大切角 + 慢速 + 加塞时，必须让求解（或经验补偿）把投掷、挤偏与弧线算进去。到「思路训练」里换力度与塞，直接看瞄准线怎么动。")

            PracticeCTA(
                title: "去思路训练看实况",
                destination: "自动求解 · 力度与塞如何改瞄准线",
                route: .positionPlaySolver
            )

            PracticeCTA(
                title: "练挤偏认知",
                destination: "免费钩子 · 直球近台带塞让点",
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

                dashedLine(proj: proj, from: cue, to: geoEnd, color: FigureLine.hint.opacity(0.7))
                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(solEnd))
                }
                .stroke(Color.btPrimary, style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                BTGhostCircle(diameter: proj.ballDiameter, showsAimPoint: true)
                    .position(proj.point(snap.ghost))

                BTFigureTag(text: "Δ", color: .btPrimary)
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
                .stroke(Color.btPrimary,
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
                BTFigureTag(text: "实际离开", color: .btPrimary)
                    .position(alongLabel(from: proj.point(target),
                                         to: proj.point(leaveEnd), t: 0.8, offset: 14))
                BTFigureTag(text: "摩擦", color: .btWarning)
                    .position(alongLabel(from: proj.point(contact),
                                         to: proj.point(frEnd), t: 0.85, offset: -12))
                BTFigureTag(text: "Δ ×\(max(1, Int(effExaggerate.rounded()))) 夸大", color: .btPrimary)
                    .position(x: proj.size.width - 52, y: 16)
                BTFigureTag(text: "假想球", color: FigureLine.contact)
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
        .stroke(Color.btWarning, style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
                    .stroke(color.opacity(isActive ? 1 : 0.28),
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
        case .low: return .btWarning
        case .mid: return FigureLine.separation
        case .high: return .btPhysicsAdjustable
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
                .stroke(FigureLine.aim.opacity(0.75),
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
                    .stroke(Color.btPrimary,
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))
                }

                BTGhostCircle(diameter: d, showsAimPoint: true)
                    .position(proj.point(snap.ghost))

                BTFigureTag(text: "瞄准线", color: FigureLine.aim)
                    .position(alongLabel(from: proj.point(aimBack),
                                         to: proj.point(aimFwd), t: 0.2, offset: -14))
                BTFigureTag(text: "实际轨迹", color: .btPrimary)
                    .position(pts.count >= 2
                              ? alongLabel(from: proj.point(pts[0]),
                                           to: proj.point(pts[pts.count / 2]),
                                           t: 0.6, offset: 14)
                              : proj.point(setup.cue))
                BTFigureTag(text: "假想球", color: FigureLine.contact)
                    .position(x: proj.point(snap.ghost).x,
                              y: proj.point(snap.ghost).y - d * 0.7)
                if abs(snap.squirtDegrees) > 0.05 {
                    BTFigureTag(
                        text: String(format: "挤偏 %+.1f°", snap.squirtDegrees),
                        color: .btWarning
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
                .stroke(FigureLine.hint.opacity(0.7),
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [5, 4]))

                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(aEnd))
                }
                .stroke(Color.btPrimary,
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(bEnd))
                }
                .stroke(Color.btWarning,
                        style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                BTGhostCircle(diameter: d, showsAimPoint: true)
                    .position(proj.point(cmp.a.ghost))

                BTFigureTag(text: "几何", color: FigureLine.hint)
                    .position(alongLabel(from: proj.point(cue),
                                         to: proj.point(geoEnd), t: 0.85, offset: -12))
                BTFigureTag(
                    text: String(format: "A Δ%+.1f°", cmp.a.aimOffsetDegrees),
                    color: .btPrimary
                )
                .position(alongLabel(from: proj.point(cue),
                                     to: proj.point(aEnd), t: 0.7, offset: 14))
                BTFigureTag(
                    text: String(format: "B Δ%+.1f°", cmp.b.aimOffsetDegrees),
                    color: .btWarning
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
