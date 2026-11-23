import CoreGraphics

/// G1 瞄准点几何（问题集合 v3）——唯一真源。
///
/// **定义**：瞄准点 = 瞄准线与「过目标球中心且垂直于瞄准线的直线」的交点，
/// 即目标球心到瞄准线的**垂足**：
/// - 瞄准线穿过目标球（垂距 < R）时，瞄准点在球内/球面上；
/// - 瞄准线从目标球侧面经过时，瞄准点在球外；
/// - 瞄准点**参考目标球**定义，不等于假想球心（旧口径）。
///
/// 数值关系（正确瞄准时）：垂距 = 2R·sin(θ)（与旧公式 d 同值），
/// 垂足沿瞄准线比假想球心前移 2R·cos(θ)；θ ≤ 30° 时瞄准点落在目标球内。
///
/// 纯 2D 平面计算，坐标系无关（视图系 x右/y下 或 SceneKit 水平面 X–Z 均可），
/// 只要求两输入点/向量在同一平面系内。
enum AimPointGeometry {

    /// 瞄准点：过 `lineOrigin`、方向 `direction` 的瞄准线上距 `targetCenter` 最近的点（垂足）。
    /// `direction` 无需单位化；长度退化（< 1e-9）时原样返回 `lineOrigin`。
    static func aimPoint(lineOrigin: CGPoint,
                         direction: CGPoint,
                         targetCenter: CGPoint) -> CGPoint {
        let len2 = direction.x * direction.x + direction.y * direction.y
        guard len2 > 1e-18 else { return lineOrigin }
        let t = ((targetCenter.x - lineOrigin.x) * direction.x
                 + (targetCenter.y - lineOrigin.y) * direction.y) / len2
        return CGPoint(x: lineOrigin.x + direction.x * t,
                       y: lineOrigin.y + direction.y * t)
    }

    /// 目标球心到瞄准线的垂距（≥ 0）。正确瞄准时 = 2R·sin(θ)。
    static func offsetDistance(lineOrigin: CGPoint,
                               direction: CGPoint,
                               targetCenter: CGPoint) -> CGFloat {
        let foot = aimPoint(lineOrigin: lineOrigin, direction: direction,
                            targetCenter: targetCenter)
        return hypot(foot.x - targetCenter.x, foot.y - targetCenter.y)
    }

    /// 有符号横向偏移：瞄准点相对目标球心、沿参考法向 `positiveNormal` 的投影。
    /// `positiveNormal` 定义「正侧」（无需单位化；长度退化返回 0）。
    /// 用于误差口径：以正确瞄准点所在侧为正，可区分「拖错侧」。
    static func signedOffset(lineOrigin: CGPoint,
                             direction: CGPoint,
                             targetCenter: CGPoint,
                             positiveNormal: CGPoint) -> CGFloat {
        let nLen = hypot(positiveNormal.x, positiveNormal.y)
        guard nLen > 1e-9 else { return 0 }
        let foot = aimPoint(lineOrigin: lineOrigin, direction: direction,
                            targetCenter: targetCenter)
        return ((foot.x - targetCenter.x) * positiveNormal.x
                + (foot.y - targetCenter.y) * positiveNormal.y) / nLen
    }
}
