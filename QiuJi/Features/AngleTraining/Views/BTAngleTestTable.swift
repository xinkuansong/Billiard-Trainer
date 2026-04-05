import SwiftUI

/// Standalone Canvas that draws the billiard table with angle-test overlays:
/// highlighted pocket, target/cue balls, and optional result lines.
struct BTAngleTestTable: View {
    let question: AngleQuestion?
    var showResult: Bool = false
    var userAngle: Double? = nil

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            // ── Table surface ──
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.btTableFelt))

            let cw = TableRender.cushionWidth * w
            for rect in [
                CGRect(x: 0, y: 0, width: w, height: cw),
                CGRect(x: 0, y: h - cw, width: w, height: cw),
                CGRect(x: 0, y: 0, width: cw, height: h),
                CGRect(x: w - cw, y: 0, width: cw, height: h),
            ] { ctx.fill(Path(rect), with: .color(.btTableCushion)) }

            for p in TableRender.pockets {
                let r = (p.isSide ? TableRender.sidePocketRadius : TableRender.cornerPocketRadius) * w
                let c = CGPoint(x: p.x * w, y: p.y * w)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(.btTablePocket))
            }

            guard let q = question else { return }

            let pt = { (p: CGPoint) -> CGPoint in CGPoint(x: p.x * w, y: p.y * w) }
            let ballR = TableRender.ballRadius * w
            let tgt = pt(q.targetBall)
            let cue = pt(q.cueBall)
            let pkt = pt(CGPoint(x: q.pocket.x, y: q.pocket.y))

            // ── Pocket glow ──
            let pR = (q.pocket.type == .side
                      ? TableRender.sidePocketRadius
                      : TableRender.cornerPocketRadius) * w * 1.8
            ctx.fill(Path(ellipseIn: CGRect(x: pkt.x - pR, y: pkt.y - pR, width: 2 * pR, height: 2 * pR)),
                     with: .color(Color.btAccent.opacity(0.35)))

            // ── Direction hint (thin line target → pocket) ──
            var hintPath = Path()
            hintPath.move(to: tgt)
            hintPath.addLine(to: pkt)
            ctx.stroke(hintPath, with: .color(Color.btAccent.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 1))

            // ── Result overlay ──
            if showResult {
                let lw = TableRender.pathLineWidth * w * 1.5

                // Correct path: cue → target → pocket (green)
                var correct = Path()
                correct.move(to: cue)
                correct.addLine(to: tgt)
                correct.addLine(to: pkt)
                ctx.stroke(correct, with: .color(.btSuccess), style: StrokeStyle(lineWidth: lw))

                // User estimated approach (orange dashed)
                if let ua = userAngle {
                    let toPkt = atan2(pkt.y - tgt.y, pkt.x - tgt.x)
                    let approach = atan2(tgt.y - cue.y, tgt.x - cue.x)
                    var diff = approach - toPkt
                    while diff >  .pi { diff -= 2 * .pi }
                    while diff < -.pi { diff += 2 * .pi }
                    let sign: Double = diff >= 0 ? 1.0 : -1.0

                    let userRad = ua * .pi / 180.0
                    let userApproach = toPkt + sign * userRad
                    let len: CGFloat = 0.25 * w
                    let userEnd = CGPoint(x: tgt.x - len * cos(userApproach),
                                          y: tgt.y - len * sin(userApproach))

                    var userPath = Path()
                    userPath.move(to: userEnd)
                    userPath.addLine(to: tgt)
                    ctx.stroke(userPath, with: .color(.btWarning),
                               style: StrokeStyle(lineWidth: lw, dash: [lw * 3, lw * 2]))
                }

                // Contact point (red dot)
                let contactDir = atan2(cue.y - tgt.y, cue.x - tgt.x)
                let cp = CGPoint(x: tgt.x + ballR * cos(contactDir),
                                 y: tgt.y + ballR * sin(contactDir))
                let dotR = max(3.0, ballR * 0.35)
                ctx.fill(Path(ellipseIn: CGRect(x: cp.x - dotR, y: cp.y - dotR,
                                                width: 2 * dotR, height: 2 * dotR)),
                         with: .color(.btDestructive))
            }

            // ── Balls ──
            Self.drawBall(ctx: ctx, at: tgt, radius: ballR, color: .btBallTarget)
            Self.drawBall(ctx: ctx, at: cue, radius: ballR, color: .btBallCue)
        }
        .aspectRatio(2, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
    }

    // MARK: - Ball renderer

    private static func drawBall(ctx: GraphicsContext, at center: CGPoint,
                                 radius: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: 2 * radius, height: 2 * radius)
        ctx.fill(Path(ellipseIn: rect), with: .color(color))

        let hr = radius * 0.35, ho = radius * 0.3
        let hc = CGPoint(x: center.x - ho, y: center.y - ho)
        ctx.fill(Path(ellipseIn: CGRect(x: hc.x - hr, y: hc.y - hr,
                                        width: 2 * hr, height: 2 * hr)),
                 with: .color(.white.opacity(0.3)))
    }
}

// MARK: - Preview

#Preview("Light") {
    let q = AngleCalculator.generateQuestion(angle: 30, pocketType: .corner)
    VStack(spacing: Spacing.lg) {
        BTAngleTestTable(question: q)
        BTAngleTestTable(question: q, showResult: true, userAngle: 25)
    }
    .padding()
    .background(.btBG)
}

#Preview("Dark") {
    let q = AngleCalculator.generateQuestion(angle: 30, pocketType: .corner)
    VStack(spacing: Spacing.lg) {
        BTAngleTestTable(question: q)
        BTAngleTestTable(question: q, showResult: true, userAngle: 25)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
