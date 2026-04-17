import SwiftUI

struct ContactPointTableView: View {
    @State private var sliderAngle: Double = 30

    private let ballRadiusMM: Double = 28.575

    private struct AngleEntry: Identifiable {
        let id: Int
        let angle: Double
        let commonName: String?
    }

    private let standardAngles: [AngleEntry] = [
        AngleEntry(id: 0, angle: 0, commonName: "全球"),
        AngleEntry(id: 1, angle: 5, commonName: nil),
        AngleEntry(id: 2, angle: 10, commonName: "≈1/3 球"),
        AngleEntry(id: 3, angle: 15, commonName: nil),
        AngleEntry(id: 4, angle: 20, commonName: nil),
        AngleEntry(id: 5, angle: 25, commonName: nil),
        AngleEntry(id: 6, angle: 30, commonName: "半球"),
        AngleEntry(id: 7, angle: 35, commonName: nil),
        AngleEntry(id: 8, angle: 40, commonName: nil),
        AngleEntry(id: 9, angle: 45, commonName: nil),
        AngleEntry(id: 10, angle: 48.6, commonName: "3/4 球"),
        AngleEntry(id: 11, angle: 50, commonName: nil),
        AngleEntry(id: 12, angle: 55, commonName: nil),
        AngleEntry(id: 13, angle: 60, commonName: nil),
        AngleEntry(id: 14, angle: 65, commonName: nil),
        AngleEntry(id: 15, angle: 70, commonName: nil),
        AngleEntry(id: 16, angle: 75, commonName: nil),
        AngleEntry(id: 17, angle: 80, commonName: nil),
        AngleEntry(id: 18, angle: 85, commonName: nil),
        AngleEntry(id: 19, angle: 90, commonName: "极薄球"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                interactiveSection
                principleSection
                staticTable
                sineCurveSection
            }
            .padding(Spacing.lg)
        }
        .background(.btBG)
        .navigationTitle("进球点对照表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Interactive slider + ball

    private var interactiveSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("拖动查看接触点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            Circle()
                .fill(.btBGTertiary)
                .frame(width: 160, height: 160)
                .overlay { ballDiagram(angle: sliderAngle, size: 160) }

            VStack(spacing: Spacing.xs) {
                Text("\(Int(sliderAngle))°")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.btText)

                Text(String(format: "偏移 %.0f%%", sin(sliderAngle * .pi / 180) * 100))
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)

                Text(String(format: "d/R = %.2f", 2.0 * sin(sliderAngle * .pi / 180)))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.btPrimary)

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

            HStack {
                Text("0°")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                Slider(value: $sliderAngle, in: 0...90, step: 1)
                    .tint(.btPrimary)
                Text("90°")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func commonName(for angle: Double) -> String? {
        standardAngles.first(where: { abs($0.angle - angle) < 0.5 })?.commonName
    }

    // MARK: - Principle

    private var principleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.btPrimary)
                Text("原理说明")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }
            Text("d = 2R × sin(α)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.btPrimary)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.btAccent)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("d 为横移量（幽灵球中心偏移目标球中心的距离），α 为切球角，R 为球半径。")
                    Text("d/R = 2sin(α) 为无量纲比，表中「d(mm)」按中八球径 57.15mm 计算。")
                }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Static table (expanded)

    private var staticTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "tablecells")
                    .foregroundStyle(.btPrimary)
                Text("对照表")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }

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
            Text("切球角").font(.btCaption2).frame(width: 44, alignment: .leading)
            Text("sin(α)").font(.btCaption2).frame(width: 44)
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
        let angleText = entry.angle == 48.6 ? "48.6°" : "\(Int(entry.angle))°"

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
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "waveform.path")
                    .foregroundStyle(.btPrimary)
                Text("d/R = 2sin(θ) 曲线")
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
            }

            sineCurveCanvas
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
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

            // Special angle markers
            let specialAngles: [(Double, String)] = [(0, "全球"), (10, "1/3球"), (30, "半球"), (48.6, "3/4球"), (90, "极薄")]
            for (angle, label) in specialAngles {
                let x = padding.leading + plotW * angle / 90.0
                let dR = 2.0 * sin(angle * .pi / 180)
                let y = padding.top + plotH * (1 - dR / 2.0)
                let dotR: CGFloat = 4
                context.fill(Path(ellipseIn: CGRect(x: x - dotR, y: y - dotR,
                                                    width: dotR * 2, height: dotR * 2)),
                            with: .color(.red))

                let labelY = y - 12
                context.draw(
                    Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.btText),
                    at: CGPoint(x: x, y: max(padding.top + 6, labelY))
                )
            }
        }
    }

    // MARK: - Ball diagram

    private func ballDiagram(angle: Double, size: CGFloat) -> some View {
        Canvas { ctx, canvasSize in
            let r = min(canvasSize.width, canvasSize.height) / 2 - 4
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                              width: 2 * r, height: 2 * r)),
                       with: .color(.btTextSecondary), lineWidth: 1.5)

            let dotR: CGFloat = 2
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - dotR,
                                            width: 2 * dotR, height: 2 * dotR)),
                     with: .color(.btTextTertiary))

            let offset = sin(angle * .pi / 180.0)
            let cpX = center.x - r * offset
            let cpR: CGFloat = max(3, r * 0.15)
            ctx.fill(Path(ellipseIn: CGRect(x: cpX - cpR, y: center.y - cpR,
                                            width: 2 * cpR, height: 2 * cpR)),
                     with: .color(.btPrimary))

            if size > 50 {
                let arrowStart = CGPoint(x: center.x + r + 6, y: center.y)
                let arrowEnd   = CGPoint(x: center.x + r + 18, y: center.y)
                var arrow = Path()
                arrow.move(to: arrowStart)
                arrow.addLine(to: arrowEnd)
                ctx.stroke(arrow, with: .color(.btTextTertiary), lineWidth: 1.5)

                var head = Path()
                head.move(to: arrowEnd)
                head.addLine(to: CGPoint(x: arrowEnd.x - 4, y: arrowEnd.y - 3))
                head.move(to: arrowEnd)
                head.addLine(to: CGPoint(x: arrowEnd.x - 4, y: arrowEnd.y + 3))
                ctx.stroke(head, with: .color(.btTextTertiary), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
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
