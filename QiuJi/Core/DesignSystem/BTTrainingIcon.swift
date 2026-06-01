import SwiftUI

/// 训练 Tab 自定义图标 — 替代之前的 `dumbbell.fill`（健身哑铃，与台球语义不符）。
///
/// 台球母题："上方三颗球三角堆（1 顶 + 2 底）+ 下方一根球杆"，比早期「球+轨迹弧」在小尺寸下更易识别。
/// - `filled = true`：球身填充（用于选中态 / 卡片）
/// - `filled = false`：球身描边（用于未选中态 / 浅色背景）
///
/// 通过 `renderForTabBar(filled:)` 静态方法以 `UIImage` 形式提供给 `Label`，确保 Tab Bar
/// 选中/未选中态的着色行为与系统其它 SF Symbols 一致；选中态会自动叠加 `tintColor`。
///
/// 在 ~25pt 单色模板下保持可读：三颗球之间留缝、球杆与球堆之间留缝，避免糊成一团。
struct BTTrainingIcon: View {

    var size: CGFloat = 28
    var filled: Bool = true

    /// 当 Tab Bar 自动着色时使用的"模板"模式 — 单色（白），让系统决定染色。
    /// `false` 时使用品牌色（绿球 + 金杆），适合 inline 卡片场景。
    var asTemplate: Bool = false

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            ctx.translateBy(x: (canvasSize.width - s) * 0.5, y: (canvasSize.height - s) * 0.5)

            let cueColor: Color = asTemplate ? .white : .btAccent
            let ballColor: Color = asTemplate ? .white : .btPrimary

            // 上方三颗球：三角堆（1 顶 + 2 底），球间留缝
            let r = 0.145 * s
            let ballCenters = [
                CGPoint(x: 0.50 * s, y: 0.23 * s),   // 顶
                CGPoint(x: 0.345 * s, y: 0.475 * s), // 左下
                CGPoint(x: 0.655 * s, y: 0.475 * s)  // 右下
            ]
            for center in ballCenters {
                let rect = CGRect(
                    x: center.x - r,
                    y: center.y - r,
                    width: r * 2,
                    height: r * 2
                )
                let path = Path(ellipseIn: rect)
                if filled {
                    ctx.fill(path, with: .color(ballColor))
                } else {
                    ctx.stroke(
                        path,
                        with: .color(ballColor),
                        style: StrokeStyle(lineWidth: 0.07 * s)
                    )
                }
            }

            // 下方球杆：横向略斜，粗（杆尾）→细（杆头）的锥形
            let butt = CGPoint(x: 0.07 * s, y: 0.80 * s)
            let tip = CGPoint(x: 0.93 * s, y: 0.70 * s)
            let buttHalf = 0.062 * s
            let tipHalf = 0.022 * s

            let dx = tip.x - butt.x
            let dy = tip.y - butt.y
            let len = (dx * dx + dy * dy).squareRoot()
            let nx = -dy / len
            let ny = dx / len

            var cue = Path()
            cue.move(to: CGPoint(x: butt.x + nx * buttHalf, y: butt.y + ny * buttHalf))
            cue.addLine(to: CGPoint(x: tip.x + nx * tipHalf, y: tip.y + ny * tipHalf))
            cue.addLine(to: CGPoint(x: tip.x - nx * tipHalf, y: tip.y - ny * tipHalf))
            cue.addLine(to: CGPoint(x: butt.x - nx * buttHalf, y: butt.y - ny * buttHalf))
            cue.closeSubpath()
            ctx.fill(cue, with: .color(cueColor))
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
