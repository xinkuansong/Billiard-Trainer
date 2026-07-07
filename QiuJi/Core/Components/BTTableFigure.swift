import SwiftUI
import SceneKit

/// 真台教学插图容器（T-P18-46）：底图 = `TableFigureRenderer` 离屏渲出的真实 USDZ 空台，
/// 叠加层通过 `TableFigureProjection` 用**世界台面坐标（米）**摆球画线 —— 与场景页
/// 同一坐标真源（`AngleSceneCalculator`），杜绝插图私设比例。
///
/// 用法：
/// ```swift
/// BTTableFigure(orientation: .landscape) { proj in
///     BTFigureBall(number: 1, diameter: proj.ballDiameter)
///         .position(proj.point(x: 0.4, z: -0.2))
/// }
/// ```
struct BTTableFigure<Overlay: View>: View {
    let orientation: TableFigureRenderer.Backdrop.Orientation
    /// 非 nil = 台呢特写取景（近景教学卡）：世界中心点 + 正交半高（米）。
    var closeup: (center: CGPoint, halfHeight: CGFloat)? = nil
    @ViewBuilder var overlay: (TableFigureProjection) -> Overlay

    @State private var backdrop: TableFigureRenderer.Backdrop?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let backdrop {
                    Image(uiImage: backdrop.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    overlay(TableFigureProjection(backdrop: backdrop, size: geo.size))
                } else {
                    // 首渲（USDZ 解析）前的占位：黑场 + 极简加载指示，与场景页同调。
                    Color.black
                    ProgressView().tint(.white.opacity(0.4))
                }
            }
            .onAppear {
                guard backdrop == nil, geo.size.width > 1, geo.size.height > 1 else { return }
                backdrop = TableFigureRenderer.backdrop(
                    orientation: orientation,
                    aspect: geo.size.width / geo.size.height,
                    closeup: closeup
                )
            }
        }
    }
}

// MARK: - Projection

/// 世界台面坐标（米，X 长轴 / Z 短轴，原点台心）→ 视图点坐标 的换算器。
struct TableFigureProjection {
    let backdrop: TableFigureRenderer.Backdrop
    let size: CGSize

    /// 世界点 → 视图点。
    func point(x: CGFloat, z: CGFloat) -> CGPoint {
        let n = backdrop.imagePoint(x: x, z: z)
        return CGPoint(x: n.x * size.width, y: n.y * size.height)
    }

    func point(_ v: SCNVector3) -> CGPoint {
        point(x: CGFloat(v.x), z: CGFloat(v.z))
    }

    /// 世界长度（米）→ 视图点长。
    func length(_ meters: CGFloat) -> CGFloat {
        backdrop.imageLength(meters) * size.height
    }

    /// 标准球直径（57.15mm）的视图点长。
    var ballDiameter: CGFloat { length(CGFloat(AngleSceneCalculator.ballRadius) * 2) }

    /// 主线宽（瞄准线/进球线，§1.2 `lineMain`）：与场景页同一物理粗细；
    /// 小图钳底保可读，特写钳顶防变粗棒（正交放大下物理宽会失控）。
    var lineMainWidth: CGFloat { min(max(1.6, length(CGFloat(TrajectoryStyle.lineMain) * 2)), 3.2) }

    /// 释义线宽（对照线/90° 线，§1.2 `lineHint`）。
    var lineHintWidth: CGFloat { min(max(1.2, length(CGFloat(TrajectoryStyle.lineHint) * 2)), 2.4) }

    /// 袋口中心（视觉标记盘位，索引同 `AngleSceneCalculator.pocketMarkerPositions`：
    /// 0 左上 1 右上 2 左下 3 右下 4 上中 5 下中，按世界系 X/Z 符号）。
    func pocketCenter(_ index: Int) -> CGPoint {
        let positions = AngleSceneCalculator.pocketMarkerPositions(surfaceY: 0)
        guard index >= 0, index < positions.count else { return point(x: 0, z: 0) }
        return point(positions[index])
    }
}

// MARK: - 线语言（§1.2 SwiftUI 侧同源取色）

/// 教学插图线语言 token：从 `TrajectoryStyle`（唯一真源）取色，SwiftUI 侧零私设。
enum FigureLine {
    /// 瞄准线 / 母球路径 = 白实线。
    static let aim = Color(uiColor: TrajectoryStyle.aimColor)
    /// 进球线 = 目标球本色（黑 8 亮灰变体）。
    static func pot(number: Int?) -> Color {
        Color(uiColor: TrajectoryStyle.potColor(forNumber: number))
    }
    /// 对照线（理想/参考）= 白虚线。
    static let hint = Color(uiColor: TrajectoryStyle.hintColor)
    /// 90° 分离角释义线 = 品牌绿短虚线（DR-021）。
    static let separation = Color(uiColor: TrajectoryStyle.separationColor)
    /// 假想球圈 / 接触点 = 品牌绿。
    static let contact = Color(uiColor: TrajectoryStyle.contactColor)
    /// 瞄准点（假想球球心）= 红（线语言 v2，条 1.6/4.2）。
    static let aimPoint = Color(uiColor: TrajectoryStyle.aimPointColor)

    /// 释义层短虚线节奏（近似场景 `hintDash/hintGap` 比例）。
    static func hintDashPattern(width: CGFloat) -> [CGFloat] { [width * 3.2, width * 2.2] }
}

// MARK: - Figure balls & marks

/// 教学插图用真球面（标准色板 `PoolBallFace`）+ 接地投影，观感与场景 USDZ 球同源。
struct BTFigureBall: View {
    /// nil = 母球。
    var number: Int? = nil
    let diameter: CGFloat
    var showsShadow: Bool = true

    var body: some View {
        ZStack {
            if showsShadow {
                Ellipse()
                    .fill(Color.black.opacity(0.30))
                    .frame(width: diameter * 0.92, height: diameter * 0.30)
                    .blur(radius: diameter * 0.05)
                    .offset(y: diameter * 0.42)
            }
            PoolBallFace(key: number.map { "_\($0)" } ?? "cueBall", diameter: diameter)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// 假想球（§1.2/§1.3 L0）：品牌绿虚线圈 + 球心红点（瞄准点，线语言 v2 条 1.6），
/// 与场景 `ghostBallNode`（含 `ghostAimDot` 子节点）同语义同色。
struct BTGhostCircle: View {
    let diameter: CGFloat
    /// 球心瞄准点红点，默认显示（条 1.6：所有页面假想球都要有球心点）。
    var showsAimPoint: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    FigureLine.contact.opacity(0.9),
                    style: StrokeStyle(lineWidth: max(1.2, diameter * 0.035),
                                       dash: [diameter * 0.12, diameter * 0.08])
                )
            if showsAimPoint {
                BTAimPointDot(diameter: max(4, diameter * 0.18))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// 瞄准点红点（假想球球心，线语言 v2 条 1.6/4.2）。
struct BTAimPointDot: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(FigureLine.aimPoint)
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.5), radius: 1)
    }
}

/// 接触点绿点（§1.3 L0）。
struct BTContactDot: View {
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(FigureLine.contact)
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.5), radius: 1)
    }
}

/// 插图标签胶囊（HUD label 级：11pt semibold 白 55%–90%，暗玻璃底）。
struct BTFigureTag: View {
    let text: String
    var color: Color = .white.opacity(0.9)

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.black.opacity(0.45), in: Capsule())
    }
}

// MARK: - Preview

#Preview("Landscape table") {
    BTTableFigure(orientation: .landscape) { proj in
        BTFigureBall(diameter: proj.ballDiameter)
            .position(proj.point(x: -0.6, z: 0.2))
        BTFigureBall(number: 1, diameter: proj.ballDiameter)
            .position(proj.point(x: 0.3, z: -0.1))
        BTGhostCircle(diameter: proj.ballDiameter)
            .position(proj.point(x: 0.24, z: -0.05))
    }
    .frame(height: 230)
    .padding()
    .background(Color.btBG)
}
