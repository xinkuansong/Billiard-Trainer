import SwiftUI
import SceneKit

/// 瞄准修正（问题集合 v12 Z1）：理想角度瞄准法 vs 真实物理偏差的横切基座页。
///
/// Z1 范围：① 开篇节（理想 vs 现实，Δ 实况图）+ ⑥ 导流节 + 对「瞄准原理」/
/// 「瞄准方法」的交叉引用。②③④⑤ 节留给 Z2/Z3。
/// 数值真源 `AimingCorrectionMath`；符号以 `build/z1-evidence/` 草稿为准。
struct AimingCorrectionView: View {
    @StateObject private var vm = AimingCorrectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                sharedControls
                idealVsRealitySection
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("理想 vs 现实")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.intro.title")

            Text("角度瞄准法假设碰撞无摩擦、母球走直线。真实球台两条都不成立：进球线可以固定，但「怎么瞄」会随力度与杆法变化。本页讲三个偏差源——投掷、高低杆对有效厚度的影响、加塞下的挤偏与弧线——以及自动求解如何把它们算进去。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Text("几何瞄准点仍由切角决定（d = 2R·sinθ，详见「瞄准原理」「瞄准方法」）；下面只讲几何之外还要补的那一截。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.intro")
    }

    // MARK: - Shared controls (Z1: drive Δ figure; Z2/Z3 will reuse)

    private var sharedControls: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("实况参数")
                .font(.btSubheadlineMedium)
                .foregroundStyle(.btText)

            HStack {
                Text("力度")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Text(String(format: "%.1f m/s", vm.velocity))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
            }
            Slider(
                value: Binding(
                    get: { vm.velocity },
                    set: { vm.setVelocity($0) }
                ),
                in: ShotTuning.velocityRange,
                step: 0.1
            )
            .tint(.btPrimary)
            .accessibilityIdentifier("aimingCorrection.velocitySlider")

            HStack {
                Text("左右塞")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Text(String(format: "%+.2f", vm.spinX))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
            }
            Slider(
                value: Binding(
                    get: { vm.spinX },
                    set: { vm.setSpinX($0) }
                ),
                in: -Double(CuePhysics.miscueLimitFraction)...Double(CuePhysics.miscueLimitFraction),
                step: 0.05
            )
            .tint(.btPrimary)
            .accessibilityIdentifier("aimingCorrection.spinXSlider")

            HStack {
                Text("高低杆")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                Spacer()
                Text(spinYLabel)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.btPrimary)
            }
            Slider(
                value: Binding(
                    get: { vm.spinY },
                    set: { vm.setSpinY($0) }
                ),
                in: -Double(CuePhysics.miscueLimitFraction)...Double(CuePhysics.miscueLimitFraction),
                step: 0.05
            )
            .tint(.btPrimary)
            .accessibilityIdentifier("aimingCorrection.spinYSlider")

            Text("拖动滑杆，Δ 与轨迹按引擎实况实时重算。正值 = 左塞 / 高杆。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.controls")
    }

    private var spinYLabel: String {
        let y = vm.spinY
        if abs(y) < 0.02 { return "中杆 0.00" }
        return y > 0 ? String(format: "高杆 %+.2f", y) : String(format: "低杆 %+.2f", y)
    }

    // MARK: - ① Δ 实况图

    private var idealVsRealitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("同一局面：几何瞄准 vs 求解瞄准")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("虚线 = 假想球几何方向（角度瞄准法）；实线 = 自动求解的瞄准方向。两线夹角 Δ 与自动求解读的是同一份引擎数值。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

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

            Text("中杆中速、小切角时 Δ 往往很小，角度瞄准法够用；大切角、慢速或加塞时，这段偏差必须补偿。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section1")
    }

    // MARK: - Cross refs（不重复成段）

    private var crossRefsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(
                title: "回看瞄准原理",
                destination: "切入角 · 假想球 · d = 2R·sinθ",
                route: .aimingPrinciple
            )

            PracticeCTA(
                title: "打开瞄准方法",
                destination: "管道 · 接触点 · 平行线",
                route: .aimingMethods
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.crossRefs")
    }

    // MARK: - ⑥ 导流

    private var practiceCTASection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("实战启示")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section6.title")

            Text("边界感知：中杆中速小切角时，用角度瞄准法通常够用；大切角 + 慢速 + 加塞时，必须让求解（或经验补偿）把投掷、挤偏与弧线算进去。到「思路训练」里换力度与塞，直接看瞄准线怎么动。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            PracticeCTA(
                title: "去思路训练看实况",
                destination: "自动求解 · 力度与塞如何改瞄准线",
                route: .positionPlaySolver
            )
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section6")
    }
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
            // Target + cue
            BTFigureBall(number: 1, diameter: proj.ballDiameter)
                .position(proj.point(setup.target))
            BTFigureBall(diameter: proj.ballDiameter)
                .position(proj.point(setup.cue))

            if let snap = snapshot {
                let cue = setup.cue
                let geoEnd = extend(from: cue, dir: snap.geometricAimDir, meters: 0.45)
                let solEnd = extend(from: cue, dir: snap.solvedAimDir, meters: 0.45)
                let ghostP = proj.point(snap.ghost)

                // Geometric aim (dashed via short segments)
                dashedLine(proj: proj, from: cue, to: geoEnd, color: .white.opacity(0.55))
                // Solved aim (solid)
                Path { p in
                    p.move(to: proj.point(cue))
                    p.addLine(to: proj.point(solEnd))
                }
                .stroke(Color.btPrimary, style: StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round))

                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: proj.ballDiameter, height: proj.ballDiameter)
                    .position(ghostP)

                Text("Δ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.btPrimary)
                    .position(midpoint(proj.point(geoEnd), proj.point(solEnd)))
            }
        }
    }

    private func extend(from: SCNVector3, dir: SCNVector3, meters: Float) -> SCNVector3 {
        SCNVector3(from.x + dir.x * meters, from.y, from.z + dir.z * meters)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
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
