import SwiftUI

/// 旋转与加塞（v11 Y2 → v12 Z4）：母球旋转状态 → 分离角联动为主轴；
/// 切角滑杆驱动三路径实况球形；最小加塞（T09）+ 打滑极限；打点产生旋转；
/// 左右塞与吃库反弹（定性示意）；投掷/挤偏/弧线一句话 + 真跳转「瞄准修正」。
/// 几何真源 `SpinAndEnglishGeometry` + 数值草稿 `build/z4-evidence/`。
struct SpinAndEnglishView: View {
    @State private var selectedSpin: SpinAndEnglishGeometry.SpinState = .stun
    /// 共享切角 θ（5°–75°）；默认 30° = 半球。只驱动球形，示意角为教学折线。
    @State private var cutAngleDeg: Double = AngleSceneCalculator.halfBall.cutAngleDegrees

    private var miscueLimit: Float { CuePhysics.miscueLimitFraction }
    private var isHalfBall: Bool {
        abs(cutAngleDeg - AngleSceneCalculator.halfBall.cutAngleDegrees) < 0.5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: isHalfBall
                        ? "默认 30°（半球）。此时示意角与半球口诀一致。"
                        : "当前非半球：插图为教学折线示意，不声称精确分离角。实战随切角变化见「分离角图谱」。",
                    accessibilityIdentifier: "spinAndEnglish.thetaSlider"
                )
                linkageSection
                statesSection
                tipContactSection
                minimumEnglishSection
                cushionEnglishSection
                aimingCorrectionCTA
                crossRefsSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxxxl)
        }
        .background(.btBG)
        .navigationTitle("旋转与加塞")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Intro

    private var introSection: some View {
        LearnDocSectionCard(title: "接触瞬间的旋转决定分离角") {
            LearnDocText.body("出杆后母球先滑动，再过渡到滚动。真正决定碰后母球走向的，不是你打了高杆还是低杆本身，而是碰到目标球那一瞬间母球处于哪种旋转状态。同一杆几何、不同接触旋转，会走出截然不同的分离角。")

            LearnDocText.footnote("本页主轴：旋转状态 → 分离角；左右塞如何改吃库反弹见下文。挤偏、弧线、投掷对瞄准的细修正见「瞄准修正」。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.intro")
    }

    // MARK: - Main axis: spin → separation

    private var linkageSection: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        let sep = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: selectedSpin)
        return LearnDocSectionCard(title: "三种旋转 → 三条分离角走向") {
            LearnDocText.body("下图同一杆几何：目标球沿进球线离开；母球碰后先沿切线出发，再按接触时的旋转前弯或后弯。拖动切角可改球形；点选状态可高亮对应轨迹。")

            Picker("旋转状态", selection: $selectedSpin) {
                ForEach(SpinAndEnglishGeometry.SpinState.allCases) { state in
                    Text(state.pickerTitle).tag(state)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("spinAndEnglish.spinPicker")

            SeparationPathsFigure(selected: selectedSpin, cutAngleDeg: CGFloat(cutAngleDeg))
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.figure")

            HStack(spacing: Spacing.sm) {
                Text(selectedSpin.pathLabel)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btPrimary)
                Spacer()
                Text(String(format: "示意角 · 教学折线 ≈ %.0f°", sep))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(Spacing.md)
            .background(Color.btPrimaryMuted)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .accessibilityIdentifier("spinAndEnglish.sepReadout")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("滑动（stun / 定杆）：接触时几乎无前旋后旋，母球沿切线离开，与进球线夹角约 90°（90° 法则 / 切线法则）。")
                LearnDocText.body("前旋（高杆 / 自然滚动）：接触时已有前旋或已自然滚动，母球从切线向前弯回瞄准线一侧——半球口诀约 30° 偏离原瞄准线（30° 法则）。")
                LearnDocText.body("后旋（低杆）：接触时后旋仍在，母球从切线向后弯，分离角大于 90°。")
            }

            LearnDocText.footnote("图上三条路径是教学折线（滑动 90° / 前旋 60° / 后旋 120°，相对进球线），用来记住口诀；实战分离角随切角、力度与滑动→滚动进度连续变化，见「分离角图谱」。App 内辅助线经验修正约为 90°±20°（高杆减小、低杆增大），仅作提示，不参与物理求解。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.linkage")
    }

    // MARK: - Spin states glossary

    private var statesSection: some View {
        LearnDocSectionCard(title: "母球旋转状态") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                stateRow("滑动", "stun：纯平移、几乎无前后旋。中杆、较短距离、偏快力度时常见。")
                stateRow("自然滚动", "滑动被台呢摩擦「吃掉」后的稳态：线速度与自转匹配，既前进又前旋。")
                stateRow("前旋", "高杆或已自然滚动：碰后向前弯（跟进走位）。")
                stateRow("后旋", "低杆：碰后向后弯（缩杆走位）。后旋也会被摩擦逐渐吃掉。")
            }

            LearnDocText.body("出杆后常见过程：滑动 →（可选）仍带后旋或已前旋 → 最终自然滚动。距离越长、力度越小，越容易在碰到目标球之前进入滚动；短距大力则更常以滑动状态接触。")

            LearnDocText.footnote("切角、假想球与瞄准点本身见「瞄准原理」；本页不重复瞄准几何。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.states")
    }

    private func stateRow(_ term: String, _ desc: String) -> some View {
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

    // MARK: - Tip contact → spin

    private var tipContactSection: some View {
        LearnDocSectionCard(title: "打点如何产生旋转") {
            LearnDocText.body("皮头打在母球正面的不同位置，接触瞬间把不同方向的旋转传给母球：高低打点改前后旋，左右打点改侧旋（加塞）。")

            TipContactFigure(limitFraction: CGFloat(miscueLimit))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.tipFigure")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("高杆 / 低杆：改变接触瞬间的前旋或后旋，从而改变分离角（见上文主轴与「分离角图谱」）。")
                LearnDocText.body("左塞 / 右塞：改变侧旋。侧旋主要改吃库后的反弹（见下节）；对瞄准线的挤偏、弧线与投掷细修正见「瞄准修正」。")
            }

            LearnDocText.footnote("可靠打点须落在打滑极限圈内（约 \(String(format: "%.0f", miscueLimit * 100))% 球半径）；圈外易滑杆，塞不再稳定传递。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.tipContact")
    }

    // MARK: - Minimum English + miscue

    private var minimumEnglishSection: some View {
        let pct = Int((miscueLimit * 100).rounded())
        return LearnDocSectionCard(title: "最小加塞与打滑极限") {
            MiscueLimitFigure(limitFraction: CGFloat(miscueLimit))
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.miscueFigure")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("能用中杆 + 高低杆（配合切线 / 30° / 90° 法则）完成的走位，尽量不要加左右塞——这就是最小加塞原则：每多一分塞，就多一分瞄准误差来源。")
                LearnDocText.body(String(
                    format: "打点偏离球心的可靠上限是母球半径的 %.0f%%（皮头打滑极限）。超过约 %.1fR，皮头容易打滑（滑杆），塞不再稳定传递。App 打点盘把可拖区域钳在这一比例内，与引擎常量一致。",
                    Float(pct), miscueLimit
                ))
            }

            LearnDocText.footnote("打滑极限与 App 打点盘钳制同一常量（母球半径的 \(String(format: "%.0f", miscueLimit * 100))%）。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.minimumEnglish")
    }

    // MARK: - Cushion × sidespin (qualitative)

    private var cushionEnglishSection: some View {
        LearnDocSectionCard(title: "左右塞与吃库反弹") {
            LearnDocText.body("无塞吃库时，可用「入射角 ≈ 反射角」作教学基线。侧旋会打破这条基线：顺塞让反弹更开，逆塞让反弹更闭——用来制造「反常」反弹角完成走位。")

            CushionEnglishFigure()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.cushionFigure")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("顺塞（Running）：侧旋与反弹切向大致同向，吃库后反弹更开（离开库法线更大）。")
                LearnDocText.body("逆塞（Reverse）：侧旋与反弹切向大致反向，吃库后反弹更闭（更靠近库法线）。")
                LearnDocText.body("实战用途：走位优先用高低杆改分离角；左右塞留给需要改吃库反弹、或必须微调瞄准的场合。")
            }

            LearnDocText.footnote("上图为定性示意（非引擎实况采样）。口径来自最少加塞原则中「用加塞调反弹角」与撞库后顺/逆塞分类；精确吃库后扇形请打开「加塞吃库图谱」（引擎实况，已补偿挤偏）。")

            LearnDocTextLink(title: "打开加塞吃库图谱",
                             subtitle: "中杆 · 8 档左右塞 · 吃库后出射",
                             route: .cushionEnglishAtlas)
                .accessibilityIdentifier("spinAndEnglish.cushionEnglishAtlasLink")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.cushionEnglish")
    }

    // MARK: - Aiming correction CTA (true NavigationLink)

    private var aimingCorrectionCTA: some View {
        LearnDocSectionCard(title: "加塞还会改变瞄准") {
            LearnDocText.body("左右塞还会带来挤偏（squirt）、弧线（swerve）与投掷（throw）等效应，使实际进球线相对几何瞄准产生偏差。")

            PracticeCTA(title: "打开瞄准修正",
                        destination: "投掷 · 挤偏 · 弧线：几何之外的偏差",
                        route: .aimingCorrection)
                .accessibilityIdentifier("spinAndEnglish.aimingCorrectionCTA")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.aimingCorrectionSection")
    }

    // MARK: - Cross refs（D-v14-6：页末大卡合计 ≤2；瞄准修正 + 挤偏 drill；图谱降为文字链）

    private var crossRefsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(title: "练挤偏认知",
                        destination: "免费钩子 · 直球近台带塞让点",
                        route: .drillDetail("drill_c073"))
                .accessibilityIdentifier("spinAndEnglish.squirtDrillCTA")

            LearnDocTextLink(title: "打开分离角图谱",
                             subtitle: "8 档高低杆 · 碰后轨迹对比",
                             route: .separationAngleAtlas)

            LearnDocTextLink(title: "回看瞄准原理",
                             subtitle: "切角 · 假想球 · 接触点",
                             route: .aimingPrinciple)

            LearnDocTextLink(title: "打开瞄准方法",
                             subtitle: "管道 · 接触点 · 平行线",
                             route: .aimingMethods)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.crossRefs")
    }
}

// MARK: - Separation paths figure

/// 碰后三路径插图（滑动沿切线 / 前旋前弯 / 后旋后弯）。
///
/// v30 W1 返工 r1：由 `private` 放开为 internal，供球理页「切线法则」复用
///（⛔ 不另造 Theory 专用三路径图）。`emphasizeAll = true` 时三条同时实描并各带标签，
/// 用于没有状态选择器的静态讲解场景；默认 false，本页行为不变。
struct SeparationPathsFigure: View {
    let selected: SpinAndEnglishGeometry.SpinState
    let cutAngleDeg: CGFloat
    var emphasizeAll: Bool = false

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: cutAngleDeg)
        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.40, y: -0.16), halfHeight: 0.36)) { proj in
            let target = proj.point(x: scene.target.x, z: scene.target.y)
            let ghost = proj.point(x: scene.ghost.x, z: scene.ghost.y)
            let cue = proj.point(x: scene.cue.x, z: scene.cue.y)
            let q = proj.point(x: scene.contact.x, z: scene.contact.y)
            let obEnd = SpinAndEnglishGeometry.objectBallEnd(scene: scene)
            let potFar = proj.point(x: obEnd.x, z: obEnd.y)
            let d = proj.ballDiameter

            ZStack {
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.35), lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                ForEach(SpinAndEnglishGeometry.SpinState.allCases) { state in
                    let endW = SpinAndEnglishGeometry.pathEnd(scene: scene, state: state)
                    let end = proj.point(x: endW.x, z: endW.y)
                    let active = emphasizeAll || state == selected
                    let color = pathColor(state)
                    Path { p in p.move(to: ghost); p.addLine(to: end) }
                        .stroke(color.opacity(active ? 1 : 0.28),
                                style: StrokeStyle(
                                    lineWidth: active ? proj.lineMainWidth : proj.lineHintWidth,
                                    dash: state == .stun ? [4, 3] : []
                                ))
                    if active {
                        BTFigureTag(text: state.pathLabel, color: color)
                            .position(spinAlongLabel(from: ghost, to: end, t: 0.72, offset: 16))
                    }
                }

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)
                BTContactDot(diameter: max(4, d * 0.2)).position(q)

                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(spinAlongLabel(from: target, to: potFar, t: 0.45, offset: -14))
                BTFigureTag(text: "母球").position(x: cue.x, y: cue.y + d / 2 + 12)
                BTFigureTag(text: "假想球", color: FigureLine.contact)
                    .position(x: ghost.x - d * 0.9, y: ghost.y + d / 2 + 12)
            }
        }
    }

    private func pathColor(_ state: SpinAndEnglishGeometry.SpinState) -> Color {
        switch state {
        case .stun:   return FigureLine.separation
        case .follow: return Color.btAccent
        case .draw:   return Color.btWarning
        }
    }
}

// MARK: - Tip contact face-on (tokenized)

private struct TipContactFigure: View {
    let limitFraction: CGFloat

    private struct TipMark: Identifiable {
        let id: String
        let dx: CGFloat
        let dy: CGFloat
        let label: String
        let color: Color
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.40, geo.size.height * 0.82)
            let cx = geo.size.width * 0.34
            let cy = geo.size.height * 0.48
            let r = side / 2
            let limitR = r * limitFraction
            let marks: [TipMark] = [
                .init(id: "high", dx: 0, dy: -limitR * 0.72, label: "高杆 → 前旋", color: .btAccent),
                .init(id: "low", dx: 0, dy: limitR * 0.72, label: "低杆 → 后旋", color: .btWarning),
                .init(id: "left", dx: -limitR * 0.72, dy: 0, label: "左塞 → 侧旋", color: .btPrimary),
                .init(id: "right", dx: limitR * 0.72, dy: 0, label: "右塞 → 侧旋", color: .btPrimary),
            ]

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btTableFelt.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                // Cue-ball disk (tokens; not hardcoded RGB sphere).
                Circle()
                    .fill(Color.btBGTertiary)
                    .overlay(Circle().stroke(Color.btSeparator, lineWidth: 1.5))
                    .frame(width: side, height: side)
                    .position(x: cx, y: cy)

                Circle()
                    .stroke(Color.btPrimary.opacity(0.85),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: limitR * 2, height: limitR * 2)
                    .position(x: cx, y: cy)

                // Crosshair.
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy - r * 0.85))
                    p.addLine(to: CGPoint(x: cx, y: cy + r * 0.85))
                    p.move(to: CGPoint(x: cx - r * 0.85, y: cy))
                    p.addLine(to: CGPoint(x: cx + r * 0.85, y: cy))
                }
                .stroke(Color.btTextTertiary.opacity(0.45), lineWidth: 1)

                Circle()
                    .fill(Color.btText.opacity(0.55))
                    .frame(width: 5, height: 5)
                    .position(x: cx, y: cy)

                ForEach(marks) { m in
                    Circle()
                        .fill(m.color)
                        .frame(width: 9, height: 9)
                        .position(x: cx + m.dx, y: cy + m.dy)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(marks) { m in
                        HStack(spacing: 6) {
                            Circle().fill(m.color).frame(width: 8, height: 8)
                            Text(m.label)
                                .font(.btCaption)
                                .foregroundStyle(.btTextSecondary)
                        }
                    }
                    Text("虚线内 = 可靠打点")
                        .font(.btCaption)
                        .foregroundStyle(.btTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .position(x: geo.size.width * 0.72, y: cy)
            }
        }
    }
}

// MARK: - Miscue limit tip diagram (tokenized)

private struct MiscueLimitFigure: View {
    let limitFraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.42, geo.size.height * 0.85)
            let cx = geo.size.width * 0.36
            let cy = geo.size.height * 0.48
            let r = side / 2
            let limitR = r * limitFraction

            ZStack {
                RoundedRectangle(cornerRadius: BTRadius.md)
                    .fill(Color.btTableFelt.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: BTRadius.md)
                            .stroke(Color.btSeparator, lineWidth: 1)
                    )

                Circle()
                    .fill(Color.btBGTertiary)
                    .overlay(Circle().stroke(Color.btSeparator, lineWidth: 1.5))
                    .frame(width: side, height: side)
                    .position(x: cx, y: cy)

                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: limitR * 2, height: limitR * 2)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(Color.btPrimary.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: limitR * 2, height: limitR * 2)
                    .position(x: cx, y: cy)

                Circle()
                    .fill(Color.btText.opacity(0.7))
                    .frame(width: 5, height: 5)
                    .position(x: cx, y: cy)
                Circle()
                    .fill(Color.btSuccess)
                    .frame(width: 8, height: 8)
                    .position(x: cx + limitR * 0.55, y: cy - limitR * 0.35)
                Circle()
                    .fill(Color.btDestructive.opacity(0.85))
                    .frame(width: 8, height: 8)
                    .position(x: cx + r * 0.78, y: cy - r * 0.2)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    legendDot(Color.btPrimary, "可靠打点 ≤ \(String(format: "%.1f", Double(limitFraction)))R")
                    legendDot(Color.btSuccess, "区内：塞可传递")
                    legendDot(Color.btDestructive, "区外：易滑杆")
                }
                .position(x: geo.size.width * 0.78, y: cy)
            }
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
    }
}

// MARK: - Cushion english qualitative figure

private struct CushionEnglishFigure: View {
    var body: some View {
        // Static teaching scene in table meters (X–Z); not engine-sampled.
        let cue = CGPoint(x: -0.35, y: 0.05)
        let impact = CGPoint(x: -0.02, y: 0.42)
        let noSpin = CGPoint(x: 0.38, y: 0.18)
        let running = CGPoint(x: 0.48, y: 0.02)
        let reverse = CGPoint(x: 0.22, y: 0.32)

        BTTableFigure(orientation: .landscape,
                      closeup: (center: CGPoint(x: 0.08, y: 0.22), halfHeight: 0.42)) { proj in
            let c = proj.point(x: cue.x, z: cue.y)
            let hit = proj.point(x: impact.x, z: impact.y)
            let a0 = proj.point(x: noSpin.x, z: noSpin.y)
            let aRun = proj.point(x: running.x, z: running.y)
            let aRev = proj.point(x: reverse.x, z: reverse.y)
            let d = proj.ballDiameter

            ZStack {
                // Top cushion hint (screen-up = −Z → smaller screen-y near top of closeup).
                Path { p in
                    let y = proj.point(x: 0, z: 0.55).y
                    p.move(to: CGPoint(x: 8, y: y))
                    p.addLine(to: CGPoint(x: proj.size.width - 8, y: y))
                }
                .stroke(Color.btTextTertiary.opacity(0.5), lineWidth: 3)

                Path { p in p.move(to: c); p.addLine(to: hit) }
                    .stroke(FigureLine.aim.opacity(0.55), lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: hit); p.addLine(to: a0) }
                    .stroke(FigureLine.separation,
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))
                Path { p in p.move(to: hit); p.addLine(to: aRun) }
                    .stroke(Color.btAccent, lineWidth: proj.lineMainWidth)
                Path { p in p.move(to: hit); p.addLine(to: aRev) }
                    .stroke(Color.btWarning, lineWidth: proj.lineMainWidth)

                BTFigureBall(diameter: d).position(c)
                BTContactDot(diameter: max(4, d * 0.22)).position(hit)

                BTFigureTag(text: "入射", color: FigureLine.aim)
                    .position(spinAlongLabel(from: c, to: hit, t: 0.45, offset: -14))
                BTFigureTag(text: "无塞", color: FigureLine.separation)
                    .position(spinAlongLabel(from: hit, to: a0, t: 0.7, offset: 14))
                BTFigureTag(text: "顺塞更开", color: .btAccent)
                    .position(spinAlongLabel(from: hit, to: aRun, t: 0.75, offset: -14))
                BTFigureTag(text: "逆塞更闭", color: .btWarning)
                    .position(spinAlongLabel(from: hit, to: aRev, t: 0.7, offset: 14))
            }
        }
    }
}

// MARK: - Label helper

private func spinAlongLabel(from a: CGPoint, to b: CGPoint,
                            t: CGFloat, offset: CGFloat) -> CGPoint {
    let pt = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    let dx = b.x - a.x, dy = b.y - a.y
    let len = max(sqrt(dx * dx + dy * dy), 0.001)
    return CGPoint(x: pt.x - dy / len * offset, y: pt.y + dx / len * offset)
}

#Preview("Light") {
    NavigationStack { SpinAndEnglishView() }
}

#Preview("Dark") {
    NavigationStack { SpinAndEnglishView() }
        .preferredColorScheme(.dark)
}
