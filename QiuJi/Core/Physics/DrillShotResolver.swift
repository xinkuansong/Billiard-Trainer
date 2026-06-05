import SceneKit

/// 把一条 Drill 解析为物理引擎入参 `ShotInput`，让动作库的轨迹/走位由 `ShotPredictor`
/// **真实计算**（而非消费手画折线）。
///
/// 优先级：
/// 1. 已标注 `shotIntent`（精确：连续力度 + 塞 + 仰角）→ 直接用。
/// 2. 否则从既有 `DrillAnimation` 反推（母球/目标球摆位 + 选袋），用默认中等力度、无塞。
///
/// 反推用于尚未补 `shotIntent` 的历史 Drill：轨迹仍是引擎真算（含减速/吃库/分离角），
/// 只是力度/塞取默认值；补上 `shotIntent` 后即可精确还原作者走位意图。
enum DrillShotResolver {

    /// 反推时的默认杆头速度（中等力度锚点，m/s；见 `ShotIntent.Shot.velocity` 注释）。
    static let defaultVelocity: Float = 3.3

    static func shotInput(for drill: DrillContent, surfaceY: Float) -> ShotInput? {
        if let shot = drill.shotIntent?.shots.first,
           let input = shot.shotInput(surfaceY: surfaceY) {
            return input
        }
        return shotInput(fromAnimation: drill.animation, surfaceY: surfaceY)
    }

    static func shotInput(fromAnimation animation: DrillAnimation, surfaceY: Float) -> ShotInput? {
        guard let pocketIndex = ShotIntent.pocketIndex(for: animation.pocket) else { return nil }
        let cue = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: animation.cueBall.start.x, y: animation.cueBall.start.y), surfaceY: surfaceY)
        let target = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: animation.targetBall.start.x, y: animation.targetBall.start.y), surfaceY: surfaceY)
        return ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: defaultVelocity, spinX: 0, spinY: 0, surfaceY: surfaceY)
    }
}
