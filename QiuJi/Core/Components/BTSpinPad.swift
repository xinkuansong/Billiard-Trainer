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

// MARK: - Spin mini icon（共享，ADR-P11-09）

/// 缩小版打点状态图标：母球小圆 + 当前打点红斑，点击弹出真正的打点盘。
/// 红点位置与 `BTSpinPad` 同一约定：spinX 正 = 左（屏幕左），spinY 正 = 高（屏幕上）。
///
/// 两种画法（ADR-P11-13）：
/// - `trueScale = false`（默认，App 内小按钮）：**归一化**——满塞（打滑极限）红点到图标
///   边缘，28pt 下可读性优先；真实比例由点开的打点盘呈现。
/// - `trueScale = true`（教学导出 HUD）：**真实比例**——与 `BTSpinPad` 同一几何（皮头中心
///   摆放位置 + 打滑极限虚线圈 + 皮头/母球真实比例接触斑），观众可照搬到真球上。
struct BTSpinMiniIcon: View {
    let spinX: Double
    let spinY: Double
    let diameter: CGFloat
    var trueScale = false

    var body: some View {
        let limit = Double(CuePhysics.miscueLimitFraction)
        let pull = Double(CuePhysics.tipContactPullFactor)
        let r = diameter / 2 - 3
        // 归一化：打点偏移按打滑极限归一化（满塞红点到图标边缘）；
        // 真实比例：皮头中心摆放位置（接触点 / 拉心系数），与 BTSpinPad 同一几何。
        let frac = trueScale ? 1.0 / pull : 1.0 / limit
        let dx = -CGFloat(spinX * frac) * r
        let dy = -CGFloat(spinY * frac) * r
        let dotD = trueScale
            ? r * 2 * CGFloat(CuePhysics.tipDiameter / BallPhysics.diameter)
            : diameter * 0.26
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 0.8)],
                                     center: .init(x: 0.38, y: 0.34),
                                     startRadius: 1, endRadius: diameter))
            Path { p in
                p.move(to: CGPoint(x: diameter / 2, y: 3))
                p.addLine(to: CGPoint(x: diameter / 2, y: diameter - 3))
                p.move(to: CGPoint(x: 3, y: diameter / 2))
                p.addLine(to: CGPoint(x: diameter - 3, y: diameter / 2))
            }
            .stroke(.black.opacity(0.15), lineWidth: 0.8)
            if trueScale {
                // 打滑极限虚线圈（皮头中心可达边界 = miscue/pull），与打点盘一致。
                Circle()
                    .stroke(.black.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: r * 2 * CGFloat(limit / pull), height: r * 2 * CGFloat(limit / pull))
            }
            Circle()
                .fill(Color.red)
                .overlay(Circle().stroke(.white, lineWidth: 0.8))
                .frame(width: dotD, height: dotD)
                .offset(x: dx, y: dy)
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Spin pad card（共享浮层卡片，ADR-P11-09）

/// 打点盘浮层卡片：半透明材质（`ultraThinMaterial`，透出底下球桌绿色，与旧「击球设置」
/// HUD 同观感）+ 打点盘 + 读数 + 回中 + 右上 ✕。浮在球桌底缘使用，**不要**放进系统
/// sheet——sheet 底下是纯黑+压暗层，材质会显得过深（用户点名要「有些透明」的观感）。
struct BTSpinPadCard: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("打点")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭打点")
            }

            BTSpinPad(spinX: $spinX, spinY: $spinY)
                .frame(width: 128, height: 128)

            HStack(spacing: Spacing.lg) {
                Text(SpinDisplay.readout(spinX: spinX, spinY: spinY))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                Button {
                    spinX = 0
                    spinY = 0
                } label: {
                    Text("回中")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl).stroke(.white.opacity(0.08), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Spin readout（共享）

enum SpinDisplay {
    /// 当前打点 → 中文读数（占打滑极限/满塞的百分比），如「中心球」「高30% · 左20%」。
    static func readout(spinX: Double, spinY: Double) -> String {
        let miscue = Double(CuePhysics.miscueLimitFraction)
        let h = Int((spinX / miscue * 100).rounded())
        let v = Int((spinY / miscue * 100).rounded())
        if h == 0 && v == 0 { return "中心球" }
        var parts: [String] = []
        if v != 0 { parts.append("\(v > 0 ? "高" : "低")\(abs(v))%") }
        if h != 0 { parts.append("\(h > 0 ? "左" : "右")\(abs(h))%") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Cue stick glyph（共享）

/// 简易球杆图标（细长锥形 + 杆尖小点），SF Symbols 无球杆符号时用。
struct CueStickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        // 斜向锥形：左下粗（杆尾）→ 右上细（杆尖）
        let tip = CGPoint(x: w * 0.84, y: h * 0.16)
        let buttA = CGPoint(x: w * 0.08, y: h * 0.74)
        let buttB = CGPoint(x: w * 0.26, y: h * 0.92)
        p.move(to: tip)
        p.addLine(to: buttA)
        p.addLine(to: buttB)
        p.closeSubpath()
        // 杆尖小圆点
        p.addEllipse(in: CGRect(x: w * 0.80, y: h * 0.12, width: w * 0.13, height: w * 0.13))
        return p
    }
}

// MARK: - Power display helper（共享）

enum PowerDisplay {
    /// 连续杆头速度 (m/s) → 直觉力度档名（参考 `ShotIntent` 锚点：轻 1.6 / 中 3.3 / 大力 5.8）。
    static func name(_ v: Double) -> String {
        switch v {
        case ..<1.2: return "轻推"
        case ..<2.2: return "轻"
        case ..<3.6: return "中"
        case ..<4.8: return "中大"
        default: return "大力"
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
