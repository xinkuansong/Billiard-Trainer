import SwiftUI

/// Six-axis load radar. Data source is stored 0–4; vertices use display scores 1–5 (D-v37-6).
enum LoadRadarGeometry {
    /// Axis 0 (aim) at the top, then clockwise.
    static func vertex(
        index: Int,
        count: Int = LoadAxes.Axis.allCases.count,
        center: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / CGFloat(count))
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    static func polygon(fractions: [Double], center: CGPoint, radius: CGFloat) -> [CGPoint] {
        fractions.enumerated().map { index, fraction in
            vertex(index: index, count: fractions.count, center: center, radius: radius * CGFloat(fraction))
        }
    }

    static func hexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let count = LoadAxes.Axis.allCases.count
        for index in 0..<count {
            let point = vertex(index: index, center: center, radius: radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

enum LoadRadarCopy {
    /// On-screen section title. Contract / JSON still use “执行负荷”.
    static let sectionTitle = "难度画像"
    static let sectionSubtitle = "这项动作难在哪"
}

struct BTLoadRadarChart: View {
    let load: LoadAxes?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(Color.btBGSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .contentShape(Rectangle())
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let labelInset: CGFloat = 52
                    let radius = max(24, side / 2 - labelInset)

                    ZStack {
                        Canvas { context, _ in
                            drawPlate(context: &context, center: center, radius: radius)
                            drawGrid(context: &context, center: center, radius: radius)
                            if let load {
                                drawFill(context: &context, load: load, center: center, radius: radius)
                            }
                        }

                        ForEach(LoadAxes.Axis.allCases, id: \.rawValue) { axis in
                            let point = LoadRadarGeometry.vertex(
                                index: axis.rawValue,
                                center: center,
                                radius: radius + 28
                            )
                            axisLabel(axis, load: load)
                                .position(x: point.x, y: point.y)
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(LoadRadarCopy.sectionTitle)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("loadRadarChart")
            .accessibilityAddTraits(.isImage)
    }

    private func axisLabel(_ axis: LoadAxes.Axis, load: LoadAxes?) -> some View {
        let score = load.map { $0.displayScore(for: axis) }
        let isPeak = (score ?? 0) >= 4
        return VStack(spacing: 1) {
            Text(axis.title)
                .font(.btCaption2)
                .foregroundStyle(.btTextSecondary)
            if let score {
                Text("\(score)")
                    .font(.btTitle2)
                    .foregroundStyle(isPeak ? Color.btPrimary : Color.btText)
                    .monospacedDigit()
            }
        }
        .multilineTextAlignment(.center)
    }

    private var accessibilityValue: String {
        guard let load else { return "暂无数据" }
        return LoadAxes.Axis.allCases.map { axis in
            "\(axis.title)\(load.displayScore(for: axis))"
        }.joined(separator: "，")
    }

    private var isDark: Bool { colorScheme == .dark }

    private func drawPlate(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let plate = LoadRadarGeometry.hexagon(center: center, radius: radius)
        let innerGlow = isDark ? 0.28 : 0.10
        context.fill(
            plate,
            with: .radialGradient(
                Gradient(colors: [
                    Color.btPrimary.opacity(innerGlow),
                    Color.btTableFelt.opacity(isDark ? 0.55 : 0.18),
                    Color.btTableFelt.opacity(isDark ? 0.22 : 0.06)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawGrid(context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let count = LoadAxes.Axis.allCases.count
        for ring in 1...LoadAxes.displayMax {
            let ringRadius = radius * CGFloat(ring) / CGFloat(LoadAxes.displayMax)
            let path = LoadRadarGeometry.hexagon(center: center, radius: ringRadius)
            let isOuter = ring == LoadAxes.displayMax
            context.stroke(
                path,
                with: .color(isOuter ? Color.btPrimary.opacity(isDark ? 0.45 : 0.28) : Color.btSeparator),
                lineWidth: isOuter ? 1.2 : 0.5
            )
        }

        for index in 0..<count {
            var spoke = Path()
            spoke.move(to: center)
            spoke.addLine(to: LoadRadarGeometry.vertex(index: index, center: center, radius: radius))
            context.stroke(spoke, with: .color(.btSeparator), lineWidth: 0.5)
        }
    }

    private func drawFill(
        context: inout GraphicsContext,
        load: LoadAxes,
        center: CGPoint,
        radius: CGFloat
    ) {
        let points = LoadRadarGeometry.polygon(
            fractions: load.radarFractions,
            center: center,
            radius: radius
        )
        var path = Path()
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()

        context.drawLayer { layer in
            layer.addFilter(
                .shadow(
                    color: Color.btPrimary.opacity(isDark ? 0.75 : 0.40),
                    radius: isDark ? 14 : 8,
                    x: 0,
                    y: 0
                )
            )
            layer.fill(path, with: .color(Color.btPrimary.opacity(isDark ? 0.45 : 0.28)))
        }

        context.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [
                    Color.btPrimary.opacity(isDark ? 0.18 : 0.10),
                    Color.btPrimary.opacity(isDark ? 0.55 : 0.38)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
        context.stroke(path, with: .color(.btPrimary), lineWidth: 2)

        for (index, point) in points.enumerated() {
            let score = load.displayScore(for: LoadAxes.Axis.allCases[index])
            let isPeak = score >= 4
            let dotRadius: CGFloat = isPeak ? 5 : 3.5
            let rect = CGRect(
                x: point.x - dotRadius,
                y: point.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            let dot = Path(ellipseIn: rect)
            context.fill(dot, with: .color(isPeak ? Color.btAccent : Color.btPrimary))
            context.stroke(dot, with: .color(.btBGSecondary), lineWidth: 1.5)
        }
    }
}
