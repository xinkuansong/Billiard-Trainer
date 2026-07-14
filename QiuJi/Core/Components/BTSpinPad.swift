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
            // G16：白盘半径明显增大（卡片/盘区尺寸不变，仅收窄内边距使母球盘更大）；
            // 打滑极限虚线圈 / 皮头接触斑均以 ballR 为基准，随盘径等比放大。
            let inset: CGFloat = 2
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

// MARK: - Spin nudge（按键微调：方向、步进、合矢量钳制）

/// 打点盘四向微调方向。坐标契约同 `BTSpinPad`：
/// `spinX` 正 = 左塞（屏幕左），`spinY` 正 = 高杆（屏幕上）。
enum SpinNudgeDirection { case up, down, left, right }

/// 按键微调的数值规则（与 `SpinDisplay` 读数同一基准，便于单元测试）。
enum SpinPadMath {
    /// 打滑极限（接触点偏移幅值上限，0.5R）——读数 100% 即此值。
    static let miscueLimit = Double(CuePhysics.miscueLimitFraction)
    /// 单次微调步进 = 打滑极限的 1%（与读数「±1%」一一对应）。
    static let step = miscueLimit / 100

    /// 沿某方向微调一步；合矢量幅值 √(x²+y²) 钳在打滑极限内（撞墙停住）：
    /// - 未越界：正常 ±step。
    /// - 越界：把被按的轴贴到打滑极限圆上（另一轴不变），方向与按键一致。
    /// - 已在边界继续按：原地不动。
    /// 返回新打点与 `moved`（false 用于触发「撞墙」反馈并停止长按连发）。
    static func nudge(spinX: Double, spinY: Double, _ dir: SpinNudgeDirection) -> (x: Double, y: Double, moved: Bool) {
        var x = spinX, y = spinY
        switch dir {
        case .up:    y += step
        case .down:  y -= step
        case .left:  x += step
        case .right: x -= step
        }
        if (x * x + y * y).squareRoot() <= miscueLimit + 1e-9 {
            return (x, y, true)
        }
        switch dir {
        case .up, .down:
            let maxY = (max(0, miscueLimit * miscueLimit - spinX * spinX)).squareRoot()
            let ny = dir == .up ? maxY : -maxY
            return (spinX, ny, abs(ny - spinY) > 1e-9)
        case .left, .right:
            let maxX = (max(0, miscueLimit * miscueLimit - spinY * spinY)).squareRoot()
            let nx = dir == .left ? maxX : -maxX
            return (nx, spinY, abs(nx - spinX) > 1e-9)
        }
    }
}

/// 打点盘方向微调键：点按走一步；长按后延迟 0.4s 触发**加速连发**（起步 ~8 次/秒，
/// 按住渐进提到 ~20 次/秒）。每步轻触觉；撞到打滑极限时换「硬」反馈并停连发（撞墙停住）。
///
/// 命中区 44pt（HIG 最小点按目标），可见图标 36pt；外层用 12pt 间距与打点盘隔开做死区，
/// 命中框与盘不交叠 → 点按键的触摸不会「漏」到盘上让红点乱跳。
private struct SpinNudgeButton: View {
    let icon: String
    let accessibility: String
    /// 执行一步微调，返回是否真的移动（false = 撞墙）。
    let onStep: () -> Bool

    @State private var repeatTimer: Timer?
    @State private var ticks = 0
    @State private var isPressing = false

    private let hitSize: CGFloat = 40
    private let iconSize: CGFloat = 30

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white.opacity(isPressing ? 1 : 0.82))
            .frame(width: iconSize, height: iconSize)
            .background(.white.opacity(isPressing ? 0.24 : 0.12), in: Circle())
            .frame(width: hitSize, height: hitSize)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressing else { return }
                        isPressing = true
                        step()
                        scheduleNext(after: 0.4)
                    }
                    .onEnded { _ in stop() }
            )
            .onDisappear { stop() }
            .accessibilityLabel(accessibility)
            .accessibilityAddTraits(.isButton)
    }

    private func step() {
        if onStep() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
    }

    private func scheduleNext(after delay: TimeInterval) {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            guard isPressing else { return }
            ticks += 1
            step()
            scheduleNext(after: max(0.05, 0.12 - Double(ticks) * 0.005))
        }
    }

    private func stop() {
        isPressing = false
        ticks = 0
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

// MARK: - Spin pad card（共享浮层卡片，ADR-P11-09）

/// 打点盘浮层卡片：半透明材质（`ultraThinMaterial`，透出底下球桌绿色，与旧「击球设置」
/// HUD 同观感）+ 打点盘 + 四向微调键 + 读数 + 回中。浮在球桌底缘使用，**不要**放进
/// 系统 sheet——sheet 底下是纯黑+压暗层，材质会显得过深（用户点名要「有些透明」的观感）。
///
/// 交互：拖打点盘做**粗选**（点哪跳哪）；四向键做 ±1% **微调**（合矢量钳在打滑极限，撞墙停住），
/// 长按连发。控件瘦身 v2（条 13.3）：盘缩至 104pt、十字更紧凑、背景近透明（透出台面），
/// 十字宽度 40+10+104+10+40=204pt → 调用方应给 `maxWidth: 228`（含卡片左右 padding）。
/// 关闭：无右上 ✕（CL-疑4）；点盘外任意处关闭由 `BTSpinPadOverlay` 捕获层承担。
struct BTSpinPadCard: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    var onClose: () -> Void

    /// 命中框与打点盘之间的死区（防误触），同时作为上/下键与盘的纵向间距。
    private let crossGap: CGFloat = 10

    var body: some View {
        VStack(spacing: Spacing.xs) {
            VStack(spacing: crossGap) {
                SpinNudgeButton(icon: "chevron.up", accessibility: "高杆增加 1%") {
                    nudge(.up)
                }
                HStack(spacing: crossGap) {
                    SpinNudgeButton(icon: "chevron.left", accessibility: "左塞增加 1%") {
                        nudge(.left)
                    }
                    BTSpinPad(spinX: $spinX, spinY: $spinY)
                        .frame(width: 104, height: 104)
                    SpinNudgeButton(icon: "chevron.right", accessibility: "右塞增加 1%") {
                        nudge(.right)
                    }
                }
                SpinNudgeButton(icon: "chevron.down", accessibility: "低杆增加 1%") {
                    nudge(.down)
                }
            }

            HStack(spacing: Spacing.md) {
                // 打点 = 可调量值 → 金（金管数值，T-P18-45）。
                Text(SpinDisplay.readout(spinX: spinX, spinY: spinY))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
                Button {
                    spinX = 0
                    spinY = 0
                } label: {
                    Text("回中")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.sm)
        // 近透明底（条 13.3）：只留 22% 黑 + 细模糊，透出台面绿；发丝描边保分层。
        .background {
            RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .background(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5)))
                .environment(\.colorScheme, .dark)
        }
        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
            .strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        .environment(\.colorScheme, .dark)
    }

    /// 沿某方向微调一步并写回绑定；返回是否真的移动（false = 撞到打滑极限）。
    private func nudge(_ dir: SpinNudgeDirection) -> Bool {
        let r = SpinPadMath.nudge(spinX: spinX, spinY: spinY, dir)
        spinX = r.x
        spinY = r.y
        return r.moved
    }
}

/// 打点盘浮层（条 13.3）：卡片 + **点盘外任意处关闭**的全屏捕获层。
/// 调用方放进球桌 ZStack 即可（代替直接放 `BTSpinPadCard`）。
struct BTSpinPadOverlay: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    var bottomPadding: CGFloat = 80
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 近乎不可见的命中层：点卡片外任意处关闭。
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
            BTSpinPadCard(spinX: $spinX, spinY: $spinY, onClose: onClose)
                .frame(maxWidth: 228)
                .padding(.bottom, bottomPadding)
        }
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
