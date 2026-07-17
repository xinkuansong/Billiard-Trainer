import SwiftUI

/// 旋转与加塞（问题集合 v11 Y2，边界 v11.3）：母球旋转状态 → 分离角联动为主轴；
/// 最小加塞（T09）+ 打滑极限（`CuePhysics.miscueLimitFraction`）；投掷/加塞三件套
/// 只留一句话概念，文案预告后续「瞄准修正」（v12，本轮不做 NavigationLink）。
/// 几何真源 `SpinAndEnglishGeometry` + 数值草稿 `build/y2-evidence/`。
struct SpinAndEnglishView: View {
    @State private var selectedSpin: SpinAndEnglishGeometry.SpinState = .stun

    private var miscueLimit: Float { CuePhysics.miscueLimitFraction }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                introSection
                linkageSection
                statesSection
                minimumEnglishSection
                aimingCorrectionTeaser
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("接触瞬间的旋转决定分离角")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("出杆后母球先滑动，再过渡到滚动。真正决定碰后母球走向的，不是你打了高杆还是低杆本身，而是碰到目标球那一瞬间母球处于哪种旋转状态。同一杆几何、不同接触旋转，会走出截然不同的分离角。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Text("本页主轴：旋转状态 → 分离角。加塞对瞄准的细修正见后续「瞄准修正」页（尚未上线）。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Main axis: spin → separation

    private var linkageSection: some View {
        let scene = SpinAndEnglishGeometry.scene()
        let sep = SpinAndEnglishGeometry.separationDegrees(scene: scene, state: selectedSpin)
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("三种旋转 → 三条分离角走向")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("下图同一杆（半球切角）：目标球沿进球线离开；母球碰后先沿切线出发，再按接触时的旋转前弯或后弯。点选状态可高亮对应轨迹。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Picker("旋转状态", selection: $selectedSpin) {
                ForEach(SpinAndEnglishGeometry.SpinState.allCases) { state in
                    Text(state.pickerTitle).tag(state)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("spinAndEnglish.spinPicker")

            SeparationPathsFigure(selected: selectedSpin)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                .accessibilityIdentifier("spinAndEnglish.figure")

            HStack(spacing: Spacing.sm) {
                Text(selectedSpin.pathLabel)
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btPrimary)
                Spacer()
                Text(String(format: "示意分离角 ≈ %.0f°", sep))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(Spacing.md)
            .background(Color.btPrimaryMuted)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("滑动（stun / 定杆）：接触时几乎无前旋后旋，母球沿切线离开，与进球线夹角约 90°（90° 法则 / 切线法则）。")
                Text("前旋（高杆 / 自然滚动）：接触时已有前旋或已自然滚动，母球从切线向前弯回瞄准线一侧——常用口诀是约 30° 偏离原瞄准线（30° 法则）。")
                Text("后旋（低杆）：接触时后旋仍在，母球从切线向后弯，分离角大于 90°。")
            }
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)

            Text("示意角度按半球教学球形锁定（见数值草稿）；实战随切角、力度与滑动→滚动进度连续变化。App 内分离角辅助线的经验修正约为 90°±20°（高杆减小、低杆增大），仅作提示，不参与物理求解。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Spin states glossary

    private var statesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("母球旋转状态")
                .font(.btTitle)
                .foregroundStyle(.btText)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                stateRow("滑动", "stun：纯平移、几乎无前后旋。中杆、较短距离、偏快力度时常见。")
                stateRow("自然滚动", "滑动被台呢摩擦「吃掉」后的稳态：线速度与自转匹配，既前进又前旋。")
                stateRow("前旋", "高杆或已自然滚动：碰后向前弯（跟进走位）。")
                stateRow("后旋", "低杆：碰后向后弯（缩杆走位）。后旋也会被摩擦逐渐吃掉。")
            }

            Text("出杆后常见过程：滑动 →（可选）仍带后旋或已前旋 → 最终自然滚动。距离越长、力度越小，越容易在碰到目标球之前进入滚动；短距大力则更常以滑动状态接触。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            Text("切角、假想球与瞄准点本身见「瞄准原理」；本页不重复瞄准几何。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
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

    // MARK: - Minimum English + miscue

    private var minimumEnglishSection: some View {
        let pct = Int((miscueLimit * 100).rounded())
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("最小加塞与打滑极限")
                .font(.btTitle)
                .foregroundStyle(.btText)

            MiscueLimitFigure(limitFraction: CGFloat(miscueLimit))
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("能用中杆 + 高低杆（配合切线 / 30° / 90° 法则）完成的走位，尽量不要加左右塞——这就是最小加塞原则：每多一分塞，就多一分瞄准误差来源。")
                Text(String(
                    format: "打点偏离球心的可靠上限是母球半径的 %.0f%%（皮头打滑极限）。超过约 %.1fR，皮头容易打滑（滑杆），塞不再稳定传递。App 打点盘把可拖区域钳在这一比例内，与引擎常量一致。",
                    Float(pct), miscueLimit
                ))
            }
            .font(.btBody)
            .foregroundStyle(.btTextSecondary)

            Text("打滑极限数值 = CuePhysics.miscueLimitFraction（当前 \(String(format: "%.1f", miscueLimit))）。")
                .font(.btCaption)
                .foregroundStyle(.btTextTertiary)
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Teaser only (no NavigationLink to v12)

    private var aimingCorrectionTeaser: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("加塞还会改变瞄准")
                .font(.btTitle)
                .foregroundStyle(.btText)

            Text("左右塞还会带来挤偏（squirt）、弧线（swerve）与投掷（throw）等效应，使实际进球线相对几何瞄准产生偏差。")
                .font(.btBody)
                .foregroundStyle(.btTextSecondary)

            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "bookmark")
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btAccent)
                Text("详见后续学页「瞄准修正」（投掷 / 挤偏 / 弧线及其对瞄准的影响）。该页尚未上线，落地后将在此补跳转。")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
            }
            .padding(Spacing.md)
            .background(Color.btAccent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            .accessibilityIdentifier("spinAndEnglish.aimingCorrectionTeaser")
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    // MARK: - Cross refs

    private var crossRefsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("相关页面")
                .font(.btTitle)
                .foregroundStyle(.btText)

            PracticeCTA(title: "回看瞄准原理",
                        destination: "切角 · 假想球 · 接触点",
                        route: .aimingPrinciple)

            PracticeCTA(title: "打开瞄准方法",
                        destination: "管道 · 接触点 · 平行线",
                        route: .aimingMethods)

            PracticeCTA(title: "打开分离角图谱",
                        destination: "8 档高低杆 · 碰后轨迹对比",
                        route: .separationAngleAtlas)
        }
    }
}

// MARK: - Separation paths figure

private struct SeparationPathsFigure: View {
    let selected: SpinAndEnglishGeometry.SpinState

    var body: some View {
        let scene = SpinAndEnglishGeometry.scene()
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
                // Aim line (context) — dim.
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim.opacity(0.35), lineWidth: proj.lineHintWidth)

                // Object ball departure.
                Path { p in p.move(to: target); p.addLine(to: potFar) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 3]))

                ForEach(SpinAndEnglishGeometry.SpinState.allCases) { state in
                    let endW = SpinAndEnglishGeometry.pathEnd(scene: scene, state: state)
                    let end = proj.point(x: endW.x, z: endW.y)
                    let active = state == selected
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

// MARK: - Miscue limit tip diagram (face-on cue ball)

private struct MiscueLimitFigure: View {
    let limitFraction: CGFloat

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * 0.42, geo.size.height * 0.85)
            let cx = geo.size.width * 0.38
            let cy = geo.size.height * 0.48
            let r = side / 2
            let limitR = r * limitFraction

            ZStack {
                Circle()
                    .fill(Color.btBGTertiary)
                    .frame(width: side, height: side)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(Color.btSeparator, lineWidth: 1)
                    .frame(width: side, height: side)
                    .position(x: cx, y: cy)

                // Safe zone (miscue disk).
                Circle()
                    .stroke(Color.btPrimary.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: limitR * 2, height: limitR * 2)
                    .position(x: cx, y: cy)
                Circle()
                    .fill(Color.btPrimary.opacity(0.12))
                    .frame(width: limitR * 2, height: limitR * 2)
                    .position(x: cx, y: cy)

                // Center + sample tip points.
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
        .background(Color.btBG.opacity(0.35))
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
