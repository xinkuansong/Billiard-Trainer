import SwiftUI
import SceneKit

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

    /// Unzoomed daily landscape playfield in stage-local points. Both HUD modes
    /// use this rect so switching the camera cannot resize or move the spin pad.
    static func landscapePlayingRect(in size: CGSize, halfLength: Double, halfWidth: Double) -> CGRect {
        guard let scale = CameraRig.landscapeOrthographicScale(
            viewSize: size, halfLength: halfLength, halfWidth: halfWidth
        ) else { return .zero }
        let pointsPerMetre = size.height / CGFloat(2 * scale)
        let width = CGFloat(AngleSceneCalculator.innerLength) * pointsPerMetre
        let height = CGFloat(AngleSceneCalculator.innerWidth) * pointsPerMetre
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2,
                      width: width, height: height)
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
    /// Daily power travel stays identical on compact phones and tablets.
    static let dailyPowerBarHeight: CGFloat = 144
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
    /// Eight non-overlapping 44pt slots; never stretch the gaps to fill a tablet.
    static let paletteMaxWidth = CGFloat(BTBallPaletteMetrics.columns) * BTBallPaletteMetrics.minimumHitSize

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

    /// Keep the loupe inside the table columns: both the aim wheel and the
    /// power/spin instrument sit directly outside these edges, even on SE/iPad.
    var aimCloseupSafeInsets: AimCloseupPlacement.SafeInsets {
        .init(top: 12, leading: max(56, tableRect.minX + 8), bottom: 46,
              trailing: max(12, sceneSize.width - tableRect.maxX + 8))
    }

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
                   maxHeight: max(44, proxy.chipBandHeight),
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


/// Perspective shot controls use viewport points, not an orthographic table projection.
struct ShotPerspectiveLayout {
    let sceneSize: CGSize

    var actionFrame: CGRect {
        CGRect(x: sceneSize.width - Spacing.sm - ShotStageMetrics.actionColumnWidth,
               y: sceneSize.height - Spacing.sm - ShotStageMetrics.actionColumnHeight,
               width: ShotStageMetrics.actionColumnWidth, height: ShotStageMetrics.actionColumnHeight)
    }

    var aimWheelFrame: CGRect {
        let bottom = actionFrame.minY - Spacing.md
        let height = min(ShotStageMetrics.aimWheelFloatingHeight,
                         max(0, bottom - ShotStageMetrics.instrumentTopReserve - ShotStageMetrics.topRowHeight))
        return CGRect(x: Spacing.sm, y: bottom - height,
                      width: ShotStageMetrics.aimWheelWidth, height: height)
    }

    var instrumentFrame: CGRect {
        let wheel = aimWheelFrame
        return CGRect(x: sceneSize.width - Spacing.sm - ShotStageMetrics.instrumentWidth,
                      y: wheel.minY - ShotStageMetrics.instrumentTopReserve,
                      width: ShotStageMetrics.instrumentWidth,
                      height: wheel.height + ShotStageMetrics.instrumentTopReserve)
    }

    func bottomLeadingFrame(size: CGSize) -> CGRect {
        CGRect(x: Spacing.sm, y: sceneSize.height - Spacing.sm - size.height,
               width: size.width, height: size.height)
    }
}

/// Window-projected cloth polygon → stage-local panel bottom, in points.
/// The whole horizontal span stays inside the lower cloth edge, including tilted rails.
enum SpinPadRailAnchor {
    /// Project the cushion nose, not the cloth plane, into the overlay's coordinate space.
    @MainActor
    static func polygon(scene: AngleTrainingScene, projector: TableProjector,
                        stageOrigin: CGPoint = .zero, usesWindowCoordinates: Bool = false) -> [CGPoint] {
        let x = AngleSceneCalculator.innerLength / 2
        let z = AngleSceneCalculator.innerWidth / 2
        let corners = [(-x, -z), (x, -z), (x, z), (-x, z)]
        let project = usesWindowCoordinates ? projector.projectInWindow : projector.projectVisible
        return corners.compactMap { x, z -> CGPoint? in
            guard let point = project?(SCNVector3(x, scene.surfaceY + BTTablePhysics.cushionHeight, z)) else { return nil }
            return CGPoint(x: point.x - stageOrigin.x, y: point.y - stageOrigin.y)
        }
    }

    @MainActor
    static func bottom(scene: AngleTrainingScene, projector: TableProjector,
                       stageFrame: CGRect, panelWidth: CGFloat, usesWindowCoordinates: Bool = true) -> CGFloat {
        bottom(polygon: polygon(scene: scene, projector: projector, stageOrigin: stageFrame.origin,
                                usesWindowCoordinates: usesWindowCoordinates),
               panelWidth: panelWidth, stageSize: stageFrame.size)
    }

    /// A centered card must fit the projected table's horizontal span before anchoring it.
    /// Otherwise a narrow whole-table view would unnecessarily fall back over the near rail.
    static func panelWidth(polygon: [CGPoint], stageSize: CGSize) -> CGFloat {
        let fallback = min(336, stageSize.width)
        guard polygon.count == 4, polygon.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              let left = polygon.map(\.x).min(), let right = polygon.map(\.x).max() else { return fallback }
        let span = 2 * min(stageSize.width / 2 - left, right - stageSize.width / 2) - 2 * Spacing.sm
        // Keep four 44pt keys usable when the table is entirely off-center or extremely distant.
        return span >= 220 ? min(fallback, span) : fallback
    }

    static func bottom(polygon: [CGPoint], panelWidth: CGFloat, stageSize: CGSize) -> CGFloat {
        let fallback = max(0, stageSize.height - Spacing.sm)
        guard polygon.count == 4, stageSize.width > 0, stageSize.height > 0,
              polygon.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return fallback }
        let left = (stageSize.width - panelWidth) / 2
        let right = left + panelWidth
        let probes = [left, right] + polygon.map(\.x).filter { $0 > left && $0 < right }
        var bottoms: [CGFloat] = []
        for x in probes {
            var intersections: [CGFloat] = []
            for i in polygon.indices {
                let a = polygon[i], b = polygon[(i + 1) % polygon.count]
                guard x >= min(a.x, b.x), x <= max(a.x, b.x) else { continue }
                if abs(a.x - b.x) < 0.001 {
                    if abs(x - a.x) < 0.001 { intersections += [a.y, b.y] }
                } else {
                    intersections.append(a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x))
                }
            }
            guard let lower = intersections.max() else { return fallback }
            bottoms.append(lower)
        }
        guard let bottom = bottoms.min(), bottom > 180, bottom <= stageSize.height else { return fallback }
        return bottom
    }
}
