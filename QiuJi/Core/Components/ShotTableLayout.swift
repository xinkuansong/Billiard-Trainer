import SwiftUI

// MARK: - 击打页共享布局引擎（问题集合 v3 · G3–G11）
//
// 单一真源：把「屏幕内实际球桌矩形」与「控件贴边定位」的几何收敛到此处，各击打页复用，
// 避免逐页手调（v3 §S1「建议产出」）。
//
// 坐标契约（钉死，见 geometry-spatial-reasoning）：
// - 球桌以正交 rotated 顶视渲染在 SCNView 内：长轴 X（外框半长）→ 屏幕竖轴、
//   短轴 Z（外框半宽）→ 屏幕横轴；正交 orthographicScale = 视口半高（世界单位）。
// - 取景 scale 镜像 `CameraRig.fitRotatedTable`：
//     scale = max(halfLen·margin, halfWid·margin·(H/W), unifiedScale)
//   （margin=1.012、unifiedScale=1.50）。
// - `topDownPanOffset = .zero` ⇒ 球桌中心 = 视口中心 ⇒ 球桌矩形在 SCNView 内居中。
// - 每 pt 对应世界单位各轴一致：pointsPerWorld = H / (2·scale)。
//   ⇒ tableH = 2·halfLen·pointsPerWorld = halfLen·H/scale；tableW = halfWid·H/scale。

/// 球桌屏幕矩形计算器（纯函数，可单测）。
enum ShotTableLayout {

    /// USDZ 实测外框半尺寸兜底（= `CameraRig` 默认值，装桌成功后与实测一致）。
    static let defaultHalfLength: Double = 1.4055
    static let defaultHalfWidth: Double = 0.7995

    /// 镜像 `CameraRig.fitRotatedTable` 的取景 scale。
    static func orthographicScale(containerSize: CGSize,
                                  halfLength: Double,
                                  halfWidth: Double) -> Double {
        guard containerSize.width > 1, containerSize.height > 1 else {
            return CameraRig.rotatedUnifiedScale
        }
        let fitVertical = halfLength * CameraRig.rotatedFitMargin
        let fitHorizontal = halfWidth * CameraRig.rotatedFitMargin
            * Double(containerSize.height / containerSize.width)
        return max(fitVertical, fitHorizontal, CameraRig.rotatedUnifiedScale)
    }

    /// 球桌外框在 SCNView 本地坐标内的居中矩形。
    static func tableRect(in containerSize: CGSize,
                          halfLength: Double = defaultHalfLength,
                          halfWidth: Double = defaultHalfWidth) -> CGRect {
        guard containerSize.width > 1, containerSize.height > 1 else { return .zero }
        let scale = orthographicScale(containerSize: containerSize,
                                      halfLength: halfLength, halfWidth: halfWidth)
        let tableH = CGFloat(halfLength) * containerSize.height / CGFloat(scale)
        let tableW = CGFloat(halfWidth) * containerSize.height / CGFloat(scale)
        let x = (containerSize.width - tableW) / 2
        let y = (containerSize.height - tableH) / 2
        return CGRect(x: x, y: y, width: tableW, height: tableH)
    }

    /// 击球区内框（库边橡皮内侧）屏幕矩形：与 `tableRect` 同心，按内外半尺寸比例缩放。
    /// 坐标契约：rotated 顶视 screen 横轴↔Z（`halfWidth`）、竖轴↔X（`halfLength`）。
    static func playingRect(outer: CGRect,
                            outerHalfLength: Double,
                            outerHalfWidth: Double) -> CGRect {
        guard outer.width > 1, outer.height > 1,
              outerHalfLength > 1e-6, outerHalfWidth > 1e-6 else { return outer }
        let innerHalfL = Double(AngleSceneCalculator.innerLength) / 2
        let innerHalfW = Double(AngleSceneCalculator.innerWidth) / 2
        let w = outer.width * CGFloat(innerHalfW / outerHalfWidth)
        let h = outer.height * CGFloat(innerHalfL / outerHalfLength)
        return CGRect(x: outer.midX - w / 2, y: outer.midY - h / 2, width: w, height: h)
    }
}

// MARK: - 共享布局度量（各击打页统一）

enum ShotStageMetrics {
    /// 瞄准刻度轮宽（G4/G7 竖长条）——与仪表柱同宽（用户修订：34/42 取平均 38）。
    static let aimWheelWidth: CGFloat = 38
    /// 3D 透视浮动瞄准轮高度（C16 / v7 W6）：无球桌矩形驱动 `barLength` 时的固定高。
    /// 原 AimPointScene 手写 44×170：宽 44 偏离 `aimWheelWidth` 无文档依据，已对齐 38；
    /// 高 170 介于 `minBarLength`…`maxBarLength`，保留为浮动态命名常量。
    static let aimWheelFloatingHeight: CGFloat = 170
    /// 打点+力度仪表柱宽（G4）——与刻度轮同宽。
    static let instrumentWidth: CGFloat = 38
    /// 仪表柱顶部固定区（打点迷你图 + 两行读数）高度——不计入力度条本体，
    /// 使力度条本体与刻度轮**等长、底部对齐**（G5）。
    static let instrumentTopReserve: CGFloat = 84
    /// 开球按钮尺寸（G9）。
    static let breakButtonSize = CGSize(width: 48, height: 46)
    /// 右下动作列（击球/上一杆/回放）尺寸（18.2）——窄款 46 以容进右侧黑边（G6/G11）。
    static let actionColumnWidth: CGFloat = 46
    static let actionColumnHeight: CGFloat = 106   // 3×30 + 2×8
    /// 角落控件（开球 / 动作列）与竖条之间的竖向让位（角袋区高度）。
    static let cornerReserve: CGFloat = 116        // actionColumnHeight + 10
    /// 竖条最大 / 最小长度（G7：1.2×220=264；小屏自适应下限）。
    static let maxBarLength: CGFloat = 264
    static let minBarLength: CGFloat = 150
    /// 紧凑手机上的视觉行程上限。交互仍按 0...1 归一化映射，不改变力度或角度语义。
    static let compactMaxBarLength: CGFloat = 180
    static let compactWidthThreshold: CGFloat = 390
    static let compactTableHeightRatio: CGFloat = 0.45
    static let paletteHorizontalInset: CGFloat = 8
    static let paletteMaxWidth: CGFloat = 440

    // MARK: G10 chrome band heights（C11 / v7 W2）

    /// Top inset / chip row height — locks scene height across shot pages.
    static let topRowHeight: CGFloat = 46

    /// Bottom band height tiers (regular-36 palette band / PlanThree role+palette).
    /// K5/X2: Silu / Snooker join Composer at 94; PlanThree = role (~48) + 36-band.
    enum BottomBarHeight: CGFloat {
        /// Legacy compact-30 palette-only band. No current consumers after K5/X2.
        case paletteOnly = 95
        /// Composer / FreePlay / ShotSim / Bank / Diamond / Silu / Snooker / SceneAiming 2D / etc.
        case composer = 94
        /// PlanThree — role row (~48) + regular-36 palette (was 116 @ compact 30).
        case planThree = 140
    }

    static func usesCompactChrome(sceneSize: CGSize) -> Bool {
        sceneSize.width <= compactWidthThreshold
    }

    /// 先服从真实空间，再应用视觉档位；绝不允许 minLength 反向制造越界。
    static func resolvedBarLength(
        available: CGFloat,
        tableHeight: CGFloat,
        sceneSize: CGSize
    ) -> CGFloat {
        let nonNegativeAvailable = max(0, available)
        let visualCap: CGFloat
        if usesCompactChrome(sceneSize: sceneSize) {
            visualCap = min(compactMaxBarLength, max(0, tableHeight) * compactTableHeightRatio)
        } else {
            visualCap = maxBarLength
        }
        let hardCap = min(nonNegativeAvailable, visualCap)
        // 真实可用空间是不可突破的硬约束；不足 150pt 时宁可缩短视觉行程，也不能越界。
        return hardCap
    }

    static func paletteDiameter(sceneSize: CGSize) -> CGFloat {
        usesCompactChrome(sceneSize: sceneSize)
            ? BTBallPaletteMetrics.compactDiameter
            : BTBallPaletteMetrics.regularDiameter
    }

    static func paletteWidth(sceneSize: CGSize) -> CGFloat {
        let available = max(0, sceneSize.width - paletteHorizontalInset * 2)
        return min(available, paletteMaxWidth)
    }
}

// MARK: - 布局代理（页面用它取贴边定位；值类型，S2 复用）
//
// 所有 frame 以 SCNView/scene 容器本地坐标返回（origin 左上）。SwiftUI 定位用
// `.frame(width:height:).position(x: rect.midX, y: rect.midY)`。

struct ShotStageProxy {
    /// scene（中部）区域尺寸 = SCNView 尺寸。
    let sceneSize: CGSize
    /// 球桌外框屏幕矩形。
    let tableRect: CGRect
    /// 击球区内框屏幕矩形（库边内侧 / playfield；打点盘背景贴此宽，DR-042）。
    let playingRect: CGRect

    init(sceneSize: CGSize,
         halfLength: Double = ShotTableLayout.defaultHalfLength,
         halfWidth: Double = ShotTableLayout.defaultHalfWidth) {
        self.sceneSize = sceneSize
        let outer = ShotTableLayout.tableRect(in: sceneSize,
                                              halfLength: halfLength,
                                              halfWidth: halfWidth)
        self.tableRect = outer
        self.playingRect = ShotTableLayout.playingRect(outer: outer,
                                                       outerHalfLength: halfLength,
                                                       outerHalfWidth: halfWidth)
    }

    var isValid: Bool { tableRect.width > 1 && tableRect.height > 1 }

    /// 竖条（刻度轮 / 力度条本体）底部 Y（G5：两侧对称，让出角落控件区）。
    var controlBottomY: CGFloat {
        max(tableRect.maxY - ShotStageMetrics.cornerReserve, tableRect.minY + 60)
    }

    /// 竖条本体长度（G7 1.5×，受可用竖向空间钳制，防小屏超出球桌上沿 G6）。
    var barLength: CGFloat {
        let avail = controlBottomY - tableRect.minY - ShotStageMetrics.instrumentTopReserve
        return ShotStageMetrics.resolvedBarLength(
            available: avail,
            tableHeight: tableRect.height,
            sceneSize: sceneSize
        )
    }

    /// 左侧刻度轮 frame：右缘贴球桌左侧（G4），底部对齐 `controlBottomY`（G5）。
    func aimWheelFrame() -> CGRect {
        let w = ShotStageMetrics.aimWheelWidth
        let h = barLength
        return CGRect(x: tableRect.minX - w, y: controlBottomY - h, width: w, height: h)
    }

    /// 右侧仪表柱 frame：左缘贴球桌右侧（G4），力度条本体底部对齐 `controlBottomY`（G5）。
    /// 总高 = 本体长 + 顶部固定区，使力度条本体（底部段）与刻度轮等长同底。
    func instrumentFrame() -> CGRect {
        let w = ShotStageMetrics.instrumentWidth
        let h = barLength + ShotStageMetrics.instrumentTopReserve
        return CGRect(x: tableRect.maxX, y: controlBottomY - h, width: w, height: h)
    }

    /// 左下开球按钮 frame：底边齐球桌底线（G6），右缘贴球桌左侧。
    func breakButtonFrame() -> CGRect {
        let s = ShotStageMetrics.breakButtonSize
        return CGRect(x: tableRect.minX - s.width, y: tableRect.maxY - s.height,
                      width: s.width, height: s.height)
    }

    /// 右下动作列 frame：底边齐球桌底线（18.2），左缘贴球桌右侧。
    func actionColumnFrame() -> CGRect {
        let w = ShotStageMetrics.actionColumnWidth
        let h = ShotStageMetrics.actionColumnHeight
        return CGRect(x: tableRect.maxX, y: tableRect.maxY - h, width: w, height: h)
    }

    /// 轨迹档位 chip 带区高度（G3）：chip 放在球桌上方空隙内，
    /// **下沿贴球桌上沿**、靠屏幕最右（带区 = scene 顶部到球桌上沿）。
    var chipBandHeight: CGFloat { max(tableRect.minY, 0) }

    /// 球库按页面安全可用宽度排布，并在 iPad 上限制最大宽度；不再绑定窄球桌宽度。
    var libraryWidth: CGFloat { ShotStageMetrics.paletteWidth(sceneSize: sceneSize) }

    var paletteBallDiameter: CGFloat {
        ShotStageMetrics.paletteDiameter(sceneSize: sceneSize)
    }

    /// 打点盘贴击球区下沿：卡片底边 → stage 底边的距离（= `sceneHeight − playingRect.maxY`）。
    var spinPadBottomPadding: CGFloat {
        max(0, sceneSize.height - playingRect.maxY)
    }

    /// 通用左下角控件 frame：右缘贴球桌左缘、底边齐球桌底线（G6）。
    func bottomLeadingFrame(size: CGSize) -> CGRect {
        CGRect(x: tableRect.minX - size.width, y: tableRect.maxY - size.height,
               width: size.width, height: size.height)
    }

    /// 通用右下角控件 frame：左缘贴球桌右缘、底边齐球桌底线（G6）。
    func bottomTrailingFrame(size: CGSize) -> CGRect {
        CGRect(x: tableRect.maxX, y: tableRect.maxY - size.height,
               width: size.width, height: size.height)
    }
}

// MARK: - 共享贴边修饰器（S2：各击打页复用，避免逐页手调）

extension View {
    /// G3：轨迹档位 chip 放球桌上方空隙带内——下沿贴球桌上沿、靠屏幕最右。
    /// 挂在 scene 容器的全尺寸 overlay 上使用。
    func btChipBandPlacement(_ proxy: ShotStageProxy) -> some View {
        self
            .padding(.trailing, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity,
                   maxHeight: proxy.chipBandHeight,
                   alignment: .bottomTrailing)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 按 `ShotStageProxy` 计算出的 rect 定位（scene 本地坐标，origin 左上）。
    func btStageFrame(_ rect: CGRect) -> some View {
        self
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
