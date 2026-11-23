import CoreGraphics

/// 角度预测题面几何真源（竖直 0° + 左右摆）。
///
/// **切角语义**（与瞄准原理一致，本类型只改题面朝向）：
/// - 0° = 正对（瞄准线与进球线共线）
/// - 90° = 极薄
/// - 答题无符号：左右两侧同一 θ 答同一度数
///
/// **坐标契约**（SwiftUI 画布）：原点左上，x 右、y 下，单位 pt。
/// - 0° 方向 = 竖直向上 `(0, -1)`
/// - 右侧 θ：`(sin θ, −cos θ)` → 90° 时水平向右
/// - 左侧 θ：`(−sin θ, −cos θ)` → 90° 时水平向左
enum AnglePredictionSide: String, CaseIterable, Equatable, Hashable, Sendable {
    case left
    case right
}

enum AnglePredictionGeometry {

    /// 单位瞄准方向（从母球顶点指向目标球）。
    static func aimDirection(angleDegrees: Double, side: AnglePredictionSide) -> CGPoint {
        let rad = angleDegrees * .pi / 180
        let sx: CGFloat = side == .right ? 1 : -1
        return CGPoint(x: sx * CGFloat(sin(rad)), y: -CGFloat(cos(rad)))
    }

    /// 射线终点：`vertex + length · aimDirection`。
    static func point(from vertex: CGPoint,
                      length: CGFloat,
                      angleDegrees: Double,
                      side: AnglePredictionSide) -> CGPoint {
        let d = aimDirection(angleDegrees: angleDegrees, side: side)
        return CGPoint(x: vertex.x + length * d.x, y: vertex.y + length * d.y)
    }

    /// 0° 参考线终点（竖直向上）。
    static func zeroEnd(from vertex: CGPoint, length: CGFloat) -> CGPoint {
        CGPoint(x: vertex.x, y: vertex.y - length)
    }

    /// 底中顶点 + 向上扇区布局。
    /// 纵向：内容带 `rayLen + 2R` 居中 ⇒ `vertex.y = h/2 + rayLen/2`。
    /// 横向：90° 时球外缘不越 `margin` ⇒ `rayLen ≤ w/2 − margin − R`。
    static func layout(canvasSize: CGSize,
                       ballRadius: CGFloat,
                       margin: CGFloat = 20) -> (vertex: CGPoint, rayLen: CGFloat) {
        let w = canvasSize.width
        let h = canvasSize.height
        let verticalBudget = h - 2 * margin - 2 * ballRadius
        let horizontalBudget = w / 2 - margin - ballRadius
        let rayLen = max(0, min(verticalBudget, horizontalBudget))
        let vertex = CGPoint(x: w / 2, y: h / 2 + rayLen / 2)
        return (vertex, rayLen)
    }
}
