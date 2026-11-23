import SwiftUI

/// Practice-home grid cover: geometric micro-illustration or static table preview (v28 W1).
///
/// Zone color from `CoverPalette` is a light tint / chip language — not a full-bleed poster fill.
struct BTPracticeCover: View {
    let visual: PracticeCoverVisual
    var chip: String? = nil

    private var layout: PracticeCoverLayout { visual.layout }
    private var palette: CoverPalette.Pair {
        PracticeCoverCatalog.palette(for: layout.tintTopKey)
    }

    var body: some View {
        ZStack {
            tableLayer

            // Light zone tint — keep content (balls/lines) primary.
            LinearGradient(
                colors: [
                    palette.top.opacity(visual.isGeometric ? 0.22 : 0.14),
                    palette.bottom.opacity(visual.isGeometric ? 0.30 : 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)

            if let chip {
                VStack {
                    HStack {
                        Spacer()
                        Text(chip)
                            .font(.btMicro.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.40), in: Capsule())
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: BTRadius.md,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: BTRadius.md
            )
        )
        .accessibilityHidden(true)
    }

    private var tableLayer: some View {
        let closeup = layout.closeup.map { (center: CGPoint(x: $0.x, y: $0.z), halfHeight: $0.halfHeight) }
        return BTTableFigure(orientation: .landscape, closeup: closeup) { proj in
            ZStack {
                ForEach(Array(layout.segments.enumerated()), id: \.offset) { _, segment in
                    Path { path in
                        path.move(to: proj.point(x: segment.x0, z: segment.z0))
                        path.addLine(to: proj.point(x: segment.x1, z: segment.z1))
                    }
                    .stroke(strokeColor(for: segment), style: strokeStyle(for: segment, proj: proj))
                }

                ForEach(Array(layout.ghosts.enumerated()), id: \.offset) { _, ghost in
                    BTGhostCircle(diameter: proj.ballDiameter)
                        .position(proj.point(x: ghost.x, z: ghost.z))
                }

                ForEach(Array(layout.balls.enumerated()), id: \.offset) { _, ball in
                    BTFigureBall(number: ball.number, diameter: proj.ballDiameter)
                        .position(proj.point(x: ball.x, z: ball.z))
                }
            }
        }
    }

    private func strokeColor(for segment: PracticeCoverLayout.Segment) -> Color {
        switch segment.style {
        case .aim: return FigureLine.aim
        case .pot: return FigureLine.pot(number: segment.potNumber)
        case .hint: return FigureLine.hint.opacity(0.85)
        case .separation: return FigureLine.separation
        }
    }

    private func strokeStyle(
        for segment: PracticeCoverLayout.Segment,
        proj: TableFigureProjection
    ) -> StrokeStyle {
        switch segment.style {
        case .aim:
            return StrokeStyle(lineWidth: proj.lineMainWidth, lineCap: .round)
        case .pot:
            return StrokeStyle(lineWidth: proj.lineMainWidth, dash: [6, 4])
        case .hint:
            return StrokeStyle(
                lineWidth: proj.lineHintWidth,
                dash: FigureLine.hintDashPattern(width: proj.lineHintWidth)
            )
        case .separation:
            return StrokeStyle(
                lineWidth: proj.lineHintWidth,
                dash: FigureLine.hintDashPattern(width: proj.lineHintWidth)
            )
        }
    }
}

#if DEBUG
#Preview("Practice covers") {
    let routes: [AngleRoute] = [
        .aimingPrinciple, .sceneAiming2D, .shotSimulation, .bankShot,
    ]
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    return LazyVGrid(columns: cols, spacing: 12) {
        ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
            BTPracticeCover(visual: PracticeCoverCatalog.visual(for: route), chip: "样")
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
        }
    }
    .padding()
    .background(.btBG)
}
#endif
