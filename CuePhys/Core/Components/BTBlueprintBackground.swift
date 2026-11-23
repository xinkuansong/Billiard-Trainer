import SwiftUI

/// Static page decoration in SwiftUI points, with a top-left origin.
/// It is ornamental only and intentionally makes no table, angle, or pocket claim.
struct BTBlueprintBackground: View {
    enum Style {
        case training, library, practice, history, profile
    }

    var style: Style = .training
    @Environment(\.colorScheme) private var colorScheme

    private var color: Color {
        Color.btPrimary.opacity(colorScheme == .dark ? 0.13 : 0.08)
    }

    var body: some View {
        ZStack {
            Color.btBG
            Canvas { context, size in
                switch style {
                case .training:
                    drawTraining(in: &context, size: size)
                case .library, .practice:
                    drawLibrary(in: &context, size: size)
                case .history:
                    drawReticle(in: &context, center: CGPoint(x: size.width - 20, y: size.height * 0.18), radius: 18)
                    drawRuler(in: &context, origin: CGPoint(x: 0, y: size.height * 0.68))
                    drawArc(in: &context, size: size)
                case .profile:
                    drawReticle(in: &context, center: CGPoint(x: size.width - 20, y: size.height * 0.22), radius: 18)
                    drawArc(in: &context, size: size)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawTraining(in context: inout GraphicsContext, size: CGSize) {
        drawReticle(
            in: &context,
            center: CGPoint(x: size.width - 28, y: 92),
            radius: 22
        )

        drawReticle(
            in: &context,
            center: CGPoint(x: 24, y: size.height * 0.48),
            radius: 15
        )

        var route = Path()
        route.move(to: CGPoint(x: size.width * 0.58, y: 270))
        route.addLine(to: CGPoint(x: size.width * 0.82, y: 220))
        route.addLine(to: CGPoint(x: size.width + 18, y: 304))
        context.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        context.stroke(
            Path(ellipseIn: CGRect(
                x: size.width * 0.82 - 6,
                y: 214,
                width: 12,
                height: 12
            )),
            with: .color(color),
            lineWidth: 1
        )

        var ruler = Path()
        let rulerY = size.height * 0.73
        ruler.move(to: CGPoint(x: 0, y: rulerY))
        ruler.addLine(to: CGPoint(x: min(size.width * 0.34, 144), y: rulerY))
        for index in 0...10 {
            let x = CGFloat(index) * 12
            let tick = index.isMultiple(of: 5) ? 9.0 : 5.0
            ruler.move(to: CGPoint(x: x, y: rulerY))
            ruler.addLine(to: CGPoint(x: x, y: rulerY + tick))
        }
        context.stroke(ruler, with: .color(color), lineWidth: 1)

        var arc = Path()
        arc.addArc(
            center: CGPoint(x: size.width - 18, y: size.height * 0.86),
            radius: 44,
            startAngle: .degrees(120),
            endAngle: .degrees(270),
            clockwise: false
        )
        context.stroke(arc, with: .color(color), lineWidth: 1)
    }


    private func drawLibrary(in context: inout GraphicsContext, size: CGSize) {
        // Edge-anchored motifs keep the central card content quiet at any width.
        drawReticle(in: &context, center: CGPoint(x: size.width - 18, y: size.height * 0.24), radius: 20)
        drawRuler(in: &context, origin: CGPoint(x: 0, y: size.height * 0.76))
        let routeWidth = min(size.width * 0.38, 180)
        let bend = CGPoint(x: size.width - routeWidth * 0.44, y: size.height * 0.58)
        var route = Path()
        route.move(to: CGPoint(x: size.width - routeWidth, y: bend.y + 36))
        route.addLine(to: bend)
        route.addLine(to: CGPoint(x: size.width + 12, y: bend.y + 84))
        context.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        context.stroke(Path(ellipseIn: CGRect(x: bend.x - 6, y: bend.y - 6, width: 12, height: 12)), with: .color(color), lineWidth: 1)
        if style == .practice {
            drawArc(in: &context, size: size)
        }
    }

    private func drawRuler(in context: inout GraphicsContext, origin: CGPoint) {
        var ruler = Path()
        ruler.move(to: origin)
        ruler.addLine(to: CGPoint(x: origin.x + 120, y: origin.y))
        for index in 0...10 {
            let x = origin.x + CGFloat(index) * 12
            ruler.move(to: CGPoint(x: x, y: origin.y))
            ruler.addLine(to: CGPoint(x: x, y: origin.y + (index.isMultiple(of: 5) ? 9 : 5)))
        }
        context.stroke(ruler, with: .color(color), lineWidth: 1)
    }

    private func drawArc(in context: inout GraphicsContext, size: CGSize) {
        var arc = Path()
        arc.addArc(center: CGPoint(x: size.width - 18, y: size.height * 0.86), radius: 44,
                   startAngle: .degrees(120), endAngle: .degrees(270), clockwise: false)
        context.stroke(arc, with: .color(color), lineWidth: 1)
    }

    private func drawReticle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        context.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .color(color),
            lineWidth: 1
        )

        var crosshair = Path()
        crosshair.move(to: CGPoint(x: center.x - radius - 8, y: center.y))
        crosshair.addLine(to: CGPoint(x: center.x + radius + 8, y: center.y))
        crosshair.move(to: CGPoint(x: center.x, y: center.y - radius - 8))
        crosshair.addLine(to: CGPoint(x: center.x, y: center.y + radius + 8))
        context.stroke(crosshair, with: .color(color), lineWidth: 1)

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)),
            with: .color(color)
        )
    }
}

#Preview("Light") {
    BTBlueprintBackground(style: .library).preferredColorScheme(.light)
}

#Preview("Dark") {
    BTBlueprintBackground(style: .library).preferredColorScheme(.dark)
}
