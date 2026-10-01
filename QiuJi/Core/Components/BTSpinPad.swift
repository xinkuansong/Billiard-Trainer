import SwiftUI

/// 打点盘（可复用）：按真实物理比例画母球正面 + 打滑极限圈 + 皮头接触斑，拖动选择真实击球点。
///
/// 绑定的 `spinX/spinY` 存的是**杆坐标系中的真实接触点偏移/R**（= pooltool a,b，喂物理）：
/// - `spinX` 正 = 左塞（屏幕左）/ 负 = 右塞；`spinY` 正 = 高杆（屏幕上）/ 负 = 低杆。
/// - 皮头中心摆放 → 接触点经曲率拉心系数 `CuePhysics.tipContactPullFactor` 换算。
/// - 接触点偏移钳在 `CuePhysics.miscueLimitFraction`(0.5R)，超出即打滑（拖不出去）。
///
/// 与 `ShotSimulationView` 内的私有打点盘同源；抽出供走位编排器/训练页复用。
struct BTSpinPad: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    /// 只读展示（序列演示）：仍按真实比例画打点，但不接受拖动改值。
    var isReadOnly = false
    /// 只选高低杆（加塞图谱）：拖动锁在竖轴，`spinX` 恒为 0。
    var locksSideSpin = false
    var strikeAccess: CueStrikeAccess? = nil

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
            let tipD = max(ballR * 2 * CGFloat(tipRatio), 8) * (isReadOnly ? 1 : 0.5)
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
                if !isReadOnly, let access = strikeAccess {
                    Path { path in
                        let columns = 48
                        let step = miscue * 2 / Double(columns)
                        for column in 0..<columns {
                            let x = -miscue + (Double(column)+0.5)*step
                            let edge = sqrt(max(0,miscue*miscue-x*x))
                            let minimum = access.constrained(spinX:x,spinY:-edge,allowSideAdjustment:false)?.y ?? edge
                            let left = cx-CGFloat((x+step/2)/pull)*ballR
                            let top = cy-CGFloat(minimum/pull)*ballR
                            path.addRect(CGRect(x:left,y:top,width:CGFloat(step/pull)*ballR+0.5,
                                                height:CGFloat((minimum+edge)/pull)*ballR))
                        }
                    }
                    .fill(Color.black.opacity(0.48))
                    .clipShape(Circle().size(width: miscueR * 2, height: miscueR * 2)
                        .offset(x: cx-miscueR, y: cy-miscueR))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                Circle()
                    .fill(Color.red)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: tipD, height: tipD)
                    .position(dot)
                    .shadow(color: .black.opacity(0.35), radius: 2)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("打点盘")
            .accessibilityValue(SpinDisplay.readout(spinX: spinX, spinY: spinY))
            .accessibilityHint(isReadOnly ? "只读打点" : "灰色区域不可选，可拖动或使用方向按钮调整")
            .gesture(
                isReadOnly ? nil : DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nx = Double((cx - value.location.x) / ballR)
                        let ny = Double((cy - value.location.y) / ballR)
                        let mag = hypot(nx,ny)
                        let scale = mag > placementLimit ? placementLimit/mag : 1
                        let requestedX = locksSideSpin ? 0 : nx*scale*pull
                        let requestedY = locksSideSpin ? max(-placementLimit,min(placementLimit,ny))*pull : ny*scale*pull
                        if let access = strikeAccess {
                            guard let point = access.constrained(spinX:requestedX,spinY:requestedY,allowSideAdjustment:!locksSideSpin) else { return }
                            spinX=point.x; spinY=point.y
                        } else {
                            spinX=requestedX; spinY=requestedY
                        }
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

// MARK: - Spin pad layout（背景贴球桌宽 / 白盘封顶）

/// 打点盘卡片几何：背景宽 = 击球区内框屏宽（`ShotStageProxy.playingRect.width`，左右贴库边内侧）；
/// 白盘直径随宽放大但封顶，不挤占四向键与底栏读数。
enum SpinPadLayout {
    /// 四向键命中框（与 `BTHoldRepeatButton` 默认一致，不缩键让路）。
    static let keyHit: CGFloat = 44
    /// 键与白盘间距（防误触）。
    static let crossGap: CGFloat = 10
    /// 卡片水平内边距（= `Spacing.sm`）。
    static let horizontalPadding: CGFloat = Spacing.sm
    /// 白盘直径上限（pt）：明显大于旧 104，又留出键区呼吸。
    static let maxPadDiameter: CGFloat = 168
    /// Daily HUD uses the same compact dimensions on phones and tablets.
    static let fixedPadDiameter: CGFloat = 160
    static let fixedCardExtent = fixedPadDiameter + 2 * keyHit + 2 * horizontalPadding
    /// 极窄球桌时的白盘下限，避免缩成不可用。
    static let minPadDiameter: CGFloat = 104
    /// `tableWidth` 无效时的卡片宽兜底（旧紧凑卡量级）。
    static let fallbackTableWidth: CGFloat = 280

    /// 白盘直径：优先放大到 `maxPadDiameter`，但绝不挤掉左右键间距；
    /// 空间够时不低于 `minPadDiameter`。
    static func padDiameter(tableWidth: CGFloat) -> CGFloat {
        let contentW = max(0, tableWidth - 2 * horizontalPadding)
        let geometricMax = contentW - 2 * keyHit - 2 * crossGap
        let capped = min(geometricMax, maxPadDiameter)
        if capped >= minPadDiameter { return capped }
        return max(0, geometricMax)
    }

    static func resolvedTableWidth(_ raw: CGFloat) -> CGFloat {
        raw > 1 ? raw : fallbackTableWidth
    }
}

// MARK: - Spin pad card（共享浮层卡片，ADR-P11-09）

/// 打点盘浮层卡片：半透明材质（`ultraThinMaterial`，透出底下球桌绿色，与旧「击球设置」
/// HUD 同观感）+ 打点盘 + 四向微调键 + 读数 + 回中。浮在球桌底缘使用，**不要**放进
/// 系统 sheet——sheet 底下是纯黑+压暗层，材质会显得过深（用户点名要「有些透明」的观感）。
///
/// 交互：拖打点盘做**粗选**（点哪跳哪）；四向键做 ±1% **微调**（合矢量钳在打滑极限，撞墙停住），
/// 长按连发。背景宽 = `tableWidth`（击球区内框屏宽，左右贴库边内侧）；白盘见 `SpinPadLayout`。
/// 关闭：无右上 ✕（CL-疑4）；点盘外任意处关闭由 `BTSpinPadOverlay` 捕获层承担。
struct BTSpinPadCard: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    /// 击球区内框屏幕宽度（`playingRect.width`）；卡片背景与此等宽。
    var tableWidth: CGFloat
    /// 只读展示（序列演示暂停时「点开看本杆打点」）：隐藏四向微调键与「回中」，
    /// 白盘不接受拖动——演示的是录制真值，不允许改。
    var isReadOnly = false
    /// 只选高低杆：隐藏左右微调键，白盘拖动锁竖轴。
    var locksSideSpin = false
    var strikeAccess: CueStrikeAccess? = nil
    /// Compact landscape cards keep the same cross layout within the available height.
    var usesCompactLayout = false
    var availableHeight: CGFloat? = nil
    /// Daily landscape: fixed size, bottom-aligned to the 2D inner rail in both modes.
    var usesFixedLayout = false
    var onClose: () -> Void

    private var padDiameter: CGFloat {
        if usesFixedLayout { return SpinPadLayout.fixedPadDiameter }
        let width = SpinPadLayout.resolvedTableWidth(tableWidth)
        let diameter = SpinPadLayout.padDiameter(tableWidth: usesCompactLayout ? min(width, 336) : width)
        let reserve = 2 * SpinPadLayout.keyHit + 2 * SpinPadLayout.crossGap
            + 2 * SpinPadLayout.horizontalPadding + 32
        return min(diameter, max(0, (availableHeight ?? .greatestFiniteMagnitude) - reserve))
    }

    var body: some View {
        let width = SpinPadLayout.resolvedTableWidth(tableWidth)
        Group {
            if usesFixedLayout, !isReadOnly {
                fixedContent
            } else {
                standardContent
            }
        }
        .padding(SpinPadLayout.horizontalPadding)
        .frame(width: usesFixedLayout
               ? SpinPadLayout.fixedCardExtent
               : (usesCompactLayout ? (isReadOnly ? nil : min(width, 2 * SpinPadLayout.maxPadDiameter)) : width),
               height: usesFixedLayout ? SpinPadLayout.fixedCardExtent : nil)
        .background {
            RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .background(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5)))
                .environment(\.colorScheme, .dark)
        }
        .overlay(RoundedRectangle(cornerRadius: BTRadius.xl, style: .continuous)
            .strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("spinPad.card")
        .environment(\.colorScheme, .dark)
    }

    private var fixedContent: some View {
        VStack(spacing: 0) {
            BTHoldRepeatButton(icon: "chevron.up", accessibility: "高杆增加 1%") { nudge(.up) }
            HStack(spacing: 0) {
                BTHoldRepeatButton(icon: "chevron.left", accessibility: "左塞增加 1%") { nudge(.left) }
                    .opacity(locksSideSpin ? 0 : 1)
                    .allowsHitTesting(!locksSideSpin)
                    .accessibilityHidden(locksSideSpin)
                BTSpinPad(spinX: $spinX, spinY: $spinY, locksSideSpin: locksSideSpin, strikeAccess: strikeAccess)
                    .frame(width: padDiameter, height: padDiameter)
                    .accessibilityIdentifier("spinPad.disc")
                BTHoldRepeatButton(icon: "chevron.right", accessibility: "右塞增加 1%") { nudge(.right) }
                    .opacity(locksSideSpin ? 0 : 1)
                    .allowsHitTesting(!locksSideSpin)
                    .accessibilityHidden(locksSideSpin)
            }
            HStack(spacing: 0) {
                Text((!isReadOnly && !(strikeAccess?.isAvailable(spinX:spinX,spinY:spinY) ?? true)) ? "当前打点受限" : SpinDisplay.readout(spinX: spinX, spinY: spinY))
                    .font(.btCaption.bold())
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                BTHoldRepeatButton(icon: "chevron.down", accessibility: "低杆增加 1%") { nudge(.down) }
                Button {
                    resetSpin()
                } label: {
                    Text("回中")
                        .font(.btCaption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(.white.opacity(0.14), in: Capsule())
                        .frame(maxWidth: .infinity, minHeight: SpinPadLayout.keyHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var standardContent: some View {
        VStack(spacing: Spacing.xs) {
            if isReadOnly {
                BTSpinPad(spinX: $spinX, spinY: $spinY, isReadOnly: true)
                    .frame(width: padDiameter, height: padDiameter)
            } else {
                VStack(spacing: SpinPadLayout.crossGap) {
                    BTHoldRepeatButton(icon: "chevron.up", accessibility: "高杆增加 1%") {
                        nudge(.up)
                    }
                    HStack(spacing: SpinPadLayout.crossGap) {
                        Spacer(minLength: 0)
                        if !locksSideSpin {
                            BTHoldRepeatButton(icon: "chevron.left", accessibility: "左塞增加 1%") {
                                nudge(.left)
                            }
                        }
                        BTSpinPad(spinX: $spinX, spinY: $spinY, locksSideSpin: locksSideSpin, strikeAccess: strikeAccess)
                            .frame(width: padDiameter, height: padDiameter)
                        if !locksSideSpin {
                            BTHoldRepeatButton(icon: "chevron.right", accessibility: "右塞增加 1%") {
                                nudge(.right)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    BTHoldRepeatButton(icon: "chevron.down", accessibility: "低杆增加 1%") {
                        nudge(.down)
                    }
                }
            }

            HStack(spacing: Spacing.md) {
                // 打点 = 可调量值 → 金（金管数值，T-P18-45）。
                Text((!isReadOnly && !(strikeAccess?.isAvailable(spinX:spinX,spinY:spinY) ?? true)) ? "当前打点受限" : SpinDisplay.readout(spinX: spinX, spinY: spinY))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDStyle.valueAdjustable)
                    .monospacedDigit()
                if !isReadOnly {
                    Button {
                        resetSpin()
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
        }
    }

    /// 沿某方向微调一步并写回绑定；返回是否真的移动（false = 撞到打滑极限）。
    private func resetSpin() {
        if let access = strikeAccess {
            guard let point = access.automaticPoint(spinX:0,spinY:0,allowSideAdjustment:!locksSideSpin) else { return }
            spinX = point.x; spinY = point.y
        } else { spinX=0; spinY=0 }
    }

    private func nudge(_ dir: SpinNudgeDirection) -> Bool {
        if locksSideSpin, dir == .left || dir == .right { return false }
        let r = SpinPadMath.nudge(spinX: locksSideSpin ? 0 : spinX, spinY: spinY, dir)
        let point: (x: Double, y: Double)
        if let access = strikeAccess {
            guard let corrected = access.constrained(spinX:r.x,spinY:r.y,allowSideAdjustment:!locksSideSpin) else { return false }
            point = corrected
        } else { point = (r.x,r.y) }
        let moved = abs(point.x-spinX)+abs(point.y-spinY) > 1e-7
        spinX = point.x; spinY = point.y
        return moved
    }
}

/// 打点盘浮层：等宽卡片 + **铺满 stage** 的拦截层（点/拖卡片外 → 关闭，挡住台面瞄准与力度条误触）。
/// 调用方放进球桌 ZStack，传入 `proxy.playingRect.width` 与 `proxy.spinPadBottomPadding`
/// （宽/底均贴击球区内框，非外框）。
struct BTSpinPadOverlay: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    /// 击球区内框屏幕宽度；卡片背景与此等宽（左右贴库边内侧）。
    var tableWidth: CGFloat
    /// 卡片底边到 stage 底的距离；贴击球区下沿时用 `proxy.spinPadBottomPadding`。
    var bottomPadding: CGFloat = 0
    /// 只读展示（序列演示）：卡片不可改值，仅供查看本杆打点。
    var isReadOnly = false
    /// 只选高低杆：隐藏左右微调键，白盘拖动锁竖轴。
    var locksSideSpin = false
    var strikeAccess: CueStrikeAccess? = nil
    var usesCompactLayout = false
    var availableHeight: CGFloat? = nil
    /// Daily landscape: fixed size, bottom-aligned to the 2D inner rail in both modes.
    var usesFixedLayout = false
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // 铺满 stage、无视觉压暗：吞掉 tap/drag，避免落到 SceneKit 调瞄或右侧力度柱；松手关闭。
            Color.clear
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in onClose() }
                )
                .accessibilityLabel("关闭打点")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onClose() }

            BTSpinPadCard(spinX: $spinX, spinY: $spinY,
                          tableWidth: tableWidth, isReadOnly: isReadOnly,
                          locksSideSpin: locksSideSpin, strikeAccess: strikeAccess,
                          usesCompactLayout: usesCompactLayout,
                          availableHeight: availableHeight,
                          usesFixedLayout: usesFixedLayout,
                          onClose: onClose)
                .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Interactive scenes share the same card size and projected cushion anchor in 2D and 3D.
/// Read-only sequence playback keeps its existing presentation geometry.
struct BTProjectedSpinPadOverlay: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    @ObservedObject var scene: AngleTrainingScene
    let projector: TableProjector
    var isReadOnly = false
    var locksSideSpin = false
    var onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let polygon = SpinPadRailAnchor.polygon(scene: scene, projector: projector)
            let width = SpinPadRailAnchor.panelWidth(polygon: polygon, stageSize: geo.size)
            let bottom = SpinPadRailAnchor.bottom(polygon: polygon, panelWidth: width, stageSize: geo.size)
            BTSpinPadOverlay(spinX: $spinX, spinY: $spinY,
                tableWidth: width, bottomPadding: geo.size.height - bottom,
                isReadOnly: isReadOnly, locksSideSpin: locksSideSpin,
                strikeAccess: isReadOnly ? nil : scene.cueAccessSnapshot,
                usesCompactLayout: true, availableHeight: bottom, onClose: onClose)
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
    /// schema Pocket index (0..5) → portrait 屏幕系中文名（DR-063）。
    /// 用于 drill 封面/精讲/击打等 `applyTopDown2DRotated` 面：
    /// 屏幕上=+X，屏幕右=+Z。
    static func name(index: Int) -> String {
        switch index {
        case 0: return "左下角袋"   // topLeft
        case 1: return "左上角袋"   // topRight
        case 2: return "右下角袋"   // bottomLeft
        case 3: return "右上角袋"   // bottomRight
        case 4: return "左侧中袋"   // topCenter
        case 5: return "右侧中袋"   // bottomCenter
        default: return "—"
        }
    }

    /// schema Pocket ID → 中文短名。
    static func name(id: String) -> String {
        ShotIntent.pocketIndex(for: id).map(name(index:)) ?? "—"
    }
}

/// Fixed daily layout subscribes to geometry changes, even while the pad is open.
struct BTSceneSpinPadOverlay: View {
    @Binding var spinX: Double
    @Binding var spinY: Double
    @ObservedObject var scene: AngleTrainingScene
    let tableWidth: CGFloat
    let bottomPadding: CGFloat
    var onClose: () -> Void
    var body: some View {
        BTSpinPadOverlay(spinX:$spinX,spinY:$spinY,tableWidth:tableWidth,
            bottomPadding:bottomPadding,strikeAccess:scene.cueAccessSnapshot,
            usesCompactLayout:true,usesFixedLayout:true,onClose:onClose)
    }
}
