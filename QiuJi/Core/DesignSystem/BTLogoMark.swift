import SwiftUI

/// 球迹品牌 Logo Mark — 程序化矢量绘制（无 PDF / SVG 依赖）。
///
/// 隐喻："球迹 = 球（圆点）+ 轨迹（弧线）"。
/// - 母球（btPrimary 绿）位于 Mark 左下区域。
/// - 金色（btAccent）轨迹弧线从母球右上切点出发，绕至右上目标点。
/// - 整体内切于一个 1:1 的方形画布，可与 `RoundedRectangle(cornerRadius: 22.37%)` 组合得到 iOS 标准圆角。
///
/// 设计参数集中在 `Geometry` 命名空间，调整时只改这一处即可在所有引用点全局生效。
struct BTLogoMark: View {

    enum Style {
        /// 仅符号本体（透明背景）。用于深色/浅色背景上的 inline 引用、Tab 图标基底。
        case markOnly
        /// 符号 + 圆形品牌色背景圆盘。用于 Onboarding / About 等需要独立呈现的场景。
        case onDisc
        /// 符号 + iOS 圆角方块背景（22.37% radius）。用于 App Icon 草图、设置页的"App Logo" 卡片。
        case onTile
    }

    var size: CGFloat = 100
    var style: Style = .onDisc

    var body: some View {
        ZStack {
            backdrop
            mark
                .padding(size * Geometry.markInset)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("球迹")
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        switch style {
        case .markOnly:
            Color.clear
        case .onDisc:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x1B6B3A),
                            Color(hex: 0x0F4D29)
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
        case .onTile:
            RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x1B6B3A),
                            Color(hex: 0x0F4D29)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Mark Geometry

    private var mark: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let scale = s

            let ballCenter = CGPoint(
                x: Geometry.ballCenter.x * scale,
                y: Geometry.ballCenter.y * scale
            )
            let ballRadius = Geometry.ballRadius * scale

            let targetCenter = CGPoint(
                x: Geometry.targetCenter.x * scale,
                y: Geometry.targetCenter.y * scale
            )
            let targetRadius = Geometry.targetRadius * scale

            drawTrajectory(
                ctx: ctx,
                from: ballCenter,
                ballRadius: ballRadius,
                to: targetCenter,
                targetRadius: targetRadius,
                strokeWidth: Geometry.strokeWidth * scale
            )
            drawCueBall(ctx: ctx, center: ballCenter, radius: ballRadius)
            drawTargetMark(ctx: ctx, center: targetCenter, radius: targetRadius)
        }
    }

    private func drawCueBall(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        switch style {
        case .markOnly:
            ctx.fill(Path(ellipseIn: rect), with: .color(.btPrimary))
        case .onDisc, .onTile:
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hex: 0xFAFAFA),
                        Color(hex: 0xE0E0E0)
                    ]),
                    center: CGPoint(
                        x: center.x - radius * 0.3,
                        y: center.y - radius * 0.3
                    ),
                    startRadius: 0,
                    endRadius: radius * 1.2
                )
            )
            let highlightRadius = radius * 0.3
            let highlightOffset = radius * 0.35
            let highlightRect = CGRect(
                x: center.x - highlightOffset - highlightRadius,
                y: center.y - highlightOffset - highlightRadius,
                width: highlightRadius * 2,
                height: highlightRadius * 2
            )
            ctx.fill(Path(ellipseIn: highlightRect), with: .color(.white.opacity(0.7)))
        }
    }

    private func drawTrajectory(
        ctx: GraphicsContext,
        from ballCenter: CGPoint,
        ballRadius: CGFloat,
        to targetCenter: CGPoint,
        targetRadius: CGFloat,
        strokeWidth: CGFloat
    ) {
        let dx = targetCenter.x - ballCenter.x
        let dy = targetCenter.y - ballCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 0 else { return }

        let unitX = dx / distance
        let unitY = dy / distance

        let start = CGPoint(
            x: ballCenter.x + unitX * (ballRadius + strokeWidth * 0.5),
            y: ballCenter.y + unitY * (ballRadius + strokeWidth * 0.5)
        )
        let end = CGPoint(
            x: targetCenter.x - unitX * (targetRadius + strokeWidth * 0.3),
            y: targetCenter.y - unitY * (targetRadius + strokeWidth * 0.3)
        )

        let perpX = -unitY
        let perpY = unitX
        let bend = distance * 0.32
        let mid = CGPoint(
            x: (start.x + end.x) * 0.5 + perpX * bend,
            y: (start.y + end.y) * 0.5 + perpY * bend
        )

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: mid)

        ctx.stroke(
            path,
            with: .color(.btAccent),
            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
        )
    }

    private func drawTargetMark(ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        ctx.fill(Path(ellipseIn: rect), with: .color(.btAccent))
    }

    // MARK: - Geometry Tokens

    private enum Geometry {
        static let markInset: CGFloat = 0.16

        static let ballCenter = CGPoint(x: 0.32, y: 0.68)
        static let ballRadius: CGFloat = 0.22

        static let targetCenter = CGPoint(x: 0.78, y: 0.26)
        static let targetRadius: CGFloat = 0.07

        static let strokeWidth: CGFloat = 0.085
    }
}

// MARK: - Wordmark

/// 球迹中文字标，搭配 Logo Mark 使用。SF Pro Rounded 同 `btLargeTitle` 字号体系。
struct BTWordmark: View {
    enum Layout {
        case horizontal
        case stacked
    }

    var primary: String = "球迹"
    var secondary: String? = "QiuJi"
    var layout: Layout = .stacked
    var primaryFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    var secondaryFont: Font = .system(size: 13, weight: .medium, design: .rounded).monospacedDigit()
    var primaryColor: Color = .btText
    var secondaryColor: Color = .btTextSecondary

    var body: some View {
        switch layout {
        case .stacked:
            VStack(spacing: 2) {
                Text(primary)
                    .font(primaryFont)
                    .foregroundStyle(primaryColor)
                if let secondary {
                    Text(secondary.uppercased())
                        .font(secondaryFont)
                        .tracking(2)
                        .foregroundStyle(secondaryColor)
                }
            }
        case .horizontal:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(primary)
                    .font(primaryFont)
                    .foregroundStyle(primaryColor)
                if let secondary {
                    Text(secondary)
                        .font(secondaryFont)
                        .foregroundStyle(secondaryColor)
                }
            }
        }
    }
}

// MARK: - Lockup（Logo Mark + Wordmark 组合）

struct BTLogoLockup: View {
    enum Orientation {
        case vertical
        case horizontal
    }

    var size: CGFloat = 80
    var orientation: Orientation = .vertical
    var markStyle: BTLogoMark.Style = .onDisc
    var showSecondaryLabel: Bool = true

    var body: some View {
        switch orientation {
        case .vertical:
            VStack(spacing: 14) {
                BTLogoMark(size: size, style: markStyle)
                BTWordmark(
                    secondary: showSecondaryLabel ? "QiuJi" : nil,
                    layout: .stacked
                )
            }
        case .horizontal:
            HStack(spacing: 12) {
                BTLogoMark(size: size, style: markStyle)
                BTWordmark(
                    secondary: showSecondaryLabel ? "QiuJi" : nil,
                    layout: .stacked,
                    primaryFont: .system(size: size * 0.32, weight: .bold, design: .rounded),
                    secondaryFont: .system(size: size * 0.14, weight: .medium, design: .rounded)
                )
            }
        }
    }
}

#Preview("Logo Mark · 三种 Style") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            VStack {
                BTLogoMark(size: 120, style: .markOnly)
                Text("markOnly").font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            VStack {
                BTLogoMark(size: 120, style: .onDisc)
                Text("onDisc").font(.btCaption).foregroundStyle(.btTextSecondary)
            }
            VStack {
                BTLogoMark(size: 120, style: .onTile)
                Text("onTile").font(.btCaption).foregroundStyle(.btTextSecondary)
            }
        }

        HStack(spacing: 24) {
            BTLogoMark(size: 24, style: .onDisc)
            BTLogoMark(size: 40, style: .onDisc)
            BTLogoMark(size: 64, style: .onDisc)
            BTLogoMark(size: 100, style: .onDisc)
        }

        BTLogoLockup(size: 100, orientation: .vertical, markStyle: .onTile)
        BTLogoLockup(size: 64, orientation: .horizontal, markStyle: .onDisc)
    }
    .padding()
    .background(.btBG)
}

#Preview("Logo Mark · Dark") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            BTLogoMark(size: 120, style: .markOnly)
            BTLogoMark(size: 120, style: .onDisc)
            BTLogoMark(size: 120, style: .onTile)
        }
        BTLogoLockup(size: 100, orientation: .vertical, markStyle: .onTile)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
