import CoreGraphics
import Foundation

/// 「旋转与加塞」页教学路径几何（v11 Y2 → v12 Z4）。
///
/// 复用 `AimingMethodsGeometry.scene(cutAngleDeg:)`；默认半球（θ=30°）。
/// 碰后三条示意路径相对进球方向 n **固定**为教学折线（见 `build/z4-evidence/`）：
/// - 切线 ⊥ 连心线 n；stun 分离角 = 90°（T02/T03）
/// - 前旋/自然滚动：相对 n 为 60°（半球下 ≡ T01「约 30° 偏离瞄准线」）
/// - 后旋：相对 n 为 120°（T03；分离角 > 90°）
///
/// 切角滑杆只驱动球形（C/G/T/Q），**不**把示意角重算成精确物理分离角。
/// 非半球档 UI 须标注「示意角 · 教学折线」。
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

    /// 默认半球教学场景（不变量单测锁定位）。
    static func scene() -> AimingMethodsGeometry.Scene {
        scene(cutAngleDeg: CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees))
    }

    /// 按切角 θ 生成教学球形（与瞄准方法页同入口）。
    static func scene(cutAngleDeg: CGFloat) -> AimingMethodsGeometry.Scene {
        AimingMethodsGeometry.scene(cutAngleDeg: cutAngleDeg)
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

    /// 碰后示意方向（单位向量）。教学折线：相对 n 固定 90°/60°/120°。
    static func departureDir(scene: AimingMethodsGeometry.Scene, state: SpinState) -> CGPoint {
        let s = side(scene: scene)
        switch state {
        case .stun:
            return tangentDir(scene: scene)
        case .follow:
            return AimingMethodsGeometry.rotate(scene.potDir, byDegrees: s * 60)
        case .draw:
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
    /// 对教学折线：任意 θ 下 stun/follow/draw 分别为 90/60/120（见 z4-cut-angle-scan）。
    static func separationDegrees(scene: AimingMethodsGeometry.Scene, state: SpinState) -> CGFloat {
        let d = departureDir(scene: scene, state: state)
        let c = max(-1, min(1, dot(d, scene.potDir)))
        return acos(c) * 180 / .pi
    }

    /// 前旋示意方向相对瞄准线的夹角（度）。仅半球 θ=30° 时 ≈30°（T01 口诀）。
    static func followAngleFromAimDegrees(scene: AimingMethodsGeometry.Scene) -> CGFloat {
        let d = departureDir(scene: scene, state: .follow)
        let c = max(-1, min(1, dot(d, scene.aimDir)))
        return acos(c) * 180 / .pi
    }

    private static func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat { a.x * b.x + a.y * b.y }

    private static func unit(_ v: CGPoint) -> CGPoint {
        let len = hypot(v.x, v.y)
        guard len > 1e-9 else { return .zero }
        return CGPoint(x: v.x / len, y: v.y / len)
    }
}
