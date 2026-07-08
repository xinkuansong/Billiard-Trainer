import SwiftUI
import UIKit

/// 标准台球「俯视球面」矢量视图：用分层渐变还原球体明暗 + 高光，号码画在中心白圈里。
///
/// 替代走位编排台早期的 USDZ 离屏渲染缩略图（`BallFaceRenderer`）：
/// USDZ 各球贴图 UV 布局不一致，单一姿态没法让所有号码正立 → 只能靠号码角标兜底。
/// 2D 矢量直接绘制号码天生正立、颜色精确（标准球色板）、任意直径清晰、零外部资源依赖。
///
/// 球号语义（标准花式九球/斯诺无关，按美式台球约定）：
/// - 1..8 单色球（solid）；9..15 花色球（stripe，白底 + 彩色环带）；母球纯白无号。
struct PoolBallFace: View {
    /// 球键：母球 `"cueBall"`，目标球 `"_1"`..`"_15"`（与 `PositionPlayBall` 一致）。
    let key: String
    /// 球直径（点）。
    let diameter: CGFloat

    var body: some View {
        let style = PoolBallStyle.style(for: key)
        ZStack {
            // 底：单色球填满，花色球以白为底、彩带居中横贯。
            Circle().fill(style.isStripe ? Color.white : style.color)

            if style.isStripe {
                stripeBand(style.color)
            }

            // 球面边缘暗化（体积感）。母球用更轻的暗化，避免纯白被压成灰。
            Circle().fill(
                RadialGradient(
                    colors: [.clear, .black.opacity(style.isCue ? 0.2 : 0.42)],
                    center: UnitPoint(x: 0.5, y: 0.52),
                    startRadius: diameter * 0.08,
                    endRadius: diameter * 0.52
                )
            )

            // 左上主光（漫反射亮面）。
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.5), .clear],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .blendMode(.screen)

            if let number = style.number {
                numberBadge(number)
            }

            // 母球中心红点（标准训练母球标记）。
            if style.isCue {
                Circle()
                    .fill(Color(red: 0.85, green: 0.16, blue: 0.16))
                    .frame(width: diameter * 0.16, height: diameter * 0.16)
            }

            // 镜面高光斑。
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: diameter * 0.2, height: diameter * 0.14)
                .blur(radius: diameter * 0.015)
                .offset(x: -diameter * 0.17, y: -diameter * 0.20)

            Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: max(0.5, diameter * 0.012))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    /// 花色环带：横贯球面的彩色带，上下留白还原标准花色球外观。
    /// 带宽内嵌于 ZStack（宽=直径），外层 `.clipShape(Circle())` 自动把带端裁成弧形。
    private func stripeBand(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: diameter, height: diameter * 0.62)
    }

    private func numberBadge(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: diameter * 0.5, height: diameter * 0.5)
            Text("\(number)")
                .font(.system(size: diameter * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
        }
    }
}

// MARK: - Standard pool ball color palette

/// 标准美式台球色板（钉死的领域契约）：1黄 2蓝 3红 4紫 5橙 6绿 7栗 8黑；
/// 9..15 复用 1..7 色作花色（白底彩带）；母球纯白。
enum PoolBallStyle {
    struct Spec {
        let color: Color
        let number: Int?
        let isStripe: Bool
        var isCue: Bool = false
    }

    /// 球号 → 单色色值（1..7；8 为黑，单列）。
    private static func solidColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.96, green: 0.78, blue: 0.10)   // 黄
        case 2: return Color(red: 0.10, green: 0.32, blue: 0.72)   // 蓝
        case 3: return Color(red: 0.84, green: 0.16, blue: 0.14)   // 红
        case 4: return Color(red: 0.40, green: 0.20, blue: 0.55)   // 紫
        case 5: return Color(red: 0.92, green: 0.45, blue: 0.08)   // 橙
        case 6: return Color(red: 0.10, green: 0.52, blue: 0.30)   // 绿
        case 7: return Color(red: 0.55, green: 0.13, blue: 0.13)   // 栗（暗红）
        case 8: return Color(white: 0.10)                          // 黑
        default: return Color(white: 0.5)
        }
    }

    static func style(for key: String) -> Spec {
        if PositionPlayBall.isCue(key) {
            return Spec(color: .white, number: nil, isStripe: false, isCue: true)
        }
        guard let n = PositionPlayBall.number(for: key) else {
            return Spec(color: Color(white: 0.5), number: nil, isStripe: false)
        }
        if n <= 8 {
            return Spec(color: solidColor(n), number: n, isStripe: false)
        }
        // 9..15 花色：复用 1..7 的色（9→1黄, 10→2蓝, …, 15→7栗）。
        return Spec(color: solidColor(n - 8), number: n, isStripe: true)
    }
}

// MARK: - Trajectory line style (shared source of truth)

/// 线语言统一真源（ADR-P11-12 + T-P18-41 + 线语言 v2，问题集合条 12）。
/// App 内 8 场景页与渲染管线（`SequenceVideoExporter`/缩略图）全部从这里取色取宽：
/// - 瞄准线 = 白实线（用户即将做的；母球碰前段）
/// - 进球线 = 绑定目标球本色**虚线**（含黑 8 本色黑，v3 P4.3；无目标语义兜底亮灰）
/// - 母球碰后轨迹 / 其它被带动球轨迹 = 各自球色**虚线**（`mainDash/mainGap` 节奏）
/// - 球迹线 = 金（引擎算出的解路径，品牌线）
/// - 对照线 = 白虚线（理想/自动解参考，弃旧蓝色）
/// - 90° 分离角释义线 = 品牌绿短虚线
/// - 接触点 = 品牌绿；瞄准点（假想球球心）= 红点
/// 线宽只有两档：`lineMain`（瞄准/进球/球迹同粗）与 `lineHint`（释义线细一档）。
enum TrajectoryStyle {
    // MARK: 线宽（两档制）

    /// 主线宽：瞄准线 / 进球线 / 球迹线同粗（T-P18-41 统一，原 0.0025/0.0030 两档并轨）。
    static let lineMain: Float = 0.0028
    /// 释义线宽：对照线 / 90° 线 / 法线等提示层。
    static let lineHint: Float = 0.0020

    /// 瞄准线（母球轨迹）半径 = `lineMain`（保留旧名兼容既有调用点）。
    static let aimRadius: Float = lineMain
    /// 进球线（目标球轨迹）半径 = `lineMain`。
    static let potRadius: Float = lineMain
    /// 紧凑场景（缩略图等低分辨率渲染）半径——太细会碎成虚点。
    static let compactRadius: Float = 0.0045

    // MARK: 颜色

    /// 瞄准线颜色（母球白，固定）。
    static let aimColor = UIColor.white.withAlphaComponent(0.95)

    /// 进球线颜色 = 目标球球色（标准色板，9..15 花色取主色）。
    /// 黑 8 也按本色（黑）——问题集合 v3 P4.3 撤销旧亮灰例外，规则全号覆盖；
    /// 无目标球语义（自由球/未知键）仍取亮灰兜底。
    static func potColor(for targetKey: String, alpha: CGFloat = 0.95) -> UIColor {
        guard PositionPlayBall.number(for: targetKey) != nil else {
            return UIColor(white: 0.85, alpha: alpha)
        }
        return UIColor(PoolBallStyle.style(for: targetKey).color).withAlphaComponent(alpha)
    }

    /// 进球线颜色（按球号）。场景静态可视化（`updateVisualization`）只持有号不持有键。
    static func potColor(forNumber n: Int?, alpha: CGFloat = 0.95) -> UIColor {
        guard let n else { return UIColor(white: 0.85, alpha: alpha) }
        return potColor(for: "_\(n)", alpha: alpha)
    }

    /// 球迹线（引擎解路径/翻库路线）= 品牌金。
    static let traceColor = UIColor(Color.btAccent)

    /// 对照线（理想/自动解参考）= 白虚线。
    static let hintColor = UIColor.white.withAlphaComponent(0.72)

    /// 瞄准点（假想球球心）标记 = 红点（问题集合条 1.6/4.2：球心是瞄准参考点，全页统一）。
    static let aimPointColor = UIColor(red: 1.0, green: 0.30, blue: 0.26, alpha: 0.95)

    /// 90° 分离角释义线 = 品牌绿短虚线，与假想球圈/接触点同「教学标注」家族。
    /// 语义：过**假想球球心**（母球碰撞瞬间位置）、垂直于撞击线的切线——定杆母球沿它离开。
    /// DR-021：弃白——定杆时该线与母球白色轨迹线共线重合，白色无法区分。
    static let separationColor = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 0.9)

    /// 接触点标记 = 品牌绿（与选中环同族）。
    static let contactColor = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 0.95)

    // MARK: 虚线节奏（对照线/90° 线共用）

    static let hintDash: Float = 0.028
    static let hintGap: Float = 0.020

    // MARK: 主轨迹虚线节奏（线语言 v2，问题集合条 12）
    // 进球线 / 母球击后轨迹 / 其它被带动球轨迹 = 虚线；瞄准线（碰前段）保持白实线。
    // 比 hint 更长的段落，保证主信息层级仍高于释义层。

    static let mainDash: Float = 0.050
    static let mainGap: Float = 0.026
}

// MARK: - Trajectory detail level（三档标注展示，问题集合条 12.5）

/// 击打页轨迹标注三档（全局偏好，所有击打页统一）：
/// - `full`：所有会移动的球的轨迹（母球 + 目标球 + 被带动球）
/// - `core`：仅母球 + 目标球轨迹
/// - `minimal`：仅瞄准线 + 假想球（自由模式空杆时瞄准线延伸到库边）
enum TrajectoryDetail: Int, CaseIterable {
    case full = 0
    case core = 1
    case minimal = 2

    var label: String {
        switch self {
        case .full: return "轨迹·全"
        case .core: return "轨迹·双"
        case .minimal: return "瞄准线"
        }
    }

    var systemImage: String {
        switch self {
        case .full: return "point.3.filled.connected.trianglepath.dotted"
        case .core: return "point.topleft.down.curvedto.point.bottomright.up"
        case .minimal: return "line.diagonal"
        }
    }

    var next: TrajectoryDetail {
        TrajectoryDetail(rawValue: (rawValue + 1) % TrajectoryDetail.allCases.count) ?? .full
    }
}

// MARK: - Preview

#Preview("Pool balls") {
    let cols = [GridItem(.adaptive(minimum: 56), spacing: 12)]
    return ScrollView {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(PositionPlayBall.allKeys, id: \.self) { key in
                PoolBallFace(key: key, diameter: 56)
            }
        }
        .padding(24)
    }
    .background(Color.btTableFelt)
}
