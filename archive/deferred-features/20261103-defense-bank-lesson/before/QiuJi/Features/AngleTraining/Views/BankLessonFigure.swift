import SwiftUI
import SceneKit

/// Native drawing over the approved, transparent liveReference model render.
/// Assets are a fixed lesson illustration, not a preview of the user's appearance settings.
struct BankLessonFigure: View {
    enum Kind { case overview, mirror, ghost, compare, power, pocket, observe }
    let kind: Kind
    var reference: BankLessonModel.Shot?
    var current: BankLessonModel.Shot?
    var progress: Double = 0
    var targetX: Double = Double(BankLessonModel.target.x)
    var aimDegrees: Double = 0
    var showsMirror = true
    var showsIdeal = true
    var showsActual = true
    var showsReference = true
    var observesAfter = false

    private static let table = UIImage(named: "BankLessonTable")
    private static let ghostTable = UIImage(named: "BankLessonGhost")
    private static let pocketTable = UIImage(named: "BankLessonPocket")
    private static let cueImage = UIImage(named: "BankLessonCue")
    private static let oneImage = UIImage(named: "BankLessonOne")

    private var framing: (center: CGPoint, span: CGFloat, aspect: CGFloat) {
        switch kind {
        case .mirror: return (CGPoint(x: 0, y: 0.2), 3.1125, 1.4)
        case .ghost: return (CGPoint(x: -0.55, y: 0.12), 0.66, 1.2)
        case .pocket: return (CGPoint(x: 0, y: -0.59), 0.65, 1.6)
        default: return (.zero, 3.1125, 1.875)
        }
    }

    var body: some View {
        Canvas { context, size in
            draw(context, size: size)
        }
        .aspectRatio(framing.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        switch kind {
        case .overview: return "一库翻中袋示范。母球碰前白实线，碰后白虚线；目标球黄色虚线。"
        case .mirror: return showsMirror ? "目标球及库外镜像球，关于球心反弹基准线等距。" : "目标球与参考吃库点，镜像已隐藏。"
        case .ghost: return "目标球后方相切的假想母球，白虚线圈与红色球心。"
        case .compare: return "几何参考与真实模拟路线对照。"
        case .power: return current.map { "杆速\(Double($0.speedIndex) / 10)米每秒。\($0.result)" } ?? "正在计算当前力度路线。"
        case .pocket: return "目标中袋附近的路线放大图。"
        case .observe: return observesAfter ? "重点观察目标球碰库后的路线。" : "重点观察目标球碰库前的路线。"
        }
    }

    private enum LineRole { case aim, cue, pot, hint }

    private func draw(_ context: GraphicsContext, size: CGSize) {
        let closeup = kind == .ghost ? Self.ghostTable : kind == .pocket ? Self.pocketTable : nil
        guard let table = closeup ?? Self.table else { return }
        let frame = framing
        let projection = TableFigureProjection(
            backdrop: .init(image: table, orientation: .landscape,
                            orthoScale: frame.span / (2 * frame.aspect), aspect: frame.aspect, center: frame.center),
            size: size)
        func xy(_ p: SIMD2<Float>) -> CGPoint { projection.point(x: CGFloat(p.x), z: CGFloat(p.y)) }
        func worldRect(_ origin: SIMD2<Float>, width: CGFloat, height: CGFloat) -> CGRect {
            CGRect(origin: xy(origin), size: CGSize(width: projection.length(width), height: projection.length(height)))
        }
        // The model's open mesh bags need a dark interior when composited on paper.
        // Positions and aperture sizes come from the same production table geometry.
        for pocket in TableGeometry.chineseEightBallQiuJi(surfaceY: 0).pockets {
            let r = CGFloat(pocket.radius), p = SIMD2<Float>(pocket.center.x, pocket.center.z)
            context.fill(Path(ellipseIn: worldRect(p - SIMD2<Float>(repeating: Float(r)), width: r * 2, height: r * 2)),
                         with: .color(.btTablePocket))
        }
        if closeup != nil {
            context.draw(Image(uiImage: table), in: CGRect(origin: .zero, size: size))
        } else {
            context.draw(Image(uiImage: table), in: worldRect([-1.55625, -0.83], width: 3.1125, height: 1.66))
        }

        func line(_ points: [SIMD2<Float>], _ role: LineRole, opacity: Double = 1) {
            guard points.count > 1 else { return }
            let path = Path { p in
                p.move(to: xy(points[0]))
                for point in points.dropFirst() { p.addLine(to: xy(point)) }
            }
            let width = role == .hint ? projection.lineHintWidth : projection.lineMainWidth
            let dash: [CGFloat] = role == .aim ? [] : role == .hint
                ? FigureLine.hintDashPattern(width: width)
                : [projection.length(CGFloat(TrajectoryStyle.mainDash)), projection.length(CGFloat(TrajectoryStyle.mainGap))]
            let color: Color = role == .pot ? FigureLine.pot(number: 1) : role == .hint ? FigureLine.hint : FigureLine.aim
            let style = StrokeStyle(lineWidth: width, lineCap: role == .aim ? .round : .butt, lineJoin: .round, dash: dash)
            context.stroke(path, with: .color(color.opacity(opacity)), style: style)
            if kind == .mirror && role == .hint {
                var outside = context
                let edge = xy([0, 0.79]).y
                outside.clip(to: Path(CGRect(x: 0, y: edge, width: size.width, height: max(0, size.height - edge))))
                outside.stroke(path, with: .color(Color.btTextSecondary.opacity(opacity)), style: style)
            }
        }
        func dot(_ point: SIMD2<Float>, color: Color = FigureLine.pot(number: 1), radius: CGFloat = 3) {
            let p = xy(point)
            context.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
        func label(_ point: SIMD2<Float>, _ title: String, dx: CGFloat = 8, dy: CGFloat = 0,
                   anchor: UnitPoint = .leading, color: Color = FigureLine.aim) {
            let p = xy(point)
            let outside = abs(point.y) > 0.79
            var textContext = context
            if !outside { textContext.addFilter(.shadow(color: .black.opacity(0.7), radius: 1)) }
            textContext.draw(Text(title).font(.btCaption).foregroundColor(outside ? .btText : color),
                             at: CGPoint(x: p.x + dx, y: p.y + dy), anchor: anchor)
        }
        func ball(_ point: SIMD2<Float>, target: Bool = false) {
            guard let image = target ? Self.oneImage : Self.cueImage else { return }
            let p = xy(point), diameter = projection.ballDiameter * 1.12
            context.draw(Image(uiImage: image), in: CGRect(x: p.x - diameter / 2, y: p.y - diameter / 2, width: diameter, height: diameter))
        }
        let cue = BankLessonModel.cue, target = BankLessonModel.target, pocket = BankLessonModel.pocket
        let geometry = BankLessonModel.geometry()
        let targetPath = reference?.object.map(\.point) ?? []
        let bounce = reference.flatMap { shot in shot.cushionTimes.first.flatMap { shot.position(in: shot.object, at: $0) } } ?? geometry.bounce

        switch kind {
        case .overview:
            if let shot = reference {
                line(targetPath, .pot)
                let contact = shot.contactTime ?? 0
                line(shot.cue.filter { $0.time <= contact }.map(\.point), .aim)
                line(shot.cue.filter { $0.time >= contact }.map(\.point), .cue)
                let time = Float(progress) * (shot.objectPocketTime ?? shot.duration)
                if shot.cuePocketTime.map({ time < $0 }) ?? true, let p = shot.position(in: shot.cue, at: time) { ball(p) }
                if shot.objectPocketTime.map({ time < $0 }) ?? true, let p = shot.position(in: shot.object, at: time) { ball(p, target: true) }
            } else { ball(cue); ball(target, target: true) }
            dot(bounce); label(bounce, "吃库点", dx: 12, dy: -14)
            label(pocket, "目标中袋", dx: 16)
            if progress == 0 {
                label(cue, "母球", dx: -12, anchor: .trailing)
                label(target, "目标球", dx: -12, anchor: .trailing)
            }
        case .mirror:
            let t = SIMD2<Float>(Float(targetX), target.y), g = BankLessonModel.geometry(target: t)
            line([t, g.bounce, pocket], .pot)
            line([[-1.13, BankLessonModel.rail], [1.13, BankLessonModel.rail]], .hint)
            dot(g.bounce); ball(t, target: true)
            label(g.bounce, "参考吃库点", dx: 12, dy: -14); label(pocket, "目标袋口", dx: 15)
            if showsMirror {
                line([g.bounce, g.mirror], .hint); line([t, g.mirror], .hint, opacity: 0.75)
                ball(g.mirror, target: true)
                label(t, "目标球", dx: -10, anchor: .trailing)
                label(g.mirror, "镜像目标球", dx: 14)
                label([t.x, (t.y + BankLessonModel.rail) / 2], "等距", dx: -10, anchor: .trailing)
                label([t.x, (g.mirror.y + BankLessonModel.rail) / 2], "等距", dx: -10, dy: 7, anchor: .trailing)
            }
        case .ghost:
            line([target, geometry.bounce], .pot); line([cue, geometry.ghost], .hint)
            line([cue, BankLessonModel.trial(degrees: aimDegrees).end], .aim)
            ball(target, target: true)
            let p = xy(geometry.ghost), d = projection.ballDiameter
            context.stroke(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)),
                           with: .color(FigureLine.ghost),
                           style: StrokeStyle(lineWidth: max(1.2, d * 0.035), dash: [d * 0.12, d * 0.08]))
            dot(geometry.ghost, color: FigureLine.aimPoint, radius: max(2, projection.length(0.004)))
            label(target, "目标球", dx: d * 0.56 + 8, dy: 3)
            label(geometry.ghost, "假想球球心", dx: -d / 2 - 8, dy: -14, anchor: .trailing)
            label([-0.48, 0.36], "去吃库点", dx: 14, color: FigureLine.pot(number: 1))
        case .compare:
            if showsIdeal { line([target, geometry.bounce, pocket], .hint) }
            if showsActual { line(targetPath, .pot) }
            ball(cue); ball(target, target: true); label(pocket, "目标中袋", dx: 16)
        case .power, .pocket:
            if showsReference { line(targetPath, .hint) }
            if let shot = current { line(shot.object.map(\.point), .pot) }
            if kind == .power {
                ball(cue); ball(target, target: true); label(pocket, "目标中袋", dx: 16)
                if let shot = current, shot.objectPocket == nil, let stop = shot.object.last?.point {
                    dot(stop)
                    label(stop, "停点", dx: stop.x > 0.8 ? -9 : 9, dy: stop.y > 0.42 ? -13 : 14,
                          anchor: stop.x > 0.8 ? .trailing : .leading)
                }
            } else {
                label([0, -0.76], "目标中袋", dx: 0, anchor: .center)
                if let shot = current, !shot.object.contains(where: { $0.point.y < -0.38 && abs($0.point.x) < 0.4 }) {
                    label([0, -0.53], "当前路线未到中袋附近", dx: 0, anchor: .center)
                }
            }
        case .observe:
            line(targetPath, .pot, opacity: 0.22)
            if let shot = reference, let time = shot.cushionTimes.first {
                line(shot.object.filter { observesAfter ? $0.time >= time : $0.time <= time }.map(\.point), .pot)
            }
            ball(target, target: true); dot(bounce)
            label(bounce, "吃库点", dx: 12, dy: -14); label(pocket, "目标中袋", dx: 16)
        }
    }
}
