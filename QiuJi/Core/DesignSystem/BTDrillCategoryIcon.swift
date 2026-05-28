import SwiftUI

/// 8 个 Drill 分类的统一品牌图标 — 程序化矢量绘制。
///
/// 设计原则：
/// 1. **视觉签名**：每个分类都包含至少一个圆形（球）+ 一段几何元素（轨迹/箭头/刻度），呼应 Logo Mark 的"球+轨迹"主题。
/// 2. **共享参数**：所有图标共用 `Tokens` 命名空间中的描边宽度、球半径、颜色，保证视觉权重 100% 一致。
/// 3. **双态**：`filled = false` 仅描边（用于侧边栏未选中态），`filled = true` 主球填充（用于卡片标题、Section Header）。
/// 4. **品牌色绑定**：球本体用 `btPrimary`，强调元素（轨迹、目标点）用 `btAccent`，无任何硬编码颜色。
///
/// 接入 UI：
/// - `DrillListView` 侧边栏分类项（48×48 区域内 28pt 图标）
/// - 分组 Section Header 前缀（22pt）
/// - StatisticsView 各分类对比（20pt）
struct BTDrillCategoryIcon: View {

    let category: DrillCategory
    var size: CGFloat = 28
    var filled: Bool = true

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            ctx.translateBy(x: (canvasSize.width - s) * 0.5, y: (canvasSize.height - s) * 0.5)

            let env = DrawEnv(
                scale: s,
                strokeWidth: Tokens.strokeWidth * s,
                ballRadius: Tokens.ballRadius * s,
                accentColor: .btAccent,
                primaryColor: .btPrimary,
                filled: filled
            )

            switch category {
            case .fundamentals:  drawFundamentals(ctx: ctx, env: env)
            case .accuracy:      drawAccuracy(ctx: ctx, env: env)
            case .cueAction:     drawCueAction(ctx: ctx, env: env)
            case .separation:    drawSeparation(ctx: ctx, env: env)
            case .positioning:   drawPositioning(ctx: ctx, env: env)
            case .forceControl:  drawForceControl(ctx: ctx, env: env)
            case .specialShots:  drawSpecialShots(ctx: ctx, env: env)
            case .combined:      drawCombined(ctx: ctx, env: env)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(category.nameZh)
    }

    // MARK: - Shared Parameters

    private struct DrawEnv {
        let scale: CGFloat
        let strokeWidth: CGFloat
        let ballRadius: CGFloat
        let accentColor: Color
        let primaryColor: Color
        let filled: Bool
    }

    private enum Tokens {
        static let strokeWidth: CGFloat = 0.075
        static let ballRadius: CGFloat = 0.16
    }

    // MARK: - Drawing Helpers

    private func drawBall(ctx: GraphicsContext, env: DrawEnv,
                          center: CGPoint, radius: CGFloat,
                          color: Color, filled: Bool? = nil) {
        let isFilled = filled ?? env.filled
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        if isFilled {
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        } else {
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(color),
                style: StrokeStyle(lineWidth: env.strokeWidth)
            )
        }
    }

    private func strokeStyle(_ env: DrawEnv, lineWidth: CGFloat? = nil) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth ?? env.strokeWidth, lineCap: .round, lineJoin: .round)
    }

    // MARK: - 1. Fundamentals (基础功)
    // 一个母球 + 标准击打十字（瞄准基础）

    private func drawFundamentals(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let center = CGPoint(x: 0.5 * s, y: 0.55 * s)
        let r = env.ballRadius * s * 1.4

        drawBall(ctx: ctx, env: env, center: center, radius: r, color: env.primaryColor)

        let crossLength = r * 0.55
        var hLine = Path()
        hLine.move(to: CGPoint(x: center.x - crossLength, y: center.y))
        hLine.addLine(to: CGPoint(x: center.x + crossLength, y: center.y))
        var vLine = Path()
        vLine.move(to: CGPoint(x: center.x, y: center.y - crossLength))
        vLine.addLine(to: CGPoint(x: center.x, y: center.y + crossLength))

        let crossColor: Color = env.filled ? .white : env.accentColor
        ctx.stroke(hLine, with: .color(crossColor), style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85))
        ctx.stroke(vLine, with: .color(crossColor), style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85))

        let dotR = r * 0.18
        let dotRect = CGRect(
            x: center.x - dotR, y: center.y - dotR,
            width: dotR * 2, height: dotR * 2
        )
        ctx.fill(Path(ellipseIn: dotRect), with: .color(env.accentColor))

        var floor = Path()
        floor.move(to: CGPoint(x: 0.18 * s, y: 0.85 * s))
        floor.addLine(to: CGPoint(x: 0.82 * s, y: 0.85 * s))
        ctx.stroke(floor, with: .color(env.primaryColor.opacity(0.4)),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.75))
    }

    // MARK: - 2. Accuracy (准度训练)
    // 圆形靶心嵌套 + 中心命中点

    private func drawAccuracy(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let center = CGPoint(x: 0.5 * s, y: 0.5 * s)

        let outerR = 0.36 * s
        let middleR = 0.24 * s
        let innerR = 0.12 * s

        ctx.stroke(
            Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR,
                                   width: outerR * 2, height: outerR * 2)),
            with: .color(env.primaryColor),
            style: strokeStyle(env)
        )
        ctx.stroke(
            Path(ellipseIn: CGRect(x: center.x - middleR, y: center.y - middleR,
                                   width: middleR * 2, height: middleR * 2)),
            with: .color(env.primaryColor.opacity(0.7)),
            style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85)
        )
        if env.filled {
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR,
                                       width: innerR * 2, height: innerR * 2)),
                with: .color(env.accentColor)
            )
        } else {
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR,
                                       width: innerR * 2, height: innerR * 2)),
                with: .color(env.accentColor),
                style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85)
            )
        }

        let cross = innerR * 1.55
        var v = Path()
        v.move(to: CGPoint(x: center.x, y: center.y - cross))
        v.addLine(to: CGPoint(x: center.x, y: center.y - innerR * 1.05))
        v.move(to: CGPoint(x: center.x, y: center.y + innerR * 1.05))
        v.addLine(to: CGPoint(x: center.x, y: center.y + cross))
        var h = Path()
        h.move(to: CGPoint(x: center.x - cross, y: center.y))
        h.addLine(to: CGPoint(x: center.x - innerR * 1.05, y: center.y))
        h.move(to: CGPoint(x: center.x + innerR * 1.05, y: center.y))
        h.addLine(to: CGPoint(x: center.x + cross, y: center.y))
        ctx.stroke(v, with: .color(env.accentColor), style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7))
        ctx.stroke(h, with: .color(env.accentColor), style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7))
    }

    // MARK: - 3. CueAction (杆法训练)
    // 母球正面 + 三个击打点（高/中/低）

    private func drawCueAction(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let center = CGPoint(x: 0.5 * s, y: 0.5 * s)
        let r = 0.34 * s

        if env.filled {
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(env.primaryColor)
            )
        } else {
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(env.primaryColor),
                style: strokeStyle(env)
            )
        }

        let dotR = r * 0.16
        let dotOffset = r * 0.5
        let dotColor: Color = env.filled ? env.accentColor : env.accentColor

        for offsetY in [-dotOffset, 0, dotOffset] {
            let dotCenter = CGPoint(x: center.x, y: center.y + offsetY)
            let rect = CGRect(x: dotCenter.x - dotR, y: dotCenter.y - dotR,
                              width: dotR * 2, height: dotR * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
        }

        let arrowLen = r * 0.32
        let arrowStart = CGPoint(x: center.x + r + env.strokeWidth, y: center.y)
        var arrow = Path()
        arrow.move(to: arrowStart)
        arrow.addLine(to: CGPoint(x: arrowStart.x + arrowLen, y: center.y))
        arrow.move(to: CGPoint(x: arrowStart.x + arrowLen - env.strokeWidth, y: center.y - env.strokeWidth))
        arrow.addLine(to: CGPoint(x: arrowStart.x + arrowLen, y: center.y))
        arrow.addLine(to: CGPoint(x: arrowStart.x + arrowLen - env.strokeWidth, y: center.y + env.strokeWidth))
        ctx.stroke(arrow, with: .color(env.accentColor),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.75))
    }

    // MARK: - 4. Separation (分离角)
    // 两个相切的圆 + 90° 分离角 V 型路径

    private func drawSeparation(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r: CGFloat = 0.16 * s

        let cueCenter = CGPoint(x: 0.32 * s, y: 0.5 * s)
        let targetCenter = CGPoint(x: 0.32 * s + r * 2 + env.strokeWidth * 0.5, y: 0.5 * s)

        let lineLen: CGFloat = 0.32 * s
        let angle: CGFloat = .pi / 4
        let cosA: CGFloat = cos(angle)
        let sinA: CGFloat = sin(angle)
        let supplementCos: CGFloat = cos(.pi - angle)
        let supplementSin: CGFloat = sin(.pi - angle)

        var cuePath = Path()
        cuePath.move(to: cueCenter)
        cuePath.addLine(to: CGPoint(
            x: cueCenter.x + supplementCos * lineLen * 0.6,
            y: cueCenter.y + supplementSin * -lineLen * 0.6 - lineLen * 0.6
        ))
        ctx.stroke(cuePath, with: .color(env.primaryColor.opacity(0.6)),
                   style: StrokeStyle(lineWidth: env.strokeWidth * 0.7,
                                      lineCap: .round, dash: [env.strokeWidth, env.strokeWidth * 1.2]))

        var targetPath = Path()
        targetPath.move(to: targetCenter)
        targetPath.addLine(to: CGPoint(
            x: targetCenter.x + cosA * lineLen,
            y: targetCenter.y - sinA * lineLen + lineLen * 0.1
        ))
        ctx.stroke(targetPath, with: .color(env.accentColor),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85))

        var cueOutPath = Path()
        cueOutPath.move(to: cueCenter)
        cueOutPath.addLine(to: CGPoint(
            x: cueCenter.x - cosA * lineLen * 0.7,
            y: cueCenter.y + sinA * lineLen * 0.7
        ))
        ctx.stroke(cueOutPath, with: .color(env.accentColor.opacity(0.8)),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7))

        drawBall(ctx: ctx, env: env, center: cueCenter, radius: r, color: env.primaryColor)
        drawBall(ctx: ctx, env: env, center: targetCenter, radius: r,
                 color: env.primaryColor.opacity(0.5),
                 filled: env.filled)
    }

    // MARK: - 5. Positioning (走位训练)
    // 母球 + 多段折线轨迹（撞击库边后回到目标位置）

    private func drawPositioning(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r = 0.14 * s

        let p1 = CGPoint(x: 0.22 * s, y: 0.72 * s)
        let p2 = CGPoint(x: 0.62 * s, y: 0.28 * s)
        let p3 = CGPoint(x: 0.86 * s, y: 0.42 * s)
        let p4 = CGPoint(x: 0.62 * s, y: 0.78 * s)

        var path = Path()
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.addLine(to: p4)
        ctx.stroke(path, with: .color(env.accentColor),
                   style: StrokeStyle(lineWidth: env.strokeWidth * 0.85,
                                      lineCap: .round, lineJoin: .round,
                                      dash: [env.strokeWidth * 1.6, env.strokeWidth * 1.0]))

        let bounceR = env.strokeWidth * 0.55
        for bounce in [p2, p3] {
            let rect = CGRect(x: bounce.x - bounceR, y: bounce.y - bounceR,
                              width: bounceR * 2, height: bounceR * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(env.accentColor))
        }

        drawBall(ctx: ctx, env: env, center: p1, radius: r, color: env.primaryColor)

        let endR = r * 0.65
        if env.filled {
            ctx.fill(
                Path(ellipseIn: CGRect(x: p4.x - endR, y: p4.y - endR,
                                       width: endR * 2, height: endR * 2)),
                with: .color(env.primaryColor.opacity(0.4))
            )
        }
        ctx.stroke(
            Path(ellipseIn: CGRect(x: p4.x - endR, y: p4.y - endR,
                                   width: endR * 2, height: endR * 2)),
            with: .color(env.accentColor),
            style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7)
        )
    }

    // MARK: - 6. ForceControl (控力训练)
    // 母球 + 力度刻度弧（半圆仪表）

    private func drawForceControl(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let center = CGPoint(x: 0.5 * s, y: 0.65 * s)
        let arcR: CGFloat = 0.34 * s

        var arc = Path()
        arc.addArc(center: center, radius: arcR,
                   startAngle: .degrees(180), endAngle: .degrees(360),
                   clockwise: false)
        ctx.stroke(arc, with: .color(env.primaryColor),
                   style: strokeStyle(env))

        for i in 0...4 {
            let angle: CGFloat = .pi * (1.0 + CGFloat(i) / 4.0)
            let cosA: CGFloat = cos(angle)
            let sinA: CGFloat = sin(angle)
            let outer = CGPoint(
                x: center.x + cosA * arcR,
                y: center.y + sinA * arcR
            )
            let inner = CGPoint(
                x: center.x + cosA * (arcR - env.strokeWidth * 1.4),
                y: center.y + sinA * (arcR - env.strokeWidth * 1.4)
            )
            var tick = Path()
            tick.move(to: outer)
            tick.addLine(to: inner)
            ctx.stroke(tick, with: .color(env.primaryColor.opacity(0.7)),
                       style: strokeStyle(env, lineWidth: env.strokeWidth * 0.75))
        }

        let needleAngle: CGFloat = .pi * 1.65
        let needleCos: CGFloat = cos(needleAngle)
        let needleSin: CGFloat = sin(needleAngle)
        let needleEnd = CGPoint(
            x: center.x + needleCos * arcR * 0.85,
            y: center.y + needleSin * arcR * 0.85
        )
        var needle = Path()
        needle.move(to: center)
        needle.addLine(to: needleEnd)
        ctx.stroke(needle, with: .color(env.accentColor),
                   style: strokeStyle(env))

        let pivotR = env.strokeWidth * 0.7
        let pivotRect = CGRect(x: center.x - pivotR, y: center.y - pivotR,
                               width: pivotR * 2, height: pivotR * 2)
        ctx.fill(Path(ellipseIn: pivotRect), with: .color(env.accentColor))
    }

    // MARK: - 7. SpecialShots (特殊球路)
    // 母球 + 旋转弧线（速度线，表示加塞旋转）

    private func drawSpecialShots(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let center = CGPoint(x: 0.55 * s, y: 0.5 * s)
        let r: CGFloat = 0.22 * s

        drawBall(ctx: ctx, env: env, center: center, radius: r, color: env.primaryColor)

        var spinArc = Path()
        spinArc.addArc(center: center, radius: r * 1.55,
                       startAngle: .degrees(-50), endAngle: .degrees(60),
                       clockwise: false)
        ctx.stroke(spinArc, with: .color(env.accentColor),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85))

        let arrowAngle: CGFloat = .pi / 180 * 60
        let arrowCos: CGFloat = cos(arrowAngle)
        let arrowSin: CGFloat = sin(arrowAngle)
        let arrowTip = CGPoint(
            x: center.x + arrowCos * r * 1.55,
            y: center.y + arrowSin * r * 1.55
        )
        let arrowSize: CGFloat = env.strokeWidth * 1.2
        let lowerAngle: CGFloat = arrowAngle - .pi / 2 - .pi / 6
        let upperAngle: CGFloat = arrowAngle - .pi / 2 + .pi / 6
        let lowerCos: CGFloat = cos(lowerAngle)
        let lowerSin: CGFloat = sin(lowerAngle)
        let upperCos: CGFloat = cos(upperAngle)
        let upperSin: CGFloat = sin(upperAngle)
        var arrowHead = Path()
        arrowHead.move(to: arrowTip)
        arrowHead.addLine(to: CGPoint(
            x: arrowTip.x - lowerCos * arrowSize,
            y: arrowTip.y - lowerSin * arrowSize
        ))
        arrowHead.move(to: arrowTip)
        arrowHead.addLine(to: CGPoint(
            x: arrowTip.x - upperCos * arrowSize,
            y: arrowTip.y - upperSin * arrowSize
        ))
        ctx.stroke(arrowHead, with: .color(env.accentColor),
                   style: strokeStyle(env, lineWidth: env.strokeWidth * 0.85))

        let speedColor: Color = env.accentColor.opacity(0.8)
        for i in 0..<3 {
            let xOff = -r * 0.55 - CGFloat(i) * env.strokeWidth * 1.4
            let len = r * (0.45 - CGFloat(i) * 0.08)
            let yOff = -r * 0.35 + CGFloat(i) * r * 0.35
            var line = Path()
            line.move(to: CGPoint(x: center.x + xOff, y: center.y + yOff))
            line.addLine(to: CGPoint(x: center.x + xOff - len, y: center.y + yOff))
            ctx.stroke(line, with: .color(speedColor),
                       style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7))
        }
    }

    // MARK: - 8. Combined (综合球形)
    // 3×3 球阵（每个圆点表示一个球）

    private func drawCombined(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r = 0.085 * s
        let spacing = 0.255 * s
        let origin = CGPoint(x: 0.5 * s - spacing, y: 0.5 * s - spacing)

        for row in 0..<3 {
            for col in 0..<3 {
                let center = CGPoint(
                    x: origin.x + CGFloat(col) * spacing,
                    y: origin.y + CGFloat(row) * spacing
                )
                let isHighlight = (row == 1 && col == 1)
                    || (row == 0 && col == 2)
                    || (row == 2 && col == 0)

                let color: Color = isHighlight ? env.accentColor : env.primaryColor
                let rect = CGRect(x: center.x - r, y: center.y - r,
                                  width: r * 2, height: r * 2)

                if env.filled || isHighlight {
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                } else {
                    ctx.stroke(Path(ellipseIn: rect),
                               with: .color(color),
                               style: strokeStyle(env, lineWidth: env.strokeWidth * 0.7))
                }
            }
        }
    }
}

#Preview("All Categories · Filled") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 8) {
                    BTDrillCategoryIcon(category: category, size: 56, filled: true)
                        .padding(12)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    Text(category.nameZh)
                        .font(.btCaption)
                        .foregroundStyle(.btText)
                }
            }
        }
        .padding()
    }
    .background(.btBG)
}

#Preview("All Categories · Outline") {
    ScrollView {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 8) {
                    BTDrillCategoryIcon(category: category, size: 56, filled: false)
                        .padding(12)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    Text(category.nameZh)
                        .font(.btCaption)
                        .foregroundStyle(.btText)
                }
            }
        }
        .padding()
    }
    .background(.btBG)
}

#Preview("Sidebar Sample") {
    HStack {
        VStack(spacing: 0) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 4) {
                    BTDrillCategoryIcon(category: category, size: 24, filled: false)
                    Text(category.nameZh)
                        .font(.btCaption2)
                        .foregroundStyle(.btTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 72, height: 56)
            }
        }
        .background(Color.btBGSecondary)
        Spacer()
    }
    .background(.btBG)
}

#Preview("Dark") {
    LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 16
    ) {
        ForEach(DrillCategory.allCases) { category in
            VStack {
                BTDrillCategoryIcon(category: category, size: 56)
                Text(category.nameZh).font(.btCaption)
            }
            .padding()
            .background(.btBGSecondary)
            .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
        }
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
