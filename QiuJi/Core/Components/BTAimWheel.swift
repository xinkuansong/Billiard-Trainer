import SwiftUI

// MARK: - 自由瞄准角度齿轮（竖向棘轮标尺）

/// 贴球桌右缘的竖向刻度齿轮：拖动微调自由瞄准方向。内容跟手——往上拖刻度上滚、读数递增
/// （= 屏幕顺时针/向右），灵敏度 0.3°/pt（刻度 1:1 随指 ≈3.33pt/°），越过整度给一次轻震。
/// `bearing` 由 `PositionPlayViewModel.freeAimBearingDeg` 喂入（0°=屏幕正上、顺时针增）。
/// 原生于批量出片台（sim-only），P18 B2 下沉共享供编排台自由模式/自由击球/分离角手动瞄准复用。
struct BTAimWheel: View {
    let bearing: Double
    let onNudge: (Float) -> Void

    private let degreesPerPoint: Float = 0.3
    private var pointsPerDegree: CGFloat { CGFloat(1 / degreesPerPoint) }

    @State private var lastHeight: CGFloat = 0
    @State private var lastTick: Int = .min
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let mid = h / 2
            let ppd = pointsPerDegree
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5))

                Canvas { ctx, size in
                    let w = size.width
                    let span = Double(h / ppd)
                    let from = Int((bearing - span / 2 - 2).rounded(.down))
                    let to = Int((bearing + span / 2 + 2).rounded(.up))
                    for d in from...to {
                        let y = mid + CGFloat(Double(d) - bearing) * ppd
                        guard y >= -2, y <= h + 2 else { continue }
                        let norm = ((d % 360) + 360) % 360
                        let isMajor = norm % 10 == 0
                        let isMed = norm % 5 == 0
                        let len: CGFloat = isMajor ? w * 0.5 : (isMed ? w * 0.34 : w * 0.2)
                        var p = Path()
                        p.move(to: CGPoint(x: w - len, y: y))
                        p.addLine(to: CGPoint(x: w - 4, y: y))
                        ctx.stroke(p, with: .color(.white.opacity(isMajor ? 0.85 : (isMed ? 0.5 : 0.28))),
                                   lineWidth: isMajor ? 1.4 : 0.8)
                        if isMajor {
                            let t = Text("\(norm)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            ctx.draw(t, at: CGPoint(x: w - len - 8, y: y), anchor: .trailing)
                        }
                    }
                }

                Rectangle()
                    .fill(Color.btAccent)
                    .frame(height: 1.5)

                Text("\(((Int(bearing.rounded()) % 360) + 360) % 360)°")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.btAccent, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dy = v.translation.height - lastHeight
                        lastHeight = v.translation.height
                        onNudge(Float(-dy) * degreesPerPoint)
                        let t = Int(bearing.rounded())
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
