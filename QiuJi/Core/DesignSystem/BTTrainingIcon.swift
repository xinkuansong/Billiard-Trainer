import SwiftUI

/// 训练 Tab 自定义图标 — 替代之前的 `dumbbell.fill`（健身哑铃，与台球语义不符）。
///
/// 视觉签名与 `BTLogoMark` 同源："球（圆点）+ 轨迹（弧线）"。
/// - `filled = true`：母球填充，金色轨迹饱和（用于选中态 / 卡片）
/// - `filled = false`：母球描边，轨迹色更淡（用于未选中态 / 浅色背景）
///
/// 通过 `Tab.render(filled:)` 静态方法以 `UIImage` 形式提供给 `Label`，确保 Tab Bar
/// 选中/未选中态的着色行为与系统其它 SF Symbols 一致；选中态会自动叠加 `tintColor`。
struct BTTrainingIcon: View {

    var size: CGFloat = 28
    var filled: Bool = true

    /// 当 Tab Bar 自动着色时使用的"模板"模式 — 单色（白），让系统决定染色。
    /// `false` 时使用品牌色（绿球 + 金弧），适合 inline 卡片场景。
    var asTemplate: Bool = false

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            ctx.translateBy(x: (canvasSize.width - s) * 0.5, y: (canvasSize.height - s) * 0.5)

            let ballCenter = CGPoint(x: 0.32 * s, y: 0.66 * s)
            let ballRadius = 0.21 * s
            let arcStrokeWidth = 0.08 * s

            let arcStart = CGPoint(
                x: ballCenter.x + ballRadius * 0.6,
                y: ballCenter.y - ballRadius * 0.6
            )
            let arcEnd = CGPoint(x: 0.78 * s, y: 0.26 * s)
            let control = CGPoint(x: 0.42 * s, y: 0.18 * s)

            var arc = Path()
            arc.move(to: arcStart)
            arc.addQuadCurve(to: arcEnd, control: control)

            let arcColor: Color = asTemplate ? .white : .btAccent
            ctx.stroke(
                arc,
                with: .color(arcColor),
                style: StrokeStyle(lineWidth: arcStrokeWidth, lineCap: .round)
            )

            let ballRect = CGRect(
                x: ballCenter.x - ballRadius,
                y: ballCenter.y - ballRadius,
                width: ballRadius * 2,
                height: ballRadius * 2
            )
            let ballColor: Color = asTemplate ? .white : .btPrimary
            if filled {
                ctx.fill(Path(ellipseIn: ballRect), with: .color(ballColor))
            } else {
                ctx.stroke(
                    Path(ellipseIn: ballRect),
                    with: .color(ballColor),
                    style: StrokeStyle(lineWidth: arcStrokeWidth)
                )
            }

            let dotRadius = 0.06 * s
            let dotRect = CGRect(
                x: arcEnd.x - dotRadius,
                y: arcEnd.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            ctx.fill(Path(ellipseIn: dotRect), with: .color(arcColor))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("训练")
    }
}

// MARK: - UIKit Bridge for TabView

extension BTTrainingIcon {
    /// 渲染为 `UIImage`，用于 SwiftUI `TabView.tabItem`。
    /// 系统 Tab Bar 期望模板（template）图像 — 输出为白色单色，由系统着色。
    @MainActor
    static func renderForTabBar(filled: Bool, size: CGFloat = 25) -> UIImage? {
        let view = BTTrainingIcon(size: size, filled: filled, asTemplate: true)
            .frame(width: size, height: size)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.withRenderingMode(.alwaysTemplate)
    }
}

#Preview("Training Icon · States") {
    HStack(spacing: 32) {
        VStack {
            BTTrainingIcon(size: 56, filled: false)
            Text("Outline").font(.btCaption)
        }
        VStack {
            BTTrainingIcon(size: 56, filled: true)
            Text("Filled").font(.btCaption)
        }
        VStack {
            BTTrainingIcon(size: 56, filled: true, asTemplate: true)
                .foregroundStyle(.btPrimary)
            Text("Template").font(.btCaption)
        }
    }
    .padding()
    .background(.btBG)
}

#Preview("Training Icon · Tab Bar Sizes") {
    HStack(spacing: 16) {
        BTTrainingIcon(size: 22, filled: false)
        BTTrainingIcon(size: 25, filled: true)
        BTTrainingIcon(size: 28, filled: true)
        BTTrainingIcon(size: 32, filled: true)
    }
    .padding()
    .background(.btBG)
}

#Preview("Dark") {
    HStack(spacing: 32) {
        BTTrainingIcon(size: 56, filled: false)
        BTTrainingIcon(size: 56, filled: true)
    }
    .padding()
    .background(.btBG)
    .preferredColorScheme(.dark)
}
