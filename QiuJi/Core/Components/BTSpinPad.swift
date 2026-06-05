import SwiftUI

/// 打点盘（可复用）：按真实物理比例画母球正面 + 打滑极限圈 + 皮头接触斑，拖动选择真实击球点。
///
/// 绑定的 `spinX/spinY` 存的是**真实接触点偏移/R**（= pooltool a,b，喂物理）：
/// - `spinX` 正 = 左塞（屏幕左）/ 负 = 右塞；`spinY` 正 = 高杆（屏幕上）/ 负 = 低杆。
/// - 皮头中心摆放 → 接触点经曲率拉心系数 `CuePhysics.tipContactPullFactor` 换算。
/// - 接触点偏移钳在 `CuePhysics.miscueLimitFraction`(0.5R)，超出即打滑（拖不出去）。
///
/// 与 `ShotSimulationView` 内的私有打点盘同源；抽出供走位编排器/训练页复用。
struct BTSpinPad: View {
    @Binding var spinX: Double
    @Binding var spinY: Double

    private let miscue = Double(CuePhysics.miscueLimitFraction)
    private let tipRatio = Double(CuePhysics.tipDiameter / BallPhysics.diameter)
    private let pull = Double(CuePhysics.tipContactPullFactor)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2, cy = geo.size.height / 2
            let inset: CGFloat = 5
            let ballR = size / 2 - inset
            let placementLimit = miscue / pull
            let placeX = spinX / pull, placeY = spinY / pull
            let dot = CGPoint(x: cx - CGFloat(placeX) * ballR,
                              y: cy - CGFloat(placeY) * ballR)
            let tipD = max(ballR * 2 * CGFloat(tipRatio), 8)
            let miscueR = ballR * CGFloat(placementLimit)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.white, Color(white: 0.86)],
                                         center: .init(x: 0.38, y: 0.34),
                                         startRadius: 2, endRadius: ballR * 2))
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                    .frame(width: ballR * 2, height: ballR * 2)
                    .position(x: cx, y: cy)
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy - ballR)); p.addLine(to: CGPoint(x: cx, y: cy + ballR))
                    p.move(to: CGPoint(x: cx - ballR, y: cy)); p.addLine(to: CGPoint(x: cx + ballR, y: cy))
                }
                .stroke(.black.opacity(0.14), lineWidth: 1)
                Circle()
                    .stroke(.black.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: miscueR * 2, height: miscueR * 2)
                    .position(x: cx, y: cy)
                Circle()
                    .fill(Color.red)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: tipD, height: tipD)
                    .position(dot)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nx = Double((cx - value.location.x) / ballR)
                        let ny = Double((cy - value.location.y) / ballR)
                        let mag = (nx * nx + ny * ny).squareRoot()
                        let s = mag > placementLimit ? placementLimit / mag : 1
                        spinX = nx * s * pull
                        spinY = ny * s * pull
                    }
            )
        }
    }
}

// MARK: - Pocket display helper

enum PocketDisplay {
    /// schema Pocket index (0..5) → 中文短名。
    static func name(index: Int) -> String {
        switch index {
        case 0: return "左上袋"
        case 1: return "右上袋"
        case 2: return "左下袋"
        case 3: return "右下袋"
        case 4: return "上中袋"
        case 5: return "下中袋"
        default: return "—"
        }
    }

    /// schema Pocket ID → 中文短名。
    static func name(id: String) -> String {
        ShotIntent.pocketIndex(for: id).map(name(index:)) ?? "—"
    }
}
