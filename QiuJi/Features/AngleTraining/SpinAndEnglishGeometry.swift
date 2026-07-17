import CoreGraphics
import Foundation

/// 「旋转与加塞」页教学路径几何（v11 Y2）。
///
/// 复用 `AimingMethodsGeometry.scene` 的半球（θ=30°）标准球形；碰后三条示意路径
/// 的方向不变量由 `build/y2-evidence/y2-geometry-draft.txt` 锁定：
/// - 切线 ⊥ 连心线 n；stun 分离角 = 90°（T02/T03）
/// - 前旋/自然滚动：相对瞄准线偏折约 30°（T01）→ 相对 n 为 60°
/// - 后旋：切线反偏约 30°（T03）→ 相对 n 为 120°（分离角 > 90°）
///
/// 坐标契约：SceneKit 台面米坐标，水平面 X–Z（`CGPoint.x`=X，`.y`=Z），
/// +X 右，屏上 = −Z；单位米。路径为教学折线，非 `simulateFree` 轨迹。
enum SpinAndEnglishGeometry {
    enum SpinState: String, CaseIterable, Identifiable {
        case stun
        case follow
        case draw

        var id: String { rawValue }

        /// 分段选择器标题（用户可见）。
        var pickerTitle: String {
            switch self {
            case .stun:   return "滑动"
            case .follow: return "前旋"
            case .draw:   return "后旋"
            }
        }

        /// 插图标签短名。
        var pathLabel: String {
            switch self {
            case .stun:   return "切线 90°"
            case .follow: return "前旋前弯"
            case .draw:   return "后旋后弯"
            }
        }
    }

    /// 标准教学场景：半球切角，与 Y1 同球位。
    static func scene() -> AimingMethodsGeometry.Scene {
        AimingMethodsGeometry.scene(
            cutAngleDeg: CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees))
    }

    /// 切线单位方向（stun 出发）：入射瞄准方向在 ⊥n 上的分量（T02/T03）。
    static func tangentDir(scene: AimingMethodsGeometry.Scene) -> CGPoint {
        let n = scene.potDir
        let u = scene.aimDir
        let vn = CGPoint(x: n.x * dot(u, n), y: n.y * dot(u, n))
        let vt = CGPoint(x: u.x - vn.x, y: u.y - vn.y)
        return unit(vt)
    }

    /// 旋向符号：切线相对进球方向 n 的旋转侧（+1 = 与切角同侧）。
    static func side(scene: AimingMethodsGeometry.Scene) -> CGFloat {
        let t = tangentDir(scene: scene)
        let cross = scene.potDir.x * t.y - scene.potDir.y * t.x
        return cross >= 0 ? 1 : -1
    }

    /// 碰后示意方向（单位向量）。
    static func departureDir(scene: AimingMethodsGeometry.Scene, state: SpinState) -> CGPoint {
        let s = side(scene: scene)
        switch state {
        case .stun:
            return tangentDir(scene: scene)
        case .follow:
            // T01：约 30° 偏离瞄准线 → 相对 n 为 60°（θ=30° 半球）
            return AimingMethodsGeometry.rotate(scene.potDir, byDegrees: s * 60)
        case .draw:
            // T03：切线反偏 ~30° → 相对 n 为 120°
            return AimingMethodsGeometry.rotate(scene.potDir, byDegrees: s * 120)
        }
    }

    /// 示意路径终点（自假想球心 G 沿出发方向）。
    static func pathEnd(scene: AimingMethodsGeometry.Scene, state: SpinState) -> CGPoint {
        let len: CGFloat = state == .draw ? 0.22 : 0.28
        let d = departureDir(scene: scene, state: state)
        return CGPoint(x: scene.ghost.x + d.x * len, y: scene.ghost.y + d.y * len)
    }

    /// 目标球进球线远端（示意）。
    static func objectBallEnd(scene: AimingMethodsGeometry.Scene) -> CGPoint {
        CGPoint(x: scene.target.x + scene.potDir.x * 0.35,
                y: scene.target.y + scene.potDir.y * 0.35)
    }

    // MARK: - Invariants (for evidence / tests)

    /// 分离角（度）：母球出发方向与进球方向 n 的夹角，0…180。
    static func separationDegrees(scene: AimingMethodsGeometry.Scene, state: SpinState) -> CGFloat {
        let d = departureDir(scene: scene, state: state)
        let c = max(-1, min(1, dot(d, scene.potDir)))
        return acos(c) * 180 / .pi
    }

    private static func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.x + a.y * b.y }

    private static func unit(_ v: CGPoint) -> CGPoint {
        let len = hypot(v.x, v.y)
        guard len > 1e-9 else { return .zero }
        return CGPoint(x: v.x / len, y: v.y / len)
    }
}
