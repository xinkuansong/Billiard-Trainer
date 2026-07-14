import SwiftUI

// MARK: - 自由瞄准角度齿轮（竖向棘轮标尺）

/// 贴球桌左缘的竖向刻度齿轮：拖动微调自由瞄准方向（控件瘦身 v2，问题集合条 13.1）。
///
/// **纯相对微调**——无绝对角度概念（去 bearing 刻度锚定）：手指滑屏是粗调、
/// 这里是细调，刻度只是「转了多少」的手感反馈，不代表任何绝对方位。
/// 内容跟手——往上拖刻度上滚（= 屏幕顺时针/向右），灵敏度 0.15°/pt（比旧 0.3 减半，
/// 细调更稳），越过整度给一次轻震。
///
/// T-P18-43（设计稿 §1.5/§1.7 刻度语法）：**只画刻度不画数值**——打点精确到毫米级，
/// 用户看的是台面上的瞄准效果不是数字；三级刻度 1°/5°/10° = 白 15/25/40%，当前位置金线。
struct BTAimWheel: View {
    let onNudge: (Float) -> Void

    private let degreesPerPoint: Float = 0.15
    private var pointsPerDegree: CGFloat { CGFloat(1 / degreesPerPoint) }

    /// 相对累计转量（度），只用于刻度滚动的视觉反馈。
    @State private var accumulated: Double = 0
    @State private var lastHeight: CGFloat = 0
    @State private var lastTick: Int = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let mid = h / 2
            let ppd = pointsPerDegree
            ZStack {
                RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                    .fill(HUDStyle.glassTint)
                    .overlay(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous)
                        .stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))

                Canvas { ctx, size in
                    let w = size.width
                    let span = Double(h / ppd)
                    let from = Int((accumulated - span / 2 - 2).rounded(.down))
                    let to = Int((accumulated + span / 2 + 2).rounded(.up))
                    for d in from...to {
                        let y = mid + CGFloat(Double(d) - accumulated) * ppd
                        guard y >= -2, y <= h + 2 else { continue }
                        let norm = ((d % 360) + 360) % 360
                        let isMajor = norm % 10 == 0
                        let isMed = norm % 5 == 0
                        // 刻度语法（§1.7）：三级刻度线居中横排，白 40 / 25 / 15%，无数值。
                        let len: CGFloat = isMajor ? w * 0.62 : (isMed ? w * 0.42 : w * 0.26)
                        var p = Path()
                        p.move(to: CGPoint(x: (w - len) / 2, y: y))
                        p.addLine(to: CGPoint(x: (w + len) / 2, y: y))
                        ctx.stroke(p, with: .color(HUDStyle.tickColor(major: isMajor, mid: isMed)),
                                   lineWidth: isMajor ? 1.4 : 0.8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: HUDStyle.rulerCornerRadius, style: .continuous))

                // 当前位置指示 = 金色短线（§1.7 刻度语法）。
                Rectangle()
                    .fill(HUDStyle.tickIndicator)
                    .frame(height: 1.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dy = v.translation.height - lastHeight
                        lastHeight = v.translation.height
                        let delta = Float(-dy) * degreesPerPoint
                        onNudge(delta)
                        accumulated += Double(delta)
                        let t = Int(accumulated.rounded())
                        if t != lastTick {
                            haptic.impactOccurred(intensity: 0.5)
                            lastTick = t
                        }
                    }
                    .onEnded { _ in lastHeight = 0 }
            )
        }
    }
}

// MARK: - Thickness Overlap Icon

/// 用两个等大圆形错位重叠表示"厚度"：
/// 在击球瞬间，沿瞄准方向看，目标球与白球的中心横向偏移量为 `2R · sin(α)`。
/// 把它直接映射到画布即可：α 越小重叠越多（"厚"），α 越大错位越多（"薄"）。
/// 原生于角度与打点页（private），P18 B2 下沉共享并参数化尺寸。
struct ThicknessOverlapIcon: View {
    /// 切球角，单位：度。
    let cutAngle: Double
    /// 图标尺寸（宽:高 ≈ 2:1 视觉最佳）。
    var size: CGSize = CGSize(width: 26, height: 14)

    var body: some View {
        Canvas { ctx, canvasSize in
            // 单球半径选择：让最大错位（α=90°，offset=2R）时两球刚好首尾相接、不出画布。
            // 因此 r = size.width / 4。再做一次 0.96 收缩留 1px 描边的余量。
            let r = (canvasSize.width / 4) * 0.96
            let centerY = canvasSize.height / 2

            let alphaRad = max(0, min(90, cutAngle)) * .pi / 180
            let offset = CGFloat(2 * r * sin(alphaRad))  // 球心横向偏移量

            // 让两个球关于画布中心对称错开：目标球居左、白球居右。
            let targetCenter = CGPoint(x: canvasSize.width / 2 - offset / 2, y: centerY)
            let cueCenter    = CGPoint(x: canvasSize.width / 2 + offset / 2, y: centerY)

            // 目标球（暖色）：实心 + 描边
            let targetRect = CGRect(x: targetCenter.x - r, y: targetCenter.y - r,
                                    width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: targetRect),
                     with: .color(Color(red: 0.96, green: 0.65, blue: 0.14)))
            ctx.stroke(Path(ellipseIn: targetRect),
                       with: .color(.white.opacity(0.5)), lineWidth: 0.5)

            // 白球：实心白 + 微弱描边，覆盖在目标球之上以呈现"被遮挡"的厚度
            let cueRect = CGRect(x: cueCenter.x - r, y: cueCenter.y - r,
                                 width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: cueRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: cueRect),
                       with: .color(.white.opacity(0.6)), lineWidth: 0.5)
        }
        .frame(width: size.width, height: size.height)
    }
}
