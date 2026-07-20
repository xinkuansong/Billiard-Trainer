import SwiftUI
import SceneKit

/// 瞄准方法（问题集合 v11 Y1，返工 r1 / FL-026）：按 §2.1 v11.2 用户原意口径——
/// ① 管道瞄准法：瞄准线与进球线各扩成半径 R 的管道，两管道外切处 = 接触点 Q；
/// ② 接触点瞄准法（点对点）：连接 Pt / Pc，击球把两点碰到一起；
/// ③ 平行线瞄准法：过母球心作接触点连线的平行线即瞄准方向。
/// 三节共享切角 θ 滑杆（5°–75°，默认 30° = 半球）；几何唯一真源
/// `AimingMethodsGeometry`（恒等式 Pc→Pt ≡ G−C，数值草稿 build/y1-evidence/）。
/// 厚薄数值真源 `AngleSceneCalculator.NamedBallThickness`；θ↔瞄准点速查与
/// 「接触点≠瞄准点」误区交叉引用「瞄准点对照表」「瞄准原理」，本页不重复成段。
struct AimingMethodsView: View {
    /// 共享切角 θ（三法节联动）；默认 30° = `NamedBallThickness.halfBall`。
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                PipeMethodSection(cutAngleDeg: cutAngleDeg)
                ContactMethodSection(cutAngleDeg: cutAngleDeg)
                ParallelMethodSection(cutAngleDeg: cutAngleDeg)
                overlapSection(cutAngleDeg: cutAngleDeg)
                crossRefsSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("瞄准方法")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Intro + shared θ

    private var introSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("三种常用瞄准法")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("「瞄准原理」里的角度瞄准法：先读出切角 θ，再用 d = 2R·sin(θ) 翻成瞄准点。下面三种方法与它同一套几何，只是换了「怎么看见」——殊途同归，都落到 d = 2R·sin(θ)。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                methodSummaryRow("管道法", "把瞄准线、进球线扩成圆管，用相切代替点瞄准")
                methodSummaryRow("接触点法", "把瞄准变成「两个点碰到一起」")
                methodSummaryRow("平行线法", "用两球接触点连线定出瞄准方向")
            }

            // A6：本页符号图例（子集与 SPEC §8.8 一致）。
            symbolLegend
                .accessibilityIdentifier("aimingMethods.symbolLegend")

            Text("拖动切角 θ：管道 / 接触点 / 平行线 / Mosconi 变体 / 厚薄示意同步变化。默认 30°（半球）。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            Divider()

            HStack {
                Text("切角 θ")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Spacer()
                Text("\(Int(cutAngleDeg))°")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
            }
            Slider(value: $cutAngleDeg, in: 5...75, step: 1)
                .tint(.btPrimary)
                .accessibilityIdentifier("aimingMethods.thetaSlider")
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    /// A6：开篇符号图例——仅本页出场符号，口径对齐 SPEC §8.8。
    private var symbolLegend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("符号图例")
                .font(.btCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.btTextSecondary)
            symbolLegendRow("θ", "切角：瞄准线与进球线的夹角")
            symbolLegendRow("φ", "试瞄角（管道法）：拖到 φ≈θ 时两管相切")
            symbolLegendRow("Q", "接触点：碰撞瞬间两球切点（碰合点）")
            symbolLegendRow("Pt", "目标球侧接触点（背袋点）")
            symbolLegendRow("Pc", "母球侧接触点（对应点）")
            symbolLegendRow("G", "假想球球心（虚线圈中心）")
            symbolLegendRow("管", "管道（隧道）：瞄准线/进球线扩成半径 R 的圆管")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.btBG.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    private func symbolLegendRow(_ symbol: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(symbol)
                .font(.btCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.btPrimary)
                .frame(width: 28, alignment: .leading)
            Text(desc)
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
    }

    private func methodSummaryRow(_ term: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(term)
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btPrimary)
                .frame(width: 72, alignment: .leading)
            Text(desc)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }

    /// D-v13-3：节内小读数（非 sticky），滑杆滚出视野后仍可知当前 θ。
    fileprivate static func sectionThetaReadout(_ cutAngleDeg: Double) -> some View {
        Text("当前 θ = \(Int(cutAngleDeg))°")
            .font(.btCaption)
            .fontWeight(.medium)
            .foregroundStyle(.btTextSecondary)
            .monospacedDigit()
            .accessibilityIdentifier("aimingMethods.sectionTheta")
    }

    // MARK: - 补充：重合比例法（厚薄法）

    private func overlapSection(cutAngleDeg: Double) -> some View {
        let nearest = AngleSceneCalculator.namedBallThickness(
            cutAngleDegrees: cutAngleDeg, tolerance: 2.5)
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("补充：重合比例法（厚薄法）")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Spacer(minLength: Spacing.sm)
                AimingMethodsView.sectionThetaReadout(cutAngleDeg)
            }

            OverlapAimingFigure(cutAngleDeg: cutAngleDeg)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("aimingMethods.overlap.figure")

            Text("俯身时不估 θ，改看母球与目标球在视线方向上的重合比例（厚度）：叠得越多球越厚、θ 越小。图随页顶 θ 连续变化。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                thicknessRow(AngleSceneCalculator.threeQuarterBall, highlighted: nearest?.name)
                thicknessRow(AngleSceneCalculator.halfBall, highlighted: nearest?.name)
                thicknessRow(AngleSceneCalculator.quarterBall, highlighted: nearest?.name)
            }
            .accessibilityIdentifier("aimingMethods.overlap.table")

            Text("sin(θ) = 1 − 重合比例，故 d/R = 2·(1 − 重合比例)。数值与「瞄准点对照表」同一口径；靠近命名厚度时表行高亮。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func thicknessRow(_ t: AngleSceneCalculator.NamedBallThickness,
                              highlighted: String?) -> some View {
        let angleText = t.cutAngleDegrees == t.cutAngleDegrees.rounded()
            ? "\(Int(t.cutAngleDegrees))°"
            : String(format: "%.1f°", t.cutAngleDegrees)
        let dText = t.dOverR == t.dOverR.rounded()
            ? String(format: "%.0f", t.dOverR)
            : String(format: "%.2f", t.dOverR)
        let isOn = highlighted == t.name
        return HStack(spacing: Spacing.sm) {
            Text(t.name)
                .font(.btSubheadlineMedium)
                .foregroundStyle(isOn ? .btPrimary : .btTextSecondary)
                .frame(width: 64, alignment: .leading)
            Text("切角 \(angleText)")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
            Spacer()
            Text("d/R \(dText)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.btTextSecondary)
            if isOn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.btPrimary)
                    .accessibilityLabel("当前厚度")
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(isOn ? Color.btPrimaryMuted : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Cross refs

    private var crossRefsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(title: "回看角度瞄准法",
                        destination: "瞄准原理 · 切角与 d = 2R·sin(θ)",
                        route: .aimingPrinciple)

            PracticeCTA(title: "打开瞄准点对照表",
                        destination: "常用角度的瞄准点速查",
                        route: .contactPointTable)

            PracticeCTA(title: "打开瞄准修正",
                        destination: "投掷 · 高低杆 · 加塞对瞄准的修正",
                        route: .aimingCorrection)

            PracticeCTA(title: "打开旋转与加塞",
                        destination: "旋转四态 · 分离角 · 打滑极限",
                        route: .spinAndEnglish)
        }
    }
}

// MARK: - Section 1: 管道瞄准法（双管道相切，可试瞄）

private struct PipeMethodSection: View {
    let cutAngleDeg: Double
    /// 试瞄角 φ：用户拖动，φ ≈ θ 时吸附到相切。
    @State private var trialAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees
    private let snapToleranceDeg: Double = 2.5

    /// 吸附后的有效试瞄角（吸附 ⇒ 距离精确 = 2R ⇒ 判定相切）。
    private var effectiveTrialDeg: Double {
        abs(trialAngleDeg - cutAngleDeg) <= snapToleranceDeg ? cutAngleDeg : trialAngleDeg
    }

    var body: some View {
        let scene = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        let result = AimingMethodsGeometry.pipeVerdict(scene: scene,
                                                       trialAngleDeg: CGFloat(effectiveTrialDeg))
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("管道瞄准法（隧道瞄准法）")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Spacer(minLength: Spacing.sm)
                AimingMethodsView.sectionThetaReadout(cutAngleDeg)
            }

            PipeTubesFigure(scene: scene,
                            trialAngleDeg: CGFloat(effectiveTrialDeg),
                            verdict: result.verdict)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            verdictBadge(result)

            HStack {
                Text("试瞄角 φ")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                Spacer()
                Text("\(Int(effectiveTrialDeg))°")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(result.verdict == .tangent ? .btSuccess : .btText)
            }
            Slider(value: $trialAngleDeg, in: 5...75, step: 1)
                .tint(.btPrimary)
                .accessibilityIdentifier("aimingMethods.pipe.trialSlider")
            Text("拖试瞄角：太厚＝两管相交，太薄＝相离，φ≈θ 时吸附为相切。改页顶 θ 时 φ 跟随到新 θ，默认保持相切。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                aimingStep(1, "把进球线、瞄准线各扩成半径 = 球半径 R 的管道（管宽恰好一个球径）。")
                aimingStep(2, "目标球走黄管进袋；母球走白管靠近目标球。")
                aimingStep(3, "瞄准正确时两管外切，切点就是接触点 Q。")
            }

            Text("两管外切 ⇔ 母球心到达假想球心 G（球心距 = 2R）。管道把「打厚打薄」变成看得见的相交与相离。加塞时管道中心随让点修正，见「瞄准修正」。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        // A4：页顶 θ 变化时试瞄角 φ 对齐到新 θ（吸附区内亦为相切）。
        .onChange(of: cutAngleDeg) { _, newTheta in
            trialAngleDeg = newTheta
        }
    }

    @ViewBuilder
    private func verdictBadge(_ result: (distance: CGFloat, verdict: AimingMethodsGeometry.PipeVerdict)) -> some View {
        let twoR = 2 * AimingMethodsGeometry.ballRadius
        // 极厚脱靶区（草稿 P3 附注）试瞄管从另一侧远离 ⇒ D>2R，文案不再称「相交」。
        let (text, color): (String, Color) = switch result.verdict {
        case .tooThick: (result.distance < twoR ? "太厚 · 管道相交" : "太厚", .btWarning)
        case .tangent:  ("✓ 相切 · 切点 = 接触点 Q", .btSuccess)
        case .tooThin:  ("太薄 · 管道相离", .btWarning)
        }
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(text)
                .font(.btSubheadlineMedium)
                .foregroundStyle(color)
            Text(String(format: "轴距 %.1f mm · 相切时 = 2R（%.1f mm）",
                        result.distance * 1000, twoR * 1000))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }
}

/// 双管道插图：进球管道（目标球本色，T→袋）+ 试瞄管道（瞄准线白，C 沿 φ）。
/// 试瞄管必须用 `FigureLine.aim`，禁止品牌绿——绿管叠绿毡几乎不可见。
/// 相切时点亮切点 Q。管道半径 = 球半径 R（世界尺度投影）。
private struct PipeTubesFigure: View {
    let scene: AimingMethodsGeometry.Scene
    let trialAngleDeg: CGFloat
    let verdict: AimingMethodsGeometry.PipeVerdict

    var body: some View {
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let d = proj.ballDiameter
            let rView = d / 2
            let edgeW = max(proj.lineHintWidth, 1.4)

            let u = AimingMethodsGeometry.trialAimDir(scene: scene, trialAngleDeg: trialAngleDeg)
            let trialEndW = CGPoint(x: scene.cue.x + u.x * scene.cueDistance,
                                    y: scene.cue.y + u.y * scene.cueDistance)
            let trialEnd = proj.point(x: trialEndW.x, z: trialEndW.y)
            let potFarW = CGPoint(x: scene.target.x + scene.potDir.x * 0.5,
                                  y: scene.target.y + scene.potDir.y * 0.5)
            let potFar = proj.point(x: potFarW.x, z: potFarW.y)

            ZStack {
                // 进球管（黄）在下；试瞄管（白）在上，避免相切时被盖住。
                tube(from: target, to: potFar, halfWidth: rView,
                     color: FigureLine.pot(number: 1), lineWidth: edgeW, fillOpacity: 0.16)
                tube(from: cue, to: trialEnd, halfWidth: rView,
                     color: FigureLine.aim, lineWidth: edgeW, fillOpacity: 0.20)

                // 试瞄管中心线（略亮于管壁，标出瞄准轴）。
                Path { p in p.move(to: cue); p.addLine(to: trialEnd) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)

                if verdict == .tangent {
                    Circle()
                        .stroke(FigureLine.contact, lineWidth: 2)
                        .frame(width: d * 0.5, height: d * 0.5)
                        .position(q)
                    BTContactDot(diameter: max(4, d * 0.22)).position(q)
                    BTFigureTag(text: "Q 接触点", color: FigureLine.contact)
                        .position(x: q.x + d * 0.9, y: q.y - d * 0.75)
                }

                BTFigureTag(text: "进球管道", color: FigureLine.pot(number: 1))
                    .position(alongLabel(from: target, to: potFar, t: 0.55, offset: -(rView + 13)))
                BTFigureTag(text: "试瞄管道", color: FigureLine.aim)
                    .position(alongLabel(from: cue, to: trialEnd, t: 0.32, offset: rView + 13))
                BTFigureTag(text: "母球").position(x: cue.x, y: cue.y + d / 2 + 12)
                BTFigureTag(text: "假想球", color: FigureLine.contact)
                    .position(x: ghost.x - d * 1.1, y: ghost.y + d / 2 + 12)
            }
        }
    }

    private func tube(from a: CGPoint, to b: CGPoint, halfWidth: CGFloat,
                      color: Color, lineWidth: CGFloat, fillOpacity: Double) -> some View {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let px = -dy / len * halfWidth, py = dx / len * halfWidth
        let l0 = CGPoint(x: a.x + px, y: a.y + py)
        let l1 = CGPoint(x: b.x + px, y: b.y + py)
        let r0 = CGPoint(x: a.x - px, y: a.y - py)
        let r1 = CGPoint(x: b.x - px, y: b.y - py)
        return ZStack {
            Path { p in
                p.move(to: l0); p.addLine(to: l1)
                p.addLine(to: r1); p.addLine(to: r0)
                p.closeSubpath()
            }
            .fill(color.opacity(fillOpacity))
            Path { p in p.move(to: l0); p.addLine(to: l1) }
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: lineWidth, dash: [5, 3]))
            Path { p in p.move(to: r0); p.addLine(to: r1) }
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: lineWidth, dash: [5, 3]))
        }
    }
}

// MARK: - Section 2: 接触点瞄准法（点对点，碰合动画）

private struct ContactMethodSection: View {
    let cutAngleDeg: Double
    /// D-v13-2 / A7：进入即碰合终帧；按钮只负责重播。
    @State private var mergeProgress: CGFloat = 1

    var body: some View {
        let scene = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        let mislead = AimingMethodsGeometry.misleadAngleDeg(scene: scene)
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("接触点瞄准法（点对点）")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Spacer(minLength: Spacing.sm)
                AimingMethodsView.sectionThetaReadout(cutAngleDeg)
            }

            ContactMergeFigure(scene: scene, progress: mergeProgress)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            // A7：误差角徽章常显，不依赖播放。
            misleadAngleBadge(degrees: mislead)

            Button {
                mergeProgress = 0
                withAnimation(.easeInOut(duration: 1.2)) { mergeProgress = 1 }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.btFootnote.weight(.semibold))
                    Text("重播碰合过程")
                        .font(.btSubheadlineMedium)
                }
                .foregroundStyle(Color.btPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.btPrimaryMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("aimingMethods.contact.play")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                aimingStep(1, "找 Pt：目标球背对袋口一侧，球心沿进球方向后退一个半径 R。")
                aimingStep(2, "找 Pc：母球心沿同一进球方向前进一个半径 R。")
                aimingStep(3, "瞄准 = 想象击球把这两个点碰到一起。")
            }

            Text("Pc→Pt 与 C→G 同向等长；两点碰合时母球心恰好落在假想球心 G。接触点≠瞄准点见「瞄准原理」。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func misleadAngleBadge(degrees: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(String(format: "误差角约 %.1f° · 别「心对点」", degrees))
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btWarning)
            Text("灰虚线让球心直指 Pt，与真瞄准线夹角如上——瞄它必打厚。")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.btWarning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityIdentifier("aimingMethods.contact.misleadBadge")
    }
}

/// 接触点碰合插图：Pt（绿点）/ Pc（白点）+ 虚线连线；播放时母球沿瞄准线
/// 平移至球心落 G、Pc 与 Pt 碰合于 Q；灰色误导线 = 球心直指 Pt。
private struct ContactMergeFigure: View {
    let scene: AimingMethodsGeometry.Scene
    let progress: CGFloat

    var body: some View {
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let cueStart = proj.point(x: scene.cue.x, z: scene.cue.y)
            let pt = proj.point(x: scene.targetContact.x, z: scene.targetContact.y)
            let d = proj.ballDiameter

            let cueNowW = AimingMethodsGeometry.mergedCueCenter(scene: scene, progress: progress)
            let pcNowW = AimingMethodsGeometry.movingCueContact(scene: scene, progress: progress)
            let cueNow = proj.point(x: cueNowW.x, z: cueNowW.y)
            let pcNow = proj.point(x: pcNowW.x, z: pcNowW.y)

            // 误导线终点：C 沿 (Pt−C) 方向延长一段。
            let mislead = extended(from: cueStart, through: pt, factor: 1.25)

            ZStack {
                // 真瞄准线 C→G（白实线）。
                Path { p in p.move(to: cueStart); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 误导线（灰虚线）：球心直指 Pt。
                Path { p in p.move(to: cueStart); p.addLine(to: mislead) }
                    .stroke(Color.gray.opacity(0.65),
                            style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [3, 3]))

                // Pc→Pt 连线（品牌绿虚线，随动画收拢）。
                Path { p in p.move(to: pcNow); p.addLine(to: pt) }
                    .stroke(FigureLine.contact,
                            style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [4, 3]))

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cueNow)

                // Pt 绿点（目标球背袋点）与 Pc 白点（母球对应点）。
                BTContactDot(diameter: max(4, d * 0.2)).position(pt)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(FigureLine.contact, lineWidth: 1.2))
                    .frame(width: max(4, d * 0.16), height: max(4, d * 0.16))
                    .position(pcNow)

                if progress >= 0.999 {
                    Circle()
                        .stroke(FigureLine.contact, lineWidth: 2)
                        .frame(width: d * 0.55, height: d * 0.55)
                        .position(pt)
                    BTFigureTag(text: "两点碰合于 Q", color: FigureLine.contact)
                        .position(x: pt.x + d * 1.1, y: pt.y - d * 0.85)
                }

                BTFigureTag(text: "Pt", color: FigureLine.contact)
                    .position(x: pt.x + d * 0.55, y: pt.y + d * 0.55)
                if progress < 0.7 {
                    BTFigureTag(text: "Pc", color: FigureLine.contact)
                        .position(x: pcNow.x - d * 0.5, y: pcNow.y - d * 0.55)
                }
                BTFigureTag(text: "母球").position(x: cueStart.x, y: cueStart.y + d / 2 + 12)
                BTFigureTag(text: "心对点（误导）", color: Color.gray)
                    .position(alongLabel(from: cueStart, to: mislead, t: 0.42, offset: -13))
                BTFigureTag(text: "瞄准线")
                    .position(alongLabel(from: cueStart, to: ghost, t: 0.26, offset: 14))
            }
        }
    }

    private func extended(from a: CGPoint, through b: CGPoint, factor: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * factor, y: a.y + (b.y - a.y) * factor)
    }
}

// MARK: - Section 3: 平行线瞄准法（接触点连线的过心平行线）

private struct ParallelMethodSection: View {
    let cutAngleDeg: Double

    var body: some View {
        let scene = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("平行线瞄准法")
                    .font(.btTitle)
                    .foregroundStyle(.btText)
                Spacer(minLength: Spacing.sm)
                AimingMethodsView.sectionThetaReadout(cutAngleDeg)
            }

            ParallelContactFigure(scene: scene)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("aimingMethods.parallel.figure")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                aimingStep(1, "连金线：两球接触点 Pc → Pt。")
                aimingStep(2, "过母球心作金线的平行线（白线）——就是瞄准方向。")
                aimingStep(3, "碰撞瞬间两球心关于接触点 Q 点对称。")
            }

            Text("白线与母球心→假想球心连线同向重合；拖页顶切角 θ 时金线与白线始终平行。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)

            Divider()

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("变体：Mosconi 平行线")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btText)
                MosconiVariantFigure(cutAngleDeg: cutAngleDeg)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    .accessibilityIdentifier("aimingMethods.mosconi.figure")
                Text("过目标球心作进球线，过母球心作平行线；两线间距 δ 即横移量，平移收拢后得瞄准线。与主图同源，随页顶 θ 变化。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }
}

/// 平行线主图：金色 Pc→Pt 连线 + 过母球心的白色平行线（= 瞄准线，指向 G）。
/// A8：标出 Q（几何上 Q ≡ Pt = (G+T)/2），与正文「点对称」一致。
private struct ParallelContactFigure: View {
    let scene: AimingMethodsGeometry.Scene

    var body: some View {
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let pt = proj.point(x: scene.targetContact.x, z: scene.targetContact.y)
            let pc = proj.point(x: scene.cueContact.x, z: scene.cueContact.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let d = proj.ballDiameter

            // 金线沿 Pc→Pt 两端各延一点；白平行线过 C 同方向延长。
            let goldA = lerp(pc, pt, t: -0.15)
            let goldB = lerp(pc, pt, t: 1.3)
            let dirX = pt.x - pc.x, dirY = pt.y - pc.y
            let aimA = CGPoint(x: cue.x - dirX * 0.15, y: cue.y - dirY * 0.15)
            let aimB = CGPoint(x: cue.x + dirX * 1.3, y: cue.y + dirY * 1.3)

            ZStack {
                // Pc→Pt 连线（金 = 作图参考量）。
                Path { p in p.move(to: goldA); p.addLine(to: goldB) }
                    .stroke(Color.btAccent, lineWidth: 1.8)

                // 过母球心的平行线 = 瞄准线（白实线）。
                Path { p in p.move(to: aimA); p.addLine(to: aimB) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)

                BTContactDot(diameter: max(4, d * 0.2)).position(q)
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(FigureLine.contact, lineWidth: 1.2))
                    .frame(width: max(4, d * 0.16), height: max(4, d * 0.16))
                    .position(pc)

                // A8：Q 与点对称提示（Q ≡ Pt）。
                BTFigureTag(text: "Q（点对称）", color: FigureLine.contact)
                    .position(x: q.x + d * 0.85, y: q.y - d * 0.75)
                BTFigureTag(text: "Pt", color: FigureLine.contact)
                    .position(x: pt.x + d * 0.45, y: pt.y + d * 0.55)
                BTFigureTag(text: "Pc", color: FigureLine.contact)
                    .position(x: pc.x - d * 0.45, y: pc.y - d * 0.5)
                BTFigureTag(text: "接触点连线 Pc→Pt", color: Color.btAccent)
                    .position(alongLabel(from: goldA, to: goldB, t: 0.55, offset: -18))
                BTFigureTag(text: "瞄准线（平行）")
                    .position(alongLabel(from: aimA, to: aimB, t: 0.30, offset: 20))
                BTFigureTag(text: "假想球 G", color: FigureLine.contact)
                    .position(x: ghost.x + d * 0.4, y: ghost.y + d / 2 + 14)
                BTFigureTag(text: "母球").position(x: cue.x - d * 0.8, y: cue.y - d / 2 - 12)
            }
        }
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Mosconi 变体附图（随页顶 θ）

private struct MosconiVariantFigure: View {
    let cutAngleDeg: Double

    var body: some View {
        let scene = AimingMethodsGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let pocket = proj.point(x: scene.pocket.x, z: scene.pocket.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let d = proj.ballDiameter

            let pdx = pocket.x - target.x, pdy = pocket.y - target.y
            let pLen = max(hypot(pdx, pdy), 0.001)
            let pux = pdx / pLen, puy = pdy / pLen

            let potA = CGPoint(x: target.x - pux * d * 2.8, y: target.y - puy * d * 2.8)
            let potB = CGPoint(x: target.x + pux * d * 2.2, y: target.y + puy * d * 2.2)
            let parA = CGPoint(x: cue.x - pux * d * 1.6, y: cue.y - puy * d * 1.6)
            let parB = CGPoint(x: cue.x + pux * d * 2.4, y: cue.y + puy * d * 2.4)

            let tOnPot = ((cue.x - target.x) * pux + (cue.y - target.y) * puy)
            let foot = CGPoint(x: target.x + pux * tOnPot, y: target.y + puy * tOnPot)

            ZStack {
                Path { p in p.move(to: potA); p.addLine(to: potB) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))
                Path { p in p.move(to: parA); p.addLine(to: parB) }
                    .stroke(Color.btAccent.opacity(0.9),
                            style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [4, 3]))
                Path { p in p.move(to: cue); p.addLine(to: foot) }
                    .stroke(Color.btAccent, lineWidth: 1.6)
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)

                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(alongLabel(from: target, to: pocket, t: 0.32, offset: -14))
                BTFigureTag(text: "过心平行线", color: Color.btAccent)
                    .position(alongLabel(from: parA, to: parB, t: 0.88, offset: 15))
                Text("δ")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.btAccent)
                    .position(x: (cue.x + foot.x) / 2 - 10, y: (cue.y + foot.y) / 2 - 8)
            }
        }
    }
}

// MARK: - 重合比例（厚薄）补充图：随页顶 θ（overlap = 1 − sinθ）

private struct OverlapAimingFigure: View {
    let cutAngleDeg: Double

    var body: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let overlap = AimingMethodsGeometry.classicOverlap(cutAngleDegrees: cutAngleDeg)
        let named = AngleSceneCalculator.namedBallThickness(
            cutAngleDegrees: cutAngleDeg, tolerance: 2.5)
        let angleText = cutAngleDeg == cutAngleDeg.rounded()
            ? "\(Int(cutAngleDeg))°"
            : String(format: "%.1f°", cutAngleDeg)
        let label: String = {
            if let named {
                return "\(named.name) · 切角 \(angleText)"
            }
            return String(format: "重合 %.0f%% · 切角 %@", overlap * 100, angleText)
        }()

        return BTTableFigure(orientation: .landscape,
                             closeup: (center: .zero, halfHeight: r * 2.4)) { proj in
            let d = proj.ballDiameter
            // 视图平面示意：球心水平间距 = 直径 × (1 − overlap)；非 SceneKit 世界坐标。
            let sep = d * (1 - CGFloat(overlap))
            let target = CGPoint(x: proj.size.width / 2 + sep / 2, y: proj.size.height / 2 - 6)
            let cue = CGPoint(x: proj.size.width / 2 - sep / 2, y: proj.size.height / 2 - 6)

            ZStack {
                BTFigureBall(number: 1, diameter: d, showsShadow: false).position(target)
                BTFigureBall(diameter: d, showsShadow: false).position(cue)

                BTFigureTag(text: "目标球")
                    .position(x: target.x + d * 0.55, y: target.y + d / 2 + 14)
                BTFigureTag(text: "母球")
                    .position(x: cue.x - d * 0.45, y: cue.y + d / 2 + 14)

                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .position(x: proj.size.width / 2, y: proj.size.height - 16)
            }
        }
    }
}

// MARK: - Shared helpers

/// 学页分步说明（对齐瞄准原理页 derivationStep 形态）。
private func aimingStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: Spacing.sm) {
        Text("\(n)")
            .font(.btCaption2)
            .fontWeight(.bold)
            .foregroundStyle(.btPrimary)
            .frame(width: 18, height: 18)
            .background(Color.btPrimaryMuted, in: Circle())
        Text(text)
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)
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

#Preview("Light") {
    NavigationStack { AimingMethodsView() }
}

#Preview("Dark") {
    NavigationStack { AimingMethodsView() }
        .preferredColorScheme(.dark)
}
