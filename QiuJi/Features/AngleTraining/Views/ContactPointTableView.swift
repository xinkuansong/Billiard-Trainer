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
                    caption: "从 0° 正球拖到 90° 擦边极限，比较瞄准点、接触点和偏移量。90° 只表示几何边界。",
                    accessibilityIdentifier: "contactPointTable.thetaSlider"
                )
                principleSection
                estimationSection
                staticTable
                sineCurveSection
            }
            .padding(Spacing.lg)
            .learnDocumentWidth()
        }
        .background(.btBG)
        .background { DailyTableOrientation(landscape: false, allowsTabletRotation: true) }
        .navigationTitle("瞄准点对照表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Interactive slider + ball

    private var interactiveSection: some View {
        LearnDocSectionCard(title: "拖动查看瞄准点与接触点", titleLevel: .subsection) {
            LearnDocText.body("先选一个切角，看红色瞄准点离目标球心多远，再与绿色接触点比较。它们作用不同：红点帮助确定母球球心的行进方向，绿点表示两球应该在哪里相碰。这里先看几何关系，不包含力度和加塞后的修正。")
            // P3.1（问题集合 v3）：卡片加高 220→260，配合图内几何调整（目标球下移、
            // 进球线延伸缩短），拖动全程「袋口方向」标签不再超出卡片。
            aimFigure
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                LearnControlStrip.ReadoutRow(
                    label: "偏移 / 球径",
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
            LearnDocText.body("d 是目标球心到瞄准线的垂直距离，也就是球心到红点的距离。θ 是切角，R 是球半径。注意量取方向垂直于瞄准线，不是垂直于进球线。")
            LearnDocText.body("表中的「偏移%」以一个球的直径为 100%，即 d ÷ 2R；d/R 则以半径为单位。比如 30° 时，偏移为 50%，d/R = 1，表示瞄准点偏离球心一个半径。等比例投影下，重叠厚度 = 100% − 偏移%，所以此时是半球。")
            LearnDocText.footnote("「d(mm)」按球径 57.15 mm 计算。换用其他球径时，毫米数会变，但 d/R、偏移百分比和对应切角不变。完整推导见「瞄准原理」。")
        }
    }

    // MARK: - 中心连线估角与距离误差（条 4.5）

    /// 实战中看不见假想球，常用「母球–目标球中心连线」代替真实瞄准线来估角。
    /// 本节交互演示：两线夹角 Δ 随母球距离增大而变小 → 远台估角更可靠。
    private var estimationSection: some View {
        LearnDocSectionCard(title: "实战估角：中心连线法", titleLevel: .subsection) {
            LearnDocText.body("实际球桌上没有画出的假想球，可以先用母球与目标球的球心连线，和进球线比较，大致估计切角。但球心连线不是正确的切球瞄准线，两者有一个角度差。下面固定为 30° 球形，只改变母球到假想球的距离，看看这个近似差在哪里。")

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
                label: "到假想球的距离",
                value: String(format: "%.2f m", estimationDistance),
                labelEmphasis: .secondary,
                valueSize: 14
            )
            Slider(value: $estimationDistance, in: 0.30...1.60)
                .tint(.btPrimary)
                .accessibilityIdentifier("contactPointTable.estimationSlider")

            LearnDocText.body("把母球移远，白色瞄准线与金色球心连线的夹角会缩小；移近，差别就更明显。因此球心连线更适合用来粗估较远球形，近距离切球需要更仔细地找假想球或接触点关系。这里只说明估角近似变得更接近，并不表示远台更容易打进。")
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
        return acos(Double(min(max(dot / mag, -1), 1))) * 180 / .pi
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
        .foregroundStyle(.btText)
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
                .foregroundStyle(.btText)
                .frame(width: 44)
            Text(String(format: "%.2f", dOverR))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.btPrimary)
                .frame(width: 36)
            Text(String(format: "%.0f%%", sinA * 100))
                .font(.btCaption)
                .foregroundStyle(.btText)
                .frame(width: 40)
            Text(String(format: "%.1f", dMM))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.btText)
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
            LearnDocText.body("偏移量随切角增大而增加，但不是每增加 5° 就移动相同的距离。曲线前段上升较快，靠近 90° 时逐渐变平。可以用它核对趋势，再回到上面的图看具体位置。")
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
                        .foregroundColor(.btText),
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
                    Text("\(xVal)°").font(.system(size: 10)).foregroundColor(.btText),
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
