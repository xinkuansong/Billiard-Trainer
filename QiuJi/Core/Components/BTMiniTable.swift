import SwiftUI

struct BTMiniTable: View {
    let animation: DrillAnimation

    private enum Mini {
        static let ballRadius: CGFloat = 0.034
        static let pocketRadius: CGFloat = 0.028
        static let pathLineWidth: CGFloat = 0.007
        static let targetPocketGlow: CGFloat = 0.055
    }

    var body: some View {
        Canvas { ctx, size in
            drawFelt(ctx: ctx, size: size)
            drawPockets(ctx: ctx, size: size)
            drawTargetPocketGlow(ctx: ctx, size: size)
            drawPaths(ctx: ctx, size: size)
            drawBalls(ctx: ctx, size: size)
        }
        .aspectRatio(2.0, contentMode: .fit)
    }

    // MARK: - Felt

    private func drawFelt(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.btTableFelt))
    }

    // MARK: - Pockets

    private func drawPockets(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        for pocket in TableRender.pockets {
            let r = Mini.pocketRadius * w
            let center = toCanvas(CanvasPoint(x: pocket.x, y: pocket.y), size: size)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.btTablePocket))
        }
    }

    // MARK: - Target Pocket Glow

    private func drawTargetPocketGlow(ctx: GraphicsContext, size: CGSize) {
        guard let pocketCoord = pocketCenter(for: animation.pocket) else { return }
        let center = toCanvas(pocketCoord, size: size)
        let r = Mini.targetPocketGlow * size.width

        let glowRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let glowPath = Path(ellipseIn: glowRect)
        ctx.stroke(glowPath, with: .color(Color.btPrimary.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 3))

        let innerR = r * 0.6
        let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
        ctx.fill(Path(ellipseIn: innerRect), with: .color(Color.btPrimary.opacity(0.15)))
    }

    // MARK: - Paths

    private func drawPaths(ctx: GraphicsContext, size: CGSize) {
        drawPath(ctx: ctx, size: size,
                 start: animation.cueBall.start,
                 path: animation.cueBall.path,
                 color: .btPathCue)
        drawPath(ctx: ctx, size: size,
                 start: animation.targetBall.start,
                 path: animation.targetBall.path,
                 color: .btPathTarget)
    }

    private func drawPath(ctx: GraphicsContext, size: CGSize,
                          start: CanvasPoint, path: [PathPoint], color: Color) {
        guard !path.isEmpty else { return }

        var swiftPath = Path()
        swiftPath.move(to: toCanvas(start, size: size))

        for (i, point) in path.enumerated() {
            let endPt = toCanvas(point.endPoint, size: size)
            if point.isCurve, let cp1 = point.cp1, let cp2 = point.cp2 {
                swiftPath.addCurve(to: endPt,
                                   control1: toCanvas(cp1, size: size),
                                   control2: toCanvas(cp2, size: size))
            } else {
                swiftPath.addLine(to: endPt)
            }
            _ = i
        }

        let lw = Mini.pathLineWidth * size.width
        ctx.stroke(swiftPath, with: .color(color),
                   style: StrokeStyle(lineWidth: lw, dash: [lw * 2.5, lw * 1.5]))
    }

    // MARK: - Balls

    private func drawBalls(ctx: GraphicsContext, size: CGSize) {
        let r = Mini.ballRadius * size.width

        let targetEnd = animation.targetBall.path.last?.endPoint ?? animation.targetBall.start
        drawBall(ctx: ctx, center: toCanvas(targetEnd, size: size), radius: r, color: .btBallTarget)

        let cueEnd = animation.cueBall.path.last?.endPoint ?? animation.cueBall.start
        drawBall(ctx: ctx, center: toCanvas(cueEnd, size: size), radius: r, color: .btBallCue)
    }

    private func drawBall(ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))

        let hlR = radius * 0.35
        let hlOff = radius * 0.3
        let hlCenter = CGPoint(x: center.x - hlOff, y: center.y - hlOff)
        let hlRect = CGRect(x: hlCenter.x - hlR, y: hlCenter.y - hlR,
                            width: hlR * 2, height: hlR * 2)
        ctx.fill(Path(ellipseIn: hlRect), with: .color(Color.white.opacity(0.4)))
    }

    // MARK: - Helpers

    private func toCanvas(_ pt: CanvasPoint, size: CGSize) -> CGPoint {
        CGPoint(x: pt.x * size.width, y: pt.y * size.width)
    }

    private func pocketCenter(for pocketName: String) -> CanvasPoint? {
        switch pocketName {
        case "topLeft":      return CanvasPoint(x: 0, y: 0)
        case "topRight":     return CanvasPoint(x: 1, y: 0)
        case "bottomLeft":   return CanvasPoint(x: 0, y: 0.5)
        case "bottomRight":  return CanvasPoint(x: 1, y: 0.5)
        case "topCenter":    return CanvasPoint(x: 0.5, y: 0)
        case "bottomCenter": return CanvasPoint(x: 0.5, y: 0.5268)
        default:             return nil
        }
    }
}

#Preview("Mini Tables") {
    let samples: [(String, DrillAnimation)] = [
        ("直线球", DrillAnimation(
            cueBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.25), path: [PathPoint(x: 0.5, y: 0.45)]),
            targetBall: BallAnimation(start: CanvasPoint(x: 0.5, y: 0.43), path: [PathPoint(x: 0.5, y: 0.5268)]),
            pocket: "bottomCenter", cueDirection: CanvasPoint(x: 0.5, y: 0.0))),
        ("斜角球", DrillAnimation(
            cueBall: BallAnimation(start: CanvasPoint(x: 0.3, y: 0.15), path: [PathPoint(x: 0.7, y: 0.35)]),
            targetBall: BallAnimation(start: CanvasPoint(x: 0.7, y: 0.33), path: [PathPoint(x: 1.0, y: 0.5)]),
            pocket: "bottomRight", cueDirection: CanvasPoint(x: 0.7, y: 0.0))),
        ("中袋", DrillAnimation(
            cueBall: BallAnimation(start: CanvasPoint(x: 0.2, y: 0.35), path: [PathPoint(x: 0.4, y: 0.25)]),
            targetBall: BallAnimation(start: CanvasPoint(x: 0.4, y: 0.25), path: [PathPoint(x: 0.5, y: 0.0)]),
            pocket: "topCenter", cueDirection: CanvasPoint(x: 0.5, y: 0.0))),
    ]
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    LazyVGrid(columns: cols, spacing: 12) {
        ForEach(samples, id: \.0) { name, anim in
            VStack(spacing: 4) {
                BTMiniTable(animation: anim)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(name).font(.btCaption)
            }
        }
    }
    .padding()
    .background(.btBG)
}
