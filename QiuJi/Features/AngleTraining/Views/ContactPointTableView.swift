import SwiftUI

struct ContactPointTableView: View {
    @State private var sliderAngle: Double = 30
    /// 估角演示：母球沿真实瞄准线到假想球的距离（米）。
    @State private var estimationDistance: Double = 0.55

    // 设计决策（P9-05 APPROVED）：移除球种切换，固定中八球径 R=28.575mm。
    private let ballRadiusMM: Double = 28.575

    private struct AngleEntry: Identifiable {
        let id: Int
        let angle: Double
        let commonName: String?
    }

    /// 19×5° + classic 「3/4 球」14.5°（`AngleSceneCalculator.threeQuarterBall` 真源）.
    private let standardAngles: [AngleEntry] = {
        let tqb = AngleSceneCalculator.threeQuarterBall
        return [
            AngleEntry(id: 0, angle: 0, commonName: AngleSceneCalculator.fullBall.name),
            AngleEntry(id: 1, angle: 5, commonName: nil),
            AngleEntry(id: 2, angle: 10, commonName: nil),
            AngleEntry(id: 3, angle: tqb.cutAngleDegrees, commonName: tqb.name),
            AngleEntry(id: 4, angle: 15, commonName: nil),
            AngleEntry(id: 5, angle: 20, commonName: nil),
            AngleEntry(id: 6, angle: 25, commonName: nil),
            AngleEntry(id: 7, angle: 30, commonName: AngleSceneCalculator.halfBall.name),
            AngleEntry(id: 8, angle: 35, commonName: nil),
            AngleEntry(id: 9, angle: 40, commonName: nil),
            AngleEntry(id: 10, angle: 45, commonName: nil),
            AngleEntry(id: 11, angle: 50, commonName: nil),
            AngleEntry(id: 12, angle: 55, commonName: nil),
            AngleEntry(id: 13, angle: 60, commonName: nil),
            AngleEntry(id: 14, angle: 65, commonName: nil),
            AngleEntry(id: 15, angle: 70, commonName: nil),
            AngleEntry(id: 16, angle: 75, commonName: nil),
            AngleEntry(id: 17, angle: 80, commonName: nil),
            AngleEntry(id: 18, angle: 85, commonName: nil),
            AngleEntry(id: 19, angle: 90, commonName: AngleSceneCalculator.thinBall.name),
        ]
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                interactiveSection
                LearnControlStrip.Theta(
                    cutAngleDeg: $sliderAngle,
                    range: 0...90,
                    caption: "对照表范围 0°–90°（全厚→最薄）。",
                    accessibilityIdentifier: "contactPointTable.thetaSlider"
                )
                principleSection
                estimationSection
                staticTable
                sineCurveSection
            }
            .padding(Spacing.lg)
        }
        .background(.btBG)
        .navigationTitle("瞄准点对照表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Interactive slider + ball

    private var interactiveSection: some View {
        LearnDocSectionCard(title: "拖动查看瞄准点与接触点", titleLevel: .subsection) {
            // P3.1（问题集合 v3）：卡片加高 220→260，配合图内几何调整（目标球下移、
            // 进球线延伸缩短），拖动全程「袋口方向」标签不再超出卡片。
            aimFigure
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                LearnControlStrip.ReadoutRow(
                    label: "偏移",
                    value: String(format: "%.0f%%", sin(sliderAngle * .pi / 180) * 100),
                    labelEmphasis: .secondary,
                    valueSize: 14
                )
                LearnControlStrip.ReadoutRow(
                    label: "d/R",
                    value: String(format: "%.2f", 2.0 * sin(sliderAngle * .pi / 180)),
                    labelEmphasis: .secondary,
                    valueSize: 14
                )
                if let name = commonName(for: sliderAngle) {
                    Text(name)
                        .font(.btCaption)
                        .foregroundStyle(.btPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.btPrimaryMuted)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func commonName(for angle: Double) -> String? {
        standardAngles.first(where: { abs($0.angle - angle) < 0.5 })?.commonName
    }

    // MARK: - 俯视真台交互图（T-P18-46 重设计）

    /// 俯视图真台渲染：以**母球方向为竖直基准**（瞄准线白实线），拖滑条时进球方向
    /// 转 α、假想球绕目标球转动。G1 口径：瞄准点（红点）= 瞄准线与「过目标球心且
    /// 垂直于瞄准线的直线」（水平白虚线）的交点，到球心的距离 = d = 2R·sin(θ)。
    private var aimFigure: some View {
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        return BTTableFigure(orientation: .landscape,
                             closeup: (center: .zero, halfHeight: r * 5.0)) { proj in
            let d = proj.ballDiameter
            let rad = sliderAngle * .pi / 180
            // P3.1 数值核验（h=260, d≈52）：target.y=0.44h、进球线延伸 1.6d 时，
            // 0° 处 potEnd.y≈31、标签 y≈19 仍在框内（旧 0.40h/2.4d 时 0° 溢出到 −46）。
            let target = CGPoint(x: proj.size.width / 2, y: proj.size.height * 0.44)
            // 进球方向与竖直瞄准方向夹 α（向右转）；假想球 = 目标球心 − 2R×进球方向。
            let potDir = CGPoint(x: sin(rad), y: -cos(rad))
            let ghost = CGPoint(x: target.x - d * potDir.x, y: target.y - d * potDir.y)
            let contact = CGPoint(x: (target.x + ghost.x) / 2, y: (target.y + ghost.y) / 2)
            let potEnd = CGPoint(x: target.x + potDir.x * d * 1.6,
                                 y: target.y + potDir.y * d * 1.6)
            // G1 瞄准点：竖直瞄准线与过目标球心水平线的交点（垂足）。
            let aimPoint = CGPoint(x: ghost.x, y: target.y)

            ZStack {
                // 进球线（目标球 → 袋口方向）：绑球色虚线（线语言 v2）。
                Path { p in p.move(to: target); p.addLine(to: potEnd) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))

                // G1 垂线：过目标球心、垂直于瞄准线（水平白细虚线）。
                Path { p in
                    p.move(to: CGPoint(x: target.x - d * 2.0, y: target.y))
                    p.addLine(to: CGPoint(x: target.x + d * 2.0, y: target.y))
                }
                .stroke(FigureLine.hint.opacity(0.7),
                        style: StrokeStyle(lineWidth: proj.lineHintWidth, dash: [5, 4]))

                // 瞄准线（母球方向，竖直白实线，延伸过垂线交点 = 瞄准点）。
                Path { p in
                    p.move(to: CGPoint(x: ghost.x, y: proj.size.height - 8))
                    p.addLine(to: CGPoint(x: ghost.x, y: target.y - d * 0.4))
                }
                .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)

                // 偏移量 d 标尺（金 = 量值）：目标球心 → 瞄准点（G1：d 就在垂线上）。
                if sliderAngle > 3 {
                    Path { p in
                        p.move(to: target)
                        p.addLine(to: aimPoint)
                    }
                    .stroke(Color.btTeachingGuide, lineWidth: 2.0)
                }

                BTGhostCircle(diameter: d, showsAimPoint: false).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                // 接触点浮于球面之上（否则被目标球盖住）。
                BTContactDot(diameter: max(4, d * 0.22)).position(contact)
                // G1 瞄准点（红点）：在垂线与瞄准线的交点处。
                BTAimPointDot(diameter: max(4, d * 0.14)).position(aimPoint)

                BTFigureTag(text: "袋口方向", color: FigureLine.pot(number: 1))
                    .position(x: potEnd.x, y: potEnd.y - 12)
                // G1：瞄准点 = 垂足（红），接触点 = 两球相切处（绿）。
                // Q3（问题集合 v5 V4）：瞄准点标签放瞄准点「左上」、接触点标签放接触点
                // 「右侧」（沿两球连线的右法向 (cos,sin) 外移）。避让为全角度域（0–90°）
                // 数值核验，非单帧调偏移：瞄准点标签框与 1 号球/假想球圆区最小间隙
                // 4.2pt@0°、接触点 6.4pt@8°，均 >0。关键最坏帧 = 90° 时假想球心与瞄准点
                // 重合，标签「左上」偏移用空的上半区避让，不压假想球。
                BTFigureTag(text: "瞄准点", color: FigureLine.aimPoint)
                    .position(x: aimPoint.x - d * 0.95, y: aimPoint.y - d * 0.40)
                BTFigureTag(text: "接触点", color: FigureLine.contact)
                    .position(x: contact.x + CGFloat(cos(rad)) * d * 0.95,
                              y: contact.y + CGFloat(sin(rad)) * d * 0.95)
            }
            .animation(BTMotion.easeInstant, value: sliderAngle)
        }
    }

    // MARK: - Principle

    private var principleSection: some View {
        LearnDocSectionCard(title: "原理说明", titleLevel: .subsection) {
            Text("d = 2R × sin(θ)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.btPrimary)
            LearnDocText.body("d 为偏移量：瞄准点（瞄准线与过目标球心垂线的交点，红点）到目标球心的距离，也等于假想球心的横移量。θ 为切角，R 为球半径。")
            LearnDocText.footnote("d/R = 2sin(θ) 为无量纲比，表中「d(mm)」按中八球径 57.15mm 计算。")
        }
    }

    // MARK: - 中心连线估角与距离误差（条 4.5）

    /// 实战中看不见假想球，常用「母球–目标球中心连线」代替真实瞄准线来估角。
    /// 本节交互演示：两线夹角 Δ 随母球距离增大而变小 → 远台估角更可靠。
    private var estimationSection: some View {
        LearnDocSectionCard(title: "实战估角：中心连线法", titleLevel: .subsection) {
            LearnDocText.body("台面上并不存在假想球，真实瞄准线（白）也就无从直接看见。实战里常用的替代方法：把母球与目标球球心连线（金色虚线）当作近似瞄准线来估计切角 θ。")

            estimationFigure
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            LearnControlStrip.ReadoutRow(
                label: "估角误差 Δ",
                value: String(format: "%.1f°", estimationErrorDegrees),
                labelEmphasis: .primary,
                valueSize: 16
            )
            LearnDocText.footnote("两线夹角 = 用中心连线估角时引入的角度误差")

            LearnControlStrip.ReadoutRow(
                label: "母球距（近↔远）",
                value: String(format: "%.2f m", estimationDistance),
                labelEmphasis: .secondary,
                valueSize: 14
            )
            Slider(value: $estimationDistance, in: 0.30...1.60)
                .tint(.btPrimary)
                .accessibilityIdentifier("contactPointTable.estimationSlider")

            LearnDocText.body("两线在目标球附近相差固定的一段横移量（≤2R），距离越远，同样的横移量对应的夹角越小。因此远台用中心连线估角误差很小；近台两线夹角明显，需要有意识地把估出的角度再修正一点。")
        }
    }

    /// 演示用固定布局：θ=30° 切球，滑条改变母球沿真实瞄准线的距离。
    private var estimationLayout: (cue: CGPoint, target: CGPoint, ghost: CGPoint,
                                   potDir: CGPoint, pocket: CGPoint) {
        let r = Double(AngleSceneCalculator.ballRadius)
        let target = CGPoint(x: 0.75, y: -0.25)
        // pocket index 1 视觉标记位；landscape 屏幕「右上角袋」（本图横版，DR-063）。
        let pocketW3 = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)[1]
        let corner = CGPoint(x: CGFloat(pocketW3.x), y: CGFloat(pocketW3.z))
        let pv = CGPoint(x: corner.x - target.x, y: corner.y - target.y)
        let pLen = hypot(pv.x, pv.y)
        let potDir = CGPoint(x: pv.x / pLen, y: pv.y / pLen)
        let ghost = CGPoint(x: target.x - 2 * r * potDir.x, y: target.y - 2 * r * potDir.y)
        let a: Double = 30.0 * .pi / 180
        let cosA: Double = cos(a)
        let sinA: Double = sin(a)
        let aimX: Double = Double(potDir.x) * cosA - Double(potDir.y) * sinA
        let aimY: Double = Double(potDir.x) * sinA + Double(potDir.y) * cosA
        let cueX: Double = Double(ghost.x) - aimX * estimationDistance
        let cueY: Double = Double(ghost.y) - aimY * estimationDistance
        let cue = CGPoint(x: cueX, y: cueY)
        return (cue, target, ghost, potDir, corner)
    }

    private var estimationErrorDegrees: Double {
        let l = estimationLayout
        let v1 = CGPoint(x: l.ghost.x - l.cue.x, y: l.ghost.y - l.cue.y)
        let v2 = CGPoint(x: l.target.x - l.cue.x, y: l.target.y - l.cue.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard mag > 0 else { return 0 }
        return acos(min(max(dot / mag, -1), 1)) * 180 / .pi
    }

    private var estimationFigure: some View {
        BTTableFigure(orientation: .landscape) { proj in
            let l = estimationLayout
            let cue = proj.point(x: l.cue.x, z: l.cue.y)
            let target = proj.point(x: l.target.x, z: l.target.y)
            let ghost = proj.point(x: l.ghost.x, z: l.ghost.y)
            let pocket = proj.point(x: l.pocket.x, z: l.pocket.y)
            let d = proj.ballDiameter

            ZStack {
                // P3.2（问题集合 v3）：进球线（目标球 → 袋口，绑球色虚线）一并画出，
                // 读者能看到估角针对的是哪一杆球。
                Path { p in p.move(to: target); p.addLine(to: pocket) }
                    .stroke(FigureLine.pot(number: 1),
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4]))
                // 真实瞄准线：母球 → 假想球心（白实线）。
                Path { p in p.move(to: cue); p.addLine(to: ghost) }
                    .stroke(FigureLine.aim, lineWidth: proj.lineMainWidth)
                // 中心连线估角线：母球 → 目标球心（金虚线）。
                Path { p in p.move(to: cue); p.addLine(to: target) }
                    .stroke(Color.btTeachingGuide,
                            style: StrokeStyle(lineWidth: proj.lineMainWidth, dash: [5, 4]))

                BTGhostCircle(diameter: d).position(ghost)
                BTFigureBall(number: 1, diameter: d).position(target)
                BTFigureBall(diameter: d).position(cue)

                BTFigureTag(text: "真实瞄准线")
                    .position(x: (cue.x + ghost.x) / 2, y: (cue.y + ghost.y) / 2 - 14)
                BTFigureTag(text: "中心连线", color: .btTeachingGuide)
                    .position(x: (cue.x + target.x) / 2, y: (cue.y + target.y) / 2 + 14)
                BTFigureTag(text: "进球线", color: FigureLine.pot(number: 1))
                    .position(x: (target.x + pocket.x) / 2 + 10,
                              y: (target.y + pocket.y) / 2 + 14)
            }
            .animation(BTMotion.easeInstant, value: estimationDistance)
        }
    }

    // MARK: - Static table (expanded)

    private var staticTable: some View {
        LearnDocSectionCard(title: "对照表", titleLevel: .subsection) {
            VStack(spacing: 0) {
                headerRow
                ForEach(standardAngles) { entry in
                    tableRow(entry: entry)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("切角").font(.btCaption2).frame(width: 44, alignment: .leading)
            Text("sin(θ)").font(.btCaption2).frame(width: 44)
            Text("d/R").font(.btCaption2).frame(width: 36)
            Text("偏移%").font(.btCaption2).frame(width: 40)
            Text("d(mm)").font(.btCaption2).frame(width: 44)
            Spacer()
            Text("通称").font(.btCaption2).frame(width: 56, alignment: .trailing)
        }
        .foregroundStyle(.btTextSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(.btBGTertiary)
    }

    private func tableRow(entry: AngleEntry) -> some View {
        let sinA = sin(entry.angle * .pi / 180)
        let dOverR = 2.0 * sinA
        let dMM = dOverR * ballRadiusMM
        let highlighted = entry.commonName != nil
        let angleText: String = {
            let a = entry.angle
            if abs(a - a.rounded()) > 0.01 {
                return String(format: "%.1f°", a)
            }
            return "\(Int(a))°"
        }()

        return HStack(spacing: 0) {
            Text(angleText)
                .font(highlighted ? .btBodyMedium : .btBody)
                .frame(width: 44, alignment: .leading)
            Text(String(format: "%.3f", sinA))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44)
            Text(String(format: "%.2f", dOverR))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.btPrimary)
                .frame(width: 36)
            Text(String(format: "%.0f%%", sinA * 100))
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 40)
            Text(String(format: "%.1f", dMM))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44)
            Spacer()
            if let name = entry.commonName {
                Text(name)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                    .fontWeight(.bold)
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("—")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .foregroundStyle(.btText)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(highlighted ? Color.btPrimaryMuted : .btBGSecondary)
    }

    // MARK: - Sine Curve Section

    private var sineCurveSection: some View {
        LearnDocSectionCard(title: "d/R = 2sin(θ) 曲线", titleLevel: .subsection) {
            sineCurveCanvas
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private var sineCurveCanvas: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let padding = EdgeInsets(top: 20, leading: 40, bottom: 30, trailing: 20)
            let plotW = w - padding.leading - padding.trailing
            let plotH = h - padding.top - padding.bottom

            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.btBG))

            // Grid lines
            let yTicks: [Double] = [0, 0.5, 1.0, 1.5, 2.0]
            for yVal in yTicks {
                let y = padding.top + plotH * (1 - yVal / 2.0)
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: padding.leading, y: y))
                gridLine.addLine(to: CGPoint(x: w - padding.trailing, y: y))
                context.stroke(gridLine, with: .color(.btSeparator),
                              style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                context.draw(
                    Text(String(format: yVal == 0 || yVal == 1 || yVal == 2 ? "%.0f" : "%.1f", yVal))
                        .font(.system(size: 10))
                        .foregroundColor(.btTextTertiary),
                    at: CGPoint(x: padding.leading - 14, y: y)
                )
            }

            let xTicks: [Int] = [0, 15, 30, 45, 60, 75, 90]
            for xVal in xTicks {
                let x = padding.leading + plotW * Double(xVal) / 90.0
                var gridLine = Path()
                gridLine.move(to: CGPoint(x: x, y: padding.top))
                gridLine.addLine(to: CGPoint(x: x, y: h - padding.bottom))
                context.stroke(gridLine, with: .color(.btSeparator),
                              style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                context.draw(
                    Text("\(xVal)°").font(.system(size: 10)).foregroundColor(.btTextTertiary),
                    at: CGPoint(x: x, y: h - padding.bottom + 14)
                )
            }

            // Curve
            var curve = Path()
            for i in 0...180 {
                let angle = Double(i) * 0.5
                let x = padding.leading + plotW * angle / 90.0
                let y = padding.top + plotH * (1 - 2.0 * sin(angle * .pi / 180) / 2.0)
                if i == 0 {
                    curve.move(to: CGPoint(x: x, y: y))
                } else {
                    curve.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(curve, with: .color(.btPrimary), lineWidth: 2.5)

            // Special angle markers (classic named thicknesses, single truth source).
            let specialAngles: [(Double, String)] =
                AngleSceneCalculator.namedBallThicknesses.map {
                    ($0.cutAngleDegrees, $0.name.replacingOccurrences(of: " ", with: ""))
                }
            for (angle, label) in specialAngles {
                let x = padding.leading + plotW * angle / 90.0
                let dR = 2.0 * sin(angle * .pi / 180)
                let y = padding.top + plotH * (1 - dR / 2.0)
                let dotR: CGFloat = 4
                context.fill(Path(ellipseIn: CGRect(x: x - dotR, y: y - dotR,
                                                    width: dotR * 2, height: dotR * 2)),
                            with: .color(.btTeachingGuide))

                let labelY = y - 12
                context.draw(
                    Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.btText),
                    at: CGPoint(x: x, y: max(padding.top + 6, labelY))
                )
            }
        }
    }

}

// MARK: - Preview

#Preview("Light") {
    NavigationStack { ContactPointTableView() }
}

#Preview("Dark") {
    NavigationStack { ContactPointTableView() }
        .preferredColorScheme(.dark)
}
