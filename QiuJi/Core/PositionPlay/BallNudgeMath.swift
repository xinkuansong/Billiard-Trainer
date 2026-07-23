import Foundation

/// 批量出片台摆球精调方向（屏幕语义）。
enum BallNudgeDirection: CaseIterable {
    case up, down, left, right
}

/// 球位精调数值规则（纯函数，可单测）。
///
/// 坐标契约（`CameraRig.applyTopDown2DRotated` + `ShotTableLayout`）：
/// - 世界系水平面 = X–Z，单位米；Y 朝上。
/// - rotated 顶视：世界 **+X = 屏幕上**，世界 **+Z = 屏幕右**。
enum BallNudgeMath {
    /// 默认精调步进：0.5 mm。
    static let fineStepMeters: Float = 0.0005

    /// 屏幕方向 → 世界水平位移（米）。
    static func delta(for dir: BallNudgeDirection, stepMeters: Float = fineStepMeters) -> (dx: Float, dz: Float) {
        switch dir {
        case .up:    return (stepMeters, 0)
        case .down:  return (-stepMeters, 0)
        case .left:  return (0, -stepMeters)
        case .right: return (0, stepMeters)
        }
    }
}
