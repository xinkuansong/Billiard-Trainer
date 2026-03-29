import SwiftUI

// MARK: - Render Constants

enum TableRender {
    static let cushionWidth: CGFloat = 0.0197
    static let ballRadius: CGFloat = 0.01125
    static let cornerPocketRadius: CGFloat = 0.01654
    static let sidePocketRadius: CGFloat = 0.01693
    static let pathLineWidth: CGFloat = 0.003

    static let pockets: [(x: CGFloat, y: CGFloat, isSide: Bool)] = [
        (-0.0165, -0.0165, false),
        ( 1.0165, -0.0165, false),
        (-0.0165,  0.5165, false),
        ( 1.0165,  0.5165, false),
        ( 0.5,    -0.0268, true),
        ( 0.5,     0.5268, true),
    ]
}

// MARK: - BTBilliardTable

struct BTBilliardTable: View {
    let animation: DrillAnimation?
    @Binding var animationProgress: CGFloat

    init(animation: DrillAnimation? = nil, animationProgress: Binding<CGFloat> = .constant(1.0)) {
        self.animation = animation
        self._animationProgress = animationProgress
    }

    var body: some View {
        Canvas { ctx, size in
            drawFelt(ctx: ctx, size: size)
            drawCushions(ctx: ctx, size: size)
            drawPockets(ctx: ctx, size: size)

            if let animation {
                drawPaths(ctx: ctx, size: size, animation: animation)
                drawBalls(ctx: ctx, size: size, animation: animation)
            }
        }
        .aspectRatio(2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    // MARK: - Table Drawing

    private func drawFelt(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.btTableFelt))
    }

    private func drawCushions(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let cw = TableRender.cushionWidth * w

        let cushions = [
            CGRect(x: 0, y: 0, width: w, height: cw),
            CGRect(x: 0, y: h - cw, width: w, height: cw),
            CGRect(x: 0, y: 0, width: cw, height: h),
            CGRect(x: w - cw, y: 0, width: cw, height: h),
        ]
        for rect in cushions {
            ctx.fill(Path(rect), with: .color(.btTableCushion))
        }
    }

    private func drawPockets(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        for pocket in TableRender.pockets {
            let r = (pocket.isSide ? TableRender.sidePocketRadius : TableRender.cornerPocketRadius) * w
            let center = toCanvas(CanvasPoint(x: pocket.x, y: pocket.y), size: size)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.btTablePocket))
        }
    }

    // MARK: - Path Drawing

    private func drawPaths(ctx: GraphicsContext, size: CGSize, animation: DrillAnimation) {
        let progress = animationProgress

        drawBallPath(
            ctx: ctx, size: size,
            start: animation.targetBall.start,
            path: animation.targetBall.path,
            color: .btPathTarget,
            progress: targetBallProgress(progress)
        )
        drawBallPath(
            ctx: ctx, size: size,
            start: animation.cueBall.start,
            path: animation.cueBall.path,
            color: .btPathCue,
            progress: cueBallProgress(progress)
        )
    }

    private func drawBallPath(
        ctx: GraphicsContext, size: CGSize,
        start: CanvasPoint, path: [PathPoint],
        color: Color, progress: CGFloat
    ) {
        guard !path.isEmpty, progress > 0 else { return }

        let totalSegments = path.count
        let segmentFraction = 1.0 / CGFloat(totalSegments)

        var swiftPath = Path()
        let startPt = toCanvas(start, size: size)
        swiftPath.move(to: startPt)

        for (i, point) in path.enumerated() {
            let segStart = CGFloat(i) * segmentFraction
            let segProgress = min(max((progress - segStart) / segmentFraction, 0), 1)

            guard segProgress > 0 else { break }

            let endPt = toCanvas(point.endPoint, size: size)
            let currentStart = i == 0 ? startPt : toCanvas(path[i - 1].endPoint, size: size)

            if point.isCurve, let cp1 = point.cp1, let cp2 = point.cp2 {
                let cp1Pt = toCanvas(cp1, size: size)
                let cp2Pt = toCanvas(cp2, size: size)

                if segProgress >= 1.0 {
                    swiftPath.addCurve(to: endPt, control1: cp1Pt, control2: cp2Pt)
                } else {
                    let partial = splitCubicBezier(
                        p0: currentStart, p1: cp1Pt, p2: cp2Pt, p3: endPt, t: segProgress
                    )
                    swiftPath.addCurve(to: partial.end, control1: partial.cp1, control2: partial.cp2)
                }
            } else {
                let target = segProgress >= 1.0
                    ? endPt
                    : CGPoint(
                        x: currentStart.x + (endPt.x - currentStart.x) * segProgress,
                        y: currentStart.y + (endPt.y - currentStart.y) * segProgress
                    )
                swiftPath.addLine(to: target)
            }
        }

        let lineWidth = TableRender.pathLineWidth * size.width
        ctx.stroke(
            swiftPath,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, dash: [lineWidth * 3, lineWidth * 2])
        )
    }

    // MARK: - Ball Drawing

    private func drawBalls(ctx: GraphicsContext, size: CGSize, animation: DrillAnimation) {
        let progress = animationProgress
        let r = TableRender.ballRadius * size.width

        let targetPos = ballPosition(
            start: animation.targetBall.start,
            path: animation.targetBall.path,
            progress: targetBallProgress(progress),
            size: size
        )
        drawBall(ctx: ctx, center: targetPos, radius: r, color: .btBallTarget)

        let cuePos = ballPosition(
            start: animation.cueBall.start,
            path: animation.cueBall.path,
            progress: cueBallProgress(progress),
            size: size
        )
        drawBall(ctx: ctx, center: cuePos, radius: r, color: .btBallCue)
    }

    private func drawBall(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))

        let highlightRadius = radius * 0.35
        let highlightOffset = radius * 0.3
        let highlightCenter = CGPoint(x: center.x - highlightOffset, y: center.y - highlightOffset)
        let highlightRect = CGRect(
            x: highlightCenter.x - highlightRadius,
            y: highlightCenter.y - highlightRadius,
            width: highlightRadius * 2, height: highlightRadius * 2
        )
        ctx.fill(Path(ellipseIn: highlightRect), with: .color(.white.opacity(0.3)))
    }

    // MARK: - Position Calculation

    private func ballPosition(
        start: CanvasPoint, path: [PathPoint],
        progress: CGFloat, size: CGSize
    ) -> CGPoint {
        guard !path.isEmpty, progress > 0 else {
            return toCanvas(start, size: size)
        }

        let totalSegments = path.count
        let segmentFraction = 1.0 / CGFloat(totalSegments)

        for (i, point) in path.enumerated() {
            let segStart = CGFloat(i) * segmentFraction
            let segProgress = min(max((progress - segStart) / segmentFraction, 0), 1)

            guard segProgress > 0 else {
                let prev = i == 0 ? start : path[i - 1].endPoint
                return toCanvas(prev, size: size)
            }

            if segProgress < 1.0 || i == path.count - 1 {
                let prevPt = i == 0
                    ? toCanvas(start, size: size)
                    : toCanvas(path[i - 1].endPoint, size: size)
                let endPt = toCanvas(point.endPoint, size: size)

                if point.isCurve, let cp1 = point.cp1, let cp2 = point.cp2 {
                    let cp1Pt = toCanvas(cp1, size: size)
                    let cp2Pt = toCanvas(cp2, size: size)
                    return cubicBezierPoint(p0: prevPt, p1: cp1Pt, p2: cp2Pt, p3: endPt, t: segProgress)
                } else {
                    return CGPoint(
                        x: prevPt.x + (endPt.x - prevPt.x) * segProgress,
                        y: prevPt.y + (endPt.y - prevPt.y) * segProgress
                    )
                }
            }
        }

        return toCanvas(path.last!.endPoint, size: size)
    }

    // MARK: - Animation Phasing

    private func cueBallProgress(_ overall: CGFloat) -> CGFloat {
        min(max((overall - 0.0) / 0.5, 0), 1)
    }

    private func targetBallProgress(_ overall: CGFloat) -> CGFloat {
        min(max((overall - 0.4) / 0.5, 0), 1)
    }

    // MARK: - Coordinate Conversion

    private func toCanvas(_ pt: CanvasPoint, size: CGSize) -> CGPoint {
        CGPoint(x: pt.x * size.width, y: pt.y * size.width)
    }

    // MARK: - Bézier Math

    private func cubicBezierPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        return CGPoint(
            x: mt2 * mt * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t2 * t * p3.x,
            y: mt2 * mt * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t2 * t * p3.y
        )
    }

    private struct BezierSegment {
        let end: CGPoint
        let cp1: CGPoint
        let cp2: CGPoint
    }

    private func splitCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> BezierSegment {
        let q0 = lerp(p0, p1, t)
        let q1 = lerp(p1, p2, t)
        let q2 = lerp(p2, p3, t)
        let r0 = lerp(q0, q1, t)
        let r1 = lerp(q1, q2, t)
        let s = lerp(r0, r1, t)
        return BezierSegment(end: s, cp1: q0, cp2: r0)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Preview

#Preview("Light") {
    VStack(spacing: Spacing.lg) {
        BTBilliardTablePreview()
    }
    .padding()
    .background(.btBG)
}

#Preview("Dark") {
    VStack(spacing: Spacing.lg) {
        BTBilliardTablePreview()
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}

private struct BTBilliardTablePreview: View {
    @State private var progress: CGFloat = 0

    private let sampleAnimation = DrillAnimation(
        cueBall: BallAnimation(
            start: CanvasPoint(x: 0.5, y: 0.25),
            path: [
                PathPoint(x: 0.5, y: 0.45)
            ]
        ),
        targetBall: BallAnimation(
            start: CanvasPoint(x: 0.5, y: 0.43),
            path: [
                PathPoint(x: 0.5, y: 0.5268)
            ]
        ),
        pocket: "bottomCenter",
        cueDirection: CanvasPoint(x: 0.5, y: 0.0)
    )

    var body: some View {
        VStack(spacing: Spacing.md) {
            BTBilliardTable(animation: sampleAnimation, animationProgress: $progress)

            Button("播放动画") {
                progress = 0
                withAnimation(.easeInOut(duration: 1.4)) {
                    progress = 1
                }
            }
            .buttonStyle(BTButtonStyle.primary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4)) {
                progress = 1
            }
        }
    }
}
