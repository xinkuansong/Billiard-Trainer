import SwiftUI
import SceneKit

/// 瞄准修正（问题集合 v12 Z1/Z2）：理想角度瞄准法 vs 真实物理偏差。
///
/// Z2 范围：② 投掷效应节 + ③ 高低杆有效厚度节 + 共享控件组第一期
/// （力度滑杆 + 高低杆三档，去抖接真源层）。④⑤ 与左右塞轴留给 Z3。
/// 数值真源 `AimingCorrectionMath`；定性符号以 `build/z1-evidence/` 草稿为准。
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

    // MARK: - Shared controls（Z2 第一期：力度 + 高低杆三档）

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

            Text("高低杆")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
            Picker("高低杆", selection: Binding(
                get: { vm.spinYTier },
                set: { vm.setSpinYTier($0) }
            )) {
                ForEach(AimingCorrectionMath.SpinYTier.allCases) { tier in
                    Text(tier.label).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("aimingCorrection.spinYPicker")

            Text("拖动力度或切换高低杆，①②③ 节插图按引擎实况实时重算（约 20ms 去抖）。左右塞轴见后续节。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.controls")
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

    // MARK: - ② 投掷效应

    private var throwSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("投掷效应（Throw）")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section2.title")

            ThrowCollisionFigure(sample: vm.throwSample, setup: vm.setup)
                .frame(height: 240)
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
                Text("碰撞瞬间，接触面摩擦把目标球拽离理想进球线——这就是投掷。下图夸大画出了实际离开方向相对进球线的夹角 Δ；离开方向数值与自动求解读的是同一份引擎实况。")
                Text("切角投掷（CIT）：不加塞也会发生，切角越大越明显、到半球附近最明显（引擎草稿：同速下 30° 切角 1.55° > 15° 切角 1.12°，45° 与半球持平）。塞致投掷（SIT）：左右塞改变接触面相对滑动，目标球离开方向再偏一截——左塞的投掷分量把目标球向右带（引擎草稿核验；净方向还叠加挤偏，深讲见后续节）。")
                Text("力度规律：越慢投掷越大（接触面相对速度越低，摩擦越大）。引擎草稿同局面：慢速投掷 1.454° > 快速 0.793°——轻推薄球容易不进，往往就是投掷把球带离进球线。")
            }
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)

            Text("切角与假想球几何见「瞄准原理」「瞄准方法」；本节省去复述。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section2")
    }

    // MARK: - ③ 高低杆改变有效厚度

    private var thicknessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("高低杆改变有效厚度")
                .font(.btTitle)
                .foregroundStyle(.btText)
                .accessibilityIdentifier("aimingCorrection.section3.title")

            ThicknessTripleFigure(triple: vm.thicknessTriple, active: vm.spinYTier)
                .frame(height: 220)
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
                Text("同一瞄准点下，上下旋改变碰撞瞬间接触面相对滑动方向，摩擦力水平分量变化，投掷方向跟着变——观感上就像「厚度变了」。")
                Text("Z1 草稿同局面（v=1.5、无塞）：高杆 bias −0.726° > 中杆 −1.546°（相对中杆更偏薄）；低杆 bias −2.995° < 中杆（相对中杆更偏厚）。正值 = 偏薄侧（符号经 ±1.5° 瞄准扰动标定）。")
                Text("实战翻译：高杆瞄厚一点、低杆瞄薄一点——补偿的是投掷带来的有效厚度变化，不是几何瞄准点公式本身变了。")
            }
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)

            Text("厚度与切角对照仍见「瞄准点对照表」；本页只讲杆法对有效厚度的修正。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aimingCorrection.section3")
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
            BTFigureBall(number: 1, diameter: proj.ballDiameter)
                .position(proj.point(setup.target))
            BTFigureBall(diameter: proj.ballDiameter)
                .position(proj.point(setup.cue))

            if let snap = snapshot {
                let cue = setup.cue
                let geoEnd = extend(from: cue, dir: snap.geometricAimDir, meters: 0.45)
                let solEnd = extend(from: cue, dir: snap.solvedAimDir, meters: 0.45)
                let ghostP = proj.point(snap.ghost)

                dashedLine(proj: proj, from: cue, to: geoEnd, color: .white.opacity(0.55))
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

// MARK: - ② Throw collision close-up（Canvas 示意 + 引擎离开方向）

private struct ThrowCollisionFigure: View {
    let sample: AimingCorrectionMath.ThrowDiagramSample?
    let setup: AimingCorrectionMath.TeachingSetup

    /// Δ 夸大倍率（视觉可读；读数仍用真实 throwDegrees）。
    private let exaggerate: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 16
            let cx = size.width * 0.42
            let cy = size.height * 0.55
            let r = min(size.width, size.height) * 0.18

            // Cue (ghost position) left, object right — schematic contact
            let cueC = CGPoint(x: cx - r * 0.95, y: cy)
            let objC = CGPoint(x: cx + r * 0.95, y: cy)
            let contact = CGPoint(x: (cueC.x + objC.x) / 2, y: cy)

            // Balls
            ctx.fill(Circle().path(in: CGRect(x: cueC.x - r, y: cueC.y - r,
                                              width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(0.92)))
            ctx.stroke(Circle().path(in: CGRect(x: cueC.x - r, y: cueC.y - r,
                                                width: r * 2, height: r * 2)),
                       with: .color(.black.opacity(0.25)), lineWidth: 1)
            ctx.fill(Circle().path(in: CGRect(x: objC.x - r, y: objC.y - r,
                                              width: r * 2, height: r * 2)),
                     with: .color(Color(red: 0.95, green: 0.75, blue: 0.2)))
            ctx.stroke(Circle().path(in: CGRect(x: objC.x - r, y: objC.y - r,
                                                width: r * 2, height: r * 2)),
                       with: .color(.black.opacity(0.3)), lineWidth: 1)

            // Contact dot
            let dotR: CGFloat = 4
            ctx.fill(Circle().path(in: CGRect(x: contact.x - dotR, y: contact.y - dotR,
                                              width: dotR * 2, height: dotR * 2)),
                     with: .color(FigureLine.contact))

            guard let sample else {
                var idle = Text("计算中…").font(.caption).foregroundColor(.secondary)
                ctx.draw(idle, at: CGPoint(x: size.width / 2, y: pad + 8), anchor: .top)
                return
            }

            // 手性标定（Z2 草稿 handedness-calibration）：顶视投影 x_s=X、y_s=−Z 下，
            // signedAngleXZ 正（绕 +Y，= 行进右侧）⇒ 屏上 y 减小（向上）。
            // 示意帧取 pot = +screenX，故实际离开方向的屏上偏转角 = −signed×夸大。
            let throwRad = CGFloat(sample.throwDegrees) * .pi / 180 * exaggerate
            let signed = AimingCorrectionMath.signedAngleXZ(
                from: sample.potDir, to: sample.objPostDir
            )
            let side: CGFloat = signed >= 0 ? -1 : 1

            let lineLen = min(size.width, size.height) * 0.42
            let potEnd = CGPoint(x: objC.x + lineLen, y: objC.y)
            let objAngle = side * throwRad
            let leaveEnd = CGPoint(
                x: objC.x + lineLen * cos(objAngle),
                y: objC.y + lineLen * sin(objAngle)
            )

            // Ideal pot line (dashed)
            var potPath = Path()
            potPath.move(to: objC)
            potPath.addLine(to: potEnd)
            ctx.stroke(potPath, with: .color(FigureLine.pot(number: 1).opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

            // Actual leave (solid, exaggerated)
            var leavePath = Path()
            leavePath.move(to: objC)
            leavePath.addLine(to: leaveEnd)
            ctx.stroke(leavePath, with: .color(Color.btPrimary),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Friction arrow at contact (tangent, exaggerated side)
            let frLen: CGFloat = r * 0.9
            let frEnd = CGPoint(x: contact.x + frLen * 0.2,
                                y: contact.y + side * frLen)
            drawArrow(ctx: ctx, from: contact, to: frEnd, color: .orange.opacity(0.9))

            // Labels
            var tContact = Text("接触点").font(.system(size: 10, weight: .semibold))
                .foregroundColor(FigureLine.contact)
            ctx.draw(tContact, at: CGPoint(x: contact.x, y: contact.y - r - 10), anchor: .bottom)

            // 标签分层防遮挡：理想线标签固定在虚线末端「反偏转侧」，
            // 实际离开标签在偏转侧再推一行，Δ 说明固定右上角。
            var tPot = Text("理想进球线").font(.system(size: 10, weight: .semibold))
                .foregroundColor(FigureLine.pot(number: 1))
            ctx.draw(tPot, at: CGPoint(x: potEnd.x - 4, y: potEnd.y - side * 14),
                     anchor: side > 0 ? .bottomTrailing : .topTrailing)

            var tLeave = Text("实际离开").font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.btPrimary)
            ctx.draw(tLeave, at: CGPoint(x: leaveEnd.x, y: leaveEnd.y + side * 14),
                     anchor: side > 0 ? .topTrailing : .bottomTrailing)

            // 摩擦标签移到箭杆左侧（母球侧空区），与接触点标签、箭头本体全部错开。
            var tFr = Text("摩擦").font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
            ctx.draw(tFr,
                     at: CGPoint(x: contact.x - 12, y: contact.y + side * frLen * 0.55),
                     anchor: .trailing)

            var tDelta = Text("Δ ×\(Int(exaggerate)) 夸大").font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.btPrimary)
            ctx.draw(tDelta, at: CGPoint(x: size.width - pad, y: pad), anchor: .topTrailing)

            var tCue = Text("母球").font(.system(size: 9)).foregroundColor(.secondary)
            ctx.draw(tCue, at: CGPoint(x: cueC.x, y: cueC.y + r + 10), anchor: .top)
            var tObj = Text("目标球").font(.system(size: 9)).foregroundColor(.secondary)
            ctx.draw(tObj, at: CGPoint(x: objC.x, y: objC.y + r + 10), anchor: .top)
        }
        .background(Color.btTableFelt.opacity(0.55))
    }

    private func drawArrow(ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        let angle = atan2(to.y - from.y, to.x - from.x)
        let head: CGFloat = 7
        var headPath = Path()
        headPath.move(to: to)
        headPath.addLine(to: CGPoint(x: to.x - head * cos(angle - 0.4),
                                     y: to.y - head * sin(angle - 0.4)))
        headPath.move(to: to)
        headPath.addLine(to: CGPoint(x: to.x - head * cos(angle + 0.4),
                                     y: to.y - head * sin(angle + 0.4)))
        ctx.stroke(headPath, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

// MARK: - ③ Thickness triple comparison

private struct ThicknessTripleFigure: View {
    let triple: AimingCorrectionMath.ThicknessTriple?
    let active: AimingCorrectionMath.SpinYTier

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let colW = w / 3
            HStack(spacing: 0) {
                ForEach(AimingCorrectionMath.SpinYTier.allCases) { tier in
                    laneColumn(
                        tier: tier,
                        lane: triple?.lanes.first { $0.tier == tier },
                        potDir: triple?.potDir,
                        midBias: triple?.mid?.thicknessBiasDegrees,
                        size: CGSize(width: colW, height: h),
                        highlighted: tier == active
                    )
                }
            }
        }
        .background(Color.btTableFelt.opacity(0.55))
    }

    @ViewBuilder
    private func laneColumn(
        tier: AimingCorrectionMath.SpinYTier,
        lane: AimingCorrectionMath.ThicknessLane?,
        potDir: SCNVector3?,
        midBias: Float?,
        size: CGSize,
        highlighted: Bool
    ) -> some View {
        Canvas { ctx, sz in
            let cx = sz.width * 0.5
            let cy = sz.height * 0.58
            let r = min(sz.width, sz.height) * 0.16

            // Object ball
            ctx.fill(Circle().path(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .color(Color(red: 0.95, green: 0.75, blue: 0.2).opacity(highlighted ? 1 : 0.75)))

            // Ideal pot = upward (screen −Y) as reference
            let potLen = sz.height * 0.32
            var potPath = Path()
            potPath.move(to: CGPoint(x: cx, y: cy))
            potPath.addLine(to: CGPoint(x: cx, y: cy - potLen))
            ctx.stroke(potPath, with: .color(FigureLine.pot(number: 1).opacity(0.7)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            if let lane, let pot = potDir {
                // Exaggerated leave relative to potDir; screen up = pot.
                // 手性与 BTTableFigure 顶视投影一致（x_s=X, y_s=−Z）：
                // +signedAngleXZ（绕 +Y）在屏上为逆时针 ⇒ pot 朝上时偏向屏左。
                // 标定：世界 +Z pot 旋 +θ → (−sinθ, 0, cosθ) → 屏 (−sinθ, −cosθ)。
                let signed = AimingCorrectionMath.signedAngleXZ(from: pot, to: lane.objPostDir)
                let exaggerate: CGFloat = 10
                let ang = CGFloat(signed) * exaggerate
                let leaveEnd = CGPoint(
                    x: cx - potLen * sin(ang),
                    y: cy - potLen * cos(ang)
                )
                var leave = Path()
                leave.move(to: CGPoint(x: cx, y: cy))
                leave.addLine(to: leaveEnd)
                ctx.stroke(leave, with: .color(highlighted ? Color.btPrimary : Color.btPrimary.opacity(0.55)),
                           style: StrokeStyle(lineWidth: highlighted ? 2.5 : 1.8, lineCap: .round))

                // 定性标签由实况数值相对中杆比较得出（Z1 符号契约：bias 正 = 偏薄侧；
                // 高杆较中杆更薄 / 低杆较中杆更厚在中速档已核验，此处不硬编码而随实况）。
                let rel: String
                if tier == .mid {
                    rel = "基准"
                } else if let mid = midBias {
                    let d = lane.thicknessBiasDegrees - mid
                    rel = abs(d) < 0.005 ? "≈中杆" : (d > 0 ? "较中杆薄" : "较中杆厚")
                } else {
                    rel = ""
                }
                var tag = Text(rel).font(.system(size: 11, weight: .bold))
                    .foregroundColor(highlighted ? Color.btPrimary : Color.secondary)
                ctx.draw(tag, at: CGPoint(x: cx, y: cy - potLen - 14), anchor: .bottom)
            }

            var title = Text(tier.label).font(.system(size: 12, weight: .semibold))
                .foregroundColor(highlighted ? Color.btPrimary : Color.primary.opacity(0.8))
            ctx.draw(title, at: CGPoint(x: cx, y: 10), anchor: .top)

            var potTag = Text("进球线").font(.system(size: 9)).foregroundColor(.secondary)
            ctx.draw(potTag, at: CGPoint(x: cx + 10, y: cy - potLen + 4), anchor: .leading)
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottom) {
            if highlighted {
                Capsule()
                    .fill(Color.btPrimary)
                    .frame(width: 28, height: 3)
                    .padding(.bottom, 6)
            }
        }
    }
}
