import SwiftUI

struct ContactPointTableView: View {
    @State private var sliderAngle: Double = 30

    private let standardAngles: [Int] = [0, 10, 15, 20, 25, 30, 35, 40, 45, 49, 60, 75, 90]

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
    }

    // MARK: - Interactive slider + ball

    private var interactiveSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("拖动查看接触点")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            ballDiagram(angle: sliderAngle, size: 120)

            HStack {
                Text("\(Int(sliderAngle))°")
                    .font(.btTitle)
                    .foregroundStyle(.btPrimary)
                    .frame(width: 60)
                Slider(value: $sliderAngle, in: 0...90, step: 1)
                    .tint(.btPrimary)
                Text(String(format: "%.1f%%", AngleCalculator.contactPointOffset(angle: sliderAngle) * 100))
                    .font(.btCallout)
                    .foregroundStyle(.btTextSecondary)
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Principle

    private var principleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("原理")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            Text("偏移量 = sin(α) × R")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.btPrimary)
            Text("其中 α 为切球角度，R 为目标球半径。角度越大，母球需击打目标球越偏的位置。")
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    // MARK: - Static table

    private var staticTable: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("标准角度对照")
                .font(.btHeadline)
                .foregroundStyle(.btText)

            VStack(spacing: 0) {
                headerRow
                ForEach(standardAngles, id: \.self) { angle in
                    tableRow(angle: angle)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }

    private var headerRow: some View {
        HStack {
            Text("角度").font(.btCaption2).frame(width: 50)
            Text("偏移 %").font(.btCaption2).frame(width: 60)
            Spacer()
            Text("接触点").font(.btCaption2).frame(width: 50)
        }
        .foregroundStyle(.btTextSecondary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBGTertiary)
    }

    private func tableRow(angle: Int) -> some View {
        let offset = AngleCalculator.contactPointOffset(angle: Double(angle))
        return HStack {
            Text("\(angle)°")
                .font(.btBody)
                .frame(width: 50)
            Text(String(format: "%.1f%%", offset * 100))
                .font(.btCallout)
                .foregroundStyle(.btTextSecondary)
                .frame(width: 60)
            Spacer()
            ballDiagram(angle: Double(angle), size: 32)
                .frame(width: 50)
        }
        .foregroundStyle(.btText)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.btBGSecondary)
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
                     with: .color(.btDestructive))

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
