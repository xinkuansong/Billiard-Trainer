import SwiftUI

struct ContactPointTableView: View {
    @State private var sliderAngle: Double = 30

    private struct AngleEntry: Identifiable {
        let id: Int
        let angle: Double
        let commonName: String?
    }

    private let standardAngles: [AngleEntry] = [
        AngleEntry(id: 0, angle: 0, commonName: "全球"),
        AngleEntry(id: 1, angle: 10, commonName: nil),
        AngleEntry(id: 2, angle: 15, commonName: nil),
        AngleEntry(id: 3, angle: 20, commonName: nil),
        AngleEntry(id: 4, angle: 25, commonName: nil),
        AngleEntry(id: 5, angle: 30, commonName: "二分之一球"),
        AngleEntry(id: 6, angle: 35, commonName: nil),
        AngleEntry(id: 7, angle: 40, commonName: nil),
        AngleEntry(id: 8, angle: 45, commonName: nil),
        AngleEntry(id: 9, angle: 48.6, commonName: "四分之三点"),
        AngleEntry(id: 10, angle: 60, commonName: nil),
        AngleEntry(id: 11, angle: 75, commonName: nil),
        AngleEntry(id: 12, angle: 90, commonName: "极薄球"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxl) {
                interactiveSection
                principleSection
                staticTable
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
                    .font(.btStatNumber)
                    .fontWeight(.heavy)
                    .foregroundStyle(.btText)
                Text(String(format: "偏移 %.0f%%", AngleCalculator.contactPointOffset(angle: sliderAngle) * 100))
                    .font(.btSubheadlineMedium)
                    .foregroundStyle(.btTextSecondary)
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
        standardAngles.first(where: { abs($0.angle - angle) < 0.1 })?.commonName
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
            Text("偏移量 = sin(α) × R")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.btPrimary)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.btAccent)
                    .frame(width: 4)
                Text("其中 α 为切球角度，R 为目标球半径。角度越大，母球需击打目标球越偏的位置。")
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

    // MARK: - Static table

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
        HStack {
            Text("切入角").font(.btCaption2).frame(width: 50)
            Text("sin(α)").font(.btCaption2).frame(width: 50)
            Text("偏移").font(.btCaption2).frame(width: 44)
            Spacer()
            Text("通称").font(.btCaption2).frame(width: 76, alignment: .trailing)
        }
        .foregroundStyle(.btTextSecondary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBGTertiary)
    }

    private func tableRow(entry: AngleEntry) -> some View {
        let offset = AngleCalculator.contactPointOffset(angle: entry.angle)
        let highlighted = entry.commonName != nil
        let angleText = entry.angle == 48.6 ? "48.6°" : "\(Int(entry.angle))°"
        return HStack {
            Text(angleText)
                .font(highlighted ? .btBodyMedium : .btBody)
                .frame(width: 50)
            Text(String(format: "%.2f", offset))
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 50)
            Group {
                if entry.angle == 0 {
                    Text("球心")
                } else if entry.angle == 90 {
                    Text("球边缘")
                } else {
                    Text(String(format: "%.0f%%", offset * 100))
                }
            }
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 44)
            Spacer()
            if let name = entry.commonName {
                Text(name)
                    .font(.btCaption)
                    .foregroundStyle(.btPrimary)
                    .fontWeight(.bold)
                    .frame(width: 76, alignment: .trailing)
            } else {
                Text("—")
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
                    .frame(width: 76, alignment: .trailing)
            }
        }
        .foregroundStyle(.btText)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(highlighted ? Color.btPrimaryMuted : .btBGSecondary)
    }

    // MARK: - Ball diagram

    private func ballDiagram(angle: Double, size: CGFloat) -> some View {
        Canvas { ctx, canvasSize in
            let r = min(canvasSize.width, canvasSize.height) / 2 - 4
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

            // Ball outline
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                              width: 2 * r, height: 2 * r)),
                       with: .color(.btTextSecondary), lineWidth: 1.5)

            // Center dot
            let dotR: CGFloat = 2
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - dotR,
                                            width: 2 * dotR, height: 2 * dotR)),
                     with: .color(.btTextTertiary))

            // Contact point (offset from center toward left by sin(α)×R)
            let offset = sin(angle * .pi / 180.0)
            let cpX = center.x - r * offset
            let cpR: CGFloat = max(3, r * 0.15)
            ctx.fill(Path(ellipseIn: CGRect(x: cpX - cpR, y: center.y - cpR,
                                            width: 2 * cpR, height: 2 * cpR)),
                     with: .color(.btPrimary))

            // Pocket direction arrow (right)
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
