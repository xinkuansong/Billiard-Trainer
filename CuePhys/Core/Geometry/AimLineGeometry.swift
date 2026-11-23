import CoreGraphics

/// Q7.1（问题集合 v5）2D 瞄准点训练：白色瞄准线终点 + 红点显隐规则的**纯 2D 平面几何**。
///
/// 取代旧「与目标球心 2R 圆求交、相交即把白线截停在假想球心位」的「假想球半径捕捉区」行为
/// （`AimPointSceneQuizViewModel.aimLineEnd`）。新规则：
/// - **未接触目标球**（目标球心到瞄准线垂距 ≥ R）⇒ 白线直接延伸到库边（`railEnd` 由调用方按坐标系算好传入）；
/// - **接触目标球**（垂距 < R，等价于「瞄准线与过球心垂线的交点距球心 < R」）⇒ 白线停在
///   射线与球面（半径 R）的**第一交点（接触点）**；此时同时给出两枚红点：
///     · 瞄准点 = 垂足（`AimPointGeometry.aimPoint`，G1 口径）；
///     · 接触点 = 射线与球面第一交点。
///
/// 坐标契约（几何任务，钉死后落码）：纯 2D 平面、坐标系无关；调用方保证所有入参在**同一平面系**内。
/// 本项目消费方（SceneKit 水平面 X–Z）以 `x→x、z→y` 映射为平面点（见 `AimPointSceneQuizViewModel.xzPoint`）。
/// 距离单位随入参（本项目为米）。
enum AimLineGeometry {

    struct Resolution {
        /// 白色瞄准线终点（接触 ⇒ 接触点；未接触 ⇒ 库边 `railEnd`）。
        let lineEnd: CGPoint
        /// 是否接触目标球（垂距 < R）。
        let touchesBall: Bool
        /// 瞄准点（目标球心到瞄准线的垂足，G1）。仅 `touchesBall` 时作红点绘制。
        let aimPoint: CGPoint
        /// 接触点（射线与球面第一交点）。仅 `touchesBall` 且存在前向交点时非 nil。
        let contactPoint: CGPoint?
    }

    /// 解析用户瞄准线的白线终点与红点。
    /// - Parameters:
    ///   - cue: 瞄准线起点（母球心）。
    ///   - dir: 瞄准方向（无需单位化；退化时白线退回 `railEnd`）。
    ///   - target: 目标球心。
    ///   - ballRadius: 球半径 R。
    ///   - railEnd: 未接触目标球时白线延伸的库边终点（调用方按坐标系用 `rayToInnerRail` 算好传入）。
    static func resolve(cue: CGPoint,
                        dir: CGPoint,
                        target: CGPoint,
                        ballRadius R: CGFloat,
                        railEnd: CGPoint) -> Resolution {
        let foot = AimPointGeometry.aimPoint(lineOrigin: cue, direction: dir, targetCenter: target)
        let perpDist = hypot(foot.x - target.x, foot.y - target.y)
        guard perpDist < R else {
            return Resolution(lineEnd: railEnd, touchesBall: false,
                              aimPoint: foot, contactPoint: nil)
        }
        let contact = firstRaySphereIntersection(origin: cue, dir: dir, center: target, radius: R)
        return Resolution(lineEnd: contact ?? railEnd, touchesBall: true,
                          aimPoint: foot, contactPoint: contact)
    }

    /// 射线（`origin` 沿 `dir` 前进）与圆（心 `center`、半径 `radius`）的**第一前向交点**。
    /// 无交点或交点在射线反向（t ≤ 0）时返回 nil。`dir` 内部单位化。
    static func firstRaySphereIntersection(origin: CGPoint,
                                           dir: CGPoint,
                                           center: CGPoint,
                                           radius R: CGFloat) -> CGPoint? {
        let len = hypot(dir.x, dir.y)
        guard len > 1e-12 else { return nil }
        let ux = dir.x / len, uy = dir.y / len
        let fx = origin.x - center.x, fy = origin.y - center.y
        // |origin + t·u − center|² = R² ⇒ t² + b·t + c = 0（u 为单位向量，a=1）。
        let b = 2 * (fx * ux + fy * uy)
        let c = fx * fx + fy * fy - R * R
        let disc = b * b - 4 * c
        guard disc >= 0 else { return nil }
        let t = (-b - sqrt(disc)) / 2      // 近端交点（第一交点）
        guard t > 0 else { return nil }
        return CGPoint(x: origin.x + ux * t, y: origin.y + uy * t)
    }
}
