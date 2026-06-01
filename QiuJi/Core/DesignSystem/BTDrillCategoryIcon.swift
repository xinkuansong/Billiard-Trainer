import SwiftUI

/// 8 个 Drill 分类的统一品牌图标 — 程序化矢量绘制。
///
/// ### 统一设计系统（阶段 B 重做，UR-20260601-IconSystem）
/// 1. **双线宽**：所有描边只用 `env.stroke`（主）与 `env.strokeThin`（次），统一 round cap/join，杜绝散落的 0.7/0.85 系数。
/// 2. **标准球半径**：出现"母球"的图标统一用 `env.ballR`，视觉权重一致。
/// 3. **单一强调**：每个图标恰好一个金色（`btAccent`）元素，其余为品牌绿（`btPrimary`）；绿在金之前绘制，金永远在最上层、保证小尺寸可读。
/// 4. **双态**：`filled=false` 描边（侧栏未选中）；`filled=true` 主体填充（选中 / Section Header）。金色元素两态一致。
///
/// 接入：侧栏分类（22pt）、Section Header（22pt）、统计页（20pt）。
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
                stroke: Tokens.stroke * s,
                strokeThin: Tokens.strokeThin * s,
                ballR: Tokens.ball * s,
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
        let stroke: CGFloat
        let strokeThin: CGFloat
        let ballR: CGFloat
        let accentColor: Color
        let primaryColor: Color
        let filled: Bool
    }

    private enum Tokens {
        static let stroke: CGFloat = 0.085
        static let strokeThin: CGFloat = 0.06
        static let ball: CGFloat = 0.17
    }

    // MARK: - Drawing Helpers

    private func style(_ w: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    }

    private func rect(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
    }

    /// 画一个球：`filled` 缺省随 env.filled；金色球建议显式传 filled: true。
    private func drawBall(_ ctx: GraphicsContext, _ env: DrawEnv,
                          center: CGPoint, radius: CGFloat,
                          color: Color, filled: Bool? = nil) {
        let isFilled = filled ?? env.filled
        let path = Path(ellipseIn: rect(center, radius))
        if isFilled {
            ctx.fill(path, with: .color(color))
        } else {
            ctx.stroke(path, with: .color(color), style: style(env.stroke))
        }
    }

    private func ring(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat,
                      color: Color, width: CGFloat) {
        ctx.stroke(Path(ellipseIn: rect(center, radius)), with: .color(color), style: style(width))
    }

    private func dot(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: rect(center, radius)), with: .color(color))
    }

    private func line(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint,
                      color: Color, width: CGFloat, dash: [CGFloat] = []) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(p, with: .color(color),
                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    // MARK: - 1. Fundamentals (基础功) — 母球 + 瞄准十字
    private func drawFundamentals(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let c = CGPoint(x: 0.5 * s, y: 0.5 * s)
        let r = env.ballR * 1.25

        drawBall(ctx, env, center: c, radius: r, color: env.primaryColor)

        // 金色瞄准十字：四向短刻度，伸出球体之外
        let inner = r * 0.45
        let outer = r * 1.55
        for (dx, dy): (CGFloat, CGFloat) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
            line(ctx,
                 CGPoint(x: c.x + dx * inner, y: c.y + dy * inner),
                 CGPoint(x: c.x + dx * outer, y: c.y + dy * outer),
                 color: env.accentColor, width: env.strokeThin)
        }
        dot(ctx, center: c, radius: r * 0.22, color: env.accentColor)
    }

    // MARK: - 2. Accuracy (准度训练) — 同心靶环 + 命中点
    private func drawAccuracy(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let c = CGPoint(x: 0.5 * s, y: 0.5 * s)

        ring(ctx, center: c, radius: 0.36 * s, color: env.primaryColor, width: env.stroke)
        ring(ctx, center: c, radius: 0.21 * s, color: env.primaryColor, width: env.strokeThin)
        dot(ctx, center: c, radius: 0.085 * s, color: env.accentColor)
    }

    // MARK: - 3. CueAction (杆法训练) — 母球 + 高/中/低三击点
    private func drawCueAction(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let c = CGPoint(x: 0.5 * s, y: 0.5 * s)
        let r = env.ballR * 1.45

        drawBall(ctx, env, center: c, radius: r, color: env.primaryColor)

        let dotR = r * 0.16
        let off = r * 0.5
        let plainColor: Color = env.filled ? .white : env.primaryColor
        dot(ctx, center: CGPoint(x: c.x, y: c.y - off), radius: dotR, color: plainColor)
        dot(ctx, center: CGPoint(x: c.x, y: c.y),       radius: dotR, color: env.accentColor)
        dot(ctx, center: CGPoint(x: c.x, y: c.y + off), radius: dotR, color: plainColor)
    }

    // MARK: - 4. Separation (分离角) — 两球相切 + 90° 分离 V
    private func drawSeparation(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r = env.ballR * 0.92
        let cue = CGPoint(x: 0.34 * s, y: 0.62 * s)
        let obj = CGPoint(x: cue.x + r * 2 + env.stroke * 0.3, y: cue.y)
        let len: CGFloat = 0.34 * s

        // 金色 90° 分离角：目标球前进（右上 45°）+ 母球切线（左上 45°）
        line(ctx, obj, CGPoint(x: obj.x + len * 0.7071, y: obj.y - len * 0.7071),
             color: env.accentColor, width: env.strokeThin)
        line(ctx, cue, CGPoint(x: cue.x - len * 0.55 * 0.7071, y: cue.y - len * 0.55 * 0.7071),
             color: env.accentColor, width: env.strokeThin)

        drawBall(ctx, env, center: cue, radius: r, color: env.primaryColor)
        drawBall(ctx, env, center: obj, radius: r, color: env.primaryColor)
    }

    // MARK: - 5. Positioning (走位训练) — 母球 + 折线走位 + 目标环
    private func drawPositioning(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r = env.ballR * 0.8
        let start = CGPoint(x: 0.24 * s, y: 0.34 * s)
        let bounce = CGPoint(x: 0.8 * s, y: 0.42 * s)
        let target = CGPoint(x: 0.46 * s, y: 0.78 * s)
        let dash: [CGFloat] = [env.stroke * 1.4, env.stroke]

        line(ctx, start, bounce, color: env.accentColor, width: env.strokeThin, dash: dash)
        line(ctx, bounce, target, color: env.accentColor, width: env.strokeThin, dash: dash)
        dot(ctx, center: bounce, radius: env.stroke * 0.55, color: env.accentColor)

        drawBall(ctx, env, center: start, radius: r, color: env.primaryColor)
        ring(ctx, center: target, radius: r * 0.85, color: env.accentColor, width: env.strokeThin)
    }

    // MARK: - 6. ForceControl (控力训练) — 力度仪表弧 + 指针
    private func drawForceControl(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let c = CGPoint(x: 0.5 * s, y: 0.64 * s)
        let arcR: CGFloat = 0.34 * s

        var arc = Path()
        arc.addArc(center: c, radius: arcR, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        ctx.stroke(arc, with: .color(env.primaryColor), style: style(env.stroke))

        for i in 0...4 {
            let a: CGFloat = .pi * (1.0 + CGFloat(i) / 4.0)
            let outer = CGPoint(x: c.x + cos(a) * arcR, y: c.y + sin(a) * arcR)
            let inner = CGPoint(x: c.x + cos(a) * (arcR - env.stroke * 1.3),
                                y: c.y + sin(a) * (arcR - env.stroke * 1.3))
            line(ctx, outer, inner, color: env.primaryColor.opacity(0.6), width: env.strokeThin)
        }

        let needleA: CGFloat = .pi * 1.68
        line(ctx, c, CGPoint(x: c.x + cos(needleA) * arcR * 0.82, y: c.y + sin(needleA) * arcR * 0.82),
             color: env.accentColor, width: env.stroke)
        dot(ctx, center: c, radius: env.stroke * 0.7, color: env.accentColor)
    }

    // MARK: - 7. SpecialShots (特殊球路) — 母球 + 旋转弧箭头
    private func drawSpecialShots(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let c = CGPoint(x: 0.46 * s, y: 0.54 * s)
        let r = env.ballR * 1.15

        drawBall(ctx, env, center: c, radius: r, color: env.primaryColor)

        let spinR = r * 1.7
        var arc = Path()
        arc.addArc(center: c, radius: spinR, startAngle: .degrees(-40), endAngle: .degrees(70), clockwise: false)
        ctx.stroke(arc, with: .color(env.accentColor), style: style(env.strokeThin))

        // 箭头（在弧线 70° 端，沿切线方向）
        let tipA: CGFloat = .pi / 180.0 * 70.0
        let tip = CGPoint(x: c.x + cos(tipA) * spinR, y: c.y + sin(tipA) * spinR)
        let head: CGFloat = env.stroke * 1.4
        let spread: CGFloat = .pi / 7.0
        let ang1: CGFloat = tipA - (.pi / 2.0 + spread)
        let ang2: CGFloat = tipA - (.pi / 2.0 - spread)
        line(ctx, tip, CGPoint(x: tip.x + cos(ang1) * head, y: tip.y + sin(ang1) * head),
             color: env.accentColor, width: env.strokeThin)
        line(ctx, tip, CGPoint(x: tip.x + cos(ang2) * head, y: tip.y + sin(ang2) * head),
             color: env.accentColor, width: env.strokeThin)
    }

    // MARK: - 8. Combined (综合球形) — 6 球三角摆位（rack）
    private func drawCombined(ctx: GraphicsContext, env: DrawEnv) {
        let s = env.scale
        let r: CGFloat = 0.1 * s
        let dx: CGFloat = r * 2 + env.stroke * 0.3
        let dy: CGFloat = dx * 0.88
        let ax: CGFloat = 0.5 * s
        let ay: CGFloat = 0.24 * s

        var centers: [CGPoint] = []
        centers.append(CGPoint(x: ax, y: ay))
        centers.append(CGPoint(x: ax - dx * 0.5, y: ay + dy))
        centers.append(CGPoint(x: ax + dx * 0.5, y: ay + dy))
        centers.append(CGPoint(x: ax - dx, y: ay + dy * 2))
        centers.append(CGPoint(x: ax, y: ay + dy * 2))
        centers.append(CGPoint(x: ax + dx, y: ay + dy * 2))

        for (i, c) in centers.enumerated() {
            if i == 0 {
                drawBall(ctx, env, center: c, radius: r, color: env.accentColor, filled: true)
            } else {
                drawBall(ctx, env, center: c, radius: r, color: env.primaryColor)
            }
        }
    }
}

#Preview("All Categories · Filled") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 8) {
                    BTDrillCategoryIcon(category: category, size: 56, filled: true)
                        .padding(12)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    Text(category.nameZh).font(.btCaption).foregroundStyle(.btText)
                }
            }
        }
        .padding()
    }
    .background(.btBG)
}

#Preview("All Categories · Outline") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 8) {
                    BTDrillCategoryIcon(category: category, size: 56, filled: false)
                        .padding(12)
                        .background(Color.btBGSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
                    Text(category.nameZh).font(.btCaption).foregroundStyle(.btText)
                }
            }
        }
        .padding()
    }
    .background(.btBG)
}

#Preview("Sidebar @22") {
    HStack {
        VStack(spacing: 0) {
            ForEach(DrillCategory.allCases) { category in
                VStack(spacing: 4) {
                    BTDrillCategoryIcon(category: category, size: 22, filled: false)
                    Text(category.nameZh)
                        .font(.btCaption2).foregroundStyle(.btTextSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
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
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
