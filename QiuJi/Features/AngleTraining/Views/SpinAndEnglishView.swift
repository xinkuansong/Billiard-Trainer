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

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                LearnControlStrip.Theta(
                    cutAngleDeg: $cutAngleDeg,
                    caption: "拖动切角改变球形，再选择旋转状态比较方向。三条线是示意，不随切角计算精确分离角；默认球形为 30° 半球。",
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
            .learnDocumentWidth()
        }
        .background(.btBG)
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .learnReadingNavigation(title: "旋转与加塞")
    }

    // MARK: - Intro

    private var introSection: some View {
        LearnDocSectionCard(title: "看打点，也要看碰球时的旋转") {
            LearnDocText.body("打了低杆，母球碰后却没有拉回来，并不一定是打点选错了。后旋可能在到达目标球之前已经消失。判断碰后走向，要把打点、力度和球距联系起来，看看母球碰球时还带着怎样的旋转。")

            LearnDocText.footnote("先比较前后旋怎样影响碰后路线，再看左右塞怎样影响吃库。加塞带来的瞄准变化，另见「瞄准修正」。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.intro")
    }

    // MARK: - Main axis: spin → separation

    private var linkageSection: some View {
        let scene = SpinAndEnglishGeometry.scene(cutAngleDeg: CGFloat(cutAngleDeg))
        let sep = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: selectedSpin)
        return LearnDocSectionCard(title: "从切线看前旋与后旋") {
            LearnDocText.body("先把目标球离开方向当作参照，与它垂直的方向就是切线。忽略球间摩擦时，切球后的母球最初沿切线出发，随后前旋或后旋通过台呢摩擦改变路线。图中用三条直线概括最终偏向哪边；点选状态可以高亮对应线。")

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
                Text(String(format: "示意角 ≈ %.0f°", sep))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.btText)
            }
            .padding(Spacing.md)
            .background(Color.btPrimaryMuted)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .accessibilityIdentifier("spinAndEnglish.sepReadout")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("斯登（Stun）：碰球时几乎没有前旋和后旋。切球后母球大致沿切线走，与目标球离开方向约成 90°，这就是切线法则。正球打成这种状态时，母球才会留在碰撞附近，也就是定杆。")
                LearnDocText.body("前旋：碰球后，母球路线逐渐向前偏离切线。自然滚动是前旋的一种特定状态；切角约在 14°–49° 时，最终路线相对原入射方向大约偏转 30°。这是方便估计的 30° 法则，不能套在所有高杆球上。")
                LearnDocText.body("后旋：碰球时若还保留后旋，母球路线会逐渐向切线后方偏。在这类理想切球中，最终路线与目标球方向的夹角大于 90°；具体能拉回多少，取决于剩余后旋、速度和切角。")
            }

            LearnDocText.footnote("图中相对进球线固定画出 90°、60°、120°，只帮助辨认切线、前偏和后偏，不表示真实轨迹会沿直线立即转向。上面的 30° 法则则以原入射方向为基准，两种角度不要混用。要比较不同打点的模拟轨迹，可打开「分离角图谱」。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.linkage")
    }

    // MARK: - Spin states glossary

    private var statesSection: some View {
        LearnDocSectionCard(title: "母球旋转状态") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                stateRow("斯登", "母球仍在前进，但几乎没有前后旋。这是滑动的一种特殊状态，不能把所有滑动都叫斯登。")
                stateRow("自然滚动", "前进速度与向前滚动的转速匹配：v = Rω。球与台呢的接触处没有相对滑动。")
                stateRow("前旋", "球向前转，但转速未必与行进速度匹配；有前旋，不一定已经自然滚动。")
                stateRow("后旋", "球向前走，却向后转。台呢摩擦会逐渐消耗后旋，碰球时是否还剩下后旋很关键。")
            }

            LearnDocText.body("以低杆为例，母球可能先带后旋向前滑行，随后后旋减到接近零，再逐渐获得前旋，最后进入自然滚动。碰球可能发生在这段过程中的任何时刻。同样的打点，换了球距或力度，碰球时的状态就可能不同；高杆也可以很快进入自然滚动，不必先经历无旋阶段。")

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
                .foregroundStyle(.btText)
        }
    }

    // MARK: - Tip contact → spin

    private var tipContactSection: some View {
        LearnDocSectionCard(title: "打点如何产生旋转") {
            LearnDocText.body("从出杆方向看，皮头打在球心上方或下方，会产生不同的前后旋；打在左侧或右侧，则会加入侧旋，也就是左右塞。上下与左右打点可以组合，但偏离球心越多，越需要控制好出杆。")

            TipContactFigure(limitFraction: CGFloat(miscueLimit))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.tipFigure")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("高杆和低杆先改变的是母球出发时的旋转。能有多少旋转保留到碰球，要结合力度和路程判断，再据此预计碰后路线。")
                LearnDocText.body("左右塞常用来调整吃库后的路线，但它的影响从出杆时就开始了。即使母球还没碰到库，也可能需要考虑挤偏、弧线和球间投掷。")
            }

            LearnDocText.footnote("图中虚线圈半径约为球半径的 \(String(format: "%.0f", miscueLimit * 100))%，与 App 可选打点范围一致。它是练习时的范围参照，圈内也仍需良好的皮头、巧粉和出杆。")
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
                LearnDocText.body("先用厚薄、力度和高低杆安排路线；如果已经能到合适的位置，就不必额外加左右塞。确实需要改变吃库路线时，再用能完成目的的塞量。这样更容易分清失误来自瞄准、力度，还是加塞后的补偿。")
                LearnDocText.body(String(
                    format: "打点越靠近球边，越容易滑杆。App 将可选打点限制在球半径的 %.0f%%，即约 %.1fR 范围内。这个距离按上下和左右的合成偏移计算：已经打得很高或很低时，就不能再横向加同样多的塞。",
                    Float(pct), miscueLimit
                ))
            }

            LearnDocText.footnote("真实的滑杆边界还受皮头、巧粉和击球条件影响。练习从较小偏移开始，不要把图中的边界当作每杆都要打到的位置。")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinAndEnglish.minimumEnglish")
    }

    // MARK: - Cushion × sidespin (qualitative)

    private var cushionEnglishSection: some View {
        LearnDocSectionCard(title: "左右塞与吃库反弹") {
            LearnDocText.body("碰库时，母球的侧旋会通过与库边的摩擦改变反弹方向。「入射角约等于反射角」可以作为最初的镜面参照，但真实库边并不是镜子；即使没有左右塞，速度、前后旋和库边条件也会让结果偏离这个参照。")

            CushionEnglishFigure()
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.cushionFigure")

            VStack(alignment: .leading, spacing: Spacing.md) {
                LearnDocText.body("顺塞（Running）：在当前这次吃库中，侧旋有助于母球继续沿库边的行进方向走。与相近条件下的无塞球比较，反弹通常更开，也就是更偏离库边法线。")
                LearnDocText.body("逆塞（Reverse）：侧旋与这次沿库行进的方向相反，反弹通常更收，靠近库边法线；塞量足够大时，还可能改变沿库方向。")
                LearnDocText.body("左塞不固定等于顺塞，右塞也不固定等于逆塞，要看母球碰哪条库、从哪边来。先比较同一入射路线下的变化，再把它用到需要改变吃库方向的走位中。")
            }

            LearnDocText.footnote("这幅图只比较反弹变开、变收的方向，不给出实测角度。想进一步比较不同塞量，可以打开「加塞吃库图谱」查看对应模拟轨迹。")

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
            LearnDocText.body("加塞后，母球可能不沿杆指向直走，目标球也可能因碰撞摩擦偏离理想离开方向。因此先确定要用什么打法，再核对瞄准，比先瞄好、临出杆才决定加塞更容易保持一致。")

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
                        destination: "直球近台 · 比较带塞后的瞄准变化",
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
                    .stroke(FigureLine.hint, lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                ForEach(SpinAndEnglishGeometry.SpinState.allCases) { state in
                    let endW = SpinAndEnglishGeometry.pathEnd(scene: scene, state: state)
                    let end = proj.point(x: endW.x, z: endW.y)
                    let active = emphasizeAll || state == selected
                    let color = pathColor(state)
                    Path { p in p.move(to: ghost); p.addLine(to: end) }
                        .stroke(color.opacity(active ? 1 : 0.85),
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
                BTFigureTag(text: "假想球", color: FigureLine.ghost)
                    .position(x: ghost.x - d * 0.9, y: ghost.y + d / 2 + 12)
            }
        }
    }

    private func pathColor(_ state: SpinAndEnglishGeometry.SpinState) -> Color {
        switch state {
        case .stun:   return FigureLine.separation
        case .follow: return FigureLine.follow
        case .draw:   return FigureLine.effect
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
                .init(id: "high", dx: 0, dy: -limitR * 0.72, label: "高杆 → 前旋", color: .btPhysicsAdjustable),
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
                                .foregroundStyle(.btText)
                        }
                    }
                    Text("虚线内：建议打点范围")
                        .font(.btCaption)
                        .foregroundStyle(.btText)
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
                    legendDot(Color.btPrimary, "打点范围 ≤ \(String(format: "%.1f", Double(limitFraction)))R")
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
                .foregroundStyle(.btText)
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
                .stroke(FigureLine.hint, lineWidth: 3)

                Path { p in p.move(to: c); p.addLine(to: hit) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineHintWidth)

                Path { p in p.move(to: hit); p.addLine(to: a0) }
                    .stroke(FigureLine.separation,
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))
                Path { p in p.move(to: hit); p.addLine(to: aRun) }
                    .stroke(FigureLine.guide, lineWidth: proj.lineMainWidth)
                Path { p in p.move(to: hit); p.addLine(to: aRev) }
                    .stroke(FigureLine.effect, lineWidth: proj.lineMainWidth)

                BTFigureBall(diameter: d).position(c)
                BTContactDot(diameter: max(4, d * 0.22)).position(hit)

                BTFigureTag(text: "入射", color: FigureLine.aim)
                    .position(spinAlongLabel(from: c, to: hit, t: 0.45, offset: -14))
                BTFigureTag(text: "无塞", color: FigureLine.separation)
                    .position(spinAlongLabel(from: hit, to: a0, t: 0.7, offset: 14))
                BTFigureTag(text: "顺塞更开", color: FigureLine.guide)
                    .position(spinAlongLabel(from: hit, to: aRun, t: 0.75, offset: -14))
                BTFigureTag(text: "逆塞更闭", color: FigureLine.effect)
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
